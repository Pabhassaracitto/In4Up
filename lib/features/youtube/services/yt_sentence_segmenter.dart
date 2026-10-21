// YT-AUDIT-11 (IN4-106) — Chia phụ đề YouTube thành **CÂU HOÀN CHỈNH**.
//
// Triệu chứng owner báo (2026-10-20):
//   "Âm thanh và chữ … chưa tối ưu: xuống dòng vô tội vạ, không chia câu rõ
//    ràng. Muốn: phân câu hoàn chỉnh, dấu đầy đủ, viết hoa đầu câu."
//
// Nguyên nhân: track phụ đề của YouTube là các **cue ngắn** cắt theo nhịp nói
// (thường 1–2 giây / 20–40 ký tự), cắt ở bất kỳ chỗ nào — kể cả giữa câu. App
// cũ hiện nguyên từng cue ⇒ người đọc thấy những mẩu câu vụn, không có dấu
// chấm, không viết hoa.
//
// Bộ này gộp các cue liên tiếp thành câu, rồi chuẩn hoá: 1 dấu cách, viết hoa
// chữ cái đầu, bảo đảm có dấu kết thúc câu.
//
// THUẦN LOGIC (không Flutter, không mạng) ⇒ test được trực tiếp — xem
// `test/yt_sentence_segment_test.dart`.
//
// LƯU Ý i18n: file này KHÔNG phải presentation file nên gate i18n không quét.
// Vì vậy KHÔNG được chứa nhãn tiếng Việt hiển thị ra UI.

import '../models/yt_video.dart';

/// Gộp cue phụ đề thành câu hoàn chỉnh + chuẩn hoá văn bản.
class YtSentenceSegmenter {
  YtSentenceSegmenter._();

  /// Độ dài tối đa của một dòng (ký tự) — vượt qua thì đóng câu luôn để
  /// không bao giờ hiện một khối chữ khổng lồ che nửa màn hình.
  static const int defaultMaxChars = 180;

  /// Thời lượng tối đa của một dòng (ms).
  static const int defaultMaxDurationMs = 9000;

  /// Khoảng lặng tối đa (ms) giữa 2 cue mà vẫn coi là CÙNG một câu.
  /// Vượt qua (ngắt nghỉ thật) ⇒ đóng câu.
  static const int defaultMaxGapMs = 1500;

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Dấu kết thúc câu (có thể đứng sau ngoặc kép / ngoặc vuông).
  static final RegExp _sentenceEnd = RegExp(r'[.!?…。！？؛؟][)"»”’\]]*$');

  /// Dấu "chưa xong câu" ở cuối — thay bằng dấu chấm thay vì chấm chồng lên.
  static final RegExp _trailingSoft = RegExp(r'[,;:、，；：]$');

  /// Chữ cái có hoa/thường (Latin mở rộng + Hy Lạp + Cyrillic).
  static final RegExp _letter = RegExp(r'[A-Za-zÀ-ɏͰ-ϿЀ-ӿ]');

  static final RegExp _digit = RegExp(r'[0-9]');

  /// Từ viết tắt hay gặp — dấu chấm sau chúng KHÔNG phải hết câu.
  static const Set<String> _abbreviations = <String>{
    'mr', 'mrs', 'ms', 'dr', 'st', 'jr', 'sr', 'vs', 'etc', 'prof', 'fig',
    'inc', 'ltd', 'co', 'corp', 'dept', 'univ', 'ave', 'rd', 'mt', 'no',
    'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'sept', 'oct',
    'nov', 'dec', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun',
  };

  /// 1. Rút gọn mọi khoảng trắng (xuống dòng vô tội vạ ⇒ đúng 1 dấu cách).
  static String normalizeWhitespace(String s) =>
      s.replaceAll(_whitespace, ' ').trim();

  /// Câu đã kết thúc chưa? (bỏ qua ngoặc kép / ngoặc vuông ở cuối).
  static bool endsSentence(String s) => _sentenceEnd.hasMatch(s);

  /// Từ đứng ngay trước dấu chấm cuối có phải viết tắt / số thập phân không.
  ///
  /// Tránh cắt nhầm: `3.5`, `U.S.`, `e.g.`, `J. R. R.`, `Dr.`, `etc.`
  static bool looksLikeAbbreviation(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    final lastSpace = t.lastIndexOf(' ');
    var word = lastSpace < 0 ? t : t.substring(lastSpace + 1);
    // Bỏ dấu chấm cuối (nếu có) để lấy thân từ.
    if (word.endsWith('.')) word = word.substring(0, word.length - 1);
    if (word.isEmpty) return false;
    // Số: 3.5 / 1,000.5
    if (RegExp(r'^[0-9]+([.,][0-9]+)*$').hasMatch(word)) return true;
    // Viết tắt có dấu chấm bên trong: U.S / e.g
    if (word.contains('.')) return true;
    // Chữ cái đơn (tên viết tắt): J. R. R.
    if (word.length == 1 && _letter.hasMatch(word)) return true;
    return _abbreviations.contains(word.toLowerCase());
  }

  /// Bảo đảm câu có dấu kết thúc (không chấm chồng lên dấu đã có).
  static String ensureSentenceEnding(String s) {
    final t = s.trimRight();
    if (t.isEmpty) return t;
    if (endsSentence(t)) return t;
    if (_trailingSoft.hasMatch(t)) {
      // "…, " ⇒ "…." thay vì "…,."
      return '${t.substring(0, t.length - 1)}.';
    }
    return '$t.';
  }

