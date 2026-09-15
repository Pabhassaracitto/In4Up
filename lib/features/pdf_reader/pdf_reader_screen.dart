// lid/features/pdf_reader/pdf_reader_screen.dart
// Màn hình đọc PDF:
//  - Render PDF gốc (pdfrx) + selection của viewer nối thẳng vào hành động học
//  - Overlay highlight theo CEFR / WordType / Difficulty + recall marker
//  - TTS đọc theo CÂU, tô sáng câu đang đọc, tự lật trang
//  - Chạm một từ → sheet tra/lưu; giữ (long-press) → chọn từ rồi hành động trên
//    vùng chọn (Ghi chú / WordList / TTS / Text Studio / Vườn Nhớ)
//  - Text Mode: extract toàn bộ text → load vào Read Mode cũ

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:provider/provider.dart';

import '../../features/grammar/grammar.dart';
import '../../features/writing/models/writing_source_request.dart';
import '../../models/color_mode.dart';
import '../../models/vocab_context.dart';
import '../../models/word_entry.dart';
import '../../providers/text_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/selection_save_sheet.dart';
import '../../widgets/unified_knowledge_sheet.dart';
import 'models/pdf_annotation.dart';
import 'pdf_reader_controller.dart';
import 'services/pdf_file_identity.dart';
import 'services/pdf_geometry.dart';
import 'services/pdf_outline_index.dart';
import 'services/pdf_reader_theme.dart';
import 'services/pdf_search_query.dart';
import 'services/pdf_shortcuts.dart';
import 'services/pdf_word_hit_test.dart';
import 'widgets/pdf_annotation_layer.dart';
import 'widgets/pdf_annotation_sheet.dart';
import 'widgets/pdf_export_row.dart';
import 'widgets/pdf_page_veils.dart';
import 'widgets/pdf_reader_theme_sheet.dart';
import 'widgets/pdf_search_panel.dart';
import 'widgets/pdf_toc_panel.dart';
import 'widgets/pdf_toolbar.dart';
import 'widgets/pdf_tts_bar.dart';
import 'widgets/pdf_word_overlay.dart';
import 'widgets/pdf_word_tap_sheet.dart';
import 'widgets/pdf_wordlist_panel.dart';

class PdfReaderScreen extends StatefulWidget {
  final String pdfPath;
  final int? initialPageIndex;
  final String? initialFocusWord;
  final VocabContext? initialFocusContext;

  /// Biến PDF Reader thành màn hình chọn nguồn cho Writing Studio.
  final bool writingMode;

