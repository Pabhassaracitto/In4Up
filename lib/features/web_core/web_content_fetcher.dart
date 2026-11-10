import 'dart:convert';

import 'package:http/http.dart' as http;

import 'web_proxy_config.dart';

class WebContentFetchException implements Exception {
  const WebContentFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fetches a web page through the controlled proxy in production.
class WebContentFetcher {
  WebContentFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get usesProxy => WebProxyConfig.endpoint('/reader') != null;

  bool get isConfigured => usesProxy || WebProxyConfig.allowDirectCors;

  Future<String> fetch(Uri target) async {
    if (target.scheme != 'http' && target.scheme != 'https') {
      throw const WebContentFetchException('Chỉ hỗ trợ URL http/https.');
    }

    final proxy = WebProxyConfig.endpoint(
      '/reader',
      queryParameters: {'url': target.toString()},
    );

    final response = proxy == null
        ? await _directFetch(target)
        : await _client.get(proxy).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebContentFetchException(
        'Không tải được trang (HTTP ${response.statusCode}).',
      );
    }

    if (response.body.trim().isEmpty) {
      throw const WebContentFetchException('Trang không có nội dung.');
    }

    // A proxy may return either plain HTML or {html: ...}/{text: ...} JSON.
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('application/json')) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final value = decoded['html'] ?? decoded['text'] ?? decoded['content'];
          if (value is String && value.trim().isNotEmpty) return value;
        }
      } catch (_) {
        throw const WebContentFetchException(
          'Proxy trả về JSON không hợp lệ.',
        );
      }
    }

    return response.body;
  }

  Future<http.Response> _directFetch(Uri target) async {
    if (!WebProxyConfig.allowDirectCors) {
      throw const WebContentFetchException(
        'Web Reader cần được cấu hình reader proxy để tránh CORS.',
      );
    }

    return _client
        .get(
          target,
          headers: const {'Accept': 'text/html,application/xhtml+xml'},
        )
        .timeout(const Duration(seconds: 15));
  }
}
