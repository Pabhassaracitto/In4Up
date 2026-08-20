/// ═══════════════════════════════════════════════════════════════
/// TEXT PIPELINE WORKER — Background Worker Isolate (mục 4 bàn giao)
///
/// "Giao tiếp: chỉ qua SendPort/ReceivePort, payload là primitive/JSON,
///  KHÔNG share mutable object giữa 2 isolate."
///
/// Thiết kế v1.2 (sau bisect C1–C5): bootstrap 1 tin nhắn (không chuỗi
/// closure .then/.catchError), MỘT listener thường trực trên responses
/// (ReceivePort là single-subscription — không được listen mỗi request),
/// bảng pending theo id cho nhiều request chồng lấn. Worker dài hạn,
/// trie seed dựng MỘT LẦN trong isolate. Nền cho các job sau (Attention
/// Score, compaction, lexical search) — cách ly khỏi audio/UI (mục 0).
///
/// Protocol (JSON-able hai chiều):
///   main → worker: {'id': int, 'op': 'process', 'request': {...},
///                   'replyTo': SendPort} | {'op': 'close'}
///   worker → main: {'id': int, 'result': {...}|'error': str} qua replyTo
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:isolate';

import 'text_pipeline.dart';
import 'vietnamese_trie.dart';

/// Client đứng ở isolate gọi (main/UI hoặc test).
class TextPipelineWorker {
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};
  late final SendPort _commandPort;
  late final StreamSubscription<dynamic> _listener;
  int _seq = 0;

  TextPipelineWorker._();

  /// Spawn worker isolate; trie seed dựng MỘT LẦN bên trong worker.
  static Future<TextPipelineWorker> spawn() async {
    final worker = TextPipelineWorker._();
    final bootstrap = ReceivePort();
    await Isolate.spawn(_workerEntry, bootstrap.sendPort);
    worker._commandPort = await bootstrap.first as SendPort;
    bootstrap.close();

    // MỘT listener thường trực — phân phát kết quả theo id.
    worker._listener = worker._responses.listen((reply) {
      final map = reply as Map<String, dynamic>;
      final completer = worker._pending.remove(map['id'] as int);
      if (completer == null || completer.isCompleted) return;
      if (map['error'] != null) {
        completer.completeError(StateError('worker lỗi: ${map['error']}'));
      } else {
        completer.complete(map['result'] as Map<String, dynamic>);
      }
    });
    return worker;
  }

  /// Chạy pipeline trong worker isolate — payload JSON hai chiều.
  /// An toàn khi gọi chồng lấn nhiều request (phân phát theo id).
  Future<PipelineResult> process(PipelineRequest request) async {
    final id = ++_seq;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _commandPort.send(<String, dynamic>{
      'id': id,
      'op': 'process',
      'request': request.toJson(),
      'replyTo': _responses.sendPort,
    });
    final resultMap = await completer.future;
    return PipelineResult.fromJson(resultMap);
  }

  /// Đóng worker; các request đang chờ hoàn tất với lỗi.
  void dispose() {
    _commandPort.send(<String, dynamic>{'op': 'close'});
    _listener.cancel();
    _responses.close();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('TextPipelineWorker đã đóng'));
      }
    }
    _pending.clear();
  }

  /// Entry point chạy TRONG worker isolate — state tối thiểu.
  static void _workerEntry(SendPort bootstrap) {
    final port = ReceivePort();
    bootstrap.send(port.sendPort);
    final trie = VietnameseTrie.fromWords(kSeedVietnameseCompoundWords);

    port.listen((message) {
      final msg = message as Map<String, dynamic>;
      final replyTo = msg['replyTo'] as SendPort?;
      if (msg['op'] == 'process' && replyTo != null) {
        try {
          final request =
              PipelineRequest.fromJson(msg['request'] as Map<String, dynamic>);
          final result = TextPipeline.process(request, trie: trie);
          replyTo.send(<String, dynamic>{
            'id': msg['id'],
            'result': result.toJson(),
          });
        } catch (e) {
          replyTo.send(<String, dynamic>{
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
