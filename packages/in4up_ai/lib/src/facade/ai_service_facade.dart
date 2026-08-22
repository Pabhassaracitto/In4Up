// packages/vipsound_ai/lib/src/facade/ai_service_facade.dart
// v11.0-final + chat integration — merged essence from branch 27 (sherpa) + 41 (9-error fix) + chat branches 01a01580/01a019bb
// Fix: analysisType param, fromGemmaJson, fromLocalDict, withIpa, sentenceParse, chat, clearAnalysis, modelSourceLabel
// Principle: đãi cát tìm đồng — chỉ lấy tinh túy, bỏ dư thừa

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/ai_engine.dart';
import '../engine/ai_engine_gemma.dart';
import '../engine/ai_engine_mock.dart';
import '../error/ai_error_handler.dart';
import '../loader/ai_model_loader.dart';
import '../models/ai_analysis.dart';
import '../models/chat_message.dart';

/// Facade duy nhất cho toàn bộ AI module — UI và Provider chỉ tương tác qua class này
/// Kết hợp: Word Lookup + Sentence Parse + Summarize + TermExtract + PAO + Chat
class AiServiceFacade extends ChangeNotifier {
  static AiServiceFacade? _instance;
  factory AiServiceFacade() => _instance ??= AiServiceFacade._internal();
  AiServiceFacade._internal();

  AiEngine? _engine;
  bool _initialized = false;
  bool _disposed = false;
  bool _useMock = false;

  final _cache = <String, AiAnalysis>{};

  // ── State for legacy UI (word_analysis_sheet) + WriteStudio ──
  AiAnalysis? _currentAnalysis;
  AiAnalysis? get currentAnalysis => _currentAnalysis;
  AiFacadeState _facadeState = AiFacadeState.idle;
  AiFacadeState get facadeState => _facadeState;
  bool get isLoading => _facadeState == AiFacadeState.loading;
  bool get isChatLoading => _facadeState == AiFacadeState.chatting;
  /// True only when a real .gguf is loaded — not mock/startup fallback.
  bool get hasModel =>
      !_useMock && _loader.hasModel && isReady;
  String? _lastError;
  String? get lastError => _lastError;
  bool get isReady => _initialized && (_engine?.state == AiEngineState.ready);
  bool get useMock => _useMock;

  // Model loader for source label
  final AiModelLoader _loader = AiModelLoader();
  String get modelSourceLabel => _loader.modelSourceLabel;
  ModelLoadResult? _modelStatus;
  ModelLoadResult? get modelStatus => _modelStatus;

  // Retry tracking
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // ── Chat state (from branches 01a01580/01a019bb) ──
  static const String _chatHistoryKey = 'in4up_ai_chat_history_v1';
  final List<ChatMessage> _chatMessages = <ChatMessage>[];
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  bool _chatHistoryLoaded = false;

