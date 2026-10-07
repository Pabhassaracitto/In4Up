// lib/features/iconize/engine/iconize_engine.dart
//
// ICONIZE-001b — Iconize Engine core (ADR-0013, blueprint Khối A).
//
// Pure function: (plainText, lang, density) → IconizeResult. Không state
// giữa 2 lần gọi, không side-effect, KHÔNG ghi vào TranslationCache
// (nguyên tắc #1/#2 của blueprint). Chạy SAU dịch + glossary restore.
//
// Phạm vi v1 của lane này:
//   - langCode `en*`: xử lý đầy đủ. Ngôn ngữ khác → trả spans rỗng
//     (Bridge-to-English là lane ICONIZE-001c).
//   - POS lấy từ Dom_Pos trong concreteness.bin (Brysbaert). Adapter đọc ké
//     sentence_structure_service khi tích hợp bề mặt (blueprint mục 3.4)
//     thuộc lane 001c/001d — KHÔNG chạy phân tích câu mới ở đây.
//   - documentHash nhận vào nhưng chưa dùng: per-document override +
//     blacklist là lane ICONIZE-001g.
//   - Fallback 4 tầng: lane này chỉ có tầng "core bundle" (localTwemoji);
//     user vocab_image / CDN là lane 001c. Không có icon → giữ chữ.

import '../data/iconize_binary.dart';
import '../models/iconize_span.dart';
import 'iconize_lemmatizer.dart';

/// Ngưỡng concreteness theo từ loại (ADR-0013 / chốt câu hỏi mở #2).
/// Đã lọc từ tầng build; engine kiểm lại lần nữa — defense in depth.
const double iconizeNounMinConcreteness = 4.0;
const double iconizeAdjMinConcreteness = 4.5;

abstract class IconizeEngine {
  /// Pure function — không state, không side-effect giữa 2 lần gọi.
  Future<IconizeResult> iconize(
    String plainText, {
    required String langCode,
    IconizeDensity density = IconizeDensity.medium,
    String? documentHash,
  });
}

class DefaultIconizeEngine implements IconizeEngine {
  final ConcretenessTable concreteness;
  final IconIndexTable iconIndex;
  final IconsBundle iconsBundle;
  final IconizeLemmatizer lemmatizer;

  DefaultIconizeEngine({
    required this.concreteness,
    required this.iconIndex,
    required this.iconsBundle,
    required this.lemmatizer,
  });

  static final RegExp _wordRe = RegExp(r"[A-Za-z][A-Za-z'\-]*");
  // Vùng cấm icon hóa (blueprint Khối F): URL, placeholder glossary còn
  // sót (__G{n}__ — protect_tokens.dart), code span trong backtick.
  static final RegExp _urlRe = RegExp(r'(https?://\S+|www\.\S+)');
  static final RegExp _glossaryPlaceholderRe = RegExp(r'__G\d+__');
  static final RegExp _codeSpanRe = RegExp(r'`[^`\n]*`');

  @override
  Future<IconizeResult> iconize(
    String plainText, {
    required String langCode,
    IconizeDensity density = IconizeDensity.medium,
    String? documentHash,
  }) async {
    // v1: chỉ tiếng Anh. Bridge-to-English (lane 001c) sẽ mở rộng.
    final lang = langCode.toLowerCase();
    if (!(lang == 'en' || lang.startsWith('en-') || lang.startsWith('en_'))) {
      return IconizeResult.empty(plainText, density);
    }

    final guarded = _guardedRanges(plainText);
    final candidates = <IconizeSpan>[];
    var totalWords = 0;

    for (final m in _wordRe.allMatches(plainText)) {
      if (_inGuarded(guarded, m.start, m.end)) continue;
      totalWords++;
      final surface = m.group(0)!;
      // Bỏ từ 1 ký tự ("a", "I") — không có giá trị icon.
      if (surface.length < 2) continue;
      // Proper-noun guard (an toàn trước, đẹp sau): từ viết hoa giữa câu
      // coi như danh từ riêng → giữ chữ.
      if (_isUpperCase(surface[0]) &&
          !_isSentenceInitial(plainText, m.start)) {
        continue;
      }
      final lower = surface.toLowerCase();
      final lemma = lemmatizer.lemma(lower, isKnown: concreteness.contains);
      var resolved = _resolve(lemma);
      // Second-chance cho số nhiều có mặt trong Brysbaert dưới dạng plural
      // ("drums" là entry riêng → lemmatizer giữ nguyên → index chỉ có
      // "drum|NOUN"): thử lại dạng cắt đuôi, index vẫn là cổng cuối.
      if (resolved == null && lemma == lower) {
        final stripped = lemmatizer.lemma(lower,
            isKnown: (w) => w != lower && concreteness.contains(w));
        if (stripped != lemma) resolved = _resolve(stripped);
      }
      if (resolved == null) continue;
      candidates.add(IconizeSpan(
        start: m.start,
        end: m.end,
        surfaceForm: surface,
        lemma: resolved.lemma,
        pos: resolved.pos.label,
        concreteness: resolved.concreteness,
        iconAssetRef: 'bundle:${iconsBundle.name(resolved.iconId)}',
        source: IconizeSource.localTwemoji,
      ));
    }

    final selected = _applyDensityBudget(candidates, totalWords, density);
    final percent =
        totalWords == 0 ? 0 : (selected.length * 100 / totalWords).round();
    return IconizeResult(
      plainText: plainText,
      spans: selected,
      density: density,
      actualIconPercent: percent,
    );
  }

