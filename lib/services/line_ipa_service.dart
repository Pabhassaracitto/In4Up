// lib/services/line_ipa_service.dart
import '../features/shadowing/services/phoneme_analyzer.dart';

/// Tạo dòng phiên âm IPA xếp chồng dưới dòng văn bản trong Read Mode.
///
/// Pipeline tái dùng có sẵn: CMU Dict (EN, chính xác) → G2P rules (fallback).
/// Service KHÔNG tự init — [TextProvider] ensure engine khi user bật chế độ,
/// rồi clear cache để các dòng đã cache chất lượng thấp được dựng lại.
///
/// Quy tắc eligibility của một dòng (chặn rác trên chữ Việt/Pali):
///   1. Tách dòng theo whitespace.
///   2. Mỗi token: bỏ ký tự không-phải-chữ ở 2 đầu (dấu câu, số bám ngoài).
///   3. Token rỗng sau khi bỏ (toàn dấu câu / số) → bỏ qua, không tính.
///   4. Token không khớp `^[A-Za-z][A-Za-z']*$` (chữ lạ, hyphen nội tại…)
///      → CẢ DÒNG trả null — không render dòng IPA.
///   5. Nếu dòng không có từ nào → null.
///
/// Từ hợp lệ → list phoneme của resolver → join `''`
/// (stress nằm trong phoneme, vd `wˈɝld` — KHÔNG dùng `ipaString`
/// vì nó join bằng dấu chấm cho UI shadowing).
///
/// Cache theo đúng content dòng (kể cả null), cap [_maxCache] entry —
/// tràn thì clear-all (dòng cũ sẽ được tính lại khi cần).
class LineIpaService {
  LineIpaService._();

  static final Map<String, String?> _cache = {};
  static const int _maxCache = 600;

  /// Seam test: thay pipeline PhonemeAnalyzer bằng fake
  /// (trả về list phoneme đã join sẵn `''`, hoặc null nếu không có IPA).
  static String? Function(String word)? wordIpaOverride;

  /// Chỉ chữ Latin + apostrophe, bắt đầu bằng chữ cái.
  static final RegExp _asciiWord = RegExp(r"^[A-Za-z][A-Za-z']*$");

  /// Bỏ ký tự không phải chữ (letter Unicode) ở 2 đầu token.
  /// Giữ nguyên chữ có dấu để detect ≠ bỏ sót chữ Việt/Pali.
  static final RegExp _edgeNonLetter =
      RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true);

  /// Trả về dòng IPA cho [content], null nếu dòng không đủ điều kiện.
  static String? buildLineIpa(String content) {
    if (_cache.containsKey(content)) return _cache[content];
    final result = _compute(content);
    if (_cache.length >= _maxCache) _cache.clear();
    _cache[content] = result;
    return result;
  }

  /// Xóa toàn bộ cache — gọi sau khi CMU Dictionary finishes loading
  /// (entry cache trước đó có thể đã fallthrough sang G2P chất lượng thấp).
  static void clearCache() => _cache.clear();

  /// Số entry đang cache (cho test).
  static int get cacheSize => _cache.length;

  static String? _compute(String content) {
    // 1–4: thu thập từ hợp lệ; từ không đạt eligibility → hủy cả dòng.
    final words = <String>[];
    for (final raw in content.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final core = raw.replaceAll(_edgeNonLetter, '');
      if (core.isEmpty) continue; // token toàn dấu câu / số → bỏ qua
      if (!_asciiWord.hasMatch(core)) return null; // chữ lạ → null cả dòng
      words.add(core);
    }
    if (words.isEmpty) return null;

    // 5: tra IPA từng từ — từ không có phoneme bị bỏ qua (không tính).
    final override = wordIpaOverride;
    final parts = <String>[];
    for (final word in words) {
      final ipa = override != null
          ? override(word)
          : PhonemeAnalyzer.getPhonemes(word).phonemes.join('');
      if (ipa == null || ipa.isEmpty) continue;
      parts.add(ipa);
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}
