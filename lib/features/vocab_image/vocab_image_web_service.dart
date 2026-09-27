// lib/features/vocab_image/vocab_image_web_service.dart
//
// IMG-WEB-001 — Tìm HÌNH TRÊN MẠNG cho từ vựng (qua API, có key).
//
// Vì sao mặc định là mạng: khi học từ, máy gần như KHÔNG có sẵn ảnh minh họa
// cho từ (một con "bướm", "tháp Eiffel", "cái cân"). Gallery chỉ là đường
// thứ hai; camera + ML Kit (xóa phông, gắn nhãn đồ vật thật) là bước tiếp
// theo — chưa bật ở đây.
//
// Nhà cung cấp (xem VocabImageProvider + VocabImageApiConfig):
//   • Pexels        — api.pexels.com/v1/search      (BẮT BUỘC API key)
//   • Unsplash      — api.unsplash.com/search/photos (BẮT BUỘC Access Key)
//   • Openverse     — api.openverse.org (token miễn phí khuyến nghị; ẩn danh
//                    vẫn được nhưng rate limit thấp) — ảnh CC/BY
//   • Wikimedia     — commons MediaWiki API (không cần key) — nguồn dữ dội
// Provider đã chọn gọi TRƯỚC, các provider dùng được còn lại là fallback
// (lỗi mạng / 429 / 0 kết quả). Pexels và Unsplash bị BỎ QUA khi chưa có key
// → [VocabImageWebService.missingKeyProvider] để UI nhắc nhập key.
// Không có key nào được hard-code trong repo: key ở SharedPreferences của
// máy, hoặc --dart-define lúc build (xem VocabImageApiConfig).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'vocab_image_api_config.dart';

/// Một ảnh tìm được trên mạng, kèm thông tin bản quyền để ghi nguồn.
class VocabWebImage {
  /// URL file ảnh gốc (jpg/png…) — thứ duy nhất app tải về.
  final String imageUrl;

  /// URL thumbnail để hiển thị lưới (nhẹ, nhanh). Có thể == imageUrl.
  final String thumbUrl;

  /// Trang nguồn (để người dùng xem full + giấy phép).
  final String pageUrl;

  final String title;
  final String? creator;
  final String? license;

  /// 'pexels' | 'unsplash' | 'openverse' | 'wikimedia' (hoặc tên nguồn con
  /// mà Openverse trả về, vd 'flickr').
  final String source;

  const VocabWebImage({
    required this.imageUrl,
    required this.thumbUrl,
    required this.pageUrl,
    required this.title,
    required this.source,
    this.creator,
    this.license,
  });

  /// Chuỗi ghi nguồn ngắn gọn, hiển thị dưới ảnh.
  String get credit {
    final parts = <String>[
      if (creator != null && creator!.trim().isNotEmpty) creator!.trim(),
      if (license != null && license!.trim().isNotEmpty) license!.trim(),
      source,
    ];
    return parts.join(' · ');
  }

  @override
  String toString() => 'VocabWebImage($source, "$title", $imageUrl)';
}

/// Lỗi tìm kiếm (dịch vụ mạng, rate limit, JSON sai…) — UI hiển thị 1 dòng.
class VocabImageSearchException implements Exception {
  final String message;
  const VocabImageSearchException(this.message);
  @override
  String toString() => message;
}

/// Client tìm ảnh trên mạng cho từ vựng.
class VocabImageWebService {
  VocabImageWebService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Từ khóa tìm ảnh tốt hơn cho một từ vựng: từ + nghĩa (cắt ngắn).
  ///
  /// Ảnh minh họa thường được gán tag tiếng Anh/đa ngữ, nên nghĩa của từ làm
  /// truy vấn khớp tốt hơn nhiều so với chỉ từ gốc (đặc biệt với từ Pali/Hindi).
  static String buildQuery({String? word, String? meaning}) {
    final w = (word ?? '').trim();
    final m = (meaning ?? '').trim();
    if (w.isEmpty) return m;
    if (m.isEmpty) return w;
    // Bỏ nghĩa quá dài: API search chỉ cần vài từ đầu để định hình chủ đề.
    final short = m.length > 48 ? m.substring(0, 48) : m;
    return '$w $short';
  }

