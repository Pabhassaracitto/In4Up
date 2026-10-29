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
// Bảo mật (ADR-0008):
// - http:// cleartext CHỈ chấp nhận host LAN/localhost — key cloud tuyệt
//   đối không đi qua http công cộng.
// - KHÔNG log key / headers.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_sse.dart';
import 'ai_transcription.dart';

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

  /// WP4 (API-005): request TTS sinh audio có thể chậm (model lớn, box LAN
  /// yếu) → timeout ngầm định rộng hơn health/list; engine tự siết nếu cần.
  static const _speechTimeout = Duration(seconds: 60);
  static const _voicesTimeout = Duration(seconds: 5);

  /// Payload audio tối thiểu hợp lệ — response nhỏ hơn mức này gần như là
  /// trang lỗi/JSON lỗi, không phải audio (guard, test được).
  static const minSpeechBytes = 100;

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

  // ────────────────────────────────────────────────────────────────
  // WP4 (API-005) — TTS qua /v1/audio/speech (+ /v1/audio/voices nếu có)
  // ────────────────────────────────────────────────────────────────

  /// POST /v1/audio/speech → audio bytes (mặc định mp3).
  ///
  /// Đọc response theo STREAM (không buffer text) vì payload là binary và có
  /// thể lớn; không log body/headers (luật bảo mật tầng API).
  ///
  /// Throw [AiApiException] mã cấu trúc: unauthorized (401/403), rateLimited
  /// (429), httpError (khác kèm status + mô tả lỗi của server nếu có),
  /// timeout, noNetwork, invalidResponse (payload quá nhỏ — nghi trang lỗi).
  Future<Uint8List> synthesizeSpeech({
    required String model,
    required String input,
    String voice = 'alloy',
    double speed = 1.0,
    String responseFormat = 'mp3',
    Duration timeout = _speechTimeout,
  }) async {
    _validateBase();
    final request = http.Request('POST', _uri('/audio/speech'))
      ..headers.addAll(_headers())
      ..body = jsonEncode(<String, dynamic>{
        'model': model,
        'input': input,
        'voice': voice,
        'response_format': responseFormat,
        'speed': speed,
      });

    http.StreamedResponse response;
    final body = BytesBuilder(copy: false);
    try {
      response = await _httpClient.send(request).timeout(timeout);
      await response.stream.forEach(body.add).timeout(timeout);
    } on TimeoutException {
      throw AiApiException(AiApiErrorCode.timeout,
          'Speech request timed out after ${timeout.inSeconds}s (model: $model)');
    } on http.ClientException catch (e) {
      throw AiApiException(AiApiErrorCode.noNetwork, e.message);
    }

    final status = response.statusCode;
    final bytes = body.takeBytes();
    if (status == 200) {
      if (bytes.length < minSpeechBytes) {
        throw AiApiException(AiApiErrorCode.invalidResponse,
            'Speech payload too small (${bytes.length} B) — likely not audio');
      }
      return bytes;
    }

    // Lỗi: gỡ mô tả ngắn từ body server (nếu có) — nhiều server trả
    // {"error": {"message": "..."}} hoặc text thường; KHÔNG log ra debug.
    final detail = _errorSnippet(bytes);
    final suffix = detail.isEmpty ? '' : ': $detail';
    if (status == 401 || status == 403) {
      throw AiApiException(
          AiApiErrorCode.unauthorized, 'Unauthorized (HTTP $status)$suffix',
          statusCode: status);
    }
    if (status == 429) {
      throw AiApiException(
          AiApiErrorCode.rateLimited, 'Rate limited (HTTP 429)$suffix',
          statusCode: 429);
    }
    throw AiApiException(AiApiErrorCode.httpError, 'HTTP $status$suffix',
        statusCode: status);
  }

  /// GET /v1/audio/voices — endpoint KHÔNG bắt buộc của chuẩn
  /// (Kokoro-FastAPI/Speaches có, OpenAI cloud không): throw [AiApiException]
  /// khi server không có/lỗi — caller tự fallback list mặc định.
  Future<List<String>> listVoices() async {
    _validateBase();
    try {
      final response = await _httpClient
          .get(_uri('/audio/voices'), headers: _headers())
          .timeout(_voicesTimeout);
      if (response.statusCode != 200) {
        throw AiApiException(AiApiErrorCode.httpError,
            'HTTP ${response.statusCode} loading voices',
            statusCode: response.statusCode);
      }
      return const OpenAiVoicesParser().parse(response.body);
    } on AiApiException {
      rethrow;
    } on TimeoutException {
      throw const AiApiException(
          AiApiErrorCode.timeout, 'Timed out loading voices');
    } on http.ClientException catch (e) {
      throw AiApiException(AiApiErrorCode.noNetwork, e.message);
    } catch (e) {
      throw AiApiException(
          AiApiErrorCode.invalidResponse, 'Cannot parse voices list: $e');
    }
  }

  /// Gỡ mô tả lỗi ngắn gọn từ body server (tối đa 160 ký tự, tolerant với
  /// body không phải JSON/UTF-8 đúng chuẩn).
  static String _errorSnippet(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.isEmpty) return '';
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          return _clip(error['message'] as String);
        }
        if (decoded['message'] is String) {
          return _clip(decoded['message'] as String);
        }
      }
    } catch (_) {
      // Không phải JSON — dùng text thô.
    }
    return _clip(text);
  }

  static String _clip(String s) =>
      s.length <= 160 ? s : '${s.substring(0, 157)}...';

  @visibleForTesting
  static List<String> parseVoicesBody(String body) =>
      const OpenAiVoicesParser().parse(body);

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

  // ── WP2 (API-003): /v1/audio/transcriptions (multipart upload) ──

  static const _transcribeBackoff = Duration(seconds: 2);
  static const _transcribeDefaultTimeout = Duration(minutes: 10);

  /// POST `/v1/audio/transcriptions` — upload file audio (multipart) lên
  /// server OpenAI-compatible (OpenAI/Groq/Speaches/whisper-server).
  ///
  /// Dùng `http.MultipartRequest` của chính `package:http` (client duy nhất
  /// từ WP0) — KHÔNG thêm dio chỉ vì multipart: `MultipartFile.fromPath`
  /// stream file từ đĩa, không load cả file vào RAM; test được bằng
  /// `MockClient.streaming` như mọi method khác.
  ///
  /// Contract:
  /// * `response_format: verbose_json` để có `segments[].start/end` (LRC
  ///   karaoke timestamps) + `words` nếu server trả ( KHÔNG fake nếu thiếu).
  /// * Timeout hữu hạn cho toàn bộ request (default 10 phút — whisper
  ///   large-v3 xử lý file 30–60 phút có thể lâu).
  /// * 429/5xx ⇒ backoff (header `Retry-After` nếu có, ngược lại 2s) rồi
  ///   retry ĐÚNG 1 lần — hết lần 2 vẫn lỗi thì throw [AiApiException].
  /// * Server 200 nhưng `text` rỗng ⇒ lỗi `invalidResponse` — không bao giờ
  ///   fake success (chuỗi rỗng ≠ xong).
  /// * Không log key / headers.
  Future<AiTranscription> transcribeAudio({
    required String filePath,
    required String model,
    String? language,
    String filename = 'audio.wav',
    Duration responseTimeout = _transcribeDefaultTimeout,
  }) async {
    _validateBase();
    return _transcribeWithRetry(
      filePath: filePath,
      model: model,
      language: language,
      filename: filename,
      responseTimeout: responseTimeout,
    );
  }

  Future<AiTranscription> _transcribeWithRetry({
    required String filePath,
    required String model,
    required String? language,
    required String filename,
    required Duration responseTimeout,
  }) async {
    http.StreamedResponse? response;
    try {
      response = await _sendMultipartTranscription(
        filePath: filePath,
        model: model,
        language: language,
        filename: filename,
        responseTimeout: responseTimeout,
      );
      if ((response.statusCode == 429 || response.statusCode >= 500) &&
          response.statusCode < 600) {
        // Drain body của response lỗi (nhỏ) để không giữ socket, rồi
        // backoff: Retry-After (giây) nếu server báo, ngược lại 2s.
        try {
          await response.stream.drain<void>();
        } catch (_) {}
        var wait = _transcribeBackoff;
        final retryAfter = response.headers['retry-after'] ??
            response.headers['Retry-After'];
        final parsed = retryAfter == null ? null : int.tryParse(retryAfter);
        if (parsed != null && parsed > 0 && parsed <= 30) {
          wait = Duration(seconds: parsed);
        }
        await Future<void>.delayed(wait);
        response = await _sendMultipartTranscription(
          filePath: filePath,
          model: model,
          language: language,
          filename: filename,
          responseTimeout: responseTimeout,
        );
      }
      final bodyText = await response.stream
          .fold<List<int>>(<int>[], (acc, d) => acc..addAll(d))
          .timeout(const Duration(seconds: 30));
      final text = utf8.decode(bodyText, allowMalformed: true);
      if (response.statusCode != 200) {
        throw AiApiException(
          response.statusCode == 429
              ? AiApiErrorCode.rateLimited
              : response.statusCode == 401 || response.statusCode == 403
                  ? AiApiErrorCode.unauthorized
                  : AiApiErrorCode.httpError,
          'HTTP ${response.statusCode}${_serverErrorMessage(text)}',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const AiApiException(
            AiApiErrorCode.invalidResponse, 'Transcription body is not JSON');
      }
      final result = AiTranscription.fromJson(decoded);
      if (result.text.isEmpty && result.segments.isEmpty) {
        // 200 nhưng rỗng — thất bại thật, không fake success.
        throw const AiApiException(AiApiErrorCode.invalidResponse,
            'Server trả transcript rỗng (200 nhưng không có text/segments)');
      }
      return result;
    } on AiApiException {
      rethrow;
    } on TimeoutException {
      // KHÔNG const — nội suy responseTimeout (tham số) không hợp lệ trong
      // const context.
      throw AiApiException(
          AiApiErrorCode.timeout,
          'Transcription timed out after '
          '${responseTimeout.inMinutes} min');
    } on http.ClientException catch (e) {
      throw AiApiException(AiApiErrorCode.noNetwork, e.message);
    } catch (e) {
      throw AiApiException(
          AiApiErrorCode.invalidResponse, 'Cannot parse transcription: $e');
    }
  }

  Future<http.StreamedResponse> _sendMultipartTranscription({
    required String filePath,
    required String model,
    required String? language,
    required String filename,
    required Duration responseTimeout,
  }) async {
    final uri = _uri('/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      // CHỈ Authorization — KHÔNG tự đặt Content-Type: multipart cần
      // boundary do request tự sinh (`_headers()` sẽ sai vì có JSON type).
      ..fields['model'] = model
      ..fields['response_format'] = 'verbose_json'
      ..fields['temperature'] = '0';
    if (apiKey != null && apiKey!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
    // 'auto' KHÔNG phải mã ISO hợp lệ — omit field để server tự detect
    // (OpenAI/Groq sẽ từ chối nếu gửi chuỗi lạ).
    final lang = language == null || language.isEmpty || language == 'auto'
        ? null
        : language;
    if (lang != null) {
      request.fields['language'] = lang;
    }
    // fromPath là async — stream file từ đĩa, không load RAM cả file.
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      filePath,
      filename: filename,
      contentType: http.MediaType('audio', 'wav'),
    ));
    return _httpClient.send(request).timeout(responseTimeout);
  }

  // ── WP1 (API-002): /v1/chat/completions streaming (SSE) ──

  static const _chatConnectTimeout = Duration(seconds: 15);
  static const _chatIdleTimeout = Duration(seconds: 60);
  static const _chatErrorBodyTimeout = Duration(seconds: 10);

  /// POST `/v1/chat/completions` với `stream: true` — đọc SSE từng event
  /// (delta `choices[0].delta.content`, `data: [DONE]`, `usage` ở chunk cuối
  /// nếu server gửi).
  ///
  /// Cơ chế stream: `http.Client.send()` trả `StreamedResponse` — response
  /// byte stream (tương đương dio `ResponseType.stream`, nhưng giữ đúng 1
  /// client duy nhất của WP0 và test được bằng `MockClient.streaming` — không
  /// thêm dependency mới; dio chỉ cần cho multipart WP2).
  ///
  /// Contract:
  /// * Không throw từ chính hàm này (base URL hỏng cũng trả qua error của
  ///   stream) — caller `await for` và xử lý [AiChatException] theo MÃ.
  /// * [cancelToken.cancel()] ⇒ đóng socket ngay (cancel subscription của
  ///   response stream), stream kết thúc bằng lỗi `canceled` — token không
  ///   "chảy tiếp" sau khi bị hủy.
  /// * [idleTimeout]: quá lâu không có byte mới (kể cả chờ token đầu) ⇒
  ///   lỗi `timeout` — mọi thời gian chờ đều hữu hạn.
  /// * Mạng đứt giữa chừng (socket reset) ⇒ lỗi `noNetwork`, stream dừng
  ///   sạch — không treo, không crash.
  Stream<AiChatStreamChunk> chatStream({
    required String model,
    required List<AiChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool includeUsage = false,
    AiChatCancelToken? cancelToken,
    Duration idleTimeout = _chatIdleTimeout,
  }) {
    final controller = StreamController<AiChatStreamChunk>();
    controller.onListen = () {
      unawaited(_runChatStream(
        controller,
        model: model,
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
        includeUsage: includeUsage,
        cancelToken: cancelToken,
        idleTimeout: idleTimeout,
      ));
    };
    return controller.stream;
  }

  Future<void> _runChatStream(
    StreamController<AiChatStreamChunk> controller, {
    required String model,
    required List<AiChatMessage> messages,
    required double temperature,
    required int? maxTokens,
    required bool includeUsage,
    required AiChatCancelToken? cancelToken,
    required Duration idleTimeout,
  }) async {
    StreamSubscription<String>? responseSub;
    Timer? idleTimer;
    var closed = false;

    // Downstream hủy subscription (await-for break / listener cancel) ⇒ hủy
    // request NGAY — không cho stream chảy nền sau khi không còn ai nghe.
    controller.onCancel = () async {
      closed = true;
      idleTimer?.cancel();
      await responseSub?.cancel();
    };

    void finishWithError(AiChatException error) {
      if (closed || controller.isClosed) return;
      closed = true;
      controller.addError(error);
      controller.close();
    }

    Future<void> abort(AiChatException error) async {
      idleTimer?.cancel();
      // Đóng socket (cancel subscription của response stream) — không token
      // nào chảy tiếp sau khi hủy. Callback cancel tới muộn (sau khi stream
      // đã xong) là no-op nhờ guard `closed`.
      await responseSub?.cancel();
      finishWithError(error);
    }

    try {
      // Base URL hỏng/chặn cleartext — trả lỗi cấu trúc thay vì throw ra
      // caller (contract phía trên).
      try {
        _validateBase();
      } on AiApiException catch (e) {
        finishWithError(AiChatException.fromApi(e));
        return;
      }

      final request = http.Request('POST', _uri('/chat/completions'))
        ..headers.addAll(_headers())
        ..body = jsonEncode({
          'model': model,
          'messages': [for (final m in messages) m.toJson()],
          'stream': true,
          'temperature': temperature,
          if (maxTokens != null && maxTokens > 0) 'max_tokens': maxTokens,
          if (includeUsage)
            'stream_options': const {'include_usage': true},
        });

      final response =
          await _httpClient.send(request).timeout(_chatConnectTimeout);

      if (closed) {
        // Bị cancel trong lúc chờ kết nối — đóng luôn socket vừa mở.
        unawaited(response.stream.listen(null).cancel());
        return;
      }

      if (response.statusCode != 200) {
        // Đọc body lỗi (JSON error của server) rồi map sang mã cấu trúc.
        String bodyText = '';
        try {
          final bytes = await response.stream
              .fold<List<int>>(<int>[], (acc, d) => acc..addAll(d))
              .timeout(_chatErrorBodyTimeout);
          bodyText = utf8.decode(bytes, allowMalformed: true);
        } catch (_) {}
        finishWithError(_mapStatusError(response.statusCode, bodyText));
        return;
      }

      final parser = AiSseChatParser();

      void onText(String text) {
        idleTimer?.cancel();
        idleTimer = Timer(idleTimeout, () {
          unawaited(abort(AiChatException(AiChatErrorCode.timeout,
              'Không nhận được dữ liệu mới trong ${idleTimeout.inSeconds}s')));
        });
        for (final chunk in parser.feed(text)) {
          if (!closed && !controller.isClosed) controller.add(chunk);
        }
        if (parser.isDone && !closed && !controller.isClosed) {
          closed = true;
          idleTimer?.cancel();
          controller.close();
          // Server có thể giữ socket mở sau `data: [DONE]` — đóng luôn để
          // không chờ idle timeout.
          unawaited(responseSub?.cancel());
        }
      }

      idleTimer = Timer(idleTimeout, () {
        unawaited(abort(AiChatException(AiChatErrorCode.timeout,
            'Không nhận được token đầu tiên trong ${idleTimeout.inSeconds}s')));
      });

      if (cancelToken != null) {
        if (cancelToken.isCancelled) {
          await abort(AiChatException(
              AiChatErrorCode.canceled, cancelToken.reason ?? 'canceled'));
          return;
        }
        // Theo dõi token hủy: cancel giữa chừng ⇒ abort ngay (kể cả khi đang
        // chờ token tiếp theo mà chưa có byte mới). Callback tới muộn sau khi
        // stream đã kết thúc là no-op (guard `closed` trong abort).
        unawaited(cancelToken.whenCancelled.then((_) {
          unawaited(abort(AiChatException(
              AiChatErrorCode.canceled, cancelToken.reason ?? 'canceled')));
        }));
      }

      // utf8.decoder là stream transformer CÓ STATE — xử lý đúng ký tự đa
      // byte (tiếng Việt) bị cắt giữa 2 chunk mạng; cancel subscription này
      // đóng luôn socket bên dưới (không token nào chảy tiếp).
      responseSub = response.stream.transform(utf8.decoder).listen(
        onText,
        onError: (Object e) {
          // Socket reset / mạng đứt giữa chừng — dừng sạch theo mã.
          idleTimer?.cancel();
          finishWithError(AiChatException(
              AiChatErrorCode.noNetwork, 'Kết nối bị đứt giữa chừng: $e'));
        },
        onDone: () {
          idleTimer?.cancel();
          // Server đóng stream (có thể không gửi [DONE] — Ollama cũ).
          for (final chunk in parser.close()) {
            if (!closed && !controller.isClosed) controller.add(chunk);
          }
          if (!closed && !controller.isClosed) {
            closed = true;
            controller.close();
          }
        },
        cancelOnError: true,
      );

      // LƯU Ý (fix bisect B1–B10): KHÔNG `await responseSub.done` ở đây —
      // `StreamSubscription` KHÔNG có getter `done` (đó là của StreamController;
      // subscription chỉ có cancel/onData/onError/onPause/resume/isPaused).
      // Không cần chờ gì thêm: mọi đường ra (onDone, onError, [DONE] trong
      // onText, abort, controller.onCancel) đều đã tự đóng controller — hàm
      // này trả về ngay, stream tiếp tục chạy qua các closure của chính nó.
    } on TimeoutException {
      await abort(
          const AiChatException(AiChatErrorCode.timeout, 'Kết nối quá chậm'));
    } on AiApiException catch (e) {
      await abort(AiChatException.fromApi(e));
    } on http.ClientException catch (e) {
      await abort(AiChatException(AiChatErrorCode.noNetwork, e.message));
    } catch (e) {
      await abort(AiChatException(AiChatErrorCode.invalidResponse, '$e'));
    }
  }

  /// Map HTTP status + body lỗi → [AiChatException] cấu trúc.
  AiChatException _mapStatusError(int statusCode, String bodyText) {
    switch (statusCode) {
      case 429:
        return AiChatException(
            AiChatErrorCode.rateLimited, 'Rate limited (HTTP 429)',
            statusCode: 429);
      case 401:
      case 403:
        return AiChatException(AiChatErrorCode.httpError,
            'Unauthorized (HTTP $statusCode) — kiểm tra API key',
            statusCode: statusCode);
      default:
        return AiChatException(AiChatErrorCode.httpError,
            'HTTP $statusCode${_serverErrorMessage(bodyText)}',
            statusCode: statusCode);
    }
  }

  /// Lấy `error.message` từ body JSON lỗi của server (nếu có) — không lộ key.
  static String _serverErrorMessage(String bodyText) {
    if (bodyText.isEmpty) return '';
    try {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          final msg = error['message'] as String;
          return ': ${msg.length > 200 ? msg.substring(0, 200) : msg}';
        }
      }
    } catch (_) {}
    return '';
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

