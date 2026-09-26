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
import 'package:in4up/features/cabin/services/cabin_asr_plan.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_session_recorder.dart';
import 'package:in4up/features/cabin/services/cabin_session_settings.dart';

// Engine type + kế hoạch chọn model nằm ở cabin_asr_plan.dart (logic thuần,
// test được không cần thiết bị). Re-export để call-site cũ không phải sửa.
export 'package:in4up/features/cabin/services/cabin_asr_plan.dart'
    show CabinSttEngineType, CabinAsrPlan, planCabinAsr;

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

  SttsCabinService._internal() {
    _bindAsrModelState();
  }

  final SttServiceFacade _stt = SttServiceFacade();
  final SherpaSttEngine _sherpaStt = SherpaSttEngine();
  final SherpaModelManager _modelManager = SherpaModelManager();
  AudioRecorder? _audioRecorder;

  final TranslationService _translator = TranslationService();
  final TtsService _tts = TtsService();

  StreamSubscription? _sttSubscription;
  StreamSubscription<SherpaAsrInfo>? _asrStateSubscription;
  Timer? _silenceTimer;
  Timer? _keepAliveTimer;
  int _consecutiveStartFails = 0;
  bool _starting = false;

  CabinState _state = CabinState.idle;
  CabinSttEngineType _sttEngineType = CabinSttEngineType.system;

  /// Ngôn ngữ nguồn user chọn tay; `null` = còn dùng mặc định theo model đã cài.
  String? _sourceLanguageOverride;

  /// Mặc định tính từ model đã cài (ưu tiên VI, chưa có model nào ⇒ VI).
  String _defaultSourceLanguage = kDefaultAsrLanguage;

  String _targetLanguage = 'en';
  bool _targetLanguageExplicit = false;
  bool _isDubbingEnabled = false;
  CabinDisplayMode _displayMode = CabinDisplayMode.oneLine;
  String? _lastError;

  /// Kế hoạch STT bị CHẶN vì thiếu model (chỉ có nghĩa khi engine Offline).
  CabinAsrPlan? _modelPlan;

  CabinCaption? _activeCaption;
  final List<CabinCaption> _history = [];
  String _lastFinalizedText = '';

  final _captionStreamController = StreamController<CabinCaption>.broadcast();

  // ── CABIN-SAVE-001: phiên ghi (audio + text) ────────────────────────────
  CabinSessionRecorder? _recorder;
  CabinSession? _pendingSession;
  Duration? _chunkStartOffset;

  /// Phiên đang ghi (null khi không chạy).
  CabinSessionRecorder? get sessionRecorder => _recorder;

  /// Đang ghi âm thật (engine Offline + bật ghi âm).
  bool get isRecordingAudio => _recorder?.hasAudio ?? false;

  /// Engine hiện tại có ghi âm song song được không (engine hệ thống giữ mic
  /// độc quyền trên Android ⇒ chỉ lưu được text).
  bool get canRecordAudio => _sttEngineType == CabinSttEngineType.sherpaOffline;

  /// Phiên vừa dừng, chờ UI hỏi lưu / tự lưu. UI gọi [takePendingSession].
  CabinSession? get pendingSession => _pendingSession;

  CabinSession? takePendingSession() {
    final s = _pendingSession;
    _pendingSession = null;
    return s;
  }

  Future<void> _ensureSession() async {
    if (_recorder != null) return;
    final settings = CabinSessionSettings.instance;
    await settings.ensureLoaded();
    try {
      _recorder = await CabinSessionRecorder.begin(
        sourceLang: sourceLanguage,
        targetLang: _targetLanguage,
        engine: _sttEngineType.name,
        recordAudio: canRecordAudio && settings.recordAudio,
        textMode: settings.textMode,
      );
    } catch (e) {
      debugPrint('⚠️ SttsCabinService: không tạo được phiên lưu: $e');
      _recorder = null;
    }
  }

  Future<void> _endSession() async {
    final r = _recorder;
    _recorder = null;
    _chunkStartOffset = null;
    if (r == null) return;
    final s = await r.finish();
    if (s != null) _pendingSession = s;
  }

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

  /// Ngôn ngữ nguồn đang dùng: lựa chọn tay của user, nếu chưa chọn thì theo
  /// model đã cài (CABIN-ASR-002: KHÔNG hardcode 'en' khi máy chỉ có VI).
  String get sourceLanguage => _sourceLanguageOverride ?? _defaultSourceLanguage;
  String get targetLanguage => _targetLanguage;
  String? get lastError => _lastError;

  CabinCaption? get activeCaption => _activeCaption;
  List<CabinCaption> get history => List.unmodifiable(_history);
  Stream<CabinCaption> get captionStream => _captionStreamController.stream;

  bool get shouldShowBubble => isListening || isPaused;

  // ── Model ASR (Zipformer) ─────────────────────────────────────────────────

  /// Kế hoạch STT gần nhất (có thể đang bị chặn vì thiếu model) — UI đọc để
  /// hiện message đã bản địa hoá.
  CabinAsrPlan? get modelPlan => _modelPlan;

  /// Cabin offline đang bị chặn vì thiếu model → hiện banner + nút
  /// "Mở Quản lý Model AI" và ô xác nhận fallback.
  bool get hasModelBlocker => _modelPlan != null && !_modelPlan!.canStart;

  /// Ngôn ngữ đang thiếu model (đã normalize), `null` khi không bị chặn.
  String? get missingModelLanguage =>
      hasModelBlocker ? _modelPlan!.requestedLanguage : null;

  /// App CÓ profile offline cho ngôn ngữ đang thiếu không. `false` ⇒ ngôn ngữ
  /// chưa được hỗ trợ offline (phải đổi ngôn ngữ hoặc dùng Engine Hệ thống).
  bool get missingModelHasOfflineProfile =>
      hasModelBlocker && _modelPlan!.profile != null;

  /// Ngôn ngữ đã cài model có thể dùng thay — chỉ GỢI Ý, user phải xác nhận
  /// qua [confirmFallbackToInstalledLanguage] (không tự đổi sau lưng user).
  String? get suggestedFallbackLanguage =>
      hasModelBlocker ? _modelPlan!.fallbackLanguage : null;

  /// Route live của model đang chọn (online streaming vs VAD) — dùng cho UI.
  AsrLiveRoute? get liveRoute => _modelPlan?.liveRoute;

  /// Theo dõi state model ASR để (a) mặc định ngôn ngữ đúng theo model đã cài,
  /// (b) user vừa import/tải model xong → cabin thấy ngay (không auto-download).
  void _bindAsrModelState() {
    _modelManager.ensureFresh().then((_) => _applyDefaultSourceLanguage()).catchError((e) {
      debugPrint('⚠️ SttsCabinService model refresh error: $e');
    });
    _asrStateSubscription = _modelManager.watchAsr().listen((_) {
      _refreshModelBlocker();
      if (_sourceLanguageOverride == null) {
        _applyDefaultSourceLanguage();
      } else {
        notifyListeners();
      }
    });
  }

  /// Sau khi user import/tải model: gỡ trạng thái chặn nếu model đã có.
  void _refreshModelBlocker() {
    final plan = _modelPlan;
    if (plan == null || plan.canStart) return;
    final next = planCabinAsr(
      engine: _sttEngineType,
      language: sourceLanguage,
      isInstalled: _modelManager.isAsrProfileInstalled,
    );
    if (next.canStart) {
      _modelPlan = null;
      if (_state == CabinState.error) _state = CabinState.idle;
    } else {
      _modelPlan = next;
    }
  }

  /// Cập nhật mặc định ngôn ngữ nguồn (model đã cài, ưu tiên VI) + ngôn ngữ
  /// đích mặc định khi user chưa chọn tay.
  void _applyDefaultSourceLanguage() {
    final next = _modelManager.defaultCabinSourceLanguageSync();
    final changed = next != _defaultSourceLanguage;
    _defaultSourceLanguage = next;
    if (_sourceLanguageOverride == null && !_targetLanguageExplicit) {
      _targetLanguage = defaultCabinTargetLanguageFor(next);
    }
    if (changed || _sourceLanguageOverride == null) notifyListeners();
  }

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
    if (sourceLang != null) {
      _sourceLanguageOverride = AsrModelRouter.normalizeLanguage(sourceLang);
      if (!_targetLanguageExplicit) {
        _targetLanguage =
            defaultCabinTargetLanguageFor(_sourceLanguageOverride!);
      }
    }
    if (targetLang != null) {
      _targetLanguage = targetLang;
      _targetLanguageExplicit = true;
    }
    if (dubbing != null) _isDubbingEnabled = dubbing;

    _lastError = null;
    _lastFinalizedText = '';

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

    // CABIN-SAVE-001: mở phiên ghi (giữ nguyên qua pause/đổi ngôn ngữ).
    await _ensureSession();

    // 2. Chạy theo engine được chọn
    if (_sttEngineType == CabinSttEngineType.sherpaOffline) {
      // Model có thể vừa được import/tải ⇒ quét lại trước khi kết luận thiếu.
      try {
        await _modelManager.ensureFresh();
      } catch (e) {
        debugPrint('⚠️ SttsCabinService ensureFresh error: $e');
      }

      final plan = planCabinAsr(
        engine: CabinSttEngineType.sherpaOffline,
        language: sourceLanguage,
        isInstalled: _modelManager.isAsrProfileInstalled,
      );
      _modelPlan = plan;

      if (!plan.canStart) {
        _state = CabinState.error;
        // Chuỗi này chỉ để log/chẩn đoán — UI hiện message đã bản địa hoá từ
        // `modelPlan` (xem `_errorBannerText` trong live_cabin_screen.dart).
        final fallbackTag = plan.fallbackLanguage?.toUpperCase();
        _lastError = plan.issue == AsrModelIssue.noProfileForLanguage
            ? 'Chưa có model Zipformer offline cho ${plan.requestedLanguage} '
                '(app chỉ có VI offline + EN streaming).'
            : 'Chưa cài model Zipformer cho ${plan.requestedLanguage.toUpperCase()}'
                '${fallbackTag == null ? '' : ' — máy có $fallbackTag, cần user xác nhận'}.';
        notifyListeners();
        debugPrint('⛔ SttsCabinService: $plan');
        return false;
      }

      try {
        final recorder = AudioRecorder();
        _audioRecorder = recorder;
        final rawPcm = await recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        // CABIN-SAVE-001: tee PCM → WAV (cùng luồng mic, không mở mic lần 2).
        final pcmStream = _recorder?.tapPcm(rawPcm) ?? rawPcm;

        final ok = await _sherpaStt.startLive(
          language: plan.requestedLanguage,
          pcmStream: pcmStream,
        );

        if (!ok) {
          _state = CabinState.error;
          _lastError = _sherpaStt.lastError ??
              'Không khởi động được Zipformer ASR cho ${plan.requestedLanguage}.';
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
        _recorder?.resumeClock();
        _startKeepAlive();
        notifyListeners();
        debugPrint(
            '🎙️ SttsCabinService started with Sherpa Zipformer ($sourceLanguage ➔ $_targetLanguage)');
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
    _recorder?.resumeClock();
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
        '🎙️ SttsCabinService started with System STT ($sourceLanguage ➔ $_targetLanguage)');
    return true;
  }

  /// Start engine hệ thống chế độ hội thoại (không cap 2 phút, ListenMode.dictation).
  Future<bool> _tryStartSystemEngine() async {
    if (_starting) return false;
    _starting = true;
    try {
      final sttLocale = _mapToSttLocale(sourceLanguage);
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
    _lastFinalizedText = '';
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

    // CABIN-SAVE-001: đóng phiên ghi → UI hỏi lưu / tự lưu.
    await _endSession();

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

      _recorder?.pauseClock();
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

  /// User chọn ngôn ngữ nguồn. Nếu ngôn ngữ này CHƯA có model offline thì
  /// cabin sẽ dừng + báo rõ (không tự nhận ngôn ngữ khác bằng model đang có).
  void setSourceLanguage(String lang) {
    final next = AsrModelRouter.normalizeLanguage(lang);
    if (next.isEmpty || sourceLanguage == next) return;
    _sourceLanguageOverride = next;
    _modelPlan = null;
    if (!_targetLanguageExplicit) {
      _targetLanguage = defaultCabinTargetLanguageFor(next);
    }
    if (isListening) {
      startCabin();
    } else {
      notifyListeners();
    }
  }

  /// Dùng lại ngôn ngữ đã cài model thay cho ngôn ngữ đang thiếu
  /// (chỉ sau khi user XÁC NHẬN qua dialog — không tự đổi).
  Future<bool> confirmFallbackToInstalledLanguage() async {
    final fallback = suggestedFallbackLanguage;
    if (fallback == null) return false;
    _sourceLanguageOverride = AsrModelRouter.normalizeLanguage(fallback);
    if (!_targetLanguageExplicit) {
      _targetLanguage = defaultCabinTargetLanguageFor(_sourceLanguageOverride!);
    }
    _modelPlan = null;
    notifyListeners();
    return startCabin();
  }

  /// Bỏ trạng thái chặn model (sau khi user mở Quản lý Model AI / đổi ngôn ngữ).
  void clearModelBlocker() {
    if (_modelPlan == null) return;
    _modelPlan = null;
    if (_state == CabinState.error) _state = CabinState.idle;
    notifyListeners();
  }

  void setTargetLanguage(String lang) {
    _targetLanguage = lang;
    _targetLanguageExplicit = true;
    notifyListeners();
  }

  void swapLanguages() {
    final temp = sourceLanguage;
    _sourceLanguageOverride = _targetLanguage;
    _targetLanguage = temp;
    _targetLanguageExplicit = true;
    _modelPlan = null;
    if (isListening) {
      startCabin();
    } else {
      notifyListeners();
    }
  }

  void clearHistory() {
    _history.clear();
    _activeCaption = null;
    _lastFinalizedText = '';
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
    if (_state == CabinState.speaking) {
      // Ignored during TTS playback to avoid audio feedback loop / mic pickup of TTS
      return;
    }

    final rawText = sttResult.fullText.trim();
    if (rawText.isEmpty) return;

    // CABIN-SAVE-001: mốc bắt đầu câu = lúc có chữ đầu tiên của câu (trừ lùi
    // ~0.6s độ trễ nhận dạng để LRC nhảy đúng đầu câu khi nghe lại).
    if (_chunkStartOffset == null && _recorder != null) {
      final now = _recorder!.elapsed - const Duration(milliseconds: 600);
      _chunkStartOffset = now.isNegative ? Duration.zero : now;
    }

    final captionId = 'cap_${DateTime.now().millisecondsSinceEpoch}';

    // Update active partial caption
    _activeCaption = CabinCaption(
      id: captionId,
      timestamp: DateTime.now(),
      sourceText: rawText,
      translatedText: _activeCaption?.translatedText ?? '',
      sourceLang: sourceLanguage,
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
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_state == CabinState.speaking) return;
    if (trimmed == _lastFinalizedText) return;
    _lastFinalizedText = trimmed;

    final recorder = _recorder;
    final startOffset = _chunkStartOffset ?? recorder?.elapsed ?? Duration.zero;
    _chunkStartOffset = null;

    _state = CabinState.translating;
    notifyListeners();

    final captionId = 'cap_${DateTime.now().millisecondsSinceEpoch}';
    String translated = '';
    String engine = 'Auto';

    try {
      final result = await _translator.translateText(
        trimmed,
        sourceLang: sourceLanguage,
        targetLang: _targetLanguage,
      );
      translated = result.translatedText.trim();
      engine = result.engineName;
    } catch (e) {
      debugPrint('⚠️ SttsCabinService translation error: $e');
      translated = trimmed; // Fallback to source
    }

    final finalizedCaption = CabinCaption(
      id: captionId,
      timestamp: DateTime.now(),
      sourceText: trimmed,
      translatedText: translated,
      sourceLang: sourceLanguage,
      targetLang: _targetLanguage,
      engineUsed: engine,
      isFinal: true,
    );

    _activeCaption = finalizedCaption;
    _history.add(finalizedCaption);
    _captionStreamController.add(finalizedCaption);

    // CABIN-SAVE-001: ghi câu đã chốt vào journal phiên (ghi đĩa ngay).
    recorder?.addEntry(CabinTranscriptEntry(
      offset: startOffset,
      sourceText: trimmed,
      translatedText: translated,
    ));

    // Speak translation if Dubbing is enabled
    if (_isDubbingEnabled && translated.isNotEmpty) {
      _state = CabinState.speaking;
      notifyListeners();
      try {
        _tts.configure(language: _targetLanguage);
        await _tts.speak(translated);
        await _tts.waitForCompletion();
      } catch (e) {
        debugPrint('⚠️ SttsCabinService Dubbing TTS error: $e');
      }
      // Brief pause to prevent microphone pickup after audio output ceases
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (isListening) {
      _state = CabinState.listening;
      // Audio focus during TTS playback on Android can terminate SpeechRecognizer session.
      // Re-arm the system recognizer if it went inactive.
      if (_sttEngineType == CabinSttEngineType.system && !_stt.isLiveListening) {
        await _tryStartSystemEngine();
      }
    }
    _lastFinalizedText = '';
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
    _asrStateSubscription?.cancel();
    _asrStateSubscription = null;
    stopCabin();
    _sherpaStt.dispose();
    _captionStreamController.close();
    super.dispose();
  }
}
