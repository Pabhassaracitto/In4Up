import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/stt_service_facade.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/features/tts/tts_service.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';

/// Service điều phối toàn bộ Pipeline Dịch Cabin Trực tiếp (Speech Translation - STS).
///
/// **Luồng xử lý (theo PLAN-008 & WP1):**
/// 1. Thu âm qua Mic $\rightarrow$ STT Live Streaming (đoạn tạm & đoạn chốt).
/// 2. Debounce & chốt câu ngắn (1-3s).
/// 3. Dịch tự động song song qua [TranslationService] (Offline ML Kit / Online Engine).
/// 4. Phát âm bản dịch qua [TtsService] (Sherpa Piper TTS offline / System TTS) nếu bật Dubbing.
/// 5. Bắn luồng phụ đề song ngữ [CabinCaption] tới UI & Bong bóng nổi [LiveCaptionBubble].
class SttsCabinService extends ChangeNotifier {
  static final SttsCabinService _instance = SttsCabinService._internal();
  factory SttsCabinService() => _instance;
  static SttsCabinService get instance => _instance;

  SttsCabinService._internal();

  final SttServiceFacade _stt = SttServiceFacade();
  final TranslationService _translator = TranslationService();
  final TtsService _tts = TtsService();

  StreamSubscription? _sttSubscription;
  Timer? _silenceTimer;
  Timer? _keepAliveTimer;
  int _consecutiveStartFails = 0;
  bool _starting = false;

  CabinState _state = CabinState.idle;
  String _sourceLanguage = 'en';
  String _targetLanguage = 'vi';
  bool _isDubbingEnabled = false;
  CabinDisplayMode _displayMode = CabinDisplayMode.oneLine;
  String? _lastError;

  CabinCaption? _activeCaption;
  final List<CabinCaption> _history = [];

  final _captionStreamController = StreamController<CabinCaption>.broadcast();

  // ── Getters ───────────────────────────────────────────────────────────────
  CabinState get state => _state;
  bool get isListening => _state == CabinState.listening || _state == CabinState.translating || _state == CabinState.speaking;
  bool get isPaused => _state == CabinState.paused;
  bool get isDubbingEnabled => _isDubbingEnabled;
  CabinDisplayMode get displayMode => _displayMode;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;
  String? get lastError => _lastError;

  CabinCaption? get activeCaption => _activeCaption;
  List<CabinCaption> get history => List.unmodifiable(_history);
  Stream<CabinCaption> get captionStream => _captionStreamController.stream;

  bool get shouldShowBubble => isListening || isPaused;

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<bool> startCabin({
    String? sourceLang,
    String? targetLang,
    bool? dubbing,
  }) async {
    if (sourceLang != null) _sourceLanguage = sourceLang;
    if (targetLang != null) _targetLanguage = targetLang;
    if (dubbing != null) _isDubbingEnabled = dubbing;

    _lastError = null;

    // 1. Check microphone permission
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          _state = CabinState.error;
          _lastError = 'Chưa cấp quyền microphone.';
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      debugPrint('⚠️ SttsCabinService permission check error: $e');
    }

    // 2. Initialize STT Facade
    try {
      await _stt.initialize();
    } catch (e) {
      debugPrint('⚠️ SttsCabinService STT init warning: $e');
    }

    // Map source language to locale ID for STT
    final sttLocale = _mapToSttLocale(_sourceLanguage);

    _state = CabinState.listening;
    notifyListeners();

    try {
      final started = await _stt.startListening(language: sttLocale);
      if (!started) {
        _state = CabinState.error;
        _lastError = 'Không thể khởi động micro / nhận diện giọng nói.';
        notifyListeners();
        return false;
      }

      await _sttSubscription?.cancel();
      _sttSubscription = _stt.liveResultStream.listen(
        _onLiveSttResult,
        onError: (e) {
          debugPrint('❌ SttsCabinService STT stream error: $e');
          _lastError = '$e';
          _state = CabinState.error;
          notifyListeners();
        },
      );

      debugPrint('🎙️ SttsCabinService started ($sttLocale ➔ $_targetLanguage)');
      return true;
    } catch (e) {
      debugPrint('❌ SttsCabinService start error: $e');
      _state = CabinState.error;
      _lastError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> stopCabin() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _stopKeepAlive();
    _consecutiveStartFails = 0;
    await _sttSubscription?.cancel();
    _sttSubscription = null;

    try {
      await _stt.stopListening();
    } catch (_) {}

    _state = CabinState.idle;
    notifyListeners();
    debugPrint('🛑 SttsCabinService stopped');
  }

  Future<void> togglePause() async {
    if (_state == CabinState.paused) {
      await startCabin();
    } else if (isListening) {
      _silenceTimer?.cancel();
      try {
        await _stt.stopListening();
      } catch (_) {}
      _state = CabinState.paused;
      notifyListeners();
    }
  }

  void setDubbing(bool enabled) {
    _isDubbingEnabled = enabled;
    notifyListeners();
  }

  void setDisplayMode(CabinDisplayMode mode) {
    _displayMode = mode;
    notifyListeners();
  }

  void setSourceLanguage(String lang) {
    if (_sourceLanguage == lang) return;
    _sourceLanguage = lang;
    if (isListening) {
      // Restart with new source language
      startCabin();
    } else {
      notifyListeners();
    }
  }

