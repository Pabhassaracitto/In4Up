import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_video.dart';

void main() {
  group('YtVideo.isUsableDataApiKey', () {
    test('rejects empty and placeholder keys, accepts real main_shell key', () {
      expect(YtVideo.isUsableDataApiKey(null), isFalse);
      expect(YtVideo.isUsableDataApiKey(''), isFalse);
      expect(YtVideo.isUsableDataApiKey('AIzaSy...YOUR_KEY_HERE'), isFalse);
      expect(YtVideo.isUsableDataApiKey('  YOUR_KEY  '), isFalse);
      // Key thật đang nằm trong main_shell.dart (56f2c15) — phải usable,
      // không thì UI YouTube báo "key chưa hợp lệ" sai sự thật.
      // (74232c5 từng assert isFalse với key này — test FAIL khi chạy
      // `flutter test`; CI không bắt vì workflow chỉ chạy locale test.)
      expect(
        YtVideo.isUsableDataApiKey('AIzaSyCpGdv7ESAJkH5-FYIC8-x0R0EWGgvK0Lg'),
        isTrue,
      );
      expect(
        YtVideo.isUsableDataApiKey('AIzaSyAbcdefghijklmnopqrstuvwxyz012345'),
        isTrue,
      );
    });
  });

  group('YtVideo.extractId', () {
    test('parses watch, short, embed and raw id', () {
      expect(
        YtVideo.extractId('https://www.youtube.com/watch?v=dQw4w9wgXcQ'),
        'dQw4w9wgXcQ',
      );
      expect(
        YtVideo.extractId('https://youtu.be/dQw4w9wgXcQ'),
        'dQw4w9wgXcQ',
      );
      expect(
        YtVideo.extractId('https://www.youtube.com/embed/dQw4w9wgXcQ'),
        'dQw4w9wgXcQ',
      );
      expect(
        YtVideo.extractId('https://www.youtube.com/shorts/dQw4w9wgXcQ'),
        'dQw4w9wgXcQ',
      );
      expect(YtVideo.extractId('dQw4w9wgXcQ'), 'dQw4w9wgXcQ');
      expect(YtVideo.extractId('not a url'), isNull);
    });
  });

  group('YtCaptionLine.toLrc', () {
    test('writes timestamp and optional translation', () {
      const line = YtCaptionLine(
        Duration(minutes: 1, seconds: 2, milliseconds: 300),
        Duration(minutes: 1, seconds: 4),
        'Hello world',
        translation: 'Xin chào',
      );
      expect(line.toLrc(), '[01:02.30]Hello world | Xin chào');
    });
  });
}
