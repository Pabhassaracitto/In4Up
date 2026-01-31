cmake_minimum_required(VERSION 3.10)
project(UltraTimeStretch VERSION 2.0.0 LANGUAGES CXX)

# ═══════════════════════════════════════════════════════════════════════════
# PROJECT CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build options
option(BUILD_V1 "Build V1 engine (faster, lower quality)" ON)
option(BUILD_V2 "Build V2 engine (slower, higher quality)" ON)
option(BUILD_SHARED "Build shared library" ON)
option(BUILD_EXAMPLES "Build example programs" OFF)
option(BUILD_BENCHMARK "Build benchmark program" OFF)
option(ENABLE_SIMD "Enable SIMD optimizations (NEON/SSE/AVX)" ON)

# Platform detection
if(ANDROID)
    message(STATUS "Building for Android")
    set(PLATFORM_ANDROID ON)
elseif(WIN32)
    message(STATUS "Building for Windows")
    set(PLATFORM_WINDOWS ON)
elseif(UNIX AND NOT APPLE)
    message(STATUS "Building for Linux")
    set(PLATFORM_LINUX ON)
elseif(APPLE)
    message(STATUS "Building for macOS/iOS")
    set(PLATFORM_APPLE ON)
endif()

# ═══════════════════════════════════════════════════════════════════════════
# SIMD DETECTION AND FLAGS
# ═══════════════════════════════════════════════════════════════════════════

if(ENABLE_SIMD)
    # ARM NEON (Android, iOS, ARM Linux)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm" OR 
       CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" OR
       ANDROID_ABI MATCHES "armeabi-v7a" OR
       ANDROID_ABI MATCHES "arm64-v8a")
        
        message(STATUS "Enabling ARM NEON optimizations")
        add_definitions(-DUTS_USE_NEON=1)
        
        if(ANDROID)
            # Android NDK
            if(ANDROID_ABI STREQUAL "armeabi-v7a")
                set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon -mfloat-abi=softfp")
            elseif(ANDROID_ABI STREQUAL "arm64-v8a")
                # NEON is default for arm64
                set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
            endif()
        else()
            # Linux ARM or iOS
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon")
        endif()
        
    # x86/x64 SSE/AVX (Windows, Linux, macOS)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64" OR 
           CMAKE_SYSTEM_PROCESSOR MATCHES "AMD64" OR
           CMAKE_SYSTEM_PROCESSOR MATCHES "i686")
        
        message(STATUS "Enabling SSE/AVX optimizations")
        add_definitions(-DUTS_USE_SSE=1)
        
        if(MSVC)
            # Windows MSVC
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /arch:AVX2")
        else()
            # GCC/Clang
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -msse2 -msse3 -mavx")
            
            # Try AVX2 if supported
            include(CheckCXXCompilerFlag)
            CHECK_CXX_COMPILER_FLAG("-mavx2" COMPILER_SUPPORTS_AVX2)
            if(COMPILER_SUPPORTS_AVX2)
                set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mavx2")
                message(STATUS "AVX2 support enabled")
            endif()
        endif()
    else()
        message(WARNING "Unknown processor: ${CMAKE_SYSTEM_PROCESSOR}, SIMD disabled")
        set(ENABLE_SIMD OFF)
    endif()
else()
    message(STATUS "SIMD optimizations disabled")
endif()

# ═══════════════════════════════════════════════════════════════════════════
# COMPILER FLAGS
# ═══════════════════════════════════════════════════════════════════════════

if(MSVC)
    # Windows MSVC
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W4 /MP")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /O2 /Ob2 /GL")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /Od /Zi")
    
    # Disable specific warnings
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
else()
    # GCC/Clang (Linux, Android, macOS)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -ffast-math")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0 -g")
endif()

# ═══════════════════════════════════════════════════════════════════════════
# SOURCE FILES
# ═══════════════════════════════════════════════════════════════════════════

# V1 Core Sources
set(V1_SOURCES
    src/V1/Engine.cpp
    src/V1/HybridStretcher.cpp
    src/V1/PhaseVocoder.cpp
    src/V1/WSOLAProcessor.cpp
    src/V1/FFTProcessor.cpp
    src/V1/TransientDetector.cpp
)

# V2 Enhancement Sources
set(V2_SOURCES
    src/V2/MultiResolutionPV.cpp
    src/V2/HarmonicPercussiveSeparator.cpp
    src/V2/FormantPreserver.cpp
    src/V2/SpectralPeakInterpolator.cpp
)

