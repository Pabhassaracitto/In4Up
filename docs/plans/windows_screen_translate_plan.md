# Kế hoạch dịch màn hình toàn hệ thống trên Windows

- **Ngày:** 2026-10-20
- **Trạng thái:** 📋 proposed — phạm vi và tiêu chí nghiệm thu đã ghi; chưa có
  Windows capture/overlay code, chưa build native, chưa chạy trên Windows.
- **Liên quan:** XLAT-SCR-002 / ADR-0011 (lane Android), PLAN-036.
- **Yêu cầu:** chụp và dịch toàn bộ một màn hình; cho người dùng kéo chọn một
  khung/vùng rồi chỉ dịch vùng đó.

## 1. Phạm vi và nguyên tắc

Đây là lane Windows của **System-wide Screen Translator**, không thay thế lane
in-app PDF (`XLAT-SCR-001`) và không thay đổi Android. Dịch màn hình phải là
thao tác do người dùng khởi tạo; không chụp nền liên tục, không lưu ảnh chụp
sau khi OCR xong, và không tự gửi ảnh tới dịch vụ mạng. Chỉ gửi văn bản OCR
qua engine dịch mà người dùng đã chọn.

Tái dùng Dart models, điều phối, giới hạn khối, cache, cài đặt ngôn ngữ và
`TranslationService` trong `lib/features/screen_translate/`. Không gọi
`OcrService` ML Kit hiện tại trên Windows: module đó tuyên bố desktop không hỗ
trợ. Thêm một giao diện OCR theo capability và một Windows OCR adapter; không
fork pipeline dịch.

## 2. Luồng người dùng

### A. Dịch toàn màn hình

1. Người dùng mở **Dịch màn hình** trong app hoặc kích hoạt một lệnh/hotkey
   do app công bố rõ ràng.
2. Người dùng chọn màn hình cần chụp qua picker hệ thống Windows; không chụp
   monitor ngầm khi chưa có hành động/picker của người dùng.
3. App lấy một frame tĩnh, OCR các khối chữ, dịch qua engine hiện hành, rồi
   vẽ các kết quả thành overlay trên màn hình vừa chụp.
4. Người dùng đóng overlay hoặc bấm **Chụp lại** để lấy frame mới. Mỗi lần
   chụp là một yêu cầu riêng; không có polling/capture loop.

### B. Kéo chọn vùng

1. Người dùng chọn **Chọn vùng**.
2. Hiện lớp chọn vùng trong suốt, viền rõ, trên màn hình/màn hình đã chọn.
   Người dùng kéo chuột để tạo hình chữ nhật; `Esc` huỷ, `Enter` xác nhận.
3. Ẩn lớp chọn trước khi chụp nội dung, chụp/crop theo hình chữ nhật vật lý
   đã chọn, OCR và dịch các khối nằm trong vùng.
4. Hiển thị overlay bản dịch được crop/đổi toạ độ về đúng vị trí gốc. Có nút
   đóng/xoá kết quả; không chụp overlay của chính app thành đầu vào.

## 3. Kiến trúc đề xuất

### 3.1 Capture + giao tiếp native

- Thêm Windows implementation cho channel `in4up/screentranslate` trong
  `windows/runner` hoặc plugin Windows riêng. Giữ Android implementation
  tách biệt; dùng payload chung `ScreenCaptureFrame` và
  `ScreenTranslateResult` khi hợp đồng đã phù hợp.
- Spike trước khi chốt API: `Windows.Graphics.Capture` / Win32 interop cho
  capture màn hình, lựa chọn monitor, quyền/consent, minimum Windows version,
  DPI và packaging C++/WinRT. Không âm thầm chụp bằng `BitBlt` nếu WGC bị từ
  chối. Ghi quyết định fallback trong ADR trước khi triển khai.
- Native trả kích thước frame, monitor identity, tọa độ gốc trong virtual
  desktop (có thể âm), DPI scale và pixel format tường minh. Crop vùng ở phía
  native hoặc Dart nhưng chỉ có **một** nơi chịu trách nhiệm đổi hệ tọa độ.
- Dùng bitmap bộ nhớ; tránh tạo ảnh tạm ra đĩa. Giải phóng frame/texture ngay
  sau OCR hoặc khi người dùng huỷ.

### 3.2 OCR Windows

- Tạo seam như `ScreenTranslateOcr`/`OcrBlocksRecognizer`: Android nối
  `OcrService.recognizeBitmapBlocks()`; Windows dùng adapter native có kết quả
  text + bounding boxes.
- Phase 0 phải so sánh Windows OCR API có sẵn với Tesseract đóng gói cùng app:
  chất lượng tiếng Anh/Việt có dấu, hỗ trợ offline, dung lượng, giấy phép,
  khả năng phát hành model/ngôn ngữ và cách trả bounding boxes. Chọn một, ghi
  ADR; chưa chọn thì không giả vờ ML Kit hỗ trợ desktop.
- Bản đầu giới hạn Latin (EN/VI/Pāḷi Roman), cùng giới hạn hiện tại của OCR.
  Thiếu gói/ngôn ngữ phải trả lỗi capability rõ và chỉ dẫn, không tải model tự
  động.

### 3.3 Dart OCR → dịch → overlay

- Thay platform gate của thẻ hiện chỉ ghi “Chỉ Android” bằng trạng thái
  capability theo platform. Dùng chung `ScreenTranslateController` sau khi
  tách nhận frame/OCR khỏi Android `MethodChannel`.
- Tái dùng `TranslationService`, lựa chọn engine đích/nguồn, cache, giới hạn
  khối và trạng thái lỗi hiện có. Chỉ văn bản OCR (không ảnh) đi vào engine
  dịch.
