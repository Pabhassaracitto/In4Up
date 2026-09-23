// test/ipa_styling_test.dart — READ-IPA-004
//
// Phân loại phoneme tái dùng getPhonemeType (pure — không cần asset CMU).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/models/phoneme_models.dart';
import 'package:in4up/services/ipa_styling.dart';
import 'package:in4up/services/line_ipa_service.dart';

void main() {
  group('IpaStyling.typeColor — bảng Okabe-Ito-derived', () {
    test('vowel vàng / consonant sky-blue / diphthong tím', () {
      expect(IpaStyling.typeColor(PhonemeType.vowel),
          const Color(0xFFF0E442));
      expect(IpaStyling.typeColor(PhonemeType.consonant),
          const Color(0xFF56B4E9));
      expect(IpaStyling.typeColor(PhonemeType.diphthong),
          const Color(0xFFCC79A7));
    });
  });

  group('IpaStyling.phonemeSpans', () {
    test('color off → span đơn base cyan đúng alpha', () {
      final spans =
          IpaStyling.phonemeSpans('ˈæ', colorByType: false, alpha: 0.9);
      expect(spans, hasLength(1));
      expect(spans[0].text, 'ˈæ');
      expect(spans[0].style!.color,
          const Color(0xFF4DD0E1).withValues(alpha: 0.9));
    });

    test('stress tách amber bold + thân theo loại âm', () {
      final spans =
          IpaStyling.phonemeSpans('ˈæ', colorByType: true, alpha: 1.0);
      expect(spans, hasLength(2));
      expect(spans[0].text, 'ˈ');
      expect(spans[0].style!.color, IpaStyling.stressColor);
      expect(spans[0].style!.fontWeight, FontWeight.bold);
      expect(spans[1].text, 'æ');
      expect(spans[1].style!.color, IpaStyling.vowelColor);
      expect(spans[1].style!.color!.a, closeTo(1.0, 0.001));
    });

    test('phụ âm không stress → span đơn sky-blue', () {
      final spans = IpaStyling.phonemeSpans('b', colorByType: true, alpha: 1.0);
      expect(spans, hasLength(1));
      expect(spans[0].style!.color, IpaStyling.consonantColor);
    });

    test('diphthong → tím; vowel không stress → vàng', () {
      expect(
        IpaStyling.phonemeSpans('aɪ', colorByType: true, alpha: 1.0)
            .first
            .style!
            .color,
        IpaStyling.diphthongColor,
      );
      expect(
        IpaStyling.phonemeSpans('æ', colorByType: true, alpha: 1.0)
            .first
            .style!
            .color,
        IpaStyling.vowelColor,
      );
    });

    test('rỗng → []', () {
      expect(
        IpaStyling.phonemeSpans('', colorByType: true, alpha: 1.0),
        isEmpty,
      );
    });
  });

  group('IpaStyling.segmentSpan / buildFlatSpan', () {
    test('color off → span.text = ipa (view phẳng giữ style P1)', () {
      const seg = IpaSegment(surface: 'world', wordCore: 'world', ipa: 'wɝld');
      final span =
          IpaStyling.segmentSpan(seg, colorByType: false, alpha: 0.9);
      expect(span.text, 'wɝld');
      expect(
        span.style!.color,
        const Color(0xFF4DD0E1).withValues(alpha: 0.9),
      );
    });

    test('phonemes rỗng nhưng có ipa → coi whole ipa 1 blob', () {
      const seg = IpaSegment(
        surface: 'be',
        wordCore: 'be',
        ipa: 'ˈbiː',
        phonemes: [],
      );
      final span =
          IpaStyling.segmentSpan(seg, colorByType: true, alpha: 1.0);
      // stress tách → tối đa 2 span, không throw.
      expect(span.children, isNotNull);
      expect(span.children!.length, lessThanOrEqualTo(2));
    });

    test('buildFlatSpan: join space, bỏ segment không-ipa, fade alpha', () {
      final segments = const <IpaSegment>[
        IpaSegment(
            surface: 'Hello',
            wordCore: 'Hello',
            ipa: 'həˈloʊ',
            phonemes: ['h', 'ə', 'ˈloʊ']),
        IpaSegment(surface: '—', wordCore: ''),
        IpaSegment(
            surface: 'world',
            wordCore: 'world',
            ipa: 'wɝld',
            phonemes: ['w', 'ɝ', 'l', 'd']),
      ];
      final span = IpaStyling.buildFlatSpan(
        segments,
        colorByType: false,
        isFaded: (w) => w.toLowerCase() == 'hello',
      );
      expect(span.children, isNotNull);
      final kids = span.children!.cast<TextSpan>();
      final texts = kids.map((s) => s.text ?? '').join();
      expect(texts, 'həˈloʊ wɝld');
      // Hello bị fade (từ đã thuộc) → alpha 0.28; world bình thường 0.9.
      expect(kids.first.style!.color!.a, closeTo(IpaStyling.fadedAlpha, 0.001));
      expect(kids.last.style!.color!.a, closeTo(0.9, 0.001));
    });
  });
}
