// lib/features/word_lookup/services/word_insight_service.dart
//
// WORD-INSIGHT-001 — Trả về NGAY nghĩa + IPA cho một từ khi người dùng chạm
// vào nó (PDF Reader, Read Mode, Wordlist…), theo waterfall MỘT CHIỀU:
//
//   1. MẠNG      — `OnlineDictionarySource` (dictionaryapi.dev, không key)
//                  + dịch nghĩa sang ngôn ngữ đích bằng `TranslationService`
//                  (pipeline online-first sẵn có, tự fallback offline).
//   2. TỪ ĐIỂN   — MDX đã import (`DictionaryService.lookup`) → làm sạch/cấu
//                  trúc bằng `DictTextCleaner` (DICT-CLEAN-001).
//   3. OFFLINE   — `OfflineDictionary` (EN→VI) → `SyntaxHighlighterService`
//                  (AI/lexicon nội bộ) và `IpaResolver` (CMU → G2P).
//
// Nguyên tắc:
// - KHÔNG BAO GIỜ ném: lỗi mạng / DB / thiếu dữ liệu ⇒ trả `WordInsight` một
//   phần, để sheet vẫn dùng được phần còn lại (không chặn người dùng).
// - Cache theo từ trong phiên (mở lại sheet không gọi mạng lần nữa).
// - Mọi nguồn ngoài đều có seam override để test không cần mạng/DB.
// - Provenance IPA: `online` (mới) | `mdx` | `cmu` | `g2p` — mở rộng ADR-0005
//   bằng một giá trị additive (chip IPA hiển thị "WEB").

import 'package:flutter/foundation.dart' show debugPrint;

import '../../dictionary/models/dict_entry.dart';
import '../../dictionary/services/dict_text_cleaner.dart';
import '../../dictionary/services/dictionary_service.dart';
import '../../translation/data/offline_dictionary.dart';
import '../../translation/translation_service.dart';
import '../../../services/ipa_resolver.dart';
import '../../../services/syntax_highlighter_service.dart';
import 'online_dictionary_source.dart';

/// Nguồn đã cung cấp dữ liệu chính cho một lần tra.
enum WordInsightOrigin { network, dictionary, offline }

/// Kết quả tra một từ — đủ để hiển thị ngay nghĩa + IPA.
class WordInsight {
  final String word;

  /// IPA đã chuẩn hoá `/…/` (null nếu chưa tìm được).
  final String? ipa;

  /// `online` | `mdx` | `cmu` | `g2p` (khớp `WordEntry.phoneticSource`).
  final String? ipaSource;

  /// Nghĩa ở ngôn ngữ đích (đã dịch nếu lấy từ mạng).
  final String? meaning;

  /// Nghĩa gốc tiếng Anh (khi nguồn là mạng) — để đối chiếu.
  final String? englishMeaning;

  final String? partOfSpeech;
  final String? example;

  /// Entry MDX thô (đã có) — dùng cho trang từ điển đầy đủ + lưu từ.
  final List<DictEntry> entries;

  /// Nội dung MDX đã làm sạch/cấu trúc, song song với [entries].
  final List<DictDefinition> definitions;

  /// dictId → tên bộ từ điển (nhãn nguồn trong UI).
  final Map<String, String> dictionaryNames;

  final WordInsightOrigin? origin;
  final bool fromCache;

  const WordInsight({
    required this.word,
    this.ipa,
    this.ipaSource,
    this.meaning,
    this.englishMeaning,
    this.partOfSpeech,
    this.example,
    this.entries = const <DictEntry>[],
    this.definitions = const <DictDefinition>[],
    this.dictionaryNames = const <String, String>{},
    this.origin,
    this.fromCache = false,
  });

  bool get hasIpa => (ipa ?? '').trim().isNotEmpty;
  bool get hasMeaning => (meaning ?? '').trim().isNotEmpty;
  bool get hasDictionary => entries.isNotEmpty;
  bool get hasAny => hasIpa || hasMeaning || hasDictionary;

