// lib/features/media_tools/services/whisper_runtime_bootstrap.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — NỐI "bộ chạy Whisper" vào đường
// tìm binary của `in4up_stt`.
//
// Vì sao cần file này (chứ không nhét vào `in4up_stt`):
//   `in4up_stt` KHÔNG phụ thuộc `path_provider`/`StorageService` (giữ đúng
//   pubspec của package). Nhưng engine cần biết "app đã cài bộ chạy vào
//   documents/whisper_runtime chưa". ⇒ App bơm đường dẫn vào bằng
//   `WhisperRuntimeRegistry.register(...)` và ghi nhớ trong `StorageService`.
//
// Gọi 1 lần trong `main()` SAU `StorageService.initialize()`:
//   `await WhisperRuntimeBootstrap.init();`

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/utils/src/whisper_cli_locator.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/storage_service.dart';

class WhisperRuntimeBootstrap {
  WhisperRuntimeBootstrap._();

  /// Key trong settings box — cố ý trùng tên biến môi trường để dễ tra.
  static const String settingKey = 'whisper_runtime_path';

  static bool _initialized = false;

  /// Đường dẫn binary đã biết (null = chưa cài hoặc chưa dò).
  static String? get knownPath {
    final stored = StorageService().getSetting<String>(settingKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return WhisperRuntimeRegistry.registeredBinaryPath;
  }

  /// Đăng ký gợi ý + đường dẫn đã lưu. An toàn khi gọi nhiều lần.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Bơm thư mục chuẩn ĐỒNG BỘ: locator là hàm sync ⇒ gợi ý phải trả
    //    ngay. Chỉ là đường dẫn; locator tự kiểm file có thật không.
    WhisperRuntimeRegistry.register(
      directoryHint: () => _cachedDocumentsFallback,
      dllDirs: const <String>[],
    );

    final stored = StorageService().getSetting<String>(settingKey);
    if (stored != null && stored.isNotEmpty) {
      WhisperRuntimeRegistry.register(binaryPath: stored);
    }

    // 2. Dò thư mục chuẩn 1 lần (rẻ — chỉ stat file) để lần đầu chạy app
    //    không phải chờ người dùng bấm gì.
    unawaited(_probeStandardLocation());

    debugPrint('[Whisper] Runtime bootstrap: ${knownPath ?? "(chưa cài)"}');
  }

  static String? _cachedDocumentsFallback;

  static Future<void> _probeStandardLocation() async {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}${Platform.pathSeparator}whisper_runtime');
      _cachedDocumentsFallback = dir.path;
      if (!await dir.exists()) return;

      final exeName = Platform.isWindows ? 'whisper-cli.exe' : 'whisper-cli';
      final exe = dir.path + Platform.pathSeparator + exeName;
      if (!await File(exe).exists()) return;
      final probe = probeWhisperBinaryOnDisk(exe);
      debugPrint('[Whisper] Bộ chạy đã cài: ${probe.summary}');
      if (probe.isRunnable) {
        WhisperRuntimeRegistry.register(
          binaryPath: exe,
          dllDirs: <String>[dir.path],
        );
      }
    } catch (e) {
      debugPrint('[Whisper] probeStandardLocation error: $e');
    }
  }

  /// Ghi nhớ bộ chạy đã cài (gọi sau khi tải xong, hoặc khi người dùng trỏ tay).
  static Future<void> rememberInstalled(String binaryPath) async {
    await StorageService().saveSetting(settingKey, binaryPath);
    WhisperRuntimeRegistry.register(
      binaryPath: binaryPath,
      dllDirs: <String>[File(binaryPath).parent.path],
    );
    WhisperCliLocator.invalidateCache();
    debugPrint('[Whisper] Đã đăng ký bộ chạy: $binaryPath');
  }

  /// Quên bộ chạy (khi người dùng xoá hoặc file không còn).
  static Future<void> forget() async {
    await StorageService().saveSetting(settingKey, '');
    WhisperRuntimeRegistry.register(binaryPath: '', dllDirs: const <String>[]);
    WhisperCliLocator.invalidateCache();
  }
}
