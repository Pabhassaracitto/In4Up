// packages/in4up_stt/lib/stt_remote_error_mapper.dart
//
// Map lỗi tầng HTTP OpenAI-compatible (`AiApiException` — in4up_ai, dùng
// chung cho chat/STT/TTS qua API) → mã lỗi cấu trúc riêng của STT remote
// (`SttRemoteFailure`) — WP2 (API-003).
//
// Pure (không network) — test bằng `flutter test` không cần server thật.

import 'package:in4up_ai/in4up_ai.dart' show AiApiException, AiApiErrorCode;

import 'stt_remote_errors.dart';

class SttRemoteErrorMapper {
  SttRemoteErrorMapper._();

  static SttRemoteFailure fromApiException(AiApiException e) {
    switch (e.code) {
      case AiApiErrorCode.noNetwork:
        return SttRemoteFailure(SttRemoteErrorCode.networkLost, e.message);
      case AiApiErrorCode.timeout:
        return SttRemoteFailure(SttRemoteErrorCode.timeout, e.message);
      case AiApiErrorCode.unauthorized:
      case AiApiErrorCode.rateLimited:
      case AiApiErrorCode.httpError:
      case AiApiErrorCode.cleartextBlocked:
      case AiApiErrorCode.invalidBaseUrl:
        return SttRemoteFailure(SttRemoteErrorCode.httpError, e.message);
      case AiApiErrorCode.invalidResponse:
        return SttRemoteFailure(SttRemoteErrorCode.invalidResponse, e.message);
    }
  }
}
