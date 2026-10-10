// test/youtube_search_parser_test.dart
// YT-SRCH-001 — parser ytInitialData (tầng fallback search/list kênh keyless).
// Test bằng fixture HTML, không cần mạng.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/services/yt_initial_data_parser.dart';

// HTML trang kết quả tìm kiếm mô phỏng: 3 videoRenderer (một cái lồng trong
// richItemRenderer, một cái trùng videoId), 1 channelRenderer (phải bị loại),
// và một script ytInitialData thứ hai (phải bị bỏ qua — lấy object đầu).
// Chú ý: tiêu đề có ngoặc nhọn, ngoặc kép (escape \") và dấu tiếng Việt để
// kiểm tra cân bằng ngoặc theo chuỗi.
const _fixtureHtml = r'''<html><head><title>yt search</title></head><body>
<script>var ytInitialData = {"contents":{"twoColumnSearchResultsRenderer":{"primaryContents":{"sectionListRenderer":{"contents":[{"itemSectionRenderer":{"contents":[
{"videoRenderer":{"videoId":"vid_0000001","title":{"runs":[{"text":"How to learn English {fast} \"today\" — bài 1"}]},"ownerText":{"runs":[{"text":"Channel One"}],"navigationEndpoint":{"browseEndpoint":{"browseId":"UC_channel_1"}}},"lengthText":{"simpleText":"12:34"},"viewCountText":{"simpleText":"1,234,567 views"},"publishedTimeText":{"simpleText":"5 days ago"},"thumbnail":{"thumbnails":[{"url":"https://img/low.jpg"},{"url":"https://img/high.jpg"}]}}},
{"channelRenderer":{"channelId":"UC_channel_2","title":{"simpleText":"Not a video"}}},
{"videoRenderer":{"videoId":"vid_0000002","title":{"runs":[{"text":"Second "},{"text":"video"}]},"longBylineText":{"runs":[{"text":"Channel Two"}],"navigationEndpoint":{"browseEndpoint":{"browseId":"UC_channel_2"}}},"lengthText":{"simpleText":"1:02:03"},"viewCountText":{"runs":[{"text":"1.2M"},{"text":" views"}]},"publishedTimeText":{"simpleText":"Streamed 3 weeks ago"},"thumbnail":{"thumbnails":[{"url":"https://img/v2.jpg"}]}}},
{"richItemRenderer":{"content":{"videoRenderer":{"videoId":"vid_0000003","title":{"simpleText":"Third video"},"ownerText":{"simpleText":"Channel Three"},"lengthText":{"simpleText":"45:00"},"viewCountText":{"simpleText":"No views"},"publishedTimeText":{"simpleText":"2 months ago"},"thumbnail":{"thumbnails":[{"url":"https://img/v3.jpg"}]}}}}},
{"videoRenderer":{"videoId":"vid_0000001","title":{"runs":[{"text":"Trùng của video đầu"}]},"lengthText":{"simpleText":"00:10"}}}
]}}]}}}}};</script>
<script>window["ytInitialData"] = {"other":true};</script>
</body></html>
''';

