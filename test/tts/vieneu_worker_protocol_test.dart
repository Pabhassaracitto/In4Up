// test/tts/vieneu_worker_protocol_test.dart — PSRC-183/184
//
// Lỗi gốc của cả 4 issue: worker isolate gửi response vào CHÍNH ReceivePort
// của nó (`mainPort.sendPort.send`) thay vì port trả lời của main isolate.
// Hệ quả: `init` / `clone_voice` / `synthesize` treo tới timeout, engine báo
// "chưa import / worker chưa khởi tạo" dù file GGUF đã có.
//
// Test này spawn worker thật (không cần lib native) và gửi một lệnh lạ: chỉ
// cần kiểm tra response có `seq` đi qua replyPort là đủ bắt được hướng port.

import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/vieneu_tts_core.dart';

void main() {
  test('worker trả lời qua replyPort của main isolate (đúng seq)', () async {
    final handshakePort = ReceivePort();
    final replyPort = ReceivePort();
    final isolate = await Isolate.spawn(
      vieneuTtsWorkerEntry,
      <SendPort>[handshakePort.sendPort, replyPort.sendPort],
    );
    addTearDown(() {
      isolate.kill(priority: Isolate.immediate);
      handshakePort.close();
      replyPort.close();
    });

    final workerPort = await handshakePort.first
        .timeout(const Duration(seconds: 20)) as SendPort;
    const int seq = 42;
    workerPort.send(<String, dynamic>{'cmd': '_probe', 'seq': seq});
    final reply = await replyPort.first
        .timeout(const Duration(seconds: 20)) as Map<dynamic, dynamic>;

    expect(reply['seq'], seq,
        reason: 'Response phải mang đúng seq để complete _pending');
    expect(reply['ok'], false);
    expect(reply['error'].toString(), contains('Lệnh không nhận diện'));
  });

  test('worker không tự gửi response ngược lại vào port lệnh', () async {
    final handshakePort = ReceivePort();
    final replyPort = ReceivePort();
    final isolate = await Isolate.spawn(
      vieneuTtsWorkerEntry,
      <SendPort>[handshakePort.sendPort, replyPort.sendPort],
    );
    addTearDown(() {
      isolate.kill(priority: Isolate.immediate);
      handshakePort.close();
      replyPort.close();
    });

    final workerPort = await handshakePort.first
        .timeout(const Duration(seconds: 20)) as SendPort;
    final received = <Map<dynamic, dynamic>>[];
    final subscription = replyPort.listen((message) {
      received.add(message as Map<dynamic, dynamic>);
    });
    addTearDown(subscription.cancel);
    workerPort.send(<String, dynamic>{'cmd': '_probe', 'seq': 7});

    // Nếu response bị gửi nhầm vào mainPort của worker, nó quay lại
    // `mainPort.listen` và sinh THÊM response (vòng lặp không hồi kết).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(received.length, 1,
        reason: 'Worker chỉ được gửi MỘT response cho mỗi lệnh');
    expect(received.single['seq'], 7);
  });
}
