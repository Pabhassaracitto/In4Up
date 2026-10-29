cmake_minimum_required(VERSION 3.10)
project(ultratimestretch_web)

set(CMAKE_CXX_STANDARD 17)

# Point to shared native code
set(NATIVE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../native)

# V1 + V2 Sources
file(GLOB V1_SOURCES ${NATIVE_DIR}/src/V1/*.cpp)
file(GLOB V2_SOURCES ${NATIVE_DIR}/src/V2/*.cpp)

include_directories(${NATIVE_DIR}/include)

add_executable(
    ultratimestretch
    bindings.cpp
    ${V1_SOURCES}
    ${V2_SOURCES}
)

# Emscripten flags
set_target_properties(ultratimestretch PROPERTIES
    LINK_FLAGS "\
        -s WASM=1 \
        -s ALLOW_MEMORY_GROWTH=1 \
        -s EXPORT_ES6=1 \
        -s MODULARIZE=1 \
        -s EXPORT_NAME='createUltraTimeStretch' \
        -s TOTAL_MEMORY=256MB \
        -O3 \
        --bind \
    "
)