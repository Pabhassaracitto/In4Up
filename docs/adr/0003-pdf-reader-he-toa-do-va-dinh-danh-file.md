# ADR-0003: PDF Reader — hệ toạ độ rect (giữ quy ước PDF y-up) và định danh file làm khoá dữ liệu đọc

- **Ngày:** 2026-09-05
- **Trạng thái:** ĐÃ TRIỂN KHAI (Wave 0, branch `arena/01a07250-in4up`) — chờ CI
  + nghiệm thu thiết bị
- **Phạm vi:** `lib/features/pdf_reader/**` (services/models/widgets), quy ước dữ
  liệu liên quan tới `VocabContext.rectHint` (Tab Đọc) và `Evidence.locator`
  (module knowledge). Không đổi schema lưu trữ, chỉ đổi CÁCH ĐỌC dữ liệu đó.

## Bối cảnh

1. **Rect "PDF space" của repo không phải rect Flutter.** `PdfRect` của pdfrx
   được chép nguyên sang `Rect` (`_pdfRectToRect` trong `pdf_text_extractor.dart`),
   mà PDF có gốc dưới-trái, y hướng lên → rect sinh ra có `top > bottom`. Với
   `Rect` của Flutter điều đó nghĩa là:
   - `rect.height == bottom - top` là **số âm**;
   - `rect.isEmpty` trả **true** (vì `width <= 0 || height <= 0`);
   - `rect.contains(p)` **luôn false**.
   Ba chỗ từng dựa vào đúng những thứ đó: `Positioned(height: bounds.height)`
   trong `PdfAnnotationLayer` (highlight của người dùng biến mất hoặc vẽ lệch),
   `bounds.contains(...)` + `dist < 20 đơn vị PDF` trong `_WordTapDetector`
   (chạm-từ chỉ "ăn" nhờ nhánh tìm-gần-nhất, sai hẳn khi zoom), và painter overlay.
   Đây là nguyên nhân gốc của hai than phiền "tap hụt" và "bôi sáng sai chỗ".

2. **Mọi dữ liệu đọc của một file PDF bị khoá theo `pdfPath.hashCode` (32 bit)**,
   kể cả `last_page_`. Hệ quả: đổi tên / chuyển thư mục / copy từ chỗ khác về =
   mất highlight, mất trang đọc; và hashCode 32 bit thì có va chạm thật giữa hai
   file. `RecentFile` (Tab Đọc) lại định danh bằng `md5(path)[0:12]` — hai hệ
   thống khác nhau cho cùng một file. ReadEra giữ trạng thái theo *chính file*, nên
   "xoá file rồi tải lại vẫn tiếp tục đúng trang đã đọc" — đó là mức cần đạt.

3. `flutter`/`dart` SDK không có trong sandbox lúc viết → mọi thay đổi ở Wave 0
   phải **tự kiểm chứng bằng nguồn pdfrx `pdfrx-v2.2.24`** và bằng unit test
   thuần Dart (`test/pdf_reader/`), không được giả định API.

## Quyết định

### 1. Quy ước toạ độ: LƯU nguyên, QUY ĐỔI ở consumer

- **Không** "sửa" `_pdfRectToRect` cho rect thuận chiều. Lý do: `PdfAnnotation
  .bounds`, `VocabContext.rectHint`, `Evidence.locator` **đã nằm trên máy người
  dùng** theo quy ước hiện tại; đảo chiều lúc ghi = dữ liệu cũ thành dữ liệu sai
  (và `Rect.fromLTWH` không cho phép chiều âm để mà "sửa" cả hai đầu).
- `lib/features/pdf_reader/services/pdf_geometry.dart` là **nguồn sự thật duy
  nhất** cho việc quy đổi: `pdfRectHeight`, `isPdfSpaceRect` (tài liệu hoá quy
  ước), `isPaintablePdfRect`, `pdfRectToViewerRect`, `pageScaleFactors`.
  Painter highlight, hit-test chạm và annotation layer **phải** gọi qua đây; không
  được tự nhân/chia scale ở widget.
- `pdfRectToViewerRect` dùng `min/max` cho hai cạnh y: rect hợp lệ ở **cả hai**
  chiều đều vẽ đúng (dữ liệu cũ do các đường khác nhau sinh ra), còn rect
  degenerate trả `Rect.zero` để caller bỏ qua, tuyệt đối không đẩy chiều âm vào
  `Positioned`.
- Hit-test và mọi dung sai tính bằng **px của vùng nhìn**, lấy cao độ chữ làm
  đơn vị → bất biến theo zoom (đây là chỗ P0-9/P0-18 được đóng).
- Khi đưa rect đã lưu vào engine (`goToRectInsidePage`), **không** đổi hệ: engine
  dùng `PdfRect(left, top, right, bottom)` với `top >= bottom` — cùng quy ước.
  Chỉ cần đảm bảo thứ tự cạnh (`_revealRect` đảo lại nếu dữ liệu cũ bị ngược).

