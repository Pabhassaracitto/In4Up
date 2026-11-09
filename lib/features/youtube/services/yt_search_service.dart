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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

import '../models/yt_video.dart' show YtVideo;
import 'yt_initial_data_parser.dart';

/// Vì sao một lần tải danh sách KHÔNG có video.
///
/// Trước đây service trả `[]` cho **mọi** trường hợp ⇒ Explorer hiện đúng một
/// câu "không có video", người dùng không biết là kênh trống, mạng hỏng, hay
/// YouTube đang chặn (bắt đồng ý cookie / xác minh không phải bot).
enum YtFetchFailure {
  /// Không lỗi (có thể danh sách rỗng thật).
  none,

  /// Mạng hỏng / timeout / HTTP ≠ 200.
  network,

  /// HTTP 200 nhưng YouTube trả trang chặn (consent, "not a bot", login).
  blocked,

  /// HTTP 200, có `ytInitialData` nhưng parser không bóc được video nào
  /// (YouTube đổi layout).
  parseFailed,

  /// Tải được, thật sự không có video nào (kênh mới, từ khoá không khớp).
  empty,
}

/// Kết quả có KIỂU của một lần tải danh sách video.
class YtFetchResult {
  const YtFetchResult(
    this.hits,
    this.failure, {
    this.fromCache = false,
    this.next,
  });

  final List<YtSearchHit> hits;
  final YtFetchFailure failure;

  /// YT1-11: token để tải TRANG KẾ (null = đã hết). Chỉ có khi lấy được bằng
  /// tầng parse HTML — tầng `youtube_explode_dart` không trả token.
  final String? next;

  /// Kết quả lấy từ bộ nhớ đệm (có thể cũ — UI hiện "cập nhật X trước").
  final bool fromCache;

  bool get ok => hits.isNotEmpty;
  bool get failed => failure == YtFetchFailure.network ||
      failure == YtFetchFailure.blocked ||
      failure == YtFetchFailure.parseFailed;

  const YtFetchResult.ok(
    List<YtSearchHit> hits, {
    bool fromCache = false,
    String? next,
  }) : this(hits, YtFetchFailure.none, fromCache: fromCache, next: next);
}

class YtSearchService {
  YtSearchService._();
  static final YtSearchService instance = YtSearchService._();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  /// Tìm video theo từ khoá — không cần API key (giữ API cũ cho chỗ gọi khác).
  Future<List<YtSearchHit>> searchVideos(
    String query, {
    int maxResults = 20,
  }) async =>
      (await searchVideosResult(query, maxResults: maxResults)).hits;

  /// Như [searchVideos] nhưng nói RA vì sao không có kết quả.
  Future<YtFetchResult> searchVideosResult(
    String query, {
    int maxResults = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const YtFetchResult.ok(<YtSearchHit>[]);

    // Tầng 1: youtube_explode_dart
    try {
      final yt = yt_exp.YoutubeExplode();
      try {
        final list = await yt.search.search(q);
        final hits = list.map(_fromVideo).toList();
        if (hits.isNotEmpty) {
          debugPrint('✅ search explode: ${hits.length} kết quả cho "$q"');
          return YtFetchResult.ok(hits.take(maxResults).toList());
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
      if (resp.statusCode != 200) {
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.network);
      }
      if (_looksBlocked(resp.body)) {
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.blocked);
      }
      final hits = parseYtInitialDataHtml(resp.body, maxResults: maxResults);
      if (hits.isNotEmpty) {
        debugPrint('✅ search ytInitialData: ${hits.length} kết quả cho "$q"');
        _rememberInnertubeKey(resp.body);
        return YtFetchResult.ok(
          hits,
          next: extractContinuationTokenFromHtml(resp.body),
        );
      }
      if (!resp.body.contains('ytInitialData')) {
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.blocked);
      }
      return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.parseFailed);
    } catch (e) {
      debugPrint('search ytInitialData failed: $e');
    }

