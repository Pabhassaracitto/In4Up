import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/features/tts/tts_service.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';
import 'package:in4up/features/cabin/services/cabin_asr_plan.dart';
import 'package:in4up/features/cabin/services/cabin_record_config.dart';
import 'package:in4up/features/cabin/services/cabin_finalization_dedup.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_session_recorder.dart';
import 'package:in4up/features/cabin/services/cabin_session_store.dart';
import 'package:in4up/features/cabin/services/cabin_session_settings.dart';
import 'package:in4up/features/cabin/services/cabin_audio_source.dart';
import 'package:in4up/features/cabin/services/cabin_pcm_gate.dart';
import 'package:in4up/features/cabin/services/cabin_android_capture.dart';
import 'package:in4up/features/cabin/services/cabin_loopback_stream.dart';
import 'package:in4up/features/cabin/services/cabin_windows_loopback.dart';
import 'package:in4up/features/cabin/services/cabin_windows_overlay.dart';

// Engine type + kế hoạch chọn model nằm ở cabin_asr_plan.dart (logic thuần,
// test được không cần thiết bị). Re-export để call-site cũ không phải sửa.
export 'package:in4up/features/cabin/services/cabin_audio_source.dart';
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
  CabinAudioSource _audioSource = CabinAudioSource.microphone;
  bool _systemOverlay = false;
  bool _systemStarting = false;
  int _systemGeneration = 0;
  bool _systemStreamFailed = false;
  int _systemTtsDepth = 0;
  int _overlaySequence = 0;
  int _overlayLastSequence = -1;
  String _overlayLastTranslation = '';
  CabinAndroidCapture? _androidCapture;
  CabinWindowsOverlay? _windowsOverlay;


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
  final Map<String, CabinSessionRecorder> _captionRecorders = {};
  int _captionSequence = 0;

  String _newCaptionId() =>
      'cap_${DateTime.now().microsecondsSinceEpoch}_${_captionSequence++}';
  String _lastFinalizedText = '';

  /// AUDIT-1.21.0 #3: chống 2 dòng trùng khi đang dịch mà nói thêm — thay
  /// cho cửa sổ 3s của `_lastFinalizedText` (xem cabin_finalization_dedup.dart).
  final CabinFinalizationDeduper _deduper = CabinFinalizationDeduper();
  final List<Future<void>> _pendingFinalizations = [];

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
  CabinAudioSource get audioSource => _audioSource;
  bool get systemOverlay => _systemOverlay;
  bool get isStartingSystemAudio => _systemStarting;
  bool get supportsSystemAudio => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.windows);

  void setAudioSource(CabinAudioSource source) {
    if (isListening || isPaused || _systemStarting || _audioSource == source) return;
    _audioSource = source;
    if (source == CabinAudioSource.systemAudio) {
      _sttEngineType = CabinSttEngineType.sherpaOffline;
    }
    _lastError = null;
    _modelPlan = null;
    if (_state == CabinState.error) _state = CabinState.idle;
    notifyListeners();
  }

  void setSystemOverlay(bool enabled) {
    if (isListening || isPaused || _systemStarting) return;
    _systemOverlay = enabled;
    notifyListeners();
  }

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

  /// Profile đang thiếu là model ĐA NGỮ (Parakeet) — UI dùng để nói đúng tên
  /// model cần tải thay vì luôn nói "Zipformer" (PARAKEET-002).
  bool get missingModelIsMultilingual =>
      hasModelBlocker && (_modelPlan!.profile?.isMultilingual ?? false);

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
    if (_audioSource == CabinAudioSource.systemAudio &&
        type != CabinSttEngineType.sherpaOffline) return;
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
    if (_audioSource != CabinAudioSource.systemAudio) {
      return _startCabin(sourceLang: sourceLang, targetLang: targetLang, dubbing: dubbing);
    }
    if (_systemStarting) return false;
    _systemStarting = true;
    _systemStreamFailed = false;
    _overlayLastTranslation = '';
    _overlayLastSequence = -1;
    final generation = ++_systemGeneration;
    notifyListeners();
    try {
      return await _startCabin(sourceLang: sourceLang, targetLang: targetLang,
          dubbing: dubbing, systemGeneration: generation);
    } finally {
      _systemStarting = false;
      if (_systemStreamFailed && generation == _systemGeneration && isListening) {
        unawaited(_failSystemAudio(generation));
      }
      notifyListeners();
    }
  }

  Future<bool> _startCabin({
    String? sourceLang,
    String? targetLang,
    bool? dubbing,
    int? systemGeneration,
  }) async {
    bool current() => systemGeneration == null || systemGeneration == _systemGeneration;
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
    _deduper.reset(); // phiên mới: không mang vân tay câu của phiên cũ.

    // 1. Check microphone permission
    try {
      final needsRecordPermission = systemGeneration == null ||
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
      final status = needsRecordPermission
          ? await Permission.microphone.status : PermissionStatus.granted;
      if (!current()) return false;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!current()) return false;
        if (!result.isGranted) {
          _state = CabinState.error;
          _lastError = systemGeneration != null
              ? 'Cần cấp quyền micro để thu âm thanh hệ thống'
              : 'Chưa cấp quyền microphone. Vào Cài đặt → Ứng dụng → '
                'In4Up → Quyền → cho phép "Microphone" rồi thử lại.';
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      debugPrint('⚠️ SttsCabinService permission check error: $e');
    }

    if (!current()) return false;
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

    if (!current()) return false;
    // CABIN-SAVE-001: mở phiên ghi (giữ nguyên qua pause/đổi ngôn ngữ).
    await _ensureSession();
    if (!current()) { await _endSession(); return false; }

    // 2. Chạy theo engine được chọn
    if (_sttEngineType == CabinSttEngineType.sherpaOffline) {
      // Model có thể vừa được import/tải ⇒ quét lại trước khi kết luận thiếu.
      try {
        await _modelManager.ensureFresh();
      } catch (e) {
        debugPrint('⚠️ SttsCabinService ensureFresh error: $e');
      }

      if (!current()) return false;
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
        // PARAKEET-002: nêu đúng họ model (Parakeet đa ngữ vs Zipformer) —
        // chuỗi này chỉ để log/chẩn đoán, UI hiện message từ `modelPlan`.
        final family = plan.profile?.family == SherpaAsrFamily.parakeet
            ? 'Parakeet'
            : 'Zipformer';
        _lastError = plan.issue == AsrModelIssue.noProfileForLanguage
            ? 'Chưa có model offline cho ${plan.requestedLanguage} '
                '(app có VI offline, EN streaming và Parakeet 25 ngôn ngữ '
                'châu Âu).'
            : 'Chưa cài model $family cho ${plan.requestedLanguage.toUpperCase()}'
                '${fallbackTag == null ? '' : ' — máy có $fallbackTag, cần user xác nhận'}.';
        if (systemGeneration != null) await _endSession();
        notifyListeners();
        debugPrint('⛔ SttsCabinService: $plan');
        return false;
      }

      try {
        Stream<Uint8List> rawPcm;
        if (systemGeneration != null) {
          rawPcm = await _openSystemAudio(systemGeneration);
          if (!current()) { await _closeSystemAudio(); return false; }
          rawPcm = _watchSystemAudio(rawPcm, systemGeneration);
        } else {
          final recorder = AudioRecorder();
          _audioRecorder = recorder;
          rawPcm = await recorder.startStream(
            cabinRecordConfig(
              isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
            ),
          );
        }

        // Keep the session recorder tee on the same PCM stream for both sources.
        final pcmStream = _recorder?.tapPcm(rawPcm) ?? rawPcm;

        // M4U-IMPORT-003: dùng ĐÚNG model đã plan (Parakeet đa ngữ khi
        // profile chuyên ngôn ngữ chưa cài) — không để engine tự tra theo
        // ngôn ngữ rồi rơi về "chưa có model".
        //
        // `plan.profile` là getter ⇒ không promote được ⇒ gán vào biến cục
        // bộ trước (biến cục bộ final mới promote được).
        final planProfile = plan.profile;
        final ok = await _sherpaStt.startLive(
          language: plan.requestedLanguage,
          pcmStream: pcmStream,
          modelPaths: planProfile == null
              ? null
              : _modelManager.getAsrModelPaths(planProfile.id),
        );

        if (!current()) {
          await _sherpaStt.stopListening();
          await _closeSystemAudio();
          return false;
        }
        if (!ok || (systemGeneration != null && _systemStreamFailed)) {
          _state = CabinState.error;
          _lastError = _sherpaStt.lastError ??
              'Không khởi động được model offline cho '
                  '${plan.requestedLanguage}.';
          final recorder = _audioRecorder;
          if (recorder != null) {
            try { await recorder.stop(); await recorder.dispose(); } catch (_) {}
            _audioRecorder = null;
          }
          if (systemGeneration != null) {
            await _closeSystemAudio();
            await _sherpaStt.stopListening();
            await _endSession();
          }
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
        if (systemGeneration == null) _startKeepAlive();
        notifyListeners();
        debugPrint('🎙️ SttsCabinService started with Sherpa '
            '${plan.profile?.family.name ?? 'zipformer'} '
            '($sourceLanguage ➔ $_targetLanguage)');
        return true;
      } catch (e) {
        if (!current()) return false;
        _state = CabinState.error;
        _lastError = systemGeneration != null
            ? 'Không thu được âm thanh hệ thống'
            : 'Lỗi khởi động Sherpa STT: $e';
        if (systemGeneration != null) {
          debugPrint('Cabin system audio start failed: $e');
          await _closeSystemAudio();
          await _sherpaStt.stopListening();
          await _endSession();
        }
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

  Future<Stream<Uint8List>> _openSystemAudio(int generation) async {
    if (!supportsSystemAudio) throw UnsupportedError('System audio unsupported');
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!await CabinAndroidCapture.isSupported()) {
        throw UnsupportedError('Android 10 required');
      }
      if (_systemOverlay && !await CabinAndroidCapture.hasOverlayPermission()) {
        throw StateError('Overlay permission required');
      }
      if (generation != _systemGeneration) throw StateError('Capture cancelled');
      final capture = CabinAndroidCapture();
      _androidCapture = capture;
      return capture.open(overlay: _systemOverlay);
    }
    if (_systemOverlay) {
      final overlay = CabinWindowsOverlay();
      overlay.show();
      _windowsOverlay = overlay;
    }
    return cabinLoopbackStream(CabinWindowsLoopback.new);
  }

  Stream<Uint8List> _watchSystemAudio(Stream<Uint8List> source, int generation) {
    return source.transform(StreamTransformer<Uint8List, Uint8List>.fromHandlers(
      handleData: (data, sink) {
        // Prevent the app's spoken translation feeding back into recognition.
        // This also mutes source speech during TTS; the UI warns about the gap.
        sink.add(gateCabinSystemPcm(data, mute: _systemTtsDepth > 0));
      },
      handleError: (error, stack, sink) {
        _systemCaptureEnded(generation);
        sink.addError(error, stack);
      },
      handleDone: (sink) {
        _systemCaptureEnded(generation);
        sink.close();
      },
    ));
  }

  void _systemCaptureEnded(int generation) {
    if (generation != _systemGeneration || _systemStreamFailed) return;
    _systemStreamFailed = true;
    if (!_systemStarting && isListening) unawaited(_failSystemAudio(generation));
  }

  Future<void> _failSystemAudio(int generation) async {
    if (generation != _systemGeneration) return;
    await stopCabin();
    if (_systemGeneration != generation + 1) return;
    _lastError = 'Không thu được âm thanh hệ thống';
    _state = CabinState.error;
    notifyListeners();
  }

  Future<void> _closeSystemAudio() async {
    ++_systemGeneration; // invalidate late consent and stream callbacks
    final capture = _androidCapture;
    _androidCapture = null;
    if (capture != null) await capture.close();
    final overlay = _windowsOverlay;
    _windowsOverlay = null;
    overlay?.close();
  }

  void _pushSystemCaption(CabinCaption caption, {String? translation}) {
    if (_audioSource != CabinAudioSource.systemAudio || !_systemOverlay) return;
    if (translation != null) _overlayLastTranslation = translation;
    final text = _overlayLastTranslation.isEmpty
        ? caption.sourceText : '$_overlayLastTranslation\n${caption.sourceText}';
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(CabinAndroidCapture.updateCaption(text).catchError((_) {}));
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      try { _windowsOverlay?.setCaption(text); } catch (_) {}
    }
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
    if (_audioSource == CabinAudioSource.systemAudio) {
      await _closeSystemAudio();
    }
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _stopKeepAlive();
    _consecutiveStartFails = 0;
    _lastFinalizedText = '';
    _deduper.reset();
    // Keep the STT listener alive until stopListening flushes the current
    // Sherpa VAD / streaming endpoint. Cancelling it first silently discarded
    // the last in-progress sentence whenever the user stopped Cabin mid-pause.
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

    // CABIN-FLUSH-001: engine có thể KHÔNG kịp phát `isFinal` cho câu đang nói
    // ⇒ chốt tay câu partial rồi mới đợi hàng đợi, nếu không sẽ mất câu cuối.
    await _flushActivePartialBeforeClose();

    // Stream callbacks are synchronous with the Sherpa flush; translation and
    // journal persistence are async, so wait before closing the session.
    await _drainPendingFinalizations();
    await _sttSubscription?.cancel();
    _sttSubscription = null;

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
      if (_audioSource == CabinAudioSource.systemAudio) {
        await _closeSystemAudio();
      }
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

      // CABIN-FLUSH-001: tạm dừng cũng phải chốt câu đang nhận (nếu không,
      // câu đó biến mất và người dùng thấy "nói xong mà không có chữ").
      await _flushActivePartialBeforeClose();
      await _drainPendingFinalizations();
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
      if (_audioSource == CabinAudioSource.systemAudio) {
        unawaited(stopCabin());
      } else {
        startCabin();
      }
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
      if (_audioSource == CabinAudioSource.systemAudio) {
        unawaited(stopCabin());
      } else {
        startCabin();
      }
    } else {
      notifyListeners();
    }
  }

  /// Modify the same journal entry that produced the visible final caption.
  Future<bool> mutateCaption(String id, {
    String? sourceText,
    String? translatedText,
    bool delete = false,
  }) async {
    final index = _history.indexWhere((caption) => caption.id == id);
    if (index < 0) return false;
    final recorder = _captionRecorders[id];
    if (recorder != null) {
      var ok = recorder.mutateEntry(id, sourceText: sourceText,
          translatedText: translatedText, delete: delete);
      if (!ok) {
        ok = await CabinSessionStore.instance.mutateEntry(recorder.session, id,
            sourceText: sourceText, translatedText: translatedText, delete: delete);
      }
      if (!ok) return false;
    }
    // The list may have changed while a saved session was being updated.
    final currentIndex = _history.indexWhere((caption) => caption.id == id);
    if (currentIndex < 0) return false;
    final old = _history[currentIndex];
    if (delete) {
      _history.removeAt(currentIndex);
      _captionRecorders.remove(id);
      if (_activeCaption?.id == id) _activeCaption = null;
    } else {
      final updated = old.copyWith(sourceText: sourceText,
          translatedText: translatedText);
      _history[currentIndex] = updated;
      if (_activeCaption?.id == id) _activeCaption = updated;
    }
    notifyListeners();
    return true;
  }

  void clearHistory() {
    _history.clear();
    _captionRecorders.clear();
    _activeCaption = null;
    _lastFinalizedText = '';
    _deduper.reset();
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

    final muteCapture = _audioSource == CabinAudioSource.systemAudio && isListening;
    if (muteCapture) _systemTtsDepth++;
    try {
      await _tts.speak(textToSpeak, language: langToSpeak);
      if (muteCapture) {
        await _tts.waitForCompletion();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      debugPrint('⚠️ Replay caption TTS error: $e');
    } finally {
      if (muteCapture) _systemTtsDepth--;
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

    // AUDIT-1.21.0 #3 — dedup: engine vừa callback lại đúng câu đã chốt
    // (bản partial lặp sau final) HOẶC câu đó đang được dịch (in-flight) —
    // bỏ qua để không sinh caption/dòng LRC/journal trùng. Trước đây chỉ có
    // `_lastFinalizedText` bị xoá sau 3s, trong khi dịch LLM/offline có thể
    // lâu hơn ⇒ đúng cửa sổ sinh "2 dòng trùng" khi user nói thêm.
    if (!_deduper.shouldFinalize(rawText)) {
      return;
    }

    // CABIN-SAVE-001: mốc bắt đầu câu = lúc có chữ đầu tiên của câu (trừ lùi
    // ~0.6s độ trễ nhận dạng để LRC nhảy đúng đầu câu khi nghe lại).
    if (_chunkStartOffset == null && _recorder != null) {
      final now = _recorder!.elapsed - const Duration(milliseconds: 600);
      _chunkStartOffset = now.isNegative ? Duration.zero : now;
    }

    final captionId = _newCaptionId();

    // Update active partial caption
    _activeCaption = CabinCaption(
      id: captionId,
      timestamp: DateTime.now(),
      sourceText: rawText,
      translatedText: '',
      sourceLang: sourceLanguage,
      targetLang: _targetLanguage,
      isFinal: sttResult.isFinal,
    );
    _pushSystemCaption(_activeCaption!);
    notifyListeners();

    _silenceTimer?.cancel();
    if (sttResult.isFinal) {
      _trackFinalization(rawText);
    } else {
      // Reset silence timer for chunk finalization. Keep every async save in a
      // queue so stop/pause waits for all pending translated captions.
      _silenceTimer = Timer(const Duration(milliseconds: 1400), () {
        _trackFinalization(rawText);
      });
    }
  }

  /// CABIN-FLUSH-001 (2026-10-29) — chốt nốt câu **ĐANG NHẬN** (partial)
  /// trước khi đóng hoặc tạm dừng phiên.
  ///
  /// Vì sao cần: engine STT (nhất là Engine Hệ thống / speech_to_text) chỉ phát
  /// `isFinal` khi nó TỰ kết thúc câu. Bấm Stop đúng lúc đang nói ⇒
  /// `_silenceTimer` bị huỷ ở đầu `stopCabin()` và engine không kịp phát final
  /// ⇒ câu cuối **mất hoàn toàn** (không caption, không dòng LRC, không bản
  /// dịch). Đây đúng là hiện tượng "nhận diện thiếu" khi so hai bản.
  ///
  /// Chỉ chốt khi: có text, câu CHƯA final, và text khác câu vừa chốt (dedup).
  Future<void> _flushActivePartialBeforeClose() async {
    final active = _activeCaption;
    if (active == null) return;
    final text = active.sourceText.trim();
    if (text.isEmpty) return;
    if (active.isFinal) return; // đã đi qua đường final bình thường
    if (!_deduper.shouldFinalize(text)) return;
    debugPrint('🧹 Cabin: chốt nốt câu đang nhận trước khi đóng phiên '
        '(${text.length} ký tự)');
    _trackFinalization(text);
  }

  Future<void> _drainPendingFinalizations() async {
    while (_pendingFinalizations.isNotEmpty) {
      final pending = List<Future<void>>.of(_pendingFinalizations);
      try {
        // Future.wait waits for all futures by default, even if one fails.
        await Future.wait(pending);
      } catch (error) {
        debugPrint('⚠️ Cabin final transcript flush failed: $error');
      }
      _pendingFinalizations.removeWhere(pending.contains);
    }
  }

  void _trackFinalization(String text) {
    // AUDIT-1.21.0 #3: chốt DUY NHẤT một lần cho mỗi câu, kể cả khi engine
    // phát lại `isFinal` lúc bản dịch (async) vẫn đang chạy. `begin()` phải
    // chạy TRƯỚC mọi await, `complete()` chạy ở mọi nhánh (kể cả lỗi dịch).
    if (!_deduper.shouldFinalize(text)) {
      debugPrint('⏭️ Cabin: bỏ qua finalization trùng "${text.trim()}"');
      return;
    }
    _deduper.begin(text);
    final outcome = CabinFinalizationOutcome();
    final future = _finalizeCurrentChunk(text, outcome: outcome).whenComplete(
      // AUDIT-1.21.0 #3 (recheck): nếu `_finalizeCurrentChunk` return sớm
      // (vd đang `speaking`) thì KHÔNG có caption nào ⇒ chỉ cancel, không
      // `complete()`, kẻo câu bị nhớ 8s rồi replay final bị nuốt ⇒ mất câu.
      () => _deduper.finish(text, createdCaption: outcome.createdCaption),
    );
    _pendingFinalizations.add(future);
    future.then<void>(
      (_) {
        _pendingFinalizations.remove(future);
      },
      onError: (Object error, StackTrace stack) {
        _pendingFinalizations.remove(future);
        debugPrint('⚠️ Cabin transcript finalization failed: $error');
      },
    );
  }

  Future<void> _finalizeCurrentChunk(
    String text, {
    CabinFinalizationOutcome? outcome,
  }) async {
    _silenceTimer?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_state == CabinState.speaking) return;
    // AUDIT-1.21.0 #3: KHÔNG dùng `_lastFinalizedText` để chặn ở đây nữa
    // (nó không bao giờ được xoá trong phiên ⇒ nói lại cùng câu sau 8s sẽ bị
    // nuốt). `_deduper` đã chốt ở `_trackFinalization` trước khi vào hàm.
    _lastFinalizedText = trimmed;

    // Freeze the direction before the translation await. The user may swap
    // languages while an earlier sentence is still being translated.
    final chunkSourceLang = sourceLanguage;
    final chunkTargetLang = _targetLanguage;
    final recorder = _recorder;
    final startOffset = _chunkStartOffset ?? recorder?.elapsed ?? Duration.zero;
    _chunkStartOffset = null;

    _state = CabinState.translating;
    notifyListeners();

    final captionId = _newCaptionId();
    final overlaySequence = _overlaySequence++;
    String translated = '';
    String engine = 'Auto';

    try {
      final result = await _translator.translateText(
        trimmed,
        sourceLang: chunkSourceLang,
        targetLang: chunkTargetLang,
      );
      translated = result.translatedText.trim();
      engine = result.engineName;
      // Do not duplicate source text if engine returned failure/empty
      if (!result.isSuccess || translated == trimmed) {
        translated = '';
      }
    } catch (e) {
      debugPrint('⚠️ SttsCabinService translation error: $e');
      translated = '';
    }

    final finalizedCaption = CabinCaption(
      id: captionId,
      timestamp: DateTime.now(),
      sourceText: trimmed,
      translatedText: translated,
      sourceLang: chunkSourceLang,
      targetLang: chunkTargetLang,
      engineUsed: engine,
      isFinal: true,
    );

    // CABIN-KEEP-PARTIAL-001 (2026-10-29): KHÔNG đè câu đang nhận mới hơn.
    //
    // Dịch là async (có thể mất vài giây). Trong lúc chờ, người dùng đã nói
    // tiếp ⇒ `_activeCaption` đã là câu MỚI. Nếu gán đè bằng câu vừa dịch xong
    // thì câu mới **biến mất** (không caption, không kịp chốt) — đúng kiểu
    // "nhận diện thiếu". Chỉ gán khi chưa có gì mới hơn.
    final current = _activeCaption;
    final hasNewerPartial = current != null &&
        !current.isFinal &&
        current.sourceText.trim().isNotEmpty &&
        current.sourceText.trim() != trimmed;
    if (!hasNewerPartial) {
      _activeCaption = finalizedCaption;
    }
    // Translation is asynchronous: keep the newest completed translation even
    // when a newer partial is on screen, and ignore late older completions.
    if (overlaySequence > _overlayLastSequence) {
      _overlayLastSequence = overlaySequence;
      _pushSystemCaption(hasNewerPartial ? current! : finalizedCaption,
          translation: translated);
    }
    _history.add(finalizedCaption);
    // AUDIT-1.21.0 #3: điểm "không thể quay lại" — caption ĐÃ được tạo, nên
    // `finish()` mới được phép `complete()` (nhớ 8s để chống replay final).
    outcome?.createdCaption = true;
    _captionStreamController.add(finalizedCaption);

    // CABIN-SAVE-001: ghi câu đã chốt vào journal phiên (ghi đĩa ngay).
    if (recorder != null) _captionRecorders[captionId] = recorder;
    recorder?.addEntry(CabinTranscriptEntry(
      id: captionId,
      offset: startOffset,
      sourceLang: chunkSourceLang,
      targetLang: chunkTargetLang,
      sourceText: trimmed,
      translatedText: translated,
    ));

    // Speak translation if Dubbing is enabled
    if (_isDubbingEnabled && translated.isNotEmpty) {
      _state = CabinState.speaking;
      notifyListeners();
      final muteCapture = _audioSource == CabinAudioSource.systemAudio;
      if (muteCapture) _systemTtsDepth++;
      try {
        await _tts.speak(translated, language: chunkTargetLang);
        await _tts.waitForCompletion();
        // Brief pause to prevent pickup after audio output ceases.
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('⚠️ SttsCabinService Dubbing TTS error: $e');
      } finally {
        if (muteCapture) _systemTtsDepth--;
      }
    }

    if (isListening) {
      _state = CabinState.listening;
      // Audio focus during TTS playback on Android can terminate SpeechRecognizer session.
      // Re-arm the system recognizer if it went inactive.
      if (_sttEngineType == CabinSttEngineType.system && !_stt.isLiveListening) {
        await _tryStartSystemEngine();
      }
    }
    // AUDIT-1.21.0 #3: KHÔNG còn `Future.delayed(3s)` xoá
    // `_lastFinalizedText`. Chính delayed đó tắt cửa sổ chống trùng khi bản
    // dịch chậm > 3s ⇒ engine replay final tạo dòng thứ 2. Cửa sổ giờ do
    // `_deduper` quản lý (in-flight + 8s), `whenComplete` ở `_trackFinalization`
    // bảo đảm luôn đóng đúng lúc, kể cả khi dịch lỗi.
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
