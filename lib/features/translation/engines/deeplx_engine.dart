// lib/features/translation/engines/deeplx_engine.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'translation_engine.dart';

/// Kết quả thử kết nối DeepLX — nút "Thử kết nối" trong sheet cài đặt engine.
class DeepLXProbeResult {
  /// Dịch được câu mẫu hay không.
  final bool ok;

  /// Bản dịch của câu mẫu (khi [ok]).
  final String? sample;

  /// Mã HTTP server trả về (`null` = không kết nối được tới server).
  final int? statusCode;

  /// Chi tiết lỗi ngắn gọn (khi `!ok`).
  final String? error;

  /// Thời gian server phản hồi.
  final Duration responseTime;

  const DeepLXProbeResult({
    required this.ok,
    this.sample,
    this.statusCode,
    this.error,
    this.responseTime = Duration.zero,
  });
}

/// DeepLX Engine — self-host hoặc public instance (vd: HF Space).
///
/// Endpoint chuẩn mọi phiên bản DeepLX (OwO-Network giữ từ bản cũ tới
/// v1.2+): `POST {url}` với body `{"text", "source_lang", "target_lang"}` →
/// `{"code": 200, "data": "..."}`. Parser cũng chấp nhận các dạng khác:
/// - `/v2/translate` (giả lập API chính thức DeepL): `translations[0].text`;
/// - wrapper jsonrpc: `result.data` / `result.texts[0].text`.
///
/// XLAT-DEEPLX-001: chuẩn hoá URL (dán host trần → tự nối `/translate`),
/// lỗi hiện rõ status + message của server thay vì mơ hồ.
class DeepLXEngine extends TranslationEngine {
  String serverUrl;

  /// Inject http client cho test (MockClient); mặc định tạo client mới.
  final http.Client _client;

  DeepLXEngine({
    this.serverUrl = 'http://localhost:1188/translate',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'DeepLX';

  @override
  String get id => 'deeplx';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 50);

  /// Chuẩn hoá URL người dùng dán:
  /// - trim + bỏ các "/" thừa cuối;
  /// - nếu CHỈ có host (path rỗng — hay gặp khi dán URL gốc của HF Space)
  ///   → tự nối `/translate`;
  /// - path khác (endpoint riêng, reverse-proxy...) → giữ nguyên;
  /// - giữ nguyên query string (DeepLX hỗ trợ `?token=...`).
  static String normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      // Không phải URL tuyệt đối hợp lệ — trả nguyên bản để caller báo lỗi rõ.
      return trimmed;
    }
    var path = uri.path == '/' ? '' : uri.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) {
      return uri.replace(path: '/translate').toString();
    }
    return uri.replace(path: path).toString();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final base =
          normalizeUrl(serverUrl).replaceAll(RegExp(r'/translate$'), '');
      final response = await _client
          .get(Uri.parse(base))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult.success(
        original: text,
        translated: '',
        engine: name,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _post(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final translated = _extractTranslated(data);

        if (translated != null) {
          return TranslationResult.success(
            original: text,
            translated: translated,
            engine: name,
            responseTime: stopwatch.elapsed,
          );
        }
        return TranslationResult.failure(
          original: text,
          error: 'Empty/unexpected response from DeepLX '
              '(no "data"/"translations" field)',
          engine: name,
        );
      }
      return TranslationResult.failure(
        original: text,
        error: 'HTTP ${response.statusCode}: ${_shortBody(response)}',
        engine: name,
      );
    } catch (e) {
      stopwatch.stop();
      return TranslationResult.failure(
        original: text,
        error: e.toString(),
        engine: name,
      );
    }
  }

  /// Dịch một câu mẫu ngắn để kiểm tra cấu hình (nút "Thử kết nối").
  ///
  /// Ngân sách thời gian dài hơn [translate] (20s) vì cold start của
  /// HF Space có thể mất ~10–20 giây.
  Future<DeepLXProbeResult> probe({
    String text = 'Hello',
    String targetLang = 'VI',
  }) async {
    final endpoint = normalizeUrl(serverUrl);
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return const DeepLXProbeResult(
        ok: false,
        error: 'invalid URL — expected http://host[:port]/…',
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _post(
        text: text,
        sourceLang: 'auto',
        targetLang: targetLang,
        timeout: const Duration(seconds: 20),
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final sample = _extractTranslated(data);
        if (sample != null) {
          return DeepLXProbeResult(
            ok: true,
            sample: sample,
            statusCode: 200,
            responseTime: stopwatch.elapsed,
          );
        }
        return DeepLXProbeResult(
          ok: false,
          statusCode: 200,
          error: 'unexpected response (no "data"/"translations" field)',
          responseTime: stopwatch.elapsed,
        );
      }
      return DeepLXProbeResult(
        ok: false,
        statusCode: response.statusCode,
        error: _shortBody(response),
        responseTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return DeepLXProbeResult(
        ok: false,
        error: e.toString(),
        responseTime: stopwatch.elapsed,
      );
    }
  }

  // ==================== Internals ====================

  Future<http.Response> _post({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
    Duration timeout = const Duration(seconds: 10),
  }) {
    final source = sourceLang.trim();
    return _client
        .post(
          Uri.parse(normalizeUrl(serverUrl)),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            if (source.isNotEmpty) 'source_lang': source,
            'target_lang': targetLang,
          }),
        )
        .timeout(timeout);
  }

  /// Rút câu dịch khỏi các dạng response DeepLX hay gặp:
  /// `/translate` + `/v1/translate`: `{"data": "..."}`;
  /// `/v2/translate` (DeepL chính thức): `{"translations":[{"text": "..."}]}`;
  /// jsonrpc wrapper: `{"result":{"data": "..." | "texts":[{"text": "..."}]}}`.
  static String? _extractTranslated(Object? data) {
    if (data is! Map) return null;

    final direct = data['data'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final translations = data['translations'];
    if (translations is List && translations.isNotEmpty) {
      final first = translations.first;
      if (first is Map) {
        final text = first['text'];
        if (text is String && text.trim().isNotEmpty) return text;
      }
    }

    final result = data['result'];
    if (result is Map) {
      final resultData = result['data'];
      if (resultData is String && resultData.trim().isNotEmpty) {
        return resultData;
      }
      final texts = result['texts'];
      if (texts is List && texts.isNotEmpty) {
        final first = texts.first;
        if (first is Map) {
          final text = first['text'];
          if (text is String && text.trim().isNotEmpty) return text;
        }
      }
    }
    return null;
  }

  /// Body lỗi rút gọn một dòng — ưu tiên trường `message` (DeepLX v1.2+).
  static String _shortBody(http.Response response) {
    var body = utf8
        .decode(response.bodyBytes, allowMalformed: true)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          body = message.trim();
        }
      }
    } catch (_) {}
    if (body.length > 140) body = '${body.substring(0, 140)}…';
    return body.isEmpty ? '(empty body)' : body;
  }
}
