# L7 — Tệp: nơi lưu mặc định + "Mở bằng in4up"

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD) và **`docs/adr/0029-noi-luu-tep-mac-dinh-va-doi-tung-lan.md`** (quyết định đã chốt — làm theo ADR, đừng thiết kế lại).
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

1. File app xuất ra (âm thanh, bản ghi, phụ đề, bản dịch) đi vào **một nơi lưu mặc định** theo hồ sơ, có nút "Đổi…" **từng lần xuất**; dữ liệu nội bộ app ở thư mục riêng tư (ADR-0029).
2. App nhận được file/âm thanh/video từ app khác qua **intent filter** ("Mở bằng in4up") và mở đúng chức năng.

## Issue

| # | Trạng thái | Triệu chứng |
|---|---|---|
| **PSRC-204** | Backlog | Vị trí lưu âm thanh/ghi âm không rõ, người dùng không tìm thấy file |
| **PSRC-222** | Backlog | Mở tài liệu/âm thanh/video bằng "in4up" (intent filter) không hoạt động |

## Hướng điều tra

1. **204**: đọc ADR-0029 (§ 3, § 4). Cần một service duy nhất trả `Destination` cho mọi loại xuất — nếu mỗi tính năng tự ghép path (`getApplicationDocumentsDirectory()` + tên) thì đó là nguyên nhân gốc. Grep `getApplicationDocumentsDirectory`, `getExternalStorageDirectory`, `saveAs`, `Share`.
2. Đảm bảo: thông báo sau khi lưu có **đường dẫn hiển thị được** + nút "Mở thư mục"/"Chia sẻ"; trên Android ghi qua MediaStore/SAF (không cần quyền lưu trữ rộng).
3. **222**: `android/app/src/main/AndroidManifest.xml` — cần `intent-filter` cho `ACTION_VIEW` + `ACTION_SEND` với `mimeType` (`text/*`, `application/pdf`, `audio/*`, `video/*`) và `content://` URI. Phía Dart: đọc intent lúc khởi động **và** khi app đã chạy (`onNewIntent`), rồi route theo loại file. iOS: `Info.plist` `CFBundleDocumentTypes` nếu kịp — nếu không, ghi rõ ngoài phạm vi.
4. Copy URI từ ngoài vào bộ nhớ app trước khi dùng (quyền đọc tạm của `content://` sẽ hết hạn).

## File chạm (dự kiến)

Service lưu file dùng chung (`lib/core/**` hoặc `lib/features/media_tools/services/**`), các điểm gọi trong `lib/features/{media_tools,tts,cabin,video,text}/**`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, test `test/files/*`.

## Nghiệm thu

- [ ] Xuất âm thanh/ghi âm/bản dịch ⇒ file nằm đúng thư mục mặc định của ADR-0029, thấy được từ app Files/MediaStore trên máy thật.
- [ ] "Đổi…" chỉ đổi cho lần xuất đó; lần sau quay lại mặc định (test cho logic chọn đích).
- [ ] Từ app Files bấm "Mở bằng in4up" với 1 PDF, 1 mp3, 1 docx ⇒ app mở đúng màn hình tương ứng; thử cả khi app đang chạy nền.
- [ ] `flutter analyze` 0 error; `app_analyze` xanh.

## Không làm

- Không làm "di chuyển file cũ sang nơi lưu mới" — đã hoãn sang 1.30 (ADR-0029 § 6).
- Không thêm quyền `MANAGE_EXTERNAL_STORAGE`.

## Commit

```
feat(PSRC-204): một nơi lưu mặc định + "Đổi…" cho mọi lần xuất [L7]
feat(PSRC-222): nhận file/âm thanh/video qua "Mở bằng in4up" [L7]
```

## Phát hiện thêm

_(trống)_
