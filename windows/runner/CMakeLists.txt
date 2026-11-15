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

# AI chat native backend — copy in4up_ai_native.dll cạnh runner.exe (chỉ khi
# target tồn tại, tức là submodule llama.cpp đã được init).
if(TARGET in4up_ai_native)
  add_dependencies(${BINARY_NAME} in4up_ai_native)
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      $<TARGET_FILE:in4up_ai_native>
      $<TARGET_FILE_DIR:${BINARY_NAME}>
    COMMENT "Copy in4up_ai_native.dll next to the Flutter executable"
  )
endif()

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

# Whisper / GGML — COPY CẢ BỘ, không chỉ vài tên cố định.
#
# WHISPER-CLI-WIN-001 (audit 1.29.0-Beta): danh sách cũ chỉ có
# `ggml.dll, whisper.dll, libwhisper.dll, ggml-base.dll, ggml-cpu.dll` nên
# THIẾU hai thứ làm `whisper-cli.exe` không nạp được trên máy người dùng:
#   • `ggml-cpu-<variant>.dll` — bản release x64 build với
#     `-DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON` (mỗi tập lệnh CPU một
#     file; không có `ggml-cpu.dll` trơn);
#   • `SDL2.dll` (bản release chính thức có nó).
# Triệu chứng: `exit -1073741515` (0xC0000135) + STDOUT/STDERR RỖNG — loader
# Windows chết TRƯỚC main() nên Dart không đọc được lỗi nào.
#
# Nay quét mọi `*.dll`/`*.exe` trong `libs/` và `libs/whisper/`. Việc chọn
# đúng file nào là của bộ chạy nằm ở phía Dart (WhisperRuntimeInstaller).
file(GLOB _WHISPER_ALL "${DLL_SOURCE_DIR}/*.dll" "${DLL_SOURCE_DIR}/*.exe"
                       "${DLL_SOURCE_DIR}/whisper/*.dll" "${DLL_SOURCE_DIR}/whisper/*.exe")

# Chép ngay cạnh in4up.exe ở chế độ Debug/`flutter run` (đường MSI/NSIS do
# `install(...)` ở windows/CMakeLists.txt lo). Bắt buộc phải CÙNG thư mục với
# .exe: ggml backend loader tìm DLL theo thư mục chứa .exe trước rồi mới tới
# CWD — đây là lý do bản chép vào `build/windows/.../Debug` chạy được còn bản
# để trong `windows/libs` thì không.
if(_WHISPER_ALL)
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      ${_WHISPER_ALL}
      "$<TARGET_FILE_DIR:${BINARY_NAME}>"
    COMMENT "[in4up] Copy Whisper runtime next to the executable"
  )
endif()

# FFmpeg exe for desktop fallback (AudioConverter uses Process.run)
foreach(_EXE ffmpeg.exe ffprobe.exe)
  if(EXISTS "${DLL_SOURCE_DIR}/${_EXE}")
    copy_if_exists("${DLL_SOURCE_DIR}/${_EXE}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_EXE}")
  endif()
  if(EXISTS "${DLL_SOURCE_DIR}/ffmpeg/bin/${_EXE}")
    copy_if_exists("${DLL_SOURCE_DIR}/ffmpeg/bin/${_EXE}" "$<TARGET_FILE_DIR:${BINARY_NAME}>/${_EXE}")
  endif()
endforeach()
