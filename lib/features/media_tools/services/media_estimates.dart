// lib/features/media_tools/services/media_estimates.dart
//
// AVTOOL-002 (PLAN-046 P1) — ƯỚC LƯỢNG DUNG LƯỢNG + KẾT LUẬN TIỀN KIỂM. THUẦN.
//
// Vì sao quan trọng: người dùng bấm "Xuất" trên file pháp thoại 90 phút, máy
// còn 40 MB → FFmpeg ghi được 30% rồi ENOSPC, để lại file dở + điện thoại gần
// đầy (hệ quả thật: Android bắt đầu xoá cache các app khác, app này bị giết).
// Chặn TRƯỚC khi ghi là cách duy nhất tránh; và phải nói cho người dùng biết
// file sẽ nặng bao nhiêu TRƯỚC khi họ bấm.

import '../models/media_export_models.dart';

class MediaEstimates {
  const MediaEstimates._();

  /// Hệ số an toàn: container + header + sai lệch VBR thực tế.
  static const double safetyFactor = 1.15;

  /// Ước lượng dung lượng (byte) của đầu ra.
  ///
  /// Trả `null` khi không biết (preset copy mà không biết bitrate nguồn, hoặc
  /// chưa biết độ dài) — người gọi phải coi `null` là "không biết" và cho phép
  /// tiếp tục, KHÔNG bịa số.
  static int? estimateBytes({
    required MediaExportPreset preset,
    Duration? duration,
    int? sourceBitrateKbps,
  }) {
    final ms = duration?.inMilliseconds;
    if (ms == null || ms <= 0) return null;
    final kbps = preset.estimatedBitrateKbps ?? sourceBitrateKbps;
    if (kbps == null || kbps <= 0) return null;
    final seconds = ms / 1000.0;
    final bytes = seconds * kbps * 1000 / 8;
    return (bytes * safetyFactor).round();
  }

  /// Số byte "hiển thị được" (1 decimal) để UI không phải tự format.
  static String formatBytes(int bytes) {
    if (bytes < 0) return '0 B';
    const kb = 1024.0;
    if (bytes < kb) return '$bytes B';
    if (bytes < kb * kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    if (bytes < kb * kb * kb) return '${(bytes / (kb * kb)).toStringAsFixed(1)} MB';
    return '${(bytes / (kb * kb * kb)).toStringAsFixed(2)} GB';
  }

  /// Ước lượng + so với dung lượng trống.
  ///
  /// [freeSpaceMb] = `probeFreeSpaceMB(dir)` (null = không đo được → KHÔNG chặn).
  static SpaceVerdict checkSpace({
    required int? estimateBytes,
    required int? freeSpaceMb,
  }) {
    if (estimateBytes == null) {
      return const SpaceVerdict(
        kind: SpaceVerdictKind.unknownEstimate,
        allowed: true,
      );
    }
    if (freeSpaceMb == null) {
      return SpaceVerdict(
        kind: SpaceVerdictKind.unknownFreeSpace,
        allowed: true,
        estimateBytes: estimateBytes,
      );
    }
    final freeBytes = freeSpaceMb * 1024 * 1024;
    if (freeBytes >= estimateBytes) {
      return SpaceVerdict(
        kind: SpaceVerdictKind.ok,
        allowed: true,
        estimateBytes: estimateBytes,
        freeBytes: freeBytes,
      );
    }
    return SpaceVerdict(
      kind: SpaceVerdictKind.notEnough,
      allowed: false,
      estimateBytes: estimateBytes,
      freeBytes: freeBytes,
    );
  }

  /// Tỉ lệ tiến trình 0..1 (đã clamp) từ số mili-giây đã xử lý.
  ///
  /// Khi chưa biết tổng thời lượng, trả 0 (UI hiện thanh chạy vô định thay vì
  /// giả vờ 0%).
  static double progressFraction({
    required int elapsedMs,
    required int totalMs,
    double sliceStartFraction = 0,
    double sliceSpanFraction = 1,
  }) {
    if (totalMs <= 0) return 0;
    final local = (elapsedMs / totalMs).clamp(0.0, 1.0);
    final combined = sliceStartFraction + local * sliceSpanFraction;
    if (combined.isNaN) return 0;
    return combined.clamp(0.0, 1.0);
  }
}

enum SpaceVerdictKind { ok, notEnough, unknownEstimate, unknownFreeSpace }

class SpaceVerdict {
  const SpaceVerdict({
    required this.kind,
    required this.allowed,
    this.estimateBytes,
    this.freeBytes,
  });

  final SpaceVerdictKind kind;

  /// Có được phép chạy không.
  final bool allowed;
  final int? estimateBytes;
  final int? freeBytes;

  /// Thông điệp canonical tiếng Anh khi bị chặn (để tầng service không phải
  /// tạo chuỗi i18n — luật #5: chuỗi chrome chỉ ở UI).
  String? get blockedMessage {
    if (allowed) return null;
    final need = estimateBytes == null ? '?' : MediaEstimates.formatBytes(estimateBytes!);
    final have = freeBytes == null ? '?' : MediaEstimates.formatBytes(freeBytes!);
    return 'Not enough free space: needs about $need, only $have available.';
  }
}
