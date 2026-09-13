import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';
import 'package:in4up_stt/stt_engine_sherpa.dart';
import 'package:in4up_stt/stt_service_facade.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/features/tts/tts_service.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';

/// Lựa chọn Engine STT cho Dịch Live Cabin.
enum CabinSttEngineType {
  system,
  sherpaOffline,
}

/// Service điều phối toàn bộ Pipeline Dịch Cabin Trực tiếp (Speech Translation - STS).
///
/// **Luồng xử lý (theo PLAN-008 & WP1/WP4):**
/// 1. Thu âm qua Mic $\rightarrow$ STT Live Streaming (đoạn tạm & đoạn chốt) qua System STT hoặc Sherpa Zipformer offline.
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
  final SherpaSttEngine _sherpaStt = SherpaSttEngine();
  AudioRecorder? _audioRecorder;

  final TranslationService _translator = TranslationService();
  final TtsService _tts = TtsService();

  StreamSubscription? _sttSubscription;
  Timer? _silenceTimer;
  Timer? _keepAliveTimer;
  int _consecutiveStartFails = 0;
  bool _starting = false;

  CabinState _state = CabinState.idle;
  CabinSttEngineType _sttEngineType = CabinSttEngineType.system;
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
  CabinSttEngineType get sttEngineType => _sttEngineType;
  bool get isListening =>
      _state == CabinState.listening ||
      _state == CabinState.translating ||
      _state == CabinState.speaking;
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

  Future<void> setSttEngineType(CabinSttEngineType type) async {
    if (_sttEngineType == type) return;
    _sttEngineType = type;
    if (isListening) {
      await stopCabin();
      await startCabin();
    } else {
      notifyListeners();
    }
  }

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
          _lastError = 'Chưa cấp quyền microphone. Vào Cài đặt → Ứng dụng → '
              'In4Up → Quyền → cho phép "Microphone" rồi thử lại.';
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      debugPrint('⚠️ SttsCabinService permission check error: $e');
    }

    // Dọn các phiên nghe cũ
    try {
      await _stt.stopListening();
    } catch (_) {}
    try {
      await _sherpaStt.stopListening();
    } catch (_) {}
    if (_audioRecorder != null) {
      try {
        if (await _audioRecorder!.isRecording()) {
          await _audioRecorder!.stop();
        }
        await _audioRecorder!.dispose();
      } catch (_) {}
      _audioRecorder = null;
    }

    // 2. Chạy theo engine được chọn
    if (_sttEngineType == CabinSttEngineType.sherpaOffline) {
      final hasModel = SherpaModelManager().hasAsrModel(_sourceLanguage);
      if (!hasModel) {
        _state = CabinState.error;
        _lastError =
            'Chưa có model Zipformer cho $_sourceLanguage. Mở Quản lý Model AI để tải/import model.';
        notifyListeners();
        return false;
      }

      try {
        final recorder = AudioRecorder();
        _audioRecorder = recorder;
        final pcmStream = await recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        final ok = await _sherpaStt.startLive(
          language: _sourceLanguage,
          pcmStream: pcmStream,
        );

        if (!ok) {
          _state = CabinState.error;
          _lastError = _sherpaStt.lastError ??
              'Không khởi động được Zipformer ASR cho $_sourceLanguage.';
          try {
            await recorder.stop();
            await recorder.dispose();
          } catch (_) {}
          _audioRecorder = null;
          notifyListeners();
          return false;
        }

        await _sttSubscription?.cancel();
        _sttSubscription = _sherpaStt.liveResultStream.listen(
          _onLiveSttResult,
          onError: (e) {
            debugPrint('❌ SttsCabinService Sherpa stream error: $e');
            _lastError = '$e';
            _state = CabinState.error;
            notifyListeners();
          },
        );

        _state = CabinState.listening;
        _consecutiveStartFails = 0;
        _startKeepAlive();
        notifyListeners();
        debugPrint(
            '🎙️ SttsCabinService started with Sherpa Zipformer ($_sourceLanguage ➔ $_targetLanguage)');
        return true;
      } catch (e) {
        _state = CabinState.error;
        _lastError = 'Lỗi khởi động Sherpa STT: $e';
        if (_audioRecorder != null) {
          try {
            await _audioRecorder!.stop();
            await _audioRecorder!.dispose();
          } catch (_) {}
          _audioRecorder = null;
        }
        notifyListeners();
        return false;
      }
    }

    // Engine Hệ thống (Native STT)
    try {
      await _stt.initialize();
    } catch (e) {
      debugPrint('⚠️ SttsCabinService STT init warning: $e');
    }

    _state = CabinState.listening;
    notifyListeners();

    // Nếu keep-alive đang restart dở → đợi nó xong
    for (int i = 0; i < 5 && _starting; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
    var started = await _tryStartSystemEngine();
    if (!started && _stt.isLiveListening) started = true; // keep-alive thắng
    if (!started) {
      _state = CabinState.error;
      _lastError = await _buildStartFailureMessage();
      notifyListeners();
      return false;
    }

    _consecutiveStartFails = 0;
    _startKeepAlive();
    debugPrint(
        '🎙️ SttsCabinService started with System STT ($_sourceLanguage ➔ $_targetLanguage)');
    return true;
  }

  /// Start engine hệ thống chế độ hội thoại (không cap 2 phút, ListenMode.dictation).
  Future<bool> _tryStartSystemEngine() async {
    if (_starting) return false;
    _starting = true;
    try {
      final sttLocale = _mapToSttLocale(_sourceLanguage);
      bool started = false;
      try {
        started = await _stt.startConversation(language: sttLocale);
      } catch (e) {
        debugPrint('❌ SttsCabinService start error: $e');
      }
      if (!started) {
        try {
          await _stt.stopListening();
        } catch (_) {}
        try {
          started = await _stt.startConversation(language: sttLocale);
        } catch (e) {
          debugPrint('❌ SttsCabinService retry error: $e');
        }
      }
      if (started) {
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
      }
      return started;
    } finally {
      _starting = false;
    }
  }

  /// Keep-alive: session hệ thống tự chết trong khi cabin vẫn "đang nghe" → tự restart.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _keepAliveTick();
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<void> _keepAliveTick() async {
    if (_state != CabinState.listening &&
        _state != CabinState.translating &&
        _state != CabinState.speaking) {
      return; // paused/stopped/error — không tự restart
    }

    if (_sttEngineType == CabinSttEngineType.sherpaOffline) {
      if (_sherpaStt.isListening) return;
      if (_starting) return;
      debugPrint('♻️ SttsCabinService: Sherpa STT session chết — tự khởi động lại');
      final ok = await startCabin();
      if (!ok) {
        _consecutiveStartFails++;
        if (_consecutiveStartFails >= 3) {
          _state = CabinState.error;
          _lastError = _sherpaStt.lastError ?? 'Sherpa STT gặp sự cố.';
        }
      } else {
        _consecutiveStartFails = 0;
      }
      notifyListeners();
      return;
    }

    if (_stt.isLiveListening) return; // session vẫn sống
    if (_starting) return;

    debugPrint('♻️ SttsCabinService: System STT session chết — tự khởi động lại');
    final ok = await _tryStartSystemEngine();
    if (ok) {
      _consecutiveStartFails = 0;
      _state = CabinState.listening;
    } else {
      _consecutiveStartFails++;
      if (_consecutiveStartFails >= 3) {
        _state = CabinState.error;
        _lastError = await _buildStartFailureMessage();
      }
    }
    notifyListeners();
  }

  Future<String> _buildStartFailureMessage() async {
    final detail = _stt.liveLastError ?? '';
    bool micOk = true;
    try {
      micOk = await _stt.checkLiveMicPermission();
    } catch (_) {}
    if (!micOk) {
      return 'Chưa có quyền microphone. Vào Cài đặt → Ứng dụng → In4Up → '
          'Quyền → cho phép "Microphone" rồi thử lại.';
    }
    return 'Không khởi động được nhận diện giọng nói'
        '${detail.isEmpty ? '' : ' — $detail'}.'
        'Máy có thể KHÔNG có sẵn dịch vụ Speech Recognition. '
        'Bạn có thể chuyển sang Engine "Offline (sherpa)" để nhận diện không cần dịch vụ hệ thống.';
  }

  Future<void> stopCabin() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _stopKeepAlive();
    _consecutiveStartFails = 0;
    await _sttSubscription?.cancel();
    _sttSubscription = null;

    if (_audioRecorder != null) {
      try {
        if (await _audioRecorder!.isRecording()) {
          await _audioRecorder!.stop();
        }
        await _audioRecorder!.dispose();
      } catch (_) {}
      _audioRecorder = null;
    }

    try {
      await _sherpaStt.stopListening();
    } catch (_) {}

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

      if (_sttEngineType == CabinSttEngineType.sherpaOffline) {
        if (_audioRecorder != null) {
          try {
            if (await _audioRecorder!.isRecording()) {
              await _audioRecorder!.stop();
            }
            await _audioRecorder!.dispose();
          } catch (_) {}
          _audioRecorder = null;
        }
        try {
          await _sherpaStt.stopListening();
        } catch (_) {}
      } else {
        try {
          await _stt.stopListening();
        } catch (_) {}
      }

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
      isFinal: sttResult.isFinal,
    );
    notifyListeners();

    if (sttResult.isFinal) {
      _silenceTimer?.cancel();
      _finalizeCurrentChunk(rawText);
    } else {
      // Reset silence timer for chunk finalization
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(milliseconds: 1400), () {
        _finalizeCurrentChunk(rawText);
      });
    }
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
    _sherpaStt.dispose();
    _captionStreamController.close();
    super.dispose();
  }
}
