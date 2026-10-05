# Kế hoạch tối ưu hiển thị I4U Tipiṭaka (tham chiếu OpenTipitaka)

> Mục tiêu: nâng trải nghiệm đọc Tipiṭaka trong In4Up lên mức chuyên nghiệp,
> trở thành một "điểm vàng" của app. Tham chiếu trực tiếp:
> `opentipitaka.org/texts/vin01m_mul?ui=vi&lang=vi`.

## 1. Bài học từ OpenTipitaka (đã đối chiếu trang thật)

| Nguyên tắc | OpenTipitaka làm | In4Up trước tối ưu |
|---|---|---|
| **Tách ngôn ngữ UI và nội dung** (`ui=` vs `lang=`) | Giao diện Việt vẫn xem bản dịch Anh… | Chưa tách rõ: checkbox cứng "Tiếng Việt/English" |
| **Đọc liên tục một trang** | Pāli ↔ dịch đan xen theo dòng chảy văn bản, heading nằm trong luồng | Mỗi đoạn = 1 `Card` → cảm giác "feed", không phải "trang sách" |
| **Mốc trang/đoạn** (`M 1`, `M 2`) | Hiển thị chip nhỏ từ `<pb ed n>` | Thẻ `<pb>` bị xóa sạch khi clean HTML |
| **Số đoạn trôi** (`hangnum`: 1. 2. 3.) | Gọn, nằm trong luồng | Render thành card riêng chỉ chứa một con số |
| **Đánh số đoạn song ngữ 1-1** | Mỗi đoạn Pāli kèm bản dịch ngay dưới | Đã có (block PĀḶI + TIẾNG VIỆT) — giữ và đánh bóng |
| **Typography sách** | Serif, giãn dòng thoáng | Sans mặc định, không theo convention đọc kinh |
| **Chế độ một trang / đa trang** | "Một trang" (one-page) | Đã phân trang theo scroll nhưng chỉ tải "về sau", không tải "về trước" |

## 2. Vấn đề hiển thị phát hiện được trong code hiện tại (audit)

1. `hangnum`/`gatha` (CSCD `rend="hangnum"`, `rend="gatha*"`) chưa được nhận
   diện → số đoạn và kệ hiển thị sai kiểu.
2. `_cleanDisplayText` loại bỏ `<pb>` nhưng không trích xuất mốc trang `ed/n`.
3. Reader là `ListView` + `AppBar` cố định; không immersive (appbar không tự ẩn
   khi cuộn), không giới hạn độ rộng đọc trên tablet/desktop/web.
4. Thanh tiến độ ở header đo "số đoạn đã tải" (loaded) thay vì vị trí đọc.
5. Settings dùng checkbox rờ (Pāli/Việt/Anh) chưa thành "chế độ đọc"; không lưu
   giữa các phiên; không có nền đọc Sáng/Sepia/Tối.
6. **Search là ngõ cụt**: kết quả không mở được bài đọc tại đúng đoạn.
7. TOC sheet thiếu lọc nhanh khi mục lục dài.
8. Library chưa phân biệt màu/biểu tượng 3 Tạng; chưa hiển thị nhãn ấn bản
   (Mūla/Aṭṭhakathā/Ṭīkā).
9. Reference kỹ thuật (`SEG 1`, `ROW 12`) lộ ra chip đoạn → cần che bằng
   nhãn "Đoạn N".

## 3. Kế hoạch triển khai (đã thực hiện trong đợt này)

### P0 — Trải nghiệm trang đọc (reader_screen)
- [x] **Bố cục "trang sách một cột"**: bỏ Card-per-segment; đoạn văn phân tách
  bằng hairline divider, rộng tối đa ~800px canh giữa trên màn hình lớn.
- [x] **Immersive app bar**: `SliverAppBar` floating + snap tự ẩn khi cuộn
  xuống; thanh tiến độ mỏng gắn dưới app bar đo **vị trí cuộn thực**.
- [x] **Typography**: bộ chữ serif (fallback stack Noto Serif → Georgia →
  Times…) cho Pāli và bản dịch; nhãn ngôn ngữ sans, tracking rộng.
- [x] **Nhận diện block CSCD đầy đủ**: book / chapter / subhead / centre /
  hangnum / gatha (kệ thụt dòng, nghiêng); heuristic "dòng chỉ chứa số" cho DB
  đã import sạch tag.
