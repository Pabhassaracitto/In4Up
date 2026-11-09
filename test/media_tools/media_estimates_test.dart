// test/media_tools/media_estimates_test.dart
//
// AVTOOL-002 (PLAN-047 P1) — máy bắt cho ước lượng dung lượng + tiến trình.
//
// Nguyên tắc test: KHÔNG đòi con số đẹp, chỉ đòi (a) không bịa khi thiếu dữ
// kiện, (b) chặn đúng khi thiếu chỗ, (c) tiến trình không vượt 0..1.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/models/media_export_models.dart';
import 'package:in4up/features/media_tools/services/media_estimates.dart';

void main() {
  group('estimateBytes', () {
    test('MP3 192 kbps × 60 giây ≈ 1.4 MB (có hệ số an toàn)', () {
      final bytes = MediaEstimates.estimateBytes(
        preset: MediaExportPreset.mp3Standard,
        duration: const Duration(minutes: 1),
      );
      expect(bytes, isNotNull);
      // 192 kbps × 60 s = 1440 kB ≈ 1_474_560 B; ×1.15 ≈ 1.7 MB
      expect(bytes!, greaterThan(1400000));
      expect(bytes, lessThan(1800000));
    });

    test('unknown duration ⇒ null (không bịa số)', () {
      expect(
        MediaEstimates.estimateBytes(
          preset: MediaExportPreset.mp3Standard,
          duration: null,
        ),
        isNull,
      );
    });

    test('preset copy dùng bitrate nguồn', () {
      final bytes = MediaEstimates.estimateBytes(
        preset: MediaExportPreset.m4aCopy,
        duration: const Duration(seconds: 10),
        sourceBitrateKbps: 128,
      );
      expect(bytes, isNotNull);
      expect(bytes, greaterThan(150000));
    });

    test('preset copy mà không biết bitrate nguồn ⇒ null', () {
      expect(
        MediaEstimates.estimateBytes(
          preset: MediaExportPreset.m4aCopy,
          duration: const Duration(seconds: 10),
        ),
        isNull,
      );
    });
  });

  group('formatBytes', () {
    test('đơn vị hiển thị hợp lý', () {
      expect(MediaEstimates.formatBytes(512), '512 B');
      expect(MediaEstimates.formatBytes(2048), '2 KB');
      expect(MediaEstimates.formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(MediaEstimates.formatBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
    });

    test('byte âm không làm hiện số vô nghĩa', () {
      expect(MediaEstimates.formatBytes(-5), '0 B');
    });
  });

  group('checkSpace', () {
    test('đủ chỗ ⇒ allowed', () {
      final verdict = MediaEstimates.checkSpace(
        estimateBytes: 10 * 1024 * 1024,
        freeSpaceMb: 100,
      );
      expect(verdict.allowed, isTrue);
      expect(verdict.kind, SpaceVerdictKind.ok);
    });

    test('thiếu chỗ ⇒ chặn', () {
      final verdict = MediaEstimates.checkSpace(
        estimateBytes: 200 * 1024 * 1024,
        freeSpaceMb: 50,
      );
      expect(verdict.allowed, isFalse);
      expect(verdict.kind, SpaceVerdictKind.notEnough);
    });

    test('không đo được dung lượng trống ⇒ KHÔNG chặn', () {
      final verdict = MediaEstimates.checkSpace(
        estimateBytes: 10 * 1024 * 1024,
        freeSpaceMb: null,
      );
      expect(verdict.allowed, isTrue);
      expect(verdict.kind, SpaceVerdictKind.unknownFreeSpace);
    });

    test('không ước lượng được ⇒ không chặn', () {
      final verdict = MediaEstimates.checkSpace(
        estimateBytes: null,
        freeSpaceMb: 1,
      );
      expect(verdict.allowed, isTrue);
      expect(verdict.kind, SpaceVerdictKind.unknownEstimate);
    });
  });

  group('progressFraction', () {
    test('tính theo chặng hiện tại', () {
      expect(
        MediaEstimates.progressFraction(elapsedMs: 500, totalMs: 1000),
        closeTo(0.5, 0.001),
      );
    });

    test('chặng 2/4 bắt đầu từ 25%', () {
      expect(
        MediaEstimates.progressFraction(
          elapsedMs: 0,
          totalMs: 1000,
          sliceStartFraction: 0.25,
          sliceSpanFraction: 0.25,
        ),
        closeTo(0.25, 0.001),
      );
    });

    test('không bao giờ vượt 1 hay xuống dưới 0', () {
      expect(
        MediaEstimates.progressFraction(elapsedMs: 9999, totalMs: 1000),
        1.0,
      );
      expect(
        MediaEstimates.progressFraction(elapsedMs: -50, totalMs: 1000),
        0.0,
      );
      expect(MediaEstimates.progressFraction(elapsedMs: 5, totalMs: 0), 0);
    });
  });
}
