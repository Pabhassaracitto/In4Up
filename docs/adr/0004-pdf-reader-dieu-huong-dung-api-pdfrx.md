# ADR-0004: PDF Reader Wave 1 — điều hướng & tìm kiếm đứng trên API của pdfrx, không tự xây

- **Ngày:** 2026-09-05
- **Trạng thái:** ĐÃ TRIỂN KHAI (đợt A: 1.1 TOC, 1.2 search, 1.3 thumbnails, nhảy trang)
  trên `arena/01a07250-in4up`; CI 🟢 `c4f62c5` (run 34011472325). Nghiệm thu thiết bị còn mở.
- **Phạm vi:** `lib/features/pdf_reader/{services,widgets}/**`, `pdf_reader_screen.dart`,
  `pdf_toolbar.dart`. Không đổi schema lưu trữ, không đổi dependency.

## Bối cảnh

Wave 1 cần ba thứ mà ReadEra có còn ta không: mục lục, tìm trong file, lược đồ trang.
Ba lựa chọn kiến trúc xuất hiện ngay khi đọc tài liệu pdfrx:

1. **Tự viết engine tìm kiếm**: `extractFullText()` của ta (đã có từ Wave 0) → build
   index trong isolate + cache theo `PdfFileIdentity.primaryKey`. Nghe "chuyên nghiệp"
   nhưng là tự nuôi một hệ thống phụ: tiến độ, hủy, cache lệch khi file đổi, và đoạn
   ngữ cảnh phải tự cắt theo charRects (dễ lệch như P0-19).
2. **Dùng `PdfTextSearcher` của pdfrx** (có từ 2.x, `packages/pdfrx/lib/src/widgets/
   pdf_text_searcher.dart` ở tag `pdfrx-v2.2.24`): quét **dần từng trang** qua
   `loadStructuredText()`, cache per-page, `Listenable`, có `searchProgress`, có luôn
   `pageTextMatchPaintCallback` để tô sáng bằng `pagePaintCallbacks`, và tự restart khi
   một trang vừa tải xong (`PdfDocumentPageStatusChangedEvent`).
3. **Nâng pdfrx lên 2.4.8/2.6.x** để lấy search/overlay "xịn hơn": đụng
   `pubspec.yaml`, `third_party/pdfium_flutter` (0.1.9 → 0.2.x), Windows Developer Mode,
   và có thể phải nâng Flutter 3.44 → 3.47 (blast radius cả app).

Một ràng buộc thứ hai: dữ liệu reopen (`Evidence.locator`, `VocabContext.rectHint`,
`PdfAnnotation.bounds`) đang nằm trong **hệ toạ độ PDF y-up** theo ADR-0003, còn rect
của kết quả tìm kiếm đến từ `charRects` của structured text. Nếu tô sáng bằng overlay
riêng, ta nhân đôi chỗ quy đổi — đúng chỗ hay sai nhất (P0-18 từng là bug thật).

## Quyết định

1. **Tìm kiếm = `PdfTextSearcher` + `pagePaintCallbacks`.** App không tự giữ index hay
   cache text cho search. Layer của ta chỉ là *chính sách query*
   (`services/pdf_search_query.dart`) và *mặt nạ UI* (`widgets/pdf_search_panel.dart`).
   `goToMatch`/`ensureVisible` được bọc try/catch ở UI: layout trang đích có thể chưa
   sẵn sàng, mất một cú nhảy tốt hơn văng khỏi màn đọc.
2. **Tạo `PdfTextSearcher` ở `PdfViewerParams.onViewerReady`, không phải
   `onDocumentChanged`.** Constructor của nó đọc `controller.document` (`_document!`)
   ngay khi dựng để nghe `events` ⇒ gọi sớm là chạm assert. Đây cũng là nơi đọc
   `loadOutline()`; outline lỗi/thiếu ⇒ coi như "không có mục lục", tuyệt đối không
   để nó làm trắng màn hình đọc.
3. **Không nâng pdfrx trong wave này.** `^2.2.24` đủ cho cả 1.1/1.2/1.3 đã verify
   (xem "Căn cứ" cuối file). Việc nâng 2.4.8 là quyết định riêng, có ADR riêng, và
   nên làm **sau** khi owner nghiệm thu thiết bị — nếu không ta đổi engine dưới chân
   đúng lúc đang đo phản ứng người dùng.
4. **Mục lục: giữ nguyên `PdfDest`, không tự tính trang.** Nhảy bằng
   `PdfViewerController.goToDest(dest)` để tận dụng `XYZ`/`FitR` (vị trí trong trang),
   thứ mà "chỉ lưu pageNumber" mất. Quy ước mốc trang (dest 1-based ↔ controller
   0-based) chỉ được dịch trong `pdf_outline_index.dart`; widget không so trang tay.
