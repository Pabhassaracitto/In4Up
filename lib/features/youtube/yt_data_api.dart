import 'models/yt_video.dart';

/// YouTube Data API v3 — tìm kiếm / kênh / playlist (quota ~100 units/search).
///
/// Hybrid: API này chỉ cho **khám phá**. Audio + phụ đề vẫn đi
/// `youtube_explode_dart` / timedtext (không tốn quota).
///
/// Restrict the key in Google Cloud (Android package / iOS bundle) before
/// shipping to Play Store.
class YtDataApi {
  YtDataApi._();

  static const String key = 'AIzaSyCpGdv7ESAJkH5-FYIC8-x0R0EWGgvK0Lg';
  static const String host = 'www.googleapis.com';
  static const String defaultDiscoverQuery = 'learn english';

  static bool get isConfigured => YtVideo.isUsableDataApiKey(key);

  /// True when [input] is a watch URL or a bare 11-char video id (no spaces).
  static bool looksLikeWatchInput(String input) {
    final t = input.trim();
    if (t.isEmpty) return false;
    final lower = t.toLowerCase();
    if (lower.contains('youtu.be') || lower.contains('youtube.com')) {
      return YtVideo.extractId(t) != null;
    }
    return !t.contains(' ') && YtVideo.extractId(t) != null;
  }

  static Uri search({
    required String apiKey,
    String? q,
    String? channelId,
    String order = 'date',
    String? pageToken,
    int maxResults = 20,
  }) {
    final qp = <String, String>{
      'part': 'snippet',
      'type': 'video',
      'maxResults': '$maxResults',
      'relevanceLanguage': 'en',
      'safeSearch': 'moderate',
      'videoEmbeddable': 'true',
      'key': apiKey,
      'order': order,
    };
    final query = (q ?? '').trim();
    final ch = (channelId ?? '').trim();
    if (query.isNotEmpty) qp['q'] = query;
    if (ch.isNotEmpty) qp['channelId'] = ch;
    if (query.isEmpty && ch.isEmpty) qp['q'] = defaultDiscoverQuery;
    if (pageToken != null && pageToken.isNotEmpty) qp['pageToken'] = pageToken;
    return Uri.https(host, '/youtube/v3/search', qp);
  }

  static Uri videos({
    required String apiKey,
    required List<String> ids,
  }) {
    return Uri.https(host, '/youtube/v3/videos', {
      'part': 'statistics,contentDetails',
      'id': ids.join(','),
      'key': apiKey,
    });
  }

  static Uri channels({
    required String apiKey,
    required List<String> ids,
  }) {
    return Uri.https(host, '/youtube/v3/channels', {
      'part': 'snippet,statistics',
      'id': ids.join(','),
      'key': apiKey,
    });
  }
}
