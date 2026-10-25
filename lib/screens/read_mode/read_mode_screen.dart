// lib/screens/read_mode/read_mode_screen.dart
// Thêm tracking tiến độ đọc vào code hiện tại
import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/core/platform/safe_haptics.dart';

import '../../features/grammar/grammar.dart';
import '../../features/translation/translation_toolbar.dart';
import '../../models/color_mode.dart';
import '../../models/ipa_display_mode.dart';
import '../../models/learning_activity.dart';
import '../../models/read_content_source.dart';
import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/learning_activity_service.dart';
import '../../services/storage_service.dart';
import 'controllers/read_mode_controller.dart';
import 'models/recent_file.dart';
import 'services/read_line_hint_service.dart';
import 'services/recent_files_service.dart';
import 'services/word_range_selection.dart';
import 'widgets/read_line_hint.dart';
import 'widgets/collapsible_bottom_controls.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/ipa_legend_strip.dart';
import 'widgets/read_bottom_bar.dart';
import 'widgets/read_source_picker.dart';
import 'widgets/read_text_action_hooks.dart';
import 'widgets/read_top_bar.dart';
import 'widgets/smart_playback_bar.dart';
import 'widgets/text_line_widget.dart';
import 'widgets/word_mini_pop.dart';

class ReadModeScreen extends StatefulWidget {
  final RecentFile? currentFile;

  /// Nguồn nội dung được chọn sẵn cho source picker (I4U-READ-UX-001).
  ///
  /// Mặc định [ReadContentSource.document] để giữ hành vi hiện có: màn hình
  /// vẫn hiển thị tài liệu đang mở (`currentFile`/`TextProvider`) như trước
  /// khi chưa có tham số này.
  final ReadContentSource initialSource;

  /// Gọi mỗi khi người dùng đổi nguồn trong source picker. Optional — nơi
  /// gọi có thể bỏ qua nếu chưa cần theo dõi lựa chọn nguồn.
  final ValueChanged<ReadContentSource>? onSourceChanged;

  /// Hợp đồng điều hướng tới `TextLibraryDrawer` / `WebReaderScreen` /
  /// `TipitakaLibraryScreen` cho integration agent nối dây. Để trống an
  /// toàn: source picker vẫn đổi trạng thái hiển thị, chỉ là chưa mở được
  /// màn hình nguồn thật.
  final ReadSourceCallbacks sourceCallbacks;

  /// Điểm móc cho 4 hành động theo ngữ cảnh khi có text được chọn: Dịch /
  /// Ngữ pháp / Phát âm / Từ điển. Để trống an toàn: không hành động nào
  /// được nối thì thanh hành động không hiển thị gì (không đổi UI hiện có).
  final ReadTextActionCallbacks textActionCallbacks;

  /// Shell mới có thể đặt source picker trong header chung; default vẫn true
  /// để caller cũ giữ nguyên hành vi.
  final bool showSourcePicker;

  const ReadModeScreen({
    super.key,
    this.currentFile,
    this.initialSource = ReadContentSource.document,
    this.onSourceChanged,
    this.sourceCallbacks = const ReadSourceCallbacks(),
    this.textActionCallbacks = const ReadTextActionCallbacks(),
    this.showSourcePicker = true,
  });

  @override
  State<ReadModeScreen> createState() => _ReadModeScreenState();
}

class _ReadModeScreenState extends State<ReadModeScreen> {
  final ScrollController _scrollController = ScrollController();
  late ReadModeController _controller;
  bool _controllerInitialized = false;
  int _lastHandledFocusCueVersion = 0;
  VoidCallback? _playerListener;
  Duration _lastPos = Duration.zero;
  bool _showWordlistPanel = false;

  // I4U-READ-UX-001 — nguồn nội dung đang chọn trong source picker riêng
  // của tab Đọc. Tách biệt khỏi Mode (Đọc/Viết, do main_shell sở hữu) và
  // khỏi Tool (Dịch/Ngữ pháp/Phát âm/Từ điển, xem _textActionCallbacks).
  late ReadContentSource _source;

  PlayerProvider? _playerProviderRef;

