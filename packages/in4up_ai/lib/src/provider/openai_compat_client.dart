// packages/in4up_ai/lib/src/provider/openai_compat_client.dart
//
// WP0 (API-001) — Client HTTP duy nhất cho chuẩn OpenAI-compatible.
//
// 1 client chạy được với: OpenAI, Groq, OpenRouter, Google Gemini (lớp
// compat), Ollama, LM Studio, llama-server, Speaches, Kokoro, LocalAI…
// — chỉ khác baseUrl + apiKey + tên model.
//
// WP0 chỉ cần healthCheck + listModels; WP1/2/4 THÊM method vào đúng
// client này (chatStream, transcribeAudio, synthesizeSpeech) — không tạo
// client thứ 2.
//
// Bảo mật (ADR-0007):
// - http:// cleartext CHỈ chấp nhận host LAN/localhost — key cloud tuyệt
//   đối không đi qua http công cộng.
// - KHÔNG log key / headers.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Mã lỗi cấu trúc — UI phân nhánh theo mã, không match chuỗi
/// (cùng khuôn mẫu HyMtErrorCode).
enum AiApiErrorCode {
  /// Không có kết nối mạng.
  noNetwork,

  /// Hết thời gian chờ (connect/health 5s).
  timeout,

  /// 401/403 — sai hoặc thiếu API key.
  unauthorized,

  /// 429 — rate limit (caller tự backoff, tối đa retry 1 lần).
  rateLimited,

  /// Lỗi HTTP khác (5xx, 4xx khác).
  httpError,

  /// Response không parse được (không phải JSON chuẩn OpenAI).
  invalidResponse,

  /// baseUrl http:// nhưng host không phải LAN/localhost → chặn.
  cleartextBlocked,

  /// baseUrl rỗng/sai format.
  invalidBaseUrl,
}

class AiApiException implements Exception {
  final AiApiErrorCode code;
  final String message;
  final int? statusCode;
  const AiApiException(this.code, this.message, {this.statusCode});

  @override
  String toString() => 'AiApiException($code): $message';
}

/// 1 tin nhắn chat completions (role + content) — đủ cho caller tầng API
/// (WP3 dịch: system + user). KHÔNG tái dùng `ChatMessage` của UI (id/
/// createdAt/isError không thuộc tầng này).
class OpenAiChatMessage {
  /// 'system' | 'user' | 'assistant'
  final String role;
  final String content;
  const OpenAiChatMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Kết quả kiểm tra kết nối.
class AiProviderHealth {
  final bool ok;
  final Duration latency;
  final int? modelCount;
  final AiApiException? error;
  const AiProviderHealth({
    required this.ok,
    this.latency = Duration.zero,
    this.modelCount,
    this.error,
  });
}

class OpenAiCompatClient {
  final String baseUrl;
  final String? apiKey;
  final http.Client _httpClient;

  static const _healthTimeout = Duration(seconds: 5);
  static const _listTimeout = Duration(seconds: 15);