# Optional: Enhanced V1 files for V2
set(V2_ENHANCED_SOURCES
    src/V2/HybridStretcher_V2.cpp
    src/V2/PhaseVocoder_Enhanced.cpp
)

# Headers
set(HEADERS
    include/UltraTimeStretch.h
    include/SIMDOptimizations.h
)

if(BUILD_V2)
    list(APPEND HEADERS include/UltraTimeStretch_V2_Enhancements.h)
endif()

# ═══════════════════════════════════════════════════════════════════════════
# LIBRARY TARGETS
# ═══════════════════════════════════════════════════════════════════════════

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# ───────────────────────────────────────────────────────────────────────────
# V1 Library (Standard Quality, Fast)
# ───────────────────────────────────────────────────────────────────────────
if(BUILD_V1)
    if(BUILD_SHARED)
        add_library(UltraTimeStretch_V1 SHARED ${V1_SOURCES} ${HEADERS})
    else()
        add_library(UltraTimeStretch_V1 STATIC ${V1_SOURCES} ${HEADERS})
    endif()
    
    target_include_directories(UltraTimeStretch_V1 PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    )
    
    set_target_properties(UltraTimeStretch_V1 PROPERTIES
        OUTPUT_NAME "UltraTimeStretch_V1"
        VERSION ${PROJECT_VERSION}
        SOVERSION 1
    )
    
    message(STATUS "V1 Library: UltraTimeStretch_V1")
endif()

# ───────────────────────────────────────────────────────────────────────────
# V2 Library (Ultra Quality, Slower)
# ───────────────────────────────────────────────────────────────────────────
if(BUILD_V2)
    # V2 includes all V1 sources + V2 enhancements
    set(V2_ALL_SOURCES ${V1_SOURCES} ${V2_SOURCES})
    
    if(BUILD_SHARED)
        add_library(UltraTimeStretch_V2 SHARED ${V2_ALL_SOURCES} ${HEADERS})
    else()
        add_library(UltraTimeStretch_V2 STATIC ${V2_ALL_SOURCES} ${HEADERS})
    endif()
    
    target_include_directories(UltraTimeStretch_V2 PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    )
    
    set_target_properties(UltraTimeStretch_V2 PROPERTIES
        OUTPUT_NAME "UltraTimeStretch_V2"
        VERSION ${PROJECT_VERSION}
        SOVERSION 2
    )
    
    message(STATUS "V2 Library: UltraTimeStretch_V2")
endif()

# ═══════════════════════════════════════════════════════════════════════════
# EXAMPLE PROGRAMS
# ═══════════════════════════════════════════════════════════════════════════

if(BUILD_EXAMPLES)
    # Example V1
    if(BUILD_V1)
        add_executable(Example_V1 examples/Example.cpp)
        target_link_libraries(Example_V1 PRIVATE UltraTimeStretch_V1)
        
        if(PLATFORM_WINDOWS)
            # Windows-specific settings
            set_target_properties(Example_V1 PROPERTIES
                WIN32_EXECUTABLE FALSE  # Console application
            )
        endif()
        
        message(STATUS "Example V1: Example_V1")
    endif()
    
    # Example V2
    if(BUILD_V2)
        add_executable(Example_V2 examples/Example_V2.cpp)
        target_link_libraries(Example_V2 PRIVATE UltraTimeStretch_V2)
        
        if(PLATFORM_WINDOWS)
            set_target_properties(Example_V2 PROPERTIES
                WIN32_EXECUTABLE FALSE
            )
        endif()
        
        message(STATUS "Example V2: Example_V2")
    endif()
endif()

# ═══════════════════════════════════════════════════════════════════════════
# BENCHMARK PROGRAM
# ═══════════════════════════════════════════════════════════════════════════

if(BUILD_BENCHMARK AND BUILD_V1 AND BUILD_V2)
    add_executable(Benchmark benchmarks/Benchmark_V1_vs_V2.cpp)
    target_link_libraries(Benchmark PRIVATE UltraTimeStretch_V2)
    
    if(PLATFORM_WINDOWS)
        set_target_properties(Benchmark PROPERTIES
            WIN32_EXECUTABLE FALSE
        )
    endif()
    
    message(STATUS "Benchmark: Benchmark")
endif()

