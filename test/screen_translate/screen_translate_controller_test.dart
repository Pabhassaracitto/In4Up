// XLAT-SCR-002 — logic một lượt dịch màn hình (thuần Dart, không thiết bị).
//
// OCR + engine dịch được BƠM vào controller nên test chạy được trên host VM:
// đây là lý do kiến trúc tách "hiểu chữ + dịch ở Dart" khỏi "chụp + vẽ ở
// native" (ADR-0011) — không có seam này thì mọi thứ chỉ test được bằng tay
// trên máy Android.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_block.dart';
import 'package:in4up/features/ocr/ocr_service.dart';
import 'package:in4up/features/screen_translate/screen_translate_controller.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';

/// Frame 2×2 px đặc (không padding), RGBA.
Map<Object?, Object?> fakeFrame({
  int width = 2,
  int height = 2,
  int screenWidth = 4,
  int screenHeight = 4,
  String target = 'VI',
  Uint8List? pixels,
  int? rowStride,
}) {
  return <Object?, Object?>{
    'pixels': pixels ?? Uint8List(width * height * 4),
    'width': width,
    'height': height,
    'rowStride': rowStride ?? width * 4,
    'screenWidth': screenWidth,
    'screenHeight': screenHeight,
    'devicePixelRatio': 2.0,
    'targetLanguage': target,
    'locale': 'en',
  };
}

OcrBlock block(String text, {int top = 0, int left = 0, int size = 40}) =>
    OcrBlock(
      text: text,
      rect: OcrBlockRect(
        left: left,
        top: top,
        right: left + size,
        bottom: top + size,
      ),
    );

