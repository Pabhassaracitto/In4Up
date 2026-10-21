// IN4-78 — YouTube báo lỗi 153 khi phát video.
//
// Root cause: từ ~07/2025 YouTube bắt buộc request trang nhúng (/embed/)
// phải có HTTP Referer hợp lệ ("must provide identification through the
// HTTP Referer request header" — YouTube IFrame API docs). WebView của
// app không tạo đủ Referrer cho load top-level → "Lỗi cấu hình trình
// phát video, mã 153". (Mất ~1 tuần xác minh trên máy thật: cách seed
// same-origin vẫn bị 153 ⇒ cần origin https THẬT.)
//
// Chain fix (từ chắc chắn nhất):
// 1) wrapper static trên GitHub Pages (origin https thật) → iframe
//    /embed/ bên trong tự gửi Referer thật;
// 2) seed → /embed/<id> (Referer same-origin) — fallback;
// 3) overlay + "Mở ngoài" trong trình duyệt/app hệ thống.
// Test pin phần quyết định này (không cần WebView thật).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/yt_player_screen.dart';

void main() {
  group('wrapper GitHub Pages (IN4-78)', () {
    test('kYtWrapperBaseUrl là https trên origin github.io thật', () {
      final u = Uri.parse(kYtWrapperBaseUrl);
      expect(u.scheme, 'https');
      expect(u.host, 'pabhassaracitto.github.io');
      expect(u.path, endsWith('/yt_embed.html'));
    });

    test('buildYtWrapperUrl gắn videoId đúng', () {
      const id = 'dQw4w9WgXcQ';
      final url = Uri.parse(buildYtWrapperUrl(id));
      expect(url.queryParameters['videoId'], id);
      expect(url.host, 'pabhassaracitto.github.io');
    });
  });

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

  group('ytParseTimeMessage (IN4-78)', () {
    test('t:<s> → giây', () {
      expect(ytParseTimeMessage('t:12.345'), 12.345);
      expect(ytParseTimeMessage('t:0'), 0.0);
    });

    test('không phải tin thời gian → null (không throw)', () {
      expect(ytParseTimeMessage('ready'), isNull);
      expect(ytParseTimeMessage('state:1'), isNull);
      expect(ytParseTimeMessage('err:153'), isNull);
      expect(ytParseTimeMessage('t:abc'), isNull);
      expect(ytParseTimeMessage(''), isNull);
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

  // IN4-109 (2026-10-21) — wrapper HTML phải nằm trong REPO (version
  // controlled) + đủ tham số bắt buộc, nếu không player báo lỗi -1.
  group('web/yt_embed.html — file wrapper trong repo (IN4-109)', () {
    final wrapper = File('web/yt_embed.html').readAsStringSync();

    test('file wrapper nằm trong repo (không chỉ ở nhánh gh-pages)', () {
      expect(wrapper.contains('<html'), isTrue);
      expect(wrapper.contains('onYouTubeIframeAPIReady'), isTrue);
    });

    test('có playerVar origin + enablejsapi (thiếu ⇒ player error -1)', () {
      expect(
        wrapper.contains('origin: location.origin'),
        isTrue,
        reason: 'Dùng host youtube-nocookie.com thì BẮT BUỘC phải có '
            'playerVar origin — thiếu ⇒ YouTube trả mã -1 (INVALID_PARAMETER).',
      );
      expect(
        wrapper.contains('enablejsapi: 1'),
        isTrue,
        reason: 'Cần JS API để app điều khiển player (seek/pause/play).',
      );
    });

    test('có fallback sang www.youtube.com khi nocookie lỗi', () {
      expect(
        wrapper.contains("host: 'https://www.youtube.com'"),
        isTrue,
        reason: 'Mạng chặn nocookie thì phải thử được host thường.',
      );
    });

    test('giữ nguyên API surface cho app (seek/pause/play + postMessage)', () {
      expect(wrapper.contains('_in4upSeek'), isTrue);
      expect(wrapper.contains('_in4upPause'), isTrue);
      expect(wrapper.contains('_in4upPlay'), isTrue);
      expect(wrapper.contains("post('ready')"), isTrue);
      expect(wrapper.contains("post('err:'"), isTrue);
    });
  });

  // IN4-109 (2026-10-21) — trang web TRẮNG vì CanvasKit tải từ CDN gstatic.
  group('web/flutter_bootstrap.js — CanvasKit cục bộ (IN4-109)', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    test('bootstrap có template token của Flutter', () {
      expect(bootstrap.contains('{{flutter_js}}'), isTrue);
      expect(bootstrap.contains('{{flutter_build_config}}'), isTrue);
    });

    test('trỏ CanvasKit về thư mục CỤC BỘ (không phụ thuộc CDN)', () {
      expect(
        bootstrap.contains('canvasKitBaseUrl: "canvaskit/"'),
        isTrue,
        reason: 'Mặc định Flutter tải CanvasKit từ gstatic.com ⇒ mạng chặn '
            'CDN là trang trắng. Build có sẵn canvaskit/ cục bộ.',
      );
      // Chỉ kiểm CONFIG (không kiểm cả comment trong file).
      expect(
        bootstrap.contains('canvasKitBaseUrl: "https://www.gstatic.com'),
        isFalse,
        reason: 'Không được trỏ CanvasKit về CDN.',
      );
      expect(bootstrap.contains('useLocalCanvasKit: false'), isFalse);
    });

    test('vẫn đăng ký service worker (để SW cũ bị thay, không giữ file lỗi)', () {
      expect(bootstrap.contains('serviceWorkerSettings'), isTrue);
      expect(bootstrap.contains('{{flutter_service_worker_version}}'), isTrue);
    });
  });
}