# ═══════════════════════════════════════════════════════════════════════════
# ANDROID-SPECIFIC CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

if(ANDROID)
    # Link Android libraries
    find_library(log-lib log)
    find_library(android-lib android)
    
    if(BUILD_V1)
        target_link_libraries(UltraTimeStretch_V1 PUBLIC ${log-lib} ${android-lib})
    endif()
    
    if(BUILD_V2)
        target_link_libraries(UltraTimeStretch_V2 PUBLIC ${log-lib} ${android-lib})
    endif()
    
    # Android logging
    add_definitions(-DANDROID_LOG_TAG="UltraTimeStretch")
    
    message(STATUS "Android ABI: ${ANDROID_ABI}")
    message(STATUS "Android API Level: ${ANDROID_PLATFORM}")
endif()

# ═══════════════════════════════════════════════════════════════════════════
# WINDOWS-SPECIFIC CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

if(PLATFORM_WINDOWS)
    # Add Windows-specific libraries if needed
    # (Currently none required for this project)
    
    # Set runtime library (MT for static, MD for dynamic)
    if(NOT BUILD_SHARED)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
    
    # Export symbols for DLL
    if(BUILD_SHARED)
        if(BUILD_V1)
            target_compile_definitions(UltraTimeStretch_V1 PRIVATE UTS_EXPORTS)
        endif()
        if(BUILD_V2)
            target_compile_definitions(UltraTimeStretch_V2 PRIVATE UTS_EXPORTS)
        endif()
    endif()
endif()

# ═══════════════════════════════════════════════════════════════════════════
# INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════

# Install libraries
if(BUILD_V1)
    install(TARGETS UltraTimeStretch_V1
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
    )
endif()

if(BUILD_V2)
    install(TARGETS UltraTimeStretch_V2
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
    )
endif()

# Install headers
install(FILES ${HEADERS}
    DESTINATION include/UltraTimeStretch
)

# Install examples (optional)
if(BUILD_EXAMPLES)
    if(BUILD_V1)
        install(TARGETS Example_V1 DESTINATION bin)
    endif()
    if(BUILD_V2)
        install(TARGETS Example_V2 DESTINATION bin)
    endif()
endif()

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

message(STATUS "")
message(STATUS "╔════════════════════════════════════════════════════════════╗")
message(STATUS "║       UltraTimeStretch Build Configuration Summary        ║")
message(STATUS "╚════════════════════════════════════════════════════════════╝")
message(STATUS "")
message(STATUS "Platform:          ${CMAKE_SYSTEM_NAME} (${CMAKE_SYSTEM_PROCESSOR})")
message(STATUS "Build Type:        ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ Compiler:      ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "")
message(STATUS "Options:")
message(STATUS "  BUILD_V1:        ${BUILD_V1}")
message(STATUS "  BUILD_V2:        ${BUILD_V2}")
message(STATUS "  BUILD_SHARED:    ${BUILD_SHARED}")
message(STATUS "  BUILD_EXAMPLES:  ${BUILD_EXAMPLES}")
message(STATUS "  BUILD_BENCHMARK: ${BUILD_BENCHMARK}")
message(STATUS "  ENABLE_SIMD:     ${ENABLE_SIMD}")
message(STATUS "")

if(ANDROID)
    message(STATUS "Android Configuration:")
    message(STATUS "  ABI:             ${ANDROID_ABI}")
    message(STATUS "  API Level:       ${ANDROID_PLATFORM}")
    message(STATUS "  STL:             ${ANDROID_STL}")
endif()

message(STATUS "")
message(STATUS "Libraries to build:")
if(BUILD_V1)
    message(STATUS "  ✓ UltraTimeStretch_V1 (Standard Quality)")
endif()
if(BUILD_V2)
    message(STATUS "  ✓ UltraTimeStretch_V2 (Ultra Quality)")
endif()

message(STATUS "")
message(STATUS "Executables to build:")
if(BUILD_EXAMPLES)
    if(BUILD_V1)
        message(STATUS "  ✓ Example_V1")
    endif()
    if(BUILD_V2)
        message(STATUS "  ✓ Example_V2")
    endif()
endif()
if(BUILD_BENCHMARK AND BUILD_V1 AND BUILD_V2)
    message(STATUS "  ✓ Benchmark")
endif()

message(STATUS "")
message(STATUS "╚════════════════════════════════════════════════════════════╝")
message(STATUS "")
