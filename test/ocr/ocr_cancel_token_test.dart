// I4U18-PDF-OCR-TTS-001 (Agent F · F2) — timeout + cancel cho OCR.
//
// Phần native (ML Kit) không test được trên host, nhưng TRỌNG TÀI thì có:
// nó quyết định UI đóng spinner lúc nào. Test ở đây khoá đúng ba lối ra
// (xong / hết giờ / bị hủy) và luật "kẻ về sau không được đổi kết quả".

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_cancel_token.dart';
import 'package:in4up/features/ocr/ocr_service.dart';

void main() {
  group('runOcrGuarded', () {
    test('tác vụ xong trước hạn → completed + giữ nguyên giá trị', () async {
      final run = await runOcrGuarded<String>(
        () async => 'xong',
        timeout: const Duration(seconds: 5),
      );

      expect(run.status, OcrRunStatus.completed);
      expect(run.isCompleted, isTrue);
      expect(run.value, 'xong');
    });

    test('quá hạn → timedOut, KHÔNG chờ tác vụ treo', () async {
      final stopwatch = Stopwatch()..start();
      final run = await runOcrGuarded<String>(
        () => Completer<String>().future, // không bao giờ hoàn tất
        timeout: const Duration(milliseconds: 80),
      );
      stopwatch.stop();

      expect(run.isTimedOut, isTrue);
      expect(run.value, isNull);
      expect(stopwatch.elapsed.inSeconds, lessThan(3));
    });

    test('hủy giữa chừng → cancelled ngay, không đợi hết timeout', () async {
      final token = OcrCancelToken();
      final future = runOcrGuarded<String>(
        () => Completer<String>().future,
        timeout: const Duration(seconds: 30),
        cancelToken: token,
      );
      Timer(const Duration(milliseconds: 20), token.cancel);

      final run = await future;
      expect(run.isCancelled, isTrue);
      expect(token.isCancelled, isTrue);
    });

    test('token đã hủy từ trước → trả cancelled mà không chạy tác vụ', () async {
      final token = OcrCancelToken()..cancel();
      var started = false;

      final run = await runOcrGuarded<String>(
        () async {
          started = true;
          return 'không nên chạy';
        },
        cancelToken: token,
      );

      expect(run.isCancelled, isTrue);
      expect(started, isFalse);
    });

    test('kết quả về SAU khi đã hết giờ không đổi được trạng thái', () async {
      final completer = Completer<String>();
      final run = await runOcrGuarded<String>(
        () => completer.future,
        timeout: const Duration(milliseconds: 40),
      );
      expect(run.isTimedOut, isTrue);

      // Tác vụ trả về muộn — không được ném lỗi / không ai còn nghe.
      completer.complete('muộn');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(run.isTimedOut, isTrue);
    });

    test('lỗi của tác vụ vẫn ném ra cho caller', () async {
      expect(
        runOcrGuarded<String>(
          () async => throw StateError('native fail'),
          timeout: const Duration(seconds: 5),
        ),
        throwsStateError,
      );
    });

    test('cancel() hai lần là vô hại', () {
      final token = OcrCancelToken()
        ..cancel()
        ..cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('OcrResult — error state rõ ràng', () {
    test('hủy không phải lỗi đỏ: isCancelled riêng, isTimeout false', () {
      final result = OcrResult.cancelled(sourceImagePath: '/tmp/a.jpg');
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.isTimeout, isFalse);
      expect(result.failureKind, OcrFailureKind.cancelled);
      expect(result.sourceImagePath, '/tmp/a.jpg');
    });

    test('hết giờ có loại riêng để UI gợi ý ảnh nhỏ/rõ hơn', () {
      final result = OcrResult.timedOut();
      expect(result.isTimeout, isTrue);
      expect(result.isCancelled, isFalse);
      expect(result.failureKind, OcrFailureKind.timeout);
    });

    test('lỗi thường giữ nguyên loại error', () {
      final result = OcrResult.failure(error: 'native fail');
      expect(result.failureKind, OcrFailureKind.error);
      expect(result.isCancelled, isFalse);
      expect(result.isTimeout, isFalse);
    });

    test('thành công: failureKind = none, isSuccess', () {
      const result = OcrResult(text: 'abc');
      expect(result.isSuccess, isTrue);
      expect(result.failureKind, OcrFailureKind.none);
      expect(result.isEmpty, isFalse);
    });
  });
}
