// lib/features/pdf_reader/widgets/pdf_open_messages.dart
//
// AUDIT-1.21.0 #4 — thông báo thân thiện thay cho `FPDF_ER_FILE:2`.
//
// Chiều dịch nằm ở file presentation (`/widgets/`) nên generator i18n quét
// được: mọi chuỗi chrome mới có English override + bản địa 4 locale ưu tiên
// (quy tắc vàng #5). Tầng service chỉ trả enum, không giữ chuỗi UI.

import 'package:in4up/core/language/localized_material.dart';

import '../services/pdf_open_preflight.dart';

String pdfOpenIssueMessage(BuildContext context, PdfOpenIssue issue) {
  return switch (issue) {
    PdfOpenIssue.none => '',
    PdfOpenIssue.missing => context.uiText(
        'Không còn file PDF trên máy. Thêm lại từ Thiết bị.'),
    PdfOpenIssue.empty => context.uiText(
        'File PDF rỗng hoặc tải dở. Chọn lại file khác.'),
    PdfOpenIssue.notPdf => context.uiText(
        'Đây không phải file PDF hợp lệ. Chọn lại file .pdf.'),
    PdfOpenIssue.unreadable => context.uiText(
        'Không đọc được file PDF. Kiểm tra lại quyền truy cập.'),
  };
}

/// Lỗi PDFium `FPDF_ER_FILE:2` ⇒ câu dễ hiểu + hành động cụ thể.
String pdfFriendlyError(BuildContext context, String raw) {
  if (isPdfFileError(raw)) {
    return context.uiText(
      'File PDF không còn hoặc bị hỏng (FPDF_ER_FILE:2). Thêm lại từ Thiết bị.',
    );
  }
  return raw;
}