/// Parser danh sách giọng TTS — tách riêng để test thuần (không cần network).
///
/// WP4 (API-005). Chuẩn OpenAI KHÔNG định nghĩa schema /audio/voices;
/// chấp nhận khoan dung các biến thể gặp thực tế:
/// - Kokoro-FastAPI: `{"voices": ["af_heart", …]}` hoặc `[{"voice": …}]`
/// - OpenAI-ish:     `{"data": [{"id": …}]}` (như /models)
/// - một số fork:    `["af_heart", …]` (top-level list) hoặc key `id`/`name`
class OpenAiVoicesParser {
  const OpenAiVoicesParser();

  List<String> parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) return _idsFrom(decoded);
    if (decoded is Map<String, dynamic>) {
      for (final key in const ['voices', 'data', 'models']) {
        final value = decoded[key];
        if (value is List) return _idsFrom(value);
      }
    }
    throw const AiApiException(
        AiApiErrorCode.invalidResponse, 'Voices list has unknown shape');
  }

  List<String> _idsFrom(List list) {
    final ids = <String>[];
    for (final item in list) {
      if (item is String && item.isNotEmpty) {
        ids.add(item);
      } else if (item is Map<String, dynamic>) {
        for (final key in const ['id', 'voice', 'name']) {
          final value = item[key];
          if (value is String && value.isNotEmpty) {
            ids.add(value);
            break;
          }
        }
      }
    }
    return ids;
  }
}
