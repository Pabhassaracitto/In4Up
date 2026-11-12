// lib/features/tts/tts_text_chunker.dart
//
// PSRC-187 (audit 1.27.0) — chia một dòng dài thành các đoạn ngắn để đọc.
//
// VÌ SAO: tab Đọc đưa NGUYÊN một dòng/đoạn văn (có khi cả trang PDF) cho
// engine TTS. Với engine tổng hợp ra file (Piper, VieNeu, Edge…) điều đó nghĩa
// là: chờ tổng hợp xong cả dòng mới có tiếng, bộ nhớ tăng theo độ dài (Piper
// từng bị ép xử lý 100 câu trong một lượt ⇒ 3,4 GB cho 2751 ký tự), và engine
// online dễ quá hạn 15 s rồi rơi về engine khác.
//
// Hàm này THUẦN (không Flutter) để test được trên host VM.

/// Số ký tự tối đa mỗi đoạn khi đọc bằng Piper.
///
/// 280 ký tự ≈ 10–18 giây âm thanh: đoạn đầu ra tiếng sau vài giây ngay cả
/// trên máy tầm trung, các đoạn sau được tổng hợp sẵn trong lúc đoạn trước
/// đang phát.
const int kPiperTtsChunkChars = 280;

/// Số ký tự tối đa mỗi đoạn khi đọc bằng engine online (Edge, Google…).
///
/// Mỗi đoạn có hạn chờ 15 giây riêng ⇒ dòng dài không còn quá hạn rồi rơi về
/// engine khác.
const int kOnlineTtsChunkChars = 600;

// Hết câu: dấu chấm câu Latin phải ĐỨNG TRƯỚC khoảng trắng (hoặc hết chuỗi)
// — nếu không "3.5 km" hay "v1.27.0" sẽ bị cắt giữa con số; dấu câu CJK và
// xuống dòng thì luôn là điểm cắt.
final RegExp _sentenceEnd = RegExp(
  r'[.!?…]+["”’)\]]*(?=\s|$)|[。！？]+[”’）」』]*|\n+',
);
// Hết vế: dấu phẩy Latin cũng phải đứng trước khoảng trắng ("1,234" không cắt).
final RegExp _clauseEnd = RegExp(r'[,;:]+(?=\s)|[、，；：]+');
final RegExp _whitespace = RegExp(r'\s');

/// Chia [text] thành các đoạn dài tối đa [maxChars] ký tự.
///
/// Thứ tự ưu tiên điểm cắt, tính trong nửa SAU của cửa sổ [maxChars] (để đoạn
/// không quá ngắn): hết câu → hết vế (dấu phẩy…) → khoảng trắng → cắt cứng
/// (không cắt giữa một cặp surrogate).
///
/// * `text` ngắn hơn hoặc bằng [maxChars] (hay `maxChars <= 0`) ⇒ trả về đúng
///   một phần tử là `text` NGUYÊN VĂN (khoá cache của câu ngắn không đổi).
/// * `text` chỉ có khoảng trắng ⇒ danh sách rỗng.
/// * Ghép các đoạn bằng một dấu cách cho lại đủ mọi từ của `text`.
List<String> chunkTextForTts(String text, int maxChars) {
  if (text.trim().isEmpty) return const <String>[];
  if (maxChars <= 0 || text.length <= maxChars) return <String>[text];

  final chunks = <String>[];
  var remaining = text.trim();
  while (remaining.length > maxChars) {
    final cutAt = _bestCut(remaining, maxChars);
    final head = remaining.substring(0, cutAt).trim();
    if (head.isNotEmpty) chunks.add(head);
    remaining = remaining.substring(cutAt).trim();
  }
  if (remaining.isNotEmpty) chunks.add(remaining);
  return chunks;
}

/// Vị trí KẾT THÚC của lần khớp cuối cùng của [pattern] nằm trọn trong
/// `[start, limit]` của [text]; -1 nếu không có. Khớp trên [text] đầy đủ để
/// lookahead nhìn thấy ký tự thật đứng sau.
int _lastMatchEnd(RegExp pattern, String text, int start, int limit) {
  var end = -1;
  for (final match in pattern.allMatches(text, start)) {
    if (match.start >= limit) break;
    if (match.end <= limit) end = match.end;
  }
  return end;
}

int _bestCut(String text, int maxChars) {
  final windowStart = maxChars ~/ 2;

  final sentence = _lastMatchEnd(_sentenceEnd, text, windowStart, maxChars);
  if (sentence > 0) return sentence;

  final clause = _lastMatchEnd(_clauseEnd, text, windowStart, maxChars);
  if (clause > 0) return clause;

  final space = text.lastIndexOf(_whitespace, maxChars);
  if (space > 0) return space;

  // Không có chỗ nào để ngắt (chuỗi liền, ví dụ tiếng Trung không dấu câu).
  var cut = maxChars;
  final unit = text.codeUnitAt(cut - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF && cut > 1) cut--;
  return cut;
}
