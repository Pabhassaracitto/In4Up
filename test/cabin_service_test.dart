import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';

void main() {
  group('Live Cabin Models Tests', () {
    test('CabinCaption model copyWith and initial properties', () {
      final now = DateTime.now();
      final caption = CabinCaption(
        id: 'cap_01',
        timestamp: now,
        sourceText: 'Hello world',
        sourceLang: 'en',
        targetLang: 'vi',
      );

      expect(caption.id, 'cap_01');
      expect(caption.sourceText, 'Hello world');
      expect(caption.translatedText, '');
      expect(caption.isFinal, isFalse);

      final updated = caption.copyWith(
        translatedText: 'Xin chào thế giới',
        isFinal: true,
      );

      expect(updated.id, 'cap_01');
      expect(updated.translatedText, 'Xin chào thế giới');
      expect(updated.isFinal, isTrue);
    });
  });
}
