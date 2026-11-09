// OCR-SCAN-CRASH-001 — trọng tài cho phiên quét tài liệu + ánh xạ lỗi native.
//
// Ba thứ được khoá ở đây (thuần Dart, chạy trên host VM — không cần thiết bị):
//   1. `watchOcrScan` (ocr_scan_guard.dart): máy quét trả kết quả TRƯỚC thì
//      thắng; native báo "phiên bị cắt ngang" hoặc "crash" thì ngừng chờ ngay,
//      KHÔNG treo im lặng như trước (giả thuyết 2 — mất activity result).
//   2. `classifyOcrScannerError`: lỗi thô của plugin 0.5.0 ("Operation
//      cancelled" ≠ "Failed to start document scanner") phải ra hai câu khác
//      nhau — trước đây cả hai thành một snackbar đỏ "Lỗi: …".
//   3. `OcrNativeBridge`: map tín hiệu của kênh `in4up/ocr` (seam `invoke`).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_native_bridge.dart';
import 'package:in4up/features/ocr/ocr_scan_guard.dart';
import 'package:in4up/features/ocr/ocr_service.dart';

void main() {
  group('watchOcrScan — ai về trước quyết định', () {
    test('máy quét trả kết quả trước hạn → completed + giữ giá trị', () async {
      final watch = await watchOcrScan<List<String>>(
        scan: () async => <String>['/a.jpg', '/b.jpg'],
        poll: () async => OcrScanSnapshot.idle,
        interval: const Duration(milliseconds: 10),
      );

      expect(watch.isCompleted, isTrue);
      expect(watch.isAborted, isFalse);
      expect(watch.value, <String>['/a.jpg', '/b.jpg']);
      expect(watch.crashTrace, isNull);
    });

    test('native báo phiên bị cắt ngang → aborted(interrupted), ngừng chờ',
        () async {
      var polls = 0;
      final watch = await watchOcrScan<List<String>>(
        // Máy quét không bao giờ trả lời — đúng cảnh activity bị huỷ giữa
        // chừng: plugin 0.5.0 mất `pendingResult` nên không có kết quả nào.
        scan: () => Completer<List<String>>().future,
        poll: () async {
          polls++;
          return polls >= 2
              ? const OcrScanSnapshot(OcrScanSignal.interrupted)
              : OcrScanSnapshot.idle;
        },
        interval: const Duration(milliseconds: 5),
      );

      expect(watch.isInterrupted, isTrue);
      expect(watch.isAborted, isTrue);
      expect(watch.value, isNull);
    });

    test('native bắt được crash → aborted(nativeCrash) + giữ vết lỗi', () async {
      const trace = 'FATAL EXCEPTION: main\n'
          'java.lang.RuntimeException: Google Play Services not available\n'
          '\tat com.google.mlkit.vision.documentscanner.zzd.zza(SourceFile:1)';

      final watch = await watchOcrScan<List<String>>(
        scan: () => Completer<List<String>>().future,
        poll: () async => const OcrScanSnapshot(
          OcrScanSignal.nativeCrash,
          crashTrace: trace,
        ),
        interval: const Duration(milliseconds: 5),
      );

      expect(watch.isNativeCrash, isTrue);
      expect(watch.isAborted, isTrue);
      expect(watch.crashTrace, contains('documentscanner'));
    });

    test('máy quét ném lỗi → ném tiếp cho caller (không nuốt)', () async {
      await expectLater(
        watchOcrScan<int>(
          scan: () async => throw PlatformException(
            code: 'DocumentScanner',
            message: 'Failed to start document scanner',
          ),
          poll: () async => OcrScanSnapshot.idle,
          interval: const Duration(milliseconds: 10),
        ),
        throwsA(isA<PlatformException>()),
      );
    });

    test('lỗi đến SAU khi đã bỏ cuộc → bị nuốt (không unhandled error)',
        () async {
      final scanCompleter = Completer<int>();
      final watch = await watchOcrScan<int>(
        scan: () => scanCompleter.future,
        poll: () async => const OcrScanSnapshot(OcrScanSignal.interrupted),
        interval: const Duration(milliseconds: 5),
      );
      expect(watch.isInterrupted, isTrue);

      scanCompleter.completeError(StateError('kết quả về muộn'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Tới được đây nghĩa là không có unhandled async error nào.
      expect(watch.isAborted, isTrue);
    });

    test('poll hỏng (kênh chết đúng lúc tiến trình bị huỷ) → không làm chết phiên',
        () async {
      var polls = 0;
      final watch = await watchOcrScan<String>(
        // Quét chậm hơn một nhịp hỏi để nhịp hỏng thật sự được gọi.
        scan: () => Future<String>.delayed(
          const Duration(milliseconds: 40),
          () => 'xong',
        ),
        poll: () async {
          polls++;
          throw PlatformException(code: 'channel-error');
        },
        interval: const Duration(milliseconds: 5),
      );

      expect(watch.isCompleted, isTrue);
      expect(watch.value, 'xong');
      expect(polls, greaterThan(0));
    });
  });

  group('classifyOcrScannerError — ba chuyện khác nhau phải nói khác nhau', () {
    test('"Operation cancelled" (user bấm Back) → KHÔNG phải lỗi', () {
      final info = classifyOcrScannerError(
        PlatformException(
          code: 'DocumentScanner',
          message: 'Operation cancelled',
        ),
      );
      expect(info.isCancellation, isTrue);
      expect(info.suggestPlayServices, isFalse);
    });

    test('"Failed to start document scanner" → mời mở Google Play services', () {
      final info = classifyOcrScannerError(
        PlatformException(
          code: 'DocumentScanner',
          message: 'Failed to start document scanner',
        ),
      );
      expect(info.isCancellation, isFalse);
      expect(info.suggestPlayServices, isTrue);
      expect(info.message, isNotEmpty);
    });

    test('"Unknown Error" → lỗi chung nhưng vẫn gợi ý Play services', () {
      final info = classifyOcrScannerError(
        PlatformException(code: 'DocumentScanner', message: 'Unknown Error'),
      );
      expect(info.isCancellation, isFalse);
      expect(info.suggestPlayServices, isTrue);
    });

    test('"Invalid options" → lỗi cấu hình, KHÔNG đổ cho Play services', () {
      final info = classifyOcrScannerError(
        PlatformException(code: 'DocumentScanner', message: 'Invalid options'),
      );
      expect(info.isCancellation, isFalse);
      expect(info.suggestPlayServices, isFalse);
      expect(info.message, isNotEmpty);
    });

    test('MissingPluginException → nói thiếu plugin, không ném', () {
      final info = classifyOcrScannerError(
        MissingPluginException('No implementation found for method scanDocument'),
      );
      expect(info.isCancellation, isFalse);
      expect(info.message, isNotEmpty);
    });

    test('lỗi lạ → câu chung, không ném', () {
      final info = classifyOcrScannerError(StateError('bất ngờ'));
      expect(info.isCancellation, isFalse);
      expect(info.message, isNotEmpty);
    });
  });

  group('OcrScanOutcome — kết cục phiên quét (hợp đồng cho UI)', () {
    test('completed giữ ảnh trang, isSuccess true', () {
      const outcome = OcrScanOutcome.completed(<String>['/p1.jpg']);
      expect(outcome.status, OcrScanStatus.completed);
      expect(outcome.isSuccess, isTrue);
      expect(outcome.pages, <String>['/p1.jpg']);
      expect(outcome.message, isEmpty);
    });

    test('cancelled (user huỷ) — rỗng, KHÔNG có thông báo lỗi', () {
      const outcome = OcrScanOutcome.cancelled();
      expect(outcome.status, OcrScanStatus.cancelled);
      expect(outcome.message, isEmpty);
      expect(outcome.pages, isEmpty);
    });

    test('interrupted — có câu giải thích, không gợi ý Play services', () {
      const outcome = OcrScanOutcome.interrupted();
      expect(outcome.status, OcrScanStatus.interrupted);
      expect(outcome.message, isNotEmpty);
      expect(outcome.suggestPlayServices, isFalse);
    });

    test('nativeCrash — có câu giải thích + giữ vết lỗi để chẩn đoán', () {
      const outcome = OcrScanOutcome.nativeCrash(trace: 'FATAL EXCEPTION');
      expect(outcome.status, OcrScanStatus.nativeCrash);
      expect(outcome.message, isNotEmpty);
      expect(outcome.crashTrace, 'FATAL EXCEPTION');
    });

    test('failed — mang cờ gợi ý mở Play services khi là lỗi GMS', () {
      const outcome = OcrScanOutcome.failed(
        message: 'Không mở được máy quét tài liệu',
        suggestPlayServices: true,
      );
      expect(outcome.status, OcrScanStatus.failed);
      expect(outcome.suggestPlayServices, isTrue);
    });
  });

  group('OcrNativeBridge — ánh xạ tín hiệu kênh in4up/ocr', () {
    late OcrNativeInvoke realInvoke;

    setUpAll(() => realInvoke = OcrNativeBridge.invoke);

    setUp(() {
      OcrNativeBridge.invoke = (method, arguments) async =>
          <Object?, Object?>{'signal': 'none'};
    });

    tearDown(() {
      OcrNativeBridge.invoke = realInvoke;
      OcrNativeBridge.instance.takeCapturedCrash();
    });

    test('signal "none" → idle', () async {
      final snapshot = await OcrNativeBridge.instance.pollScanSignal();
      expect(snapshot.signal, OcrScanSignal.none);
    });

    test('signal "interrupted" → interrupted', () async {
      OcrNativeBridge.invoke = (method, arguments) async =>
          <Object?, Object?>{'signal': 'interrupted'};
      final snapshot = await OcrNativeBridge.instance.pollScanSignal();
      expect(snapshot.signal, OcrScanSignal.interrupted);
    });

    test('signal "nativeCrash" → nativeCrash + mang theo vết lỗi', () async {
      OcrNativeBridge.invoke = (method, arguments) async => <Object?, Object?>{
            'signal': 'nativeCrash',
            'trace': 'FATAL EXCEPTION: main',
          };
      final snapshot = await OcrNativeBridge.instance.pollScanSignal();
      expect(snapshot.signal, OcrScanSignal.nativeCrash);
      expect(snapshot.crashTrace, 'FATAL EXCEPTION: main');
    });

    test('native trả rác (không phải map) → idle, không ném', () async {
      OcrNativeBridge.invoke = (method, arguments) async => 'hỏng';
      final snapshot = await OcrNativeBridge.instance.pollScanSignal();
      expect(snapshot.signal, OcrScanSignal.none);
    });

    test('probeCapabilities: map thô → đọc đúng, gọi đúng method', () async {
      final calls = <String>[];
      OcrNativeBridge.invoke = (method, arguments) async {
        calls.add(method);
        return <Object?, Object?>{
          'gmsInstalled': true,
          'gmsEnabled': true,
          'gmsVersionCode': 240000000,
          'sdkInt': 34,
          'totalRamBytes': 4000000000,
        };
      };

      final raw = await OcrNativeBridge.instance.probeCapabilities();
      expect(calls, <String>['probeCapabilities']);
      expect(raw, isNotNull);
      expect(raw!['gmsInstalled'], isTrue);
      expect(raw['totalRamBytes'], 4000000000);
    });

    test('probeCapabilities: kênh lỗi → ném để service tự xử (không nuốt ở đây)',
        () async {
      OcrNativeBridge.invoke = (method, arguments) async =>
          throw MissingPluginException('chưa có kênh in4up/ocr');
      await expectLater(
        OcrNativeBridge.instance.probeCapabilities(),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('beginScanSession/endScanSession: lỗi kênh KHÔNG làm chết luồng quét',
        () async {
      final calls = <String>[];
      OcrNativeBridge.invoke = (method, arguments) async {
        calls.add(method);
        throw PlatformException(code: 'channel-error');
      };

      await OcrNativeBridge.instance.beginScanSession();
      await OcrNativeBridge.instance.endScanSession();

      expect(calls, <String>['beginScanSession', 'endScanSession']);
    });
  });
}
