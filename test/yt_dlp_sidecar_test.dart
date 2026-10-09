// test/yt_dlp_sidecar_test.dart
// WP-Z (PLAN-020) — yt-dlp sidecar: test các hàm thuần (parse progress,
// build args, chọn file phụ đề, map cue). Không cần yt-dlp, không cần mạng,
// không cần desktop.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/video/services/subtitle_parser.dart';
import 'package:in4up/features/youtube/services/yt_dlp_sidecar.dart';

void main() {
  group('parseProgressPercent', () {
    test('đọc đúng phần trăm từ dòng tiến độ của yt-dlp', () {
      // closeTo vì 45.3/100 lệch 1 ULP so với literal 0.453 (IEEE-754)
      expect(
        YtDlpSidecar.parseProgressPercent(
            '[download]  45.3% of    3.21MiB at  1.20MiB/s ETA 00:02'),
        closeTo(0.453, 1e-9),
      );
      expect(
        YtDlpSidecar.parseProgressPercent(
            '[download]   0.0% of    3.21MiB at  1.20MiB/s ETA 00:02'),
        0.0,
      );
      expect(
        YtDlpSidecar.parseProgressPercent(
            '[download] 100% of    3.21MiB in 00:02'),
        1.0,
      );
    });

    test('chấp nhận dấu ~ (kích thước ước lượng)', () {
      expect(
        YtDlpSidecar.parseProgressPercent(
            '[download]  45.3% of ~   3.21MiB at  1.20MiB/s ETA 00:02'),
        closeTo(0.453, 1e-9),
      );
    });

    test('dòng không phải tiến độ → null', () {
      expect(
          YtDlpSidecar.parseProgressPercent('[download] Destination: a.m4a'),
          isNull);
      expect(
          YtDlpSidecar.parseProgressPercent('ERROR: Video unavailable'),
          isNull);
      expect(YtDlpSidecar.parseProgressPercent('[Merger] Merging formats'),
          isNull);
      expect(YtDlpSidecar.parseProgressPercent(''), isNull);
    });
  });

  group('buildCaptionArgs', () {
    test('chứa đủ cờ bắt buộc, url ở cuối, template trong outDir', () {
      final args = YtDlpSidecar.buildCaptionArgs(
          videoId: 'dQw4w9wgXcQ', outDir: '/tmp/x', lang: 'en');
      expect(args,
          containsAll(['--write-sub', '--write-auto-sub', '--skip-download']));
      expect(args, contains('--sub-langs'));
      expect(args, contains('en'));
      expect(args, contains('vtt'));
      expect(args.last, 'https://www.youtube.com/watch?v=dQw4w9wgXcQ');
      expect(args.any((a) => a.contains('/tmp/x') && a.contains('%(id)s')),
          isTrue);
    });
  });

  group('buildAudioArgs', () {
    test('extract: có -x + audio-format m4a + audio-quality + --newline', () {
      final args = YtDlpSidecar.buildAudioArgs(
          videoId: 'dQw4w9wgXcQ',
          outDir: '/tmp/x',
          audioQuality: 5,
          extract: true);
      expect(
          args, containsAll(['-x', '--audio-format', 'm4a', '--audio-quality']));
      expect(args, contains('5'));
      expect(args, contains('--newline'));
      expect(args.any((a) => a.contains('%(id)s')), isTrue);
      expect(args.last, 'https://www.youtube.com/watch?v=dQw4w9wgXcQ');
    });

    test('không extract: dùng format selector, không cần ffmpeg', () {
      final args = YtDlpSidecar.buildAudioArgs(
          videoId: 'dQw4w9wgXcQ', outDir: '/tmp/x', extract: false);
      expect(args, isNot(contains('-x')));
      expect(args, contains('-f'));
      expect(args.any((a) => a.contains('bestaudio')), isTrue);
      expect(args.last, 'https://www.youtube.com/watch?v=dQw4w9wgXcQ');
    });
  });

  group('pickSubtitleFile', () {
    const id = 'dQw4w9wgXcQ';

    test('ưu tiên bản đúng ngôn ngữ', () {
      final files = ['/tmp/$id.en.vtt', '/tmp/$id.vi.vtt', '/tmp/$id.srt'];
      expect(YtDlpSidecar.pickSubtitleFile(files, id, 'vi'),
          '/tmp/$id.vi.vtt');
      expect(YtDlpSidecar.pickSubtitleFile(files, id, 'en'),
          '/tmp/$id.en.vtt');
    });

    test('không đúng ngôn ngữ thì lấy bản cùng id (fallback)', () {
      final files = ['/tmp/$id.fr.vtt'];
      expect(YtDlpSidecar.pickSubtitleFile(files, id, 'en'),
          '/tmp/$id.fr.vtt');
    });

    test('không có file sub → null', () {
      expect(YtDlpSidecar.pickSubtitleFile(['/tmp/$id.m4a'], id, 'en'), isNull);
      expect(YtDlpSidecar.pickSubtitleFile([], id, 'en'), isNull);
    });

    test('đường dẫn Windows cũng đọc được tên file', () {
      final files = ['C:\\tmp\\$id.en.vtt'];
      expect(YtDlpSidecar.pickSubtitleFile(files, id, 'en'),
          'C:\\tmp\\$id.en.vtt');
    });
  });

  group('cuesToCaptionLines', () {
    test('map cue → YtCaptionLine, bỏ dòng chỉ có tag', () {
      final cues = SubtitleParser.parseSrt('''
1
00:00:01,000 --> 00:00:03,000
Hello

2
00:00:04,000 --> 00:00:06,000
<i></i>
''');
      final lines = YtDlpSidecar.cuesToCaptionLines(cues);
      expect(lines, hasLength(1));
      expect(lines.single.start, const Duration(seconds: 1));
      expect(lines.single.end, const Duration(seconds: 3));
      expect(lines.single.text, 'Hello');
    });
  });
}
