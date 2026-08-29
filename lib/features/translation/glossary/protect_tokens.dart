// lib/features/translation/glossary/protect_tokens.dart
//
// Longest-match protect/restore cho glossary — logic thuần Dart.
//
// Cách hoạt động (một chiều, không đổi input):
//   1. Build bản normalize của text (lowercase + bỏ dấu Việt/Pali) kèm
//      ánh xạ về vị trí gốc, để Pali có dấu khớp cả biến thể không dấu.
//   2. Quét text; tại mỗi vị trí thử các term theo thứ tự DÀI TRƯỚC
//      (longest-match), tie-break theo priority (user > hạt giống) rồi
//      domain. Chỉ nhận match có word boundary hai bên — "sati" KHÔNG
//      khớp trong "satisfaction".
//   3. Hit → ghi placeholder `__G{n}__` (n bắt đầu từ [startIndex]).
//   4. Sau khi engine dịch, [GlossaryProtection.restore] gắn lại nghĩa khóa.
//
// Giới hạn đã ghi nhận: nếu engine phá vỡ placeholder (bỏ mất hoàn toàn),
// nghĩa khóa theo placeholder đó mất — restore chỉ gắn lại được placeholder
// còn nguyên hoặc sai hoa/thường.

import 'translation_glossary.dart';

/// Kết quả của [protectWithGlossary]: text đã thay placeholder + bảng
/// placeholder → entry để restore.
class GlossaryProtection {
  final String protectedText;
  final List<String> placeholders;
  final Map<String, GlossaryEntry> _placeholderToEntry;

  GlossaryProtection._(
    this.protectedText,
    this.placeholders,
    this._placeholderToEntry,
  );

  /// Không có hit nào — engine nhận text trần.
  bool get changed => placeholders.isNotEmpty;

  int get placeholderCount => placeholders.length;

  /// Gắn lại nghĩa khóa vào output của engine.
  ///
  /// Pass 1: thay đúng `__G{n}__`.
  /// Pass 2 (best-effort): engine có thể lowercase placeholder
  /// (`__g3__`) — vẫn gắn lại theo bản đồ.
  String restore(String translated) {
    var out = translated;
    for (final MapEntry(:key, :value) in _placeholderToEntry.entries) {
      out = out.replaceAll(key, value.targetText);
    }
    out = out.replaceAllMapped(
      RegExp(r'__g(\d+)__', caseSensitive: false),
      (match) {
        final entry = _placeholderToEntry['__G${match.group(1)}__'];
        return entry?.targetText ?? match.group(0)!;
      },
    );
    return out;
  }
}

/// "Word char" cho boundary check: CHỈ chữ Latin ASCII + số.
/// Chữ CJK/Myanmar KHÔNG phải word-char (không có khoảng trắng giữa từ —
/// "正念" được phép khớp trong "正念禅修"; longest-match xử lý từ dài hơn).
/// Chặn Latin: "sati" KHÔNG khớp trong "satisfaction".
bool _isWordUnit(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return true; // 0-9
  if (codeUnit >= 0x41 && codeUnit <= 0x5A) return true; // A-Z
  return codeUnit >= 0x61 && codeUnit <= 0x7A; // a-z
}

class _Term {
  final List<int> units;
  final GlossaryEntry entry;

  _Term(String normalized, this.entry) : units = normalized.codeUnits;
}

int _domainRank(String domain) {
  switch (domain) {
    case GlossaryDomain.user:
      return 2;
    case GlossaryDomain.buddhist:
      return 1;
    default:
      return 0;
  }
}

/// Thay thuật ngữ khớp trong [text] bằng placeholder `__G{n}__`.
///
/// [entries] đã lọc theo cặp ngôn ngữ (xem [Glossary.applicable]).
GlossaryProtection protectWithGlossary(
  String text,
  Iterable<GlossaryEntry> entries, {
  int startIndex = 0,
}) {
  if (text.isEmpty || entries.isEmpty) {
    return GlossaryProtection._(text, const <String>[], const {});
  }

  // 1) Bản normalize + ánh xạ normIndex → originalIndex (unit UTF-16).
  //    normalizeTerm của một unit có thể trả về rỗng (combining mark) —
  //    ánh xạ song song nên không lệch vị trí.
  final normUnits = <int>[];
  final normToUnit = <int>[];
  for (var i = 0; i < text.length; i++) {
    final normalized = normalizeTerm(text[i]);
    for (final unit in normalized.codeUnits) {
      normUnits.add(unit);
      normToUnit.add(i);
    }
  }
  final normText = String.fromCharCodes(normUnits);
  final isWord = <bool>[
    for (final unit in normUnits) _isWordUnit(unit),
  ];

  // 2) Term theo thứ tự: dài trước → priority giảm → domain rank giảm.
  //    Hit đầu tại mỗi vị trí là match dài nhất hợp lệ.
  final terms = <_Term>[];
  for (final entry in entries) {
    final normalized = normalizeTerm(entry.sourceNorm);
    if (normalized.isEmpty) continue;
    terms.add(_Term(normalized, entry));
  }
  terms.sort((a, b) {
    if (a.units.length != b.units.length) {
      return b.units.length.compareTo(a.units.length);
    }
    final byPriority = b.entry.priority.compareTo(a.entry.priority);
    if (byPriority != 0) return byPriority;
    return _domainRank(b.entry.domain).compareTo(_domainRank(a.entry.domain));
  });

  // 3) Quét + thay placeholder.
  //    Copy chữ theo span đơn vị gốc (lastEmittedUnit → unit): giữ trọn
  //    các combining mark (input NFD) nằm giữa hai ký tự normalize được.
  final out = StringBuffer();
  final placeholders = <String>[];
  final map = <String, GlossaryEntry>{};
  var count = 0;
  var i = 0;
  var lastEmittedUnit = 0;
  while (i < normText.length) {
    var matched = false;
    for (final term in terms) {
      final len = term.units.length;
      if (i + len > normText.length) continue;
      var same = true;
      for (var k = 0; k < len; k++) {
        if (normUnits[i + k] != term.units[k]) {
          same = false;
          break;
        }
      }
      if (!same) continue;
      final end = i + len;
      final leftBoundary = i == 0 || !isWord[i - 1];
      final rightBoundary = end == normText.length || !isWord[end];
      if (!leftBoundary || !rightBoundary) continue;

      final unitEnd = normToUnit[end - 1];
      final placeholder = '__G${startIndex + count}__';
      out.write(placeholder);
      placeholders.add(placeholder);
      map[placeholder] = term.entry;
      count++;
      i = end;
      lastEmittedUnit = (unitEnd + 1) > lastEmittedUnit ? unitEnd + 1 : lastEmittedUnit;
      matched = true;
      break;
    }
    if (!matched) {
      final unit = normToUnit[i];
      if (unit >= lastEmittedUnit) {
        out.write(text.substring(lastEmittedUnit, unit + 1));
        lastEmittedUnit = unit + 1;
      }
      i++;
    }
  }

  return GlossaryProtection._(out.toString(), placeholders, map);
}
