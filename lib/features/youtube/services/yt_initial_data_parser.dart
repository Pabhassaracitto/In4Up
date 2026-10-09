//
// Parser thuần Dart cho ytInitialData của YouTube — không phụ thuộc Flutter,
// không cần mạng. Tách riêng để unit test bằng fixture HTML.
//
// YouTube nhúng dữ liệu trang (kết quả tìm kiếm, danh sách video của kênh)
// vào HTML dạng:
//   <script>var ytInitialData = {...};</script>
//   <script>window["ytInitialData"] = {...};</script>
//
// Parser tìm mốc "ytInitialData", xác định dấu '{' đầu tiên sau mốc, rồi đọc
// JSON bằng cách cân bằng ngoặc (theo chuỗi kép + escape) — không dùng regex
// ăn gian vì tiêu đề video có thể chứa ngoặc, nháy, ngoặc nhọn.
//
// Kết quả: List<YtSearchHit> — đủ field cho Explorer (title, channel,
// duration, viewCount, publishedAt, thumb). Đây là TẦNG FALLBACK khi
// youtube_explode_dart gãy (YouTube đổi client) — xem yt_search_service.dart.

import 'dart:convert';

/// Một video tìm thấy trong ytInitialData (node videoRenderer).
class YtSearchHit {
  final String id;
  final String title;
  final String channel;
  final String channelId;
  final String? thumb;
  final Duration? duration;
  final int? viewCount;
  final DateTime? publishedAt;

  const YtSearchHit({
    required this.id,
    required this.title,
    required this.channel,
    required this.channelId,
    this.thumb,
    this.duration,
    this.viewCount,
    this.publishedAt,
  });
}

/// Tìm và decode object ytInitialData trong HTML trang YouTube.
/// Trả về null nếu không có marker hoặc JSON không đọc được.
Map<String, dynamic>? extractYtInitialData(String html) {
  final marker = html.indexOf('ytInitialData');
  if (marker < 0) return null;
  final braceStart = html.indexOf('{', marker);
  if (braceStart < 0) return null;
  final raw = readBalancedJson(html, braceStart);
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Đọc chuỗi JSON bắt đầu tại vị trí dấu '{' — cân bằng ngoặc theo chuỗi kép
/// và escape. Trả về null nếu ngoặc không cân bằng (HTML bị cắt cụt).
String? readBalancedJson(String s, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < s.length; i++) {
    final ch = s.codeUnitAt(i);
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == 0x5C) {
        // backslash — bỏ qua ký tự kế (kể cả ngoặc kép)
        escaped = true;
      } else if (ch == 0x22) {
        // " — kết thúc chuỗi
        inString = false;
      }
      continue;
    }
    if (ch == 0x22) {
      inString = true;
    } else if (ch == 0x7B) {
      // {
      depth++;
    } else if (ch == 0x7D) {
      // }
      depth--;
      if (depth == 0) return s.substring(start, i + 1);
    }
  }
  return null;
}

/// Gom toàn bộ node có dạng videoRenderer trong cây ytInitialData (đệ quy),
/// khử trùng theo videoId, giữ thứ tự xuất hiện. Node nhận diện: có
/// `videoId` (string) và `title` (object) — bao phủ videoRenderer,
/// gridVideoRenderer (trang kênh) và videoRenderer lồng trong richItemRenderer.
List<Map<String, dynamic>> collectVideoRenderers(
  dynamic node, {
  int maxDepth = 48,
}) {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};

  void walk(dynamic n, int depth) {
    if (n == null || depth > maxDepth) return;
    if (n is Map) {
      final map = n.cast<String, dynamic>();
      final vid = map['videoId'];
      if (vid is String && vid.isNotEmpty && map['title'] is Map) {
        if (seen.add(vid)) out.add(map);
      }
      for (final v in map.values) {
        walk(v, depth + 1);
      }
      return;
    }
    if (n is List) {
      for (final v in n) {
        walk(v, depth + 1);
      }
    }
  }

  walk(node, 0);
  return out;
}

/// Đọc một node videoRenderer thành YtSearchHit. Trả về null nếu thiếu
/// videoId hoặc title.
YtSearchHit? parseVideoRenderer(Map<String, dynamic> r, {DateTime? now}) {
  final id = r['videoId'];
  if (id is! String || id.isEmpty) return null;
  final title = runsText(r['title']) ?? '';
  if (title.isEmpty) return null;

  final owner = r['ownerText'] ?? r['longBylineText'] ?? r['shortBylineText'];
  final channel = runsText(owner) ?? '';
  final channelId = browseId(owner) ?? '';

  String? thumb;
  final thumbList = (r['thumbnail'] as Map?)?['thumbnails'];
  if (thumbList is List) {
    // YouTube xếp thumbnail từ thấp đến cao — lấy cái cuối (nét nhất)
    for (final t in thumbList.reversed) {
      final u = (t as Map?)?['url'];
      if (u is String && u.isNotEmpty) {
        thumb = u;
        break;
      }
    }
  }

  final lengthNode = r['lengthText'];
  final duration =
      parseLength(simpleText(lengthNode) ?? runsText(lengthNode));

  final viewNode = r['viewCountText'];
  final viewCount =
      parseViewCount(simpleText(viewNode) ?? runsText(viewNode));

  final publishedNode = r['publishedTimeText'];
  final publishedAt = parsePublished(
    simpleText(publishedNode) ?? runsText(publishedNode),
    now: now,
  );

  return YtSearchHit(
    id: id,
    title: title,
    channel: channel,
    channelId: channelId,
    thumb: thumb,
    duration: duration,
    viewCount: viewCount,
    publishedAt: publishedAt,
  );
}

