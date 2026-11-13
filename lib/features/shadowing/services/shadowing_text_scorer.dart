/// Pure, deterministic shadowing text coverage scorer (PSRC-227).
///
/// The reference sentence is the denominator. Missing words, wrong words and
/// extra words all lower the score; word order is preserved by sequence
/// alignment. This is text/STT coverage, not a new acoustic recognition model.
library;

enum ShadowingNumberLanguage { english, vietnamese }

class ShadowingWordAlignment {
  const ShadowingWordAlignment({
    required this.expected,
    required this.recognized,
    required this.credit,
  });

  final String expected;
  final String? recognized;
  final double credit;
  bool get isCorrect => credit >= 1.0;
}

class ShadowingTextScore {
  const ShadowingTextScore({
    required this.score,
    required this.alignments,
    required this.extraWordCount,
    required this.referenceWordCount,
    required this.recognizedWordCount,
  });

  final double score;
  final List<ShadowingWordAlignment> alignments;
  final int extraWordCount;
  final int referenceWordCount;
  final int recognizedWordCount;
}

class ShadowingTextScorer {
  ShadowingTextScorer._();

  // Latin/Vietnamese canonical composition pairs. Dart has no built-in Unicode
  // normalizer and this lane must not add a dependency; the table covers the
  // precomposed Latin letters used by the app's vi/en/Pāli content.
  static const Map<String, String> _nfcPairs = {
    'a\u{0300}': 'à',
    'a\u{0301}': 'á',
    'a\u{0302}': 'â',
    'a\u{0303}': 'ã',
    'a\u{0304}': 'ā',
    'a\u{0306}': 'ă',
    'a\u{0307}': 'ȧ',
    'a\u{0308}': 'ä',
    'a\u{0309}': 'ả',
    'a\u{030a}': 'å',
    'a\u{030c}': 'ǎ',
    'a\u{030f}': 'ȁ',
    'a\u{0311}': 'ȃ',
    'a\u{0323}': 'ạ',
    'a\u{0325}': 'ḁ',
    'a\u{0328}': 'ą',
    'b\u{0307}': 'ḃ',
    'b\u{0323}': 'ḅ',
    'b\u{0331}': 'ḇ',
    'c\u{0301}': 'ć',
    'c\u{0302}': 'ĉ',
    'c\u{0307}': 'ċ',
    'c\u{030c}': 'č',
    'c\u{0327}': 'ç',
    'd\u{0307}': 'ḋ',
    'd\u{030c}': 'ď',
    'd\u{0323}': 'ḍ',
    'd\u{0327}': 'ḑ',
    'd\u{032d}': 'ḓ',
    'd\u{0331}': 'ḏ',
    'e\u{0300}': 'è',
    'e\u{0301}': 'é',
    'e\u{0302}': 'ê',
    'e\u{0303}': 'ẽ',
    'e\u{0304}': 'ē',
    'e\u{0306}': 'ĕ',
    'e\u{0307}': 'ė',
    'e\u{0308}': 'ë',
    'e\u{0309}': 'ẻ',
    'e\u{030c}': 'ě',
    'e\u{030f}': 'ȅ',
    'e\u{0311}': 'ȇ',
    'e\u{0323}': 'ẹ',
    'e\u{0327}': 'ȩ',
    'e\u{0328}': 'ę',
    'e\u{032d}': 'ḙ',
    'e\u{0330}': 'ḛ',
    'f\u{0307}': 'ḟ',
    'g\u{0301}': 'ǵ',
    'g\u{0302}': 'ĝ',
    'g\u{0304}': 'ḡ',
    'g\u{0306}': 'ğ',
    'g\u{0307}': 'ġ',
    'g\u{030c}': 'ǧ',
    'g\u{0327}': 'ģ',
    'h\u{0302}': 'ĥ',
    'h\u{0307}': 'ḣ',
    'h\u{0308}': 'ḧ',
    'h\u{030c}': 'ȟ',
    'h\u{0323}': 'ḥ',
    'h\u{0327}': 'ḩ',
    'h\u{032e}': 'ḫ',
    'h\u{0331}': 'ẖ',
    'i\u{0300}': 'ì',
    'i\u{0301}': 'í',
    'i\u{0302}': 'î',
    'i\u{0303}': 'ĩ',
    'i\u{0304}': 'ī',
    'i\u{0306}': 'ĭ',
    'i\u{0308}': 'ï',
    'i\u{0309}': 'ỉ',
    'i\u{030c}': 'ǐ',
    'i\u{030f}': 'ȉ',
    'i\u{0311}': 'ȋ',
    'i\u{0323}': 'ị',
    'i\u{0328}': 'į',
    'i\u{0330}': 'ḭ',
    'j\u{0302}': 'ĵ',
    'j\u{030c}': 'ǰ',
    'k\u{0301}': 'ḱ',
    'k\u{030c}': 'ǩ',
    'k\u{0323}': 'ḳ',
    'k\u{0327}': 'ķ',
    'k\u{0331}': 'ḵ',
    'l\u{0301}': 'ĺ',
    'l\u{030c}': 'ľ',
    'l\u{0323}': 'ḷ',
    'l\u{0327}': 'ļ',
    'l\u{032d}': 'ḽ',
    'l\u{0331}': 'ḻ',
    'm\u{0301}': 'ḿ',
    'm\u{0307}': 'ṁ',
    'm\u{0323}': 'ṃ',
    'n\u{0300}': 'ǹ',
    'n\u{0301}': 'ń',
    'n\u{0303}': 'ñ',
    'n\u{0307}': 'ṅ',
    'n\u{030c}': 'ň',
    'n\u{0323}': 'ṇ',
    'n\u{0327}': 'ņ',
    'n\u{032d}': 'ṋ',
    'n\u{0331}': 'ṉ',
    'o\u{0300}': 'ò',
    'o\u{0301}': 'ó',
    'o\u{0302}': 'ô',
    'o\u{0303}': 'õ',
    'o\u{0304}': 'ō',
    'o\u{0306}': 'ŏ',
    'o\u{0307}': 'ȯ',
    'o\u{0308}': 'ö',
    'o\u{0309}': 'ỏ',
    'o\u{030b}': 'ő',
    'o\u{030c}': 'ǒ',
    'o\u{030f}': 'ȍ',
    'o\u{0311}': 'ȏ',
    'o\u{031b}': 'ơ',
    'o\u{0323}': 'ọ',
    'o\u{0328}': 'ǫ',
    'p\u{0301}': 'ṕ',
    'p\u{0307}': 'ṗ',
    'r\u{0301}': 'ŕ',
    'r\u{0307}': 'ṙ',
    'r\u{030c}': 'ř',
    'r\u{030f}': 'ȑ',
    'r\u{0311}': 'ȓ',
    'r\u{0323}': 'ṛ',
    'r\u{0327}': 'ŗ',
    'r\u{0331}': 'ṟ',
    's\u{0301}': 'ś',
    's\u{0302}': 'ŝ',
    's\u{0307}': 'ṡ',
    's\u{030c}': 'š',
    's\u{0323}': 'ṣ',
    's\u{0326}': 'ș',
    's\u{0327}': 'ş',
    't\u{0307}': 'ṫ',
    't\u{0308}': 'ẗ',
    't\u{030c}': 'ť',
    't\u{0323}': 'ṭ',
    't\u{0326}': 'ț',
    't\u{0327}': 'ţ',
    't\u{032d}': 'ṱ',
    't\u{0331}': 'ṯ',
    'u\u{0300}': 'ù',
    'u\u{0301}': 'ú',
    'u\u{0302}': 'û',
    'u\u{0303}': 'ũ',
    'u\u{0304}': 'ū',
    'u\u{0306}': 'ŭ',
    'u\u{0308}': 'ü',
    'u\u{0309}': 'ủ',
    'u\u{030a}': 'ů',
    'u\u{030b}': 'ű',
    'u\u{030c}': 'ǔ',
    'u\u{030f}': 'ȕ',
    'u\u{0311}': 'ȗ',
    'u\u{031b}': 'ư',
    'u\u{0323}': 'ụ',
    'u\u{0324}': 'ṳ',
    'u\u{0328}': 'ų',
    'u\u{032d}': 'ṷ',
    'u\u{0330}': 'ṵ',
    'v\u{0303}': 'ṽ',
    'v\u{0323}': 'ṿ',
    'w\u{0300}': 'ẁ',
    'w\u{0301}': 'ẃ',
    'w\u{0302}': 'ŵ',
    'w\u{0307}': 'ẇ',
    'w\u{0308}': 'ẅ',
    'w\u{030a}': 'ẘ',
    'w\u{0323}': 'ẉ',
    'x\u{0307}': 'ẋ',
    'x\u{0308}': 'ẍ',
    'y\u{0300}': 'ỳ',
    'y\u{0301}': 'ý',
    'y\u{0302}': 'ŷ',
    'y\u{0303}': 'ỹ',
    'y\u{0304}': 'ȳ',
    'y\u{0307}': 'ẏ',
    'y\u{0308}': 'ÿ',
    'y\u{0309}': 'ỷ',
    'y\u{030a}': 'ẙ',
    'y\u{0323}': 'ỵ',
    'z\u{0301}': 'ź',
    'z\u{0302}': 'ẑ',
    'z\u{0307}': 'ż',
    'z\u{030c}': 'ž',
    'z\u{0323}': 'ẓ',
    'z\u{0331}': 'ẕ',
    '\u{00e2}\u{0300}': 'ầ',
    '\u{00e2}\u{0301}': 'ấ',
    '\u{00e2}\u{0303}': 'ẫ',
    '\u{00e2}\u{0309}': 'ẩ',
    '\u{00e4}\u{0304}': 'ǟ',
    '\u{00e5}\u{0301}': 'ǻ',
    '\u{00e6}\u{0301}': 'ǽ',
    '\u{00e6}\u{0304}': 'ǣ',
    '\u{00e7}\u{0301}': 'ḉ',
    '\u{00ea}\u{0300}': 'ề',
    '\u{00ea}\u{0301}': 'ế',
    '\u{00ea}\u{0303}': 'ễ',
    '\u{00ea}\u{0309}': 'ể',
    '\u{00ef}\u{0301}': 'ḯ',
    '\u{00f4}\u{0300}': 'ồ',
    '\u{00f4}\u{0301}': 'ố',
    '\u{00f4}\u{0303}': 'ỗ',
    '\u{00f4}\u{0309}': 'ổ',
    '\u{00f5}\u{0301}': 'ṍ',
    '\u{00f5}\u{0304}': 'ȭ',
    '\u{00f5}\u{0308}': 'ṏ',
    '\u{00f6}\u{0304}': 'ȫ',
    '\u{00f8}\u{0301}': 'ǿ',
    '\u{00fc}\u{0300}': 'ǜ',
    '\u{00fc}\u{0301}': 'ǘ',
    '\u{00fc}\u{0304}': 'ǖ',
    '\u{00fc}\u{030c}': 'ǚ',
    '\u{0103}\u{0300}': 'ằ',
    '\u{0103}\u{0301}': 'ắ',
    '\u{0103}\u{0303}': 'ẵ',
    '\u{0103}\u{0309}': 'ẳ',
    '\u{0113}\u{0300}': 'ḕ',
    '\u{0113}\u{0301}': 'ḗ',
    '\u{014d}\u{0300}': 'ṑ',
    '\u{014d}\u{0301}': 'ṓ',
    '\u{015b}\u{0307}': 'ṥ',
    '\u{0161}\u{0307}': 'ṧ',
    '\u{0169}\u{0301}': 'ṹ',
    '\u{016b}\u{0308}': 'ṻ',
    '\u{017f}\u{0307}': 'ẛ',
    '\u{01a1}\u{0300}': 'ờ',
    '\u{01a1}\u{0301}': 'ớ',
    '\u{01a1}\u{0303}': 'ỡ',
    '\u{01a1}\u{0309}': 'ở',
    '\u{01a1}\u{0323}': 'ợ',
    '\u{01b0}\u{0300}': 'ừ',
    '\u{01b0}\u{0301}': 'ứ',
    '\u{01b0}\u{0303}': 'ữ',
    '\u{01b0}\u{0309}': 'ử',
    '\u{01b0}\u{0323}': 'ự',
    '\u{01eb}\u{0304}': 'ǭ',
    '\u{0227}\u{0304}': 'ǡ',
    '\u{0229}\u{0306}': 'ḝ',
    '\u{022f}\u{0304}': 'ȱ',
    '\u{0292}\u{030c}': 'ǯ',
    '\u{1e37}\u{0304}': 'ḹ',
    '\u{1e5b}\u{0304}': 'ṝ',
    '\u{1e63}\u{0307}': 'ṩ',
    '\u{1ea1}\u{0302}': 'ậ',
    '\u{1ea1}\u{0306}': 'ặ',
    '\u{1eb9}\u{0302}': 'ệ',
    '\u{1ecd}\u{0302}': 'ộ',
  };

