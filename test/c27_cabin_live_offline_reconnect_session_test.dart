import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/controllers/c27_cabin_live_controller.dart';
import 'package:in4up/features/cabin/models/c27_cabin_live_state.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';

/// C-27 — offline/reconnect/session preservation test (doc 43 §7/§8/§9).
/// Kiểm chứng: reconnect có backoff và không mất session; offline → có mạng →
/// tiếp tục; service unavailable → error nhưng giữ session để save draft;
/// save draft chỉ chứa final/translated; discard không để lại snapshot;
/// sessionId ổn định suốt vòng đời.
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

  C27CabinLiveController startedController({String sessionId = 's-offline'}) {
    final controller = C27CabinLiveController(sessionIdFactory: () => sessionId);
    controller.startFromListen(
      sessionTitle: 'Phiên offline',
      sourceLang: 'vi',
      targetLang: 'en',
    );
    return controller;
  }

  group('C-27 reconnect', () {
    test('mất kết nối → reconnecting → về listening, session giữ nguyên', () {
      final controller = startedController();
      controller.onFinalCaption(caption('c1', isFinal: true));
      controller.onTranslatedCaption('c1', 'dịch c1');
      final id = controller.machine.sessionId;
      final captionCount = controller.captions.length;

      controller.connectionLost();
      expect(controller.state, C27CabinLiveState.reconnecting);
      controller.reconnected();
      expect(controller.state, C27CabinLiveState.listening);

      expect(controller.machine.sessionId, id);
      expect(controller.captions.length, captionCount);
      expect(controller.captions.single.translatedText, 'dịch c1');
    });

    test('reconnect quá 3 lượt → offline; có mạng lại → connecting → listening', () {
      final controller = startedController();
      controller.connectionLost();
      expect(controller.state, C27CabinLiveState.reconnecting);
      controller.reconnectFailed();
      controller.reconnectFailed();
      expect(controller.state, C27CabinLiveState.reconnecting);
      controller.reconnectFailed();
      expect(controller.state, C27CabinLiveState.offline);

      controller.networkRestored();
      expect(controller.state, C27CabinLiveState.connecting);
      controller.engineConnected();
      expect(controller.state, C27CabinLiveState.listening);
      expect(controller.machine.reconnectAttempts, 0);
    });
  });

  group('C-27 offline', () {
    test('mất mạng từ paused → offline; có mạng → tiếp tục, session giữ nguyên', () {
      final controller = startedController();
      controller.onFinalCaption(caption('c1', isFinal: true));
      final id = controller.machine.sessionId;

      controller.pause();
      expect(controller.state, C27CabinLiveState.paused);
      controller.networkLost();
      expect(controller.state, C27CabinLiveState.offline);
      // transcript vẫn xem được khi offline
      expect(controller.captions.single.sourceText, 'src-c1');

      controller.networkRestored();
      expect(controller.state, C27CabinLiveState.connecting);
      controller.engineConnected();
      expect(controller.state, C27CabinLiveState.listening);
      expect(controller.machine.sessionId, id);
    });
  });

  group('C-27 service unavailable + session preservation', () {
    test('engine lỗi vĩnh viễn → error; vẫn giữ session để save draft', () {
      final controller = startedController();
      controller.onPartialCaption(caption('c1'));
      controller.onFinalCaption(caption('c2', isFinal: true));
      controller.onTranslatedCaption('c2', 'dịch c2');
      final id = controller.machine.sessionId;

      // đang nghe thì engine báo lỗi vĩnh viễn
      controller.serviceUnavailable();
      expect(controller.state, C27CabinLiveState.error);
      // dữ liệu vẫn còn
      expect(controller.captions.length, 2);

      // bỏ lỗi → idle → khôi phục phiên → kết thúc và lưu nháp
      controller.dismissError();
      expect(controller.state, C27CabinLiveState.idle);
      controller.loadRecovered(sessionId: id!, sessionTitle: 'Phiên offline');
      expect(controller.state, C27CabinLiveState.ready);
      expect(controller.machine.sessionId, id);

      controller.endSession(save: true);
      expect(controller.state, C27CabinLiveState.saved);
      final snapshot = controller.lastSnapshot;
      expect(snapshot, isNotNull);
      expect(snapshot!.sessionId, id);
      expect(snapshot.entries.length, 1, reason: 'partial không vào snapshot');
      expect(snapshot.entries.single.sourceText, 'src-c2');
      expect(snapshot.entries.single.translatedText, 'dịch c2');
    });

    test('pause giữ sessionId; kết thúc từ paused vẫn lưu được', () {
      final controller = startedController(sessionId: 's-pause');
      controller.onFinalCaption(caption('c1', isFinal: true));
      controller.onTranslatedCaption('c1', 'dịch c1');
      controller.pause();
      expect(controller.machine.sessionId, 's-pause');
      controller.endSession(save: true);
      expect(controller.state, C27CabinLiveState.saved);
      expect(controller.lastSnapshot!.sessionId, 's-pause');
      expect(controller.lastSnapshot!.entries.single.translatedText, 'dịch c1');
    });

    test('discard: không để lại snapshot, session bị bỏ', () {
      final controller = startedController(sessionId: 's-discard');
      controller.onFinalCaption(caption('c1', isFinal: true));
      controller.endSession(save: false);
      expect(controller.state, C27CabinLiveState.idle);
      expect(controller.discarded, isTrue);
      expect(controller.lastSnapshot, isNull);
    });

    test('sessionId ổn định qua cả vòng đời có sự cố', () {
      final controller = startedController(sessionId: 's-gauntlet');
      controller.onFinalCaption(caption('c1', isFinal: true));
      controller.onTranslatedCaption('c1', 'dịch c1');
      const id = 's-gauntlet';

      controller.pause();
      controller.resume();
      controller.connectionLost();
      controller.reconnected();
      controller.networkLost();
      controller.networkRestored();
      controller.engineConnected();
      controller.openHandoff(target: C27SourceType.understand);
      controller.closeHandoff();
      controller.pause();
      controller.resume();
      controller.endSession(save: true);

      expect(controller.state, C27CabinLiveState.saved);
      expect(controller.machine.sessionId, id);
      expect(controller.lastSnapshot!.sessionId, id);
      expect(controller.lastSnapshot!.entries.single.sourceText, 'src-c1');
    });
  });
}
