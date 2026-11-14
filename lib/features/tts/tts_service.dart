// lib/features/tts/tts_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language/app_language.dart';
import 'cache/tts_cache.dart';
import 'edge_voice_prefs.dart';
import 'engines/edge_tts_engine.dart';
import 'engines/fpt_tts_engine.dart';
import 'engines/openai_compat_tts_engine.dart';
import 'engines/tts_engine.dart';
import 'engines/google_tts_engine.dart';
import 'engines/offline_tts_engine.dart';
import 'engines/piper_tts_engine.dart';
import 'engines/zalo_tts_engine.dart';
import 'engines/vieneu_tts_engine.dart';
import 'package:in4up_stt/tts/vieneu_tts_core.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';
import 'language_detector.dart';
import 'tts_candidate_router.dart';
import 'tts_settings.dart';
import 'tts_text_chunker.dart';

/// PSRC-183/186 — kết quả import model GGUF kèm giọng mẫu.
class VieneuImportResult {
  /// Đường dẫn file .gguf đã copy vào documents (rỗng nếu chỉ import giọng).
  final String modelPath;

  /// Số giọng mẫu mới được nạp kèm.
  final int importedVoices;

  /// Id các giọng mới (dùng để UI hiển thị / test máy).
  final List<String> voiceIds;

