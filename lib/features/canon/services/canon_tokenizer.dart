// lib/features/canon/services/canon_tokenizer.dart
//
// Tokenizer + normalizer cho tiếng Việt / Pali / English.
// - lowerCase
// - strip diacritics (để "niem xu" match "niệm xứ")
// - tách theo Unicode word boundaries
// - bỏ stopwords ngắn
// - giữ cả bản có dấu và không dấu để score ưu tiên match chính xác

class CanonTokenizer {
  // Bảng ánh xạ bỏ dấu tiếng Việt (thủ công, không cần package)
  static const _vietMap = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'đ': 'd',
    // Pali với diacritics: ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ
    'ā': 'a', 'ī': 'i', 'ū': 'u', 'ṁ': 'm', 'ṃ': 'm',
    'ṅ': 'n', 'ñ': 'n', 'ṭ': 't', 'ḍ': 'd', 'ṇ': 'n', 'ḷ': 'l',
  };

  static const _stopWords = {
    'va', 'la', 'cua', 'ma', 'thi', 'de', 'cac', 'mot', 'nhung', 'voi', 'cho', 'den', 'tu',
    'the', 'and', 'or', 'a', 'an', 'et', 'is', 'are', 'be', 'to', 'of', 'in', 'on',
  };

  /// Bỏ dấu, lowerCase
  static String stripDiacritics(String input) {
    final lower = input.toLowerCase();
    final sb = StringBuffer();
    for (int i = 0; i < lower.length; i++) {
      final ch = lower[i];
      sb.write(_vietMap[ch] ?? ch);
    }
    // loại bỏ combining marks còn sót (nếu có)
    return sb.toString();
  }

  /// Tokenize giữ nguyên dấu (dùng cho hiển thị/highlight)
  static List<String> tokenizeKeepDiacritics(String text) {
    final lower = text.toLowerCase();
    // tách theo ký tự không phải chữ/số (Unicode)
    final parts = lower.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true));
    return parts.where((w) => w.length >= 2 && !_stopWords.contains(w)).toList();
  }

  /// Tokenize đã bỏ dấu (dùng cho index/search)
  static List<String> tokenize(String text) {
    final stripped = stripDiacritics(text);
    final parts = stripped.split(RegExp(r'[^a-z0-9]+'));
    return parts.where((w) => w.length >= 2 && !_stopWords.contains(w)).toList();
  }

  /// Tạo n-gram cho prefix suggest (optional)
  static List<String> ngrams(String token, {int min = 2}) {
    final out = <String>[];
    for (int i = min; i <= token.length; i++) {
      out.add(token.substring(0, i));
    }
    return out;
  }

  /// Chuẩn hóa query: bỏ dấu + tokenize
  static List<String> queryTokens(String query) => tokenize(query);

  /// Từ query gốc, trả về cả 2 dạng: có dấu và không dấu để ưu tiên
  static ({List<String> raw, List<String> stripped}) bothForms(String query) {
    final raw = tokenizeKeepDiacritics(query);
    final stripped = tokenize(query);
    return (raw: raw, stripped: stripped);
  }
}
