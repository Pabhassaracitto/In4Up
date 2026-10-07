# ADR-0011: Dịch màn hình TOÀN HỆ THỐNG — lane native Android riêng, não dịch vẫn ở Dart

- **Ngày:** 2026-10-05
- **Trạng thái:** ĐÃ TRIỂN KHAI TRONG CODE (P1 Android), chờ CI + nghiệm thu
  thiết bị thật. Xem card `XLAT-SCR-002` trong `docs/project/KANBAN.md`.
- **Nhánh:** `arena/01a10bdd-in4up` (tách từ `arena/01a0251e-in4up` @ de9e00b,
  đã rebase lên tip `296eafc`). Kế hoạch: PLAN-036.
- **Phạm vi:** Android. iOS = KHÔNG LÀM (không có overlay toàn hệ thống).
  Desktop Linux/Windows = P2 (ghi nhận, chưa làm).

## Bối cảnh

- Lane **in-app** đã có trên `arena/01a0251e-in4up`: `ADR-0010 — dịch màn
  hình in-app trước`, card `XLAT-SCR-001` + `PDF-OCR-002`,
  `lib/features/pdf_reader/services/pdf_page_translate.dart`, panel
  `pdf_page_translate_panel.dart`. ADR này **không đụng** vào lane đó; nó mô
  tả lane **native** chạy song song, đúng tinh thần ADR-0010 ("system-wide là
  lane native RIÊNG").
  > Ghi chú lịch sử: nhánh `arena/01a10bdd-in4up` được tách ra từ `de9e00b`
  > — thời điểm đó ADR-0010/XLAT-SCR-001 CHƯA có trên lineage (ADR-0010 khi
  > ấy là *dictionary-cross-platform-import*). Toàn bộ code được viết độc
  > lập rồi **rebase lên tip 251e `296eafc`**: không một file code nào xung
  > đột, chỉ KANBAN/PLAN phải hợp nhất thủ công và PLAN-035 → **PLAN-036**.
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

---

## Bản sửa đổi 2026-10-07 — XLAT-SCR-003: "chạm bong bóng không có gì xảy ra"

> ADR là append-only: phần trên giữ nguyên, phần này BỔ SUNG và sửa lại mục 4,
> 5 và 12 của quyết định gốc. Agent `arena/92e02500-in4up`.

### Bối cảnh

Bản 0.10.3: bật bong bóng → chạm vào ⇒ không overlay, không toast, không lỗi.
Ba chặn đã biết của Android đều **im lặng**, nên không có log nào chỉ tay vào
chúng. Đọc code + đối chiếu tài liệu chính thức phát hiện thêm **hai** chặn
nữa (xem #4 và #5 bên dưới).

### Sửa quyết định 4 (consent MediaProjection)

**Cũ:** "`createScreenCaptureIntent` cần Activity ⇒ có
`ScreenCaptureRequestActivity` trong suốt" — nhưng activity đó được mở bằng
`startActivity` **từ foreground service**, và Android 10+ (API 29) chặn mở
activity từ nền: hệ thống BỎ QUA lệnh, log chỉ còn một dòng
`ActivityTaskManager: Background activity start ...`. Service không nằm trong
danh sách được miễn.

**Mới (2 đường, dùng cả hai):**

1. **Đường chính — xin consent khi app còn foreground.**
   `ScreenTranslatePlugin.start` (được gọi từ màn hình Cài đặt) khởi service
   rồi mở `ScreenCaptureRequestActivity` ngay. Khi ấy app đang hiện trên màn
   hình nên việc mở activity là hợp pháp, không vướng chặn nào. Hệ quả: lần
   chạm bong bóng đầu tiên đã có projection sẵn ⇒ có kết quả ngay.
2. **Đường dự phòng — PendingIntent có opt-in.**
   Khi consent bị mất giữa phiên (Android 14 thu hồi theo phiên, user bấm
   "Dừng chia sẻ", token đã dùng), `requestConsent()` gửi
   `PendingIntent.getActivity(...)` được tạo với
   `ActivityOptions.setPendingIntentBackgroundActivityStartMode(
   MODE_BACKGROUND_ACTIVITY_START_ALLOWED)` (API 34+) — opt-in theo đúng
   tài liệu "Behavior changes: apps targeting Android 14". Trước API 34,
   `PendingIntent.send()` vẫn là đường được phép.

**Watchdog (bắt buộc):** hệ thống vẫn CÓ THỂ chặn (màn hình khoá, ROM siết,
`appSwitchState`). Vì vậy activity báo ngược `ACTION_CONSENT_UI_SHOWN` khi
thực sự `onCreate`; nếu sau 2.5s service không nhận được tín hiệu, nó kết luận
"đã bị chặn" và hiện **thông báo heads-up có thể bấm** (khi user bấm thông báo,
hệ thống mới là bên gửi pending intent ⇒ được miễn chặn). Không có watchdog thì
bản sửa chỉ là "hy vọng là chạy".

### Sửa quyết định 5 (loại foreground service)

Giữ nguyên thứ tự và cả hai loại. Đã kiểm chứng bằng tài liệu chính thức
(*Foreground service types → Media projection*): runtime prerequisite là
`createScreenCaptureIntent()` phải được gọi TRƯỚC `startForeground`, và
`getMediaProjection()` chỉ được gọi SAU khi foreground service đã chạy. Thứ tự
hiện tại trong code (`consent → startForeground(type=mediaProjection) →
getMediaProjection → createVirtualDisplay`) đã đúng; giữ nguyên, không "tối
ưu". Kiểm tra chéo `compileSdk 36 / targetSdk 35 / minSdk 24`.

### Bổ sung: một phiên chụp = một VirtualDisplay (chặn #4, MỚI)

Tài liệu *Media projection*: "A session is a single call to
`createVirtualDisplay()`. A MediaProjection token must be used only once.";
Android 14 ném `SecurityException` nếu gọi `createVirtualDisplay()` quá một
lần trên cùng `MediaProjection`. Code cũ tạo rồi gỡ VirtualDisplay sau **mỗi**
lần bấm ⇒ lần bấm thứ hai trở đi hỏng trên Android 14.

**Quyết định:** tạo `ImageReader` + `VirtualDisplay` **MỘT LẦN cho cả phiên**
(khi vừa có consent), giữ ấm đến khi tắt; mỗi lần bấm chỉ gọi
`acquireLatestImage()` — lấy frame mới nhất, rồi đẩy sang Dart. Quyết định 3
("một lần bấm = một lần chụp") **không thay đổi**: Dart vẫn chỉ xử lý đúng một
frame mỗi lần bấm, không có vòng lặp capture. Đổi đổi lấy: tốn thêm một ít pin
và icon "đang truyền màn hình" của hệ thống hiện trong lúc bật bong bóng —
đánh đổi này minh bạch, và là cách duy nhất để bấm nhiều lần được trên
Android 14.

### Bổ sung: luật "không bao giờ im lặng" (chặn #5, MỚI)

Mọi nhánh thất bại của `onBubbleTapped()` PHẢI gọi `tellUser()` = **toast +
notification + rung nhẹ**, kèm bước tiếp theo cụ thể. Toast được ưu tiên vì
Android 13+ có thể chưa cấp `POST_NOTIFICATIONS` (app trước đây chưa bao giờ
xin quyền này ⇒ notification bị ẩn mà không ai báo). Thêm:

- Kênh thông báo riêng `in4up_screen_translate_alert` (IMPORTANCE_HIGH) cho các
  trường hợp "cần user thao tác".
- Bong bóng 2 trạng thái: xanh "文A" = sẵn sàng; cam "⚙" = **cần thiết lập**.
- `OnAttachStateChangeListener` trên bong bóng: hệ thống tự gỡ bong bóng khi
  quyền overlay bị thu hồi ⇒ phát hiện được và hướng dẫn mở đúng màn hình
  Cài đặt (trước đây chỉ có `printStackTrace()` rồi `stopEverything()`).

### Sửa quyết định 12 (i18n)

Nguyên tắc giữ nguyên. Riêng chuỗi của service: thêm 10 chuỗi, bản mặc định
trong `res/values` là **tiếng Anh** + `res/values-vi` tiếng Việt ⇒ máy locale
khác không bao giờ rơi về tiếng Việt (quy tắc vàng #5). Chuỗi chrome Dart: 5
chuỗi mới trong `priority_ui_overrides.dart` đủ en/hi/zh/zh_TW/si.

### Quyết định 13 (MỚI): quyền do DART quyết định, không phải Kotlin

Phần Kotlin **chưa có CI biên dịch** (xem card XLAT-SCR-002) nên mọi quyết
định "thiếu quyền gì / bước tiếp theo là gì" được đẩy sang Dart, nơi có máy
bắt:

- `lib/features/screen_translate/screen_translate_permission.dart` —
  `ScreenTranslatePermissionState` (unsupported / needsOverlayPermission /
  needsCaptureConsent / consentDenied / ready) +
  `ScreenTranslateNativeStatus` (đọc map của Kotlin, chịu kiểu lạ) +
  `ScreenTranslateRecoveryAction`. THUẦN DART, test được trên host VM.
- Kotlin chỉ trả dữ kiện qua `ScreenTranslatePlugin.status()` (9 khoá).
- Thẻ Cài đặt không tự đoán: đọc máy trạng thái rồi hiện đúng thông điệp + nút.

### Hệ quả / việc còn nợ

- Thêm quyền `VIBRATE`. `POST_NOTIFICATIONS` đã có trong manifest, nay được xin
  runtime từ Dart (`permission_handler`) trước khi bật bong bóng.
- CHƯA có bằng chứng logcat và CHƯA nghiệm thu thiết bị: sandbox không có
  adb/Android SDK/Flutter SDK. Script `scripts/qa/screen_translate_logcat.sh`
  đã viết sẵn để chủ dự án chạy trên máy thật (mục 3.1 của prompt).
