// packages/vipsound_ai/lib/src/facade/ai_service_facade.dart
// v11.0-final — fix fromLocalDict, withIpa, sentenceAnalysis

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/ai_engine.dart';
import '../engine/ai_engine_gemma.dart';
import '../engine/ai_engine_mock.dart';
import '../error/ai_error_handler.dart';
import '../loader/ai_model_loader.dart';
import '../models/ai_analysis.dart';
import '../prompts/ai_prompts_library.dart';

/// Facade duy nhất cho toàn bộ AI module
/// UI và Provider chỉ tương tác qua class này
class AiServiceFacade extends ChangeNotifier {
  static AiServiceFacade? _instance;
  factory AiServiceFacade() => _instance ??= AiServiceFacade._internal();
  AiServiceFacade._internal();

  AiEngine? _engine;
  bool _initialized = false;
  bool _disposed = false;
  bool _useMock = false;

  final _cache = <String, AiAnalysis>{};

  // ── State for legacy UI (word_analysis_sheet) ─────────────
  AiAnalysis? _currentAnalysis;
  AiAnalysis? get currentAnalysis => _currentAnalysis;
  AiFacadeState _facadeState = AiFacadeState.idle;
  AiFacadeState get facadeState => _facadeState;
  bool get isLoading => _facadeState == AiFacadeState.loading;
  bool get hasModel => _initialized;
  String? _lastError;
  String? get lastError => _lastError;

  bool get isReady => _initialized && (_engine?.state == AiEngineState.ready);
  bool get useMock => _useMock;

  // ── Init ──────────────────────────────────────────────────

  Future<void> initializeAsync() async {
    if (_initialized) return;
    try {
      final loader = AiModelLoader();
      final result = await loader.findOrLoadModel(allowDownload: false);
      if (result.success && result.modelPath != null) {
        await initialize(modelPath: result.modelPath!);
      } else {
        await initialize(modelPath: '', useMock: true);
      }
    } catch (e) {
      debugPrint('[AiServiceFacade] initializeAsync error: $e');
      await initialize(modelPath: '', useMock: true);
    }
  }

  Future<bool> initialize({
    required String modelPath,
    bool useMock = false,
  }) async {
    if (_initialized) return true;
    _useMock = useMock;

    if (useMock) {
      _engine = AiEngineMock();
      await _engine!.initialize(modelPath: modelPath);
      _initialized = true;
      debugPrint('[AiServiceFacade] Mock mode');
      if (!_disposed) notifyListeners();
      return true;
    }

    _engine = AiEngineGemma();
    final ok = await _engine!.initialize(modelPath: modelPath);
    _initialized = ok;
    if (!_disposed) notifyListeners();
    return ok;
  }

  // ── Word Lookup ───────────────────────────────────────────