  final _recentService = RecentFilesService();
  int _lastSavedLine = 0;

  // HOME-STREAK-001 — nhịp đếm phút đọc thật (1 phút/lần, có khoá chống trùng).
  Timer? _readingHeartbeat;
  String? _readingSessionFileId;

  // Smart-hide all reader chrome together; start compact and keep a reveal affordance.
  bool _readerChromeVisible = false;

  /// IN4-30 (READ-FOCUS-002): vị trí phần TIÊU ĐỀ khi ở chế độ Focus —
  /// 'hidden' (mặc định) | 'top' | 'bottom'.
  String _focusTitlePosition = StorageService.readFocusTitleHidden;
  double _lastScrollOffset = 0;

  // I4U18-READ-IPA-001 (F1.2) — chống lên lịch gợi ý nhiều lần trong khi
  // đang chờ đọc cờ prefs (build có thể chạy lại vài lần liên tiếp).
  bool _lineHintScheduled = false;

  @override
  void initState() {
    super.initState();
    _source = widget.initialSource;
    // IN4-30: đọc lựa chọn "chỉ giữ phần tiêu đề" khi ở chế độ Focus.
    _focusTitlePosition = StorageService().getReadFocusTitlePosition();
  }

  void _handleSourceChanged(ReadContentSource source) {
    if (_source == source) return;
    setState(() => _source = source);
    widget.onSourceChanged?.call(source);
  }

  /// AUDIT-2026-10-20 (mục 1): controller đổi ⇒ màn rebuild + đọc lại cấu
  /// hình "vị trí phần TIÊU ĐỀ khi ở chế độ Focus" (Ẩn / Trên / Dưới) từ
  /// storage, để lựa chọn trong Cài đặt có hiệu lực ngay.
  void _onControllerChanged() {
    if (!mounted) return;
    final next = StorageService().getReadFocusTitlePosition();
    if (next == _focusTitlePosition) {
      setState(() {});
      return;
    }
    setState(() => _focusTitlePosition = next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      final tp = context.read<TextProvider>();
      final pp = context.read<PlayerProvider>();

      _playerProviderRef = pp;

      _controller = ReadModeController(textProvider: tp, playerProvider: pp);
      // AUDIT-2026-10-20 (mục 1): màn Đọc PHẢI rebuild khi controller đổi.
      // Trước đây screen chỉ watch TextProvider ⇒ `toggleFocusMode()` gọi
      // notifyListeners() nhưng KHÔNG ai nghe ⇒ bấm nút Focus (và chọn
      // Ẩn/Trên/Dưới trong Cài đặt) không hề thay đổi gì trên màn.
      _controller.addListener(_onControllerChanged);
      _playerListener = () {
        if (!mounted) return;
        final pos = pp.state.position;
        if (pos == _lastPos) return;
        _lastPos = pos;
        final targetLine = _controller.checkAudioSync(pos);
        if (targetLine >= 0) {
          _controller.scrollToLine(_scrollController, targetLine);
        }
      };
      pp.addListener(_playerListener!);
      _controllerInitialized = true;
    }

    _startReadingSession();
  }

