// Phím tắt desktop (Wave 1.9) cho màn đọc PDF.
//
// Tách thành hàm thuần vì đây là *chính sách*, không phải widget: bảng nào được
// phép thắng bàn nào (ô tìm kiếm đang nhận chữ, Text Mode không phải viewer
// pdfrx, Ctrl/Cmd tổ hợp thuộc về hệ thống). Test được mà không cần pump widget.
import 'package:flutter/services.dart';

enum PdfReaderShortcut {
  nextPage,
  previousPage,
  firstPage,
  lastPage,
  toggleChrome,
  openSearch,
  closeSearchOrScreen,
  openToc,
  toggleBookmark,
  zoomIn,
  zoomOut,
}

/// Một dòng trong hộp "Phím tắt" — key hiển thị + hành vi, dùng cho dialog trợ giúp
/// và cũng là bảng duy nhất mô tả tổ hợp phím (đừng để tài liệu lệch code).
typedef PdfShortcutHelpRow = ({List<String> keys, PdfReaderShortcut action});

const List<PdfShortcutHelpRow> pdfReaderShortcutHelp = [
  (keys: ['→', 'PageDown'], action: PdfReaderShortcut.nextPage),
  (keys: ['←', 'PageUp'], action: PdfReaderShortcut.previousPage),
  (keys: ['Home'], action: PdfReaderShortcut.firstPage),
  (keys: ['End'], action: PdfReaderShortcut.lastPage),
  (keys: ['Space'], action: PdfReaderShortcut.toggleChrome),
  (keys: ['F'], action: PdfReaderShortcut.openSearch),
  (keys: ['T'], action: PdfReaderShortcut.openToc),
  (keys: ['B'], action: PdfReaderShortcut.toggleBookmark),
  (keys: ['+', '='], action: PdfReaderShortcut.zoomIn),
  (keys: ['-', '_'], action: PdfReaderShortcut.zoomOut),
  (keys: ['Esc'], action: PdfReaderShortcut.closeSearchOrScreen),
];

/// Đổi phím thành hành vi, hoặc `null` nếu không có.
///
/// Quy tắc:
/// - **có Ctrl/Cmd/Alt/Shift+modifier tổ hợp** → bỏ qua (phím hệ thống/phím trình
///   duyệt đã giành). Riêng Shift một mình được phép cho `+`/`_` (gõ shift+= ra `+`).
/// - **Text Mode** (`isPdfView == false`): chỉ `Esc` còn nghĩa, vì lúc đó không có
///   viewer để lật trang.
/// - **đang mở ô tìm kiếm**: `Space` nhường cho việc gõ chữ; `T`/`F` thành `null`
///   (đang gõ mà bật sheet khác là mất focus); `Esc` luôn đóng.
/// - Các mũi tên/PageUp/PageDown vẫn hoạt động khi đang tìm: người dùng bấm `Enter`
///   để nhảy kết quả rồi vẫn cần lật trang.
PdfReaderShortcut? resolvePdfReaderShortcut({
  required LogicalKeyboardKey key,
  required bool isPdfView,
  bool searchOpen = false,
  bool hasModifier = false,
}) {
  if (key == LogicalKeyboardKey.escape) {
    return PdfReaderShortcut.closeSearchOrScreen;
  }
  if (!isPdfView) return null;

  // `+`/`-` đi cùng Shift/Ctrl vẫn có nghĩa (gõ shift+= ra `+`), nên riêng hai
  // họ phím này được miễn kiểm tra modifier. Lưu ý: `LogicalKeyboardKey` KHÔNG có
  // `plus` — phím numpad tên là `add` (đây chính là lỗi CI đỏ ở Wave 1.9).
  final isZooming = key == LogicalKeyboardKey.equal ||
      key == LogicalKeyboardKey.minus ||
      key == LogicalKeyboardKey.numpadAdd ||
      key == LogicalKeyboardKey.numpadSubtract;
  if (hasModifier && !isZooming) return null;

  if (key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.pageDown) {
    return PdfReaderShortcut.nextPage;
  }
  if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.pageUp) {
    return PdfReaderShortcut.previousPage;
  }
  if (key == LogicalKeyboardKey.home) return PdfReaderShortcut.firstPage;
  if (key == LogicalKeyboardKey.end) return PdfReaderShortcut.lastPage;
  if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) {
    return PdfReaderShortcut.zoomIn;
  }
  if (key == LogicalKeyboardKey.minus ||
      key == LogicalKeyboardKey.numpadSubtract) {
    return PdfReaderShortcut.zoomOut;
  }
  if (key == LogicalKeyboardKey.keyF) {
    return searchOpen ? null : PdfReaderShortcut.openSearch;
  }
  if (key == LogicalKeyboardKey.keyT) {
    return searchOpen ? null : PdfReaderShortcut.openToc;
  }
  if (key == LogicalKeyboardKey.keyB) return PdfReaderShortcut.toggleBookmark;
  if (key == LogicalKeyboardKey.space && !searchOpen) {
    return PdfReaderShortcut.toggleChrome;
  }
  return null;
}

/// Nhãn hành vi cho dialog trợ giúp — trả về key đã đăng ký trong catalog để
/// `uiText` dịch được (rule #5: không có chuỗi Việt thô trong mã).
String pdfShortcutHelpLabelKey(PdfReaderShortcut action) {
  switch (action) {
    case PdfReaderShortcut.nextPage:
      return 'Trang sau';
    case PdfReaderShortcut.previousPage:
      return 'Trang trước';
    case PdfReaderShortcut.firstPage:
      return 'Trang đầu';
    case PdfReaderShortcut.lastPage:
      return 'Trang cuối';
    case PdfReaderShortcut.toggleChrome:
      return 'Ẩn/hiện thanh công cụ';
    case PdfReaderShortcut.openSearch:
      return 'Tìm trong file';
    case PdfReaderShortcut.closeSearchOrScreen:
      return 'Đóng';
    case PdfReaderShortcut.openToc:
      return 'Mục lục';
    case PdfReaderShortcut.toggleBookmark:
      return 'Đánh dấu trang';
    case PdfReaderShortcut.zoomIn:
      return 'Phóng to';
    case PdfReaderShortcut.zoomOut:
      return 'Thu nhỏ';
  }
}
