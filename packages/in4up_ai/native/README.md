# in4up AI native backend

C ABI adapter (Dart FFI) for the local GGUF inference backend. The adapter
links against the `llama` target from the shallow `third_party/llama.cpp`
submodule and exposes model loading plus synchronous generation.

## Init submodule (bắt buộc trước khi build native)

```bash
git submodule update --init --depth 1
```

Submodule được pin tại tag ổn định của llama.cpp (xem `git ls-tree HEAD
third_party/llama.cpp`).

## Build targets

| Platform | Cấu hình | Kết quả |
|---|---|---|
| Android | `android/app/src/main/cpp/ai/CMakeLists.txt` (wire qua `externalNativeBuild` trong `build.gradle.kts`) | `libin4up_ai_native.so` — AGP đóng gói tự động vào APK |
| Windows | `windows/CMakeLists.txt` + `windows/runner/CMakeLists.txt` | `in4up_ai_native.dll` — copy cạnh `in4up.exe` (POST_BUILD + install) |

Nếu thiếu submodule, CMake chỉ in WARNING (không fail configure) và app chạy
không có native lib — Dart engine tự fallback về mock để Chat vẫn dùng được.

Dart FFI load `libin4up_ai_native.so` trên Android và `in4up_ai_native.dll`
trên Windows. Native lib cũng export alias `in2up_ai_*` để tương thích ngược
với các build cũ (harvested từ nhánh vipsound).

Model KHÔNG commit vào Git. Import file `.gguf` từ màn hình I2U AI Chat;
loader kiểm tra magic header GGUF trước khi copy vào app storage.
