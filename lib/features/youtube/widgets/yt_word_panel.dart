// YT-LR-002 / IN4-86 — Bảng `Word Dictionary & Analysis` của chế độ YouTube.
//
// Bổ sung những gì `WordAnalysisSheet` chưa có cho luồng xem video:
//   • phiên âm IPA + từ loại ngay trên đầu bảng
//   • thanh trượt tần suất / độ khó (ngưỡng "từ đã quen")
//   • 3 nút ✓ Known / 📖 Learning / 🚫 Ignored
//   • tab Giải thích & Ngữ pháp (AI giải thích theo ngữ cảnh + ví dụ)
//
// Local-first: nghĩa lấy từ `OfflineDictionary` → MDX → AI trên máy
// (`AiServiceFacade`). Không gọi mạng.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

import '../../dictionary/models/dict_entry.dart';
import '../../dictionary/services/dictionary_service.dart';
import '../../translation/data/offline_dictionary.dart';
import '../services/cmu_phonetics_service.dart';
import '../models/yt_learning_settings.dart';
import '../models/yt_subtitle.dart' show LrWord, WordState;

/// Hiện bảng tra cứu từ vựng. Dùng chung cho portrait (bottom sheet) và
/// landscape (panel bên phải).
Future<void> showYtWordPanel(
  BuildContext context, {
  required LrWord word,
  String? sentenceContext,
  required YtLearningSettings settings,
  required ValueChanged<double> onFrequencyChanged,
  required ValueChanged<WordState> onStateChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: YtWordPanel(
        word: word,
        sentenceContext: sentenceContext,
        settings: settings,
        onFrequencyChanged: onFrequencyChanged,
        onStateChanged: onStateChanged,
      ),
    ),
  );
}

class YtWordPanel extends StatefulWidget {
  final LrWord word;
  final String? sentenceContext;
  final YtLearningSettings settings;
  final ValueChanged<double> onFrequencyChanged;
  final ValueChanged<WordState> onStateChanged;

  const YtWordPanel({
    super.key,
    required this.word,
    this.sentenceContext,
    required this.settings,
    required this.onFrequencyChanged,
    required this.onStateChanged,
  });

  @override
  State<YtWordPanel> createState() => _YtWordPanelState();
}

