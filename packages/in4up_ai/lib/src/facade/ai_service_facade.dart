// packages/vipsound_ai/lib/src/facade/ai_service_facade.dart
// v11.0-final + chat integration — merged essence from branch 27 (sherpa) + 41 (9-error fix) + chat branches 01a01580/01a019bb
// Fix: analysisType param, fromGemmaJson, fromLocalDict, withIpa, sentenceParse, chat, clearAnalysis, modelSourceLabel
// Principle: đãi cát tìm đồng — chỉ lấy tinh túy, bỏ dư thừa

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/chat_context_policy.dart';
import '../engine/ai_engine.dart';
import '../engine/ai_engine_gemma.dart';
import '../engine/ai_engine_mock.dart';
import '../engine/ai_engine_remote.dart';
import '../engine/ai_route_planner.dart';
import '../error/ai_error_handler.dart';
import '../loader/ai_model_loader.dart';
import '../models/ai_analysis.dart';
import '../models/chat_message.dart';
import '../provider/ai_provider_config.dart';
import '../provider/ai_provider_store.dart';
import '../provider/ai_sse.dart';

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

  // ── WP1 (API-002): engine remote + định tuyến theo AiRoutingPrefs (WP0) ──
  //
  // `_engine` vẫn là engine LOCAL (Gemma .gguf hoặc mock) — mọi hành vi cũ
  // giữ nguyên khi chưa cấu hình provider. Engine remote tạo LƯỚI theo
  // provider đang bật (key = id|baseUrl|model) và chỉ được dùng khi route
  // plan cho phép (offlineOnly ⇒ không bao giờ tạo ⇒ không request nào đi ra).
  AiEngineRemote? _remoteEngine;
  String? _remoteEngineKey;

  /// Token hủy của lượt chat remote đang stream (nút Dừng / đóng màn).
  AiChatCancelToken? _activeChatToken;

  /// Lỗi API gần nhất theo MÃ cấu trúc — UI branch theo `lastChatErrorCode`,
  /// không match chuỗi (mẫu HyMtErrorCode).
  AiChatException? _lastChatApiError;

  /// Usage của lượt chat remote gần nhất (từ chunk cuối nếu server trả) —
  /// hiển thị nhẹ đếm token/chi phí ước tính (luật BYOK).
  AiChatUsage? _lastChatUsage;
  String? _lastChatModelId;
  DateTime? _lastStreamNotify;

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

  /// Có FILE model trên thiết bị (bất kể engine đang nạp / vừa bị OOM thu hồi
  /// / đang khởi động lại). Banner chat dùng cờ này để KHÔNG bao giờ nói
  /// "Chưa nạp model AI — import file .gguf" khi thật ra model đã import
  /// (DoD AI-CHAT-01 #1: gửi tin không làm banner xanh nhảy thành "chưa nạp").
  bool get hasModelFile =>
      _loader.hasModel || (_modelStatus?.modelPath != null);
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

  // ── WP1 (API-002): route + trạng thái engine remote cho UI ──

  /// Lỗi API gần nhất (mã cấu trúc) — null khi lượt cuối không lỗi.
  AiChatException? get lastChatApiError => _lastChatApiError;

  /// Mã lỗi cấu trúc của lượt API gần nhất — UI branch theo mã này, không
  /// match chuỗi.
  AiChatErrorCode? get lastChatErrorCode => _lastChatApiError?.code;

  /// Usage lượt chat remote gần nhất (token prompt/completion) — hiển thị
  /// nhẹ trong chat (luật chi phí BYOK). Null khi không có usage.
  AiChatUsage? get lastChatUsage => _lastChatUsage;

  /// Model remote đã trả lời lượt gần nhất (vd `llama3.1:8b`).
  String? get lastChatModelId => _lastChatModelId;

  /// Có provider + model cho chat và mode ≠ offlineOnly (chưa kể model local).
  bool get isRemoteChatConfigured {
    final store = AiProviderStore.instance;
    if (!store.isLoaded) return false;
    return store.resolveProvider(AiRouteCapability.chat) != null;
  }

  /// Nhãn route remote cho banner chat ("Ollama nhà · llama3.1:8b"). Đọc từ
  /// engine đang có hoặc provider trong store (engine tạo lười — chưa request
  /// lần nào vẫn hiển thị đúng đích sẽ dùng).
  String get chatRouteLabel {
    final remote = _remoteEngine;
    if (remote != null) {
      final p = remote.providerLabel;
      final m = remote.modelId;
      return (p == null || p.isEmpty ? 'API' : p) +
          (m == null || m.isEmpty ? '' : ' · $m');
    }
    final store = AiProviderStore.instance;
    final provider =
        store.isLoaded ? store.resolveProvider(AiRouteCapability.chat) : null;
    if (provider == null) return 'API';
    final m = provider.chatModel;
    return (provider.label.isEmpty ? 'API' : provider.label) +
        (m == null || m.isEmpty ? '' : ' · $m');
  }

  /// Engine remote có đang là nơi xử lý lượt chat này không (streaming).
  bool get isRemoteChatActive =>
      _activeChatToken != null || _remoteEngine?.isBusy == true;

  /// Remote có đứng ĐẦU route chat không (onlineFirst, hoặc offlineFirst mà
  /// chưa có model local) — UI hiện nhãn "đang dùng API" khi true.
  bool get isRemoteChatPreferred => _chatRoutePlan().remoteFirst;

  /// Dừng sinh câu trả lời remote NGAY (đóng socket — token không chảy tiếp).
  /// Local Gemma generate bằng FFI blocking trong isolate nên không cancel
  /// giữa chừng được — lượt hiện tại vẫn chạy tới watchdog như trước (hàng
  /// đợi/epoch cũ giữ nguyên).
  void stopGenerating() {
    _activeChatToken?.cancel('user stopped');
  }

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

  // ── Hàng đợi chat (AI-CHAT-01 audit B3) ──
  //
  // Vì sao cần: isolate native xử lý TUẦN TỰ và `sendMessage` bản cũ `return`
  // ngay khi `isChatLoading` ⇒ tin thứ hai bị NUỐT (chat screen cũng chặn nút
  // gửi), còn nếu có request khác đang chạy thì engine trả "not ready" giả.
  // Hàng đợi này giữ mọi tin theo thứ tự, mỗi tin được await đúng lượt.
  final List<_PendingChat> _chatQueue = <_PendingChat>[];
  bool _chatDraining = false;

  /// Tăng mỗi lần `clearChat()`: item của "phiên chat cũ" tự bỏ (không trả lời
  /// vào lịch sử vừa bị xoá).
  int _chatEpoch = 0;

  /// Số tin đang chờ (chưa tới lượt xử lý) — UI có thể hiện "đang xếp hàng".
  int get chatQueueLength => _chatQueue.length;

  /// Timeout của MỘT lượt chat. 3 phút là trần an toàn cho máy yếu (Gemma-2B
  /// Q4 trên tablet mất 30s–2 phút cho một câu trả lời); hết hạn ⇒ báo lỗi rõ
  /// + thử lại được, KHÔNG xoay vòng vô hạn.
  Duration chatRequestTimeout = const Duration(minutes: 3);

  /// Chính sách context chat (tin mới nhất + ngân sách ký tự + maxTokens).
  static const ChatContextPolicy _chatContext = ChatContextPolicy.defaults;

  /// Trần token cho chat (schema JSON chat cần > 256; context native 2048).
  static const int _chatMaxTokens = 512;

  /// Xấp xỉ phần prompt cố định (SYSTEM/TYPE/OUTPUT SCHEMA) — dùng để tính
  /// chỗ trống còn lại cho phần sinh, không cần chính xác tuyệt đối.
  static const int _chatPromptOverheadChars = 260;

  // ── "Sức khoẻ" engine thật (AI-CHAT-01 audit B3) ──
  // Lý do engine không dùng được (native treo / isolate bị OOM thu hồi /
  // khởi động lại thất bại). UI hiện banner ĐỎ + "Thử lại" (khởi động lại
  // engine, KHÔNG mở file picker) — khác với `importError` (lỗi import/tải).
  String? _engineError;
  String? get engineError => _engineError;

  /// Lần khởi động lại engine đang chạy (chống gọi trùng từ nhiều nơi:
  /// chat timeout + banner "Thử lại" + switch tab).
  Future<bool>? _restartInFlight;

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
    _chatEpoch++;
    for (final item in _chatQueue) {
      if (!item.done.isCompleted) item.done.complete();
    }
    _chatQueue.clear();
    _chatMessages.clear();
    await _persistChatHistory();
    notifyListeners();
  }

  void _addAssistantMessage(String text, {bool isError = false}) {
    _chatMessages.add(ChatMessage(
      id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.assistant,
      text: text,
      isError: isError,
    ));
  }

  /// Gửi một tin nhắn chat.
  ///
  /// Tin thứ hai gửi trong lúc tin thứ nhất đang generate KHÔNG bị bỏ: nó vào
  /// hàng đợi (`chatQueueLength`) và tự chạy sau khi tin trước xong — isolate
  /// native vốn xử lý tuần tự nên đây chính là hành vi đúng (DoD AI-CHAT-01 #3:
  /// "hai tin liên tiếp được queue đúng, không trả 'engine not ready' giả").
  Future<void> sendMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;

    final item = _PendingChat(
      message: ChatMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.user,
        text: text,
      ),
      epoch: _chatEpoch,
    );
    _chatMessages.add(item.message);
    await _persistChatHistory();
    if (!_disposed) notifyListeners();

    _chatQueue.add(item);
    if (!_chatDraining) unawaited(_drainChatQueue());
    return item.done.future;
  }

  Future<void> _drainChatQueue() async {
    if (_chatDraining) return;
    _chatDraining = true;
    try {
      while (_chatQueue.isNotEmpty) {
        final item = _chatQueue.removeAt(0);
        if (item.epoch != _chatEpoch) {
          // Chat đã bị xoá trong lúc tin này chờ tới lượt.
          if (!item.done.isCompleted) item.done.complete();
          continue;
        }
        _setFacadeState(AiFacadeState.chatting);
        _lastError = null;
        if (!_disposed) notifyListeners();
        try {
          await _processChat(item);
        } catch (e) {
          debugPrint('[AiServiceFacade] chat worker error: $e');
          _addAssistantMessage('Có lỗi khi xử lý. Vui lòng thử lại.', isError: true);
        } finally {
          await _persistChatHistory();
          _setFacadeState(AiFacadeState.idle);
          if (!_disposed) notifyListeners();
          if (!item.done.isCompleted) item.done.complete();
        }
      }
    } finally {
      _chatDraining = false;
      _setFacadeState(AiFacadeState.idle);
      if (!_disposed) notifyListeners();
    }
  }

  /// Xử lý MỘT tin trong hàng đợi (bubble user đã có trong lịch sử).
  ///
  /// WP1 (API-002): chọn engine theo `AiRoutingPrefs` (WP0):
  /// * remote đứng đầu route (onlineFirst, hoặc offlineFirst mà chưa có
  ///   model local) ⇒ streaming từng token qua API, token hiện dần trong UI.
  /// * Remote lỗi mà chưa thu token nào ⇒ tự fallback engine local (Gemma
  ///   nếu có model → mock kèm disclaimer như cũ) — không đổi signature.
  /// * Local lỗi (timeout/engine chết) ⇒ thử remote như stop cuối nếu route
  ///   có (fallback 2 chiều theo ADR-0007).
  Future<void> _processChat(_PendingChat item) async {
    final plan = _chatRoutePlan();

    if (plan.remoteFirst) {
      if (await _processChatRemote(item)) return;
    }

    final failure = await _processChatLocal(item);
    if (failure == null) return; // đã có câu trả lời (hoặc tin bị bỏ).

    if (plan.usesRemote && !plan.remoteFirst) {
      // offlineFirst: local (thật) vừa lỗi ⇒ thử API trước khi báo lỗi.
      if (await _processChatRemote(item)) return;
    }

    // Mọi engine đều fail — bubble lỗi trung thực (kèm mã cấu trúc của API
    // nếu remote cũng vừa lỗi — UI branch theo `lastChatErrorCode`).
    var text = failure;
    final apiError = _lastChatApiError;
    if (plan.usesRemote && apiError != null) {
      text = '$failure\n(${apiError.code.name}) ${apiError.message}';
    }
    if (item.epoch == _chatEpoch) {
      _addAssistantMessage(text, isError: true);
    }
  }

  /// Xử lý 1 tin bằng engine LOCAL (Gemma thật hoặc mock — giữ nguyên toàn bộ
  /// semantics AI-CHAT-01/02). Trả về:
  /// * null — đã có kết cục (câu trả lời đã add, hoặc tin bị bỏ vì epoch).
  /// * failure text — local thất bại; caller quyết định fallback remote hay
  ///   add bubble lỗi.
  Future<String?> _processChatLocal(_PendingChat item) async {
    final text = item.message.text.trim();
    final engine = _engine;

    if (engine == null) {
      return 'AI local chưa sẵn sàng. Bạn có thể import model .gguf trong phần cài đặt AI.';
    }

    // Engine THẬT: đảm bảo backend còn sống + model đã nạp xong trước khi gửi.
    // (Model native nạp 1–2 phút; hoặc engine vừa bị OOM thu hồi ⇒ recover.)
    if (!_useMock) {
      final ready = await _ensureEngineReady();
      if (!ready) {
        return 'Không kết nối được AI local (model chưa nạp xong). Bạn thử lại sau vài giây.';
      }
      if (item.epoch != _chatEpoch || _disposed) return null;
    }

    final engineState = _engine?.state;
    if (_engine == null ||
        (engineState != AiEngineState.ready &&
            engineState != AiEngineState.processing)) {
      // processing = request khác (tab Viết/Nghe) còn chạy — engine tự xếp
      // hàng, đây KHÔNG phải "engine not ready" theo nghĩa lỗi.
      return 'AI local chưa sẵn sàng. Bạn có thể import model .gguf trong phần cài đặt AI.';
    }

    // FIX AI-CHAT-01 #3: chỉ gửi các tin MỚI NHẤT và trong ngân sách ký tự —
    // context native cố định 2048 token, prompt dài hơn ⇒ llama_decode fail ⇒
    // model trả về RỖNG. (Bản cũ `take(10)` lấy 10 tin ĐẦU hội thoại.)
    final index = _chatMessages.indexOf(item.message);
    final prior =
        index > 0 ? _chatMessages.sublist(0, index) : const <ChatMessage>[];
    final context = _chatContext.build(prior);
    // Câu hỏi dán dài (cả đoạn văn) cũng phải nằm trong ngân sách context —
    // prompt dài hơn n_ctx 2048 ⇒ llama_decode fail ⇒ trả lời rỗng.
    final promptText = _chatContext.clipQuestion(text);
    final maxTokens = _chatContext.resolveMaxTokens(
      promptChars:
          context.length + promptText.length + _chatPromptOverheadChars,
      requested: _chatMaxTokens,
    );

    try {
      final result = await _engine!
          .analyze(
            text: promptText,
            type: AiAnalysisType.conversation,
            // Lịch sử rỗng ⇒ không nhét "Context:" trống vào prompt.
            context: context.isEmpty ? null : context,
            temperature: 0.2,
            maxTokens: maxTokens,
          )
          .first
          .timeout(chatRequestTimeout);
      if (item.epoch != _chatEpoch) return null;
      final answer = result.success && result.summary.isNotEmpty
          ? result.summary
          : '';
      if (answer.isEmpty) {
        if (result.success) {
          // Success nhưng summary rỗng — giữ đúng behavior cũ (bubble không
          // đỏ, không phải lỗi kỹ thuật).
          _addAssistantMessage('Mình chưa tạo được câu trả lời cho tin nhắn này.');
          return null;
        }
        // Model không sinh được gì (JSON hỏng + rescue rỗng) — trả failure để
        // caller thử fallback remote thay vì add câu chung chung.
        return 'Mình chưa tạo được câu trả lời cho tin nhắn này.';
      }
      final isRealModel = _modelLoaded && !_useMock;
      _addAssistantMessage(
        isRealModel
            ? answer
            : '⚠️ Chưa nạp model AI — đây là trả lời MẪU (mock), không phải câu trả lời thật.\n\nImport file .gguf (nút model trên cùng, hoặc Cài đặt → Quản lý Model AI) để dùng AI thật.\n\n$answer',
        isError: !result.success,
      );
      // Backend vừa mất giữa request (OOM) ⇒ engine đã ở state error: dựng lại
      // ở nền để tin kế tiếp chạy được, banner hiện lỗi + "Thử lại".
      if (!result.success &&
          _engine?.state == AiEngineState.error &&
          !_useMock) {
        unawaited(restartEngine(
          reason: result.errorReason ??
              'AI process bị hệ thống thu hồi (thiếu bộ nhớ) — thử lại.',
        ));
      }
      return null;
    } on TimeoutException {
      // FIX AI-CHAT-01 #2: generate quá lâu (máy yếu / native treo) — trả lời
      // rõ + về trạng thái bình thường; nút gửi không xoay vòng vô hạn.
      _lastError = 'Chat timeout (${chatRequestTimeout.inSeconds}s)';
      // Native generate là FFI blocking — không cancel được request trong
      // isolate con. Còn request treo ⇒ dựng lại isolate Ở NỀN để tin sau
      // chạy được thay vì chờ hết watchdog 5 phút (DoD: "request sau vẫn
      // hoạt động hoặc báo lỗi retry được").
      if (!_useMock && (_engine?.isBusy ?? false)) {
        unawaited(restartEngine(
          reason:
              'AI xử lý quá lâu (>${chatRequestTimeout.inSeconds}s) — đang khởi động lại AI',
        ));
      }
      return 'AI xử lý quá lâu (model lớn trên máy yếu). Vui lòng thử lại sau vài giây.';
    } catch (e) {
      _lastError = e.toString();
      if (!_useMock && _engine?.state == AiEngineState.error) {
        unawaited(restartEngine(
          reason: 'AI process bị hệ thống thu hồi (thiếu bộ nhớ) — thử lại.',
        ));
      }
      return 'Có lỗi khi xử lý. Vui lòng thử lại.';
    }
  }

  /// System prompt cho chat qua API remote — model lớn hiểu chỉ thị tốt hơn
  /// Gemma 2B, trả lời thẳng (không cần ép JSON schema như analysis).
  static const String _remoteChatSystemPrompt =
      'Bạn là trợ lý học tập của ứng dụng in4up. Trả lời ngắn gọn, rõ ràng, '
      'thân thiện. Người dùng đang học tiếng Anh (từ vựng, ngữ pháp, phát '
      'âm) — ưu tiên giải thích bằng tiếng Việt trừ khi được hỏi bằng ngôn '
      'ngữ khác. Không bịa đặt: không chắc thì nói rõ là không chắc.';

  /// Xử lý 1 tin bằng engine REMOTE — streaming từng token, bubble assistant
  /// cập nhật dần (token hiện dần trong UI). Trả về true khi tin này ĐÃ CÓ
  /// KẾT CỤC (câu trả lời đủ/một phần, user chủ động dừng, hoặc phiên chat
  /// bị xoá); false khi remote lỗi mà CHƯA thu được token nào — caller bỏ
  /// placeholder và fallback engine kế tiếp trong route.
  Future<bool> _processChatRemote(_PendingChat item) async {
    final remote = await _ensureRemoteEngine();
    if (remote == null) return false;
    if (_disposed) return true;
    if (item.epoch != _chatEpoch) return true; // phiên chat đã bị xoá.

    final text = item.message.text.trim();
    final index = _chatMessages.indexOf(item.message);
    final prior =
        index > 0 ? _chatMessages.sublist(0, index) : const <ChatMessage>[];

    // Bubble placeholder — text cập nhật dần theo từng delta (streaming UI).
    final placeholder = ChatMessage(
      id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.assistant,
      text: '',
    );
    _chatMessages.add(placeholder);
    _lastStreamNotify = null;
    if (!_disposed) notifyListeners();

    final token = AiChatCancelToken();
    _activeChatToken = token;
    final buffer = StringBuffer();
    AiChatUsage? usage;
    AiChatException? failure;
    try {
      // Lịch sử: TÁI DÙNG ChatContextPolicy (tin gần nhất + ngân sách ký tự)
      // nhưng gửi dạng message chuẩn OpenAI thay vì nhét vào 1 prompt — model
      // lớn xử lý hội thoại đa lượt tốt hơn nhiều.
      final history = _chatContext.selectHistory(prior, current: item.message);
      final messages = <AiChatMessage>[
        const AiChatMessage('system', _remoteChatSystemPrompt),
        for (final m in history) AiChatMessage(m.role.name, m.text),
        AiChatMessage('user', _chatContext.clipQuestion(text)),
      ];
      await for (final chunk in remote.chatStream(
        messages: messages,
        temperature: 0.4,
        maxTokens: _chatMaxTokens,
        cancelToken: token,
      )) {
        if (item.epoch != _chatEpoch) {
          token.cancel('chat cleared');
          break;
        }
        final delta = chunk.deltaContent;
        if (delta != null && delta.isNotEmpty) {
          buffer.write(delta);
          _updateStreamingMessage(placeholder.id, buffer.toString());
        }
        if (chunk.usage != null) usage = chunk.usage;
      }
    } on AiChatException catch (e) {
      failure = e;
    } catch (e) {
      failure = AiChatException(AiChatErrorCode.invalidResponse, e.toString());
    } finally {
      _activeChatToken = null;
      _lastChatApiError = failure;
      if (usage != null) {
        _lastChatUsage = usage;
        _lastChatModelId = remote.modelId;
      }
    }

    if (item.epoch != _chatEpoch) {
      // Phiên chat bị xoá giữa chừng — bỏ bubble, không trả vào lịch sử mới.
      _chatMessages.removeWhere((m) => m.id == placeholder.id);
      if (!_disposed) notifyListeners();
      return true;
    }

    final answer = buffer.toString().trim();
    final userStopped = token.isCancelled;
    if (answer.isEmpty && failure == null && !userStopped) {
      // Stream kết thúc "bình thường" nhưng không có nội dung gì — ghi mã
      // emptyOutput để UI phân nhánh đúng (không phải lỗi mạng).
      failure = const AiChatException(
          AiChatErrorCode.emptyOutput, 'Model không trả nội dung');
      _lastChatApiError = failure;
    }
    final idx = _indexOfMessage(placeholder.id);
    if (idx < 0) return true; // phòng thủ: bubble đã biến mất.

    if (answer.isEmpty) {
      // Không thu được token nào (lỗi API hoặc model rỗng) — bỏ placeholder,
      // trả false để route fallback engine kế (AT: fallback rõ, không treo).
      _chatMessages.removeAt(idx);
      if (!_disposed) notifyListeners();
      return false;
    }

    // Có nội dung (đủ hoặc một phần do user dừng / mạng đứt giữa chừng).
    var finalText = answer;
    if (userStopped) {
      finalText += '\n\n⏹ Đã dừng.';
    } else if (failure != null) {
      // Cắt mạng giữa lúc generate: giữ phần đã sinh + cảnh báo theo MÃ —
      // dừng sạch, không treo, không crash.
      finalText += '\n\n⚠️ ${_chatFailureNotice(failure)}';
    }
    _chatMessages[idx] =
        _chatMessages[idx].copyWith(text: finalText, isError: failure != null && !userStopped);
    await _persistChatHistory();
    if (!_disposed) notifyListeners();
    return true;
  }

  /// Thông báo lỗi chat theo MÃ cấu trúc — UI không phải match chuỗi.
  String _chatFailureNotice(AiChatException e) {
    switch (e.code) {
      case AiChatErrorCode.noNetwork:
        return 'Mất kết nối tới server AI giữa chừng — đã dừng an toàn.';
      case AiChatErrorCode.timeout:
        return 'Server AI không phản hồi kịp (timeout).';
      case AiChatErrorCode.rateLimited:
        return 'Vượt giới hạn gọi API (429) — thử lại sau ít phút.';
      case AiChatErrorCode.httpError:
        return 'Lỗi HTTP từ server AI'
            '${e.statusCode != null ? ' (${e.statusCode})' : ''}.';
      case AiChatErrorCode.emptyOutput:
        return 'Model không trả nội dung.';
      case AiChatErrorCode.busy:
        return 'API đang bận — thử lại.';
      case AiChatErrorCode.canceled:
        return 'Đã dừng.';
      case AiChatErrorCode.invalidResponse:
        return 'Server trả dữ liệu không đúng chuẩn OpenAI.';
    }
  }

  int _indexOfMessage(String id) {
    for (var i = 0; i < _chatMessages.length; i++) {
      if (_chatMessages[i].id == id) return i;
    }
    return -1;
  }

  /// Cập nhật text bubble đang stream — throttle notify ~60ms/token-batch để
  /// ListView không rebuild từng ký tự (token vẫn hiện dần mượt).
  void _updateStreamingMessage(String id, String text) {
    final idx = _indexOfMessage(id);
    if (idx < 0) return;
    _chatMessages[idx] = _chatMessages[idx].copyWith(text: text);
    final now = DateTime.now();
    final last = _lastStreamNotify;
    if (last == null || now.difference(last) >= const Duration(milliseconds: 60)) {
      _lastStreamNotify = now;
      if (!_disposed) notifyListeners();
    }
  }

  /// Đảm bảo engine THẬT dùng được: chờ restart đang chạy (nếu có), khởi động
  /// lại nếu backend đã chết, chờ native nạp model xong. Trả về false ⇒ caller
  /// báo lỗi retry được (không gửi request vào hư không).
  Future<bool> _ensureEngineReady({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (_engine == null) return false;
    if (_useMock) return true;

    final restarting = _restartInFlight;
    if (restarting != null) {
      try {
        await restarting;
      } catch (_) {
        // Lỗi đã được ghi vào _engineError bên trong restartEngine.
      }
    }

    final engineState = _engine?.state;
    if (engineState == AiEngineState.error ||
        engineState == AiEngineState.disposed) {
      final ok = await restartEngine(
        reason: _engineError ??
            'AI process bị hệ thống thu hồi (thiếu bộ nhớ) — đang khởi động lại',
      );
      if (!ok) return false;
    }

    if (!_modelLoaded) {
      try {
        await _awaitModelReady(timeout: timeout);
      } on TimeoutException {
        _engineError =
            'Model AI nạp quá lâu (>${timeout.inMinutes} phút) — thử lại.';
        if (!_disposed) notifyListeners();
        return false;
      } catch (e) {
        // Native không nạp được (build thiếu backend / file hỏng): ghi lỗi để
        // banner hiện + "Thử lại", nhưng KHÔNG chặn chat — engine vẫn trả lời
        // bằng mock kèm disclaimer như trước (MODELS-002 không bị regress).
        _engineError =
            e is StateError ? e.message : 'Model AI không nạp được: $e';
        if (!_disposed) notifyListeners();
        return _engineStateUsable;
      }
    }
    return !_useMock;
  }

  bool get _engineStateUsable {
    final state = _engine?.state;
    return state == AiEngineState.ready || state == AiEngineState.processing;
  }

  /// Engine có đang được khởi động lại không (UI: hiện "đang nạp" thay vì lỗi
  /// trong lúc recover).
  bool get isEngineRestarting => _restartInFlight != null;

  /// Khởi động lại AI engine THẬT với model đã có trên máy — KHÔNG mở file
  /// picker. Dùng khi native treo / isolate bị OOM thu hồi; nút "Thử lại" của
  /// banner chat gọi hàm này khi đã có file model.
  Future<bool> restartEngine({String? reason}) {
    final existing = _restartInFlight;
    if (existing != null) return existing;
    final future = _restartEngine(reason: reason);
    _restartInFlight = future;
    return future;
  }

  Future<bool> _restartEngine({String? reason}) async {
    final note = reason ?? 'AI engine cần khởi động lại';
    final path = _loader.currentModelPath ?? _modelStatus?.modelPath;
    _engineError = note;
    _modelLoaded = false;
    _setImportStage(AiImportStage.loading, notify: false);
    if (!_disposed) notifyListeners();

    var ok = false;
    try {
      if (_useMock || path == null) {
        _engineError = 'Chưa có model .gguf trên máy để khởi động lại AI.';
      } else {
        final engine = _engine;
        if (engine != null) {
          // Kill isolate treo + spawn lại + chờ handshake (native nạp lại
          // model 1–2 phút) — dùng CÙNG engine nên không mất state model path.
          ok = await engine.recover(reason: note);
        }
        if (!ok) {
          // Engine chưa từng init / không tự dựng lại được ⇒ tạo mới từ path.
          ok = await initialize(
            modelPath: path,
            useMock: false,
            forceReload: true,
          );
        }
        if (ok) {
          await _awaitModelReady();
          _engineError = null;
          _setImportStage(AiImportStage.ready, notify: false);
          debugPrint('[AiServiceFacade] ♻️ AI engine đã hồi phục');
        }
      }
    } catch (e) {
      ok = false;
      _engineError =
          e is StateError ? e.message : 'Không khởi động lại được AI: $e';
      debugPrint('[AiServiceFacade] restartEngine error: $e');
    } finally {
      if (!ok) {
        _modelLoaded = false;
        _setImportStage(
          AiImportStage.failed,
          error: _engineError,
          notify: false,
        );
      }
      _restartInFlight = null;
      if (!_disposed) notifyListeners();
    }
    return ok;
  }

  // ── Init ──

  Future<void> initializeAsync() async {
    if (_initialized) return;
    await _restoreChatHistory();
    // WP1: nạp cấu hình provider/routing (WP0) để route chat/analysis biết
    // có tầng API nào không. Không chặn khi prefs hỏng — store tự dùng mặc định.
    unawaited(AiProviderStore.instance.ensureLoaded().catchError((Object e) {
      debugPrint('[AiServiceFacade] provider store load error: $e');
    }));
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
            _engineError = null;
            if (!_disposed) notifyListeners();
          }).catchError((Object e) {
            // Native không nạp được (thiếu lib trong build / file hỏng) —
            // hasModel=false (mock không được báo "đã nạp"), nhưng ghi lý do
            // để banner chat hiện lỗi + "Thử lại" (khởi động lại engine)
            // thay vì nói "chưa nạp model" khi file model vẫn còn trên máy.
            _modelLoaded = false;
            _engineError = e is StateError ? e.message : e.toString();
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
      _engineError = 'Không khởi tạo được AI engine (spawn isolate lỗi).';
      debugPrint('[AiServiceFacade] Gemma init failed → mock fallback');
    } else {
      // Engine thật đã spawn: lỗi cũ (nếu có) không còn đúng nữa — model
      // native sẽ báo qua modelReady (isModelLoading).
      _engineError = null;
    }
    if (!_disposed) notifyListeners();
    return ok;
  }

  // ── WP1 (API-002): định tuyến engine remote/local theo AiRoutingPrefs ──

  /// Hoạch định route LLM thuần (xem `planLlmRoute`). offlineOnly hoặc chưa
  /// cấu hình provider ⇒ KHÔNG có stop `remote` ⇒ không request nào đi ra.
  AiLlmRoutePlan _chatRoutePlan() {
    final store = AiProviderStore.instance;
    return planLlmRoute(
      mode: store.routing.modeOf(AiRouteCapability.chat),
      remoteAvailable: isRemoteChatConfigured,
      localModelReady: hasModel,
    );
  }

  /// Lấy (hoặc tái tạo) engine remote theo provider đang bật. Trả về null
  /// khi: store chưa nạp / offlineOnly / không provider / provider thiếu
  /// model chat. Tái tạo khi user đổi cấu hình (khác key) — hủy request cũ.
  Future<AiEngineRemote?> _ensureRemoteEngine() async {
    final store = AiProviderStore.instance;
    if (!store.isLoaded) return null;
    final provider = store.resolveProvider(AiRouteCapability.chat);
    if (provider == null) return null;
    final key = '${provider.id}|${provider.baseUrl}|${provider.chatModel ?? ''}';
    final existing = _remoteEngine;
    if (existing != null && _remoteEngineKey == key) return existing;
    await existing?.dispose();
    final engine = AiEngineRemote(provider: provider);
    final ok = await engine.initialize(
        modelPath: 'api://${provider.id}/${provider.chatModel ?? ''}');
    if (!ok) {
      await engine.dispose();
      _remoteEngine = null;
      _remoteEngineKey = null;
      return null;
    }
    _remoteEngine = engine;
    _remoteEngineKey = key;
    debugPrint('[AiServiceFacade] 🛰️ Remote engine ready: $key');
    return engine;
  }

  /// Thử 1 request analysis qua engine remote (khi route cho phép). Trả về
  /// kết quả THÀNH CÔNG, hoặc null (remote không có trong route / lỗi — đã
  /// ghi `_lastChatApiError` theo mã cấu trúc). KHÔNG ném lỗi ra ngoài.
  Future<AiAnalysis?> _tryRemoteAnalysis({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
    int maxTokens = 256,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final remote = await _ensureRemoteEngine();
    if (remote == null) return null;
    try {
      final result = await remote
          .analyze(
            text: text,
            type: type,
            context: context,
            temperature: temperature,
            maxTokens: maxTokens,
          )
          .first
          .timeout(timeout);
      if (result.success) {
        _lastChatApiError = null;
        _lastChatUsage = remote.lastUsage;
        _lastChatModelId = remote.modelId;
        return result;
      }
      _lastChatApiError = remote.lastErrorOrNull;
      return null;
    } on TimeoutException {
      _lastChatApiError =
          const AiChatException(AiChatErrorCode.timeout, 'API xử lý quá lâu');
      return null;
    } on AiChatException catch (e) {
      _lastChatApiError = e;
      return null;
    } catch (e) {
      _lastChatApiError =
          AiChatException(AiChatErrorCode.httpError, e.toString());
      return null;
    }
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

    // WP1 (API-002): route theo AiRoutingPrefs — remote đứng đầu (onlineFirst,
    // hoặc offlineFirst mà chưa có model local) ⇒ hỏi API trước. Word Lookup
    // qua API vẫn trả ĐÚNG JSON schema như Gemma (Word Lookup AT).
    final plan = _chatRoutePlan();
    var remoteTried = false;
    Future<AiAnalysis?> tryRemote() => _tryRemoteAnalysis(
          text: word,
          type: AiAnalysisType.wordLookup,
          context: sentenceContext,
          timeout: const Duration(seconds: 45),
        );

    if (plan.remoteFirst) {
      remoteTried = true;
      final remote = await tryRemote();
      if (remote != null) {
        final enriched = localDictEntry != null
            ? enrichWithLocalDict(remote, localDictEntry)
            : remote;
        _cache[cacheKey] = enriched;
        return enriched;
      }
    }

    try {
      AiAnalysis result;
      // Busy (đang generate cho chat) ⇒ dùng từ điển local ngay — không
      // chen request vào (AI-CHAT-01: isReady giờ bao gồm processing).
      // WP1: nếu route có remote thì API trả lời song song (không đợi isolate).
      final engineBusy = _engine?.state == AiEngineState.processing;
      if (!isReady || engineBusy) {
        if (!remoteTried && plan.usesRemote) {
          remoteTried = true;
          final remote = await tryRemote();
          if (remote != null) {
            final enriched = localDictEntry != null
                ? enrichWithLocalDict(remote, localDictEntry)
                : remote;
            _cache[cacheKey] = enriched;
            return enriched;
          }
        }
        result = buildFromLocalDict(word, localDictEntry);
      } else {
        result = await _engine!.analyze(text: word, type: AiAnalysisType.wordLookup, context: sentenceContext).first.timeout(const Duration(seconds: 30));
        if (!result.success && !remoteTried && plan.usesRemote) {
          // Gemma lỗi (JSON hỏng / output rỗng) ⇒ fallback remote theo route.
          remoteTried = true;
          final remote = await tryRemote();
          if (remote != null) {
            final enriched = localDictEntry != null
                ? enrichWithLocalDict(remote, localDictEntry)
                : remote;
            _cache[cacheKey] = enriched;
            return enriched;
          }
        }
        if (localDictEntry != null) {
          result = enrichWithLocalDict(result, localDictEntry);
        }
      }
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('[AiServiceFacade] lookupWord error: $e');
      if (!remoteTried && plan.usesRemote) {
        remoteTried = true;
        final remote = await tryRemote();
        if (remote != null) {
          final enriched = localDictEntry != null
              ? enrichWithLocalDict(remote, localDictEntry)
              : remote;
          _cache[cacheKey] = enriched;
          return enriched;
        }
      }
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

    // WP1 (API-002): remote đứng đầu route ⇒ Write Studio hỏi API trước.
    final plan = _chatRoutePlan();
    if (plan.remoteFirst) {
      final remote = await _tryRemoteAnalysis(
        text: sentence,
        type: AiAnalysisType.sentenceParse,
        maxTokens: 384,
        timeout: const Duration(seconds: 90),
      );
      if (remote != null) {
        _currentAnalysis = remote;
        _setFacadeState(AiFacadeState.idle);
        notifyListeners();
        return;
      }
    }

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

    // WP1: local không ra kết quả (chưa sẵn sàng / retry hết) ⇒ remote là
    // fallback cuối nếu route cho phép.
    if (plan.usesRemote && !(_currentAnalysis?.success ?? false)) {
      final remote = await _tryRemoteAnalysis(
        text: sentence,
        type: AiAnalysisType.sentenceParse,
        maxTokens: 384,
        timeout: const Duration(seconds: 90),
      );
      if (remote != null) {
        _currentAnalysis = remote;
        _lastError = null;
      }
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
    return _analyzeWithRoute(
      text: transcript,
      type: AiAnalysisType.summarize,
      context: speakerContext,
      localTimeout: const Duration(seconds: 60),
      remoteTimeout: const Duration(seconds: 120),
      maxTokens: 512,
    );
  }

  // ── Term Extract ──

  Future<AiAnalysis> extractTerms(String transcript) async {
    return _analyzeWithRoute(
      text: transcript,
      type: AiAnalysisType.termExtract,
      localTimeout: const Duration(seconds: 45),
      remoteTimeout: const Duration(seconds: 120),
      maxTokens: 512,
    );
  }

  // ── PAO Generation ──

  Future<AiAnalysis> generatePao(String word) async {
    return _analyzeWithRoute(
      text: word,
      type: AiAnalysisType.paoGeneration,
      localTimeout: const Duration(seconds: 20),
      remoteTimeout: const Duration(seconds: 45),
    );
  }

  /// Chạy 1 analysis theo route plan (remote ↔ local 2 chiều): engine đầu
  /// lỗi ⇒ thử engine kế; thất bại hết ⇒ fallback analysis errorReason rõ.
  /// KHÔNG có provider ⇒ đúng behavior cũ (chỉ engine local).
  Future<AiAnalysis> _analyzeWithRoute({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
    int maxTokens = 256,
    required Duration localTimeout,
    Duration remoteTimeout = const Duration(seconds: 90),
  }) async {
    final plan = _chatRoutePlan();

    Future<AiAnalysis?> tryRemote() => _tryRemoteAnalysis(
          text: text,
          type: type,
          context: context,
          temperature: temperature,
          maxTokens: maxTokens,
          timeout: remoteTimeout,
        );

    if (plan.remoteFirst) {
      final remote = await tryRemote();
      if (remote != null) return remote;
    }

    if (isReady) {
      try {
        // Giữ NGUYÊN call local như bản cũ (không truyền temperature/
        // maxTokens — engine dùng mặc định của chính nó, context 2048 của
        // Gemma không bị tăng rủi ro tràn).
        final result = await _engine!
            .analyze(text: text, type: type, context: context)
            .first
            .timeout(localTimeout);
        if (result.success) return result;
        if (plan.usesRemote && !plan.remoteFirst) {
          final remote = await tryRemote();
          if (remote != null) return remote;
        }
        return result; // engine tự trả fallback analysis (success=false).
      } catch (e) {
        if (plan.usesRemote) {
          final remote = await tryRemote();
          if (remote != null) return remote;
        }
        return AiAnalysis.fallback(text, errorReason: e.toString(), analysisType: type);
      }
    }

    // Engine local chưa sẵn sàng (chưa import model / đang khởi động lại).
    if (plan.usesRemote && !plan.remoteFirst) {
      final remote = await tryRemote();
      if (remote != null) return remote;
    }
    return AiAnalysis.fallback(text, errorReason: 'Engine not ready', analysisType: type);
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
    _engineError = null;
    await initialize(modelPath: '', useMock: true);
    _setImportStage(AiImportStage.idle);
  }

  /// Sau khi có file model hợp lệ (import/download): khởi động engine thật,
  /// chờ native llama.cpp nạp model xong, báo UI "sẵn sàng" hoặc lỗi rõ ràng.
  Future<bool> _adoptModel(String modelPath) async {
    _engineError = null;
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
    _engineError = null;
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

  /// Test-seam: gắn engine giả (fake) + đánh dấu model đã nạp để kiểm tra
  /// hàng đợi/timeout/banner mà không cần native lib hay file .gguf thật.
  @visibleForTesting
  void debugAttachEngine(AiEngine engine, {bool modelLoaded = true}) {
    _engine = engine;
    _initialized = true;
    _useMock = false;
    _modelLoaded = modelLoaded;
    _engineError = null;
  }

  /// Test-seam (AT WP1): route hiện tại có chứa engine remote không — kiểm
  /// tra "offlineOnly ⇒ không request /chat/completions nào đi ra" bằng logic
  /// routing thuần, không cần network.
  @visibleForTesting
  bool get debugUsesRemoteChatRoute => _chatRoutePlan().usesRemote;

  @override
  void dispose() {
    _disposed = true;
    // Đừng để UI/await nào treo vì hàng đợi chat còn item chưa xử lý.
    _chatEpoch++;
    for (final item in _chatQueue) {
      if (!item.done.isCompleted) item.done.complete();
    }
    _chatQueue.clear();
    // WP1: hủy request remote đang stream — token không được chảy tiếp sau
    // dispose (AT: đóng màn giữa lúc generate ⇒ dừng sạch).
    _activeChatToken?.cancel('facade disposed');
    unawaited(_remoteEngine?.dispose());
    _remoteEngine = null;
    _remoteEngineKey = null;
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

/// Một tin nhắn đang trong hàng đợi chat. Giữ Completer để `sendMessage` await
/// đúng lượt của tin đó (thay vì `return` sớm và nuốt tin khi engine đang bận).
class _PendingChat {
  _PendingChat({required this.message, required this.epoch});

  final ChatMessage message;

  /// Phiên chat lúc tin được gửi — `clearChat()` tăng epoch ⇒ item cũ tự bỏ.
  final int epoch;

  final Completer<void> done = Completer<void>();
}

enum AiFacadeState { idle, loading, error, noModel, chatting }
