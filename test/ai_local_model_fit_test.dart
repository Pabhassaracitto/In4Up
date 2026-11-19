import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

const int _mib = 1024 * 1024;

void main() {
  test('phân biệt RAM đo được và dữ liệu thiếu', () {
    final measured = assessAiLocalModelFit(
      modelFileBytes: 1500 * _mib,
      totalRamBytes: 2048 * _mib,
    );
    expect(measured.evidence, AiMemoryEvidence.measuredTotalRam);
    expect(measured.status, AiModelFitStatus.fit);
    expect(measured.guaranteedSafe, isFalse);

    final unknown = assessAiLocalModelFit(
      modelFileBytes: 1500 * _mib,
      totalRamBytes: null,
    );
    expect(unknown.evidence, AiMemoryEvidence.unavailable);
    expect(unknown.reasonCode, 'fit');
    expect(unknown.guaranteedSafe, isFalse);
  });

  test('RAM thấp: chặn model vượt ngưỡng trước khi nạp vào native', () {
    final verdict = assessAiLocalModelFit(
      modelFileBytes: 4096 * _mib,
      totalRamBytes: 2048 * _mib,
    );
    expect(verdict.status, AiModelFitStatus.tooLarge);
    expect(verdict.isBlocked, isTrue);
    expect(verdict.recommendedProfile, AiLocalProfile.lite);
    // Xác nhận của user KHÔNG override số đo thực tế.
    final forced = assessAiLocalModelFit(
      modelFileBytes: 4096 * _mib,
      totalRamBytes: 2048 * _mib,
      userConfirmedRisk: true,
    );
    expect(forced.isBlocked, isTrue);
  });

  test('RAM tầm trung: balanced fit, full bị chặn', () {
    expect(
      assessAiLocalModelFit(
        modelFileBytes: 3000 * _mib,
        totalRamBytes: 3584 * _mib,
      ).status,
      AiModelFitStatus.fit,
    );
    expect(
      assessAiLocalModelFit(
        modelFileBytes: 5000 * _mib,
        totalRamBytes: 3584 * _mib,
      ).status,
      AiModelFitStatus.tooLarge,
    );
  });

  test('RAM lớn hoặc thiếu số liệu: model lớn cần xác nhận, không tự chạy', () {
    final large = 5000 * _mib;
    final measured = assessAiLocalModelFit(
      modelFileBytes: large,
      totalRamBytes: 8192 * _mib,
    );
    expect(measured.status, AiModelFitStatus.needsConfirmation);
    expect(measured.reasonCode, 'large_model');
    expect(
      assessAiLocalModelFit(
        modelFileBytes: large,
        totalRamBytes: 8192 * _mib,
        userConfirmedRisk: true,
      ).status,
      AiModelFitStatus.fit,
    );

    final unknown = assessAiLocalModelFit(
      modelFileBytes: large,
      totalRamBytes: null,
    );
    expect(unknown.status, AiModelFitStatus.needsConfirmation);
    expect(unknown.reasonCode, 'memory_unknown');
    expect(unknown.isBlocked, isFalse,
        reason: 'Không có số liệu ⇒ không tự chặn oan, nhưng cũng không cam kết');
  });

  test('RAM đỉnh là ước tính, không phải số đo', () {
    final verdict = assessAiLocalModelFit(
      modelFileBytes: 2000 * _mib,
      totalRamBytes: 3072 * _mib,
    );
    expect(verdict.estimatedPeakBytes, estimateAiPeakRamBytes(2000 * _mib));
    expect(verdict.estimatedPeakBytes, greaterThan(2000 * _mib));
    expect(profileForFileBytes(2000 * _mib), AiLocalProfile.lite);
    expect(profileForFileBytes(3000 * _mib), AiLocalProfile.balanced);
    expect(profileForFileBytes(6000 * _mib), AiLocalProfile.full);
  });
}
