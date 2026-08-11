cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
# Add this line to existing CMakeLists.txt
add_subdirectory(native)
# Copy ultratimestretch.dll cạnh runner.exe sau mỗi lần build
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    $<TARGET_FILE:ultratimestretch>
    $<TARGET_FILE_DIR:${BINARY_NAME}>
)

# Copy Whisper & GGML DLLs từ windows/libs/ sang thư mục build cạnh file .exe
# Support both flat libs/ and libs/whisper/ layouts, plus ffmpeg.exe fallback for desktop STT/audio conversion
set(DLL_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../libs")

# Helper function to copy if exists (avoid CMake error when file missing)
function(copy_if_exists SRC DST)
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${SRC}"
      "${DST}"
    COMMENT "Copy ${SRC} -> ${DST} (if exists)"
  )
endfunction()

# Whisper / GGML — try multiple possible names
foreach(_DLL ggml.dll whisper.dll libwhisper.dll ggml-base.dll ggml-cpu.dll)
  if(EXISTS "${DLL_SOURCE_DIR}/${_DLL}")
    copy_if_exists("${DLL_SOURCE_DIR}/${_DLL}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_DLL}")
  endif()
  if(EXISTS "${DLL_SOURCE_DIR}/whisper/${_DLL}")
    copy_if_exists("${DLL_SOURCE_DIR}/whisper/${_DLL}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_DLL}")
  endif()
endforeach()

# FFmpeg exe for desktop fallback (AudioConverter uses Process.run)
foreach(_EXE ffmpeg.exe ffprobe.exe whisper.exe)
  if(EXISTS "${DLL_SOURCE_DIR}/${_EXE}")
    copy_if_exists("${DLL_SOURCE_DIR}/${_EXE}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_EXE}")
  endif()
  if(EXISTS "${DLL_SOURCE_DIR}/ffmpeg/bin/${_EXE}")
    copy_if_exists("${DLL_SOURCE_DIR}/ffmpeg/bin/${_EXE}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_EXE}")
  endif()
endforeach()

# Fallback: copy all dlls/exes from libs/ (already handled in top-level install, but for run in place)
file(GLOB _ALL_DLLS "${DLL_SOURCE_DIR}/*.dll")
foreach(_F ${_ALL_DLLS})
  get_filename_component(_FN ${_F} NAME)
  copy_if_exists("${_F}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_FN}")
endforeach()
file(GLOB _ALL_EXES "${DLL_SOURCE_DIR}/*.exe")
foreach(_F ${_ALL_EXES})
  get_filename_component(_FN ${_F} NAME)
  copy_if_exists("${_F}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_FN}")
endforeach()