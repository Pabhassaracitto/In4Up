// lib/services/ipa_styling.dart
//
// READ-IPA-004 — tô màu phoneme + mờ IPA từ đã thuộc (ADR-0005 §4).
// READ-IPA-006 — ẩn RIÊNG từng loại màu (P1), màu NỐI ÂM (P2),
//                đánh dấu âm tiết nhấn (P3).
//
// Bảng màu derived Okabe-Ito, kiểm tra trên nền tối #1A1A2E:
//   nguyên âm vàng · phụ âm sky-blue · đôi nguyên âm tím · trọng âm amber.
//   Nối âm deep-orange (tách bảng, không lẫn amber trọng âm).
// (Không đụng bảng POS/CEFR — đó là ColorMode, khác layer.)
// Phân loại phụ âm/nguyên âm tái dùng CMUDictionaryService.getPhonemeType.
//
// markRanges() là primitive DUY NHẤT để "tóm đúng chữ" trong 1 word-span:
// flatten TextSpan thành lá (char-run), chẻ lá ở biên mark rồi merge style —
// nên đánh dấu trọng âm/nối âm KHÔNG lẫn màu loại âm (thêm style, không đổi
// phân loại), và vẫn chính xác khi span lồng (stress split 2 span).

import 'package:flutter/material.dart';

import '../features/shadowing/models/phoneme_models.dart';
import '../features/shadowing/services/cmu_dictionary_service.dart';
import '../models/ipa_color_visibility.dart';
import 'ipa_stress_annotator.dart';
import 'line_ipa_service.dart';

/// Vết nối âm trên 1 TỪ (word-local, trong ipa của chính từ đó):
/// [trailStart] = đầu đoạn phụ âm cuối nối sang từ kế (null = không có);
/// [leadEnd] = cuối đoạn nguyên âm đầu nhận nối từ từ trước (null = không có).
class IpaLinkMark {
  final int? trailStart;
  final int? leadEnd;

  const IpaLinkMark({this.trailStart, this.leadEnd});

  static const IpaLinkMark none = IpaLinkMark();

  bool get isEmpty => trailStart == null && leadEnd == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IpaLinkMark &&
          other.trailStart == trailStart &&
          other.leadEnd == leadEnd;

  @override
  int get hashCode => Object.hash(trailStart, leadEnd);
}

class IpaStyling {
  IpaStyling._();

  /// Màu base khi KHÔNG tô màu (khớp dòng IPA cyan của P1).
  static const Color baseIpaColor = Color(0xFF4DD0E1);
  static const Color vowelColor = Color(0xFFF0E442);
  static const Color consonantColor = Color(0xFF56B4E9);
  static const Color diphthongColor = Color(0xFFCC79A7);
  static const Color stressColor = Color(0xFFFFD54F);

  /// Nối âm C→V (READ-IPA-006 P2): deep-orange — tách khỏi amber trọng âm
  /// và bảng loại âm (vàng/sky-blue/tím).
  static const Color linkingColor = Color(0xFFFF7043);

  /// Alpha khi fade (từ đã MasteryZone.mastered).
  static const double fadedAlpha = 0.28;
  static const double normalAlpha = 0.9;

  static Color? typeColorFor(PhonemeType type, IpaColorVisibility vis) {
    switch (type) {
      case PhonemeType.vowel:
        return vis.vowels ? vowelColor : null;
      case PhonemeType.diphthong:
        return vis.diphthongs ? diphthongColor : null;
      case PhonemeType.consonant:
        return vis.consonants ? consonantColor : null;
    }
  }

  static Color typeColor(PhonemeType type) {
    switch (type) {
      case PhonemeType.vowel:
        return vowelColor;
      case PhonemeType.diphthong:
        return diphthongColor;
      case PhonemeType.consonant:
        return consonantColor;
    }
  }

  // =====================================================================
  // P1 — ẩn riêng từng loại màu (phonemeSpans / segmentSpan)
  // =====================================================================

