// PLAN-035 · KANBAN PDF-OCR-002 — batch OCR cho PDF Reader.
//
// Khoá lại hành vi của phần "não" (`services/pdf_batch_ocr.dart`):
//  - resolvePdfOcrPages: 3 phạm vi + biên (clamp, hoán đổi from/to, rỗng);
//  - runPdfBatchOcr: skip trang có lớp chữ, MỘT trang lỗi không giết cả lô,
//    cancel giữ lại phần đã quét, progress đúng số lượng, join bằng dòng trống.
//
// Thuần Dart: recognizer/probe là closure giả — không cần pdfrx/ML Kit.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_cancel_token.dart';
import 'package:in4up/features/pdf_reader/services/pdf_batch_ocr.dart';

void main() {
  group('resolvePdfOcrPages', () {
    test('currentPage → đúng 1 trang đang đọc (clamp khi sai lệch)', () {
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.currentPage,
          currentPage: 4,
          totalPages: 10,
        ),
        const [4],
      );
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.currentPage,
          currentPage: 99,
          totalPages: 10,
        ),
        const [9],
      );
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.currentPage,
          currentPage: -3,
          totalPages: 10,
        ),
        const [0],
      );
    });

    test('tài liệu chưa mở (totalPages 0) → rỗng, mọi phạm vi', () {
      for (final scope in PdfOcrScope.values) {
        expect(
          resolvePdfOcrPages(
            scope: scope,
            currentPage: 0,
            totalPages: 0,
          ),
          isEmpty,
          reason: '$scope',
        );
      }
    });

    test('range: from/to là số trang 1-based, nhập ngược thì hoán đổi', () {
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.range,
          currentPage: 0,
          totalPages: 10,
          from: 3,
          to: 5,
        ),
        const [2, 3, 4],
      );
      // Người dùng gõ "từ 8 đến 2" — hiểu ý là 2..8 thay vì trả rỗng.
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.range,
          currentPage: 0,
          totalPages: 10,
          from: 8,
          to: 2,
        ),
        const [1, 2, 3, 4, 5, 6, 7],
      );
    });

    test('range: clamp vào 1..totalPages (nhập 0 / vượt cuối)', () {
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.range,
          currentPage: 0,
          totalPages: 10,
          from: 0,
          to: 3,
        ),
        const [0, 1, 2],
      );
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.range,
          currentPage: 0,
          totalPages: 10,
          from: 9,
          to: 99,
        ),
        const [8, 9],
      );
    });

    test('range: null → mặc định toàn tài liệu (giá trị khởi tạo của sheet)',
        () {
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.range,
          currentPage: 2,
          totalPages: 4,
        ),
        const [0, 1, 2, 3],
      );
    });

    test('all → mọi trang 0-based', () {
      expect(
        resolvePdfOcrPages(
          scope: PdfOcrScope.all,
          currentPage: 0,
          totalPages: 3,
        ),
        const [0, 1, 2],
      );
    });
  });

  group('runPdfBatchOcr', () {
    test('quét tuần tự, join các trang có chữ bằng dòng trống', () async {
      final outcome = await runPdfBatchOcr(
        pages: const [0, 1, 2],
        // Fake recognizer theo ĐÚNG hợp đồng production (_recognizePage):
        // text rỗng → .empty, không bao giờ .ok với text rỗng.
        recognize: (page) async => page == 1
            ? PdfPageOcrOutcome.empty(page)
            : PdfPageOcrOutcome.ok(page, 'Trang $page'),
        delayBetweenPages: Duration.zero,
      );

      expect(outcome.cancelled, isFalse);
      expect(outcome.okCount, 2);
      expect(outcome.emptyCount, 1);
      expect(outcome.failedCount, 0);
      // Trang empty (không có chữ) KHÔNG tạo khối rỗng giữa các trang.
      expect(outcome.joinedText, 'Trang 0\n\nTrang 2');
      expect(outcome.hasText, isTrue);
    });

    test('một trang lỗi KHÔNG giết cả lô — đếm và nói rõ trang nào lỗi',
        () async {
      final outcome = await runPdfBatchOcr(
        pages: const [0, 1, 2, 3],
        recognize: (page) async => page == 1 || page == 3
            ? PdfPageOcrOutcome.failure(page, 'render failed')
            : PdfPageOcrOutcome.ok(page, 'Trang $page'),
        delayBetweenPages: Duration.zero,
      );

      expect(outcome.failedCount, 2);
      expect(outcome.failedPageNumbers, const [2, 4]); // 1-based cho user
      expect(outcome.joinedText, 'Trang 0\n\nTrang 2');
    });

    test('skip trang đã có lớp chữ khi bật mặc định', () async {
      final probed = <int>[];
      final outcome = await runPdfBatchOcr(
        pages: const [0, 1, 2],
        recognize: (page) async => PdfPageOcrOutcome.ok(page, 'Trang $page'),
        hasTextLayer: (page) async {
          probed.add(page);
          return page == 1; // trang 1 đã có lớp chữ
        },
        skipPagesWithTextLayer: true,
        delayBetweenPages: Duration.zero,
      );

      expect(probed, const [0, 1, 2]);
      expect(outcome.skippedCount, 1);
      expect(outcome.joinedText, 'Trang 0\n\nTrang 2');
    });

    test('tắt skip → quét lại cả trang đã có lớp chữ', () async {
      final outcome = await runPdfBatchOcr(
        pages: const [0, 1],
        recognize: (page) async => PdfPageOcrOutcome.ok(page, 'OCR $page'),
        hasTextLayer: (page) async => true,
        skipPagesWithTextLayer: false,
        delayBetweenPages: Duration.zero,
      );

      expect(outcome.skippedCount, 0);
      expect(outcome.joinedText, 'OCR 0\n\nOCR 1');
    });

    test('cancel giữa chừng → dừng ở ranh giới trang, GIỮ phần đã quét',
        () async {
      final token = OcrCancelToken();
      final scanned = <int>[];

      // Hủy trong lúc trang 1 đang quét — mô phỏng người dùng bấm Hủy giữa
      // chừng. Trang đang quét dở KHÔNG được đếm (kết quả nửa vời), phần đã
      // quét xong TRƯỚC đó phải giữ nguyên.
      final outcomeFuture = runPdfBatchOcr(
        pages: const [0, 1, 2, 3],
        recognize: (page) async {
          scanned.add(page);
          if (page == 1) token.cancel();
          return PdfPageOcrOutcome.ok(page, 'Trang $page');
        },
        cancelToken: token,
        delayBetweenPages: Duration.zero,
      );
      final outcome = await outcomeFuture;

      expect(outcome.cancelled, isTrue);
      expect(scanned, const [0, 1]); // trang 2, 3 không quét tiếp
      expect(outcome.joinedText, 'Trang 0'); // trang 1 dở → không đếm
    });

    test('progress gọi sau mỗi trang (kể cả trang bị skip), đủ số lượng',
        () async {
      final events = <PdfBatchOcrProgress>[];
      await runPdfBatchOcr(
        pages: const [0, 1, 2],
        recognize: (page) async => PdfPageOcrOutcome.ok(page, 'T$page'),
        hasTextLayer: (page) async => page == 0,
        onProgress: events.add,
        delayBetweenPages: Duration.zero,
      );

      expect(events.length, 3);
      expect(events[0].done, 1);
      expect(events[0].pageIndex, 0);
      expect(events[1].done, 2);
      expect(events[2].done, 3);
      expect(events[2].fraction, 1.0);
    });

    test('mọi trang đều trống → hasText false, không throw', () async {
      final outcome = await runPdfBatchOcr(
        pages: const [0, 1],
        recognize: (page) async => PdfPageOcrOutcome.empty(page),
        delayBetweenPages: Duration.zero,
      );

      expect(outcome.hasText, isFalse);
      expect(outcome.joinedText, '');
    });
  });
}