  const PdfReaderScreen({
    super.key,
    required this.pdfPath,
    this.initialPageIndex,
    this.initialFocusWord,
    this.initialFocusContext,
    this.writingMode = false,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late final PdfReaderController _controller;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _showWordlistPanel = false;
  bool _chromeVisible = true;

  // ── Wave 1: mục lục + tìm kiếm trong file ─────────────────
  List<PdfOutlineEntry> _outlineEntries = const [];
  bool _outlineLoading = true;
  bool _hasOutline = true;
  PdfTextSearcher? _searcher;
  // Wave 1.5: chủ đề đọc = nền quanh trang + lớp phủ màu trang + độ sáng. Đây là
  // cài đặt TOÀN CỤC của tính năng (không theo từng file), mặc định giữ nguyên
  // hình dạng cũ của app ⇒ nâng cấp không đổi giao diện người dùng đang quen.
  PdfReaderThemeState _readerTheme = PdfReaderThemeState.defaults;
  bool _searchOpen = false;
  String _searchQuery = '';
  bool _searchIgnoreTones = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfReaderController(pdfPath: widget.pdfPath);
    _controller.addListener(_onControllerUpdate);

    // Controller không import pdfrx → nó lái viewer qua cầu nối này
    // (lật trang khi TTS đọc sang trang khác, cua tới vùng đã lưu).
    _controller.viewerCommands
      ..goToPage = _goToPage
      ..revealRect = _revealRect;

    // Đọc trước khi trang kịp render: màu sai trong 1 khung hình là nhấp nháy.
    unawaited(_loadReaderThemeState());
  }

  void _goToPage(int pageIndex) {
    if (!_pdfViewerController.isReady) return;
    final total = _pdfViewerController.pageCount;
    if (total == 0) return;
    unawaited(
      _pdfViewerController.goToPage(
        pageNumber: (pageIndex + 1).clamp(1, total),
        duration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _revealRect(int pageIndex, Rect rect) {
    if (!_pdfViewerController.isReady || !isPaintablePdfRect(rect)) return;
    final total = _pdfViewerController.pageCount;
    // `PdfRect` của engine assert left <= right && top >= bottom (quy ước PDF
    // y-up). Dữ liệu lưu cũ có thể bị đảo chiều y → đưa về đúng thứ tự trước
    // khi gọi, nếu không là một vụ ném exception khi mở lại ghi chú.
    final yTop = rect.top > rect.bottom ? rect.top : rect.bottom;
    final yBottom = rect.top > rect.bottom ? rect.bottom : rect.top;
    final xLeft = rect.left < rect.right ? rect.left : rect.right;
    final xRight = rect.left < rect.right ? rect.right : rect.left;
    unawaited(
      _pdfViewerController.goToRectInsidePage(
        pageNumber: (pageIndex + 1).clamp(1, total),
        rect: PdfRect(xLeft, yTop, xRight, yBottom),
      ),
    );
  }

  // ── Chrome (toolbar + thanh TTS) ──────────────────────────
  //
  // Trước đây chrome tự ẩn sau 3 giây bằng timer, kể cả lúc đang gõ ghi chú
  // hay đang nghe TTS. Reader thật ẩn/hiện theo Ý ĐỊNH của người dùng: một chạm
  // vào nền tắt, chạm tiếp mở — nên ở đây bỏ hẳn timer.
  bool get _showTopChrome =>
      _controller.viewMode != PdfViewMode.pdfView ||
      _chromeVisible ||
      // Ô tìm kiếm là nhập liệu: ẩn nó theo timer/theo chạm nền là mất nội dung
      // người dùng vừa gõ ⇒ đang tìm thì chrome phải ở lại.
      _searchOpen ||
      _controller.hasSelection;

  bool get _showBottomChrome => _showTopChrome;

  void _onControllerUpdate() {
    if (!mounted) return;
    if (_controller.viewerSelectionShouldBeCleared) {
      _controller.viewerSelectionShouldBeCleared = false;
      _clearViewerSelection();
    }
    final mustShowChrome = _controller.hasSelection ||
        _controller.viewMode == PdfViewMode.textMode;
    if (mustShowChrome && !_chromeVisible) _chromeVisible = true;
    setState(() {});
  }

  void _showChrome() {
    if (!mounted) return;
    if (_chromeVisible) return;
    setState(() => _chromeVisible = true);
  }

  void _clearViewerSelection() {
    if (!_pdfViewerController.isReady) return;
    try {
      unawaited(_pdfViewerController.textSelectionDelegate.clearTextSelection());
    } catch (_) {
      // viewer chưa attach xong — selection vốn đã không còn
    }
  }

  void _toggleChromeVisibility() {
    if (_controller.viewMode != PdfViewMode.pdfView) return;
    if (_controller.hasSelection) {
      _controller.clearSelection();
      return;
    }
    setState(() => _chromeVisible = !_chromeVisible);
  }

  @override
  void dispose() {
    _searcher?.dispose();
    _searcher = null;
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  // ── Mục lục / tìm kiếm / nhảy trang ───────────────────────
  int get _activeOutlineIndex =>
      findActiveOutlineIndex(_outlineEntries, _controller.currentPage);

  /// `PdfTextSearcher` đọc `controller.document` ngay trong constructor ⇒ chỉ
  /// được tạo ở `onViewerReady` (viewer đã chắc chắn có document), không phải
  /// `onDocumentChanged`.
  Future<void> _onViewerReady(
    PdfDocument document,
    PdfViewerController controller,
  ) async {
    try {
      _searcher ??= PdfTextSearcher(controller);
    } catch (_) {
      _searcher = null;
    }
    await _loadOutline(document);
  }

  Future<void> _loadOutline(PdfDocument document) async {
    try {
      final nodes = await document.loadOutline();
      if (!mounted) return;
      setState(() {
        _outlineEntries = flattenPdfOutline(nodes);
        _hasOutline = nodes.isNotEmpty;
        _outlineLoading = false;
      });
    } catch (_) {
      // Outline hỏng/missing là chuyện bình thường với file scan hoặc file ghi
      // cẩu thả: coi như không có mục lục, tuyệt đối không làm trắng màn đọc.
      if (!mounted) return;
      setState(() {
        _outlineLoading = false;
        _hasOutline = false;
        _outlineEntries = const [];
      });
    }
  }

  /// Document cho lưới thumbnail. `controller.document` là getter `!` ⇒ chỉ an
  /// toàn khi `isReady`; fallback về bản mà reader controller đang giữ.
  PdfDocument? get _safeDocument {
    try {
      if (_pdfViewerController.isReady) return _pdfViewerController.document;
    } catch (_) {
      // fallthrough
    }
    return _controller.document;
  }

  void _openTocNavigator() {
    _showChrome();
    unawaited(
      showPdfReadingNavigator(
        context: context,
        entries: _outlineEntries,
        activeIndex: _activeOutlineIndex,
        isLoadingOutline: _outlineLoading,
        hasOutline: _hasOutline,
        currentPage: _controller.currentPage,
        totalPages: _controller.totalPages,
        document: _safeDocument,
        onSelectEntry: _goToOutlineEntry,
        onSelectPage: _goToPageIndex,
      ),
    );
  }

  void _goToOutlineEntry(PdfOutlineEntry entry) {
    final dest = entry.dest;
    if (dest == null || !_pdfViewerController.isReady) return;
    unawaited(_pdfViewerController.goToDest(dest));
    final page = entry.pageNumber;
    // Đồng bộ trang cho controller NGAY, không chờ viewer báo lại: highlight
    // chương đang đọc trong panel phải đúng ngay khi panel đóng.
    if (page != null && page >= 1) _controller.onPageChanged(page - 1);
  }

  void _goToPageIndex(int pageIndex) {
    _controller.onPageChanged(pageIndex);
    _goToPage(pageIndex);
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) _showChrome();
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
    });
    _searcher?.resetTextSearch();
  }

  void _runSearch(String query, bool ignoreTones) {
    if (query != _searchQuery || ignoreTones != _searchIgnoreTones) {
      setState(() {
        _searchQuery = query;
        _searchIgnoreTones = ignoreTones;
      });
    }
    final searcher = _searcher;
    if (searcher == null) return;
    if (!isPdfSearchQueryMeaningful(query)) {
      searcher.resetTextSearch();
      return;
    }
    final pattern = buildPdfSearchPattern(query, ignoreTones: ignoreTones);
    if (pattern == null) {
      searcher.resetTextSearch();
      return;
    }
    // `goToFirstMatch: false` — người dùng đang gõ, nhảy liên tục mỗi ký tự là
    // chóng mặt; để họ bấm mũi tên/danh sách.
    searcher.startTextSearch(
      pattern,
      caseInsensitive: true,
      goToFirstMatch: false,
    );
  }

  // ── Phím tắt desktop (Wave 1.9) ───────────────────────────
  KeyEventResult _handleShortcutKey(FocusNode node, KeyEvent event) {
    // KeyUp để ngỏ: xử lý cả Down lẫn Repeat để giữ phím lật trang liền mạch.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final action = resolvePdfReaderShortcut(
      key: event.logicalKey,
      isPdfView: _controller.viewMode == PdfViewMode.pdfView,
      searchOpen: _searchOpen,
      hasModifier: HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isAltPressed,
    );
    if (action == null) return KeyEventResult.ignored;
    _applyShortcut(action);
    return KeyEventResult.handled;
  }

  void _applyShortcut(PdfReaderShortcut action) {
    // Switch EXPRESSION (không phải statement): khỏi phải lo case cuối "completes
    // normally" và khỏi break thừa — enum đã đủ exhaustive.
    switch (action) {
      case PdfReaderShortcut.nextPage:
        _goToPage(_controller.currentPage + 1);
        break;
      case PdfReaderShortcut.previousPage:
        _goToPage(_controller.currentPage - 1);
        break;
      case PdfReaderShortcut.firstPage:
        _goToPage(0);
        break;
      case PdfReaderShortcut.lastPage:
        _goToPage(_controller.totalPages - 1);
        break;
      case PdfReaderShortcut.toggleChrome:
        _toggleChromeVisibility();
        break;
      case PdfReaderShortcut.openSearch:
        if (!_searchOpen) _toggleSearch();
        break;
      case PdfReaderShortcut.openToc:
        _openTocNavigator();
        break;
      case PdfReaderShortcut.toggleBookmark:
        unawaited(_controller.toggleBookmark());
        break;
      case PdfReaderShortcut.zoomIn:
        _zoom(byUp: true);
        break;
      case PdfReaderShortcut.zoomOut:
        _zoom(byUp: false);
        break;
      case PdfReaderShortcut.closeSearchOrScreen:
        if (_searchOpen) {
          _closeSearch();
        } else {
          Navigator.of(context).maybePop();
        }
        break;
    }
  }

  void _zoom({required bool byUp}) {
    if (!_pdfViewerController.isReady) return;
    unawaited(
      byUp
          ? _pdfViewerController.zoomUp()
          : _pdfViewerController.zoomDown(),
    );
  }

  /// Painter cho vùng trang, đã trộn đúng thứ tự: phủ màu chủ đề đọc TRƯỚC, rồi
  /// mới tới tô sáng kết quả tìm ⇒ highlight luôn giữ đúng màu của nó. Trả về
  /// null khi không có gì phải vẽ để pdfrx đi đường tắt của nó.
  List<PdfViewerPagePaintCallback>? _pagePaintCallbacks() {
    final painters = pdfPageVeilPainters(_readerTheme.pageVeils);
    final match = _searcher?.pageTextMatchPaintCallback;
    if (painters.isEmpty && match == null) return null;
    return <PdfViewerPagePaintCallback>[
      ...painters,
      if (match != null) match,
    ];
  }

  Future<void> _loadReaderThemeState() async {
    final state = await loadPdfReaderThemeState();
    if (!mounted || state == _readerTheme) return;
    setState(() => _readerTheme = state);
    _invalidateViewerPaint();
  }

  void _applyReaderTheme(PdfReaderThemeState state) {
    if (state == _readerTheme) return;
    setState(() => _readerTheme = state);
    _invalidateViewerPaint();
    unawaited(savePdfReaderThemeState(state));
  }

  /// Bắt buộc sau khi đổi theme: `pagePaintCallbacks` KHÔNG nằm trong
  /// `doChangesRequireReload` của pdfrx 2.2.24 ⇒ không tự vẽ lại trang đã render.
  void _invalidateViewerPaint() {
    if (!_pdfViewerController.isReady) return;
    _pdfViewerController.invalidate();
  }

  void _showReaderThemeSheet() {
    showModalBottomSheet<void>(
      context: context,
      // Sheet tự bọc SafeArea (xem pdf_reader_theme_sheet.dart) ⇒ không bật
      // useSafeArea ở đây, kẻo cộng dồn padding hai lần.
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // Sheet nằm ở overlay riêng nên setState của màn đọc KHÔNG rebuild nó;
      // StatefulBuilder giữ cho ô đang chọn + % độ sáng cập nhật khi tinh chỉnh.
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => PdfReaderThemeSheet(
          state: _readerTheme,
          onChanged: (state) {
            setSheetState(() {});
            _applyReaderTheme(state);
          },
        ),
      ),
    );
  }

