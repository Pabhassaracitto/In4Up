// lib/services/ipa_resolver.dart
//
// READ-IPA-002 — Nguồn IPA khi LƯU từ. Waterfall 1 chiều, KHÔNG prompt
// từng lần lưu (ADR-0005):
//   auto : MDX (DictEntry.phonetic → trích từ definition) → CMU → G2P → bỏ trống
//   dict : chỉ MDX — không có thì để trống (user tự gõ)
//   g2p  : bỏ qua MDX, đi thẳng CMU → G2P
//   off  : không điền
//
// Invariant do VocabularyProvider giữ: KHÔNG bao giờ ghi đè IPA đã có.
// Chứng minh nguồn (provenance) nằm ở WordEntry.phoneticSource:
//   'mdx' | 'cmu' | 'g2p' | 'user'.

import '../features/dictionary/models/dict_entry.dart';
import '../features/dictionary/services/dictionary_service.dart';
import '../features/shadowing/services/cmu_dictionary_service.dart';
import '../features/shadowing/services/g2p_rules_service.dart';
import '../features/shadowing/services/phoneme_analyzer.dart';

/// Mode nguồn IPA khi lưu — khớp storage key `ipa_save_source`
/// (mặc định 'auto', xem StorageService.getIpaSaveSource).
enum IpaSaveMode {
  auto,
  dict,
  g2p,
  off;

  static IpaSaveMode fromName(String name) {
    for (final m in IpaSaveMode.values) {
      if (m.name == name) return m;
    }
    return IpaSaveMode.auto;
  }
}

/// Kết quả 1 lần resolve: IPA đã normalize (luôn bọc /.../) + nguồn.
class IpaResolution {
  final String ipa;

  /// 'mdx' | 'cmu' | 'g2p'
  final String source;

  const IpaResolution({required this.ipa, required this.source});

  @override
  bool operator ==(Object other) =>
      other is IpaResolution && other.ipa == ipa && other.source == source;

  @override
  int get hashCode => Object.hash(ipa, source);

  @override
  String toString() => 'IpaResolution($ipa, $source)';
}

/// validate IPA trước khi tin dữ liệu từ điển / extractor.
/// Từ điển có entry rác (respelling "he-lō", câu giải nghĩa…) — chỉ nhận
/// khi CHỨA ít nhất 1 ký tự IPA-đặc-triệu, KHÔNG lẫn dấu tiếng Việt,
/// không quá dài / quá nhiều khoảng trắng.
class IpaValidator {
  IpaValidator._();

  /// Ký tự chỉ IPA mới có (Arpabet kiểu CMU + IPA chung, có stress/space).
  static final RegExp _ipaSignal =
      RegExp('[əɪʊɛæɑɒɔʌɜɚɝʃθðŋʔɹɫʁɨʉɐœːˈˌ]');

  /// Dấu tiếng Việt (kể cả không dấu) → chắc chắn không phải IPA.
  static final RegExp _vietJunk = RegExp(
      '[đĐăâêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]');

  static final RegExp _spaces = RegExp(' ');

  static bool looksLikeIpa(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s.length > 80) return false;
    if (!_ipaSignal.hasMatch(s)) return false;
    if (_vietJunk.hasMatch(s)) return false;
    // Câu giải nghĩa / cụm dài → không phải 1 phiên âm.
    if (_spaces.allMatches(s).length > 2) return false;
    return true;
  }

  /// Chuẩn hóa để LƯU: bọc /.../, [x] → /x/. Trả null nếu không hợp lệ.
  static String? normalize(String raw) {
    var s = raw.trim();
    if (!looksLikeIpa(s)) return null;
    if (s.startsWith('[') && s.endsWith(']') && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('/') && s.endsWith('/') && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isEmpty) return null;
    return '/$s/';
  }
}

/// Rút IPA từ plain definition (đã strip HTML) của DictEntry khi cột
/// `phonetic` còn null/đểu — lazy extraction lúc lookup, KHÔNG đụng
/// mdx_parser (owned by DICT-001 / arena/01a07234-in4up).
class IpaDefinitionExtractor {
  IpaDefinitionExtractor._();

  static final RegExp _slash = RegExp(r'/([^/\n]{1,50})/');
  static final RegExp _bracket = RegExp(r'\[\s*([^\]\n]{1,50})\]');

  static String? extract(String? plainDefinition) {
    final s = plainDefinition?.trim();
    if (s == null || s.isEmpty) return null;
    for (final m in _slash.allMatches(s).take(8)) {
      final n = IpaValidator.normalize(m.group(1) ?? '');
      if (n != null) return n;
    }
    for (final m in _bracket.allMatches(s).take(8)) {
      final n = IpaValidator.normalize(m.group(1) ?? '');
      if (n != null) return n;
    }
    return null;
  }
}

