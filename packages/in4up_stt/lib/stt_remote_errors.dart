// packages/in4up_stt/lib/stt_remote_errors.dart
//
// Mã lỗi cấu trúc cho STT qua API (Groq/Speaches...) — WP2 (API-003).
// UI/facade phân nhánh theo mã, KHÔNG match chuỗi (cùng khuôn mẫu
// HyMtErrorCode / AiApiErrorCode).

/// Mã lỗi remote STT — mọi nhánh lỗi của [SttEngineRemote] đều dùng mã này
/// (kể cả lỗi mạng/HTTP đã được map lại từ `AiApiException` của in4up_ai)
/// để facade/UI xử lý thống nhất mà không cần biết chi tiết tầng HTTP.
enum SttRemoteErrorCode {
  /// Request khác vẫn đang chạy (hết hạn chờ slot single-flight).
  busy,

  /// Chưa cấu hình provider STT API (Groq/Speaches...) cho AiRouteCapability.sttFile.
  notConfigured,

  /// Routing đang đặt offlineOnly cho năng lực sttFile.
  offlineOnly,

  /// Mất kết nối mạng giữa chừng (hoặc không có mạng khi bắt đầu).
  networkLost,

  /// Request/response vượt timeout.
  timeout,

  /// Server trả lỗi HTTP (401/403/429/5xx...).
  httpError,

  /// Response không đúng định dạng JSON mong đợi.
  invalidResponse,

  /// Người dùng hủy giữa chừng (giữa các chunk).
  cancelled,

  /// Không cắt/convert được audio thành chunk để gửi API.
  chunkingFailed,
}

/// Lỗi runtime của STT qua API — cấu trúc, không phải chuỗi tự do.
class SttRemoteFailure implements Exception {
  const SttRemoteFailure(this.code, this.message);

  final SttRemoteErrorCode code;
  final String message;

  @override
  String toString() => 'SttRemoteFailure(${code.name}): $message';
}
