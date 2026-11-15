import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import '../models/dict_info.dart';
import 'dict_mdd_resources.dart';
import 'mdd_reader.dart';
import 'random_access_source.dart';

/// An explicitly cancelled operation; distinct from a missing resource.
class MddReadCancelled implements Exception {
  const MddReadCancelled();
  @override
  String toString() => 'MDD resource read cancelled';
}

/// Bounded pool. The worker indexes/decompresses; the originating isolate owns
/// all file/SAF handles and services seek/read RPCs. The pool retains no cache.
class MddWorkerPool {
  final int maxConcurrent;
  final int maxQueued;
  final Queue<MddReadTask> _queue = Queue();
  int _active = 0;

  MddWorkerPool({this.maxConcurrent = 1, this.maxQueued = 16}) {
    if (maxConcurrent < 1 || maxConcurrent > 2 || maxQueued < 0 || maxQueued > 16) {
      throw ArgumentError('Invalid worker pool limits');
    }
  }

  MddReadTask start(DictInfo info, String key) {
    if (_active >= maxConcurrent && _queue.length >= maxQueued) {
      throw StateError('MDD worker queue is full');
    }
    final task = MddReadTask._(this, info, key);
    _queue.add(task);
    _drain();
    return task;
  }

  void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      if (task._finishing) continue;
      _active++;
      task._active = true;
      task._launchFuture = task._launch();
    }
  }

  void _finished(MddReadTask task) {
    if (task._active) {
      _active--;
      task._active = false;
    } else {
      _queue.remove(task);
    }
    _drain();
  }
}

/// Call [cancel] when a consumer goes away and await it to ensure open handles
/// and outstanding native reads are closed/settled. Result completes once only.
class MddReadTask {
  final MddWorkerPool _pool;
  final DictInfo _info;
  final String _key;
  final Completer<Uint8List?> _result = Completer();
  final Completer<void> _finished = Completer();
  Future<void>? _launchFuture;
  Future<void>? _operation;
  ReceivePort? _port;
  Isolate? _isolate;
  RandomAccessSource? _source;
  List<String> _locations = const [];
  bool _active = false;
  bool _finishing = false;

  MddReadTask._(this._pool, this._info, this._key);
  Future<Uint8List?> get result => _result.future;

  Future<void> cancel() {
    _finish(error: const MddReadCancelled(), kill: true);
    return _finished.future;
  }

  Future<void> _launch() async {
    try {
      if (MddReader.normalizeKey(_key) == null) {
        unawaited(_finish());
        return;
      }
      _locations = await DictMddResources(_info).locations();
      if (_finishing) return;
      if (_locations.length > MddParts.maxParts) {
        throw const FormatException('Too many MDD parts');
      }
      if (_locations.isEmpty) {
        unawaited(_finish());
        return;
      }
      final port = _port = ReceivePort();
      port.listen(_message);
      final isolate = await Isolate.spawn(
        _workerMain, [port.sendPort, _key, _locations.length],
        onExit: port.sendPort, onError: port.sendPort, errorsAreFatal: true,
      );
      if (_finishing) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    } catch (error) {
      unawaited(_finish(error: error));
    }
  }

  void _message(dynamic message) {
    if (_finishing) return;
    if (message == null) {
      unawaited(_finish(error: StateError('MDD worker exited unexpectedly')));
    } else if (message is List && message.isNotEmpty && message[0] == 'rpc') {
      _operation = _handleRpc(message);
    } else if (message is List && message.isNotEmpty && message[0] == 'result') {
      final value = message[1];
      unawaited(_finish(data: value == null ? null : (value as TransferableTypedData).materialize().asUint8List()));
    } else if (message is List && message.isNotEmpty && message[0] == 'error') {
      unawaited(_finish(error: _unpackError(message[1] as List)));
    } else {
      unawaited(_finish(error: StateError('MDD worker failed: $message')));
    }
  }

  Future<void> _handleRpc(List message) async {
    final reply = message[1] as SendPort;
    final id = message[2] as int;
    try {
      final op = message[3] as String;
      Object? answer;
      if (op == 'open') {
        if (_source != null) throw StateError('MDD source already open');
        final index = message[4] as int;
        if (index < 0 || index >= _locations.length) throw RangeError.index(index, _locations);
        final source = await DictMddResources.openLocation(_locations[index]);
        _source = source;
        answer = await source.length;
      } else if (op == 'read') {
        final source = _source ?? (throw StateError('MDD source not open'));
        final offset = message[4] as int;
        final count = message[5] as int;
        final length = await source.length;
        if (offset < 0 || count < 0 || count > SafRandomAccessSource.pageSize || offset > length - count) {
          throw const FormatException('Invalid MDD worker read range');
        }
        final data = await source.readAt(offset, count);
        answer = TransferableTypedData.fromList([data]);
      } else if (op == 'close') {
        final source = _source;
        _source = null;
        await source?.close();
      } else {
        throw StateError('Invalid MDD worker operation');
      }
      if (!_finishing) reply.send([id, true, answer]);
    } catch (error) {
      if (!_finishing) reply.send([id, false, _packError(error)]);
    }
  }