  // ── Endpoints ────────────────────────────────────────────────────────────
  static const String openverseEndpoint =
      'https://api.openverse.org/v1/images/';
  static const String commonsEndpoint =
      'https://commons.wikimedia.org/w/api.php';
  static const String pexelsSearchEndpoint =
      'https://api.pexels.com/v1/search';
  static const String unsplashSearchEndpoint =
      'https://api.unsplash.com/search/photos';

  /// MediaWiki + Openverse đều từ chối UA rỗng.
  static const String userAgent =
      'In4Up/1.4 (language learning app; offline-first) +https://github.com/Pabhassaracitto/In4Up';

  /// Cache kết quả trong 1 phiên — lật qua lại giữa các từ không gọi API lặp.
  static final Map<String, List<VocabWebImage>> _cache =
      <String, List<VocabWebImage>>{};
  static const int _cacheMax = 40;

  /// Lỗi gần nhất (chuỗi ngắn để log/debug — UI tự chọn câu hiển thị).
  String? lastError;

  /// Provider cần key mà user CHƯA nhập key → UI nhắc "Thêm API key".
  VocabImageProvider? missingKeyProvider;

  /// Tìm ảnh cho [rawQuery]. Không bao giờ ném:
  /// kết quả rỗng + [lastError] / [missingKeyProvider] để UI báo đúng nguyên
  /// nhân (thiếu key KHÁC với hết mạng KHÁC với không có kết quả).
  Future<List<VocabWebImage>> search(
    String rawQuery, {
    int limit = 24,
    VocabImageApiSettings? settings,
  }) async {
    final query = rawQuery.trim();
    missingKeyProvider = null;
    if (query.isEmpty) {
      lastError = null;
      return const [];
    }
    final cfg = settings ?? await VocabImageApiConfig.instance.load();
    final cap = limit < 1 ? 1 : (limit > 40 ? 40 : limit);
    final cacheKey = '${query.toLowerCase()}|${cfg.provider.name}|$cap';
    final cached = _cache[cacheKey];
    if (cached != null) {
      lastError = null;
      return cached;
    }

    List<VocabWebImage> results = const [];
    String? error;
    for (final provider in cfg.searchOrder()) {
      final key = cfg.keyFor(provider);
      if (provider.needsKey && (key == null || key.isEmpty)) {
        // Nguồn có key là yêu cầu của chủ dự án — ghi lại provider đầu tiên
        // bị thiếu key để UI nhắc người dùng nhập đúng chỗ.
        missingKeyProvider ??= provider;
        continue;
      }
      try {
        results = await _searchWith(provider, query, cap, key);
      } catch (e) {
        error = e.toString();
        debugPrint('[VocabImageWeb] ${provider.label} lỗi: $e');
        results = const [];
        continue;
      }
      if (results.isNotEmpty) {
        error = null;
        break;
      }
    }

    lastError = results.isEmpty ? (error ?? 'empty') : null;

    if (results.isNotEmpty) {
      if (_cache.length >= _cacheMax) _cache.clear();
      _cache[cacheKey] = results;
    }
    return results;
  }

  Future<List<VocabWebImage>> _searchWith(
    VocabImageProvider provider,
    String query,
    int limit,
    String? key,
  ) {
    switch (provider) {
      case VocabImageProvider.pexels:
        return _searchPexels(query, limit, key ?? '');
      case VocabImageProvider.unsplash:
        return _searchUnsplash(query, limit, key ?? '');
      case VocabImageProvider.openverse:
        return _searchOpenverse(query, limit, key);
      case VocabImageProvider.wikimedia:
        return _searchCommons(query, limit);
    }
  }

  Future<List<VocabWebImage>> _searchPexels(
      String query, int limit, String apiKey) async {
    final uri = Uri.parse(pexelsSearchEndpoint).replace(queryParameters: {
      'query': query,
      'per_page': '$limit',
      'size': 'medium',
      'locale': 'en-US',
      'safe_search': 'true',
    });
    final body = await _get(uri, headers: {'Authorization': apiKey});
    return parsePexels(body, limit: limit);
  }

  Future<List<VocabWebImage>> _searchUnsplash(
      String query, int limit, String accessKey) async {
    final uri = Uri.parse(unsplashSearchEndpoint).replace(queryParameters: {
      'query': query,
      'per_page': '$limit',
      'orientation': 'square',
      'content_filter': 'low',
    });
    final body = await _get(
      uri,
      headers: {'Authorization': 'Client-ID $accessKey'},
    );
    return parseUnsplash(body, limit: limit);
  }

