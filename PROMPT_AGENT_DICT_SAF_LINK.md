# Prompt giao việc — Trả lại chế độ "Liên kết thư mục" cho từ điển trên Android (DICT-LINK-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. Việc này cần
**máy Android thật** để nghiệm thu (SAF chỉ sống trên thiết bị).

---

## 0. Luật phiên

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`).
- `AGENTS.md` + quy tắc vàng: không đụng `lib/ffi/`, không gộp 3 SM-2, giữ
  reopen anchor, ADR cho thay đổi kiến trúc, i18n rule #5 (chuỗi mới đủ
  `en/hi/zh/zh_TW/si` trong `lib/core/language/priority_ui_overrides.dart`,
  **đừng** chạy `tool/generate_arbs.py`).
- Không tải gì lúc bootstrap. Build release `--flavor stable`.
- Card KANBAN `DICT-LINK-001`: status-only + append lịch sử.

## 1. Yêu cầu của chủ dự án (audit 0.10.3 mục 1.d)

"Nhập từ điển thành công nhưng **mục liên kết tới thư mục biến mất**, chỉ còn
sao chép vào app. Nói 'tốn dung lượng tương đương' là không đúng: copy thì
file nằm **hai nơi**, liên kết thì **một nơi**."

Chủ dự án hoàn toàn đúng về dung lượng. Phần copy đã được sửa lời trong commit
`DICT-LINK-001` (nói rõ "nằm ở HAI nơi, xoá bản gốc sau khi copy"), và hộp
thoại nay giải thích vì sao Android tạm thời không có chế độ liên kết. **Việc
của bạn là làm cho chế độ liên kết chạy thật trên Android.**

## 2. Sự thật trong repo

- `lib/features/dictionary/widgets/dict_manager_screen.dart` — `_askStorageMode()`
  ẩn lựa chọn "Liên kết thư mục" bằng `if (!Platform.isAndroid)`.
- `lib/features/dictionary/services/dict_import_service.dart` — luồng import,
  hai chế độ `DictStorageMode.linked` / `.imported`.
- `lib/features/dictionary/services/dict_device_channel.dart` — cầu nối
  native hiện có.
- Tra từ: `DictionaryService.instance.lookup(word)` →
  `lib/features/dictionary/` (MDX parser + DB index).
- Test đang chạy trong CI: `test/dictionary/dict_db_service_test.dart`,
  `dict_result_sheet_test.dart`, `mdx_parser_test.dart`,
  `dict_import_lookup_test.dart`, `test/dict_bundle_scanner_test.dart`.

**Lý do kỹ thuật của việc ẩn:** trên Android 10+ người dùng chọn thư mục qua
**SAF** (`ACTION_OPEN_DOCUMENT_TREE`) và app chỉ nhận được `content://` URI,
**không** phải đường dẫn hệ thống. Parser MDX hiện đọc bằng `dart:io` `File`
với `RandomAccessFile` (seek theo offset) nên không mở được `content://`.

## 3. Hướng giải (chốt trước khi code, ghi vào ADR nếu đổi kiến trúc)

**Bắt buộc giữ tính chất "chỉ một bản sao trên máy".**

1. **Persistable URI permission**: khi người dùng chọn thư mục, gọi
   `takePersistableUriPermission` để quyền sống qua các lần khởi động.
2. **Lớp đọc ngẫu nhiên qua SAF**: viết một `RandomAccessSource` trừu tượng
   trong Dart (`seek`, `read(n)`, `length`) với hai hiện thực:
   - `FileRandomAccessSource` (hiện tại, desktop/iOS/file thật),
   - `SafRandomAccessSource` (Android): native Kotlin mở
     `ParcelFileDescriptor` từ URI rồi đọc theo offset, trả bytes qua
     MethodChannel/`pigeon`. **Đọc theo khối** (vd 64 KB) + cache nhỏ, không
     bao giờ nạp cả file mdd vào RAM.
3. **MDX parser nhận `RandomAccessSource`** thay vì `File` — đây là thay đổi
   có rủi ro nhất, phải giữ nguyên hành vi (các test MDX hiện có phải xanh
   không sửa).
4. **Index vẫn nằm trong app** (SQLite) — đó chỉ là chỉ mục nhỏ, không phải
   bản sao từ điển; nói rõ điều này trong UI.
5. **Mất quyền/đổi thẻ nhớ**: khi URI chết, hiện thông báo "Thư mục từ điển
   không còn truy cập được — chọn lại" kèm nút chọn lại, không xoá index.
6. Bật lại lựa chọn trong `_askStorageMode()` (bỏ `if (!Platform.isAndroid)`)
   và xoá đoạn ghi chú giải thích tạm thời.

## 4. Việc phải làm

1. ADR ngắn cho `RandomAccessSource` (vì đụng kiến trúc đọc từ điển).
2. Hiện thực hai nguồn đọc + native SAF reader.
3. Chuyển MDX parser sang nguồn đọc trừu tượng; giữ API công khai.
4. Bật lại lựa chọn liên kết trên Android + cập nhật lời thoại.
5. Test thuần: `RandomAccessSource` giả (bộ nhớ) đọc đúng offset/biên; parser
   đọc được từ nguồn giả; URI chết ⇒ trạng thái `needsReselect`.
6. Nối test mới vào `app_analyze.yml` (mẫu bước có `[ -f ]` guard).
7. i18n đủ `en/hi/zh/zh_TW/si`.

## 5. Nghiệm thu

1. Android: chọn thư mục có `*.mdx` + `*.mdd` → tra từ ra nghĩa, **không**
   tốn thêm dung lượng bằng cỡ bộ từ điển (kiểm bằng Cài đặt → Bộ nhớ).
2. Khởi động lại app → vẫn tra được (quyền persistable còn).
3. Đổi tên/di chuyển thư mục gốc → thông báo rõ + nút chọn lại.
4. Tra từ có hình/âm thanh (mdd) hoạt động.
5. Chế độ "Sao chép vào app" không đổi hành vi.
6. `flutter analyze` 0 error; toàn bộ test từ điển cũ xanh **không sửa test**.
