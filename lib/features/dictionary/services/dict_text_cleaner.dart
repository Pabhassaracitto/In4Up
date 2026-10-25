// lib/features/dictionary/services/dict_text_cleaner.dart
//
// DICT-CLEAN-001 — Làm sạch + cấu trúc hoá nội dung MDX trước khi hiển thị.
//
// Vì sao cần: `DictEntry.plainDefinition` cũ chỉ bỏ thẻ HTML
// (`replaceAll(RegExp(r'<[^>]*>'), '')`) nên vẫn giữ lại CSS/JS/entity/URL và
// các dòng tiêu đề lặp của từng bộ từ điển. Khi 2–3 bộ MDX cùng trả một từ,
// sheet tra cứu in ra 3 khối text dài gần giống nhau ⇒ "dư thừa" đúng như
// phản hồi của người sở hữu.
//
// Lớp này KHÔNG đụng `mdx_parser` (DICT-001 sở hữu) — chỉ xử lý ở đầu ra:
//   1. `plain()`  : text sạch, một dòng — dùng cho lưu/auto-fill/AI prompt.
//   2. `parse()`  : `DictDefinition` có IPA + nhóm loại từ + nghĩa đánh số +
//                   ví dụ, để render như một từ điển thật.
//   3. `merge()`  : gộp nhiều bộ từ điển, KHỬ nghĩa trùng, giữ nhãn nguồn.
//
// Ràng buộc:
// - `plain()` vẫn PHẢI giữ chuỗi IPA (`/…/` hoặc `[...]`) trong text: các nơi
//   khác (IpaResolver → IpaDefinitionExtractor) trích IPA từ chính chuỗi này.
// - Hàm thuần Dart, không phụ thuộc Flutter ⇒ test được bằng `dart test`.

/// Một nghĩa (sense) đã tách khỏi HTML từ điển.
class DictSense {
  final String text;

  /// Câu ví dụ đi kèm nghĩa (có thể rỗng).
  final List<String> examples;

  const DictSense(this.text, {this.examples = const <String>[]});

  DictSense withExample(String example) {
    final trimmed = example.trim();
    if (trimmed.isEmpty || examples.contains(trimmed)) return this;
    return DictSense(
      text,
      examples: <String>[...examples, trimmed],
    );
  }
}

/// Nhóm nghĩa theo loại từ (`n.`, `v.`, `adj.`… — null = không rõ).
class DictPosGroup {
  final String? pos;
  final List<DictSense> senses;

  const DictPosGroup({this.pos, this.senses = const <DictSense>[]});
}

/// Nội dung một entry từ điển đã được làm sạch + cấu trúc.
class DictDefinition {
  final String headword;
  final String? ipa;
  final List<DictPosGroup> groups;

  /// Text phẳng đã làm sạch (dùng khi cần 1 chuỗi liền).
  final String plainText;

  const DictDefinition({
    required this.headword,
    this.ipa,
    this.groups = const <DictPosGroup>[],
    required this.plainText,
  });

  static const DictDefinition empty = DictDefinition(
    headword: '',
    plainText: '',
  );

  bool get isEmpty => groups.isEmpty && plainText.isEmpty;

  List<DictSense> get senses => <DictSense>[
        for (final group in groups) ...group.senses,
      ];

  int get senseCount => senses.length;

  /// Nhãn loại từ ngắn (`noun, verb`) để hiển thị cạnh IPA.
  String? get partOfSpeechLabel {
    final labels = <String>[
      for (final group in groups)
        if ((group.pos ?? '').trim().isNotEmpty) group.pos!.trim(),
    ];
    if (labels.isEmpty) return null;
    return labels.join(', ');
  }

  /// Nghĩa cô đọng để nhúng trong PDF/Read Mode (không phải trang từ điển).
  String compactMeaning({int maxSenses = 3, int maxChars = 220}) {
    if (senses.isEmpty) return DictTextCleaner.truncate(plainText, maxChars);
    final parts = <String>[];
    for (final sense in senses) {
      if (parts.length >= maxSenses) break;
      final text = sense.text.trim();
      if (text.isEmpty) continue;
      parts.add(text);
    }
    if (parts.isEmpty) return DictTextCleaner.truncate(plainText, maxChars);
    return DictTextCleaner.truncate(parts.join(' • '), maxChars);
  }
}

