# ADR-0011: Dịch màn hình TOÀN HỆ THỐNG — lane native Android riêng, não dịch vẫn ở Dart

- **Ngày:** 2026-10-05
- **Trạng thái:** ĐÃ TRIỂN KHAI TRONG CODE (P1 Android), chờ CI + nghiệm thu
  thiết bị thật. Xem card `XLAT-SCR-002` trong `docs/project/KANBAN.md`.
- **Nhánh:** `arena/01a10bdd-in4up` (tách từ `arena/01a0251e-in4up` @ de9e00b).
- **Phạm vi:** Android. iOS = KHÔNG LÀM (không có overlay toàn hệ thống).
  Desktop Linux/Windows = P2 (ghi nhận, chưa làm).

## Bối cảnh

- Prompt giao việc nhắc tới "ADR-0010 — dịch màn hình in-app" và card
  `XLAT-SCR-001`. **Trên lineage này (251e @ de9e00b) hai thứ đó KHÔNG tồn
  tại**: `docs/adr/0010-*` là *dictionary-cross-platform-import*, và không có
  `lib/features/pdf_reader/services/pdf_page_translate.dart`. Đã kiểm tra
  bằng `git grep` + liệt kê `docs/adr/`, không chẩn đoán lại.
  ⇒ ADR này lấy số **0011** và tự mô tả kiến trúc; khi lane in-app được
  thâu hoạch về đây, hai lane vẫn độc lập đúng như tinh thần đã chốt
  ("system-wide là lane native RIÊNG, không đụng lane in-app").
- Hạ tầng sẵn có và PHẢI tái dùng:
  - `lib/features/ocr/ocr_service.dart` — ML Kit Text Recognition v2 (Latin),
    `recognizeBitmap(pixels: BGRA8888, …)`, timeout + cancel token (ADR-0009).
  - `lib/features/translation/translation_service.dart` — cache → glossary →
    ML Kit offline → online (DeepLX/Google/MyMemory/Libre/LLM-MT) → Hy-MT.
  - Chưa có pattern "engine Flutter chạy nền ngoài UI" (chỉ có `audio_service`
    giữ engine UI sống khi phát nhạc).

## Quyết định

1. **Chụp + vẽ ở NATIVE, hiểu chữ + dịch ở DART.** Native (Kotlin) lo
   bong bóng `SYSTEM_ALERT_WINDOW`, MediaProjection, ImageReader và lớp vẽ
   `TranslationOverlayView`. Dart lo OCR (ML Kit) + dịch (TranslationService)
   + quyết định hiển thị. **Không viết engine dịch thứ hai, không viết OCR
   thứ hai.**
2. **Engine Flutter NỀN riêng** cho service: `FlutterEngineGroup` +
   entrypoint `screenTranslateMain`
   (`lib/features/screen_translate/screen_translate_entrypoint.dart`).
   - Vì bong bóng phải sống khi app đã đóng khỏi màn hình gần đây.
   - Engine group chia sẻ snapshot ⇒ tốn thêm vài MB thay vì cả engine mới.
   - Hệ quả chấp nhận được: isolate riêng ⇒ Hive riêng; cache dịch nằm trên
     SharedPreferences nên VẪN dùng chung với app (tiêu chí nghiệm thu #3).
3. **Một lần bấm = một lần chụp.** Không vòng lặp capture trong P1; thêm
   debounce 1.5s (`CaptureGate`, đồng hồ bơm từ ngoài để test được). Bấm lần
   nữa khi đang hiện bản dịch = tắt overlay. Notification có action "Tắt".
4. **Consent MediaProjection xin lại mỗi phiên** (Android 14+ bắt buộc).
   `createScreenCaptureIntent` cần Activity ⇒ có `ScreenCaptureRequestActivity`
   trong suốt, `noHistory`, `excludeFromRecents`. KHÔNG lưu `resultData` để
   tái dùng cho phiên sau.
5. **Loại foreground service đổi theo giai đoạn:** chỉ-bong-bóng =
   `specialUse`; sau khi có consent mới nâng lên `mediaProjection` rồi mới gọi
   `getMediaProjection` (Android 14 chặn thứ tự ngược lại).
6. **Một hàm quy đổi toạ độ duy nhất** — `mapCaptureRectToOverlay` trong
   `screen_translate_geometry.dart` (scale X và Y TÁCH RIÊNG để lúc xoay màn
   hình không kéo lệch chữ). Native không được tự scale lần hai.
7. **Định dạng pixel xử lý ở Dart:** ImageReader trả RGBA_8888 có
   `rowStride` padding; Dart cắt padding rồi hoán R↔B thành BGRA mà
   `InputImage.fromBitmap` khai báo. Có unit test cho cả hai bước — đây là
   lớp lỗi "chỉ lộ trên thiết bị" nên phải có máy bắt từ sandbox.
8. **OCR mở rộng, không sửa cũ:** thêm `OcrService.recognizeBitmapBlocks()`
   trả `List<OcrBlock>` (text + bbox). `recognizeBitmap()` giữ nguyên vì PDF
   Reader đang dùng.
9. **Không tải model:** rơi vào nhánh offline thiếu model ⇒ trả status
   `missingModel` + `missingModelCodes`, native hiện thông báo rõ. Tuyệt đối
   không tự tải (luật vàng).
10. **Giới hạn 32 khối/lượt**, ưu tiên khối to + nhiều chữ, giữ thứ tự đọc —
    để không vượt mốc 3 giây và không đốt quota engine online.
11. **i18n:** chuỗi Dart đi qua `priority_ui_overrides.dart`
    (en/hi/zh/zh_TW/si); chuỗi của service nằm trong `res/values` với bản
    MẶC ĐỊNH TIẾNG ANH + `res/values-vi` tiếng Việt ⇒ máy locale khác không
    bao giờ rơi về tiếng Việt (quy tắc vàng #5).

## Hệ quả

- Thêm quyền: `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`,
  `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`. Quyền overlay user
  phải bật tay trong Settings — UI giải thích trước khi mở Settings.
- Có một đường "app chạy nền" mới: mọi thay đổi `TranslationService` phải
  nhớ nó còn được gọi từ isolate nền (không giả định có BuildContext/Provider).
- P2 (chưa làm, cần ADR riêng nếu làm): script OCR ngoài Latin (CJK cần
  dependency native khác), desktop (`maim`/`scrot` + Tesseract + cửa sổ
  trong suốt), capture liên tục theo vòng lặp.

## Bằng chứng / phần chờ nghiệm thu

- Test thuần Dart: `test/screen_translate/` (bbox, scale 2 mật độ, rowStride,
  hoán R/B, debounce, pipeline, giao thức channel, prefs).
- CHƯA chạy được `flutter analyze` / `flutter test` trong sandbox (không có
  Flutter SDK) và CHƯA build Android (không có Android SDK) — CI
  `app_analyze.yml` + nghiệm thu thiết bị theo mục 5 của card là cổng cuối.
