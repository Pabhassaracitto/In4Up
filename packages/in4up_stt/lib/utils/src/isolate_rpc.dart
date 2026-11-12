// packages/in4up_stt/lib/utils/src/isolate_rpc.dart
//
// PSRC-187 (audit 1.27.0) — KÊNH HỎI/ĐÁP với một worker isolate sống lâu.
//
// VÌ SAO CẦN một lớp dùng chung (thay vì mỗi engine tự viết):
//   Ở bản 1.27.0, worker của VieNeu-TTS tự viết giao thức và sai ở HAI chỗ, nên
//   engine chưa từng khởi tạo được lần nào:
//     1. phía main gọi `port.listen(...)` rồi lại `await port.first` trên CÙNG
//        một `ReceivePort`. `ReceivePort` là stream một-người-nghe
//        (`StreamController(sync: true)` trong `isolate_patch.dart` của SDK)
//        ⇒ lần nghe thứ hai ném `Bad state: Stream has already been listened
//        to.` ngay lập tức;
//     2. phía worker trả lời bằng `mainPort.sendPort.send(...)` — tức gửi vào
//        CHÍNH cổng nhận của nó — nên main không bao giờ nhận được gì, còn
//        worker tự trả lời mình vô hạn.
//   Mỗi lần thử lại rò thêm một isolate (đã spawn, không ai đóng).
//
// Lớp này làm đúng một việc và được test bằng isolate THẬT trên host VM:
//   • một cổng nhận, MỘT người nghe; bắt tay bằng `SendPort` đầu tiên;
//   • worker trả lời về cổng của MAIN, xử lý TUẦN TỰ từng lệnh;
//   • mỗi lệnh có số thứ tự ⇒ trả lời không thể lẫn;
//   • worker chết (thoát / lỗi không bắt) ⇒ mọi lời gọi đang chờ nhận
//     [IsolateRpcClosedException] thay vì treo mãi;
//   • quá hạn ⇒ `TimeoutException`, trả lời đến muộn bị bỏ qua.
//
// Hiện Piper/sherpa-onnx chạy trên lớp này: gọi FFI trong worker để KHÔNG chặn
// luồng UI. (Worker VieNeu giữ giao thức riêng, đã được sửa tại chỗ ở
// PSRC-183/184 — xem `tts/vieneu_tts_core.dart`.) Lưu ý giới hạn: native tự
// `_Exit`/SIGSEGV thì cả tiến trình vẫn chết — isolate không cứu được, phải
// chặn TRƯỚC khi gọi.

import 'dart:async';
import 'dart:isolate';

/// Hàm xử lý lệnh, chạy TRONG worker isolate. Giá trị trả về phải gửi được
/// qua `SendPort` (số, chuỗi, List/Map, typed data…). Ném lỗi ⇒ phía gọi
/// nhận [IsolateRpcRemoteException].
typedef IsolateRpcHandler = FutureOr<Object?> Function(
  String command,
  Map<String, Object?> args,
);

/// Tạo [IsolateRpcHandler] bên trong worker (giữ trạng thái native ở đó).
///
/// PHẢI là hàm top-level hoặc static: nó được gửi sang isolate mới.
typedef IsolateRpcHandlerFactory = FutureOr<IsolateRpcHandler> Function();

/// Lỗi của kênh hỏi/đáp.
class IsolateRpcException implements Exception {
  const IsolateRpcException(this.message);

  final String message;

  @override
  String toString() => 'IsolateRpcException: $message';
}

/// Worker đã đóng/chết nên không thể trả lời.
class IsolateRpcClosedException extends IsolateRpcException {
  const IsolateRpcClosedException(super.message);

  @override
  String toString() => 'IsolateRpcClosedException: $message';
}

/// Handler trong worker ném lỗi khi xử lý lệnh.
class IsolateRpcRemoteException extends IsolateRpcException {
  const IsolateRpcRemoteException(super.message);

  @override
  String toString() => 'IsolateRpcRemoteException: $message';
}

/// Đầu phía main của kênh. Một client = một worker isolate.
class IsolateRpcClient {
  IsolateRpcClient._(
    this._isolate,
    this._inbox,
    this._exitPort,
    this._errorPort,
  );

  static const String _closeCommand = '\u0000close';