  Future<List<VocabWebImage>> _searchOpenverse(
      String query, int limit, String? token) async {
    final uri = Uri.parse(openverseEndpoint).replace(queryParameters: {
      'q': query,
      'page_size': '$limit',
      // Ảnh minh họa từ vựng: ưu tiên ảnh "đẹp" + có giấy phép mở.
      'license_type': 'all',
      'mature': 'false',
    });
    final body = await _get(
      uri,
      headers: token == null ? const {} : {'Authorization': 'Bearer $token'},
    );
    return parseOpenverse(body, limit: limit);
  }

  Future<List<VocabWebImage>> _searchCommons(String query, int limit) async {
    final uri = Uri.parse(commonsEndpoint).replace(queryParameters: {
      'action': 'query',
      'format': 'json',
      'origin': '*', // MediaWiki yêu cầu cho CORS/anonymous
      'generator': 'search',
      'gsrsearch': 'filetype:bitmap $query',
      'gsrnamespace': '6', // File:
      'gsrlimit': '$limit',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'iiurlwidth': '480',
    });
    final body = await _get(uri);
    return parseCommons(body, limit: limit);
  }

  Future<String> _get(Uri uri, {Map<String, String> headers = const {}}) async {
    final res = await _client
        .get(uri, headers: {'User-Agent': userAgent, ...headers})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 429) {
      throw const VocabImageSearchException('rate limited (429)');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw VocabImageSearchException('HTTP ${res.statusCode}');
    }
    return res.body;
  }

  /// Tải bytes ảnh (có trần dung lượng) để lưu vào app storage.
  Future<Uint8List> download(String imageUrl,
      {int maxBytes = 8 * 1024 * 1024}) async {
    final res = await _client
        .get(Uri.parse(imageUrl), headers: const {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw VocabImageSearchException('HTTP ${res.statusCode}');
    }
    final bytes = res.bodyBytes;
    if (bytes.isEmpty) {
      throw const VocabImageSearchException('empty body');
    }
    if (bytes.length > maxBytes) {
      throw const VocabImageSearchException('image too large');
    }
    if (!looksLikeImage(bytes)) {
      throw const VocabImageSearchException('not an image');
    }
    return bytes;
  }

  void dispose() => _client.close();

  // ─────────────────────────── PARSERS (pure, testable) ───────────────────
  /// Pexels `/v1/search` → `{"total_results": n, "photos": [ {…} ]}`.
  /// `photos[].src` có đủ `original`, `large2x`, `medium`, `thumbnail`.
  static List<VocabWebImage> parsePexels(String body, {int limit = 24}) {
    final out = <VocabWebImage>[];
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      final photos = json['photos'];
      if (photos is! List) return const [];
      for (final item in photos) {
        if (out.length >= limit) break;
        if (item is! Map) continue;
        final src = item['src'];
        final full = src is Map
            ? (_url(src['large2x']) ??
                _url(src['original']) ??
                _url(src['medium']))
            : null;
        if (full == null) continue;
        final thumb = src is Map ? (_url(src['medium']) ?? full) : full;
        final alt = _str(item['alt']) ?? _str(item['id']);
        out.add(VocabWebImage(
          imageUrl: full,
          thumbUrl: thumb,
          pageUrl: _url(item['url']) ?? full,
          title: alt ?? '',
          creator: _nestedName(item['user']),
          license: 'Pexels License',
          source: 'pexels',
        ));
      }
    } catch (_) {
      return const [];
    }
    return out;
  }

  /// Unsplash `/search/photos` → `{"total": n, "results": [ {urls: {raw,full,
  /// regular, small}, user: {name}, links: {html}, alt_description} ]}`.
  static List<VocabWebImage> parseUnsplash(String body, {int limit = 24}) {
    final out = <VocabWebImage>[];
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      final raw = json['results'];
      if (raw is! List) return const [];
      for (final item in raw) {
        if (out.length >= limit) break;
        if (item is! Map) continue;
        final urls = item['urls'];
        if (urls is! Map) continue;
        final full = _url(urls['regular']) ?? _url(urls['full']);
        if (full == null) continue;
        final links = item['links'];
        out.add(VocabWebImage(
          imageUrl: _url(urls['full']) ?? full,
          thumbUrl: _url(urls['small']) ?? full,
          pageUrl: (links is Map ? _url(links['html']) : null) ?? full,
          title: _str(item['alt_description']) ?? _str(item['description']) ?? '',
          creator: item['user'] is Map ? _str((item['user'] as Map)['name']) : null,
          license: 'Unsplash License',
          source: 'unsplash',
        ));
      }
    } catch (_) {
      return const [];
    }
    return out;
  }

  /// Openverse `/v1/images/` → `{"result": [...], "count": n}` (một số bản
  /// dùng key `results`). Mỗi item: title, url, thumbnail, foreign_landing_url,
  /// detail_url, creator, license, source.
  static List<VocabWebImage> parseOpenverse(String body, {int limit = 24}) {
    final out = <VocabWebImage>[];
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      final raw = json['results'] ?? json['result'];
      if (raw is! List) return const [];
      for (final item in raw) {
        if (out.length >= limit) break;
        if (item is! Map) continue;
        final url = _url(item['url']);
        if (url == null) continue;
        out.add(VocabWebImage(
          imageUrl: url,
          thumbUrl: _url(item['thumbnail']) ?? url,
          pageUrl: _url(item['foreign_landing_url']) ??
              _url(item['detail_url']) ??
              url,
          title: _str(item['title']) ?? '',
          creator: _str(item['creator']),
          license: _str(item['license']),
          source: _str(item['source']) ?? 'openverse',
        ));
      }
    } catch (_) {
      return const [];
    }
    return out;
  }

  /// MediaWiki `action=query&generator=search&prop=imageinfo` →
  /// `{"query":{"pages":{"<pageid>":{"title":…, "imageinfo":[{…}]}}}}`.
  /// `pages` là MAP (key = pageid), không phải list.
  static List<VocabWebImage> parseCommons(String body, {int limit = 24}) {
    final out = <VocabWebImage>[];
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      final query = json['query'];
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
        final url = _url(first['url']);
        if (url == null) continue;
        final meta = first['extmetadata'];
        final license = meta is Map
            ? _metaText(meta['LicenseShortName'])
            : null;
        final artist =
            meta is Map ? _metaText(meta['Artist']) : null;
        final title = _str(page['title']) ?? '';
        out.add(VocabWebImage(
          imageUrl: url,
          thumbUrl: _url(first['thumburl']) ?? url,
          pageUrl: _url(first['descriptionurl']) ?? url,
          title: title.startsWith('File:')
              ? title.substring(5)
              : title,
          creator: artist,
          license: license,
          source: 'wikimedia',
        ));
      }
      // MediaWiki trả pages theo thứ tự ngẫu nhiên; giữ nguyên (search đã xếp
      // theo điểm liên quan trong `searchinfo` — không đủ dữ liệu để sort lại).
    } catch (_) {
      return const [];
    }
    return out;
  }

  /// `extmetadata` value là `{"value": "<a href=…>Name</a>", "html": …}`.
  static String? _metaText(dynamic node) {
    if (node is! Map) return null;
    final v = node['value'];
    if (v is! String) return null;
    final stripped = v
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
    return stripped.isEmpty ? null : stripped;
  }

  /// `photos[].user.name` (Pexels) — map lồng, an toàn với shape lạ.
  static String? _nestedName(dynamic node) =>
      node is Map ? _str(node['name']) : null;

  /// Chuỗi text thường (title, creator, license…) — KHÔNG đòi hỏi tiền tố
  /// http: phần lớn field của 4 API là chữ thuần.
  static String? _str(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  /// Chỉ nhận URL tuyệt đối. URL tương đối (thấy ở thumbnail Openverse) →
  /// null để caller fallback về ảnh gốc, không ghép chuỗi thủ công.
  static String? _url(dynamic v) {
    final t = _str(v);
    if (t == null) return null;
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t;
  }

  /// Magic bytes — chặn file HTML/RSS disguised as image.
  static bool looksLikeImage(Uint8List b) {
    if (b.length < 12) return false;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true; // JPEG
    if (b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return true;
    } // PNG
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true; // GIF
    if (b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b.length > 11 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return true;
    } // WEBP
    return false;
  }
}
