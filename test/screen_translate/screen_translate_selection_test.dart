// XLAT-SCR-005 — kéo chọn vùng + dịch song song (thuần Dart, không thiết bị).
//
// Vì sao có file này: hai thay đổi của đợt 24/10 đều nằm ở "toán" chứ không
// ở UI:
//   1. Vùng người dùng kéo là toạ độ MÀN HÌNH, còn ảnh chụp có thể đã bị
//      downscale và bị CẮT theo vùng. Sai một phép nhân là bản dịch hiện lệch
//      chỗ — lỗi chỉ thấy trên máy thật.
//   2. Trước đây mỗi khối là một request TUẦN TỰ; nay chạy song song có giới
//      hạn + gộp khối trùng. Test khoá cả tốc độ (số request) lẫn giới hạn
//      đồng thời (không đốt rate limit của engine online).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_block.dart';
import 'package:in4up/features/ocr/ocr_service.dart';
import 'package:in4up/features/screen_translate/screen_translate_controller.dart';
import 'package:in4up/features/screen_translate/screen_translate_geometry.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';

Map<Object?, Object?> frame({
  int width = 4,
  int height = 4,
  int screenWidth = 8,
  int screenHeight = 8,
  String target = 'VI',
  String? source,
  ScreenRegion? region,
  Uint8List? pixels,
}) {
  return <Object?, Object?>{
    'pixels': pixels ?? Uint8List(width * height * 4),
    'width': width,
    'height': height,
    'rowStride': width * 4,
    'screenWidth': screenWidth,
    'screenHeight': screenHeight,
    'devicePixelRatio': 2.0,
    'targetLanguage': target,
    'locale': 'en',
    if (source != null) 'sourceLanguage': source,
    if (region != null) ...region.toMap(),
  };
}

OcrBlock block(String text, {int left = 0, int top = 0, int size = 2}) =>
    OcrBlock(
      text: text,
      rect: OcrBlockRect(
        left: left,
        top: top,
        right: left + size,
        bottom: top + size,
      ),
    );

ScreenTranslateController controllerWith(
  List<OcrBlock> blocks, {
  int maxBlocks = kScreenTranslateMaxBlocks,
  int concurrency = kScreenTranslateConcurrency,
  ScreenProgressReporter? onProgress,
  Future<TranslationResult> Function(String text, String target)? translator,
}) {
  return ScreenTranslateController(
    localeCode: 'en',
    maxBlocks: maxBlocks,
    concurrency: concurrency,
    onProgress: onProgress,
    ocrRunner: ({
      required Uint8List pixels,
      required int width,
      required int height,
    }) async =>
        OcrBlocksResult(blocks: blocks),
    translator: translator ??
        (text, target) async => TranslationResult.success(
              original: text,
              translated: '[$target] $text',
              engine: 'fake-engine',
            ),
  );
}