  Future<void> _finish({Uint8List? data, Object? error, bool kill = false}) async {
    if (_finishing) return;
    _finishing = true;
    // Remove a cancelled waiter synchronously so _drain cannot start it
    // while its asynchronous cleanup is still pending.
    if (!_active) _pool._queue.remove(this);
    if (kill || error != null) _isolate?.kill(priority: Isolate.immediate);
    // An in-flight open must finish before cleanup so a late SAF handle cannot
    // escape. Do not kill the owning isolate while native I/O is outstanding.
    await _launchFuture;
    await _operation;
    final source = _source;
    _source = null;
    try {
      await source?.close();
    } catch (closeError) {
      error ??= closeError;
    }
    _port?.close();
    if (error == null) {
      _result.complete(data);
    } else {
      _result.completeError(error);
    }
    _pool._finished(this);
    _finished.complete();
  }
}

List<Object> _packError(Object error) {
  if (error is RandomAccessSourceException) return ['source', error.code, error.message];
  if (error is FormatException) return ['format', error.message];
  return ['other', error.toString()];
}

Object _unpackError(List error) {
  if (error[0] == 'source') return RandomAccessSourceException(error[1] as String, error[2] as String);
  if (error[0] == 'format') return FormatException(error[1] as String);
  return StateError(error[1] as String);
}

/// Worker never touches the filesystem, MethodChannel or user-provided paths.
void _workerMain(List<dynamic> args) async {
  final parent = args[0] as SendPort;
  final key = args[1] as String;
  final count = args[2] as int;
  final client = _RpcClient(parent);
  try {
    final parts = MddParts([
      for (var i = 0; i < count; i++) () => _RemoteSource.open(client, i),
    ]);
    final data = await parts.readResource(key);
    parent.send(['result', data == null ? null : TransferableTypedData.fromList([data])]);
  } catch (error) {
    parent.send(['error', _packError(error)]);
  } finally {
    client.close();
  }
}

class _RpcClient {
  final SendPort parent;
  final ReceivePort _port = ReceivePort();
  final Map<int, Completer<Object?>> _pending = {};
  int _next = 0;
  _RpcClient(this.parent) {
    _port.listen((dynamic message) {
      final response = message as List;
      final completion = _pending.remove(response[0] as int);
      if (completion == null) return;
      if (response[1] == true) {
        completion.complete(response[2]);
      } else {
        completion.completeError(_unpackError(response[2] as List));
      }
    });
  }
  Future<Object?> call(String op, [Object? a, Object? b]) {
    final id = _next++;
    final completion = Completer<Object?>();
    _pending[id] = completion;
    parent.send(['rpc', _port.sendPort, id, op, a, b]);
    return completion.future;
  }
  void close() => _port.close();
}

class _RemoteSource implements RandomAccessSource {
  final _RpcClient client;
  final int _length;
  int _position = 0;
  bool _closed = false;
  _RemoteSource(this.client, this._length);
  static Future<_RemoteSource> open(_RpcClient client, int part) async =>
      _RemoteSource(client, await client.call('open', part) as int);
  @override
  Future<int> get length async => _length;
  @override
  Future<void> seek(int offset) async {
    if (_closed) throw StateError('MDD source closed');
    if (offset < 0 || offset > _length) throw RangeError.range(offset, 0, _length);
    _position = offset;
  }
  @override
  Future<Uint8List> read(int count) async {
    if (_closed) throw StateError('MDD source closed');
    if (count < 0) throw RangeError.value(count);
    final wanted = count < _length - _position ? count : _length - _position;
    if (wanted == 0) return Uint8List(0);
    // Limit each root-isolate I/O RPC so cancellation waits for at most one
    // SAF page, rather than an entire 16 MiB block. The parser assembles the
    // block on the worker and still enforces its existing size limits.
    final output = Uint8List(wanted);
    var written = 0;
    while (written < wanted) {
      final remaining = wanted - written;
      final size = remaining < SafRandomAccessSource.pageSize
          ? remaining : SafRandomAccessSource.pageSize;
      final response = await client.call('read', _position, size) as TransferableTypedData;
      final bytes = response.materialize().asUint8List();
      output.setRange(written, written + bytes.length, bytes);
      written += bytes.length;
      _position += bytes.length;
      if (bytes.length != size) break;
    }
    return written == wanted ? output : Uint8List.sublistView(output, 0, written);
  }
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await client.call('close');
  }
}
