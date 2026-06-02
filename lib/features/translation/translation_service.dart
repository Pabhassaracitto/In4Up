import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:vipsound/features/tts/language_detector.dart';

import 'cache/translation_cache.dart';
import 'engines/deeplx_engine.dart';
import 'engines/google_free_engine.dart';
import 'engines/libre_engine.dart';
import 'engines/mymemory_engine.dart';
import 'engines/offline_engine.dart';
import 'engines/translation_engine.dart';

/// Quản lý dịch thuật với auto-fallback
///
/// Thứ tự ưu tiên:
/// 1. Cache (memory → disk)
/// 2. DeepLX (nếu user đã cấu hình server)
/// 3. Google Free (không cần API key)
/// 4. MyMemory (không cần đăng ký)
/// 5. Offline Dictionary (luôn sẵn sàng)
class TranslationService {
  // ═══════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════

  static final TranslationService _instance = TranslationService._();
  factory TranslationService() => _instance;
  TranslationService._() {
    _initEngines();
  }

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  final TranslationCache _cache = TranslationCache();
  final List<TranslationEngine> _engines = [];
  final OfflineEngine _offlineEngine = OfflineEngine();

  String _sourceLang = 'auto';
  String _targetLang = 'VI';
  String? _deeplxUrl;

  /// Danh sách các ngôn ngữ đích phổ biến
  static const Map<String, String> supportedTargetLanguages = {
    'VI': 'Tiếng Việt 🇻🇳',
    'EN': 'English 🇺🇸',
    'JA': '日本語 🇯🇵',
    'KO': '한국어 🇰🇷',
    'ZH': '中文 🇨🇳',
    'FR': 'Français 🇫🇷',
    'DE': 'Deutsch 🇩🇪',
    'ES': 'Español 🇪🇸',
    'RU': 'Русский 🇷🇺',
    'SI': 'Sinhala 🇱🇰',
    'TH': 'Thái Lan 🇹🇭',
    'MY': 'Burmese 🇲🇲',
    'HI': 'Indian 🇮🇳',
  };

  static String getFlagForLang(String code) {
    code = code.toUpperCase();
    switch (code) {
      case 'VI': return '🇻🇳';
      case 'EN': return '🇺🇸';
      case 'JA': return '🇯🇵';
      case 'KO': return '🇰🇷';
      case 'ZH': return '🇨🇳';
      case 'FR': return '🇫🇷';
      case 'DE': return '🇩🇪';
      case 'ES': return '🇪🇸';
      case 'RU': return '🇷🇺';
      case 'SI': return '🇱🇰';
      case 'TH': return '🇹🇭';
      case 'MY': return '🇲🇲';
      case 'HI': return '🇮🇳';
      default: return '🌐';
    }
  }

  static String getNameForLang(String code) {
    code = code.toUpperCase();
    switch (code) {
      case 'VI': return 'Việt';
      case 'EN': return 'Anh';
      case 'JA': return 'Nhật';
      case 'KO': return 'Hàn';
      case 'ZH': return 'Trung';
      case 'FR': return 'Pháp';
      case 'DE': return 'Đức';
      case 'ES': return 'Tây Ban Nha';
      case 'RU': return 'Nga';
      case 'SI': return 'Sinhala';
      case 'TH': return 'Thái';
      case 'MY': return 'Burmese';
      case 'HI': return 'Indian';
      default: return 'Global';
    }
  }

  static String getTtsLanguageCode(String code) {
    code = code.toUpperCase();
    switch (code) {
      case 'VI': return 'vi-VN';
      case 'EN': return 'en-US';
      case 'JA': return 'ja-JP';
      case 'KO': return 'ko-KR';
      case 'ZH': return 'zh-CN';
      case 'FR': return 'fr-FR';
      case 'DE': return 'de-DE';
      case 'ES': return 'es-ES';
      case 'RU': return 'ru-RU';
      case 'SI': return 'si-LK';
      case 'TH': return 'th-TH';
      case 'MY': return 'my-MM';
      case 'HI': return 'hi-IN';
      default: return 'vi-VN';
    }
  }

