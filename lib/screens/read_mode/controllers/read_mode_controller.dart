// lib/screens/read_mode/controllers/read_mode_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport, RenderBox;
import 'package:in4up/core/platform/safe_haptics.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../../../services/storage_service.dart';
import '../services/read_line_sync.dart';

/// Controller quản lý business logic cho Read Mode
/// Tách khỏi UI để dễ test và maintain
class ReadModeController extends ChangeNotifier {
  final TextProvider textProvider;
  final PlayerProvider playerProvider;

  ReadModeController({
    required this.textProvider,
    required this.playerProvider,
  }) {
    final storage = StorageService();
    if (storage.isInitialized) {
      _singleLineMode = storage.getSetting<bool>('read_single_line', defaultValue: false) ?? false;
      _autoSyncEnabled = storage.getSetting<bool>('read_auto_sync', defaultValue: true) ?? true;
    }
    _init();
  }

  // ===== STATE =====
  bool _autoSyncEnabled = true;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool _singleLineMode = false;
  bool get singleLineMode => _singleLineMode;

  void setSingleLineMode(bool value) {
    if (_singleLineMode == value) return;
    _singleLineMode = value;
    final storage = StorageService();
    if (storage.isInitialized) unawaited(storage.saveSetting('read_single_line', value));
    notifyListeners();
  }

  int _lastSyncedLine = -1;
  bool _isScrolling = false;

  /// True khi đang chạy animation tự cuộn (UI có thể dùng để ẩn gợi ý).
  bool get isScrolling => _isScrolling;

