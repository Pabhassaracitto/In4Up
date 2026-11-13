// lib/core/platform/system_tts/system_tts_entrypoint.dart
//
// PSRC-221 — điểm vào Dart của ENGINE NỀN mà `In4UpTtsService` (Kotlin) khởi:
// `DartEntrypoint(bundle,
//   "package:in4up/core/platform/system_tts/system_tts_entrypoint.dart",
//   "in4upSystemTtsMain")`.
//
// Vì sao engine RIÊNG: Android bind service giọng đọc khi một app KHÁC cần
// đọc — lúc đó UI của in4up thường không chạy, engine UI không tồn tại. Cùng
// lý do và cùng cách làm với `screen_translate_entrypoint.dart` (ADR-0011).
//
// `lib/main.dart` PHẢI import file này: engine phụ tra entrypoint trong CÙNG
// snapshot, không import thì bản release báo "library not found".
//
// KHÔNG nạp model ở đây: chỉ quét đĩa lấy danh sách giọng. Model được nạp khi
// có yêu cầu đọc đầu tiên.

import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'system_tts_backends.dart';
import 'system_tts_worker.dart';

/// Giữ tham chiếu để worker không bị GC khi `main` kết thúc.
SystemTtsWorker? systemTtsWorker;

@pragma('vm:entry-point')
Future<void> in4upSystemTtsMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Plugin phía Dart (path_provider, shared_preferences) — gọi lại vô hại.
  DartPluginRegistrant.ensureInitialized();
  final worker = SystemTtsWorker(
    backends: <SystemTtsBackend>[
      // Thứ tự = thứ tự ưu tiên khi hai engine cùng có giọng một ngôn ngữ.
      PiperSystemTtsBackend(),
      VieneuSystemTtsBackend(),
    ],
  );
  systemTtsWorker = worker;
  await worker.attach();
}
