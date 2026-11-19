# ADR-0029 — Nơi lưu tệp: mặc định theo hồ sơ + đổi được từng lần xuất

- **Trạng thái:** accepted (owner chốt 2026-11-12)
- **Ngày:** 2026-11-12
- **Lane:** L7 của `BETA-1.29.0` (PSRC-204, PSRC-222)
- **Liên quan:** [BETA-1.29.0 §10](../project/BETA-1.29.0.md) (bản đề xuất owner đã duyệt),
  [ADR-0028](0028-vieneu-engine-ship-audio-cpp-va-sea-g2p.md) (lane L6 cùng đợt)

## 1. Câu hỏi của owner

> "Nên chọn nơi lưu cố định hay lưu từng file do người dùng chọn — đâu là cách
> chuyên nghiệp, phù hợp nhất?"

Câu hỏi đặt ra từ hai chỗ đau thật:

1. Người dùng xuất bản ghi âm/bản dịch xong **không tìm thấy tệp** — trên Android
   11+ đường dẫn cũ `Android/data/com.in4up/files/...` gần như không mở được bằng
   ứng dụng quản lý tệp thông thường.
2. Nếu bắt chọn thư mục **mỗi lần** xuất, xuất 10 đoạn A–B liên tiếp = 10 hộp
   thoại; đó là kiểu UX đã bị bỏ dùng từ lâu.

## 2. Quyết định

**Phân tầng, không chọn một trong hai:**

| Tầng | Nội dung | Ghi chú |
|---|---|---|
| Mặc định (không hỏi lại) | Android `Download/In4Up/` · iOS `Files → On My iPhone/In4Up` · Windows/Linux `~/In4Up` | Người dùng mở Files/Downloads là thấy |
| Đổi cho riêng một lần xuất | Hộp thoại xuất hiện rõ *"Lưu vào: Download/In4Up"* + nút **Đổi…** (SAF `ACTION_OPEN_DOCUMENT_TREE`) + tick *"Luôn lưu vào thư mục này"* | Xuất hàng loạt không bị hỏi liên tục; ai cần Drive/thẻ nhớ vẫn làm được |
| Dữ liệu app tự quản | Phiên cabin, model, DB, cache, từ điển SEA-G2P | **Giữ trong thư mục riêng của app** — người dùng không xoá nhầm, app không bị coi là trình quản lý tệp |

Nguyên tắc một dòng: **tệp người dùng tạo ra và muốn mang đi → thư mục công khai;
dữ liệu app cần để chạy → thư mục riêng.**

## 3. Phương án đã loại

| Phương án | Vì sao loại |
|---|---|
| Chỉ cố định, không đổi được | Không gửi được tệp đi nơi khác mà không vào Cài đặt; người dùng vẫn lạc đường |
| Hỏi mỗi lần xuất | 10 lần xuất = 10 hộp thoại; đây chính là kiểu UX gây phàn nàn |
| Ghi vào đường dẫn tuyệt đối bất kỳ (kiểu desktop cũ) | Android 11+ cần `MANAGE_EXTERNAL_STORAGE` ⇒ vướng chính sách Play, dễ bị từ chối |
| Tự di chuyển tệp cũ sang vị trí mới | Người dùng không yêu cầu; xoá/di chuyển ngầm là hành vi nguy hiểm |

## 4. Hệ quả

**Tốt**
- Tệp xuất luôn tìm thấy được bằng ứng dụng quản lý tệp / Files / Explorer.
- Xuất hàng loạt vẫn một cú bấm sau lần chọn đầu tiên.
- Không cần quyền bộ nhớ rộng trên Android 10+ (MediaStore/SAF), không đụng
  `MANAGE_EXTERNAL_STORAGE`.

**Xấu / phải trả giá**
- Thêm một khái niệm trạng thái: "thư mục đã cấp quyền" (SAF URI) có thể **chết**
  khi người dùng xoá thư mục hoặc đổi máy ⇒ phải có đường lùi về mặc định + báo
  một lần, không lỗi im lặng.
- Cần phân biệt "xuất" (công khai) với "lưu phiên" (nội bộ) trong code — hai
  đường ghi khác nhau, không được trộn.
- iOS: bật `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` để thư mục
  hiện trong Files.

## 5. Chi tiết kỹ thuật (khi lane L7 thi công)

| Nền tảng | API | Bắt buộc |
|---|---|---|
| Android 10+ | `MediaStore.Downloads` (thư mục con `In4Up/`) hoặc SAF `ACTION_CREATE_DOCUMENT` | ghi `IS_PENDING` → publish; không cần quyền bộ nhớ |
| Android ≤ 9 | `WRITE_EXTERNAL_STORAGE` + `Environment.DIRECTORY_DOWNLOADS` | đường dự phòng, không mở rộng |
| iOS | App container `Documents/In4Up` + 2 khoá Info.plist ở §4 | — |
| Windows/Linux | `path_provider` `getDownloadsDirectory()` fallback `~/In4Up` | không hộp thoại mỗi lần |
| Mọi nền tảng | Ghi `*.part` → `fsync` → `rename` | tệp hỏng không bao giờ mang tên cuối |
| Mọi nền tảng | Trùng tên ⇒ thêm ` (2)` | không ghi đè |
| Mọi nền tảng | Luôn có "Mở thư mục chứa" sau khi xuất | người dùng thấy kết quả ngay |

Điểm chạm code dự kiến: `lib/features/media_tools/services/media_export_service.dart`
(đường xuất A–B/âm thanh), `lib/features/cabin/services/cabin_session_store.dart`
(lưu phiên — **giữ nội bộ**, chỉ xuất khi người dùng bấm), `lib/features/tipitaka/services/db_service.dart`
(không đổi — dữ liệu app), `TtsService` cache (không đổi).

## 6. Ba điểm owner cần chốt khi lane L7 bắt đầu

1. **Tên thư mục:** `In4Up` (khớp tên app, đọc đẹp) trên cả 4 nền tảng — thay vì
   `in4up` chữ thường. Đề xuất: `In4Up`.
2. **Nút "Chuyển bản xuất cũ"** (chỉ chạy khi người dùng bấm, có xác nhận + báo số
   tệp/dung lượng): làm ở 1.29 hay để 1.30? Đề xuất: **1.30** — 1.29 đã khá dày.
3. **Bản ghi âm cabin:** chỉ xuất ra thư mục công khai khi người dùng bấm "Xuất",
   hay tự xuất khi kết thúc phiên? Đề xuất: **chỉ khi bấm** — tránh thư mục công
   khai đầy tệp tạm.

## 7. Kiểm chứng (máy thật, khi lane L7 xong)

- Xuất 1 tệp ⇒ nhận được ngay thông báo + "Mở thư mục chứa" ⇒ tệp nằm trong
  `Download/In4Up/`.
- Chọn thư mục khác + tick "Luôn lưu vào đây" ⇒ lần xuất sau không hỏi nữa.
- Xoá thư mục đã cấp quyền trong Files ⇒ lần xuất sau quay về mặc định + báo **một**
  lần, không crash.
- Xuất 5 tệp cùng tên ⇒ ` (2)`, ` (3)`… không ghi đè.
- Ngắt mạng/đầy bộ nhớ giữa lúc ghi ⇒ không còn tệp `.part` mang tên thật.
