import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'models/stt_result.dart';

/// Engine Native - dùng speech_to_text
/// Ưu tiên cho "ghi chú nhanh" - không cần internet, phản hồi tức thì
class SttEngineNative {
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;

  /// Stream kết quả real-time (dùng cho live transcription)
  final _resultController =
      StreamController<SttResult>.broadcast();
  Stream<SttResult> get resultStream => _resultController.stream;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  // ─── Initialization ───────────────────────────────────────────────────────

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _stt.initialize(
        onError: (error) => debugPrint('❌ Native STT error: ${error.errorMsg}'),
        onStatus: (status) => debugPrint('📢 Native STT status: $status'),
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        debugPrint('✅ Native STT initialized');
        final locales = await _stt.locales();
        debugPrint(
            '   Available locales: ${locales.map((l) => l.localeId).take(5).join(', ')}...');
      } else {
        debugPrint('❌ Native STT initialization failed '
            '(microphone permission may be missing)');
      }
    } catch (e) {
      debugPrint('❌ Native STT init error: $e');
      _isInitialized = false;
    }

    return _isInitialized;
  }

  // ─── Live Listening ───────────────────────────────────────────────────────

  /// Bắt đầu lắng nghe microphone real-time
  /// Dùng cho tính năng "Shadowing" và "Quick Note"
  Future<bool> startListening({
    String language = 'en-US',
    Duration? listenTimeout,
    Duration pauseTimeout = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_isListening) return true;

    try {
      final started = await _stt.listen(
        localeId: language,
        listenFor: listenTimeout ?? const Duration(minutes: 2),
        pauseFor: pauseTimeout,
        partialResults: true,
        onSoundLevelChange: (level) {
          // Có thể emit sound level cho waveform visualization
        },
        onResult: (result) => _onNativeResult(result, language),
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );

      _isListening = started;
      debugPrint('🎤 Native STT listening started: $started');
      return started;
    } catch (e) {
      debugPrint('❌ Native STT startListening error: $e');
      return false;
    }
  }

  /// Dừng lắng nghe
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
    debugPrint('🛑 Native STT stopped');
  }

  /// Huỷ lắng nghe
  Future<void> cancelListening() async {
    await _stt.cancel();
    _isListening = false;
  }

  // ─── File Transcription ───────────────────────────────────────────────────

  /// Transcribe từ file audio (simulate - Native STT không hỗ trợ trực tiếp)
  /// Đây là wrapper để SttServiceFacade có API nhất quán
  /// 
  /// NOTE: speech_to_text không hỗ trợ transcribe file trực tiếp.
  /// Dùng cho compatibility. Với file, ưu tiên dùng Whisper.
  Future<SttResult> transcribeFile(
    String audioPath, {
    String language = 'en-US',
  }) async {
    debugPrint(
        '⚠️ Native STT không hỗ trợ transcribe file trực tiếp. '
        'Sử dụng Whisper để xử lý file: $audioPath');

    // Trả về kết quả rỗng để Facade có thể fallback sang Whisper
    return SttResult(
      fullText: '',
      segments: const [],
      engineUsed: SttEngineType.native,
      language: language,
      processingTime: Duration.zero,
      hasWordTimestamps: false,
    );
  }

  // ─── Callbacks ───────────────────────────────────────────────────────────

  void _onNativeResult(
    SpeechRecognitionResult result,
    String language,
  ) {
    if (_resultController.isClosed) return;

    // Chuyển đổi SpeechRecognitionResult → SttResult
    final words = result.recognizedWords
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Native STT không có word timestamps → tạo segment đơn giản
    final sttResult = SttResult(
      fullText: result.recognizedWords,
      segments: [
        SttSegment(
          id: 0,
          startSeconds: 0,
          endSeconds: 0,
          text: result.recognizedWords,
          words: words
              .map((w) => SttWord(
                    word: w,
                    startSeconds: 0,
                    endSeconds: 0,
                    confidence: result.confidence,
                  ))
              .toList(),
          avgConfidence: result.confidence,
        ),
      ],
      engineUsed: SttEngineType.native,
      language: language,
      processingTime: Duration.zero,
      hasWordTimestamps: false,
    );

    _resultController.add(sttResult);
  }

  // ─── Utility ─────────────────────────────────────────────────────────────

  /// Lấy danh sách ngôn ngữ hỗ trợ
  Future<List<String>> getSupportedLocales() async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return [];
    final locales = await _stt.locales();
    return locales.map((l) => l.localeId).toList();
  }

  /// Kiểm tra thiết bị có hỗ trợ không
  Future<bool> checkAvailability() async {
    return _stt.hasPermission;
  }

  void dispose() {
    _stt.cancel();
    _resultController.close();
  }
}
