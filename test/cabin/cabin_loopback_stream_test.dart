import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_loopback_stream.dart';

class FakeDevice implements CabinLoopbackDevice {
  FakeDevice({this.rate = 16000, this.channelCount = 2, this.failStart = false});
  final int rate;
  final int channelCount;
  final bool failStart;
  bool closed = false;
  int reads = 0;
  @override
  int get sampleRate => rate;
  @override
  int get channels => channelCount;
  @override
  void start() {
    if (failStart) throw StateError('start failed');
  }
  @override
  Float32List read(int maxFrames) {
    reads++;
    if (reads == 1) return Float32List.fromList([1, 1, -1, -1]);
    return Float32List(0);
  }
  @override
  void close() { closed = true; }
}

void main() {
  test('converts and closes on cancellation', () async {
    final device = FakeDevice();
    final first = await cabinLoopbackStream(() => device).first;
    expect(first, [255, 127, 0, 128]);
    expect(device.closed, isTrue);
  });

  test('closes when native startup fails', () async {
    final device = FakeDevice(failStart: true);
    await expectLater(cabinLoopbackStream(() => device), emitsError(isA<StateError>()));
    expect(device.closed, isTrue);
  });

  test('rejects a bad format and closes the device', () async {
    final device = FakeDevice(rate: 0);
    await expectLater(cabinLoopbackStream(() => device), emitsError(isA<StateError>()));
    expect(device.closed, isTrue);
    expect(device.reads, 0);
  });

  test('rejects partial and oversized frames and closes the device', () async {
    for (final channels in [3, 1]) {
      final device = FakeDevice(channelCount: channels);
      await expectLater(
        cabinLoopbackStream(() => device, maxFrames: 1),
        emitsError(isA<StateError>()),
      );
      expect(device.closed, isTrue);
    }
  });

  test('invalid polling arguments fail before creating a device', () async {
    var created = false;
    final stream = cabinLoopbackStream(() {
      created = true;
      return FakeDevice();
    }, pollInterval: Duration.zero);
    await expectLater(stream, emitsError(isA<ArgumentError>()));
    expect(created, isFalse);
  });
}
