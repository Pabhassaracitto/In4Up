// lib/features/pdf_reader/models/pdf_page_translation.dart
//
// Model bản dịch theo CÂU cho "Dịch màn hình" của PDF Reader (PLAN-035 ·
// KANBAN XLAT-SCR-001).
//
// Một dòng = một câu (hoặc một đoạn OCR) của trang + bản dịch. `bounds` lấy từ
// `PdfSentenceCue.bounds` (toạ độ PDF gốc dưới-trái) — bản này chỉ hiển thị
// trong panel song ngữ, nhưng giữ bounds sẵn để bước nâng cấp sau (overlay đè
// nhẹ lên dòng gốc — xem ADR-0010) không phải đổi schema.

import 'dart:ui' show Rect;

/// Một cặp gốc → dịch trên trang PDF.
class PdfPageSentenceTranslation {
  const PdfPageSentenceTranslation({
    required this.pageIndex,
    required this.original,
    required this.bounds,
    this.translation,
  });

  final int pageIndex;

  /// Câu gốc (văn bản đã làm sạch — `PdfSentenceCue.speakText`, hoặc đoạn tách
  /// từ text OCR khi trang không có lớp chữ).
  final String original;

  /// Bản dịch — `null` nghĩa là câu đó dịch thất bại (UI hiện dấu gạch thay vì
  /// giả vờ thành công).
  final String? translation;

  /// Vùng của câu trên trang (toạ độ PDF). `Rect.zero` với đơn vị tách từ OCR
  /// (OCR chỉ cho text phẳng, không có toạ độ câu).
  final Rect bounds;

  bool get hasTranslation =>
      translation != null && translation!.trim().isNotEmpty;

  PdfPageSentenceTranslation copyWith({String? translation}) {
    return PdfPageSentenceTranslation(
      pageIndex: pageIndex,
      original: original,
      bounds: bounds,
      translation: translation ?? this.translation,
    );
  }
}

/// Tổng kết một lượt dịch trang.
class PdfPageTranslateReport {
  const PdfPageTranslateReport({
    required this.translations,
    required this.translatedCount,
    required this.failedCount,
    this.stoppedEarly = false,
    this.error,
  });

  final List<PdfPageSentenceTranslation> translations;
  final int translatedCount;
  final int failedCount;

  /// True khi dừng vì lỗi liên tiếp (không dịch nốt phần còn lại).
  final bool stoppedEarly;

  /// Lỗi cuối cùng (nếu có) — để UI nói đúng chuyện (mạng, engine…).
  final String? error;

  bool get isEmpty => translations.isEmpty;
}
