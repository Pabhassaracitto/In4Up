# ADR-0028 — Đưa engine native VieNeu-TTS vào bản cài: pin audio.cpp + SEA-G2P, model vẫn do người dùng nhập

- **Ngày:** 2026-11-12
- **Trạng thái:** accepted (owner quyết 2026-11-12: *"Tôi muốn VieNeu thực sự hoạt động"*)
- **Liên quan:** `TTS-VIENEU-001`, `TTS-VIENEU-SHIP-001`, `PSRC-187`, `PSRC-214…218`, `BETA-1.29.0` lane L6

## 1. Bối cảnh — vì sao "engine đã tích hợp" mà chưa từng đọc được

Từ ticket `TTS-VIENEU-001`, app có: wrapper C (`native/tts_vieneu/`), CMake Android
(`android/app/src/main/cpp/ai/CMakeLists.txt`), lõi Dart + worker isolate
(`packages/in4up_stt/lib/tts/vieneu_tts_core.dart`), engine + UI cài đặt. **Chưa bản
cài nào có `libvieneu_tts.so`.** Ba lỗ hổng độc lập, mỗi cái đủ để engine không chạy:

1. **Không có mã nguồn audio.cpp.** `.gitmodules` khai `third_party/audio.cpp` nhưng
   **gitlink chưa từng được commit** ⇒ `git submodule update -- third_party/audio.cpp`
   báo `pathspec did not match`, CI nuốt bằng `|| true`, CMake in *"vieneu_tts BỎ QUA"*
   và APK không có `.so`.
2. **Thiếu bộ chuyển văn bản → âm vị (SEA-G2P).** Theo tài liệu upstream, VieNeu v3 Turbo
   nhận **chuỗi phoneme SEA-G2P**, không nhận chữ thô. Thiếu `libsea_g2p_rs.so` +
   `sea_g2p.bin` thì hoặc lỗi, hoặc đọc ra vô nghĩa. Bản phát hành sea-g2p trên GitHub
   **không có** `.so` cho Android ⇒ phải cross-compile.
3. **Hợp đồng âm thanh sai.** VieNeu phát **48 kHz stereo**; Dart FFI của app khai
   **mono float32** và wrapper `memcpy` đúng `frames` mẫu ⇒ mất nửa dữ liệu và phát
   nhanh gấp đôi. Lỗi này chỉ lộ khi engine thật sự chạy, nên chưa ai thấy.

## 2. Quyết định

Đưa **engine** vào bản cài; **model và từ điển vẫn do người dùng nhập/tải** (không nhúng
188 MB GGUF vào APK — giữ nguyên chính sách "không bundle model" của dự án).

| Mảnh | Đóng gói | Pin |
|---|---|---|
| audio.cpp (ggml + C ABI + `vieneu_v3_turbo`) | **submodule** `third_party/audio.cpp`; **module Gradle riêng `:vieneu`** (`android/vieneu/`), CMake CPU-only, chỉ target `audiocpp` + `vieneu_tts` | tag **v0.9.4** — `717efc34` (API C đã đối chiếu khớp wrapper) |
| wrapper C | `native/tts_vieneu/vieneu_tts.cpp` → `libvieneu_tts.so` | trong repo |
| SEA-G2P (Rust, C ABI) | **submodule** `third_party/sea-g2p`; CI cross-compile `--no-default-features --features capi` cho `arm64-v8a`, chép vào `jniLibs` | tag **v0.10.0** — `dae5ca83` |
| `sea_g2p.bin` (~30 MB, từ điển) | **không nhúng** — người dùng tải/import cạnh model (bước tải trong app là việc của lane L6) | bản phát hành sea-g2p v0.10.0 |
| `vieneu-v3-turbo-q8_0.gguf` (188 MB) + `voices/minh_quan_pro/*` | người dùng import như Hy-MT `.gguf` | model author (Apache-2.0) |

