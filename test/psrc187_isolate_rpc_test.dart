// test/psrc187_isolate_rpc_test.dart
//
// PSRC-187 (audit v1.27.0) — MÁY BẮT cho kênh hỏi/đáp với worker isolate.
//
// Ở bản 1.27.0, worker của VieNeu-TTS chưa từng khởi tạo được vì giao thức tự
// viết sai hai chỗ (nghe hai lần trên cùng một `ReceivePort`; worker trả lời
// vào chính cổng của mình). `IsolateRpcClient` là kênh hỏi/đáp viết một lần cho
// đúng — Piper (sherpa-onnx) chạy trên nó — và các test dưới đây chạy bằng
// isolate THẬT trên host VM, không mock cổng.
//
// Worker VieNeu giữ giao thức riêng, đã được sửa tại chỗ ở PSRC-183/184
// (PR #175) và khoá bằng test/tts/vieneu_worker_protocol_test.dart +
// test/tts/vieneu_state_contract_test.dart; nhóm cuối file này chỉ khoá thêm
// hai lỗi gốc nói trên trên chính giao thức đó.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/src/isolate_rpc.dart';

/// Handler mẫu: giữ trạng thái trong worker (bộ đếm + nhật ký thứ tự).
IsolateRpcHandler _demoFactory() {
  var counter = 0;
  final order = <String>[];
  return (String command, Map<String, Object?> args) async {
    switch (command) {
      case 'echo':
        return args['value'];
      case 'count':
        counter++;
        return counter;
      case 'slow':
        // Lệnh chậm: nếu worker xử lý song song thì thứ tự sẽ đảo.
        await Future<void>.delayed(
          Duration(milliseconds: (args['ms'] as int?) ?? 50),
        );
        order.add(args['tag'] as String);
        return List<String>.from(order);
      case 'fast':
        order.add(args['tag'] as String);
        return List<String>.from(order);
      case 'boom':
        throw StateError('native said no');
      case 'bytes':
        final input = args['data'] as Uint8List;
        return Uint8List.fromList(input.reversed.toList());
      case 'samples':
        final n = args['n'] as int;
        final out = Float32List(n);
        for (var i = 0; i < n; i++) {
          out[i] = i / n;
        }
        return <String, Object?>{'samples': out, 'sampleRate': 22050};
      case 'isolateName':
        return Isolate.current.debugName;
      case 'die':
        // Mô phỏng worker chết giữa chừng (không trả lời).
        Isolate.exit();
      case 'hang':
        await Future<void>.delayed(const Duration(seconds: 30));
        return 'late';
    }
    throw ArgumentError('unknown command: $command');
  };
}

/// Factory ném lỗi ngay khi khởi tạo (vd không nạp được thư viện native).
IsolateRpcHandler _brokenFactory() {
  throw StateError('cannot load native library');
}

/// Factory bất đồng bộ (nạp tài nguyên rồi mới sẵn sàng).
Future<IsolateRpcHandler> _asyncFactory() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return (String command, Map<String, Object?> args) => 'async:$command';
}

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  }).join('\n');
}

