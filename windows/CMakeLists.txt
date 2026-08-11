# Project-level configuration.
cmake_minimum_required(VERSION 3.14)

# Suppress warnings from dependencies
set(CMAKE_WARN_DEPRECATED OFF CACHE BOOL "" FORCE)

set(CMAKE_POLICY_VERSION_MINIMUM "3.5")
project(in2up LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "in2up")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)
cmake_policy(SET CMP0175 NEW)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Silence experimental coroutine deprecation warnings (was in force_flags.props)
add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)

# Enable parallel compilation for faster builds
if(MSVC)
  add_compile_options(/MP)
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /wd"4100" /wd"4267")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Check if flutter pub get was run - ephemeral dir must exist
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/flutter_windows.dll")
  message(WARNING "[in2up] flutter/ephemeral not found! Run 'flutter pub get' before building. "
    "If you see 'cannot open source file cloud_firestore/...' errors, it's because ephemeral was deleted by flutter clean.")
endif()

add_subdirectory(${FLUTTER_MANAGED_DIR})

# === PATCH: Workaround for broken Windows plugins ===
# Issue: ffmpeg_kit_flutter_new v4.2.1 fails with C1083
#   Cannot open include file: 'include/ffmpeg_kit_flutter_new_full/f_fmpeg_kit_flutter_plugin.h'
# Root cause: old CMake unpacked prebuilt archive into pub-cache symlink (fails on Windows)
#   Fixed in 4.6.2 (commit c83a702) by unpacking into CMAKE_CURRENT_BINARY_DIR.
# Our Dart code already guards ffmpeg_kit to Android/iOS only (AudioConverter._useFFmpegKit),
# so on Windows we can safely REMOVE the plugin from the build. Desktop uses Process.run('ffmpeg').
#
# This patch runs at CMake configure time, before runner and plugins are added:
#  - Removes ffmpeg_kit_flutter_new (+ variants) from generated_plugins.cmake
#  - Removes its #include and RegisterWithRegistrar from generated_plugin_registrant.cc
# If flutter pub get regenerates those files, patch re-applies on next build.
# Also patches webview_windows's deprecated /await flag to /await:strict to silence D9047.

set(_GEN_PLUGINS "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake")
set(_GEN_REGISTRANT "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.cc")
set(_GEN_REGISTRANT_H "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.h")

# --- Patch generated_plugins.cmake ---
if(EXISTS "${_GEN_PLUGINS}")
  file(READ "${_GEN_PLUGINS}" _PLUGINS_CONTENT)
  set(_NEEDS_PATCH FALSE)
  if(_PLUGINS_CONTENT MATCHES "ffmpeg_kit_flutter_new")
    set(_NEEDS_PATCH TRUE)
    message(STATUS "[in2up][patch] Removing ffmpeg_kit_flutter_new from Windows plugin list")
    # Handle all known variants
    foreach(_VARIANT ffmpeg_kit_flutter_new ffmpeg_kit_flutter_new_full ffmpeg_kit_flutter_new_min ffmpeg_kit_flutter_new_min_gpl ffmpeg_kit_flutter_new_https ffmpeg_kit_flutter_new_https_gpl ffmpeg_kit_flutter_new_audio ffmpeg_kit_flutter_new_video ffmpeg_kit_flutter_new_full_gpl)
      string(REPLACE "  ${_VARIANT}\n" "" _PLUGINS_CONTENT "${_PLUGINS_CONTENT}")
      string(REPLACE "  ${_VARIANT}\r\n" "" _PLUGINS_CONTENT "${_PLUGINS_CONTENT}")
    endforeach()
  endif()
  if(_NEEDS_PATCH)
    file(WRITE "${_GEN_PLUGINS}" "${_PLUGINS_CONTENT}")
    message(STATUS "[in2up][patch] Patched ${_GEN_PLUGINS}")
  endif()
endif()

# --- Patch generated_plugin_registrant.cc ---
if(EXISTS "${_GEN_REGISTRANT}")
  file(READ "${_GEN_REGISTRANT}" _REG_CONTENT)
  set(_REG_NEEDS_PATCH FALSE)
  if(_REG_CONTENT MATCHES "ffmpeg_kit_flutter_new" OR _REG_CONTENT MATCHES "FFmpegKitFlutterPlugin")
    set(_REG_NEEDS_PATCH TRUE)
    message(STATUS "[in2up][patch] Removing ffmpeg includes from registrant.cc")
    # Remove #include lines for all variants
    string(REGEX REPLACE "#include <ffmpeg_kit_flutter_new[^>]*>\n" "" _REG_CONTENT "${_REG_CONTENT}")
    string(REGEX REPLACE "#include <ffmpeg_kit_flutter_new_full[^>]*>\n" "" _REG_CONTENT "${_REG_CONTENT}")
    # Remove registration block that spans 2 lines:
    #   FFmpegKitFlutterPluginRegisterWithRegistrar(
    #       registry->GetRegistrarForPlugin("FFmpegKitFlutterPlugin"));
    # Use [^;]*; to span across newlines until semicolon
    string(REGEX REPLACE "[ \t]*FFmpegKitFlutterPluginRegisterWithRegistrar\\([^;]*;[\r\n]*" "" _REG_CONTENT "${_REG_CONTENT}")
    # Fallback: remove any leftover line that still contains FFmpegKitFlutterPlugin (orphaned second line from previous buggy patch)
    string(REGEX REPLACE ".*FFmpegKitFlutterPlugin.*\n" "" _REG_CONTENT "${_REG_CONTENT}")
    string(REGEX REPLACE ".*GetRegistrarForPlugin\\(\"FFmpegKitFlutterPlugin.*\n" "" _REG_CONTENT "${_REG_CONTENT}")
  endif()
  # Also silence webview_windows /await deprecation warning by ensuring
  # we don't inject extra flags here; the fix for /await is in plugin's CMakeLists patch below.
  if(_REG_NEEDS_PATCH)
    file(WRITE "${_GEN_REGISTRANT}" "${_REG_CONTENT}")
    message(STATUS "[in2up][patch] Patched ${_GEN_REGISTRANT}")
  endif()