    debugPrint('❌ Không tìm được kết quả cho "$q"');
    return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.network);
  }

  /// Liệt kê video mới nhất của một kênh — không cần API key.
  Future<List<YtSearchHit>> fetchChannelVideos(
    String channelId, {
    int maxResults = 30,
  }) async =>
      (await fetchChannelVideosResult(channelId, maxResults: maxResults)).hits;

  /// Như [fetchChannelVideos] nhưng nói RA vì sao không có video.
  Future<YtFetchResult> fetchChannelVideosResult(
    String channelId, {
    int maxResults = 30,
  }) async {
    final id = channelId.trim();
    if (id.isEmpty) return const YtFetchResult.ok(<YtSearchHit>[]);

    // Tầng 1: youtube_explode_dart (đi qua uploads playlist UU...)
    try {
      final yt = yt_exp.YoutubeExplode();
      try {
        final videos =
            await yt.channels.getUploads(id).take(maxResults).toList();
        if (videos.isNotEmpty) {
          debugPrint('✅ channel explode: ${videos.length} video của $id');
          return YtFetchResult.ok(videos.map(_fromVideo).toList());
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
      // (IN4-77 phụ: nút "Xem video kênh" trống) — 200 nhưng 0 video thường là
      // trang bot-check/consent hoặc layout mới mà parser chưa cover.
      final hasInitialData = resp.body.contains('ytInitialData');
      debugPrint('channel ytInitialData: HTTP ${resp.statusCode}, '
          'body ${resp.body.length} chars, '
          '${hasInitialData ? 'có' : 'KHÔNG'} ytInitialData — $id');
      if (resp.statusCode != 200) {
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.network);
      }
      if (_looksBlocked(resp.body)) {
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.blocked);
      }
      final hits = parseYtInitialDataHtml(resp.body, maxResults: maxResults);
      if (hits.isNotEmpty) {
        debugPrint('✅ channel ytInitialData: ${hits.length} video của $id');
        _rememberInnertubeKey(resp.body);
        return YtFetchResult.ok(
          hits,
          next: extractContinuationTokenFromHtml(resp.body),
        );
      }
      if (!hasInitialData) {
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.blocked);
      }
      return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.parseFailed);
    } catch (e) {
      debugPrint('channel ytInitialData failed: $e');
    }

    debugPrint('❌ Không lấy được video của kênh $id');
    return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.network);
  }

  /// Key InnerTube lấy từ HTML lần tải gần nhất (không hard-code — YouTube
  /// đổi key theo thời gian).
  static String? _innertubeKey;

  void _rememberInnertubeKey(String html) {
    final k = extractInnertubeApiKey(html);
    if (k != null) _innertubeKey = k;
  }

  /// YT1-11: tải TRANG KẾ của một danh sách đã có (tìm kiếm hoặc kênh).
  ///
  /// Dùng chính continuation token mà YouTube nhúng trong trang đầu. Không cần
  /// đăng nhập, không cần Data API key — vẫn là scrape trên máy người dùng.
  Future<YtFetchResult> fetchMoreResult(
    String continuation, {
    String? previousToken,
  }) async {
    final token = continuation.trim();
    if (token.isEmpty) return const YtFetchResult.ok(<YtSearchHit>[]);
    final key = _innertubeKey;
    if (key == null) {
      // Chưa từng đọc được trang HTML (lần đầu đi qua explode) ⇒ không thể
      // phân trang. Trả `empty` để UI ẩn nút "Tải thêm" thay vì báo lỗi.
      return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.empty);
    }
    try {
      final resp = await http.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/browse?key=$key'),
        headers: {
          'User-Agent': _ua,
          'Content-Type': 'application/json',
          'Accept-Language': 'en',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20240101.00.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
          'continuation': token,
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.network);
      }
      final decoded = jsonDecode(resp.body);
      final parsed = parseContinuationResponse(decoded);
      if (parsed.hits.isEmpty) {
        // Hết trang thật (hoặc YouTube đổi layout) — coi là hết, không lỗi.
        return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.empty);
      }
      // Token có thể trả lại chính token cũ ⇒ phải chặn vòng lặp vô hạn.
      final next = (parsed.next == previousToken || parsed.next == token)
          ? null
          : parsed.next;
      return YtFetchResult.ok(parsed.hits, next: next);
    } catch (e) {
      debugPrint('fetchMore failed: $e');
      return const YtFetchResult(<YtSearchHit>[], YtFetchFailure.network);
    }
  }

  /// Trang có phải "tường chặn" của YouTube không (consent / bot-check /
  /// đòi đăng nhập). Nhận diện bằng dấu hiệu văn bản, KHÔNG dựa vào mã HTTP —
  /// YouTube trả 200 cho cả trang chặn.
  bool _looksBlocked(String body) {
    final b = body.toLowerCase();
    return b.contains('consent.youtube.com') ||
        b.contains('before you continue to youtube') ||
        b.contains('sign in to confirm you') ||
        b.contains('confirm you\'re not a bot') ||
        b.contains('trang này không khả dụng') ||
        b.contains('this page isn\'t available');
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
