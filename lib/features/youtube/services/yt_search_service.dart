//
// Tìm kiếm video + liệt kê video của kênh KHÔNG cần YouTube Data API key.
//
// Trước đây YoutubeExplorerScreen ẩn thanh search và trả về list rỗng khi
// không có key (key mặc định là '' — xem _kDefaultApiKey). Service này làm
// Explorer chạy được trên mọi máy, đúng tinh thần local-first của PLAN-020:
//
//   Tầng 1: youtube_explode_dart — search.search / channels.getUploads /
//           search.getQuerySuggestions (scrape trang YouTube, keyless).
//   Tầng 2: fallback tự parse ytInitialData trong HTML (yt_initial_data_parser)
//           khi explode gãy (YouTube đổi client).
//
// Không server, không yt-dlp ở đây — mobile vẫn chạy được vì cả 2 tầng đều
// chạy trên máy user.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

import '../models/yt_video.dart' show YtVideo;
import 'yt_initial_data_parser.dart';

class YtSearchService {
  YtSearchService._();
  static final YtSearchService instance = YtSearchService._();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  /// Tìm video theo từ khoá — không cần API key.
  Future<List<YtSearchHit>> searchVideos(
    String query, {
    int maxResults = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Tầng 1: youtube_explode_dart
    try {
      final yt = yt_exp.YoutubeExplode();
      try {
        final list = await yt.search.search(q);
        final hits = list.map(_fromVideo).toList();
        if (hits.isNotEmpty) {
          debugPrint('✅ search explode: ${hits.length} kết quả cho "$q"');
          return hits.take(maxResults).toList();
        }
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint('search explode failed: $e');
    }

    // Tầng 2: parse ytInitialData từ trang kết quả tìm kiếm
    try {
      final uri = Uri.parse(
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}');
      final resp = await http.get(uri, headers: {
        'User-Agent': _ua,
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final hits = parseYtInitialDataHtml(resp.body, maxResults: maxResults);
        if (hits.isNotEmpty) {
          debugPrint('✅ search ytInitialData: ${hits.length} kết quả cho "$q"');
          return hits;
        }
      }
    } catch (e) {
      debugPrint('search ytInitialData failed: $e');
    }

    debugPrint('❌ Không tìm được kết quả cho "$q"');
    return [];
  }

  /// Liệt kê video mới nhất của một kênh — không cần API key.
  Future<List<YtSearchHit>> fetchChannelVideos(
    String channelId, {
    int maxResults = 30,
  }) async {
    final id = channelId.trim();
    if (id.isEmpty) return [];

    // Tầng 1: youtube_explode_dart (đi qua uploads playlist UU...)
    try {
      final yt = yt_exp.YoutubeExplode();
      try {
        final videos =
            await yt.channels.getUploads(id).take(maxResults).toList();
        if (videos.isNotEmpty) {
          debugPrint('✅ channel explode: ${videos.length} video của $id');
          return videos.map(_fromVideo).toList();
        }
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint('channel explode failed: $e');
    }

    // Tầng 2: parse ytInitialData từ trang /videos của kênh
    try {
      final resp = await http.get(
        Uri.parse('https://www.youtube.com/channel/$id/videos'),
        headers: {'User-Agent': _ua, 'Accept-Language': 'en'},
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final hits = parseYtInitialDataHtml(resp.body, maxResults: maxResults);
        if (hits.isNotEmpty) {
          debugPrint('✅ channel ytInitialData: ${hits.length} video của $id');
          return hits;
        }
        // (IN4-77 phụ: nút "Xem video kênh" trống) — log dữ liệu để chẩn
        // đoán: 200 nhưng 0 video thường là trang bot-check/consent hoặc
        // layout mới mà parser chưa cover.
        debugPrint('❌ channel ytInitialData: 200 nhưng 0 video '
            '(body ${resp.body.length} chars; '
            '${resp.body.contains('ytInitialData') ? 'có' : 'KHÔNG'} '
            'ytInitialData) — $id');
      } else {
        debugPrint('❌ channel ytInitialData: HTTP ${resp.statusCode} — $id');
      }
    } catch (e) {
      debugPrint('channel ytInitialData failed: $e');
    }

    debugPrint('❌ Không lấy được video của kênh $id');
    return [];
  }

  /// Gợi ý từ khoá khi gõ — cho dropdown của ô tìm kiếm (keyless).
  Future<List<String>> getSuggestions(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      final yt = yt_exp.YoutubeExplode();
      try {
        return await yt.search.getQuerySuggestions(q);
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint('getSuggestions failed: $e');
      return [];
    }
  }

  YtSearchHit _fromVideo(yt_exp.Video v) => YtSearchHit(
        id: v.id.value,
        title: v.title,
        channel: v.author,
        channelId: v.channelId.value,
        thumb: v.thumbnails.mediumResUrl,
        duration: v.duration,
        viewCount: v.engagement?.viewCount,
        publishedAt: v.uploadDate,
      );
}

/// YT-ONE-BAR-001 (#2) — nhận diện "người dùng vừa dán một VIDEO" trong ô
/// tìm kiếm duy nhất.
///
/// Trả `videoId` khi chắc chắn, `null` khi nên đi tìm kiếm theo từ khoá.
///
/// Ba trường hợp, cố tình KHÔNG nhận tất cả:
///  • Có `youtu` hoặc bắt đầu bằng `http` ⇒ chắc chắn là link ⇒ lấy ID.
///  • Chuỗi đúng 11 ký tự ID **và có ít nhất một chữ số** ⇒ coi là ID trần.
///    Điều kiện "có chữ số" để một từ khoá tiếng Anh đúng 11 ký tự (vd
///    `learnenglis`) KHÔNG bị biến thành lệnh mở video rác — đây là cái bẫy
///    dễ gặp nhất khi gộp hai thanh (tìm kiếm + dán URL) làm một.
///  • Còn lại ⇒ từ khoá, đi tìm kiếm bình thường.
String? ytVideoIdFromSearchInput(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (t.contains('youtu') || t.startsWith('http')) {
    return YtVideo.extractId(t);
  }
  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(t) &&
      RegExp(r'[0-9]').hasMatch(t)) {
    return t;
  }
  return null;
}
