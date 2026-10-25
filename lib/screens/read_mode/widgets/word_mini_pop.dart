// lib/screens/read_mode/widgets/word_mini_pop.dart
//
// READ-POP-003 (owner 2026-10-25) — pop tra từ nhanh trong tab Đọc.
//
// YÊU CẦU CỦA OWNER (thay đổi so với bản 2026-10-20):
//   • Chạm một từ ⇒ phát âm **và** pop thông tin từ vựng trồi lên ngay.
//   • Pop KHÔNG được làm tối phần còn lại và KHÔNG được chặn chạm: chạm chỗ
//     khác thì pop tự ẩn (và thao tác đó vẫn chạy bình thường); chạm từ khác
//     thì pop ẩn đi và hiện pop mới cho từ đó.
//   • Muốn xem sâu: KÉO "rèm" ở đầu pop lên (hoặc chạm vào rèm/nút mở rộng)
//     ⇒ mở `WordActionsSheet` (bảng chi tiết đầy đủ).
//   • Giữ im một từ ⇒ vào chế độ chọn nhiều từ (READ-SELECT-002), kéo/quẹt để
//     chọn nhanh các từ LIỀN KỀ; chọn chỗ khác thì trở lại bình thường.
//
// Vì sao đổi khỏi `showGeneralDialog` (bản cũ): dialog có barrier tối + chặn
// toàn bộ chạm ra ngoài ⇒ đúng hai điều owner yêu cầu bỏ. Nay pop là
// `OverlayEntry` KHÔNG barrier, đặt cạnh từ (tính bằng
// `services/word_pop_layout.dart` — hàm thuần, có test), kèm một `Listener`
// `HitTestBehavior.translucent` phủ toàn màn: nó NHẬN pointer-down để tự ẩn
// nhưng vẫn để sự kiện đi tiếp xuống text phía dưới (translucent không chặn
// hit-test), nên "chạm chỗ khác" vừa ẩn pop vừa chạy thao tác bình thường.
// UI i18n: mọi widget chữ phải dùng `Text` của localized_material (KHÔNG
// import thêm `material.dart` rồi `hide Text`) — xem AGENTS.md.
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';
import 'package:in4up/core/platform/safe_haptics.dart';

import '../../../features/dictionary/services/dict_text_cleaner.dart';
import '../../../features/dictionary/widgets/dict_definition_view.dart';
import '../../../features/vocab_image/vocab_image_picker.dart';
import '../../../features/word_lookup/services/word_insight_service.dart';
import '../../../models/vocab_context.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../services/ipa_resolver.dart';
import '../services/word_pop_layout.dart';
import '../sheets/word_actions_sheet.dart';

/// Key của "rèm" (kéo lên để bung thông tin đầy đủ).
const Key wordMiniPopCurtainKey = Key('word_mini_pop_curtain');

/// Key của nút mở bảng chi tiết đầy đủ.
const Key wordMiniPopExpandKey = Key('word_mini_pop_expand');

/// Key của nút lưu nhớ trong pop.
const Key wordMiniPopSaveKey = Key('word_mini_pop_save');

/// Key của nút thêm ảnh trong pop.
const Key wordMiniPopImageKey = Key('word_mini_pop_image');

/// Key của nút phát âm trong pop.
const Key wordMiniPopSpeakKey = Key('word_mini_pop_speak');

/// Key của nút "Bôi nhiều chữ" trong pop.
const Key wordMiniPopSelectMoreKey = Key('word_mini_pop_select_more');

/// Key của cả thẻ pop (dùng cho test + để biết vùng "trong pop").
const Key wordMiniPopCardKey = Key('word_mini_pop_card');

/// Pop nhỏ cho 1 từ trong vùng đọc — hiển thị bằng OVERLAY, không modal.
class WordMiniPop extends StatefulWidget {
  const WordMiniPop({
    super.key,
    required this.word,
    required this.lineIndex,
    required this.wordIndex,
    this.onSelectMore,
    this.anchorRect,
  });

  final AnalyzedWord word;
  final int lineIndex;
  final int wordIndex;

  /// Nếu khác null ⇒ hiện nút "Bôi nhiều chữ" (bật chế độ chọn nhiều từ
  /// của READ-SELECT-002). Bấm ⇒ đóng pop và bắt đầu bôi từ.
  final VoidCallback? onSelectMore;

  /// Hình chữ nhật của từ (toạ độ toàn cục) — để pop đặt cạnh đúng từ.
  final Rect? anchorRect;

