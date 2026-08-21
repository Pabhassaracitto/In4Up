// test/sound_auto_toc_test.dart
// Test logic thuần của bộ máy tự tạo mục lục (không cần thiết bị/audio).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/vad_settings.dart';
import 'package:in4up/providers/soundlist_provider.dart';
import 'package:in4up/services/sound_auto_toc_service.dart';
import 'package:in4up_stt/in4up_stt.dart';

SttSegment _seg(int id, double startSec, double endSec, String text) {
  return SttSegment(
    id: id,
    uid: 'u$id',
    startSeconds: startSec,
    endSeconds: endSec,
    text: text,
    words: const [],
    avgConfidence: 0.9,
  );
}

void main() {
  group('SoundAutoTocService.buildChapters', () {
    test('slices + whisper → chapter per slice, title = first sentence', () {
      final slices = [
        const AudioSlice(
          start: Duration(seconds: 0),
          end: Duration(seconds: 30),
        ),
        const AudioSlice(
          start: Duration(seconds: 30),
          end: Duration(seconds: 60),
        ),
      ];
      final segments = [
        _seg(0, 0.5, 8.0, 'Xin chào, hôm nay chúng ta học về Tứ Niệm Xứ.'),
        _seg(1, 8.0, 20.0, 'Thân là vô thường.'),
        _seg(2, 35.0, 45.0, 'Cảm thọ cũng vô thường.'),
      ];

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/1.mp3',
        slices: slices,
        sttSegments: segments,
        useWhisper: true,
      );

      expect(chapters, hasLength(2));
      expect(chapters[0].title, 'Xin chào, hôm nay chúng ta học về Tứ Niệm Xứ.');
      expect(chapters[0].position, const Duration(seconds: 0));
      expect(chapters[1].title, 'Cảm thọ cũng vô thường.');
      expect(chapters[1].position, const Duration(seconds: 30));
    });

    test('slices only (no whisper) → fallback "Đoạn N · mm:ss"', () {
      final slices = [
        const AudioSlice(
          start: Duration(seconds: 0),
          end: Duration(seconds: 40),
        ),
        const AudioSlice(
          start: Duration(seconds: 40),
          end: Duration(seconds: 90),
        ),
      ];

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/2.mp3',
        slices: slices,
        useWhisper: false,
      );

      expect(chapters, hasLength(2));
      expect(chapters[0].title, 'Đoạn 1 · 00:00');
      expect(chapters[1].title, 'Đoạn 2 · 00:40');
      expect(chapters[0].position, const Duration(seconds: 0));
      expect(chapters[1].position, const Duration(seconds: 40));
    });

    test('no slices, many whisper segments → grouped ≤ 80 chapters', () {
      final segments = List.generate(120, (i) {
        return _seg(
          i,
          i * 2.0,
          i * 2.0 + 1.5,
          'Câu số $i nội dung khá dài để kiểm tra việc gom nhóm chapter.',
        );
      });

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/3.mp3',
        slices: const [],
        sttSegments: segments,
        useWhisper: true,
      );

      expect(chapters.length, lessThanOrEqualTo(80));
      expect(chapters.first.position, const Duration(seconds: 0));
      expect(chapters.first.title, contains('Câu số'));
    });

    test('title is truncated to 64 chars and cleaned', () {
      final long = '  --  '
          'Từ bi là một phẩm chất vô cùng quan trọng trong đời sống tâm linh '
          'và chúng ta nên thực tập mỗi ngày để tâm được an lạc hơn.';
      final segments = [_seg(0, 1, 5, long)];

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/4.mp3',
        slices: const [
          AudioSlice(start: Duration.zero, end: Duration(seconds: 30)),
        ],
        sttSegments: segments,
        useWhisper: true,
      );

      expect(chapters.single.title.length, lessThanOrEqualTo(65));
      expect(chapters.single.title, isNot(startsWith('--')));
    });
  });

  group('SoundlistProvider.transcriptFromLrcLines', () {
    test('builds lines with end = next line timestamp (fallback +3s)', () {
      final provider = SoundlistProvider();
      final lines = [
        LrcLine(timestamp: const Duration(seconds: 1), text: 'Hello world'),
        LrcLine(timestamp: const Duration(seconds: 5), text: 'Second line'),
        LrcLine(timestamp: const Duration(seconds: 5), text: '   '), // bỏ dòng trống
      ];

      final t = provider.transcriptFromLrcLines('/a.mp3', lines);

      expect(t, isNotNull);
      expect(t!.lineCount, 2);
      expect(t.lines[0].text, 'Hello world');
      expect(t.lines[0].start, const Duration(seconds: 1));
      expect(t.lines[0].end, const Duration(seconds: 5));
      expect(t.lines[1].end, const Duration(seconds: 8)); // dòng cuối + 3s
      expect(t.fullText, contains('Second line'));
    });

    test('returns null for empty lines', () {
      final provider = SoundlistProvider();
      expect(provider.transcriptFromLrcLines('/a.mp3', const []), isNull);
    });
  });

  group('SoundAutoTocService.computeBoundaryMs', () {
    test('phát hiện ranh giới ở giữa khoảng lặng dài', () {
      // 600 mẫu = 60s (1 mẫu = 100ms): nói 20s, lặng 8s (200..280), nói tiếp.
      final peaks = List<double>.generate(600, (i) {
        if (i >= 200 && i < 280) return 0.01; // im lặng
        return 0.7; // có tiếng
      });

      final boundaries = SoundAutoTocService.computeBoundaryMs(
        peaks,
        60000,
        settings: VadSettings.normal, // minSilence 0.9s
      );

      expect(boundaries, isNotEmpty);
      // Ranh giới ~ giữa khoảng lặng: (200+280)/2 = 240 → 24000ms.
      expect(boundaries.first, closeTo(24000, 2000));
    });

    test('không có im lặng → không có ranh giới (UI sẽ dùng fallback chia đều)', () {
      final peaks = List<double>.filled(600, 0.8);
      final boundaries = SoundAutoTocService.computeBoundaryMs(
        peaks,
        60000,
        settings: VadSettings.normal,
      );
      expect(boundaries, isEmpty);
    });
  });
}
