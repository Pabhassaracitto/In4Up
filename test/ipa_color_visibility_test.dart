// test/ipa_color_visibility_test.dart — READ-IPA-006 (P1)
//
// Model thuần — không cần widget/asset.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/ipa_color_visibility.dart';

void main() {
  group('IpaColorVisibility', () {
    test('mặc định bật hết (yêu cầu mục 2)', () {
      const v = IpaColorVisibility.all;
      expect(v.vowels, isTrue);
      expect(v.consonants, isTrue);
      expect(v.diphthongs, isTrue);
      expect(v.stress, isTrue);
      expect(v.linking, isTrue);
      expect(v.stressWords, isTrue);
      expect(v.anyVisible, isTrue);
      expect(v.hasHidden, isFalse);
    });

    test('copyWith tắt 1 loại → hasHidden + tô màu còn hiệu lực', () {
      final v = IpaColorVisibility.all.copyWith(linking: false);
      expect(v.linking, isFalse);
      expect(v.hasHidden, isTrue);
      expect(v.anyVisible, isTrue);
    });

    test('tắt hết → anyVisible false', () {
      const v = IpaColorVisibility(
        vowels: false,
        consonants: false,
        diphthongs: false,
        stress: false,
        linking: false,
        stressWords: false,
      );
      expect(v.anyVisible, isFalse);
      expect(v.hasHidden, isTrue);
    });

    test('serialize round-trip giữ nguyên trạng thái', () {
      final v = IpaColorVisibility.all.copyWith(vowels: false, stressWords: false);
      final decoded = IpaColorVisibility.fromJson(v.toJson());
      expect(decoded, v);
    });

    test('fromJsonString lỗi/rỗng → mặc định bật hết', () {
      expect(IpaColorVisibility.fromJsonString(null), IpaColorVisibility.all);
      expect(IpaColorVisibility.fromJsonString(''), IpaColorVisibility.all);
      expect(IpaColorVisibility.fromJsonString('not-json{'),
          IpaColorVisibility.all);
    });
  });
}