void main() {
  group('IsolateRpcClient — bắt tay và hỏi/đáp', () {
    test('spawn xong là dùng được; trả lời đúng lệnh', () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      addTearDown(client.close);

      expect(client.isAlive, isTrue);
      expect(await client.call('echo', args: {'value': 'xin chào'}),
          'xin chào');
      expect(await client.call('echo', args: {'value': 42}), 42);
    });

    test('handler chạy trong isolate KHÁC và giữ trạng thái giữa các lệnh',
        () async {
      final client =
          await IsolateRpcClient.spawn(_demoFactory, debugName: 'rpc-demo');
      addTearDown(client.close);

      expect(await client.call('isolateName'), 'rpc-demo');
      expect(await client.call('isolateName'),
          isNot(Isolate.current.debugName));
      expect(await client.call('count'), 1);
      expect(await client.call('count'), 2);
      expect(await client.call('count'), 3);
    });

    test('factory bất đồng bộ vẫn bắt tay được', () async {
      final client = await IsolateRpcClient.spawn(_asyncFactory);
      addTearDown(client.close);
      expect(await client.call('ping'), 'async:ping');
    });

    test('typed data đi qua cổng nguyên vẹn (WAV / mẫu PCM)', () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      addTearDown(client.close);

      final reversed = await client.call(
        'bytes',
        args: {
          'data': Uint8List.fromList([1, 2, 3, 4]),
        },
      );
      expect(reversed, isA<Uint8List>());
      expect(reversed, [4, 3, 2, 1]);

      final reply = await client.call('samples', args: {'n': 2205}) as Map;
      final samples = reply['samples'] as Float32List;
      expect(samples.length, 2205);
      expect(samples.first, 0);
      expect(reply['sampleRate'], 22050);
    });
  });

  group('IsolateRpcClient — thứ tự và lỗi', () {
    test('worker xử lý TUẦN TỰ: lệnh chậm gửi trước vẫn xong trước', () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      addTearDown(client.close);

      // Gửi liền ba lệnh, KHÔNG await từng cái.
      final a = client.call('slow', args: {'tag': 'a', 'ms': 80});
      final b = client.call('fast', args: {'tag': 'b'});
      final c = client.call('slow', args: {'tag': 'c', 'ms': 10});

      expect(await a, ['a']);
      expect(await b, ['a', 'b']);
      expect(await c, ['a', 'b', 'c']);
    });

    test('trả lời không lẫn giữa nhiều lời gọi đang chờ', () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      addTearDown(client.close);

      final futures = <Future<Object?>>[
        for (var i = 0; i < 20; i++) client.call('echo', args: {'value': i}),
      ];
      expect(await Future.wait(futures), List<int>.generate(20, (i) => i));
      expect(client.pendingCalls, 0);
    });

    test('handler ném lỗi ⇒ IsolateRpcRemoteException, worker VẪN sống',
        () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      addTearDown(client.close);

      await expectLater(
        client.call('boom'),
        throwsA(
          isA<IsolateRpcRemoteException>().having(
            (e) => e.message,
            'message',
            contains('native said no'),
          ),
        ),
      );
      expect(client.isAlive, isTrue);
      expect(await client.call('echo', args: {'value': 'còn sống'}),
          'còn sống');
    });

    test('quá hạn ⇒ TimeoutException; lời gọi không còn nằm chờ', () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      addTearDown(client.close);

      await expectLater(
        client.call('hang', timeout: const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
      expect(client.pendingCalls, 0);
    });
  });

  group('IsolateRpcClient — worker chết / đóng', () {
    test('worker chết giữa chừng ⇒ lời gọi đang chờ nhận lỗi, KHÔNG treo',
        () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      addTearDown(client.close);

      await expectLater(
        client.call('die').timeout(const Duration(seconds: 10)),
        throwsA(isA<IsolateRpcClosedException>()),
      );
      expect(client.isAlive, isFalse);
      // Sau đó gọi tiếp phải lỗi NGAY, không gửi vào cổng chết.
      await expectLater(
        client.call('echo', args: {'value': 1}),
        throwsA(isA<IsolateRpcClosedException>()),
      );
    });

    test('factory ném lỗi ⇒ spawn báo lỗi rõ, không treo ở bước bắt tay',
        () async {
      await expectLater(
        IsolateRpcClient.spawn(_brokenFactory)
            .timeout(const Duration(seconds: 10)),
        throwsA(
          isA<IsolateRpcClosedException>().having(
            (e) => e.message,
            'message',
            contains('cannot load native library'),
          ),
        ),
      );
    });

    test('close() ⇒ không còn sống; gọi tiếp báo lỗi; gọi close lần hai vô hại',
        () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      expect(await client.call('count'), 1);

      await client.close();
      expect(client.isAlive, isFalse);
      await expectLater(
        client.call('count'),
        throwsA(isA<IsolateRpcClosedException>()),
      );
      await client.close();
    });

    test('close() trong lúc lệnh còn chạy ⇒ lời gọi đó nhận lỗi đóng', () async {
      final client = await IsolateRpcClient.spawn(_demoFactory);
      final hanging = client.call('hang');
      // Gắn người nhận lỗi trước khi đóng.
      final expectation = expectLater(
        hanging,
        throwsA(isA<IsolateRpcClosedException>()),
      );
      await client.close(grace: const Duration(milliseconds: 100));
      await expectation;
    });
  });

  group('PSRC-187 — giao thức worker cũ không được quay lại', () {
    String code(String path) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'thiếu $path');
      return _stripComments(file.readAsStringSync());
    }

    test('isolate_rpc.dart: worker trả lời về cổng của MAIN', () {
      final source = code('packages/in4up_stt/lib/utils/src/isolate_rpc.dart');
      expect(source.contains('boot.replyTo.send('), isTrue);
      expect(source.contains('inbox.sendPort.send('), isFalse,
          reason: 'gửi vào cổng của chính worker = main không bao giờ nhận');
    });

    test('vieneu_tts_core.dart: không còn nghe hai lần / tự trả lời mình', () {
      final source = code('packages/in4up_stt/lib/tts/vieneu_tts_core.dart');
      // Trả lời đi qua một cổng RIÊNG của main, chỉ có MỘT người nghe…
      expect(source.contains('responsePort.listen(_onWorkerMessage)'), isTrue);
      // …còn cổng bắt tay chỉ được đọc bằng `.first`.
      expect(source.contains('commandPort.listen('), isFalse,
          reason: 'ReceivePort chỉ nghe được MỘT lần — `.first` sau `.listen` '
              'ném "Stream has already been listened to"');
      expect(source.contains('_commandPort!.listen('), isFalse);
      expect(source.contains('mainPort.sendPort.send('), isFalse,
          reason: 'worker gửi vào cổng của chính nó ⇒ main không nhận được');
      // Init thất bại thì worker bị đóng, không bị bỏ rơi.
      expect(source.contains('_workerIsolate?.kill('), isTrue,
          reason: 'spawn thủ công từng rò isolate ở mỗi lần init thất bại');
    });

    test('sherpa_piper_tts_core.dart: native chạy trong worker, không ở UI',
        () {
      final source =
          code('packages/in4up_stt/lib/tts/sherpa_piper_tts_core.dart');
      expect(source.contains('IsolateRpcClient.spawn('), isTrue,
          reason: 'OfflineTts/generate phải chạy trong worker isolate');
    });
  });
}
