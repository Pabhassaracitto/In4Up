// lib/features/vocab_image/vocab_animation_library.dart
//
// VOCAB-MEDIA-003 (ADR-0013) — nguồn thứ 4 của sheet chọn media: duyệt
// THƯ VIỆN ANIMATION (Lottie) + xem trước từng cái trước khi lưu.
//
// Nguồn dữ liệu (đúng triết lý IMG-WEB-001 — không hard-code key bên thứ ba):
//   1. Endpoint CẤU HÌNH ĐƯỢC (prefs `vocab_animation_endpoint` + tùy chọn
//      `vocab_animation_api_key` làm Bearer) — ƯU TIÊN khi user đã set.
//   2. Mặc định: Wikimedia Commons (MediaWiki `filemime:application/json`,
//      KHÔNG cần key) — để app dùng được ngay, không chết khi chưa cấu hình.
// Ô "Dán URL" có sẵn trong sheet vẫn là đường nhập tay từng link.
//
// Không tải gì khi mở app: chỉ tìm khi user MỞ tab Animation và bấm Tìm.
// Kết quả là `VocabWebImage` (tái dùng model tìm ảnh): `imageUrl` = link
// .json/.lottie tải về, `thumbUrl` = ảnh tĩnh xem trước (có thể trùng
// imageUrl nếu nguồn không có preview — tile tự render Lottie khi đó).

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'vocab_image_web_service.dart';

/// Cấu hình nguồn animation (đọc từ SharedPreferences — chỉ trên máy).
class VocabAnimationLibraryConfig {
  /// Endpoint tùy chỉnh (rỗng = dùng mặc định Commons). Không có endpoint
  /// "có key" nào bị hard-code trong repo.
  final String endpoint;

  /// Bearer token cho endpoint tùy chỉnh (rỗng = không gửi).
  final String apiKey;

  const VocabAnimationLibraryConfig({this.endpoint = '', this.apiKey = ''});

  /// true khi user đã cấu hình endpoint riêng (được ưu tiên cao nhất).
  bool get hasCustomEndpoint => endpoint.trim().isNotEmpty;

  /// Nhãn nguồn ngắn gọn cho UI: host của endpoint tùy chỉnh, hoặc
  /// 'Wikimedia Commons' khi dùng mặc định.
  String get sourceLabel {
    final ep = endpoint.trim();
    if (ep.isEmpty) return 'Wikimedia Commons';
    try {
      final host = Uri.parse(ep).host;
      return host.isEmpty ? ep : host;
    } catch (_) {
      return ep;
    }
  }
}

/// Store prefs cho [VocabAnimationLibraryConfig] (theo lối VocabImageApiConfig).
class VocabAnimationApiConfig {
  VocabAnimationApiConfig._();
  static final VocabAnimationApiConfig instance = VocabAnimationApiConfig._();

  static const String endpointKey = 'vocab_animation_endpoint';
  static const String apiKeyKey = 'vocab_animation_api_key';

  SharedPreferences? _prefs;
  VocabAnimationLibraryConfig? _cached;

  Future<SharedPreferences> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Đọc cấu hình (cache trong phiên — mở/đóng sheet không đọc disk lại).
  Future<VocabAnimationLibraryConfig> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await _ensure();
    return _cached = VocabAnimationLibraryConfig(
      endpoint: (prefs.getString(endpointKey) ?? '').trim(),
      apiKey: (prefs.getString(apiKeyKey) ?? '').trim(),
    );
  }

  /// Lưu endpoint + key. Chuỗi rỗng → xoá key khỏi prefs (về mặc định).
  Future<void> save({String? endpoint, String? apiKey}) async {
    final prefs = await _ensure();
    final ep = (endpoint ?? '').trim();
    final key = (apiKey ?? '').trim();
    if (ep.isEmpty) {
      await prefs.remove(endpointKey);
    } else {
      await prefs.setString(endpointKey, ep);
    }
    if (key.isEmpty) {
      await prefs.remove(apiKeyKey);
    } else {
      await prefs.setString(apiKeyKey, key);
    }
    _cached = null;
  }

  /// Chỉ test: dọn cache trong phiên.
  void clearCacheForTest() => _cached = null;
}

/// Client tìm animation Lottie trên mạng cho từ vựng.
class VocabAnimationLibraryService {
  VocabAnimationLibraryService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Nguồn mặc định (không cần key): MediaWiki Commons.
  static const String commonsEndpoint =
      'https://commons.wikimedia.org/w/api.php';

