/// ═══════════════════════════════════════════════════════════════
/// TEXT PIPELINE WORKER — Background Worker Isolate (mục 4 bàn giao)
///
/// "Giao tiếp: chỉ qua SendPort/ReceivePort, payload là primitive/JSON,
///  KHÔNG share mutable object giữa 2 isolate."
///
/// Triển khai: worker DÀI HẠNG (long-lived) — nền táng cho các job sau
/// (Attention Score Task 7, compaction Task 5, lexical search) cùng chạy
/// ở isolate này, cách ly hoàn toàn khỏi audio/UI isolate (mục 0).
///
/// Protocol (toàn bộ Map<String,dynamic> JSON-able):
///   main → worker: {'id': int, 'op': 'process'|'close', 'request': {...}?}
///   worker → main: {'id': int, 'ok': bool, 'result': {...}?, 'error': str?}
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:isolate';

import 'text_pipeline.dart';
import 'vietnamese_trie.dart';

/// Client đứng ở isolate gọi (main/UI hoặc test).
class TextPipelineWorker {
  late final SendPort _commandPort;
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};
  int _seq = 0;
  late final Isolate _isolate;

  TextPipelineWorker._();

  /// Spawn worker isolate; trie seed dựng MỘT LẦN bên trong worker.
  static Future<TextPipelineWorker> spawn() {
    final worker = TextPipelineWorker._();
    final ready = Completer<TextPipelineWorker>();
    final bootstrap = ReceivePort();

    Isolate.spawn(_workerEntry, bootstrap.sendPort).then((isolate) {
      worker._isolate = isolate;
      bootstrap.listen((msg) {
        if (msg is SendPort) {
          worker._commandPort = msg;
          worker._responses.listen((reply) {
            final map = reply as Map<String, dynamic>;
            final completer = worker._pending.remove(map['id'] as int);
            if (completer == null || completer.isCompleted) return;
            if (map['ok'] == true) {
              completer.complete(map['result'] as Map<String, dynamic>);
            } else {
              completer.completeError(StateError(
                  'TextPipelineWorker: ${map['error'] ?? 'lỗi không rõ'}'));
            }
          });
          // gửi port nhận kết quả về cho worker
          worker._commandPort.send(<String, dynamic>{
            'op': 'handshake',
            'replyTo': worker._responses.sendPort,
          });
          ready.complete(worker);
        }
      });
    }).catchError((Object e) {
      ready.completeError(e);
    });
    return ready.future;
  }

  /// Chạy pipeline trong worker isolate — payload JSON hai chiều.
  Future<PipelineResult> process(PipelineRequest request) async {
    final id = ++_seq;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _commandPort.send(<String, dynamic>{
      'id': id,
      'op': 'process',
      'request': request.toJson(),
    });
    final resultMap = await completer.future;
    return PipelineResult.fromJson(resultMap);
  }

  /// Đóng worker (idempotent).
  void dispose() {
    _commandPort.send(<String, dynamic>{'op': 'close'});
    _responses.close();
    _isolate.kill(priority: Isolate.immediate);
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('TextPipelineWorker đã đóng'));
      }
    }
    _pending.clear();
  }

  /// Entry point chạy TRONG worker isolate.
  static void _workerEntry(SendPort bootstrap) {
    final port = ReceivePort();
    bootstrap.send(port.sendPort);
    SendPort? replyTo;
    var trie = VietnameseTrie.fromWords(kSeedVietnameseCompoundWords);

    port.listen((message) {
      final msg = message as Map<String, dynamic>;
      final op = msg['op'] as String?;
      if (op == 'handshake') {
        replyTo = msg['replyTo'] as SendPort;
        return;
      }
      if (op == 'close') {
        // Isolate.exit() trả Never — KHÔNG đặt lệnh gì ngay sau
        // (dead_code hint là fatal ở CI này).
        Isolate.exit();
      } else if (op == 'process') {
        final send = replyTo;
        if (send == null) {
          return; // chưa handshake — bỏ qua (không thể reply)
        }
        final id = msg['id'] as int;
        try {
          final request =
              PipelineRequest.fromJson(msg['request'] as Map<String, dynamic>);
          final result = TextPipeline.process(request, trie: trie);
          send.send(<String, dynamic>{
            'id': id,
            'ok': true,
            'result': result.toJson(),
          });
        } catch (e) {
          send.send(<String, dynamic>{
            'id': id,
            'ok': false,
            'error': e.toString(),
          });
        }
      } else if (op == 'reloadTrie') {
        // (dự phòng cho tương lai: nạp từ điển người dùng) — giữ stateless v1.
        trie = VietnameseTrie.fromWords(
            (msg['words'] as List<dynamic>).whereType<String>());
      }
    });
  }
}
