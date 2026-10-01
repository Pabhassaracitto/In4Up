// lib/features/video/services/subtitle_parser.dart
// I4U18-VIDEO-LIB-001 — Parser phụ đề THUẦN (test được).
//
// Hỗ trợ SRT và WebVTT (và biến thể LRC đơn giản). Trả danh sách cue có
// thời gian bắt đầu/kết thúc + text (đã strip tag HTML/ASS cơ bản).
// KHÔNG phụ thuộc Flutter — chỉ String → List<SubtitleCue>.

/// Một dòng phụ đề với khoảng thời gian hiển thị.
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  bool contains(Duration t) => t >= start && t < end;

  @override
  String toString() => '[$start-$end] $text';
}

class SubtitleParser {
  const SubtitleParser._();

  /// Chọn parser theo extension (chữ thường, không dấu chấm).
  static List<SubtitleCue> parse(String content, {String ext = 'srt'}) {
    switch (ext.toLowerCase()) {
      case 'vtt':
        return parseVtt(content);
      case 'lrc':
        return parseLrc(content);
      case 'ass':
      case 'ssa':
        return parseAss(content);
      case 'srt':
      case 'sub':
      default:
        return parseSrt(content);
    }
  }

  /// SRT: khối "index / start --> end / text lines".
  static List<SubtitleCue> parseSrt(String content) {
    final cues = <SubtitleCue>[];
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n[ \t]*\n'));
    for (final block in blocks) {
      final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;
      // Bỏ dòng index nếu là số nguyên đơn thuần.
      var i = 0;
      if (RegExp(r'^\d+$').hasMatch(lines[0].trim())) i = 1;
      if (i >= lines.length) continue;
      final timeMatch = _timeLine.firstMatch(lines[i]);
      if (timeMatch == null) continue;
      final start = _parseTs(timeMatch.group(1)!);
      final end = _parseTs(timeMatch.group(2)!);
      final text = lines.sublist(i + 1).join('\n');
      if (text.trim().isEmpty) continue;
      cues.add(SubtitleCue(start: start, end: end, text: _stripTags(text)));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// WebVTT: giống SRT nhưng dùng "." cho ms và có header WEBVTT + cue id tùy chọn.
  static List<SubtitleCue> parseVtt(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Bỏ header WEBVTT (dòng đầu) + NOTE blocks.
    final body = normalized.replaceFirst(RegExp(r'^WEBVTT[^\n]*\n'), '');
    return parseSrt(body);
  }

  /// LRC: "[mm:ss.xx] text" — end = start của cue kế tiếp.
  static List<SubtitleCue> parseLrc(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final raw = <MapEntry<Duration, String>>[];
    final tag = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final line in normalized.split('\n')) {
      final matches = tag.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.replaceAll(tag, '').trim();
      if (text.isEmpty) continue;
      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final frac = m.group(3);
        var ms = 0;
        if (frac != null) {
          ms = int.parse(frac.padRight(3, '0').substring(0, 3));
        }
        raw.add(MapEntry(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          _stripTags(text),
        ));
      }
    }
    raw.sort((a, b) => a.key.compareTo(b.key));
    final cues = <SubtitleCue>[];
    for (var i = 0; i < raw.length; i++) {
      final start = raw[i].key;
      final end = i + 1 < raw.length
          ? raw[i + 1].key
          : start + const Duration(seconds: 5);
      cues.add(SubtitleCue(start: start, end: end, text: raw[i].value));
    }
    return cues;
  }

  /// ASS/SSA: dòng "Dialogue: Marked,Start,End,Style,...,Text".
  static List<SubtitleCue> parseAss(String content) {
    final cues = <SubtitleCue>[];
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (final line in normalized.split('\n')) {
      if (!line.startsWith('Dialogue:')) continue;
      final rest = line.substring('Dialogue:'.length);
      // 9 trường đầu, trường 10 (text) có thể chứa dấu phẩy.
      final parts = rest.split(',');
      if (parts.length < 10) continue;
      final start = _parseAssTs(parts[1].trim());
      final end = _parseAssTs(parts[2].trim());
      final text = parts.sublist(9).join(',');
      final clean = _stripAss(text);
      if (clean.trim().isEmpty) continue;
      cues.add(SubtitleCue(start: start, end: end, text: clean));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// Cue đang hiển thị tại thời điểm [t] (hoặc null).
  static SubtitleCue? cueAt(List<SubtitleCue> cues, Duration t) {
    for (final c in cues) {
      if (c.contains(t)) return c;
    }
    return null;
  }

  // ── helpers ──────────────────────────────────────────────────
  static final RegExp _timeLine = RegExp(
    r'(\d{1,2}:\d{2}:\d{2}[.,]\d{1,3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[.,]\d{1,3})',
  );

  static Duration _parseTs(String ts) {
    final s = ts.replaceAll(',', '.');
    final parts = s.split(':');
    if (parts.length != 3) return Duration.zero;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final sec = int.tryParse(secParts[0]) ?? 0;
    final ms = secParts.length > 1
        ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0
        : 0;
    return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
  }

  static Duration _parseAssTs(String ts) {
    // Format: H:MM:SS.cc (centiseconds)
    final parts = ts.split(':');
    if (parts.length != 3) return Duration.zero;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final sec = int.tryParse(secParts[0]) ?? 0;
    final cs = secParts.length > 1 ? int.tryParse(secParts[1]) ?? 0 : 0;
    return Duration(hours: h, minutes: m, seconds: sec, milliseconds: cs * 10);
  }

  static String _stripTags(String text) {
    // Bỏ tag HTML (<i>, <b>, <font ...>) và các thẻ định dạng cơ bản.
    return text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  static String _stripAss(String text) {
    // Bỏ override block {\...} và \N \n → xuống dòng.
    return text
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(RegExp(r'\\[Nn]'), '\n')
        .trim();
  }
}
