import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/controllers/c27_cabin_live_controller.dart';
import 'package:in4up/features/cabin/models/c27_cabin_live_state.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';

/// C-27 — handoff preservation test (doc 43 §6/§9).
/// Kiểm chứng: schema đúng 10 trường, round-trip bảo toàn 10/10, validate reject
/// thiếu/sai từng trường, chuỗi handoff 3 hop (Cabin→Hiểu→Nhớ) bảo toàn dữ liệu và
/// returnPath không đổi; đường quay lại Cabin đúng.
void main() {
  CabinCaption translatedCaption(String id) => CabinCaption(
        id: id,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
        sourceText: 'nguồn $id',
        translatedText: 'translated $id',
        sourceLang: 'vi',
        targetLang: 'en',
        isFinal: true,
      );

  C27Handoff sampleHandoff() => C27Handoff(
        sourceType: C27SourceType.cabin,
        sessionId: 's1',
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
        originalCaption: 'xin chào',
        translatedCaption: 'hello',
        sourceLanguage: 'vi',
        targetLanguage: 'en',
        speakerTag: 'S1',
        sessionTitle: 'Phiên A',
        returnPath: 'cabin',
      );

  group('C-27 handoff schema', () {
    test('đúng 10 trường bắt buộc', () {
      expect(C27Handoff.fieldNames.length, 10);
      expect(sampleHandoff().toJson().keys.toSet(),
          C27Handoff.fieldNames.toSet());
    });

    test('round-trip toJson/fromJson bảo toàn 10/10 trường', () {
      final handoff = sampleHandoff();
      final restored = C27Handoff.fromJson(handoff.toJson());
      expect(restored, handoff);
      expect(restored.sourceType, C27SourceType.cabin);
      expect(restored.sessionId, 's1');
      expect(restored.originalCaption, 'xin chào');
      expect(restored.translatedCaption, 'hello');
      expect(restored.sourceLanguage, 'vi');
      expect(restored.targetLanguage, 'en');
      expect(restored.speakerTag, 'S1');
      expect(restored.sessionTitle, 'Phiên A');
      expect(restored.returnPath, 'cabin');
      expect(restored.timestamp, handoff.timestamp);
    });

    test('validate: hợp lệ → null; speakerTag rỗng vẫn hợp lệ', () {
      expect(C27Handoff.validateJson(sampleHandoff().toJson()), isNull);
      final noSpeaker = sampleHandoff().toJson()..['speakerTag'] = '';
      expect(C27Handoff.validateJson(noSpeaker), isNull);
    });

    test('validate reject khi thiếu/sai từng trường', () {
      final valid = sampleHandoff().toJson();
      for (final name in C27Handoff.fieldNames) {
        final broken = Map<String, dynamic>.from(valid)..remove(name);
        expect(C27Handoff.validateJson(broken), isNotNull,
            reason: 'thiếu $name phải bị reject');
      }
      // thêm field lạ (schema kín v1)
      final extra = Map<String, dynamic>.from(valid)..['extra'] = 1;
      expect(C27Handoff.validateJson(extra), isNotNull);

      final emptyCaption = Map<String, dynamic>.from(valid)
        ..['originalCaption'] = '';
      expect(C27Handoff.validateJson(emptyCaption), isNotNull);

      final badReturnPath = Map<String, dynamic>.from(valid)
        ..['returnPath'] = 'Cabin!';
      expect(C27Handoff.validateJson(badReturnPath), isNotNull);

      final badSourceType = Map<String, dynamic>.from(valid)
        ..['sourceType'] = 'mars';
      expect(C27Handoff.validateJson(badSourceType), isNotNull);

      final badTimestamp = Map<String, dynamic>.from(valid)..['timestamp'] = 0;
      expect(C27Handoff.validateJson(badTimestamp), isNotNull);
    });
  });

  group('C-27 handoff flow (Nghe → Cabin → Hiểu → Nhớ → về Cabin)', () {
    test('handoff từ Cabin sang Hiểu: đủ dữ liệu, returnPath giữ nguyên', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's-handoff');
      controller.startFromListen(
        sessionTitle: 'Phiên học',
        sourceLang: 'vi',
        targetLang: 'en',
      );
      controller.onFinalCaption(translatedCaption('c1'));
      controller.onTranslatedCaption('c1', 'translated c1');

      controller.openHandoff(
        target: C27SourceType.understand,
        speakerTag: 'S2',
      );
      expect(controller.state, C27CabinLiveState.handoffActive);
      final handoff = controller.activeHandoff;
      expect(handoff, isNotNull);
      expect(handoff!.sourceType, C27SourceType.cabin);
      expect(handoff.sessionId, 's-handoff');
      expect(handoff.originalCaption, 'nguồn c1');
      expect(handoff.translatedCaption, 'translated c1');
      expect(handoff.sourceLanguage, 'vi');
      expect(handoff.targetLanguage, 'en');
      expect(handoff.speakerTag, 'S2');
      expect(handoff.sessionTitle, 'Phiên học');
      expect(handoff.returnPath, 'cabin');
      expect(handoff.timestamp.millisecondsSinceEpoch, greaterThan(0));
      // handoff do controller dựng phải tự validate được
      expect(C27Handoff.validateJson(handoff.toJson()), isNull);
    });

    test('chuỗi 3 hop bảo toàn dữ liệu; returnPath không đổi suốt chuỗi', () {
      // Hop 1: Cabin → Hiểu
      final hop1 = sampleHandoff();
      // Hop 2: Hiểu → Nhớ (cùng ngữ cảnh, nguồn là understand, về vẫn cabin)
      final hop2 = C27Handoff(
        sourceType: C27SourceType.understand,
        sessionId: hop1.sessionId,
        timestamp: hop1.timestamp.add(const Duration(minutes: 1)),
        originalCaption: hop1.originalCaption,
        translatedCaption: hop1.translatedCaption,
        sourceLanguage: hop1.sourceLanguage,
        targetLanguage: hop1.targetLanguage,
        speakerTag: hop1.speakerTag,
        sessionTitle: hop1.sessionTitle,
        returnPath: hop1.returnPath,
      );
      // Hop 3: Nhớ → quay lại Cabin Live
      final hop3 = C27Handoff(
        sourceType: C27SourceType.remember,
        sessionId: hop2.sessionId,
        timestamp: hop2.timestamp.add(const Duration(minutes: 1)),
        originalCaption: hop2.originalCaption,
        translatedCaption: hop2.translatedCaption,
        sourceLanguage: hop2.sourceLanguage,
        targetLanguage: hop2.targetLanguage,
        speakerTag: hop2.speakerTag,
        sessionTitle: hop2.sessionTitle,
        returnPath: hop2.returnPath,
      );

      // returnPath không đổi qua cả chuỗi (bất biến #6)
      expect(hop2.returnPath, 'cabin');
      expect(hop3.returnPath, 'cabin');
      // dữ liệu bảo toàn từng hop
      for (final hop in [hop1, hop2, hop3]) {
        expect(hop.sessionId, 's1');
        expect(hop.originalCaption, 'xin chào');
        expect(hop.translatedCaption, 'hello');
        expect(hop.sourceLanguage, 'vi');
        expect(hop.targetLanguage, 'en');
        expect(hop.speakerTag, 'S1');
        expect(hop.sessionTitle, 'Phiên A');
        expect(C27Handoff.validateJson(hop.toJson()), isNull);
      }
      expect(hop2.sourceType, C27SourceType.understand);
      expect(hop3.sourceType, C27SourceType.remember);
    });

    test('returnToCabinPath: mở handoff → đúng returnPath; đóng vẫn giữ', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      controller.startFromListen();
      controller.onFinalCaption(translatedCaption('c1'));
      controller.onTranslatedCaption('c1', 'translated c1');
      expect(controller.returnToCabinPath(), 'cabin');
      controller.openHandoff(target: C27SourceType.understand);
      expect(controller.returnToCabinPath(), 'cabin');
      controller.closeHandoff();
      expect(controller.returnToCabinPath(), 'cabin');
    });

    test('handoff chọn đúng caption theo id', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      controller.startFromListen();
      controller.onFinalCaption(translatedCaption('c1'));
      controller.onTranslatedCaption('c1', 'dịch c1');
      controller.onFinalCaption(translatedCaption('c2'));
      controller.onTranslatedCaption('c2', 'dịch c2');
      controller.openHandoff(
        target: C27SourceType.remember,
        captionId: 'c1',
      );
      expect(controller.activeHandoff!.originalCaption, 'nguồn c1');
      expect(controller.activeHandoff!.translatedCaption, 'dịch c1');
    });
  });
}