  /// Bắt đầu đếm phút đọc cho tài liệu đang mở (HOME-STREAK-001).
  ///
  /// Gọi trong `didChangeDependencies` — an toàn khi rebuild vì có chốt theo
  /// id tài liệu; event được ghi ngoài build().
  void _startReadingSession() {
    final file = widget.currentFile;
    if (file == null || _readingSessionFileId == file.id) return;
    _readingSessionFileId = file.id;
    _readingHeartbeat?.cancel();
    _readingHeartbeat = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _recordReadingMinute(),
    );
  }

  void _recordReadingMinute() {
    final file = widget.currentFile;
    if (file == null) return;

    // Khoá theo phút đồng hồ: dựng lại widget / mở lại app trong cùng một phút
    // không đếm trùng, nhưng đọc tiếp phút sau vẫn cộng thêm.
    final now = DateTime.now();
    final minuteBucket = '${now.year}-${now.month}-${now.day}'
        'T${now.hour}:${now.minute}';
    unawaited(LearningActivityService.instance.record(
      LearningActivityKind.readingMinutes,
      sourceKey: '${file.id}|$minuteBucket',
    ));
  }

  /// I4U18-READ-IPA-001 (F1.2) — nhắc "chạm dòng/chạm từ" khi mở nguồn chữ
  /// theo dòng (Word/DOCX, md, txt…).
  ///
  /// Gọi từ `build` nhưng CHỈ lên lịch sau frame: showSnackBar trong build là
  /// lỗi "setState during build". Khoá theo documentId + cờ "đừng nhắc lại"
  /// nằm trong ReadLineHintService (logic thuần ở `shouldAutoShowLineHint`).
  void _maybeShowLineHint(TextProvider tp) {
    if (_lineHintScheduled) return;
    final documentId = tp.currentDocument?.id;
    final path = tp.currentTextPath;
    final service = ReadLineHintService.instance;
    if (!shouldAutoShowLineHint(
      path: path,
      documentId: documentId,
      dismissedForever: service.dismissedForever,
      lastShownDocumentId: service.lastShownDocumentId,
      hasLines: tp.lines.isNotEmpty,
    )) {
      return;
    }
    _lineHintScheduled = true;
    unawaited(() async {
      await service.ensureLoaded();
      if (!mounted) return;
      _lineHintScheduled = false;
      if (!shouldAutoShowLineHint(
        path: path,
        documentId: documentId,
        dismissedForever: service.dismissedForever,
        lastShownDocumentId: service.lastShownDocumentId,
        hasLines: tp.lines.isNotEmpty,
      )) {
        return;
      }
      service.markShown(documentId!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ReadLineHint.showSnackBar(context, wordSource: isWordSource(path));
      });
    }());
  }

  void _onScrollEnd(TextProvider tp) {
    if (widget.currentFile == null) return;
    if (tp.lines.isEmpty) return;

    final offset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final approxLine =
        maxOffset > 0 ? ((offset / maxOffset) * tp.lines.length).round() : 0;

    if ((approxLine - _lastSavedLine).abs() >= 3) {
      _lastSavedLine = approxLine;
      _recentService.updateProgress(
        widget.currentFile!.id,
        currentLine: approxLine,
        totalLines: tp.lines.length,
      );
    }
  }

  @override
  void deactivate() {
    _controller.removeFloatingMenu();
    super.deactivate();
  }

  @override
  void dispose() {
    // READ-POP-003: pop tra từ nhanh là OVERLAY (không tự đóng cùng màn hình)
    // ⇒ phải dọn tay, nếu không nó sẽ nổi trên màn khác sau khi rời tab Đọc.
    WordMiniPop.dismiss();
    if (_playerListener != null && _playerProviderRef != null) {
      _playerProviderRef!.removeListener(_playerListener!);
    }
    _readingHeartbeat?.cancel();
    _readingHeartbeat = null;
    _scrollController.dispose();
    // AUDIT-2026-10-20 (mục 1): bỏ listener trước khi dispose controller.
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<TextProvider>(
        builder: (context, textProvider, _) {
          if (textProvider.focusCueVersion != _lastHandledFocusCueVersion &&
              textProvider.focusCueLineIndex != null) {
            _lastHandledFocusCueVersion = textProvider.focusCueVersion;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients) return;
              _controller.scrollToLine(
                _scrollController,
                textProvider.focusCueLineIndex!,
                animated: true,
              );
            });
          }

          if (!textProvider.hasLyrics) {
            return const ReadEmptyState();
          }
          _maybeShowLineHint(textProvider);
          final showGrammarLegend =
              textProvider.colorMode == ColorMode.wordType &&
                  textProvider.grammarSettings.enabled &&
                  textProvider.grammarSettings.showLegend;

          final hasTranslation = textProvider.translatedLineCount > 0;
          final isFocusMode = _controller.isFocusMode;
          final isSmallScreen = MediaQuery.of(context).size.height < 700 ||
              MediaQuery.of(context).size.width < 380;

          // READ-IPA-006: panel màu IPA — dải thông tin tương tác ngay dưới
          // TopBar, ẩn được (yêu cầu mục 2). Chỉ có nghĩa khi có IPA + tô màu.
          final showIpaLegend = textProvider.ipaLegendVisible &&
              textProvider.ipaColorByType &&
              textProvider.ipaDisplayMode != IpaDisplayMode.hidden;

          // READ-ACT-001 (audit 1.a — phương án 1): KHÔNG dựng lại
          // `ReadTextActionBar` ở đây nữa. Bốn hành động Dịch/Ngữ pháp/
          // Phát âm/Từ điển chỉ còn MỘT chỗ duy nhất: hàng nút có nhãn ở
          // header workspace (main_shell). Thanh nổi cũ lặp đúng 4 hành
          // động đó nên vừa thừa vừa che mất chữ đang đọc.
          // Widget `ReadTextActionBar` vẫn giữ nguyên (còn test + còn dùng
          // được cho màn hình khác), chỉ bỏ chỗ dựng trùng này.

          return Stack(
            children: [
              Column(
                children: [
                  if (!isFocusMode && _readerChromeVisible) const ReadTopBar(),
                  // IN4-30 (READ-FOCUS-002): ở chế độ Focus, người dùng có
                  // thể chọn "chỉ giữ phần tiêu đề" — TRÊN hoặc DƯỚI vùng
                  // đọc (mặc định: ẩn hẳn, hành vi cũ).
                  if (isFocusMode && _focusTitlePosition == 'top')
                    ReadFocusTitleBar(
                      tp: textProvider,
                      controller: _controller,
                    ),
                  // I4U-READ-UX-001 — Source picker riêng (Tài liệu / Web /
                  // Tam tạng), tách biệt khỏi Mode (Đọc/Viết) và Tool.
                  if (!isFocusMode && _readerChromeVisible && widget.showSourcePicker)
                    ReadSourcePicker(
                      selectedSource: _source,
                      onSourceChanged: _handleSourceChanged,
                      callbacks: widget.sourceCallbacks,
                    ),
                  if (!isFocusMode && _readerChromeVisible && showIpaLegend)
                    IpaLegendStrip(tp: textProvider),
                  if (!isFocusMode && _readerChromeVisible && showGrammarLegend)
                    _GrammarLegendStrip(textProvider: textProvider),
                  if (!isFocusMode &&
                      _readerChromeVisible &&
                      (textProvider.showTranslation || hasTranslation))
                    const TranslationToolbar(),
                  Expanded(
                    child: _showWordlistPanel
                        ? _buildSplitView(textProvider)
                        : GestureDetector(
                            onTap: () {
                              if (isFocusMode) {
                                _controller.setFocusMode(false);
                                setState(() => _readerChromeVisible = true);
                              } else {
                                // READ-SELECT-002: đang chọn nhiều từ ở ô chữ
                                // ⇒ chạm ra vùng trống cũng là BỎ CHỌN.
                                if (WordSelectionState.isActive) {
                                  textProvider.clearSelection();
                                  _controller.removeFloatingMenu();
                                  return;
                                }
                                _controller.removeFloatingMenu();
                                // Giống PDF Reader: chạm nền bật/tắt chrome;
                                // khi ẩn, FAB nhỏ ở góc dưới luôn là lối gọi lại.
                                setState(() => _readerChromeVisible =
                                    !_readerChromeVisible);
                              }
                            },
                            onDoubleTap: () {
                              // AUDIT-2026-10-20 (mục 1): đọc TRẠNG THÁI MỚI
                              // sau khi toggle (trước đây dùng giá trị cũ
                              // ⇒ thanh dưới bị hiện/ẩn ngược).
                              _controller.toggleFocusMode();
                              setState(
                                () => _readerChromeVisible =
                                    !_controller.isFocusMode,
                              );
                            },
                            child: _buildTextList(textProvider, isFocusMode),
                          ),
                  ),
                  // Bottom controls share the smart-chrome visibility state.
                  // Hidden chrome collapses completely so the reading area gets
                  // the space back; focus mode always keeps this section closed.
                  CollapsibleBottomControls(
                    visible: _readerChromeVisible,
                    collapsed: isFocusMode,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SmartPlaybackBar(),
                        ReadBottomBar(
                          showWordlistPanel: _showWordlistPanel,
                          onToggleWordlist: () {
                            setState(() =>
                                _showWordlistPanel = !_showWordlistPanel);
                            SafeHaptics.lightImpact();
                          },
                        ),
                      ],
                    ),
                  ),
                  // IN4-30: thanh tiêu đề tối giản đặt DƯỚI vùng đọc.
                  if (isFocusMode && _focusTitlePosition == 'bottom')
                    ReadFocusTitleBar(
                      tp: textProvider,
                      controller: _controller,
                    ),
                  // IN4-31: cụm đáy đã gập hẳn khi ẩn (chiều cao 0) ⇒
                  // không cần spacer 8px nữa (trước đó để chừa chỗ cho
                  // nền đen vẫn còn).
                ],
              ),
              // Focus mode exit FAB
              if (isFocusMode)
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      _controller.setFocusMode(false);
                      setState(() => _readerChromeVisible = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2235),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen_exit,
                              size: 16, color: Color(0xFF6C63FF)),
                          const SizedBox(width: 6),
                          Text(
                            context.uiText('Thoát Focus'),
                            style: TextStyle(
                                color: const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Smart chrome is collapsed by default; this compact affordance
              // is the persistent, no-guesswork way to bring the controls back.
              if (!_readerChromeVisible && !isFocusMode)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  right: 12,
                  child: Tooltip(
                    message: context.uiText('Mở công cụ đọc'),
                    child: Material(
                      color: const Color(0xFF1A2235),
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () =>
                            setState(() => _readerChromeVisible = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                size: 17,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.uiText('Công cụ đọc'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Focus entry pill for small screens
              if (isSmallScreen && !isFocusMode && _readerChromeVisible)
                Positioned(
                  bottom: 98,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      _controller.setFocusMode(true);
                      setState(() => _readerChromeVisible = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen,
                              size: 14, color: Color(0xFF6C63FF)),
                          SizedBox(width: 4),
                          Text(
                            'Focus',
                            style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSplitView(TextProvider tp) {
    final title = tp.currentDocument?.title ?? 'Text Studio';
    return Row(
      children: [
        Expanded(
          flex: 65,
          child: GestureDetector(
            onTap: () => _controller.removeFloatingMenu(),
            child: _buildTextList(tp, false),
          ),
        ),
        Expanded(
          flex: 35,
          child: _StoryWordlistPanel(storyTitle: title),
        ),
      ],
    );
  }

  Widget _buildTextList(TextProvider textProvider, bool isFocusMode) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _controller.setScrolling(true);
          _lastScrollOffset = notification.metrics.pixels;
        } else if (notification is ScrollUpdateNotification) {
          // Smart hide: scroll down hides reader chrome, scroll up restores it.
          if (!isFocusMode) {
            final diff = notification.metrics.pixels - _lastScrollOffset;
            if (diff > 12 && _readerChromeVisible) {
              setState(() => _readerChromeVisible = false);
            } else if (diff < -12 && !_readerChromeVisible) {
              setState(() => _readerChromeVisible = true);
            }
            _lastScrollOffset = notification.metrics.pixels;
          }
        } else if (notification is ScrollEndNotification) {
          _controller.setScrolling(false);
          _onScrollEnd(textProvider);
        }
        return false;
      },
      child: Container(
        color: const Color(0xFF0D1520),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: textProvider.lines.length,
          cacheExtent: 300,
          itemBuilder: (context, index) {
            return TextLineWidget(
              index: index,
              scrollController: _scrollController,
            );
          },
        ),
      ),
    );
  }
}

class _GrammarLegendStrip extends StatelessWidget {
  final TextProvider textProvider;

  const _GrammarLegendStrip({required this.textProvider});

  @override
  Widget build(BuildContext context) {
    final settings = textProvider.grammarSettings;
    final palette = textProvider.activeGrammarPalette;
    final visibleCategories = settings.visibleCategories.toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));
    final hiddenCount =
        GrammarCategory.values.length - settings.visibleCategories.length;
    final previousPreset = textProvider.availableGrammarPresets.firstWhere(
      (preset) => preset.id == settings.lastNonCustomPresetId,
      orElse: () => GrammarHighlightPresets.byId(settings.lastNonCustomPresetId),
    );
    final activePreset = textProvider.activeGrammarPreset;
    final activePresetName = activePreset.isBuiltIn
        ? context.uiText(activePreset.name)
        : activePreset.name;
    final previousPresetName = previousPreset.isBuiltIn
        ? context.uiText(previousPreset.name)
        : previousPreset.name;
    final grammarTitle = settings.isCustomPreset
        ? context.uiText('Grammar Highlight · Tùy chỉnh')
        : settings.legendCollapsed
            ? activePresetName
            : 'Grammar Highlight · $activePresetName';

    void handleMenuAction(String value) {
      if (value == 'restore') {
        textProvider.restorePreviousGrammarPreset();
      } else if (value == 'showAll') {
        textProvider.showAllGrammarCategories();
      }
    }

    Widget overflowMenu() {
      if (!settings.isCustomPreset && hiddenCount <= 0) {
        return const SizedBox.shrink();
      }
      return PopupMenuButton<String>(
        tooltip: context.uiText('Cài đặt từ loại chuyên sâu'),
        color: const Color(0xFF151B26),
        padding: EdgeInsets.zero,
        child: const SizedBox(
          width: 30,
          height: 30,
          child: Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 19),
        ),
        onSelected: handleMenuAction,
        itemBuilder: (context) => [
          if (settings.isCustomPreset)
            PopupMenuItem<String>(
              value: 'restore',
              child: Text(context.uiText('Khôi phục $previousPresetName')),
            ),
          if (hiddenCount > 0)
            PopupMenuItem<String>(
              value: 'showAll',
              child: Text(context.uiText('Bật lại tất cả')),
            ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_motion,
                size: 14,
                color: Color(0xFF8E83FF),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  grammarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (settings.legendCollapsed && visibleCategories.isNotEmpty) ...[
                const SizedBox(width: 4),
                for (final category in visibleCategories.take(6))
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: palette.styleFor(category).color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
              overflowMenu(),
              IconButton(
                tooltip: context.uiText(
                  settings.legendCollapsed ? 'Mở rộng' : 'Thu gọn',
                ),
                onPressed: () => textProvider.setGrammarLegendCollapsed(
                  !settings.legendCollapsed,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: Icon(
                  settings.legendCollapsed
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  size: 20,
                  color: const Color(0xFFB8B5FF),
                ),
              ),
            ],
          ),
          if (!settings.legendCollapsed) ...[
            const SizedBox(height: 4),
            GrammarLegendBar(
              settings: settings,
              palette: palette,
              toolbarStyle: true,
              compact: false,
              horizontalScroll: false,
              showHandle: false,
              onToggleCategory: textProvider.toggleGrammarCategory,
            ),
          ],
        ],
      ),
    );
  }
}