  static const String userAgent = VocabImageWebService.userAgent;

  /// Cache kết quả trong 1 phiên — lật qua lại giữa các từ không gọi API lặp.
  static final Map<String, List<VocabWebImage>> _cache =
      <String, List<VocabWebImage>>{};
  static const int _cacheMax = 40;

  /// Index 100 khái niệm đóng gói offline; đọc JSON một lần trong phiên.
  static Future<String>? _conceptPackFuture;

  /// Lỗi gần nhất (chuỗi ngắn để log/debug — UI tự chọn câu hiển thị).
  String? lastError;

  /// Pure parser/search cho catalog gốc; dùng chung giữa asset runtime và test.
  static List<VocabWebImage> parseBundledConceptSearch(
    String rawPack,
    String rawQuery, {
    int limit = 24,
  }) {
    final query = _normalizeSearchText(rawQuery);
    if (query.isEmpty) return const [];
    final decoded = jsonDecode(rawPack) as Map<String, dynamic>;
    final concepts = decoded['concepts'];
    if (concepts is! List) return const [];
    final tokens = query.split(RegExp(r'\s+')).where((s) => s.length > 1).toList();
    final ranked = <({int score, VocabWebImage item})>[];
    for (final rawConcept in concepts) {
      if (rawConcept is! Map<String, dynamic>) continue;
      final concept = rawConcept;
      final animations = concept['animations'];
      if (animations is! List || animations.isEmpty) continue;
      final animation = animations.first;
      if (animation is! Map<String, dynamic> || animation['type'] != 'asset') {
        continue;
      }
      final keywords = (concept['keywords'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .join(' ');
      final text = _normalizeSearchText(
        '${concept['id'] ?? ''} ${concept['glossVi'] ?? ''} $keywords',
      );
      var score = text == query ? 100 : (text.contains(query) ? 50 : 0);
      for (final token in tokens) {
        if (text.contains(token)) score += 5;
      }
      if (score == 0) continue;
      final id = (concept['id'] ?? '').toString();
      final gloss = (concept['glossVi'] ?? id).toString();
      final path = (animation['path'] ?? '').toString();
      if (!path.startsWith('assets/animations/files/') || !path.endsWith('.json')) {
        continue;
      }
      ranked.add((
        score: score,
        item: VocabWebImage(
          imageUrl: path,
          thumbUrl: path,
          pageUrl: '',
          title: '$gloss · $id',
          creator: 'In4Up',
          license: 'CC0',
          source: 'In4Up CC0',
        ),
      ));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    final cap = limit < 1 ? 1 : (limit > 40 ? 40 : limit);
    return ranked.take(cap).map((r) => r.item).toList(growable: false);
  }

  /// Chỉ mục offline đã chọn. Catalog và animation được đọc một lần trong phiên.
  Future<List<VocabWebImage>> searchBundledConcepts(
    String rawQuery, {
    int limit = 24,
  }) async {
    if (_normalizeSearchText(rawQuery).isEmpty) return const [];
    try {
      final raw = await (_conceptPackFuture ??= rootBundle
          .loadString('assets/animations/concept_animation_pack.json'));
      return parseBundledConceptSearch(raw, rawQuery, limit: limit);
    } catch (e) {
      debugPrint('[VocabAnimationLibrary] gói offline lỗi: $e');
      return const [];
    }
  }

  /// Tìm trong gói offline trước, rồi gộp kết quả nguồn mạng. Không có mạng
  /// vẫn trả animation gốc; chỉ báo lỗi khi cả hai nguồn đều trống.
  Future<List<VocabWebImage>> search(
    String rawQuery, {
    int limit = 24,
    VocabAnimationLibraryConfig? config,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      lastError = null;
      return const [];
    }
    final cfg = config ?? await VocabAnimationApiConfig.instance.load();
    final cap = limit < 1 ? 1 : (limit > 40 ? 40 : limit);
    final cacheKey = '${query.toLowerCase()}|${cfg.endpoint}|$cap';
    final cached = _cache[cacheKey];
    if (cached != null) {
      lastError = null;
      return cached;
    }

    final bundled = await searchBundledConcepts(query, limit: cap);
    if (bundled.isNotEmpty) {
      // Matched concepts are served immediately and entirely offline. Keep
      // network calls for terms that have no curated asset yet.
      lastError = null;
      if (_cache.length >= _cacheMax) _cache.clear();
      _cache[cacheKey] = bundled;
      return bundled;
    }
    List<VocabWebImage> online = const [];
    String? error;
    if (cfg.hasCustomEndpoint) {
      try {
        online = await _searchEndpoint(cfg, query, cap);
      } catch (e) {
        error = e.toString();
        debugPrint('[VocabAnimationLibrary] endpoint lỗi: $e');
      }
    }
    if (online.isEmpty) {
      try {
        online = await _searchCommons(query, cap);
        error = null;
      } catch (e) {
        error ??= e.toString();
        debugPrint('[VocabAnimationLibrary] commons lỗi: $e');
      }
    }
    final seen = <String>{};
    final results = <VocabWebImage>[];
    for (final item in [...bundled, ...online]) {
      if (seen.add(item.imageUrl)) results.add(item);
    }
    lastError = results.isEmpty ? (error ?? 'empty') : null;
    if (results.isNotEmpty) {
      if (_cache.length >= _cacheMax) _cache.clear();
      _cache[cacheKey] = results;
    }
    return results;
  }

  /// Lowercase + bỏ dấu Latin để tìm catalog offline bằng tiếng Việt/Anh.
  static String _normalizeSearchText(String value) {
    const replacements = <String, String>{
      'àáạảãâầấậẩẫăằắặẳẵ': 'a',
      'èéẹẻẽêềếệểễ': 'e',
      'ìíịỉĩ': 'i',
      'òóọỏõôồốộổỗơờớợởỡ': 'o',
      'ùúụủũưừứựửữ': 'u',
      'ỳýỵỷỹ': 'y',
      'đ': 'd',
    };
    var out = value.toLowerCase();
    for (final entry in replacements.entries) {
      for (final char in entry.key.split('')) {
        out = out.replaceAll(char, entry.value);
      }
    }
    return out.replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Endpoint tùy chỉnh: GET `{endpoint}?q=<query>&limit=<n>` (+ Bearer nếu
  /// có key). Hợp đồng JSON linh hoạt — xem [parseAnimationLibraryJson].
  Future<List<VocabWebImage>> _searchEndpoint(
    VocabAnimationLibraryConfig cfg,
    String query,
    int limit,
  ) async {
    final base = cfg.endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
        '$base?q=${Uri.encodeQueryComponent(query)}&limit=$limit');
    final headers = <String, String>{'User-Agent': userAgent};
    if (cfg.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${cfg.apiKey}';
    }
    final res = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 429) {
      throw Exception('rate limited (429)');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return parseAnimationLibraryJson(res.body, limit: limit, source: 'custom');
  }

  /// Mặc định: MediaWiki Commons — tìm file `application/json` (Lottie) theo
  /// từ khóa. Không cần key.
  Future<List<VocabWebImage>> _searchCommons(String query, int limit) async {
    final uri = Uri.parse(commonsEndpoint).replace(queryParameters: {
      'action': 'query',
      'format': 'json',
      'origin': '*', // MediaWiki yêu cầu cho CORS/anonymous
      'generator': 'search',
      'gsrsearch': 'filemime:application/json $query',
      'gsrnamespace': '6', // File:
      'gsrlimit': '$limit',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'iiurlwidth': '480',
    });
    final res = await _client
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return parseCommonsAnimations(res.body, limit: limit);
  }

  void dispose() => _client.close();

  // ─────────────────────────── PARSERS (pure, testable) ───────────────────

  /// Parse JSON của endpoint tùy chỉnh. Chấp nhận nhiều shape:
  /// `{results:[…]}` / `{data:[…]}` / `{items:[…]}` / `[...]` thuần.
  ///
  /// Mỗi item — url (`url`|`imageUrl`|`file`|`src`|`json`|`lottie`): bắt buộc
  /// là link http(s) kết thúc `.json`/`.lottie`; preview
  /// (`preview`|`thumbnail`|`thumb`|`previewUrl`|`poster`): ảnh tĩnh xem
  /// trước, có thể thiếu; title (`title`|`name`|`id`); page
  /// (`pageUrl`|`page`|`link`); creator (`creator`|`author`|`user`);
  /// license (`license`); source (`source`).
  static List<VocabWebImage> parseAnimationLibraryJson(
    String body, {
    int limit = 24,
    String source = 'custom',
  }) {
    final out = <VocabWebImage>[];
    try {
      final decoded = jsonDecode(body);
      final List raw = decoded is List
          ? decoded
          : (decoded is Map
              ? ((decoded['results'] ??
                      decoded['data'] ??
                      decoded['items']) as List? ??
                  const [])
              : const []);
      for (final item in raw) {
        if (out.length >= limit) break;
        if (item is! Map) continue;
        final url = _pickUrl(
            item, const ['url', 'imageUrl', 'file', 'src', 'json', 'lottie']);
        if (url == null || !_isLottieUrl(url)) continue;
        final preview = _pickUrl(
            item, const ['preview', 'thumbnail', 'thumb', 'previewUrl', 'poster']);
        out.add(VocabWebImage(
          imageUrl: url,
          // Không có preview tĩnh → thumbUrl = url; tile nhận ra (trùng +
          // là .json) và tự render Lottie xem trước thay vì Image.network.
          thumbUrl: preview ?? url,
          pageUrl: _pickUrl(item, const ['pageUrl', 'page', 'link']) ?? url,
          title: _pickText(item, const ['title', 'name', 'id']) ?? '',
          creator: _pickText(item, const ['creator', 'author', 'user']),
          license: _pickText(item, const ['license', 'licenseType']),
          source: _pickText(item, const ['source']) ?? source,
        ));
      }
    } catch (_) {
      return const [];
    }
    return out;
  }

  /// Parse MediaWiki Commons (`action=query&generator=search&prop=imageinfo`)
  /// — `pages` là MAP theo pageid. Chỉ giữ file `.json`/`.lottie` (Lottie);
  /// `thumburl` (nếu có) làm ảnh xem trước tĩnh, không có thì tile tự render
  /// Lottie xem trước khi ô hiện trên màn hình.
  static List<VocabWebImage> parseCommonsAnimations(
    String body, {
    int limit = 24,
  }) {
    final out = <VocabWebImage>[];
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const [];
      final query = decoded['query'];
      if (query is! Map) return const [];
      final pages = query['pages'];
      if (pages is! Map) return const [];
      for (final entry in pages.entries) {
        if (out.length >= limit) break;
        final page = entry.value;
        if (page is! Map) continue;
        final info = page['imageinfo'];
        if (info is! List || info.isEmpty) continue;
        final first = info.first;
        if (first is! Map) continue;
        final url = _pickUrl(first, const ['url']);
        if (url == null || !_isLottieUrl(url)) continue;
        final thumb = _pickUrl(first, const ['thumburl']);
        final meta = first['extmetadata'];
        final title = _pickText(page, const ['title']) ?? '';
        out.add(VocabWebImage(
          imageUrl: url,
          thumbUrl: thumb ?? url,
          pageUrl: _pickUrl(first, const ['descriptionurl']) ?? url,
          title: title.startsWith('File:') ? title.substring(5) : title,
          creator: meta is Map ? _metaText(meta['Artist']) : null,
          license: meta is Map ? _metaText(meta['LicenseShortName']) : null,
          source: 'wikimedia',
        ));
      }
    } catch (_) {
      return const [];
    }
    return out;
  }

  /// Chỉ nhận URL http(s) kết thúc .json/.lottie (bỏ query/fragment).
  static bool _isLottieUrl(String url) {
    final clean = url.split(RegExp(r'[?#]')).first.toLowerCase();
    return clean.endsWith('.json') || clean.endsWith('.lottie');
  }

  /// Chỉ nhận URL tuyệt đối (http/https) — bỏ qua giá trị tương đối.
  static String? _pickUrl(dynamic item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v is! String) continue;
      final t = v.trim();
      if (t.startsWith('http://') || t.startsWith('https://')) return t;
    }
    return null;
  }

  /// Chuỗi text thường (title, creator, license…) — không đòi hỏi tiền tố.
  static String? _pickText(dynamic item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v is! String) continue;
      final t = v.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  /// `extmetadata` value là `{"value": "<a href=…>Name</a>"}` — gỡ HTML.
  static String? _metaText(dynamic node) {
    if (node is! Map) return null;
    final v = node['value'];
    if (v is! String) return null;
    final stripped = v
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .trim();
    return stripped.isEmpty ? null : stripped;
  }
}