void main() {
  // now cố định để assert ngày đăng chính xác
  final now = DateTime(2026, 10, 9, 12, 0, 0);

  group('extractYtInitialData', () {
    test('decode object đầu tiên, bỏ qua script khác', () {
      final data = extractYtInitialData(_fixtureHtml);
      expect(data, isNotNull);
      expect(data!['contents'], isA<Map>());
    });

    test('trả về null khi không có marker hoặc JSON hỏng', () {
      expect(extractYtInitialData('<html>no data</html>'), isNull);
      expect(extractYtInitialData('var ytInitialData = {broken'), isNull);
    });
  });

  group('readBalancedJson', () {
    test('bỏ qua ngoặc nằm trong chuỗi kép (kể cả escape)', () {
      const s = '{"a": "x { y \\" } z", "b": 1} trailing';
      expect(readBalancedJson(s, s.indexOf('{')), '{"a": "x { y \\" } z", "b": 1}');
    });

    test('trả về null khi ngoặc không cân bằng', () {
      expect(readBalancedJson('{"a": {"b": 1}', 0), isNull);
    });
  });

  group('parseYtInitialDataHtml', () {
    test('gom videoRenderer, bỏ node không phải video, khử trùng theo videoId', () {
      final hits = parseYtInitialDataHtml(_fixtureHtml, now: now);
      expect(hits.map((h) => h.id), ['vid_0000001', 'vid_0000002', 'vid_0000003']);
    });

    test('map đủ field từ videoRenderer (title có ngoặc/nháy, thumb lấy cái nét nhất)', () {
      final hits = parseYtInitialDataHtml(_fixtureHtml, now: now);
      final first = hits.first;
      expect(first.title, 'How to learn English {fast} "today" — bài 1');
      expect(first.channel, 'Channel One');
      expect(first.channelId, 'UC_channel_1');
      expect(first.thumb, 'https://img/high.jpg');
      expect(first.duration, const Duration(minutes: 12, seconds: 34));
      expect(first.viewCount, 1234567);
      expect(first.publishedAt, DateTime(2026, 10, 4, 12, 0, 0));
    });

    test('ghép runs, dùng longBylineText khi thiếu ownerText', () {
      final hits = parseYtInitialDataHtml(_fixtureHtml, now: now);
      final second = hits[1];
      expect(second.title, 'Second video');
      expect(second.channel, 'Channel Two');
      expect(second.channelId, 'UC_channel_2');
      expect(second.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(second.viewCount, 1200000); // "1.2M views"
      expect(second.publishedAt, DateTime(2026, 9, 18, 12, 0, 0)); // 3 weeks
    });

    test('videoRenderer lồng trong richItemRenderer vẫn được tìm thấy', () {
      final hits = parseYtInitialDataHtml(_fixtureHtml, now: now);
      final third = hits[2];
      expect(third.id, 'vid_0000003');
      expect(third.channel, 'Channel Three'); // ownerText.simpleText
      expect(third.duration, const Duration(minutes: 45));
      expect(third.viewCount, 0); // "No views"
      expect(third.publishedAt, DateTime(2026, 8, 10, 12, 0, 0)); // 2 months = 60 ngày
    });

    test('respect maxResults', () {
      final hits = parseYtInitialDataHtml(_fixtureHtml, maxResults: 2);
      expect(hits, hasLength(2));
    });

    test('HTML không có dữ liệu → list rỗng', () {
      expect(parseYtInitialDataHtml('<html></html>'), isEmpty);
    });

    test('publishedTimeText không phải dạng "ago" → null', () {
      const html =
          '<script>var ytInitialData = {"x":[{"videoRenderer":{"videoId":"vid_0000009","title":{"simpleText":"t"},"publishedTimeText":{"simpleText":"Premiered Oct 1, 2024"}}}]};</script>';
      final hits = parseYtInitialDataHtml(html, now: now);
      expect(hits, hasLength(1));
      expect(hits.single.publishedAt, isNull);
    });
  });

  group('parseLength', () {
    test('các dạng mm:ss / h:mm:ss', () {
      expect(parseLength('0:45'), const Duration(seconds: 45));
      expect(parseLength('12:34'), const Duration(minutes: 12, seconds: 34));
      expect(parseLength('1:02:03'),
          const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('không hợp lệ → null', () {
      expect(parseLength(null), isNull);
      expect(parseLength(''), isNull);
      expect(parseLength('LIVE'), isNull);
      expect(parseLength('12345'), isNull);
    });
  });

  group('parseViewCount', () {
    test('dạng số, dạng K/M/B, No views', () {
      expect(parseViewCount('1,234,567 views'), 1234567);
      expect(parseViewCount('1.2M views'), 1200000);
      expect(parseViewCount('850K views'), 850000);
      expect(parseViewCount('2B views'), 2000000000);
      expect(parseViewCount('No views'), 0);
    });

    test('không có số → null', () {
      expect(parseViewCount(null), isNull);
      expect(parseViewCount(''), isNull);
      expect(parseViewCount('LIVE'), isNull);
    });
  });

  group('parsePublished', () {
    test('các đơn vị ago', () {
      expect(parsePublished('5 days ago', now: now), DateTime(2026, 10, 4, 12));
      expect(parsePublished('Streamed 3 weeks ago', now: now),
          DateTime(2026, 9, 18, 12));
      expect(parsePublished('2 months ago', now: now), DateTime(2026, 8, 10, 12));
      expect(parsePublished('1 year ago', now: now), DateTime(2025, 10, 9, 12));
      expect(parsePublished('2 hours ago', now: now),
          DateTime(2026, 10, 9, 10));
    });

    test('không phải dạng ago → null', () {
      expect(parsePublished(null, now: now), isNull);
      expect(parsePublished('Premiered Oct 1, 2024', now: now), isNull);
    });
  });
}
