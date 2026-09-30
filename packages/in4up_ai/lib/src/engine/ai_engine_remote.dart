// packages/in4up_ai/lib/src/engine/ai_engine_remote.dart
//
// WP1 (API-002) — AiEngine chạy qua API OpenAI-compatible (cloud hoặc server
// LAN: Ollama, LM Studio, llama-server, Groq, Gemini compat, OpenRouter…).
//
// Thiết kế theo interface `AiEngine` có sẵn — KHÔNG phá interface:
// * `initialize(modelPath)` nhận config encoded `api://<providerId>/<model>`
//   (facade giữ nguyên signature) HOẶC provider inject qua constructor.
// * Remote không cần isolate/native handle: `modelReady` complete ngay,
//   `recover()` = hủy request treo + coi như sẵn sàng cho request MỚI
//   (HTTP stateless — không có gì phải dựng lại).
// * `analyze` dùng ĐÚNG prompt schema của `AiPromptsLibrary` (chat/word
//   lookup/summarize… trả JSON cùng schema như Gemma) rồi parse bằng pipeline
//   `AiAnalysis.fromGemmaJson` hiện có.
// * Chat streaming: `chatStream` (ngoài interface — facade kiểm tra kiểu
//   trước khi dùng), UI hiện từng token.

import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/ai_analysis.dart';
import '../prompts/ai_prompts_library.dart';
import '../provider/ai_provider_config.dart';
import '../provider/ai_sse.dart';
import '../provider/openai_compat_client.dart';
import 'ai_engine.dart';

/// Engine LLM qua API. 1 instance = 1 provider + 1 model (key trùng khớp
/// facade dùng để tái tạo khi user đổi cấu hình trong màn Server & API).
class AiEngineRemote implements AiEngine {
  AiEngineRemote({
    required AiProviderConfig provider,
    http.Client? httpClient,
    Duration idleTimeout = const Duration(seconds: 60),
  })  : _provider = provider,
        _idleTimeout = idleTimeout {
    _client = OpenAiCompatClient(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      httpClient: httpClient,
    );
  }

  final AiProviderConfig _provider;
  late final OpenAiCompatClient _client;
  final Duration _idleTimeout;

  /// Model đang dùng (từ provider.chatModel hoặc override qua initialize).
  String? _modelId;

  int _inFlight = 0;
  bool _disposed = false;
  AiEngineState _state = AiEngineState.uninitialized;

  /// Lỗi cấu trúc gần nhất (UI branch theo mã — không match chuỗi).
  AiChatException? lastError;
  AiChatException? get lastErrorOrNull => lastError;

  /// Usage gần nhất (từ chunk cuối nếu server trả) — hiển thị token/chi phí.
  AiChatUsage? lastUsage;

  /// Mọi token của request đang chạy — dispose/recover hủy hết (token
  /// không được "chảy tiếp" sau khi engine chết).
  final List<AiChatCancelToken> _activeTokens = <AiChatCancelToken>[];

  String? get providerLabel => _provider.label;
  String? get modelId => _modelId;
  String get providerId => _provider.id;
  bool get hasModelSelected => _modelId != null && _modelId!.isNotEmpty;

  @override
  AiEngineState get state => _state;

  @override
  bool get isBusy => _inFlight > 0;

  @override
  Future<void> get modelReady =>
      Future<void>.value(); // remote: không nạp gì — sẵn sàng ngay.

