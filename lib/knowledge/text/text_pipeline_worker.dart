/// ═══════════════════════════════════════════════════════════════
/// TEXT PIPELINE WORKER — Background Worker Isolate (mục 4 bàn giao)
///
/// "Giao tiếp: chỉ qua SendPort/ReceivePort, payload là primitive/JSON,
///  KHÔNG share mutable object giữa 2 isolate."
///
/// Thiết kế v1.1 (sau bisect C1–C4): KHÔNG handshake trạng thái — mỗi
/// request tự mang SendPort nhận kết quả (reply-port pattern). Worker
/// dài hạn, trie seed dựng MỘT LẦN trong isolate. Nền tảng cho các job
/// sau (Attention Score, compaction, lexical search) cùng isolate này —
/// cách ly hoàn toàn khỏi audio/UI isolate (mục 0).
///
/// Protocol (JSON-able hai chiều):
///   main → worker: {'id': int, 'op': 'process', 'request': {...},
///                   'replyTo': SendPort}
///   worker → main: {'id': int, 'result': {...}} qua replyTo
///   main → worker: {'op': 'close'} ⇒ Isolate.exit()
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:isolate';

import 'text_pipeline.dart';
import 'vietnamese_trie.dart';

/// Client đứng ở isolate gọi (main/UI hoặc test).
class TextPipelineWorker {
  final ReceivePort _responses = ReceivePort();
  late final SendPort _commandPort;
  int _seq = 0;

  TextPipelineWorker._();

  /// Spawn worker isolate; trie seed dựng MỘT LẦN bên trong worker.
  static Future<TextPipelineWorker> spawn() async {
    final worker = TextPipelineWorker._();
    final bootstrap = ReceivePort();
    await Isolate.spawn(_workerEntry, bootstrap.sendPort);
    worker._commandPort = await bootstrap.first as SendPort;
    bootstrap.close();
    return worker;
  }

  /// Chạy pipeline trong worker isolate — payload JSON hai chiều.
  Future<PipelineResult> process(PipelineRequest request) async {
    final id = ++_seq;
    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription<dynamic> subscription;
    subscription = _responses.listen((reply) {
      final map = reply as Map<String, dynamic>;
      if (map['id'] as int == id) {
        if (!completer.isCompleted) {
          if (map['error'] != null) {
            completer.completeError(
                StateError('worker lỗi: ${map['error']}'));
          } else {
            completer.complete(map['result'] as Map<String, dynamic>);
          }
        }
        subscription.cancel();
      }
    });
    _commandPort.send(<String, dynamic>{
      'id': id,
      'op': 'process',
      'request': request.toJson(),
      'replyTo': _responses.sendPort,
    });
    try {
      return PipelineResult.fromJson(await completer.future);
    } finally {
      await subscription.cancel();
    }
  }

  /// Đóng worker.
  void dispose() {
    _commandPort.send(<String, dynamic>{'op': 'close'});
    _responses.close();
  }

  /// Entry point chạy TRONG worker isolate — state tối thiểu.
  static void _workerEntry(SendPort bootstrap) {
    final port = ReceivePort();
    bootstrap.send(port.sendPort);
    final trie = VietnameseTrie.fromWords(kSeedVietnameseCompoundWords);

    port.listen((message) {
      final msg = message as Map<String, dynamic>;
      if (msg['op'] == 'process') {
        try {
          final request =
              PipelineRequest.fromJson(msg['request'] as Map<String, dynamic>);
          final result = TextPipeline.process(request, trie: trie);
          (msg['replyTo'] as SendPort).send(<String, dynamic>{
            'id': msg['id'],
            'result': result.toJson(),
          });
        } catch (e) {
          (msg['replyTo'] as SendPort).send(<String, dynamic>{
            'id': msg['id'],
            'error': e.toString(),
          });
        }
      } else if (msg['op'] == 'close') {
        // Isolate.exit() trả Never — không đặt lệnh gì ngay sau.
        Isolate.exit();
      }
    });
  }
}
