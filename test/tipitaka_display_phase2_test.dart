import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_markup.dart';

void main() {
  test('apparatus is separated or retained without a second parser', () {
    const raw = '<p>Dhammo [(syā.) (sī.)] pavattati.</p>';
    final compact = parseTipitakaText(raw);
    expect(compact.text, 'Dhammo pavattati.');
    expect(compact.apparatus, ['syā.) (sī.']);

    final inline = parseTipitakaText(raw, apparatusInline: true);
    expect(inline.text, contains('[(syā.) (sī.)]'));
    expect(inline.apparatus, compact.apparatus);
  });

  test('Mūla, Aṭṭhakathā and Ṭīkā codes share a parallel family', () {
    TipitakaBook book(String code) => TipitakaBook(
          id: code.hashCode,
          collectionId: 1,
          code: code,
          namePali: code.toLowerCase(),
          nameEn: '',
          nameVi: '',
          orderIndex: 0,
        );

    expect(book('VIN01M_MUL').catalogIndex.parallelFamilyCode, 'VIN01');
    expect(book('VIN01A_ATT').catalogIndex.parallelFamilyCode, 'VIN01');
    expect(book('VIN01T_TIK').catalogIndex.parallelFamilyCode, 'VIN01');
  });

  test('bundled serif family precedes platform fallback', () {
    expect(tipitakaSerifFamily, 'NotoSerifTipitaka');
    expect(tipitakaSerifFallback, contains('Noto Serif'));
  });
}
