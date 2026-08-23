// lib/features/tts/tts_service.dart

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/language/app_language.dart';
import 'cache/tts_cache.dart';
import 'engines/fpt_tts_engine.dart';
import 'engines/piper_tts_engine.dart';
import 'engines/tts_engine.dart';
import 'engines/google_tts_engine.dart';
import 'engines/offline_tts_engine.dart';
import 'engines/zalo_tts_engine.dart';
import 'language_detector.dart';
import 'tts_settings.dart';
// VoidCallback

class TtsService extends ChangeNotifier {
  // ═══════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════

  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._() {
    _init();
  }

  // ═══════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════

  final AudioPlayer _audioPlayer = AudioPlayer();
  final TtsCache _cache = TtsCache();
  final OfflineTtsEngine _offlineEngine = OfflineTtsEngine();

  // ★ Piper offline neural (sherpa_onnx) — offline but sinh BYTES (WAV) nên
  //   cache + phát qua just_audio như engine online. Ưu tiên trước flutter_tts
  //   khi có model; user tắt trong settings nếu muốn giọng máy "phát ngay".
  final PiperTtsEngine _piperEngine = PiperTtsEngine();

  // Settings
  TtsPriority _priority = TtsPriority.offlineFirst;
  String _language = 'auto';
  double _speed = 1.0;
  double _pitch = 1.0;
  String? _selectedVoiceId;
  String? _fptApiKey;
  String? _zaloApiKey;
  bool _autoDetectLanguage = true;

  List<TtsEngineInfo> _engineOrder = [];

  // Status
  bool _isSpeaking = false;
  bool _isLoading = false;
  bool _stopRequested = false;
  String _lastUsedEngine = '';
  String _detectedLanguage = '';
  String? _error;
  bool _isPrefetching = false;

  // ★ FIX: Track nguồn âm thanh đang dùng để tránh xung đột state
  bool _usingOfflineEngine = false;

  // ★ FIX: Guard chống notify sau khi dispose
  bool _disposed = false;

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get isLoading => _isLoading;
  String get lastUsedEngine => _lastUsedEngine;
  String get detectedLanguage => _detectedLanguage;
  String? get error => _error;
  String get language => _language;
  double get speed => _speed;
  double get pitch => _pitch;
  String? get selectedVoiceId => _selectedVoiceId;
  String? get fptApiKey => _fptApiKey;
  String? get zaloApiKey => _zaloApiKey;
  bool get autoDetectLanguage => _autoDetectLanguage;
  TtsPriority get priority => _priority;
  bool get isPrefetching => _isPrefetching;
  List<TtsEngineInfo> get engineOrder => List.unmodifiable(_engineOrder);

  // ═══════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════

  void _init() {
    _buildDefaultEngineOrder();

    _audioPlayer.playerStateStream.listen((state) {
      // ★ FIX: Chỉ xử lý stream khi đang dùng AudioPlayer (KHÔNG dùng OfflineEngine)
      if (_usingOfflineEngine) return;

      final wasPlaying = _isSpeaking;
      if (state.processingState == ProcessingState.completed) {
        _isSpeaking = false;
      } else if (state.playing) {
        _isSpeaking = true;
      }
      if (wasPlaying != _isSpeaking) _safeNotify();
    });
  }

  void _buildDefaultEngineOrder() {
    _engineOrder = [
      const TtsEngineInfo(
        id: 'piper_tts',
        name: 'Piper (Offline Neural)',
        description: 'Neural local, cần model .onnx — tự nhiên nhất',
        isOnline: false,
        priority: 0,
      ),
      const TtsEngineInfo(
        id: 'offline_tts',
        name: 'Offline (Máy)',
        description: 'Phát ngay, giọng máy',
        isOnline: false,
        priority: 1,
      ),
      const TtsEngineInfo(
        id: 'google_tts',
        name: 'Google TTS',
        description: 'Miễn phí, khá tự nhiên',
        priority: 2,
      ),
      const TtsEngineInfo(
        id: 'zalo_tts',
        name: 'Zalo AI',
        description: 'Tiếng Việt cực tự nhiên',
        needsApiKey: true,
        priority: 3,
      ),
      const TtsEngineInfo(
        id: 'fpt_tts',
        name: 'FPT.AI',
        description: 'Tiếng Việt tự nhiên, nhiều giọng',
        needsApiKey: true,
        priority: 4,
      ),
    ];
  }

