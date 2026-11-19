// lib/features/vad/pipeline/vad_failure_reason.dart
//
// PSRC-205 (audit 1.28.0) — "tạo lời cho file dài báo lỗi KHÔNG XÁC ĐỊNH".
//
// GỐC: `VadPipelineIntegration.transcribeWithVad` trả
//   `SttTranscribeOutput(result: …, success: segments.isNotEmpty)` — KHÔNG có
//   `errorMessage`. Khi VAD tìm được đoạn nói nhưng mọi đoạn đều bị bỏ (cắt
//   chunk hỏng / nhận diện lỗi), job kết thúc "completed" với 0 dòng ⇒
//   `success == false`, `errorMessage == null` ⇒ UI hiện đúng câu mặc định
//   'Lỗi không xác định' và người dùng không có cách nào đoán được nguyên
//   nhân. Nay mọi nhánh thất bại đều có câu nêu ĐÚNG khâu hỏng + số liệu.
//
// Hàm THUẦN (không I/O) để CI khoá lại được trên host VM.

/// Câu báo lỗi khi job VAD + Whisper không ra được dòng lời nào.
///
/// [totalSegments] số đoạn VAD đề xuất · [cutFailures] số đoạn không cắt được
/// chunk (FFmpeg) · [transcribeFailures] số đoạn cắt được nhưng nhận diện lỗi.
String vadNothingTranscribedMessage({
  required int totalSegments,
  required int cutFailures,
  required int transcribeFailures,
}) {
  final parts = <String>[];
  if (totalSegments <= 0) {
    return 'Không tìm thấy đoạn nói nào trong tệp này. Hãy thử tắt "bỏ khoảng '
        'lặng" hoặc chọn model nhận diện khác.';
  }
  if (cutFailures > 0) {
    parts.add('không cắt được $cutFailures/$totalSegments đoạn (FFmpeg)');
  }
  if (transcribeFailures > 0) {
    parts.add('nhận diện lỗi ở $transcribeFailures/$totalSegments đoạn');
  }
  final detail = parts.isEmpty ? '' : ' — ${parts.join(', ')}';
  return 'Không tạo được lời cho tệp này$detail. Hãy kiểm tra FFmpeg/model '
      'nhận diện rồi thử lại.';
}
