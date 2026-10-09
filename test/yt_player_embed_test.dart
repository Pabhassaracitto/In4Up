// IN4-78 — YouTube báo lỗi 153 khi phát video.
//
// Root cause: từ ~10/2025 YouTube bắt buộc request video nhúng phải có
// HTTP Referer hợp lệ; WebView load thẳng `youtube.com/embed/...` không
// gửi Referer → "Lỗi cấu hình trình phát video, mã 153".
//
// Fix: wrapper page load bằng `loadHtml(html, baseUrl:)` (Android:
// loadDataWithBaseURL → request con mang Referer = base URL) + host
// `youtube-nocookie.com` + meta referrer. Test pin phần quyết định này
// (không cần WebView thật).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/yt_player_screen.dart';

void main() {
  group('kYtEmbedBase (IN4-78)', () {
    test('phải là https (YouTube từ chối base URL không bảo mật làm Referer)',
        () {
      expect(kYtEmbedBase.scheme, 'https');
      expect(kYtEmbedBase.host, isNotEmpty);
    });

    test('host cố định — đổi là phải có lý do + cập nhật test', () {
      expect(kYtEmbedBase.toString(), 'https://in4up.app/embed');
    });
  });

  group('buildYtEmbedHtml (IN4-78)', () {
    test('nhúng đúng video ID', () {
      const id = 'dQw4w9WgXcQ';
      final html = buildYtEmbedHtml(id);
      expect(html, contains('var VIDEO_ID = "$id";'));
    });

    test('video ID lạ không phá vỡ JS (escape nháy kép)', () {
      final html = buildYtEmbedHtml('abc"def');
      expect(html, isNot(contains('VIDEO_ID = "abc"def"')));
      expect(html, contains('var VIDEO_ID = "abcdef";'));
    });

    test('dùng host youtube-nocookie.com (domain nhúng chuẩn của Google)',
        () {
      expect(buildYtEmbedHtml('x'), contains('youtube-nocookie.com'));
    });

    test('tải IFrame API chính chủ + player có onReady/onError', () {
      final html = buildYtEmbedHtml('x');
      expect(html, contains('https://www.youtube.com/iframe_api'));
      expect(html, contains('onReady'));
      expect(html, contains('onError'));
      expect(html, contains("post('err:' + e.data)"));
    });

    test('referrer policy phòng khi nền tảng bỏ qua base URL', () {
      expect(
        buildYtEmbedHtml('x'),
        contains('strict-origin-when-cross-origin'),
      );
    });

    test('kênh YtSync + tick 250ms (đồng bộ phụ đề) + lệnh seek/pause/play',
        () {
      final html = buildYtEmbedHtml('x');
      expect(html, contains('window.YtSync'));
      expect(html, contains("post('t:'"));
      expect(html, contains('setInterval(tick, 250)'));
      expect(html, contains('window._in4upSeek'));
      expect(html, contains('window._in4upPause'));
      expect(html, contains('window._in4upPlay'));
    });

    test('playsinline + rel=0 (giữ hành vi cũ: xem inline, không gợi ý video khác)',
        () {
      expect(buildYtEmbedHtml('x'), contains('playsinline: 1'));
      expect(buildYtEmbedHtml('x'), contains('rel: 0'));
    });
  });

  group('ytParseTimeMessage (IN4-78)', () {
    test('t:<s> → giây', () {
      expect(ytParseTimeMessage('t:12.345'), 12.345);
      expect(ytParseTimeMessage('t:0'), 0.0);
    });

    test('không phải tin thời gian → null', () {
      expect(ytParseTimeMessage('ready'), isNull);
      expect(ytParseTimeMessage('state:1'), isNull);
      expect(ytParseTimeMessage('err:153'), isNull);
      expect(ytParseTimeMessage(''), isNull);
    });

    test('t: rác → null (không throw)', () {
      expect(ytParseTimeMessage('t:abc'), isNull);
      expect(ytParseTimeMessage('t:'), isNull);
    });
  });

  group('describeYtPlayerError (IN4-78)', () {
    test('mã 153 → giải thích chính sách referrer + gợi ý hành động', () {
      final msg = describeYtPlayerError('153');
      expect(msg, contains('153'));
      expect(msg, contains('Thử lại'));
    });

    test('mã 100/120 → video không tồn tại', () {
      expect(describeYtPlayerError('100'), contains('Không tìm thấy video'));
      expect(describeYtPlayerError('120'), contains('Không tìm thấy video'));
    });

    test('mã 101/150 → chủ video cấm nhúng', () {
      expect(describeYtPlayerError('101'), contains('không cho phép'));
      expect(describeYtPlayerError('150'), contains('không cho phép'));
    });

    test('mã lạ → vẫn nêu được mã (để owner báo lại)', () {
      expect(describeYtPlayerError('999'), contains('999'));
    });
  });
}
