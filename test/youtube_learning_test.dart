import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_video.dart';
import 'package:in4up/features/youtube/yt_data_api.dart';

void main() {
  group('YtVideo.isUsableDataApiKey', () {
    test('rejects empty and placeholder main_shell key', () {
      expect(YtVideo.isUsableDataApiKey(null), isFalse);
      expect(YtVideo.isUsableDataApiKey(''), isFalse);
      expect(YtVideo.isUsableDataApiKey('AIzaSy...YOUR_KEY_HERE'), isFalse);
      expect(YtVideo.isUsableDataApiKey('  YOUR_KEY  '), isFalse);
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

  group('YtDataApi', () {
    test('rejects placeholder keys and accepts configured key', () {
      expect(YtVideo.isUsableDataApiKey(YtDataApi.key), isTrue);
      expect(YtDataApi.isConfigured, isTrue);
    });

    test('looksLikeWatchInput vs free-text search', () {
      expect(
        YtDataApi.looksLikeWatchInput(
          'https://www.youtube.com/watch?v=dQw4w9wgXcQ',
        ),
        isTrue,
      );
      expect(YtDataApi.looksLikeWatchInput('learn english news'), isFalse);
      expect(YtDataApi.looksLikeWatchInput('dQw4w9wgXcQ'), isTrue);
    });

    test('search URI uses q or default discover query', () {
      final discovered = YtDataApi.search(apiKey: 'k');
      expect(discovered.queryParameters['q'], YtDataApi.defaultDiscoverQuery);
      expect(discovered.queryParameters['type'], 'video');

      final typed = YtDataApi.search(apiKey: 'k', q: 'bbc 6 minute english');
      expect(typed.queryParameters['q'], 'bbc 6 minute english');

      final channel = YtDataApi.search(
        apiKey: 'k',
        channelId: 'UCVHFbw7woebKtfvug_Nzpig',
      );
      expect(channel.queryParameters['channelId'], 'UCVHFbw7woebKtfvug_Nzpig');
      expect(channel.queryParameters.containsKey('q'), isFalse);
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