  final Isolate _isolate;
  final ReceivePort _inbox;
  final ReceivePort _exitPort;
  final ReceivePort _errorPort;
  final Completer<void> _ready = Completer<void>();
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};

  SendPort? _toWorker;
  int _nextSeq = 0;
  bool _closed = false;
  String _closeReason = 'worker not running';

  /// Worker còn sống và đã bắt tay xong.
  bool get isAlive => !_closed && _toWorker != null;

  /// Số lời gọi đang chờ trả lời.
  int get pendingCalls => _pending.length;

  /// Spawn worker và chờ bắt tay.
  ///
  /// Ném [IsolateRpcClosedException] nếu worker chết trong lúc khởi tạo
  /// (kể cả khi [factory] ném lỗi), `TimeoutException` nếu quá
  /// [handshakeTimeout].
  static Future<IsolateRpcClient> spawn(
    IsolateRpcHandlerFactory factory, {
    String debugName = 'isolate-rpc',
    Duration handshakeTimeout = const Duration(seconds: 30),
  }) async {
    final inbox = ReceivePort();
    final exitPort = ReceivePort();
    final errorPort = ReceivePort();
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn<_IsolateRpcBoot>(
        _isolateRpcMain,
        _IsolateRpcBoot(inbox.sendPort, factory),
        onExit: exitPort.sendPort,
        onError: errorPort.sendPort,
        errorsAreFatal: true,
        debugName: debugName,
      );
    } catch (_) {
      inbox.close();
      exitPort.close();
      errorPort.close();
      rethrow;
    }

    final client = IsolateRpcClient._(isolate, inbox, exitPort, errorPort);
    client._attach();
    try {
      await client._ready.future.timeout(handshakeTimeout);
    } catch (error) {
      client._shutdown('handshake failed: $error', kill: true);
      rethrow;
    }
    return client;
  }

  void _attach() {
    // Lỗi của `_ready` luôn có người nhận ⇒ không thành "unhandled error" khi
    // worker chết sau lúc `spawn` đã hết chờ.
    _ready.future.then<void>((_) {}, onError: (Object _) {});
    // MỘT người nghe duy nhất trên mỗi cổng.
    _inbox.listen(_onMessage);
    _exitPort.listen((dynamic _) => _shutdown('worker isolate exited'));
    _errorPort.listen((dynamic message) {
      final detail = message is List && message.isNotEmpty
          ? '${message.first}'
          : '$message';
      _shutdown('worker isolate crashed: $detail');
    });
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _toWorker = message;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }
    if (message is List && message.length == 3 && message[0] is int) {
      final completer = _pending.remove(message[0] as int);
      if (completer == null || completer.isCompleted) return;
      if (message[1] == true) {
        completer.complete(message[2]);
      } else {
        completer.completeError(IsolateRpcRemoteException('${message[2]}'));
      }
    }
  }

  void _shutdown(String reason, {bool kill = false}) {
    if (_closed) return;
    _closed = true;
    _closeReason = reason;
    _toWorker = null;
    if (kill) {
      try {
        _isolate.kill(priority: Isolate.immediate);
      } catch (_) {}
    }
    _inbox.close();
    _exitPort.close();
    _errorPort.close();

    final error = IsolateRpcClosedException(reason);
    if (!_ready.isCompleted) _ready.completeError(error);
    final waiting = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in waiting) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  /// Gửi [command] kèm [args] và chờ trả lời.
  ///
  /// Lỗi: [IsolateRpcClosedException] (worker đã đóng/chết),
  /// [IsolateRpcRemoteException] (handler ném lỗi), `TimeoutException`
  /// (quá [timeout]).
  Future<Object?> call(
    String command, {
    Map<String, Object?> args = const <String, Object?>{},
    Duration? timeout,
  }) {
    final port = _toWorker;
    if (_closed || port == null) {
      return Future<Object?>.error(IsolateRpcClosedException(_closeReason));
    }
    final seq = _nextSeq++;
    final completer = Completer<Object?>();
    _pending[seq] = completer;
    try {
      port.send(<Object?>[seq, command, args]);
    } catch (error) {
      _pending.remove(seq);
      return Future<Object?>.error(
        IsolateRpcException('cannot send "$command": $error'),
      );
    }
    if (timeout == null) return completer.future;
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(seq);
        throw TimeoutException('Isolate RPC "$command" timed out', timeout);
      },
    );
  }

  /// Đóng worker: xin nó tự thoát, quá [grace] thì kill.
  Future<void> close({Duration grace = const Duration(seconds: 2)}) async {
    if (_closed) return;
    try {
      _toWorker?.send(const <Object?>[-1, _closeCommand, <String, Object?>{}]);
    } catch (_) {}
    final deadline = DateTime.now().add(grace);
    while (!_closed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    _shutdown('closed', kill: true);
  }
}

class _IsolateRpcBoot {
  const _IsolateRpcBoot(this.replyTo, this.factory);

  final SendPort replyTo;
  final IsolateRpcHandlerFactory factory;
}

/// Điểm vào của worker isolate.
Future<void> _isolateRpcMain(_IsolateRpcBoot boot) async {
  final inbox = ReceivePort();
  final handler = await boot.factory();
  // Bắt tay: gửi cổng nhận của worker về cho MAIN.
  boot.replyTo.send(inbox.sendPort);

  // `await for` ⇒ lệnh sau chỉ được lấy ra khi lệnh trước đã trả lời xong.
  await for (final dynamic message in inbox) {
    if (message is! List || message.length != 3) continue;
    final seq = message[0];
    final command = message[1];
    if (command == IsolateRpcClient._closeCommand) break;
    if (seq is! int || command is! String) continue;
    final rawArgs = message[2];
    final args = rawArgs is Map
        ? rawArgs.cast<String, Object?>()
        : const <String, Object?>{};
    try {
      final result = await handler(command, args);
      boot.replyTo.send(<Object?>[seq, true, result]);
    } catch (error) {
      // Trả lời về cổng của MAIN — không phải `inbox.sendPort`.
      boot.replyTo.send(<Object?>[seq, false, '$error']);
    }
  }
  inbox.close();
}
