# Prompt giao việc — Dịch màn hình TOÀN HỆ THỐNG, các mảnh còn lại (XLAT-SCR-002 P1-nghiệm-thu → P2)

> Nguồn: tiếp nối `PROMPT_AGENT_DICH_MAN_HINH.md` (owner) và phần đã thi công
> trên nhánh `arena/01a10bdd-in4up`. Nền kiến trúc: **ADR-0011** (lane native
> Android) chạy song song **ADR-0010** (lane in-app, `XLAT-SCR-001`). Card:
> `XLAT-SCR-002` trong `docs/project/KANBAN.md`. Kế hoạch: **PLAN-036**.
>
> Mảnh đã xong (P1, code đầy đủ, CI logic thuần xanh, **chưa chạy trên máy
> thật, chưa có CI nào biên dịch Kotlin**): bong bóng SYSTEM_ALERT_WINDOW →
> MediaProjection → ImageReader → MethodChannel `in4up/screentranslate` →
> OCR Dart (ML Kit Latin) → `TranslationService` → overlay vẽ bản dịch.

---

## 0. Luật chung (đọc trước khi code)

1. **Đọc trước:** `AGENTS.md` (5 quy tắc vàng), `docs/GOVERNANCE.md`,
   `docs/adr/0011-dich-man-hinh-toan-he-thong-lane-native.md`,
   `docs/adr/0010-*` (lane in-app), card `XLAT-SCR-001` + `XLAT-SCR-002`.
2. **Branch:** trong Arena Agent Mode chỉ làm trên branch session được cấp;
   ngoài phiên thì topic branch tách từ tip mới nhất của
   `arena/01a0251e-in4up` (fetch đúng refspec — GOVERNANCE mục 2a).
3. **Rule #5 i18n:** nhãn chrome Dart mới ⇒ `context.uiText('…')` + key +
   en/hi/zh/zh_TW/si trong `lib/core/language/priority_ui_overrides.dart`.
   **KHÔNG chạy `tool/generate_arbs.py` / `generate_arbs.py`.** Chuỗi Android
   native nằm ở `android/app/src/main/res/values/strings_screen_translate.xml`
   (mặc định tiếng Anh) + `values-vi/` — thêm chuỗi mới phải thêm cả hai.
4. **Không để đỏ:** sandbox không có Flutter SDK ⇒ push sớm, CI
   `.github/workflows/app_analyze.yml` là oracle (analyze 0 ERROR + các batch
   test). Nói rõ cái gì *đã chạy* và cái gì *chờ CI/máy thật* — không bịa.
5. **Không đụng** vùng bảo vệ: UltraTimeStretch FFI, 3 skill SM-2,
   reopen-at-source, lane in-app `pdf_page_translate.dart`.
6. Commit nhỏ, push ngay (push = backup). Release Android dùng
   `--flavor stable`. Ghim `google_mlkit_text_recognition` 0.16.x và
   `google_mlkit_document_scanner` 0.5.x (CI = Flutter 3.44.1 / Dart 3.11.5).

## 1. Bản đồ code đã có (đọc cái này thay vì dò mù)

**Dart — `lib/features/screen_translate/`**

| File | Vai trò |
| --- | --- |
| `screen_translate_models.dart` | `ScreenCaptureFrame`, `ScreenTextBlock`, `ScreenTranslateResult` + JSON hai chiều với native |
| `screen_translate_geometry.dart` | `mapCaptureRectToOverlay` (hàm quy đổi toạ độ **duy nhất**), `pixelsToDp` |
| `screen_translate_channel.dart` | MethodChannel `in4up/screentranslate`, tên method + hằng |
| `screen_translate_controller.dart` | Điều phối: RGBA→BGRA, OCR, dịch theo block, `CaptureGate` debounce 1.5s |
| `screen_translate_entrypoint.dart` | `@pragma('vm:entry-point') screenTranslateMain` cho FlutterEngineGroup |
| `screen_translate_prefs.dart` | Bật/tắt, ngôn ngữ nguồn/đích dùng chung SharedPreferences với app |
| `screen_translate_card.dart` | Thẻ UI trong màn "Quản lý Model AI" (ẩn/`Chỉ Android` trên desktop) |

