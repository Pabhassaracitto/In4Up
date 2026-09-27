// packages/in4up_stt/test/stt_remote_error_mapper_test.dart
//
// WP2 (API-003) — "mạng rớt giữa chừng → dừng sạch với mã lỗi cấu trúc,
// không treo progress". Kiểm tra ánh xạ đầy đủ AiApiErrorCode (in4up_ai)
// → SttRemoteErrorCode (không match chuỗi thông báo).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up_stt/stt_remote_error_mapper.dart';
import 'package:in4up_stt/stt_remote_errors.dart';

void main() {
  group('SttRemoteErrorMapper.fromApiException', () {
    test('noNetwork → networkLost (mất mạng giữa chừng)', () {
      final f = SttRemoteErrorMapper.fromApiException(
        const AiApiException(AiApiErrorCode.noNetwork, 'no network'),
      );
      expect(f.code, SttRemoteErrorCode.networkLost);
      expect(f.message, 'no network');
    });

    test('timeout → timeout', () {
      final f = SttRemoteErrorMapper.fromApiException(
        const AiApiException(AiApiErrorCode.timeout, 'request timed out'),
      );
      expect(f.code, SttRemoteErrorCode.timeout);
    });

    test('unauthorized/rateLimited/httpError/cleartextBlocked/'
        'invalidBaseUrl → httpError (gộp mọi lỗi tầng HTTP/cấu hình URL)',
        () {
      for (final code in [
        AiApiErrorCode.unauthorized,
        AiApiErrorCode.rateLimited,
        AiApiErrorCode.httpError,
        AiApiErrorCode.cleartextBlocked,
        AiApiErrorCode.invalidBaseUrl,
      ]) {
        final f = SttRemoteErrorMapper.fromApiException(
          AiApiException(code, 'msg-${code.name}'),
        );
        expect(f.code, SttRemoteErrorCode.httpError,
            reason: '$code phải map thành httpError');
        expect(f.message, 'msg-${code.name}');
      }
    });

    test('invalidResponse → invalidResponse', () {
      final f = SttRemoteErrorMapper.fromApiException(
        const AiApiException(
            AiApiErrorCode.invalidResponse, 'bad json shape'),
      );
      expect(f.code, SttRemoteErrorCode.invalidResponse);
    });

    test('mọi AiApiErrorCode đều có nhánh xử lý (switch không rơi mặc '
        'định/throw bất ngờ)', () {
      for (final code in AiApiErrorCode.values) {
        expect(
          () => SttRemoteErrorMapper.fromApiException(
            AiApiException(code, 'x'),
          ),
          returnsNormally,
          reason: '$code chưa được map trong SttRemoteErrorMapper',
        );
      }
    });

    test('statusCode của AiApiException không làm mất message gốc', () {
      final f = SttRemoteErrorMapper.fromApiException(
        const AiApiException(AiApiErrorCode.httpError, 'server 503',
            statusCode: 503),
      );
      expect(f.message, 'server 503');
      expect(f.code, SttRemoteErrorCode.httpError);
    });
  });

  group('SttRemoteFailure', () {
    test('toString() chứa mã lỗi và message (debug log dễ đọc)', () {
      const f = SttRemoteFailure(SttRemoteErrorCode.busy, 'job đang chạy');
      expect(f.toString(), contains('busy'));
      expect(f.toString(), contains('job đang chạy'));
    });
  });
}
