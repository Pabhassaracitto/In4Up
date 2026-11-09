# Prompt giao việc — Thư viện đọc ▸ Quét ảnh ▸ "Chụp & quét tài liệu" LÀM SẬP APP (OCR-SCAN-CRASH-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. Việc này **bắt
buộc có máy Android thật** (hoặc emulator có Google Play Services) — sandbox
không bắt được lỗi này.

---

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; **không** đổi nhánh, **không** merge `main`/`251e`
  từ sandbox. PR nhắm nhánh **`251e`** (`arena/01a0251e-in4up`).
- Đọc `AGENTS.md` ở gốc repo trước. Quy tắc vàng (vi phạm = dừng, hỏi người):
  1. KHÔNG đụng `lib/ffi/` (UltraTimeStretch C++).
  2. KHÔNG gộp 3 skill SM-2.
  3. KHÔNG làm mất khả năng mở lại đúng vị trí nguồn (PDF page/rect, Web
     url/scroll, audio timestamp).
  4. Đổi kiến trúc ⇒ ADR + review.
  5. Locale ≠ `vi` thì chrome UI phải là bản dịch hoặc English — chuỗi mới
     đăng ký `lib/core/language/priority_ui_overrides.dart` đủ
     `en/hi/zh/zh_TW/si`; **đừng** chạy `tool/generate_arbs.py`.
- CẤM tải model bằng HTTP lúc bootstrap/`main()`; chỉ tải khi user bấm.
- Build release Android bắt buộc `--flavor stable`.
- Cập nhật card `OCR-SCAN-CRASH-001` trong `docs/project/KANBAN.md`
  (status-only + append lịch sử, không xoá — xem `docs/GOVERNANCE.md`).
- Commit nhỏ, push ngay. CI: `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (chủ dự án báo, bản 0.10.3)

Thư viện đọc → **Quét ảnh** → **Chụp & quét tài liệu** ⇒ **app tắt ngay**
(không toast, không dialog, không màn hình lỗi).

## 2. Những gì đã loại trừ (đừng làm lại)

Lớp Dart đã bọc try/catch quanh toàn bộ đường quét: lỗi `PlatformException`
hay lỗi ML Kit sẽ hiện snackbar chứ không thể làm tắt app. Việc app biến mất
không dấu vết ⇒ **crash/kill ở tầng native hoặc process bị hệ thống giết**.

Ba giả thuyết theo thứ tự khả năng:

1. **Tải module ML Kit lúc chạy.** `com.google.mlkit:text-recognition` bản
   "thin" tải model qua Google Play Services lần đầu dùng. Máy thiếu/lỗi GMS,
   hết dung lượng, hoặc bị chặn mạng ⇒ `MlKitException`/`UnavailableException`
   ném trên luồng native. Kiểm chứng: `adb logcat | grep -i "mlkit\|vision\|
   DynamiteModule"`.
2. **Mất kết quả camera do `launchMode` / process death.** Khi `MainActivity`
   là `singleTop` (xem `android/app/src/main/AndroidManifest.xml`) và máy ít
   RAM, Android có thể huỷ activity trong lúc app camera đang mở; quay lại,
   `onActivityResult` không có state ⇒ NPE native. Kiểm chứng: bật
   *Developer options → Don't keep activities* rồi lặp lại — nếu tái hiện
   100% thì đúng nhánh này.
3. **Thiếu quyền/khai báo.** `CAMERA` chưa được cấp runtime, hoặc thiếu
   `<queries>` cho intent camera trên Android 11+, hoặc `FileProvider`
   authority sai ⇒ `SecurityException` native.

## 3. Nơi cần đọc

- `lib/features/ocr/` — toàn bộ lane OCR (service, cancel token, UI quét).
- Màn gọi: tìm bằng `grep -rn "Chụp & quét tài liệu" lib/`.
- `android/app/src/main/AndroidManifest.xml` — `launchMode`, `CAMERA`,
  `<queries>`, `FileProvider`.
- `android/app/src/main/kotlin/.../MainActivity.kt`.
- `android/app/build.gradle.kts` — phiên bản ML Kit (dự án **pin 0.16.x** cho
  một số plugin ML Kit; đừng nâng bừa).
- Test đang có: `test/ocr/ocr_cancel_token_test.dart` (chạy trong CI).

## 4. Việc phải làm

1. **Lấy log crash thật**: `adb logcat -c` → thao tác tái hiện →
   `adb logcat -d > crash.log`. Dán **đúng stack trace** vào card KANBAN. Đây
   là sản phẩm bắt buộc; mọi sửa đổi phải chỉ được vào dòng log cụ thể.
2. **Sửa đúng nguyên nhân** tìm được (một giả thuyết một commit).
3. **Chốt an toàn cho cả ba nhánh**, kể cả khi nguyên nhân chỉ là một:
   - Bọc gọi ML Kit trong native/Dart sao cho mọi `MlKitException` trở thành
     thông báo tiếng Việt có hành động ("Thiếu dịch vụ Google Play — cài/cập
     nhật rồi thử lại").
   - Kiểm tra `isGooglePlayServicesAvailable` **trước** khi mở camera; thiếu
     thì hỏi người dùng thay vì lao vào quét.
   - Đổi `launchMode` nếu cần + lưu `pendingCaptureUri` qua
     `onSaveInstanceState` để không mất kết quả khi activity bị huỷ.
   - Xin quyền `CAMERA` đúng vòng đời, từ chối thì giải thích.
4. **i18n**: mọi chuỗi mới đủ `en/hi/zh/zh_TW/si`.
5. **Test**: thêm test thuần cho phần quyết định (vd "thiếu GMS ⇒ trả
   `OcrPrecheckResult.missingPlayServices`"), nối vào `app_analyze.yml` theo
   mẫu các bước test sẵn có (có `[ -f ]` guard).

## 5. Nghiệm thu

1. Máy có GMS đầy đủ: chụp → quét → ra chữ, không tắt app.
2. Máy/emulator **không** có GMS: hiện thông báo tiếng Việt rõ ràng, app sống.
3. Bật *Don't keep activities*: chụp → quay lại → vẫn ra chữ hoặc báo lỗi
   lịch sự, không crash.
4. Từ chối quyền camera: có giải thích, app sống.
5. `flutter analyze` 0 error + các bước test trong `app_analyze.yml` xanh.
6. Log `adb logcat` sạch (không còn `FATAL EXCEPTION`).