  String get targetLangFlag => getFlagForLang(_targetLang);
  String get targetLangLabel => _targetLang.toUpperCase();
  String get targetLangName => getNameForLang(_targetLang);

  /// Engine đang được dùng (để hiển thị UI)
  String _lastUsedEngine = '';
  String get lastUsedEngine => _lastUsedEngine;

  /// Thống kê
  int _cacheHits = 0;
  int _totalRequests = 0;
  int get cacheHits => _cacheHits;
  int get totalRequests => _totalRequests;

  // ═══════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════

  void _initEngines() {
    _engines.clear();

    // Thứ tự ưu tiên online:
    // 1. DeepLX (nếu user cấu hình)
    if (_deeplxUrl != null && _deeplxUrl!.isNotEmpty) {
      _engines.add(DeepLXEngine(serverUrl: _deeplxUrl!));
    }

    // 2. Google Free (ổn định nhất, chất lượng cao)
    _engines.add(GoogleFreeEngine());

    // 3. MyMemory (backup tốt, 5000 chars/ngày)
    _engines.add(MyMemoryEngine());

    // 4. LibreTranslate (mã nguồn mở, nhiều server miễn phí) ★ THÊM
    _engines.add(LibreEngine());
    // _engines.add(LibreEngine());

    // 5. Offline xử lý riêng ở cuối (trong translateText)

    debugPrint(
        '🔧 Engines: ${_engines.map((e) => e.name).join(" → ")} → Offline');
  }

  // ═══════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════

  /// Cấu hình service
  void configure({
    String? sourceLang,
    String? targetLang,
    String? deeplxUrl,
  }) {
    if (sourceLang != null) _sourceLang = sourceLang;
    if (targetLang != null) _targetLang = targetLang;
    if (deeplxUrl != null) {
      _deeplxUrl = deeplxUrl.trim().isEmpty ? null : deeplxUrl.trim();
    }
    _initEngines(); // Rebuild engine list
    debugPrint('🔧 TranslationService configured: '
        'source=$_sourceLang, target=$_targetLang, '
        'deeplx=${_deeplxUrl ?? "none"}, '
        'engines=${_engines.map((e) => e.name).join(", ")}');
  }

  String get sourceLang => _sourceLang;
  String get targetLang => _targetLang;
  String? get deeplxUrl => _deeplxUrl;

  /// Kiểm tra xem text đã ở trong ngôn ngữ đích chưa
  bool isAlreadyInTargetLanguage(String text) {
    if (text.trim().isEmpty) return false;
    final detected = LanguageDetector.detect(text).split('-').first.toUpperCase();
    final target = _targetLang.toUpperCase();

    // Map một số mã tương đương nếu cần
    if (target == 'VI' && detected == 'VI') return true;
    if (target == 'ZH' && detected == 'ZH') return true;
    if (target == 'EN' && detected == 'EN') return true;
    if (target == 'JA' && detected == 'JA') return true;
    if (target == 'KO' && detected == 'KO') return true;

    return detected == target;
  }

  /// Danh sách engine đang active
  List<String> get activeEngines =>
      [..._engines.map((e) => e.name), _offlineEngine.name];

  // ═══════════════════════════════════════════
  // 🔥 TRANSLATE - HÀM CHÍNH
  // ═══════════════════════════════════════════

