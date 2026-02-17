// lib/features/tts/language_detector.dart

/// Tự động phát hiện ngôn ngữ của text
class LanguageDetector {
  /// Detect ngôn ngữ chính của text
  /// Trả về language code: 'vi-VN', 'en-US', 'ja-JP', 'ko-KR', 'zh-CN'
  static String detect(String text) {
    if (text.trim().isEmpty) return 'en-US';

    final cleaned = text.replaceAll(RegExp(r'[0-9\s\p{P}]', unicode: true), '');
    if (cleaned.isEmpty) return 'en-US';

    int viCount = 0;
    int enCount = 0;
    int jaCount = 0;
    int koCount = 0;
    int zhCount = 0;

    for (final char in cleaned.runes) {
      if (_isVietnamese(char)) {
        viCount++;
      } else if (_isJapanese(char)) {
        jaCount++;
      } else if (_isKorean(char)) {
        koCount++;
      } else if (_isChinese(char)) {
        zhCount++;
      } else if (_isLatin(char)) {
        enCount++;
      }
    }

    final total = cleaned.length;
    if (total == 0) return 'en-US';

    // Tiếng Việt: có dấu đặc biệt
    if (viCount > 0 && viCount.toDouble() / total > 0.05) return 'vi-VN';

    // CJK languages
    if (jaCount > 0 && jaCount >= koCount && jaCount >= zhCount) return 'ja-JP';
    if (koCount > 0 && koCount >= jaCount && koCount >= zhCount) return 'ko-KR';
    if (zhCount > 0) return 'zh-CN';

    // Mặc định Latin → English
    if (enCount > 0) return 'en-US';

    return 'en-US';
  }

  /// Kiểm tra có phải ký tự Việt đặc biệt (có dấu)
  static bool _isVietnamese(int code) {
    // Các ký tự Việt đặc trưng (có dấu)
    // ă, â, đ, ê, ô, ơ, ư và các biến thể có thanh
    const viRanges = [
      [0x00C0, 0x00C3], // À-Ã
      [0x00C8, 0x00CA], // È-Ê
      [0x00CC, 0x00CD], // Ì-Í
      [0x00D2, 0x00D5], // Ò-Õ
      [0x00D9, 0x00DA], // Ù-Ú
      [0x00DD, 0x00DD], // Ý
      [0x00E0, 0x00E3], // à-ã
      [0x00E8, 0x00EA], // è-ê
      [0x00EC, 0x00ED], // ì-í
      [0x00F2, 0x00F5], // ò-õ
      [0x00F9, 0x00FA], // ù-ú
      [0x00FD, 0x00FD], // ý
      [0x0102, 0x0103], // Ă ă
      [0x0110, 0x0111], // Đ đ
      [0x0128, 0x0129], // Ĩ ĩ
      [0x0168, 0x0169], // Ũ ũ
      [0x01A0, 0x01B0], // Ơ ơ Ư ư
      [0x1EA0, 0x1EF9], // Vietnamese diacritics block
    ];

    for (final range in viRanges) {
      if (code >= range[0] && code <= range[1]) return true;
    }
    return false;
  }

  static bool _isJapanese(int code) {
    return (code >= 0x3040 && code <= 0x309F) || // Hiragana
        (code >= 0x30A0 && code <= 0x30FF) || // Katakana
        (code >= 0x31F0 && code <= 0x31FF); // Katakana ext
  }

  static bool _isKorean(int code) {
    return (code >= 0xAC00 && code <= 0xD7AF) || // Hangul Syllables
        (code >= 0x1100 && code <= 0x11FF) || // Hangul Jamo
        (code >= 0x3130 && code <= 0x318F); // Hangul Compatibility
  }

  static bool _isChinese(int code) {
    return (code >= 0x4E00 && code <= 0x9FFF) || // CJK Unified
        (code >= 0x3400 && code <= 0x4DBF) || // CJK Extension A
        (code >= 0xF900 && code <= 0xFAFF); // CJK Compatibility
  }

  static bool _isLatin(int code) {
    return (code >= 0x0041 && code <= 0x005A) || // A-Z
        (code >= 0x0061 && code <= 0x007A); // a-z
  }
}
