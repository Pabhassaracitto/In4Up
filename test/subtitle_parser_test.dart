// test/subtitle_parser_test.dart
// I4U18-VIDEO-LIB-001 — parser phụ đề (SRT/VTT/LRC/ASS) + cueAt.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/video/services/subtitle_parser.dart';

void main() {
  group('SRT', () {
    const srt = '''
1
00:00:01,000 --> 00:00:03,500
Hello world

2
00:00:04,000 --> 00:00:06,000
<i>Second line</i>
extra
''';

    test('parse cơ bản + strip tag', () {
      final cues = SubtitleParser.parseSrt(srt);
      expect(cues, hasLength(2));
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 3, milliseconds: 500));
      expect(cues[0].text, 'Hello world');
      expect(cues[1].text, 'Second line\nextra');
    });

    test('cueAt trả cue đúng thời điểm', () {
      final cues = SubtitleParser.parseSrt(srt);
      expect(SubtitleParser.cueAt(cues, const Duration(seconds: 2))?.text,
          'Hello world');
      expect(SubtitleParser.cueAt(cues, const Duration(milliseconds: 3600)),
          isNull);
      expect(SubtitleParser.cueAt(cues, const Duration(seconds: 5))?.text,
          'Second line\nextra');
    });
  });

  group('WebVTT', () {
    const vtt = '''
WEBVTT

00:00:01.000 --> 00:00:02.000
Xin chào

00:00:03.000 --> 00:00:04.000
Tạm biệt
''';

    test('bỏ header WEBVTT + parse dấu chấm ms', () {
      final cues = SubtitleParser.parse(vtt, ext: 'vtt');
      expect(cues, hasLength(2));
      expect(cues[0].text, 'Xin chào');
      expect(cues[1].start, const Duration(seconds: 3));
    });
  });

  group('LRC', () {
    const lrc = '''
[00:01.00]Line one
[00:03.50]Line two
''';

    test('end = start của cue kế tiếp', () {
      final cues = SubtitleParser.parse(lrc, ext: 'lrc');
      expect(cues, hasLength(2));
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 3, milliseconds: 500));
      expect(cues[0].text, 'Line one');
    });
  });

  group('ASS', () {
    const ass = '''
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.50,Default,,0,0,0,,{\\i1}Hello{\\i0}, world
''';

    test('parse Dialogue + strip override + giữ dấu phẩy trong text', () {
      final cues = SubtitleParser.parse(ass, ext: 'ass');
      expect(cues, hasLength(1));
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 2, milliseconds: 500));
      expect(cues[0].text, 'Hello, world');
    });
  });
}
