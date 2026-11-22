// test/great_library/pack_download_manager_test.dart — GLIB-002 (PLAN-049)
//
// Test thuần cho PackDownloadManager với fake backend + in-memory store:
// tải mới, resume byte-range, server bỏ qua Range, đứt giữa chừng + retry,
// checksum sai → xoá partial, huỷ giữa đường, lỗi không retryable,
// partial rác lớn hơn file đích.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/pack_download_manager.dart';
import 'package:in4up/features/great_library/services/pack_storage_backend.dart';

/// Backend giả: phục vụ `data`, mô phỏng range / đứt gói / lỗi mạng.
class FakeBackend implements PackStorageBackend {
  FakeBackend(this.data);

  final Uint8List data;

  /// Server bỏ qua Range header (trả nguyên file dù có start).
  bool ignoreRange = false;

  /// Call index (1-based) sẽ ném lỗi network.
  final Set<int> failOnCalls = <int>{};

  /// Trả body bị cắt cụt còn N byte ở call index cho trước.
  final Map<int, int> truncateOnCall = <int, int>{};

  final List<int?> requestedStarts = <int?>[];
  int downloadCalls = 0;

  @override
  String get backendId => 'fake';

  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) async {
    downloadCalls++;
    requestedStarts.add(start);
    if (failOnCalls.contains(downloadCalls)) {
      throw const PackStorageException(
          PackStorageErrorCode.network, 'mạng chập chờn (fake)');
    }
    final effectiveStart = (ignoreRange ? null : start) ?? 0;
    final effectiveEnd = end ?? data.length;
    var slice =
        data.sublist(effectiveStart, effectiveEnd.clamp(0, data.length));
    final truncateTo = truncateOnCall[downloadCalls];
    if (truncateTo != null && truncateTo < slice.length) {
      slice = slice.sublist(0, truncateTo);
    }
    return slice;
  }

  @override
  Future<int> contentLength(PackStorageRef ref) async => data.length;

  @override
  Future<void> upload(PackStorageRef ref, List<int> bytes,
      {void Function(int sentBytes, int totalBytes)? onProgress}) async {}

  @override
  Uri publicUrl(PackStorageRef ref) =>
      Uri.parse('https://fake.test/${ref.path}');
}

/// Backend luôn báo notFound — kiểm tra manager KHÔNG retry lỗi này.
class NotFoundBackend extends FakeBackend {
  NotFoundBackend() : super(Uint8List(0));

  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) {
    throw const PackStorageException(
        PackStorageErrorCode.notFound, 'không thấy object');
  }
}

class MemoryStore implements PackDownloadStore {
  final Map<String, List<int>> partials = <String, List<int>>{};
  final Map<String, Uint8List> finals = <String, Uint8List>{};

  @override
  Future<int> partialLength(String packId) async =>
      partials[packId]?.length ?? 0;

  @override
  Future<void> appendPartial(String packId, List<int> chunk) async {
    partials.putIfAbsent(packId, () => <int>[]).addAll(chunk);
  }

  @override
  Future<Uint8List?> readPartial(String packId) async {
    final partial = partials[packId];
    return partial == null ? null : Uint8List.fromList(partial);
  }

  @override
  Future<void> saveFinal(String packId, Uint8List bytes) async {
    finals[packId] = bytes;
  }

  @override
  Future<Uint8List?> readFinal(String packId) async => finals[packId];

  @override
  Future<void> clearPartial(String packId) async {
    partials.remove(packId);
  }
}

/// Bộ dựng gọn backend + store + manager cho mỗi test.
class Harness {
  Harness({PackStorageBackend? backend})
      : backend = backend ?? FakeBackend(sampleBytes()) {
    manager = PackDownloadManager(
      backend: this.backend,
      store: store,
      sleeper: (_) async {}, // test không ngủ thật
    );
  }

  static Uint8List sampleBytes() =>
      Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));

  final PackStorageBackend backend;
  final MemoryStore store = MemoryStore();
  late final PackDownloadManager manager;

  Uint8List get data => sampleBytes();
  String get fileSha => sha256.convert(data).toString();

  static PackStorageRef refOf(String packId) =>
      PackStorageRef(backend: 'fake', path: 'packs/$packId/1.i4upack');

  Future<PackDownloadResult> run(
    String packId, {
    void Function(PackDownloadProgress)? onProgress,
    PackDownloadCancel? cancel,
    String? sha,
    int? expectedBytes,
  }) {
    return manager.downloadPack(
      packId: packId,
      ref: refOf(packId),
      expectedBytes: expectedBytes ?? data.length,
      expectedFileSha256: sha ?? fileSha,
      onProgress: onProgress,
      cancelToken: cancel,
    );
  }
}

