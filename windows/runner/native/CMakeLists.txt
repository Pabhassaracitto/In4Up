cmake_minimum_required(VERSION 3.14)
project(ultratimestretch LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Disable Windows min/max macros
add_definitions(-DNOMINMAX)
add_definitions(-D_USE_MATH_DEFINES)

# Path to shared native code
# Sử dụng absolute path hoặc kiểm tra sự tồn tại của thư mục native
get_filename_component(NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../native" ABSOLUTE)
message(STATUS "NATIVE_DIR = ${NATIVE_DIR}")

# Include headers
include_directories(
    "${NATIVE_DIR}"
    "${NATIVE_DIR}/include"
    "${NATIVE_DIR}/src/V1"
    "${NATIVE_DIR}/src/V2"
)

# -------------------------
# V1 sources
# -------------------------
set(V1_SOURCES
    "${NATIVE_DIR}/src/V1/Engine.cpp"
    "${NATIVE_DIR}/src/V1/FFTProcessor.cpp"
    "${NATIVE_DIR}/src/V1/PhaseVocoder.cpp"
    "${NATIVE_DIR}/src/V1/WSOLAProcessor.cpp"
    "${NATIVE_DIR}/src/V1/HybridStretcher.cpp"
    "${NATIVE_DIR}/src/V1/TransientDetector.cpp"
)

# -------------------------
# V2 sources (3-option engine)
# NOTE: KHÔNG build native/src/V2/PhaseVocoder*.cpp vì nó redefine V1 PhaseVocoder
# -------------------------
set(V2_SOURCES
    "${NATIVE_DIR}/src/V2/SpectralPeakInterpolator.cpp"
    "${NATIVE_DIR}/src/V2/FormantPreserver.cpp"
    "${NATIVE_DIR}/src/V2/HarmonicPercussiveSeparator.cpp"
    "${NATIVE_DIR}/src/V2/MultiResolutionPV.cpp"
    "${NATIVE_DIR}/src/V2/HybridStretcherV2.cpp"
    "${NATIVE_DIR}/src/V2/EngineV2.cpp"
)

# Debug: check sources exist
foreach(src ${V1_SOURCES} ${V2_SOURCES})
    if(EXISTS "${src}")
        message(STATUS "Found: ${src}")
    else()
        message(FATAL_ERROR "NOT FOUND: ${src}")
    endif()
endforeach()

# Build shared library
add_library(ultratimestretch SHARED
    native_wrapper.cpp
    ${V1_SOURCES}
    ${V2_SOURCES}
)

if(WIN32)
    target_compile_definitions(ultratimestretch PRIVATE
        _CRT_SECURE_NO_WARNINGS
        NOMINMAX
        _USE_MATH_DEFINES
    )
    # /wd4267: Tắt cảnh báo size_t to int
    # /MP: Biên dịch song song để build nhanh hơn
    target_compile_options(ultratimestretch PRIVATE 
        /wd4267 
        /MP
    )
endif()

set_target_properties(ultratimestretch PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS ON
)