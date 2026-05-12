import 'stt_model_info.dart';

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

  const SttConfig({
    this.preferredEngine = SttEngineType.native,
    this.language = 'en-US',
    this.whisperModel = WhisperModelLevel.base,
    this.autoFallback = true,
    this.generateLrc = false,
    this.cacheResults = true,
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
  }) {
    return SttConfig(
      preferredEngine: preferredEngine ?? this.preferredEngine,
      language: language ?? this.language,
      whisperModel: whisperModel ?? this.whisperModel,
      autoFallback: autoFallback ?? this.autoFallback,
      generateLrc: generateLrc ?? this.generateLrc,
      cacheResults: cacheResults ?? this.cacheResults,
    );
  }
}
