// lib/features/word_lookup/widgets/word_pronunciation_row.dart
//
// PRON-002 (PLAN-038 §2.1, ADR-0015 D1/D3) — MỘT affordance "Phát âm" dùng
// chung cho mọi surface tra từ. Triết lý đã chốt: **một nút, lười** — YouGlish
// (WebView) CHỈ được dựng khi người dùng bấm vào nguồn đó, không preload, không
// thêm TabBar vào sheet nào.
//
// Ba chế độ (mỗi surface ĐÚNG một affordance — PLAN-038 §2.1):
//   • [WordPronunciationRowMode.youglishIconOnly] — pop không-modal
//     `WordMiniPop` (OverlayEntry, ADR-0016): pop đã có nút ▶ `Phát âm` riêng
//     (giữ nguyên hành vi + key `wordMiniPopSpeakKey`), nên row chỉ THÊM đúng
//     một icon 🎧, không choán chỗ.
//   • [WordPronunciationRowMode.compact] — header của `WordActionsSheet`: thay
//     cụm loa cô độc cũ bằng [▶ theo nguồn policy] + [🎧 YouGlish].
//   • [WordPronunciationRowMode.full] — các sheet còn lại (PRON-003): play +
//     chip chọn nguồn + "Mở trình duyệt".
//
// `onBeforeOpen` là chỗ pop tự `WordMiniPop.dismiss()`: sheet modal PHẢI mở sau
// khi pop biến mất, nếu không OverlayEntry của pop nằm trên Route modal.
//
// ⚠️ KHÔNG import file này vào cây reachable từ `lib/main_web.dart`: nó kéo
//    theo `YouGlishMiniSheet` → `YouGlishView` → `dart:io` (build web
//    `deploy-web.yml` sẽ đỏ). Web (nếu sau này cần) dùng `web/youglish_embed.html`.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/core/platform/safe_haptics.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/text_provider.dart';
import '../../../screens/tools/youglish/youglish_config.dart';
import '../../../screens/tools/youglish/youglish_mini_sheet.dart';
import '../../../screens/tools/youglish/youglish_prefs.dart';
import '../pronunciation_source.dart';
import '../services/pronunciation_prefs.dart';
import '../services/pronunciation_session.dart';

enum WordPronunciationRowMode {
  /// Một icon 🎧 duy nhất, đặt cạnh nút ▶ đã tồn tại (pop không-modal).
  youglishIconOnly,

  /// [▶ nguồn theo policy] + [🎧 YouGlish] (header `WordActionsSheet`).
  compact,

  /// Play + chip chọn nguồn + mở trình duyệt (PRON-003).
  full,
}

class WordPronunciationRow extends StatefulWidget {
  const WordPronunciationRow({
    super.key,
    required this.word,
    this.mode = WordPronunciationRowMode.compact,
    this.lineIndex,
    this.buttonKey,
    this.onBeforeOpen,
    this.accentColor = _kDefaultAccent,
    this.dictionaryHasAudio = false,
  });

  final String word;
  final WordPronunciationRowMode mode;

  /// Dòng đang đọc — chỉ pop truyền; `WordActionsSheet` trước PRON-002 gọi
  /// `tp.speak(word)` không lineIndex ⇒ giữ nguyên để không đổi highlight.
  final int? lineIndex;

  /// Key để test bám vào (vd `wordMiniPopYouGlishKey`).
  final Key? buttonKey;

  /// Chạy TRƯỚC khi mở sheet (pop dùng để `WordMiniPop.dismiss()`).
  final VoidCallback? onBeforeOpen;
  final Color accentColor;

  /// PRON-005 sẽ cấp giá trị thật từ `DictEntry.hasAudio`. Ở PRON-002 nguồn
  /// này LUÔN false ⇒ policy không bao giờ chọn nó (không "nút ma").
  final bool dictionaryHasAudio;

  static const Color _kDefaultAccent = Color(0xFF2196F3);

  @override
  State<WordPronunciationRow> createState() => _WordPronunciationRowState();
}

