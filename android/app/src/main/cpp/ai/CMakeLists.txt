# AI chat native backend (llama.cpp + in4up_ai_native)
#
# File riêng cho backend AI để KHÔNG đụng vào CMakeLists.txt của
# UltraTimeStretch (vùng bảo vệ mục 0). AGP trỏ externalNativeBuild vào đây.
#
# Yêu cầu submodule llama.cpp đã init (shallow):
#   git submodule update --init --depth 1
# Nếu thiếu, configure vẫn thành công (chỉ WARNING) — APK build ra không có
# libin4up_ai_native.so và Dart engine tự fallback về mock theo thiết kế.
cmake_minimum_required(VERSION 3.14)
project(in4up_ai_native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Link static llama/ggml vào shared lib ⇒ bắt buộc PIC (llama.cpp chỉ tự bật
# PIC khi BUILD_SHARED_LIBS=ON; ta bật thủ công cho mọi target trong scope này).
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# android/app/src/main/cpp/ai → root repo = 6 cấp cha
get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../.." ABSOLUTE)
set(LLAMA_DIR "${REPO_ROOT}/third_party/llama.cpp")

# Tự init submodule nếu thiếu (git có sẵn). Lý do: token GitHub App của repo
# không có quyền `workflows` nên KHÔNG thể sửa .github/workflows để thêm bước
# "git submodule update"; tự chữa tại configure giúp CI (chạy workflow gốc)
# vẫn build + kiểm chứng được native backend, và dev local khỏi cần lệnh tay.
if(NOT EXISTS "${LLAMA_DIR}/CMakeLists.txt")
    find_program(GIT_EXECUTABLE git)
    if(GIT_EXECUTABLE AND EXISTS "${REPO_ROOT}/.git")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" submodule update --init --depth 1 -- third_party/llama.cpp
            WORKING_DIRECTORY "${REPO_ROOT}"
            RESULT_VARIABLE _IN4UP_GIT_RC
            OUTPUT_QUIET ERROR_QUIET
        )
    endif()
endif()

if(NOT EXISTS "${LLAMA_DIR}/CMakeLists.txt")
    message(WARNING "[in4up-ai] third_party/llama.cpp missing. Run: git submodule update --init --depth 1. AI native backend disabled; Dart falls back to mock.")
    return()
endif()

# Chỉ cần thư viện `llama` — tắt toàn bộ target phụ để build nhanh và gọn.
set(LLAMA_BUILD_COMMON   OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS    OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER   OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_LLAMA_CLI OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP          OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE          OFF CACHE BOOL "" FORCE)
# GGML_LLAMAFILE: llama.cpp bật ON mặc định (CMakeLists gốc). TẮT vì file
# ggml-cpu/llamafile/sgemm.cpp dùng intrinsics FP16 NEON (vld1q_f16/vld1_f16)
# MÀ KHÔNG check __ARM_FEATURE_FP16_VECTOR_ARITHMETIC — upstream ghi thẳng
# "FIXME: this should check for __ARM_FEATURE_FP16_VECTOR_ARITHMETIC". Target
# armeabi-v7a của NDK không có extension +fp16 ⇒ CI chết (run 32586625020):
#   sgemm.cpp:311: error: use of undeclared identifier 'vld1q_f16'
# (arm64 không ảnh hưởng vì NDK arm64 mặc định có fp16). Tắt OFF giữ nguyên
# inference hoàn chỉnh — ggml dùng bộ kernel CPU chuẩn, chỉ mất fast path
# llamafile cho model f16.
set(GGML_LLAMAFILE       OFF CACHE BOOL "" FORCE)

add_subdirectory(${LLAMA_DIR} ${CMAKE_CURRENT_BINARY_DIR}/llama.cpp EXCLUDE_FROM_ALL)

add_library(in4up_ai_native SHARED
    ${REPO_ROOT}/packages/in4up_ai/native/in4up_ai_native.cpp
)
target_include_directories(in4up_ai_native PRIVATE
    ${REPO_ROOT}/packages/in4up_ai/native
    ${LLAMA_DIR}/include
)
# link `llama` kéo theo transitively ggml-base/ggml-cpu/… (CMake tự xử lý)
target_link_libraries(in4up_ai_native PRIVATE llama)

# ══════════════════════════════════════════════════════════════════════════════
# VieNeu-TTS native engine (ticket TTS-VIENEU-001)
# audio.cpp (github.com/0xShug0/audio.cpp, commit be1286e0) làm runtime GGUF,
# VieNeu-TTS v3 Turbo (pnnbao-ump/VieNeu-TTS-v3-Turbo-GGUF, Apache-2.0).
#
# Chỉ build CPU backend, chỉ mô hình vieneu_v3_turbo (custom model set) để
# giữ thời gian build + dung lượng APK hợp lý. CUDA/Vulkan/Metal/Metal/RKNN
# tắt hết (ticket: chỉ CPU cho bản đầu).
#
# Nếu submodule third_party/audio.cpp chưa init → chỉ WARNING, app vẫn build
# và Dart engine tự báo engine không sẵn sàng → fallback sang TTS cũ, không
# crash. Cách kích hoạt: `git submodule update --init --depth 1`.
# ══════════════════════════════════════════════════════════════════════════════

set(AUDIOCPP_ROOT "${REPO_ROOT}/third_party/audio.cpp")

if(NOT EXISTS "${AUDIOCPP_ROOT}/CMakeLists.txt")
    find_program(GIT_EXECUTABLE git)
    if(GIT_EXECUTABLE AND EXISTS "${REPO_ROOT}/.git")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" submodule update --init --depth 1
                    -- third_party/audio.cpp
            WORKING_DIRECTORY "${REPO_ROOT}"
            RESULT_VARIABLE _IN4UP_AUDIOCPP_GIT_RC
            OUTPUT_QUIET ERROR_QUIET)
    endif()
