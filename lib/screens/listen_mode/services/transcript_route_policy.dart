// lib/screens/listen_mode/services/transcript_route_policy.dart
//
// PSRC-205 (audit 1.28.0) — "tạo lời cho file âm thanh dài báo lỗi không xác
// định; một số file .m4a cũng lỗi, nhưng không phải tất cả".
//
// GỐC của phần "không phải tất cả":
//   `PlayerSttMixin.generateLrcForCurrentAudio` chọn đường chạy theo DUNG
//   LƯỢNG FILE (`size > 5 MB ⇒ VAD pipeline`). Dung lượng phụ thuộc bitrate
//   chứ không phụ thuộc độ dài: cùng một bài 6 phút, MP3 128 kbps ≈ 5,6 MB
//   (⇒ VAD) còn M4A/AAC 96 kbps ≈ 4,3 MB (⇒ đường chunk thường). Vì vậy
//   CÙNG một "file dài" lúc lỗi lúc không, và .m4a (bitrate thấp hơn trên
//   cùng thời lượng) là nhóm hay rơi vào nhánh chạy được — đúng như audit
//   ghi "một số file m4a cũng đôi khi gặp lỗi, nhưng không phải tất cả".
//
// Cách sửa: quyết định theo ĐỘ DÀI (probe bằng ffmpeg), chỉ dùng dung lượng
// làm phỏng đoán khi KHÔNG probe được — và ghi rõ lý do để log/commit đọc
// được. Hàm thuần dưới đây để CI khoá lại hành vi (không cần thiết bị).

/// Đường chạy cho một job "tạo lời".
enum TranscriptRoute {
  /// File ngắn: một đường chunk thường (convert → chia chunk), không VAD.
  inlineShort,

  /// File dài: VAD pipeline (bỏ khoảng lặng, cắt theo đoạn nói).
  vadLong,

  /// Người dùng chọn engine offline sherpa — không liên quan VAD/Whisper.
  sherpaOffline,
}

/// Kết quả quyết định + lý do (để log và test đọc được).
class TranscriptRouteDecision {
  const TranscriptRouteDecision({
    required this.route,
    required this.reason,
    this.durationMs,
    this.usedSizeFallback = false,
  });

  final TranscriptRoute route;

  /// Vì sao chọn đường này ('sherpa' · 'duration' · 'unknown-duration').
  final String reason;

  /// Độ dài file nếu probe được.
  final int? durationMs;

  /// `true` = không probe được độ dài nên phải dựa vào dung lượng.
  final bool usedSizeFallback;

  @override
  String toString() =>
      'TranscriptRouteDecision($route, reason=$reason, durationMs=$durationMs, '
      'sizeFallback=$usedSizeFallback)';
}

/// Ngưỡng "file dài" cho VAD: 5 phút.
///
/// Vì sao 5 phút (không phải 60 s): VAD phải nạp model + quét toàn file trước
/// khi nhận diện được câu đầu; với file ngắn thì chi phí đó lớn hơn lợi ích.
/// 5 phút cũng xấp xỉ ngưỡng cũ 5 MB ở 128 kbps (≈ 5,4 phút) nên không đổi
/// hành vi của các file đang chạy tốt.
const int kTranscriptVadThresholdMs = 5 * 60 * 1000;

/// Phỏng đoán dung lượng khi KHÔNG probe được độ dài: ≥ 5 MB ⇒ coi là dài.
///
/// Giữ đúng ngưỡng cũ để nhánh "không probe được" không đổi hành vi, chỉ
/// khác là giờ nó được ghi nhận rõ (`usedSizeFallback = true`).
const int kTranscriptUnknownDurationProxyBytes = 5 * 1024 * 1024;

/// Quyết định đường chạy cho job tạo lời.
///
/// [durationMs] lấy từ `AudioConverter.probeDurationMs` (null = probe hỏng,
/// ví dụ .m4a có `Duration: N/A`).
TranscriptRouteDecision decideTranscriptRoute({
  required int? durationMs,
  required int fileSizeBytes,
  required bool preferSherpa,
  int vadThresholdMs = kTranscriptVadThresholdMs,
  int unknownDurationProxyBytes = kTranscriptUnknownDurationProxyBytes,
}) {
  if (preferSherpa) {
    return const TranscriptRouteDecision(
      route: TranscriptRoute.sherpaOffline,
      reason: 'sherpa',
    );
  }
  if (durationMs != null && durationMs > 0) {
    return TranscriptRouteDecision(
      route: durationMs >= vadThresholdMs
          ? TranscriptRoute.vadLong
          : TranscriptRoute.inlineShort,
      reason: 'duration',
      durationMs: durationMs,
    );
  }
  final assumeLong = fileSizeBytes >= unknownDurationProxyBytes;
  return TranscriptRouteDecision(
    route: assumeLong ? TranscriptRoute.vadLong : TranscriptRoute.inlineShort,
    reason: 'unknown-duration',
    usedSizeFallback: true,
  );
}
