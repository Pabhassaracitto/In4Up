# ADR-0012: Lớp an toàn cho máy quét tài liệu (precheck GMS + trọng tài phiên quét + crash shield)

- **Ngày:** 2026-10-07
- **Trạng thái:** ĐÃ TRIỂN KHAI TRONG CODE (Android + Dart) + **CI 🟢** (run
  `37653016584` @ `469522f`: analyze 0 error, 2 file test thuần chạy thật —
  artifact `app-ocr-scan-test-log`). **Còn chờ máy thật**: vết crash `adb logcat`
  và 4/6 tiêu chí nghiệm thu của card `OCR-SCAN-CRASH-001` phải chạy trên thiết
  bị — sandbox không có adb/thiết bị.
- **Nhánh:** `arena/b07d7c38-in4up` (session audit 2026-10-07, mục 1.i).
- **Card:** `OCR-SCAN-CRASH-001` trong `docs/project/KANBAN.md`.
- **Phạm vi:** Android (lane "Quét ảnh ▸ Chụp & quét tài liệu" — ADR-0009/OCR-001).
  iOS/desktop không đổi (không có Document Scanner).

## Bối cảnh

Triệu chứng owner báo ở bản 0.10.3: Thư viện đọc ▸ Quét ảnh ▸ "Chụp & quét tài
liệu" ⇒ **app tắt ngay**, không toast/dialog/màn hình lỗi.

Đã loại trừ từ trước: lớp Dart đã bọc try/catch quanh toàn bộ đường quét, nên
`PlatformException`/lỗi ML Kit sẽ hiện snackbar chứ không thể làm app biến mất.
⇒ Chỗ chết nằm ở tầng native, **hoặc** tiến trình bị hệ thống giết.

Đọc source tại đúng commit release `f29f844` (= `google_mlkit_document_scanner`
0.5.0, bản đang pin) cho thấy ba lỗ hổng cụ thể:

1. `GmsDocumentScanning.getClient(options)` / `getStartScanIntent(activity)`
   được gọi **không** bọc try/catch trên luồng platform. Document Scanner là
   thư viện *unbundled*: model + logic + UI nằm trong **Google Play services**
   (tài liệu ML Kit: tải động, cần API 21+, **tối thiểu 1,7 GB RAM**, nếu thấp
   hơn API trả `MlKitException` mã `UNSUPPORTED`). Máy thiếu/tắt Play services
   ⇒ lỗi ném ở luồng chính ⇒ tiến trình chết, Dart không có cơ hội bắt.
