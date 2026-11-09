// YT-TTS-READ-001 — đọc phụ đề (và **bản dịch**) thành tiếng trong chế độ
// YouTube.
//
// Vì sao không dùng lại `PlaybackController` của tab Đọc: bộ đó gắn với việc
// phát FILE âm thanh theo mốc thời gian `.lrc` (và đồng bộ với player). Ở
// YouTube, âm thanh là video trong iframe WebView — không tua/không lấy được
// PCM. Nên phần "đọc thành tiếng" ở đây chạy ĐỘC LẬP với video: nó đọc từng
// dòng phụ đề bằng TTS, theo đúng bộ tuỳ chọn owner yêu cầu (lặp mấy lần, xen
// kẽ, bên nhiều bên ít, khoảng nghỉ, tốc độ).
//
// Chất lượng/nguồn giọng do `TtsService` quyết (Piper offline, Edge/Google/
// API online) nên WiFi/4G/không mạng đều có đường chạy — xem
// `TtsPriority.auto`.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../tts/tts_service.dart';
import '../models/yt_learning_settings.dart';
import 'yt_read_aloud_sequence.dart';

class YtReadAloudController extends ChangeNotifier {
  YtReadAloudController(this._tts);

  final TtsService _tts;

  bool _running = false;
  bool get isRunning => _running;

  /// Dòng đang đọc (-1 = không đọc). UI dùng để tô sáng dòng.
  int _activeLine = -1;
  int get activeLine => _activeLine;

  /// Đang đọc bên nào: `source` | `target` — để UI hiện "gốc/dịch".
  String _activeSide = 'source';
  String get activeSide => _activeSide;

  /// Đang ở lượt thứ mấy của cả bài (1-based) và tổng số lượt.
  /// `_passTotal == null` ⇒ đọc mãi mãi.
  int _pass = 0;
  int? _passTotal;
  int get pass => _pass;
  int? get passTotal => _passTotal;

  int _epoch = 0;

  /// Đã huỷ controller chưa. KHÔNG được `notifyListeners()` sau khi dispose
  /// (Flutter ném lỗi "A YtReadAloudController was used after being disposed"),
  /// mà vòng đọc vẫn có thể đang chạy dở khi người dùng thoát màn.
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({
    required List<YtReadAloudLine> lines,
    required String sourceLangCode,
    required String targetLangCode,
    required YtLearningSettings settings,
    int startIndex = 0,
    bool stopCurrent = true,
  }) async {
    if (_running && stopCurrent) await stop();
    if (lines.isEmpty) return;

    final epoch = ++_epoch;
    _running = true;
    _activeLine = -1;
    _notify();

    // YT-READ-LOOP-LESSON-001 (#8): đọc lại CẢ BÀI theo `readAloudPasses`.
    // `0` = mãi mãi ⇒ `passTotal == null` (không có trần).
    final passTotal = ytPassCount(settings.readAloudPasses);
    final gap = Duration(milliseconds: settings.readAloudGapMs);
    final speed = settings.readAloudSpeed;

    var pass = 0;
    while (passTotal == null || pass < passTotal) {
      // Lượt đầu bắt đầu từ `startIndex`; các lượt sau đọc LẠI TỪ ĐẦU bài
      // (người dùng chọn "lặp bài" nghĩa là nghe trọn bài, không phải lặp
      // phần đuôi từ chỗ đang đứng).
      final steps = buildYtReadAloudSequence(
        lines: lines,
        settings: settings,
        startIndex: pass == 0 ? startIndex : 0,
      );
      if (steps.isEmpty) break;

      _pass = pass + 1;
      _passTotal = passTotal;
      _notify();

      for (var i = 0; i < steps.length; i++) {
        if (_isStale(epoch)) return;
        final step = steps[i];
        _activeLine = step.line;
        _activeSide = step.isTarget ? 'target' : 'source';
        _notify();

        if (!await _speak(
          step.text,
          step.isTarget ? targetLangCode : sourceLangCode,
          speed,
          epoch,
        )) {
          return;
        }
        if (i < steps.length - 1) await _gap(gap, epoch);
      }

      pass++;
      // Nghỉ giữa hai lượt bài lâu hơn giữa hai dòng để người dùng kịp
      // chuyển sang việc khác / bấm dừng trước khi bài đọc lại.
      if (passTotal == null || pass < passTotal) {
        await _gap(gap * 3, epoch);
      }
    }

    if (!_isStale(epoch)) {
      _running = false;
      _activeLine = -1;
      _notify();
    }
  }

  Future<void> stop() async {
    _epoch++;
    _running = false;
    _activeLine = -1;
    _pass = 0;
    _passTotal = null;
    _notify();
    await _tts.stop();
  }

  // ─── Nội bộ ───────────────────────────────────────────────────────

  bool _isStale(int epoch) => _disposed || epoch != _epoch || !_running;

  @override
  void dispose() {
    // Huỷ phiên TRƯỚC khi dispose: nếu không, vòng `for` đang chờ TTS sẽ gọi
    // `notifyListeners()` trên object đã chết ở bước kế tiếp.
    _disposed = true;
    _epoch++;
    final wasRunning = _running;
    _running = false;
    // Chỉ dừng TTS khi CHÍNH mình đang đọc. `_tts` là singleton dùng chung với
    // tab Đọc ⇒ dừng vô điều kiện sẽ cắt ngang việc đọc của tab khác.
    if (wasRunning) unawaited(_tts.stop());
    super.dispose();
  }

  /// Trả `false` khi phiên đã bị thay thế (đừng đọc tiếp).
  Future<bool> _speak(
    String text,
    String langCode,
    double speed,
    int epoch,
  ) async {
    try {
      // `configure` là cách DUY NHẤT đổi ngôn ngữ/giọng của TtsService — dùng
      // đúng như tab Đọc đang làm khi chuyển giọng gốc ↔ dịch.
      _tts.configure(language: langCode, speed: speed);
      await _tts.speak(text);
      // `speak()` trả về khi âm thanh được dựng; phải chờ đọc xong mới sang
      // lượt kế (nếu không thì các dòng chồng lên nhau).
      await _tts.waitForCompletion();
    } catch (e) {
      debugPrint('⚠️ [in4up-yt] đọc TTS lỗi: $e');
    }
    return !_isStale(epoch);
  }

  Future<void> _gap(Duration gap, int epoch) async {
    if (gap <= Duration.zero) return;
    // Chờ theo từng nhịp 100ms để `stop()` có hiệu lực ngay, không phải đợi
    // hết khoảng nghỉ (3s ở mức "tự kiểm tra").
    final end = DateTime.now().add(gap);
    while (DateTime.now().isBefore(end)) {
      if (_isStale(epoch)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
