import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_repeat.dart';

void main() {
  group('RecitationRepeat', () {
    test('item 0 means infinite and keeps looping', () {
      expect(RecitationRepeat.clampItem(0), 0);
      expect(RecitationRepeat.anotherItemPass(1, 0), isTrue);
      expect(RecitationRepeat.anotherItemPass(99, 0), isTrue);
    });

    test('finite item repeats stop after N passes', () {
      expect(RecitationRepeat.anotherItemPass(1, 1), isFalse);
      expect(RecitationRepeat.anotherItemPass(1, 3), isTrue);
      expect(RecitationRepeat.anotherItemPass(3, 3), isFalse);
    });

    test('line repeats stay in 1…999 and honor per-line overrides', () {
      expect(RecitationRepeat.clampLine(0), 1);
      expect(RecitationRepeat.clampLine(12), 12);
      expect(
        RecitationRepeat.forLine(
          3,
          defaultCount: 2,
          overrides: const {3: 5, 4: 1},
        ),
        5,
      );
      expect(
        RecitationRepeat.forLine(1, defaultCount: 2, overrides: const {}),
        2,
      );
    });

    test('labels match the Word List style', () {
      expect(RecitationRepeat.itemLabel(1), '1×');
      expect(RecitationRepeat.itemLabel(0), '∞');
      expect(RecitationRepeat.itemLabel(3, current: 2), '2/3×');
      expect(RecitationRepeat.itemLabel(0, current: 4), '4/∞');
      expect(RecitationRepeat.lineLabel(3), '3×');
      expect(RecitationRepeat.lineLabel(3, current: 1), '1/3');
    });
  });
}
