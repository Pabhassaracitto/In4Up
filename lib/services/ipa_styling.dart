// lib/services/ipa_styling.dart
//
// READ-IPA-004 — tô màu phoneme + mờ IPA từ đã thuộc (ADR-0005 §4).
//
// Bảng màu derived Okabe-Ito, kiểm tra trên nền tối #1A1A2E:
//   nguyên âm vàng · phụ âm sky-blue · đôi nguyên âm tím · trọng âm amber
// (không đụng bảng POS/CEFR — đó là ColorMode, khác layer).
// Phân loại tái dùng CMUDictionaryService.getPhonemeType (strip stress
// trước, diphthong set trước) — phoneme đơn từ [IpaSegment.phonemes].

import 'package:flutter/material.dart';

import '../features/shadowing/models/phoneme_models.dart';
import '../features/shadowing/services/cmu_dictionary_service.dart';
import 'line_ipa_service.dart';

class IpaStyling {
  IpaStyling._();

  /// Màu base khi KHÔNG tô màu (khớp dòng IPA cyan của P1).
  static const Color baseIpaColor = Color(0xFF4DD0E1);
  static const Color vowelColor = Color(0xFFF0E442);
  static const Color consonantColor = Color(0xFF56B4E9);
  static const Color diphthongColor = Color(0xFFCC79A7);
  static const Color stressColor = Color(0xFFFFD54F);

  /// Alpha khi fade (từ đã MasteryZone.mastered).
  static const double fadedAlpha = 0.28;
  static const double normalAlpha = 0.9;

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

  /// 1 phoneme → span(s). Stress `ˈ`/`ˌ` tách riêng amber bold
  /// (pre-attentive cue), thân âm theo loại.
  static List<TextSpan> phonemeSpans(
    String phoneme, {
    required bool colorByType,
    required double alpha,
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
    final body =
        typeColor(CMUDictionaryService.getPhonemeType(phoneme))
            .withValues(alpha: alpha);
    if (phoneme.startsWith('ˈ') || phoneme.startsWith('ˌ')) {
      return [
        TextSpan(
          text: phoneme.substring(0, 1),
          style: TextStyle(
            color: stressColor.withValues(alpha: alpha),
            fontWeight: FontWeight.bold,
          ),
        ),
        if (phoneme.length > 1)
          TextSpan(text: phoneme.substring(1), style: TextStyle(color: body)),
      ];
    }
    return [TextSpan(text: phoneme, style: TextStyle(color: body))];
  }

  /// 1 segment → TextSpan duy nhất (color/fade đã nhúng vào style).
  static TextSpan segmentSpan(
    IpaSegment seg, {
    required bool colorByType,
    required double alpha,
  }) {
    final ipa = seg.ipa ?? '';
    if (ipa.isEmpty) return const TextSpan();
    if (!colorByType) {
      return TextSpan(
        text: ipa,
        style: TextStyle(color: baseIpaColor.withValues(alpha: alpha)),
      );
    }
    // phonemes rỗng (override seam / dữ liệu cũ) → coi whole ipa 1 blob.
    final phonemes = seg.phonemes.isEmpty ? <String>[ipa] : seg.phonemes;
    final children = <TextSpan>[
      for (final p in phonemes)
        ...phonemeSpans(p, colorByType: true, alpha: alpha),
    ];
    return TextSpan(children: children);
  }

  /// View phẳng: join các word segment bằng space (trống bị bỏ —
  /// khớp [LineIpaService.flatIpa]); [isFaded] → alpha mờ từng từ.
  static TextSpan buildFlatSpan(
    List<IpaSegment> segments, {
    required bool colorByType,
    required bool Function(String word) isFaded,
  }) {
    final children = <TextSpan>[];
    var first = true;
    for (final seg in segments) {
      if (!seg.isWord || !seg.hasIpa) continue;
      if (!first) children.add(const TextSpan(text: ' '));
      first = false;
      final faded = isFaded(seg.wordCore);
      children.add(segmentSpan(
        seg,
        colorByType: colorByType,
        alpha: faded ? fadedAlpha : normalAlpha,
      ));
    }
    return TextSpan(children: children);
  }
}