  Future<void> _restoreChatHistory() async {
    if (_chatHistoryLoaded) return;
    _chatHistoryLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatHistoryKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      _chatMessages
        ..clear()
        ..addAll(decoded.whereType<Map>().map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item))));
      notifyListeners();
    } catch (e) {
      debugPrint('[AiFacade] Could not restore chat history: $e');
    }
  }

  Future<void> _persistChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatHistoryKey, jsonEncode(_chatMessages.map((m) => m.toJson()).toList()));
    } catch (e) {
      debugPrint('[AiFacade] Could not persist chat history: $e');
    }
  }

  Future<void> clearChat() async {
    _chatMessages.clear();
    await _persistChatHistory();
    notifyListeners();
  }

  Future<void> sendMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty || isChatLoading) return;

    _chatMessages.add(ChatMessage(id: 'user-${DateTime.now().microsecondsSinceEpoch}', role: ChatRole.user, text: text));
    await _persistChatHistory();
    _setFacadeState(AiFacadeState.chatting);
    _lastError = null;
    notifyListeners();

    final history = _chatMessages.map((m) => '${m.role.name.toUpperCase()}: ${m.text}').join('\n');

    try {
      if (_engine == null || _engine!.state != AiEngineState.ready) {
        _chatMessages.add(ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          text: 'AI local chưa sẵn sàng. Bạn có thể import model .gguf trong phần cài đặt AI.',
          isError: true,
        ));
      } else {
        final result = await _engine!.analyze(text: text, type: AiAnalysisType.conversation, context: history, temperature: 0.2).first;
        _chatMessages.add(ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          text: result.success && result.summary.isNotEmpty ? result.summary : 'Mình chưa tạo được câu trả lời cho tin nhắn này.',
          isError: !result.success,
        ));
      }
    } catch (e) {
      _lastError = e.toString();
      _chatMessages.add(ChatMessage(id: 'assistant-${DateTime.now().microsecondsSinceEpoch}', role: ChatRole.assistant, text: 'Có lỗi khi xử lý. Vui lòng thử lại.', isError: true));
    } finally {
      await _persistChatHistory();
      _setFacadeState(AiFacadeState.idle);
      notifyListeners();
    }
  }

  // ── Init ──

  Future<void> initializeAsync() async {
    if (_initialized) return;
    await _restoreChatHistory();
    try {
      final result = await _loader.findOrLoadModel(allowDownload: false);
      _modelStatus = result;
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
    bool forceReload = false,
  }) async {
    if (_initialized && !forceReload) return true;
    _useMock = useMock;

    await _engine?.dispose();
    _engine = null;

    if (useMock || modelPath.trim().isEmpty) {
      _engine = AiEngineMock();
      await _engine!.initialize(modelPath: modelPath);
      _useMock = true;
      _initialized = true;
      debugPrint('[AiServiceFacade] Mock mode');
      if (!_disposed) notifyListeners();
      return true;
    }

    _engine = AiEngineGemma();
    final ok = await _engine!.initialize(modelPath: modelPath);
    _initialized = ok;
    _useMock = !ok;
    if (!ok) {
      _engine = AiEngineMock();
      await _engine!.initialize(modelPath: '');
      _initialized = true;
      debugPrint('[AiServiceFacade] Gemma init failed → mock fallback');
    }
    if (!_disposed) notifyListeners();
    return ok;
  }

  // ── Word Lookup (final 9-error fix) ──

  Future<AiAnalysis> lookupWord(String word, {String? sentenceContext, Map<String, dynamic>? localDictEntry}) async {
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
        result = await _engine!.analyze(text: word, type: AiAnalysisType.wordLookup, context: sentenceContext).first.timeout(const Duration(seconds: 30));
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

  AiAnalysis buildFromLocalDict(String word, Map<String, dynamic>? dictEntry) {
    if (dictEntry == null) {
      return AiAnalysis.fallback(word, errorReason: 'No local dict entry and engine not ready');
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
      wordDetail: WordDetail(word: word, meaning: meaning, phonetic: phonetic, memoryHook: example),
    );
  }

  AiAnalysis enrichWithLocalDict(AiAnalysis result, Map<String, dynamic> dictEntry) {
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

  // ── Sentence Analysis — named param to match WriteStudio usage (issue 3) ──

  Future<void> analyzeSentence({required String sentence}) async {
    _retryCount = 0;
    _setFacadeState(AiFacadeState.loading);
    _currentAnalysis = null;
    notifyListeners();

    if (_engine != null && _engine!.state == AiEngineState.ready) {
      try {
        await _analyzeWithRetry(word: sentence, type: AiAnalysisType.sentenceParse);
      } catch (e) {
        _setError('Lỗi phân tích câu: $e');
      }
    } else {
      _currentAnalysis = AiAnalysis.fallback(sentence, errorReason: 'Engine not ready', analysisType: AiAnalysisType.sentenceParse);
      _setError('AI engine chưa sẵn sàng. Vui lòng import model.');
    }

    _setFacadeState(AiFacadeState.idle);
    notifyListeners();
  }

  // Compatibility wrapper returning AiAnalysis for callers expecting result
  Future<AiAnalysis> analyzeSentenceWithResult(String sentence) async {
    await analyzeSentence(sentence: sentence);
    return _currentAnalysis ?? AiAnalysis.fallback(sentence, errorReason: 'No analysis', analysisType: AiAnalysisType.sentenceParse);
  }

  // ── Summarize ──

  Future<AiAnalysis> summarize(String transcript, {String? speakerContext}) async {
    if (!isReady) {
      return AiAnalysis.fallback(transcript, errorReason: 'Engine not ready', analysisType: AiAnalysisType.summarize);
    }
    try {
      return await _engine!.analyze(text: transcript, type: AiAnalysisType.summarize, context: speakerContext).first.timeout(const Duration(seconds: 60));
    } catch (e) {
      return AiAnalysis.fallback(transcript, errorReason: e.toString(), analysisType: AiAnalysisType.summarize);
    }
  }

  // ── Term Extract ──

  Future<AiAnalysis> extractTerms(String transcript) async {
    if (!isReady) {
      return AiAnalysis.fallback(transcript, errorReason: 'Engine not ready', analysisType: AiAnalysisType.termExtract);
    }
    try {
      return await _engine!.analyze(text: transcript, type: AiAnalysisType.termExtract).first.timeout(const Duration(seconds: 45));
    } catch (e) {
      return AiAnalysis.fallback(transcript, errorReason: e.toString(), analysisType: AiAnalysisType.termExtract);
    }
  }

  // ── PAO Generation ──

  Future<AiAnalysis> generatePao(String word) async {
    if (!isReady) {
      return AiAnalysis.fallback(word, errorReason: 'Engine not ready', analysisType: AiAnalysisType.paoGeneration);
    }
    try {
      return await _engine!.analyze(text: word, type: AiAnalysisType.paoGeneration).first.timeout(const Duration(seconds: 20));
    } catch (e) {
      return AiAnalysis.fallback(word, errorReason: e.toString(), analysisType: AiAnalysisType.paoGeneration);
    }
  }

  // ── Legacy 3-tier API for word_analysis_sheet ──

  Future<void> analyzeWord({required String word, String? sentenceContext, required String? Function(String) localDictLookup, required List<String>? Function(String) ipaPhoneLookup}) async {
    _retryCount = 0;
    _setFacadeState(AiFacadeState.loading);
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

    _setFacadeState(AiFacadeState.idle);
    notifyListeners();
  }

  // ── Retry Logic ──

  Future<void> _analyzeWithRetry({required String word, required AiAnalysisType type, String? context}) async {
    while (_retryCount < _maxRetries) {
      final temperature = AiErrorHandler.getRetryTemperature(_retryCount + 1);
      try {
        await for (final analysis in _engine!.analyze(text: word, type: type, context: context, temperature: temperature)) {
          final check = AiErrorHandler.checkForHallucination(analysis);
          if (check.isClean) {
            _currentAnalysis = analysis;
            notifyListeners();
            return;
          } else {
            debugPrint('[AiFacade] Hallucination attempt $_retryCount: ${check.issues}');
            _retryCount++;
            break;
          }
        }
      } catch (e) {
        debugPrint('[AiFacade] Analyze error: $e');
        _retryCount++;
      }
    }
    debugPrint('[AiFacade] Max retries reached, keeping Tier 1/2 result');
  }

  Future<bool> importModelFromUser() async {
    try {
      final result = await _loader.importModelFromUser();
      _modelStatus = result;
      if (result.success && result.modelPath != null) {
        final ok = await initialize(
          modelPath: result.modelPath!,
          useMock: false,
          forceReload: true,
        );
        if (!_disposed) notifyListeners();
        return ok;
      }
      return false;
    } catch (e) {
      debugPrint('[AiServiceFacade] importModelFromUser error: $e');
      return false;
    }
  }

  ErrorLogEntry reportError({required String reason}) {
    final log = AiErrorHandler.createErrorLog(inputText: _currentAnalysis?.inputText ?? '', rawAiOutput: '', issues: [reason]);
    debugPrint('[AiFacade] Error reported: $reason');
    return log;
  }

  // ── Cache + clearAnalysis ──

  void clearAnalysis() {
    _currentAnalysis = null;
    _setFacadeState(AiFacadeState.idle);
    notifyListeners();
  }

  void clearCache() {
    _cache.clear();
    debugPrint('[AiServiceFacade] Cache cleared');
  }

  void invalidateCacheFor(String word) {
    _cache.remove('word_${word.toLowerCase().trim()}');
  }

  void _setFacadeState(AiFacadeState state) {
    _facadeState = state;
  }

  void _setError(String? message) {
    _lastError = message;
    _facadeState = AiFacadeState.error;
  }

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

enum AiFacadeState { idle, loading, error, noModel, chatting }
