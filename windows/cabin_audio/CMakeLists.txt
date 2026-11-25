cmake_minimum_required(VERSION 3.14)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(in4up_cabin_audio LANGUAGES CXX)
endif()

add_library(in4up_cabin_audio SHARED cabin_loopback.cpp cabin_overlay.cpp)
target_compile_features(in4up_cabin_audio PRIVATE cxx_std_17)
target_compile_options(in4up_cabin_audio PRIVATE /EHsc)
target_link_libraries(in4up_cabin_audio PRIVATE ole32 user32 gdi32)

# Standalone Windows CI checks compilation and the exported ABI without a device.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  enable_testing()
  add_executable(cabin_loopback_abi_smoke abi_smoke_test.cpp)
  add_test(NAME cabin_loopback_abi
    COMMAND cabin_loopback_abi_smoke $<TARGET_FILE:in4up_cabin_audio>)
endif()