endif()

set(IN4UP_BUILD_VIENEU_TTS ON CACHE BOOL "Build VieNeu-TTS native engine (audio.cpp C API)")

if(IN4UP_BUILD_VIENEU_TTS AND EXISTS "${AUDIOCPP_ROOT}/CMakeLists.txt")
    set(AUDIOCPP_BUILD_C_API         ON   CACHE BOOL "" FORCE)
    set(AUDIOCPP_MODEL_SET           custom CACHE STRING "" FORCE)
    set(AUDIOCPP_MODELS              "vieneu_v3_turbo" CACHE STRING "" FORCE)
    set(ENGINE_ENABLE_CUDA           OFF  CACHE BOOL "" FORCE)
    set(ENGINE_ENABLE_HIP            OFF  CACHE BOOL "" FORCE)
    set(ENGINE_ENABLE_VULKAN         OFF  CACHE BOOL "" FORCE)
    set(ENGINE_ENABLE_METAL          OFF  CACHE BOOL "" FORCE)
    set(ENGINE_ENABLE_WEBGPU         OFF  CACHE BOOL "" FORCE)
    set(ENGINE_ENABLE_LLAMAFILE      OFF  CACHE BOOL "" FORCE)   // tránh lỗi fp16 NEON trên armeabi-v7a (xem GGML_LLAMAFILE trên)
    set(ENGINE_ENABLE_NATIVE_CPU     OFF  CACHE BOOL "" FORCE)   // -march=native không hợp lệ khi cross-compile NDK
    set(ENGINE_ENABLE_OPENMP         OFF  CACHE BOOL "" FORCE)   // NDK không ship OpenMP_host mặc định
    set(ENGINE_ENABLE_RKNN           OFF  CACHE BOOL "" FORCE)
    set(AUDIOCPP_BUILD_NATIVE_MODEL_MANAGER OFF CACHE BOOL "" FORCE)
    set(ENGINE_BUILD_EXAMPLES        OFF  CACHE BOOL "" FORCE)
    set(ENGINE_BUILD_TESTS           OFF  CACHE BOOL "" FORCE)
    set(GGML_LLAMAFILE               OFF  CACHE BOOL "" FORCE)

    message(STATUS "[in4up-tts] Building audio.cpp C API (vieneu_v3_turbo, CPU only)")
    add_subdirectory(${AUDIOCPP_ROOT} ${CMAKE_CURRENT_BINARY_DIR}/audio.cpp EXCLUDE_FROM_ALL)

    add_library(vieneu_tts SHARED
        ${REPO_ROOT}/native/tts_vieneu/vieneu_tts.cpp
    )
    target_include_directories(vieneu_tts PRIVATE
        ${AUDIOCPP_ROOT}/include
        ${REPO_ROOT}/native/tts_vieneu
    )
    target_link_libraries(vieneu_tts PRIVATE audiocpp)

    set_target_properties(vieneu_tts PROPERTIES
        OUTPUT_NAME "vieneu_tts"
        C_VISIBILITY_PRESET hidden
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )

    message(STATUS "[in4up-tts] target: libvieneu_tts.so (links libaudiocpp.so)")
else()
    message(STATUS
        "[in4up-tts] vieneu_tts BỎ QUA: chưa có third_party/audio.cpp "
        "(chạy: git submodule update --init --depth 1) hoặc "
        "IN4UP_BUILD_VIENEU_TTS=OFF. Dart engine sẽ báo chưa sẵn sàng "
        "và fallback về TTS cũ — không crash.")
endif()