  /// ★ FIX: Bọc notifyListeners để tránh crash khi đã dispose
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════

  void configure({
    String? language,
    double? speed,
    double? pitch,
    String? voiceId,
    String? fptApiKey,
    String? zaloApiKey,
    bool? autoDetect,
    TtsPriority? priority,
  }) {
    if (language != null) {
      final isAuto = language.toLowerCase() == 'auto';
      final normalized = isAuto
          ? 'auto'
          : AppLanguageCatalog.fromCode(language).ttsLocale;
      if (_language != normalized) _selectedVoiceId = null;
      _language = normalized;
    }
    if (speed != null) _speed = speed.clamp(0.25, 2.0);
    if (pitch != null) _pitch = pitch.clamp(0.5, 2.0);
    if (voiceId != null) _selectedVoiceId = voiceId;
    if (autoDetect != null) _autoDetectLanguage = autoDetect;
    if (priority != null) _priority = priority;
    if (fptApiKey != null) {
      _fptApiKey = fptApiKey.trim().isEmpty ? null : fptApiKey.trim();
    }
    if (zaloApiKey != null) {
      _zaloApiKey = zaloApiKey.trim().isEmpty ? null : zaloApiKey.trim();
    }
    _safeNotify();
  }

  void reorderEngines(List<TtsEngineInfo> newOrder) {
    _engineOrder = newOrder
        .asMap()
        .entries
        .map((e) => e.value.copyWith(priority: e.key))
        .toList();
    _safeNotify();
  }

  void toggleEngine(String engineId, bool enabled) {
    _engineOrder = _engineOrder.map((e) {
      if (e.id == engineId) return e.copyWith(isEnabled: enabled);
      return e;
    }).toList();
    _safeNotify();
  }

  void setPriority(TtsPriority p) {
    _priority = p;
    _safeNotify();
  }

  // ═══════════════════════════════════════
  // 🔥 SPEAK - HÀM CHÍNH
  // ═══════════════════════════════════════

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();

    _error = null;

    final lang = _resolveLanguage(text);
    _detectedLanguage = lang;

