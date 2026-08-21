// in4up v11.0 — Helper tạo AudioFingerprint tại call site

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class AudioFingerprintUtil {
  AudioFingerprintUtil._();

  /// Tạo fingerprint offline, rẻ, ổn định
  ///
  /// Gọi tại: PlayerProvider.generateLrcForCurrentAudio()
  /// TRƯỚC khi tạo SttResult
  ///
  /// Fallback: chỉ dùng basename nếu không đọc được file size
  static Future<String> compute({
    required String audioPath,
    required int durationMs,
  }) async {
    try {
      final file = File(audioPath);
      final size = await file.length();
      final base =
          audioPath.replaceAll("\\", "/").split('/').last.toLowerCase();
      final raw = '$size|$durationMs|$base';
      return md5.convert(utf8.encode(raw)).toString().substring(0, 16);
    } catch (e) {
      debugPrint('[AudioFingerprintUtil] Fallback fingerprint: $e');
      final base =
          audioPath.replaceAll("\\", "/").split('/').last.toLowerCase();
      return md5.convert(utf8.encode(base)).toString().substring(0, 16);
    }
  }

  /// Sync version — dùng khi không thể await (painter context)
  /// Kém ổn định hơn async version, chỉ dùng làm fallback
  static String computeSync({
    required String audioPath,
    required int durationMs,
  }) {
    try {
      final file = File(audioPath);
      final size = file.lengthSync();
      final base =
          audioPath.replaceAll("\\", "/").split('/').last.toLowerCase();
      final raw = '$size|$durationMs|$base';
      return md5.convert(utf8.encode(raw)).toString().substring(0, 16);
    } catch (_) {
      final base =
          audioPath.replaceAll("\\", "/").split('/').last.toLowerCase();
      return md5.convert(utf8.encode(base)).toString().substring(0, 16);
    }
  }
}