/// Parse trực tiếp từ HTML trang kết quả tìm kiếm / trang kênh.
List<YtSearchHit> parseYtInitialDataHtml(
  String html, {
  DateTime? now,
  int? maxResults,
}) {
  final data = extractYtInitialData(html);
  if (data == null) return [];
  final hits = <YtSearchHit>[];
  for (final r in collectVideoRenderers(data)) {
    final hit = parseVideoRenderer(r, now: now);
    if (hit != null) hits.add(hit);
    if (maxResults != null && hits.length >= maxResults) break;
  }
  return hits;
}

// ─── Helpers ──────────────────────────────────────────────

/// Đọc text từ node {simpleText} hoặc {runs: [{text}, ...]} của YouTube.
String? runsText(dynamic node) {
  if (node is! Map) return null;
  final simple = node['simpleText'];
  if (simple is String && simple.isNotEmpty) return simple;
  final runs = node['runs'];
  if (runs is List) {
    final buf = StringBuffer();
    for (final r in runs) {
      final t = (r as Map?)?['text'];
      if (t is String) buf.write(t);
    }
    final s = buf.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

String? simpleText(dynamic node) {
  if (node is! Map) return null;
  final s = node['simpleText'];
  return s is String ? s : null;
}

/// Lấy browseId (UC...) từ node byline (ownerText / longBylineText).
String? browseId(dynamic bylineNode) {
  if (bylineNode is! Map) return null;
  final nav = bylineNode['navigationEndpoint'];
  if (nav is Map) {
    final browse = nav['browseEndpoint'];
    if (browse is Map) {
      final id = browse['browseId'];
      if (id is String && id.isNotEmpty) return id;
    }
  }
  return null;
}

/// "12:34" / "1:02:03" / "0:45" → Duration. Không parse được → null.
Duration? parseLength(String? text) {
  if (text == null) return null;
  final m = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (m == null) return null;
  final h = int.tryParse(m.group(1) ?? '0') ?? 0;
  final min = int.tryParse(m.group(2)) ?? 0;
  final s = int.tryParse(m.group(3)) ?? 0;
  return Duration(hours: h, minutes: min, seconds: s);
}

/// "1,234,567 views" / "1.2M views" / "850K views" / "No views" → int.
int? parseViewCount(String? text) {
  if (text == null) return null;
  final t = text.trim();
  if (t.isEmpty) return null;
  if (RegExp(r'no views', caseSensitive: false).hasMatch(t)) return 0;
  // Dạng chữ số + hậu tố K/M/B: "1.2M views"
  final kmb =
      RegExp(r'([\d.,]+)\s*([KMB])\b', caseSensitive: false).firstMatch(t);
  if (kmb != null) {
    final num = double.tryParse((kmb.group(1) ?? '').replaceAll(',', ''));
    if (num == null) return null;
    final mult = switch (kmb.group(2)!.toUpperCase()) {
      'K' => 1000,
      'M' => 1000000,
      _ => 1000000000, // B
    };
    return (num * mult).round();
  }
  final digits = t.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// "5 days ago" / "Streamed 3 weeks ago" / "2 years ago" → DateTime gần đúng
/// (tháng = 30 ngày, năm = 365 ngày). Truyền [now] để test ổn định.
/// Không parse được (vd "Premiered Oct 1, 2024") → null.
DateTime? parsePublished(String? text, {DateTime? now}) {
  if (text == null) return null;
  final m = RegExp(
    r'(\d+)\s*(second|minute|hour|day|week|month|year)s?\s+ago',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final n = int.tryParse(m.group(1) ?? '') ?? 0;
  final unit = (m.group(2) ?? '').toLowerCase();
  final delta = switch (unit) {
    'second' => Duration(seconds: n),
    'minute' => Duration(minutes: n),
    'hour' => Duration(hours: n),
    'day' => Duration(days: n),
    'week' => Duration(days: n * 7),
    'month' => Duration(days: n * 30),
    _ => Duration(days: n * 365), // year
  };
  return (now ?? DateTime.now()).subtract(delta);
}
