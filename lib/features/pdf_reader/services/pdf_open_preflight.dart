// lib/features/pdf_reader/services/pdf_open_preflight.dart
//
// AUDIT-1.21.0 #4 — Thư viện «Gần đây» ⇒ `PdfException ... FPDF_ER_FILE:2`.
//
// PR #129 đã sửa 6 lỗi PDF Reader, nhưng đường MỞ LẠI file từ danh sách
// "Gần đây" vẫn push thẳng `PdfReaderScreen(pdfPath: file.localPath!)` mà
// KHÔNG kiểm tra file còn tồn tại không (trong khi nhánh localText bên cạnh
// đã có `File(path).existsSync()`). Android dọn cache `file_picker` / user xoá
// file / đổi SAF permission ⇒ pdfrx gọi FPDF_LoadDocument trên path chết ⇒
// `FPDF_ER_FILE:2` ("file not found or could not be opened"), hiện nguyên
// stack lỗi đỏ thay vì hướng dẫn chọn lại file.
//
/// Hàm này là preflight THUẦN Dart (chỉ `dart:io`), chạy được trên host VM:
//  • trước khi điều hướng (library/quick sheet/empty state/device scan);
//  • VÀ ngay trong `PdfReaderScreen.initState` để mọi cửa vào đều được che.
//
// Không đụng `pdf_geometry.dart` / `PdfFileIdentity` (quy tắc vàng #3).

import 'dart:io';

enum PdfOpenIssue {
  none,

  /// File không còn trên đĩa (cache tạm bị dọn / user xoá).
  missing,

  /// File tồn tại nhưng quá nhỏ để là PDF (tải dở / rỗng).
  empty,

  /// Có dữ liệu nhưng thiếu header `%PDF-` (dán nhầm link/HTML/ảnh).
  notPdf,

  /// Không đọc được (quyền, SAF, I/O).
  unreadable,
}

class PdfOpenCheck {
  const PdfOpenCheck(this.issue, {this.length = 0});

  final PdfOpenIssue issue;
  final int length;

  bool get canOpen => issue == PdfOpenIssue.none;
}

/// Số byte tối thiểu của một PDF hợp lệ (header + xref tối thiểu).
const int kPdfMinPlausibleBytes = 128;

/// Kiểm tra [path] TRƯỚC khi `PdfViewer.file()` chạm native PDFium.
///
/// Chỉ đọc 1KB đầu (không nạp cả file vào RAM — PDF có thể hàng trăm MB).
/// Chấp nhận BOM/khoảng trắng trước header `%PDF-` vì một số tool export thêm.
PdfOpenCheck inspectPdfForOpen(String path) {
  if (path.trim().isEmpty) {
    return const PdfOpenCheck(PdfOpenIssue.missing);
  }
  try {
    final file = File(path);
    if (!file.existsSync()) {
      return const PdfOpenCheck(PdfOpenIssue.missing);
    }
    final length = file.lengthSync();
    if (length < kPdfMinPlausibleBytes) {
      return PdfOpenCheck(PdfOpenIssue.empty, length: length);
    }
    final raf = file.openSync();
    late final List<int> head;
    try {
      head = raf.readSync(1024);
    } finally {
      raf.closeSync();
    }
    if (head.length < 5) {
      return PdfOpenCheck(PdfOpenIssue.empty, length: length);
    }
    // Bỏ BOM/khoảng trắng đầu (một số exporter ghi UTF-8 BOM).
    var start = 0;
    if (head.length >= 3 &&
        head[0] == 0xEF &&
        head[1] == 0xBB &&
        head[2] == 0xBF) {
      start = 3;
    }
    while (start < head.length &&
        (head[start] == 0x20 || head[start] == 0x0A || head[start] == 0x0D)) {
      start++;
    }
    const signature = <int>[0x25, 0x50, 0x44, 0x46, 0x2D]; // '%PDF-'
    if (start + signature.length > head.length) {
      return PdfOpenCheck(PdfOpenIssue.notPdf, length: length);
    }
    for (var i = 0; i < signature.length; i++) {
      if (head[start + i] != signature[i]) {
        return PdfOpenCheck(PdfOpenIssue.notPdf, length: length);
      }
    }
    return PdfOpenCheck(PdfOpenIssue.none, length: length);
  } catch (_) {
    return const PdfOpenCheck(PdfOpenIssue.unreadable);
  }
}

/// Nhận diện lỗi PDFium `FPDF_ER_FILE:2` để đổi thành thông báo thân thiện.
/// (pdfrx ném chuỗi này khi file mất/hỏng — không phải lỗi viewer.)
bool isPdfFileError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('fpdf_er_file') ||
      (text.contains('pdf') &&
          (text.contains('file not found') ||
              text.contains('could not be opened') ||
              text.contains('cannot open')));
}
