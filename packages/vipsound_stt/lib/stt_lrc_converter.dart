import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models/stt_result.dart';

/// Chuyển đổi SttResult (với word timestamps) thành file .lrc chuẩn
/// Tích hợp vào Understand Mode của Vipsound
class SttLrcConverter {
  // ─── LRC Format Constants ─────────────────────────────────────────────────
  static const _lrcTimestampPattern = r'\[(\d{2}):(\d{2})\.(\d{2})\]';

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Tạo nội dung file LRC từ SttResult
  ///
  /// LRC chuẩn có dạng:
  /// [00:01.23] First line of text
  /// [00:05.67] Second line of text
  ///
  /// Enhanced LRC với word timestamps:
  /// [00:01.23] <00:01.23>First <00:01.89>line <00:02.45>of <00:02.78>text
  String generateLrcContent(
    SttResult result, {
    String? title,
    String? artist,
    String? album,
    bool useWordTimestamps = true,
    int maxWordsPerLine = 12,
    double maxLineSeconds = 5.0,
  }) {
    final buffer = StringBuffer();

    // ── LRC Metadata Header ───────────────────────────────────────────────
    buffer.writeln('[ti:${title ?? 'Untitled'}]');
    buffer.writeln('[ar:${artist ?? 'Vipsound AI Transcript'}]');
    buffer.writeln('[al:${album ?? ''}]');
    buffer.writeln('[by:Vipsound STT Engine]');
    buffer.writeln(
        '[re:Generated ${DateTime.now().toIso8601String().split('T').first}]');
    buffer.writeln('[ve:1.0.0]');
    buffer.writeln('');

    if (result.segments.isEmpty) {
      buffer.writeln('[00:00.00]${result.fullText}');
      return buffer.toString();
    }

    if (useWordTimestamps && result.hasWordTimestamps) {
      // ── Chế độ Word-Level (Enhanced LRC) ─────────────────────────────
      _generateWordLevelLrc(
        buffer,
        result,
        maxWordsPerLine: maxWordsPerLine,
        maxLineSeconds: maxLineSeconds,
      );
    } else {
      // ── Chế độ Segment-Level (Standard LRC) ──────────────────────────
      _generateSegmentLevelLrc(buffer, result);
    }

    return buffer.toString();
  }