### 2. Định danh file: khoá dữ liệu đọc là `PdfFileIdentity`, không phải đường dẫn

`lib/features/pdf_reader/services/pdf_file_identity.dart`:

- `primaryKey = md5("size|mtime")` — thông tin đi theo **file**, nên đổi tên /
  chuyển thư mục / copy vẫn nhận ra.
- `pathKey = md5(AudioSourceIdentity.normalize(path))` — khoá dự phòng khi không
  `stat` được (sandbox, permission, thẻ nhớ rút ra), và là khoá để so khớp với
  `VocabContext.sourceName` (chỗ chỉ có tên file).
- `legacyKey = path.hashCode.abs()` — **chỉ** dùng để đọc dữ liệu cũ một lần.
- `PdfAnnotationStorage` sở hữu chuối key (`ann_<idKey>`, `page_<idKey>`) và tự
  migrate qua 3 thế hệ key; caller không bao giờ ghép key thủ công nữa.
- Phép chuẩn hoá đường dẫn **dùng chung** với nguồn audio
  (`utils/audio_source_identity.dart`): `/`, trim, lowercase, percent-decode.
  Một định nghĩa duy nhất cho tới khi có người dùng thứ ba → tách thành
  `SourcePathIdentity` (TODO đã ghi trong code).
- Đổi lại có ý thức: (a) hai file cùng kích thước+cùng mtime sẽ chung khoá — thực
  tế gần như không xảy ra với PDF người dùng tự tạo, và hậu quả chỉ là kế thừa vị
  trí đọc; (b) `pdfSourceMatches` khớp theo basename nên hai `book.pdf` ở hai thư
  mục được coi là một — chọn vậy để "đọc tiếp" mạch lạc, panel chỉ là danh sách từ.

### 3. Mô hình chạm cho PDF (để Wave 1 không vô tình phá)

- **1 chạm** vào chữ = sheet từ (đi qua `PdfViewerParams.onGeneralTap`, không có
  overlay `GestureDetector` phủ trang); **long-press** = `selectWord` của pdfrx;
  **kéo handle** = mở rộng vùng chọn; chạm nền = tắt selection, chạm tiếp = tắt
  chrome. Không có timer auto-hide chrome.
- Vì `onGeneralTap` là điểm chờ (gate) duy nhất, handler **phải** trả `false` cho
  loại chạm nó không xử lý (`doubleTap`/`secondaryTap`) để viewer còn zoom.

## Hệ quả

- Highlight/ghi chú/bookmark của dữ liệu **cũ** hiển thị lại đúng mà không cần
  migration hình học; đồng thời annotation mới có `lineRects` nên một selection
  dài nhiều dòng sáng đúng hình dạng câu thay vì một khối phủ khoảng trắng.
- Dữ liệu đọc sống sót khi người dùng đổi tên file — đóng P0-5, và mở đường cho
  "thư viện + tiếp tục đọc" (Wave 2) dùng cùng một định danh.
- Chi phí: một hàm quy đổi dùng chung (thêm ~2 dòng call ở mỗi consumer), một lần
  `stat()` mỗi file mỗi phiên (cache trong `PdfFileIdentity._cache`), một lượt
  migrate key khi mở file có dữ liệu cũ.
- Ràng buộc cho code mới: **cấm** dùng `Rect.height`/`Rect.contains`/`isEmpty`
  trực tiếp trên rect PDF space; phải qua `pdf_geometry.dart`. Vi phạm là tái lập
  bug P0-18.
- Ràng buộc i18n (rule #5): nhãn mới của PDF Reader phải có key trong catalog —
  `test/pdf_reader/pdf_reader_i18n_coverage_test.dart` quét source mà chặn.

## Triển khai

- `services/pdf_geometry.dart` (mới), `services/pdf_word_hit_test.dart` (mới),
  `services/pdf_file_identity.dart` (mới), `models/pdf_sentence_cue.dart` (mới),
  `models/pdf_annotation.dart` (+`lineRects`/offset/`canReopenToPosition`),
  `services/pdf_annotation_storage.dart` (key theo identity + migration 3 thế hệ),
  `pdf_reader_controller.dart` (selection/TTS/bookmark/`viewerCommands`),
  `pdf_reader_screen.dart` (`onGeneralTap`, `textSelectionParams`, bỏ overlay +
  bỏ auto-hide), `widgets/{pdf_annotation_layer,pdf_word_overlay,pdf_tts_bar,
  pdf_toolbar,pdf_wordlist_panel,pdf_word_tap_sheet}.dart`,
  `core/language/priority_ui_overrides.dart` (51 key).
- Test: `test/pdf_reader/{pdf_reader_geometry,pdf_annotation_model,
  pdf_file_identity,pdf_text_cleaning,pdf_reader_i18n_coverage}_test.dart`.
- Bối cảnh đầy đủ + các mục còn nợ: `docs/pdf_reader_readera_upgrade.md` (mục 2
  P0-18/P0-19, mục 4.0).
