import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/controllers/c27_cabin_live_scope.dart';
import 'package:in4up/features/cabin/models/c27_cabin_live_state.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';

/// C-27 wiring — test cho scope chia sẻ phiên (doc 42 §1/§10, doc 43).
/// Kiểm chứng: sessionActive đúng theo state, viewport ẩn bubble, handoff
/// inbox + pendingTarget, snapshot chỉ giữ final/translated (bất biến #8).
void main() {
  CabinCaption caption(
    String id, {
    bool isFinal = false,
    String translatedText = '',
  }) =>
      CabinCaption(
        id: id,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
        sourceText: 'src-$id',
        translatedText: translatedText,
        sourceLang: 'vi',
        targetLang: 'en',
        isFinal: isFinal,
      );

  group('C27CabinLiveScope (wiring)', () {
    test('scope mới: chưa có phiên, viewport đóng, không handoff', () {
      final scope = C27CabinLiveScope();
      expect(scope.sessionActive, isFalse);
      expect(scope.viewportOpen, isFalse);
      expect(scope.handoffInbox, isNull);
      expect(scope.controller.state, C27CabinLiveState.idle);
    });

    test('instance chia sẻ đúng một controller', () {
      expect(
        identical(C27CabinLiveScope.instance.controller,
            C27CabinLiveScope.instance.controller),
        isTrue,
      );
    });

    test('start → active; pause vẫn active; endSession(save) → hết active', () {
      final scope = C27CabinLiveScope();
      scope.controller.startFromListen(sessionTitle: 'Phiên học');
      expect(scope.sessionActive, isTrue);
      scope.controller.onFinalCaption(caption('c1', isFinal: true));
      scope.controller.onTranslatedCaption('c1', 'hello');
      scope.controller.pause();
      expect(scope.sessionActive, isTrue); // paused vẫn là phiên đang chạy
      scope.controller.endSession(save: true);
      expect(scope.sessionActive, isFalse);
      expect(scope.controller.lastSnapshot, isNotNull);
      expect(scope.controller.lastSnapshot!.entries.length, 1);
    });

    test('partial không vào snapshot (bất biến #8)', () {
      final scope = C27CabinLiveScope();
      scope.controller.startFromListen();
      scope.controller.onPartialCaption(caption('p1'));
      scope.controller.onFinalCaption(caption('f1', isFinal: true));
      scope.controller.endSession(save: true);
      final entries = scope.controller.lastSnapshot!.entries;
      expect(entries.length, 1);
      expect(entries.single.sourceText, 'src-f1');
    });

    test('setViewportOpen: notify khi đổi, idempotent khi trùng', () {
      final scope = C27CabinLiveScope();
      var notified = 0;
      scope.addListener(() => notified++);
      scope.setViewportOpen(true);
      expect(scope.viewportOpen, isTrue);
      final after = notified;
      expect(after, greaterThan(0));
      scope.setViewportOpen(true); // trùng — không notify lại
      expect(notified, after);
    });

    test('handoff: setHandoff → inbox + pendingTarget; consume 1 lần; clear', () {
      final scope = C27CabinLiveScope();
      scope.controller.startFromListen(sessionTitle: 'Phiên học');
      scope.controller.onFinalCaption(caption('c1', isFinal: true));
      scope.controller.onTranslatedCaption('c1', 'hello');
      scope.controller.openHandoff(
        target: C27SourceType.understand,
        speakerTag: 'S1',
      );
      final handoff = scope.controller.activeHandoff!;
      expect(C27Handoff.validateJson(handoff.toJson()), isNull);
      expect(handoff.sourceType, C27SourceType.cabin);
      expect(handoff.returnPath, 'cabin');
      scope.setHandoff(C27SourceType.understand, handoff);
      expect(scope.handoffInbox, isNotNull);
      expect(scope.consumePendingTarget(), C27SourceType.understand);
      expect(scope.consumePendingTarget(), isNull); // chỉ 1 lần
      scope.clearHandoffInbox();
      expect(scope.handoffInbox, isNull);
    });

    test('returnPath giữ nguyên suốt chuỗi (bất biến #6)', () {
      final scope = C27CabinLiveScope();
      scope.controller.returnPath = 'cabin';
      scope.controller.startFromListen();
      scope.controller.onFinalCaption(caption('c1', isFinal: true));
      scope.controller.onTranslatedCaption('c1', 'b');
      scope.controller.openHandoff(target: C27SourceType.remember);
      expect(scope.controller.returnToCabinPath(), 'cabin');
    });
  });
}
