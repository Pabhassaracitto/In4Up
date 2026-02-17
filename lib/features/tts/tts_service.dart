// lib/features/tts/tts_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'cache/tts_cache.dart';
import 'engines/fpt_tts_engine.dart';
import 'engines/google_tts_engine.dart';
import 'engines/offline_tts_engine.dart';
import 'engines/tts_engine.dart';
import 'engines/zalo_tts_engine.dart'; // ★ THÊM

/// TTS Service với auto-fallback
///
/// Thứ tự ưu tiên cho TIẾNG VIỆT:
///   1. Cache (đã tải trước đó)
///   2. FPT.AI (nếu có API key - tự nhiên nhất)
///   3. Google Translate TTS (miễn phí, khá tự nhiên)
///   4. Offline flutter_tts (luôn sẵn sàng)
///
/// Thứ tự cho TIẾNG ANH + ngôn ngữ khác:
///   1. Cache
///   2. Google Translate TTS (tốt cho mọi ngôn ngữ)
///   3. Offline flutter_tts
class TtsService extends ChangeNotifier {
  // ═══════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════

  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._() {
    _init();
  }

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  final AudioPlayer _audioPlayer = AudioPlayer();
  final TtsCache _cache = TtsCache();
  final OfflineTtsEngine _offlineEngine = OfflineTtsEngine();

  final List<TtsEngine> _onlineEngines = [];

  // Settings
  String _language = 'vi-VN';
  double _speed = 1.0;
  double _pitch = 1.0;
  String? _selectedVoiceId;
  String? _fptApiKey = 'l3RScswkVRkGBthy81uj5Xyaz8obKzz3';
  String? _zaloApiKey = 'e7UfI0vm7gHyXLLAhCX7Yr7JLHd3bjnN';

  // Status
  bool _isSpeaking = false;
  bool _isLoading = false;
  String _lastUsedEngine = '';
  String? _error;

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get isLoading => _isLoading;
  String get lastUsedEngine => _lastUsedEngine;
  String? get error => _error;
  String get language => _language;
  double get speed => _speed;
  double get pitch => _pitch;
  String? get selectedVoiceId => _selectedVoiceId;
  String? get fptApiKey => _fptApiKey;
  String? get zaloApiKey => _zaloApiKey;

  // ═══════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════

  void _init() {
    _buildEngineList();

    _audioPlayer.playerStateStream.listen((state) {
      final wasPlaying = _isSpeaking;

      if (state.processingState == ProcessingState.completed) {
        _isSpeaking = false;
      } else if (state.playing) {
        _isSpeaking = true;
      }

      if (wasPlaying != _isSpeaking) {
        notifyListeners();
      }
    });
  }

  void _buildEngineList() {
    _onlineEngines.clear();

    // Cho tiếng Việt: Zalo + FPT (tự nhiên nhất)
    if (_language.startsWith('vi')) {
      if (_zaloApiKey != null && _zaloApiKey!.isNotEmpty) {
        _onlineEngines.add(ZaloTtsEngine(apiKey: _zaloApiKey));
      }
      if (_fptApiKey != null && _fptApiKey!.isNotEmpty) {
        _onlineEngines.add(FptTtsEngine(apiKey: _fptApiKey));
      }
    }

    // Google TTS (cho mọi ngôn ngữ)
    _onlineEngines.add(GoogleTtsEngine());

    debugPrint('🔧 TTS Engines: '
        '${_onlineEngines.map((e) => e.name).join(" → ")} → Offline');
  }

  // ═══════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════

