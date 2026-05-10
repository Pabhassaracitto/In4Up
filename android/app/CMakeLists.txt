# android/app/CMakeLists.txt

cmake_minimum_required(VERSION 3.22.1)
project(vipsound_native)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

# ── llama.cpp source ──────────────────────────────────────
set(LLAMA_DIR "${CMAKE_SOURCE_DIR}/../../native/llama_cpp/vendor/llama.cpp")

# Build flags cho Android ARM
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -DNDEBUG")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -ffast-math -DNDEBUG")

# Enable NEON trên ARM64
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a+dotprod+fp16 -mcpu=generic")
endif()

# ── llama.cpp core sources ────────────────────────────────
# Chỉ include files cần thiết (không phải toàn bộ project)
file(GLOB GGML_SOURCES
    "${LLAMA_DIR}/ggml.c"
    "${LLAMA_DIR}/ggml-alloc.c"
    "${LLAMA_DIR}/ggml-backend.c"
    "${LLAMA_DIR}/ggml-quants.c"
    "${LLAMA_DIR}/ggml-threading.c"
)

file(GLOB LLAMA_SOURCES
    "${LLAMA_DIR}/llama.cpp"
    "${LLAMA_DIR}/unicode.cpp"
    "${LLAMA_DIR}/unicode-data.cpp"
)

# ── Bridge ────────────────────────────────────────────────
set(BRIDGE_DIR "${CMAKE_SOURCE_DIR}/../../native/llama_cpp")

add_library(
    llama
    SHARED
    ${BRIDGE_DIR}/llama_bridge.cpp
    ${LLAMA_SOURCES}
    ${GGML_SOURCES}
)

target_compile_definitions(llama PRIVATE GGML_USE_CPU)

target_include_directories(llama PRIVATE
    ${LLAMA_DIR}
    ${BRIDGE_DIR}
)

target_link_libraries(llama
    android
    log
)

# ── Tối ưu size ──────────────────────────────────────────
set_target_properties(llama PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
)