  /// Gộp các bộ từ điển đã trả về, KHỬ nghĩa trùng (DICT-CLEAN-001).
  DictMergedEntry get mergedDictionary => DictTextCleaner.merge(
        <DictSourceText>[
          for (final entry in entries)
            DictSourceText(
              headword: entry.headword,
              definition: entry.definition,
              phonetic: entry.phonetic,
              sourceLabel: dictionaryNames[entry.dictId] ?? entry.dictId,
            ),
        ],
      );

  WordInsight copyWith({bool? fromCache}) => WordInsight(
        word: word,
        ipa: ipa,
        ipaSource: ipaSource,
        meaning: meaning,
        englishMeaning: englishMeaning,
        partOfSpeech: partOfSpeech,
        example: example,
        entries: entries,
        definitions: definitions,
        dictionaryNames: dictionaryNames,
        origin: origin,
        fromCache: fromCache ?? this.fromCache,
      );

  @override
  String toString() =>
      'WordInsight($word, ipa=$ipa/$ipaSource, meaning=$meaning, '
      'origin=${origin?.name}, entries=${entries.length})';
}

/// Dịch vụ tra nghĩa/IPA ưu tiên mạng — xem đầu file.
class WordInsightService {
  WordInsightService._();

  static final WordInsightService _instance = WordInsightService._();
  factory WordInsightService() => _instance;

  // ── Seams test (không chạm mạng / DB / SharedPreferences) ────────────────
  static Future<OnlineDictEntry?> Function(String word)? onlineLookupOverride;
  static Future<List<DictEntry>> Function(String word)?
      dictionaryLookupOverride;
  static Future<String?> Function(String text)? translateOverride;
  static String? Function(String word)? offlineMeaningOverride;
  static Future<String?> Function(String word)? offlineIpaOverride;
  static String? Function()? targetLanguageOverride;
  static Map<String, String> Function()? dictionaryNamesOverride;

  /// Xoá seam + cache (test).
  static void resetForTest() {
    onlineLookupOverride = null;
    dictionaryLookupOverride = null;
    translateOverride = null;
    offlineMeaningOverride = null;
    offlineIpaOverride = null;
    targetLanguageOverride = null;
    dictionaryNamesOverride = null;
    _instance._cache.clear();
    _instance._localCache.clear();
  }

  /// Kết quả có nguồn MẠNG (đầy đủ nhất trong phiên).
  final Map<String, WordInsight> _cache = <String, WordInsight>{};

  /// Kết quả cục bộ (MDX + offline) — hiện NGAY khi mở sheet, không chờ mạng.
  final Map<String, WordInsight> _localCache = <String, WordInsight>{};

  static const int _cacheMax = 80;

  void clearCache() {
    _cache.clear();
    _localCache.clear();
  }

  /// Chuẩn hoá từ khoá tra cứu: bỏ dấu câu bám ngoài, gộp khoảng trắng.
  static String normalizeWord(String raw) {
    var word = raw.trim().toLowerCase();
    word = word.replaceAll(RegExp(r'^[^\w\u00c0-\u024f]+'), '');
    word = word.replaceAll(RegExp(r'[^\w\u00c0-\u024f\s]+$'), '');
    word = word.replaceAll(RegExp(r'\s+'), ' ').trim();
    return word;
  }

  /// Bước 1 của UI: chỉ nguồn CỤC BỘ (MDX → offline) — trả rất nhanh để sheet
  /// hiện nghĩa/IPA ngay, sau đó [resolve] nâng cấp bằng nguồn mạng.
  Future<WordInsight> resolveLocal(String rawWord) async {
    final word = normalizeWord(rawWord);
    if (word.isEmpty) return WordInsight(word: rawWord.trim());

    final cached = _localCache[word];
    if (cached != null) return cached.copyWith(fromCache: true);

    WordInsight insight;
    try {
      insight = await _resolveUncached(word, allowNetwork: false);
    } catch (error) {
      debugPrint('[WordInsight] resolveLocal "$word" lỗi: $error');
      insight = WordInsight(word: word);
    }
    if (_localCache.length >= _cacheMax) _localCache.clear();
    _localCache[word] = insight;
    return insight;
  }