Cách nạp SEA-G2P: audio.cpp **`dlopen` theo tên** (`libsea_g2p_rs.so`) khi option
`vieneu_v3_turbo.g2p_library` để trống. Vì vậy `libsea_g2p_rs.so` nằm trong `jniLibs`
của APK (đường tìm mặc định của linker) là đủ; **chỉ** `sea_g2p.bin` phải nằm cạnh model.
Wrapper ưu tiên đường dẫn tuyệt đối nếu người dùng vẫn đặt `.so` cạnh model (cách cũ).

## 3. Phương án đã cân nhắc và loại

| Phương án | Vì sao loại |
|---|---|
| Giữ nguyên trạng + chỉ sửa thông báo "chưa kèm engine" | Owner đã chốt muốn engine **chạy thật**; thông báo đúng mà không dùng được thì vô nghĩa |
| Nhúng sẵn GGUF 188 MB trong APK | APK đã ~199 MB; model có phiên bản/giấy phép riêng; trái chính sách "không bundle model" (Hy-MT, Whisper, Sherpa đều import) |
| Chép `.so` dựng sẵn vào repo | Không có bản Android dựng sẵn; binary không nguồn gốc không kiểm toán được; mỗi ABI/NDK lại phải làm lại |
| Bỏ SEA-G2P, đưa thẳng chữ thô vào model | Model không nhận chữ thô — sai kiến trúc, không phải "tối ưu" |
| Dùng `MANAGE_EXTERNAL_STORAGE` để tiện đọc/ghi | Play policy; không liên quan tới quyết định này (xem PSRC-204) |

## 4. Hệ quả

**Tốt**
- Engine có mặt trong APK; `TtsService` sẽ thấy engine sẵn sàng khi model + từ điển có đủ.
- Build hỏng **ồn ào**: workflow riêng `vieneu_engine_build.yml` chứng minh 3 `.so` có
  trong APK thay vì để tới bước release mới biết.
- Stereo→mono được sửa ⇒ đúng thời lượng, đúng cao độ.

**Xấu / phải trả giá**
- Build NDK lần đầu: audio.cpp + ggml cho arm64 — **đo thật (run 43325244915): job
  `vieneu_engine_build` 17 phút 05 giây** từ checkout tới APK, gồm cả `cargo ndk` build
  SEA-G2P và compile ggml **hai lần** (một cho llama.cpp của `:app`, một cho `:vieneu`).
  **Dung lượng engine đo thật (APK debug arm64, run 43328297538):** `libaudiocpp.so`
  4,9 MiB + `libsea_g2p_rs.so` 4,2 MiB + `libvieneu_tts.so` 0,9 MiB = **≈10 MiB chưa nén**
  (APK debug tổng 261 MiB — số này KHÔNG dùng để ước lượng bản phát hành; chênh lệch
  APK release đo ở G4).
- Thêm Rust toolchain + `cargo-ndk` vào đường build ⇒ một phụ thuộc mới; pin tag để
  không bị upstream đổi.
- Repo nặng thêm khi `submodule update` (audio.cpp ~144 MB, sea-g2p ~84 MB).
- **Chỉ Android arm64-v8a** ở bản này (CMake hiện chỉ build arm64; desktop/iOS chưa có
  đường build engine ⇒ vẫn fallback).

## 5. Kiểm chứng

| Cổng | Nội dung |
|---|---|
| Build | `vieneu_engine_build.yml`: init submodule theo pin → `cargo ndk` build SEA-G2P → `flutter build apk --debug --flavor stable --target-platform android-arm64` → `unzip -l` phải thấy `libvieneu_tts.so`, `libaudiocpp.so`, `libsea_g2p_rs.so` |
| Hợp đồng | `test/tts/vieneu_native_engine_contract_test.dart` (source-scan): trộn kênh, cách truyền SEA-G2P, `.gitmodules`, workflow kiểm `.so` |
| Máy thật (owner) | import `vieneu-v3-turbo-q8_0.gguf` + `sea_g2p.bin` (+ voices) ⇒ đọc 3 đoạn tiếng Việt; đo thời gian nạp, tổng hợp, RAM đỉnh; gỡ model ⇒ rơi về engine kế, không crash |

