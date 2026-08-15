import '../../core/language/app_language.dart';

/// Lightweight on-device language detection used by translation and TTS.
///
/// Script-based languages are detected deterministically. Latin and
/// Devanagari languages use small stop-word profiles so an English voice is
/// never reused merely because the previous sentence was English/Vietnamese.
class LanguageDetector {
  LanguageDetector._();

  static AppLanguage detectLanguage(
    String text, {
    AppLanguage? fallback,
  }) {
    final effectiveFallback = fallback ?? AppLanguageCatalog.english;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return effectiveFallback;

    final runes = trimmed.runes.toList(growable: false);
    final counts = <String, int>{};
    void hit(String code) => counts[code] = (counts[code] ?? 0) + 1;

    var hanCount = 0;
    var hiraganaKatakanaCount = 0;
    var devanagariCount = 0;
    var cyrillicCount = 0;

    for (final rune in runes) {
      if (_inAny(rune, const [
        (0x0600, 0x06FF),
        (0x0750, 0x077F),
        (0x08A0, 0x08FF),
      ])) {
        hit('AR');
      } else if (_inRange(rune, 0x0980, 0x09FF)) {
        hit('BN');
      } else if (_inRange(rune, 0x0F00, 0x0FFF)) {
        hit('BO');
      } else if (_inRange(rune, 0x0900, 0x097F)) {
        devanagariCount++;
      } else if (_inAny(rune, const [
        (0x3040, 0x309F),
        (0x30A0, 0x30FF),
        (0x31F0, 0x31FF),
      ])) {
        hiraganaKatakanaCount++;
      } else if (_inRange(rune, 0x1780, 0x17FF)) {
        hit('KM');
      } else if (_inAny(rune, const [
        (0xAC00, 0xD7AF),
        (0x1100, 0x11FF),
        (0x3130, 0x318F),
      ])) {
        hit('KO');
      } else if (_inRange(rune, 0x0E80, 0x0EFF)) {
        hit('LO');
      } else if (_inRange(rune, 0x1800, 0x18AF)) {
        hit('MN');
      } else if (_inRange(rune, 0x1000, 0x109F)) {
        hit('MY');
      } else if (_inRange(rune, 0x0D80, 0x0DFF)) {
        hit('SI');
      } else if (_inRange(rune, 0x0B80, 0x0BFF)) {
        hit('TA');
      } else if (_inRange(rune, 0x0C00, 0x0C7F)) {
        hit('TE');
      } else if (_inRange(rune, 0x0E00, 0x0E7F)) {
        hit('TH');
      } else if (_inAny(rune, const [
        (0x4E00, 0x9FFF),
        (0x3400, 0x4DBF),
        (0xF900, 0xFAFF),
      ])) {
        hanCount++;
      } else if (_inRange(rune, 0x0400, 0x04FF)) {
        cyrillicCount++;
      }
    }

    if (hiraganaKatakanaCount > 0) {
      return AppLanguageCatalog.fromCode('JA');
    }
    if (devanagariCount > 0) {
      return AppLanguageCatalog.fromCode(_detectDevanagari(trimmed));
    }
    if (cyrillicCount > 0) {
      return AppLanguageCatalog.fromCode(_detectCyrillic(trimmed));
    }

    final scriptWinner = _winner(counts);
    if (scriptWinner != null) {
      return AppLanguageCatalog.fromCode(scriptWinner);
    }

    if (hanCount > 0) {
      final traditional = _traditionalChineseHints.hasMatch(trimmed);
      return AppLanguageCatalog.fromCode(traditional ? 'ZH-TW' : 'ZH');
    }

    return AppLanguageCatalog.fromCode(
      _detectLatinLanguage(
        trimmed,
        fallbackCode: effectiveFallback.translationCode,
      ),
      fallback: effectiveFallback,
    );
  }

  /// Backward-compatible API used by TTS engines.
  static String detect(String text) => detectLanguage(text).ttsLocale;

  static String detectTranslationCode(String text) =>
      detectLanguage(text).translationCode;

  static String _detectDevanagari(String text) {
    final tokens = _tokens(text);
    final marathi = _score(tokens, _marathiWords);
    final hindi = _score(tokens, _hindiWords);
    return marathi > hindi ? 'MR' : 'HI';
  }

  static String _detectCyrillic(String text) {
    final tokens = _tokens(text);
    final mongolian = _score(tokens, _mongolianWords);
    final russian = _score(tokens, _russianWords);
    return mongolian > russian ? 'MN' : 'RU';
  }

  static String _detectLatinLanguage(
    String text, {
    String fallbackCode = 'EN',
  }) {
    final normalized = text.toLowerCase();
    final tokens = _tokens(normalized);
    if (tokens.isEmpty) return 'EN';

    final scores = <String, int>{
      'DE': _score(tokens, _germanWords),
      'EN': _score(tokens, _englishWords),
      'ES': _score(tokens, _spanishWords),
      'FR': _score(tokens, _frenchWords),
      'ID': _score(tokens, _indonesianWords),
      'IT': _score(tokens, _italianWords),
      'PT': _score(tokens, _portugueseWords),
      'VI': _score(tokens, _vietnameseWords),
    };

    void bonus(String code, Pattern pattern, int value) {
      if (pattern.allMatches(normalized).isNotEmpty) {
        scores[code] = (scores[code] ?? 0) + value;
      }
    }

    bonus('DE', RegExp(r'[ßäöü]'), 4);
    bonus('ES', RegExp(r'[¿¡ñ]'), 4);
    bonus('FR', RegExp(r'[œëïÿ]'), 4);
    bonus('ID', RegExp(r'\b(yang|dengan|tidak|adalah|untuk)\b'), 3);
    bonus('IT', RegExp(r'\b(gli|della|sono|ciao|questo)\b'), 3);
    bonus('PT', RegExp(r'Content'), 4);
    bonus('VI', _strongVietnameseHints, 6);

    var winner = 'EN';
    var best = scores[winner] ?? 0;
    for (final entry in scores.entries) {
      if (entry.value > best) {
        winner = entry.key;
        best = entry.value;
      }
    }
    if (best == 0) {
      return AppLanguageCatalog.normalizeTranslationCode(
        fallbackCode,
        fallback: 'EN',
      );
    }
    return winner;
  }