- Overlay kết quả là cửa sổ Windows trong suốt, topmost, không nhận click
  ngoài các nút đóng/chụp lại. Trước mọi lần capture phải ẩn overlay và lớp
  chọn; trên Windows hỗ trợ thì thêm capture-exclusion affinity, nhưng vẫn giữ
  bước ẩn làm bảo đảm chính.
- Giữ nguyên phép đổi toạ độ chung hoặc tạo một helper duy nhất cho Windows;
  không để cả native và Dart cùng scale. Quy đổi phải xử lý monitor có DPI
  khác nhau, virtual desktop origin âm, scaling 100/125/150/200% và crop.

### 3.4 Privacy, lỗi và khả năng truy cập

- Capture chỉ bắt đầu sau thao tác/picker của người dùng; có trạng thái rõ
  “đang chọn vùng/chụp/đang OCR/đang dịch”. Không lưu frame hoặc ghi frame vào
  log. Lỗi quyền, monitor không hỗ trợ, OCR thiếu capability, vùng quá nhỏ,
  timeout và lỗi dịch đều báo được và cho thử lại.
- Overlay có nút đóng, phím `Esc`, hỗ trợ bàn phím, tương phản đủ cao; không
  chiếm chuột ngoài vùng điều khiển.
- Không capture nội dung bị Windows/app bảo vệ nếu API trả frame đen hoặc từ
  chối; báo giới hạn bình thường, không lách bảo vệ.

## 4. Các giai đoạn

### W0 — Spike + ADR (chặn trước code)

- Xác định Windows minimum version, C++/WinRT interop từ Flutter Windows,
  picker màn hình, capture frame, DPI/virtual desktop, overlay trên nhiều
  monitor, capture exclusion và OCR adapter.
- Thử trên Windows 10/11 thật với một ứng dụng thường và một cửa sổ có quyền
  cao/protected; ghi rõ trường hợp không chụp được.
- Chốt backend capture, backend OCR, cách đóng gói dependency, channel methods
  và data contract trong ADR bổ sung cho ADR-0011.

### W1 — Capture toàn màn hình + hợp đồng Dart

- Native: liệt kê/chọn display qua picker, chụp một frame, trả dimensions,
  pixel format, origin và DPI metadata; xử lý cancel/error.
- Dart: platform capability, channel adapter, frame model và test protocol/
  pixel/geometry. Không bật overlay dịch khi chưa có OCR Windows.

### W2 — Chọn vùng + hình học đa màn hình

- Native: borderless selection layer, mouse drag, `Esc`/`Enter`, hiển thị
  rectangle; chụp/crop sau khi lớp chọn đã ẩn.
- Dart/native tests: rectangle rỗng/ngoài màn hình, crop clipping, scaling
  hỗn hợp, origin âm, monitor đổi DPI, overlay exclusion.

### W3 — OCR + dịch + overlay

- Cắm OCR adapter đã chọn vào cùng luồng controller; giới hạn số khối như
  Android, dịch qua engine được cấu hình và dùng cache.
- Vẽ/đóng overlay native; hỗ trợ chụp lại và xoá kết quả. Kiểm tra overlay
  không xuất hiện trong OCR ở lần chụp thứ hai.

### W4 — CI, phát hành và nghiệm thu

- Windows CI compile runner/plugin ở cả debug và release, xác nhận DLL/dependency
  native được đặt cạnh executable và package archive chứa đủ file.
- Có smoke test trên Windows 10 và 11; CI compile không thay thế được test
  capture/overlay thực trên desktop có nhiều màn hình.
- Cập nhật card XLAT-SCR-WIN-001 bằng commit, CI run, model/OCR limitation và
  bằng chứng nghiệm thu; không ghi “done” chỉ từ test thuần.

## 5. Tiêu chí nghiệm thu

1. **Toàn màn hình:** người dùng chọn một display; app dịch khối chữ trên
   display đó, không chụp display khác ngoài lựa chọn.
2. **Vùng kéo chọn:** kéo khung bất kỳ trên display, xác nhận thì chỉ vùng đó
   được OCR/dịch; `Esc` huỷ mà không hiện kết quả.
3. **Hình học:** overlay khớp bounding boxes ở scaling 100%, 125%, 150% và
   200%, một monitor và hai monitor có DPI khác nhau, gồm monitor có origin
   âm.
4. **Không tự chụp overlay:** bản dịch/lớp chọn không bị OCR trong frame hiện
   tại hoặc lần chụp kế tiếp; đóng overlay dọn toàn bộ view/frame.
5. **Engine và lỗi:** dùng engine/ngôn ngữ đang chọn, tôn trọng offline/online
   routing, cache và cancel; báo đúng lỗi khi OCR/engine/model không khả dụng.
6. **Privacy:** không có capture loop, không lưu frame, không upload ảnh; người
   dùng chủ động từng lần chụp và có thể huỷ.
7. **Build:** Windows debug + release build xanh, native dependency được đóng
   gói, app khởi chạy được khi mở thư mục phát hành trên một máy Windows sạch.

## 6. Rủi ro / quyết định còn mở

- API capture và OCR backend phải được kiểm chứng trên Windows 10/11 trước khi
  cam kết minimum OS hoặc dung lượng phát hành.
- Không giả định `GraphicsCapturePicker` có thể chọn toàn bộ monitor theo cùng
  cách trên mọi build Windows; W0 xác minh API/interop cụ thể.
- Tọa độ Flutter logical, native physical pixels và virtual desktop không đồng
  nhất; test helper hình học trước khi nối overlay.
- Native DLL, OCR language data và Visual C++ runtime cần được đóng gói/kiểm
  tra trong artifact, không phụ thuộc môi trường dev.
- Protected content, desktop UAC secure desktop và một số cửa sổ elevated có
  thể không capture được; thông báo giới hạn, không tìm cách vượt qua.
