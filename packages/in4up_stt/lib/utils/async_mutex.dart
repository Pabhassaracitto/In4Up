// packages/in4up_stt/lib/utils/async_mutex.dart
//
// QA-PERF-001 — Khoá tuần tự (single-flight) cho các tác vụ nặng chạy trên
// MAIN isolate (mỗi lượt tự spawn isolate/FFI riêng bên trong).
//
// Vì sao cần: AiServiceFacade (in4up_ai) đã có hàng đợi chat tuần tự
// (`_chatQueue`/`_drainChatQueue`) để không bao giờ 2 lượt chat chạy chồng
// lên engine Gemma cùng lúc. `SttServiceFacade.transcribeFile` KHÔNG có cơ
// chế tương đương: gọi `transcribeFile` 2 lần liên tiếp (vd 2 màn hình khác
// nhau cùng bóc băng, hoặc auto-TOC chạy nền trong lúc người dùng bấm bóc
// băng tay) spawn 2 Isolate Whisper ĐỘC LẬP — mỗi isolate tự load 1 bản
// model GGML riêng + chạy nhiều luồng CPU riêng. [AsyncMutex] đóng đúng gap
// này cho whisper on-device mà KHÔNG đổi public API của facade.
//
// Thiết kế: FIFO thuần Dart (không cần package bên ngoài) — mỗi lệnh gọi
// `run()` phải đợi lệnh gọi TRƯỚC nó hoàn tất (thành công hay lỗi) rồi mới
// được chạy; lỗi của một lượt không làm "kẹt" các lượt sau (hàng đợi luôn
// tiến tới dù lượt trước throw).
import 'dart:async';

class AsyncMutex {
  Future<void> _chain = Future<void>.value();

  /// Số lượt đang CHỜ (chưa tới lượt chạy) — 0 nghĩa là lượt tiếp theo được
  /// chạy ngay (không ai giữ khoá).
  int _waiting = 0;

  /// true khi có ít nhất 1 lượt đang giữ khoá hoặc đang chờ.
  bool get isBusy => _waiting > 0;

  /// Chạy [action] SAU KHI mọi lượt gọi `run()` trước đó (theo thứ tự gọi)
  /// đã hoàn tất. Trả về đúng kết quả/kết lỗi của [action] cho CALLER của
  /// lượt này — không ảnh hưởng tới kết quả của các lượt khác trong hàng
  /// đợi.
  Future<T> run<T>(Future<T> Function() action) {
    _waiting++;
    final previous = _chain;
    final gate = Completer<void>();
    _chain = gate.future;

    final result = previous.then((_) => action()).whenComplete(() {
      _waiting--;
      gate.complete();
    });
    return result;
  }
}