**Kotlin — `android/app/src/main/kotlin/com/in4up/screentranslate/`**:
`ScreenTranslateService.kt` (foreground service + bong bóng + ImageReader),
`ScreenCaptureRequestActivity.kt` (xin consent, trong suốt, `noHistory`),
`ScreenTranslatePlugin.kt` (cầu MethodChannel), `TranslationOverlayView.kt`
(vẽ bản dịch đè lên từng block).

**Test thuần (đang chạy trên CI, step “Screen translate tests — XLAT-SCR-002”)**:
`test/screen_translate/{ocr_block,screen_translate_geometry,screen_translate_controller,screen_translate_prefs,screen_translate_protocol}_test.dart`
— gồm test hoán kênh ARGB↔BGRA và test quy đổi toạ độ khi xoay màn hình.

## 2. Việc còn lại — làm theo thứ tự

### 2.1 (CHẶN) Biên dịch Kotlin thật + nghiệm thu thiết bị

Hiện **không workflow nào biên dịch `android/`**: `build.yml` /
`build_final_complete*.yml` chỉ chạy khi push tag `v*` hoặc dispatch tay, và
`app_analyze.yml` lọc path loại trừ `android/**`. Việc cần làm:

1. Thêm job CI nhẹ, chỉ chạy khi `android/**` hoặc `pubspec.yaml` đổi:
   `flutter build apk --flavor stable --debug --target-platform android-arm64`
   (hoặc tối thiểu `./gradlew :app:compileStableDebugKotlin`). Mục tiêu là có
   **máy bắt lỗi Kotlin**, không phải ra artifact.
2. Chạy 7 tiêu chí nghiệm thu trong card `XLAT-SCR-002` trên máy Android thật
   (bong bóng đè mọi app; trang web tiếng Anh dịch ≤3s, overlay đúng vị trí kể
   cả landscape; dùng đúng engine đã chọn trong cài đặt dịch + lần 2 trúng
   cache; tắt là sạch overlay + notification + tiến trình nền; Android 14 xin
   lại consent; desktop không vỡ; analyze 0 error + test locale xanh).
3. Mọi lỗi phát hiện trên máy ⇒ sửa + ghi dòng lịch sử vào card (append-only,
   `- YYYY-MM-DD | HH:MM UTC | from→to | who | evidence`).

### 2.2 P1+ — các điểm đã biết là thô, chờ dữ liệu thật

- **Cỡ chữ / xuống dòng trong overlay**: hiện auto-fit theo chiều cao block;
  với câu dài tiếng Việt có thể tràn. Cân nhắc rút gọn + chạm để xem đầy đủ.
- **Chạm vào một block để xem bản gốc / copy text** (chưa có).
- **Vùng chọn (drag-select)**: chỉ dịch vùng người dùng khoanh thay vì cả màn.
- **Chế độ dịch lại tự động** khi nội dung màn hình đổi (vòng lặp capture) —
  ADR-0011 cố ý chốt “một lần bấm = một lần chụp” cho P1; mở vòng lặp phải
  kèm đánh giá pin/nhiệt và cập nhật ADR.
- **Proguard**: `isMinifyEnabled = false` hiện tại ⇒ chưa lộ lỗi; khi bật
  minify phải giữ `-keep` cho plugin + entrypoint Dart.

### 2.3 P2 — chữ không-Latin (CJK)

OCR hiện cứng `TextRecognitionScript.latin`. Thêm Chinese/Japanese/Korean
đòi thêm dependency ML Kit riêng (tăng APK) và chọn script theo ngôn ngữ
nguồn ⇒ **cần ADR riêng** (số kế tiếp còn trống), đừng lén thêm.

### 2.4 P2 — desktop Linux / Windows

iOS = **không làm** (không có overlay toàn hệ thống). Desktop: chụp bằng
`maim`/`scrot` (Linux) hoặc API Windows, OCR bằng Tesseract (ML Kit không có
desktop), vẽ bằng cửa sổ trong suốt always-on-top. Tái dùng nguyên
`screen_translate_geometry.dart` + `TranslationService`; chỉ thay lớp chụp và
lớp vẽ. Ghi ADR bổ sung khi bắt đầu.

## 3. Bàn giao

- Cập nhật card `XLAT-SCR-002` (status-only, append-only) + PLAN-036.
- PR vào `arena/01a0251e-in4up`, mô tả nêu rõ: cái gì CI xanh, cái gì đã thử
  trên máy thật, cái gì vẫn chưa có máy bắt.
