// in4up v11.0 — Content-Anchored UID System
// Nguồn thật duy nhất cho mọi UID/JoinKey trong hệ thống

import 'dart:convert';
import 'package:crypto/crypto.dart';

class ContentId {
  ContentId._(); // Không cho khởi tạo

  /// Audio Fingerprint — offline, rẻ, ổn định cho file local
  /// Dùng để phân biệt cùng tên file ở 2 vị trí khác nhau
  static String audioFingerprint({
    required String filePath,
    required int fileSizeBytes,
    required int durationMs,
  }) {
    final base = filePath.replaceAll("\\", "/").split('/').last.toLowerCase();
    final raw = '$fileSizeBytes|$durationMs|$base';
    return md5.convert(utf8.encode(raw)).toString().substring(0, 16);
  }

  /// Chuẩn hóa text: lowercase + collapse whitespace
  static String textNorm(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Segment UID — bất biến dù document thay đổi layout
  /// Scope: cross-file unique (cần fingerprint)
  static String segmentUid({
    required String audioFingerprint,
    required int startMs,
    required String text,
  }) {
    final raw = '$audioFingerprint|$startMs|${textNorm(text)}';
    return md5.convert(utf8.encode(raw)).toString().substring(0, 12);
  }

  /// Join Key — bridge giữa LrcLine và SpeakerAnnotation sidecar
  /// Scope: single-file (không cần fingerprint)
  /// Format: startMs|textNorm
  static String joinKey({
    required int startMs,
    required String text,
  }) =>
      '$startMs|${textNorm(text)}';
}