/// Một entry từ điển thô đưa vào [DictTextCleaner.merge].
///
/// Giữ lớp sạch này KHÔNG import `DictEntry` để tránh vòng import
/// (`DictEntry.plainDefinition` gọi ngược lại cleaner).
class DictSourceText {
  final String headword;
  final String definition;
  final String? phonetic;

  /// Tên bộ từ điển (nhãn nguồn hiển thị dưới nghĩa).
  final String sourceLabel;

  const DictSourceText({
    required this.headword,
    required this.definition,
    this.phonetic,
    this.sourceLabel = '',
  });
}

/// Kết quả gộp nhiều bộ từ điển cho cùng một từ — đã khử nghĩa trùng.
class DictMergedEntry {
  final String headword;
  final String? ipa;
  final List<DictPosGroup> groups;
  final List<String> sourceLabels;

  const DictMergedEntry({
    required this.headword,
    this.ipa,
    this.groups = const <DictPosGroup>[],
    this.sourceLabels = const <String>[],
  });

  bool get isEmpty => groups.isEmpty;

  List<DictSense> get senses => <DictSense>[
        for (final group in groups) ...group.senses,
      ];

  int get senseCount => senses.length;

  String get sourceLabel => sourceLabels.join(' · ');

  String compactMeaning({int maxSenses = 3, int maxChars = 220}) {
    final parts = <String>[
      for (final sense in senses.take(maxSenses)) sense.text,
    ];
    if (parts.isEmpty) return '';
    return DictTextCleaner.truncate(parts.join(' • '), maxChars);
  }
}

/// Bộ làm sạch + bóc tách nội dung từ điển MDX.
class DictTextCleaner {
  DictTextCleaner._();

  static const int _maxSensesPerPos = 12;
  static const int _maxPosGroups = 6;

  // ── Regex dọn HTML ───────────────────────────────────────────────────────

  static final RegExp _commentRe = RegExp(r'<!--[\s\S]*?-->');

  /// Khối có nội dung không bao giờ là nghĩa (script/style/head/… ).
  static final RegExp _scriptBlockRe = RegExp(
    r'<(script|style|head|noscript|svg|iframe|object|audio|video|select|form|template)\b[^>]*>[\s\S]*?</(script|style|head|noscript|svg|iframe|object|audio|video|select|form|template)\s*>',
    caseSensitive: false,
  );

  /// Thẻ mở không có thẻ đóng (file MDX lỗi) → bỏ phần còn lại.
  static final RegExp _scriptOpenRe = RegExp(
    r'<(script|style|noscript|svg|iframe|object|template)\b[^>]*>[\s\S]*$',
    caseSensitive: false,
  );

  static final RegExp _breakRe = RegExp(
    r'<\s*/?\s*(br|p|div|li|tr|h[1-6]|blockquote|dd|dt|section|article|ul|ol|table|tbody|thead|pre)\b[^>]*>',
    caseSensitive: false,
  );

  static final RegExp _listItemRe = RegExp(r'<\s*li\b[^>]*>',
      caseSensitive: false);

  /// Thẻ rỗng/thuộc tính đơn lẻ: ảnh, icon, link, nguồn media…
  static final RegExp _voidTagRe = RegExp(
    r'<\s*/?\s*(link|meta|img|input|source|track|embed|base|param|area|col|hr|wbr|button)\b[^>]*>',
    caseSensitive: false,
  );

  /// Khối mà CHÍNH CSS CỦA TỪ ĐIỂN ẩn đi (`span.meta{display:none}`,
  /// `span.domClass`, `span.semClass`, `span.encClass`, `span.morphSet`,
  /// `span.construction`, `span.cdf`, `div.entry-headword`, `div.tocTitle`… —
  /// xem `lad.css` của bộ Lạc Việt). Bóc thẻ mà giữ chữ của khối ẩn ⇒ chữ
  /// "rác" (mã bản ghi, nhãn kỹ thuật) lọt vào nghĩa: đúng lỗi owner báo
  /// "hiện nhiều phần dư mà không thấy nghĩa" (DICT-CLEAN-002).
  static final RegExp _hiddenClassBlockRe = RegExp(
    "<(span|div|p|sup|sub|td|li|a|font)\\b[^>]*\\bclass\\s*=\\s*"
    "[\"'][^\"']*\\b(?:meta|domClass|semClass|encClass|morphSet|"
    "construction|cdf|entry-headword|hidden|tocTitle|tocText)"
    "\\b[^\"']*[\"'][^>]*>[\\s\\S]*?</\\1\\s*>",
    caseSensitive: false,
  );

