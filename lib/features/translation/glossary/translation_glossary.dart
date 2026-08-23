// lib/features/translation/glossary/translation_glossary.dart
//
// Glossary thuật ngữ cho pipeline dịch — tầng chuyên ngữ (Phật học / Pali).
//
// Thiết kế thuần Dart (KHÔNG import Flutter) để test logic không cần GUI:
// - [GlossaryEntry]: một mục từ khóa (source → target).
// - [Glossary]: bộ mục + tra cứu [Glossary.protect] (longest-match).
//
// Sự thật nền: Pali KHÔNG phải ngôn ngữ MT (ML Kit không có Pali) —
// Pali = glossary + giữ nguyên + gloss. Thuật ngữ đã khóa (locked) phải
// được giữ đúng nghĩa sau khi engine dịch phần còn lại.
//
// Placeholder: `__G{n}__` — engine nhận text đã thay placeholder, kết quả
// được restore lại bằng nghĩa khóa.

import '../../canon/services/canon_tokenizer.dart';

/// Language codes trong schema glossary (lowercase, 1–2 ký tự).
class GlossaryLang {
  GlossaryLang._();

  static const String pali = 'pi';
  static const String english = 'en';
  static const String hindi = 'hi';
  static const String vietnamese = 'vi';

  /// Normalize mã ngôn ngữ user nhập ("pali", "Pali", "PI" → "pi").
  static String? normalize(String? code) {
    final c = (code ?? '').trim().toLowerCase().replaceAll('_', '-');
    if (c == 'pali' || c == 'pi') return pali;
    if (c == 'en' || c == 'eng' || c == 'english') return english;
    if (c == 'hi' || c == 'hin' || c == 'hindi') return hindi;
    if (c == 'vi' || c == 'vie' || c == 'việt' || c == 'vietnamese') {
      return vietnamese;
    }
    return c.isEmpty ? null : c;
  }
}

/// Domain phân loại nguồn của mục glossary.
class GlossaryDomain {
  GlossaryDomain._();

  static const String buddhist = 'buddhist';
  static const String user = 'user';
  static const String general = 'general';
}

/// Priority mặc định: user > hạt giống (buddhist) khi cùng khóa.
class GlossaryPriority {
  GlossaryPriority._();

  static const int seed = 0;
  static const int user = 100;
}

/// Normalize một từ cho việc so khớp: lowercase + bỏ dấu tiếng Việt/Pali
/// (dùng [CanonTokenizer.stripDiacritics]) + loại ký tự combining còn sót
/// (input NFD).
///
/// Nhờ normalize, "nibbāna", "nibbana", "NIBBĀNA" cùng khớp một entry.
String normalizeTerm(String input) {
  final stripped = CanonTokenizer.stripDiacritics(input);
  return stripped.replaceAll(RegExp('[\u0300-\u036f]'), '');
}

/// Một mục từ khóa trong glossary.
///
/// [id] ổn định theo (từ đã normalize, sourceLang, targetLang) — dùng làm
/// key Hive và để dedup: "nibbāna" và "nibbana" cùng một id.
class GlossaryEntry {
  final String id;
  final String sourceNorm;
  final String sourceLang;
  final String targetLang;
  final String targetText;
  final bool locked;
  final String domain;
  final int priority;

  const GlossaryEntry({
    required this.id,
    required this.sourceNorm,
    required this.sourceLang,
    required this.targetLang,
    required this.targetText,
    this.locked = true,
    this.domain = GlossaryDomain.buddhist,
    this.priority = GlossaryPriority.seed,
  });

  /// Tạo id ổn định cho một bộ (source, sourceLang, targetLang).
  static String makeId(String source, String sourceLang, String targetLang) {
    return '${normalizeTerm(source)}|'
        '${GlossaryLang.normalize(sourceLang) ?? sourceLang.toLowerCase()}|'
        '${GlossaryLang.normalize(targetLang) ?? targetLang.toLowerCase()}';
  }

  /// Từ nguồn đã normalize (dùng để so khớp, cache lại).
  String get normalizedSource => normalizeTerm(sourceNorm);

