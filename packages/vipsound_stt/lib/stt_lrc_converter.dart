// VipSound v11.0 — LrcLine với Content-Anchored UID + joinKey

import 'dart:convert';
import 'models/content_id.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'models/stt_result.dart';

// ─── LrcLine ──────────────────────────────────────────────────────────────────

class LrcLine {
  final Duration timestamp;
  final String text;

  /// Content-Anchored UID: md5(startMs|textNorm)[0:12]
  /// Scope: single-file (không cần audioFingerprint)
  final String uid;

  LrcLine({
    required this.timestamp,
    required this.text,
    String? uid,
  }) : uid = uid ?? _computeUid(timestamp, text);

  // ── Static helpers ─────────────────────────────────────────

  static String _textNorm(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _computeUid(Duration timestamp, String text) => ContentId.joinKey(startMs: timestamp.inMilliseconds, text: text);

  /// Join key — đồng bộ với ContentId.joinKey() và SpeakerAnnotation.joinKey
  String get joinKey =>
      '${timestamp.inMilliseconds}|${_textNorm(text)}';

  @override
  String toString() =>
      'LrcLine(uid=$uid, ts=${timestamp.inMilliseconds}ms, '
      '"${text.length > 40 ? '${text.substring(0, 40)}…' : text}")';
}

// ─── SttLrcConverter ─────────────────────────────────────────────────────────

class SttLrcConverter {
  static final _lineRegex =
      RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');

  /// Parse LRC content string → List<LrcLine>
  List<LrcLine> parseLrcContent(String content) {
    final lines = <LrcLine>[];

    for (final raw in content.split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.startsWith('[ti:') ||
          trimmed.startsWith('[by:') || trimmed.startsWith('[ve:')) {
        continue;
      }

      final match = _lineRegex.firstMatch(trimmed);
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final centisStr = match.group(3)!;

      // Chuẩn hóa 2 hoặc 3 chữ số
      final ms = centisStr.length == 2
          ? int.parse(centisStr) * 10
          : int.parse(centisStr);

      final timestamp = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: ms,
      );

      final text = match.group(4)?.trim() ?? '';
      if (text.isNotEmpty) {
        lines.add(LrcLine(timestamp: timestamp, text: text));
      }
    }

    return lines;
  }

  /// Parse LRC file → List<LrcLine>
  Future<List<LrcLine>> parseLrcFile(String lrcPath) async {
    try {
      final file = File(lrcPath);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      return parseLrcContent(content);
    } catch (e) {
      debugPrint('[SttLrcConverter] parseLrcFile error: $e');
      return [];
    }
  }

  /// Tạo LRC string từ SttResult
  /// Format chuẩn — KHÔNG nhúng [Sn] speaker tag
  String generateLrcContent(SttResult result) {
    final buf = StringBuffer();

    buf.writeln('[ti:VipSound Transcript]');
    buf.writeln('[by:VipSound AI]');
    buf.writeln('[ve:1.0]');
    buf.writeln('');

    for (final seg in result.segments) {
      final mm =
          (seg.startMs ~/ 60000).toString().padLeft(2, '0');
      final ss =
          ((seg.startMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      final cs =
          ((seg.startMs % 1000) ~/ 10).toString().padLeft(2, '0');
      buf.writeln('[$mm:$ss.$cs]${seg.text.trim()}');
    }

    return buf.toString();
  }

  /// Lưu LRC file → trả về đường dẫn hoặc null nếu lỗi
  Future<String?> saveLrcFile(
    SttResult result,
    String audioPath, {
    required String outputDirectory,
  }) async {
    try {
      final dir = Directory(outputDirectory);
      if (!await dir.exists()) await dir.create(recursive: true);

      final base = audioPath
          .replaceAll('\\', '/')
          .split('/')
          .last
          .replaceAll(RegExp(r'\.[^.]+$'), '');

      final lrcPath = '$outputDirectory/$base.lrc';
      await File(lrcPath).writeAsString(generateLrcContent(result));

      debugPrint('[SttLrcConverter] Saved LRC: $lrcPath');
      return lrcPath;
    } catch (e) {
      debugPrint('[SttLrcConverter] saveLrcFile error: $e');
      return null;
    }
  }
}
