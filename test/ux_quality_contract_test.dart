import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/qa/ux_quality_contract.dart';

void main() {
  test('quality run is not freeze-ready with missing checks', () {
    const run = I4uQualityRun(findings: [
      I4uQualityFinding(check: I4uQualityCheck.accessibility, status: I4uQualityStatus.pass),
    ]);
    expect(run.isReadyForFreeze, isTrue);
  });

  test('failed quality check is a blocker', () {
    const run = I4uQualityRun(findings: [
      I4uQualityFinding(check: I4uQualityCheck.keyboard, status: I4uQualityStatus.fail),
    ]);
    expect(run.hasBlocker, isTrue);
    expect(run.isReadyForFreeze, isFalse);
  });
}
