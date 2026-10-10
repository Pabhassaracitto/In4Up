import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/watch/watch_mode_flow.dart';
import 'package:in4up/models/i4u_shell_contracts.dart';
import 'package:in4up/models/watch_mode_state.dart';

void main() {
  test('watch flow preserves timestamp and source for Understand handoff', () {
    final flow = I4uWatchModeFlowController();
    const source = I4uSourceFingerprint(
      sourceType: I4uSourceType.video,
      sourceId: 'video-1',
      returnPath: '/watch/video-1',
    );
    flow.ready(source: source, transcriptAvailable: true);
    flow.setTimestamp(42000);
    final handoff = flow.handoffToUnderstand(selectedSubtitle: 'tri giác');
    expect(handoff?.source.sourceId, 'video-1');
    expect(handoff?.timestampMs, 42000);
    expect(handoff?.selectedSubtitle, 'tri giác');
  });

  test('timestamp is clamped to a safe non-negative range', () {
    final flow = I4uWatchModeFlowController();
    flow.setTimestamp(-20);
    expect(flow.value.currentTimestampMs, 0);
  });
}