5. **Chính sách bỏ dấu khi tìm: gộp theo HỌ, 1 ký tự ↔ 1 ký tự.** `ă/â/a` vào một họ,
   `ê/e`, `ô/ơ/o`, `ư/u`, `đ/d`. **Không** cho co giãn `aa`↔`â`: nó làm offset
   `start/end` mà pdfrx dùng để tô sáng lệch khỏi charRects. Đây là đánh đổi có ý:
   người dùng gõ Telex "caan" sẽ không thấy "cân" — nhưng mọi kết quả tìm được đều
   tô đúng chỗ. Mặc định tắt; bật bằng chip "Không phân biệt dấu".
6. **Thumbnail qua `PdfPageView` với `maximumDpi: 96`, suy dựng lười bằng
   `GridView.builder`** — không tạo thư mục cache ảnh, không tiền render. 500 trang
   chỉ tốn RAM những ô đang thấy.

## Hệ quả

- **P0-11 ("extract cả file đồng bộ, chặn UI") không còn là điều kiện của tính năng
  tìm kiếm**: searcher của pdfrx đã incremental theo trang. P0-11 vẫn còn đó cho
  **Text Mode** (nơi ta vẫn gọi `extractFullText`), và vẫn là nợ có ghi nhận.
- **Kết quả tìm nằm trong không gian structured text** (`loadStructuredText`) còn
  cue TTS của Wave 0 dựa trên `fullText` của `loadText` → đúng va chạm đã ghi ở
  **P0-19**: search không bị ảnh hưởng (nó dùng offset của chính nó), nhưng nếu sau
  này muốn "tìm rồi đọc từ chỗ tìm" thì phải hợp nhất một nguồn offset. Việc đó nằm
  ở đợt B, không phải ở đây.
- **Không có chỉ mục nghĩa là tìm lần đầu chậm hơn về lý thuyết** (quét tuần tự từng
  trang thay vì tra cache). Đổi lại: không có cache hỏng, không có trường hợp "index
  lệch file", và tiến độ là thật (`searchProgress`).
- UI chrome phải tôn trọng ô nhập: `_showTopChrome` giờ bao gồm `_searchOpen` — ẩn
  theo timer khi user đang gõ là mất chữ họ gõ.
- Test: `pdf_outline_index_test.dart` + `pdf_search_query_test.dart` phủ hai hàm có
  logic thật; widget không có test (cần SDK máy dev; `test/pdf_reader/**` vẫn chưa
  chạy lần nào trong CI — xem KANBAN PDF-W1).

## Căn cứ (API đã đối chiếu tại tag `pdfrx-v2.2.24`, engine `pdfrx_engine 0.3.9`)

- `packages/pdfrx/lib/pdfrx.dart` dòng 6: `export 'src/widgets/pdf_text_searcher.dart';`
  ⇒ `PdfTextSearcher` là API công khai, không phải nội bộ.
- `pdf_text_searcher.dart`: `startTextSearch(Pattern, {caseInsensitive, goToFirstMatch,
  searchImmediately})` (debounce 500 ms khi `searchImmediately: false`), `matches`,
  `currentIndex`, `isSearching`, `searchProgress`, `goToNextMatch/goToPrevMatch/
  goToMatchOfIndex`, `resetTextSearch`, `pageTextMatchPaintCallback`, `dispose`.
- `pdf_viewer_params.dart`: `onViewerReady` = `void Function(PdfDocument,
  PdfViewerController)`; `pagePaintCallbacks` = `List<PdfViewerPagePaintCallback>?`
  với `void Function(ui.Canvas, Rect, PdfPage)`; `matchTextColor`,
  `activeMatchTextColor` là `Color?`.
- `pdfrx_engine/lib/src/pdf_document.dart`: `Future<List<PdfOutlineNode>> loadOutline()`;
  `pdf_outline_node.dart`: `{title, dest, children}`; `pdf_dest.dart`:
  `PdfDest(int pageNumber, PdfDestCommand command, List<double?>? params)`.
- `pdf_text.dart`: `PdfPageTextRange.{pageNumber, start, end, text, pageText}`;
  `PdfPageText.allMatches` — với `RegExp` thì **cờ `caseInsensitive` của hàm bị ghi
  đè bằng `pattern.isCaseSensitive`** ⇒ mọi độ nhạy hoa/thường phải nằm trong RegExp
  mà ta dựng (đó là lý do `buildPdfSearchPattern` nhét cả biến thể HOA vào lớp ký tự).
