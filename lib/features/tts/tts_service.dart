// lib/features/tts/tts_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language/app_language.dart';
import 'cache/tts_cache.dart';
import 'engines/fpt_tts_engine.dart';
import 'engines/tts_engine.dart';
import 'engines/google_tts_engine.dart';
import 'engines/offline_tts_engine.dart';
import 'engines/piper_tts_engine.dart';
import 'engines/zalo_tts_engine.dart';
import 'language_detector.dart';
import 'tts_settings.dart';

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

  // Settings Keys
  static const _kPriorityKey = 'tts_priority_mode';
  static const _kEngineOrderKey = 'tts_engine_order_json';
  static const _kFptApiKey = 'tts_fpt_api_key';
  static const _kZaloApiKey = 'tts_zalo_api_key';
  static const _kSpeedKey = 'tts_speed_val';
  static const _kPitchKey = 'tts_pitch_val';

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
    _loadPersistedSettings();

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
        name: 'Piper (neural / Sherpa)',
        description: 'Offline, giọng neural đã import',
        isOnline: false,
        priority: 0,
      ),
      const TtsEngineInfo(
        id: 'offline_tts',
        name: 'Offline (Máy)',
        description: 'Phát ngay, giọng máy hệ thống',
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

  Future<void> _loadPersistedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final priorityStr = prefs.getString(_kPriorityKey);
      if (priorityStr != null) {
        for (final p in TtsPriority.values) {
          if (p.name == priorityStr) {
            _priority = p;
            break;
          }
        }
      }

      _fptApiKey = prefs.getString(_kFptApiKey);
      _zaloApiKey = prefs.getString(_kZaloApiKey);
      _speed = prefs.getDouble(_kSpeedKey) ?? _speed;
      _pitch = prefs.getDouble(_kPitchKey) ?? _pitch;

      final engineJson = prefs.getString(_kEngineOrderKey);
      if (engineJson != null && engineJson.isNotEmpty) {
        final decoded = jsonDecode(engineJson) as List<dynamic>;
        final map = <String, bool>{};
        final orderList = <String>[];
        for (final item in decoded) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            final enabled = item['enabled'] == true;
            if (id.isNotEmpty) {
              map[id] = enabled;
              orderList.add(id);
            }
          }
        }

        final currentMap = {for (final e in _engineOrder) e.id: e};
        final reordered = <TtsEngineInfo>[];
        for (final id in orderList) {
          if (currentMap.containsKey(id)) {
            final existing = currentMap.remove(id)!;
            reordered.add(existing.copyWith(
              isEnabled: map[id] ?? existing.isEnabled,
              priority: reordered.length,
            ));
          }
        }
        // Thêm các engine mới chưa có trong saved json
        for (final remaining in currentMap.values) {
          reordered.add(remaining.copyWith(priority: reordered.length));
        }
        _engineOrder = reordered;
      }
      _safeNotify();
    } catch (e) {
      debugPrint('⚠️ TtsService load settings error: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPriorityKey, _priority.name);
      if (_fptApiKey != null) {
        await prefs.setString(_kFptApiKey, _fptApiKey!);
      } else {
        await prefs.remove(_kFptApiKey);
      }
      if (_zaloApiKey != null) {
        await prefs.setString(_kZaloApiKey, _zaloApiKey!);
      } else {
        await prefs.remove(_kZaloApiKey);
      }
      await prefs.setDouble(_kSpeedKey, _speed);
      await prefs.setDouble(_kPitchKey, _pitch);

      final serialized = _engineOrder
          .map((e) => {'id': e.id, 'enabled': e.isEnabled})
          .toList();
      await prefs.setString(_kEngineOrderKey, jsonEncode(serialized));
    } catch (e) {
      debugPrint('⚠️ TtsService save settings error: $e');
    }
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
    _saveSettings();
    _safeNotify();
  }

  void reorderEngines(List<TtsEngineInfo> newOrder) {
    _engineOrder = newOrder
        .asMap()
        .entries
        .map((e) => e.value.copyWith(priority: e.key))
        .toList();
    _saveSettings();
    _safeNotify();
  }

  void toggleEngine(String engineId, bool enabled) {
    _engineOrder = _engineOrder.map((e) {
      if (e.id == engineId) return e.copyWith(isEnabled: enabled);
      return e;
    }).toList();
    _saveSettings();
    _safeNotify();
  }

  void setPriority(TtsPriority p) {
    _priority = p;
    _saveSettings();
    _safeNotify();
  }

  // ═══════════════════════════════════════
  // 🔥 SPEAK - CƠ CHẾ LINH HOẠT & ƯU TIÊN
  // ═══════════════════════════════════════

  /// Danh sách candidate engines theo thứ tự ưu tiên cấu hình
  List<TtsEngineInfo> _getCandidateEngines(TtsPriority priority) {
    final enabled = _engineOrder.where((e) => e.isEnabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    switch (priority) {
      case TtsPriority.offlineFirst:
        // Offline trước (Piper Sherpa, Máy), sau đó Online (Google, Zalo, FPT)
        final off = enabled.where((e) => !e.isOnline).toList();
        final on = enabled.where((e) => e.isOnline).toList();
        return [...off, ...on];

      case TtsPriority.onlineFirst:
        // Online trước, sau đó fallback Offline
        final on = enabled.where((e) => e.isOnline).toList();
        final off = enabled.where((e) => !e.isOnline).toList();
        return [...on, ...off];

      case TtsPriority.offlineOnly:
        // Chỉ offline
        return enabled.where((e) => !e.isOnline).toList();

      case TtsPriority.onlineOnly:
        // Online trước, fallback offline nếu cần thiết
        final on = enabled.where((e) => e.isOnline).toList();
        final off = enabled.where((e) => !e.isOnline).toList();
        return [...on, ...off];
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();

    _error = null;
    _stopRequested = false;

    final lang = _resolveLanguage(text);
    _detectedLanguage = lang;

    // 1. Kiểm tra cache trước
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

    // 2. Chạy qua danh sách engine theo thứ tự ưu tiên
    final candidates = _getCandidateEngines(_priority);
    var played = false;

    for (final engineInfo in candidates) {
      if (_stopRequested) break;

      switch (engineInfo.id) {
        case 'piper_tts':
          played = await _trySpeakPiper(text, lang);
          break;

        case 'offline_tts':
          played = await _trySpeakOffline(text, lang);
          break;

        case 'google_tts':
          played = await _trySpeakOnline(GoogleTtsEngine(), text, lang);
          break;

        case 'zalo_tts':
          if (_zaloApiKey != null &&
              _zaloApiKey!.isNotEmpty &&
              lang.startsWith('vi')) {
            played = await _trySpeakOnline(
              ZaloTtsEngine(apiKey: _zaloApiKey),
              text,
              lang,
            );
          }
          break;

        case 'fpt_tts':
          if (_fptApiKey != null &&
              _fptApiKey!.isNotEmpty &&
              lang.startsWith('vi')) {
            played = await _trySpeakOnline(
              FptTtsEngine(apiKey: _fptApiKey),
              text,
              lang,
            );
          }
          break;
      }

      if (played) {
        // Nếu dùng offline và chế độ offlineFirst, kích hoạt prefetch online nền
        if (_priority == TtsPriority.offlineFirst) {
          _prefetchOnline(text, lang);
        }
        return;
      }
    }

    // Nếu tất cả candidate engines đều thất bại, thử fallback khẩn cấp sang Offline (Máy)
    if (!played && !_stopRequested) {
      debugPrint('⚠️ Tất cả engine ưu tiên thất bại, thử fallback khẩn cấp sang Offline Máy');
      played = await _trySpeakOffline(text, lang);
    }

    if (!played && !_stopRequested) {
      _error = 'Không có engine TTS nào phát được văn bản này ($lang).';
      _isLoading = false;
      _isSpeaking = false;
      _safeNotify();
    }
  }

  /// Thử phát bằng Sherpa Piper neural TTS.
  /// Trả về true nếu thành công, false nếu không có model / lỗi để tự động fallback.
  Future<bool> _trySpeakPiper(String text, String lang) async {
    try {
      final piper = PiperTtsEngine.instance;
      if (!await piper.isAvailable()) return false;

      _usingOfflineEngine = false;
      _isLoading = true;
      _safeNotify();

      final result = await piper.synthesize(
        text: text,
        language: lang,
        speed: _speed,
        pitch: _pitch,
        voiceId: _selectedVoiceId,
      );

      _isLoading = false;

      if (!result.isSuccess ||
          result.audioData == null ||
          result.audioData!.isEmpty) {
        debugPrint('ℹ️ Sherpa Piper TTS không khả dụng cho $lang (${result.error}), fallback sang engine tiếp theo');
        _safeNotify();
        return false;
      }

      final filePath = await _cache.put(
        text: text,
        language: lang,
        engineId: piper.id,
        audioData: result.audioData!,
      );

      _lastUsedEngine = '🎙️ Sherpa Piper';
      _safeNotify();
      await _playFile(filePath);
      return true;
    } catch (e) {
      debugPrint('⚠️ Piper TTS error: $e, fallback tiếp');
      _isLoading = false;
      _safeNotify();
      return false;
    }
  }

  /// Thử phát bằng Offline TTS (giọng máy thiết bị qua flutter_tts)
  Future<bool> _trySpeakOffline(String text, String lang) async {
    _usingOfflineEngine = true;
    _lastUsedEngine = '📖 Offline (Máy)';
    _isSpeaking = true;
    _safeNotify();

    try {
      await _offlineEngine.speakDirect(
        text: text,
        language: lang,
        speed: _speed,
        pitch: _pitch,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ OfflineTTS direct error: $e');
      return false;
    } finally {
      _usingOfflineEngine = false;
      _isSpeaking = false;
      _safeNotify();
    }
  }

  /// Thử phát bằng Online Engine (Google, Zalo, FPT)
  Future<bool> _trySpeakOnline(TtsEngine engine, String text, String lang) async {
    final hasNet = await _checkNetwork();
    if (!hasNet) return false;

    _isLoading = true;
    _safeNotify();

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

      _isLoading = false;

      if (result.isSuccess) {
        if (result.audioData != null && result.audioData!.isNotEmpty) {
          final filePath = await _cache.put(
            text: text,
            language: lang,
            engineId: engine.id,
            audioData: result.audioData!,
          );

          _lastUsedEngine = '🌐 ${result.engineName}';
          _safeNotify();
          await _playFile(filePath);
          return true;
        } else if (result.audioUrl != null) {
          _lastUsedEngine = '🌐 ${result.engineName}';
          _safeNotify();
          await _playUrl(result.audioUrl!);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Online ${engine.name} error: $e');
      _isLoading = false;
      _safeNotify();
      return false;
    }
  }

  /// Prefetch: tải online ở nền để cache cho lần sau
  void _prefetchOnline(String text, String lang) {
    if (_isPrefetching) return;
    _isPrefetching = true;

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
      voices.addAll(await _offlineEngine.getAvailableVoices(effectiveLang));
    } catch (_) {}
    try {
      voices.addAll(
        await PiperTtsEngine.instance.getAvailableVoices(effectiveLang),
      );
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
    status[_offlineEngine.name] = await _offlineEngine.isAvailable();
    try {
      status[PiperTtsEngine.instance.name] =
          await PiperTtsEngine.instance.isAvailable();
    } catch (_) {
      status[PiperTtsEngine.instance.name] = false;
    }
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
