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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:provider/provider.dart';

import '../../models/color_mode.dart';
import '../../models/vocab_context.dart';
import '../../providers/text_provider.dart';
import '../../providers/vocabulary_provider.dart';
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

  const PdfReaderScreen({super.key, required this.pdfPath});

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
              child: _SelectionBar(controller: _controller),
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
            // Jump to last page
            if (_controller.currentPage > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _pdfViewerController.goToPage(
                  pageNumber: _controller.currentPage + 1,
                );
              });
            }
          }
        },

        // Per-page overlay builder
        pageOverlaysBuilder: (context, pageRect, page) {
          final pageIndex = page.pageNumber - 1;
          final words = _controller.getWordsForPage(pageIndex);
          final annotations = _controller.annotationsForPage(pageIndex);

          return [
            // Layer 1: Word highlight (CEFR / WordType)
            if (_controller.colorMode != ColorMode.none && words.isNotEmpty)
              Positioned.fill(
                child: PdfWordOverlay(
                  words: words,
                  colorMode: _controller.colorMode,
                  page: page,
                  speakingWord: _controller.currentSpeakingWord,
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
      padding: const EdgeInsets.only(top: 64, bottom: 84),
      child: Column(
        children: [
          // Banner thông báo Text Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A237E),
            child: Row(
              children: [
                const Icon(Icons.text_fields, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chế độ văn bản — toàn bộ tính năng highlight & TTS',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _loadIntoReadMode,
                  child: const Text(
                    'Mở trong Read Mode →',
                    style: TextStyle(fontSize: 11),
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
        content: Text('✅ Đã load "$_title" vào Text Studio'),
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
  const _SelectionBar({required this.controller});

  @override
  Widget build(BuildContext context) {
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

          // ★ MỚI: Save to Wordlist (Cấp 1)
          IconButton(
            icon: const Icon(Icons.bookmark_add,
                color: Color(0xFF4CAF50), size: 20),
            onPressed: () {
              final provider = context.read<VocabularyProvider>();
              final text = controller.selectedText ?? '';
              if (text.trim().isEmpty) return;

              final pdfName = controller.pdfPath
                  .split(Platform.isWindows ? '\\' : '/')
                  .last;
              final ctx = VocabContext.fromPdf(
                fileName: pdfName,
                page: controller.currentPage + 1,
                surroundingText: text,
              );

              // Tự động phân loại dựa trên nội dung text được chọn
              provider.addWithAutoClassify(
                text: text.trim(),
                meaning: '',
                context: ctx,
              );

              controller.clearSelection();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Đã lưu vào Wordlist'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF4CAF50),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Lưu vào Wordlist',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),

          // Speak (giữ nguyên)
          IconButton(
            icon: const Icon(Icons.volume_up, color: Colors.blue, size: 20),
            onPressed: controller.speakSelectedText,
            tooltip: 'Đọc',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),

          // Save to Memory (giữ nguyên)
          IconButton(
            icon: const Icon(Icons.psychology, color: Colors.purple, size: 20),
            onPressed: () {
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
            tooltip: 'Lưu vào Vườn Nhớ',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),

          // Close (giữ nguyên)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
            onPressed: controller.clearSelection,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
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
