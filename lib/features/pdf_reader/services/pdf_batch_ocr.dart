// lib/features/pdf_reader/services/pdf_batch_ocr.dart
//
// Batch OCR cho PDF Reader (PLAN-035 · KANBAN PDF-OCR-002).
//
// Vì sao cần: nút "Quét chữ trang này" (pdf_tts_bar.dart, ADR-0009 · OCR-001)
// chỉ quét MỘT trang đang đọc. Sách scan vài trăm trang thì bấm từng trang là
// không dùng được. File này là phần "não" của batch OCR: suy ra danh sách trang
// từ lựa chọn user + chạy vòng quét có progress/cancel/skip — tất cả qua
// callback tiêm vào để test thuần Dart trên host VM (không cần pdfrx/ML Kit).
//
// Khác với `OcrService.recognizeFiles` (dừng sớm khi MỘT trang lỗi): batch PDF
// phải KHÔNG chết vì một trang — trang fail được đếm, cả lô vẫn trả về phần đã
// quét được. Lý do: quét 80 trang mất vài phút, chết ở trang 79 rồi bỏ hết là
// tệ nhất có thể.
//
// Quy ước join: các trang có chữ ghép bằng '\n\n' — cùng quy ước
// `recognizeFiles` (Document Scanner nhiều trang) để pipeline ngắt dòng của
// TextProvider xử lý tự nhiên. KHÔNG chèn tiêu đề "trang N" vào giữa: đó là
// nội dung giả sẽ lọt vào pipeline CEFR/POS và vào SRS người học.

import '../../ocr/ocr_cancel_token.dart';

/// Phạm vi quét mà người dùng chọn trong sheet.
enum PdfOcrScope {
  /// Chỉ trang đang đọc.
  currentPage,

  /// Khoảng trang (nhập từ… đến…, 1-based như người dùng thấy trên UI).
  range,

  /// Toàn bộ tài liệu.
  all,
}

/// Trạng thái của MỘT trang trong lô.
enum PdfPageOcrStatus {
  /// Quét xong và có chữ.
  ok,

  /// Quét xong nhưng trang không có chữ (trang bìa, trang ảnh không chữ…).
  empty,

  /// Render/OCR lỗi — KHÔNG giết cả lô, chỉ đếm.
  failed,

  /// Bỏ qua vì trang đã có lớp chữ (extract-by-code chạy được, quét lại là
  /// đốt pin vô ích) hoặc người dùng tắt chế độ bỏ qua thì không bao giờ có.
  skippedHasText,
}

/// Kết quả quét MỘT trang.
class PdfPageOcrOutcome {
  const PdfPageOcrOutcome({
    required this.pageIndex,
    required this.status,
    this.text = '',
    this.error,
  });

  const PdfPageOcrOutcome.ok(this.pageIndex, this.text)
      : status = PdfPageOcrStatus.ok,
        error = null;

  const PdfPageOcrOutcome.empty(this.pageIndex)
      : status = PdfPageOcrStatus.empty,
        text = '',
        error = null;

  const PdfPageOcrOutcome.failure(this.pageIndex, this.error)
      : status = PdfPageOcrStatus.failed,
        text = '';

  const PdfPageOcrOutcome.skipped(this.pageIndex)
      : status = PdfPageOcrStatus.skippedHasText,
        text = '',
        error = null;

  final int pageIndex;
  final PdfPageOcrStatus status;
  final String text;
  final String? error;

  bool get hasText => status == PdfPageOcrStatus.ok && text.trim().isNotEmpty;
}

/// Tiến độ vòng quét: [done] trang đã xử lý (kể cả skip/empty), [total] là số
/// trang trong kế hoạch, [pageIndex] là trang vừa xử lý xong.
class PdfBatchOcrProgress {
  const PdfBatchOcrProgress({
    required this.done,
    required this.total,
    required this.pageIndex,
  });

  final int done;
  final int total;
  final int pageIndex;

  double get fraction => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);
}

/// Kết quả cả lô.
class PdfBatchOcrOutcome {
  const PdfBatchOcrOutcome({
    required this.pages,
    required this.cancelled,
  });

  /// Kết quả từng trang THEO THỨ TỰ quét.
  final List<PdfPageOcrOutcome> pages;

  /// True khi người dùng bấm Hủy giữa chừng — phần đã quét vẫn giữ lại.
  final bool cancelled;

  bool get hasText => pages.any((p) => p.hasText);

  /// Toàn bộ chữ của lô, các trang ghép bằng dòng trống.
  String get joinedText {
    final parts = <String>[];
    for (final p in pages) {
      if (p.hasText) parts.add(p.text.trim());
    }
    return parts.join('\n\n');
  }

  int get okCount =>
      pages.where((p) => p.status == PdfPageOcrStatus.ok).length;
  int get emptyCount =>
      pages.where((p) => p.status == PdfPageOcrStatus.empty).length;
  int get failedCount =>
      pages.where((p) => p.status == PdfPageOcrStatus.failed).length;
  int get skippedCount =>
      pages.where((p) => p.status == PdfPageOcrStatus.skippedHasText).length;