2. Plugin giữ **đúng một** ô `pendingResult` và chỉ trả lời Dart trong
   `onActivityResult`. Activity bị huỷ giữa lúc máy quét mở (ít RAM / "Don't
   keep activities") ⇒ instance mới không có `pendingResult` ⇒ `scanDocument()`
   không bao giờ hoàn tất (treo im lặng), và không có đường báo cho UI.
3. Lỗi thô của plugin (`"Operation cancelled"`, `"Failed to start document
   scanner"`, `"Invalid options"`, `"Unknown Error"`) đều rơi vào **một**
   snackbar `Lỗi: …` đỏ — không phân biệt "người dùng bấm Back" với "Play
   services không mở nổi máy quét".

Bối cảnh kỹ thuật liên quan:

- `google_mlkit_text_recognition` 0.16.0 dùng bản **bundled**
  (`com.google.mlkit:text-recognition:16.0.1`) — nhận dạng chữ KHÔNG cần Play
  services. Chỉ **máy quét tài liệu** mới là unbundled ⇒ phải kiểm tra riêng.
- App **không** xin quyền `CAMERA`: máy quét dùng camera của Play services
  (không phải ACTION_IMAGE_CAPTURE của app). Vì vậy "từ chối quyền camera"
  không phải nguyên nhân của card này; ghi lại để agent sau không đi sai đường.

## Quyết định

1. **Quyết định trước khi mở máy quét** — `OcrPrecheck.decide()` (thuần Dart,
   `lib/features/ocr/ocr_precheck.dart`) dựa trên dữ liệu thô lấy từ native
   (`probeCapabilities`, kênh `in4up/ocr` do `MainActivity` đăng ký):
   - thiếu/tắt Google Play services ⇒ `missingPlayServices` — **không** đi vào
     đường native, hiện thông báo tiếng Việt + hành động "Mở Google Play
     services" (Play Store `com.google.android.gms`).
   - RAM < 1,7 GB ⇒ `lowRam` — chặn trước (Google đã nói API trả `UNSUPPORTED`).
   - RAM/phiên bản không đo được ⇒ **vẫn cho thử** (không chặn oan); lỗi thật
     đi qua nhánh 3.
   - `<queries><package android:name="com.google.android.gms"/></queries>` được
     khai trong manifest để Android 11+ cho phép truy vấn gói này (nếu thiếu,
     `PackageManager` ném `NameNotFoundException` oan).
2. **Trọng tài phiên quét** — `watchOcrScan()` (`ocr_scan_guard.dart`) chạy đua
   giữa lời gọi `scanDocument()` và nhịp hỏi `pollScanSignal` (mặc định 800 ms):
   - Dart báo native `beginScanSession`/`endScanSession`; `MainActivity` lưu cờ
     "đang có phiên quét" vào `onSaveInstanceState` ⇒ instance mới biết phiên
     bị hệ thống cắt ngang mà trả `interrupted` (thay vì treo vô hạn).
   - Tín hiệu `nativeCrash` (do crash shield đẩy lên) cũng kết thúc phiên.
   - Kết cục được mô hình hoá: `OcrScanStatus.{completed,cancelled,interrupted,
     nativeCrash,failed}` + câu giải thích (chuỗi nguồn tiếng Việt có trong
     catalog i18n).
3. **Crash shield có mục tiêu** — `MainActivity` cài
   `Thread.setDefaultUncaughtExceptionHandler` **một lần cho cả tiến trình**:
   - **Luôn** ghi vết đầy đủ ra tệp chẩn đoán
     (`getExternalFilesDir(null)/in4up_diagnostics/ocr-crash-<ts>.log`) — đây là
     "logcat tại chỗ" cho owner dán vào KANBAN khi không có adb.
   - **Chỉ** khi stack trace khớp dấu vết ML Kit/GMS scanner
     (`com.google_mlkit_document_scanner`, `mlkit_vision_document_scanner`,
     `GmsDocumentScanning`, `com.google.mlkit.vision.documentscanner`) thì mới
     nuốt exception để giữ app sống + báo Dart (`onOcrNativeCrash`). Mọi
     exception khác vẫn đi theo handler cũ ⇒ **không che giấu bug ngoài lane**.
4. **Không xin quyền CAMERA**, không đổi `launchMode`: không có bằng chứng nào
   chỉ vào hai đường đó, và mỗi thay đổi như vậy đều có giá (quyền thừa, hành
   vi back-stack). Ghi lại trong KANBAN để lần sau khỏi thử lại.
5. **Giữ nguyên API Dart đã có** cho các lane khác: `recognizeFile`,
   `recognizeBitmap`, `recognizeBitmapBlocks`, `normalizeOcrText` không đổi.
   `scanDocumentPages` đổi kiểu trả về `List<String>?` → `OcrScanOutcome`
   (chỉ `ocr_flow.dart` gọi nó; `UnsupportedError` trên nền tảng không có
   scanner vẫn giữ nguyên).

## Hệ quả

- Máy không có GMS: **không còn** đường nào dẫn vào `getStartScanIntent` ⇒
  không còn khả năng app biến mất vì lý do đó; người dùng nhận câu giải thích
  + nút mở Play services, và vẫn còn nguồn "Chọn ảnh có sẵn".
- Activity bị huỷ giữa phiên: UI báo "phiên quét bị cắt ngang" thay vì đứng im.
- Crash native bất ngờ ở lane quét: app sống, có tệp vết lỗi để chẩn đoán, và
  UI nói rõ đã ghi vết. Đổi lại: một số crash thật của lane này không còn làm
  chết tiến trình — chấp nhận có chủ đích, đổi lại phải theo dõi tệp chẩn đoán.
- Trên bản cài cũ (chưa có kênh `in4up/ocr`), `probeCapabilities` trả null ⇒
  coi như "có GMS" và để đường lỗi Dart xử lý — hành vi xấu nhất bằng bản cũ.
- **Chưa xác nhận bằng logcat thiết bị.** Giả thuyết 1/2/3 đã được chặn ở mức
  thiết kế + có máy bắt CI cho phần quyết định, nhưng nguyên nhân GỐC vẫn phải
  đối chiếu `crash.log` trên máy thật (card `OCR-SCAN-CRASH-001` giữ nguyên
  trạng thái chờ nghiệm thu). Nếu logcat cho thấy nguyên nhân khác, ADR này
  không chặn việc sửa đúng gốc — nó chỉ bảo đảm app không chết trên đường đã biết.
