cmake_minimum_required(VERSION 3.10.2)
project(ultratimestretch)

if(ANDROID)
    if(NOT DEFINED ANDROID_STL)
        message(WARNING "ANDROID_STL is not defined. This can lead to runtime errors. It is recommended to set this in your app's build.gradle file. For example: android.defaultConfig.externalNativeBuild.cmake.arguments.add('-DANDROID_STL=c++_static')")
    elseif(ANDROID_STL STREQUAL "c++_shared")
        message(WARNING "You are using the shared C++ standard library (c++_shared). This requires you to load it manually in your application's Java/Kotlin code before loading the main native library. E.g., System.loadLibrary(\"c++_shared\"); System.loadLibrary(\"ultratimestretch\");. Using 'c++_static' is often simpler.")
    endif()
endif()

set(CMAKE_CXX_STANDARD 17)

# Point to shared native code
set(NATIVE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../native)

# V1 Sources (from shared)
set(V1_SOURCES
    ${NATIVE_DIR}/src/V1/Engine.cpp
    ${NATIVE_DIR}/src/V1/HybridStretcher.cpp
    ${NATIVE_DIR}/src/V1/PhaseVocoder.cpp
    ${NATIVE_DIR}/src/V1/WSOLAProcessor.cpp
    ${NATIVE_DIR}/src/V1/FFTProcessor.cpp
    ${NATIVE_DIR}/src/V1/TransientDetector.cpp
)

# V2 Sources (from shared)
set(V2_SOURCES
    ${NATIVE_DIR}/src/V2/MultiResolutionPV.cpp
    ${NATIVE_DIR}/src/V2/HarmonicPercussiveSeparator.cpp
    ${NATIVE_DIR}/src/V2/FormantPreserver.cpp
    ${NATIVE_DIR}/src/V2/SpectralPeakInterpolator.cpp
)

# Include directories
include_directories(${NATIVE_DIR}/include)

# Build library
add_library(
    ultratimestretch
    SHARED
    native-lib.cpp          # Platform-specific wrapper
    ${V1_SOURCES}
    ${V2_SOURCES}
)

# NEON for ARM
if(ANDROID_ABI MATCHES "^armeabi-v7a" OR ANDROID_ABI MATCHES "^arm64-v8a")
    target_compile_definitions(ultratimestretch PRIVATE UTS_USE_NEON=1)
    if(ANDROID_ABI MATCHES "^armeabi-v7a")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon")
    endif()
endif()

# Link libraries
find_library(log-lib log)
target_link_libraries(ultratimestretch ${log-lib})