  void configure({
    String? language,
    double? speed,
    double? pitch,
    String? voiceId,
    String? fptApiKey,
    String? zaloApiKey,
  }) {
    bool changed = false;

    if (language != null && _language != language) {
      _language = language;
      changed = true;
    }
    if (speed != null) _speed = speed.clamp(0.25, 2.0);
    if (pitch != null) _pitch = pitch.clamp(0.5, 2.0);
    if (voiceId != null) _selectedVoiceId = voiceId;
    if (fptApiKey != null) {
      _fptApiKey = fptApiKey.trim().isEmpty ? null : fptApiKey.trim();
      changed = true;
    }
    if (zaloApiKey != null) {
      _zaloApiKey = zaloApiKey.trim().isEmpty ? null : zaloApiKey.trim();
      changed = true;
    }

    if (changed) _buildEngineList();
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // 🔥 SPEAK - HÀM CHÍNH
  // ═══════════════════════════════════════════

  /// Phát giọng đọc cho text
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    // Dừng audio đang phát
    await stop();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ──── 1. CHECK CACHE ────
      final cachedPath = await _cache.get(
        text: text,
        language: _language,
        engineId: 'any', // Cache không phân biệt engine
      );

      if (cachedPath != null) {
        debugPrint('💾 TTS Cache hit!');
        _lastUsedEngine = '💾 Cache';
        _isLoading = false;
        notifyListeners();
        await _playFile(cachedPath);
        return;
      }

      // ──── 2. CHECK NETWORK ────
      final hasNetwork = await _checkNetwork();

      if (hasNetwork) {
        // ──── 3. THỬ ONLINE ENGINES ────
        for (final engine in _onlineEngines) {
          try {
            debugPrint('🔄 TTS trying ${engine.name}...');

            final result = await engine
                .synthesize(
                  text: text,
                  language: _language,
                  speed: _speed,
                  pitch: _pitch,
                  voiceId: _selectedVoiceId,
                )
                .timeout(const Duration(seconds: 20));

            if (result.isSuccess) {
              if (result.audioData != null && result.audioData!.isNotEmpty) {
                // Có bytes → lưu cache + phát
                final filePath = await _cache.put(
                  text: text,
                  language: _language,
                  engineId: engine.id,
                  audioData: result.audioData!,
                );

                debugPrint('✅ TTS ${engine.name} thành công! '
                    '(${result.responseTime.inMilliseconds}ms)');
                _lastUsedEngine = '🌐 ${result.engineName}';
                _isLoading = false;
                notifyListeners();
                await _playFile(filePath);
                return;
              } else if (result.audioUrl != null) {
                // Có URL → stream trực tiếp
                debugPrint('✅ TTS ${engine.name} → stream URL');
                _lastUsedEngine = '🌐 ${result.engineName}';
                _isLoading = false;
                notifyListeners();
                await _playUrl(result.audioUrl!);
                return;
              }
            } else {
              debugPrint('❌ TTS ${engine.name}: ${result.error}');
            }
          } catch (e) {
            debugPrint('❌ TTS ${engine.name} exception: $e');
          }
        }
      } else {
        debugPrint('📡 Không có mạng, dùng offline TTS...');
      }

      // ──── 4. OFFLINE FALLBACK ────
      debugPrint('📖 Dùng Offline TTS...');
      _lastUsedEngine = '📖 Offline';
      _isLoading = false;
      notifyListeners();

      await _offlineEngine.speakDirect(
        text: text,
        language: _language,
        speed: _speed,
        pitch: _pitch,
        voiceId: _selectedVoiceId,
      );

      _isSpeaking = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ TTS all failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════
  // PLAYBACK CONTROL
  // ═══════════════════════════════════════════

  /// Dừng phát
  Future<void> stop() async {
    _isSpeaking = false;
    _isLoading = false;
    await _audioPlayer.stop();
    await _offlineEngine.stop();
    notifyListeners();
  }

  /// Tạm dừng
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isSpeaking = false;
    notifyListeners();
  }

  /// Tiếp tục
  Future<void> resume() async {
    await _audioPlayer.play();
    _isSpeaking = true;
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // SPEAK MULTIPLE
  // ═══════════════════════════════════════════

  /// Đọc nhiều dòng liên tiếp
  Future<void> speakLines(
    List<String> lines, {
    Duration pauseBetween = const Duration(milliseconds: 500),
    void Function(int currentIndex)? onLineChanged,
  }) async {
    for (int i = 0; i < lines.length; i++) {
      if (!_isSpeaking && i > 0) break; // User đã stop

      onLineChanged?.call(i);
      await speak(lines[i]);

      // Chờ phát xong
      await _waitForCompletion();

      if (i < lines.length - 1) {
        await Future.delayed(pauseBetween);
      }
    }
  }

  /// Đọc lặp lại nhiều lần (cho luyện tập)
  Future<void> speakRepeat(
    String text, {
    int times = 3,
    Duration pauseBetween = const Duration(milliseconds: 800),
    void Function(int current, int total)? onRepeat,
  }) async {
    for (int i = 0; i < times; i++) {
      if (!_isSpeaking && i > 0) break;

      onRepeat?.call(i + 1, times);
      await speak(text);
      await _waitForCompletion();

      if (i < times - 1) {
        await Future.delayed(pauseBetween);
      }
    }
  }

  // ═══════════════════════════════════════════
  // VOICE SELECTION
  // ═══════════════════════════════════════════

  /// Lấy tất cả giọng khả dụng cho ngôn ngữ hiện tại
  Future<List<TtsVoice>> getAvailableVoices() async {
    final voices = <TtsVoice>[];

    // Online voices
    for (final engine in _onlineEngines) {
      try {
        final engineVoices = await engine.getAvailableVoices(_language);
        voices.addAll(engineVoices);
      } catch (_) {}
    }

    // Offline voices
    try {
      final offlineVoices = await _offlineEngine.getAvailableVoices(_language);
      voices.addAll(offlineVoices);
    } catch (_) {}

    return voices;
  }

  // ═══════════════════════════════════════════
  // ENGINE STATUS
  // ═══════════════════════════════════════════

  /// Kiểm tra trạng thái engine
  Future<Map<String, bool>> checkEngineStatus() async {
    final status = <String, bool>{};

    for (final engine in _onlineEngines) {
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

  /// Danh sách engine active
  List<String> get activeEngines => [
        ..._onlineEngines.map((e) => e.name),
        _offlineEngine.name,
      ];

  // ═══════════════════════════════════════════
  // CACHE
  // ═══════════════════════════════════════════

  Future<double> getCacheSizeMB() => _cache.getCacheSizeMB();
  Future<int> getCacheCount() => _cache.getCacheCount();
  Future<void> clearCache() => _cache.clear();

  // ═══════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════

  Future<void> _playFile(String filePath) async {
    try {
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.setSpeed(_speed);
      _isSpeaking = true;
      notifyListeners();
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Play file error: $e');
      _error = 'Không thể phát audio: $e';
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
      debugPrint('Play URL error: $e');
      _error = 'Không thể stream audio: $e';
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> _waitForCompletion() async {
    try {
      // Chờ just_audio phát xong
      await _audioPlayer.playerStateStream
          .firstWhere(
            (state) =>
                state.processingState == ProcessingState.completed ||
                state.processingState == ProcessingState.idle,
          )
          .timeout(const Duration(seconds: 30));
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
