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

/// Giai đoạn import/tải model — cho UI hiển thị progress + trạng thái rõ ràng.
enum AiImportStage {
  idle, // chưa làm gì
  copying, // đang copy file .gguf đã chọn vào app directory
  downloading, // đang tải model từ URL
  loading, // native llama.cpp đang nạp model (1–2 phút với file lớn)
  ready, // model đã nạp, sẵn sàng
  failed, // lỗi (xem importError)
}

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
  /// (Merge 2026-08-22: giữ bản 01a0251e — chặt hơn bản `_initialized && !_useMock`
  /// của 01a02601, tương thích `_loader.hasModel` + `isReady` đã có trong file.
  /// 2026-08-23: thêm `_modelLoaded` — isolate báo ready trước khi native model
  /// nạp xong (ready-first), nên "isReady" đơn thuần chưa đủ.)
  bool get hasModel =>
      !_useMock && _loader.hasModel && isReady && _modelLoaded;
  String? _lastError;
  String? get lastError => _lastError;
  /// "Ready" = engine đã khởi động và không hỏng — cả `ready` lẫn
  /// `processing`. FIX AI-CHAT-01 (chủ báo 2026-08-29): lúc đang sinh câu
  /// trả lời, engine ở trạng thái `processing` 30s–2 phút; bản cũ `isReady`
  /// chỉ nhận `ready` ⇒ `hasModel` bật FALSE giữa chừng generate ⇒ banner
  /// chat nhảy sang "Chưa nạp model AI — import file .gguf (Gemma ~1.5GB)"
  /// ngay sau khi bấm gửi (dù model ĐÃ nạp thật — banner xanh là đúng).
  bool get isReady => _initialized &&
      (_engine?.state == AiEngineState.ready ||
          _engine?.state == AiEngineState.processing);
  bool get useMock => _useMock;

  // Model loader for source label
  final AiModelLoader _loader = AiModelLoader();
  String get modelSourceLabel => _loader.modelSourceLabel;
  ModelLoadResult? _modelStatus;
  ModelLoadResult? get modelStatus => _modelStatus;

  // ── Trạng thái import/tải model — cho chat screen + trung tâm model ──
  AiImportStage _importStage = AiImportStage.idle;
  double _importProgress = 0;
  String? _importError;
  bool _modelLoaded = false;

  AiImportStage get importStage => _importStage;
  double get importProgress => _importProgress;
  String? get importError => _importError;

  /// True trong lúc import/tải model (UI vô hiệu nút + hiện progress).
  bool get isImportActive =>
      _importStage == AiImportStage.copying ||
      _importStage == AiImportStage.downloading ||
      _importStage == AiImportStage.loading;

  /// True khi engine thật đã khởi động nhưng model native chưa load xong
  /// (kể cả app tự nạp model lúc khởi động) — UI hiện "đang nạp model".
  bool get isModelLoading =>
      isImportActive || (_initialized && !_useMock && !_modelLoaded);

  String? get modelFileName => _loader.currentModelName;
  int? get modelSizeBytes => _loader.currentModelSizeBytes;

  void _setImportStage(
    AiImportStage stage, {
    double? progress,
    String? error,
    bool notify = true,
  }) {
    _importStage = stage;
    if (progress != null) _importProgress = progress;
    if (stage == AiImportStage.failed) {
      _importError = error ?? _importError;
    } else {
      _importError = null;
    }
    if (notify && !_disposed) notifyListeners();
  }

  /// Chờ native model load xong trong isolate (1–2 phút với file lớn).
  Future<void> _awaitModelReady(
      {Duration timeout = const Duration(minutes: 5)}) async {
    final engine = _engine;
    if (engine == null || _useMock) return;
    await engine.modelReady.timeout(timeout);
    _modelLoaded = true;
    if (!_disposed) notifyListeners();
  }

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

    // FIX AI-CHAT-01: chỉ gửi 10 tin gần nhất làm context — context native
    // cố định 2048 tokens (in4up_ai_create), prompt dài hơn khiến
    // llama_decode fail và model trả về RỖNG (hội thoại càng dài càng dễ
    // dính, kể cả khi model chạy hoàn hảo).
    final history = _chatMessages
        .take(10)
        .map((m) => '${m.role.name.toUpperCase()}: ${m.text}')
        .join('\n');

    try {
      final engineState = _engine?.state;
      if (_engine == null ||
          (engineState != AiEngineState.ready &&
              engineState != AiEngineState.processing)) {
        _chatMessages.add(ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          text: 'AI local chưa sẵn sàng. Bạn có thể import model .gguf trong phần cài đặt AI.',
          isError: true,
        ));
      } else {
        // FIX AI-CHAT-01: engine đang bận sinh câu trả lời cho request khác
        // (tab Viết/Nghe) — isolate xử lý tuần tự, chờ nó rảnh (tối đa ~60s)
        // thay vì báo sai "chưa sẵn sàng".
        var waitedSec = 0;
        while (_engine?.state == AiEngineState.processing && waitedSec < 60) {
          await Future<void>.delayed(const Duration(seconds: 1));
          waitedSec += 1;
        }
        // (AI-CHAT-01 v2) Request trước hit timeout nhưng native vẫn đang
        // sinh tiếp (không cancel được FFI) — đừng chen request thứ 2,
        // báo rõ để user thử lại sau vài giây.
        if (_engine?.state == AiEngineState.processing) {
          _chatMessages.add(ChatMessage(
            id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
            role: ChatRole.assistant,
            text: 'AI vẫn đang xử lý tin nhắn trước đó — vui lòng thử lại sau vài giây.',
            isError: true,
          ));
          return;
        }
        // Model native còn đang nạp (app tự nạp lúc khởi động) thì chờ xong
        // trước — message của user không bị trả lời bằng mock "chui".
        if (!_useMock && !_modelLoaded) {
          try {
            await _awaitModelReady();
          } catch (_) {
            // native load fail → mock fallback bên dưới (kèm disclaimer).
          }
        }
        // FIX AI-CHAT-01: chat KHÔNG có timeout (các API khác có 30–60s) —
        // native generate treo ⇒ nút gửi xoay vòng VÔ HẠN.
        // (v2 — chủ báo timeout trên build 102978f: tablet ~1.5–2 token/s,
        // 512 tokens > 3 phút) ⇒ maxTokens 320 (đủ schema thông thường; JSON
        // bị cắt thì _rescueSummary cứu summary) + trần 4 phút an toàn.
        final result = await _engine!.analyze(text: text, type: AiAnalysisType.conversation, context: history, temperature: 0.2, maxTokens: 320).first.timeout(const Duration(minutes: 4));
        final answer = result.success && result.summary.isNotEmpty
            ? result.summary
            : 'Mình chưa tạo được câu trả lời cho tin nhắn này.';
        final isRealModel = _modelLoaded && !_useMock;
        _chatMessages.add(ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          text: isRealModel
              ? answer
              : '⚠️ Chưa nạp model AI — đây là trả lời MẪU (mock), không phải câu trả lời thật.\n\nImport file .gguf (nút model trên cùng, hoặc Cài đặt → Quản lý Model AI) để dùng AI thật.\n\n$answer',
          isError: !result.success,
        ));
      }
    } on TimeoutException {
      // FIX AI-CHAT-01: generate quá 4 phút (máy yếu / native treo) — trả lời
      // rõ + về trạng thái bình thường; nút gửi không xoay vòng vô hạn.
      // (Isolate vẫn tự thoát sau watchdog 5 phút trong AiEngineGemma.)
      _lastError = 'Chat timeout sau 4 phút';
      _chatMessages.add(ChatMessage(
        id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.assistant,
        text: 'AI xử lý quá lâu (model lớn trên máy yếu). Vui lòng thử lại sau vài giây.',
        isError: true,
      ));
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
        // Model native load trong nền (1–2 phút) — UI theo dõi qua
        // isModelLoading; khi xong notify để hiện "sẵn sàng".
        if (!_useMock && _engine != null) {
          _engine!.modelReady.then((_) {
            _modelLoaded = true;
            if (!_disposed) notifyListeners();
          }).catchError((Object _) {
            // Native không nạp được (thiếu lib/file hỏng) — vẫn mock,
            // UI hiện "chưa nạp" qua hasModel=false.
            if (!_disposed) notifyListeners();
          });
        }
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
    // Cho phép chuyển backend giữa phiên chạy (VD: app khởi động ở mock mode,
    // người dùng import .gguf ⇒ cần re-init sang AiEngineGemma thật).
    // forceReload (từ 01a0251e): ép init lại dù đã sẵn sàng cùng backend
    // (VD: đổi file .gguf giữa phiên).
    if (_initialized) {
      if (!forceReload && useMock == _useMock) return true;
      debugPrint(
          '[AiServiceFacade] (Re)initializing: ${_useMock ? "mock" : "real"} → ${useMock ? "mock" : "real"}');
      await _engine?.dispose();
      _engine = null;
      _initialized = false;
      _useMock = false;
    }
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
      // Busy (đang generate cho chat) ⇒ dùng từ điển local ngay — không
      // chen request vào (AI-CHAT-01: isReady giờ bao gồm processing).
      final engineBusy = _engine?.state == AiEngineState.processing;
      if (!isReady || engineBusy) {
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

    // Busy (AI-CHAT-01): không chen request — giữ kết quả local tier 1.
    if (isReady && _engine?.state != AiEngineState.processing) {
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

  /// Import model .gguf do người dùng chọn file.
  /// Báo tiến độ liên tục qua [importStage]/[importProgress]:
  /// copying (0–100%) → loading (native nạp model) → ready/failed.
  /// UI (chat screen / trung tâm model) chỉ cần lắng nghe ChangeNotifier.
  Future<bool> importModelFromUser() async {
    _modelLoaded = false;
    _setImportStage(AiImportStage.copying, progress: 0);
    try {
      final result = await _loader.importModelFromUser(
        onCopyProgress: (p) =>
            _setImportStage(AiImportStage.copying, progress: p, notify: false),
      );
      _modelStatus = result;
      if (result.success && result.modelPath != null) {
        return await _adoptModel(result.modelPath!);
      }
      _setImportStage(AiImportStage.failed,
          error: result.errorMessage ?? 'Import thất bại');
      return false;
    } catch (e) {
      debugPrint('[AiServiceFacade] importModelFromUser error: $e');
      _setImportStage(AiImportStage.failed, error: 'Lỗi import: $e');
      return false;
    }
  }

  /// Tải model từ URL (nút "Tải về" trong trung tâm model).
  /// Tiến độ: downloading (0–100%) → loading → ready/failed.
  Future<bool> downloadModel(String url) async {
    _modelLoaded = false;
    _setImportStage(AiImportStage.downloading, progress: 0);
    try {
      final result = await _loader.downloadModel(
        url: url,
        onProgress: (p) =>
            _setImportStage(AiImportStage.downloading, progress: p, notify: false),
      );
      _modelStatus = result;
      if (result.success && result.modelPath != null) {
        return await _adoptModel(result.modelPath!);
      }
      _setImportStage(AiImportStage.failed,
          error: result.errorMessage ?? 'Download thất bại');
      return false;
    } catch (e) {
      debugPrint('[AiServiceFacade] downloadModel error: $e');
      _setImportStage(AiImportStage.failed, error: 'Download thất bại: $e');
      return false;
    }
  }

  /// Xóa file model khỏi thiết bị + quay về mock (nút "Xóa").
  Future<void> removeModel() async {
    await _loader.removeModel();
    _modelStatus = null;
    _modelLoaded = false;
    await initialize(modelPath: '', useMock: true);
    _setImportStage(AiImportStage.idle);
  }

  /// Sau khi có file model hợp lệ (import/download): khởi động engine thật,
  /// chờ native llama.cpp nạp model xong, báo UI "sẵn sàng" hoặc lỗi rõ ràng.
  Future<bool> _adoptModel(String modelPath) async {
    _setImportStage(AiImportStage.loading);
    final ok = await initialize(
      modelPath: modelPath,
      useMock: false,
      forceReload: true,
    );
    if (!ok) {
      _setImportStage(
          AiImportStage.failed,
          error: 'Không khởi tạo được AI engine');
      return false;
    }
    try {
      await _awaitModelReady();
    } catch (e) {
      // Native không nạp được (thiếu lib trong build / file hỏng) →
      // quay về mock TRUNG THỰC (hasModel=false, UI báo rõ).
      await _engine?.dispose();
      _engine = AiEngineMock();
      await _engine!.initialize(modelPath: '');
      _useMock = true;
      _initialized = true;
      _modelLoaded = false;
      _setImportStage(AiImportStage.failed,
          error: e is StateError ? e.message : 'Model không load được: $e');
      return false;
    }
    _setImportStage(AiImportStage.ready);
    return true;
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
