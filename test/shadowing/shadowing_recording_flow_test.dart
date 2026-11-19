import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recording waits for permission and recorder readiness without a 3-second timer', () {
    final provider = File('lib/features/shadowing/providers/shadowing_provider.dart').readAsStringSync();
    expect(provider, isNot(contains('Timer.periodic(const Duration(seconds: 1)')));
    expect(provider, contains('if (!await _recorder.hasPermission())'));

    final start = provider.indexOf('await _recorder.start(');
    final recordingState = provider.indexOf('_setState(ShadowingState.recording);', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(recordingState, greaterThan(start),
        reason: 'UI must not claim recording until native recorder start completes');
    expect(provider, contains('if (!current()) {\n        await _recorder.stop();'));
    expect(provider, contains('_recordingAttempt++;'));
  });

  test('both user-facing flows render differentiated analysis failures', () {
    final notice = File('lib/features/shadowing/widgets/shadowing_analysis_notice.dart').readAsStringSync();
    final understand = File('lib/screens/understand_mode/understand_mode_screen.dart').readAsStringSync();
    final speak = File('lib/features/shadowing/widgets/shadowing_widget.dart').readAsStringSync();
    for (final code in ['permission_denied', 'no_audio', 'recognition_error']) {
      expect(notice, contains("case '$code':"));
    }
    expect(speak, contains('ShadowingAnalysisNotice(code: shadowing.analysisError!)'));
    expect(understand, contains('ShadowingAnalysisNotice(code: shadowing.analysisError!)'));
    expect(understand, contains("shadowing.state == ShadowingState.countdown"));
    expect(understand, contains('shadowing.reset();'));
  });
}
