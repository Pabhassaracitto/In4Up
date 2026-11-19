# ADR-0035 — Bộ chạy Whisper trên desktop: app tự cài + chẩn đoán thiếu DLL

- **Trạng thái:** ✅ accepted (đã code, chờ CI + nghiệm thu máy Windows thật).
- **Nguồn:** owner (2026-11-15) báo lỗi thực tế trên bản `1.29.0-Beta`:
  1. `Exception: Lỗi: Bad state: Khong tim thay whisper binary: whisper-cli.exe`
     khi bấm "⚡ Tự tạo mục lục".
  2. Sau khi chép "4 file" binary đã tìm thấy nhưng chết với
     `whisper.exe thất bại (exit -1073741515)` và **STDOUT/STDERR rỗng**.
- **Phạm vi:** chỉ đường STT Whisper trên desktop. Không chạm `lib/ffi/`
  và `UltraTimeStretch` (khu vực audio realtime được bảo vệ).

## Bối cảnh

Trên Windows, engine Whisper đi theo 2 đường: FFI (`whisper.dll`) rồi CLI
(`whisper-cli.exe`). Cả hai đều **không** được đóng kèm trong bản phát hành.

- Đường FFI hỏng vì `_loadAudioAsPcm` là stub trả `[]` ⇒ `whisper_full` nhận 0
  mẫu ⇒ whisper.cpp trả lỗi khó hiểu.
- Đường CLI hỏng vì locator cũ chỉ dò cạnh `.exe`/`PATH`, và danh sách copy
  trong `windows/runner/CMakeLists.txt` **thiếu** `ggml-cpu-*.dll` + `SDL2.dll`.

Hai triệu chứng, một nguyên nhân gốc: **người dùng phải tự đoán file nào là đủ**.
Tài liệu cũ ghi "chép `whisper-cli.exe` + `ggml-*.dll`" (4 file) — thiếu
`whisper.dll` nên loader Windows chết trước `main()` và không in gì.

Đo được từ release `v1.9.2` (`release.yml` build với
`-DBUILD_SHARED_LIBS=ON -DWHISPER_SDL2=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON`):
bộ chạy cần **6 nhóm file** — `whisper-cli.exe`, `whisper.dll`, `ggml.dll`,
`ggml-base.dll`, một `ggml-cpu-<variant>.dll` (không có `ggml-cpu.dll` trơn),
`SDL2.dll`. Lưu ý `v1.9.3`+ **không** phát hành zip Windows ⇒ ghim `v1.9.2`.

## Quyết định

### D1 — App tự cài bộ chạy, không bắt người dùng chép tay

`WhisperRuntimeInstaller` tải `whisper-bin-x64.zip` (`v1.9.2`) vào
`documents/whisper_runtime/`, giải nén **phẳng** và **chỉ** lấy file của bộ chạy.
Lý do chọn `documents` thay vì cạnh `.exe`: thư mục cài đặt (`Program Files`)
thường không ghi được, và bản MSI sẽ xoá file lạ khi cập nhật.

An toàn: tải ra `.part` rồi `rename`; chặn zip-slip (`..`, ổ đĩa, tuyệt đối);
chuẩn hoá `\\`→`/` trước khi lấy basename (zip Windows); KHÔNG tự chạy — chỉ khi
người dùng bấm.

### D2 — Chẩn đoán bằng import table của PE, không đoán theo tên file

`utils/src/whisper_cli_runtime.dart` đọc `IMAGE_IMPORT_DESCRIPTOR` (20 byte) và
`IMAGE_DELAYLOAD_DESCRIPTOR` (**32 byte**, attributes ở `+0`, bit 0 = `dlattrRva`)
rồi so với file cùng thư mục. Kết quả `WhisperBinaryProbe` nêu **đúng tên file
thiếu**, file `0 byte`, và lệch 32/64-bit.

Hàm thuần ⇒ CI test được trên Linux bằng PE dựng tay; không cần Windows.

### D3 — `isRunnable` là "chạy được", không phải "không thấy thiếu"

`scanned == false` (file hỏng/rỗng) và `machineMismatch` không rỗng đều trả
`isRunnable == false`. Trước đây cả hai đều lọt ⇒ installer đăng ký một bộ chạy
chết rồi người dùng lại gặp `-1073741515`.

### D4 — Một registry để app bơm đường dẫn vào package

`in4up_stt` không phụ thuộc `path_provider`/`StorageService`. App dùng
`WhisperRuntimeRegistry.register(...)` + setting `whisper_runtime_path`
(`WhisperRuntimeBootstrap`) để báo "bộ chạy nằm ở đây". Locator thử theo thứ tự:
app đã cài → `WHISPER_PATH`/`WHISPER_CPP_PATH`/`WHISPER_BIN` → cạnh `.exe` →
`windows/libs` (chạy từ source) → `PATH` → vị trí cài phổ biến.

`dllDirs` rỗng **không** xoá danh sách đã đăng ký: `init()` chạy sau
`rememberInstalled` từng làm mất thư mục DLL.

### D5 — Đóng gói: copy CẢ bộ, không liệt kê tay

`windows/runner/CMakeLists.txt` + `windows/CMakeLists.txt` glob `libs/**/*.dll`
và `*.exe` (cả `libs/` lẫn `libs/whisper/`) rồi copy cạnh `in4up.exe` ở POST_BUILD
(cho `flutter run`) và trong bước `install` (cho MSI/NSIS). Danh sách tay cũ
chính là thứ đã thiếu `ggml-cpu-*`/`SDL2`.

CI `build.yml` **thôi** tạo `windows/libs/{ggml,whisper}.dll` rỗng: file 0 byte bị
Windows coi như không có *và* che mất DLL thật người dùng chép vào sau.

### D6 — UI: thẻ "Bộ chạy Whisper" trong Quản lý Model AI

Hiện trạng thái (đủ file / thiếu file / chưa có), đường dẫn binary, danh sách
file thiếu, nút **Kiểm tra lại**, **Cài bộ chạy**, và hộp thoại **Cách khác**
(mô tả đủ 6 file + giải thích `-1073741515`). Chỉ desktop (Android/iOS dùng
plugin). Mọi chuỗi đi qua `context.uiText` và đã có bản dịch 8 locale.

## Hệ quả

- Người dùng Windows không cần `setx WHISPER_PATH`, không cần chép tay; nếu
  vẫn chép tay thì câu báo lỗi nói đúng file còn thiếu.
- Lỗi mới phải diễn đạt được bằng *dữ liệu* (tên file, cờ bitness) để test được
  ở tầng thuần.
- Chưa làm: FFI PCM loader thật (`_whisperPcmLoader` vẫn `null` ⇒ đi CLI);
  kiểm tra DLL phụ thuộc bậc 2; Linux/macOS tự cài (dùng trình quản lý gói).
- **Nghiệm thu cần máy Windows thật**: bấm Cài → chạy "Tự tạo mục lục" trên
  file ~2 phút; kiểm cả trường hợp mạng đứt giữa chừng.
