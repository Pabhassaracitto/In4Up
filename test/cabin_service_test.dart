import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';
import 'package:in4up/features/cabin/services/stts_cabin_service.dart';

void main() {
  group('Live Cabin Models & Service Tests', () {
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

    test('SttsCabinService initial state and configuration', () {
      final service = SttsCabinService.instance;
      expect(service.state, CabinState.idle);
      expect(service.isListening, isFalse);
      expect(service.shouldShowBubble, isFalse);

      service.setSourceLanguage('en');
      service.setTargetLanguage('vi');
      expect(service.sourceLanguage, 'en');
      expect(service.targetLanguage, 'vi');

      service.swapLanguages();
      expect(service.sourceLanguage, 'vi');
      expect(service.targetLanguage, 'en');

      service.setDubbing(true);
      expect(service.isDubbingEnabled, isTrue);

      service.setDisplayMode(CabinDisplayMode.fullTranscript);
      expect(service.displayMode, CabinDisplayMode.fullTranscript);
    });
  });
}
