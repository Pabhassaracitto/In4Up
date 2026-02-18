// lib/features/tts/tts_service.dart
// ★ THAY THẾ TOÀN BỘ

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'engines/tts_engine.dart';
import 'engines/google_tts_engine.dart';
import 'engines/fpt_tts_engine.dart';
import 'engines/zalo_tts_engine.dart';
import 'engines/offline_tts_engine.dart';
import 'cache/tts_cache.dart';
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

  // Settings
  TtsPriority _priority = TtsPriority.offlineFirst; // ★ Mặc định OFFLINE
  String _language = 'auto';
  double _speed = 1.0;
  double _pitch = 1.0;
  String? _selectedVoiceId;
  String? _fptApiKey;
  String? _zaloApiKey;
  bool _autoDetectLanguage = true;

  // Engine order (user có thể thay đổi)
  List<TtsEngineInfo> _engineOrder = [];

  // Status
  bool _isSpeaking = false;
  bool _isLoading = false;
  String _lastUsedEngine = '';
  String _detectedLanguage = '';
  String? _error;

  // ★ THÊM: Prefetch cho mode offlineFirst
  bool _isPrefetching = false;

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
      final wasPlaying = _isSpeaking;
      if (state.processingState == ProcessingState.completed) {
        _isSpeaking = false;
      } else if (state.playing) {
        _isSpeaking = true;
      }
      if (wasPlaying != _isSpeaking) notifyListeners();
    });
  }

  void _buildDefaultEngineOrder() {
    _engineOrder = [
      const TtsEngineInfo(
        id: 'offline_tts',
        name: 'Offline (Máy)',
        description: 'Phát ngay, giọng máy',
        isOnline: false,
        priority: 0,
      ),
      const TtsEngineInfo(
        id: 'google_tts',
        name: 'Google TTS',
        description: 'Miễn phí, khá tự nhiên',
        priority: 1,
      ),
      const TtsEngineInfo(
        id: 'zalo_tts',
        name: 'Zalo AI',
        description: 'Tiếng Việt cực tự nhiên',
        needsApiKey: true,
        priority: 2,
      ),
      const TtsEngineInfo(
        id: 'fpt_tts',
        name: 'FPT.AI',
        description: 'Tiếng Việt tự nhiên, nhiều giọng',
        needsApiKey: true,
        priority: 3,
      ),
    ];
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
    if (language != null) _language = language;
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
    notifyListeners();
  }

  /// Thay đổi thứ tự engine
  void reorderEngines(List<TtsEngineInfo> newOrder) {
    _engineOrder = newOrder
        .asMap()
        .entries
        .map((e) => e.value.copyWith(priority: e.key))
        .toList();
    notifyListeners();
  }

  /// Bật/tắt engine
  void toggleEngine(String engineId, bool enabled) {
    _engineOrder = _engineOrder.map((e) {
      if (e.id == engineId) return e.copyWith(isEnabled: enabled);
      return e;
    }).toList();
    notifyListeners();
  }

  /// Đặt priority mode
  void setPriority(TtsPriority p) {
    _priority = p;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  // 🔥 SPEAK - HÀM CHÍNH
  // ═══════════════════════════════════════

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();

    _error = null;

    // Detect language
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

  /// ★ MODE 1: Offline trước → phát ngay, tải online nền
  Future<void> _speakOfflineFirst(String text, String lang) async {
    // Check cache trước
    final cachedPath = await _cache.get(
      text: text,
      language: lang,
      engineId: 'any',
    );

    if (cachedPath != null) {
      _lastUsedEngine = '💾 Cache';
      notifyListeners();
      await _playFile(cachedPath);
      return;
    }

    // Phát offline NGAY LẬP TỨC
    _lastUsedEngine = '📖 Offline';
    _isSpeaking = true;
    notifyListeners();

    await _offlineEngine.speakDirect(
      text: text,
      language: lang,
      speed: _speed,
      pitch: _pitch,
    );

    // ★ Tải online ở nền để lần sau phát đẹp hơn
    _prefetchOnline(text, lang);
  }

  /// ★ MODE 2: Online trước → chờ tải, chất lượng cao
  Future<void> _speakOnlineFirst(String text, String lang) async {
    // Check cache
    final cachedPath = await _cache.get(
      text: text,
      language: lang,
      engineId: 'any',
    );

    if (cachedPath != null) {
      _lastUsedEngine = '💾 Cache';
      notifyListeners();
      await _playFile(cachedPath);
      return;
    }

    _isLoading = true;
    notifyListeners();

    final hasNetwork = await _checkNetwork();

    if (hasNetwork) {
      // Thử online engines theo thứ tự user đã chọn
      final engines = _getOnlineEngines(lang);

      for (final engine in engines) {
        try {
          debugPrint('🔄 TTS trying ${engine.name}...');

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
              notifyListeners();
              await _playFile(filePath);
              return;
            } else if (result.audioUrl != null) {
              _lastUsedEngine = '🌐 ${result.engineName}';
              _isLoading = false;
              notifyListeners();
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
    _lastUsedEngine = '📖 Offline';
    _isSpeaking = true;
    notifyListeners();

    await _offlineEngine.speakDirect(
      text: text,
      language: lang,
      speed: _speed,
      pitch: _pitch,
    );
  }

  /// MODE 3: Chỉ offline
  Future<void> _speakOfflineOnly(String text, String lang) async {
    // Vẫn check cache (cache từ lần online trước)
    final cachedPath = await _cache.get(
      text: text,
      language: lang,
      engineId: 'any',
    );

    if (cachedPath != null) {
      _lastUsedEngine = '💾 Cache';
      notifyListeners();
      await _playFile(cachedPath);
      return;
    }

    _lastUsedEngine = '📖 Offline';
    _isSpeaking = true;
    notifyListeners();

    await _offlineEngine.speakDirect(
      text: text,
      language: lang,
      speed: _speed,
      pitch: _pitch,
    );
  }

  /// ★ Prefetch: tải online ở nền để cache cho lần sau
  void _prefetchOnline(String text, String lang) {
    if (_isPrefetching) return;
    _isPrefetching = true;
    notifyListeners();

    Future(() async {
      try {
        final hasNetwork = await _checkNetwork();
        if (!hasNetwork) return;

        // Đã có cache rồi thì thôi
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
              return; // Chỉ cần 1 engine thành công
            }
          } catch (_) {}
        }
      } finally {
        _isPrefetching = false;
        notifyListeners();
      }
    });
  }

  /// Lấy online engines theo thứ tự user chọn
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
    if (!_autoDetectLanguage && _language != 'auto') return _language;
    return LanguageDetector.detect(text);
  }

  // ═══════════════════════════════════════
  // PLAYBACK
  // ═══════════════════════════════════════

  Future<void> stop() async {
    _isSpeaking = false;
    _isLoading = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _offlineEngine.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
    _isSpeaking = true;
    notifyListeners();
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
    notifyListeners();

    for (int i = 0; i < lines.length; i++) {
      if (!_isSpeaking) break;
      onLineChanged?.call(i);
      await speak(lines[i]);
      await _waitForCompletion();
      if (_isSpeaking && i < lines.length - 1) {
        await Future.delayed(pauseBetween);
      }
    }

    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> speakRepeat(
    String text, {
    int times = 3,
    Duration pauseBetween = const Duration(milliseconds: 800),
    void Function(int current, int total)? onRepeat,
  }) async {
    _isSpeaking = true;
    notifyListeners();

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
  // VOICES
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

    return voices;
  }

  // ═══════════════════════════════════════
  // STATUS
  // ═══════════════════════════════════════

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
    return status;
  }

  List<String> get activeEngines {
    final lang = _language == 'auto' ? 'vi-VN' : _language;
    return [
      ..._getOnlineEngines(lang).map((e) => e.name),
      _offlineEngine.name,
    ];
  }

  // ═══════════════════════════════════════
  // CACHE
  // ═══════════════════════════════════════

  Future<double> getCacheSizeMB() => _cache.getCacheSizeMB();
  Future<int> getCacheCount() => _cache.getCacheCount();
  Future<void> clearCache() => _cache.clear();

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  Future<void> _playFile(String filePath) async {
    try {
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.setSpeed(_speed);
      _isSpeaking = true;
      notifyListeners();
      await _audioPlayer.play();
    } catch (e) {
      _error = 'Lỗi phát: $e';
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> _playUrl(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.setSpeed(_speed);
      _isSpeaking = true;
      notifyListeners();
      await _audioPlayer.play();
    } catch (e) {
      _error = 'Lỗi stream: $e';
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> _waitForCompletion() async {
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    _offlineEngine.dispose();
    super.dispose();
  }
}
