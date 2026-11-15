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

# ── Cấu hình audio.cpp: chỉ C API, chỉ model VieNeu v3 Turbo, chỉ CPU ───────
#
# `AUDIOCPP_MODEL_SET=custom` + `AUDIOCPP_MODELS` chọn NHỮNG MODEL ĐƯỢC BIÊN
# DỊCH (CMakeLists.txt L425-427, L2878+). Bỏ hai dòng này ⇒ `full` ⇒ mọi
# community model đều vào build, kể cả model dùng API không có trên NDK
# (`latentsync/video.cpp`: `posix_spawn_file_actions_init` undeclared) ⇒
# `:vieneu:buildCMakeDebug` đỏ. Chúng KHÔNG liên quan tới model spec.
#
# PSRC-171: model spec là chuyện KHÁC — `builtin_model_specs()` chỉ có entry
# khi `AUDIOCPP_DEPLOYMENT_BUILD=ON` (mặc định OFF, L64-67) nên libaudiocpp.so
# ra đời không có spec nào và mọi lần nạp model chết ở
# "model spec not found for family 'vietneu_tts'". Cách sửa: nhúng đúng file
# spec của family này vào wrapper (khối "MODEL SPEC" bên dưới) rồi truyền qua
# `model_spec_override`.
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

# ── MODEL SPEC (PSRC-171) ───────────────────────────────────────────────────
# audio.cpp v0.9.4 KHÔNG nhúng `model_specs/*.json` vào libaudiocpp.so trừ khi
# bật `AUDIOCPP_DEPLOYMENT_BUILD` (mặc định OFF, và bật thì tốn thêm 1,3 MB
# cho 140 family không dùng tới). Wrapper vì thế mang theo spec của ĐÚNG family
# này (12 279 B, sinh từ submodule đã ghim v0.9.4) và đưa cho audio.cpp qua
# `audiocpp_model_config.model_spec_override` khi lần nạp đầu báo thiếu spec.
set(IN4UP_VIENEU_SPEC_JSON "${AUDIOCPP_ROOT}/model_specs/vieneu_v3_turbo.json")
if(EXISTS "${IN4UP_VIENEU_SPEC_JSON}")
    file(READ "${IN4UP_VIENEU_SPEC_JSON}" AUDIOCPP_V3_TURBO_SPEC_JSON)
    set(AUDIOCPP_V3_TURBO_SPEC_EMBEDDED "true")
    # Sửa json trong submodule ⇒ CMake tự configure lại (không phải build sạch).
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                 "${IN4UP_VIENEU_SPEC_JSON}")
    string(LENGTH "${AUDIOCPP_V3_TURBO_SPEC_JSON}" _in4up_spec_len)
    message(STATUS "[in4up-tts] nhúng model spec vieneu_v3_turbo.json (${_in4up_spec_len} B)")
else()
    # Không có submodule ⇒ đã `return()` ở trên. Giữ nhánh này cho tương lai
    # (audio.cpp đổi layout): build vẫn xanh, wrapper báo lỗi rõ ở runtime.
    set(AUDIOCPP_V3_TURBO_SPEC_JSON "")
    set(AUDIOCPP_V3_TURBO_SPEC_EMBEDDED "false")
    message(WARNING
        "[in4up-tts] KHÔNG thấy ${IN4UP_VIENEU_SPEC_JSON} — wrapper sẽ không "
        "nhúng model spec; audio.cpp có thể báo 'model spec not found'.")
endif()
configure_file(
    "${REPO_ROOT}/native/tts_vieneu/model_spec.inc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/vieneu_model_spec.inc"
    @ONLY)

# ── Wrapper FFI cho Dart ────────────────────────────────────────────────────
add_library(vieneu_tts SHARED
    ${REPO_ROOT}/native/tts_vieneu/vieneu_tts.cpp
)
target_include_directories(vieneu_tts PRIVATE
    ${AUDIOCPP_ROOT}/include
    ${REPO_ROOT}/native/tts_vieneu
    ${CMAKE_CURRENT_BINARY_DIR}   # vieneu_model_spec.inc (sinh ở configure)
)
target_link_libraries(vieneu_tts PRIVATE audiocpp)

set_target_properties(vieneu_tts PROPERTIES
    OUTPUT_NAME "vieneu_tts"
    C_VISIBILITY_PRESET hidden
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

message(STATUS "[in4up-tts] target: libvieneu_tts.so (links libaudiocpp.so)")