  /// Tra đầy đủ (mạng → cục bộ). Không bao giờ ném; trả kết quả một phần nếu
  /// thiếu nguồn. [allowNetwork] = false ⇒ chỉ dùng [resolveLocal].
  Future<WordInsight> resolve(
    String rawWord, {
    bool allowNetwork = true,
  }) async {
    if (!allowNetwork) return resolveLocal(rawWord);

    final word = normalizeWord(rawWord);
    if (word.isEmpty) {
      return WordInsight(word: rawWord.trim());
    }

    final cached = _cache[word];
    if (cached != null) return cached.copyWith(fromCache: true);

    WordInsight insight;
    try {
      insight = await _resolveUncached(word, allowNetwork: true);
    } catch (error) {
      debugPrint('[WordInsight] resolve "$word" lỗi: $error');
      insight = WordInsight(word: word);
    }

    if (_cache.length >= _cacheMax) _cache.clear();
    _cache[word] = insight;
    _localCache[word] = insight;
    return insight;
  }

  Future<WordInsight> _resolveUncached(
    String word, {
    required bool allowNetwork,
  }) async {
    String? ipa;
    String? ipaSource;
    String? meaning;
    String? englishMeaning;
    String? partOfSpeech;
    String? example;
    WordInsightOrigin? origin;

    // ── 1. MẠNG ────────────────────────────────────────────────────────────
    if (allowNetwork) {
      final online = await _safeOnlineLookup(word);
      if (online != null) {
        final phonetic = online.phonetic?.trim();
        if (phonetic != null &&
            phonetic.isNotEmpty &&
            DictTextCleaner.looksLikeIpa(phonetic)) {
          ipa = DictTextCleaner.normalizeIpa(phonetic);
          ipaSource = 'online';
        }
        partOfSpeech = online.primaryPartOfSpeech;
        example = online.primaryExample;

        final summary = online.englishSummary();
        if (summary.isNotEmpty) {
          englishMeaning = summary;
          final translated = await _safeTranslate(summary);
          // Dịch lỗi (hoặc ngôn ngữ đích là EN) ⇒ vẫn hiện nghĩa gốc tiếng Anh,
          // không chặn người dùng.
          meaning =
              (translated != null && translated.isNotEmpty) ? translated : summary;
          origin = WordInsightOrigin.network;
        }
      }
    }

    // ── 2. TỪ ĐIỂN MDX ─────────────────────────────────────────────────────
    final entries = await _safeDictionaryLookup(word);
    final definitions = <DictDefinition>[];
    for (final entry in entries) {
      final view = entry.definitionView;
      if (!view.isEmpty) definitions.add(view);
    }

    if (entries.isNotEmpty) {
      for (final definition in definitions) {
        if (ipa == null && definition.ipa != null) {
          ipa = definition.ipa;
          ipaSource = 'mdx';
        }
        if (partOfSpeech == null) {
          final label = definition.partOfSpeechLabel;
          if (label != null && label.isNotEmpty) {
            partOfSpeech = label;
          }
        }
        if (example == null && definition.senses.isNotEmpty) {
          final sense = definition.senses.first;
          if (sense.examples.isNotEmpty) example = sense.examples.first;
        }
      }
      if (meaning == null) {
        for (final definition in definitions) {
          final compact =
              definition.compactMeaning(maxSenses: 3, maxChars: 260);
          if (compact.isNotEmpty) {
            meaning = compact;
            break;
          }
        }
      }
      origin ??= WordInsightOrigin.dictionary;
    }

    // ── 3. OFFLINE / AI ────────────────────────────────────────────────────
    if (ipa == null) {
      final offlineIpa = await _safeOfflineIpa(word);
      if (offlineIpa != null && offlineIpa.ipa.trim().isNotEmpty) {
        ipa = offlineIpa.ipa;
        ipaSource = offlineIpa.source;
        origin ??= WordInsightOrigin.offline;
      }
    }

    if (meaning == null) {
      final offlineMeaning = _safeOfflineMeaning(word);
      if (offlineMeaning != null && offlineMeaning.isNotEmpty) {
        meaning = offlineMeaning;
        origin ??= WordInsightOrigin.offline;
      }
    }

    return WordInsight(
      word: word,
      ipa: ipa,
      ipaSource: ipaSource,
      meaning: meaning,
      englishMeaning: englishMeaning,
      partOfSpeech: partOfSpeech,
      example: example,
      entries: entries,
      definitions: definitions,
      dictionaryNames: _safeDictionaryNames(),
      origin: origin,
    );
  }

