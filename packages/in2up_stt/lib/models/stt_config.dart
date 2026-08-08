import 'stt_model_info.dart';
import 'stt_result.dart';

/// Cấu hình cho SttServiceFacade
class SttConfig {
  /// Engine ưu tiên khi gọi transcribe()
  final SttEngineType preferredEngine;

  /// Ngôn ngữ nhận diện (BCP-47: 'en-US', 'vi-VN', ...)
  final String language;

  /// Model Whisper sẽ dùng
  final WhisperModelLevel whisperModel;

  /// Có tự động fallback sang engine khác khi lỗi không
  final bool autoFallback;

  /// Có tạo file LRC sau khi Whisper transcribe không
  final bool generateLrc;

  /// Có lưu kết quả vào cache không
  final bool cacheResults;

  /// Có chia nhỏ file audio thành từng chunk để transcribe dần không.
  /// Bật lên để file dài không phải đợi hết: kết quả stream về từng chunk,
  /// có progress + có thể hủy giữa chừng.
  final bool enableChunking;

  /// Độ dài mỗi chunk (giây). Whisper vốn xử lý theo cửa sổ ~30s.
  final int chunkDurationSeconds;

  /// Số chunk tối đa cho phép trước khi yêu cầu chọn tải theo chặng
  /// (bảo vệ file cực dài, tránh chờ quá lâu). 0 = không giới hạn.
  final int maxChunks;

  const SttConfig({
    this.preferredEngine = SttEngineType.native,
    this.language = 'en-US',
    // ★ TASK 1: Đổi default từ base → tiny để khởi động nhanh hơn
    this.whisperModel = WhisperModelLevel.tiny,
    this.autoFallback = true,
    this.generateLrc = false,
    this.cacheResults = true,
    this.enableChunking = true,
    this.chunkDurationSeconds = 30,
    this.maxChunks = 0,
  });

  /// Config nhanh cho "ghi chú tức thì" - dùng Native
  static const quickNote = SttConfig(
    preferredEngine: SttEngineType.native,
    autoFallback: false,
    generateLrc: false,
  );

  /// Config cho "Deep Learning" - dùng Whisper Small + LRC
  static const deepLearning = SttConfig(
    preferredEngine: SttEngineType.whisper,
    whisperModel: WhisperModelLevel.small,
    autoFallback: true,
    generateLrc: true,
    cacheResults: true,
  );

  /// Config cân bằng - Whisper Base
  static const balanced = SttConfig(
    preferredEngine: SttEngineType.whisper,
    whisperModel: WhisperModelLevel.base,
    autoFallback: true,
    generateLrc: true,
  );

  SttConfig copyWith({
    SttEngineType? preferredEngine,
    String? language,
    WhisperModelLevel? whisperModel,
    bool? autoFallback,
    bool? generateLrc,
    bool? cacheResults,
    bool? enableChunking,
    int? chunkDurationSeconds,
    int? maxChunks,
  }) {
    return SttConfig(
      preferredEngine: preferredEngine ?? this.preferredEngine,
      language: language ?? this.language,
      whisperModel: whisperModel ?? this.whisperModel,
      autoFallback: autoFallback ?? this.autoFallback,
      generateLrc: generateLrc ?? this.generateLrc,
      cacheResults: cacheResults ?? this.cacheResults,
      enableChunking: enableChunking ?? this.enableChunking,
      chunkDurationSeconds: chunkDurationSeconds ?? this.chunkDurationSeconds,
      maxChunks: maxChunks ?? this.maxChunks,
    );
  }
}
