import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/ai_engine.dart';
import '../engine/ai_engine_gemma.dart';
import '../error/ai_error_handler.dart';
import '../loader/ai_model_loader.dart';

/// Orchestrator chính - tích hợp với Provider pattern của in2up
/// Quản lý 3 tầng Cold Start + CMU IPA lookup
class AiServiceFacade extends ChangeNotifier {
  final AiEngine _engine;
  final AiModelLoader _loader;

  // State
  AiAnalysis? _currentAnalysis;
  AiFacadeState _facadeState = AiFacadeState.idle;
  String? _lastError;
  ModelLoadResult? _modelStatus;

  // Retry tracking
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Conversation state. Kept in the facade so the UI can remain a thin client.
  static const String _chatHistoryKey = 'in2up_ai_chat_history_v1';
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
        ..addAll(decoded
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson));
      notifyListeners();
    } catch (e) {
      debugPrint('[AiFacade] Could not restore chat history: $e');
    }
  }

  Future<void> _persistChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _chatHistoryKey,
        jsonEncode(_chatMessages.map((message) => message.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[AiFacade] Could not persist chat history: $e');
    }
  }
  bool get isChatLoading => _facadeState == AiFacadeState.chatting;

  Future<void> clearChat() async {
    _chatMessages.clear();
    await _persistChatHistory();
    notifyListeners();
  }

  /// Send one conversational turn. The history is included as context on each
  /// request, making the API ready for a real streaming engine later.
  Future<void> sendMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty || isChatLoading) return;

    _chatMessages.add(ChatMessage(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      text: text,
    ));
    await _persistChatHistory();
    _setFacadeState(AiFacadeState.chatting);
    _lastError = null;
    notifyListeners();

    final history = _chatMessages
        .map((m) => '${m.role.name.toUpperCase()}: ${m.text}')
        .join('\\n');

    try {
      if (_engine.state != AiEngineState.ready) {
        _chatMessages.add(ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          text: 'AI local chưa sẵn sàng. Bạn có thể import model .gguf trong phần cài đặt AI.',
          isError: true,
        ));
      } else {
        final result = await _engine.analyze(
          text: text,
          type: AiAnalysisType.conversation,
          context: history,
          temperature: 0.2,
        ).first;
        _chatMessages.add(ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          text: result.success && result.summary.isNotEmpty
              ? result.summary
              : 'Mình chưa tạo được câu trả lời cho tin nhắn này.',
          isError: !result.success,
        ));
      }
    } catch (e) {
      _lastError = e.toString();
      _chatMessages.add(ChatMessage(
        id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.assistant,
        text: 'Có lỗi khi xử lý. Vui lòng thử lại.',
        isError: true,
      ));
    } finally {
      await _persistChatHistory();
      _setFacadeState(AiFacadeState.idle);
      notifyListeners();
    }
  }

  AiServiceFacade({
    AiEngine? engine,
    AiModelLoader? loader,
  })  : _engine = engine ?? AiEngineGemma(),
        _loader = loader ?? AiModelLoader();

  // ── Getters ─────────────────────────────────────────────

  AiAnalysis? get currentAnalysis => _currentAnalysis;
  AiFacadeState get facadeState => _facadeState;
  String? get lastError => _lastError;
  bool get isLoading => _facadeState == AiFacadeState.loading;
  bool get hasModel => _loader.hasModel;
  ModelLoadResult? get modelStatus => _modelStatus;
  String get modelSourceLabel => _loader.modelSourceLabel;

  // ── Khởi tạo ────────────────────────────────────────────

  /// Gọi khi app start - không block UI
  Future<void> initializeAsync() async {
    await _restoreChatHistory();
    _setFacadeState(AiFacadeState.loading);

    // Tìm model theo 3 tầng A → B → C
    final result = await _loader.findOrLoadModel(
      allowDownload: false, // Mặc định không auto-download
    );

    _modelStatus = result;

    if (result.success && result.modelPath != null) {
      final engineReady = await _engine.initialize(
        modelPath: result.modelPath!,
      );

      if (engineReady) {
        _setFacadeState(AiFacadeState.idle);
        // Warm-up ngầm sau 2 giây (không block UI)
        Future.delayed(const Duration(seconds: 2), () {
          _engine.warmUp().ignore();
        });
      } else {
        _setError('Không thể khởi động AI engine');
      }
    } else {
      // Không có model → vẫn hoạt động với Mock engine
      // Tầng 1 và 2 vẫn chạy bình thường
      _setFacadeState(AiFacadeState.noModel);
      _lastError = result.errorMessage;
    }

    notifyListeners();
  }

  /// User chủ động import model file
  Future<bool> importModelFromUser() async {
    _setFacadeState(AiFacadeState.loading);
    notifyListeners();

    final result = await _loader.importModelFromUser();
    _modelStatus = result;

    if (result.success && result.modelPath != null) {
      final engineReady = await _engine.initialize(
        modelPath: result.modelPath!,
      );

      if (engineReady) {
        _setFacadeState(AiFacadeState.idle);
        notifyListeners();
        return true;
      }
    }

    _setError(result.errorMessage ?? 'Import thất bại');
    notifyListeners();
    return false;
  }

  // ── Phân tích từ - 3 tầng Cold Start ────────────────────

  /// Phân tích từ đơn
  /// [localDictLookup]: inject từ OfflineDictionary (Tầng 1, 0ms)
  /// [ipaLookup]: inject từ CMUDictionaryService (Tầng 2, ~50ms)
  Future<void> analyzeWord({
    required String word,
    String? sentenceContext,

    /// Tầng 1: OfflineDictionary.lookup
    required String? Function(String) localDictLookup,

    /// Tầng 2: CMUDictionaryService.getIPA - trả về List<String> phonemes
    /// Facade tự join thành IPA string
    required List<String>? Function(String) ipaPhoneLookup,
  }) async {
    _retryCount = 0;
    _setFacadeState(AiFacadeState.loading);
    _currentAnalysis = null;
    notifyListeners();

    // ── Tầng 1: Local Dict (0ms) ──────────────────────────
    final localMeaning = localDictLookup(word);
    if (localMeaning != null && localMeaning.isNotEmpty) {
      _currentAnalysis = AiAnalysis.fromLocalDict(
        inputText: word,
        meaning: localMeaning,
      );
      notifyListeners(); // UI update ngay lập tức
    }

    // ── Tầng 2: CMU IPA (~50ms, async) ───────────────────
    // Chạy song song với Tầng 3
    final ipaFuture = _lookupIpaAsync(word, ipaPhoneLookup);

    // ── Tầng 3: Gemma Isolate (3-8s) ─────────────────────
    if (_engine.state == AiEngineState.ready) {
      await _analyzeWithRetry(
        word: word,
        type: AiAnalysisType.wordLookup,
        context: sentenceContext,
      );
    }
    // Nếu không có engine → giữ kết quả Tầng 1/2

    // Chờ IPA hoàn thành và merge vào kết quả
    final ipaString = await ipaFuture;
    if (ipaString != null && _currentAnalysis != null) {
      _currentAnalysis = _currentAnalysis!.withIpa(ipaString);
      notifyListeners();
    }

    _setFacadeState(AiFacadeState.idle);
    notifyListeners();
  }

  /// Phân tích câu (ngữ pháp 5 đầu ngón tay)
  Future<void> analyzeSentence({required String sentence}) async {
    _retryCount = 0;
    _setFacadeState(AiFacadeState.loading);
    notifyListeners();

    if (_engine.state == AiEngineState.ready) {
      await _analyzeWithRetry(
        word: sentence,
        type: AiAnalysisType.sentenceParse,
      );
    } else {
      _setError('AI engine chưa sẵn sàng. Vui lòng import model.');
    }

    _setFacadeState(AiFacadeState.idle);
    notifyListeners();
  }

  // ── Retry Logic ──────────────────────────────────────────

  Future<void> _analyzeWithRetry({
    required String word,
    required AiAnalysisType type,
    String? context,
  }) async {
    while (_retryCount < _maxRetries) {
      final temperature = AiErrorHandler.getRetryTemperature(_retryCount + 1);

      try {
        await for (final analysis in _engine.analyze(
          text: word,
          type: type,
          context: context,
          temperature: temperature,
        )) {
          final check = AiErrorHandler.checkForHallucination(analysis);

          if (check.isClean) {
            _currentAnalysis = analysis;
            notifyListeners();
            return; // Thành công
          } else {
            debugPrint(
              '[AiFacade] Hallucination attempt $_retryCount: ${check.issues}',
            );
            _retryCount++;
            // Retry với temperature thấp hơn
            break;
          }
        }
      } catch (e) {
        debugPrint('[AiFacade] Analyze error: $e');
        _retryCount++;
      }
    }

    // Hết retry → giữ kết quả Tầng 1/2 (không overwrite bằng kết quả xấu)
    debugPrint('[AiFacade] Max retries reached, keeping Tier 1/2 result');
  }

  // ── IPA Lookup ───────────────────────────────────────────

  /// Convert List<String> phonemes từ CMU → IPA string chuẩn
  /// Input:  ['b', 'r', 'eɪ', 'k', 'θ', 'r', 'u']
  /// Output: "/breɪkθruː/"
  Future<String?> _lookupIpaAsync(
    String word,
    List<String>? Function(String) ipaPhoneLookup,
  ) async {
    // Chạy trong microtask để không block
    return Future.microtask(() {
      final phonemes = ipaPhoneLookup(word);
      if (phonemes == null || phonemes.isEmpty) return null;

      // Join phonemes và wrap trong //
      final ipaBody = phonemes.join('');
      return '/$ipaBody/';
    });
  }

  // ── User Feedback ────────────────────────────────────────

  /// User báo kết quả AI sai
  /// Lưu error log để fine-tune prompt sau này
  /// ErrorLogEntry được xử lý bởi in2up_storage, không phải ở đây
  ErrorLogEntry reportError({required String reason}) {
    final log = AiErrorHandler.createErrorLog(
      inputText: _currentAnalysis?.inputText ?? '',
      rawAiOutput: '', // TODO: lưu raw output trong AiAnalysis
      issues: [reason],
    );
    debugPrint('[AiFacade] Error reported: $reason');
    // Caller (app layer) chịu trách nhiệm lưu log vào storage
    return log;
  }

  // ── Helpers ──────────────────────────────────────────────

  void clearAnalysis() {
    _currentAnalysis = null;
    _setFacadeState(AiFacadeState.idle);
    notifyListeners();
  }

  void _setFacadeState(AiFacadeState state) {
    _facadeState = state;
  }

  void _setError(String? message) {
    _lastError = message;
    _facadeState = AiFacadeState.error;
  }

  @override
  Future<void> dispose() async {
    await _engine.dispose();
    super.dispose();
  }
}

enum AiFacadeState {
  idle,
  loading,
  error,
  noModel, // Có thể chạy nhưng thiếu Gemma
  chatting,
}