  void setTargetLanguage(String lang) {
    _targetLanguage = lang;
    notifyListeners();
  }

  void swapLanguages() {
    final temp = _sourceLanguage;
    _sourceLanguage = _targetLanguage;
    _targetLanguage = temp;
    if (isListening) {
      startCabin();
    } else {
      notifyListeners();
    }
  }

  void clearHistory() {
    _history.clear();
    _activeCaption = null;
    notifyListeners();
  }

  Future<void> replayCaption(CabinCaption caption) async {
    final textToSpeak = caption.translatedText.isNotEmpty
        ? caption.translatedText
        : caption.sourceText;
    final langToSpeak = caption.translatedText.isNotEmpty
        ? caption.targetLang
        : caption.sourceLang;

    if (textToSpeak.trim().isEmpty) return;

    try {
      _tts.configure(language: langToSpeak);
      await _tts.speak(textToSpeak);
    } catch (e) {
      debugPrint('⚠️ Replay caption TTS error: $e');
    }
  }


  // ── BISECT DEAD CODE (Version B) ─────────────────────────
  Future<String> _buildStartFailureMessage() async {
    final detail = _stt.liveLastError ?? '';
    bool micOk = true;
    try {
      micOk = await _stt.checkLiveMicPermission();
    } catch (_) {}
    if (!micOk) {
      return 'Chưa có quyền microphone.';
    }
    return 'Không khởi động được${detail.isEmpty ? '' : ' — $detail'}.';
  }


  Future<bool> _tryStartEngine() async {
    try {
      final sttLocale = _mapToSttLocale(_sourceLanguage);
      bool started = false;
      try {
        started = await _stt.startConversation(language: sttLocale);
      } catch (e) {
        debugPrint('e1: $e');
      }
      if (!started) {
        try {
          await _stt.stopListening();
        } catch (_) {}
        try {
          started = await _stt.startConversation(language: sttLocale);
        } catch (e) {
          debugPrint('e2: $e');
        }
      }
      if (started) {
        await _sttSubscription?.cancel();
        _sttSubscription = _stt.liveResultStream.listen(
          _onLiveSttResult,
          onError: (e) {
            debugPrint('e3: $e');
          },
        );
      }
      return started;
    } catch (e) {
      debugPrint('e4: $e');
      return false;
    }
  }


  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 4), () {
      _keepAliveTick();
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<void> _keepAliveTick() async {
    // (bisect stub)
  }

  // ── Pipeline Logic ────────────────────────────────────────────────────────

  void _onLiveSttResult(SttResult sttResult) {
    final rawText = sttResult.fullText.trim();
    if (rawText.isEmpty) return;

    final captionId = 'cap_${DateTime.now().millisecondsSinceEpoch}';

    // Update active partial caption
    _activeCaption = CabinCaption(
      id: captionId,
      timestamp: DateTime.now(),
      sourceText: rawText,
      translatedText: _activeCaption?.translatedText ?? '',
      sourceLang: _sourceLanguage,
      targetLang: _targetLanguage,
      isFinal: false,
    );
    notifyListeners();

    // Reset silence timer for chunk finalization
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 1400), () {
      _finalizeCurrentChunk(rawText);
    });
  }

  Future<void> _finalizeCurrentChunk(String text) async {
    if (text.trim().isEmpty) return;

    _state = CabinState.translating;
    notifyListeners();

    final captionId = 'cap_${DateTime.now().millisecondsSinceEpoch}';
    String translated = '';
    String engine = 'Auto';

    try {
      final result = await _translator.translateText(
        text,
        sourceLang: _sourceLanguage,
        targetLang: _targetLanguage,
      );
      translated = result.translatedText.trim();
      engine = result.engineName;
    } catch (e) {
      debugPrint('⚠️ SttsCabinService translation error: $e');
      translated = text; // Fallback to source
    }

    final finalizedCaption = CabinCaption(
      id: captionId,
      timestamp: DateTime.now(),
      sourceText: text,
      translatedText: translated,
      sourceLang: _sourceLanguage,
      targetLang: _targetLanguage,
      engineUsed: engine,
      isFinal: true,
    );

    _activeCaption = finalizedCaption;
    _history.add(finalizedCaption);
    _captionStreamController.add(finalizedCaption);

    // Speak translation if Dubbing is enabled
    if (_isDubbingEnabled && translated.isNotEmpty) {
      _state = CabinState.speaking;
      notifyListeners();
      try {
        _tts.configure(language: _targetLanguage);
        await _tts.speak(translated);
      } catch (e) {
        debugPrint('⚠️ SttsCabinService Dubbing TTS error: $e');
      }
    }

    if (isListening) {
      _state = CabinState.listening;
    }
    notifyListeners();
  }

  String _mapToSttLocale(String lang) {
    switch (lang.toLowerCase()) {
      case 'vi':
        return 'vi-VN';
      case 'en':
        return 'en-US';
      case 'zh':
        return 'zh-CN';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'th':
        return 'th-TH';
      case 'hi':
        return 'hi-IN';
      case 'si':
        return 'si-LK';
      case 'my':
        return 'my-MM';
      default:
        return '$lang-${lang.toUpperCase()}';
    }
  }

  @override
  void dispose() {
    stopCabin();
    _captionStreamController.close();
    super.dispose();
  }
}
