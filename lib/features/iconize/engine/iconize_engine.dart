// lib/features/iconize/engine/iconize_engine.dart
//
// ICONIZE-001b/001c — Iconize Engine core (ADR-0013, blueprint Khối A).
//
// Pure function: (plainText, lang, density) → IconizeResult. Không state
// giữa 2 lần gọi, không side-effect, KHÔNG ghi vào TranslationCache
// (nguyên tắc #1/#2 của blueprint). Chạy SAU dịch + glossary restore.
//
// Phạm vi sau lane 001c:
//   - `en*`: xử lý đầy đủ; POS mặc định từ Dom_Pos (Brysbaert), bề mặt nào
//     có sẵn phân tích cú pháp (sentence_structure/grammar) truyền
//     [posHint] để sửa case động từ bị Dom_Pos gán danh từ ("taste") —
//     engine KHÔNG tự chạy phân tích câu mới (blueprint mục 3.4).
//   - `vi*`: Bridge-to-English qua [EnglishBridgeDictionary] — chỉ icon
//     hóa khi các ứng viên EN resolve được đồng thuận đúng 1 icon.
//   - Ngôn ngữ khác: trả spans rỗng (light-beta hi/si/zh là roadmap).
//   - Fallback nguồn icon: [userSources] (ảnh user gán trong vocab_image,
//     wire ở lane 001d) → core bundle → giữ chữ. CDN dời sang gói
//     Model Centre (ghi vết card KANBAN).
//   - documentHash nhận vào nhưng chưa dùng: override/blacklist là 001g.

import '../data/iconize_binary.dart';
import '../models/iconize_span.dart';
import 'iconize_bridge.dart';
import 'iconize_icon_source.dart';
import 'iconize_lemmatizer.dart';

/// Ngưỡng concreteness theo từ loại (ADR-0013 / chốt câu hỏi mở #2).
/// Đã lọc từ tầng build; engine kiểm lại lần nữa — defense in depth.
const double iconizeNounMinConcreteness = 4.0;
const double iconizeAdjMinConcreteness = 4.5;

/// Gợi ý POS từ bề mặt đã có phân tích cú pháp (offset + surface → POS).
/// Trả null = không có ý kiến (engine dùng Dom_Pos).
typedef IconizePosHint = IconizePos? Function(int start, String surface);

abstract class IconizeEngine {
  /// Pure function — không state, không side-effect giữa 2 lần gọi.
  Future<IconizeResult> iconize(
    String plainText, {
    required String langCode,
    IconizeDensity density = IconizeDensity.medium,
    String? documentHash,
    IconizePosHint? posHint,
  });
}

class DefaultIconizeEngine implements IconizeEngine {
  final ConcretenessTable concreteness;
  final IconIndexTable iconIndex;
  final IconsBundle iconsBundle;
  final IconizeLemmatizer lemmatizer;

  /// Nguồn icon ưu tiên trước bundle (tầng 1: ảnh user — lane 001d wire).
  final List<IconizeIconSource> userSources;

  /// Bảng đảo VI→EN cho Bridge-to-English; null = tắt đường vi.
  final EnglishBridgeDictionary? bridge;

  DefaultIconizeEngine({
    required this.concreteness,
    required this.iconIndex,
    required this.iconsBundle,
    required this.lemmatizer,
    this.userSources = const [],
    this.bridge,
  });