    switch (_priority) {
      case TtsPriority.offlineFirst:
        await _speakOfflineFirst(text, lang);
        break;
      case TtsPriority.onlineFirst:
        await _speakOnlineFirst(text, lang);
        break;
      case TtsPriority.offlineOnly:
        await _speakOfflineOnly(text, lang);
        break;
      case TtsPriority.onlineOnly:
        await _speakOnlineFirst(text, lang);
        break;
    }
  }

  /// Piper offline neural: sinh WAV + cache, trả file path.
  /// Trả null nếu: user tắt Piper trong settings / chưa có model / lỗi —
  /// caller tự rơi xuống flutter_tts (pipeline không gãy).
  Future<String?> _tryPiper(String text, String lang) async {
    final info = _engineOrder.firstWhere(
      (e) => e.id == 'piper_tts',
      orElse: () => const TtsEngineInfo(
        id: 'piper_tts',
        name: 'Piper (Offline Neural)',
        description: '',
        isOnline: false,
      ),
    );
    if (!info.isEnabled) return null;

    // Cache riêng Piper (key cụ thể 'piper_tts') — tránh re-synth mỗi lần
    // đọc lại. (Lookup chung 'any' của service là quirk legacy không match
    // key cụ thể — không đụng ở bước này, chỉ thêm hit-check phía Piper.)
    try {
      final cachedPiper = await _cache.get(
        text: text,
        language: lang,
        engineId: 'piper_tts',
      );
      if (cachedPiper != null) return cachedPiper;
    } catch (_) {}

    try {
      // Chỉ dùng voiceId khi user chọn giọng PIPER — giọng của engine
      // khác (Google/Zalo...) thì để Piper tự chọn khớp language.
      final piperVoiceId =
          (_selectedVoiceId?.startsWith(PiperTtsEngine.voiceIdPrefix) ?? false)
              ? _selectedVoiceId
              : null;

      final result = await _piperEngine
          .synthesize(
            text: text,
            language: lang,
            speed: _speed,
            voiceId: piperVoiceId,
          )
          .timeout(const Duration(seconds: 30));

      if (result.isSuccess &&
          result.audioData != null &&
          result.audioData!.isNotEmpty) {
        return await _cache.put(
          text: text,
          language: lang,
          engineId: 'piper_tts',
          audioData: result.audioData!,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Piper TTS: $e');
    }
    return null;
  }

  /// MODE 1: Offline trước → phát ngay, tải online nền
  Future<void> _speakOfflineFirst(String text, String lang) async {
    // Check cache trước
    final cachedPath = await _cache.get(
      text: text,
      language: lang,
      engineId: 'any',
    );

    if (cachedPath != null) {
      _lastUsedEngine = '💾 Cache';
      _safeNotify();
      await _playFile(cachedPath);
      return;
    }

    // Piper local model (offline neural) — có model khớp thì dùng trước
    // giọng máy; không có model → discoverVoices() trả [] nhanh, bỏ qua.
    final piperPath = await _tryPiper(text, lang);
    if (piperPath != null) {
      _lastUsedEngine = '🎙️ Piper';
      _safeNotify();
      await _playFile(piperPath);
      return;
    }

    // ★ FIX: Đánh dấu đang dùng offline engine TRƯỚC KHI set _isSpeaking
    _usingOfflineEngine = true;
    _lastUsedEngine = '📖 Offline';
    _isSpeaking = true;
    _safeNotify();

    try {
      await _offlineEngine.speakDirect(
        text: text,
        language: lang,
        speed: _speed,
        pitch: _pitch,
      );
    } catch (e) {
      _error = 'Lỗi offline TTS: $e';
      debugPrint('OfflineTTS error: $e');
    } finally {
      // ★ FIX: Reset cờ TRƯỚC KHI update state
      _usingOfflineEngine = false;
      _isSpeaking = false;
      _safeNotify();
    }

    // Tải online ở nền (fire-and-forget)
    _prefetchOnline(text, lang);
  }

  /// MODE 2: Online trước → chờ tải, chất lượng cao
  Future<void> _speakOnlineFirst(String text, String lang) async {
    final cachedPath = await _cache.get(
      text: text,
      language: lang,
      engineId: 'any',
    );

    if (cachedPath != null) {
      _lastUsedEngine = '💾 Cache';
      _safeNotify();
      await _playFile(cachedPath);
      return;
    }

    _isLoading = true;
    _safeNotify();

    final hasNetwork = await _checkNetwork();

    if (hasNetwork) {
      final engines = _getOnlineEngines(lang);

      for (final engine in engines) {
        try {
          final result = await engine
              .synthesize(
                text: text,
                language: lang,
                speed: _speed,
                pitch: _pitch,
                voiceId: _selectedVoiceId,
              )
              .timeout(const Duration(seconds: 15));

          if (result.isSuccess) {
            if (result.audioData != null && result.audioData!.isNotEmpty) {
              final filePath = await _cache.put(
                text: text,
                language: lang,
                engineId: engine.id,
                audioData: result.audioData!,
              );

              _lastUsedEngine = '🌐 ${result.engineName}';
              _isLoading = false;
              _safeNotify();
              await _playFile(filePath);
              return;
            } else if (result.audioUrl != null) {
              _lastUsedEngine = '🌐 ${result.engineName}';
              _isLoading = false;
              _safeNotify();
              await _playUrl(result.audioUrl!);
              return;
            }
          }
        } catch (e) {
          debugPrint('❌ ${engine.name}: $e');
        }
      }
    }

    // Fallback offline
    _isLoading = false;

    // Piper local model (offline neural) — offline tốt nhất, trước giọng máy.
    final piperPath = await _tryPiper(text, lang);
    if (piperPath != null) {
      _lastUsedEngine = '🎙️ Piper';
      _safeNotify();
      await _playFile(piperPath);
      return;
    }

    // ★ FIX: Đánh dấu offline mode
    _usingOfflineEngine = true;
    _lastUsedEngine = '📖 Offline';
    _isSpeaking = true;
    _safeNotify();

    try {
      await _offlineEngine.speakDirect(
        text: text,
        language: lang,
        speed: _speed,
        pitch: _pitch,
      );
    } finally {
      _usingOfflineEngine = false;
      _isSpeaking = false;
      _safeNotify();
    }
  }

  /// MODE 3: Chỉ offline
  Future<void> _speakOfflineOnly(String text, String lang) async {
    final cachedPath = await _cache.get(
      text: text,
      language: lang,
      engineId: 'any',
    );

    if (cachedPath != null) {
      _lastUsedEngine = '💾 Cache';
      _safeNotify();
      await _playFile(cachedPath);
      return;
    }

    // Piper local model — offline hoàn toàn, ưu tiên trước giọng máy.
    final piperPath = await _tryPiper(text, lang);
    if (piperPath != null) {
      _lastUsedEngine = '🎙️ Piper';
      _safeNotify();
      await _playFile(piperPath);
      return;
    }

    // ★ FIX: Đánh dấu offline mode
    _usingOfflineEngine = true;
    _lastUsedEngine = '📖 Offline';
    _isSpeaking = true;
    _safeNotify();

    try {
      await _offlineEngine.speakDirect(
        text: text,
        language: lang,
        speed: _speed,
        pitch: _pitch,
      );
    } finally {
      _usingOfflineEngine = false;
      _isSpeaking = false;
      _safeNotify();
    }
  }

  /// Prefetch: tải online ở nền để cache cho lần sau
  void _prefetchOnline(String text, String lang) {
    if (_isPrefetching) return;
    _isPrefetching = true;
    // ★ FIX: Không gọi _safeNotify ở đây - tránh rebuild không cần thiết

    Future(() async {
      try {
        final hasNetwork = await _checkNetwork();
        if (!hasNetwork) return;

        final existing = await _cache.get(
          text: text,
          language: lang,
          engineId: 'any',
        );
        if (existing != null) return;

        final engines = _getOnlineEngines(lang);

        for (final engine in engines) {
          try {
            final result = await engine
                .synthesize(
                  text: text,
                  language: lang,
                  speed: _speed,
                  pitch: _pitch,
                )
                .timeout(const Duration(seconds: 20));

            if (result.isSuccess &&
                result.audioData != null &&
                result.audioData!.isNotEmpty) {
              await _cache.put(
                text: text,
                language: lang,
                engineId: engine.id,
                audioData: result.audioData!,
              );
              debugPrint('📥 Prefetch done: ${engine.name}');
              return;
            }
          } catch (_) {}
        }
      } finally {
        _isPrefetching = false;
        // ★ FIX: Không notify ở đây - prefetch là silent operation
        // Chỉ notify nếu app còn sống
        if (!_disposed) {
          // Không cần notify - prefetch là background, UI không cần biết
        }
      }
    });
  }

  List<TtsEngine> _getOnlineEngines(String lang) {
    final engines = <TtsEngine>[];
    final sorted = _engineOrder.where((e) => e.isEnabled && e.isOnline).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final info in sorted) {
      switch (info.id) {
        case 'google_tts':
          engines.add(GoogleTtsEngine());
          break;
        case 'zalo_tts':
          if (_zaloApiKey != null &&
              _zaloApiKey!.isNotEmpty &&
              lang.startsWith('vi')) {
            engines.add(ZaloTtsEngine(apiKey: _zaloApiKey));
          }
          break;
        case 'fpt_tts':
          if (_fptApiKey != null &&
              _fptApiKey!.isNotEmpty &&
              lang.startsWith('vi')) {
            engines.add(FptTtsEngine(apiKey: _fptApiKey));
          }
          break;
      }
    }

    return engines;
  }

  String _resolveLanguage(String text) {
    if (_language != 'auto') {
      return AppLanguageCatalog.fromCode(_language).ttsLocale;
    }
    if (_autoDetectLanguage) return LanguageDetector.detect(text);
    return AppLanguageCatalog.english.ttsLocale;
  }

  // ═══════════════════════════════════════
  // PLAYBACK
  // ═══════════════════════════════════════

  Future<void> stop() async {
    _isSpeaking = false;
    _isLoading = false;
    _stopRequested = true;
    _usingOfflineEngine = false; // ★ FIX: Reset cờ khi stop
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _offlineEngine.stop();
    } catch (_) {}
    _safeNotify();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isSpeaking = false;
    _safeNotify();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
    _isSpeaking = true;
    _safeNotify();
  }

  // ═══════════════════════════════════════
  // SPEAK MULTIPLE
  // ═══════════════════════════════════════

  Future<void> speakLines(
    List<String> lines, {
    Duration pauseBetween = const Duration(milliseconds: 500),
    void Function(int currentIndex)? onLineChanged,
  }) async {
    _isSpeaking = true;
    _stopRequested = false;
    _safeNotify();

    for (int i = 0; i < lines.length; i++) {
      if (_stopRequested) break;
      onLineChanged?.call(i);

      await speak(lines[i]);

      // Đảm bảo trạng thái vẫn đang trong phiên đọc
      _isSpeaking = true;

      await _waitForCompletion();
      if (_stopRequested) break;

      if (i < lines.length - 1) {
        await Future.delayed(pauseBetween);
      }
    }

    _isSpeaking = false;
    _safeNotify();
  }

  Future<void> speakRepeat(
    String text, {
    int times = 3,
    Duration pauseBetween = const Duration(milliseconds: 800),
    void Function(int current, int total)? onRepeat,
  }) async {
    _isSpeaking = true;
    _safeNotify();

    for (int i = 0; i < times; i++) {
      if (!_isSpeaking) break;
      onRepeat?.call(i + 1, times);
      await speak(text);
      await _waitForCompletion();
      if (_isSpeaking && i < times - 1) {
        await Future.delayed(pauseBetween);
      }
    }
  }

  // ═══════════════════════════════════════
  // VOICES / STATUS / CACHE
  // ═══════════════════════════════════════

  Future<List<TtsVoice>> getAvailableVoices([String? lang]) async {
    final effectiveLang = lang ?? _language;
    final voices = <TtsVoice>[];
    for (final engine in _getOnlineEngines(effectiveLang)) {
      try {
        voices.addAll(await engine.getAvailableVoices(effectiveLang));
      } catch (_) {}
    }
    try {
      voices.addAll(await _piperEngine.getAvailableVoices(effectiveLang));
    } catch (_) {}
    try {
      voices.addAll(await _offlineEngine.getAvailableVoices(effectiveLang));
    } catch (_) {}
    return voices;
  }

  Future<Map<String, bool>> checkEngineStatus() async {
    final status = <String, bool>{};
    final lang = _language == 'auto' ? 'vi-VN' : _language;
    for (final engine in _getOnlineEngines(lang)) {
      try {
        status[engine.name] =
            await engine.isAvailable().timeout(const Duration(seconds: 5));
      } catch (_) {
        status[engine.name] = false;
      }
    }
    try {
      status[_piperEngine.name] =
          await _piperEngine.isAvailable().timeout(const Duration(seconds: 5));
    } catch (_) {
      status[_piperEngine.name] = false;
    }
    status[_offlineEngine.name] = await _offlineEngine.isAvailable();
    return status;
  }

  List<String> get activeEngines {
    final lang = _language == 'auto' ? 'vi-VN' : _language;
    return [
      ..._getOnlineEngines(lang).map((e) => e.name),
      _offlineEngine.name,
    ];
  }

  Future<double> getCacheSizeMB() => _cache.getCacheSizeMB();
  Future<int> getCacheCount() => _cache.getCacheCount();
  Future<void> clearCache() => _cache.clear();

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  Future<void> _playFile(String filePath) async {
    try {
      _usingOfflineEngine = false; // ★ Đang dùng AudioPlayer
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.setSpeed(_speed);
      _isSpeaking = true;
      _safeNotify();
      await _audioPlayer.play();
    } catch (e) {
      _error = 'Lỗi phát: $e';
      _isSpeaking = false;
      _safeNotify();
    }
  }

  Future<void> _playUrl(String url) async {
    try {
      _usingOfflineEngine = false; // ★ Đang dùng AudioPlayer
      await _audioPlayer.setUrl(url);
      await _audioPlayer.setSpeed(_speed);
      _isSpeaking = true;
      _safeNotify();
      await _audioPlayer.play();
    } catch (e) {
      _error = 'Lỗi stream: $e';
      _isSpeaking = false;
      _safeNotify();
    }
  }

  Future<void> _waitForCompletion() async {
    if (_usingOfflineEngine) return; // ★ Offline đã await trực tiếp rồi
    try {
      await _audioPlayer.playerStateStream
          .firstWhere((s) =>
              s.processingState == ProcessingState.completed ||
              s.processingState == ProcessingState.idle)
          .timeout(const Duration(seconds: 60));
    } catch (_) {}
  }

  Future<bool> _checkNetwork() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════

  @override
  void dispose() {
    _disposed = true; // ★ FIX: Đánh dấu đã dispose trước khi cleanup
    _audioPlayer.dispose();
    _offlineEngine.dispose();
    super.dispose();
  }
}
