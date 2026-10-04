// packages/in2up_stt/lib/stt_engine.dart
//
// in2up — Abstraction (Strategy Pattern) cho các STT engine.
//
// Mỗi engine (Whisper, Sherpa, Native mic...) implement interface này.
// SttServiceFacade dùng nó để switch engine mà không cần sửa logic bên ngoài.
//
// Thiết kế:
//   - File transcription (chính, cho LRC/karaoke): [transcribeFile]
//   - Live streaming mic (shadowing/live): [startListening]/[stopListening]
//   - Đặc tả năng lực: [capabilities]
//
// Các engine hiện tại:
//   - WhisperSttEngine  (file + chunked, mobile plugin / desktop FFI/CLI)
//   - NativeSttEngine   (live mic via speech_to_text, không transcribe file)

import 'dart:async';

import 'models/stt_result.dart';

/// Đặc tả năng lực của một engine — để facade chọn engine phù hợp task.
class SttEngineCapabilities {
  /// Có thể transcribe file audio (dùng cho Tạo lời thoại / LRC / karaoke).
  final bool supportsFileTranscription;

  /// Có hỗ trợ live mic streaming (shadowing / realtime).
  final bool supportsLiveMic;

  /// Có trả word-level timestamps (cho karaoke highlight).
  final bool supportsWordTimestamps;

  /// Có hỗ trợ offline hoàn toàn không.
  final bool supportsOffline;

  /// Có hỗ trợ chia nhỏ file dài (chunking) không.
  final bool supportsChunking;

  const SttEngineCapabilities({
    this.supportsFileTranscription = false,
    this.supportsLiveMic = false,
    this.supportsWordTimestamps = false,
    this.supportsOffline = false,
    this.supportsChunking = false,
  });
}

/// Kết quả một lần transcribe file (chuẩn hoá cho mọi engine).
class SttFileResult {
  final SttResult result;
  final bool success;
  final String? errorMessage;

  const SttFileResult({
    required this.result,
    this.success = true,
    this.errorMessage,
  });

  factory SttFileResult.failure(String error) => SttFileResult(
        result: SttResult.empty(SttEngineType.whisper),
        success: false,
        errorMessage: error,
      );
}

/// Interface chung cho mọi STT engine.
abstract class SttEngine {
  /// Tên engine (dùng cho log / debug).
  String get engineName;

  /// Năng lực của engine này.
  SttEngineCapabilities get capabilities;

  /// Khởi tạo (nạp model, init native). Không bắt buộc.
  Future<void> initialize() async {}

  /// Transcribe một file audio → SttResult (hoặc ném/trả lỗi).
  ///
  /// [config] tuỳ engine; các engine có thể bỏ qua các tham số không dùng.
  Future<SttResult> transcribeFile(
    String audioPath, {
    Map<String, dynamic>? options,
  });

  /// Live mic streaming — trả về Stream kết quả từng phần.
  /// Engine không hỗ trợ thì trả [Stream.empty].
  Stream<SttResult> get liveResultStream => const Stream.empty();

  /// Bắt đầu nghe mic (nếu [supportsLiveMic]).
  Future<bool> startListening({String language = 'en-US'}) async => false;

  /// Dừng nghe mic.
  Future<void> stopListening() async {}

  /// Giải phóng tài nguyên.
  Future<void> dispose() async {}
}