  void _showShortcutHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(
            dialogContext.uiText('Phím tắt'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in pdfReaderShortcutHelp)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            row.keys.join('  '),
                            style: const TextStyle(
                              color: Color(0xFF64B5F6),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            dialogContext
                                .uiText(pdfShortcutHelpLabelKey(row.action)),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.uiText('Đóng')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showJumpToPageDialog() async {
    final total = _controller.totalPages;
    if (total <= 0) return;
    final field = TextEditingController(text: '${_controller.currentPage + 1}');
    final target = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(
            dialogContext.uiText('Tới trang'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: field,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  onSubmitted: (value) => Navigator.of(dialogContext)
                      .pop(int.tryParse(value.trim())),
                ),
                Slider(
                  value: (_controller.currentPage + 1)
                      .clamp(1, total)
                      .toDouble(),
                  min: 1,
                  max: total.toDouble(),
                  onChanged: (value) =>
                      field.text = value.round().toString(),
                ),
                Text(
                  '1 – $total',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.uiText('Huỷ')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(int.tryParse(field.text.trim())),
              child: Text(dialogContext.uiText('Đi tới')),
            ),
          ],
        );
      },
    );
    field.dispose();
    final page = target;
    if (page == null) return;
    _goToPageIndex(page.clamp(1, total) - 1);
  }

  String get _title => pdfDisplayName(widget.pdfPath);

  @override
  Widget build(BuildContext context) {
    final showWordlistFab =
        _controller.viewMode == PdfViewMode.pdfView && (_chromeVisible || _showWordlistPanel);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Focus(
        // Phím tắt desktop (Wave 1.9). Đặt TRÊN viewer: TextField/Sheet
        // nhận key trước (chúng là nút focus sâu hơn) nên gõ chữ không bị
        // phím tắt nuốt — xem services/pdf_shortcuts.dart.
        autofocus: true,
        onKeyEvent: _handleShortcutKey,
        child:   Stack(
          children: [
            Positioned.fill(
              child: _controller.viewMode == PdfViewMode.textMode
                  ? _buildTextMode()
                  : _buildSplitOrPdf(),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showTopChrome,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  offset: _showTopChrome ? Offset.zero : const Offset(0, -1.05),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showTopChrome ? 1 : 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PdfToolbar(
                          controller: _controller,
                          title: _title,
                          onUserInteraction: () => _showChrome(),
                          onShowAnnotations: _showAnnotationManager,
                          onOpenGrammarSettings: _openGrammarSettings,
                          writingMode: widget.writingMode,
                          onSendToWriting: _sendPdfToWriting,
                          onBatchSavePage: _openBatchSaveFromPage,
                          onSearch: _toggleSearch,
                          onShowToc: _openTocNavigator,
                          onJumpToPage: _showJumpToPageDialog,
                          onShowShortcuts: _showShortcutHelp,
                          readerThemeState: _readerTheme,
                          onShowReaderTheme: _showReaderThemeSheet,
                        ),
                        if (_searchOpen)
                          PdfSearchPanel(
                            searcher: _searcher,
                            initialQuery: _searchQuery,
                            initialIgnoreTones: _searchIgnoreTones,
                            onSearch: _runSearch,
                            onClose: _closeSearch,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_showBottomChrome,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  offset: _showBottomChrome ? Offset.zero : const Offset(0, 1.1),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showBottomChrome ? 1 : 0,
                    child: PdfTtsBar(
                      controller: _controller,
                      onUserInteraction: () => _showChrome(),
                    ),
                  ),
                ),
              ),
            ),
            if (_controller.hasSelection)
              Positioned(
                // Neo vào safe area + chiều cao thật của thanh chrome thay vì
                // số đo cứng 92/20 (khi chrome ẩn, thanh chọn đè lên FAB).
                bottom: MediaQuery.of(context).padding.bottom +
                    (_showBottomChrome ? 84 : 16),
                left: 16,
                right: 16,
                child: _SelectionBar(
                  controller: _controller,
                  onSaveNote: _saveSelectionAsAnnotation,
                  onHighlight: _highlightSelection,
                  onOpenTextStudio: _openSelectedInTextStudio,
                  writingMode: widget.writingMode,
                ),
              ),
            // Legend marker "từ đã lưu" — chỉ khi BẬT (READ-630-03)
            if (_controller.showRecallMarkers &&
                _controller.viewMode == PdfViewMode.pdfView)
              Positioned(
                left: 12,
                bottom: 88,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RecallLegendSwatch(color: Color(0xFF4CAF50), label: 'đã lưu'),
                      _RecallLegendSwatch(color: Color(0xFFFFC107), label: 'ghi chú'),
                      _RecallLegendSwatch(color: Color(0xFFF44336), label: 'đến kỳ ôn'),
                    ],
                  ),
                ),
              ),
          ],
        )
      ),

      floatingActionButton: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: showWordlistFab ? 1 : 0,
        child: IgnorePointer(
          ignoring: !showWordlistFab,
          child: FloatingActionButton.small(
            heroTag: 'wordlist_panel',
            backgroundColor: _showWordlistPanel
                ? const Color(0xFF6C63FF)
                : const Color(0xFF1A2235),
            onPressed: () {
              _showChrome();
              setState(() => _showWordlistPanel = !_showWordlistPanel);
              HapticFeedback.lightImpact();
            },
            child: Icon(
              _showWordlistPanel ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  // ── PDF View Mode ──────────────────────────────────────

  Widget _buildSplitOrPdf() {
    if (!_showWordlistPanel) return _buildPdfMode();

    final pdfName = pdfBaseName(widget.pdfPath);

    return Row(
      children: [
        Expanded(
          flex: 65,
          child: _buildPdfMode(),
        ),
        Expanded(
          flex: 35,
          child: PdfWordlistPanel(pdfFileName: pdfName),
        ),
      ],
    );
  }

  Widget _buildPdfMode() {
    if (_controller.errorMessage != null) {
      return _buildError(_controller.errorMessage!);
    }

    return PdfViewer.file(
      widget.pdfPath,
      controller: _pdfViewerController,
      params: PdfViewerParams(
        // Chủ đề đọc đổi NỀN QUANH TRANG (canvas của viewer). `backgroundColor`
        // nằm trong doChangesRequireReload của pdfrx nên đây là phần tự vẽ lại.
        backgroundColor: Color(_readerTheme.surroundColorArgb),
        // BÔI ĐEN CHỮ: trước đây selection của viewer KHÔNG hề được nối vào
        // controller (`setSelection` chỉ được gọi ở Text Mode) → 6 hành động
        // trên SelectionBar vô dụng ở chế độ PDF. Nay lấy trực tiếp từ pdfrx;
        // callback đã được viewer debounce 300 ms nên kéo handle không gây bão
        // rebuild.
        textSelectionParams: PdfTextSelectionParams(
          onTextSelectionChange: _onViewerTextSelection,
        ),
        // CHẠM: một chạm = tra từ, giữ (long-press) = chọn từ. Không còn
        // GestureDetector phủ kín trang chặn pan/zoom/selection của viewer.
        onGeneralTap: _onViewerTap,
        // TÌM KIẾM + MỤC LỤC (Wave 1). `onViewerReady` mới là lúc document chắc
        // chắn đã attach vào controller ⇒ tạo searcher và đọc outline ở đây.
        onViewerReady: _onViewerReady,
        // pdfrx tự tô sáng kết quả khớp qua paint callback: không cần overlay
        // riêng, và vùng khớp nằm ĐÚNG theo charRects của structured text.
        pagePaintCallbacks: _pagePaintCallbacks(),
        matchTextColor: const Color(0xFFFFEB3B).withValues(alpha: 0.35),
        activeMatchTextColor: const Color(0xFFFF9800).withValues(alpha: 0.60),
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF2196F3)),
                ),
                SizedBox(height: 16),
                Text('Đang mở PDF...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          );
        },

        // Callback khi document load xong. `onDocumentLoaded` là Future: phải
        // chờ nó đọc xong trang-của-phiên-trước (Hive) rồi mới quyết định nhảy
        // trang, nếu không viewer vẽ trang 1 trong khi dữ liệu nói trang 87.
        onDocumentChanged: (document) async {
          if (document == null) return;
          await _controller.onDocumentLoaded(document);
          if (!mounted) return;
          final pageCount = document.pages.length;
          int? targetPage;
          for (final candidate in <int?>[
            widget.initialPageIndex,
            widget.initialFocusContext?.pageIndexHint,
            _controller.initialPageToRestore,
          ]) {
            if (candidate != null && candidate > 0 && candidate < pageCount) {
              targetPage = candidate;
              break;
            }
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (targetPage != null && targetPage != _controller.currentPage) {
                _pdfViewerController.goToPage(
                  pageNumber: targetPage + 1,
                  duration: Duration.zero,
                );
                _controller.onPageChanged(targetPage);
              }
              if (widget.initialFocusContext != null) {
                _controller.showFocusCueForContext(
                  widget.initialFocusContext!,
                  fallbackWord: widget.initialFocusWord,
                );
              } else if (widget.initialFocusWord != null &&
                  widget.initialFocusWord!.trim().isNotEmpty) {
                _controller.showFocusCueForWord(widget.initialFocusWord!);
              }
            });
          _showChrome();
        },

        // Per-page overlay builder
        pageOverlaysBuilder: (context, pageRect, page) {
          final pageIndex = page.pageNumber - 1;
          final words = _controller.getWordsForPage(pageIndex);
          final annotations = _controller.annotationsForPage(pageIndex);
          final cuePage = _controller.ttsCuePageIndex;
          final ttsRects = (cuePage == null || cuePage == pageIndex)
              ? _controller.ttsCueRects
              : const <Rect>[];

          return [
            // Layer 1: Word highlight / recall / focus cue / câu đang đọc
            if ((_controller.colorMode != ColorMode.none ||
                    _controller.focusWordCue != null ||
                    _controller.focusRectCue != null ||
                    _controller.focusTextStartOffsetCue != null ||
                    _controller.showRecallMarkers ||
                    ttsRects.isNotEmpty) &&
                (words.isNotEmpty ||
                    _controller.focusRectCue != null ||
                    ttsRects.isNotEmpty))
              Positioned.fill(
                child: PdfWordOverlay(
                  words: words,
                  pageIndex: pageIndex,
                  colorMode: _controller.colorMode,
                  grammarSettings: _controller.grammarSettings,
                  grammarPalette: _controller.activeGrammarPalette,
                  page: page,
                  speakingWord: _controller.currentSpeakingWord,
                  focusWordCue: _controller.focusWordCue,
                  focusRectCue: _controller.focusRectCue,
                  focusPageIndexCue: _controller.focusPageIndexCue,
                  focusTextStartOffsetCue: _controller.focusTextStartOffsetCue,
                  focusTextEndOffsetCue: _controller.focusTextEndOffsetCue,
                  showRecallMarkers: _controller.showRecallMarkers,
                  ttsCueRects: ttsRects,
                ),
              ),

            // Layer 2: Annotations
            if (annotations.isNotEmpty)
              Positioned.fill(
                child: PdfAnnotationLayer(
                  annotations: annotations,
                  page: page,
                  onAnnotationTap: (ann) =>
                      PdfAnnotationSheet.show(context, ann, _controller),
                ),
              ),

          ];
        },

        // Page changed callback
        onPageChanged: (pageNumber) {
          if (pageNumber != null) {
            _controller.onPageChanged(pageNumber - 1);
          }
        },

        // Viewer layout
        layoutPages: (pages, params) {
          // Single page scroll (vertical)
          final height = pages.fold(
            0.0,
            (prev, page) => prev + page.height + params.margin,
          );
          return PdfPageLayout(
            pageLayouts: pages.mapIndexed((i, page) {
              final y = pages
                  .take(i)
                  .fold(0.0, (prev, p) => prev + p.height + params.margin);
              return Rect.fromLTWH(0, y, page.width, page.height);
            }).toList(),
            documentSize: Size(pages.first.width, height),
          );
        },
      ),
    );
  }

  // ── Text Mode ──────────────────────────────────────────

  Widget _buildTextMode() {
    if (_controller.isExtractingText) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF2196F3)),
            ),
            SizedBox(height: 16),
            Text('Đang trích xuất văn bản...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_controller.extractedFullText.isEmpty) {
      return const Center(
        child: Text(
          'Không thể trích xuất text từ PDF này.\nCó thể là PDF scan (hình ảnh).',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: widget.writingMode
            ? MediaQuery.of(context).padding.top + 116
            : 64,
        bottom: 84,
      ),
      child: Column(
        children: [
          // Banner thông báo Text Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A237E),
            child: Row(
              children: [
                Icon(
                  widget.writingMode ? Icons.edit_square : Icons.text_fields,
                  color: widget.writingMode
                      ? const Color(0xFF80DEEA)
                      : Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.writingMode
                        ? 'Nguồn cho Viết — bôi chọn một đoạn hoặc dùng toàn bộ PDF'
                        : 'Chế độ văn bản — toàn bộ tính năng highlight & TTS',
                    style: TextStyle(
                      color: widget.writingMode
                          ? const Color(0xFF80DEEA)
                          : Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.writingMode
                      ? _sendExtractedPdfToWriting
                      : _loadIntoReadMode,
                  child: Text(
                    widget.writingMode
                        ? 'Đưa toàn bộ vào Viết →'
                        : 'Mở trong Read Mode →',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Text content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                _controller.extractedFullText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.7,
                  letterSpacing: 0.2,
                ),
                onSelectionChanged: (selection, cause) {
                  if (selection.baseOffset == selection.extentOffset) return;
                  final base = selection.baseOffset < selection.extentOffset
                      ? selection.baseOffset
                      : selection.extentOffset;
                  final extent = selection.baseOffset < selection.extentOffset
                      ? selection.extentOffset
                      : selection.baseOffset;
                  final text = _controller.extractedFullText
                      .substring(base, extent);
                  if (text.trim().isNotEmpty) {
                    // Rect.zero ở đây từng là nguồn gốc highlight "mở ra không
                    // thấy gì": Text Mode chỉ có offset trong chuỗi gộp, nên
                    // controller phải tự dò lại trang + rect (xem
                    // resolveTextModeSelectionToPage).
                    _controller.applyTextModeSelection(
                      text: text,
                      startOffset: base,
                      endOffset: extent,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tô sáng nhanh: một chạm, không dialog — rồi mới bật menu ghi chú nếu
  /// người dùng muốn thêm lời bình (đúng thứ tự thao tác của ReadEra).
  Future<void> _highlightSelection() async {
    final annotation = await _controller.addAnnotationFromSelection(note: '');
    if (!mounted || annotation == null) return;
    HapticFeedback.lightImpact();
    _controller.clearSelection();
    _showChrome();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText('🖍 Đã tô sáng · chạm để ghi chú thêm')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: context.uiText('Ghi chú'),
          onPressed: () => PdfAnnotationSheet.show(context, annotation, _controller),
        ),
      ),
    );
  }

  Future<void> _saveSelectionAsAnnotation() async {
    final selectedText = _controller.selectedText?.trim() ?? '';
    if (selectedText.isEmpty) return;

    final noteCtrl = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Ghi chú cho đoạn chọn'),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$selectedText"',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.uiText('Nhập ghi chú / bản dịch / insight...'),
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu ghi chú'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true || !mounted) return;
    await _controller.addAnnotationFromSelection(note: noteCtrl.text);
    if (!mounted) return;
    _controller.clearSelection();
    _showChrome();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📝 Đã lưu ghi chú cho đoạn chọn'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openSelectedInTextStudio() {
    final selectedText = _controller.selectedText?.trim() ?? '';
    if (selectedText.isEmpty) return;

    if (widget.writingMode) {
      context.read<TextProvider>().loadWritingSource(
            selectedText,
            title: 'PDF đoạn chọn · ${_title.replaceAll('.pdf', '')}',
            task: WritingTaskType.rewrite,
            kind: WritingSourceKind.pdf,
            sourceLabel: _title,
            isExcerpt: true,
          );
      Navigator.of(context).pop();
      return;
    }

    context.read<TextProvider>().loadFromString(
          selectedText,
          title: context.uiText(
            'PDF đoạn chọn · ${_title.replaceAll('.pdf', '')}',
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Đã mở đoạn chọn trong Text Studio'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendPdfToWriting() async {
    _showChrome();
    await _controller.switchToTextMode();
    if (!mounted) return;
    _sendExtractedPdfToWriting();
  }

  void _sendExtractedPdfToWriting() {
    final text = _controller.extractedFullText.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể lấy chữ từ PDF này. File có thể chỉ chứa ảnh scan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<TextProvider>().loadWritingSource(
          text,
          title: _title.replaceAll('.pdf', ''),
          task: WritingTaskType.summary,
          kind: WritingSourceKind.pdf,
          sourceLabel: _title,
        );
    Navigator.of(context).pop();
  }

  void _showAnnotationManager() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (context) => _PdfAnnotationManager(
        controller: _controller,
        title: _title,
      ),
    );
  }

  /// READ-630-04: lưu hàng loạt từ trang hiện tại
  Future<void> _openBatchSaveFromPage() async {
    _showChrome();
    final text = await _controller.extractCurrentPageText();
    if (!mounted) return;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không trích xuất được text từ trang này.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await SelectionSaveSheet.show(
      context,
      text: text,
      sourceLabel: _title,
      sourceDetail: 'trang ${_controller.currentPage + 1}',
      contextBuilder: (sample) => VocabContext.fromPdf(
        fileName: pdfBaseName(widget.pdfPath),
        page: _controller.currentPage + 1,
        pageIndexHint: _controller.currentPage,
        surroundingText: sample,
        pdfPath: widget.pdfPath,
        anchorText: sample,
      ),
    );
  }

  Future<void> _openGrammarSettings() async {
    await _controller.refreshGrammarPresetLibrary();
    await GrammarQuickSettingsSheet.show(
      context,
      title: 'PDF Reader · Từ loại chuyên sâu',
      settings: _controller.grammarSettings,
      palette: _controller.activeGrammarPalette,
      activePreset: _controller.activeGrammarPreset,
      presets: _controller.availableGrammarPresets,
      onToggleEnabled: (value) => _controller.setGrammarHighlightEnabled(value),
      onSelectPreset: (id) => _controller.applyGrammarPreset(id),
      onSaveCurrentAsPreset: (name, description) =>
          _controller.saveCurrentGrammarPreset(
        name: name,
        description: description,
      ),
      onRestorePreviousPreset: () => _controller.restorePreviousGrammarPreset(),
      onToggleAdvancedMode: (value) => _controller.setGrammarAdvancedControls(value),
      onSelectPalette: (id) => _controller.setGrammarPalette(id),
      onSelectStyle: (style) => _controller.setGrammarHighlightStyle(style),
      onToggleCategory: (category) => _controller.toggleGrammarCategory(category),
      onToggleLegend: (visible) => _controller.setGrammarLegendVisible(visible),
      onShowAllCategories: () => _controller.showAllGrammarCategories(),
    );
  }

  /// Load toàn bộ text vào TextProvider → navigate to Read Mode
  void _loadIntoReadMode() {
    if (_controller.extractedFullText.isEmpty) return;

    final textProvider = context.read<TextProvider>();
    textProvider.loadFromString(
      _controller.extractedFullText,
      title: _title.replaceAll('.pdf', ''),
    );

    // Pop back → Read Mode tab sẽ hiển thị nội dung
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText('✅ Đã load "$_title" vào Text Studio')),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Viewer tương tác: chạm & chọn chữ ───────────────────
  //
  // Trước đây mọi tương tác đi qua một `GestureDetector` phủ kín TỪNG TRANG
  // (layer 3 trong pageOverlaysBuilder). Hệ quả: nó ăn mất long-press mà pdfrx
  // dùng để BẮT ĐẦU selection trên màn cảm ứng, và nó nằm trên viewer nên
  // pan/zoom cũng nặng tay. pdfrx có `onGeneralTap` đúng cho việc này —
  // chạm thì mình giữ, còn lại trả `false` để viewer xử lý như thiết kế.

  /// Một chạm: vào từ → sheet tra cứu; vào nền → bật/tắt chrome; vào vùng đang
  /// chọn → giữ nguyên menu để người dùng kịp bấm hành động.
  bool _onViewerTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type != PdfViewerGeneralTapType.tap) {
      // double tap = zoom, long press = chọn từ: mặc cho viewer làm.
      return false;
    }
    if (details.tapOn == PdfViewerPart.selectedText) return true;

    final hit = _wordAtDocumentPoint(details.documentPosition);
    if (hit != null && hit.word.text.trim().length > 1) {
      _showChrome();
      HapticFeedback.selectionClick();
      PdfWordTapSheet.show(context, hit.word, _controller);
      return true;
    }
    if (_controller.hasSelection) {
      _controller.clearSelection();
      return true;
    }
    _toggleChromeVisibility();
    return true;
  }

  /// Điểm chạm trong không gian tài liệu → không gian nhìn của trang → hit-test
  /// theo pixel (ổn định ở mọi mức zoom, không còn "20 đơn vị PDF").
  PdfWordHit? _wordAtDocumentPoint(Offset documentPoint) {
    final doc = _controller.document;
    if (doc == null || !_pdfViewerController.isReady) return null;
    PdfPageLayout layout;
    try {
      layout = _pdfViewerController.layout;
    } catch (_) {
      return null;
    }
    final count = layout.pageLayouts.length < doc.pages.length
        ? layout.pageLayouts.length
        : doc.pages.length;
    for (int i = 0; i < count; i++) {
      final pageRect = layout.pageLayouts[i];
      if (!pageRect.contains(documentPoint)) continue;
      final page = doc.pages[i];
      return hitTestWord(
        _controller.getWordsForPage(i),
        point: documentPoint - pageRect.topLeft,
        pageWidth: page.width,
        pageHeight: page.height,
        pageViewSize: pageRect.size,
      );
    }
    return null;
  }

  void _onViewerTextSelection(PdfTextSelection selection) {
    if (!selection.hasSelectedText) {
      if (_controller.selectionSource == PdfSelectionSource.viewer) {
        _controller.clearSelection(alsoClearViewer: false);
      }
      return;
    }
    unawaited(_syncViewerSelection(selection));
  }

  Future<void> _syncViewerSelection(PdfTextSelection selection) async {
    try {
      final text = await selection.getSelectedText();
      final ranges = await selection.getSelectedTextRanges();
      if (!mounted) return;
      if (text.trim().isEmpty || ranges.isEmpty) {
        _controller.clearSelection(alsoClearViewer: false);
        return;
      }
      _controller.applyViewerSelection(
        text: text,
        fragments: [
          for (final range in ranges)
            if (range.text.trim().isNotEmpty)
              PdfSelectionFragment(
                pageIndex: range.pageNumber - 1,
                startOffset: range.start,
                endOffset: range.end,
                // `PdfRect` (top > bottom) chép nguyên vào `Rect` — đúng quy
                // ước dùng chung với `PdfWordInfo.bounds` và
                // `VocabContext.rectHint`; việc lật trục chỉ xảy ra lúc vẽ.
                bounds: Rect.fromLTRB(
                  range.bounds.left,
                  range.bounds.top,
                  range.bounds.right,
                  range.bounds.bottom,
                ),
              ),
        ],
      );
      _showChrome();
    } catch (e) {
      debugPrint('PdfReaderScreen: selection sync error: $e');
    }
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Không thể mở PDF',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selection Action Bar ──────────────────────────────────

class _SelectionBar extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback onSaveNote;
  final VoidCallback onHighlight;
  final VoidCallback onOpenTextStudio;
  final bool writingMode;

  const _SelectionBar({
    required this.controller,
    required this.onSaveNote,
    required this.onHighlight,
    required this.onOpenTextStudio,
    required this.writingMode,
  });

  @override
  Widget build(BuildContext context) {
    final existing = context.watch<VocabularyProvider>().findByWord(
          controller.selectedText?.trim() ?? '',
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1A237E),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '"${controller.selectedText}"',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (existing != null)
            _SelectionIconButton(
              icon: Icons.history_edu_outlined,
              color: const Color(0xFFB9F6CA),
              tooltip: context.uiText('Xem ghi chú đã lưu trước đó'),
              onTap: () => _showSelectionRecallSheet(context, existing),
            ),
          if (existing != null) const SizedBox(width: 2),
          _SelectionIconButton(
            icon: Icons.format_paint,
            color: const Color(0xFFFFD54F),
            tooltip: context.uiText('Tô sáng đoạn chọn'),
            onTap: onHighlight,
          ),
          _SelectionIconButton(
            icon: Icons.note_add_outlined,
            color: Colors.amber,
            tooltip: context.uiText('Ghi chú đoạn chọn'),
            onTap: onSaveNote,
          ),
          _SelectionIconButton(
            icon: writingMode ? Icons.edit_square : Icons.text_snippet_outlined,
            color: Colors.cyan,
            tooltip: writingMode
                ? 'Dùng đoạn này cho bài Viết lại ý'
                : 'Mở trong Text Studio',
            onTap: onOpenTextStudio,
          ),
          _SelectionIconButton(
            icon: Icons.bookmark_add,
            color: const Color(0xFF4CAF50),
            tooltip: context.uiText('Lưu vào WordList (chủ đề + ngôn ngữ)'),
            onTap: () {
              final text = controller.selectedText?.trim() ?? '';
              if (text.isEmpty) return;
              SelectionSaveSheet.show(
                context,
                text: text,
                sourceLabel: pdfBaseName(controller.pdfPath),
                sourceDetail: 'trang ${controller.currentPage + 1}',
                contextBuilder: (sample) =>
                    controller.buildSelectionContext(sample),
              );
            },
          ),
          _SelectionIconButton(
            icon: Icons.volume_up,
            color: Colors.blue,
            tooltip: context.uiText('Đọc'),
            onTap: controller.speakSelectedText,
          ),
          _SelectionIconButton(
            icon: Icons.psychology,
            color: Colors.purple,
            tooltip: context.uiText('Lưu vào Vườn Nhớ'),
            onTap: () {
              controller.saveSelectedTextToMemory();
              controller.clearSelection();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Đã lưu vào Vườn Nhớ'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          _SelectionIconButton(
            icon: Icons.close,
            color: Colors.grey,
            tooltip: context.uiText('Đóng'),
            onTap: controller.clearSelection,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _SelectionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  const _SelectionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      onPressed: onTap,
      tooltip: context.uiText(tooltip),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}

void _showSelectionRecallSheet(BuildContext context, WordEntry entry) {
  final latestContext = entry.latestContext;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            entry.word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniRecallBadge(label: '${entry.encounterCount} lần gặp'),
              _MiniRecallBadge(label: '${entry.sourceFiles.length} nguồn'),
              _MiniRecallBadge(label: entry.vocabType.label(context)),
            ],
          ),
          if (entry.meaning.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              entry.meaning,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if ((entry.personalNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              entry.personalNotes!.trim(),
              style: const TextStyle(
                color: Color(0xFFB9F6CA),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (latestContext != null) ...[
            const SizedBox(height: 12),
            Text(
              context.uiText(
                'Ngữ cảnh gần nhất: ${latestContext.composeDisplaySource(
                  latestContext.hasGeneratedPositionLabel &&
                          latestContext.pageOrPosition != null
                      ? context.uiText(latestContext.pageOrPosition!)
                      : latestContext.pageOrPosition,
                )}',
              ),
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              latestContext.surroundingText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                UnifiedKnowledgeSheet.show(context, word: entry);
              },
              icon: const Icon(Icons.hub_outlined, size: 18),
              label: const Text('Mở hồ sơ tri thức hợp nhất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64B5F6),
                side: BorderSide(
                  color: const Color(0xFF64B5F6).withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniRecallBadge extends StatelessWidget {
  final String label;

  const _MiniRecallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.uiText(label),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PdfAnnotationManager extends StatelessWidget {
  final PdfReaderController controller;
  final String title;

  const _PdfAnnotationManager({
    required this.controller,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final annotations = List<PdfAnnotation>.from(controller.annotations)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ghi chú PDF',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[400], height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              context.uiText('${annotations.length} ghi chú đã lưu'),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 12),
            // B1+B2 (Wave 2): công sức đánh dấu phải ra khỏi được cái máy này,
            // và phải nhập lại được ở máy khác — nên để ngay trong bảng quản lý,
            // không giấu sau menu.
            PdfReaderExportRow(controller: controller),
            const SizedBox(height: 12),
            Expanded(
              child: annotations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.note_alt_outlined,
                              size: 42, color: Colors.grey[700]),
                          const SizedBox(height: 10),
                          Text(
                            'Chưa có ghi chú nào',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Long-press một từ trên PDF hoặc ghi chú từ đoạn chọn ở Text Mode.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: annotations.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, index) {
                        final ann = annotations[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          leading: ann.type == AnnotationType.bookmark
                              ? const Icon(Icons.bookmark,
                                  color: Color(0xFF64B5F6), size: 18)
                              : Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: ann.color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                          title: Text(
                            context.uiText('Trang ${ann.pageIndex + 1}'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                ann.selectedText.isEmpty
                                    ? context.uiText('Đánh dấu trang')
                                    : ann.selectedText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                              if ((ann.note ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  ann.note!.trim(),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.amber[100],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_note_rounded,
                                color: Colors.white54),
                            tooltip: context.uiText('Sửa / xoá'),
                            onPressed: () {
                              Navigator.pop(context);
                              PdfAnnotationSheet.show(context, ann, controller);
                            },
                          ),
                          // Chạm vào dòng = ĐẾN CHỖ NÓ (reader chuẩn: danh sách
                          // ghi chú là mục lục để nhảy, không phải hộp thoại).
                          onTap: () {
                            Navigator.pop(context);
                            controller.revealAnnotation(ann);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recall legend (READ-630-03) ───────────────────────────
class _RecallLegendSwatch extends StatelessWidget {
  final Color color;
  final String label;

  const _RecallLegendSwatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color, width: 1.2),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// Iterable extension
extension _IterableIndexed<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T item) f) sync* {
    int i = 0;
    for (final item in this) {
      yield f(i++, item);
    }
  }
}
