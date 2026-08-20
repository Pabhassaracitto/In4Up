# in4up AI native backend

This directory contains the small C ABI adapter used by Dart FFI. The adapter
links against the `llama` target from an optional `third_party/llama.cpp`
checkout and exposes model loading plus synchronous generation.

Native linking is **opt-in**. Android and Windows CMake only build
`in4up_ai_native` when `third_party/llama.cpp/CMakeLists.txt` exists:

```bash
git submodule add --depth 1 https://github.com/ggerganov/llama.cpp.git third_party/llama.cpp
```

The Dart side loads `libin4up_ai_native.so` on Android and
`in4up_ai_native.dll` on Windows. When the native library is unavailable, the
engine falls back to the existing mock backend so Chat and analysis stay usable.

The model itself is not committed to Git. Import a valid `.gguf` file from the
I2U AI Chat screen; the loader validates the GGUF magic header and copies it to
application storage.
