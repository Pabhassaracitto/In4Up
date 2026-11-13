// lib/core/platform/system_tts/system_tts_protocol.dart
//
// PSRC-221 — giao thức MethodChannel giữa `In4UpTtsService` (Kotlin, engine
// "Chuyển văn bản thành giọng nói" của Android) và worker Dart chạy trong
// engine Flutter NỀN.
//
// MỘT nguồn sự thật cho tên channel / method / khoá payload. Phía Kotlin
// (`android/app/src/main/kotlin/com/in4up/systemtts/SystemTtsRuntime.kt`) chép
// đúng các chuỗi này; `test/system_tts/system_tts_contract_test.dart` đọc file
// Kotlin và so từng chuỗi ⇒ đổi một bên mà quên bên kia là CI đỏ.
//
// File THUẦN Dart (không import Flutter) để test chạy trên host VM.

class SystemTtsProtocol {
  SystemTtsProtocol._();

  /// Channel duy nhất giữa service native và worker Dart.
  static const String channel = 'in4up/system_tts';

  /// Thư viện + hàm entrypoint mà native tra bằng CHUỖI.
  static const String dartLibrary =
      'package:in4up/core/platform/system_tts/system_tts_entrypoint.dart';
  static const String dartEntrypoint = 'in4upSystemTtsMain';

  // ── Dart → native ────────────────────────────────────────────────────────
  /// Worker đã gắn handler; kèm danh sách giọng ([keyVoices]).
  static const String methodReady = 'ready';

  /// Một khối PCM 16-bit mono của yêu cầu đang đọc. Native trả `true` khi đã
  /// ghi xong khối cho Android, `false` khi yêu cầu đã bị dừng.
  static const String methodAudio = 'audio';

  // ── native → Dart ────────────────────────────────────────────────────────
  /// Quét lại giọng trên đĩa, trả `List<Map>` (mỗi phần tử: name + locale).
  static const String methodListVoices = 'listVoices';

  /// Đọc một đoạn văn bản. Trả `Map` có [keyStatus] (+ [keyMessage]).
  static const String methodSynthesize = 'synthesize';

  /// Dừng yêu cầu [keyRequestId] (Android gọi `onStop`).
  static const String methodCancel = 'cancel';

  // ── khoá payload ─────────────────────────────────────────────────────────
  static const String keyRequestId = 'requestId';
  static const String keyText = 'text';
  static const String keyVoice = 'voice';
  static const String keyLocale = 'locale';
  static const String keyRate = 'rate';
  static const String keyPitch = 'pitch';
  static const String keySampleRate = 'sampleRate';
  static const String keyPcm = 'pcm';
  static const String keyVoices = 'voices';
  static const String keyName = 'name';
  static const String keyStatus = 'status';
  static const String keyMessage = 'message';

  // ── giá trị của [keyStatus] ──────────────────────────────────────────────
  static const String statusOk = 'ok';
  static const String statusCancelled = 'cancelled';

  /// Không có giọng offline nào cho ngôn ngữ được yêu cầu.
  static const String statusNoVoice = 'noVoice';

  /// Engine có giọng nhưng không tạo được âm thanh.
  static const String statusFailed = 'failed';
}