  static final RegExp _tokenPattern = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
  static final RegExp _marks = RegExp(r'\p{M}', unicode: true);
  static final RegExp _numberPattern = RegExp(r'\d+(?:[.,]\d+)?');
  static final RegExp _vietnameseChars = RegExp(
    r'[ăâđêôơưáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]',
  );
  static const Set<String> _vietnameseWords = {
    'tôi', 'bạn', 'là', 'và', 'của', 'có', 'không', 'được', 'người', 'những',
    'các', 'đang', 'sẽ', 'đã', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy',
    'tám', 'chín', 'mười', 'trăm', 'nghìn', 'triệu', 'con', 'mèo', 'chó',
  };

  static String composeNfc(String input) {
    final out = <int>[];
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (out.isNotEmpty && _isCombining(rune)) {
        final base = String.fromCharCode(out.last);
        final lowerBase = base.toLowerCase();
        final composed = _nfcPairs['$base$ch'] ?? _nfcPairs['$lowerBase$ch'];
        if (composed != null) {
          final upper = base != lowerBase && base == base.toUpperCase();
          out[out.length - 1] = (upper ? composed.toUpperCase() : composed).runes.first;
          continue;
        }
      }
      out.add(rune);
    }
    return String.fromCharCodes(out);
  }

  static bool _isCombining(int rune) =>
      (rune >= 0x0300 && rune <= 0x036F) ||
      (rune >= 0x1AB0 && rune <= 0x1AFF) ||
      (rune >= 0x1DC0 && rune <= 0x1DFF) ||
      rune == 0x0323 || rune == 0x0327 || rune == 0x0328;

  static ShadowingNumberLanguage detectNumberLanguage(String text) {
    final lower = text.toLowerCase();
    if (_vietnameseChars.hasMatch(lower)) return ShadowingNumberLanguage.vietnamese;
    final tokens = _tokenPattern.allMatches(lower).map((m) => m.group(0)!);
    if (tokens.any(_vietnameseWords.contains)) {
      return ShadowingNumberLanguage.vietnamese;
    }
    return ShadowingNumberLanguage.english;
  }

  static List<String> normalizeTokens(
    String text, {
    ShadowingNumberLanguage? numberLanguage,
  }) {
    if (text.trim().isEmpty) return const [];
    final language = numberLanguage ?? detectNumberLanguage(text);
    var normalized = composeNfc(text).toLowerCase();
    normalized = normalized.replaceAllMapped(_numberPattern, (m) {
      return ' ${_numberToWords(m.group(0)!, language)} ';
    });
    return _tokenPattern
        .allMatches(normalized)
        .map((m) => m.group(0)!)
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }

  static final Map<String, String> _foldMap = {
    for (final entry in _nfcPairs.entries)
      entry.value: String.fromCharCode(entry.key.runes.first),
  };

  /// Bỏ dấu cả ký tự precomposed ("tôi" → "toi") lẫn dạng decomposed đã
  /// tách marks — chỉ xóa \p{M} không fold được precomposed (PSRC-227).
  /// Fold lặp đến ổn định vì bảng có chuỗi ("ợ" → "ơ" → "o").
  static String accentFold(String token) {
    final buffer = StringBuffer();
    for (final rune in token.runes) {
      var ch = String.fromCharCode(rune);
      var next = _foldMap[ch];
      var guard = 0;
      while (next != null && next != ch && guard++ < 4) {
        ch = next;
        next = _foldMap[ch];
      }
      buffer.write(ch);
    }
    return buffer.toString().replaceAll('đ', 'd').replaceAll(_marks, '');
  }

  static double wordCredit(String expected, String recognized) {
    if (expected == recognized) return 1.0;
    if (accentFold(expected) == accentFold(recognized)) return 0.8;
    final a = accentFold(expected);
    final b = accentFold(recognized);
    final minLen = a.length < b.length ? a.length : b.length;
    final maxLen = a.length < b.length ? b.length : a.length;
    // Một ký tự chênh lệch trên từ đủ dài: 0.6 (> 0.5) để "gần đúng"
    // vẫn qua ngưỡng isCorrect 0.6 của SpeakScorer (knowledge adapter).
    if (minLen >= 4 && maxLen >= 5 && _levenshtein(a, b) == 1) return 0.6;
    return 0.0;
  }

  static ShadowingTextScore score(
    String originalText,
    String recognizedText, {
    ShadowingNumberLanguage? numberLanguage,
  }) {
    final language = numberLanguage ?? detectNumberLanguage(originalText);
    final reference = normalizeTokens(originalText, numberLanguage: language);
    final recognized = normalizeTokens(recognizedText, numberLanguage: language);
    final n = reference.length;
    final m = recognized.length;
    if (n == 0) {
      return ShadowingTextScore(
        score: 0,
        alignments: const [],
        extraWordCount: m,
        referenceWordCount: 0,
        recognizedWordCount: m,
      );
    }

    final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      cost[i][0] = i.toDouble();
    }
    for (var j = 1; j <= m; j++) {
      cost[0][j] = j.toDouble();
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final substitution = cost[i - 1][j - 1] + 1 - wordCredit(reference[i - 1], recognized[j - 1]);
        final deletion = cost[i - 1][j] + 1;
        final insertion = cost[i][j - 1] + 1;
        var best = substitution;
        if (deletion < best) best = deletion;
        if (insertion < best) best = insertion;
        cost[i][j] = best;
      }
    }

    final alignments = <ShadowingWordAlignment>[];
    var extra = 0;
    var credit = 0.0;
    var i = n;
    var j = m;
    bool near(double a, double b) => (a - b).abs() < 1e-9;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 &&
          near(cost[i][j], cost[i - 1][j - 1] + 1 - wordCredit(reference[i - 1], recognized[j - 1]))) {
        final c = wordCredit(reference[i - 1], recognized[j - 1]);
        alignments.add(ShadowingWordAlignment(
          expected: reference[i - 1],
          recognized: recognized[j - 1],
          credit: c,
        ));
        credit += c;
        i--;
        j--;
      } else if (i > 0 && near(cost[i][j], cost[i - 1][j] + 1)) {
        alignments.add(ShadowingWordAlignment(
          expected: reference[i - 1],
          recognized: null,
          credit: 0,
        ));
        i--;
      } else {
        extra++;
        j--;
      }
    }
    final denominator = n > m ? n : m;
    return ShadowingTextScore(
      score: (credit / denominator).clamp(0.0, 1.0).toDouble(),
      alignments: alignments.reversed.toList(growable: false),
      extraWordCount: extra,
      referenceWordCount: n,
      recognizedWordCount: m,
    );
  }

  static int _levenshtein(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, i);
      for (var j = 1; j <= b.length; j++) {
        final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        var best = substitution;
        if (deletion < best) best = deletion;
        if (insertion < best) best = insertion;
        current[j] = best;
      }
      previous = current;
    }
    return previous[b.length];
  }

  static const _enOnes = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
    'sixteen', 'seventeen', 'eighteen', 'nineteen',
  ];
  static const _enTens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  ];
  static const _viOnes = [
    'không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín',
    'mười', 'mười một', 'mười hai', 'mười ba', 'mười bốn', 'mười lăm',
    'mười sáu', 'mười bảy', 'mười tám', 'mười chín',
  ];

  static String _numberToWords(String raw, ShadowingNumberLanguage language) {
    final separator = raw.contains(',') ? ',' : (raw.contains('.') ? '.' : null);
    if (separator != null) {
      final parts = raw.split(separator);
      final integer = _integerToWords(int.tryParse(parts[0]) ?? 0, language);
      final fraction = parts[1].split('').map((d) {
        final digit = int.tryParse(d) ?? 0;
        return language == ShadowingNumberLanguage.vietnamese ? _viOnes[digit] : _enOnes[digit];
      }).join(' ');
      final point = language == ShadowingNumberLanguage.vietnamese ? 'phẩy' : 'point';
      return '$integer $point $fraction';
    }
    final value = int.tryParse(raw);
    if (value == null) return raw;
    return _integerToWords(value, language);
  }

  static String _integerToWords(int value, ShadowingNumberLanguage language) {
    if (value < 0 || value > 999999999) return value.toString();
    if (language == ShadowingNumberLanguage.vietnamese) return _viInteger(value);
    return _enInteger(value);
  }

  static String _enInteger(int value) {
    if (value < 20) return _enOnes[value];
    if (value < 100) {
      final tens = _enTens[value ~/ 10];
      final rest = value % 10;
      return rest == 0 ? tens : '$tens ${_enOnes[rest]}';
    }
    if (value < 1000) {
      final hundreds = '${_enOnes[value ~/ 100]} hundred';
      final rest = value % 100;
      return rest == 0 ? hundreds : '$hundreds ${_enInteger(rest)}';
    }
    if (value < 1000000) {
      final thousands = '${_enInteger(value ~/ 1000)} thousand';
      final rest = value % 1000;
      return rest == 0 ? thousands : '$thousands ${_enInteger(rest)}';
    }
    final millions = '${_enInteger(value ~/ 1000000)} million';
    final rest = value % 1000000;
    return rest == 0 ? millions : '$millions ${_enInteger(rest)}';
  }

  static String _viInteger(int value) {
    if (value < 20) return _viOnes[value];
    if (value < 100) {
      final tens = '${_viOnes[value ~/ 10]} mươi';
      final rest = value % 10;
      if (rest == 0) return tens;
      if (rest == 1) return '$tens mốt';
      if (rest == 5) return '$tens lăm';
      return '$tens ${_viOnes[rest]}';
    }
    if (value < 1000) {
      final hundreds = '${_viOnes[value ~/ 100]} trăm';
      final rest = value % 100;
      if (rest == 0) return hundreds;
      if (rest < 10) return '$hundreds lẻ ${_viOnes[rest]}';
      return '$hundreds ${_viInteger(rest)}';
    }
    if (value < 1000000) {
      final thousands = '${_viInteger(value ~/ 1000)} nghìn';
      final rest = value % 1000;
      if (rest == 0) return thousands;
      if (rest < 100) return '$thousands không trăm ${_viInteger(rest)}';
      return '$thousands ${_viInteger(rest)}';
    }
    final millions = '${_viInteger(value ~/ 1000000)} triệu';
    final rest = value % 1000000;
    if (rest == 0) return millions;
    if (rest < 100000) return '$millions không trăm ${_viInteger(rest)}';
    return '$millions ${_viInteger(rest)}';
  }
}