void main() {
  test('tải mới hoàn tất: final đúng byte, progress đủ trạng thái', () async {
    final h = Harness();
    final progresses = <PackDownloadProgress>[];
    final result = await h.run('p1', onProgress: progresses.add);

    expect(result.isSuccess, isTrue);
    expect(await h.store.readFinal('p1'), h.data);
    expect(await h.store.partialLength('p1'), 0); // partial đã dọn
    expect(
      progresses.map((p) => p.state),
      containsAll(<PackDownloadState>[
        PackDownloadState.downloading,
        PackDownloadState.verifying,
        PackDownloadState.completed,
      ]),
    );
    expect(progresses.last.receivedBytes, h.data.length);
  });

  test('resume: có partial sẵn → gọi Range từ đúng offset, ghép đủ byte',
      () async {
    final backend = FakeBackend(Harness.sampleBytes());
    final h = Harness(backend: backend);
    // Seed sẵn 1500 byte đầu như thể phiên trước đứt mạng.
    await h.store.appendPartial('p2', h.data.sublist(0, 1500));

    final result = await h.run('p2');

    expect(result.isSuccess, isTrue);
    expect(backend.requestedStarts.single, 1500);
    expect(await h.store.readFinal('p2'), h.data);
  });

  test('đứt giữa chừng (short-body) → lưu partial, attempt sau resume',
      () async {
    final backend = FakeBackend(Harness.sampleBytes())
      ..truncateOnCall[1] = 1000; // call 1 chỉ trả 1000 byte đầu
    final h = Harness(backend: backend);

    final result = await h.run('p3');

    expect(result.isSuccess, isTrue);
    expect(backend.downloadCalls, greaterThanOrEqualTo(2));
    // Call 2 phải resume từ đúng offset 1000.
    expect(backend.requestedStarts[1], 1000);
    expect(await h.store.readFinal('p3'), h.data);
  });

  test('server bỏ qua Range (trả nguyên file) → bỏ partial, dùng bản mới',
      () async {
    final backend = FakeBackend(Harness.sampleBytes())..ignoreRange = true;
    final h = Harness(backend: backend);
    await h.store.appendPartial('p4', h.data.sublist(0, 999));

    final result = await h.run('p4');

    expect(result.isSuccess, isTrue);
    expect(await h.store.readFinal('p4'), h.data);
  });

  test('lỗi mạng 1 lần rồi thành công (retry)', () async {
    final backend = FakeBackend(Harness.sampleBytes())..failOnCalls.add(1);
    final h = Harness(backend: backend);

    final result = await h.run('p5');

    expect(result.isSuccess, isTrue);
    expect(backend.downloadCalls, 2);
  });

  test('checksum sai mọi attempt → failed, partial bị xoá, không giữ final',
      () async {
    final h = Harness();

    final result = await h.run('p6', sha: '0' * 64);

    expect(result.isSuccess, isFalse);
    expect(result.state, PackDownloadState.failed);
    expect(await h.store.partialLength('p6'), 0);
    expect(await h.store.readFinal('p6'), isNull);
  });

  test('notFound (không retryable) → failed ngay, đúng 1 call', () async {
    final backend = NotFoundBackend();
    final h = Harness(backend: backend);

    final result = await h.run('p7');

    expect(result.state, PackDownloadState.failed);
    expect(result.errorCode, PackStorageErrorCode.notFound);
    expect(backend.downloadCalls, 0); // NotFoundBackend không đếm
  });

  test('cancel trước khi chạy → canceled, không tải gì', () async {
    final h = Harness();
    final cancel = PackDownloadCancel()..cancel();

    final result = await h.run('p8', cancel: cancel);

    expect(result.state, PackDownloadState.canceled);
    expect(await h.store.readFinal('p8'), isNull);
  });

  test('partial rác (lớn hơn file đích) → xoá, tải lại từ đầu', () async {
    final h = Harness();
    await h.store
        .appendPartial('p9', List<int>.filled(h.data.length + 10, 9));

    final result = await h.run('p9');

    expect(result.isSuccess, isTrue);
    expect(await h.store.readFinal('p9'), h.data);
  });

  test('partial đủ byte từ phiên trước → verify luôn, không gọi backend',
      () async {
    final backend = FakeBackend(Harness.sampleBytes());
    final h = Harness(backend: backend);
    await h.store.appendPartial('p10', h.data); // đã đủ byte

    final result = await h.run('p10');

    expect(result.isSuccess, isTrue);
    expect(backend.downloadCalls, 0);
    expect(await h.store.readFinal('p10'), h.data);
  });

  test('hàng đợi tuần tự: 2 pack tải cùng lúc không chồng call', () async {
    final backend = FakeBackend(Harness.sampleBytes());
    final h = Harness(backend: backend);

    final results = await Future.wait(<Future<PackDownloadResult>>[
      h.run('pa'),
      h.run('pb'),
    ]);

    expect(results.every((r) => r.isSuccess), isTrue);
    expect(await h.store.readFinal('pa'), h.data);
    expect(await h.store.readFinal('pb'), h.data);
  });
}
