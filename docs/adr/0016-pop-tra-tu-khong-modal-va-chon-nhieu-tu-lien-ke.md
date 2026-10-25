# ADR-0016: Pop tra từ nhanh KHÔNG modal + chọn nhiều từ liền kề (tab Đọc)

- **Ngày:** 2026-10-25
- **Trạng thái:** ĐÃ TRIỂN KHAI (nhánh `arena/054f9e9a-in4up`; sandbox không có
  Flutter SDK nên **chưa chạy `flutter analyze`/`flutter test`** — chờ CI)
- **Phạm vi:** `lib/screens/read_mode/widgets/word_mini_pop.dart` (viết lại),
  `lib/screens/read_mode/services/word_pop_layout.dart` (mới),
  `lib/screens/read_mode/widgets/colored_text_widget.dart`,
  `lib/screens/read_mode/services/word_range_selection.dart`,
  `lib/screens/read_mode/read_mode_screen.dart`,
  `lib/screens/read_mode/widgets/text_line_widget.dart`,
  `lib/models/word_color_style.dart` (mới),
  `lib/services/reader_display_settings.dart`, `lib/providers/text_provider.dart`,
  `lib/services/storage_service.dart`.
  KHÔNG đụng `lib/ffi/`/`UltraTimeStretch`, KHÔNG gộp 3 skill SM-2, KHÔNG đổi
  quy ước rect PDF (`PdfGeometry`).

## Bối cảnh

Người sở hữu (2026-10-25) yêu cầu cụ thể cho tab **Đọc**:

1. "Chạm vào một từ thì nó đọc từ đó lên và hiện một cái bảng thông tin nhanh
   về từ đó, không làm tối cả màn hình, không chặn thao tác… muốn thì người
   dùng kéo cái rèm ở trên bảng lên để xem chi tiết đầy đủ" — tức là pop phải
   là **lớp thông tin nhanh**, không phải dialog.
2. "Giữ im một từ thì vào chế độ chọn nhiều từ, kiểu bôi đen, chọn thông minh
   chỉ các từ liền kề nhau thôi; chọn chỗ khác thì trở lại bình thường. Sau
   khi giữ thì phải kéo/quẹt để chọn nhanh nhiều từ."
3. "Cho phép người dùng chọn cách hiển thị các từ, ví dụ chỉ đổi màu chữ thay
   vì có màu nền, để không bị phân tâm" — chỉnh được trong Cài đặt.
4. "Mặc định văn bản căn giữa thay vì bên trái" và lựa chọn căn lề phải sống
   qua lần mở app sau.

Bản 2026-10-20 dùng `showGeneralDialog` + `Dialog`: barrier tối toàn màn hình
và chặn mọi cú chạm ra ngoài ⇒ đúng hai điều bị yêu cầu bỏ. Lựa chọn căn lề
còn bị comment "Tạm thời bỏ qua" nên không lưu.

## Quyết định

### 1. Pop là `OverlayEntry`, KHÔNG có barrier

`WordMiniPop.show()` chèn **hai** overlay entry vào `Overlay.maybeOf(rootOverlay: true)`:

- **catcher**: `Positioned.fill` + `Listener(behavior: HitTestBehavior.translucent,
  onPointerDown: dismiss)`. `translucent` vẫn nhận pointer-down để tự ẩn nhưng
  **trả `false`** ⇒ sự kiện tiếp tục xuống route bên dưới, nên "chạm chỗ khác"
  vừa ẩn pop vừa chạy thao tác bình thường (kể cả chạm sang từ khác — `show()`
  đã `dismiss()` trước nên chỉ còn một pop).
- **card**: `Positioned` đặt cạnh từ, bên trong là `Listener(behavior:
  HitTestBehavior.opaque)` để chạm trong thẻ pop **không** rơi xuống catcher
  (nếu không, chạm vào khoảng đệm của pop sẽ tự đóng pop). Dùng `Listener` chứ
  không `GestureDetector` để không tranh cử chỉ với các nút bên trong.

Chỉ **một** pop tồn tại: `dismiss()` idempotent, gọi trong `dispose()` của
`ReadModeScreen`, khi cuộn vùng đọc (pop "trôi" khỏi từ) và khi vào chế độ chọn.

