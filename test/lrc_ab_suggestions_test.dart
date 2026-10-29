// test/lrc_ab_suggestions_test.dart
// SHADOW-FILE-001 — gợi ý A-B theo câu từ LRC + chỉnh tay A-B:
//  - mỗi câu LRC = 1 gợi ý; A = timestamp câu, B = timestamp câu kế
//  - câu cuối: kéo tới duration bài (hoặc fallback 4s)
//  - gợi ý cho câu đang phát
//  - nudge ± clamp hợp lệ (0 ≤ A < B, B ≤ duration)

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/services/lrc_ab_suggestions.dart';
import 'package:in4up_stt/stt_lrc_converter.dart' show LrcLine;

void main() {
  LrcLine line(int seconds, String text) =>
      LrcLine(timestamp: Duration(seconds: seconds), text: text);

  final lines = [
    line(0, 'Hello there.'),
    line(5, 'How are you?'),
    line(12, 'I am fine, thanks.'),
    line(20, ''),
    line(30, 'Let us start the poem.'),
  ];

  group('buildSentenceSuggestions', () {
    test('mỗi câu không-rỗng = 1 gợi ý, A=timestamp câu, B=đầu câu kế', () {
      final sugg = LrcAbSuggestions.buildSentenceSuggestions(
        lines: lines,
        trackDuration: const Duration(seconds: 40),
      );

      // Câu rỗng (index 3) bị bỏ qua → 4 gợi ý.
      expect(sugg, hasLength(4));

      expect(sugg[0].start, Duration.zero);
      expect(sugg[0].end, const Duration(seconds: 5));
      expect(sugg[1].start, const Duration(seconds: 5));
      expect(sugg[1].end, const Duration(seconds: 12));

      // Câu gần cuối có B = timestamp câu cuối (trừ pad 50ms).
      expect(
        sugg[2].end,
        const Duration(seconds: 30) - const Duration(milliseconds: 50),
      );

      // Câu cuối kéo tới duration bài.
      expect(sugg[3].start, const Duration(seconds: 30));
      expect(sugg[3].end, const Duration(seconds: 40));
      expect(sugg[3].text, 'Let us start the poem.');
    });

    test('không biết duration bài → câu cuối fallback 4s', () {
      final sugg = LrcAbSuggestions.buildSentenceSuggestions(lines: lines);
      final last = sugg.last;
      expect(last.end - last.start, const Duration(seconds: 4));
    });

    test('input chưa sort vẫn đúng (defensive sort)', () {
      final shuffled = [lines[2], lines[0], lines[1], lines[4]];
      final sugg = LrcAbSuggestions.buildSentenceSuggestions(
        lines: shuffled,
        trackDuration: const Duration(seconds: 40),
      );
      expect(sugg.first.start, Duration.zero);
      expect(sugg.first.text, 'Hello there.');
      expect(sugg[1].start, const Duration(seconds: 5));
    });

    test('câu kế quá sát → đoạn vẫn đủ dài tối thiểu để luyện', () {
      final tight = [
        line(10, 'A'),
        line(10, 'B'), // cùng timestamp — sát nhau bất thường
        line(20, 'C'),
      ];
      final sugg = LrcAbSuggestions.buildSentenceSuggestions(
        lines: tight,
        trackDuration: const Duration(seconds: 60),
      );
      for (final s in sugg) {
        expect(
          s.end - s.start,
          greaterThanOrEqualTo(LrcAbSuggestions.minSegmentLength),
        );
      }
    });

    test('list rỗng → không gợi ý', () {
      expect(
        LrcAbSuggestions.buildSentenceSuggestions(lines: const []),
        isEmpty,
      );
    });
  });

  group('suggestionAtPosition — dùng câu đang phát', () {
    test('vị trí giữa câu → trả đúng câu đó', () {
      final hit = LrcAbSuggestions.suggestionAtPosition(
        lines: lines,
        position: const Duration(seconds: 7),
        trackDuration: const Duration(seconds: 40),
      );
      expect(hit, isNotNull);
      expect(hit!.text, 'How are you?');
      expect(hit.start, const Duration(seconds: 5));
      expect(hit.end, const Duration(seconds: 12));
    });

    test('trước câu đầu → gợi ý câu đầu tiên (tiện hơn là không gợi)', () {
      final before = LrcAbSuggestions.suggestionAtPosition(
        lines: [line(10, 'First'), line(20, 'Second')],
        position: Duration.zero,
      );
      expect(before!.text, 'First');
    });

    test('không có câu → null', () {
      expect(
        LrcAbSuggestions.suggestionAtPosition(
          lines: const [],
          position: const Duration(seconds: 5),
        ),
        isNull,
      );
    });
  });

  group('nudgeLoop — chỉnh tay A-B', () {
    test('tăng/giảm A và B bình thường', () {
      final r1 = LrcAbSuggestions.nudgeLoop(
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 20),
        moveStart: true,
        delta: const Duration(milliseconds: -500),
        trackDuration: const Duration(seconds: 60),
      );
      expect(r1.start, const Duration(milliseconds: 9500));
      expect(r1.end, const Duration(seconds: 20));

      final r2 = LrcAbSuggestions.nudgeLoop(
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 20),
        moveStart: false,
        delta: const Duration(milliseconds: 500),
        trackDuration: const Duration(seconds: 60),
      );
      expect(r2.end, const Duration(milliseconds: 20500));
    });

    test('A không về trước 0 và không vượt quá B - tối thiểu', () {
      final min = LrcAbSuggestions.minSegmentLength;

      final clampLow = LrcAbSuggestions.nudgeLoop(
        start: const Duration(milliseconds: 300),
        end: const Duration(seconds: 5),
        moveStart: true,
        delta: const Duration(seconds: -10),
      );
      expect(clampLow.start, Duration.zero);

      final clampHigh = LrcAbSuggestions.nudgeLoop(
        start: const Duration(seconds: 4),
        end: const Duration(seconds: 5),
        moveStart: true,
        delta: const Duration(seconds: 10),
      );
      expect(clampHigh.start, const Duration(seconds: 5) - min);
    });

    test('B không nhỏ hơn A + tối thiểu và không vượt duration bài', () {
      final clampDur = LrcAbSuggestions.nudgeLoop(
        start: const Duration(seconds: 55),
        end: const Duration(seconds: 58),
        moveStart: false,
        delta: const Duration(seconds: 10),
        trackDuration: const Duration(seconds: 60),
      );
      expect(clampDur.end, const Duration(seconds: 60));

      final clampShort = LrcAbSuggestions.nudgeLoop(
        start: const Duration(seconds: 58),
        end: const Duration(seconds: 59),
        moveStart: false,
        delta: const Duration(seconds: -10),
        trackDuration: const Duration(seconds: 60),
      );
      expect(
        clampShort.end - clampShort.start,
        LrcAbSuggestions.minSegmentLength,
      );
    });
  });
}
