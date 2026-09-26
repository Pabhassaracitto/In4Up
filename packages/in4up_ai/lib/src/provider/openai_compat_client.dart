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
import 'dart:typed_data';

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
}

/// Parser danh sách giọng TTS — tách riêng để test thuần (không cần network).
///
/// Chuẩn OpenAI KHÔNG định nghĩa schema /audio/voices; chấp nhận khoan dung
/// các biến thể gặp thực tế:
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
