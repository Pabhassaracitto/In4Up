// lib/features/tts/engines/tts_engine.dart

import 'dart:typed_data';

/// Kết quả TTS
class TtsResult {
  final Uint8List? audioData; // Raw audio bytes (MP3/WAV)
  final String? audioUrl; // URL stream trực tiếp
  final bool isSuccess;
  final String? error;
  final String engineName;
  final Duration responseTime;
  final TtsAudioSource source; // bytes hay url

  const TtsResult({
    this.audioData,
    this.audioUrl,
    required this.isSuccess,
    this.error,
    required this.engineName,
    this.responseTime = Duration.zero,
    this.source = TtsAudioSource.bytes,
  });

  factory TtsResult.successBytes({
    required Uint8List data,
    required String engine,
    Duration responseTime = Duration.zero,
  }) {
    return TtsResult(
      audioData: data,
      isSuccess: true,
      engineName: engine,
      responseTime: responseTime,
      source: TtsAudioSource.bytes,
    );
  }

  factory TtsResult.successUrl({
    required String url,
    required String engine,
    Duration responseTime = Duration.zero,
  }) {
    return TtsResult(
      audioUrl: url,
      isSuccess: true,
      engineName: engine,
      responseTime: responseTime,
      source: TtsAudioSource.url,
    );
  }

  factory TtsResult.failure({
    required String error,
    required String engine,
  }) {
    return TtsResult(
      isSuccess: false,
      error: error,
      engineName: engine,
    );
  }
}

enum TtsAudioSource { bytes, url, offline }

/// Thông tin giọng đọc
class TtsVoice {
  final String id;
  final String name;
  final String language; // 'vi-VN', 'en-US'
  final String gender; // 'male', 'female'
  final String engine;
  final bool isNeural; // Giọng AI neural hay không

  const TtsVoice({
    required this.id,
    required this.name,
    required this.language,
    required this.gender,
    required this.engine,
    this.isNeural = false,
  });

  @override
  String toString() => '$name ($gender, $engine)';
}

/// Interface cho mọi TTS engine
abstract class TtsEngine {
  /// Tên hiển thị
  String get name;

  /// ID
  String get id;

  /// Engine khả dụng?
  Future<bool> isAvailable();

  /// Tạo audio từ text
  Future<TtsResult> synthesize({
    required String text,
    required String language, // 'vi-VN', 'en-US'
    double speed = 1.0, // 0.25 - 2.0
    double pitch = 1.0, // 0.5 - 2.0
    String? voiceId, // Giọng cụ thể
  });

  /// Danh sách giọng hỗ trợ
  Future<List<TtsVoice>> getAvailableVoices(String language);

  /// Giới hạn ký tự mỗi request
  int get maxCharsPerRequest => 200;

  /// Ngôn ngữ hỗ trợ
  List<String> get supportedLanguages;
}
