// TẠM THỜI — tách lỗi CI analyze (xóa sau khi xanh).
// Chứa TẤT CẢ construct mới từ hymt_engine (2026-09-03) trong bối cảnh
// độc lập (không isolate thật — chỉ để analyzer check types).

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoadResultRepro {
  final bool ready;
  final String? error;
  _LoadResultRepro({required this.ready, this.error});
}

class ReproConstructs {
  static const minBytes = 80 * 1024 * 1024;
  static const expectedBytes = 601 * 1024 * 1024;
  static const int minPlausibleBytes = 481 * 1024 * 1024;

  static bool isGgufMagic(List<int> head) {
    return head.length >= 4 &&
        head[0] == 0x47 &&
        head[1] == 0x47 &&
        head[2] == 0x55 &&
        head[3] == 0x46;
  }

  static bool looksLikeGguf(List<int> head, int size) {
    if (size < minPlausibleBytes) return false;
    return isGgufMagic(head);
  }

  static bool headIsGguf(String path) {
    try {
      final rand = File(path).openSync();
      try {
        return isGgufMagic(rand.readBytesSync(4, position: 0));
      } finally {
        rand.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  Future<String?> resolvedModelPathLike() async {
    final saved = 'some-path';
    if (saved != null && await File(saved).exists()) {
      final n = File(saved).lengthSync();
      if (n >= minPlausibleBytes && headIsGguf(saved)) return saved;
    }
    final def = '/tmp/default.gguf';
    if (await File(def).exists() &&
        File(def).lengthSync() >= minPlausibleBytes &&
        headIsGguf(def)) {
      return def;
    }
    return null;
  }

  Future<String?> modelIssueLike() async {
    if (await resolvedModelPathLike() != null) return null;
    try {
      final saved = 'some-path';
      final def = '/tmp/default.gguf';
      final candidates = <String?>[saved, def];
      for (final path in candidates) {
        if (path == null) continue;
        final f = File(path);
        if (await f.exists()) {
          final mb = (f.lengthSync() / 1048576).toStringAsFixed(0);
          return 'File bị cắt/hỏng (${mb}MB/~601MB) — tải lại.';
        }
      }
    } catch (_) {}
    return 'Chưa có model.';
  }

  String? lastLoadError;

  /// Mô phỏng handshake 2-stage (SendPort + _LoadResult) bằng message
  // trên ReceivePort — cùng pattern ensureLoaded mới.
  Future<bool> ensureLoadedLike() async {
    final receivePort = ReceivePort();
    final ready = Completer<SendPort>();
    final loadDone = Completer<bool>();
    lastLoadError = null;
    receivePort.listen((msg) {
      if (msg is SendPort && !ready.isCompleted) ready.complete(msg);
      if (msg is _LoadResultRepro && !loadDone.isCompleted) {
        if (!msg.ready) lastLoadError = msg.error;
        loadDone.complete(msg.ready);
      }
    });
    // Mô phỏng isolate gửi handshake rồi gửi kết quả create() fail.
    final simPort = ReceivePort();
    simPort.listen((msg) {});
    unawaited(
      Future<void>.microtask(() {
        simPort.sendPort.send(SendPort(() {}));
      }),
    );
    try {
      final handshake = await receivePort
          .first
          .timeout(const Duration(seconds: 5));
      if (handshake is SendPort) {
        ready.complete(handshake);
      }
      // Giả lập kết quả create() fail (bên isolate thật sẽ gửi _LoadResult).
      final okMsg = await loadDone.future.timeout(const Duration(seconds: 2));
      if (!okMsg) {
        debugPrint('Repro create failed: ${lastLoadError}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Repro load failed: $e');
      return false;
    } finally {
      receivePort.close();
      simPort.close();
    }
  }

  String translateErrorLike() {
    final loadErr =
        lastLoadError ?? 'thiếu RAM hoặc llama.cpp không hỗ trợ.';
    return 'Không nạp được: $loadErr. Thử tải lại.';
  }
}

ffi.Pointer<ffi.Void>? _handleRepro;
String? _loadErrorRepro;

void _isolateEntryRepro(Object? init) {
  final port = ReceivePort();
  _handleRepro = null;
  _loadErrorRepro = 'simulated create failure';
  // (bên isolate thật) gửi _LoadResult SAU khi create() xong
  port.sendPort.send(
    _LoadResultRepro(ready: _handleRepro != null, error: _loadErrorRepro),
  );
}

void main() {
  test('constructs compile (tạm — xóa sau)', () async {
    expect(
      ReproConstructs.looksLikeGguf([0x47, 0x47, 0x55, 0x46], 500 * 1024 * 1024),
      isTrue,
    );
    expect(
      ReproConstructs.looksLikeGguf([0x47, 0x47, 0x55, 0x46], 100 * 1024 * 1024),
      isFalse,
    );
    final r = ReproConstructs();
    expect(r.translateErrorLike(), isNotEmpty);
    final ok = await r.ensureLoadedLike();
    expect(ok, isFalse); // create fail simulated → false
  });
}
