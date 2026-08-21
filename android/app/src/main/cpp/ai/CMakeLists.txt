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
