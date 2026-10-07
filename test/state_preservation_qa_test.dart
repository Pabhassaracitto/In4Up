import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/qa/state_preservation_qa.dart';

void main() {
  test('C-31 — cả 6 vùng bảo toàn trạng thái đều giữ', () async {
    final report = await const I4uStatePreservationQa().run();
    expect(
      report.failures
          .map((failure) =>
              '${failure.scenario.id} (${failure.scenario.area.slug}): ${failure.detail}')
          .toList(),
      isEmpty,
      reason: report.toSummary(),
    );
    expect(report.isComplete, isTrue, reason: report.toSummary());
  });

  test('C-31 — bộ kịch bản phủ đủ 6 vùng và nối được vào quality run', () async {
    final report = await const I4uStatePreservationQa().run();
    expect(
      report.results.map((result) => result.scenario.area).toSet(),
      I4uPreservationArea.values.toSet(),
    );
    expect(report.toQualityRun().isReadyForFreeze, isTrue, reason: report.toSummary());
    expect(report.toQualityRun().hasBlocker, isFalse);
  });

  test('C-31 — thiếu vùng thì KHÔNG freeze-ready (không pass rỗng)', () {
    final report = I4uPreservationReport(
      results: <I4uPreservationCheckResult>[
        I4uPreservationCheckResult(
          scenario: I4uPreservationScenario(
            id: 'C31-FAKE-OK',
            area: I4uPreservationArea.draft,
            requirement: 'kịch bản giả định đạt',
            body: () {},
          ),
          passed: true,
        ),
      ],
    );

    expect(report.allHold, isTrue);
    expect(report.uncoveredAreas.length, I4uPreservationArea.values.length - 1);
    expect(report.isComplete, isFalse);
    expect(report.toQualityRun().hasBlocker, isTrue);
  });

  test('C-31 — kịch bản fail được ghi chi tiết, không nuốt lỗi', () async {
    final report = await I4uStatePreservationQa(
      scenarios: <I4uPreservationScenario>[
        I4uPreservationScenario(
          id: 'C31-FAKE-FAIL',
          area: I4uPreservationArea.draft,
          requirement: 'kịch bản giả định hỏng',
          body: () => i4uCheckHolds(false, 'nháp bị xoá khi nguồn đổi'),
        ),
      ],
    ).run();

    expect(report.failures.single.scenario.id, 'C31-FAKE-FAIL');
    expect(report.failures.single.detail, contains('nháp bị xoá khi nguồn đổi'));
    expect(report.toQualityRun().hasBlocker, isTrue);
  });

  test('C-31 — summary nêu rõ vùng thiếu máy bắt và việc QA tay', () async {
    final report =
        await I4uStatePreservationQa(scenarios: <I4uPreservationScenario>[]).run();

    expect(report.isComplete, isFalse);
    expect(report.uncoveredAreas.length, I4uPreservationArea.values.length);

    final summary = report.toSummary();
    expect(summary, contains('THIẾU MÁY BẮT'));
    expect(summary, contains('QA TAY'));
  });
}
