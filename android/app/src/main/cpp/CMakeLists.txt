cmake_minimum_required(VERSION 3.22.1)

project("ultra_time_stretch" VERSION 1.0.0 LANGUAGES CXX)

# C++17 Standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimization flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -fPIC")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -DNDEBUG")

# NEON for ARM
if(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon -mfloat-abi=softfp")
elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a+simd")
endif()

# Source files
set(ULTRA_SOURCES
        UltraTimeStretch.h
        SIMDOptimizations.h
        FFTProcessor.cpp
        TransientDetector.cpp
        PhaseVocoder.cpp
        WSOLAProcessor.cpp
        HybridStretcher.cpp
        Engine.cpp
        native_bridge.cpp
)

# Shared library
add_library(ultra_time_stretch SHARED ${ULTRA_SOURCES})

# Include directories
target_include_directories(ultra_time_stretch PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# Android libraries
find_library(log-lib log)
find_library(android-lib android)
find_library(OpenSLES-lib OpenSLES)

target_link_libraries(ultra_time_stretch
        ${log-lib}
        ${android-lib}
        ${OpenSLES-lib}
)

# Export symbols
set_target_properties(ultra_time_stretch PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
)