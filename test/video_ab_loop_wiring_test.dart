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

    test(
      'exported audio can open in Listen with source title and clip time',
      () {
        final library = File(
          'lib/features/video/widgets/video_library_screen.dart',
        ).readAsStringSync();
        final shell = File('lib/screens/main_shell.dart').readAsStringSync();
        final exportActions =
            File('lib/features/media_tools/media_export_actions.dart')
                .readAsStringSync();

        expect(player.contains('openInListenTab:'), isTrue);
        expect(player.contains('widget.onOpenAudioInListen == null'), isTrue);
        expect(player.contains(r"'${widget.video.title}$timestamp'"), isTrue);
        expect(library.contains('widget.onOpenAudioInListen!(path, title)'),
            isTrue);
        expect(
          library.contains('if (opened && widget.showBackButton)'),
          isTrue,
        );
        expect(library.contains('_popAfterListenOpen'), isTrue);
        expect(
          shell.contains('onOpenAudioInListen: _openVideoExportInListen'),
          isTrue,
        );
        expect(shell.contains('loadSong('), isTrue);
        expect(shell.contains('_setListenMode(0)'), isTrue);
        expect(
          exportActions.contains('openInListenTab: openInListenTab'),
          isTrue,
        );
      },
    );

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
