// packages/in4up_ai/lib/src/model/ai_local_model_fit.dart
//
// PSRC-253 — chọn profile model AI local theo khả năng THẬT của thiết bị.
//
// Nguyên tắc chống "văng app vì tải model quá nặng":
//  * `totalRamBytes` là số ĐO ĐƯỢC từ native (Android ActivityManager qua
//    `OcrService.probeCapabilities`), không phải con số user tự nhập. Đây là
//    TỔNG RAM thiết bị — KHÔNG phải RAM đang trống.
//  * `modelFileBytes` là số đo được từ file .gguf trên máy. Đây là kích
//    thước file, KHÔNG phải RAM khi chạy (llama.cpp còn cần bộ nhớ cho KV
//    cache, runtime và các tiến trình khác).
//  * `estimatedPeakBytes` là ƯỚC TÍNH (file × 1.25 + context overhead) — chỉ
//    để xếp hạng gợi ý, KHÔNG phải cam kết "chạy an toàn". Vì vậy verdict
//    luôn có [guaranteedSafe] = false.
//  * Khi nền tảng không trả được RAM (iOS/desktop/web/kênh cũ) ⇒ evidence =
//    unavailable, KHÔNG đoán RAM. Model lớn chỉ chạy sau xác nhận của user.
//
// File THUẦN Dart — test chạy trên host VM, không cần Flutter/plugin.

import 'dart:math' as math;

/// Nguồn của số liệu RAM.
enum AiMemoryEvidence {
  /// Có số tổng RAM đo được qua native.
  measuredTotalRam,

  /// Không có số liệu đáng tin — chỉ dùng mức conservative.
  unavailable,
}

/// Mức model local phổ thông, theo kích thước file GGUF Q4 thường gặp.
/// Tên model chỉ là ví dụ tham khảo — app KHÔNG tự tải, user tự import file.
enum AiLocalProfile {
  lite('lite', 1536, 2048),
  balanced('balanced', 3584, 4096),
  full('full', 6144, 4096);

  const AiLocalProfile(this.id, this.approxFileMB, this.recommendedContext);

  final String id;

  /// Kích thước file ~MB ở quantization Q4 phổ biến (chỉ để phân loại).
  final int approxFileMB;

  /// `n_ctx` gợi ý; giảm context cũng giảm RAM nóng máy.
  final int recommendedContext;
}

enum AiModelFitStatus {
  /// Phù hợp theo ngưỡng conservative hiện có.
  fit,

  /// Cho phép nhưng phải xác nhận (thiếu số liệu RAM hoặc model lớn).
  needsConfirmation,

  /// Chặn trước khi nạp vào RAM — model vượt ngưỡng đo được.
  tooLarge,
}

/// Kết luận preflight. Không phải bảo chứng chạy được trên mọi thiết bị.
class AiModelFitVerdict {
  final AiModelFitStatus status;
  final AiMemoryEvidence evidence;
  final int? totalRamBytes;

  /// Kích thước FILE đo được (byte), null khi chưa có model.
  final int? modelFileBytes;

  /// RAM đỉnh ƯỚC TÍNH (byte) — không đo thực tế.
  final int? estimatedPeakBytes;

  final AiLocalProfile recommendedProfile;

  const AiModelFitVerdict({
    required this.status,
    required this.evidence,
    this.totalRamBytes,
    this.modelFileBytes,
    this.estimatedPeakBytes,
    required this.recommendedProfile,
  });

  bool get isBlocked => status == AiModelFitStatus.tooLarge;
  bool get needsConfirmation =>
      status == AiModelFitStatus.needsConfirmation;

  /// Luôn false: preflight này chỉ giảm rủi ro, không đảm bảo an toàn.
  bool get guaranteedSafe => false;

  /// Mã ngắn để UI dịch (không nhét chuỗi tiếng Việt vào tầng logic).
  String get reasonCode => switch (status) {
        AiModelFitStatus.fit => 'fit',
        AiModelFitStatus.needsConfirmation =>
          evidence == AiMemoryEvidence.unavailable
              ? 'memory_unknown'
              : 'large_model',
        AiModelFitStatus.tooLarge => 'exceeds_measured_ram',
      };
}

/// Ngưỡng tổng RAM (MiB) và trần FILE model (MiB) — cố ý conservative:
/// để dư chỗ cho hệ điều hành, engine, KV cache và các app khác.
const int kAiLiteMaxFileMiB = 2048;
const int kAiBalancedMaxFileMiB = 3584;
const int kAiFullMaxFileMiB = 7168;

const int kAiLowRamTotalMiB = 2560;
const int kAiMidRamTotalMiB = 4096;

/// Hệ số ƯỚC TÍNH RAM đỉnh so với file model + chi phí cố định cho context.
const double kAiPeakRamFactor = 1.25;
const int kAiContextOverheadBytes = 384 * 1024 * 1024;