  /// Entry này có bảo vệ thuật ngữ cho cặp dịch [source] → [target] không?
  ///
  /// - targetLang phải đúng ngôn ngữ đích.
  /// - sourceLang đúng ngôn ngữ nguồn, HOẶC là Pali: Pali là thuật ngữ
  ///   nhúng trong câu của bất kỳ ngôn ngữ Latin nào (EN, HI, ...), không
  ///   phải "ngôn ngữ của câu".
  bool appliesTo({required String source, required String target}) {
    final s = source.trim().toLowerCase();
    final t = target.trim().toLowerCase();
    if (t.isEmpty || s.isEmpty || s == t) return false;
    if (targetLang.toLowerCase() != t) return false;
    final sl = sourceLang.toLowerCase();
    if (sl == s) return true;
    return sl == GlossaryLang.pali;
  }

  factory GlossaryEntry.fromMap(Map<dynamic, dynamic> map) {
    final source = (map['source'] ?? map['sourceNorm'] ?? '') as String;
    final sourceLang =
        (map['sourceLang'] ?? map['source_lang'] ?? 'en') as String;
    final targetLang =
        (map['targetLang'] ?? map['target_lang'] ?? 'vi') as String;
    final targetText = (map['target'] ?? map['targetText'] ?? '') as String;
    final id =
        (map['id'] as String?) ?? makeId(source, sourceLang, targetLang);
    return GlossaryEntry(
      id: id,
      sourceNorm: source,
      sourceLang: sourceLang.toLowerCase(),
      targetLang: targetLang.toLowerCase(),
      targetText: targetText,
      locked: map['locked'] is! bool || (map['locked'] as bool),
      domain: (map['domain'] as String?) ?? GlossaryDomain.buddhist,
      priority: (map['priority'] as int?) ?? GlossaryPriority.seed,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'source': sourceNorm,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'target': targetText,
        'locked': locked,
        'domain': domain,
        'priority': priority,
      };

  GlossaryEntry copyWith({
    String? sourceNorm,
    String? sourceLang,
    String? targetLang,
    String? targetText,
    bool? locked,
    String? domain,
    int? priority,
  }) {
    final id = (sourceNorm == null &&
            sourceLang == null &&
            targetLang == null)
        ? this.id
        : GlossaryEntry.makeId(
            sourceNorm ?? this.sourceNorm,
            sourceLang ?? this.sourceLang,
            targetLang ?? this.targetLang,
          );
    return GlossaryEntry(
      id: id,
      sourceNorm: sourceNorm ?? this.sourceNorm,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      targetText: targetText ?? this.targetText,
      locked: locked ?? this.locked,
      domain: domain ?? this.domain,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() =>
      'GlossaryEntry(${sourceNorm} [$sourceLang→$targetLang] '
      '→ "$targetText" ${locked ? 'locked' : 'unlocked'} '
      '$domain p=$priority)';
}

/// Bộ glossary trong bộ nhớ + tra cứu longest-match.
///
/// [Glossary] là snapshot thuần — không phụ thuộc Hive, test được trực tiếp.
class Glossary {
  final List<GlossaryEntry> _entries;

  const Glossary(this._entries);

  factory Glossary.empty() => const Glossary(const <GlossaryEntry>[]);

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Snapshot không sửa được của toàn bộ entry.
  List<GlossaryEntry> get entries => List.unmodifiable(_entries);

  /// Entry nào có thể bảo vệ thuật ngữ cho cặp [source] → [target].
  List<GlossaryEntry> applicable({
    required String source,
    required String target,
  }) {
    final out = <GlossaryEntry>[];
    for (final entry in _entries) {
      if (entry.appliesTo(source: source, target: target)) out.add(entry);
    }
    return out;
  }

  /// Thay các thuật ngữ khớp bằng placeholder `__G{n}__`, trả về
  /// [GlossaryProtection] dùng để restore sau khi engine dịch.
  ///
  /// [startIndex] dịch số placeholder (dùng khi ghép nhiều bước pivot).
  GlossaryProtection protect(
    String text, {
    required String source,
    required String target,
    int startIndex = 0,
  }) {
    return protectWithGlossary(
      text,
      applicable(source: source, target: target),
      startIndex: startIndex,
    );
  }
}
