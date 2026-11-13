// lib/services/linux_media_backends.dart
//
// PSRC-219 + PSRC-220 (beta 1.29.0, lane L2) — điểm vào DUY NHẤT để cắm
// backend phát media_kit (libmpv) cho Linux.
//
// VÌ SAO CẦN: `just_audio` và `video_player` đều KHÔNG có implementation cho
// Linux trong cây dependency của app (xem `linux/flutter/generated_plugin_
// registrant.cc` trước bản này). Hệ quả: mọi lần phát đều thất bại ở tầng
// plugin (`MissingPluginException` cho âm thanh, `UnimplementedError` cho
// video) — người dùng chỉ thấy "Không phát được bài này" /
// "…UnimplementedError int() has not been implemented".
//
// CÁCH CẮM: hai gói chính thức của media-kit, mỗi gói chỉ ĐỔI BACKEND của
// package gốc (không phải viết lại UI):
//   • `just_audio_media_kit`   → đăng ký `JustAudioPlatform` cho Linux,
//   • `video_player_media_kit` → đăng ký `VideoPlayerPlatform` cho Linux,
//   • `media_kit_libs_linux`   → đánh dấu "native libs available" cho Linux.
//
// CHI PHÍ DUNG LƯỢNG: `media_kit_libs_linux` KHÔNG nhúng libmpv vào bundle
// (xem `linux/CMakeLists.txt` của gói — chỉ bật cờ + link mimalloc tĩnh).
// media_kit `dlopen("libmpv.so.2")` lúc chạy ⇒ bundle chỉ tăng phần Dart +
// plugin nhỏ (~1–3 MB), nhưng MÁY NGƯỜI DÙNG phải có libmpv:
//   Debian/Ubuntu: sudo apt install libmpv2
//   Fedora:        sudo dnf install mpv-libs
//   Arch:          sudo pacman -S mpv
// Không có libmpv ⇒ `install()` trả false và app GIỮ NGUYÊN hành vi cũ (báo
// đúng "máy chưa có bộ phát" + mở bằng trình phát của hệ thống). Muốn zero-
// dependency thì phải nhúng libmpv (~+10–15 MB tarball) — việc của hub.
//
// File này là facade có điều kiện: bản web không kéo `dart:io`/plugin vào.

export 'linux_media_backends_stub.dart'
    if (dart.library.io) 'linux_media_backends_io.dart';