## 6. Việc còn lại (lane L6)

1. Chạy `vieneu_engine_build.yml` tới xanh, ghi thời gian build + dung lượng APK thật.
2. Đường **tải `sea_g2p.bin` trong app** (kèm checksum) hoặc hướng dẫn import rõ ràng —
   hiện người dùng phải tự đặt file.
3. `PSRC-214…218`: import model ở mọi mục, không báo "thành công" giả, khởi tạo/import
   giọng/tạo giọng có thông điệp đúng.
4. Nghiệm thu máy như bảng trên.

## 7. Điều chỉnh khi thi công (2026-11-12) — ba lỗi chỉ lộ khi build thật

Quyết định ở §2 không đổi, nhưng đường thi công phải sửa ba lần; ghi lại để người sau
không "sửa lại cho gọn" rồi tái hiện đúng ba lỗi này.

| # | Triệu chứng (run) | Nguyên nhân thật | Cách sửa đã áp dụng |
|---|---|---|---|
| 1 | `Failed to load Cargo.toml in current directory` (43310174692) | `cargo ndk` đọc `cargo metadata` theo **cwd**, không theo `--manifest-path` | `cd third_party/sea-g2p` rồi mới gọi; `-o "$GITHUB_WORKSPACE/…/jniLibs"` tuyệt đối |
| 2 | `configure CMake` đỏ: `add_library cannot create ALIAS target "ggml::ggml"` (43318161013) | llama.cpp của `:app` kéo ggml **0.21.0**, audio.cpp kéo ggml **0.12.0** của riêng nó (`external/ggml`, không có option dùng ggml ngoài) ⇒ hai bản trong **cùng** project CMake | Tách **module Gradle `:vieneu`** (`android/vieneu/`) với CMake project riêng; `:app` chỉ `implementation(project(":vieneu"))`. Bỏ hẳn `add_subdirectory(audio.cpp)` khỏi `ai/CMakeLists.txt` (có test chặn thêm lại) |
| 3 | `workflow.cpp:392: use of undeclared identifier 'posix_spawnp'` (43323259962) | AGP mặc định build **mọi** target CMake ⇒ kéo `audiocpp_cli` / `audiocpp_server` / `model_perf`; CLI dùng `posix_spawnp` (API 28+) trong khi `minSdk = 24` | Khai báo `targets += listOf("audiocpp", "vieneu_tts")` trong `defaultConfig` của module |

Hai bài học CI kèm theo (không thuộc engine nhưng chặn đường):
- Runner **không có NDK 27** mà plugin `whisper_flutter_new` khai riêng ⇒
  `LicenceNotAcceptedException: ndk;27.0.11902837`. Workflow engine nay cài NDK 27 + 28.2
  và `sdkmanager --licenses` y như `build_final_complete.yml`.
- Log workflow/artifact Actions bị chặn egress từ sandbox agent ⇒ thêm
  `scripts/ci/emit_failure_annotation.py` biến lỗi build thành **annotation** (một message
  bị GitHub cắt ~4096 ký tự nên script cắt thành nhiều phần, ưu tiên khối `FAILED:` và
  dòng `error:`). Đây là công cụ chẩn đoán thường trực, không phải đồ nghề tạm.

**Trạng thái đo được:** `vieneu_engine_build` 🟢 hai lần liên tiếp — 43325244915 (17m05s)
và 43328297538 (18m52s, có bước đo). APK arm64-debug 261 MiB chứa đủ `libvieneu_tts.so`
0,9 MiB + `libaudiocpp.so` 4,9 MiB + `libsea_g2p_rs.so` 4,2 MiB (≈10 MiB engine, chưa nén). Đường phát hành
(`build_final_complete.yml`) nay init submodule **không nuốt lỗi** và tự `cargo ndk` build
SEA-G2P ⇒ APK release cũng có engine, không còn cảnh "build xanh mà thiếu engine".