  Future<OnlineDictEntry?> _safeOnlineLookup(String word) async {
    final override = onlineLookupOverride;
    try {
      if (override != null) return await override(word);
      return await OnlineDictionarySource.lookup(word);
    } catch (error) {
      debugPrint('[WordInsight] online "$word" lỗi: $error');
      return null;
    }
  }

  Future<List<DictEntry>> _safeDictionaryLookup(String word) async {
    final override = dictionaryLookupOverride;
    try {
      if (override != null) return await override(word);
      return await DictionaryService.instance.lookup(word);
    } catch (error) {
      debugPrint('[WordInsight] MDX "$word" lỗi: $error');
      return const <DictEntry>[];
    }
  }

  Future<String?> _safeTranslate(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final override = translateOverride;
    if (override != null) {
      try {
        return await override(trimmed);
      } catch (_) {
        return null;
      }
    }
    try {
      final service = TranslationService();
      final target = targetLanguageOverride?.call() ?? service.targetLang;
      if (target.trim().toUpperCase() == 'EN') return null;
      final result = await service.translateText(
        trimmed,
        sourceLang: 'EN',
        targetLang: target,
      );
      if (!result.isSuccess) return null;
      final translated = result.translatedText.trim();
      if (translated.isEmpty) return null;
      if (translated.toLowerCase() == trimmed.toLowerCase()) return null;
      return translated;
    } catch (error) {
      debugPrint('[WordInsight] translate lỗi: $error');
      return null;
    }
  }

  Future<_ResolvedIpa?> _safeOfflineIpa(String word) async {
    final override = offlineIpaOverride;
    try {
      if (override != null) {
        final ipa = await override(word);
        if (ipa == null || ipa.trim().isEmpty) return null;
        return _ResolvedIpa(ipa.trim(), 'cmu');
      }
      // mode g2p = bỏ qua MDX (đã tra ở bước 2) → CMU trước, rồi G2P rules.
      final resolution = await IpaResolver.resolve(word, mode: IpaSaveMode.g2p);
      if (resolution == null) return null;
      return _ResolvedIpa(resolution.ipa, resolution.source);
    } catch (error) {
      debugPrint('[WordInsight] offline IPA "$word" lỗi: $error');
      return null;
    }
  }

  String? _safeOfflineMeaning(String word) {
    final override = offlineMeaningOverride;
    try {
      if (override != null) {
        final value = override(word)?.trim();
        return (value == null || value.isEmpty) ? null : value;
      }
      final dictionaryMeaning = OfflineDictionary().lookup(word)?.trim();
      if (dictionaryMeaning != null && dictionaryMeaning.isNotEmpty) {
        return dictionaryMeaning;
      }
      final analyzed = SyntaxHighlighterService.instance.analyzeWord(word);
      final local = analyzed.meaning?.trim();
      return (local == null || local.isEmpty) ? null : local;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _safeDictionaryNames() {
    final override = dictionaryNamesOverride;
    try {
      if (override != null) return override();
      final names = <String, String>{};
      for (final info in DictionaryService.instance.dictionaries) {
        names[info.id] = info.name;
      }
      return names;
    } catch (_) {
      return const <String, String>{};
    }
  }
}

/// IPA + provenance từ resolver offline.
class _ResolvedIpa {
  final String ipa;
  final String source;

  const _ResolvedIpa(this.ipa, this.source);
}
