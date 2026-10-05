// XLAT-SCR-002 — quy đổi toạ độ + định dạng pixel (thuần Dart).
//
// Hai lỗi "chỉ lộ trên thiết bị" mà test này chặn từ sandbox:
//  1. bbox OCR tính theo ảnh downscale nhưng overlay vẽ theo pixel màn hình
//     ⇒ chữ lệch chỗ (tiêu chí nghiệm thu #2 "không lệch khi xoay ngang").
//  2. ImageReader trả hàng có padding + kênh RGBA, ML Kit đợi BGRA đặc
//     ⇒ OCR ra rác mà không ai biết vì sao.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_block.dart';
import 'package:in4up/features/screen_translate/screen_translate_geometry.dart';

void main() {
  group('mapCaptureRectToOverlay', () {
    test('ảnh đúng cỡ màn hình: giữ nguyên toạ độ', () {
      const geometry = ScreenCaptureGeometry(
        captureWidth: 1080,
        captureHeight: 2400,
        screenWidth: 1080,
        screenHeight: 2400,
        devicePixelRatio: 2.75,
      );
      final rect = mapCaptureRectToOverlay(
        const OcrBlockRect(left: 100, top: 200, right: 400, bottom: 260),
        geometry,
      );
      expect(rect, const OverlayRect(left: 100, top: 200, right: 400, bottom: 260));
    });

    test('ảnh downscale 1/2: toạ độ nhân đôi', () {
      const geometry = ScreenCaptureGeometry(
        captureWidth: 540,
        captureHeight: 1200,
        screenWidth: 1080,
        screenHeight: 2400,
        devicePixelRatio: 2.75,
      );
      final rect = mapCaptureRectToOverlay(
        const OcrBlockRect(left: 50, top: 100, right: 200, bottom: 130),
        geometry,
      );
      expect(rect, const OverlayRect(left: 100, top: 200, right: 400, bottom: 260));
    });

    test('hai mật độ khác nhau cho cùng khung tương đối ⇒ cùng tỉ lệ vị trí',
        () {
      // Máy A: 1080×2400 @2.75 ; Máy B: 1440×3200 @3.5. Khối chữ nằm ở 10%
      // chiều rộng, 25% chiều cao trên CẢ HAI ⇒ overlay phải ra đúng 10%/25%.
      const a = ScreenCaptureGeometry(
        captureWidth: 1080,
        captureHeight: 2400,
        screenWidth: 1080,
        screenHeight: 2400,
        devicePixelRatio: 2.75,
      );
      const b = ScreenCaptureGeometry(
        // 1440×3200 bị cap về cạnh dài 1920 ⇒ ảnh chụp 864×1920.
        captureWidth: 864,
        captureHeight: 1920,
        screenWidth: 1440,
        screenHeight: 3200,
        devicePixelRatio: 3.5,
      );
      final rectA = mapCaptureRectToOverlay(
        const OcrBlockRect(left: 108, top: 600, right: 540, bottom: 660),
        a,
      );
      final rectB = mapCaptureRectToOverlay(
        const OcrBlockRect(left: 86, top: 480, right: 432, bottom: 528),
        b,
      );
      expect(rectA.left / a.screenWidth, closeTo(0.10, 0.01));
      expect(rectB.left / b.screenWidth, closeTo(0.10, 0.01));
      expect(rectA.top / a.screenHeight, closeTo(0.25, 0.01));
      expect(rectB.top / b.screenHeight, closeTo(0.25, 0.01));
    });

    test('khung vượt mép bị clamp và luôn có diện tích ≥ 1px', () {
      const geometry = ScreenCaptureGeometry(
        captureWidth: 100,
        captureHeight: 100,
        screenWidth: 100,
        screenHeight: 100,
      );
      final rect = mapCaptureRectToOverlay(
        const OcrBlockRect(left: 99, top: 99, right: 400, bottom: 400),
        geometry,
      );
      expect(rect.left, 99);
      expect(rect.right, 100);
      expect(rect.width >= 1, isTrue);
      expect(rect.height >= 1, isTrue);
    });

    test('fromMap đọc được payload native và suy screen từ capture khi thiếu',
        () {
      final geometry = ScreenCaptureGeometry.fromMap(<Object?, Object?>{
        'width': 540,
        'height': 1200,
        'devicePixelRatio': 2.0,
      });
      expect(geometry.captureWidth, 540);
      expect(geometry.screenWidth, 540);
      expect(geometry.scaleX, 1.0);
      expect(geometry.isValid, isTrue);
    });
  });

  group('suggestedTextSizeSp', () {
    test('khung cao 60px @2.75 ⇒ khoảng 17sp, nằm trong kẹp [10,28]', () {
      const rect = OverlayRect(left: 0, top: 0, right: 300, bottom: 60);
      final size = suggestedTextSizeSp(rect, 2.75);
      expect(size, closeTo(17.9, 0.5));
    });

    test('khung quá cao vẫn bị kẹp 28sp; quá thấp vẫn ≥ 10sp', () {
      expect(
        suggestedTextSizeSp(
            const OverlayRect(left: 0, top: 0, right: 10, bottom: 800), 2.0),
        28.0,
      );
      expect(
        suggestedTextSizeSp(
            const OverlayRect(left: 0, top: 0, right: 10, bottom: 8), 3.0),
        10.0,
      );
    });
  });

  group('removeRowPadding', () {
    test('không padding ⇒ trả đúng mảng gốc (không copy thừa)', () {
      final src = Uint8List(2 * 2 * 4);
      final out = removeRowPadding(src, width: 2, height: 2, rowStride: 8);
      expect(identical(out, src), isTrue);
    });

    test('có padding ⇒ cắt đúng từng hàng', () {
      // 2×2 px, rowStride 12 (8 byte dữ liệu + 4 byte rác mỗi hàng).
      final src = Uint8List.fromList(<int>[
        1, 2, 3, 4, 5, 6, 7, 8, 99, 99, 99, 99, //
        9, 10, 11, 12, 13, 14, 15, 16, 99, 99, 99, 99,
      ]);
      final out = removeRowPadding(src, width: 2, height: 2, rowStride: 12);
      expect(out, <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
    });

    test('rowStride nhỏ hơn một hàng ⇒ ném ArgumentError (không đọc tràn)', () {
      final src = Uint8List(16);
      expect(
        () => removeRowPadding(src, width: 2, height: 2, rowStride: 4),
        throwsArgumentError,
      );
    });

    test('dữ liệu thiếu byte ⇒ ném ArgumentError', () {
      final src = Uint8List(10);
      expect(
        () => removeRowPadding(src, width: 2, height: 2, rowStride: 8),
        throwsArgumentError,
      );
    });
  });

  group('swapRedBlue', () {
    test('RGBA → BGRA: đổi kênh 0 và 2, giữ G/A', () {
      final src = Uint8List.fromList(<int>[10, 20, 30, 255, 1, 2, 3, 4]);
      final out = swapRedBlue(src);
      expect(out, <int>[30, 20, 10, 255, 3, 2, 1, 4]);
      // Không được sửa mảng gốc (native có thể tái dùng buffer).
      expect(src, <int>[10, 20, 30, 255, 1, 2, 3, 4]);
    });

    test('hoán hai lần = ảnh gốc', () {
      final src = Uint8List.fromList(<int>[7, 8, 9, 10, 11, 12, 13, 14]);
      expect(swapRedBlue(swapRedBlue(src)), src);
    });

    test('độ dài không chia hết cho 4 ⇒ ArgumentError', () {
      expect(() => swapRedBlue(Uint8List(7)), throwsArgumentError);
    });
  });

  group('normalizeCaptureFrame', () {
    test('cắt padding rồi hoán kênh trong một lượt', () {
      final src = Uint8List.fromList(<int>[
        10, 20, 30, 255, 40, 50, 60, 255, 0, 0, 0, 0, //
        70, 80, 90, 255, 100, 110, 120, 255, 0, 0, 0, 0,
      ]);
      final out = normalizeCaptureFrame(
        src,
        width: 2,
        height: 2,
        rowStride: 12,
      );
      expect(out.length, 16);
      expect(out.sublist(0, 4), <int>[30, 20, 10, 255]);
      expect(out.sublist(12, 16), <int>[120, 110, 100, 255]);
    });

    test('alreadyBgra ⇒ không hoán kênh, vẫn trả bản copy', () {
      final src = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      final out = normalizeCaptureFrame(
        src,
        width: 2,
        height: 1,
        rowStride: 8,
        alreadyBgra: true,
      );
      expect(out, src);
      expect(identical(out, src), isFalse);
    });
  });
}
