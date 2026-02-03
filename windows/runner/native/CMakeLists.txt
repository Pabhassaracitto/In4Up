cmake_minimum_required(VERSION 3.14)
project(ultratimestretch)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Prevent Windows min/max macro conflicts
add_definitions(-DNOMINMAX)
add_definitions(-D_USE_MATH_DEFINES)

# Native directory path (từ windows/runner/native/ lên 3 cấp rồi vào native/)
set(NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../native")

# Debug: In ra đường dẫn để kiểm tra
message(STATUS "NATIVE_DIR = ${NATIVE_DIR}")
message(STATUS "Looking for sources in: ${NATIVE_DIR}/src/V1/")

# Include directories
include_directories(${NATIVE_DIR}/include)

# V1 Sources
set(V1_SOURCES
    "${NATIVE_DIR}/src/V1/Engine.cpp"
    "${NATIVE_DIR}/src/V1/FFTProcessor.cpp"
    "${NATIVE_DIR}/src/V1/PhaseVocoder.cpp"
    "${NATIVE_DIR}/src/V1/WSOLAProcessor.cpp"
    "${NATIVE_DIR}/src/V1/HybridStretcher.cpp"
    "${NATIVE_DIR}/src/V1/TransientDetector.cpp"
)

# V2 Sources
set(V2_SOURCES
    "${NATIVE_DIR}/src/V2/MultiResolutionPV.cpp"
    "${NATIVE_DIR}/src/V2/EngineV2.cpp"
)

# Debug: Kiểm tra file tồn tại
foreach(src ${V1_SOURCES} ${V2_SOURCES})
    if(EXISTS ${src})
        message(STATUS "Found: ${src}")
    else()
        message(WARNING "NOT FOUND: ${src}")
    endif()
endforeach()

# Build shared library
add_library(ultratimestretch SHARED
    native_wrapper.cpp
    ${V1_SOURCES}
    ${V2_SOURCES}
)

# Windows specific settings
if(WIN32)
    target_compile_definitions(ultratimestretch PRIVATE
        _CRT_SECURE_NO_WARNINGS
        NOMINMAX
        _USE_MATH_DEFINES
    )

    # Enable optimizations for Release
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        target_compile_options(ultratimestretch PRIVATE /O2 /fp:fast)
    endif()
endif()

# Export all symbols for DLL
set_target_properties(ultratimestretch PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS ON
)