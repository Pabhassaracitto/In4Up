// packages/in4up_ai/lib/src/model/ai_download_preflight.dart
//
// PSRC-253 (bổ sung) — dò kích thước model TRƯỚC khi bấm tải.
//
// Máy chủ (HuggingFace, self-hosted) thường trả `Content-Length` cho yêu cầu
// HEAD. Đây là số do MÁY CHỦ báo, chưa phải file trên máy, nên:
//  * chỉ dùng để CHẶN sớm trường hợp rõ ràng vượt RAM đo được (tiết kiệm
//    băng thông/pin/dung lượng);
//  * KHÔNG thay thế preflight sau khi file có trên máy (khi đó mới đo được
//    kích thước thật bằng `File.lengthSync`);
//  * nếu máy chủ không trả số ⇒ bỏ qua bước này, vẫn tải bình thường rồi
//    kiểm tra sau — không chặn oan vì thiếu header.
//
// File thuần Dart, test được trên host VM.

/// Nguồn của số dung lượng tải.
enum AiDownloadProbeSource {
  /// `Content-Length` từ phản hồi HEAD của máy chủ.
  head,

  /// Máy chủ không trả số đáng tin (HEAD lỗi, chunked, redirect lạ...).
  unavailable,
}

class AiDownloadSizeProbe {
  final int? contentLengthBytes;
  final AiDownloadProbeSource source;

  const AiDownloadSizeProbe({
    this.contentLengthBytes,
    this.source = AiDownloadProbeSource.unavailable,
  });

  const AiDownloadSizeProbe.unavailable()
      : contentLengthBytes = null,
        source = AiDownloadProbeSource.unavailable;

  bool get hasSize =>
      source == AiDownloadProbeSource.head &&
      contentLengthBytes != null &&
      contentLengthBytes! > 0;
}

/// Đọc `Content-Length` dạng thập phân. Trả null cho giá trị rỗng/âm/rác —
/// không đoán kích thước từ tên file hay URL.
int? parseHttpContentLength(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^[0-9]+$').hasMatch(text)) return null;
  final value = int.tryParse(text);
  if (value == null || value <= 0) return null;
  return value;
}

/// Hiển thị gọn dung lượng tải (MB/GB nhị phân), kèm đơn vị rõ ràng.
String formatAiDownloadSize(int bytes) {
  final mib = bytes / (1024 * 1024);
  if (mib >= 1024) return '${(mib / 1024).toStringAsFixed(1)} GB';
  return '${mib.round()} MB';
}
