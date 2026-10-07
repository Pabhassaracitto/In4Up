// lib/features/tts/cache/tts_cache.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Cache audio TTS đã tải về
/// Lưu file MP3 trên disk, tránh tải lại
class TtsCache {
  static final TtsCache _instance = TtsCache._();
  factory TtsCache() => _instance;
  TtsCache._();

  /// Phiên bản công thức khoá cache. TĂNG số này mỗi khi [makeKey] đổi.
  ///
  /// TTS-VOICE-CACHE-002 (audit 1.g): bản 1 ghi file theo khoá
  /// `engine + ngôn ngữ + chữ` — KHÔNG có giọng, nên bản ghi giọng mặc định
  /// (nữ) nằm lại trên máy người dùng cũ. Khi phiên bản khoá đổi, toàn bộ
  /// thư mục phải bị xoá một lần; nếu không, người dùng đã cập nhật app vẫn
  /// nghe lại giọng sai cho tới khi cache hết hạn theo dung lượng.
  static const int keyVersion = 2;

  /// Khoá SharedPreferences ghi phiên bản khoá đang dùng trên máy này.
  static const String keyVersionPrefsKey = 'tts_cache_key_version';

  String? _cacheDir;

  Future<String> get _cachePath async {
    if (_cacheDir == null) {
      final dir = await getTemporaryDirectory();
      _cacheDir = '${dir.path}/tts_cache';
      await _ensureKeyVersion();
    }

    final cacheFolder = Directory(_cacheDir!);
    if (!await cacheFolder.exists()) {
      await cacheFolder.create(recursive: true);
    }

    return _cacheDir!;
  }

  /// Có phải xoá cache khi phiên bản khoá đã ghi trên máy là [storedVersion]?
  ///
  /// Tách riêng để test thuần (không cần path_provider/plugin): lần đầu chạy
  /// (`null`) coi như khớp — máy mới thì chưa có gì để xoá.
  @visibleForTesting
  static bool shouldWipeForStoredVersion(int? storedVersion) {
    if (storedVersion == null) return false;
    return storedVersion != keyVersion;
  }

  /// Xoá cache một lần khi phiên bản công thức khoá đổi (chạy tối đa 1
  /// lần/tiến trình nhờ [_cachePath] memo hoá).
  Future<void> _ensureKeyVersion() async {
    final dir = _cacheDir;
    if (dir == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(keyVersionPrefsKey);
      if (shouldWipeForStoredVersion(stored)) {
        final folder = Directory(dir);
        if (await folder.exists()) {
          await folder.delete(recursive: true);
        }
        debugPrint(
            '🧹 TTS Cache: phiên bản khoá $stored → $keyVersion — đã xoá cache cũ.');
      }
      if (stored != keyVersion) {
        await prefs.setInt(keyVersionPrefsKey, keyVersion);
      }
      final folder = Directory(dir);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
    } catch (e) {
      // Không có SharedPreferences (test/đời nền) → KHÔNG xoá gì: thà giữ
      // cache cũ còn hơn làm hỏng đường phát âm.
      debugPrint('⚠️ TTS Cache: không kiểm được phiên bản khoá: $e');
    }
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