  static final RegExp _tagRe = RegExp(r'<[a-zA-Z/!][^>]{0,4000}>');

  /// Mã bản ghi ở ĐẦU dòng do một số bộ từ điển (bản export wordlist) chèn
  /// vào nội dung entry: `0000015105 reading n. …` (DICT-CLEAN-002).
  static final RegExp _recordIdRe =
      RegExp(r'^(?:\d{6,}|\d{3,}[-_.]\d{2,})[\s.:\-–—|]*');

  /// Nhãn metadata (không phải nghĩa) đứng trước dấu hai chấm.
  static final RegExp _metaLabelRe = RegExp(
    r'^(?:reading|pronunciation|pron|phonetic|ipa|transcription|pinyin|romaji|romanization|word forms?|forms?|inflections?|variants?|etymology|usage note|note|synonyms?|antonyms?|see also|related(?: words?)?|compare|frequency|cefr|part of speech|pos)\s*[:：]\s*',
    caseSensitive: false,
  );

  /// Chữ cái thật (Latin có dấu, Cyrillic, Hán, Thái, Ả-rập, Devanagari…).
  static final RegExp _letterRe = RegExp(
    '[A-Za-zÀ-ɏĀ-ſ\u0400-\u04FF\u0590-\u05FF\u0600-\u06FF'
    '\u0900-\u097F\u0E00-\u0E7F\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]',
  );

  /// Metadata KHÔNG có dấu hai chấm ở đầu dòng (`reading …`).
  static final RegExp _metaWordPrefixRe = RegExp(
    r'^(?:reading|pronunciation|pron|phonetic|ipa|transcription|pinyin|romaji|'
    r'romanization|part of speech|pos|cefr)\s+',
    caseSensitive: false,
  );

  /// Nhãn metadata trơ (chỉ có nhãn, không có nội dung) ⇒ không phải nghĩa.
  static final RegExp _bareMetaRe = RegExp(
    r'^(?:reading|pronunciation|pron|phonetic|ipa|transcription|pinyin|romaji|'
    r'romanization|forms?|word forms?|variant|inflection|etymology|usage|'
    r'note|pos|part of speech|frequency|level)$',
    caseSensitive: false,
  );

  static final RegExp _bareRecordIdRe = RegExp(r'^\d{5,}$');

  static final RegExp _spacesRe = RegExp(r'[ \t\u00a0]+');

  static final RegExp _cssDeclRe = RegExp(
    r'^(?:-{0,2}(?:webkit-|moz-|ms-)?(?:color|background|background-color|font|font-family|font-size|font-weight|font-style|line-height|margin|padding|border|display|width|height|text-align|text-decoration|vertical-align|float|clear|list-style|white-space|letter-spacing|opacity|z-index|cursor|content)\s*:\s*[^;{}]+;?\s*)+$',
    caseSensitive: false,
  );

  static final RegExp _urlOnlyRe = RegExp(
    r'^(?:https?://|www\.|mailto:|javascript:)\S*$',
    caseSensitive: false,
  );

  static final RegExp _symbolsOnlyRe = RegExp(
    r'^[\s\-–—_=*~•·<>/\\|.,;:!?"'
    '`^%\$#@&()+\\[\\]{}0-9]+' r'$',
  );

