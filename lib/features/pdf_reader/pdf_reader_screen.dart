//lid/features/pdf_reader/pdf_reader_screen.dart
// Màn hình đọc PDF với:
//  - Render PDF gốc (pdfrx)
//  - Overlay highlight theo CEFR / WordType / Difficulty
//  - TTS đọc tiếng Anh / Việt / Song ngữ
//  - Ghi chú per-đoạn văn
//  - Tap từ → word detail + lưu vào Memory Garden
//  - Text Mode: extract toàn bộ text → load vào Read Mode cũ

import 'dart:async';
import 'dart:io';

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
import '../../widgets/unified_knowledge_sheet.dart';
import 'models/pdf_annotation.dart';
import 'models/pdf_word_info.dart';
import 'pdf_reader_controller.dart';
import 'widgets/pdf_annotation_layer.dart';
import 'widgets/pdf_annotation_sheet.dart';
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
  static const Duration _kPdfChromeAutoHideDelay = Duration(seconds: 3);

  late final PdfReaderController _controller;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _showWordlistPanel = false;
  bool _chromeVisible = true;
  Timer? _chromeHideTimer;

  @override
  void initState() {
    super.initState();
    _controller = PdfReaderController(pdfPath: widget.pdfPath);
    _controller.addListener(_onControllerUpdate);

    // Đồng bộ vùng chọn từ PDF Viewer vào controller
    _pdfViewerController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleChromeAutoHide();
    });
  }

  bool get _isImmersivePdfMode =>
      _controller.viewMode == PdfViewMode.pdfView && _controller.selectedText == null;

  bool get _showTopChrome =>
      _controller.viewMode != PdfViewMode.pdfView || _chromeVisible;

  bool get _showBottomChrome =>
      _controller.viewMode != PdfViewMode.pdfView || _chromeVisible;

  double get _selectionBottomOffset => _showBottomChrome ? 92 : 20;

  void _onControllerUpdate() {
    if (!mounted) return;

    if (_controller.selectedText != null ||
        _controller.viewMode == PdfViewMode.textMode) {
      _showChrome(autoHide: false);
      return;
    }

    setState(() {});
    _scheduleChromeAutoHide();
  }

  void _scheduleChromeAutoHide() {
    _chromeHideTimer?.cancel();
    if (!_isImmersivePdfMode) return;
    _chromeHideTimer = Timer(_kPdfChromeAutoHideDelay, () {
      if (!mounted || !_isImmersivePdfMode) return;
      setState(() => _chromeVisible = false);
    });
  }

  void _showChrome({bool autoHide = true}) {
    _chromeHideTimer?.cancel();
    if (!mounted) return;
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    } else {
      setState(() {});
    }
    if (autoHide) {
      _scheduleChromeAutoHide();
    }
  }

  void _toggleChromeVisibility() {
    if (_controller.viewMode != PdfViewMode.pdfView) return;
    if (_controller.selectedText != null) return;

    _chromeHideTimer?.cancel();
    setState(() => _chromeVisible = !_chromeVisible);
    if (_chromeVisible) {
      _scheduleChromeAutoHide();
    }
  }

  @override
  void dispose() {
    _chromeHideTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  String get _title {
    final parts = widget.pdfPath.split(Platform.pathSeparator);
    final name = parts.last;
    return name.length > 30 ? '${name.substring(0, 28)}...' : name;
  }

  @override
  Widget build(BuildContext context) {
    final showWordlistFab =
        _controller.viewMode == PdfViewMode.pdfView && (_chromeVisible || _showWordlistPanel);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
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
                  child: PdfToolbar(
                    controller: _controller,
                    title: _title,
                    onUserInteraction: () => _showChrome(),
                    onShowAnnotations: _showAnnotationManager,
                    onOpenGrammarSettings: _openGrammarSettings,
                    writingMode: widget.writingMode,
                    onSendToWriting: _sendPdfToWriting,
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
          if (_controller.selectedText != null)
            Positioned(
              bottom: _selectionBottomOffset,
              left: 20,
              right: 20,
              child: _SelectionBar(
                controller: _controller,
                onSaveNote: _saveSelectionAsAnnotation,
                onOpenTextStudio: _openSelectedInTextStudio,
                writingMode: widget.writingMode,
              ),
            ),
        ],
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

    final pdfName = widget.pdfPath.split(Platform.pathSeparator).last;

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
        backgroundColor: const Color(0xFF1A1A2E),
        // Text selection được xử lý qua PdfViewerController hoặc gestures
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

        // Callback khi document load xong
        onDocumentChanged: (document) {
          if (document != null) {
            _controller.onDocumentLoaded(document);
            final contextPage = widget.initialFocusContext?.pageIndexHint;
            final targetPage = widget.initialPageIndex != null &&
                    widget.initialPageIndex! >= 0 &&
                    widget.initialPageIndex! < document.pages.length
                ? widget.initialPageIndex!
                : contextPage != null &&
                        contextPage >= 0 &&
                        contextPage < document.pages.length
                    ? contextPage
                    : _controller.currentPage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (targetPage != _controller.currentPage) {
                _pdfViewerController.goToPage(
                  pageNumber: targetPage + 1,
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
          }
        },

        // Per-page overlay builder
        pageOverlaysBuilder: (context, pageRect, page) {
          final pageIndex = page.pageNumber - 1;
          final words = _controller.getWordsForPage(pageIndex);
          final annotations = _controller.annotationsForPage(pageIndex);

          return [
            // Layer 1: Word highlight / recall / focus cue
            if ((_controller.colorMode != ColorMode.none ||
                    _controller.focusWordCue != null ||
                    _controller.focusRectCue != null ||
                    _controller.focusTextStartOffsetCue != null) &&
                (words.isNotEmpty || _controller.focusRectCue != null))
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

            // Layer 3: Tap detector for words
            Positioned.fill(
              child: _WordTapDetector(
                page: page,
                pageIndex: pageIndex,
                controller: _controller,
                onBackgroundTap: _toggleChromeVisibility,
                onWordInteraction: () => _showChrome(),
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
                  if (selection.baseOffset != selection.extentOffset) {
                    final text = _controller.extractedFullText.substring(
                      selection.baseOffset,
                      selection.extentOffset,
                    );
                    if (text.trim().isNotEmpty) {
                      _controller.setSelection(text, Rect.zero);
                    }
                  }
                },
              ),
            ),
          ),
        ],
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
    _showChrome(autoHide: false);
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
    _showChrome(autoHide: false);
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

// ── Word Tap Detector ─────────────────────────────────────

/// GestureDetector trong suốt phủ lên PDF page, detect tap vào từ
class _WordTapDetector extends StatelessWidget {
  final PdfPage page;
  final int pageIndex;
  final PdfReaderController controller;
  final VoidCallback onBackgroundTap;
  final VoidCallback onWordInteraction;

  const _WordTapDetector({
    required this.page,
    required this.pageIndex,
    required this.controller,
    required this.onBackgroundTap,
    required this.onWordInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final scaleX = page.width / constraints.maxWidth;
      final scaleY = page.height / constraints.maxHeight;

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          // Convert screen tap position → PDF coordinates
          final tapX = details.localPosition.dx * scaleX;
          // PDF Y: bottom-left origin
          final tapY = page.height - details.localPosition.dy * scaleY;

          final words = controller.getWordsForPage(pageIndex);
          if (words.isEmpty) return;

          // Tìm từ gần nhất với tap position
          PdfWordInfo? tappedWord;
          double minDist = double.infinity;

          for (final word in words) {
            if (word.bounds.contains(Offset(tapX, tapY))) {
              tappedWord = word;
              break;
            }
            // Fallback: tìm từ gần nhất trong radius
            final center = word.bounds.center;
            final dist = (center - Offset(tapX, tapY)).distance;
            if (dist < minDist && dist < 20) {
              minDist = dist;
              tappedWord = word;
            }
          }

          if (tappedWord != null && tappedWord.text.trim().length > 1) {
            onWordInteraction();
            HapticFeedback.selectionClick();
            PdfWordTapSheet.show(context, tappedWord, controller);
          } else {
            onBackgroundTap();
          }
        },
        onLongPressStart: (details) {
          // Long press → Add annotation
          final tapX = details.localPosition.dx * scaleX;
          final tapY = page.height - details.localPosition.dy * scaleY;

          // Tìm từ tại vị trí này
          final words = controller.getWordsForPage(pageIndex);
          for (final word in words) {
            if (word.bounds.contains(Offset(tapX, tapY))) {
              onWordInteraction();
              HapticFeedback.mediumImpact();
              PdfAnnotationSheet.showAdd(
                context,
                word.text,
                word.bounds,
                pageIndex,
                controller,
              );
              break;
            }
          }
        },
        child: const SizedBox.expand(),
      );
    });
  }
}

// ── Selection Action Bar ──────────────────────────────────

class _SelectionBar extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback onSaveNote;
  final VoidCallback onOpenTextStudio;
  final bool writingMode;

  const _SelectionBar({
    required this.controller,
    required this.onSaveNote,
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
            tooltip: context.uiText('Lưu vào WordList'),
            onTap: () {
              final added = controller.saveSelectedTextToWordList();
              controller.clearSelection();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(added
                      ? '✅ Đã lưu vào WordList'
                      : '✅ Đã bổ sung ngữ cảnh vào WordList'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF4CAF50),
                  duration: const Duration(seconds: 2),
                ),
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
                          leading: Container(
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
                                ann.selectedText,
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
                            icon: const Icon(Icons.chevron_right,
                                color: Colors.white54),
                            onPressed: () {
                              Navigator.pop(context);
                              PdfAnnotationSheet.show(context, ann, controller);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            PdfAnnotationSheet.show(context, ann, controller);
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

// Iterable extension
extension _IterableIndexed<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T item) f) sync* {
    int i = 0;
    for (final item in this) {
      yield f(i++, item);
    }
  }
}
