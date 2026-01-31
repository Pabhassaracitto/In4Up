cmake_minimum_required(VERSION 3.14)
project(ultratimestretch_windows)

set(CMAKE_CXX_STANDARD 17)

# Point to shared native code
set(NATIVE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../native)

# V1 Sources
file(GLOB V1_SOURCES ${NATIVE_DIR}/src/V1/*.cpp)

# V2 Sources
file(GLOB V2_SOURCES ${NATIVE_DIR}/src/V2/*.cpp)

# Include directories
include_directories(${NATIVE_DIR}/include)

# Build as DLL
add_library(
    ultratimestretch
    SHARED
    native_wrapper.cpp
    ${V1_SOURCES}
    ${V2_SOURCES}
)

# AVX2 for x64
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    target_compile_definitions(ultratimestretch PRIVATE UTS_USE_SSE=1)
    if(MSVC)
        target_compile_options(ultratimestretch PRIVATE /arch:AVX2)
    else()
        target_compile_options(ultratimestretch PRIVATE -mavx2)
    endif()
endif()

# Export symbols
if(MSVC)
    target_compile_definitions(ultratimestretch PRIVATE UTS_EXPORTS)
endif()