  /// Viết hoa chữ cái đầu tiên (bỏ qua ngoặc kép / gạch ngang mở đầu).
  ///
  /// KHÔNG hạ chữ cái nào khác — danh từ riêng (iPhone, NASA) phải được giữ
  /// nguyên. Gặp chữ số trước khi gặp chữ cái ⇒ bỏ cuộc (vd "3 ways to…").
  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (_letter.hasMatch(c)) {
        return '${s.substring(0, i)}${c.toUpperCase()}${s.substring(i + 1)}';
      }
      if (_digit.hasMatch(c)) return s;
      i++;
    }
    return s;
  }

  /// Chuẩn hoá đầy đủ: 1 dấu cách + viết hoa đầu + dấu kết thúc câu.
  static String tidy(String s) =>
      capitalizeFirst(ensureSentenceEnding(normalizeWhitespace(s)));

  /// Track có phải dạng "rolling window" không (cue sau CHỨA toàn bộ cue
  /// trước). YouTube auto-caption và nhiều track dịch dùng dạng này.
  static bool isCumulativeTrack(List<YtCaptionLine> cues) {
    if (cues.length < 3) return false;
    var cumulative = 0;
    var checked = 0;
    for (var i = 1; i < cues.length; i++) {
      final prev = cues[i - 1].text.trim();
      final cur = cues[i].text.trim();
      if (prev.isEmpty || cur.isEmpty) continue;
      checked++;
      if (cur.length > prev.length && cur.startsWith(prev)) cumulative++;
    }
    if (checked == 0) return false;
    // ≥ 60% dòng lặp tiền tố ⇒ đây là rolling window.
    return cumulative / checked >= 0.6;
  }

  /// Tách phần chữ MỚI của mỗi cue (track rolling window ⇒ chỉ lấy phần thêm).
  static List<String> incrementalTexts(List<YtCaptionLine> cues) {
    final cumulative = isCumulativeTrack(cues);
    final out = <String>[];
    for (var i = 0; i < cues.length; i++) {
      final cur = normalizeWhitespace(cues[i].text);
      if (!cumulative || i == 0) {
        out.add(cur);
        continue;
      }
      // So với cue TRƯỚC ở dạng ĐẦY ĐỦ, không phải phần chữ mới vừa tách ở
      // bước trước. Nếu so với phần vừa tách, từ cue thứ 3 trở đi không còn
      // khớp tiền tố nữa (vd: 'Bye.' không bắt đầu bằng 'world.') ⇒ rớt về
      // nguyên cue ⇒ chữ bị lặp lại.
      final prev = normalizeWhitespace(cues[i - 1].text);
      if (prev.isNotEmpty && cur.length > prev.length && cur.startsWith(prev)) {
        out.add(cur.substring(prev.length).trim());
      } else {
        out.add(cur);
      }
    }
    return out;
  }

  /// Gộp danh sách cue thành các câu hoàn chỉnh.
  ///
  /// * Đóng câu khi: gặp dấu kết thúc câu (không phải viết tắt) · vượt
  ///   [maxChars] · vượt [maxDurationMs] · khoảng lặng tới cue sau > [maxGapMs].
  /// * Mốc thời gian của câu = start cue đầu + end cue cuối.
  /// * Bản dịch (nếu có) được nối theo cùng cách.
  static List<YtCaptionLine> segmentCaptions(
    List<YtCaptionLine> cues, {
    int maxChars = defaultMaxChars,
    int maxDurationMs = defaultMaxDurationMs,
    int maxGapMs = defaultMaxGapMs,
  }) {
    if (cues.isEmpty) return const <YtCaptionLine>[];
    final texts = incrementalTexts(cues);

    final out = <YtCaptionLine>[];
    final buf = <int>[];
    final bufWords = <String>[];

    void flush() {
      if (buf.isEmpty) return;
      final first = cues[buf.first];
      final last = cues[buf.last];
      var end = last.end;
      if (end.inMilliseconds <= first.start.inMilliseconds) {
        end = first.start + const Duration(milliseconds: 500);
      }
      final text = tidy(bufWords.join(' '));
      if (text.isNotEmpty) {
        final translations = <String>[
          for (final i in buf)
            if ((cues[i].translation ?? '').trim().isNotEmpty)
              cues[i].translation!.trim(),
        ];
        out.add(
          YtCaptionLine(
            first.start,
            end,
            text,
            translation: translations.isEmpty ? null : translations.join(' '),
          ),
        );
      }
      buf.clear();
      bufWords.clear();
    }

    for (var i = 0; i < cues.length; i++) {
      final t = texts[i];
      if (t.isEmpty) continue;

      if (buf.isNotEmpty) {
        final gap =
            cues[i].start.inMilliseconds - cues[buf.last].end.inMilliseconds;
        if (gap > maxGapMs ||
            bufWords.join(' ').length >= maxChars ||
            cues[i].end.inMilliseconds -
                    cues[buf.first].start.inMilliseconds >
                maxDurationMs) {
          flush();
        }
      }

      buf.add(i);
      bufWords.add(t);

      // Vừa đủ một câu ⇒ đóng ngay. Đây là nhánh chính: phần lớn track phụ đề
      // cắt đúng theo dấu chấm, chỉ bị vỡ thành nhiều cue.
      if (endsSentence(t) && !looksLikeAbbreviation(t)) flush();
    }
    flush();

    if (out.isEmpty) return const <YtCaptionLine>[];

    // Không để dòng này lấn sang mốc bắt đầu của dòng sau (track gốc có cue
    // đè lên nhau ⇒ chữ của câu sau bị hiện sớm).
    for (var i = 0; i < out.length - 1; i++) {
      if (out[i].end > out[i + 1].start) {
        out[i] = YtCaptionLine(
          out[i].start,
          out[i + 1].start,
          out[i].text,
          translation: out[i].translation,
        );
      }
    }
    return out;
  }
}
