import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/controllers/c27_cabin_live_controller.dart';
import 'package:in4up/features/cabin/models/c27_cabin_live_state.dart';
import 'package:in4up/features/cabin/models/cabin_caption.dart';

/// C-27 — state transition test (doc 43 §3/§4/§9).
/// Kiểm证: đủ 14 state, happy path Nghe→Cabin→Hiểu→Nhớ→về, các chuyển bị reject,
/// guard reconnect 3 lượt, recovery, save/discard, partial không vào snapshot.
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

  group('C-27 state matrix', () {
    test('đủ 14 state và 27 event', () {
      expect(C27CabinLiveState.values.length, 14);
      expect(C27CabinEvent.values.length, 27);
    });

    test('happy path: Nghe → Cabin Live (idle → listening)', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      expect(controller.state, C27CabinLiveState.idle);
      controller.startFromListen(sessionTitle: 'Test');
      expect(controller.state, C27CabinLiveState.listening);
      expect(controller.machine.sessionId, 's1');
    });

    test('chu trình caption partial → final → translated (cùng id)', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      controller.startFromListen();
      controller.onPartialCaption(caption('c1'));
      expect(controller.state, C27CabinLiveState.listening);
      expect(stageOfCabinCaption(controller.captions.single),
          C27CaptionStage.partial);

      controller.onFinalCaption(caption('c1', isFinal: true));
      expect(controller.state, C27CabinLiveState.translating);
      expect(stageOfCabinCaption(controller.captions.single),
          C27CaptionStage.final);

      controller.onTranslatedCaption('c1', 'hello');
      expect(controller.state, C27CabinLiveState.listening);
      expect(stageOfCabinCaption(controller.captions.single),
          C27CaptionStage.translated);
      expect(controller.captions.single.translatedText, 'hello');
      expect(controller.captions.length, 1, reason: 'cùng id chỉ upsert');
    });

    test('pause/resume và playback', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      controller.startFromListen();
      controller.pause();
      expect(controller.state, C27CabinLiveState.paused);
      controller.resume();
      expect(controller.state, C27CabinLiveState.listening);
      controller.startPlayback();
      expect(controller.state, C27CabinLiveState.speaking);
      controller.endPlayback();
      expect(controller.state, C27CabinLiveState.listening);
    });

    test('handoff mở/đóng về đúng state cũ (listening và paused)', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      controller.startFromListen();
      controller.openHandoff(target: C27SourceType.understand);
      expect(controller.state, C27CabinLiveState.handoffActive);
      expect(controller.machine.handoffOrigin, C27CabinLiveState.listening);
      controller.closeHandoff();
      expect(controller.state, C27CabinLiveState.listening);
      expect(controller.activeHandoff, isNull);

      controller.pause();
      controller.openHandoff(target: C27SourceType.remember);
      expect(controller.machine.handoffOrigin, C27CabinLiveState.paused);
      controller.closeHandoff();
      expect(controller.state, C27CabinLiveState.paused);
    });

    test('các chuyển ngoài bảng bị reject (state không đổi)', () {
      final machine = C27CabinLiveStateMachine();
      expect(machine.transition(C27CabinEvent.permissionsGranted), isNull);
      expect(machine.state, C27CabinLiveState.idle);

      // lên listening rồi thử các event không hợp lệ
      machine.transition(C27CabinEvent.startRequested);
      machine.transition(C27CabinEvent.permissionsGranted);
      machine.transition(C27CabinEvent.engineConnect);
      machine.transition(C27CabinEvent.engineConnected);
      expect(machine.state, C27CabinLiveState.listening);
      expect(machine.transition(C27CabinEvent.startRequested), isNull);
      expect(machine.transition(C27CabinEvent.permissionsGranted), isNull);
      expect(machine.state, C27CabinLiveState.listening);

      // ending không nhận caption event
      machine.transition(C27CabinEvent.endRequested);
      expect(machine.state, C27CabinLiveState.ending);
      expect(machine.transition(C27CabinEvent.translatedCaption), isNull);
      expect(machine.state, C27CabinLiveState.ending);

      // saved không quay lại listening cùng session
      machine.transition(C27CabinEvent.saveDraft);
      expect(machine.state, C27CabinLiveState.saved);
      expect(machine.transition(C27CabinEvent.pause), isNull);
      expect(machine.state, C27CabinLiveState.saved);
    });

    test('guard reconnect: quá 3 lượt mới xuống offline', () {
      final machine = C27CabinLiveStateMachine();
      machine.transition(C27CabinEvent.startRequested);
      machine.transition(C27CabinEvent.permissionsGranted);
      machine.transition(C27CabinEvent.engineConnect);
      expect(machine.state, C27CabinLiveState.connecting);

      machine.transition(C27CabinEvent.engineConnectFailed);
      expect(machine.state, C27CabinLiveState.reconnecting);
      expect(machine.reconnectAttempts, 1);

      machine.transition(C27CabinEvent.reconnectFailed);
      expect(machine.state, C27CabinLiveState.reconnecting);
      expect(machine.reconnectAttempts, 2);
      machine.transition(C27CabinEvent.reconnectFailed);
      expect(machine.state, C27CabinLiveState.reconnecting);
      expect(machine.reconnectAttempts, 3);
      machine.transition(C27CabinEvent.reconnectFailed);
      expect(machine.state, C27CabinLiveState.offline);

      // có mạng lại: connecting → listening, reset attempts
      machine.transition(C27CabinEvent.networkRestored);
      expect(machine.state, C27CabinLiveState.connecting);
      machine.transition(C27CabinEvent.engineConnected);
      expect(machine.state, C27CabinLiveState.listening);
      expect(machine.reconnectAttempts, 0);
    });

    test('service unavailable → error → dismiss → recovery', () {
      final machine = C27CabinLiveStateMachine();
      machine.transition(C27CabinEvent.startRequested);
      machine.transition(C27CabinEvent.permissionsGranted);
      machine.transition(C27CabinEvent.engineConnect);
      machine.transition(C27CabinEvent.serviceUnavailable);
      expect(machine.state, C27CabinLiveState.error);
      machine.transition(C27CabinEvent.dismissError);
      expect(machine.state, C27CabinLiveState.idle);
      machine.transition(C27CabinEvent.recoveryLoaded);
      expect(machine.state, C27CabinLiveState.ready);
    });

    test('save draft: chỉ final/translated vào snapshot, partial bị loại', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      controller.startFromListen(sessionTitle: 'T');
      controller.onPartialCaption(caption('c1'));
      controller.onFinalCaption(caption('c2', isFinal: true));
      controller.onTranslatedCaption('c2', 'hello');
      controller.endSession(save: true);
      expect(controller.state, C27CabinLiveState.saved);
      final snapshot = controller.lastSnapshot;
      expect(snapshot, isNotNull);
      expect(snapshot!.saved, isTrue);
      expect(snapshot.sessionId, 's1');
      expect(snapshot.title, 'T');
      expect(snapshot.entries.length, 1, reason: 'partial không vào snapshot');
      expect(snapshot.entries.single.sourceText, 'src-c2');
      expect(snapshot.entries.single.translatedText, 'hello');
    });

    test('discard draft: về idle, không snapshot, đánh dấu discarded', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 's1');
      controller.startFromListen();
      controller.onFinalCaption(caption('c1', isFinal: true));
      controller.endSession(save: false);
      expect(controller.state, C27CabinLiveState.idle);
      expect(controller.discarded, isTrue);
      expect(controller.lastSnapshot, isNull);
    });

    test('saved → reset → idle (phiên mới)', () {
      final machine = C27CabinLiveStateMachine();
      machine.transition(C27CabinEvent.startRequested);
      machine.transition(C27CabinEvent.permissionsGranted);
      machine.transition(C27CabinEvent.engineConnect);
      machine.transition(C27CabinEvent.engineConnected);
      machine.transition(C27CabinEvent.endRequested);
      machine.transition(C27CabinEvent.saveDraft);
      expect(machine.state, C27CabinLiveState.saved);
      machine.transition(C27CabinEvent.reset);
      expect(machine.state, C27CabinLiveState.idle);
    });

    test('sessionId ổn định qua pause/reconnect/offline/handoff', () {
      final controller = C27CabinLiveController(sessionIdFactory: () => 'stable-1');
      controller.startFromListen();
      final id = controller.machine.sessionId;
      controller.pause();
      controller.resume();
      controller.connectionLost();
      controller.reconnected();
      controller.networkLost();
      controller.networkRestored();
      controller.engineConnected();
      controller.openHandoff(target: C27SourceType.understand);
      controller.closeHandoff();
      expect(controller.machine.sessionId, id);
      expect(controller.machine.sessionId, 'stable-1');
    });
  });
}