/// Ước tính RAM đỉnh (byte) — KHÔNG phải số đo.
int estimateAiPeakRamBytes(int modelFileBytes) =>
    (modelFileBytes * kAiPeakRamFactor).round() + kAiContextOverheadBytes;

AiLocalProfile profileForFileBytes(int fileBytes) {
  final mib = fileBytes / (1024 * 1024);
  if (mib <= kAiLiteMaxFileMiB) return AiLocalProfile.lite;
  if (mib <= kAiBalancedMaxFileMiB) return AiLocalProfile.balanced;
  return AiLocalProfile.full;
}

AiLocalProfile recommendedProfileForRam(int? totalRamBytes) {
  if (totalRamBytes == null || totalRamBytes <= 0) return AiLocalProfile.lite;
  final mib = totalRamBytes / (1024 * 1024);
  if (mib < kAiLowRamTotalMiB) return AiLocalProfile.lite;
  if (mib < kAiMidRamTotalMiB) return AiLocalProfile.balanced;
  return AiLocalProfile.full;
}

/// Đánh giá trước khi nạp model. `userConfirmedRisk` chỉ được phép nới mức
/// `needsConfirmation` — KHÔNG bao giờ override mức `tooLarge` (đã có số đo
/// thực tế cho thấy máy không đủ RAM).
AiModelFitVerdict assessAiLocalModelFit({
  required int modelFileBytes,
  int? totalRamBytes,
  bool userConfirmedRisk = false,

  /// Lựa chọn của người dùng (ưu tiên nhẹ/tốc độ). null = tự theo RAM đo
  /// được. Không bao giờ được nới quá trần RAM ĐO ĐƯỢC của thiết bị.
  AiLocalProfile? requestedProfile,
}) {
  final fileMiB = modelFileBytes / (1024 * 1024);
  final evidence = totalRamBytes != null && totalRamBytes > 0
      ? AiMemoryEvidence.measuredTotalRam
      : AiMemoryEvidence.unavailable;
  final recommended = recommendedProfileForRam(totalRamBytes);
  final peak = estimateAiPeakRamBytes(modelFileBytes);
  AiModelFitVerdict verdict(AiModelFitStatus status) => AiModelFitVerdict(
        status: status,
        evidence: evidence,
        totalRamBytes: totalRamBytes,
        modelFileBytes: modelFileBytes,
        estimatedPeakBytes: peak,
        recommendedProfile: recommended,
      );

  // Trần cứng theo RAM đo được — user chọn profile "đầy đủ" cũng KHÔNG được
  // nới quá trần này (nếu không có số đo thì chỉ cho phép sau xác nhận).
  final int hardCapMiB;
  if (evidence == AiMemoryEvidence.unavailable) {
    hardCapMiB = kAiFullMaxFileMiB;
  } else {
    final totalMiB = totalRamBytes! / (1024 * 1024);
    if (totalMiB < kAiLowRamTotalMiB) {
      hardCapMiB = kAiLiteMaxFileMiB;
    } else if (totalMiB < kAiMidRamTotalMiB) {
      hardCapMiB = kAiBalancedMaxFileMiB;
    } else {
      hardCapMiB = kAiFullMaxFileMiB;
    }
  }
  if (fileMiB > hardCapMiB) return verdict(AiModelFitStatus.tooLarge);

  // Trần mềm theo lựa chọn của user (mặc định = gợi ý theo RAM). Vượt trần
  // mềm ⇒ xác nhận; KHÔNG phải coi là "an toàn" chỉ vì file vừa kích thước.
  final chosen = requestedProfile ?? recommended;
  final softCapMiB = evidence == AiMemoryEvidence.unavailable
      ? kAiLiteMaxFileMiB // không có số đo ⇒ KHÔNG tự nới theo profile đã chọn
      : switch (chosen) {
          AiLocalProfile.lite => kAiLiteMaxFileMiB,
          AiLocalProfile.balanced => kAiBalancedMaxFileMiB,
          // "Đầy đủ" chỉ mở đường cho xác nhận model lớn — vẫn không tự
          // coi file > balanced là an toàn.
          AiLocalProfile.full => kAiBalancedMaxFileMiB,
        };
  if (fileMiB <= softCapMiB) return verdict(AiModelFitStatus.fit);
  return verdict(
    userConfirmedRisk ? AiModelFitStatus.fit : AiModelFitStatus.needsConfirmation,
  );
}

/// KiB → MiB, tiện cho UI hiển thị số đo được mà không tự chia nhầm đơn vị.
String formatAiMemoryMb(int bytes) =>
    '${(bytes / (1024 * 1024)).round()} MB';

/// Làm tròn xuống theo 128 MiB để UI gọn; vẫn là số ĐO ĐƯỢC, không ước tính.
int roundedMeasuredRamBytes(int bytes) =>
    (math.max(0, bytes) ~/ (128 * 1024 * 1024)) * 128 * 1024 * 1024;
