// lib/screens/read_mode/controllers/read_mode_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../services/syntax_highlighter_service.dart';

/// Controller quản lý business logic cho Read Mode
/// Tách khỏi UI để dễ test và maintain
class ReadModeController extends ChangeNotifier {
  final TextProvider textProvider;
  final PlayerProvider playerProvider;

  ReadModeController({
    required this.textProvider,
    required this.playerProvider,
  }) {
    _init();
  }

  // ===== STATE =====
  bool _autoSyncEnabled = true;
  bool get autoSyncEnabled => _autoSyncEnabled;

  int _lastSyncedLine = -1;
  bool _isScrolling = false;

  // Floating menu
  OverlayEntry? _floatingOverlay;
  bool get hasFloatingMenu => _floatingOverlay != null;

  // Reading progress
  DateTime? _sessionStart;
  int _sessionReadSeconds = 0;
  Timer? _readingTimer;

  double get readingProgress {
    if (textProvider.lines.isEmpty) return 0.0;
    return (textProvider.currentLineIndex + 1) / textProvider.lines.length;
  }

  String get readingProgressText {
    final current = textProvider.currentLineIndex + 1;
    final total = textProvider.lines.length;
    return '$current / $total';
  }

  String get sessionTimeText {
    final mins = _sessionReadSeconds ~/ 60;
    final secs = _sessionReadSeconds % 60;
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  // ===== INIT =====
  void _init() {
    _sessionStart = DateTime.now();
    _startReadingTimer();
    _initSyntaxHighlighter();
  }

  Future<void> _initSyntaxHighlighter() async {
    try {
      await SyntaxHighlighterService.instance.initialize();
      // Re-analyze nếu đã có text
      if (textProvider.hasLyrics) {
        _analyzeWithHighlighter();
      }
    } catch (e) {
      debugPrint('SyntaxHighlighter init failed: $e');
    }
  }

  void _analyzeWithHighlighter() {
    final lines = textProvider.lines.map((l) => l.content).toList();
    final analyzed = SyntaxHighlighterService.instance.analyzeAllLines(lines);
    textProvider.updateAnalyzedLines(analyzed);
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionReadSeconds++;
      // Không notify mỗi giây, chỉ khi cần hiển thị
    });
  }

  // ===== AUTO-SCROLL SYNC =====
  void toggleAutoSync() {
    _autoSyncEnabled = !_autoSyncEnabled;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Gọi từ audio position listener
  /// Trả về line index cần scroll tới, hoặc -1
  int checkAudioSync(Duration position) {
    if (!_autoSyncEnabled || _isScrolling) return -1;
    if (!textProvider.hasLyrics) return -1;

    for (int i = 0; i < textProvider.lines.length; i++) {
      final line = textProvider.lines[i];
      if (line.startTime == null) continue;

      final isInRange = position >= line.startTime! &&
          (line.endTime == null || position <= line.endTime!);

      if (isInRange && i != _lastSyncedLine) {
        _lastSyncedLine = i;
        textProvider.setCurrentLine(i);
        return i;
      }
    }
    return -1;
  }

  void setScrolling(bool value) {
    _isScrolling = value;
  }

  // ===== SCROLL LOGIC =====
  void scrollToLine(
    ScrollController controller,
    int index, {
    double estimatedLineHeight = 85.0,
    bool animated = true,
  }) {
    if (!controller.hasClients) return;

    final targetOffset = index * estimatedLineHeight;
    final viewportHeight = controller.position.viewportDimension;
    // Đặt dòng mục tiêu ở 1/3 trên viewport
    final scrollTo = (targetOffset - viewportHeight / 3)
        .clamp(0.0, controller.position.maxScrollExtent);

    _isScrolling = true;

    if (animated) {
      controller
          .animateTo(
            scrollTo,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          )
          .then((_) => _isScrolling = false);
    } else {
      controller.jumpTo(scrollTo);
      _isScrolling = false;
    }
  }

  // ===== FLOATING MENU =====
  void showFloatingMenu(OverlayEntry entry, BuildContext context) {
    removeFloatingMenu();
    _floatingOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void removeFloatingMenu() {
    try {
      _floatingOverlay?.remove();
    } catch (_) {}
    _floatingOverlay = null;
  }

  // ===== TEXT SELECTION =====
  void handleTextSelection({
    required TextSelection selection,
    required String content,
    required int lineStartOffset,
    required int lineIndex,
  }) {
    if (selection.baseOffset == selection.extentOffset) return;

    final start = selection.start;
    final end = selection.end;
    final selectedText = content.substring(start, end);

    textProvider.selectTextWithOffsets(
      text: selectedText,
      startOffset: lineStartOffset + start,
      endOffset: lineStartOffset + end,
      lineIndex: lineIndex,
    );
  }

  /// Tính offset bắt đầu của 1 dòng trong toàn bộ text
  int getLineStartOffset(int lineIndex) {
    int offset = 0;
    for (int i = 0; i < lineIndex && i < textProvider.lines.length; i++) {
      offset += textProvider.lines[i].content.length + 1;
    }
    return offset;
  }

  // ===== LINE ACTIONS =====
  void jumpToLineAudio(int lineIndex) {
    final line = textProvider.lines[lineIndex];
    if (line.startTime != null && playerProvider.currentSongPath != null) {
      playerProvider.seek(line.startTime!);
      playerProvider.play();
    }
  }

  void bookmarkLine(int lineIndex) {
    final line = textProvider.lines[lineIndex];
    final offset = getLineStartOffset(lineIndex);
    textProvider.selectTextWithOffsets(
      text: line.content,
      startOffset: offset,
      endOffset: offset + line.content.length,
      lineIndex: lineIndex,
    );
  }

  // ===== CLEANUP =====
  @override
  void dispose() {
    removeFloatingMenu();
    _readingTimer?.cancel();
    super.dispose();
  }
}
