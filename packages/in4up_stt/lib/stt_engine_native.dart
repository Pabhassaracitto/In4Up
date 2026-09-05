// packages/in4up_stt/lib/stt_engine_native.dart
// Patch v11.0 — thêm audioFingerprint vào SttResult,
//               thêm uid vào SttSegment (Content-Anchored)

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'models/content_id.dart';
import 'models/stt_result.dart';

class SttEngineNative {
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;
  String? _lastError;

  final _resultController = StreamController<SttResult>.broadcast();
  Stream<SttResult> get resultStream => _resultController.stream;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  /// Lý do gần nhất init/listen thất bại (để UI — vd cabin — chẩn đoán).
  String? get lastError => _lastError;

  // ── Initialization ────────────────────────────────────────

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _stt.initialize(
        onError: (e) {
          // Lỗi TRONG phiên (service bị kill, network drop...) — lưu lại
          // để UI thấy lý do thay vì im lặng.
          _lastError = e.errorMsg?.isNotEmpty == true
              ? 'STT session: ${e.errorMsg}'
              : 'STT session error (${e.errorType})';
          debugPrint('❌ Native STT error: ${e.errorMsg}');
        },
        onStatus: (s) => debugPrint('📢 Native STT status: $s'),
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        _lastError = null;
        debugPrint('✅ Native STT initialized');
        final locales = await _stt.locales();
        debugPrint(
          '   Locales: '
          '${locales.map((l) => l.localeId).take(5).join(', ')}...',
        );
      } else {
        _lastError =
            'Native STT init thất bại — chưa cấp quyền microphone HOẶC máy '
            'không có dịch vụ nhận diện giọng nói (Speech Recognition).';
        debugPrint('❌ Native STT init failed '
            '(microphone permission may be missing)');
      }
    } catch (e) {
      debugPrint('❌ Native STT init error: $e');
      _lastError = 'Native STT init exception: $e';
      _isInitialized = false;
    }

    return _isInitialized;
  }

  // ── Live Listening ────────────────────────────────────────

  Future<bool> startListening({
    String language = 'en-US',
    Duration? listenTimeout,
    Duration pauseTimeout = const Duration(seconds: 3),
    ListenMode listenMode = ListenMode.confirmation,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    // SELF-HEAL: phiên nghe cũ còn treo (flow khác start mà không stop,
    // hoặc lần trước chưa dừng sạch) → plugin native sẽ trả FALSE cho
    // listen mới ("isListening" bên native). Hủy sạch phiên cũ trước.
    if (_isListening) {
      debugPrint('🧹 Native STT: session cũ còn mở — cancel trước khi start');
      await cancelListening();
    }

    try {
      String? targetLocaleId = language;
      try {
        final locales = await _stt.locales();
        if (locales.isNotEmpty) {
          final exact = locales.where((l) =>
              l.localeId.toLowerCase().replaceAll('_', '-') ==
              language.toLowerCase().replaceAll('_', '-'));
          if (exact.isNotEmpty) {
            targetLocaleId = exact.first.localeId;
          } else {
            final prefix = language.split(RegExp(r'[-_]')).first.toLowerCase();
            final byPrefix = locales.where(
                (l) => l.localeId.toLowerCase().startsWith(prefix));
            if (byPrefix.isNotEmpty) {
              targetLocaleId = byPrefix.first.localeId;
            } else {
              targetLocaleId = null; // fallback to system default
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Native STT locale discovery note: $e');
      }

      var started = await _stt.listen(
        localeId: targetLocaleId,
        // listenFor = null → KHÔNG có timer auto-stop 2 phút (live cabin
        // cần nghe liên tục; session do hệ thống + pauseFor quản lý).
        listenFor: listenTimeout,
        pauseFor: pauseTimeout,
        partialResults: true,
        onResult: (r) => _onNativeResult(r, language),
        cancelOnError: false,
        listenMode: listenMode,
      );

      if (!started && targetLocaleId != null) {
        debugPrint('⚠️ Native STT retry with default system locale');
        started = await _stt.listen(
          listenFor: listenTimeout,
          pauseFor: pauseTimeout,
          partialResults: true,
          onResult: (r) => _onNativeResult(r, language),
          cancelOnError: false,
          listenMode: listenMode,
        );
      }

      _isListening = started;
      if (started) {
        _lastError = null;
      } else {
        _lastError ??= 'Native STT listen thất bại cho "$language" và cả '
            'default locale — kiểm tra dịch vụ nhận diện giọng nói của máy '
            '(Cài đặt → Ứng dụng → Google/Samsung: Speech Services).';
      }
      debugPrint('🎤 Native STT listening: $started');
      return started;
    } catch (e) {
      debugPrint('❌ Native STT startListening error: $e');
      _lastError = 'Native STT startListening exception: $e';
      _isListening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
    debugPrint('🛑 Native STT stopped');
  }

  Future<void> cancelListening() async {
    await _stt.cancel();
    _isListening = false;
  }

  // ── File Transcription ────────────────────────────────────

  /// Native STT không hỗ trợ transcribe file.
  /// Trả về SttResult rỗng để Facade fallback sang Whisper.
  ///
  /// ★ PATCH v11: thêm audioFingerprint (hash từ path)
  ///              SttSegment không tạo vì rỗng → không cần uid
  Future<SttResult> transcribeFile(
    String audioPath, {
    String language = 'en-US',
  }) async {
    debugPrint(
      '⚠️ Native STT không hỗ trợ file. '
      'Fallback Whisper: $audioPath',
    );

    // Tạo fingerprint nhẹ từ path (không đọc file — non-blocking)
    final fp = _quickFingerprint(audioPath);

    return SttResult(
      fullText: '',
      segments: const [],
      engineUsed: SttEngineType.native,
      language: language,
      processingTime: Duration.zero,
      audioFingerprint: fp, // ★ v11: bắt buộc
      hasWordTimestamps: false,
    );
  }

  // ── Callbacks ─────────────────────────────────────────────

  void _onNativeResult(
    SpeechRecognitionResult result,
    String language,
  ) {
    if (_resultController.isClosed) return;

    final recognizedText = result.recognizedWords;
    if (recognizedText.isEmpty) return;

    // Fingerprint cho live result: dùng timestamp hiện tại
    final fp =
        _quickFingerprint('live_${DateTime.now().millisecondsSinceEpoch}');

    final startMs = 0;
    final uid = ContentId.segmentUid(
      audioFingerprint: fp,
      startMs: startMs,
      text: recognizedText,
    );

    final words = recognizedText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final sttResult = SttResult(
      fullText: recognizedText,
      segments: [
        SttSegment(
          id: 0,
          uid: uid, // ★ v11: Content-Anchored UID
          startSeconds: 0,
          endSeconds: 0,
          text: recognizedText,
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
      audioFingerprint: fp, // ★ v11
      hasWordTimestamps: false,
    );

    _resultController.add(sttResult);
  }

  // ── Utility ───────────────────────────────────────────────

  Future<List<String>> getSupportedLocales() async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return [];
    final locales = await _stt.locales();
    return locales.map((l) => l.localeId).toList();
  }

  Future<bool> checkAvailability() async => _stt.hasPermission;

  void dispose() {
    _stt.cancel();
    _resultController.close();
  }

  // ── Private helpers ───────────────────────────────────────

  /// Fingerprint nhanh không cần đọc file (dùng cho Native/Live)
  static String _quickFingerprint(String seed) {
    final raw = utf8.encode(seed);
    return md5.convert(raw).toString().substring(0, 16);
  }
}
