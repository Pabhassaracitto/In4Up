// lib/features/translation/engines/libre_engine.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'translation_engine.dart';

/// LibreTranslate - Mã nguồn mở, có nhiều instance public MIỄN PHÍ
///
/// Danh sách server miễn phí (không cần API key):
///   - https://libretranslate.com         (có thể cần key)
///   - https://lt.vern.cc                 (miễn phí)
///   - https://translate.terraprint.co    (miễn phí)
///   - https://translate.fortytwo.cafe    (miễn phí)
///   - https://translate.argosopentech.com (miễn phí)
///
/// Tự host: docker run -ti --rm -p 5000:5000 libretranslate/libretranslate
class LibreEngine extends TranslationEngine {
  /// Danh sách server miễn phí - sẽ thử lần lượt
  static const List<String> _publicServers = [
    'https://lt.vern.cc',
    'https://translate.terraprint.co',
    'https://translate.fortytwo.cafe',
    'https://translate.argosopentech.com',
    'https://libretranslate.com',
  ];

  /// Server tùy chỉnh (nếu user tự host)
  String? customServerUrl;

  /// Server đang hoạt động (cache lại để lần sau dùng nhanh)
  String? _activeServer;

  /// API key (một số server yêu cầu)
  String? apiKey;

  LibreEngine({this.customServerUrl, this.apiKey});

  @override
  String get name => 'LibreTranslate';

  @override
  String get id => 'libre';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 400);

  // Map ngôn ngữ sang format LibreTranslate
  static const Map<String, String> _langMap = {
    'AR': 'ar',
    'BN': 'bn',
    'BO': 'bo',
    'DE': 'de',
    'EN': 'en',
    'ES': 'es',
    'FR': 'fr',
    'HI': 'hi',
    'ID': 'id',
    'IT': 'it',
    'JA': 'ja',
    'KM': 'km',
    'KO': 'ko',
    'LO': 'lo',
    'MN': 'mn',
    'MR': 'mr',
    'MY': 'my',
    'PT': 'pt',
    'RU': 'ru',
    'SI': 'si',
    'TA': 'ta',
    'TE': 'te',
    'TH': 'th',
    'VI': 'vi',
    'ZH': 'zh',
    'ZH-CN': 'zh',
    'ZH-TW': 'zh',
    'AUTO': 'auto',
  };

  String _mapLang(String lang) {
    return _langMap[lang.toUpperCase()] ?? lang.toLowerCase();
  }

  // ══════════════════════════════════════════
  // FIND WORKING SERVER
  // ══════════════════════════════════════════

  /// Tìm server đang hoạt động
  Future<String?> _findWorkingServer() async {
    // Nếu có custom server, thử nó trước
    if (customServerUrl != null && customServerUrl!.isNotEmpty) {
      if (await _pingServer(customServerUrl!)) {
        return customServerUrl;
      }
    }

    // Nếu đã có server hoạt động từ lần trước, thử lại
    if (_activeServer != null) {
      if (await _pingServer(_activeServer!)) {
        return _activeServer;
      }
      _activeServer = null; // Server cũ đã chết
    }

    // Thử từng server public
    for (final server in _publicServers) {
      debugPrint('🔍 LibreTranslate: Trying $server...');
      if (await _pingServer(server)) {
        debugPrint('✅ LibreTranslate: Found working server: $server');
        _activeServer = server;
        return server;
      }
    }

    debugPrint('❌ LibreTranslate: No working server found');
    return null;
  }

  /// Ping server để kiểm tra
  Future<bool> _pingServer(String serverUrl) async {
    try {
      // LibreTranslate có endpoint /languages để check
      final url = serverUrl.endsWith('/')
          ? '${serverUrl}languages'
          : '$serverUrl/languages';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════
  // IS AVAILABLE
  // ══════════════════════════════════════════

  @override
  Future<bool> isAvailable() async {
    final server = await _findWorkingServer();
    return server != null;
  }

  // ══════════════════════════════════════════
  // TRANSLATE
  // ══════════════════════════════════════════

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

    // Tìm server hoạt động
    final server = await _findWorkingServer();
    if (server == null) {
      return TranslationResult.failure(
        original: text,
        error: 'Không tìm thấy server LibreTranslate nào hoạt động',
        engine: name,
      );
    }

    try {
      final sl = _mapLang(sourceLang);
      final tl = _mapLang(targetLang);

      final translateUrl =
          server.endsWith('/') ? '${server}translate' : '$server/translate';

      // Build request body
      final body = <String, dynamic>{
        'q': text,
        'source': sl,
        'target': tl,
        'format': 'text',
      };

      // Thêm API key nếu có
      if (apiKey != null && apiKey!.isNotEmpty) {
        body['api_key'] = apiKey;
      }

      final response = await http
          .post(
            Uri.parse(translateUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // LibreTranslate response: {"translatedText": "..."}
        final translated = data['translatedText'] as String? ?? '';

        if (translated.isNotEmpty) {
          return TranslationResult.success(
            original: text,
            translated: translated,
            engine: '$name ($server)',
            detectedLang: data['detectedLanguage']?['language'] as String?,
            responseTime: stopwatch.elapsed,
          );
        } else {
          return TranslationResult.failure(
            original: text,
            error: 'Empty response',
            engine: name,
          );
        }
      } else if (response.statusCode == 429) {
        // Rate limited - đánh dấu server này tạm chết
        _activeServer = null;
        return TranslationResult.failure(
          original: text,
          error: 'Rate limited (429) tại $server',
          engine: name,
        );
      } else if (response.statusCode == 403) {
        // Cần API key
        _activeServer = null;
        return TranslationResult.failure(
          original: text,
          error: 'Server $server yêu cầu API key',
          engine: name,
        );
      } else {
        // Lỗi khác - thử server khác lần sau
        _activeServer = null;

        // Parse error message
        String errorMsg = 'HTTP ${response.statusCode}';
        try {
          final errData = jsonDecode(response.body);
          errorMsg = errData['error'] as String? ?? errorMsg;
        } catch (_) {}

        return TranslationResult.failure(
          original: text,
          error: errorMsg,
          engine: name,
        );
      }
    } catch (e) {
      stopwatch.stop();
      // Lỗi kết nối - thử server khác lần sau
      _activeServer = null;
      return TranslationResult.failure(
        original: text,
        error: e.toString(),
        engine: name,
      );
    }
  }

  // ══════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════

  /// Lấy danh sách ngôn ngữ hỗ trợ từ server
  Future<List<String>> getSupportedLanguages() async {
    final server = _activeServer ?? _publicServers.first;
    try {
      final url =
          server.endsWith('/') ? '${server}languages' : '$server/languages';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> languages = jsonDecode(response.body);
        return languages.map((l) => '${l['code']} - ${l['name']}').toList();
      }
    } catch (e) {
      debugPrint('LibreTranslate getSupportedLanguages error: $e');
    }
    return [];
  }

  /// Reset active server (buộc tìm lại)
  void resetServer() {
    _activeServer = null;
  }

  /// Server đang dùng
  String? get activeServer => _activeServer;
}
