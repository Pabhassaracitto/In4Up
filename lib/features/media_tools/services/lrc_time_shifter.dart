// lib/features/media_tools/services/lrc_time_shifter.dart
//
// AVTOOL-002 (PLAN-047 P1) — DỊCH MỐC THỜI GIAN LRC. HÀM THUẦN.
//
// Vì sao cần: trong app, LRC là "linh hồn" của tab Nghe (karaoke + A–B theo
// câu + tự cuộn tab Đọc). Khi người dùng xuất một ĐOẠN của file 90 phút thành
// clip 20 giây, nếu không dịch mốc thì:
//   - clip không có karaoke (LRC cũ trỏ vào mốc 01:23:45 của file gốc), hoặc
//   - LRC sai lệch hoàn toàn ⇒ app còn tệ hơn không có LRC.
// Nên mọi thao tác cắt/nối phải sinh LRC mới đã dịch mốc và đăng ký với
// `SourceArtifactStore.rememberLrc`.
//
// Luật đọc/ghi mốc dùng CHUNG với `lib/services/lrc_time_parser.dart`:
//   * `[mm:ss]`, `[mm:ss.cs]`, `[mm:ss.xxx]`, `[mm:ss,xx]`
//   * `[mmm:ss.xx]` — phút > 59 (không chia giờ, giữ nguyên quy ước của app)
//   * `[hh:mm:ss.xx]`
// Đầu ra luôn dùng dạng `[mm:ss.cc]` (khớp `CabinTranscriptExporter.formatTimestamp`)
// để mọi parser hiện có đọc được.

import '../../../services/lrc_time_parser.dart' show LrcLine, parseLrcLine;

/// Một dòng LRC thô đã dịch mốc (dùng khi cần giữ nguyên chữ gốc).
class ShiftedLrcLine {
  const ShiftedLrcLine(this.start, this.text);

  final Duration start;
  final String text;
}

class LrcTimeShifter {
  const LrcTimeShifter._();

  /// Định dạng mốc `[mm:ss.cc]` — phút KHÔNG bị chia thành giờ (quy ước app),
  /// nên video/clip > 100 phút vẫn đọc được bằng parser đã nới.
  static String formatTimestamp(Duration d) {
    final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
    final totalCs = ms ~/ 10;
    final minutes = totalCs ~/ 6000;
    final seconds = (totalCs % 6000) ~/ 100;
    final cs = totalCs % 100;
    return '[${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${cs.toString().padLeft(2, '0')}]';
  }

  /// Lọc + dịch mốc cho MỘT đoạn cắt.
  ///
  /// - Dòng có mốc `< start` → bỏ (nội dung thuộc phần trước clip).
  /// - Dòng có mốc `>= start + duration` → bỏ (thuộc phần sau clip).
  /// - Còn lại: mốc mới = mốc cũ − start.
  ///
  /// [toleranceMs] hấp thụ sai số làm tròn centi-giây: một dòng nằm sát mốc
  /// cắt (trong khoảng dung sai) vẫn được giữ và kéo về `[00:00.00]`, vì với
  /// clip học tập, câu nói ngay tại mốc cắt là câu QUAN TRỌNG NHẤT.
  static List<ShiftedLrcLine> shiftForClip(
    List<LrcLine> lines, {
    required Duration start,
    Duration? duration,
    int toleranceMs = 250,
  }) {
    final startMs = start.inMilliseconds;
    final endMs = duration == null ? null : startMs + duration.inMilliseconds;
    final out = <ShiftedLrcLine>[];

    for (final line in lines) {
      final ms = line.start.inMilliseconds;
      if (ms + toleranceMs < startMs) continue;
      if (endMs != null && ms > endMs + toleranceMs) continue;
      final shifted = ms - startMs;
      out.add(ShiftedLrcLine(
        Duration(milliseconds: shifted < 0 ? 0 : shifted),
        line.text,
      ));
    }

    // Mốc trùng nhau sau khi kéo về 0 (nhiều dòng trong dung sai) → giữ thứ tự
    // bằng cách cộng thêm 10ms mỗi dòng, đúng quy ước song ngữ của app
    // (CabinTranscriptExporter.bilingualGap) để parser không bỏ dòng trùng.
    out.sort((a, b) => a.start.compareTo(b.start));
    final fixed = <ShiftedLrcLine>[];
    var lastMs = -1;
    for (final line in out) {
      var ms = line.start.inMilliseconds;
      if (ms <= lastMs) ms = lastMs + 10;
      lastMs = ms;
      fixed.add(ShiftedLrcLine(Duration(milliseconds: ms), line.text));
    }
    return fixed;
  }

  /// Dịch mốc cho NHIỀU chặng liên tiếp (tách theo chương), trả về theo đúng
  /// thứ tự chặng.
  static List<List<ShiftedLrcLine>> shiftForSlices(
    List<LrcLine> lines, {
    required List<({Duration start, Duration? duration})> slices,
    int toleranceMs = 250,
  }) {
    return [
      for (final slice in slices)
        shiftForClip(
          lines,
          start: slice.start,
          duration: slice.duration,
          toleranceMs: toleranceMs,
        ),
    ];
  }

  /// Dựng nội dung file LRC hoàn chỉnh.
  static String buildLrc(
    List<ShiftedLrcLine> lines, {
    String? title,
    String? artist,
    Duration? totalDuration,
  }) {
    final buffer = StringBuffer();
    if (title != null && title.trim().isNotEmpty) {
      buffer.writeln('[ti:${_cleanHeader(title)}]');
    }
    if (artist != null && artist.trim().isNotEmpty) {
      buffer.writeln('[ar:${_cleanHeader(artist)}]');
    }
    if (totalDuration != null) {
      // `formatTimestamp` trả `[mm:ss.cc]`; thẻ `length` cần phần trong ngoặc
      // ⇒ bỏ 2 đầu, tránh `[length:[00:12.00]]` (LRC sai chuẩn).
      final stamp = formatTimestamp(totalDuration);
      buffer.writeln('[length:${stamp.substring(1, stamp.length - 1)}]');
    }
    buffer.writeln('[by:In4Up]');
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      buffer.writeln('${formatTimestamp(line.start)}$text');
    }
    return buffer.toString();
  }

  /// Đọc nội dung LRC → danh sách dòng có mốc, dùng parser CHUNG của app
  /// (`parseLrcLine`) để không có luật thứ hai.
  static List<LrcLine> parse(String content) {
    final lines = <LrcLine>[];
    for (final raw in const LineSplitterShim().split(content)) {
      final line = parseLrcLine(raw);
      if (line != null) lines.add(line);
    }
    lines.sort((a, b) => a.start.compareTo(b.start));
    return lines;
  }

  /// Thẻ `[ti:...]` không được chứa `]` (sẽ làm parser hiểu nhầm là mốc).
  static String _cleanHeader(String value) =>
      value.replaceAll(RegExp(r'[\[\]\r\n]'), ' ').trim();
}

/// Tách dòng không phụ thuộc `dart:convert` (để file này thuần, nhẹ).
class LineSplitterShim {
  const LineSplitterShim();

  List<String> split(String content) =>
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
}