class _WordPronunciationRowState extends State<WordPronunciationRow> {
  bool _youglishEnabled = true;
  bool _network = true;
  PronunciationSource _source = PronunciationSource.tts;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WordPronunciationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pop có thể nhảy sang từ khác mà không rebuild cả Overlay ⇒ nguồn phải
    // được tính lại theo từ mới (kill-switch/khả dụng không đổi, chỉ remember).
    if (oldWidget.word != widget.word ||
        oldWidget.dictionaryHasAudio != widget.dictionaryHasAudio) {
      _applyPolicy();
    }
  }

  Future<void> _load() async {
    await PronunciationPrefs.load();
    bool enabled = true;
    try {
      final prefs = await YouGlishPrefs.load();
      enabled = prefs.enabled;
    } catch (_) {
      // Không đọc được pref ⇒ mặc định BẬT (kill-switch vẫn còn trong prefs
      // tool); trạng thái suy giảm không được làm mất nút phát âm.
      enabled = true;
    }
    bool network = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      network = !conn.every((c) => c == ConnectivityResult.none);
    } catch (_) {
      network = true; // chưa biết ⇒ đừng chặn tính năng
    }
    if (!mounted) return;
    setState(() {
      _youglishEnabled = enabled;
      _network = network;
      _loaded = true;
    });
    _applyPolicy();
  }

  PronunciationAvailability get _availability => PronunciationAvailability(
        youglishEnabled: _youglishEnabled,
        networkAvailable: _network,
        dictionaryHasAudio: widget.dictionaryHasAudio,
      );

  void _applyPolicy() {
    final resolved = PronunciationSourcePolicy.resolve(
      remembered: PronunciationPrefs.lastSource,
      availability: _availability,
    );
    if (mounted && resolved != _source) setState(() => _source = resolved);
  }

  Future<void> _play() async {
    SafeHaptics.lightImpact();
    if (_source == PronunciationSource.youglish) {
      await _openYouGlish();
      return;
    }
    // PRON-002: `dictionary` CHƯA được nối (việc của PRON-005) ⇒ không được
    // im lặng nuốt cú bấm, thoái lui về TTS.
    await _speak();
  }

  Future<void> _speak() async {
    final tp = context.read<TextProvider>();
    await tp.speak(widget.word, lineIndex: widget.lineIndex);
  }

  /// Điểm vào DUY NHẤT dựng WebView YouGlish từ surface tra từ (rule "một nút
  /// lười" — `YouGlishMiniSheet.show` mới load `YouGlishPrefs` + nạp URL).
  Future<void> _openYouGlish() async {
    if (!_loaded) await _load();
    if (!_network) {
      // Không có mạng ⇒ hạ bậc về TTS ngay, báo rõ ràng, KHÔNG dựng WebView.
      await _speak();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.uiText('Không có mạng — đã dùng giọng máy')),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    // Context BỀN: sau `onBeforeOpen` (pop tự dismiss), element của row có thể
    // bị gỡ ⇒ mở sheet trên Navigator gốc, nơi Provider vẫn còn (TextProvider
    // được provide ABOVE MaterialApp trong main.dart:297).
    final host = Navigator.of(context, rootNavigator: true).context;
    widget.onBeforeOpen?.call();
    await PronunciationSession.wrapRead(
      host,
      () => YouGlishMiniSheet.show(host, widget.word),
    );
    if (!mounted) return;
    await PronunciationPrefs.setLastSource(PronunciationSource.youglish);
    _applyPolicy();
  }

  Future<void> _select(PronunciationSource source) async {
    SafeHaptics.selectionClick();
    await PronunciationPrefs.setLastSource(source);
    if (!mounted) return;
    setState(() => _source = source);
  }

  Future<void> _openInBrowser() async {
    SafeHaptics.lightImpact();
    final prefs = await YouGlishPrefs.load();
    final url = YouGlishUrl.build(
      word: widget.word,
      language: prefs.language,
      accent:
          prefs.language == YouGlishLanguage.english ? prefs.accent : null,
      autoplay: false,
    );
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  IconData _iconFor(PronunciationSource source) => switch (source) {
        PronunciationSource.tts => Icons.volume_up_rounded,
        PronunciationSource.youglish => Icons.headset_mic_rounded,
        PronunciationSource.dictionary => Icons.menu_book_rounded,
      };

  String _tooltipFor(PronunciationSource source) => switch (source) {
        PronunciationSource.tts => context.uiText('Phát âm'),
        PronunciationSource.youglish => context.uiText('Nghe trên YouGlish'),
        PronunciationSource.dictionary =>
          context.uiText('Âm thanh từ điển'),
      };

  /// Icon 🎧 riêng (bên cạnh nút ▶) — chỉ khi YouGlish BẬT, mode không phải
  /// iconOnly (mode đó CHỈ có icon này), và nguồn hiện hành chưa phải YouGlish
  /// (nếu đã là YouGlish thì nút ▶ chính đã làm việc đó, khỏi lặp).
  bool get _youglishShown =>
      _youglishEnabled &&
      widget.mode != WordPronunciationRowMode.youglishIconOnly &&
      _source != PronunciationSource.youglish;

  @override
  Widget build(BuildContext context) {
    if (widget.mode == WordPronunciationRowMode.youglishIconOnly) {
      // ĐÚNG một icon 🎧 — nguồn luôn là YouGlish ở mode này. Kill-switch
      // `youglish.enabled` (ADR-0015 D2) TẮC HẲN affordance, không phải đổi
      // hành vi trong: chủ nhân kill-switch là owner, không phải người dùng.
      if (!_youglishEnabled) return const SizedBox.shrink();
      return _PronCircleButton(
        key: widget.buttonKey,
        icon: Icons.headset_mic_rounded,
        tooltip: context.uiText('Nghe trên YouGlish'),
        onTap: _openYouGlish,
        dense: true,
        accent: const Color(0xFF00BCD4),
        busy: !_loaded,
      );
    }
    // Nút ▶ KHÔNG bị khoá lúc chờ pref: mặc định an toàn là TTS, bấm là nghe
    // được ngay; YouGlish (icon phụ) mới cần chờ vì nó dựng WebView.
    final play = _PronCircleButton(
      key: widget.buttonKey,
      icon: _iconFor(_source),
      tooltip: _tooltipFor(_source),
      onTap: _play,
      // cỡ lớn (24px) cho header sheet; mode iconOnly đã trả sớm ở trên.
      dense: false,
      accent: widget.accentColor,
    );

    final youglish = _youglishShown
        ? Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _PronCircleButton(
              icon: Icons.headset_mic_rounded,
              tooltip: context.uiText('Nghe trên YouGlish'),
              onTap: _openYouGlish,
              dense: true,
              accent: const Color(0xFF00BCD4),
            ),
          )
        : const SizedBox.shrink();

    if (widget.mode == WordPronunciationRowMode.compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: [play, youglish]);
    }

    // full: play + chip nguồn + mở trình duyệt
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          play,
          youglish,
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _PronCircleButton(
              icon: Icons.open_in_new_rounded,
              tooltip: context.uiText('Mở trình duyệt'),
              onTap: _openInBrowser,
              dense: true,
              accent: Colors.white54,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in PronunciationSourcePolicy.preferredOrder)
              if (_availability.isAvailable(s))
                _PronSourceChip(
                  label: context.uiText(s.labelVi),
                  selected: _source == s,
                  onTap: () => _select(s),
                ),
          ],
        ),
      ],
    );
  }
}

class _PronCircleButton extends StatelessWidget {
  const _PronCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.accent,
    this.dense = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color accent;
  final bool dense;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final size = dense ? 16.0 : 24.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.all(dense ? 6 : 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: dense ? 0.18 : 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: size, color: busy ? Colors.white38 : accent),
        ),
      ),
    );
  }
}

class _PronSourceChip extends StatelessWidget {
  const _PronSourceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2196F3)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[400],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
