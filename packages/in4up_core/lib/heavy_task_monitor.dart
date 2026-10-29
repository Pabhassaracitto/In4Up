// packages/in4up_core/lib/heavy_task_monitor.dart
//
// QA-PERF-001 — Giám sát tác vụ "nặng" (CPU/pin cao) chạy ĐỒNG THỜI trên
// nhiều module độc lập (AI chat local, dịch offline Hy-MT, Whisper on-device,
// TTS). Mỗi module tự quản lý concurrency RIÊNG (xem HyMtSlot, hàng đợi chat
// của AiServiceFacade, AsyncMutex của SttServiceFacade) nhưng KHÔNG module
// nào biết module khác có đang chạy hay không.
//
// Vì sao cần: in4up có tính năng xin miễn "tối ưu pin" (BATTERY-OPT-001) để
// STT/AI/audio chạy nền không bị hệ thống giết — nghĩa là KHÔNG còn lưới an
// toàn của Android (Doze/App Standby) nếu 2-3 engine native (mỗi engine tự
// spawn isolate + load model trăm MB + chạy nhiều luồng CPU) cùng chạy một
// lúc. Hệ quả thực tế đã thấy trong code: AiEngineGemma có hẳn cơ chế phục
// hồi khi isolate bị OOM killer thu hồi — tức là kịch bản "nhiều engine nặng
// cùng lúc → hết RAM/CPU" đã từng xảy ra.
//
// Lớp này KHÔNG chặn (block) bất kỳ tác vụ nào — mục tiêu là QUAN SÁT để:
//   1. UI có thể cảnh báo người dùng khi phát hiện ≥2 LOẠI tác vụ nặng khác
//      nhau đang chạy chồng lên nhau (nguy cơ nóng máy / tụt pin nhanh).
//   2. QA/telemetry sau này có chỗ gắn log/analytics mà không phải sửa từng
//      engine.
//   3. Mỗi engine chỉ cần bọc đúng 1 lệnh gọi (`track`) tại điểm đã có sẵn
//      try/finally — rủi ro thay đổi hành vi gần như bằng 0 (không throw,
//      không block, không giữ lock).
//
// Thiết kế: Dart isolate không chia sẻ memory, nên lớp này chỉ thấy được
// các tác vụ chạy trên MAIN/UI isolate (nơi gọi `track`/`begin`/`end`) — đúng
// với cách AiServiceFacade/HyMtEngine/SttServiceFacade hiện đưa yêu cầu vào
// isolate con rồi `await` kết quả trên main isolate, nên khoảng thời gian
// "đang chờ isolate xử lý" vẫn được tính đúng là "đang bận".
library heavy_task_monitor;

import 'package:flutter/foundation.dart';

/// Các loại tác vụ "nặng" đã biết trong app — thêm loại mới khi có engine
/// CPU/pin cao khác (vd OCR hàng loạt, export video).
enum HeavyTaskKind {
  /// Chat với AI local (Gemma GGUF qua llama.cpp, isolate riêng).
  aiChatLocal,

  /// Phân tích câu/từ bằng AI local (Write Studio, Word Lookup…).
  aiAnalysisLocal,

  /// Dịch offline bằng Hy-MT (model GGUF riêng, llama.cpp isolate riêng —
  /// ĐỘC LẬP với engine AI chat ở trên, có thể cùng chạy một lúc).
  translateOffline,

  /// Bóc băng bằng Whisper on-device (isolate FFI hoặc plugin mobile).
  sttWhisper,

  /// Tổng hợp giọng nói offline (Piper qua sherpa-onnx).
  ttsSynthesis,
}

/// Singleton theo dõi số tác vụ nặng đang chạy theo từng loại trên MAIN
/// isolate. An toàn gọi từ bất kỳ đâu (Flutter main isolate only).
class HeavyTaskMonitor extends ChangeNotifier {
  HeavyTaskMonitor._internal();

  static final HeavyTaskMonitor instance = HeavyTaskMonitor._internal();

  final Map<HeavyTaskKind, int> _active = <HeavyTaskKind, int>{};

  /// Tổng số tác vụ đang chạy (đếm cả trùng loại — vd 2 lượt Whisper xếp
  /// hàng nối tiếp trong AsyncMutex không tính là "chạy cùng lúc" vì chỉ 1
  /// lượt thật sự `begin()` tại một thời điểm).
  int get activeCount => _active.values.fold(0, (sum, v) => sum + v);

  /// Các LOẠI tác vụ đang có ít nhất 1 lượt chạy.
  Set<HeavyTaskKind> get activeKinds => _active.entries
      .where((e) => e.value > 0)
      .map((e) => e.key)
      .toSet();

  /// Đáng cảnh báo khi có ≥2 LOẠI tác vụ KHÁC NHAU chạy chồng — đây là lúc
  /// ≥2 engine native độc lập (vd Gemma chat + Hy-MT dịch) cùng chiếm CPU,
  /// khác với việc cùng 1 engine xử lý nhiều job nối tiếp.
  bool get hasOverlappingHeavyTasks => activeKinds.length >= 2;

  int countOf(HeavyTaskKind kind) => _active[kind] ?? 0;

  bool isActive(HeavyTaskKind kind) => countOf(kind) > 0;

  /// Đánh dấu 1 lượt [kind] bắt đầu chạy. PHẢI gọi [end] đúng 1 lần tương
  /// ứng (dùng [track] để tự đảm bảo qua try/finally thay vì gọi tay).
  void begin(HeavyTaskKind kind) {
    _active[kind] = (_active[kind] ?? 0) + 1;
    notifyListeners();
  }

  /// Kết thúc 1 lượt [kind]. Gọi thừa (không khớp begin) chỉ no-op an toàn
  /// (không âm số đếm) — phòng lỗi lập trình ở nơi gọi không làm hỏng state
  /// chung.
  void end(HeavyTaskKind kind) {
    final current = _active[kind] ?? 0;
    if (current <= 1) {
      _active.remove(kind);
    } else {
      _active[kind] = current - 1;
    }
    notifyListeners();
  }

  /// Chạy [action] trong khi đánh dấu [kind] đang hoạt động. Luôn gọi
  /// [end] kể cả khi [action] throw — không bao giờ "quên nhả" làm monitor
  /// báo sai mãi mãi.
  Future<T> track<T>(HeavyTaskKind kind, Future<T> Function() action) async {
    begin(kind);
    try {
      return await action();
    } finally {
      end(kind);
    }
  }

  /// Chỉ dùng trong test: xoá sạch state giữa các test case.
  @visibleForTesting
  void debugReset() {
    _active.clear();
  }
}
