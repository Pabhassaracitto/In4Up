import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language/app_language.dart';
import '../tts/language_detector.dart';
import 'cache/translation_cache.dart';
import 'engines/deeplx_engine.dart';
import 'engines/google_free_engine.dart';
import 'engines/libre_engine.dart';
import 'engines/mymemory_engine.dart';
import 'engines/offline_engine.dart';
import 'engines/mlkit_engine.dart';
import 'engines/translation_engine.dart';
import 'glossary/glossary_store.dart';
import 'glossary/protect_tokens.dart';
import 'glossary/translation_glossary.dart';

/// Translation orchestration with automatic source detection and engine
/// fallback. Language metadata comes from the same 26-language catalog used
/// by app settings and TTS.
///
/// Pipeline (bắt buộc — một pipeline duy nhất):
///   1. TranslationCache (MD5, key ổn định)
///   2. GLOSSARY longest-match + protect-tokens (thay thuật ngữ bằng
///      `__G{n}__`) — TẦNG CHUYÊN NGỮ, chạy TRƯỚC mọi engine
///   3. Engine câu offline — ML Kit On-Device (Android/iOS, model đã tải)
///   4. Online engines (DeepLX/Google Free/MyMemory/Libre) nếu có mạng và
///      user KHÔNG khóa offline-only
///   5. OfflineEngine từ điển từ (last resort, chỉ EN → VI)
///   → restore placeholder → cache lưu CÂU ĐÃ RESTORE.
///
/// HI ↔ VI: pivot qua EN (2 bước + glossary hai đầu) khi đủ model ML Kit.
class TranslationService {
  TranslationService._({
    List<TranslationEngine>? onlineEngines,
    TranslationEngine? offlineEngine,
    TranslationEngine? mlkitEngine,
    Glossary? glossary,
    bool? networkAvailable,
  })  : _cache = TranslationCache(),
        _engines = onlineEngines ?? <TranslationEngine>[],
        _offlineEngine = offlineEngine ?? OfflineEngine(),
        _mlkit = mlkitEngine ?? MlKitEngine(),
        _glossary = glossary ?? const Glossary(const <GlossaryEntry>[]),
        _glossaryStore = glossary == null ? GlossaryStore() : null,
        _injectedNetwork = networkAvailable {
    if (onlineEngines == null) {
      _initEngines();
      _loadOfflineOnlyPref();
    }
    final store = _glossaryStore;
    if (store != null) {
      // Fire-and-forget: không block UI; translateText sẽ ensureInit lại.
      unawaited(store.ensureInit());
      _glossarySub = store.changes.listen(_onGlossaryChanged);
    }
  }

  static final TranslationService _instance = TranslationService._();
  factory TranslationService() => _instance;

  /// Constructor test DUY NHẤT (không phải singleton): inject engine,
  /// glossary, network. Không chạm Hive/asset/SharedPreferences.
  factory TranslationService.forTest({
    List<TranslationEngine> onlineEngines = const <TranslationEngine>[],
    TranslationEngine? offlineEngine,
    TranslationEngine? mlkitEngine,
    Glossary? glossary,
    bool networkAvailable = false,
  }) {
    return TranslationService._(
      onlineEngines: onlineEngines,
      offlineEngine: offlineEngine,
      mlkitEngine: mlkitEngine,
      glossary: glossary ?? const Glossary(const <GlossaryEntry>[]),
      networkAvailable: networkAvailable,
    );
  }

  final TranslationCache _cache;
  final List<TranslationEngine> _engines;
  final TranslationEngine _offlineEngine;
  final TranslationEngine _mlkit;
  Glossary _glossary;
  final GlossaryStore? _glossaryStore;
  final bool? _injectedNetwork;
  StreamSubscription<void>? _glossarySub;

  String _sourceLang = 'AUTO';
  String _targetLang = 'VI';
  String? _deeplxUrl;

  String _lastUsedEngine = '';
  int _cacheHits = 0;
  int _totalRequests = 0;

  /// Bật/tắt tầng glossary (mặc định bật; test tắt để chứng minh thứ tự).
  bool _glossaryEnabled = true;

  /// "Chỉ offline": bỏ qua online engines (vòng 3).
  bool _offlineOnly = false;

  static const String _offlineOnlyPrefKey = 'translation_offline_only';

  // ==================== Public state ====================

  static List<AppLanguage> get supportedTargetLanguages =>
      AppLanguageCatalog.languages;

  String get sourceLang => _sourceLang;
  String get targetLang => _targetLang;
  String? get deeplxUrl => _deeplxUrl;
  String get lastUsedEngine => _lastUsedEngine;
  int get cacheHits => _cacheHits;
  int get totalRequests => _totalRequests;
  int get cacheSize => _cache.memorySize;

