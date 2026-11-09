// lib/features/media_tools/services/ffmpeg_runtime_bootstrap.dart
//
// AVTOOL-002 (PLAN-047 P1) — NỐI "FFmpeg tải về" vào đường tìm binary.
//
// Vì sao cần file này (chứ không nhét vào `in4up_stt`):
//   `in4up_stt` KHÔNG phụ thuộc `path_provider`/`hive` (xem pubspec của package).
//   Nhưng nó cần biết "app đã tải ffmpeg vào documents/ffmpeg_runtime chưa".
//   ⇒ App bơm gợi ý vào bằng `FfmpegRunner.setBinaryHintProvider`, và ghi nhớ
//   đường dẫn đã cài trong `StorageService` (settings box, key
//   `ffmpeg_runtime_path`) để khỏi dò lại mỗi lần khởi động.
//
// Gọi 1 lần trong `main()` SAU `StorageService.initialize()`:
//   `await FfmpegRuntimeBootstrap.init();`

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/utils/src/ffmpeg_runner.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/storage_service.dart';

class FfmpegRuntimeBootstrap {
  FfmpegRuntimeBootstrap._();

  /// Key trong settings box — cố ý trùng tên với biến môi trường để dễ tra.
  static const String settingKey = 'ffmpeg_runtime_path';

  static bool _initialized = false;

  /// Đường dẫn đã biết (null = chưa cài hoặc chưa dò).
  static String? get knownPath {
    final stored = StorageService().getSetting<String>(settingKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return FfmpegRunner.registeredBinaryPath;
  }

  /// Đăng ký gợi ý + đường dẫn đã lưu. An toàn khi gọi nhiều lần.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final stored = StorageService().getSetting<String>(settingKey);

    // 1. Bơm gợi ý ĐỒNG BỘ: `findFfmpegBinary()` là hàm sync (nhiều caller cũ),
    //    nên gợi ý phải trả ngay — dùng giá trị đã lưu, không await ở đây.
    FfmpegRunner.setBinaryHintProvider(() {
      final saved = StorageService().getSetting<String>(settingKey);
      if (saved != null && saved.isNotEmpty) return saved;
      // Chưa có trong settings (lần đầu): trả về thư mục chuẩn để locator tự
      // kiểm `bin/ffmpeg.exe` bên trong nếu người dùng đã copy tay vào.
      return _cachedDocumentsFallback;
    });

    if (stored != null && stored.isNotEmpty) {
      FfmpegRunner.registerBinary(stored);
    } else {
      // Lần đầu chạy: dò thư mục chuẩn 1 lần (rẻ — chỉ stat file).
      unawaited(_probeStandardLocation());
    }

    debugPrint('[MediaTools] FFmpeg runtime bootstrap: '
        '${knownPath ?? "(chưa cài)"}');
  }

  static String? _cachedDocumentsFallback;

  /// Dò `documents/ffmpeg_runtime` rồi ghi nhớ nếu thấy binary chạy được.
  static Future<void> _probeStandardLocation() async {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}${Platform.pathSeparator}ffmpeg_runtime');
      _cachedDocumentsFallback = dir.path;
      if (!await dir.exists()) return;

      final exe = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final candidates = <File>[File('${dir.path}${Platform.pathSeparator}$exe')];
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          candidates.add(
            File('${entity.path}${Platform.pathSeparator}bin'
                '${Platform.pathSeparator}$exe'),
          );
        }
      }
      for (final file in candidates) {
        if (!await file.exists()) continue;
        final result = await Process.run(file.path, ['-version'])
            .timeout(const Duration(seconds: 6));
        if (result.exitCode == 0) {
          await rememberInstalled(file.path);
          return;
        }
      }
    } catch (e) {
      debugPrint('[MediaTools] probeStandardLocation error: $e');
    }
  }

  /// Ghi nhớ binary đã cài (gọi sau khi tải xong, hoặc khi người dùng trỏ tay).
  static Future<void> rememberInstalled(String executablePath) async {
    await StorageService().saveSetting(settingKey, executablePath);
    FfmpegRunner.registerBinary(executablePath);
    FfmpegRunner.resetAvailabilityCache();
  }

  /// Quên binary (khi người dùng xoá hoặc file không còn).
  static Future<void> forget() async {
    await StorageService().saveSetting(settingKey, '');
    FfmpegRunner.registerBinary(null);
    FfmpegRunner.resetAvailabilityCache();
  }
}