/// Resolver 1 nguồn IPA cho 1 từ (hoặc cụm ASCII) theo [IpaSaveMode].
class IpaResolver {
  IpaResolver._();

  // ── Seams test (giống pattern LineIpaService.wordIpaOverride) ──
  static Future<List<DictEntry>> Function(String word)? dictLookupOverride;
  static String? Function(String word)? cmuWordIpaOverride;
  static String? Function(String word)? g2pWordIpaOverride;

  static Future<IpaResolution?> resolve(
    String rawWord, {
    required IpaSaveMode mode,
  }) async {
    if (mode == IpaSaveMode.off) return null;
    final word = rawWord.trim();
    if (word.isEmpty) return null;

    if (mode == IpaSaveMode.auto || mode == IpaSaveMode.dict) {
      final fromDict = await _fromDictionary(word);
      if (fromDict != null) return fromDict;
      if (mode == IpaSaveMode.dict) return null;
    }
    return _fromG2p(word);
  }

  static Future<IpaResolution?> _fromDictionary(String word) async {
    // Dict headword hay lưu lowercase nhưng thử cả bản gốc (từ viết hoa).
    final queries = <String>{word, word.toLowerCase()}.toList();
    for (final q in queries) {
      List<DictEntry> entries;
      if (dictLookupOverride != null) {
        entries = await dictLookupOverride!(q);
      } else {
        try {
          entries = await DictionaryService.instance.lookup(q);
        } catch (_) {
          // Manifest/DB lỗi hoặc chưa import từ điển → coi như không có.
          return null;
        }
      }
      for (final e in entries.take(5)) {
        final p = e.phonetic;
        if (p != null && IpaValidator.looksLikeIpa(p)) {
          final n = IpaValidator.normalize(p);
          if (n != null) return IpaResolution(ipa: n, source: 'mdx');
        }
        final x = IpaDefinitionExtractor.extract(e.plainDefinition);
        if (x != null) return IpaResolution(ipa: x, source: 'mdx');
      }
    }
    return null;
  }

  static Future<IpaResolution?> _fromG2p(String word) async {
    final tokens = _asciiTokens(word);
    if (tokens == null || tokens.isEmpty) return null;

    final cmuOverride = cmuWordIpaOverride;
    final g2pOverride = g2pWordIpaOverride;
    if (cmuOverride == null) {
      try {
        await PhonemeAnalyzer.initialize();
      } catch (_) {
        // CMU chưa nạp được → G2P vẫn chạy, provenance trung thực 'g2p'.
      }
    }

    final ipas = <String>[];
    var allCmu = true;
    for (final t in tokens) {
      final key = t.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      final ipa = cmuOverride != null ? cmuOverride(t) : _cmuIpa(key);
      if (ipa != null && ipa.isNotEmpty) {
        ipas.add(ipa);
        continue;
      }
      allCmu = false;
      final g = g2pOverride != null ? g2pOverride(t) : _g2pIpa(key);
      if (g == null || g.isEmpty) return null; // thiếu 1 từ → bỏ cả cụm
      ipas.add(g);
    }
    if (ipas.isEmpty) return null;
    return IpaResolution(
      ipa: '/${ipas.join(' ')}/',
      source: allCmu ? 'cmu' : 'g2p',
    );
  }

  static String? _cmuIpa(String key) {
    if (key.isEmpty) return null;
    final phonemes = CMUDictionaryService.getIPA(key);
    if (phonemes == null || phonemes.isEmpty) return null;
    return phonemes.join('');
  }

  static String? _g2pIpa(String key) {
    if (key.isEmpty) return null;
    final phonemes = G2PRulesService.predict(key);
    if (phonemes.isEmpty) return null;
    return phonemes.join('');
  }

  /// Cùng eligibility với LineIpaService: chặn chữ lạ (VI/Pali/hyphen)
  /// → null = không điền G2P cho token không phải word-ASCII.
  static final RegExp _edgeNonLetter =
      RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true);
  static final RegExp _asciiWord = RegExp(r"^[A-Za-z][A-Za-z']*$");

  static List<String>? _asciiTokens(String content) {
    final out = <String>[];
    for (final raw in content.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final core = raw.replaceAll(_edgeNonLetter, '');
      if (core.isEmpty) continue;
      if (!_asciiWord.hasMatch(core)) return null;
      out.add(core);
    }
    return out;
  }
}