  /// Dịch text với auto-fallback qua các engine
  Future<TranslationResult> translateText(String text) async {
    _totalRequests++;

    if (text.trim().isEmpty) {
      return TranslationResult.success(
        original: text,
        translated: '',
        engine: 'skip',
      );
    }

    // ──── 1. CHECK CACHE ────
    final cached = await _cache.get(
      text: text,
      sourceLang: _sourceLang,
      targetLang: _targetLang,
    );

    if (cached != null) {
      _cacheHits++;
      _lastUsedEngine = '💾 Cache';
      return TranslationResult.success(
        original: text,
        translated: cached,
        engine: 'cache',
      );
    }

    // ──── 2. CHECK NETWORK ────
    final hasNetwork = await _checkNetwork();

    if (hasNetwork) {
      // ──── 3. THỬ TỪNG ENGINE ONLINE ────
      for (final engine in _engines) {
        try {
          debugPrint('🔄 Trying ${engine.name}...');

          final result = await engine
              .translate(
                text: text,
                targetLang: _targetLang,
                sourceLang: _sourceLang,
              )
              .timeout(
                const Duration(seconds: 12),
                onTimeout: () => TranslationResult.failure(
                  original: text,
                  error: 'Timeout sau 12s',
                  engine: engine.name,
                ),
              );

          if (result.isSuccess && result.translatedText.isNotEmpty) {
            debugPrint('✅ ${engine.name} thành công! '
                '(${result.responseTime.inMilliseconds}ms)');

            // Lưu cache
            await _cache.put(
              text: text,
              sourceLang: _sourceLang,
              targetLang: _targetLang,
              translation: result.translatedText,
            );

            _lastUsedEngine = '🌐 ${engine.name}';
            return result;
          } else {
            debugPrint('❌ ${engine.name} thất bại: ${result.error}');
            // Tiếp tục thử engine tiếp theo
          }
        } catch (e) {
          debugPrint('❌ ${engine.name} exception: $e');
          // Tiếp tục thử engine tiếp theo
        }

        // Delay nhỏ trước khi thử engine tiếp
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else {
      debugPrint('📡 Không có mạng, chuyển sang offline...');
    }

    // ──── 4. OFFLINE FALLBACK ────
    debugPrint('📖 Dùng Offline Dictionary...');
    final offlineResult = await _offlineEngine.translate(
      text: text,
      targetLang: _targetLang,
      sourceLang: _sourceLang,
    );

    _lastUsedEngine = '📖 Offline';

    if (offlineResult.isSuccess) {
      // Cache offline result cũng được
      await _cache.put(
        text: text,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        translation: offlineResult.translatedText,
      );
    }

    return offlineResult;
  }

  // ═══════════════════════════════════════════
  // BATCH TRANSLATE
  // ═══════════════════════════════════════════

  /// Dịch nhiều dòng tuần tự
  Future<List<TranslationResult>> translateBatch(
    List<String> texts, {
    void Function(int done, int total)? onProgress,
    Duration? delayBetween,
  }) async {
    final results = <TranslationResult>[];

    for (int i = 0; i < texts.length; i++) {
      final result = await translateText(texts[i]);
      results.add(result);
      onProgress?.call(i + 1, texts.length);

      // Delay giữa requests (chỉ cho online)
      if (i < texts.length - 1) {
        final delay = delayBetween ?? const Duration(milliseconds: 200);
        await Future.delayed(delay);
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════
  // HEALTH CHECK
  // ═══════════════════════════════════════════

  /// Kiểm tra trạng thái từng engine
  Future<Map<String, bool>> checkAllEngines() async {
    final results = <String, bool>{};

    for (final engine in _engines) {
      try {
        results[engine.name] =
            await engine.isAvailable().timeout(const Duration(seconds: 5));
      } catch (_) {
        results[engine.name] = false;
      }
    }

    results[_offlineEngine.name] = await _offlineEngine.isAvailable();
    return results;
  }

  // ═══════════════════════════════════════════
  // CACHE MANAGEMENT
  // ═══════════════════════════════════════════

  Future<void> clearCache() async {
    await _cache.clear();
    _cacheHits = 0;
    _totalRequests = 0;
  }

  int get cacheSize => _cache.memorySize;

  // ═══════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════

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

  // ═══════════════════════════════════════════
  // BACKWARD COMPATIBILITY (cho code cũ)
  // ═══════════════════════════════════════════

  /// Tương thích ngược với DeepLXService.serverUrl
  static String get serverUrl =>
      TranslationService()._deeplxUrl ?? 'http://localhost:1188/translate';

  static set serverUrl(String url) {
    TranslationService().configure(deeplxUrl: url);
  }

  static String get targetLangStatic => TranslationService()._targetLang;

  static set targetLangStatic(String lang) {
    TranslationService().configure(targetLang: lang);
  }
}