class _YtWordPanelState extends State<YtWordPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _dict = OfflineDictionary();

  List<DictEntry> _mdxEntries = const [];
  bool _mdxLoading = true;
  String? _localMeaning;
  String? _ipa;

  /// Trạng thái Known/Learning/Ignored giữ cục bộ trong bảng (bottom sheet là
  /// một route riêng — `setState` của màn player không rebuild được nó), rồi
  /// báo ngược lên qua [YtWordPanel.onStateChanged].
  late WordState _state;

  // ── YT-LR-002 (fix IN4-86) — trạng thái AI do CHÍNH panel giữ ─────────
  // Bản cũ đăng ký nghe provider (select/watch) + `facade.analyzeWord()`.
  // `analyzeWord()` gọi `notifyListeners()` ở GIỮA các `await`, và bảng đang
  // dựng `TabBarView` (PageView → viewport cần layout) ⇒ notify đúng lúc
  // build/layout sinh lỗi
  //   '!_debugDoingThisLayout': is not true → RenderBox was not laid out
  //   (RenderFlex / RenderPadding / RenderDecoratedBox NEEDS-PAINT).
  // Cách sửa: KHÔNG đăng ký nghe provider; tự gọi `lookupWord` và tự giữ
  // kết quả bằng `setState` của panel.
  bool _aiAvailable = false;
  bool _aiWaiting = false;
  AiAnalysis? _aiResult;
  String? _aiError;
  bool _aiDictOnly = false;
  int _waitedSec = 0;
  int _aiTab = 0;
  Timer? _aiTicker;

  @override
  void initState() {
    super.initState();
    _state = widget.word.state;
    _tabCtrl = TabController(length: 2, vsync: this);
    // Nghĩa offline (đồng bộ) lấy ngay để truyền vào AI làm nền tảng.
    _localMeaning = _dict.lookup(widget.word.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lookupMdx();
      _lookupPhonetic();
      _prepareAi();
    });
  }

  @override
  void didUpdateWidget(covariant YtWordPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.state != widget.word.state) {
      _state = widget.word.state;
    }
  }

  @override
  void dispose() {
    _aiTicker?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  /// Bấm lại nút đang chọn ⇒ bỏ đánh dấu (về `unknown`).
  void _onStateTap(WordState state) {
    final next = _state == state ? WordState.unknown : state;
    setState(() => _state = next);
    widget.onStateChanged(next);
  }

  Future<void> _lookupPhonetic() async {
    final local = _dict.phonetic(widget.word.text);
    final ipa = await CmuPhoneticsService.ipa(widget.word.text);
    if (!mounted) return;
    setState(() {
      _localMeaning = _dict.lookup(widget.word.text);
      _ipa = ipa ?? (local == null ? null : '/$local/');
    });
  }

  Future<void> _lookupMdx() async {
    try {
      final entries =
          await DictionaryService.instance.lookup(widget.word.text);
      if (mounted) {
        setState(() {
          _mdxEntries = entries;
          _mdxLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _mdxLoading = false);
    }
  }

  /// Có đường AI nào dùng được không (model local đã nạp, hoặc API remote
  /// đã cấu hình). Không có ⇒ đừng gọi, đừng để người dùng chờ vô ích.
  void _prepareAi() {
    final f = context.read<AiServiceFacade>();
    final available = f.hasModel || f.isRemoteChatConfigured;
    if (!mounted) return;
    setState(() => _aiAvailable = available);
    if (available) _triggerAnalysis();
  }

  /// Facade có thể trả về `AiAnalysis.fromLocalDict()` (chỉ nghĩa từ điển,
  /// vẫn `success: true` và `isPartial: false`) khi engine local timeout 30s
  /// hoặc chưa sẵn sàng — đúng triệu chứng owner báo: "hình như nó chỉ đang
  /// dịch chứ không giải thích". Đoán theo ĐỘ SÂU của kết quả để BÁO TRUNG
  /// THỰC thay vì im lặng.
  bool _isDictionaryOnly(AiAnalysis a) {
    if (!a.success || a.isPartial) return false; // lỗi → xử lý riêng
    final d = a.wordDetail;
    final hasAiDepth = a.terms.isNotEmpty ||
        a.grammar != null ||
        a.contextExamples.isNotEmpty ||
        (d?.wordType?.isNotEmpty ?? false) ||
        (d?.cefrLevel?.isNotEmpty ?? false) ||
        (d?.etymologyHint?.isNotEmpty ?? false);
    return !hasAiDepth;
  }

  /// Gọi AI, TỰ GIỮ kết quả. Có timeout 90s (facade bên trong đã có 30s local
  /// + 45s remote) để không bao giờ treo mãi như bản cũ.
  Future<void> _triggerAnalysis() async {
    if (_aiWaiting) return;
    final facade = context.read<AiServiceFacade>();
    if (!mounted) return;
    setState(() {
      _aiWaiting = true;
      _aiError = null;
      _aiResult = null;
      _aiDictOnly = false;
      _waitedSec = 0;
    });
    _aiTicker?.cancel();
    _aiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_aiWaiting) return;
      setState(() => _waitedSec++);
    });
    try {
      final result = await facade
          .lookupWord(
            widget.word.text,
            sentenceContext: widget.sentenceContext,
            localDictEntry:
                _localMeaning == null ? null : {'meaning': _localMeaning!},
          )
          .timeout(const Duration(seconds: 90));
      if (!mounted) return;
      setState(() {
        _aiResult = result;
        _aiDictOnly = _isDictionaryOnly(result);
        _aiWaiting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString();
        _aiWaiting = false;
      });
    } finally {
      _aiTicker?.cancel();
    }
  }

  /// Bỏ chờ: giữ kết quả từ điển, tắt vòng xoay (future cũ tự bỏ qua).
  void _skipAiWait() {
    if (!mounted) return;
    setState(() => _aiWaiting = false);
    _aiTicker?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    // Xem chú thích ở phần field: KHÔNG watch/select `AiServiceFacade` ở đây.
    final analysis = _aiResult;

    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _buildHeader(analysis),
        _buildFrequencySlider(),
        _buildStateButtons(),
        TabBar(
          controller: _tabCtrl,
          onTap: (i) => setState(() => _aiTab = i),
          indicatorColor: const Color(0xFF9C27B0),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: context.uiText('NGHĨA')),
            Tab(text: context.uiText('GIẢI THÍCH')),
          ],
        ),
        Expanded(
          // YT-LR-002 (fix crash IN4-86): `IndexedStack` thay `TabBarView`.
          // TabBarView là PageView → cần viewport/Scrollable tự layout; con
          // chưa laid out bị hỏi kích thước sinh 'RenderBox was not laid out'.
          // IndexedStack gán CÙNG một约束 tĩnh cho mọi con ⇒ không có chuyển
          // trang, không có viewport, không crash.
          child: IndexedStack(
            index: _aiTab,
            children: [
              _buildMeaningTab(analysis),
              _buildExplanationTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader(AiAnalysis? analysis) {
    final detail = analysis?.wordDetail;
    final phonetic = detail?.phonetic ?? _ipa ?? analysis?.ipaFallback;
    final typeLabel = detail?.wordTypeLabel ?? _typeLabel(context, widget.word);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.word.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (phonetic != null && phonetic.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      phonetic,
                      style: const TextStyle(
                        color: Color(0xFFFFCA28),
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _chip(typeLabel, widget.word.typeColor.withValues(alpha: 0.22)),
          const SizedBox(width: 6),
          _chip('rank ${widget.word.langRank}', Colors.white12),
          if (detail?.cefrLevel != null) ...[
            const SizedBox(width: 6),
            _chip(detail!.cefrLevel!, const Color(0xFF4CAF50).withValues(alpha: 0.22)),
          ],
        ],
      ),
    );
  }

  /// Nhãn từ loại — literal nằm ngay tại `uiText()` call-site để gate i18n
  /// (`tool/generate_legacy_ui_fallbacks.py`) quét được và có English fallback.
  String _typeLabel(BuildContext context, LrWord word) {
    return switch (word.type) {
      'verb' => context.uiText('động từ'),
      'noun' => context.uiText('danh từ'),
      'proper' => context.uiText('tên riêng'),
      'adj' => context.uiText('tính từ'),
      'adv' => context.uiText('trạng từ'),
      'prep' => context.uiText('giới từ'),
      'conj' => context.uiText('liên từ'),
      _ => context.uiText('từ'),
    };
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  // ── Thanh trượt tần suất ──────────────────────────────────
  Widget _buildFrequencySlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            context.uiText('Ngưỡng tần suất'),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          Expanded(
            child: Slider(
              value: widget.settings.frequencyRankThreshold,
              min: YtLearningSettings.kMinRank,
              max: YtLearningSettings.kMaxRank,
              divisions: ((YtLearningSettings.kMaxRank -
                          YtLearningSettings.kMinRank) /
                      YtLearningSettings.kRankStep)
                  .round(),
              activeColor: const Color(0xFF9C27B0),
              onChanged: widget.onFrequencyChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              widget.settings.frequencyRankThreshold.round().toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3 nút Known / Learning / Ignored ──────────────────────
  Widget _buildStateButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _stateButton(
              icon: Icons.check,
              label: 'Đã biết',
              color: const Color(0xFF4CAF50),
              state: WordState.known,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _stateButton(
              icon: Icons.menu_book,
              label: 'Đang học',
              color: const Color(0xFF9C27B0),
              state: WordState.learning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _stateButton(
              icon: Icons.block,
              label: 'Bỏ qua',
              color: const Color(0xFF607D8B),
              state: WordState.ignored,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateButton({
    required IconData icon,
    required String label,
    required Color color,
    required WordState state,
  }) {
    final active = _state == state;
    return GestureDetector(
      onTap: () => _onStateTap(state),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                context.uiText(label),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : color,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab NGHĨA ─────────────────────────────────────────────
  Widget _buildMeaningTab(AiAnalysis? analysis) {
    final meaning = analysis?.wordDetail?.meaning ?? _localMeaning;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (meaning != null && meaning.isNotEmpty)
          Text(
            meaning,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
          )
        else
          Text(
            context.uiText('Chưa có nghĩa offline cho từ này.'),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        if (widget.sentenceContext != null &&
            widget.sentenceContext!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            context.uiText('Câu đang phát'),
            style: const TextStyle(
                color: Color(0xFF9C27B0), fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.sentenceContext!,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
        if (analysis?.wordDetail?.synonym != null) ...[
          const SizedBox(height: 14),
          Text(
            context.uiText('Từ đồng nghĩa'),
            style: const TextStyle(
                color: Color(0xFF9C27B0), fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            analysis!.wordDetail!.synonym!,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.uiText('Từ điển (${_mdxEntries.length})'),
          style: const TextStyle(
              color: Color(0xFF2196F3), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (_mdxLoading)
          Text(
            context.uiText('Đang tra từ điển…'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          )
        else if (_mdxEntries.isEmpty)
          Text(
            context.uiText('Không có mục nào trong từ điển.'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          )
        else
          ..._mdxEntries.take(4).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    e.plainDefinition,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
      ],
    );
  }

  // ── Tab GIẢI THÍCH & NGỮ PHÁP ─────────────────────────────
  //
  // YT-LR-002 (fix IN4-86): bản cũ chỉ hiện một `LinearProgressIndicator`
  // rồi im lặng — facade mất tới 30s (local) + 45s (remote) trước khi rớt về
  // nghĩa từ điển, nên người dùng tưởng "không có phản ứng". Giờ hiện RÕ 4
  // trạng thái: đang chờ / lỗi / chỉ có nghĩa từ điển / có phân tích AI.
  Widget _buildExplanationTab() {
    if (!_aiAvailable) return _buildNoModelTab();

    final a = _aiResult;
    final detail = a?.wordDetail;
    final grammar = a?.grammar;
    final examples = a?.contextExamples ?? const <String>[];
    final aiFailed = a != null && (a.isPartial || !a.success);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // 1) Đang chờ AI.
        if (_aiWaiting)
          _aiStatusCard(
            color: const Color(0xFF9C27B0),
            icon: Icons.auto_awesome,
            title: context.uiText('Đang nhờ AI phân tích…'),
            body: context.uiText(
              'Đã chờ ${_waitedSec}s. AI chạy trên máy nên có thể mất 30–90 giây.',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _skipAiWait,
                  child: Text(context.uiText('Bỏ chờ, xem nghĩa từ điển')),
                ),
              ],
            ),
          ),

        // 2) AI báo lỗi / không trả lời được.
        if (!_aiWaiting && (_aiError != null || aiFailed))
          _aiStatusCard(
            color: Colors.redAccent,
            icon: Icons.error_outline,
            title: context.uiText('AI chưa phân tích được.'),
            body: _aiError ?? a?.errorReason ?? context.uiText('Không rõ lý do.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                ),
                onPressed: _triggerAnalysis,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.uiText('Thử lại bằng AI')),
              ),
            ),
          ),

        // 3) Có kết quả nhưng thực chất CHỈ LÀ NGHĨA TỪ ĐIỂN (timeout 30s
        //    của engine local ⇒ facade rớt về `buildFromLocalDict`).
        if (!_aiWaiting && !aiFailed && _aiError == null && _aiDictOnly)
          _aiStatusCard(
            color: Colors.amber,
            icon: Icons.hourglass_disabled,
            title: context.uiText('AI chưa trả lời kịp (thường do quá 30 giây).'),
            body: context.uiText(
              'Phần dưới mới chỉ là NGHĨA TỪ ĐIỂN offline, chưa phải giải thích theo ngữ cảnh.',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                ),
                onPressed: _triggerAnalysis,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.uiText('Thử lại bằng AI')),
              ),
            ),
          ),

        // 4) Nội dung — luôn hiện phần có được, ghi rõ nguồn.
        if (a?.summary.isNotEmpty == true) ...[
          if (!_aiDictOnly)
            Text(
              context.uiText('Giải thích theo ngữ cảnh'),
              style: const TextStyle(
                  color: Color(0xFF9C27B0),
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          Text(
            a!.summary,
            style:
                const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
        ],
        if (detail?.memoryHook != null) ...[
          _block(context.uiText('Mẹo nhớ'), detail!.memoryHook!),
        ],
        if (grammar != null) ...[
          _block(
            context.uiText('Ngữ pháp'),
            '${context.uiText('Cấu trúc')}: ${grammar.pattern}\n'
                '${context.uiText('Chủ ngữ')}: ${grammar.subject}\n'
                '${context.uiText('Động từ')}: ${grammar.verb}\n'
                '${context.uiText('Tân ngữ')}: ${grammar.object}',
          ),
          _block(context.uiText('Giải thích'), grammar.explanationVi),
        ],
        if (examples.isNotEmpty) ...[
          _block(
            context.uiText('Ví dụ trong ngữ cảnh'),
            examples.map((e) => '• $e').join('\n'),
          ),
        ],
        if (a?.visualPrompt != null)
          _block(context.uiText('Hình ảnh gợi nhớ'), a!.visualPrompt!),
        if (a != null && a.paoSuggestions.isNotEmpty)
          _block(
            context.uiText('Câu chuyện ghi nhớ'),
            a.paoSuggestions.map((e) => '• $e').join('\n'),
          ),
        // Chưa có gì (chưa gọi / vừa bỏ chờ) → nút gọi thủ công.
        if (!_aiWaiting && a == null && _aiError == null) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
            ),
            onPressed: _triggerAnalysis,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(context.uiText('Phân tích bằng AI')),
          ),
          const SizedBox(height: 12),
        ],
        if (_localMeaning != null) ...[
          _block(context.uiText('Nghĩa từ điển offline'), _localMeaning!),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  /// Ô trạng thái AI (đang chờ / lỗi / chỉ có từ điển).
  Widget _aiStatusCard({
    required Color color,
    required IconData icon,
    required String title,
    required String body,
    Widget? child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          if (child != null) child,
        ],
      ),
    );
  }

  /// Chưa có model AI và chưa cấu hình API ⇒ nói thẳng, không để chờ.
  Widget _buildNoModelTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Text(
            context.uiText(
              'Chưa cài model AI. Cài để có giải thích ngữ pháp và ví dụ.',
            ),
            style: const TextStyle(color: Colors.amber, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
          ),
          onPressed: () async {
            await context.read<AiServiceFacade>().importModelFromUser();
            if (!mounted) return;
            _prepareAi();
          },
          icon: const Icon(Icons.download, size: 16),
          label: Text(context.uiText('Cài AI')),
        ),
        if (_localMeaning != null) ...[
          const SizedBox(height: 16),
          _block(context.uiText('Nghĩa từ điển offline'), _localMeaning!),
        ],
      ],
    );
  }

  Widget _block(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9C27B0),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }
}