  AppLanguage get targetLanguage =>
      AppLanguageCatalog.fromCode(_targetLang, fallback: AppLanguageCatalog.vietnamese);
  String get targetLangFlag => targetLanguage.flag;
  String get targetLangLabel => targetLanguage.translationCode;
  String get targetLangName => targetLanguage.nativeName;
  String get targetTtsLocale => targetLanguage.ttsLocale;

  /// Engine câu offline (ML Kit) — UI cài đặt dùng.
  /// (Instance forTest có thể inject engine giả — UI chỉ dùng singleton.)
  MlKitEngine get mlkit => _mlkit as MlKitEngine;

  /// Glossary hiện tại (snapshot) — UI + test.
  Glossary get glossary => _glossary;

  /// Store glossary (singleton app); null với instance forTest.
  GlossaryStore? get glossaryStore => _glossaryStore;

  bool get glossaryEnabled => _glossaryEnabled;
  set glossaryEnabled(bool value) => _glossaryEnabled = value;

  bool get offlineOnly => _offlineOnly;
  set offlineOnly(bool value) {
    _offlineOnly = value;
    _persistOfflineOnly(value);
  }

  List<String> get activeEngines => [
        _mlkit.name,
        ..._engines.map((engine) => engine.name),
        _offlineEngine.name,
      ];

  void _initEngines() {
    _engines.clear();
    if (_deeplxUrl != null && _deeplxUrl!.isNotEmpty) {
      _engines.add(DeepLXEngine(serverUrl: _deeplxUrl!));
    }
    _engines
      ..add(GoogleFreeEngine())
      ..add(MyMemoryEngine())
      ..add(LibreEngine());

    debugPrint(
      '🔧 Translation engines: ML Kit → '
      '${_engines.map((e) => e.name).join(" → ")} → Offline',
    );
  }

  void configure({
    String? sourceLang,
    String? targetLang,
    String? deeplxUrl,
  }) {
    if (sourceLang != null) {
      final normalized = sourceLang.trim().replaceAll('_', '-').toUpperCase();
      _sourceLang = normalized == 'AUTO'
          ? 'AUTO'
          : AppLanguageCatalog.normalizeTranslationCode(
              normalized,
              fallback: _sourceLang == 'AUTO' ? 'EN' : _sourceLang,
            );
    }

    if (targetLang != null) {
      final resolved = AppLanguageCatalog.maybeFromCode(targetLang);
      if (resolved != null) _targetLang = resolved.translationCode;
    }

    var rebuildEngines = false;
    if (deeplxUrl != null) {
      final normalizedUrl = deeplxUrl.trim().isEmpty ? null : deeplxUrl.trim();
      rebuildEngines = normalizedUrl != _deeplxUrl;
      _deeplxUrl = normalizedUrl;
    }
    if (rebuildEngines) _initEngines();

    debugPrint(
      '🔧 Translation configured: source=$_sourceLang, target=$_targetLang, '
      'deeplx=${_deeplxUrl ?? "none"}',
    );
  }

  AppLanguage detectSourceLanguage(String text) =>
      LanguageDetector.detectLanguage(text);

  bool isAlreadyInTargetLanguage(String text, {String? targetLang}) {
    if (text.trim().isEmpty) return false;
    final source = detectSourceLanguage(text);
    final target = AppLanguageCatalog.fromCode(targetLang ?? _targetLang);
    return source.translationCode == target.translationCode;
  }

  // ==================== Core pipeline ====================

  Future<TranslationResult> translateText(
    String text, {
    String? sourceLang,
    String? targetLang,
  }) async {
    _totalRequests++;

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult.success(
        original: text,
        translated: '',
        engine: 'skip',
      );
    }

    final requestedSource =
        (sourceLang ?? _sourceLang).trim().replaceAll('_', '-').toUpperCase();
    final source = requestedSource == 'AUTO'
        ? detectSourceLanguage(trimmed)
        : AppLanguageCatalog.fromCode(requestedSource);
    final target = AppLanguageCatalog.fromCode(
      targetLang ?? _targetLang,
      fallback: targetLanguage,
    );

    if (source.translationCode == target.translationCode) {
      _lastUsedEngine = '↔️ Cùng ngôn ngữ';
      return TranslationResult.success(
        original: text,
        translated: text,
        engine: 'same-language',
        detectedLang: source.translationCode,
        targetLang: target.translationCode,
      );
    }