class _StoryWordlistPanel extends StatelessWidget {
  final String storyTitle;

  const _StoryWordlistPanel({required this.storyTitle});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (_, provider, __) {
        final words = provider.allWords
            .where((w) => w.contexts.any(
                  (c) => c.sourceName == storyTitle,
                ))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF080B1A),
            border: Border(
              left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                color: const Color(0xFF0D1520),
                child: Row(
                  children: [
                    const Icon(Icons.library_books,
                        size: 13, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.uiText('Từ đã lưu (${words.length})'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: words.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border,
                                size: 28, color: Colors.grey[800]),
                            const SizedBox(height: 6),
                            Text(
                              'Chưa lưu từ nào\ntừ story này',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 10),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: words.length,
                        itemBuilder: (_, i) {
                          final w = words[i];
                          return Container(
                            margin: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.025),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: w.vocabType.color
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        w.vocabType.badge,
                                        style: TextStyle(
                                          color: w.vocabType.color,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        w.word,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => provider.removeWord(w.id),
                                      child: Icon(Icons.close,
                                          size: 11, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                if (w.meaning.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    w.meaning,
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(1),
                                  child: LinearProgressIndicator(
                                    value: w.mastery,
                                    minHeight: 2,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.06),
                                    valueColor: AlwaysStoppedAnimation(
                                      w.zone.color.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