Toạ độ đặt pop là **hàm thuần** `computeWordPopPlacement(anchor, screen,
maxWidth)` (test được, không cần widget test): rộng `clamp(180, 340)`, không
quá `screen.width - 16`; ưu tiên đặt **dưới** từ khi còn ≥ 240 px, ngược lại
đặt phía nhiều chỗ hơn; `maxHeight` = `clamp(chỗ trống, 96, screen.height - 16)`.

### 2. "Rèm" để bung chi tiết

Đầu thẻ pop có `wordMiniPopCurtainKey`: kéo lên > 36 px (hoặc vuốt nhanh lên)
⇒ `dismiss()` rồi mở `WordActionsSheet` (bảng chi tiết đầy đủ, dùng chung với
PDF/Word Analysis). Chạm vào rèm cũng mở bảng đó. Nội dung pop tái dùng
`WordInsightService` (cục bộ trước → nâng cấp bằng mạng) và `DictDefinitionView`
(compact) y như sheet PDF mà owner khen.

### 3. Chọn nhiều từ: LIỀN KỀ hoặc thoát

`isAdjacentToWordRange(range, index)` trong `word_range_selection.dart` trả
`true` chỉ khi `index == start - 1` hoặc `index == end + 1`. `_onWordTap`:

| Trạng thái | Chạm vào | Kết quả |
|---|---|---|
| đang chọn | từ trong vùng | không đổi gì |
| đang chọn | từ liền kề | mở rộng vùng chọn (`_extendTo`) |
| đang chọn | từ cách xa | **thoát** chế độ chọn (`clearProvider: true`) rồi chạm thường |
| không chọn | bất kỳ | phát âm + mở pop |

`onDoubleTap` bị bỏ (giữ im là chọn từ, nhấn đúp không còn tác dụng phụ).

### 4. Kiểu hiển thị từ (READ-WORDSTYLE-001)

`enum WordColorStyle { fill, textOnly, underline }` — thuần Dart, **độc lập**
với việc chọn *màu gì* (loại từ / CEFR / độ khó). Lưu trong
`ReaderDisplaySettings` (SharedPreferences `reader_word_color_style`), mặc định
`fill` (giữ trải nghiệm cũ). Áp ở **cả hai** đường vẽ chữ của tab Đọc:
`ColoredTextWidget` (chế độ ô chữ) và `SelectableText.rich` trong
`text_line_widget.dart` (chế độ bôi chữ). `textOnly` bỏ cả nền lẫn viền của tô
màu; `underline` giữ chữ màu + gạch chân 1.6 px. UI: `_WordColorStyleSelector`
trong `read_settings_sheet.dart`, chỉ hiện khi `colorMode != none`.

### 5. Căn lề mặc định GIỮA + lưu bền (READ-ALIGN-001)

`TextProvider._textAlign = TextAlign.center`; `setTextAlign` ghi
`read_text_align` qua `StorageService.saveReadTextAlign`; `_restoreFromStorage`
đọc lại bằng `getReadTextAlign()` (giá trị lạ/rỗng ⇒ giữa). Xoá hẳn ghi chú
"Tạm thời bỏ qua" — đó là lý do lựa chọn của người dùng biến mất sau khi mở
lại app.

## Hệ quả

- Pop không còn làm tối/không chặn thao tác; người dùng chạm liên tiếp nhiều
  từ để so sánh nhanh, chỉ cần kéo rèm khi muốn đào sâu.
- Test: `test/read_mode/word_pop_layout_test.dart` (toán đặt pop),
  `test/read_mode/word_range_selection_test.dart` (`isAdjacentToWordRange`),
  `test/read_mode/read_word_style_align_test.dart` (kiểu hiển thị + căn lề),
  `test/read_mode/audit_2026_10_20_ui_compact_test.dart` (cập nhật: chạm =
  pop, giữ = chọn, không còn `onDoubleTap`);
  `test/ai_provider_builtin_and_read_align_test.dart` cập nhật kỳ vọng mặc
  định GIỮA.
- Đánh đổi: pop dùng overlay nên phải tự quản "chỉ một pop" + tự ẩn khi cuộn
  hoặc khi widget chủ unmount; đã xử lý ở `dismiss()`.