  /// GlobalKey theo chỉ số dòng — PSRC-233: cần `RenderObject` THẬT của dòng
  /// để cuộn tới đúng nó (thay cho `index * 85.0`).
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};

  /// Dòng đặt ở 28% chiều cao viewport (trên 1/3 một chút ⇒ còn thấy cả câu
  /// trước và vài câu sau).
  static const double _lineAnchorAlignment = 0.28;

  /// Key ổn định cho item dòng [index] (cùng index ⇒ cùng key giữa các lần
  /// build; nếu key đổi, `currentContext` không còn trỏ tới item trên màn).
  GlobalKey lineKey(int index) => _lineKeys.putIfAbsent(
        index,
        () => GlobalKey(debugLabel: 'read_line_$index'),
      );

  // Floating menu
  OverlayEntry? _floatingOverlay;
  bool get hasFloatingMenu => _floatingOverlay != null;

  // Reading progress
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
    final storage = StorageService();
    if (storage.isInitialized) unawaited(storage.saveSetting('read_auto_sync', _autoSyncEnabled));
    SafeHaptics.selectionClick();
    notifyListeners();
  }

  /// Gọi từ audio position listener. Trả về chỉ số dòng đang phát, hoặc -1.
  ///
  /// PSRC-233 — bản cũ tự dò `position >= start && position <= end` và:
  ///   * dùng `endTime` ĐÃ LƯU (với LRC song ngữ, `_parseLrc` gán
  ///     `endTime = startTime` của dòng kế ⇒ dòng đầu của cặp có cửa sổ 0
  ///     giây, gần như không bao giờ khớp ⇒ bỏ câu / nhảy cóc sang bản dịch);
  ///   * trả -1 khi `_isScrolling` (tức là trong suốt 400 ms animation tự
  ///     cuộn ⇒ câu tiếp theo bị mất highlight).
  /// Nay phép chọn dòng nằm trong `lineIndexForPosition` (hàm thuần, có test)
  /// và cuộn không còn chặn highlight.
  int checkAudioSync(Duration position) {
    if (!_autoSyncEnabled) return -1;
    if (!textProvider.hasLyrics) return -1;

    final lines = textProvider.lines;
    final index = lineIndexForPosition(
      starts: [for (final line in lines) line.startTime],
      ends: [for (final line in lines) line.endTime],
      position: position,
    );
    if (index < 0) return -1;

    // `_lastSyncedLine` chỉ để khỏi notify thừa, KHÔNG phải điều kiện để
    // highlight — trả index cho caller để nó biết dòng đang phát.
    if (index != _lastSyncedLine || index != textProvider.currentLineIndex) {
      _lastSyncedLine = index;
      textProvider.setCurrentLine(index);
    }
    return index;
  }

  void setScrolling(bool value) {
    _isScrolling = value;
  }

  // ===== SCROLL LOGIC =====
  /// Cuộn danh sách tới dòng [index] — **đúng item thật**, không ước lượng.
  ///
  /// PSRC-233: `index * 85.0` giả định mọi dòng cao bằng nhau. Thực tế dòng
  /// xuống hàng / song ngữ / phiên âm IPA / LRC cao gấp 2–4 lần ⇒ cuộn tới
  /// sai chỗ, càng về cuối càng lệch (owner: «không nhảy chính xác đến đoạn
  /// thực tế đang phát»).
  ///
  /// Nay:
  ///   1. item đã build ⇒ `RenderAbstractViewport.getOffsetToReveal` cho
  ///      offset CHÍNH XÁC của chính item đó;
  ///   2. item chưa build (ListView lười) ⇒ nhảy tới vị trí ước lượng để
  ///      ListView dựng tới đó, rồi TINH CHỈNH ngay frame sau bằng (1).
  void scrollToLine(
    ScrollController controller,
    int index, {
    double estimatedLineHeight = 85.0,
    bool animated = true,
  }) {
    if (!controller.hasClients || index < 0) return;
    unawaited(_revealLine(
      controller,
      index,
      estimatedLineHeight: estimatedLineHeight,
      animated: animated,
    ));
  }

  Future<void> _revealLine(
    ScrollController controller,
    int index, {
    required double estimatedLineHeight,
    required bool animated,
  }) async {
    _isScrolling = true;
    try {
      final exact = _measuredOffset(controller, index);
      if (exact != null) {
        await _animateOrJump(controller, exact, animated);
        return;
      }

      final estimate = estimatedLineOffset(
        index: index,
        lineHeight: estimatedLineHeight,
        viewportHeight: controller.position.viewportDimension,
        maxScrollExtent: controller.position.maxScrollExtent,
        alignment: _lineAnchorAlignment,
      );
      await _animateOrJump(controller, estimate, animated);

      // Vừa cuộn tới vùng lân cận ⇒ chờ frame vẽ để item có context rồi
      // tinh chỉnh (tối đa 2 vòng; hết vòng vẫn không có thì thôi, không
      // cuộn tiếp để tránh "giật" khi người dùng đang kéo tay).
      for (var attempt = 0; attempt < 2; attempt++) {
        // Chờ 1 frame nhưng KHÔNG chờ vô hạn: nếu không có frame nào được
        // lên lịch (màn bị che / test), `endOfFrame` không bao giờ hoàn tất
        // và cờ `_isScrolling` sẽ treo lại.
        await WidgetsBinding.instance.endOfFrame.timeout(
          const Duration(milliseconds: 150),
          onTimeout: () {},
        );
        if (!controller.hasClients) return;
        final refined = _measuredOffset(controller, index);
        if (refined == null) continue;
        if ((refined - controller.offset).abs() <= 1.0) return;
        await _animateOrJump(controller, refined, false);
        return;
      }
    } catch (error) {
      debugPrint('[ReadModeController] scrollToLine($index) lỗi: $error');
    } finally {
      _isScrolling = false;
    }
  }

  /// Offset CHÍNH XÁC của dòng [index] nếu item đã được build, ngược lại null.
  double? _measuredOffset(ScrollController controller, int index) {
    final context = _lineKeys[index]?.currentContext;
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    final offset =
        viewport.getOffsetToReveal(box, _lineAnchorAlignment).offset;
    if (!offset.isFinite) return null;
    if (!controller.hasClients) return null;
    return offset
        .clamp(0.0, controller.position.maxScrollExtent)
        .toDouble();
  }

  Future<void> _animateOrJump(
    ScrollController controller,
    double offset,
    bool animated,
  ) async {
    if (!controller.hasClients) return;
    final target =
        offset.clamp(0.0, controller.position.maxScrollExtent).toDouble();
    if (animated) {
      await controller.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else if ((controller.offset - target).abs() > 0.5) {
      controller.jumpTo(target);
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

  // ===== FOCUS MODE FOR SMALL SCREENS =====
  bool _isFocusMode = false;
  bool get isFocusMode => _isFocusMode;

  void toggleFocusMode() {
    _isFocusMode = !_isFocusMode;
    SafeHaptics.selectionClick();
    notifyListeners();
  }

  void setFocusMode(bool value) {
    if (_isFocusMode != value) {
      _isFocusMode = value;
      notifyListeners();
    }
  }

  /// AUDIT-2026-10-20 (mục 1): báo cho UI biết "cấu hình đã đổi, hãy đọc
  /// lại" — dùng khi sheet Cài đặt đóng lại (ví dụ vị trí phần TIÊU ĐỀ khi
  /// ở chế độ Focus: Ẩn / Trên / Dưới) để thay đổi có hiệu lực NGAY mà
  /// không phải mở lại app.
  ///
  /// Không đụng `isFocusMode` (nó đã có `toggleFocusMode`/`setFocusMode`).
  void requestRefresh() {
    notifyListeners();
  }

  // ===== CLEANUP =====
  @override
  void dispose() {
    removeFloatingMenu();
    _readingTimer?.cancel();
    _lineKeys.clear();
    super.dispose();
  }
}