- [x] **Chip mốc trang** trích từ `<pb ed="M" n="1.0001"/>` → "M 1.0001"…
- [x] **Tải 2 chiều**: nút "Tải các đoạn phía trước" khi nhảy từ TOC xuống
  giữa sách, giữ neo vị trí bằng GlobalKey anchor.
- [x] **Che reference kỹ thuật**: `SEG 1`/`ROW 2`/chuỗi rỗng → "Đoạn N".
- [x] Highlight đoạn đang TTS + đoạn anchor nhảy đến.

### P1 — Cài đặt hiển thị chuyên nghiệp (reader_appearance.dart — mới)
- [x] `TipitakaReaderAppearance` (ChangeNotifier) **lưu bền** bằng
  shared_preferences giữa các phiên.
- [x] **Chế độ đọc** (SegmentedButton): Song ngữ / Chỉ Pāli / Chỉ bản dịch.
- [x] **Ngôn ngữ bản dịch chính**: chip chọn vi/en/my/th/… — tương đương tham
  số `lang` của OpenTipitaka, độc lập với ngôn ngữ UI (`ui`).
- [x] **Nền trang đọc**: Theo hệ thống / Sáng / **Sepia** / Tối (override
  ColorScheme cục bộ quanh reader, không ảnh hưởng toàn app).
- [x] **Cỡ chữ slider** 80–160% + slider tốc độ TTS.
- [x] Tùy chọn "Kèm thêm English" làm bản dịch phụ.

### P2 — Search → deep link (search_screen + db_service)
- [x] Thêm `TipitakaDb.getBookById` (kèm content-title subquery).
- [x] Kết quả tìm kiếm **mở Workspace tại đúng đoạn** (initialSegmentId).
- [x] Snippet tự cắt quanh từ khóa trùng đầu tiên + **highlight** từ khóa.
- [x] Số lượng kết quả, nút xóa truy vấn, empty state rõ ràng.

### P3 — Library & TOC polish (library_screen, reader TOC)
- [x] Biểu tượng + màu riêng cho Tạng Kinh/Luật/Luận (CircleAvatar tint).
- [x] Chip ấn bản Mūla/Aṭṭhakathā/Ṭīkā trên từng sách.
- [x] TOC bottom-sheet có ô lọc nhanh.

### Tài nguyên kiến trúc mới
- `lib/features/tipitaka/services/tipitaka_markup.dart` — parser thuần Dart
  dùng chung (clean text, classify block, page markers, nhãn số đoạn, serif
  fallback stack).
- `lib/features/tipitaka/models/reader_appearance.dart` — state hiển thị bền.

## 4. Lộ trình tiếp theo (chưa làm — đề xuất)

| Ưu tiên | Hạng mục | Ghi chú |
|---|---|---|
| P4 | Bookmark/highlight đoạn + "Đọc tiếp" | Lưu vị trí cuộn cuối cùng theo book_id; resume khi mở lại |
| P4 | Ấn bản song hành (Mūla ↔ Aṭṭhakathā) trong split view | Workspace đã hỗ trợ split; cần nút "mở bản đối chiếu" |
| P5 | Footnote/apparatus `\[(...)\]` thu gọn thành chú thích chạm-mở | Hiện inline như OpenTipitaka |
| P5 | Chia sẻ đoạn (deep link trong app) + copy kèm citation chuẩn (DN 1.1) | share_plus đã có |
| P5 | Bundle font Noto Serif thật (assets/fonts) | Sandbox hiện không tải được binary font; stack fallback đã đủ tốt |
| P6 | Đồng bộ cuộn Pāli↔dịch ở chế độ song ngữ ở split | Cần ScrollController đôi |

## 5. Lưu ý license dữ liệu

Dữ liệu Pāli gốc (VRI/CSCD, CC-BY-NC, "non-commercial") — app dùng nội bộ/học
tập cần giữ attribution "Vipassana Research Institute" trong màn Quản lý dữ
liệu và tài liệu phát hành. Không nhúng dữ liệu vào sản phẩm thương mại khi
chưa rà soát giấy phép.

## 6. Kiểm chứng

- `TipitakaWorkspaceScreen` API giữ nguyên → test
  `tipitaka_workspace_retention_test.dart` không bị ảnh hưởng (test dùng
  `readerBuilder` thay thế reader).
- `db_service.dart` chỉ **thêm** phương thức đọc → các test import/i18n không
  đổi.
- Sandbox không có Flutter SDK → cần chạy lại `flutter analyze` +
  `flutter test` trên máy dev/CI sau khi merge.