  /// Phân giải lemma → (POS, concreteness, iconId) theo chuỗi kiểm tra
  /// của blueprint mục 3.4: Dom_Pos → ngưỡng theo loại → index là cổng cuối.
  _ResolvedIcon? _resolve(String lemma) {
    final entry = concreteness.lookup(lemma);
    if (entry == null) return null;
    final IconizePos pos;
    final double minConc;
    if (entry.pos == IconizePos.noun) {
      pos = IconizePos.noun;
      minConc = iconizeNounMinConcreteness;
    } else if (entry.pos == IconizePos.adj) {
      pos = IconizePos.adj;
      minConc = iconizeAdjMinConcreteness;
    } else {
      // VERB/OTHER: v1 default giữ chữ (chốt câu hỏi mở #1).
      return null;
    }
    if (entry.concreteness < minConc) return null;
    final iconId = iconIndex.lookup('$lemma|${pos.label}');
    if (iconId == null) return null;
    return _ResolvedIcon(lemma, pos, entry.concreteness, iconId);
  }

  /// Cognitive-load guard (blueprint mục 3.7): cắt theo ngân sách density,
  /// giữ từ concreteness CAO trước (khi chưa có dữ liệu scaffold stage —
  /// ưu tiên theo stage là lane 001f). Sàn 1 icon cho câu ngắn có ứng viên
  /// để câu ví dụ 4–8 từ không trắng icon ở density thấp.
  List<IconizeSpan> _applyDensityBudget(
    List<IconizeSpan> candidates,
    int totalWords,
    IconizeDensity density,
  ) {
    if (candidates.isEmpty) return const [];
    final pct = maxIconPercentByDensity[density]!;
    var budget = (totalWords * pct) ~/ 100;
    if (budget < 1) budget = 1;
    if (candidates.length <= budget) {
      return List.unmodifiable(candidates);
    }
    final ranked = [...candidates]..sort((a, b) {
        final byConc = b.concreteness.compareTo(a.concreteness);
        if (byConc != 0) return byConc;
        return a.start.compareTo(b.start);
      });
    final kept = ranked.sublist(0, budget)
      ..sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(kept);
  }

  List<List<int>> _guardedRanges(String text) {
    final ranges = <List<int>>[];
    for (final re in [_urlRe, _glossaryPlaceholderRe, _codeSpanRe]) {
      for (final m in re.allMatches(text)) {
        ranges.add([m.start, m.end]);
      }
    }
    return ranges;
  }

  bool _inGuarded(List<List<int>> ranges, int start, int end) {
    for (final r in ranges) {
      if (start < r[1] && end > r[0]) return true;
    }
    return false;
  }

  bool _isUpperCase(String ch) => ch != ch.toLowerCase();

  /// true nếu vị trí [start] là đầu câu: trước đó chỉ có khoảng trắng /
  /// ngoặc / nháy cho tới đầu chuỗi hoặc một dấu kết câu (.!?…:) / xuống dòng.
  bool _isSentenceInitial(String text, int start) {
    var i = start - 1;
    while (i >= 0) {
      final ch = text[i];
      if (ch == ' ' ||
          ch == '\t' ||
          ch == '"' ||
          ch == "'" ||
          ch == '\u201C' ||
          ch == '\u2018' ||
          ch == '(' ||
          ch == '[' ||
          ch == '\u2014' ||
          ch == '-') {
        i--;
        continue;
      }
      return ch == '.' ||
          ch == '!' ||
          ch == '?' ||
          ch == '\u2026' ||
          ch == ':' ||
          ch == '\n';
    }
    return true; // đầu chuỗi
  }
}

class _ResolvedIcon {
  final String lemma;
  final IconizePos pos;
  final double concreteness;
  final int iconId;
  const _ResolvedIcon(this.lemma, this.pos, this.concreteness, this.iconId);
}
