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

    // ── PSRC-211 vòng 2 · mục 4 — trần 32 KHÔNG bỏ vĩnh viễn phần dư ──
    test('70 khối vào ⇒ 32 dịch + 38 pending, đúng thứ tự đọc, không trùng',
        () {
      final blocks = <OcrBlock>[
        for (var i = 0; i < 70; i++)
          block('dòng $i', top: i * 30, size: 10 + i),
      ];
      final selection = rankBlocksForTranslate(
        blocks,
        kScreenTranslateMaxBlocks,
        viewportTop: 0,
        viewportBottom: 2400,
      );
      expect(selection.selected, hasLength(32),
          reason: 'trần 32 khối MỖI LƯỢT giữ nguyên (không nâng 64)');
      expect(selection.pendingBlocks, 38,
          reason: 'phần dư phải ĐẾM ĐƯỢC, không biến mất');

      // Thứ tự đọc được giữ: top tăng dần.
      final tops = selection.selected.map((b) => b.rect.top).toList();
      expect(tops, orderedEquals(List<int>.of(tops)..sort()));

      // Không khối nào xuất hiện hai lần, và không khối nào vừa chọn vừa dư.
      final ids = selection.selected.map((b) => identityHashCode(b)).toSet();
      expect(ids, hasLength(32));
      for (final pending in selection.pending) {
        expect(ids.contains(identityHashCode(pending)), isFalse);
      }
      expect(
        selection.selected.length + selection.pendingBlocks,
        70,
        reason: 'chọn + dư = toàn bộ khối có chữ ⇒ không bỏ im lặng',
      );
    });

    test('viewport cắt nửa trên màn hình ⇒ khối ĐANG NHÌN được chọn trước',
        () {
      // 40 khối: 20 khối đầu nằm trên viewport, 20 khối sau nằm trong.
      final blocks = <OcrBlock>[
        for (var i = 0; i < 40; i++) block('dòng $i', top: i * 60, size: 40),
      ];
      final selection = rankBlocksForTranslate(
        blocks,
        10,
        viewportTop: 1200,
        viewportBottom: 2400,
      );
      expect(selection.selected, hasLength(10));
      for (final picked in selection.selected) {
        expect(picked.rect.top, greaterThanOrEqualTo(1200),
            reason: 'khối ngoài viewport không được chiếm suất khi còn khối '
                'trong viewport');
      }
      expect(selection.pendingBlocks, 30);
    });

    test('màn hình thật: hết khối thì pending = 0, không báo dư giả', () {
      final selection = rankBlocksForTranslate(<OcrBlock>[
        block('a', top: 0),
        block('bb', top: 100),
      ], kScreenTranslateMaxBlocks);
      expect(selection.pendingBlocks, 0);
      expect(selection.selected, hasLength(2));
    });

    test('hạn mức 0 vẫn đếm phần dư (không bỏ im lặng)', () {
      final selection = rankBlocksForTranslate(<OcrBlock>[
        block('a'),
        block('12:30', top: 50), // không có chữ cái ⇒ không tính là phần dư
        block('bb', top: 100),
      ], 0);
      expect(selection.selected, isEmpty);
      expect(selection.pendingBlocks, 2);
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

    // ── PSRC-211 vòng 2 · mục 4 — "còn N khối · Dịch tiếp" ─────────────
    test('trần 32: pending giữ ĐỦ phần dư, không cắt còn 32', () async {
      // 70 khối ⇒ 38 chờ. Bản trước cắt hàng đợi còn đúng `maxBlocks` ⇒ lượt
      // "Dịch tiếp" chỉ cứu được 32, 6 khối biến mất vĩnh viễn.
      final blocks = <OcrBlock>[
        for (var i = 0; i < 70; i++) block('dòng số $i', top: i * 10, size: 8),
      ];
      final selection = rankBlocksForTranslate(blocks, 32);
      expect(selection.pending, hasLength(38),
          reason: 'hàng đợi phải giữ đủ 38 khối dư');
      expect(selection.pendingBlocks, 38);
    });

    test('vượt trần 32 ⇒ result báo pendingBlocks > 0 (không bỏ im lặng)',
        () async {
      // Frame CỠ THẬT (>= 200px) để layout không bị bỏ qua.
      final controller = build(
        maxBlocks: 2,
        blocks: <OcrBlock>[
          block('một', top: 0, size: 20),
          block('hai', top: 100, size: 20),
          block('ba', top: 200, size: 20),
          block('bốn', top: 300, size: 20),
        ],
      );
      final result = await controller.handleFrame(
        fakeFrame(width: 50, height: 200, screenWidth: 100, screenHeight: 400),
      );
      expect(result.status, ScreenTranslateStatus.ok);
      expect(result.pendingBlocks, 2,
          reason: '2 khối dịch + 2 khối dư ⇒ chip "còn 2 khối · Dịch tiếp"');
      expect(result.hasPending, isTrue);
      expect(controller.pendingCount, 2);
      expect(result.toMap()['pendingBlocks'], 2,
          reason: 'native đọc đúng tên khoá này để hiện chip');
    });

    test('70 khối: lượt đầu 32 + lượt "Dịch tiếp" 32 + còn 6 (KHÔNG mất khối)',
        () async {
      var now = DateTime(2026, 11, 13, 12);
      var calls = 0;
      final controller = build(
        maxBlocks: 32,
        gate: CaptureGate(now: () => now),
        blocks: <OcrBlock>[
          for (var i = 0; i < 70; i++) block('dòng số $i', top: i * 10, size: 8),
        ],
        translator: (text, target) async {
          calls++;
          return TranslationResult.success(
            original: text,
            translated: 'VI $text',
            engine: 'fake',
          );
        },
      );
      final frame0 =
          fakeFrame(width: 50, height: 200, screenWidth: 100, screenHeight: 400);

      final first = await controller.handleFrame(frame0);
      expect(first.pendingBlocks, 38);
      expect(calls, 32);

      now = now.add(const Duration(seconds: 4));
      final second = await controller.translatePendingBlocks();
      expect(second!.blocks, hasLength(32));
      expect(second.pendingBlocks, 6,
          reason: '"Dịch tiếp" chỉ dịch thêm MỘT lượt trần 32, không tự lặp');
      expect(calls, 64);
      expect(controller.pendingCount, 6);

      now = now.add(const Duration(seconds: 4));
      final third = await controller.translatePendingBlocks();
      expect(third!.blocks, hasLength(6),
          reason: 'phần dư cuối cùng vẫn dịch được — 32+32+6 = 70 khối');
      expect(third.pendingBlocks, 0);
      expect(calls, 70);
      expect(controller.pendingCount, 0);
    });

    test('lượt "Dịch tiếp" dịch nốt phần dư rồi trả về, pending về 0',
        () async {
      // Đồng hồ giả: `CaptureGate.complete()` tính lại mốc debounce từ lúc
      // KẾT THÚC lượt (chống spam bấm), nên lượt "Dịch tiếp" ngay sau lượt đầu
      // sẽ bị bỏ nếu không tua đồng hồ. Trên máy thật người dùng bấm chip sau
      // vài giây nên đây mới đúng là kịch bản cần test.
      var now = DateTime(2026, 11, 13, 12);
      final controller = build(
        maxBlocks: 2,
        gate: CaptureGate(now: () => now),
        blocks: <OcrBlock>[
          block('một', top: 0, size: 20),
          block('hai', top: 100, size: 20),
          block('ba', top: 200, size: 20),
        ],
      );
      final first = await controller.handleFrame(
        fakeFrame(width: 50, height: 200, screenWidth: 100, screenHeight: 400),
      );
      expect(first.pendingBlocks, 1);

      now = now.add(const Duration(seconds: 4));
      final second =
          await controller.translatePendingBlocks(targetLanguage: 'VI');
      expect(second, isNotNull);
      expect(second!.status, ScreenTranslateStatus.ok);
      expect(second.blocks, hasLength(1));
      expect(second.blocks.single.hasTranslation, isTrue);
      // Hết phần dư ⇒ chip tự ẩn ở lượt sau.
      expect(controller.pendingCount, 0);
      expect(await controller.translatePendingBlocks(), isNull,
          reason: 'không còn phần dư ⇒ null để native ẩn chip');
    });

    // ── mục 7.3 — lọc số/ký hiệu/link TRƯỚC khi cắt hạn mức ──────────────
    test('khối rác KHÔNG chiếm suất của trần 32 (lọc trước khi cắt)',
        () async {
      // Màn hình dày chữ: 3 khối chữ thật chen giữa rất nhiều khối rác. Bản
      // cũ cắt 2 khối đầu rồi mới lọc ⇒ cả 2 suất rơi vào khối rác và màn
      // hình có chữ nhưng không khối nào được dịch.
      final controller = build(
        maxBlocks: 2,
        blocks: <OcrBlock>[
          block('12:30', top: 0, size: 20),
          block('100%', top: 40, size: 20),
          block('https://ví-dụ.com/rat/dai', top: 80, size: 20),
          block('Chữ thật một', top: 120, size: 20),
          block('Chữ thật hai', top: 160, size: 20),
        ],
      );
      final result = await controller.handleFrame(
        fakeFrame(width: 50, height: 200, screenWidth: 100, screenHeight: 400),
      );
      expect(result.status, ScreenTranslateStatus.ok);
      final translated = result.blocks
          .where((b) => b.hasTranslation)
          .map((b) => b.original)
          .toList();
      expect(translated, containsAll(<String>['Chữ thật một', 'Chữ thật hai']),
          reason: 'suất hạn mức phải dành cho khối CÓ CHỮ, không phải giờ/URL');
      // Khối rác vẫn có mặt (bản dịch rỗng) ⇒ native không vẽ ô trống nhưng
      // bên gọi vẫn biết đủ vị trí khối OCR.
      expect(result.blocks, hasLength(5));
    });

    test('hạn mức tính trên khối có chữ: 5 chữ + 40 rác ⇒ 2 dịch, 3 dư',
        () async {
      final controller = build(
        maxBlocks: 2,
        blocks: <OcrBlock>[
          for (var i = 0; i < 40; i++)
            block('${i % 60}:${(i * 7) % 60}', top: i * 10, size: 5),
          for (var i = 0; i < 5; i++)
            block('dòng chữ $i', top: 500 + i * 40, size: 20),
        ],
      );
      final result = await controller.handleFrame(
        fakeFrame(width: 50, height: 200, screenWidth: 100, screenHeight: 400),
      );
      expect(result.pendingBlocks, 3,
          reason: '5 khối chữ, hạn mức 2 ⇒ còn 3; 40 khối số không tính');
    });

    test('"Dịch tiếp" không tự lặp vô hạn: cổng chặn bấm dồn', () async {
      var now = DateTime(2026, 11, 13, 12);
      // 3 khối + trần 1 ⇒ sau lượt "Dịch tiếp" đầu VẪN còn 1 khối chờ. Nếu chỉ
      // để 2 khối thì lần bấm thứ hai rơi vào nhánh "hết phần dư" (null) chứ
      // không chạm cổng chặn — test sẽ không chứng minh được gì.
      final controller = build(
        maxBlocks: 1,
        gate: CaptureGate(now: () => now),
        blocks: <OcrBlock>[
          block('một', top: 0, size: 20),
          block('hai', top: 100, size: 20),
          block('ba', top: 200, size: 20),
        ],
      );
      await controller.handleFrame(
        fakeFrame(width: 50, height: 200, screenWidth: 100, screenHeight: 400),
      );
      now = now.add(const Duration(seconds: 4));
      final first = await controller.translatePendingBlocks();
      final second = await controller.translatePendingBlocks();
      expect(first, isNotNull);
      expect(first!.pendingBlocks, 1, reason: 'vẫn còn 1 khối chờ');
      // Lượt thứ hai (bấm liên tiếp) bị CaptureGate bỏ ⇒ không đốt quota engine.
      expect(second?.status, ScreenTranslateStatus.skipped);
    });
  });
}
