// packages/in4up_ai/lib/src/provider/ai_sse.dart
//
// WP1 (API-002) — Primitives cho /v1/chat/completions streaming (SSE):
// mã lỗi cấu trúc, cancel token, event/chunk, parser SSE thuần (test được).
//
// Mã lỗi (mẫu HyMtErrorCode): UI phân nhánh theo `AiChatErrorCode`, KHÔNG
// match chuỗi.
//
// Cancel token (mẫu dio CancelToken): `AiChatCancelToken.cancel()` hủy request
// đang streaming ngay — client đóng socket (cancel subscription của response
// stream). Sau khi engine/facade dispose, token đã cancel ⇒ không token nào
// "chảy tiếp" trong nền.

import 'dart:async';
import 'dart:convert';

import 'openai_compat_client.dart' show AiApiErrorCode, AiApiException;

/// Mã lỗi cấu trúc của tầng chat/analysis qua API — UI phân nhánh theo mã,
/// không match chuỗi (cùng khuôn mẫu `HyMtErrorCode` của Hy-MT).
enum AiChatErrorCode {
  /// Không có kết nối mạng (socket lỗi / server không tới được).
  noNetwork,

  /// Hết thời gian chờ (kết nối, hoặc quá lâu không có token mới).
  timeout,

  /// 429 — rate limit (caller tự backoff, tối đa retry 1 lần).
  rateLimited,

  /// Lỗi HTTP khác (4xx/5xx — kèm statusCode).
  httpError,

  /// Stream kết thúc mà model không sinh nội dung gì.
  emptyOutput,

  /// Engine đang bận xử lý request khác (hàng đợi chat đã có người chờ).
  busy,

  /// Người dùng đóng màn / bấm Dừng — request đã bị hủy chủ động.
  canceled,

  /// Response không parse được (SSE/JSON sai format chuẩn OpenAI).
  invalidResponse,
}

/// Lỗi có mã cấu trúc của tầng chat API.
class AiChatException implements Exception {
  final AiChatErrorCode code;
  final String message;
  final int? statusCode;

  const AiChatException(this.code, this.message, {this.statusCode});

  /// Đổi mã lỗi WP0 (client HTTP) sang mã chat — giữ statusCode khi có.
  factory AiChatException.fromApi(AiApiException e) {
    switch (e.code) {
      case AiApiErrorCode.noNetwork:
        return AiChatException(AiChatErrorCode.noNetwork, e.message,
            statusCode: e.statusCode);
      case AiApiErrorCode.timeout:
        return AiChatException(AiChatErrorCode.timeout, e.message,
            statusCode: e.statusCode);
      case AiApiErrorCode.rateLimited:
        return AiChatException(AiChatErrorCode.rateLimited, e.message,
            statusCode: e.statusCode);
      case AiApiErrorCode.invalidResponse:
        return AiChatException(AiChatErrorCode.invalidResponse, e.message,
            statusCode: e.statusCode);
      case AiApiErrorCode.unauthorized:
      case AiApiErrorCode.httpError:
      case AiApiErrorCode.cleartextBlocked:
      case AiApiErrorCode.invalidBaseUrl:
        return AiChatException(AiChatErrorCode.httpError, e.message,
            statusCode: e.statusCode);
    }
  }

  @override
  String toString() => 'AiChatException($code): $message';
}

/// Token hủy request kiểu dio — `cancel()` từ UI (đóng màn / nút Dừng) hoặc
/// từ engine.dispose() đều dừng stream ngay ở token kế tiếp.
class AiChatCancelToken {
  bool _cancelled = false;
  String? _reason;
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _cancelled;

  /// Lý do hủy (hiển thị/chẩn đoán — ví dụ 'user stopped').
  String? get reason => _reason;

  /// Complete ngay lần đầu `cancel()` được gọi; các lần sau no-op.
  Future<void> get whenCancelled => _completer.future;