  /// Các trang lỗi (để UI nói rõ trang nào cần quét lại) — 1-based cho user.
  List<int> get failedPageNumbers => [
        for (final p in pages)
          if (p.status == PdfPageOcrStatus.failed) p.pageIndex + 1,
      ];
}

/// Suy ra danh sách trang (0-based) sẽ quét từ lựa chọn của người dùng.
///
/// [from]/[to] là số trang 1-based NHƯ HIỂN THỊ cho user ("từ trang 3 đến
/// trang 10"). Hai số được hoán đổi nếu nhập ngược, và clamp vào
/// 1..totalPages. Trả về danh sách rỗng khi đầu vào không dùng được (tài liệu
/// chưa mở, khoảng rỗng sau clamp).
List<int> resolvePdfOcrPages({
  required PdfOcrScope scope,
  required int currentPage,
  required int totalPages,
  int? from,
  int? to,
}) {
  if (totalPages <= 0) return const <int>[];

  switch (scope) {
    case PdfOcrScope.currentPage:
      final page = currentPage.clamp(0, totalPages - 1);
      return <int>[page];
    case PdfOcrScope.range:
      var start = (from ?? 1).clamp(1, totalPages);
      var end = (to ?? totalPages).clamp(1, totalPages);
      if (start > end) {
        final swap = start;
        start = end;
        end = swap;
      }
      return List<int>.generate(end - start + 1, (i) => start - 1 + i);
    case PdfOcrScope.all:
      return List<int>.generate(totalPages, (i) => i);
  }
}

/// Nhận dạng chữ MỘT trang (đã raster hoá hay chưa là việc của closure này).
typedef PdfPageRecognizer = Future<PdfPageOcrOutcome> Function(int pageIndex);

/// Hỏi xem một trang đã có lớp chữ (extract-by-code được) chưa.
typedef PdfPageTextProbe = Future<bool> Function(int pageIndex);

/// Chạy batch OCR qua danh sách trang đã suy ra.
///
/// - [recognize]: closure quét 1 trang (production: rasterizePdfPage +
///   OcrService.recognizeBitmap; test: giả lập).
/// - [hasTextLayer] + [skipPagesWithTextLayer]: bỏ qua trang đã có chữ.
/// - [onProgress]: gọi sau MỖI trang (kể cả skip) để UI vẽ "trang i/N".
/// - [cancelToken]: bấm Hủy → dừng ở ranh giới trang, giữ lại phần đã quét.
/// - [delayBetweenPages]: nhả UI isolate + hạ nhiệt thiết bị giữa hai trang.
Future<PdfBatchOcrOutcome> runPdfBatchOcr({
  required List<int> pages,
  required PdfPageRecognizer recognize,
  PdfPageTextProbe? hasTextLayer,
  bool skipPagesWithTextLayer = true,
  void Function(PdfBatchOcrProgress progress)? onProgress,
  OcrCancelToken? cancelToken,
  Duration delayBetweenPages = const Duration(milliseconds: 120),
}) async {
  final outcomes = <PdfPageOcrOutcome>[];
  final total = pages.length;

  for (var i = 0; i < total; i++) {
    if (cancelToken?.isCancelled ?? false) {
      return PdfBatchOcrOutcome(pages: outcomes, cancelled: true);
    }

    final pageIndex = pages[i];
    PdfPageOcrOutcome outcome;

    if (skipPagesWithTextLayer && hasTextLayer != null) {
      final hasText = await hasTextLayer(pageIndex);
      if (cancelToken?.isCancelled ?? false) {
        return PdfBatchOcrOutcome(pages: outcomes, cancelled: true);
      }
      if (hasText) {
        outcome = PdfPageOcrOutcome.skipped(pageIndex);
        outcomes.add(outcome);
        onProgress?.call(
          PdfBatchOcrProgress(done: i + 1, total: total, pageIndex: pageIndex),
        );
        continue;
      }
    }

    outcome = await recognize(pageIndex);

    // Cancel có thể tới trong lúc await recognize: kết quả trang đó là rác
    // nửa vời (recognizer thường trả failed với error 'cancelled') — không
    // đếm vào lô, dừng ngay và giữ phần đã quét.
    if (cancelToken?.isCancelled ?? false) {
      return PdfBatchOcrOutcome(pages: outcomes, cancelled: true);
    }

    outcomes.add(outcome);
    onProgress?.call(
      PdfBatchOcrProgress(done: i + 1, total: total, pageIndex: pageIndex),
    );

    if (i < total - 1 && delayBetweenPages > Duration.zero) {
      await Future<void>.delayed(delayBetweenPages);
    }
  }

  return PdfBatchOcrOutcome(pages: outcomes, cancelled: false);
}