  // \p{L} để nhận cả chữ có dấu tiếng Việt.
  static final RegExp _wordRe =
      RegExp(r"[\p{L}][\p{L}'\-]*", unicode: true);
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
    IconizePosHint? posHint,
  }) async {
    final lang = langCode.toLowerCase();
    final isEn = lang == 'en' || lang.startsWith('en-') || lang.startsWith('en_');
    final isVi = lang == 'vi' || lang.startsWith('vi-') || lang.startsWith('vi_');
    if (!isEn && !(isVi && bridge != null)) {
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
      final resolved = isEn
          ? _resolveEnglish(lower, m.start, surface, posHint)
          : _resolveViaBridge(lower);
      if (resolved == null) continue;
      candidates.add(IconizeSpan(
        start: m.start,
        end: m.end,
        surfaceForm: surface,
        lemma: resolved.lemma,
        pos: resolved.pos.label,
        concreteness: resolved.concreteness,
        iconAssetRef: resolved.iconRef,
        source: resolved.source,
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

  _ResolvedIcon? _resolveEnglish(
    String lower,
    int start,
    String surface,
    IconizePosHint? posHint,
  ) {
    // Cú pháp của bề mặt nói đây là động từ/từ chức năng → giữ chữ,
    // bất kể Dom_Pos ("Apples taste sweet" — taste là VERB).
    final hinted = posHint?.call(start, surface);
    if (hinted == IconizePos.verb || hinted == IconizePos.other) {
      return null;
    }
    final lemma = lemmatizer.lemma(lower, isKnown: concreteness.contains);
    var resolved = _resolve(lemma, forcedPos: hinted);
    // Second-chance cho số nhiều có mặt trong Brysbaert dưới dạng plural
    // ("drums" là entry riêng → lemmatizer giữ nguyên → index chỉ có
    // "drum|NOUN"): thử lại dạng cắt đuôi, index vẫn là cổng cuối.
    if (resolved == null && lemma == lower) {
      final stripped = lemmatizer.lemma(lower,
          isKnown: (w) => w != lower && concreteness.contains(w));
      if (stripped != lemma) resolved = _resolve(stripped, forcedPos: hinted);
    }
    return resolved;
  }

  /// Bridge-to-English (blueprint 3.5): mọi ứng viên EN resolve được phải
  /// đồng thuận đúng MỘT icon; khác đi → giữ chữ.
  _ResolvedIcon? _resolveViaBridge(String viLower) {
    final b = bridge;
    if (b == null) return null;
    _ResolvedIcon? agreed;
    for (final candidate in b.englishCandidates(viLower)) {
      final r = _resolve(candidate);
      if (r == null) continue;
      if (agreed == null) {
        agreed = r;
      } else if (agreed.iconRef != r.iconRef) {
        return null; // hai nghĩa EN ra hai icon khác nhau → không chắc.
      }
    }
    return agreed;
  }

  /// Phân giải lemma → (POS, concreteness, iconRef) theo chuỗi kiểm tra
  /// blueprint 3.4 + 3.6: Dom_Pos (hoặc [forcedPos] từ cú pháp) → ngưỡng
  /// theo loại → nguồn user trước → index bundle là cổng cuối.
  _ResolvedIcon? _resolve(String lemma, {IconizePos? forcedPos}) {
    final entry = concreteness.lookup(lemma);
    if (entry == null) return null;
    final effective = forcedPos ?? entry.pos;
    final IconizePos pos;
    final double minConc;
    if (effective == IconizePos.noun) {
      pos = IconizePos.noun;
      minConc = iconizeNounMinConcreteness;
    } else if (effective == IconizePos.adj) {
      pos = IconizePos.adj;
      minConc = iconizeAdjMinConcreteness;
    } else {
      // VERB/OTHER: v1 default giữ chữ (chốt câu hỏi mở #1).
      return null;
    }
    if (entry.concreteness < minConc) return null;
    // Tầng 1: icon user gán (không cần qua index — người dùng đã xác nhận
    // nghĩa khi gán ảnh; cổng còn lại là concreteness + POS ở trên).
    for (final source in userSources) {
      final ref = source.resolve(lemma, pos);
      if (ref != null) {
        return _ResolvedIcon(
            lemma, pos, entry.concreteness, ref, source.sourceKind);
      }
    }
    // Tầng 2: core bundle, index là cổng cuối.
    final iconId = iconIndex.lookup('$lemma|${pos.label}');
    if (iconId == null) return null;
    return _ResolvedIcon(lemma, pos, entry.concreteness,
        'bundle:${iconsBundle.name(iconId)}', IconizeSource.localTwemoji);
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
  final String iconRef;
  final IconizeSource source;
  const _ResolvedIcon(
      this.lemma, this.pos, this.concreteness, this.iconRef, this.source);
}