  // ── Quản lý overlay (chỉ MỘT pop sống tại một thời điểm) ────────────────

  static OverlayEntry? _cardEntry;
  static OverlayEntry? _catcherEntry;
  static ScrollPosition? _scrollPosition;
  static VoidCallback? _scrollListener;

  /// Pop đang hiển thị?
  static bool get isShowing => _cardEntry != null;

  /// Ẩn pop (idempotent).
  static void dismiss() {
    _cardEntry?.remove();
    _cardEntry = null;
    _catcherEntry?.remove();
    _catcherEntry = null;
    final position = _scrollPosition;
    final listener = _scrollListener;
    if (position != null && listener != null) {
      position.removeListener(listener);
    }
    _scrollPosition = null;
    _scrollListener = null;
  }

  /// Hiện pop cho [word] cạnh [anchorRect] (hoặc cạnh chính widget gọi).
  ///
  /// KHÔNG dùng dialog/barrier: phần còn lại của màn hình vẫn sáng và vẫn
  /// chạm được. Chạm ra ngoài ⇒ [dismiss] chạy trên pointer-down, cú chạm vẫn
  /// được text phía dưới xử lý như thường.
  static void show(
    BuildContext context, {
    required AnalyzedWord word,
    required int lineIndex,
    required int wordIndex,
    Rect? anchorRect,
    VoidCallback? onSelectMore,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Từ khác ⇒ thay pop cũ bằng pop mới (owner: "chạm từ khác thì tự nó ẩn
    // đi hay hiện pop cho từ khác").
    dismiss();

    final anchor = anchorRect ?? _rectOfContext(context);
    final size = overlay.context.size ??
        MediaQuery.maybeOf(context)?.size ??
        const Size(400, 800);
    final placement = computeWordPopPlacement(anchor: anchor, screen: size);

    final catcher = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Listener(
          // translucent = nhận pointer để tự ẩn, NHƯNG vẫn để sự kiện đi
          // xuống widget phía dưới (không chặn chạm như barrier của dialog).
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => dismiss(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    final card = OverlayEntry(
      builder: (_) => Positioned(
        left: placement.left,
        top: placement.top,
        width: placement.width,
        child: WordMiniPop(
          key: wordMiniPopCardKey,
          word: word,
          lineIndex: lineIndex,
          wordIndex: wordIndex,
          onSelectMore: onSelectMore,
          anchorRect: anchor,
        ),
      ),
    );

    overlay.insertAll(<OverlayEntry>[catcher, card]);
    _catcherEntry = catcher;
    _cardEntry = card;

    // Cuộn vùng đọc ⇒ pop "trôi" khỏi từ ⇒ ẩn luôn (không hiện thông tin
    // sai chỗ).
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      void listener() => dismiss();
      scrollable.position.addListener(listener);
      _scrollPosition = scrollable.position;
      _scrollListener = listener;
    }
  }

  static Rect _rectOfContext(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return Rect.zero;
  }

  @override
  State<WordMiniPop> createState() => _WordMiniPopState();
}

class _WordMiniPopState extends State<WordMiniPop> {
  WordInsight? _insight;
  DictMergedEntry? _merged;
  bool _loading = true;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _loadInsight();
  }

  /// WORD-INSIGHT-001: hiện nghĩa NGAY từ nguồn cục bộ (MDX → offline), rồi
  /// nâng cấp bằng nguồn mạng — giống trải nghiệm sheet PDF mà owner khen.
  Future<void> _loadInsight() async {
    final raw = widget.word.word;
    if (raw.trim().isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final service = WordInsightService();
    try {
      final local = await service.resolveLocal(raw);
      if (!mounted) return;
      setState(() {
        _insight = local;
        if (local.hasDictionary) _merged = local.mergedDictionary;
        if (local.hasAny) _loading = false;
      });

      final online = await service.resolve(raw);
      if (!mounted) return;
      setState(() {
        _insight = online;
        if (online.hasDictionary) _merged = online.mergedDictionary;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// IPA ưu tiên: từ đã phân tích → nguồn tra → từ điển.
  String? get _ipa {
    final own = widget.word.phonetic?.trim();
    if (own != null && own.isNotEmpty) return own;
    final fromInsight = (_insight?.ipa ?? '').trim();
    if (fromInsight.isNotEmpty) return fromInsight;
    for (final group in _merged?.groups ?? const <DictPosGroup>[]) {
      for (final sense in group.senses) {
        final found = IpaDefinitionExtractor.extract(sense.text);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? get _meaning {
    final fromInsight = (_insight?.meaning ?? '').trim();
    if (fromInsight.isNotEmpty) return fromInsight;
    final m = widget.word.meaning;
    return (m == null || m.isEmpty) ? null : m;
  }

  bool get _hasDictionaryContent =>
      _merged != null && (_merged?.isEmpty == false);

  /// Kéo rèm lên quá ngưỡng ⇒ mở bảng chi tiết đầy đủ.
  void _onCurtainDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDistance < 36 && velocity > -260) {
      setState(() => _dragDistance = 0);
      return;
    }
    _openFullSheet();
  }

  void _openFullSheet() {
    // Lấy navigator TRƯỚC khi ẩn pop: context của overlay entry sẽ unmount.
    final navigator = Navigator.of(context, rootNavigator: true);
    final sheetCtx = navigator.context;
    WordMiniPop.dismiss();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!sheetCtx.mounted) return;
      WordActionsSheet.show(
        sheetCtx,
        widget.word,
        widget.lineIndex,
        widget.wordIndex,
      );
    });
  }

  void _save() {
    final tp = context.read<TextProvider>();
    final vocab = context.read<VocabularyProvider>();
    if (vocab.hasWord(widget.word.word)) {
      _toast(context.uiText('Từ đã có trong thư viện'));
      return;
    }
    final ipa = _ipa;
    vocab.addWithAutoClassify(
      text: widget.word.word,
      meaning: widget.word.meaning ?? _meaning ?? '',
      phonetic: ipa,
      phoneticSource: ipa == null ? null : 'mdx',
      context: _buildContext(tp),
    );
    tp.saveWord(widget.word);
    _toast(context.uiText('Đã lưu từ'));
  }

  VocabContext _buildContext(TextProvider tp) {
    final title = tp.currentDocument?.title ?? 'Text Studio';
    final lineContent = widget.lineIndex < tp.lines.length
        ? tp.lines[widget.lineIndex].content
        : widget.word.word;
    return VocabContext.fromStory(
      storyTitle: title,
      lineIndex: widget.lineIndex,
      surroundingText: lineContent,
      sourceRef: tp.currentContextSourceRef,
      sourceRefType: tp.currentContextSourceRefType,
      anchorText: widget.word.word,
    );
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Mở hộp chọn ảnh (tìm/chọn ảnh — cùng cơ chế với Worklist + Sửa từ).
  void _openImagePicker() {
    final vocab = context.read<VocabularyProvider>();
    final existing = vocab.findByWord(widget.word.word);
    if (existing == null) {
      _toast(context.uiText('Hãy lưu từ trước khi thêm ảnh'));
      return;
    }
    final dialogCtx = Navigator.of(context, rootNavigator: true).context;
    showDialog<void>(
      context: dialogCtx,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VocabImagePicker(
                wordId: existing.id,
                word: existing.word,
                meaning: existing.meaning,
                currentImageUrl: existing.imageUrl,
                onImageChanged: (_) {},
                size: 120,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(context.uiText('Đóng')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocab = context.watch<VocabularyProvider>();
    final saved = vocab.hasWord(widget.word.word);
    final type = widget.word.wordType;
    final media = MediaQuery.maybeOf(context);
    final maxHeight = media == null
        ? 320.0
        : computeWordPopPlacement(
            anchor: widget.anchorRect ?? Rect.zero,
            screen: media.size,
          ).maxHeight;

    // `HitTestBehavior.opaque`: chạm vào BẤT KỲ chỗ nào trong thẻ pop (kể cả
    // khoảng đệm) đều dừng tại đây — không rơi xuống lớp bắt-chạm bên dưới
    // (nếu không, chạm vào đệm của pop sẽ tự đóng pop và kích hoạt luôn từ
    // nằm dưới). Dùng `Listener` chứ không dùng `GestureDetector` để KHÔNG
    // tranh cử chỉ với các nút bên trong pop.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                // Cuộn trong pop (không tràn) — bảng đầy đủ ở WordActionsSheet.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurtain(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context, type),
                          const SizedBox(height: 8),
                          _buildBadges(type),
                          const SizedBox(height: 10),
                          _buildMeaningBlock(context),
                          const SizedBox(height: 12),
                          _buildActions(context, saved),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Rèm: kéo lên ⇒ bung thông tin đầy đủ; chạm ⇒ mở bảng chi tiết.
  Widget _buildCurtain(BuildContext context) {
    return GestureDetector(
      key: wordMiniPopCurtainKey,
      onVerticalDragUpdate: (d) => setState(() => _dragDistance += d.delta.dy),
      onVerticalDragEnd: _onCurtainDragEnd,
      onTap: _openFullSheet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 3),
                Text(
                  context.uiText('Kéo lên để xem đầy đủ'),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WordType type) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.word.word,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: type.color,
            ),
          ),
        ),
        if (_ipa != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _ipa!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Colors.white60),
            ),
          ),
        ],
        const SizedBox(width: 6),
        _MiniIconButton(
          buttonKey: wordMiniPopSpeakKey,
          icon: Icons.volume_up_rounded,
          tooltip: context.uiText('Phát âm'),
          onTap: () {
            SafeHaptics.lightImpact();
            final tp = context.read<TextProvider>();
            tp.speak(widget.word.word, lineIndex: widget.lineIndex);
          },
        ),
        const SizedBox(width: 4),
        _MiniIconButton(
          buttonKey: const Key('word_mini_pop_close'),
          icon: Icons.close_rounded,
          tooltip: context.uiText('Đóng'),
          subtle: true,
          onTap: WordMiniPop.dismiss,
        ),
      ],
    );
  }

  Widget _buildBadges(WordType type) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _MiniBadge(label: type.labelVi, color: type.color),
        _MiniBadge(
          label: widget.word.cefrLevel.shortLabel,
          color: widget.word.cefrLevel.color,
        ),
        if (widget.word.userDifficulty != null)
          _MiniBadge(
            label: widget.word.userDifficulty!.label,
            color: widget.word.userDifficulty!.color,
          ),
      ],
    );
  }

  /// Nghĩa: ưu tiên nội dung từ điển ĐÃ CẤU TRÚC (nhóm loại từ + nghĩa +
  /// ví dụ) — bản cũ chỉ in 200 ký tự đầu của chuỗi phẳng nên dễ lòi mã bản
  /// ghi/nhãn rác và "không thấy nghĩa đâu" (owner mục 3).
  Widget _buildMeaningBlock(BuildContext context) {
    if (_hasDictionaryContent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DictDefinitionView(
            groups: _merged!.groups,
            maxSenses: 3,
            compact: true,
            accentColor: const Color(0xFF64B5F6),
            sourceLabel: _merged!.sourceLabel,
            onOpenFull: _openFullSheet,
          ),
          if (_meaning != null && (_insight?.origin == WordInsightOrigin.network))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _meaning!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
        ],
      );
    }

    if (_loading && _meaning == null) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final meaning = _meaning;
    if (meaning != null) {
      return Text(
        meaning,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          height: 1.4,
        ),
      );
    }

    return Text(
      context.uiText('Chưa tra được nghĩa cho từ này'),
      style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
    );
  }

  Widget _buildActions(BuildContext context, bool saved) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MiniActionButton(
          buttonKey: wordMiniPopSaveKey,
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: context.uiText('Lưu'),
          active: saved,
          onTap: _save,
        ),
        if (widget.onSelectMore != null)
          _MiniActionButton(
            buttonKey: wordMiniPopSelectMoreKey,
            icon: Icons.format_list_bulleted,
            label: context.uiText('Bôi nhiều chữ'),
            onTap: () {
              final cb = widget.onSelectMore;
              WordMiniPop.dismiss();
              cb?.call();
            },
          ),
        _MiniActionButton(
          buttonKey: wordMiniPopImageKey,
          icon: Icons.image_outlined,
          label: context.uiText('Thêm ảnh'),
          onTap: _openImagePicker,
        ),
        _MiniActionButton(
          buttonKey: wordMiniPopExpandKey,
          icon: Icons.open_in_full_rounded,
          label: context.uiText('Xem đầy đủ'),
          onTap: _openFullSheet,
        ),
      ],
    );
  }
}

/// Badge nhỏ (loại từ / CEFR / độ khó).
class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Nút tròn chỉ có icon.
class _MiniIconButton extends StatelessWidget {
  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool subtle;

  const _MiniIconButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        subtle ? Colors.white54 : const Color(0xFF2196F3);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: subtle
                ? Colors.white.withValues(alpha: 0.06)
                : color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// Nút hành động nhỏ (icon + nhãn).
class _MiniActionButton extends StatelessWidget {
  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF4CAF50).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? const Color(0xFF81C784) : Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? const Color(0xFF81C784) : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