  /// Nhận config encoded `api://<providerId>/<model>`:
  /// * providerId phải khớp provider inject qua constructor (bảo đảm facade
  ///   không gửi nhầm request sang provider khác).
  /// * model (path sau providerId, có thể chứa '/') override chatModel.
  /// * modelPath rỗng ⇒ dùng chatModel của provider.
  /// * modelPath là đường dẫn file thường (vd .gguf) ⇒ engine này không phải
  ///   lựa chọn đúng — trả false để facade chuyển sang Gemma.
  @override
  Future<bool> initialize({required String modelPath}) async {
    if (_disposed) return false;
    final chatModel = _provider.chatModel;
    if (modelPath.trim().isEmpty) {
      if (chatModel == null || chatModel.isEmpty) return false;
      _modelId = chatModel;
      _state = AiEngineState.ready;
      return true;
    }
    final trimmed = modelPath.trim();
    if (!trimmed.startsWith('api://')) {
      // Không phải config API — engine local (Gemma) sẽ lo.
      return false;
    }
    final rest = trimmed.substring('api://'.length);
    final slash = rest.indexOf('/');
    final providerId = slash < 0 ? rest : rest.substring(0, slash);
    final modelPart = slash < 0 ? '' : rest.substring(slash + 1);
    if (providerId != _provider.id) return false;
    if (modelPart.isEmpty && (chatModel == null || chatModel.isEmpty)) {
      return false;
    }
    _modelId = modelPart.isEmpty ? chatModel : modelPart;
    _state = AiEngineState.ready;
    return true;
  }

  /// Remote không có isolate/native treo: hủy request đang chạy và sẵn sàng
  /// cho request mới (recover = tạo lại request mới — HTTP stateless).
  @override
  Future<bool> recover({String? reason}) async {
    if (_disposed) return false;
    for (final token in List.of(_activeTokens)) {
      token.cancel('recover: ${reason ?? 'engine recover'}');
    }
    if (_inFlight == 0) _state = AiEngineState.ready;
    return true;
  }

  // ── Analysis (không streaming): prompt schema sẵn + fromGemmaJson ──

