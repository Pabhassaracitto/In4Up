/// Tách text dài thuần (pure) cho Hy-MT offline (HYMT-002).
///
/// Bất biến quan trọng: kết quả là một **phân hoạch chính xác** của text
/// gốc — `chunks.map((c) => c.text).join('') == text`. Không lặp, không
/// mất đoạn, thứ tự luôn giữ nguyên.
///
/// Chiến lược:
///   * text ≤ [maxChars] → 1 chunk (câu ngắn KHÔNG bị tách → 1 request
///     duy nhất, không "timeout giả" do thêm round-trip).
///   * text dài → tách ở ranh giới CÂU (`. ! ? …` + ngắt dòng) gần nhất
///     với giới hạn `maxChars`; không có ranh giới câu thì tách ở khoảng
///     trắng; không có cả khoảng trắng thì cắt cứng ở `maxChars`.
///
/// Module không phụ thuộc Flutter/IO — test thuần bằng `flutter test`.
library;

/// Một mảnh text cần dịch + ký tự phân cách dùng khi ghép output của mảnh
/// này với output của mảnh kế tiếp.
class HyMtChunk {
  /// Substring CHÍNH XÁC của text gốc (phân hoạch — join('') = text gốc).
  final String text;

  /// Phân cách giữa output của mảnh này và mảnh kế tiếp: `'\n'` khi ranh
  /// giới gốc là ngắt dòng, ngược lại `' '`. Bỏ qua ở mảnh cuối.
  final String separator;

  const HyMtChunk(this.text, this.separator);
}

class HyMtChunking {
  HyMtChunking._();

  /// Mục tiêu tối đa ký tự mỗi chunk (tune cho Hy-MT1.5 trên máy mobile;
  /// "khoảng ≤500 ký tự nếu phù hợp engine" — HYMT-002 mục 3).
  static const int defaultMaxChars = 500;

  /// Chấm câu được coi là ranh giới tách (BMP).
  static const String _sentenceEnd = '.!?…:;।؟。！';

  /// Nháy đóng / ngoặc đóng — bỏ qua khi dò chấm câu phía sau
  /// (vd `Hello." World` → ranh giới vẫn là `. `).
  static const String _closingPunct = '\u0022\u2019\u201d\u0027\u3009\u300d\u0029\u005d';

  /// Tách [text] thành các chunk theo thứ tự (xem doc module).
  ///
  /// Mỗi chunk ≤ [maxChars]; riêng mảnh cuối có thể vượt tới 31 ký tự khi
  /// đoạn còn lại quá ngắn (<32) — vượt nhẹ mục tiêu rẻ hơn một request
  /// riêng cho 1-2 từ.
  static List<HyMtChunk> chunk(String text, {int maxChars = defaultMaxChars}) {
    if (maxChars < 16) maxChars = 16;
    final n = text.length;
    if (n == 0) return const <HyMtChunk>[];
    if (n <= maxChars) return <HyMtChunk>[HyMtChunk(text, ' ')];

    final chunks = <HyMtChunk>[];
    var start = 0;
    while (start < n) {
      final hardEnd = start + maxChars > n ? n : start + maxChars;
      int end;
      var atLine = false;
      if (hardEnd == n) {
        end = n;
      } else {
        // 1) Ranh giới câu / ngắt dòng gần nhất với giới hạn.
        final boundary = _lastBoundary(text, start, hardEnd);
        end = boundary.$1;
        atLine = boundary.$2;

        // 2) Fallback: khoảng trắng trong vùng cân bằng (≥60% cửa sổ) —
        //    tránh mảnh đầu bé xíu rồi lại mảnh 500.
        if (end < 0) {
          final floor = start + (maxChars * 0.6).floor();
          for (var i = hardEnd; i > floor; i--) {
            final c = text[i - 1];
            if (c == ' ' || c == '\t') {
              end = i;
              break;
            }
          }
        }

        // 3) Cắt cứng ("từ" dài vô lý không khoảng trắng).
        if (end < 0) end = hardEnd;

        // 4) Đoạn đuôi quá ngắn (<32) và ranh giới không phải câu → lấy
        //    luôn cả đuôi (mảnh cuối được phép vượt nhẹ — xem doc).
        if (!atLine && n - end < 32) end = n;
      }
      chunks.add(HyMtChunk(text.substring(start, end), atLine ? '\n' : ' '));
      start = end;
    }
    return chunks;
  }

  /// Vị trí ranh giới gần nhất với [hardEnd] trong (start, hardEnd]
  /// (end của chunk, exclusive) + cờ "ranh giới là ngắt dòng".
  /// `(-1, false)` nếu không có.
  static (int, bool) _lastBoundary(String text, int start, int hardEnd) {
    for (var i = hardEnd; i > start; i--) {
      final kind = _boundaryKind(text, start, i);
      if (kind > 0) return (i, kind == 2);
    }
    return (-1, false);
  }

  /// 0 = không phải ranh giới; 1 = chấm câu; 2 = ngắt dòng.
  static int _boundaryKind(String text, int start, int end) {
    if (end <= start) return 0;
    var k = end;
    // Qua các khoảng trắng đuôi (KHÔNG qua '\n' — '\n' là ranh giới riêng).
    while (k > 0) {
      final c = text[k - 1];
      if (c == ' ' || c == '\t' || c == '\r') {
        k--;
      } else {
        break;
      }
    }
    if (k <= start) return 0;
    if (text[k - 1] == '\n') return 2;
    // Bỏ qua nháy/ngoặc đóng để thấy chấm câu thật phía sau.
    while (k > start) {
      final c = text[k - 1];
      if (_closingPunct.contains(c)) {
        k--;
      } else {
        break;
      }
    }
    if (k <= start) return 0;
    return _sentenceEnd.contains(text[k - 1]) ? 1 : 0;
  }

  /// Ghép output của từng chunk (đã trim) theo THỨ TỰ chunk với phân cách
  /// đúng loại ranh giới. Gộp khoảng trắng thừa trong dòng (model đôi khi
  /// nhả 2-3 space), giữ nguyên ngắt dòng.
  static String assemble(List<String> outputs, List<HyMtChunk> chunks) {
    if (outputs.isEmpty) return '';
    if (outputs.length != chunks.length) {
      throw ArgumentError(
        'Mismatch: ${outputs.length} outputs cho ${chunks.length} chunks',
      );
    }
    var out = '';
    for (var i = 0; i < outputs.length; i++) {
      final piece = outputs[i].trim();
      if (piece.isEmpty) continue;
      if (out.isNotEmpty) out += chunks[i].separator;
      out += piece;
    }
    out = out.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return out.trim();
  }
}
