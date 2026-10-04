import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/grammar/grammar.dart';

void main() {
  test('SentenceStructureService phân tích 200 câu trong ngưỡng UI-safe', () {
    final service = SentenceStructureService.instance;
    const samples = [
      ('The old man gave his son a book yesterday.', 'gave'),
      ('They have been waiting since morning.', 'waiting'),
      ('If it rains tomorrow, we will stay at home.', 'stay'),
      ('The report must be submitted by Friday.', 'submitted'),
    ];

    for (final sample in samples) {
      final start = sample.$1.indexOf(sample.$2);
      service.analyzeLine(sample.$1, anchorStart: start, anchorEnd: start + sample.$2.length);
    }

    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      final sample = samples[i % samples.length];
      final start = sample.$1.indexOf(sample.$2);
      service.analyzeLine(
        sample.$1,
        anchorStart: start,
        anchorEnd: start + sample.$2.length,
      );
    }
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(50),
        reason: 'P1 chạy lazy theo cú chạm; 200 câu phải dưới 50 ms trong JIT CI.');
  });
}
