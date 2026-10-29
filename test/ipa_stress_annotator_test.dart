// test/ipa_stress_annotator_test.dart — READ-IPA-006 (P3)
//
// Đánh dấu âm tiết nhấn chính — thuần logic, không cần asset CMU.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/ipa_stress_annotator.dart';
import 'package:in4up/services/line_ipa_service.dart';

void main() {
  group('IpaStressAnnotator.annotate', () {
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

    test('đánh dấu âm tiết nhấn khi phoneme tách đúng (CMU)', () {
      final annot = IpaStressAnnotator.annotate(
        const [
          IpaSegment(
            surface: 'world',
            wordCore: 'world',
            ipa: 'wˈɝld',
            phonemes: ['w', 'ˈɝ', 'l', 'd'],
          ),
        ],
      );
      final syl = annot.primaryPerWord[0];
      expect(syl, isNotNull);
      expect(syl!.start, 1); // 'w'
      expect(syl.end, 3); // 'ˈɝ'
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
      expect(syl.end, 3); // 'ɝ' (IPA Extensions U+025D) — chạy đến trước 'l'
    });

    test('không trọng âm → không mark', () {
      final annot = IpaStressAnnotator.annotate(
        const [
          IpaSegment(surface: 'go', wordCore: 'go', ipa: 'ɡoʊ', phonemes: []),
        ],
      );
      expect(annot.isEmpty, isTrue);
    });
  });
}