  /// Lưu file .lrc vào đường dẫn chỉ định
  /// Quy tắc: cùng tên với file audio, thay đổi extension → .lrc
  Future<String> saveLrcFile(
    SttResult result,
    String audioFilePath, {
    String? outputDirectory,
    String? title,
    bool useWordTimestamps = true,
  }) async {
    // ── Xác định đường dẫn output ─────────────────────────────────────
    final lrcPath = _buildLrcPath(audioFilePath, outputDirectory);
    final lrcContent = generateLrcContent(
      result,
      title: title ?? _extractFileName(audioFilePath),
      useWordTimestamps: useWordTimestamps,
    );

    // ── Ghi file ──────────────────────────────────────────────────────
    final file = File(lrcPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(lrcContent, flush: true);

    debugPrint('💾 LRC saved: $lrcPath (${lrcContent.length} chars)');
    return lrcPath;
  }

  /// Parse file .lrc thành danh sách LrcLine (dùng để load lại)
  List<LrcLine> parseLrcFile(String lrcContent) {
    final lines = <LrcLine>[];
    final lineRegex = RegExp(_lrcTimestampPattern + r'\s*(.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.startsWith('[') && !_isMetadataLine(trimmed)) {
        final match = lineRegex.firstMatch(trimmed);
        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final centiseconds = int.parse(match.group(3)!);
          final text = match.group(4)?.trim() ?? '';

          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: centiseconds * 10,
          );

          lines.add(LrcLine(
            timestamp: timestamp,
            text: _stripWordTimestamps(text),
            rawText: text,
          ));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  void _generateWordLevelLrc(
    StringBuffer buffer,
    SttResult result, {
    required int maxWordsPerLine,
    required double maxLineSeconds,
  }) {
    // Gom các từ thành "dòng" dựa trên khoảng dừng và số từ
    final allWords = result.allWords;
    if (allWords.isEmpty) {
      _generateSegmentLevelLrc(buffer, result);
      return;
    }

    final lines = _groupWordsIntoLines(
      allWords,
      maxWordsPerLine: maxWordsPerLine,
      maxLineSeconds: maxLineSeconds,
    );

    for (final line in lines) {
      if (line.words.isEmpty) continue;
      final lineStart = line.words.first.startSeconds;

      // [MM:SS.cc] <MM:SS.cc>word1 <MM:SS.cc>word2 ...
      buffer.write(_formatTimestamp(lineStart));
      for (final word in line.words) {
        buffer.write(
            ' ${_formatInlineWordTimestamp(word.startSeconds)}${word.word}');
      }
      buffer.writeln();
    }
  }

  void _generateSegmentLevelLrc(StringBuffer buffer, SttResult result) {
    for (final segment in result.segments) {
      if (segment.text.isEmpty) continue;
      buffer
          .writeln('${_formatTimestamp(segment.startSeconds)}${segment.text}');
    }
  }

  /// Gom từ thành dòng dựa trên:
  /// - Số từ tối đa / dòng
  /// - Độ dài thời gian tối đa / dòng
  /// - Khoảng dừng tự nhiên (>0.5s giữa các từ)
  List<_LrcLineGroup> _groupWordsIntoLines(
    List<SttWord> words, {
    required int maxWordsPerLine,
    required double maxLineSeconds,
  }) {
    final lines = <_LrcLineGroup>[];
    var currentLine = <SttWord>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      currentLine.add(word);

      bool shouldBreak = false;

      // Điều kiện ngắt dòng:
      // 1. Đủ số từ tối đa
      if (currentLine.length >= maxWordsPerLine) shouldBreak = true;

      // 2. Dòng hiện tại đã dài quá giới hạn thời gian
      if (currentLine.length > 1) {
        final lineDuration = word.endSeconds - currentLine.first.startSeconds;
        if (lineDuration >= maxLineSeconds) shouldBreak = true;
      }

      // 3. Khoảng dừng tự nhiên (>= 0.5s) sau từ này
      if (!shouldBreak && i < words.length - 1) {
        final gap = words[i + 1].startSeconds - word.endSeconds;
        if (gap >= 0.5) shouldBreak = true;
      }

      // 4. Từ cuối cùng
      if (i == words.length - 1) shouldBreak = true;

      if (shouldBreak && currentLine.isNotEmpty) {
        lines.add(_LrcLineGroup(words: List.from(currentLine)));
        currentLine.clear();
      }
    }

    return lines;
  }

  /// Format timestamp theo chuẩn LRC: [MM:SS.cc]
  String _formatTimestamp(double seconds) {
    final totalMs = (seconds * 1000).round();
    final minutes = totalMs ~/ 60000;
    final secs = (totalMs % 60000) ~/ 1000;
    final centiseconds = (totalMs % 1000) ~/ 10;

    return '[${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}]';
  }

  String _formatInlineWordTimestamp(double seconds) {
    final totalMs = (seconds * 1000).round();
    final minutes = totalMs ~/ 60000;
    final secs = (totalMs % 60000) ~/ 1000;
    final centiseconds = (totalMs % 1000) ~/ 10;

    return '<${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}>';
  }

  /// Xây dựng đường dẫn file LRC
  /// Quy tắc: thay extension của file audio bằng .lrc
  String _buildLrcPath(String audioPath, String? outputDir) {
    // Normalize path separators
    final normalized = audioPath.replaceAll('\\', '/');
    final lastDot = normalized.lastIndexOf('.');
    final withoutExt =
        lastDot > 0 ? normalized.substring(0, lastDot) : normalized;

    if (outputDir != null) {
      final fileName = normalized.split('/').last;
      final fileWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      return '${outputDir.replaceAll('\\', '/')}/$fileWithoutExt.lrc';
    }

    return '$withoutExt.lrc';
  }

  String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final fileWithExt = parts.last;
    final dotIndex = fileWithExt.lastIndexOf('.');
    return dotIndex > 0 ? fileWithExt.substring(0, dotIndex) : fileWithExt;
  }

  bool _isMetadataLine(String line) {
    final metaKeys = [
      'ti:',
      'ar:',
      'al:',
      'by:',
      're:',
      've:',
      'length:',
      'offset:'
    ];
    return metaKeys.any((key) => line.startsWith('[${key}'));
  }

  /// Xóa word timestamps khỏi text: <00:01.23>word → word
  String _stripWordTimestamps(String text) {
    return text.replaceAll(RegExp(r'<\d{2}:\d{2}\.\d{2}>'), '').trim();
  }
}

// ─── Helper Classes ───────────────────────────────────────────────────────────

class _LrcLineGroup {
  final List<SttWord> words;
  const _LrcLineGroup({required this.words});
}

/// Một dòng LRC đã được parse
class LrcLine {
  final Duration timestamp;

  /// Text đã xóa word timestamps (hiển thị cho user)
  final String text;

  /// Raw text (có thể chứa word timestamps)
  final String rawText;

  const LrcLine({
    required this.timestamp,
    required this.text,
    required this.rawText,
  });

  @override
  String toString() => 'LrcLine(${timestamp.inSeconds}s: "$text")';
}
