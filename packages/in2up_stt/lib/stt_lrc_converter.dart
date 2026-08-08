// in2up v11.0 — LrcLine với Content-Anchored UID + joinKey

import 'dart:convert';
import 'models/content_id.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'models/stt_result.dart';

// ─── LrcWord ──────────────────────────────────────────────────────────────────

/// Một từ với timestamp bắt đầu — dùng cho karaoke word-level highlight.
class LrcWord {
  final String word;
  final Duration start;

  const LrcWord({required this.word, required this.start});

  /// Phân tách text thành các từ theo khoảng trắng (fallback khi LRC không có
  /// inline timestamp): gán timestamp đều trên cả dòng.
  static List<LrcWord> estimateFrom(String text, Duration lineStart) {
    final parts = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final result = <LrcWord>[];
    var cursor = lineStart;
    for (final w in parts) {
      result.add(LrcWord(word: w, start: cursor));
      cursor += const Duration(milliseconds: 350);
    }
    return result;
  }
}

// ─── LrcLine ──────────────────────────────────────────────────────────────────

class LrcLine {
  final Duration timestamp;
  final String text;

  /// Danh sách từ kèm timestamp (cho karaoke). Rỗng nếu LRC không có inline
  /// `<mm:ss.cs>` timestamps (khi đó UI có thể ước lượng bằng [LrcWord.estimateFrom]).
  final List<LrcWord> words;

  /// Content-Anchored UID: md5(startMs|textNorm)[0:12]
  /// Scope: single-file (không cần audioFingerprint)
  final String uid;

  LrcLine({
    required this.timestamp,
    required this.text,
    List<LrcWord>? words,
    String? uid,
  })  : words = words ?? const [],
        uid = uid ?? _computeUid(timestamp, text);

  // ── Static helpers ─────────────────────────────────────────

  static String _textNorm(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _computeUid(Duration timestamp, String text) =>
      ContentId.joinKey(startMs: timestamp.inMilliseconds, text: text);

  /// Join key — đồng bộ với ContentId.joinKey() và SpeakerAnnotation.joinKey
  String get joinKey => '${timestamp.inMilliseconds}|${_textNorm(text)}';

  @override
  String toString() => 'LrcLine(uid=$uid, ts=${timestamp.inMilliseconds}ms, '
      '"${text.length > 40 ? '${text.substring(0, 40)}…' : text}")';
}

// ─── SttLrcConverter ─────────────────────────────────────────────────────────

class SttLrcConverter {
  static final _lineRegex = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');

  /// Inline word timestamp trong enhanced-LRC: `<mm:ss.cs>` (2 hoặc 3 chữ số).
  static final _wordRegex = RegExp(r'<(\d{2}):(\d{2})\.(\d{2,3})>');

  /// Parse LRC content string → List<LrcLine>
  List<LrcLine> parseLrcContent(String content) {
    final lines = <LrcLine>[];

    for (final raw in content.split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('[ti:') ||
          trimmed.startsWith('[by:') ||
          trimmed.startsWith('[ve:')) {
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
      if (text.isEmpty) continue;

      // Tách inline word timestamps `<mm:ss.cs>` → words (karaoke)
      final words = _parseInlineWords(text, timestamp);

      // text thuần (bỏ inline tags) để hiển thị / edit
      final cleanText = text.replaceAll(_wordRegex, '').trim();

      lines.add(LrcLine(
        timestamp: timestamp,
        text: cleanText,
        words: words,
      ));
    }

    return lines;
  }

  /// Trích danh sách từ + timestamp từ inline `<mm:ss.cs>` tags.
  /// Nếu không có tag nào, trả về rỗng (UI sẽ ước lượng bằng [LrcWord.estimateFrom]).
  static List<LrcWord> _parseInlineWords(String lineText, Duration lineStart) {
    final words = <LrcWord>[];

    final matches = _wordRegex.allMatches(lineText).toList();
    if (matches.isEmpty) return words;

    // Text trước tag đầu tiên → thuộc timestamp của dòng
    var cursorStart = 0;
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final before = lineText.substring(cursorStart, m.start).trim();
      final tagTime = _parseTime(
        m.group(1)!,
        m.group(2)!,
        m.group(3)!,
      );
      if (before.isNotEmpty) {
        words.add(LrcWord(word: before, start: i == 0 ? lineStart : tagTime));
      }
      cursorStart = m.end;
    }

    // Text sau tag cuối cùng
    final after = lineText.substring(cursorStart).trim();
    if (after.isNotEmpty) {
      final lastTime =
          _parseTime(matches.last.group(1)!, matches.last.group(2)!, matches.last.group(3)!);
      words.add(LrcWord(word: after, start: lastTime));
    }

    return words;
  }

  static Duration _parseTime(String m, String s, String c) {
    final centis = c.length == 2 ? int.parse(c) * 10 : int.parse(c);
    return Duration(
      minutes: int.parse(m),
      seconds: int.parse(s),
      milliseconds: centis,
    );
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
  /// Format chuẩn — KHÔNG nhúng [Sn] speaker tag.
  /// Nếu segment có word-timestamps, nhúng inline `<mm:ss.cs>` để karaoke.
  String generateLrcContent(SttResult result) {
    final buf = StringBuffer();

    buf.writeln('[ti:in2up Transcript]');
    buf.writeln('[by:in2up AI]');
    buf.writeln('[ve:1.0]');
    buf.writeln('');

    for (final seg in result.segments) {
      final ts = _fmtDuration(seg.startMs);
      final text = seg.text.trim();

      if (seg.words.isNotEmpty) {
        // Enhanced-LRC: dòng + inline word timestamps
        final parts = <String>[];
        for (var i = 0; i < seg.words.length; i++) {
          final w = seg.words[i];
          if (i == 0) {
            parts.add(w.word);
          } else {
            parts.add('<${_fmtDuration((w.startSeconds * 1000).round())}>${w.word}');
          }
        }
        buf.writeln('[$ts]${parts.join(' ')}');
      } else {
        buf.writeln('[$ts]$text');
      }
    }

    return buf.toString();
  }

  static String _fmtDuration(int ms) {
    final mm = (ms ~/ 60000).toString().padLeft(2, '0');
    final ss = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final cs = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$mm:$ss.$cs';
  }

  /// Serialize một LrcLine thành chuỗi dòng LRC.
  /// Nếu line có `words` (từ + timestamp) → nhúng inline `<mm:ss.cs>`.
  static String serializeLine(LrcLine line) {
    final ts = _fmtDuration(line.timestamp.inMilliseconds);

    if (line.words.isNotEmpty) {
      final parts = <String>[];
      for (var i = 0; i < line.words.length; i++) {
        final w = line.words[i];
        if (i == 0) {
          parts.add(w.word);
        } else {
          parts.add('<${_fmtDuration(w.start.inMilliseconds)}>${w.word}');
        }
      }
      return '[$ts]${parts.join(' ')}';
    }

    return '[$ts]${line.text.trim()}';
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
