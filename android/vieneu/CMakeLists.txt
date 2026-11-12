# Engine TTS VieNeu-TTS — CMake project RIÊNG (ADR-0028 / lane L6).
#
# Vì sao tách project: xem android/vieneu/build.gradle.kts. Tóm tắt: audio.cpp
# mang ggml 0.12.0 của riêng nó, llama.cpp của :app mang ggml 0.21.0; hai bản
# trong cùng project CMake trùng target `ggml` / alias `ggml::ggml` ⇒ configure
# đỏ. Project riêng thì mỗi bên có ggml của mình.
#
# Kết quả build: libvieneu_tts.so (wrapper FFI cho Dart) + libaudiocpp.so
# (runtime C API của audio.cpp). Cả hai được AGP đóng gói vào APK nhờ :app phụ
# thuộc module này.
cmake_minimum_required(VERSION 3.14)
project(in4up_vieneu_engine LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Link static ggml vào shared lib ⇒ bắt buộc PIC.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# android/vieneu → root repo = 2 cấp cha
get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)

set(AUDIOCPP_ROOT "${REPO_ROOT}/third_party/audio.cpp")

# Tự init submodule nếu thiếu: người clone không dùng --recursive vẫn build được
# (git có sẵn trên máy dev; trên CI submodule đã init từ trước).
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

if(NOT EXISTS "${AUDIOCPP_ROOT}/CMakeLists.txt")
    message(WARNING
        "[in4up-tts] BỎ QUA: thiếu third_party/audio.cpp "
        "(chạy: git submodule update --init --depth 1). Dart engine sẽ báo "
        "chưa sẵn sàng và fallback TTS cũ — không crash.")
    return()
endif()

# ── Cấu hình audio.cpp: chỉ C API, chỉ model VieNeu v3 Turbo, chỉ CPU ────────
set(AUDIOCPP_BUILD_C_API         ON   CACHE BOOL "" FORCE)
set(AUDIOCPP_MODEL_SET           custom CACHE STRING "" FORCE)
set(AUDIOCPP_MODELS              "vieneu_v3_turbo" CACHE STRING "" FORCE)
set(AUDIOCPP_BUILD_NATIVE_MODEL_MANAGER OFF CACHE BOOL "" FORCE)

set(ENGINE_ENABLE_CUDA           OFF  CACHE BOOL "" FORCE)
set(ENGINE_ENABLE_HIP            OFF  CACHE BOOL "" FORCE)
set(ENGINE_ENABLE_VULKAN         OFF  CACHE BOOL "" FORCE)
set(ENGINE_ENABLE_METAL          OFF  CACHE BOOL "" FORCE)
set(ENGINE_ENABLE_WEBGPU         OFF  CACHE BOOL "" FORCE)
set(ENGINE_ENABLE_RKNN           OFF  CACHE BOOL "" FORCE)
# -march=native không hợp lệ khi cross-compile bằng NDK.
set(ENGINE_ENABLE_NATIVE_CPU     OFF  CACHE BOOL "" FORCE)
# NDK không ship OpenMP host.
set(ENGINE_ENABLE_OPENMP         OFF  CACHE BOOL "" FORCE)
# sgemm llamafile dùng intrinsic FP16 NEON không check __ARM_FEATURE_FP16_*.
set(ENGINE_ENABLE_LLAMAFILE      OFF  CACHE BOOL "" FORCE)
set(ENGINE_BUILD_EXAMPLES        OFF  CACHE BOOL "" FORCE)
set(ENGINE_BUILD_TESTS           OFF  CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE               OFF  CACHE BOOL "" FORCE)

message(STATUS "[in4up-tts] audio.cpp C API (vieneu_v3_turbo, CPU only) từ ${AUDIOCPP_ROOT}")
add_subdirectory(${AUDIOCPP_ROOT} ${CMAKE_CURRENT_BINARY_DIR}/audio.cpp EXCLUDE_FROM_ALL)

# ── Wrapper FFI cho Dart ────────────────────────────────────────────────────
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
