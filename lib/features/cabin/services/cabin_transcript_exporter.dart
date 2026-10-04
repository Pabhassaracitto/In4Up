import 'package:in4up/features/cabin/models/cabin_session.dart';

/// CABIN-SAVE-001 — xuất transcript phiên Cabin ra LRC / TXT (logic thuần,
/// test được không cần thiết bị).
///
/// LRC song ngữ: mỗi câu 2 dòng — câu gốc tại mốc `t`, bản dịch tại `t+10ms`
/// (parser LRC của app chỉ nhận 1 mốc/dòng; lệch 1 centi-giây để thứ tự
/// gốc → dịch không bị đảo khi sort và dòng gốc không có độ dài 0).
class CabinTranscriptExporter {
  const CabinTranscriptExporter._();

  static const bilingualGap = Duration(milliseconds: 10);

  /// `[mm:ss.cc]` — phút có thể > 99 cho phiên rất dài (vẫn đúng regex `\d{2}`
  /// với phút < 100; phiên ≥ 100 phút hiếm, khi đó để 3 chữ số).
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

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  /// Các dòng (mốc, chữ) theo chế độ — dùng chung cho LRC và TXT.
  static List<(Duration, String)> lines(
    List<CabinTranscriptEntry> entries,
    CabinTextMode mode,
  ) {
    final sorted = [...entries]..sort((a, b) => a.offset.compareTo(b.offset));
    final out = <(Duration, String)>[];
    for (final e in sorted) {
      final src = _clean(e.sourceText);
      final tgt = _clean(e.translatedText);
      switch (mode) {
        case CabinTextMode.source:
          if (src.isNotEmpty) out.add((e.offset, src));
        case CabinTextMode.target:
          final t = tgt.isNotEmpty ? tgt : src;
          if (t.isNotEmpty) out.add((e.offset, t));
        case CabinTextMode.bilingual:
          if (src.isNotEmpty) out.add((e.offset, src));
          if (tgt.isNotEmpty && tgt != src) {
            out.add((e.offset + bilingualGap, tgt));
          }
      }
    }
    return out;
  }

  static String buildLrc(
    List<CabinTranscriptEntry> entries,
    CabinTextMode mode, {
    String? title,
  }) {
    final b = StringBuffer();
    if (title != null && title.trim().isNotEmpty) {
      b.writeln('[ti:${_clean(title)}]');
    }
    b.writeln('[by:In4Up Cabin]');
    for (final (t, text) in lines(entries, mode)) {
      b.writeln('${formatTimestamp(t)}$text');
    }
    return b.toString();
  }

  static String buildTxt(
    List<CabinTranscriptEntry> entries,
    CabinTextMode mode,
  ) {
    final sorted = [...entries]..sort((a, b) => a.offset.compareTo(b.offset));
    final b = StringBuffer();
    for (final e in sorted) {
      final src = _clean(e.sourceText);
      final tgt = _clean(e.translatedText);
      switch (mode) {
        case CabinTextMode.source:
          if (src.isNotEmpty) b.writeln(src);
        case CabinTextMode.target:
          final t = tgt.isNotEmpty ? tgt : src;
          if (t.isNotEmpty) b.writeln(t);
        case CabinTextMode.bilingual:
          if (src.isNotEmpty) b.writeln(src);
          if (tgt.isNotEmpty && tgt != src) b.writeln(tgt);
          b.writeln();
      }
    }
    return b.toString().trimRight();
  }
}
