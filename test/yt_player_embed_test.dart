// IN4-78 — YouTube báo lỗi 153 khi phát video.
//
// Root cause: từ ~10/2025 YouTube bắt buộc request trang nhúng (/embed/)
// phải có HTTP Referer hợp lệ; WebView load thẳng /embed/ (load đầu, không
// có trang trước) → không gửi Referer → "Lỗi cấu hình trình phát video,
// mã 153".
//
// Fix: tải TRƯỚC trang seed cùng domain (`youtube-nocookie.com/embed`),
// rồi điều hướng tới /embed/<id> — request lúc đó tự mang Referer (mặc
// định referrer policy của WebView gửi origin). Test pin phần quyết định
// này (không cần WebView thật).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/yt_player_screen.dart';

void main() {
  group('kYtEmbedSeedUrl (IN4-78)', () {
    test('phải là https (Referer không bảo mật vô dụng)', () {
      expect(kYtEmbedSeedUrl, startsWith('https://'));
    });

    test('phải CÙNG domain với trang embed thật (nguồn của Referer)', () {
      final seed = Uri.parse(kYtEmbedSeedUrl);
      final embed = Uri.parse(buildYtEmbedUrl('x'));
      expect(seed.host, embed.host);
    });
  });

  group('buildYtEmbedUrl (IN4-78)', () {
    test('nhúng đúng video ID trên domain nocookie (domain nhúng chuẩn)', () {
      const id = 'dQw4w9WgXcQ';
      final url = buildYtEmbedUrl(id);
      expect(url, contains('youtube-nocookie.com/embed/$id'));
      expect(url, isNot(contains('www.youtube.com/embed/')));
    });

    test('giữ parameters cũ: enablejsapi + cc_off + rel=0 + playsinline',
        () {
      final url = buildYtEmbedUrl('x');
      expect(url, contains('enablejsapi=1'));
      expect(url, contains('cc_load_policy=0'));
      expect(url, contains('rel=0'));
      expect(url, contains('playsinline=1'));
    });

    test('origin khớp domain thực (player kiểm tra referrer theo param này)',
        () {
      final url = buildYtEmbedUrl('x');
      expect(url, contains('origin=https://www.youtube-nocookie.com'));
    });
  });

  group('ytLooksLikePlayerError (IN4-78)', () {
    test('phát hiện màn lỗi tiếng Việt (mã 153 theo screenshot owner)', () {
      expect(
        ytLooksLikePlayerError(
            'Lỗi cấu hình trình phát video\nMã lỗi 153'),
        isTrue,
      );
    });

    test('phát hiện "lỗi cấu hình" + 153 tách dòng', () {
      expect(ytLooksLikePlayerError('Lỗi cấu hình\n153'), isTrue);
    });

    test('phát hiện bản tiếng Anh', () {
      expect(
        ytLooksLikePlayerError('Video player configuration error. Error 153'),
        isTrue,
      );
    });

    test('trang player bình thường / phụ đề / trống → KHÔNG báo lỗi', () {
      expect(ytLooksLikePlayerError(''), isFalse);
      expect(ytLooksLikePlayerError('Hello world, this is a video'), isFalse);
      expect(ytLooksLikePlayerError('Phụ đề tiếng Việt cho bài học'), isFalse);
      // Số 153 xuất hiện bình thường (phụ đề có con số) mà không kèm
      // "lỗi cấu hình" → không dương tính giả.
      expect(ytLooksLikePlayerError('Năm 153 sau công nguyên'), isFalse);
    });
  });
}
