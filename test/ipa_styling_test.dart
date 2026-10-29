// test/ipa_styling_test.dart — READ-IPA-004 + READ-IPA-006
//
// Phân loại phoneme tái dùng getPhonemeType (pure — không cần asset CMU).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/models/phoneme_models.dart';
import 'package:in4up/models/ipa_color_visibility.dart';
import 'package:in4up/services/ipa_stress_annotator.dart';
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

  group('IpaStyling — ẩn riêng từng loại (READ-IPA-006 P1)', () {
    test('ẩn nguyên âm → vowel về base cyan, phụ âm giữ màu', () {
      const vis = IpaColorVisibility(vowels: false);
      final v = IpaStyling.phonemeSpans('æ',
          colorByType: true, alpha: 1.0, visibility: vis);
      expect(v.single.style!.color, IpaStyling.baseIpaColor);

      final c = IpaStyling.phonemeSpans('b',
          colorByType: true, alpha: 1.0, visibility: vis);
      expect(c.single.style!.color, IpaStyling.consonantColor);
    });

    test('ẩn stress → nhập vào thân âm (1 span, không amber)', () {
      const vis = IpaColorVisibility(stress: false);
      final spans = IpaStyling.phonemeSpans('ˈæ',
          colorByType: true, alpha: 1.0, visibility: vis);
      expect(spans, hasLength(1));
      expect(spans.single.text, 'ˈæ');
      expect(spans.single.style!.color, IpaStyling.vowelColor);
      expect(spans.single.style!.fontWeight, isNot(FontWeight.bold));
    });

    test('visibility mặc định = bật hết', () {
      expect(IpaColorVisibility.all.vowels, isTrue);
      expect(IpaColorVisibility.all.consonants, isTrue);
      expect(IpaColorVisibility.all.diphthongs, isTrue);
      expect(IpaColorVisibility.all.stress, isTrue);
      expect(IpaColorVisibility.all.linking, isTrue);
      expect(IpaColorVisibility.all.stressWords, isTrue);
    });
  });

  group('IpaStyling.segmentSpan', () {
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
      // stress tách → 2 span, không throw.
      expect(span.children, isNotNull);
      expect(span.children!.length, 2);
    });
  });

  group('IpaStyling — nối âm C→V (READ-IPA-006 P2)', () {
    test('phát hiện nối C-V khi từ trước kết thúc phụ âm, từ sau bắt đầu nguyên âm',
        () {
      final marks = IpaStyling.detectLinkMarks(
        const [
          IpaSegment(
            surface: 'an',
            wordCore: 'an',
            ipa: 'ən',
            phonemes: ['ə', 'n'],
          ),
          IpaSegment(
            surface: 'apple',
            wordCore: 'apple',
            ipa: 'ˈæpəl',
            phonemes: ['ˈæ', 'p', 'ə', 'l'],
          ),
        ],
      );
      expect(marks[0].trailStart, 1); // 'n' trong 'ən' bắt đầu ở offset 1
      expect(marks[0].leadEnd, isNull);
      expect(marks[1].trailStart, isNull);
      expect(marks[1].leadEnd, 2); // bỏ ˈ, 'æ' trong 'ˈæpəl' kết thúc ở 2
    });

    test('không nối khi không có phụ âm cuối hoặc nguyên âm đầu', () {
      final marks = IpaStyling.detectLinkMarks(
        const [
          IpaSegment(surface: 'go', wordCore: 'go', ipa: 'ɡoʊ', phonemes: []),
          IpaSegment(
              surface: 'store', wordCore: 'store', ipa: 'stɔr', phonemes: []),
        ],
      );
      expect(marks[0].trailStart, isNull);
      expect(marks[1].leadEnd, isNull);
    });

    test('markRanges tô đúng phụ âm cuối mà không đụng các khoảng khác', () {
      const seg = IpaSegment(
        surface: 'an',
        wordCore: 'an',
        ipa: 'ən',
        phonemes: ['ə', 'n'],
      );
      final span =
          IpaStyling.segmentSpan(seg, colorByType: true, alpha: 1.0);
      final link = IpaLinkMark(trailStart: 1, leadEnd: null);
      final marked =
          IpaStyling.stressOrLinkFromIpa(span, seg.ipa!, link: link);
      expect(chainPlain(marked), 'ən');
      final cons = leafWith(marked, (s) => s.style?.color == IpaStyling.linkingColor);
      expect(cons, isNotNull);
      expect(cons!.text, 'n');
      expect(cons.style!.decoration, TextDecoration.underline);
    });
  });

  group('IpaStressAnnotator — từ nhấn (READ-IPA-006 P3)', () {
    test('đánh dấu âm tiết trọng âm chính, bỏ qua trọng âm phụ', () {
      final annot = IpaStressAnnotator.annotate(
        const [
          IpaSegment(
            surface: 'university',
            wordCore: 'university',
            ipa: 'ˌjunəˈvɝsəti',
            phonemes: ['ˌju', 'nə', 'ˈvɝ', 'sə', 'ti'],
          ),
        ],
      );
      final syl = annot.primaryPerWord[0];
      expect(syl, isNotNull);
      expect(syl!.start, 'ˌjunə'.length);
      expect(syl.end, 'ˌjunəˈvɝ'.length);
    });

    test('loại trừ function word (can/to/that…) để tránh lẫn lộn', () {
      final annot = IpaStressAnnotator.annotate(
        const [
          IpaSegment(
            surface: 'can',
            wordCore: 'can',
            ipa: 'kæn',
            phonemes: ['k', 'æ', 'n'],
          ),
          IpaSegment(
            surface: 'table',
            wordCore: 'table',
            ipa: 'ˈteɪbəl',
            phonemes: ['ˈteɪ', 'bəl'],
          ),
        ],
      );
      expect(annot.primaryPerWord.containsKey(0), isFalse);
      expect(annot.primaryPerWord.containsKey(1), isTrue);
    });

    test('blob seam (1 phoneme) vẫn tìm được trọng âm chính', () {
      final annot = IpaStressAnnotator.annotate(
        const [
          IpaSegment(
            surface: 'world',
            wordCore: 'world',
            ipa: 'wˈɝld',
            phonemes: ['wˈɝld'],
          ),
        ],
      );
      final syl = annot.primaryPerWord[0];
      expect(syl, isNotNull);
      expect(syl!.start, 1);
      expect(syl.end, 3);
    });
  });

  group('IpaStyling.buildFlatSpan', () {
    test('join space, bỏ segment không-ipa, fade alpha + link + stress', () {
      final segments = const <IpaSegment>[
        IpaSegment(
            surface: 'Hello',
            wordCore: 'Hello',
            ipa: 'həˈloʊ',
            phonemes: ['h', 'ə', 'ˈloʊ'],
            ),
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

String chainPlain(TextSpan span) {
  final buf = StringBuffer();
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      buf.write(s.text ?? '');
      for (final c in s.children ?? const <InlineSpan>[]) {
        walk(c);
      }
    }
  }

  walk(span);
  return buf.toString();
}

TextSpan? leafWith(TextSpan span, bool Function(TextSpan) pred) {
  final found = <TextSpan>[];
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      if (pred(s)) found.add(s);
      for (final c in s.children ?? const <InlineSpan>[]) {
        walk(c);
      }
    }
  }

  walk(span);
  return found.isEmpty ? null : found.first;
}