void main() {
  group('CaptureGate (chống spam bấm bong bóng)', () {
    test('lượt thứ hai trong 1.5s bị bỏ qua', () {
      var now = DateTime(2026, 10, 5, 12);
      final gate = CaptureGate(
        minInterval: const Duration(milliseconds: 1500),
        now: () => now,
      );
      expect(gate.tryAcquire(), isTrue);
      gate.complete();
      now = now.add(const Duration(milliseconds: 900));
      expect(gate.tryAcquire(), isFalse);
      now = now.add(const Duration(milliseconds: 700));
      expect(gate.tryAcquire(), isTrue);
    });

    test('đang bận ⇒ từ chối ngay cả khi đã quá hạn debounce', () {
      var now = DateTime(2026, 10, 5, 12);
      final gate = CaptureGate(now: () => now);
      expect(gate.tryAcquire(), isTrue);
      now = now.add(const Duration(seconds: 30));
      expect(gate.tryAcquire(), isFalse);
      expect(gate.isBusy, isTrue);
      gate.complete();
      expect(gate.isBusy, isFalse);
    });

    test('reset (tắt service) cho phép chụp lại ngay', () {
      var now = DateTime(2026, 10, 5, 12);
      final gate = CaptureGate(now: () => now);
      expect(gate.tryAcquire(), isTrue);
      gate.complete();
      gate.reset();
      expect(gate.tryAcquire(), isTrue);
    });
  });

  group('selectBlocksToTranslate', () {
    test('ít hơn hạn mức ⇒ giữ nguyên tất cả', () {
      final blocks = <OcrBlock>[block('a'), block('bb', top: 50)];
      expect(selectBlocksToTranslate(blocks, 10).length, 2);
    });

    test('vượt hạn mức ⇒ giữ khối to/nhiều chữ nhất, ĐÚNG thứ tự đọc', () {
      final blocks = <OcrBlock>[
        block('x', top: 0, size: 10), // nhỏ
        block('nội dung chính dài', top: 100, size: 200),
        block('tiêu đề', top: 300, size: 120),
      ];
      final kept = selectBlocksToTranslate(blocks, 2);
      expect(kept.map((b) => b.text).toList(),
          <String>['nội dung chính dài', 'tiêu đề']);
    });

    test('hạn mức 0 ⇒ rỗng', () {
      expect(selectBlocksToTranslate(<OcrBlock>[block('a')], 0), isEmpty);
    });
  });

  group('ScreenTranslateController.handleFrame', () {
    ScreenTranslateController build({
      required List<OcrBlock> blocks,
      OcrBlocksResult? ocrOverride,
      Future<TranslationResult> Function(String text, String target)?
          translator,
      CaptureGate? gate,
      int maxBlocks = kScreenTranslateMaxBlocks,
      List<String>? seenTargets,
    }) {
      return ScreenTranslateController(
        localeCode: 'en',
        maxBlocks: maxBlocks,
        gate: gate,
        ocrRunner: ({
          required Uint8List pixels,
          required int width,
          required int height,
        }) async =>
            ocrOverride ?? OcrBlocksResult(blocks: blocks),
        translator: translator ??
            (text, target) async {
              seenTargets?.add(target);
              return TranslationResult.success(
                original: text,
                translated: '[$target] $text',
                engine: 'fake-engine',
              );
            },
      );
    }

    test('đường hạnh phúc: trả khối đã dịch + engine + toạ độ đã scale',
        () async {
      final targets = <String>[];
      final controller = build(
        blocks: <OcrBlock>[block('Hello', left: 0, top: 0, size: 2)],
        seenTargets: targets,
      );
      final result = await controller.handleFrame(fakeFrame());

      expect(result.status, ScreenTranslateStatus.ok);
      expect(result.engine, 'fake-engine');
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single.original, 'Hello');
      expect(result.blocks.single.translation, '[VI] Hello');
      // capture 2×2 → screen 4×4 ⇒ nhân đôi toạ độ.
      expect(result.blocks.single.rect.right, 4);
      expect(targets, <String>['VI']);
    });

    test('ngôn ngữ đích từ native được dùng nguyên văn (viết hoa)', () async {
      final targets = <String>[];
      final controller = build(
        blocks: <OcrBlock>[block('Hi', size: 2)],
        seenTargets: targets,
      );
      await controller.handleFrame(fakeFrame(target: 'hi'));
      expect(targets, <String>['HI']);
    });

    test('không có chữ ⇒ noText, không gọi engine dịch', () async {
      var called = 0;
      final controller = build(
        blocks: const <OcrBlock>[],
        translator: (text, target) async {
          called++;
          return TranslationResult.success(
            original: text,
            translated: text,
            engine: 'x',
          );
        },
      );
      final result = await controller.handleFrame(fakeFrame());
      expect(result.status, ScreenTranslateStatus.noText);
      expect(called, 0);
      expect(result.message, isNotEmpty);
    });

    test('OCR lỗi ⇒ error có thông điệp', () async {
      final controller = build(
        blocks: const <OcrBlock>[],
        ocrOverride: OcrBlocksResult.failure(error: 'native boom'),
      );
      final result = await controller.handleFrame(fakeFrame());
      expect(result.status, ScreenTranslateStatus.error);
      expect(result.message, isNotEmpty);
    });

    test('thiếu model offline ⇒ missingModel + liệt kê mã ngôn ngữ', () async {
      final controller = build(
        blocks: <OcrBlock>[block('Hello', size: 2)],
        translator: (text, target) async => TranslationResult.failure(
          original: text,
          error: 'Chưa tải gói dịch',
          engine: 'mlkit',
          missingModelCodes: const <String>['VI'],
        ),
      );
      final result = await controller.handleFrame(fakeFrame());
      expect(result.status, ScreenTranslateStatus.missingModel);
      expect(result.missingModelCodes, <String>['VI']);
      // Khối vẫn được trả về (bản dịch rỗng) để native biết chỗ nào hỏng.
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single.hasTranslation, isFalse);
    });

    test('engine ném exception ở 1 khối ⇒ các khối còn lại vẫn dịch', () async {
      final controller = build(
        blocks: <OcrBlock>[
          block('one', size: 2),
          block('two', top: 2, size: 2),
        ],
        translator: (text, target) async {
          if (text == 'one') throw StateError('engine chết');
          return TranslationResult.success(
            original: text,
            translated: 'OK $text',
            engine: 'fake-engine',
          );
        },
      );
      final result = await controller.handleFrame(fakeFrame());
      expect(result.status, ScreenTranslateStatus.ok);
      expect(result.blocks, hasLength(2));
      expect(result.blocks.first.hasTranslation, isFalse);
      expect(result.blocks.last.translation, 'OK two');
    });

    test('frame không có pixels ⇒ error, không ném exception', () async {
      final controller = build(blocks: <OcrBlock>[block('a')]);
      final result = await controller.handleFrame(<Object?, Object?>{
        'width': 2,
        'height': 2,
      });
      expect(result.status, ScreenTranslateStatus.error);
    });

    test('rowStride sai ⇒ error chứ không đọc tràn bộ nhớ', () async {
      final controller = build(blocks: <OcrBlock>[block('a')]);
      final result = await controller.handleFrame(
        fakeFrame(rowStride: 2),
      );
      expect(result.status, ScreenTranslateStatus.error);
    });

    test('bấm liên tiếp ⇒ lượt sau skipped (debounce)', () async {
      var now = DateTime(2026, 10, 5, 12);
      final gate = CaptureGate(now: () => now);
      final controller = build(
        blocks: <OcrBlock>[block('Hello', size: 2)],
        gate: gate,
      );
      final first = await controller.handleFrame(fakeFrame());
      expect(first.status, ScreenTranslateStatus.ok);
      final second = await controller.handleFrame(fakeFrame());
      expect(second.status, ScreenTranslateStatus.skipped);

      now = now.add(const Duration(seconds: 2));
      final third = await controller.handleFrame(fakeFrame());
      expect(third.status, ScreenTranslateStatus.ok);
    });

    test('số khối vượt hạn mức ⇒ chỉ dịch đúng hạn mức', () async {
      var calls = 0;
      final controller = build(
        maxBlocks: 2,
        blocks: <OcrBlock>[
          block('a', top: 0, size: 2),
          block('bb', top: 2, size: 2),
          block('ccc', top: 4, size: 2),
        ],
        translator: (text, target) async {
          calls++;
          return TranslationResult.success(
            original: text,
            translated: text,
            engine: 'fake-engine',
          );
        },
      );
      final result = await controller.handleFrame(
        fakeFrame(width: 2, height: 8, screenWidth: 2, screenHeight: 8),
      );
      expect(calls, 2);
      expect(result.blocks, hasLength(2));
    });
  });
}