  /// 1 phoneme → span(s). Stress `ˈ`/`ˌ` tách riêng amber bold,
  /// thân âm theo loại. Loại bị ẩn trong [visibility] → về base cyan.
  static List<TextSpan> phonemeSpans(
    String phoneme, {
    required bool colorByType,
    required double alpha,
    IpaColorVisibility visibility = IpaColorVisibility.all,
  }) {
    if (phoneme.isEmpty) return const [];
    if (!colorByType) {
      return [
        TextSpan(
          text: phoneme,
          style: TextStyle(color: baseIpaColor.withValues(alpha: alpha)),
        ),
      ];
    }

    final type = CMUDictionaryService.getPhonemeType(phoneme);
    final colored = typeColorFor(type, visibility);
    final body = colored?.withValues(alpha: alpha) ??
        baseIpaColor.withValues(alpha: alpha);

    final hasStress = phoneme.startsWith('ˈ') || phoneme.startsWith('ˌ');
    if (!hasStress) return [TextSpan(text: phoneme, style: TextStyle(color: body))];
    if (phoneme.length == 1) {
      // Stress đứng riêng (dữ liệu cũ) — giữ như cũ, ẩn stress thì base.
      return [
        TextSpan(
          text: phoneme,
          style: TextStyle(
            color: visibility.stress
                ? stressColor.withValues(alpha: alpha)
                : baseIpaColor.withValues(alpha: alpha),
            fontWeight:
                visibility.stress ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ];
    }
    if (!visibility.stress) {
      // Ẩn stress → nhập vào thân âm, không tách span.
      return [TextSpan(text: phoneme, style: TextStyle(color: body))];
    }
    return [
      TextSpan(
        text: phoneme.substring(0, 1),
        style: TextStyle(
          color: stressColor.withValues(alpha: alpha),
          fontWeight: FontWeight.bold,
        ),
      ),
      TextSpan(text: phoneme.substring(1), style: TextStyle(color: body)),
    ];
  }

  /// 1 segment → TextSpan duy nhất (color/fade đã nhúng vào style).
  /// phonemes rỗng (override seam / dữ liệu cũ) → coi whole ipa 1 blob.
  static TextSpan segmentSpan(
    IpaSegment seg, {
    required bool colorByType,
    required double alpha,
    IpaColorVisibility visibility = IpaColorVisibility.all,
  }) {
    final ipa = seg.ipa ?? '';
    if (ipa.isEmpty) return const TextSpan();
    if (!colorByType) {
      return TextSpan(
        text: ipa,
        style: TextStyle(color: baseIpaColor.withValues(alpha: alpha)),
      );
    }
    final phonemes = seg.phonemes.isEmpty ? <String>[ipa] : seg.phonemes;
    return TextSpan(
      children: [
        for (final p in phonemes)
          ...phonemeSpans(p,
              colorByType: true, alpha: alpha, visibility: visibility),
      ],
    );
  }

  // =====================================================================
  // P2 — nối âm C→V
  // =====================================================================

  /// Quét cả dòng, xác định vết nối C→V giữa các từ liền kề:
  /// phụ âm cuối của từ i + nguyên âm đầu của từ i+1.
  static List<IpaLinkMark> detectLinkMarks(List<IpaSegment> segments) {
    final trailMarks = List<int?>.filled(segments.length, null);
    final leadMarks = List<int?>.filled(segments.length, null);

    for (var i = 0; i + 1 < segments.length; i++) {
      final cur = segments[i];
      final next = segments[i + 1];
      if (!cur.isWord || !cur.hasIpa || !next.isWord || !next.hasIpa) {
        continue;
      }
      final trailStart = _trailingConsonantStart(cur.ipa!);
      final leadEnd = _leadingVowelEnd(next.ipa!);
      if (trailStart != null && leadEnd != null && leadEnd > 0) {
        trailMarks[i] = trailStart;
        leadMarks[i + 1] = leadEnd;
      }
    }

    return List<IpaLinkMark>.generate(
      segments.length,
      (i) => IpaLinkMark(
        trailStart: trailMarks[i],
        leadEnd: leadMarks[i],
      ),
    );
  }

  static const Set<String> _consonantChars = {
    'b', 'd', 'f', 'g', 'h', 'k', 'l', 'm', 'n', 'p', 'r', 's', 't',
    'v', 'w', 'z', 'j', 'ʃ', 'ʒ', 'θ', 'ð', 'ŋ', 'tʃ', 'dʒ',
  };
  static const Set<String> _vowelChars = {
    'ɑ', 'æ', 'ʌ', 'ə', 'ɔ', 'ɛ', 'ɝ', 'ɚ', 'ɪ', 'i', 'ʊ', 'u',
    'ɒ', 'œ', 'ɜ', 'ɐ', 'ɨ', 'ʉ', 'aʊ', 'aɪ', 'eɪ', 'oʊ', 'ɔɪ',
  };

  /// Vị trí bắt đầu của cụm phụ âm cuối (trail) trong ipa — null nếu không có
  /// (word kết thúc bằng nguyên âm). Quét ký tự IPA thật, không phụ thuộc
  /// phoneme list (chính xác với mọi nguồn CMU/G2P/override seam).
  static int? _trailingConsonantStart(String ipa) {
    var i = ipa.length;
    while (i > 0) {
      final m = _matchLongestEnd(ipa, i, _consonantChars);
      if (m == 0) break;
      i -= m;
    }
    if (i == ipa.length) return null; // không có phụ âm cuối
    return i;
  }

  /// Vị trí kết thúc của nguyên âm đầu (lead) trong ipa — null nếu không có
  /// (word bắt đầu bằng phụ âm). Chấp nhận dấu nhấn `ˈ`/`ˌ` đứng trước
  /// (thuộc về âm tiết nguyên âm đó nên vẫn nằm trong khoảng đánh dấu).
  static int? _leadingVowelEnd(String ipa) {
    var i = 0;
    while (i < ipa.length && (ipa[i] == 'ˈ' || ipa[i] == 'ˌ')) {
      i++;
    }
    final m = _matchLongestStart(ipa, i, _vowelChars);
    if (m == 0) return null;
    // Chỉ lấy 1 âm tiết đầu (đơn nguyên âm hoặc diphthong).
    return i + m;
  }

  static int _matchLongestEnd(String s, int endExclusive, Set<String> set) {
    for (final len in const [2, 1]) {
      final start = endExclusive - len;
      if (start < 0) continue;
      if (set.contains(s.substring(start, endExclusive))) return len;
    }
    return 0;
  }

  static int _matchLongestStart(String s, int start, Set<String> set) {
    for (final len in const [2, 1]) {
      if (start + len > s.length) continue;
      if (set.contains(s.substring(start, start + len))) return len;
    }
    return 0;
  }

  // =====================================================================
  // markRanges — primitive chung cho trọng âm + nối âm
  // =====================================================================

  static const TextStyle _stressMarkStyle = TextStyle(
    decoration: TextDecoration.overline,
    decorationColor: stressColor,
    decorationThickness: 2.2,
  );
  static const TextStyle _linkMarkStyle = TextStyle(
    color: linkingColor,
    decoration: TextDecoration.underline,
    decorationColor: linkingColor,
    decorationThickness: 2.0,
  );

  /// Đánh dấu các khoảng [start,end) trong span của 1 TỪ (word-local).
  static TextSpan stressOrLinkFromIpa(
    TextSpan wordSpan,
    String ipa, {
    IpaStressSyllable? primary,
    IpaLinkMark? link,
    bool showStress = true,
    bool showLink = true,
  }) {
    final marks = <_CharMark>[];
    if (showStress && primary != null) {
      marks.add(_CharMark(primary.start, primary.end, _stressMarkStyle));
    }
    if (showLink && link != null && ipa.isNotEmpty) {
      if (link.trailStart != null && link.trailStart! < ipa.length) {
        marks.add(_CharMark(link.trailStart!, ipa.length, _linkMarkStyle));
      }
      if (link.leadEnd != null && link.leadEnd! > 0) {
        // Nguyên âm đầu: bỏ qua dấu nhấn ˈ/ˌ đứng trước — chúng giữ màu trọng âm.
        var leadStart = 0;
        while (leadStart < ipa.length &&
            (ipa[leadStart] == 'ˈ' || ipa[leadStart] == 'ˌ')) {
          leadStart++;
        }
        if (leadStart < link.leadEnd!) {
          marks.add(_CharMark(leadStart, link.leadEnd!, _linkMarkStyle));
        }
      }
    }
    if (marks.isEmpty) return wordSpan;
    return markRanges(wordSpan, marks);
  }

  static TextSpan markRanges(TextSpan root, List<_CharMark> marks) {
    final leaves = _flattenLeaves(root);
    if (leaves.isEmpty) return root;
    var spans = leaves;
    for (final m in marks) {
      if (m.start >= m.end) continue;
      spans = _applyMark(spans, m);
    }
    return TextSpan(style: root.style, children: spans);
  }

  static List<TextSpan> _flattenLeaves(TextSpan root) {
    final out = <TextSpan>[];
    void visit(InlineSpan node) {
      if (node is! TextSpan) return;
      final t = node.text;
      if (t != null && t.isNotEmpty) {
        out.add(node);
      }
      final kids = node.children;
      if (kids != null) {
        for (final k in kids) {
          visit(k);
        }
      }
    }

    visit(root);
    return out;
  }

  static List<TextSpan> _applyMark(List<TextSpan> spans, _CharMark m) {
    final out = <TextSpan>[];
    var pos = 0;
    for (final s in spans) {
      final len = (s.text ?? '').length;
      if (len == 0) {
        out.add(s);
        continue;
      }
      final sEnd = pos + len;
      if (m.end <= pos || m.start >= sEnd) {
        out.add(s);
        pos = sEnd;
        continue;
      }
      final localStart = (m.start - pos).clamp(0, len).toInt();
      final localEnd = (m.end - pos).clamp(0, len).toInt();
      if (localStart > 0) {
        out.add(_subSpan(s, 0, localStart));
      }
      out.add(_mergeSpanStyle(_subSpan(s, localStart, localEnd), m.style));
      if (localEnd < len) {
        out.add(_subSpan(s, localEnd, len));
      }
      pos = sEnd;
    }
    return out;
  }

  static TextSpan _subSpan(TextSpan s, int a, int b) =>
      TextSpan(text: (s.text ?? '').substring(a, b), style: s.style);

  static TextSpan _mergeSpanStyle(TextSpan s, TextStyle patch) {
    final base = s.style ?? const TextStyle();
    TextDecoration? decoration;
    if (patch.decoration != null && base.decoration != null &&
        patch.decoration != base.decoration) {
      decoration = TextDecoration.combine([base.decoration!, patch.decoration!]);
    } else {
      decoration = patch.decoration ?? base.decoration;
    }
    return TextSpan(
      text: s.text,
      style: TextStyle(
        color: patch.color ?? base.color,
        backgroundColor: patch.backgroundColor ?? base.backgroundColor,
        decoration: decoration,
        decorationColor: patch.decorationColor ?? base.decorationColor,
        decorationThickness:
            patch.decorationThickness ?? base.decorationThickness,
        fontWeight: patch.fontWeight ?? base.fontWeight,
        fontStyle: patch.fontStyle ?? base.fontStyle,
        fontSize: patch.fontSize ?? base.fontSize,
        letterSpacing: patch.letterSpacing ?? base.letterSpacing,
        height: patch.height ?? base.height,
      ),
    );
  }

  // =====================================================================
  // View phẳng (README-IPA-001 style P1) — nơi ghép mọi lớp mark
  // =====================================================================

  /// View phẳng: join các word segment bằng space (trống bị bỏ — khớp
  /// [LineIpaService.flatIpa]); [isFaded] → alpha mờ từng từ.
  ///
  /// [lineStress]: âm tiết nhấn chính (P3, từ [IpaStressAnnotator.annotate]).
  /// [linkMarks]: vết nối âm C→V (P2, từ [detectLinkMarks]) — length =
  /// segments.length; null → tắt.
  static TextSpan buildFlatSpan(
    List<IpaSegment> segments, {
    required bool colorByType,
    required bool Function(String word) isFaded,
    IpaColorVisibility visibility = IpaColorVisibility.all,
    IpaLineStress? lineStress,
    List<IpaLinkMark>? linkMarks,
  }) {
    final children = <TextSpan>[];
    var first = true;
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (!seg.isWord || !seg.hasIpa) continue;
      if (!first) children.add(const TextSpan(text: ' '));
      first = false;
      final faded = isFaded(seg.wordCore);
      final alpha = faded ? fadedAlpha : normalAlpha;

      TextSpan wordSpan = segmentSpan(
        seg,
        colorByType: colorByType,
        alpha: alpha,
        visibility: visibility,
      );

      final primary = lineStress?.primaryPerWord[i];
      final link = (linkMarks != null && linkMarks.length == segments.length)
          ? linkMarks[i]
          : IpaLinkMark.none;

      if (colorByType &&
          ((visibility.stressWords && primary != null) ||
              (visibility.linking && link != null && !link.isEmpty))) {
        wordSpan = stressOrLinkFromIpa(
          wordSpan,
          seg.ipa!,
          primary: visibility.stressWords ? primary : null,
          link: (visibility.linking && !link.isEmpty) ? link : null,
          showStress: visibility.stressWords,
          showLink: visibility.linking,
        );
      }
      children.add(wordSpan);
    }
    return TextSpan(children: children);
  }
}

class _CharMark {
  final int start;
  final int end;
  final TextStyle style;

  const _CharMark(this.start, this.end, this.style);
}
