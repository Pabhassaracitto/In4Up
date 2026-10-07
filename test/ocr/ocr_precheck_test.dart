// OCR-SCAN-CRASH-001 — "máy thiếu Google Play services ⇒ KHÔNG mở máy quét".
//
// Đây là phần QUYẾT ĐỊNH của lớp an toàn mới (lib/features/ocr/ocr_precheck.dart):
// thuần Dart nên chạy được trên host VM, không cần thiết bị/ML Kit. Máy thật
// (logcat) là QA tay — xem KANBAN OCR-SCAN-CRASH-001.
//
// Vì sao phải có test này: ở bản 0.10.3, máy thiếu/tắt Play services mở máy quét
// ⇒ lỗi ném ở luồng native ⇒ app tắt ngay, không toast/dialog. Điều kiện tiên
// quyết để không tái diễn là quyết định "có mở được không" phải SAI theo hướng
// an toàn: thiếu thông tin (RAM null) thì cho thử, thiếu Play services thì chặn.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_precheck.dart';

void main() {
  group('OcrPrecheck.decide — máy Android đủ điều kiện', () {
    const ok = OcrDeviceCapabilities(
      platformSupported: true,
      documentScannerSupported: true,
      playServicesInstalled: true,
      playServicesEnabled: true,
      playServicesVersionCode: 240000000,
      androidSdkInt: 34,
      totalRamBytes: 4000000000,
    );

    test('đủ GMS + RAM → ready, được mở máy quét', () {
      final decision = OcrPrecheck.decide(ok);
      expect(decision.status, OcrPrecheckStatus.ready);
      expect(decision.canOpenScanner, isTrue);
      expect(decision.suggestPlayServices, isFalse);
    });

    test('RAM không đo được (null) → vẫn ready, KHÔNG chặn oan', () {
      const caps = OcrDeviceCapabilities(
        platformSupported: true,
        documentScannerSupported: true,
        playServicesInstalled: true,
        playServicesEnabled: true,
        totalRamBytes: null,
      );
      expect(OcrPrecheck.decide(caps).canOpenScanner, isTrue);
    });
  });

  group('OcrPrecheck.decide — các nhánh phải CHẶN (trước đây là crash native)',
      () {
    test('chưa cài Google Play services → missingPlayServices + gợi ý mở GMS',
        () {
      const caps = OcrDeviceCapabilities(
        platformSupported: true,
        documentScannerSupported: true,
        playServicesInstalled: false,
        playServicesEnabled: false,
      );
      final decision = OcrPrecheck.decide(caps);
      expect(decision.status, OcrPrecheckStatus.missingPlayServices);
      expect(decision.canOpenScanner, isFalse);
      expect(decision.suggestPlayServices, isTrue);
      expect(decision.message, isNotEmpty);
    });

    test('Play services bị người dùng TẮT → cũng chặn (không chỉ "chưa cài")',
        () {
      const caps = OcrDeviceCapabilities(
        platformSupported: true,
        documentScannerSupported: true,
        playServicesInstalled: true,
        playServicesEnabled: false,
      );
      final decision = OcrPrecheck.decide(caps);
      expect(decision.status, OcrPrecheckStatus.missingPlayServices);
      expect(decision.canOpenScanner, isFalse);
    });

    test('RAM dưới 1,7 GB → lowRam (Google trả MlKitException UNSUPPORTED)', () {
      const caps = OcrDeviceCapabilities(
        platformSupported: true,
        documentScannerSupported: true,
        playServicesInstalled: true,
        playServicesEnabled: true,
        totalRamBytes: 1500000000,
      );
      final decision = OcrPrecheck.decide(caps);
      expect(decision.status, OcrPrecheckStatus.lowRam);
      expect(decision.canOpenScanner, isFalse);
      // Không phải lỗi GMS ⇒ không mời mở Play services.
      expect(decision.suggestPlayServices, isFalse);
    });

    test('đúng sát ngưỡng 1,7 GB → cho qua (biên trên)', () {
      const caps = OcrDeviceCapabilities(
        platformSupported: true,
        documentScannerSupported: true,
        playServicesInstalled: true,
        playServicesEnabled: true,
        totalRamBytes: OcrPrecheck.minTotalRamBytes,
      );
      expect(OcrPrecheck.decide(caps).canOpenScanner, isTrue);
    });

    test('desktop/web → unsupportedPlatform', () {
      const caps = OcrDeviceCapabilities(
        platformSupported: false,
        documentScannerSupported: false,
      );
      final decision = OcrPrecheck.decide(caps);
      expect(decision.status, OcrPrecheckStatus.unsupportedPlatform);
      expect(decision.canOpenScanner, isFalse);
    });

    test('iOS (có ML Kit nhưng không có scanner) → scannerUnsupported', () {
      const caps = OcrDeviceCapabilities(
        platformSupported: true,
        documentScannerSupported: false,
      );
      final decision = OcrPrecheck.decide(caps);
      expect(decision.status, OcrPrecheckStatus.scannerUnsupported);
      expect(decision.canOpenScanner, isFalse);
    });
  });

  group('OcrDeviceCapabilities.fromNativeMap — đọc map thô của kênh in4up/ocr',
      () {
    test('map đầy đủ → parse đúng từng trường', () {
      final caps = OcrDeviceCapabilities.fromNativeMap(
        const <Object?, Object?>{
          'gmsInstalled': true,
          'gmsEnabled': true,
          'gmsVersionCode': 240000000,
          'sdkInt': 33,
          'totalRamBytes': 4000000000,
        },
        platformSupported: true,
        documentScannerSupported: true,
      );
      expect(caps.playServicesInstalled, isTrue);
      expect(caps.playServicesEnabled, isTrue);
      expect(caps.playServicesVersionCode, 240000000);
      expect(caps.androidSdkInt, 33);
      expect(caps.totalRamBytes, 4000000000);
      expect(OcrPrecheck.decide(caps).canOpenScanner, isTrue);
    });

    test('map rỗng/thiếu khoá → coi như KHÔNG có Play services (an toàn)', () {
      final caps = OcrDeviceCapabilities.fromNativeMap(
        const <Object?, Object?>{},
        platformSupported: true,
        documentScannerSupported: true,
      );
      expect(caps.playServicesInstalled, isFalse);
      expect(OcrPrecheck.decide(caps).status, OcrPrecheckStatus.missingPlayServices);
    });

    test('kiểu sai (String thay vì bool/int) → không được hiểu thành "có"', () {
      final caps = OcrDeviceCapabilities.fromNativeMap(
        const <Object?, Object?>{
          'gmsInstalled': 'yes',
          'gmsEnabled': 'true',
          'versionCode': 'abc',
        },
        platformSupported: true,
        documentScannerSupported: true,
      );
      expect(caps.playServicesInstalled, isFalse);
      expect(caps.playServicesVersionCode, isNull);
      expect(caps.androidSdkInt, isNull);
      expect(caps.totalRamBytes, isNull);
    });

    test('num từ native (double/long) vẫn đọc được thành int', () {
      final caps = OcrDeviceCapabilities.fromNativeMap(
        const <Object?, Object?>{
          'gmsInstalled': true,
          'gmsEnabled': true,
          'sdkInt': 34,
          'totalRamBytes': 3000000000,
        },
        platformSupported: true,
        documentScannerSupported: true,
      );
      expect(caps.androidSdkInt, 34);
      expect(caps.totalRamBytes, 3000000000);
    });
  });

  test('minTotalRamBytes đúng 1,7 GB theo tài liệu Google', () {
    expect(OcrPrecheck.minTotalRamBytes, 1825361100);
  });
}
