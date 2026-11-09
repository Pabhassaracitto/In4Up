import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final player =
      File('lib/features/video/widgets/video_player_screen.dart').readAsStringSync();

  group('local video A–B loop wiring', () {
    test('player keeps its native position as the loop clock', () {
      expect(player.contains('_abLoop.wrapTarget(position)'), isTrue);
      expect(player.contains('unawaited(c.seekTo(target))'), isTrue);
      expect(player.contains('_loopRewindPending'), isTrue);
    });

    test('manual markers, subtitle cue loop, clear and A-B export are exposed',
        () {
      expect(player.contains('onPressed: _markLoopA'), isTrue);
      expect(player.contains('onPressed: _abLoop.hasA ? _markLoopB : null'),
          isTrue);
      expect(player.contains('onPressed: _loopCurrentCue'), isTrue);
      expect(player.contains('onPressed: _clearLoop'), isTrue);
      expect(player.contains("value: 'clip_ab_audio'"), isTrue);
      expect(player.contains('clipDuration: end - start'), isTrue);
    });

    test('new chrome phrase is in every priority native locale', () {
      final pack = jsonDecode(
        File('tool/priority_native_pack.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in [
        'Xuất đoạn A-B',
        'Đặt B cách A ít nhất 0,3 giây',
      ]) {
        final entry = pack[key] as Map<String, dynamic>;
        for (final locale in [
          'en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja',
        ]) {
          expect(entry[locale], isNotNull, reason: '$key missing locale $locale');
          expect(entry[locale], isNotEmpty, reason: '$key empty locale $locale');
        }
      }
    });
  });
}