  static List<String> _tokens(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}]+', unicode: true))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  static int _score(List<String> tokens, Set<String> profile) {
    var score = 0;
    for (final token in tokens) {
      if (profile.contains(token)) score += token.length <= 2 ? 1 : 2;
    }
    return score;
  }

  static String? _winner(Map<String, int> counts) {
    String? winner;
    var best = 0;
    for (final entry in counts.entries) {
      if (entry.value > best) {
        winner = entry.key;
        best = entry.value;
      }
    }
    return winner;
  }

  static bool _inRange(int value, int start, int end) =>
      value >= start && value <= end;

  static bool _inAny(int value, List<(int, int)> ranges) {
    for (final range in ranges) {
      if (_inRange(value, range.$1, range.$2)) return true;
    }
    return false;
  }

  static final _strongVietnameseHints = RegExp(
    r'Content',
  );

  static final _traditionalChineseHints = RegExp(
    r'[體學國語讀聽書這個為與時會來們說對開關後裡發現應實長萬東業]',
  );

  static const _englishWords = <String>{
    'the', 'and', 'is', 'are', 'to', 'of', 'in', 'that', 'this', 'you',
    'for', 'with', 'on', 'not', 'hello', 'from', 'have', 'be', 'was',
    'were', 'as', 'at', 'it', 'we', 'they', 'your', 'can', 'will'
  };
  static const _germanWords = <String>{
    'der', 'die', 'das', 'und', 'ist', 'sind', 'zu', 'von', 'mit', 'nicht',
    'ein', 'eine', 'ich', 'sie', 'wir', 'für', 'auf', 'den', 'dem', 'des',
    'hallo', 'dass', 'wie', 'auch'
  };
  static const _spanishWords = <String>{
    'el', 'la', 'los', 'las', 'y', 'es', 'son', 'de', 'que', 'en', 'un',
    'una', 'para', 'con', 'no', 'por', 'como', 'hola', 'del', 'yo', 'usted',
    'nosotros', 'este', 'esta'
  };
  static const _frenchWords = <String>{
    'le', 'la', 'les', 'et', 'est', 'sont', 'de', 'des', 'du', 'que', 'en',
    'un', 'une', 'pour', 'avec', 'pas', 'je', 'vous', 'nous', 'bonjour',
    'dans', 'ce', 'cette', 'sur'
  };
  static const _indonesianWords = <String>{
    'yang', 'dan', 'di', 'ke', 'dari', 'untuk', 'dengan', 'tidak', 'ini',
    'itu', 'adalah', 'saya', 'anda', 'kami', 'mereka', 'pada', 'selamat',
    'juga', 'akan', 'bisa'
  };
  static const _italianWords = <String>{
    'il', 'lo', 'la', 'gli', 'le', 'e', 'è', 'sono', 'di', 'che', 'in',
    'un', 'una', 'per', 'con', 'non', 'io', 'voi', 'noi', 'ciao', 'della',
    'questo', 'questa', 'come'
  };
  static const _portugueseWords = <String>{
    'o', 'a', 'os', 'as', 'e', 'é', 'Content', 'de', 'do', 'da', 'que', 'em',
    'um', 'uma', 'para', 'com', 'Content', 'eu', 'Content', 'Content', 'Content', 'este',
    'esta', 'como'
  };
  static const _vietnameseWords = <String>{
    'Content', 'Content', 'Content', 'cho', 'Content', 'Content', 'Content', 'Content', 'Content',
    'trong', 'Content', 'Content', 'Content', 'Content', 'Content', 'Content', 'xin', 'Content',
    'Content', 'Content', 'Content', 'Content', 'khi'
  };
  static const _russianWords = <String>{
    'и', 'в', 'не', 'на', 'что', 'я', 'он', 'она', 'мы', 'вы', 'это',
    'как', 'с', 'по', 'для', 'привет', 'есть'
  };
  static const _mongolianWords = <String>{
    'ба', 'бөгөөд', 'нь', 'энэ', 'тэр', 'би', 'та', 'бид', 'сайн', 'байна',
    'уу', 'үгүй', 'дээр', 'хэл', 'монгол'
  };
  static const _hindiWords = <String>{
    'और', 'है', 'हैं', 'का', 'की', 'के', 'में', 'यह', 'वह', 'नहीं', 'से',
    'को', 'मैं', 'आप', 'हम', 'लिए'
  };
  static const _marathiWords = <String>{
    'आणि', 'आहे', 'आहेत', 'च्या', 'मध्ये', 'नाही', 'मी', 'तुम्ही', 'आपण',
    'हे', 'ते', 'ला', 'साठी', 'एक'
  };
}