  void cancel([String? reason]) {
    if (_cancelled) return;
    _cancelled = true;
    _reason = reason ?? 'canceled';
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// 1 tin nhắn cho `/v1/chat/completions` — role chuẩn OpenAI
/// (`system` / `user` / `assistant`) + nội dung.
class AiChatMessage {
  final String role;
  final String content;
  const AiChatMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Số token dùng của 1 request (từ field `usage` của chunk cuối — một số
/// server gửi kèm: OpenAI khi `stream_options.include_usage`, Ollama/Groq
/// luôn gửi ở chunk cuối). Null khi server không trả usage.
class AiChatUsage {
  final int promptTokens;
  final int completionTokens;
  final int? totalTokens;

  const AiChatUsage({
    required this.promptTokens,
    required this.completionTokens,
    this.totalTokens,
  });

  int get total => totalTokens ?? (promptTokens + completionTokens);
}

/// 1 sự kiện đã parse từ stream chat: hoặc là delta text (token mới), hoặc là
/// usage của request, hoặc cả hai (chunk cuối của một số server).
class AiChatStreamChunk {
  final String? deltaContent;
  final AiChatUsage? usage;
  const AiChatStreamChunk({this.deltaContent, this.usage});
}

/// Parser SSE cho chuẩn OpenAI chat-completions — THUẦN logic (không network)
/// để test được với fixture thật.
///
/// Xử lý đúng các trường hợp gặp ngoài đời:
/// * chunk mạng cắt giữa dòng / giữa ký tự đa byte (caller feed text đã decode
///   UTF-8 an toàn bằng `Stream.transform(utf8.decoder)`).
/// * `data: {...}` và `data:{...}` (có/không space).
/// * event nhiều dòng `data:` (nối bằng \n theo chuẩn SSE).
/// * `data: [DONE]` → `isDone = true`.
/// * dòng comment/keep-alive `: ping` → bỏ qua.
/// * chunk chỉ có `usage` (choices rỗng — OpenAI include_usage), `usage` /
///   `x_groq.usage` ở chunk cuối (Ollama, Groq).
/// * JSON hỏng của 1 event → bỏ qua event đó, không chết cả stream.
class AiSseChatParser {
  final List<String> _pendingDataLines = <String>[];
  String _lineRemainder = '';
  bool _done = false;

  bool get isDone => _done;

  /// Nạp 1 đoạn text (có thể cắt giữa dòng) — trả về các chunk hoàn chỉnh
  /// đã parse trong đoạn. Không throw.
  List<AiChatStreamChunk> feed(String text) {
    final out = <AiChatStreamChunk>[];
    var content = _lineRemainder + text;
    while (true) {
      final nl = content.indexOf('\n');
      if (nl < 0) break;
      var line = content.substring(0, nl);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      _feedLine(line, out);
      content = content.substring(nl + 1);
    }
    _lineRemainder = content;
    return out;
  }

  /// Kết thúc stream — xử lý nốt dòng cuối chưa có newline (một số server
  /// đóng socket ngay sau `data: [DONE]` không kèm newline).
  List<AiChatStreamChunk> close() {
    final out = <AiChatStreamChunk>[];
    final rest = _lineRemainder;
    _lineRemainder = '';
    if (rest.isNotEmpty) {
      var line = rest;
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      _feedLine(line, out);
    }
    // Event cuối chưa kết thúc bằng blank line.
    out.addAll(_flushEvent());
    return out;
  }

  void _feedLine(String line, List<AiChatStreamChunk> out) {
    if (line.isEmpty) {
      // Blank line = kết thúc 1 event SSE.
      out.addAll(_flushEvent());
      return;
    }
    if (line.startsWith(':')) return; // comment / keep-alive
    if (line.startsWith('data:')) {
      var payload = line.substring('data:'.length);
      if (payload.startsWith(' ')) payload = payload.substring(1);
      _pendingDataLines.add(payload);
    }
    // Các field SSE khác (event:, id:, retry:) — chat-completions không dùng.
  }

  List<AiChatStreamChunk> _flushEvent() {
    if (_pendingDataLines.isEmpty) return const <AiChatStreamChunk>[];
    final data = _pendingDataLines.join('\n');
    _pendingDataLines.clear();
    if (data.trim() == '[DONE]') {
      _done = true;
      return const <AiChatStreamChunk>[];
    }
    final chunk = AiSseChatParser.parseChunkBody(data);
    if (chunk == null) return const <AiChatStreamChunk>[];
    return <AiChatStreamChunk>[chunk];
  }

  /// Parse body 1 event `data:` (JSON chuẩn OpenAI chunk). Public-static cho
  /// test trực tiếp bằng fixture thật.
  static AiChatStreamChunk? parseChunkBody(String data) {
    dynamic decoded;
    try {
      decoded = _decodeJson(data);
    } catch (_) {
      return null; // event hỏng — bỏ qua, không chết stream.
    }
    if (decoded is! Map) return null;

    String? delta;
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices[0];
      if (first is Map) {
        final deltaMap = first['delta'];
        if (deltaMap is Map) {
          final content = deltaMap['content'];
          if (content is String && content.isNotEmpty) delta = content;
        }
        // Legacy completions API (`text`) — một số server compat còn dùng.
        if (delta == null) {
          final text = first['text'];
          if (text is String && text.isNotEmpty) delta = text;
        }
      }
    }

    AiChatUsage? usage;
    dynamic rawUsage = decoded['usage'];
    if (rawUsage == null) {
      // Groq gửi usage trong `x_groq.usage` ở chunk cuối.
      final xGroq = decoded['x_groq'];
      if (xGroq is Map) rawUsage = xGroq['usage'];
    }
    if (rawUsage is Map) {
      usage = _usageFrom(rawUsage);
    }

    if (delta == null && usage == null) return null;
    return AiChatStreamChunk(deltaContent: delta, usage: usage);
  }

  static AiChatUsage? _usageFrom(Map raw) {
    final prompt = raw['prompt_tokens'] ?? raw['promptTokens'] ?? raw['input_tokens'];
    final completion =
        raw['completion_tokens'] ?? raw['completionTokens'] ?? raw['output_tokens'];
    final total = raw['total_tokens'] ?? raw['totalTokens'];
    if (prompt is! int || completion is! int) return null;
    return AiChatUsage(
      promptTokens: prompt,
      completionTokens: completion,
      totalTokens: total is int ? total : null,
    );
  }

  static dynamic _decodeJson(String data) {
    // BOM đôi khi kèm theo chunk đầu.
    var body = data;
    if (body.startsWith('\uFEFF')) body = body.substring(1);
    return jsonDecode(body);
  }
}
