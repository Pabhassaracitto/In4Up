import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

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
import 'glossary/translation_glossary.dart';

/// Translation orchestration with automatic source detection and engine
/// fallback. Language metadata comes from the same 26-language catalog used
/// by app settings and TTS.
class TranslationService {
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

  bool _glossaryEnabled = true;

  bool _offlineOnly = false;

  static const String _offlineOnlyPrefKey = 'translation_offline_only';

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

  List<String> get activeEngines =>
      [..._engines.map((engine) => engine.name), _offlineEngine.name];

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
      '🔧 Translation engines: ${_engines.map((e) => e.name).join(" → ")} → Offline',
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

    final hasNetwork = await _checkNetwork();
    if (hasNetwork) {
      for (final engine in _engines) {
        try {
          final result = await engine
              .translate(
                text: text,
                targetLang: target.translationCode,
                sourceLang: source.translationCode,
              )
              .timeout(
                const Duration(seconds: 12),
                onTimeout: () => TranslationResult.failure(
                  original: text,
                  error: 'Timeout sau 12 giây',
                  engine: engine.name,
                  detectedLang: source.translationCode,
                  targetLang: target.translationCode,
                ),
              );

          if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
            final enriched = result.withLanguages(
              source: source.translationCode,
              target: target.translationCode,
            );
            await _cache.put(
              text: text,
              sourceLang: source.translationCode,
              targetLang: target.translationCode,
              translation: enriched.translatedText,
            );
            _lastUsedEngine = '🌐 ${engine.name}';
            return enriched;
          }
          debugPrint('❌ ${engine.name}: ${result.error}');
        } catch (error) {
          debugPrint('❌ ${engine.name} exception: $error');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    final offlineResult = await _offlineEngine.translate(
      text: text,
      targetLang: target.translationCode,
      sourceLang: source.translationCode,
    );
    _lastUsedEngine = '📖 Offline';
    final enrichedOffline = offlineResult.withLanguages(
      source: source.translationCode,
      target: target.translationCode,
    );

    if (enrichedOffline.isSuccess &&
        enrichedOffline.translatedText.trim().isNotEmpty) {
      await _cache.put(
        text: text,
        sourceLang: source.translationCode,
        targetLang: target.translationCode,
        translation: enrichedOffline.translatedText,
      );
    }
    return enrichedOffline;
  }

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
