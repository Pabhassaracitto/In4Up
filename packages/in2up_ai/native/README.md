# in2up AI native backend

This directory contains the small C ABI adapter used by Dart FFI. The adapter
links against the `llama` target from the shallow `third_party/llama.cpp`
submodule and exposes model loading plus synchronous generation.

Before building native targets:

```bash
git submodule update --init --depth 1
```

Android and Windows CMake files in this repository build `in2up_ai_native`.
The Dart side loads `libin2up_ai_native.so` on Android and
`in2up_ai_native.dll` on Windows. When the native library is unavailable, the
engine deliberately falls back to the existing mock backend so the rest of the
app remains usable.

The model itself is not committed to Git. Import a valid `.gguf` file from the
I2U AI Chat screen; the loader validates the GGUF magic header and copies it to
application storage.