endif()

# --- Patch webview_windows plugin if present (fix /await -> /await:strict) ---
# The plugin's windows/CMakeLists.txt uses target_compile_options(... "/await") which is deprecated (D9047)
# We try to patch the pub-cache symlink source if writable.
set(_WEBVIEW_CMAKE "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks/webview_windows/windows/CMakeLists.txt")
if(EXISTS "${_WEBVIEW_CMAKE}")
  file(READ "${_WEBVIEW_CMAKE}" _WEBVIEW_CONTENT)
  if(_WEBVIEW_CONTENT MATCHES "\"/await\"")
    message(STATUS "[in2up][patch] Fixing webview_windows /await -> /await:strict")
    string(REPLACE "\"/await\"" "\"/await:strict\"" _WEBVIEW_CONTENT "${_WEBVIEW_CONTENT}")
    # Write back if we can (may fail if pub-cache read-only, ignore error)
    file(WRITE "${_WEBVIEW_CMAKE}" "${_WEBVIEW_CONTENT}")
  endif()
endif()

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# --- Post-include: Remove /await flag from target if it still exists ---
# This handles cases where webview_windows CMakeLists couldn't be patched on disk
# (read-only pub cache). We strip the flag from the target compile options.
if(TARGET webview_windows_plugin)
  get_target_property(_WV_OPTS webview_windows_plugin COMPILE_OPTIONS)
  if(_WV_OPTS)
    list(REMOVE_ITEM _WV_OPTS "/await")
    # Ensure /await:strict is present for coroutine support
    list(FIND _WV_OPTS "/await:strict" _IDX)
    if(_IDX EQUAL -1)
      list(APPEND _WV_OPTS "/await:strict")
    endif()
    set_target_properties(webview_windows_plugin PROPERTIES COMPILE_OPTIONS "${_WV_OPTS}")
    message(STATUS "[in2up][patch] Adjusted webview_windows_plugin compile options: ${_WV_OPTS}")
  endif()
endif()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# === Manual Firebase SDK Management ===
set(FIREBASE_SDK_DIR "$ENV{FIREBASE_CPP_SDK_DIR}")
file(TO_CMAKE_PATH "${FIREBASE_SDK_DIR}" FIREBASE_SDK_DIR)

if(FIREBASE_SDK_DIR)
  message(STATUS "[in2up] FIREBASE_CPP_SDK_DIR found: ${FIREBASE_SDK_DIR}")
else()
  message(STATUS "[in2up] FIREBASE_CPP_SDK_DIR is NOT set.")
endif()

# === Quản lý Firebase SDK (Manual) ===
if(FIREBASE_SDK_DIR AND EXISTS "${FIREBASE_SDK_DIR}")
    file(GLOB_RECURSE FIREBASE_LIBS "${FIREBASE_SDK_DIR}/*.lib")
    if(FIREBASE_LIBS)
        message(STATUS "[in2up] Firebase Static Libs validated.")
        file(GLOB_RECURSE FIREBASE_DLLS "${FIREBASE_SDK_DIR}/*.dll")
        if(FIREBASE_DLLS)
            install(FILES ${FIREBASE_DLLS} DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
            # Lưu ý: add_custom_command cho Firebase DLLs cũng nên dời vào runner nếu cần chạy debug
        endif()
    endif()
endif()

# === Manual External DLLs Management (Whisper, FFmpeg, etc.) ===
file(GLOB EXTRA_DLLS "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.dll")
if(EXTRA_DLLS)
    message(STATUS "[in2up] Found extra DLLs in libs/: ${EXTRA_DLLS}")
    install(FILES ${EXTRA_DLLS} DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Also bundle FFmpeg exe if present (for desktop audio conversion fallback)
file(GLOB EXTRA_EXES "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.exe")
if(EXTRA_EXES)
    message(STATUS "[in2up] Found extra EXEs in libs/: ${EXTRA_EXES}")
    install(FILES ${EXTRA_EXES} DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Bundle Whisper binaries (ggml*.dll, whisper.dll) + ffmpeg.exe presence check
file(GLOB WHISPER_BINS "${CMAKE_CURRENT_SOURCE_DIR}/libs/whisper/*.exe" "${CMAKE_CURRENT_SOURCE_DIR}/libs/whisper/*.dll")
if(WHISPER_BINS)
    message(STATUS "[in2up] Found Whisper binaries: ${WHISPER_BINS}")
    install(FILES ${WHISPER_BINS} DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()