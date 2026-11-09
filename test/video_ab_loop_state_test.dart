import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/video/models/video_ab_loop_state.dart';

void main() {
  group('VideoAbLoopState', () {
    const duration = Duration(seconds: 30);

    test('mark A clamps to the media duration and resets prior B', () {
      final withB = VideoAbLoopState(
        a: const Duration(seconds: 2),
        b: const Duration(seconds: 4),
        enabled: true,
      );

      final reset = withB.markA(const Duration(seconds: 50), duration);

      expect(reset.a, duration);
      expect(reset.b, isNull);
      expect(reset.isActive, isFalse);
    });

    test('B needs A, positive duration, and minimum interval', () {
      expect(VideoAbLoopState.empty.markB(const Duration(seconds: 2), duration),
          isNull);

      final withA = VideoAbLoopState.empty.markA(
        const Duration(seconds: 2), duration);
      expect(withA.markB(const Duration(milliseconds: 2299), duration), isNull);
      expect(withA.markB(const Duration(milliseconds: 2300), duration)?.isActive,
          isTrue);
      expect(withA.markB(const Duration(seconds: 2), Duration.zero), isNull);
    });

    test('B is clamped to duration and looping wraps at/after B only', () {
      final state = VideoAbLoopState.empty
          .markA(const Duration(seconds: 4), duration)
          .markB(const Duration(seconds: 50), duration)!;

      expect(state.b, duration);
      expect(state.wrapTarget(const Duration(seconds: 29, milliseconds: 999)),
          isNull);
      expect(state.wrapTarget(duration), const Duration(seconds: 4));
      expect(state.wrapTarget(const Duration(seconds: 31)),
          const Duration(seconds: 4));
    });

    test('disabled and cleared intervals never wrap', () {
      const disabled = VideoAbLoopState(
        a: Duration(seconds: 1),
        b: Duration(seconds: 3),
      );
      expect(disabled.wrapTarget(const Duration(seconds: 3)), isNull);
      expect(disabled.clear().isActive, isFalse);
      expect(disabled.clear().a, isNull);
    });

    test('A cannot be negative', () {
      final state = VideoAbLoopState.empty.markA(
        const Duration(milliseconds: -10), duration);
      expect(state.a, Duration.zero);
    });
  });
}
