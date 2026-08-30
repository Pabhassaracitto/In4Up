import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_video.dart';

void main() {
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
