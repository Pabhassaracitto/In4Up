import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_android_capture.dart';

void main() {
  test('waits for ready and started, forwards PCM and stops on cancel', () async {
    final events = StreamController<dynamic>();
    final calls = <String>[];
    final capture = CabinAndroidCapture(
      eventStream: () => events.stream,
      invoke: (method, [args]) async {
        calls.add(method);
        if (method == 'start') {
          events.add('started');
          return true;
        }
        return null;
      },
    );
    final opening = capture.open(overlay: true);
    events.add('ready');
    final pcm = await opening;
    final first = pcm.first;
    events.add(Uint8List.fromList([1, 2]));
    expect(await first, [1, 2]);
    expect(calls, ['start', 'stop']);
    await events.close();
  });

  test('denied consent fails and releases the native session', () async {
    final events = StreamController<dynamic>();
    final calls = <String>[];
    final capture = CabinAndroidCapture(
      eventStream: () => events.stream,
      invoke: (method, [args]) async {
        calls.add(method);
        if (method == 'start') {
          events.addError(StateError('denied'));
          return true;
        }
        return null;
      },
    );
    final opening = capture.open();
    events.add('ready');
    await expectLater(opening, throwsStateError);
    expect(calls, ['start', 'stop']);
    await events.close();
  });

  test('invalid PCM packet ends capture rather than passing corrupt audio', () async {
    final events = StreamController<dynamic>();
    final calls = <String>[];
    final capture = CabinAndroidCapture(
      eventStream: () => events.stream,
      invoke: (method, [args]) async {
        calls.add(method);
        if (method == 'start') { events.add('started'); return true; }
        return null;
      },
    );
    final opening = capture.open();
    events.add('ready');
    final stream = await opening;
    final expectation = expectLater(stream, emitsError(isA<StateError>()));
    events.add(Uint8List.fromList([1]));
    await expectation;
    await capture.close();
    expect(calls, ['start', 'stop']);
    await events.close();
  });

  test('closing a pending consent rejects the open operation', () async {
    final events = StreamController<dynamic>();
    final startCalled = Completer<void>();
    final capture = CabinAndroidCapture(
      eventStream: () => events.stream,
      invoke: (method, [args]) async {
        if (method == 'start') { startCalled.complete(); return true; }
        return null;
      },
    );
    final opening = capture.open();
    final expectation = expectLater(opening, throwsStateError);
    events.add('ready');
    await startCalled.future;
    await capture.close();
    await expectation;
    await events.close();
  });
}