  const VieneuImportResult({
    required this.modelPath,
    required this.importedVoices,
    this.voiceIds = const <String>[],
  });
}

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
  static const _kZaloApiKey = 'tts_fpt_api_key'; // typo fixed in code below
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

  // ── I4U18-PDF-OCR-TTS-001 (F3) — trọng tài phát ──────────────
  // `_stopRequested` một mình không đủ: `speak()` đặt lại nó về false ở đầu
  // mỗi câu, nên lệnh Stop rơi đúng vào lúc đó bị nuốt và câu kế vẫn phát
  // ("Stop xong vẫn phát"). Thêm một số THẾ HỆ chỉ tăng: mọi lệnh stop tăng
  // nó lên, và mọi tác vụ phát đang bay đều mang theo thế hệ của mình —
  // thế hệ cũ thì không được chạm vào AudioPlayer nữa.
  int _playbackEpoch = 0;

  // Tạm dừng là trạng thái RIÊNG: vòng `speakLines` phải ĐỢI ở đây thay vì
  // coi câu đã xong rồi chạy tiếp sang câu sau (lỗi "Pause không dừng âm").
  bool _paused = false;
  String _lastUsedEngine = '';
  String _detectedLanguage = '';
  String? _error;
  bool _isPrefetching = false;

  // Track source audio and the offline sentence being replayed after pause.
  bool _usingOfflineEngine = false;
  bool _pausedOfflineEngine = false;
  Future<void>? _offlineResumeFuture;

  // ★ FIX: Guard chống notify sau khi dispose
  bool _disposed = false;

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get isLoading => _isLoading;
  bool get isPaused => _paused;

  /// Thế hệ phát hiện tại — tác vụ async so sánh để biết mình còn hiệu lực.
  int get playbackEpoch => _playbackEpoch;

  /// True khi [epoch] đã bị một lệnh stop mới hơn thay thế.
  bool isStaleEpoch(int epoch) => epoch != _playbackEpoch;
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
        id: 'vieneu_tts',
        name: 'VieNeu-TTS (native)',
        description:
            'Giọng Việt neural, ngoại tuyến (audio.cpp GGUF, on-device)',
        isOnline: false,
        priority: 0,
      ),
      const TtsEngineInfo(
        id: 'piper_tts',
        name: 'Piper (neural / Sherpa)',
        description: 'Offline, giọng neural đã import',
        isOnline: false,
        priority: 1,
      ),
      const TtsEngineInfo(
        id: 'offline_tts',
        name: 'Offline (Máy)',
        description: 'Phát ngay, giọng máy hệ thống',
        isOnline: false,
        priority: 2,
      ),
      // TTS-EDGE-001 — Microsoft Edge Read Aloud (giao thức edge-tts):
      // giọng Neural cực tự nhiên, KHÔNG cần API key, miễn phí ⇒ làm
      // engine ONLINE ĐẦU TIÊN của cài đặt mới. User cũ (đã có saved
      // order) không bị xáo trộn: merge `_loadPersistedSettings` append
      // engine mới xuống CUỐI (kéo lên bằng UI sẵn có). Mạng chập chờn/
      // timeout ⇒ chuỗi `_getCandidateEngines` + emergency Offline lo
      // fallback (không nghẽn app).
      const TtsEngineInfo(
        id: 'edge_tts',
        name: 'Microsoft Edge TTS',
        description: 'Neural siêu tự nhiên, miễn phí, không cần key',
        priority: 3,
      ),
      const TtsEngineInfo(
        id: 'google_tts',
        name: 'Google TTS',
        description: 'Miễn phí, khá tự nhiên',
        priority: 4,
      ),
      const TtsEngineInfo(
        id: 'zalo_tts',
        name: 'Zalo AI',
        description: 'Tiếng Việt cực tự nhiên',
        needsApiKey: true,
        priority: 5,
      ),
      const TtsEngineInfo(
        id: 'fpt_tts',
        name: 'FPT.AI',
        description: 'Tiếng Việt tự nhiên, nhiều giọng',
        needsApiKey: true,
        priority: 6,
      ),
      // WP4 (API-005) — engine TTS qua tầng Server API (OpenAI tts-1,
      // Kokoro local/LAN…). Nằm SAU offline/Zalo/FPT ⇒ thứ tự mặc định của
      // user cũ KHÔNG đổi; user kéo lên trong cùng UI này nếu muốn. Chưa cấu
      // hình provider thì engine tự bỏ qua (chuỗi y hệt trước WP4).
      // Key/baseUrl/model dùng store chung WP0 (màn Server & API) — KHÔNG
      // nhập key riêng như Zalo/FPT.
      const TtsEngineInfo(
        id: 'openai_compat_tts',
        name: 'Server TTS (API)',
        description: 'OpenAI tts-1 / Kokoro — cấu hình ở Server & API',
        priority: 7,
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

  /// PSRC-183/186: revision RIÊNG cho danh sách giọng. Picker lắng nghe
  /// notifier này thay vì toàn bộ `TtsService` (vốn notify liên tục trong lúc
  /// phát nhạc ⇒ reload giọng/ nạp lại UI không cần thiết).
  final ValueNotifier<int> voicesRevision = ValueNotifier<int>(0);

  /// Thông báo danh sách giọng/model vừa đổi (import, clone, xoá giọng).
  void notifyVoicesChanged() {
    if (!_disposed) voicesRevision.value++;
    _safeNotify();
  }

  // ═══════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════

  static final RegExp _bcp47RegionPattern =
      RegExp(r'^[a-zA-Z]{2,3}[-_][a-zA-Z]{2}$');

  String _normalizeRequestedLocale(String raw) {
    final trimmed = raw.trim();
    if (_bcp47RegionPattern.hasMatch(trimmed)) {
      final parts = trimmed.replaceAll('_', '-').split('-');
      return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
    }
    return AppLanguageCatalog.fromCode(trimmed).ttsLocale;
  }

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
      final normalized = isAuto ? 'auto' : _normalizeRequestedLocale(language);
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

  /// Danh sách candidate engines theo thứ tự ưu tiên cấu hình.
  /// Nếu user đã chọn rõ một giọng Edge, lựa chọn đó được ưu tiên trước
  /// fallback offline (trừ chế độ `offlineOnly`).
  List<TtsEngineInfo> _getCandidateEngines(
    TtsPriority priority, {
    String? preferredEngineId,
  }) =>
      orderTtsCandidates(
        engines: _engineOrder,
        priority: priority,
        preferredEngineId: preferredEngineId,
      );

  Future<void> speak(String text, {String? language, bool matchVoiceLanguage = false}) async {
    if (text.trim().isEmpty) return;
    // Dừng âm đang phát nhưng KHÔNG tăng thế hệ: một câu mới trong cùng
    // phiên đọc không được vô hiệu hoá chính phiên đó.
    final epoch = _playbackEpoch;
    await _silenceCurrentAudio();
    if (isStaleEpoch(epoch)) return;

    _error = null;
    _stopRequested = false;
    _paused = false;
    _pausedOfflineEngine = false;
    _offlineResumeFuture = null;
    // Nguồn âm của câu trước đã tắt; cờ engine phải về mặc định để
    // `_awaitLineFinished` không tưởng nhầm là đang dùng giọng máy.
    _usingOfflineEngine = false;
    final lang = language == null
        ? _resolveLanguage(text)
        : language.toLowerCase() == 'auto'
            ? LanguageDetector.detect(text)
            : _normalizeRequestedLocale(language);
    _detectedLanguage = lang;

    // 1. Cache: KHÔNG dò bằng engineId 'any' nữa.
    // TTS-VOICE-CACHE-001 (audit 1.g): `get(engineId: 'any')` không bao giờ
    // khớp `put(engineId: engine.id)` ⇒ cache coi như chết; và nếu khớp thì
    // còn tệ hơn — một bản ghi giọng mặc định (nữ) sẽ phát đè lên giọng
    // người dùng vừa chọn. Giờ mỗi engine tự dò cache theo đúng danh tính
    // (engine + ngôn ngữ + giọng + tốc độ + cao độ).

    // 2. Chạy qua danh sách engine theo thứ tự ưu tiên. Chọn một giọng Edge
    // cụ thể là lựa chọn engine tường minh: thử Edge trước rồi mới fallback.
    // `offlineOnly` và công tắc tắt Edge vẫn được tôn trọng.
    // YT-TTS-READ-001: `auto` phải được RESOLVE theo loại mạng NGAY TẠI ĐÂY
    // (mỗi câu, có cache ngắn) rồi mới dùng cho cả chuỗi engine bên dưới.
    final effectivePriority = await _effectivePriority();
    final edgeEnabled = _engineOrder.any(
      (engine) => engine.id == 'edge_tts' && engine.isEnabled,
    );
    final edgeVoice =
        edgeEnabled && effectivePriority != TtsPriority.offlineOnly
            ? await _resolveEdgeVoice(lang, matchLanguage: matchVoiceLanguage)
            : null;
    final candidates = _getCandidateEngines(
      effectivePriority,
      preferredEngineId: edgeVoice == null ? null : 'edge_tts',
    );
    var played = false;

    for (final engineInfo in candidates) {
      if (_stopRequested || isStaleEpoch(epoch)) break;

      if (!_engineSupportsLanguage(engineInfo.id, lang)) continue;
      switch (engineInfo.id) {
        case 'vieneu_tts':
          // TTS-VIENEU-001 — VieNeu-TTS native (GGUF, audio.cpp, on-device,
          // chỉ tiếng Việt; _engineSupportsLanguage đã lọc lang ở trên).
          played = await _trySpeakVieneu(text, lang, epoch, matchVoiceLanguage);
          break;

        case 'piper_tts':
          played = await _trySpeakPiper(text, lang, epoch, matchVoiceLanguage);
          break;

        case 'offline_tts':
          played = await _trySpeakOffline(text, lang);
          break;

        case 'edge_tts':
          // TTS-EDGE-001 — không cần key, mọi ngôn ngữ: thử trực tiếp;
          // `_trySpeakOnline` tự check mạng + timeout 15s → false ⇒ chuỗi
          // chạy tiếp engine kế (fallback mượt, không nghẽn app).
          // TTS-EDGE-VOICE-001 — dùng giọng Edge đã chọn theo ngôn ngữ
          // (EdgeVoicePrefs); chưa chọn → null → engine tự chọn mặc định.
          played = await _trySpeakOnline(
            EdgeTtsEngine(),
            text,
            lang,
            voiceOverride: edgeVoice,
            epoch: epoch, matchVoiceLanguage: matchVoiceLanguage,
          );
          break;

        case 'google_tts':
          played = await _trySpeakOnline(GoogleTtsEngine(), text, lang, epoch: epoch, matchVoiceLanguage: matchVoiceLanguage);
          break;

        case 'zalo_tts':
          if (_zaloApiKey != null &&
              _zaloApiKey!.isNotEmpty &&
              lang.startsWith('vi')) {
            played = await _trySpeakOnline(
              ZaloTtsEngine(apiKey: _zaloApiKey),
              text,
              lang,
              epoch: epoch, matchVoiceLanguage: matchVoiceLanguage,
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
              epoch: epoch, matchVoiceLanguage: matchVoiceLanguage,
            );
          }
          break;

        case 'openai_compat_tts':
          // WP4 (API-005): chỉ chạy khi đã có provider hỗ trợ TTS trong
          // store chung WP0 (routing tts ≠ offlineOnly). Chưa cấu hình →
          // bỏ qua — chuỗi TTS y hệt như trước khi có engine này.
          final apiEngine = await _resolveApiTtsEngine();
          if (apiEngine != null) {
            played = await _trySpeakOnline(apiEngine, text, lang, epoch: epoch, matchVoiceLanguage: matchVoiceLanguage);
          }
          break;
      }

      if (played) {
        // Nếu dùng offline và chế độ offlineFirst (kể cả `auto` đã resolve
        // thành offlineFirst vì đang dùng mạng di động), prefetch online nền.
        if (effectivePriority == TtsPriority.offlineFirst) {
          _prefetchOnline(text, lang, matchVoiceLanguage: matchVoiceLanguage);
        }
        return;
      }
    }

    // Nếu tất cả candidate engines đều thất bại, thử fallback khẩn cấp sang Offline (Máy)
    if (!played && !_stopRequested && !isStaleEpoch(epoch)) {
      debugPrint('⚠️ Tất cả engine ưu tiên thất bại, thử fallback khẩn cấp sang Offline Máy');
      played = await _trySpeakOffline(text, lang);
    }

    if (!played && !_stopRequested && !isStaleEpoch(epoch)) {
      _error = 'Không có engine TTS nào phát được văn bản này ($lang).';
      _isLoading = false;
      _isSpeaking = false;
      _safeNotify();
    }
  }

  /// PSRC-187 — phát [text] theo TỪNG ĐOẠN bằng một engine tổng hợp ra file.
  ///
  /// Tab Đọc đưa nguyên một dòng (có khi cả trang) cho TTS. Trước đây engine
  /// phải tổng hợp xong CẢ dòng mới có tiếng; với Piper cả dòng còn bị nhồi
  /// vào một lượt chạy model — RAM đỉnh tăng mạnh theo độ dài dòng (đo trên
  /// x86-64: 935 MB với 786 ký tự, 3,4 GB với 2751 ký tự), nhiều khả năng đủ
  /// để Android giết app (suy ra, chưa đo trên máy); với engine online thì
  /// dòng dài dễ quá hạn 15 s rồi rơi về engine khác.
  ///
  /// [prepare] biến một đoạn thành âm thanh sẵn sàng phát (file cache hoặc
  /// URL); trả `null` nếu engine không làm được. Đoạn KẾ TIẾP được chuẩn bị
  /// ngay trong lúc đoạn hiện tại đang phát ⇒ không hở tiếng giữa các đoạn.
  ///
  /// Trả `false` CHỈ KHI chưa phát được gì (để `speak()` thử engine kế tiếp
  /// với nguyên dòng). Engine hỏng giữa chừng ⇒ đọc nốt phần còn lại bằng
  /// giọng máy: không đọc lại từ đầu, không bỏ dở dòng.
  Future<bool> _speakPreparedChunks({
    required String text,
    required String lang,
    required int epoch,
    required int maxChars,
    required Future<_PreparedChunk?> Function(String chunk) prepare,
    double? playbackSpeed,
  }) async {
    final chunks = chunkTextForTts(text, maxChars);
    if (chunks.isEmpty) return false;

    bool cancelled() => _stopRequested || isStaleEpoch(epoch);

    // Không bao giờ ném: future "đoạn kế" có thể bị bỏ lại khi người dùng
    // bấm Dừng — lỗi của nó không được thành lỗi không ai nhận.
    Future<_PreparedChunk?> safePrepare(String chunk) async {
      try {
        return await prepare(chunk);
      } catch (e) {
        debugPrint('⚠️ TTS: không chuẩn bị được đoạn (${chunk.length} ký tự): $e');
        return null;
      }
    }

    Future<bool> play(_PreparedChunk chunk) {
      final path = chunk.path;
      if (path != null) {
        return _playFile(path, epoch, playbackSpeed: playbackSpeed);
      }
      return _playUrl(chunk.url!, epoch);
    }

    Future<bool> finishWithSystemVoice(int from) async {
      await _awaitLineFinished(epoch);
      if (cancelled()) return true;
      debugPrint(
        '⚠️ TTS: engine hỏng ở đoạn ${from + 1}/${chunks.length} — đọc nốt '
        'phần còn lại bằng giọng máy',
      );
      await _trySpeakOffline(chunks.sublist(from).join(' '), lang);
      return true;
    }

    _usingOfflineEngine = false;
    _isLoading = true;
    _safeNotify();

    var pending = safePrepare(chunks.first);
    for (var i = 0; i < chunks.length; i++) {
      var prepared = await pending;
      if (cancelled()) {
        _isLoading = false;
        return i > 0;
      }
      // Chuẩn bị SẴN đoạn kế ngay bây giờ — nó chạy song song với lúc đoạn
      // này phát (Piper/VieNeu tổng hợp trong worker isolate).
      if (i + 1 < chunks.length) pending = safePrepare(chunks[i + 1]);

      if (prepared == null) {
        _isLoading = false;
        _safeNotify();
        if (i == 0) return false;
        return finishWithSystemVoice(i);
      }

      if (i > 0) {
        // Đoạn trước phải phát XONG (và không đang tạm dừng) mới tới đoạn này.
        await _awaitLineFinished(epoch);
        if (cancelled()) {
          _isLoading = false;
          return true;
        }
      }

      _isLoading = false;
      _lastUsedEngine = prepared.label;
      _safeNotify();
      var ok = await play(prepared);
      if (!ok && prepared.fromCache && !cancelled()) {
        // File cache hỏng ⇒ xoá và tổng hợp lại ĐÚNG MỘT lần. Bị Dừng thì
        // không phải cache hỏng: không xoá file hợp lệ.
        try {
          await File(prepared.path!).delete();
        } catch (_) {}
        prepared = await safePrepare(chunks[i]);
        if (cancelled()) return i > 0;
        if (prepared != null && !prepared.fromCache) {
          _lastUsedEngine = prepared.label;
          _safeNotify();
          ok = await play(prepared);
        }
      }
      if (!ok) {
        if (cancelled()) return i > 0;
        if (i == 0) return false;
        return finishWithSystemVoice(i);
      }
    }
    return true;
  }

  /// Thử phát bằng Sherpa Piper neural TTS.
  /// Trả về true nếu thành công, false nếu không có model / lỗi để tự động fallback.
  ///
  /// PSRC-187: đọc theo từng đoạn ≤ [kPiperTtsChunkChars] ([_speakPreparedChunks]).
  Future<bool> _trySpeakPiper(String text, String lang, int epoch, bool matchVoiceLanguage) async {
    try {
      final piper = PiperTtsEngine.instance;
      if (!await piper.isAvailable()) return false;
      if (isStaleEpoch(epoch)) return false;

      // PSRC-230 — GIẢI giọng TRƯỚC khi tổng hợp/cache: câu tiếng Anh trong
      // tài liệu song ngữ phải dùng giọng tiếng Anh; không có giọng phù hợp
      // thì trả false để chuỗi engine chạy tiếp (thà fallback còn hơn đọc
      // tiếng Anh bằng giọng Việt).
      //
      // Bản cũ truyền `voiceId: null` khi `matchVoiceLanguage` và cache theo
      // `null` ⇒ mọi ngôn ngữ dùng chung một bản ghi giọng người dùng chọn.
      final requestedVoiceId = matchVoiceLanguage ? null : _selectedVoiceId;
      final voiceId = await piper.resolveVoiceName(
        lang,
        voiceId: requestedVoiceId,
      );
      if (voiceId == null) {
        debugPrint('ℹ️ Piper: không có giọng phù hợp cho $lang — '
            'chuyển engine kế tiếp');
        return false;
      }
      return await _speakPreparedChunks(
        text: text,
        lang: lang,
        epoch: epoch,
        maxChars: kPiperTtsChunkChars,
        prepare: (chunk) async {
          final cached = await _cache.get(
            text: chunk,
            language: lang,
            engineId: piper.id,
            voiceId: voiceId,
            speed: _speed,
            pitch: _pitch,
          );
          if (cached != null) {
            return _PreparedChunk.file(
              cached,
              '💾 Cache · Sherpa Piper',
              fromCache: true,
            );
          }

          final result = await piper.synthesize(
            text: chunk,
            language: lang,
            speed: _speed,
            pitch: _pitch,
            voiceId: voiceId,
          );
          if (result.isSuccess) {
            debugPrint('[TTS-PIPER] $lang → giọng $voiceId');
          }
          final audio = result.audioData;
          if (!result.isSuccess || audio == null || audio.isEmpty) {
            debugPrint('ℹ️ Sherpa Piper TTS không khả dụng cho $lang (${result.error}), fallback sang engine tiếp theo');
            return null;
          }

          final filePath = await _cache.put(
            text: chunk,
            language: lang,
            engineId: piper.id,
            audioData: audio,
            voiceId: voiceId,
            speed: _speed,
            pitch: _pitch,
          );
          return _PreparedChunk.file(filePath, '🎙️ Sherpa Piper');
        },
      );
    } catch (e) {
      debugPrint('⚠️ Piper TTS error: $e, fallback tiếp');
      _isLoading = false;
      _safeNotify();
      return false;
    }
  }

  /// Thử phát bằng VieNeu-TTS native (audio.cpp GGUF, on-device, chỉ tiếng Việt).
  /// Trả về true nếu thành công, false nếu model chưa import / lỗi native
  /// để TtsService tự fallback qua engine kế tiếp (không crash app).
  Future<bool> _trySpeakVieneu(String text, String lang, int epoch, bool matchVoiceLanguage) async {
    try {
      final vieneu = VieneuTtsEngine.instance;
      // GIAI ĐOẠN 3 — dùng biến thể mô hình người dùng đã chọn (mặc định Q8_0).
      final selectedVariant = await getSelectedVieneuModelVariant();
      await vieneu.init(modelVariant: selectedVariant);
      if (!await vieneu.isAvailable()) return false;
      if (isStaleEpoch(epoch)) return false;

      // Cache theo đúng danh tính (text + ngôn ngữ + engine + biến thể +
      // giọng + tốc độ/cao độ) — TTS-VOICE-CACHE-001.
      final voiceId = matchVoiceLanguage ? null : _selectedVoiceId;
      // PSRC-187: văn bản dài được chia đoạn (cùng một đường với Piper/online).
      return await _speakPreparedChunks(
        text: text,
        lang: lang,
        epoch: epoch,
        maxChars: vieneu.maxCharsPerRequest,
        prepare: (chunk) async {
          final cached = await _cache.get(
            text: chunk,
            language: lang,
            engineId: vieneu.id,
            voiceId: voiceId,
            speed: _speed,
            pitch: _pitch,
            modelVariant: selectedVariant.name,
          );
          if (cached != null) {
            return _PreparedChunk.file(
              cached,
              '💾 Cache · VieNeu-TTS',
              fromCache: true,
            );
          }

          final result = await vieneu.synthesize(
            text: chunk,
            language: lang,
            speed: _speed,
            pitch: _pitch,
            voiceId: voiceId,
          );
          final audio = result.audioData;
          if (!result.isSuccess || audio == null || audio.isEmpty) {
            debugPrint(
                'ℹ️ VieNeu-TTS không khả dụng cho $lang (${result.error}), fallback sang engine tiếp theo');
            return null;
          }

          final filePath = await _cache.put(
            text: chunk,
            language: lang,
            engineId: vieneu.id,
            audioData: audio,
            voiceId: voiceId,
            modelVariant: selectedVariant.name,
            speed: _speed,
            pitch: _pitch,
          );
          return _PreparedChunk.file(filePath, '🇻🇳 VieNeu-TTS');
        },
      );
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS error: $e, fallback tiếp');
      _isLoading = false;
      _safeNotify();
      return false;
    }
  }

  /// Kết quả một lần import model GGUF (PSRC-183/186). UI cần biết cả số
  /// giọng mẫu được nạp kèm để không báo "đã import" trong khi danh sách
  /// giọng vẫn trống.
  Future<VieneuImportResult> importVieneuModel(File file,
      {VieneuModelVariant variant = VieneuModelVariant.q8_0}) async {
    if (!await file.exists()) {
      throw FileSystemException('File không tồn tại', file.path);
    }

    final ext = p.extension(file.path).toLowerCase();
    if (ext != '.gguf') {
      throw FileSystemException('File phải có định dạng .gguf', file.path);
    }

    final dir = await getApplicationDocumentsDirectory();
    final vieneuDir = Directory(p.join(dir.path, 'vieneu_tts'));
    if (!await vieneuDir.exists()) {
      await vieneuDir.create(recursive: true);
    }

    // Chỉ tạo thư mục, KHÔNG sinh placeholder ref_codes.txt (PSRC-187).
    final voicesDir = Directory(p.join(vieneuDir.path, 'voices'));
    if (!await voicesDir.exists()) {
      await voicesDir.create(recursive: true);
    }

    final target = File(p.join(vieneuDir.path, variant.fileName));
    await file.copy(target.path);

    // PSRC-186: `file_picker` thường trả bản COPY trong cache của app, nên
    // dò nhiều vị trí (cạnh GGUF, thư mục cha, chính thư mục bundle) thay vì
    // chỉ `dirname(file)/voices`. Mỗi thư mục giọng phải có dữ liệu thật.
    final voiceIds = <String>[];
    try {
      voiceIds.addAll(await _importBundledVoicesFromSource(
        ggufPath: file.path,
        targetVoicesDir: voicesDir.path,
      ));
    } catch (e) {
      debugPrint('⚠️ VieNeu voices import kèm GGUF bỏ qua: $e');
    }

    // PSRC-183: worker có thể đang giữ model CŨ. Dọn để lần phát tới nạp
    // đúng file vừa import; trạng thái UI (model/engine) được làm mới.
    await VieneuTtsEngine.instance.invalidate();
    notifyVoicesChanged();
    return VieneuImportResult(
      modelPath: target.path,
      importedVoices: voiceIds.length,
      voiceIds: List<String>.unmodifiable(voiceIds),
    );
  }

  /// PSRC-186 — dò các thư mục `voices/` đi kèm GGUF và copy giọng hợp lệ.
  /// Trả về id các giọng mới (không ghi đè giọng đã có dữ liệu thật).
  Future<List<String>> _importBundledVoicesFromSource({
    required String ggufPath,
    required String targetVoicesDir,
  }) async {
    final imported = <String>[];
    for (final candidate in bundledVoiceDirCandidates(ggufPath)) {
      final source = Directory(candidate);
      if (!await source.exists()) continue;
      final ids = await _importVoiceFoldersFromDirectory(source, targetVoicesDir);
      for (final id in ids) {
        if (!imported.contains(id)) imported.add(id);
      }
    }
    if (imported.isNotEmpty) {
      debugPrint('✅ VieNeu đã import ${imported.length} giọng kèm GGUF');
    }
    return imported;
  }

  /// Một thư mục giọng phải có ít nhất một file dữ liệu có NỘI DUNG THỰC —
  /// placeholder comment `# VieNeu-TTS default` không được tính.
  Future<bool> _folderHasValidVoiceData(Directory folder) async {
    if (!await folder.exists()) return false;
    for (final name in vieneuVoiceDataFileNames) {
      final file = File(p.join(folder.path, name));
      if (!await file.exists()) continue;
      try {
        if (p.extension(name) == '.bin') {
          if (await file.length() > 32) return true;
        } else if (hasVieneuVoiceData(await file.readAsString())) {
          return true;
        }
      } catch (_) {
        // File nhị phân: có kích thước hợp lệ vẫn chấp nhận.
        try {
          if (await file.length() > 32) return true;
        } catch (_) {}
      }
    }
    return false;
  }

  /// Copy các thư mục giọng con của [sourceDir] (hoặc chính [sourceDir] nếu
  /// nó là một giọng đơn lẻ) vào [targetVoicesDir].
  Future<List<String>> _importVoiceFoldersFromDirectory(
    Directory sourceDir,
    String targetVoicesDir,
  ) async {
    final imported = <String>[];
    if (await _folderHasValidVoiceData(sourceDir)) {
      final id = p.basename(sourceDir.path);
      if (!id.startsWith('_')) {
        final ok = await _copyVoiceFolder(sourceDir, Directory(p.join(targetVoicesDir, id)));
        if (ok) imported.add(id);
      }
      return imported;
    }
    await for (final entity in sourceDir.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (id.startsWith('_') || id == vieneuTempSamplesDirName) continue;
      if (!await _folderHasValidVoiceData(entity)) continue;
      final ok = await _copyVoiceFolder(entity, Directory(p.join(targetVoicesDir, id)));
      if (ok) imported.add(id);
    }
    return imported;
  }

  /// Copy một giọng; bỏ qua nếu đích đã có dữ liệu thật, nhưng THAY THẾ nếu
  /// đích chỉ là placeholder (lỗi import đời đầu — PSRC-186).
  Future<bool> _copyVoiceFolder(Directory source, Directory target) async {
    if (await _folderHasValidVoiceData(target)) return false;
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await _copyDirectoryRecursively(source, target);
    return true;
  }

  Future<void> _copyDirectoryRecursively(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectoryRecursively(entity, Directory(newPath));
      }
    }
  }

  /// PSRC-186 — import TRỌN BỘ từ thư mục người dùng chọn: mọi file .gguf
  /// (Q8_0/bf16) + mọi thư mục `voices/`. Cần cho Android/SAF nếu file
  /// GGUF bị copy vào cache và tự động dò cạnh file không đủ.
  Future<VieneuImportResult> importVieneuBundleFromDirectory(
      String sourceDirPath) async {
    final sourceDir = Directory(sourceDirPath);
    if (!await sourceDir.exists()) {
      throw FileSystemException('Thư mục không tồn tại', sourceDirPath);
    }
    final ggufFiles = await _findFilesUnder(sourceDir, maxDepth: 3)
        .where((f) => p.extension(f.path).toLowerCase() == '.gguf')
        .toList();
    String? modelPath;
    final voiceIds = <String>[];
    for (final gguf in ggufFiles) {
      final name = detectVieneuVariantName(gguf.path) ??
          VieneuModelVariant.q8_0.name;
      final variant = VieneuModelVariant.values.firstWhere(
        (v) => v.name == name,
        orElse: () => VieneuModelVariant.q8_0,
      );
      final result = await importVieneuModel(gguf, variant: variant);
      modelPath ??= result.modelPath;
      for (final id in result.voiceIds) {
        if (!voiceIds.contains(id)) voiceIds.add(id);
      }
    }

    // Dò thêm mọi thư mục tên `voices` (kể cả lồng sâu) dù không có GGUF.
    final dir = await getApplicationDocumentsDirectory();
    final targetVoicesDir =
        Directory(p.join(dir.path, 'vieneu_tts', 'voices'));
    if (!await targetVoicesDir.exists()) {
      await targetVoicesDir.create(recursive: true);
    }
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is! Directory) continue;
      if (p.basename(entity.path).toLowerCase() != 'voices') continue;
      final ids = await _importVoiceFoldersFromDirectory(
          entity, targetVoicesDir.path);
      for (final id in ids) {
        if (!voiceIds.contains(id)) voiceIds.add(id);
      }
    }
    if (modelPath == null && voiceIds.isEmpty) {
      throw FileSystemException(
          'Không tìm thấy file .gguf hoặc giọng hợp lệ trong thư mục',
          sourceDirPath);
    }
    await VieneuTtsEngine.instance.invalidate();
    notifyVoicesChanged();
    return VieneuImportResult(
      modelPath: modelPath ?? '',
      importedVoices: voiceIds.length,
      voiceIds: List<String>.unmodifiable(voiceIds),
    );
  }

  /// Duyệt file có giới hạn độ sâu (tránh `list(recursive: true)` đi vào
  /// thư mục hệ thống khổng lồ khi người dùng chọn sai thư mục).
  Stream<File> _findFilesUnder(Directory root, {required int maxDepth}) async* {
    if (maxDepth < 0 || !await root.exists()) return;
    await for (final entity in root.list(recursive: false)) {
      if (entity is File) {
        yield entity;
      } else if (entity is Directory &&
          !p.basename(entity.path).startsWith('.')) {
        yield* _findFilesUnder(entity, maxDepth: maxDepth - 1);
      }
    }
  }

  /// PSRC-185/186 — import giọng VieNeu từ thư mục do người dùng chọn.
  /// Hỗ trợ: thư mục chứa `voices/`, thư mục chứa nhiều giọng con, hoặc
  /// chính là một giọng đơn lẻ. Trả về số giọng mới.
  Future<int> importVieneuVoicesFromDirectory(String sourceVoicesDirPath) async {
    final sourceDir = Directory(sourceVoicesDirPath);
    if (!await sourceDir.exists()) {
      throw FileSystemException('Thư mục không tồn tại', sourceVoicesDirPath);
    }
    final dir = await getApplicationDocumentsDirectory();
    final targetVoicesDir = Directory(p.join(dir.path, 'vieneu_tts', 'voices'));
    if (!await targetVoicesDir.exists()) {
      await targetVoicesDir.create(recursive: true);
    }
    final nested = Directory(p.join(sourceDir.path, 'voices'));
    final chosen = await nested.exists() ? nested : sourceDir;
    final ids = await _importVoiceFoldersFromDirectory(
        chosen, targetVoicesDir.path);
    if (ids.isEmpty) {
      throw FileSystemException('Không tìm thấy giọng hợp lệ trong thư mục');
    }
    await VieneuTtsEngine.instance.invalidate();
    notifyVoicesChanged();
    return ids.length;
  }

  /// PSRC-186 — fallback khi platform không hỗ trợ chọn thư mục
  /// (`getDirectoryPath` trên Android/SAF): người dùng chọn nhiều file
  /// `ref_codes.txt` / `speaker.emb.txt` / `ref_codes.bin` trực tiếp.
  ///
  /// Các file cùng thư mục nguồn được gom thành MỘT giọng; nếu nguồn là thư
  /// mục cache của file_picker (không còn cấu trúc) thì gom tất cả vào một
  /// giọng `imported_voice`.
  Future<int> importVieneuVoiceFiles(List<String> sourcePaths) async {
    const genericDirs = <String>{'cache', 'file_picker', 'tmp', 'temp', ''};
    final groups = <String, List<String>>{};
    for (final path in sourcePaths) {
      if (!isVieneuVoiceDataFile(path)) continue;
      if (!await File(path).exists()) continue;
      var voiceId = sanitizeVieneuVoiceId(p.basename(p.dirname(path)));
      if (genericDirs.contains(voiceId.toLowerCase())) voiceId = '';
      final key = voiceId.isEmpty ? 'imported_voice' : voiceId;
      groups.putIfAbsent(key, () => <String>[]).add(path);
    }
    if (groups.isEmpty) {
      throw FileSystemException('Không tìm thấy file giọng hợp lệ');
    }
    final dir = await getApplicationDocumentsDirectory();
    final targetRoot = Directory(p.join(dir.path, 'vieneu_tts', 'voices'));
    if (!await targetRoot.exists()) {
      await targetRoot.create(recursive: true);
    }
    var imported = 0;
    for (final entry in groups.entries) {
      var voiceId = entry.key;
      var suffix = 0;
      var target = Directory(p.join(targetRoot.path, voiceId));
      while (await target.exists() && await _folderHasValidVoiceData(target)) {
        suffix++;
        voiceId = '${entry.key}_$suffix';
        target = Directory(p.join(targetRoot.path, voiceId));
      }
      await target.create(recursive: true);
      for (final path in entry.value) {
        final fileName = p.basename(path);
        var sequence = 0;
        var dest = File(uniqueVieneuCopyPath(target.path, fileName, sequence));
        while (await dest.exists()) {
          sequence++;
          dest = File(uniqueVieneuCopyPath(target.path, fileName, sequence));
        }
        await File(path).copy(dest.path);
      }
      imported++;
    }
    await VieneuTtsEngine.instance.invalidate();
    notifyVoicesChanged();
    return imported;
  }

  /// PSRC-185 — import các file mẫu WAV từ thư mục có sẵn vào vùng tạm của
  /// VoiceClone. Chỉ nhận `.wav` (đúng định dạng native đọc được), duyệt cả
  /// thư mục con. Trả về số file đã copy.
  Future<int> importVieneuSamplesFromDirectory(String sourceDirPath) async {
    final sourceDir = Directory(sourceDirPath);
    if (!await sourceDir.exists()) {
      throw FileSystemException('Thư mục không tồn tại', sourceDirPath);
    }
    final paths = <String>[];
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File && isVieneuVoiceSampleFile(entity.path)) {
        paths.add(entity.path);
      }
    }
    return importVieneuSampleFiles(paths);
  }

  /// Fallback cho platform không hỗ trợ `getDirectoryPath` (Android/SAF):
  /// người dùng chọn NHIỀU file WAV trực tiếp.
  Future<int> importVieneuSampleFiles(List<String> sourcePaths) async {
    final dir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(p.join(
        dir.path, 'vieneu_tts', 'cloned_voices', vieneuTempSamplesDirName));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    var copied = 0;
    for (final sourcePath in sourcePaths) {
      if (!isVieneuVoiceSampleFile(sourcePath)) continue;
      final source = File(sourcePath);
      if (!await source.exists()) continue;
      final fileName = p.basename(sourcePath);
      var sequence = 0;
      var target = File(uniqueVieneuCopyPath(tempDir.path, fileName, sequence));
      while (await target.exists()) {
        sequence++;
        target = File(uniqueVieneuCopyPath(tempDir.path, fileName, sequence));
      }
      await source.copy(target.path);
      copied++;
    }
    if (copied == 0) {
      throw FileSystemException('Không tìm thấy file WAV trong thư mục');
    }
    _safeNotify();
    return copied;
  }

  /// Số mẫu WAV đang chờ tạo giọng (hiển thị trong VoiceCloneSection).
  Future<int> getVieneuSampleCount() async {
    final dir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(p.join(
        dir.path, 'vieneu_tts', 'cloned_voices', vieneuTempSamplesDirName));
    if (!await tempDir.exists()) return 0;
    var count = 0;
    await for (final entity in tempDir.list()) {
      if (entity is File && isVieneuVoiceSampleFile(entity.path)) count++;
    }
    return count;
  }

  /// Dọn mẫu tạm CHỈ SAU KHI clone thành công (PSRC-184: bản cũ xoá trước,
  /// nên một lần clone lỗi là mất sạch mẫu đã thu âm).
  Future<void> clearVieneuTempSamples() async {
    final dir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(p.join(
        dir.path, 'vieneu_tts', 'cloned_voices', vieneuTempSamplesDirName));
    if (!await tempDir.exists()) return;
    await for (final entity in tempDir.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
    _safeNotify();
  }

  /// PSRC-184 — bảo đảm worker đã nạp model TRƯỚC khi gọi clone giọng.
  /// Đi qua engine (có lock + áp đúng biến thể) thay vì gọi `core.init`
  /// trực tiếp từ UI rồi kiểm tra `isInitialized` trong lúc init còn đang bay.
  Future<void> ensureVieneuWorkerReady() async {
    final variant = await getSelectedVieneuModelVariant();
    await VieneuTtsEngine.instance.init(modelVariant: variant);
    if (!VieneuTtsEngine.instance.isInitialized) {
      throw StateError('VieNeu worker chưa khởi tạo');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // GIAI ĐOẠN 3 — persistence lựa chọn biến thể mô hình (SharedPreferences)
  // ══════════════════════════════════════════════════════════════════════════════

  static const String _vieneuVariantPrefsKey = 'vieneu_tts_model_variant';

  /// Biến thể mô hình người dùng đã chọn (mặc định Q8_0).
  ///
  /// PSRC-183: lựa chọn lưu trong prefs có thể trỏ tới biến thể KHÔNG còn
  /// file (xoá file / cài đè / import chỉ một biến thể). Khi đó picker báo
  /// "Chưa import model" dù Q8_0 đã sẵn sàng. Đồng bộ lại với file thật
  /// trên đĩa và ghi đè prefs — một nguồn sự thật duy nhất.
  Future<VieneuModelVariant> getSelectedVieneuModelVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vieneuVariantPrefsKey);
    final saved = VieneuModelVariant.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => VieneuModelVariant.q8_0,
    );
    final available = await VieneuTtsCore.getAvailableVariants();
    if (available.isEmpty || available.contains(saved)) return saved;
    final fallback = available.first;
    await prefs.setString(_vieneuVariantPrefsKey, fallback.name);
    return fallback;
  }

  /// Lưu biến thể mô hình người dùng chọn.
  Future<void> setSelectedVieneuModelVariant(VieneuModelVariant v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vieneuVariantPrefsKey, v.name);
    _safeNotify();
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
      // A paused offline sentence may have been restarted by resume(); do not
      // let the interrupted native call clear the replacement's state.
      if (_offlineResumeFuture == null) {
        _usingOfflineEngine = false;
        _isSpeaking = false;
        _safeNotify();
      }
    }
  }

  /// Nhãn ngắn của giọng để hiện cạnh tên engine: `vi-VN-NamMinhNeural`
  /// → `NamMinh`. Người dùng nhìn là biết ngay giọng nào vừa đọc — trước
  /// đây chỉ thấy "Edge TTS" nên không cách nào tự kiểm chứng (audit 1.g).
  String _shortVoiceLabel(String voiceId) {
    final parts = voiceId.split('-');
    final last = parts.isEmpty ? voiceId : parts.last;
    return last.endsWith('Neural')
        ? last.substring(0, last.length - 'Neural'.length)
        : last;
  }

  /// Giọng Edge sẽ dùng cho [lang] — TTS-EDGE-VOICE-002 (audit 1.g).
  ///
  /// Trước đây chỉ hỏi [EdgeVoicePrefs.voiceForLang]; khi câu được NHẬN
  /// DIỆN sang một ngôn ngữ mà người dùng chưa cấu hình (rất hay gặp với
  /// tài liệu lẫn lộn Việt–Anh), hàm trả null ⇒ Edge rơi về giọng mặc định
  /// của ngôn ngữ đó (en-US → Aria, nữ) ⇒ "chọn giọng nam mà giọng nữ đọc".
  /// Bậc thang mới: giọng theo ngôn ngữ → giọng GHIM cho mọi ngôn ngữ chưa
  /// chọn giọng riêng (TTS-EDGE-VOICE-003, công tắc trong phần cài đặt
  /// Edge) → giọng chung đang chọn nếu đúng dạng id Edge → null (engine tự
  /// mặc định). Phần ghim nằm TRONG [EdgeVoicePrefs.voiceForLang] nên đường
  /// phát, đường nạp sẵn và nhãn giọng đều đi qua đúng một luật.
  Future<String?> _resolveEdgeVoice(String lang, {bool matchLanguage = false}) async {
    try {
      final perLanguage = await EdgeVoicePrefs.instance.voiceForLang(lang);
      if (perLanguage != null && perLanguage.trim().isNotEmpty &&
          (!matchLanguage || _voiceMatchesLanguage(perLanguage, lang))) {
        return perLanguage;
      }
    } catch (error) {
      // Voice preferences must not block offline speech or the default Edge
      // voice when SharedPreferences is unavailable on a desktop build.
      debugPrint('⚠️ Edge voice preferences unavailable: $error');
    }
    final shared = _selectedVoiceId;
    if (shared != null && EdgeTtsEngine.isEdgeVoiceId(shared) &&
        (!matchLanguage || _voiceMatchesLanguage(shared, lang))) return shared;
    return null;
  }

  @visibleForTesting
  static bool voiceMatchesLanguage(String voice, String language) =>
      _voiceMatchesLanguage(voice, language);

  static bool _voiceMatchesLanguage(String voice, String language) {
    final voicePrefix = voice.toLowerCase().split(RegExp('[-_]')).first;
    final languagePrefix = language.toLowerCase().split(RegExp('[-_]')).first;
    return voicePrefix == languagePrefix;
  }

  /// Resolve the actual voice once for synthesis and its cache identity.
  @visibleForTesting
  static String? resolveOnlineVoice({
    required String engineId,
    required String language,
    String? voiceOverride,
    String? selectedVoiceId,
    bool matchVoiceLanguage = false,
  }) {
    var candidate = voiceOverride ?? (matchVoiceLanguage ? null : selectedVoiceId);
    if (matchVoiceLanguage && engineId == 'edge_tts' && candidate != null &&
        !_voiceMatchesLanguage(candidate, language)) {
      candidate = null;
    }
    return engineId == 'edge_tts'
        ? EdgeTtsEngine.resolveVoice(voiceId: candidate, language: language)
        : candidate;
  }

  @visibleForTesting
  static double onlinePlaybackSpeed(String engineId, double speed) =>
      engineId == 'edge_tts' ? 1.0 : speed;

  /// Thử phát bằng Online Engine (Google, Zalo, FPT, Edge)
  ///
  /// [voiceOverride] — giọng ưu tiên cho engine này (TTS-EDGE-VOICE-001: Edge
  /// đọc giọng đã chọn theo ngôn ngữ từ [EdgeVoicePrefs]). `null` → dùng
  /// `_selectedVoiceId` chung (hành vi cũ cho Google/Zalo/FPT).
  ///
  /// PSRC-187: dòng dài được đọc theo từng đoạn ≤ [kOnlineTtsChunkChars]
  /// ([_speakPreparedChunks]) — mỗi đoạn có hạn chờ 15 s riêng, nên một dòng
  /// dài của tab Đọc không còn quá hạn rồi lặng lẽ rơi về engine khác.
  Future<bool> _trySpeakOnline(
    TtsEngine engine,
    String text,
    String lang, {
    String? voiceOverride,
    required int epoch,
    bool matchVoiceLanguage = false,
  }) async {
    final voiceId = resolveOnlineVoice(
      engineId: engine.id,
      language: lang,
      voiceOverride: voiceOverride,
      selectedVoiceId: _selectedVoiceId,
      matchVoiceLanguage: matchVoiceLanguage,
    );
    // Edge synthesizes the requested speed into SSML; do not apply it twice.
    final playbackSpeed = onlinePlaybackSpeed(engine.id, _speed);
    final voiceLabel = voiceId == null || voiceId.trim().isEmpty
        ? null
        : _shortVoiceLabel(voiceId);
    // Hỏi trạng thái mạng tối đa MỘT lần cho cả dòng (chỉ khi cache hụt).
    bool? hasNetwork;

    try {
      return await _speakPreparedChunks(
        text: text,
        lang: lang,
        epoch: epoch,
        maxChars: kOnlineTtsChunkChars,
        playbackSpeed: playbackSpeed,
        prepare: (chunk) async {
          // Cache theo đúng danh tính giọng — bản ghi của giọng khác KHÔNG
          // được dùng lại (TTS-VOICE-CACHE-001).
          final cached = await _cache.get(
            text: chunk,
            language: lang,
            engineId: engine.id,
            voiceId: voiceId,
            speed: _speed,
            pitch: _pitch,
          );
          if (cached != null) {
            return _PreparedChunk.file(
              cached,
              voiceLabel == null
                  ? '💾 Cache · ${engine.name}'
                  : '💾 Cache · ${engine.name} · $voiceLabel',
              fromCache: true,
            );
          }

          hasNetwork ??= await _checkNetwork();
          if (hasNetwork != true) return null;

          final result = await engine
              .synthesize(
                text: chunk,
                language: lang,
                speed: _speed,
                pitch: _pitch,
                voiceId: voiceId,
              )
              .timeout(const Duration(seconds: 15));
          if (!result.isSuccess) return null;

          final audio = result.audioData;
          if (audio != null && audio.isNotEmpty) {
            final filePath = await _cache.put(
              text: chunk,
              language: lang,
              engineId: engine.id,
              audioData: audio,
              voiceId: voiceId,
              speed: _speed,
              pitch: _pitch,
            );
            return _PreparedChunk.file(
              filePath,
              voiceLabel == null
                  ? '🌐 ${result.engineName}'
                  : '🌐 ${result.engineName} · $voiceLabel',
            );
          }
          final url = result.audioUrl;
          if (url != null) {
            return _PreparedChunk.url(url, '🌐 ${result.engineName}');
          }
          return null;
        },
      );
    } catch (e) {
      debugPrint('❌ Online ${engine.name} error: $e');
      _isLoading = false;
      _safeNotify();
      return false;
    }
  }

  /// Prefetch: tải online ở nền để cache cho lần sau
  void _prefetchOnline(String text, String lang, {bool matchVoiceLanguage = false}) {
    if (_isPrefetching) return;
    // PSRC-187: dòng dài được phát (và cache) theo TỪNG ĐOẠN — bản ghi của
    // cả dòng không bao giờ khớp khoá cache nữa ⇒ đừng tải cho phí mạng.
    if (text.length > kOnlineTtsChunkChars) return;
    _isPrefetching = true;

    Future(() async {
      try {
        final hasNetwork = await _checkNetwork();
        if (!hasNetwork) return;

        final engines = await _getOnlineEngines(lang);

        for (final engine in engines) {
          try {
            // TTS-VOICE-CACHE-001: prefetch phải dùng ĐÚNG giọng mà lúc
            // phát sẽ dùng, nếu không sẽ nạp sẵn một bản ghi giọng mặc
            // định (nữ) rồi không bao giờ khớp key — vừa phí mạng vừa là
            // nguồn gốc của "chọn giọng nam mà giọng nữ đọc".
            final voiceOverride = engine.id == 'edge_tts'
                ? await _resolveEdgeVoice(lang, matchLanguage: matchVoiceLanguage)
                : null;
            final voiceId = resolveOnlineVoice(
              engineId: engine.id,
              language: lang,
              voiceOverride: voiceOverride,
              selectedVoiceId: _selectedVoiceId,
              matchVoiceLanguage: matchVoiceLanguage,
            );

            final existing = await _cache.get(
              text: text,
              language: lang,
              engineId: engine.id,
              voiceId: voiceId,
              speed: _speed,
              pitch: _pitch,
            );
            if (existing != null) return;

            final result = await engine
                .synthesize(
                  text: text,
                  language: lang,
                  speed: _speed,
                  pitch: _pitch,
                  voiceId: voiceId,
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
                voiceId: voiceId,
                speed: _speed,
                pitch: _pitch,
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

  /// WP4 (API-005) — resolve engine TTS qua API từ store chung WP0.
  ///
  /// Trả null (engine bị bỏ qua, chuỗi y hệt hôm nay) khi: chưa cấu hình
  /// provider nào có ttsModel / routing tts = offlineOnly / provider bị tắt.
  Future<OpenAiCompatTtsEngine?> _resolveApiTtsEngine() async {
    try {
      await AiProviderStore.instance.ensureLoaded();
      final provider =
          AiProviderStore.instance.resolveProvider(AiRouteCapability.tts);
      if (provider == null) return null;
      return OpenAiCompatTtsEngine(provider: provider);
    } catch (e) {
      debugPrint('⚠️ TTS API: lỗi đọc cấu hình provider: $e');
      return null;
    }
  }

  Future<List<TtsEngine>> _getOnlineEngines(String lang) async {
    final engines = <TtsEngine>[];
    final sorted = _engineOrder.where((e) => e.isEnabled && e.isOnline).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final info in sorted) {
      switch (info.id) {
        case 'edge_tts':
          engines.add(EdgeTtsEngine());
          break;
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
        case 'openai_compat_tts':
          final apiEngine = await _resolveApiTtsEngine();
          if (apiEngine != null) engines.add(apiEngine);
          break;
      }
    }

    return engines;
  }

  String _resolveLanguage(String text) {
    if (_language != 'auto') {
      return _normalizeRequestedLocale(_language);
    }
    if (_autoDetectLanguage) return LanguageDetector.detect(text);
    return AppLanguageCatalog.english.ttsLocale;
  }

  // ═══════════════════════════════════════
  // PLAYBACK
  // ═══════════════════════════════════════

  /// Dừng hẳn: chặn MỌI callback phát tiếp bằng cách tăng thế hệ phát.
  Future<void> stop() async {
    _playbackEpoch++; // vô hiệu hoá mọi tác vụ đang bay (F3)
    _isSpeaking = false;
    _isLoading = false;
    _stopRequested = true;
    _paused = false;
    _pausedOfflineEngine = false;
    _offlineResumeFuture = null;
    _usingOfflineEngine = false; // Reset the active source when stopping
    await _silenceCurrentAudio();
    _safeNotify();
  }

  /// Tắt tiếng nguồn âm đang phát mà KHÔNG đổi thế hệ / cờ stop.
  ///
  /// Dùng khi chuyển câu trong cùng một phiên đọc.
  Future<void> _silenceCurrentAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _offlineEngine.stop();
    } catch (_) {}
  }

  /// Tạm dừng — phải DỪNG ÂM ĐANG PHÁT, cả AudioPlayer lẫn giọng máy.
  ///
  /// Lỗi cũ: chỉ `_audioPlayer.pause()`. Khi câu đang được đọc bằng
  /// flutter_tts (engine offline của máy) thì âm vẫn chạy tới hết câu, và
  /// vòng `speakLines` lập tức chuyển sang câu kế → bấm Pause xong vẫn nghe.
  Future<void> pause() async {
    if (_paused) return;
    _pausedOfflineEngine =
        _usingOfflineEngine || _offlineResumeFuture != null;
    _paused = true;
    try {
      await _audioPlayer.pause();
    } catch (_) {}
    try {
      if (_pausedOfflineEngine) await _offlineEngine.pause();
    } catch (_) {}
    _isSpeaking = false;
    _safeNotify();
  }

  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    _isSpeaking = true;
    if (_pausedOfflineEngine) {
      _usingOfflineEngine = true;
      final replay = _offlineEngine.restartPausedSpeech().catchError((error) {
        debugPrint('OfflineTTS resume error: $error');
      });
      _offlineResumeFuture = replay;
      unawaited(replay.whenComplete(() {
        if (!identical(_offlineResumeFuture, replay)) return;
        _offlineResumeFuture = null;
        _usingOfflineEngine = false;
        _isSpeaking = false;
        _safeNotify();
      }));
      _pausedOfflineEngine = false;
    } else {
      try {
        await _audioPlayer.play();
      } catch (_) {}
    }
    _safeNotify();
  }

  // ═══════════════════════════════════════
  // SPEAK MULTIPLE
  // ═══════════════════════════════════════

  /// Đọc lần lượt từng dòng.
  ///
  /// F3 — ba bảo đảm:
  ///   • Stop (tăng thế hệ) chặn luôn dòng kế, kể cả khi lệnh rơi vào giữa
  ///     lúc `speak()` đang dựng nguồn âm;
  ///   • Pause giữ vòng lặp ĐỨNG YÊN ở đúng dòng đang đọc (không auto-skip);
  ///   • `onLineChanged` bắn ĐÚNG MỘT LẦN cho mỗi dòng, và không bắn nữa sau
  ///     khi phiên đã bị thay thế.
  Future<void> speakLines(
    List<String> lines, {
    Duration pauseBetween = const Duration(milliseconds: 500),
    void Function(int currentIndex)? onLineChanged,
  }) async {
    _stopRequested = false;
    _paused = false;
    _isSpeaking = true;
    final epoch = _playbackEpoch;
    _safeNotify();

    for (int i = 0; i < lines.length; i++) {
      if (_stopRequested || isStaleEpoch(epoch)) break;
      onLineChanged?.call(i);

      await speak(lines[i]);
      if (_stopRequested || isStaleEpoch(epoch)) break;

      // Đảm bảo trạng thái vẫn đang trong phiên đọc
      if (!_paused) _isSpeaking = true;

      await _awaitLineFinished(epoch);
      if (_stopRequested || isStaleEpoch(epoch)) break;

      if (i < lines.length - 1) {
        await Future.delayed(pauseBetween);
      }
    }

    if (!isStaleEpoch(epoch)) {
      _isSpeaking = false;
      _safeNotify();
    }
  }

  /// Chờ dòng hiện tại phát xong, nhưng bỏ chờ ngay khi bị stop, và ĐỨNG YÊN
  /// (không coi là xong) khi đang tạm dừng.
  ///
  /// Dùng polling thay cho `firstWhere` trên `playerStateStream`: lúc pause,
  /// stream chỉ báo `playing == false` với `processingState == ready`, nên
  /// điều kiện completed/idle không bao giờ đúng và vòng cũ kẹt tới khi hết
  /// timeout 60 s rồi mới… chạy tiếp sang dòng sau.
  Future<void> _awaitLineFinished(int epoch) async {
    const tick = Duration(milliseconds: 120);
    // Đang tạm dừng thì ĐỨNG YÊN, kể cả khi nguồn âm đã tắt vì chính lệnh
    // pause: nếu không, giọng máy (flutter_tts) vừa bị cắt sẽ bị hiểu là
    // "đọc xong" và vòng lặp nhảy sang dòng kế trong lúc người dùng đang
    // tạm dừng. Đây chính là kiểu tự lướt dòng đã báo.
    while (_paused || _offlineResumeFuture != null) {
      if (_stopRequested || isStaleEpoch(epoch)) return;
      if (_paused) {
        await Future.delayed(tick);
        continue;
      }
      final replay = _offlineResumeFuture;
      if (replay != null) {
        try {
          await replay;
        } catch (_) {}
      }
    }
    // Offline speech futures complete only after the current sentence (or its
    // restart-after-pause) finishes; don't wait on AudioPlayer for them.
    if (_usingOfflineEngine) return;
    // Trần an toàn cho một dòng (dòng dài nhất của PDF vẫn dưới mức này).
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (_stopRequested || isStaleEpoch(epoch)) return;
      if (_paused) {
        await Future.delayed(tick);
        continue;
      }
      final state = _audioPlayer.processingState;
      if (state == ProcessingState.completed ||
          state == ProcessingState.idle) {
        return;
      }
      await Future.delayed(tick);
    }
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

  /// Tổng hợp văn bản thành FILE âm thanh (không phát) — cho tính năng
  /// "lưu bài đọc thành âm thanh" ở Web Reader: file thu được có thể mở lại
  /// trong tab Nghe để học với tốc độ chậm / A-B loop.
  /// Ưu tiên Piper offline (on-device, .wav); nếu không có thì thử Edge
  /// online (.mp3). Trả về đường dẫn file đầy đủ (có extension), null nếu
  /// thất bại. Dùng giọng/tốc độ/cao độ đang cài đặt của user.
  Future<String?> synthesizeToFile(
    String text, {
    required String pathWithoutExtension,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final lang = _resolveLanguage(trimmed);

    // 1. Piper offline — on-device, riêng tư
    try {
      final piper = PiperTtsEngine.instance;
      if (await piper.isAvailable()) {
        final result = await piper.synthesize(
          text: trimmed,
          language: lang,
          speed: _speed,
          pitch: _pitch,
          voiceId: _selectedVoiceId,
        );
        if (result.isSuccess &&
            result.audioData != null &&
            result.audioData!.isNotEmpty) {
          final path = '$pathWithoutExtension.wav';
          await File(path).writeAsBytes(result.audioData!, flush: true);
          _lastUsedEngine = '🎙️ Sherpa Piper (lưu file)';
          debugPrint('✅ TTS lưu file: $path');
          return path;
        }
        debugPrint('ℹ️ synthesizeToFile: Piper fail (${result.error})');
      }
    } catch (e) {
      debugPrint('⚠️ synthesizeToFile piper error: $e');
    }

    // 2. Edge online — cần mạng
    try {
      final edgeVoice = await _resolveEdgeVoice(lang);
      final result = await EdgeTtsEngine().synthesize(
        text: trimmed,
        language: lang,
        speed: _speed,
        pitch: _pitch,
        voiceId: edgeVoice,
      );
      if (result.isSuccess &&
          result.audioData != null &&
          result.audioData!.isNotEmpty) {
        final path = '$pathWithoutExtension.mp3';
        await File(path).writeAsBytes(result.audioData!, flush: true);
        _lastUsedEngine = '☁️ Edge (lưu file)';
        debugPrint('✅ TTS lưu file: $path');
        return path;
      }
      debugPrint('ℹ️ synthesizeToFile: Edge fail (${result.error})');
    } catch (e) {
      debugPrint('⚠️ synthesizeToFile edge error: $e');
    }

    return null;
  }

  // ═══════════════════════════════════════
  // VOICES / STATUS / CACHE
  // ═══════════════════════════════════════

  Future<List<TtsVoice>> getAvailableVoices([String? lang]) async {
    final effectiveLang = lang ?? _language;
    final voices = <TtsVoice>[];
    for (final engine in await _getOnlineEngines(effectiveLang)) {
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
    try {
      voices.addAll(
        await VieneuTtsEngine.instance.getAvailableVoices(effectiveLang),
      );
    } catch (_) {}
    return voices;
  }

  /// VieNeu-TTS chỉ đọc tiếng Việt (không đọc Pali/mūla gốc) — lọc theo
  /// trường ngôn ngữ của từng đoạn Tipiṭaka trước khi đưa vào engine này.
  bool _engineSupportsLanguage(String engineId, String lang) {
    if (engineId == 'vieneu_tts') return lang.startsWith('vi');
    return true;
  }

  Future<Map<String, bool>> checkEngineStatus() async {
    final status = <String, bool>{};
    final lang = _language == 'auto' ? 'vi-VN' : _language;
    for (final engine in await _getOnlineEngines(lang)) {
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
    try {
      status[VieneuTtsEngine.instance.name] =
          await VieneuTtsEngine.instance.isAvailable();
    } catch (_) {
      status[VieneuTtsEngine.instance.name] = false;
    }
    return status;
  }

  Future<List<String>> get activeEngines async {
    final lang = _language == 'auto' ? 'vi-VN' : _language;
    return [
      ...(await _getOnlineEngines(lang)).map((e) => e.name),
      _offlineEngine.name,
      if (await VieneuTtsEngine.instance.isAvailable())
        VieneuTtsEngine.instance.name,
    ];
  }

  Future<double> getCacheSizeMB() => _cache.getCacheSizeMB();
  Future<int> getCacheCount() => _cache.getCacheCount();
  Future<void> clearCache() => _cache.clear();

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  Future<bool> _playFile(String filePath, int epoch,
      {double? playbackSpeed}) async {
    try {
      _usingOfflineEngine = false; // ★ Đang dùng AudioPlayer
      await _audioPlayer.setFilePath(filePath);
      if (isStaleEpoch(epoch)) return false;
      await _audioPlayer.setSpeed(playbackSpeed ?? _speed);
      if (isStaleEpoch(epoch)) return false;
      _isSpeaking = true;
      _safeNotify();
      await _audioPlayer.play();
      // PSRC-187: KHÔNG clear _isSpeaking ở đây — audio đang phát bất đồng bộ.
      // Trạng thái sẽ được tắt khi AudioPlayer báo completed qua
      // playerStateStream listener, hoặc khi stop() được gọi. Clear ngay sau
      // play() khiến FlutterTtsServiceImpl poll thoát sớm và chồng phát.
      return !isStaleEpoch(epoch);
    } catch (e) {
      if (isStaleEpoch(epoch)) return false;
      _error = 'Lỗi phát: $e';
      _isSpeaking = false;
      _safeNotify();
      return false;
    }
  }

  Future<bool> _playUrl(String url, int epoch) async {
    try {
      _usingOfflineEngine = false; // ★ Đang dùng AudioPlayer
      await _audioPlayer.setUrl(url);
      if (isStaleEpoch(epoch)) return false;
      await _audioPlayer.setSpeed(_speed);
      if (isStaleEpoch(epoch)) return false;
      _isSpeaking = true;
      _safeNotify();
      await _audioPlayer.play();
      // PSRC-187: tương tự _playFile — không clear _isSpeaking ngay.
      return !isStaleEpoch(epoch);
    } catch (e) {
      if (isStaleEpoch(epoch)) return false;
      _error = 'Lỗi stream: $e';
      _isSpeaking = false;
      _safeNotify();
      return false;
    }
  }

  Future<void> waitForCompletion() => _waitForCompletion();

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

  /// YT-TTS-READ-001 — `TtsPriority.auto`: chọn ưu tiên theo **loại mạng**.
  ///
  /// * WiFi / Ethernet / VPN / desktop ⇒ `onlineFirst` (giọng tự nhiên, không
  ///   tốn data di động) — vẫn rớt về offline khi online lỗi.
  /// * Mạng di động ⇒ `offlineFirst` (phát ngay, không đốt data) — vẫn thử
  ///   online ở cuối chuỗi nếu offline không phát được.
  /// * Không có mạng ⇒ `offlineOnly` (khỏi chờ timeout 15s cho mỗi câu).
  ///
  /// Không phải `auto` thì trả nguyên `_priority`. Kết quả được cache 5 giây
  /// để đọc liên tiếp nhiều dòng không phải hỏi hệ thống từng câu — nhưng đủ
  /// ngắn để bật/tắt WiFi giữa phiên vẫn được nhận ra.
  TtsPriority? _autoCache;
  DateTime? _autoCachedAt;

  Future<TtsPriority> _effectivePriority() async {
    if (_priority != TtsPriority.auto) return _priority;
    final now = DateTime.now();
    final cachedAt = _autoCachedAt;
    if (_autoCache != null &&
        cachedAt != null &&
        now.difference(cachedAt) < const Duration(seconds: 5)) {
      return _autoCache!;
    }

    TtsPriority resolved;
    try {
      final result = await Connectivity().checkConnectivity();
      final noNetwork = result.isEmpty ||
          (result.length == 1 && result.contains(ConnectivityResult.none));
      if (noNetwork) {
        resolved = TtsPriority.offlineOnly;
      } else if (result.contains(ConnectivityResult.mobile)) {
        // Mạng di động (kể cả khi song song WiFi — ưu tiên tiết kiệm data).
        resolved = TtsPriority.offlineFirst;
      } else {
        resolved = TtsPriority.onlineFirst;
      }
    } catch (_) {
      // Không đọc được loại mạng (một số bản desktop): chọn offline trước và
      // vẫn giữ online ở cuối chuỗi — an toàn hơn là treo chờ mạng.
      resolved = TtsPriority.offlineFirst;
    }
    _autoCache = resolved;
    _autoCachedAt = now;
    debugPrint('🔊 [in4up-tts] auto → ${resolved.name}');
    return resolved;
  }

  Future<bool> _checkNetwork() async {
    try {
      final result = await Connectivity().checkConnectivity();
      // Desktop and corporate networks may expose only a VPN/other adapter.
      // Connectivity reports link types, not Internet reachability; the actual
      // TTS request remains the final check and already falls back on failure.
      final hasOnlineAdapter = result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.other);
      if (hasOnlineAdapter) return true;
      // Only skip the request when the plugin explicitly reports no network.
      // Empty/unknown desktop results are not reliable enough to block Edge;
      // the bounded synthesize timeout remains the definitive reachability test.
      return result.isEmpty || !result.contains(ConnectivityResult.none);
    } catch (_) {
      // Some desktop builds have no connectivity implementation. Try the
      // request rather than silently disabling online TTS.
      return true;
    }
  }

  // ═══════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════

  @override
  void dispose() {
    _disposed = true; // ★ FIX: Đánh dấu đã dispose trước khi cleanup
    voicesRevision.dispose();
    _audioPlayer.dispose();
    _offlineEngine.dispose();
    VieneuTtsEngine.instance.dispose();
    super.dispose();
  }
}

/// Một đoạn văn bản đã có sẵn âm thanh — file trong cache hoặc URL stream —
/// chờ tới lượt phát (PSRC-187, xem `TtsService._speakPreparedChunks`).
class _PreparedChunk {
  const _PreparedChunk.file(
    String this.path,
    this.label, {
    this.fromCache = false,
  }) : url = null;

  const _PreparedChunk.url(String this.url, this.label)
      : path = null,
        fromCache = false;

  /// File âm thanh (cache) — `null` khi là URL.
  final String? path;

  /// URL stream — `null` khi là file.
  final String? url;

  /// Nhãn engine hiện cho người dùng (`lastUsedEngine`).
  final String label;

  /// File lấy từ cache (phát hỏng thì được xoá + tổng hợp lại một lần).
  final bool fromCache;
}
