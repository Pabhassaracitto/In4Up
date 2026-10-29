// lib/features/pdf_reader/services/pdf_tts_machine.dart
//
// I4U18-PDF-OCR-TTS-001 (Agent F · F3) — máy trạng thái Play/Pause/Stop/Next
// của thanh đọc to trong PDF Reader.
//
// Ba lỗi cũ, cùng MỘT gốc: không có ai làm trọng tài giữa các lần bấm.
//
//   1. `startReading()` là một vòng lặp async dài. Bấm Next gọi
//      `stopReading()` rồi `startReading()` mới — nhưng khối `finally` của
//      lần chạy CŨ chạy SAU đó và set `_readingActive = false`,
//      `_ttsState = idle`, đạp lên phiên MỚI vừa dựng. Phiên mới thấy cờ tắt
//      nên thoát ngay → "Stop rồi mà vẫn phát" / "Next chết cứng".
//   2. Callback `onLineChanged` của phiên cũ vẫn bắn vào `_readingCueIndex`
//      sau khi phiên mới đã bắt đầu → chỉ số nhảy nhiều dòng một lúc
//      ("lướt nhanh nhiều dòng").
//   3. Bấm hai lần thật nhanh (double-tap) chạy hai lần chuyển trạng thái
//      chồng nhau.
//
// Lời giải: MỘT số phiên tăng dần + MỘT cờ "đang chuyển trạng thái".
// Mọi tác dụng phụ (phát/dừng/tua) đều phải khai báo mình thuộc phiên nào;
// phiên cũ = không có quyền đổi gì nữa. Lớp này THUẦN DART, không đụng TTS
// hay Flutter, nên test được trực tiếp (test/pdf_reader/pdf_tts_machine_test).

/// Trạng thái hiển thị của thanh đọc.
enum PdfTtsState { idle, loading, playing, paused }

/// Việc mà controller phải làm sau một lần bấm nút.
enum PdfTtsCommand {
  /// Không làm gì (bấm trùng, hoặc đang bận chuyển trạng thái).
  none,

  /// Bắt đầu đọc từ trang/câu hiện tại.
  start,

  /// Tạm dừng âm đang phát (phải dừng THẬT, không chỉ đổi nhãn).
  pause,

  /// Phát tiếp từ chỗ đang dừng.
  resume,

  /// Dừng hẳn + chặn mọi callback phát tiếp.
  stop,

  /// Dừng phiên hiện tại rồi phát lại ĐÚNG một câu mục tiêu.
  restartAtCue,
}

class PdfTtsMachine {
  PdfTtsState _state = PdfTtsState.idle;
  int _session = 0;
  bool _busy = false;

  PdfTtsState get state => _state;

  /// Số phiên hiện tại. Mọi callback async phải kèm số này.
  int get session => _session;

  /// Đang có một lần chuyển trạng thái chạy dở (guard double-tap).
  bool get isBusy => _busy;

  /// Đang trong một phiên đọc (kể cả khi đang tạm dừng).
  bool get isActive => _state != PdfTtsState.idle;

  bool get isPlaying => _state == PdfTtsState.playing;
  bool get isPaused => _state == PdfTtsState.paused;

  /// True khi [session] là phiên đang sống — callback của phiên cũ phải im.
  bool isCurrent(int session) => session == _session && _state != PdfTtsState.idle;

  /// Bắt đầu một lần chuyển trạng thái. Trả về false nếu đang bận
  /// (double-tap / callback vào lại) — caller phải bỏ qua lần bấm đó.
  bool beginTransition() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void endTransition() => _busy = false;

  /// Mở một phiên mới và trả về số phiên của nó. Mọi phiên cũ lập tức hết
  /// hiệu lực (callback đến muộn bị [isCurrent] loại).
  int beginSession() {
    _session++;
    _state = PdfTtsState.loading;
    return _session;
  }

  /// Nút Play/Pause/Stop chính của thanh đọc.
  PdfTtsCommand onPlayPressed() {
    switch (_state) {
      case PdfTtsState.idle:
        return PdfTtsCommand.start;
      case PdfTtsState.playing:
        return PdfTtsCommand.pause;
      case PdfTtsState.paused:
        return PdfTtsCommand.resume;
      case PdfTtsState.loading:
        // Đang nạp câu: bấm lần nữa = đổi ý → dừng hẳn, không xếp hàng thêm
        // một phiên phát nữa.
        return PdfTtsCommand.stop;
    }
  }

  /// Nút Câu trước / Câu kế.
  ///
  /// Đang phát hoặc đang nạp → phát lại đúng câu mục tiêu (một câu, không
  /// lướt). Đang dừng/tạm dừng → chỉ dời con trỏ, giữ nguyên trạng thái.
  PdfTtsCommand onStepPressed() {
    if (_state == PdfTtsState.playing || _state == PdfTtsState.loading) {
      return PdfTtsCommand.restartAtCue;
    }
    return PdfTtsCommand.none;
  }

  /// Phiên [session] đã phát được câu đầu tiên.
  void markPlaying(int session) {
    if (session != _session) return;
    _state = PdfTtsState.playing;
  }

  void markPaused(int session) {
    if (session != _session || _state != PdfTtsState.playing) return;
    _state = PdfTtsState.paused;
  }

  void markResumed(int session) {
    if (session != _session || _state != PdfTtsState.paused) return;
    _state = PdfTtsState.playing;
  }

  /// Dừng hẳn: đổi phiên để mọi callback đang bay bị vô hiệu.
  void markStopped() {
    _session++;
    _state = PdfTtsState.idle;
  }

  /// Phiên [session] đọc xong / gặp lỗi. KHÔNG được đụng tới trạng thái nếu
  /// nó không còn là phiên hiện tại — đây chính là lỗi "finally của phiên cũ
  /// đạp lên phiên mới".
  void markFinished(int session) {
    if (session != _session) return;
    _state = PdfTtsState.idle;
  }
}