  OpenAiCompatClient({
    required this.baseUrl,
    this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Chuẩn hoá: bỏ trailing '/', thêm '/v1' nếu user nhập baseUrl gốc
  /// (vd `http://192.168.1.10:11434` → `http://192.168.1.10:11434/v1`).
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return url;
    if (!url.endsWith('/v1')) {
      final schemeEnd = url.indexOf('://');
      final pathStart = schemeEnd >= 0 ? url.indexOf('/', schemeEnd + 3) : -1;
      final hasPath = pathStart >= 0 && pathStart < url.length - 1;
      if (!hasPath) {
        url = '$url/v1';
      }
    }
    return url;
  }

  /// Guard cleartext: http:// chỉ cho host nội bộ (IP riêng, localhost,
  /// hostname không dấu chấm kiểu `deskpc`). https:// luôn OK.
  static bool isCleartextAllowed(Uri uri) {
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;
    final host = uri.host;
    if (host.isEmpty) return false;
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    // Hostname không có dấu chấm (máy trong LAN đặt tên ngắn).
    if (!host.contains('.')) return true;
    // IP riêng RFC1918 + link-local.
    final parts = host.split('.');
    if (parts.length == 4) {
      final octets = parts.map((p) => int.tryParse(p)).toList();
      if (octets.every((o) => o != null && o! >= 0 && o <= 255)) {
        final a = octets[0]!, b = octets[1]!;
        if (a == 10 || a == 192 && b == 168 || a == 172 && b >= 16 && b <= 31) {
          return true;
        }
        if (a == 169 && b == 254) return true;
      }
    }
    // Tên máy trong LAN có đuôi `.local` / `.lan` / `.internal` / `.home`.
    final tld = host.substring(host.lastIndexOf('.') + 1).toLowerCase();
    return tld == 'local' || tld == 'lan' || tld == 'internal' || tld == 'home';
  }

  Uri _uri(String path) {
    final normalized = normalizeBaseUrl(baseUrl);
    return Uri.parse('$normalized$path');
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      };

  void _validateBase() {
    final normalized = normalizeBaseUrl(baseUrl);
    if (normalized.isEmpty) {
      throw const AiApiException(
          AiApiErrorCode.invalidBaseUrl, 'Base URL is empty');
    }
    Uri uri;
    try {
      uri = Uri.parse(normalized);
    } catch (e) {
      throw AiApiException(
          AiApiErrorCode.invalidBaseUrl, 'Invalid base URL: $e');
    }
    if (!isCleartextAllowed(uri)) {
      throw const AiApiException(
          AiApiErrorCode.cleartextBlocked,
          'Plain http is only allowed for LAN/localhost — use https for '
          'public servers (API key would travel unencrypted)');
    }
  }

  /// GET /v1/models — dùng cho nút "Kiểm tra kết nối" (timeout ngắn 5s).
  ///
  /// KHÔNG bao giờ throw — mọi nhánh lỗi trả về [AiProviderHealth] với
  /// [AiApiException] tương ứng (UI hiển thị mã lỗi cấu trúc).
  Future<AiProviderHealth> healthCheck() async {
    final sw = Stopwatch()..start();
    try {
      _validateBase();
      final response = await _httpClient
          .get(_uri('/models'), headers: _headers())
          .timeout(_healthTimeout);
      sw.stop();
      if (response.statusCode == 401 || response.statusCode == 403) {
        return AiProviderHealth(
            ok: false,
            error: AiApiException(AiApiErrorCode.unauthorized,
                'Unauthorized (HTTP ${response.statusCode}) — check API key',
                statusCode: response.statusCode));
      }
      if (response.statusCode == 429) {
        return AiProviderHealth(
            ok: false,
            error: const AiApiException(
                AiApiErrorCode.rateLimited, 'Rate limited (HTTP 429)',
                statusCode: 429));
      }
      if (response.statusCode != 200) {
        return AiProviderHealth(
            ok: false,
            error: AiApiException(AiApiErrorCode.httpError,
                'HTTP ${response.statusCode}',
                statusCode: response.statusCode));
      }
      final models = _parseModels(response.body);
      return AiProviderHealth(
          ok: true, latency: sw.elapsed, modelCount: models.length);
    } on AiApiException catch (e) {
      return AiProviderHealth(ok: false, error: e);
    } on TimeoutException {
      return AiProviderHealth(
          ok: false,
          error: const AiApiException(
              AiApiErrorCode.timeout, 'Timed out after 5s'));
    } on http.ClientException catch (e) {
      return AiProviderHealth(
          ok: false,
          error: AiApiException(AiApiErrorCode.noNetwork, e.message));
    } catch (e) {
      return AiProviderHealth(
          ok: false,
          error: AiApiException(
              AiApiErrorCode.invalidResponse, 'Unexpected error: $e'));
    }
  }

  /// GET /v1/models → danh sách id model (dropdown chọn model trong UI).
  Future<List<String>> listModels() async {
    _validateBase();
    try {
      final response = await _httpClient
          .get(_uri('/models'), headers: _headers())
          .timeout(_listTimeout);
      if (response.statusCode != 200) {
        throw AiApiException(AiApiErrorCode.httpError,
            'HTTP ${response.statusCode} loading models',
            statusCode: response.statusCode);
      }
      return _parseModels(response.body);
    } on AiApiException {
      rethrow;
    } on TimeoutException {
      throw const AiApiException(
          AiApiErrorCode.timeout, 'Timed out loading models');
    } on http.ClientException catch (e) {
      throw AiApiException(AiApiErrorCode.noNetwork, e.message);
    } catch (e) {
      throw AiApiException(
          AiApiErrorCode.invalidResponse, 'Cannot parse model list: $e');
    }
  }

  /// Parse body chuẩn OpenAI: {"data": [{"id": "model-name", …}, …]}.
  /// Một số server (Ollama) trả thêm các field khác — chỉ đọc `data[].id`.
  List<String> _parseModels(String body) {
    return const OpenAiModelsParser().parse(body);
  }

  @visibleForTesting
  static List<String> parseModelsBody(String body) =>
      const OpenAiModelsParser().parse(body);

  /// POST /v1/chat/completions (KHÔNG stream) — WP3 (API-004) dịch bằng LLM.
  ///
  /// Trả về text content của trợ lý (`choices[0].message.content`).
  /// Mọi nhánh lỗi throw [AiApiException] mã cấu trúc — caller map sang
  /// errorCode của mình, không match chuỗi.
  ///
  /// Timeout mặc định 90s: dịch 1 chunk ~2000 ký tự cần hữu hạn nhưng
  /// thoáng hơn health/list (model chậm trên server nhà vẫn kịp trả).
  Future<String> chatCompletion({
    required String model,
    required List<OpenAiChatMessage> messages,
    double? temperature,
    int? maxTokens,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    _validateBase();
    final body = <String, dynamic>{
      'model': model,
      'messages': [for (final m in messages) m.toJson()],
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };
    http.Response response;
    try {
      response = await _httpClient
          .post(_uri('/chat/completions'),
              headers: _headers(), body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw AiApiException(AiApiErrorCode.timeout,
          'Chat completion timed out after ${timeout.inSeconds}s');
    } on http.ClientException catch (e) {
      throw AiApiException(AiApiErrorCode.noNetwork, e.message);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AiApiException(AiApiErrorCode.unauthorized,
          'Unauthorized (HTTP ${response.statusCode}) — check API key',
          statusCode: response.statusCode);
    }
    if (response.statusCode == 429) {
      throw const AiApiException(
          AiApiErrorCode.rateLimited, 'Rate limited (HTTP 429)',
          statusCode: 429);
    }
    if (response.statusCode != 200) {
      throw AiApiException(AiApiErrorCode.httpError,
          'HTTP ${response.statusCode} from chat completions',
          statusCode: response.statusCode);
    }
    return parseChatContent(response.body);
  }

  /// Parse body /v1/chat/completions → content text của trợ lý.
  ///
  /// Chấp nhận: `choices[0].message.content` là String; content là List
  /// parts (một số lớp compat trả kiểu vision) — ghép phần text; biến thể
  /// legacy `choices[0].text`. Sai cấu trúc → [AiApiErrorCode.invalidResponse].
  static String parseChatContent(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const AiApiException(
          AiApiErrorCode.invalidResponse, 'Chat completion body is not JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiApiException(AiApiErrorCode.invalidResponse,
          'Chat completion body is not a JSON object');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiApiException(AiApiErrorCode.invalidResponse,
          'Chat completion has no "choices"');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const AiApiException(
          AiApiErrorCode.invalidResponse, 'Choice #0 is not an object');
    }
    final message = first['message'];
    String? content;
    if (message is Map) {
      content = _contentToString(message['content']);
    }
    content ??= _contentToString(first['text']);
    if (content == null || content.isEmpty) {
      throw const AiApiException(
          AiApiErrorCode.invalidResponse, 'Chat completion has no content');
    }
    return content;
  }

  static String? _contentToString(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map) {
          final text = part['text'] ?? part['content'];
          if (text is String) buffer.write(text);
        } else if (part is String) {
          buffer.write(part);
        }
      }
      final joined = buffer.toString();
      return joined.isEmpty ? null : joined;
    }
    return null;
  }
}

/// Tách riêng để test thuần (không cần network).
class OpenAiModelsParser {
  const OpenAiModelsParser();

  List<String> parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const AiApiException(
          AiApiErrorCode.invalidResponse, 'Model list is not a JSON object');
    }
    final data = decoded['data'];
    if (data is! List) {
      // Gemini compat trả {models:[…]} — chấp nhận cả 2 khoá.
      final alt = decoded['models'];
      if (alt is List) {
        return _idsFrom(alt);
      }
      throw const AiApiException(AiApiErrorCode.invalidResponse,
          'Model list has no "data" array');
    }
    return _idsFrom(data);
  }

  List<String> _idsFrom(List list) {
    final ids = <String>[];
    for (final item in list) {
      if (item is Map<String, dynamic> && item['id'] is String) {
        final id = item['id'] as String;
        if (id.isNotEmpty) ids.add(id);
      }
    }
    ids.sort();
    return ids;
  }
}