  Future<AiAnalysis> lookupWord(
    String word, {
    String? sentenceContext,
    Map<String, dynamic>? localDictEntry,
  }) async {
    if (word.trim().isEmpty) {
      return AiAnalysis.fallback(word, errorReason: 'Empty word');
    }

    final cacheKey = 'word_${word.toLowerCase().trim()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      AiAnalysis result;

      if (!isReady) {
        result = buildFromLocalDict(word, localDictEntry);
      } else {
        result = await _engine!
            .analyze(
              text: word,
              type: AiAnalysisType.wordLookup,
              context: sentenceContext,
            )
            .first
            .timeout(const Duration(seconds: 30));

        if (localDictEntry != null) {
          result = enrichWithLocalDict(result, localDictEntry);
        }
      }

      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('[AiServiceFacade] lookupWord error: $e');
      return buildFromLocalDict(word, localDictEntry);
    }
  }

  AiAnalysis buildFromLocalDict(
    String word,
    Map<String, dynamic>? dictEntry,
  ) {
    if (dictEntry == null) {
      return AiAnalysis.fallback(
        word,
        errorReason: 'No local dict entry and engine not ready',
      );
    }

    final meaning = dictEntry['meaning'] as String? ?? '';
    final phonetic = dictEntry['phonetic'] as String?;
    final example = dictEntry['example'] as String?;

    return AiAnalysis(
      summary: meaning,
      topics: const ['Vocabulary'],
      terms: const [],
      success: true,
      language: 'en',
      analysisType: AiAnalysisType.wordLookup,
      generatedAt: DateTime.now(),
      wordDetail: WordDetail(
        word: word,
        meaning: meaning,
        phonetic: phonetic,
        memoryHook: example,
      ),
    );
  }

  AiAnalysis enrichWithLocalDict(
    AiAnalysis result,
    Map<String, dynamic> dictEntry,
  ) {
    final phonetic = dictEntry['phonetic'] as String?;
    if (phonetic == null || phonetic.isEmpty) return result;
    if (result.wordDetail == null) return result;

    final enrichedDetail = WordDetail(
      word: result.wordDetail!.word,
      meaning: result.wordDetail!.meaning,
      phonetic: phonetic,
      cefrLevel: result.wordDetail!.cefrLevel,
      wordType: result.wordDetail!.wordType,
      etymologyHint: result.wordDetail!.etymologyHint,
      memoryHook: result.wordDetail!.memoryHook,
    );

    return AiAnalysis(
      inputText: result.inputText,
      summary: result.summary,
      topics: result.topics,
      terms: result.terms,
      success: result.success,
      actionItems: result.actionItems,
      language: result.language,
      errorReason: result.errorReason,
      analysisType: result.analysisType,
      wordDetail: enrichedDetail,
      paoSuggestions: result.paoSuggestions,
      isPartial: result.isPartial,
      contextExamples: result.contextExamples,
      generatedAt: result.generatedAt,
      source: result.source,
      grammar: result.grammar,
      visualPrompt: result.visualPrompt,
      ipaFallback: result.ipaFallback,
    );
  }

  // ── Sentence Analysis ─────────────────────────────────────

  Future<AiAnalysis> analyzeSentence(String sentence) async {
    if (!isReady) {
      return AiAnalysis.fallback(
        sentence,
        errorReason: 'Engine not ready',
        analysisType: AiAnalysisType.sentenceParse,
      );
    }

    final cacheKey = 'sent_${sentence.trim()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final result = await _engine!
          .analyze(
            text: sentence,
            type: AiAnalysisType.sentenceParse,
          )
          .first
          .timeout(const Duration(seconds: 30));

      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      return AiAnalysis.fallback(
        sentence,
        errorReason: e.toString(),
        analysisType: AiAnalysisType.sentenceParse,
      );
    }
  }

  // ── Summarize ─────────────────────────────────────────────

  Future<AiAnalysis> summarize(
    String transcript, {
    String? speakerContext,
  }) async {
    if (!isReady) {
      return AiAnalysis.fallback(
        transcript,
        errorReason: 'Engine not ready',
        analysisType: AiAnalysisType.summarize,
      );
    }

    try {
      return await _engine!
          .analyze(
            text: transcript,
            type: AiAnalysisType.summarize,
            context: speakerContext,
          )
          .first
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      return AiAnalysis.fallback(
        transcript,
        errorReason: e.toString(),
        analysisType: AiAnalysisType.summarize,
      );
    }
  }

  // ── Term Extract ──────────────────────────────────────────

  Future<AiAnalysis> extractTerms(String transcript) async {
    if (!isReady) {
      return AiAnalysis.fallback(
        transcript,
        errorReason: 'Engine not ready',
        analysisType: AiAnalysisType.termExtract,
      );
    }

    try {
      return await _engine!
          .analyze(
            text: transcript,
            type: AiAnalysisType.termExtract,
          )
          .first
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      return AiAnalysis.fallback(
        transcript,
        errorReason: e.toString(),
        analysisType: AiAnalysisType.termExtract,
      );
    }
  }

  // ── PAO Generation ────────────────────────────────────────

  Future<AiAnalysis> generatePao(String word) async {
    if (!isReady) {
      return AiAnalysis.fallback(
        word,
        errorReason: 'Engine not ready',
        analysisType: AiAnalysisType.paoGeneration,
      );
    }

    try {
      return await _engine!
          .analyze(
            text: word,
            type: AiAnalysisType.paoGeneration,
          )
          .first
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return AiAnalysis.fallback(
        word,
        errorReason: e.toString(),
        analysisType: AiAnalysisType.paoGeneration,
      );
    }
  }

  // ── Legacy 3-tier API for word_analysis_sheet ───────────

  Future<void> analyzeWord({
    required String word,
    String? sentenceContext,
    required String? Function(String) localDictLookup,
    required List<String>? Function(String) ipaPhoneLookup,
  }) async {
    _facadeState = AiFacadeState.loading;
    _currentAnalysis = null;
    notifyListeners();

    final localMeaning = localDictLookup(word);
    if (localMeaning != null && localMeaning.isNotEmpty) {
      _currentAnalysis = AiAnalysis.fromLocalDict(inputText: word, meaning: localMeaning);
      notifyListeners();
    }

    final ipaFuture = Future.microtask(() {
      final phonemes = ipaPhoneLookup(word);
      if (phonemes == null || phonemes.isEmpty) return null;
      return '/${phonemes.join('')}/';
    });

    if (isReady) {
      try {
        final result = await lookupWord(word, sentenceContext: sentenceContext, localDictEntry: localMeaning != null ? {'meaning': localMeaning} : null);
        _currentAnalysis = result;
        notifyListeners();
      } catch (_) {}
    }

    final ipaString = await ipaFuture;
    if (ipaString != null && _currentAnalysis != null) {
      _currentAnalysis = _currentAnalysis!.withIpa(ipaString);
      notifyListeners();
    }

    _facadeState = AiFacadeState.idle;
    notifyListeners();
  }

  Future<bool> importModelFromUser() async {
    // Delegate to AiModelLoader if available
    try {
      final loader = AiModelLoader();
      final result = await loader.importModelFromUser();
      if (result.success && result.modelPath != null) {
        return await initialize(modelPath: result.modelPath!);
      }
      return false;
    } catch (e) {
      debugPrint('[AiServiceFacade] importModelFromUser error: $e');
      return false;
    }
  }

  ErrorLogEntry reportError({required String reason}) {
    final log = AiErrorHandler.createErrorLog(
      inputText: _currentAnalysis?.inputText ?? '',
      rawAiOutput: '',
      issues: [reason],
    );
    debugPrint('[AiFacade] Error reported: $reason');
    return log;
  }

  // ── Cache ─────────────────────────────────────────────────

  void clearCache() {
    _cache.clear();
    debugPrint('[AiServiceFacade] Cache cleared');
  }

  void invalidateCacheFor(String word) {
    _cache.remove('word_${word.toLowerCase().trim()}');
  }

  // ── Dispose ───────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _engine?.dispose();
    _cache.clear();
    _instance = null;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}

enum AiFacadeState { idle, loading, error, noModel }
