// lib/features/tts/cache/tts_cache.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Cache audio TTS đã tải về
/// Lưu file MP3 trên disk, tránh tải lại
class TtsCache {
  static final TtsCache _instance = TtsCache._();
  factory TtsCache() => _instance;
  TtsCache._();

  String? _cacheDir;

  Future<String> get _cachePath async {
    if (_cacheDir != null) return _cacheDir!;

    final dir = await getTemporaryDirectory();
    _cacheDir = '${dir.path}/tts_cache';

    final cacheFolder = Directory(_cacheDir!);
    if (!await cacheFolder.exists()) {
      await cacheFolder.create(recursive: true);
    }

    return _cacheDir!;
  }

  /// Tạo key từ text + language + engine + GIỌNG + tốc độ + cao độ.
  ///
  /// TTS-VOICE-CACHE-001 (audit 1.g — "chọn giọng nam mà giọng nữ đọc"):
  /// key cũ chỉ gồm engine+ngôn ngữ+chữ ⇒ một file audio đọc bằng giọng
  /// mặc định (nữ) có thể được phát lại cho MỌI giọng của cùng ngôn ngữ.
  /// Giọng/tốc độ/cao độ là một phần danh tính của bản ghi nên phải nằm
  /// trong key.
  @visibleForTesting
  static String makeKey(
    String text,
    String language,
    String engineId, {
    String? voiceId,
    double speed = 1.0,
    double pitch = 1.0,
  }) {
    final voice = (voiceId ?? '').trim().isEmpty ? 'default' : voiceId!.trim();
    final input = '${engineId}_${language}_${voice}_'
        '${speed.toStringAsFixed(2)}_${pitch.toStringAsFixed(2)}_$text';
    return md5.convert(utf8.encode(input)).toString();
  }

  /// Lưu audio vào cache
  Future<String> put({
    required String text,
    required String language,
    required String engineId,
    required Uint8List audioData,
    String? voiceId,
    double speed = 1.0,
    double pitch = 1.0,
  }) async {
    final key = makeKey(
      text,
      language,
      engineId,
      voiceId: voiceId,
      speed: speed,
      pitch: pitch,
    );
    final path = '${await _cachePath}/$key.mp3';

    final file = File(path);
    await file.writeAsBytes(audioData);

    debugPrint(
        '💾 TTS Cache saved: ${text.substring(0, text.length.clamp(0, 30))}...');
    return path;
  }

  /// Lấy audio từ cache
  Future<String?> get({
    required String text,
    required String language,
    required String engineId,
    String? voiceId,
    double speed = 1.0,
    double pitch = 1.0,
  }) async {
    final key = makeKey(
      text,
      language,
      engineId,
      voiceId: voiceId,
      speed: speed,
      pitch: pitch,
    );
    final path = '${await _cachePath}/$key.mp3';

    final file = File(path);
    if (await file.exists() && await file.length() > 100) {
      debugPrint(
          '💾 TTS Cache HIT: ${text.substring(0, text.length.clamp(0, 30))}...');
      return path;
    }

    return null;
  }

  /// Xóa cache
  Future<void> clear() async {
    final dir = Directory(await _cachePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
    }
    debugPrint('🗑️ TTS Cache cleared');
  }

  /// Kích thước cache (MB)
  Future<double> getCacheSizeMB() async {
    final dir = Directory(await _cachePath);
    if (!await dir.exists()) return 0;

    int totalBytes = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes / (1024 * 1024);
  }

  /// Số file trong cache
  Future<int> getCacheCount() async {
    final dir = Directory(await _cachePath);
    if (!await dir.exists()) return 0;

    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File) count++;
    }
    return count;
  }
}