void main() {
  group('ScreenRegion / screenRegionToCapture', () {
    test('đọc vùng từ payload native, thiếu khoá ⇒ null', () {
      final parsed = ScreenRegion.fromMap(<Object?, Object?>{
        'regionLeft': 10,
        'regionTop': 20,
        'regionRight': 110,
        'regionBottom': 220,
      });
      expect(parsed, const ScreenRegion(left: 10, top: 20, right: 110, bottom: 220));
      expect(ScreenRegion.fromMap(const <Object?, Object?>{}), isNull);
    });

    test('toạ độ màn hình → toạ độ ảnh chụp khi ảnh bị downscale', () {
      // Ảnh 540×1200, màn hình 1080×2400 ⇒ ảnh bằng một nửa màn hình.
      const geometry = ScreenCaptureGeometry(
        captureWidth: 540,
        captureHeight: 1200,
        screenWidth: 1080,
        screenHeight: 2400,
        devicePixelRatio: 3,
      );
      final region = screenRegionToCapture(
        const ScreenRegion(left: 100, top: 200, right: 900, bottom: 1000),
        geometry,
      );
      expect(region, isNotNull);
      expect(region!.left, 50);
      expect(region.top, 100);
      expect(region.width, 400);
      expect(region.height, 400);
    });

    test('vùng quá bé / ngoài màn hình ⇒ null (rơi về dịch cả màn hình)', () {
      const geometry = ScreenCaptureGeometry(
        captureWidth: 100,
        captureHeight: 100,
        screenWidth: 100,
        screenHeight: 100,
        devicePixelRatio: 1,
      );
      expect(
        screenRegionToCapture(
          const ScreenRegion(left: 0, top: 0, right: 4, bottom: 4),
          geometry,
        ),
        isNull,
      );
      expect(
        screenRegionToCapture(
          const ScreenRegion(left: 5000, top: 5000, right: 6000, bottom: 6000),
          geometry,
        ),
        isNull,
      );
      expect(screenRegionToCapture(null, geometry), isNull);
    });

    test('vùng kéo vượt mép được kẹp vào màn hình', () {
      const geometry = ScreenCaptureGeometry(
        captureWidth: 100,
        captureHeight: 200,
        screenWidth: 100,
        screenHeight: 200,
        devicePixelRatio: 1,
      );
      final region = screenRegionToCapture(
        const ScreenRegion(left: -50, top: -50, right: 80, bottom: 150),
        geometry,
      );
      expect(region, isNotNull);
      expect(region!.left, 0);
      expect(region.top, 0);
      expect(region.right, 80);
      expect(region.bottom, 150);
    });
  });

  group('cropPackedFrame', () {
    test('cắt đúng pixel của vùng (BGRA, 4 byte/pixel)', () {
      // ảnh 3×2, mỗi pixel 4 byte mang giá trị = chỉ số pixel.
      final src = Uint8List(3 * 2 * 4);
      for (var i = 0; i < 6; i++) {
        src[i * 4] = i;
        src[i * 4 + 1] = i;
        src[i * 4 + 2] = i;
        src[i * 4 + 3] = 255;
      }
      final out = cropPackedFrame(
        src,
        width: 3,
        height: 2,
        region: const CaptureRegion(left: 1, top: 1, width: 2, height: 1),
      );
      expect(out.length, 2 * 4);
      // Pixel (1,1) = index 4, pixel (2,1) = index 5.
      expect(out[0], 4);
      expect(out[4], 5);
    });

    test('vùng nằm ngoài ảnh ⇒ ArgumentError (không đọc tràn)', () {
      expect(
        () => cropPackedFrame(
          Uint8List(4 * 4 * 4),
          width: 4,
          height: 4,
          region: const CaptureRegion(left: 3, top: 3, width: 4, height: 4),
        ),
        throwsArgumentError,
      );
    });

    test('dữ liệu ngắn hơn khai báo ⇒ ArgumentError', () {
      expect(
        () => cropPackedFrame(
          Uint8List(8),
          width: 4,
          height: 4,
          region: const CaptureRegion(left: 0, top: 0, width: 1, height: 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('controller — vùng chọn', () {
    test('khung OCR trong ảnh CẮT được dời về đúng chỗ trên màn hình',
        () async {
      // Ảnh 40×40, màn hình 80×80 (×2). Vùng chọn (20,20)-(60,60) trên màn
      // hình ⇒ ảnh cắt (10,10) 20×20. Khối OCR phủ kín ảnh cắt phải hiện
      // đúng (20,20)-(60,60) trên màn hình — lệch phép cộng offset là bản
      // dịch hiện lệch chỗ.
      final controller = controllerWith(
        <OcrBlock>[block('Hi', left: 0, top: 0, size: 20)],
      );
      final result = await controller.handleFrame(
        frame(
          width: 40,
          height: 40,
          screenWidth: 80,
          screenHeight: 80,
          region: const ScreenRegion(left: 20, top: 20, right: 60, bottom: 60),
        ),
      );
      expect(result.status, ScreenTranslateStatus.ok);
      expect(result.blocks.single.rect.left, 20);
      expect(result.blocks.single.rect.top, 20);
      expect(result.blocks.single.rect.right, 60);
      expect(result.blocks.single.rect.bottom, 60);
    });

    test('vùng quá bé ⇒ vẫn dịch (cả màn hình), không lỗi', () async {
      final controller = controllerWith(
        <OcrBlock>[block('Hello', size: 2)],
      );
      final result = await controller.handleFrame(
        frame(
          width: 4,
          height: 4,
          screenWidth: 4000,
          screenHeight: 4000,
          region: const ScreenRegion(left: 0, top: 0, right: 1, bottom: 1),
        ),
      );
      expect(result.status, ScreenTranslateStatus.ok);
    });
  });

  group('controller — tốc độ + giới hạn song song', () {
    test('khối trùng nội dung chỉ dịch MỘT lần', () async {
      var calls = 0;
      final controller = controllerWith(
        <OcrBlock>[
          block('Settings', top: 0),
          block('Settings', top: 3),
          block('Settings', top: 6),
        ],
        translator: (text, target) async {
          calls++;
          return TranslationResult.success(
            original: text,
            translated: 'Cài đặt',
            engine: 'fake',
          );
        },
      );
      final result = await controller.handleFrame(frame());
      expect(calls, 1);
      expect(result.blocks, hasLength(3));
      expect(result.blocks.every((b) => b.translation == 'Cài đặt'), isTrue);
    });

    test('chạy song song nhưng không vượt quá concurrency', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final blocks = <OcrBlock>[
        for (var i = 0; i < 9; i++) block('text $i', top: i * 2),
      ];
      final controller = controllerWith(
        blocks,
        concurrency: 3,
        translator: (text, target) async {
          inFlight++;
          maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inFlight--;
          return TranslationResult.success(
            original: text,
            translated: 'x',
            engine: 'fake',
          );
        },
      );
      final result = await controller.handleFrame(frame());
      expect(result.blocks, hasLength(9));
      // Giới hạn là bắt buộc: 9 request song song sẽ ăn 429 của engine online.
      expect(maxInFlight, lessThanOrEqualTo(3));
      // Và phải thật sự dùng nhiều hơn 1 luồng, nếu không "nhanh hơn" chỉ là
      // lời hứa.
      expect(maxInFlight, greaterThan(1));
    });

    test('khối chỉ có số/ký hiệu không tốn request dịch', () async {
      var calls = 0;
      final controller = controllerWith(
        <OcrBlock>[
          block('12:30', top: 0),
          block('Hello', top: 3),
        ],
        translator: (text, target) async {
          calls++;
          return TranslationResult.success(
            original: text,
            translated: 'Xin chào',
            engine: 'fake',
          );
        },
      );
      final result = await controller.handleFrame(frame());
      expect(calls, 1);
      expect(result.blocks, hasLength(2));
      expect(result.blocks.first.hasTranslation, isFalse);
      expect(result.blocks.last.hasTranslation, isTrue);
    });

    test('toàn khối không có chữ cái ⇒ noText, không gọi engine', () async {
      var calls = 0;
      final controller = controllerWith(
        <OcrBlock>[block('1234', top: 0), block('— · —', top: 3)],
        translator: (text, target) async {
          calls++;
          return TranslationResult.success(
            original: text,
            translated: 'x',
            engine: 'fake',
          );
        },
      );
      final result = await controller.handleFrame(frame());
      expect(calls, 0);
      expect(result.status, ScreenTranslateStatus.noText);
      expect(result.message, isNotEmpty);
    });
  });

  group('controller — ngôn ngữ nguồn + tiến trình', () {
    test('sourceLanguage từ native được chuẩn hoá; lạ ⇒ AUTO', () async {
      final controller = controllerWith(<OcrBlock>[block('Hello')]);
      await controller.handleFrame(frame(source: 'ja'));
      expect(controller.sourceLanguage, 'JA');

      final second = controllerWith(<OcrBlock>[block('Hello')]);
      await second.handleFrame(frame(source: 'klingon'));
      expect(second.sourceLanguage, kScreenTranslateAutoSource);
    });

    test('báo tiến trình theo thứ tự OCR → dịch → sắp xong', () async {
      final stages = <ScreenTranslateStage>[];
      final controller = controllerWith(
        <OcrBlock>[block('Hello'), block('World', top: 3)],
        onProgress: (stage, done, total) => stages.add(stage),
      );
      await controller.handleFrame(frame());
      expect(stages.first, ScreenTranslateStage.ocr);
      expect(stages, contains(ScreenTranslateStage.translating));
      expect(stages.last, ScreenTranslateStage.finishing);
    });

    test('progressText đã i18n (không trả tiếng Việt cho locale en)', () {
      final controller = ScreenTranslateController(localeCode: 'en');
      final text = controller.progressText(
        ScreenTranslateStage.ocr,
      );
      expect(text, isNotEmpty);
      expect(text.contains('Đang'), isFalse);
    });
  });

  group('hasTranslatableLetters', () {
    test('chữ Latin / Hán / Devanagari ⇒ true', () {
      expect(hasTranslatableLetters('Hello'), isTrue);
      expect(hasTranslatableLetters('日本語'), isTrue);
      expect(hasTranslatableLetters('नमस्ते'), isTrue);
    });

    test('số, giờ, ký hiệu ⇒ false', () {
      expect(hasTranslatableLetters('12:30'), isFalse);
      expect(hasTranslatableLetters('— · ▸'), isFalse);
      expect(hasTranslatableLetters('   '), isFalse);
    });
  });
}
