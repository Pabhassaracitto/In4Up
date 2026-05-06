cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

apply_standard_settings(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

add_subdirectory("native")
target_link_libraries(${BINARY_NAME} PRIVATE ultratimestretch)

# Copy DLLs post-build
file(GLOB EXTRA_DLLS "${CMAKE_CURRENT_SOURCE_DIR}/../libs/*.dll")
foreach(DLL ${EXTRA_DLLS})
  add_custom_command(
    TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${DLL}"
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/"
    VERBATIM
  )
endforeach()

# Copy ffmpeg.exe
set(FFMPEG_EXE_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../libs/ffmpeg.exe")
if(EXISTS "${FFMPEG_EXE_SRC}")
  add_custom_command(
    TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${FFMPEG_EXE_SRC}"
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/ffmpeg.exe"
    VERBATIM
  )
  message(STATUS "[Runner] Will copy ffmpeg.exe post-build")
endif()