    final cached = await _cache.get(
      text: text,
      sourceLang: source.translationCode,
      targetLang: target.translationCode,
    );
    if (cached != null) {
      _cacheHits++;
      _lastUsedEngine = '💾 Cache';
      return TranslationResult.success(
        original: text,
        translated: cached,
        engine: 'cache',
        detectedLang: source.translationCode,
        targetLang: target.translationCode,
      );
    }

    await _ensureGlossary();
    final hasNetwork = _offlineOnly ? false : await _checkNetwork();
    return _translateWithPipeline(text, source, target, hasNetwork);
  }

  /// Glossary (protect) → engine chain (ML Kit → online → từ điển) →
  /// restore, cho từng bước (pivot HI ↔ VI chạy 2 bước qua EN).
  Future<TranslationResult> _translateWithPipeline(
    String text,
    AppLanguage source,
    AppLanguage target,
    bool hasNetwork,
  ) async {
    final sourceCode = source.translationCode;
    final targetCode = target.translationCode;
    final steps = await _planSteps(sourceCode, targetCode);

    var current = text;
    var placeholderBase = 0;
    var engineLabel = '';
    var glossaryHits = 0;

    for (final step in steps) {
      final String stepSource = step.$1;
      final String stepTarget = step.$2;

      // TẦNG CHUYÊN NGỮ — luôn trước engine của bước này.
      GlossaryProtection? protection;
      if (_glossaryEnabled && _glossary.isNotEmpty) {
        protection = _glossary.protect(
          current,
          source: stepSource,
          target: stepTarget,
          startIndex: placeholderBase,
        );
        placeholderBase += protection.placeholderCount;
        glossaryHits += protection.placeholderCount;
      }
      final engineText = protection?.protectedText ?? current;

      final result = await _runEngineChain(
        text: engineText,
        sourceCode: stepSource,
        targetCode: stepTarget,
        hasNetwork: hasNetwork,
      );
      if (!result.isSuccess) {
        _lastUsedEngine = '❌ ${result.engineName}';
        return result.withLanguages(
          source: sourceCode,
          target: targetCode,
        );
      }

      current = protection != null
          ? protection.restore(result.translatedText)
          : result.translatedText;
      engineLabel = result.engineName;
    }

    final enriched = TranslationResult.success(
      original: text,
      translated: current,
      engine: engineLabel,
      detectedLang: sourceCode,
      targetLang: targetCode,
    );
    if (current.trim().isNotEmpty) {
      await _cache.put(
        text: text,
        sourceLang: sourceCode,
        targetLang: targetCode,
        translation: current,
      );
    }
    _lastUsedEngine = glossaryHits > 0
        ? '📚 $engineLabel (glossary $glossaryHits)'
        : '📚 $engineLabel';
    return enriched;
  }

  /// HI ↔ VI không dịch trực tiếp trong ML Kit → pivot qua EN (2 lần +
  /// glossary hai đầu). Chỉ pivot khi model ML Kit đủ cho CẢ tuyến;
  /// ngược lại giữ cặp trực tiếp (online engines tự xử lý).
  Future<List<(String, String)>> _planSteps(
    String sourceCode,
    String targetCode,
  ) async {
    const pivotPairs = <String, String>{'HI': 'VI', 'VI': 'HI'};
    if (pivotPairs[sourceCode] == targetCode) {
      final pivotSteps = <(String, String)>[
        (sourceCode, 'EN'),
        ('EN', targetCode),
      ];
      var ready = true;
      for (final step in pivotSteps) {
        if (!await _sentenceEngineReady(step.$1, step.$2)) {
          ready = false;
          break;
        }
      }
      if (ready) return pivotSteps;
    }
    return <(String, String)>[(sourceCode, targetCode)];
  }

  Future<bool> _sentenceEngineReady(String sourceCode, String targetCode) async {
    try {
      if (!await _mlkit.isAvailable()) return false;
      if (_mlkit is MlKitEngine) {
        return _mlkit.isPairReady(
          sourceCode: sourceCode,
          targetCode: targetCode,
        );
      }
      return true; // engine test inject
    } catch (_) {
      return false;
    }
  }

  /// Engine chain của MỘT bước:
  ///   1) ML Kit (offline câu, Android/iOS, model đã tải)
  ///   2) Online engines (nếu có mạng + không khóa offline-only)
  ///   3) OfflineEngine từ điển từ (last resort)
  Future<TranslationResult> _runEngineChain({
    required String text,
    required String sourceCode,
    required String targetCode,
    required bool hasNetwork,
  }) async {
    // 1) Engine câu offline.
    //    Gọi translate cả khi model CHƯA tải: engine tự trả failure RÕ
    //    ("Chưa tải gói dịch Hindi") thay vì im lặng rơi về ráp từ.
    TranslationResult? mlkitFailure;
    if (await _mlkit.isAvailable()) {
      try {
        final result = await _mlkit
            .translate(
              text: text,
              targetLang: targetCode,
              sourceLang: sourceCode,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => TranslationResult.failure(
                original: text,
                error: 'Timeout ML Kit sau 30 giây',
                engine: _mlkit.name,
              ),
            );
        if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
          return result;
        }
        mlkitFailure = result;
        debugPrint('❌ ${_mlkit.name}: ${result.error}');
      } catch (error) {
        debugPrint('❌ ${_mlkit.name} exception: $error');
      }
    }

    // 2) Online engines.
    if (hasNetwork && !_offlineOnly) {
      for (final engine in _engines) {
        try {
          final result = await engine
              .translate(
                text: text,
                targetLang: targetCode,
                sourceLang: sourceCode,
              )
              .timeout(
                const Duration(seconds: 12),
                onTimeout: () => TranslationResult.failure(
                  original: text,
                  error: 'Timeout sau 12 giây',
                  engine: engine.name,
                  detectedLang: sourceCode,
                  targetLang: targetCode,
                ),
              );

          if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
            return result;
          }
          debugPrint('❌ ${engine.name}: ${result.error}');
        } catch (error) {
          debugPrint('❌ ${engine.name} exception: $error');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    // 3) Từ điển offline (last resort — placeholder __G{n}__ không có trong
    //    từ điển nên được giữ nguyên → restore sau).
    final dictResult = await _offlineEngine.translate(
      text: text,
      targetLang: targetCode,
      sourceLang: sourceCode,
    );
    if (dictResult.isSuccess) return dictResult;
    // Cặp này không service được offline (vd thiếu model Hindi + không
    // mạng) → trả lỗi CỤ THỂ hơn của ML Kit thay cho lỗi chung của từ điển.
    return mlkitFailure ?? dictResult;
  }

  // ==================== Batch / engine check / cache ====================

  Future<List<TranslationResult>> translateBatch(
    List<String> texts, {
    String? sourceLang,
    String? targetLang,
    void Function(int done, int total)? onProgress,
    Duration? delayBetween,
  }) async {
    final results = <TranslationResult>[];
    final sourceSnapshot = sourceLang ?? _sourceLang;
    final targetSnapshot = targetLang ?? _targetLang;

    for (var index = 0; index < texts.length; index++) {
      results.add(await translateText(
        texts[index],
        sourceLang: sourceSnapshot,
        targetLang: targetSnapshot,
      ));
      onProgress?.call(index + 1, texts.length);
      if (index < texts.length - 1) {
        await Future<void>.delayed(
          delayBetween ?? const Duration(milliseconds: 200),
        );
      }
    }
    return results;
  }

  Future<Map<String, bool>> checkAllEngines() async {
    final results = <String, bool>{};
    try {
      results[_mlkit.name] =
          await _mlkit.isAvailable().timeout(const Duration(seconds: 5));
    } catch (_) {
      results[_mlkit.name] = false;
    }
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

  Future<void> clearCache() async {
    await _cache.clear();
    _cacheHits = 0;
    _totalRequests = 0;
  }

  // ==================== Internal ====================

  Future<void> _ensureGlossary() async {
    final store = _glossaryStore;
    if (store == null) return;
    try {
      await store.ensureInit();
      _glossary = store.glossary;
    } catch (e) {
      debugPrint('⚠️ Glossary không sẵn sàng (dùng glossary rỗng): $e');
    }
  }

  void _onGlossaryChanged() {
    final store = _glossaryStore;
    if (store == null) return;
    _glossary = store.glossary;
    // Glossary đổi → bản dịch cache cũ có thể chứa nghĩa cũ → clear.
    unawaited(
      _cache.clear().catchError((Object e) {
        debugPrint('⚠️ Clear cache sau glossary change: $e');
      }),
    );
    debugPrint(
      '📚 Glossary đổi: ${store.entries.length} entries — translation cache cleared',
    );
  }

  Future<bool> _checkNetwork() async {
    final injected = _injectedNetwork;
    if (injected != null) return injected;
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any(
        (entry) =>
            entry == ConnectivityResult.wifi ||
            entry == ConnectivityResult.mobile ||
            entry == ConnectivityResult.ethernet,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadOfflineOnlyPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _offlineOnly = prefs.getBool(_offlineOnlyPrefKey) ?? false;
    } catch (_) {}
  }

  Future<void> _persistOfflineOnly(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_offlineOnlyPrefKey, value);
    } catch (_) {}
  }

  // ==================== Static compat (cũ) ====================

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