  static final RegExp _entityRe =
      RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]{1,31});?');

  static final RegExp _linkSchemeRe = RegExp(
    r'(?:entry|bword|sound|query|file)://[^\s"<>]+',
    caseSensitive: false,
  );

  static const Map<String, String> _entities = <String, String>{
    'nbsp': ' ',
    'ensp': ' ',
    'emsp': ' ',
    'thinsp': ' ',
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'hellip': '…',
    'mdash': '—',
    'ndash': '–',
    'lsquo': '‘',
    'rsquo': '’',
    'ldquo': '“',
    'rdquo': '”',
    'laquo': '«',
    'raquo': '»',
    'bull': '•',
    'middot': '·',
    'times': '×',
    'divide': '÷',
    'deg': '°',
    'copy': '©',
    'reg': '®',
    'trade': '™',
    'eacute': 'é',
    'egrave': 'è',
    'ecirc': 'ê',
    'agrave': 'à',
    'acirc': 'â',
    'ocirc': 'ô',
    'sect': '§',
    'para': '¶',
    'dagger': '†',
  };

  // ── IPA ─────────────────────────────────────────────────────────────────

  static final RegExp _slashIpaRe = RegExp(r'/([^/\n]{2,60})/');
  static final RegExp _bracketIpaRe = RegExp(r'\[\s*([^\]\n]{2,60})\]');
  static final RegExp _ipaSignalRe =
      RegExp('[əɪʊɛæɑɒɔʌɜɚɝʃθðŋɹɫʉɨœɐʔˈˌː]');
  static final RegExp _vietJunkRe = RegExp(
      '[đĐăâêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]');

  // ── Loại từ ─────────────────────────────────────────────────────────────

  static const Map<String, String> _posTokens = <String, String>{
    'n': 'noun',
    'noun': 'noun',
    'nouns': 'noun',
    'danh từ': 'noun',
    'v': 'verb',
    'verb': 'verb',
    'verbs': 'verb',
    'động từ': 'verb',
    'adj': 'adj',
    'adjective': 'adj',
    'adjectives': 'adj',
    'tính từ': 'adj',
    'adv': 'adv',
    'adverb': 'adv',
    'adverbs': 'adv',
    'trạng từ': 'adv',
    'phó từ': 'adv',
    'prep': 'prep',
    'preposition': 'prep',
    'giới từ': 'prep',
    'conj': 'conj',
    'conjunction': 'conj',
    'liên từ': 'conj',
    'pron': 'pron',
    'pronoun': 'pron',
    'đại từ': 'pron',
    'det': 'det',
    'determiner': 'det',
    'mạo từ': 'det',
    'interj': 'interj',
    'interjection': 'interj',
    'thán từ': 'interj',
    'num': 'num',
    'number': 'num',
    'số từ': 'num',
    'abbr': 'abbr',
    'abbreviation': 'abbr',
    'aux': 'aux',
    'auxiliary verb': 'aux',
    'phr v': 'phr. verb',
    'phrasal verb': 'phr. verb',
    'phrase': 'phrase',
    'cụm từ': 'phrase',
    'idiom': 'idiom',
    'thành ngữ': 'idiom',
  };

  static final RegExp _numberMarkerRe = RegExp(r'(?:^|\s)\d{1,2}[.)]\s');
  static final RegExp _leadingMarkersRe =
      RegExp(r'^[\s\-–—*•·▸◆⇒>»~]+');
  static final RegExp _trailingPunctRe = RegExp(r'[\s;,]+$');
  /// Marker của DÒNG VÍ DỤ. KHÔNG gồm `•` (do `<li>` sinh ra) — bullet thường
  /// là danh sách NGHĨA, không phải ví dụ.
  static final RegExp _exampleMarkerRe =
      RegExp(r'^\s*[-–—▸◆⇒»~]+');

  // ── API công khai ───────────────────────────────────────────────────────

  /// Text sạch, một dòng — thay cho `plainDefinition` cũ.
  ///
  /// [headword] (tuỳ chọn): bỏ dòng tiêu đề lặp đúng bằng từ đang tra.
  static String plain(String raw, {String? headword}) {
    if (raw.trim().isEmpty) return '';
    final head = (headword ?? '').trim();
    final lines = <String>[
      for (final line in _cleanLines(raw))
        if (!_isHeadwordOnly(line, head) && !_isJunkSense(line)) line,
    ];
    return _collapse(lines.join(' '));
  }

  /// Bóc tách đầy đủ: IPA + nhóm loại từ + nghĩa đánh số + ví dụ.
  static DictDefinition parse(String raw, {String? headword}) {
    final head = (headword ?? '').trim();
    if (raw.trim().isEmpty) {
      return DictDefinition(headword: head, plainText: '');
    }
    final lines = _cleanLines(raw);
    final ipa = extractIpa(lines);
    final groups = _groupLines(lines, headword: head);
    final plainLines = <String>[
      for (final line in lines)
        if (!_isHeadwordOnly(line, head) && !_isJunkSense(line)) line,
    ];
    return DictDefinition(
      headword: head,
      ipa: ipa,
      groups: groups,
      plainText: _collapse(plainLines.join(' ')),
    );
  }

  /// Gộp nhiều bộ từ điển cho cùng một từ, khử nghĩa trùng.
  static DictMergedEntry merge(Iterable<DictSourceText> sources) {
    var headword = '';
    String? ipa;
    final labels = <String>[];
    final groups = <DictPosGroup>[];

    for (final source in sources) {
      if (headword.isEmpty) headword = source.headword.trim();
      final parsed = parse(source.definition, headword: source.headword);
      if (ipa == null && parsed.ipa != null) ipa = parsed.ipa;
      if (ipa == null &&
          source.phonetic != null &&
          looksLikeIpa(source.phonetic!)) {
        ipa = normalizeIpa(source.phonetic!);
      }
      final label = source.sourceLabel.trim();
      if (label.isNotEmpty && !labels.contains(label)) labels.add(label);
      groups.addAll(parsed.groups);
      // Entry rỗng nhưng có text phẳng: vẫn giữ làm 1 nghĩa duy nhất.
      if (parsed.groups.isEmpty && parsed.plainText.isNotEmpty) {
        groups.add(DictPosGroup(
          senses: <DictSense>[DictSense(parsed.plainText)],
        ));
      }
    }

    return DictMergedEntry(
      headword: headword,
      ipa: ipa,
      groups: _dedupeGroups(groups),
      sourceLabels: labels,
    );
  }

  /// Trích IPA đầu tiên hợp lệ trong text phẳng (đã làm sạch).
  static String? extractIpaFromText(String? text) {
    final source = (text ?? '').trim();
    if (source.isEmpty) return null;
    for (final match in _slashIpaRe.allMatches(source).take(8)) {
      final candidate = match.group(1);
      if (candidate == null) continue;
      if (looksLikeIpa(candidate)) return normalizeIpa(candidate);
    }
    for (final match in _bracketIpaRe.allMatches(source).take(8)) {
      final candidate = match.group(1);
      if (candidate == null) continue;
      if (looksLikeIpa(candidate)) return normalizeIpa(candidate);
    }
    return null;
  }

  /// IPA chỉ được tin khi có ít nhất 1 ký tự đặc trưng IPA (ADR-0005).
  static bool looksLikeIpa(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 80) return false;
    if (!_ipaSignalRe.hasMatch(value)) return false;
    if (_vietJunkRe.hasMatch(value)) return false;
    return true;
  }

  /// Chuẩn hoá về dạng `/…/`; trả nguyên văn nếu không hợp lệ.
  static String normalizeIpa(String raw) {
    var value = raw.trim();
    while (value.length > 2 &&
        ((value.startsWith('[') && value.endsWith(']')) ||
            (value.startsWith('/') && value.endsWith('/')))) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.isEmpty) return raw.trim();
    return '/$value/';
  }

  /// Cắt gọn theo ranh giới từ, thêm dấu ba chấm.
  static String truncate(String text, int maxChars) {
    final value = _collapse(text);
    if (value.length <= maxChars) return value;
    var cut = value.substring(0, maxChars);
    final space = cut.lastIndexOf(' ');
    if (space > maxChars ~/ 2) cut = cut.substring(0, space);
    return '${cut.trimRight()}…';
  }

  // ── Bước làm sạch ───────────────────────────────────────────────────────

  static String _stripMarkup(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(_commentRe, ' ');
    text = text.replaceAll(_hiddenClassBlockRe, ' ');
    text = text.replaceAll(_scriptBlockRe, ' ');
    text = text.replaceAll(_scriptOpenRe, ' ');
    text = text.replaceAll(_voidTagRe, ' ');
    text = text.replaceAll(_listItemRe, '\n• ');
    text = text.replaceAll(_breakRe, '\n');
    text = text.replaceAll(_tagRe, ' ');
    text = text.replaceAllMapped(_linkSchemeRe, (match) {
      final value = match.group(0) ?? '';
      if (value.toLowerCase().startsWith('sound://')) return ' ';
      return value.substring(value.indexOf('://') + 3).replaceAll('_', ' ');
    });
    text = text.replaceAll('@@@LINK=', '');
    return text;
  }

  static List<String> _cleanLines(String raw) {
    var text = _stripMarkup(raw);
    text = _decodeEntities(text);
    text = text
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u00ad', '')
        .replaceAll(RegExp('[\\u200b\\u200c\\u200d\\ufeff\\u2028\\u2029]'), '')
        .replaceAll('\t', ' ');

    final lines = <String>[];
    for (final rawLine in text.split('\n')) {
      var line = _collapse(rawLine);
      if (line.isEmpty) continue;
      // `0000015105 reading n. …` → bỏ mã bản ghi + nhãn metadata.
      line = _stripRecordIdAndMetaLabel(line);
      if (line.isEmpty) continue;
      if (_isNoise(line)) continue;
      if (_isJunkSense(line)) continue;
      lines.add(line);
    }
    return lines;
  }

  /// Bỏ mã bản ghi dài + nhãn metadata ở đầu dòng (DICT-CLEAN-002).
  ///
  /// `0000015105 reading: /ˈriːdɪŋ/` ⇒ `/ˈriːdɪŋ/` (vẫn giữ để trích IPA),
  /// `0000015105 reading n. việc đọc` ⇒ `n. việc đọc`.
  static String _stripRecordIdAndMetaLabel(String line) {
    var value = line;
    for (var i = 0; i < 2; i++) {
      final withoutId = value.replaceFirst(_recordIdRe, '');
      if (withoutId == value) break;
      value = _collapse(withoutId);
      if (value.isEmpty) return '';
    }
    value = _collapse(value.replaceFirst(_metaLabelRe, ''));
    value = _stripMetaWordPrefix(value);
    return value;
  }

  /// Metadata KHÔNG có dấu hai chấm: `reading n. việc đọc`, `ipa /ˈriːdɪŋ/`.
  ///
  /// Chỉ bỏ chữ metadata khi phần còn lại CHẮC CHẮN là dữ liệu từ điển (bắt
  /// đầu bằng loại từ, IPA…). Nếu không, một nghĩa thật mở đầu bằng chữ
  /// "reading" sẽ bị cắt mất chữ đầu — cái giá quá đắt.
  static String _stripMetaWordPrefix(String line) {
    final match = _metaWordPrefixRe.firstMatch(line);
    if (match == null) return line;
    final rest = _collapse(line.substring(match.end));
    if (rest.isEmpty) return '';
    final looksLikeData = _asPosHeader(rest) != null ||
        _inlinePosPrefix(rest) != null ||
        rest.startsWith('/') ||
        rest.startsWith('[') ||
        RegExp(r'^\(?\d{1,2}[.)]\s').hasMatch(rest);
    return looksLikeData ? rest : line;
  }

  /// Dòng không thể là NGHĨA: không có chữ cái, chỉ là nhãn metadata trơ,
  /// hoặc chỉ là mã bản ghi số. (DICT-CLEAN-002)
  static bool _isJunkSense(String text) {
    final value = text.trim();
    if (value.isEmpty) return true;
    // Dòng IPA (`/ˈriːdɪŋ/`, `[həˈloʊ]`) KHÔNG phải rác: phải giữ để
    // `extractIpa` trích được (hợp đồng ADR-0005).
    if (_ipaSignalRe.hasMatch(value)) return false;
    if (!_letterRe.hasMatch(value)) return true;
    if (_bareMetaRe.hasMatch(value)) return true;
    if (_bareRecordIdRe.hasMatch(value)) return true;
    return false;
  }

  static String _decodeEntities(String text) {
    return text.replaceAllMapped(_entityRe, (match) {
      final body = match.group(1) ?? '';
      if (body.isEmpty) return ' ';
      if (body.startsWith('#')) {
        final isHex = body.length > 1 &&
            (body[1] == 'x' || body[1] == 'X');
        final digits = isHex ? body.substring(2) : body.substring(1);
        final code = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (code == null || code <= 0 || code > 0x10FFFF) return ' ';
        return String.fromCharCode(code);
      }
      return _entities[body.toLowerCase()] ?? ' ';
    });
  }

  static bool _isNoise(String line) {
    if (line.contains('{') && line.contains('}')) return true;
    if (_cssDeclRe.hasMatch(line)) return true;
    if (_urlOnlyRe.hasMatch(line)) return true;
    if (_symbolsOnlyRe.hasMatch(line)) return true;
    if (line.startsWith('/*') || line.startsWith('*')) return true;
    return false;
  }

  static String _collapse(String text) =>
      text.replaceAll(_spacesRe, ' ').trim();

  static bool _isHeadwordOnly(String line, String headword) {
    if (headword.isEmpty) return false;
    final normalizedLine = line
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\u00c0-\u024f]'), '')
        .trim();
    final normalizedHead = headword
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\u00c0-\u024f]'), '')
        .trim();
    if (normalizedLine.isEmpty || normalizedHead.isEmpty) return false;
    return normalizedLine == normalizedHead;
  }

  static String? extractIpa(List<String> lines) {
    for (final line in lines.take(16)) {
      if (_isIpaOnly(line)) {
        return normalizeIpa(line);
      }
      final inline = extractIpaFromText(line);
      if (inline != null) return inline;
    }
    return null;
  }

  static bool _isIpaOnly(String line) {
    var value = line.trim();
    if (value.length < 3 || value.length > 82) return false;
    var stripped = false;
    if (value.startsWith('/') && value.endsWith('/')) {
      value = value.substring(1, value.length - 1).trim();
      stripped = true;
    } else if (value.startsWith('[') && value.endsWith(']')) {
      value = value.substring(1, value.length - 1).trim();
      stripped = true;
    }
    if (!stripped) return false;
    if (RegExp(r'[a-zA-Z]{4,}').hasMatch(value) &&
        !RegExp(r'[əɪʊɛæɑɒɔʌɜɚɝʃθðŋɹɫˈˌː]').hasMatch(value)) {
      return false;
    }
    return looksLikeIpa(value);
  }

  // ── Bóc tách nghĩa ──────────────────────────────────────────────────────

  static List<DictPosGroup> _groupLines(
    List<String> lines, {
    String headword = '',
  }) {
    final groups = <DictPosGroup>[];
    var currentPos = '';
    var current = <DictSense>[];

    void pushGroup() {
      if (current.isEmpty) return;
      groups.add(DictPosGroup(
        pos: currentPos.isEmpty ? null : currentPos,
        senses: List<DictSense>.from(current),
      ));
      current = <DictSense>[];
    }

    /// Thêm (các) nghĩa của một dòng — tách số hiệu `1.`/`2.` nếu có.
    void addSenses(String source) {
      for (final piece in _splitNumbered(source)) {
        if (current.length >= _maxSensesPerPos) break;
        if (_isJunkSense(piece)) continue;
        current.add(DictSense(piece));
      }
    }

    for (final line in lines) {
      if (_isHeadwordOnly(line, headword)) continue;
      if (_isIpaOnly(line)) continue;

      final pos = _asPosHeader(line);
      if (pos != null) {
        pushGroup();
        currentPos = pos;
        continue;
      }

      // DICT-CLEAN-002: nhiều bộ MDX ghi loại từ NGAY ĐẦU nghĩa thay vì
      // một dòng riêng: `n. quyển sách`, `v. đọc`. Trước đây cả dòng thành
      // một "nghĩa" kèm nhãn `n.` ⇒ hiển thị rối. Nay tách nhãn ra làm
      // nhóm loại từ, phần còn lại là nghĩa.
      final inlinePos = _inlinePosPrefix(line);
      if (inlinePos != null) {
        pushGroup();
        currentPos = inlinePos.pos;
        addSenses(inlinePos.rest);
        continue;
      }

      if (_isExampleLine(line)) {
        final cleaned = _stripExampleMarkers(line);
        if (_isJunkSense(cleaned)) continue;
        if (current.isNotEmpty) {
          final last = current.removeLast();
          current.add(last.withExample(cleaned));
        } else if (cleaned.isNotEmpty) {
          // Dòng mở đầu bằng marker nhưng chưa có nghĩa nào → là nghĩa.
          current.add(DictSense(cleaned));
        }
        continue;
      }

      addSenses(line);
    }
    pushGroup();
    return _dedupeGroups(groups);
  }

  /// Loại từ ghi NGAY ĐẦU dòng nghĩa (`n. quyển sách`, `phr v to give up`).
  /// Trả null nếu dòng không bắt đầu bằng một nhãn loại từ đã biết.
  static _InlinePos? _inlinePosPrefix(String line) {
    final lower = line.toLowerCase();
    for (final entry in _posTokens.entries) {
      final token = entry.key;
      if (!lower.startsWith(token)) continue;
      final rest = line.substring(token.length);
      if (rest.isEmpty) continue;
      // Sau nhãn phải là dấu chấm hoặc khoảng trắng, nếu không thì đó chỉ là
      // một từ bắt đầu giống nhãn (vd "detail …" vs "det").
      if (!rest.startsWith('.') && !rest.startsWith(' ')) continue;
      final cleaned = rest.replaceFirst(RegExp(r'^\.?\s+'), '').trim();
      if (cleaned.length < 2) continue;
      if (_isJunkSense(cleaned)) continue;
      return _InlinePos(entry.value, cleaned);
    }
    return null;
  }

  static String? _asPosHeader(String line) {
    var value = line.toLowerCase().trim();
    if (value.isEmpty || value.length > 24) return null;
    value = value.replaceAll(RegExp(r'^[\(\[]+'), '');
    value = value.replaceAll(RegExp(r'[\)\]]+$'), '');
    value = value.replaceAll(RegExp(r'[.:;,\-–—]+$'), '').trim();
    if (value.isEmpty) return null;
    return _posTokens[value];
  }

  static bool _isExampleLine(String line) {
    final value = line.trim();
    if (value.isEmpty) return false;
    if (value.startsWith('"') && value.endsWith('"') && value.length > 4) {
      return true;
    }
    if (value.startsWith('“') && value.endsWith('”') && value.length > 4) {
      return true;
    }
    return _exampleMarkerRe.hasMatch(value);
  }

  static String _stripExampleMarkers(String line) {
    var value = line.trim();
    value = value.replaceAll(_exampleMarkerRe, '').trim();
    value = value.replaceAll(_leadingMarkersRe, '').trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length > 2) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.startsWith('“') && value.endsWith('”') && value.length > 2) {
      value = value.substring(1, value.length - 1).trim();
    }
    return truncate(value, 240);
  }

  static List<String> _splitNumbered(String line) {
    final parts = <String>[];
    final matches = _numberMarkerRe.allMatches(line).toList();
    if (matches.isEmpty) {
      final cleaned = _stripLead(line);
      if (cleaned.isNotEmpty) parts.add(cleaned);
      return parts;
    }
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : line.length;
      if (end <= start) continue;
      final cleaned = _stripLead(line.substring(start, end));
      if (cleaned.isNotEmpty) parts.add(cleaned);
    }
    return parts;
  }

  static String _stripLead(String value) {
    var text = value.trim();
    text = text.replaceAll(_leadingMarkersRe, '').trim();
    text = text.replaceAll(_trailingPunctRe, '').trim();
    return truncate(text, 400);
  }

  static List<DictPosGroup> _dedupeGroups(List<DictPosGroup> groups) {
    final buckets = <String, List<DictSense>>{};
    final order = <String>[];
    final seen = <String>{};

    for (final group in groups) {
      final key = (group.pos ?? '').trim();
      final bucket = buckets.putIfAbsent(key, () {
        order.add(key);
        return <DictSense>[];
      });
      for (final sense in group.senses) {
        final normalized = _senseKey(sense.text);
        if (normalized.isEmpty || !seen.add(normalized)) continue;
        if (bucket.length >= _maxSensesPerPos) continue;
        bucket.add(sense);
      }
    }

    final result = <DictPosGroup>[];
    for (final key in order) {
      final senses = buckets[key];
      if (senses == null || senses.isEmpty) continue;
      result.add(DictPosGroup(
        pos: key.isEmpty ? null : key,
        senses: senses,
      ));
      if (result.length >= _maxPosGroups) break;
    }
    return result;
  }

  static String _senseKey(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u00c0-\u024f\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Loại từ tách từ đầu dòng nghĩa (DICT-CLEAN-002).
class _InlinePos {
  final String pos;
  final String rest;

  const _InlinePos(this.pos, this.rest);
}