  @override
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
    int maxTokens = 256,
  }) async* {
    if (_disposed) {
      yield AiAnalysis.fallback(text,
          errorReason: 'Remote engine disposed', analysisType: type);
      return;
    }
    if (_state == AiEngineState.uninitialized) {
      yield AiAnalysis.fallback(text,
          errorReason: 'Remote engine chưa initialize', analysisType: type);
      return;
    }

    try {
      final prompt = AiPromptsLibrary.buildPrompt(
          type: type, text: text, context: context);
      final buffer = StringBuffer();
      await for (final chunk in chatStream(
        messages: [
          const AiChatMessage(
              'system', 'You are a precise assistant. Return ONLY valid JSON.'),
          AiChatMessage('user', prompt),
        ],
        temperature: temperature,
        maxTokens: maxTokens,
      )) {
        final delta = chunk.deltaContent;
        if (delta != null && delta.isNotEmpty) buffer.write(delta);
        if (chunk.usage != null) lastUsage = chunk.usage;
      }
      final raw = buffer.toString();
      if (raw.trim().isEmpty) {
        lastError = const AiChatException(
            AiChatErrorCode.emptyOutput, 'Model không trả nội dung');
        yield AiAnalysis.fallback(text,
            errorReason:
                '(${AiChatErrorCode.emptyOutput.name}) Model không trả nội dung',
            analysisType: type);
        return;
      }
      // Model lớn đôi khi bọc JSON trong ```json fence — lột trước khi đưa
      // vào pipeline fromGemmaJson của Gemma (2 engine cùng 1 schema).
      yield AiAnalysis.fromGemmaJson(
        AiRemoteJsonExtractor.extract(raw),
        analysisType: type,
        inputText: text,
      );
    } on AiChatException catch (e) {
      lastError = e;
      yield AiAnalysis.fallback(text,
          errorReason: '(${e.code.name}) ${e.message}',
          analysisType: type);
    } catch (e) {
      lastError = AiChatException(AiChatErrorCode.invalidResponse, '$e');
      yield AiAnalysis.fallback(text,
          errorReason: '(${AiChatErrorCode.invalidResponse.name}) $e',
          analysisType: type);
    }
  }

  // ── Chat streaming (ngoài interface AiEngine) ──

  /// Gửi hội thoại qua `/v1/chat/completions` (`stream: true`) — mỗi token
  /// model sinh ra thành 1 chunk. [cancelToken] hủy ngay khi user đóng màn
  /// hoặc bấm Dừng; engine theo dõi token để dispose/recover dừng sạch.
  ///
  /// Lỗi được đẩy vào stream dưới dạng [AiChatException] (mã cấu trúc) —
  /// caller xử lý trong `await for`/`onError`.
  Stream<AiChatStreamChunk> chatStream({
    required List<AiChatMessage> messages,
    double temperature = 0.4,
    int? maxTokens,
    AiChatCancelToken? cancelToken,
  }) {
    final model = _modelId ?? _provider.chatModel;
    if (model == null || model.isEmpty) {
      final controller = StreamController<AiChatStreamChunk>();
      controller.onListen = () {
        const error = AiChatException(AiChatErrorCode.invalidResponse,
            'Provider chưa chọn model cho chat');
        lastError = error;
        controller.addError(error);
        controller.close();
      };
      return controller.stream;
    }

    final token = cancelToken ?? AiChatCancelToken();
    _activeTokens.add(token);
    _inFlight++;
    if (_state != AiEngineState.disposed) {
      _state = AiEngineState.processing;
    }

    var finished = false;
    void untrack() {
      if (finished) return; // idempotent — lỗi + done + cancel chỉ tính 1 lần.
      finished = true;
      _activeTokens.remove(token);
      _inFlight--;
      if (_inFlight <= 0) {
        _inFlight = 0;
        if (!_disposed && _state == AiEngineState.processing) {
          _state = AiEngineState.ready;
        }
      }
    }

    // Controller riêng để BẮT BUỘC dọn state ở MỌI đường ra: done, error,
    // và cả khi caller hủy subscription giữa chừng (await for break) —
    // cancel lan lên client ⇒ đóng socket, không token nào chảy tiếp.
    late final StreamController<AiChatStreamChunk> out;
    StreamSubscription<AiChatStreamChunk>? sub;
    out = StreamController<AiChatStreamChunk>(
      onListen: () {
        sub = _client
            .chatStream(
              model: model,
              messages: messages,
              temperature: temperature,
              maxTokens: maxTokens,
              idleTimeout: _idleTimeout,
              cancelToken: token,
            )
            .listen(
              out.add,
              onError: (Object e, StackTrace s) {
                if (e is AiChatException) lastError = e;
                if (!out.isClosed) out.addError(e, s);
                untrack();
                if (!out.isClosed) out.close();
              },
              onDone: () {
                untrack();
                if (!out.isClosed) out.close();
              },
            );
      },
      onCancel: () async {
        await sub?.cancel(); // đóng socket phía client
        untrack();
      },
    );
    return out.stream;
  }

  @override
  Future<void> warmUp() async {
    // Remote không cần warm-up (không nạp model) — no-op trung thực.
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Hủy mọi request đang chạy — token không được chảy tiếp sau dispose.
    for (final token in List.of(_activeTokens)) {
      token.cancel('engine disposed');
    }
    _activeTokens.clear();
    _state = AiEngineState.disposed;
  }
}

/// Lột JSON khỏi output model lớn (```json fence, câu dẫn trước/sau JSON) —
/// cùng cách `AiModelMapper._extractJson` đã làm cho Gemma, nhưng trả về
/// chuỗi gốc khi không tìm thấy cặp ngoặc (pipeline fromGemmaJson tự lo
/// phần rescue/fallback).
class AiRemoteJsonExtractor {
  const AiRemoteJsonExtractor._();

  static String extract(String raw) {
    var text = raw.trim();
    // Bọc markdown: ```json\n{...}\n``` hoặc ```\n{...}\n```.
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline > 0) {
        text = text.substring(firstNewline + 1);
      }
      final fenceEnd = text.lastIndexOf('```');
      if (fenceEnd >= 0) {
        text = text.substring(0, fenceEnd);
      }
      text = text.trim();
    }
    final start = text.indexOf('{');
    if (start < 0) return raw;
    final end = text.lastIndexOf('}');
    if (end <= start) return raw;
    return text.substring(start, end + 1);
  }
}
