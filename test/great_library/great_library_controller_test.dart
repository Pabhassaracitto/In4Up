// test/great_library/great_library_controller_test.dart
//
// GLIB-004 — controller của Thư Viện Chung: load (thành công / lỗi),
// lọc-tìm qua query, tải pack (progress → completed / failed),
// và downloadedIds phản ánh đúng kết quả verify checksum.

import 'dart:convert';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/great_library_controller.dart';
import 'package:in4up/features/great_library/models/gl_pack_entry.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/gl_catalog_service.dart';
import 'package:in4up/features/great_library/services/pack_content.dart';
import 'package:in4up/features/great_library/services/pack_download_manager.dart';
import 'package:in4up/features/great_library/services/pack_download_store_memory.dart';
import 'package:in4up/features/great_library/services/pack_file.dart';
import 'package:in4up/features/great_library/services/pack_import_service.dart';
import 'package:in4up/features/great_library/services/pack_storage_backend.dart';

final Uint8List kPayload = Uint8List.fromList(List<int>.filled(128, 7));
final String kPayloadSha = sha256.convert(kPayload).toString();

GlPackEntry _entry(
  String id, {
  PackType type = PackType.vocab,
  String title = 'Pack',
  int downloads = 0,
  DateTime? publishedAt,
  bool withStorage = true,
  String? fileSha256,
  int? fileBytes,
}) {
  final published = publishedAt ?? DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
  return GlPackEntry(
    manifest: PackManifest(
      id: id,
      type: type,
      title: title,
      description: 'mô tả $id',
      srcLang: 'en',
      dstLang: 'vi',
      level: 'A2',
      author: const PackAuthor(uid: 'u1', displayName: 'Tester'),
      license: PackLicense.ccBy,
      version: 1,
      storage: withStorage
          ? PackStorageRef(backend: 'firebase', path: 'packs/$id.i4upack')
          : null,
      stats: PackStats(downloads: downloads),
      createdAt: published.subtract(const Duration(seconds: 1000)),
      updatedAt: published,
      tags: const ['test'],
    ),
    fileSha256: fileSha256 ?? kPayloadSha,
    fileBytes: fileBytes ?? kPayload.length,
    publishedAt: published,
  );
}

class _FakeTransport implements GlCatalogTransport {
  _FakeTransport({this.entries = const [], this.error});
  List<GlPackEntry> entries;
  Object? error;
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return [
      for (final entry in entries)
        <String, dynamic>{
          ...entry.manifest.toJson(),
          'fileSha256': entry.fileSha256,
          'fileBytes': entry.fileBytes,
          if (entry.publishedAt != null) 'publishedAt': entry.publishedAt,
        }
    ];
  }
}

class _FakeStorageBackend implements PackStorageBackend {
  _FakeStorageBackend({this.fail = false, this.payload});
  final bool fail;
  final Uint8List? payload;

  @override
  String get backendId => 'firebase';

  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) async {
    if (fail) {
      throw const PackStorageException(
          PackStorageErrorCode.network, 'boom', statusCode: 500);
    }
    return payload ?? kPayload;
  }

  @override
  Future<int> contentLength(PackStorageRef ref) async => kPayload.length;

  @override
  Future<void> upload(PackStorageRef ref, List<int> bytes,
      {void Function(int sentBytes, int totalBytes)? onProgress}) async {}

  @override
  Uri publicUrl(PackStorageRef ref) =>
      Uri.parse('https://example.com/${ref.path}');
}

GreatLibraryController _build({
  List<GlPackEntry> entries = const [],
  Object? transportError,
  bool storageFails = false,
  MemoryPackDownloadStore? store,
}) {
  final s = store ?? MemoryPackDownloadStore();
  return GreatLibraryController(
    catalog: GlCatalogService(
      transport: _FakeTransport(entries: entries, error: transportError),
      cache: GlCatalogMemoryCache(),
    ),
    downloads: PackDownloadManager(
      backend: _FakeStorageBackend(fail: storageFails),
      store: s,
      sleeper: (_) async {},
    ),
  );
}

void main() {
  test('load: thành công → entries hiển thị, không lỗi', () async {
    final c = _build(entries: [_entry('p1'), _entry('p2')]);
    await c.load();
    expect(c.visibleEntries.length, 2);
    expect(c.errorMessage, isNull);
    expect(c.isLoading, isFalse);
  });

  test('load: thất bại không có cache → errorMessage, danh sách rỗng',
      () async {
    final c = _build(transportError: const GlCatalogException('network down'));
    await c.load();
    expect(c.visibleEntries, isEmpty);
    expect(c.errorMessage, isNotNull);
  });

  test('query: lọc theo loại + tìm theo tiêu đề', () async {
    final c = _build(entries: [
      _entry('a', type: PackType.vocab, title: 'NGSL 1200'),
      _entry('b', type: PackType.audio, title: 'Dhamma Talk'),
    ]);
    await c.load();
    c.setQuery(const GlCatalogQuery(type: PackType.audio));
    expect(c.visibleEntries.single.packId, 'b');
    c.setQuery(const GlCatalogQuery(text: 'ngsl'));
    expect(c.visibleEntries.single.packId, 'a');
  });

  test('query: sắp xếp theo lượt tải', () async {
    final c = _build(entries: [
      _entry('few', downloads: 3),
      _entry('many', downloads: 900),
    ]);
    await c.load();
    c.setQuery(const GlCatalogQuery(sort: GlPackSort.mostDownloaded));
    expect(c.visibleEntries.first.packId, 'many');
  });

  test('download: thành công → completed + packId trong downloadedIds',
      () async {
    final c = _build(entries: [_entry('p1')]);
    await c.load();
    final result = await c.download(c.visibleEntries.single);
    expect(result.isSuccess, isTrue);
    expect(c.downloadStates['p1']?.state, PackDownloadState.completed);
    expect(c.downloadedIds.contains('p1'), isTrue);
  });

  test('download: thất bại → state failed, không đánh dấu đã tải', () async {
    final c = _build(entries: [_entry('p1')], storageFails: true);
    await c.load();
    final result = await c.download(c.visibleEntries.single);
    expect(result.state, PackDownloadState.failed);
    expect(c.downloadStates['p1']?.state, PackDownloadState.failed);
    expect(c.downloadedIds.contains('p1'), isFalse);
  });

  test('download: checksum sai → retry rồi failed', () async {
    final bad = _entry('p1', fileSha256: '0' * 64);
    final c = _build(entries: [bad]);
    await c.load();
    final result = await c.download(c.visibleEntries.single);
    expect(result.state, PackDownloadState.failed);
    expect(c.downloadedIds.contains('p1'), isFalse);
  });

  test('download: pack thiếu storage ref → failed ngay, không gọi mạng',
      () async {
    final c = _build();
    await c.load();
    final noStorage = _entry('x', withStorage: false);
    final result = await c.download(noStorage);
    expect(result.state, PackDownloadState.failed);
    expect(result.errorCode, PackStorageErrorCode.invalidRef);
    expect(c.downloadStates['x']?.state, PackDownloadState.failed);
  });

  test('store giữ bytes sau khi tải (để GLIB-005 import)', () async {
    final store = MemoryPackDownloadStore();
    final c = _build(entries: [_entry('p1')], store: store);
    await c.load();
    await c.download(c.visibleEntries.single);
    expect(await store.readFinal('p1'), kPayload);
  });

  // ─────────────────────── GLIB-005: import vào Studio ──────────────────────

  test('importDownloaded: pack đã tải → imported + isInstalled', () async {
    final store = MemoryPackDownloadStore();
    final installed = MemoryInstalledPackStore();
    final vocabSink = _RecordingVocabSink();
    final entry = _entry('p1',
        fileSha256: kImportPack.fileSha256, fileBytes: kImportPack.bytes.length);
    final c = GreatLibraryController(
      catalog: GlCatalogService(
        transport: _FakeTransport(entries: [entry]),
        cache: GlCatalogMemoryCache(),
      ),
      downloads: PackDownloadManager(
        backend: _FakeStorageBackend(payload: kImportPack.bytes),
        store: store,
        sleeper: (_) async {},
      ),
      downloadStore: store,
      importService: PackImportService(
        vocabSink: vocabSink,
        audioSink: _NoopAudioSink(),
        imageSink: _NoopImageSink(),
        installedStore: installed,
      ),
      installedStore: installed,
    );
    await c.load();
    expect(c.isInstalled('p1'), isFalse);
    await c.download(c.visibleEntries.single);
    final result = await c.importDownloaded('p1');
    expect(result?.status, PackImportStatus.imported);
    expect(result?.added, 2);
    expect(c.isInstalled('p1'), isTrue);
    expect(vocabSink.totalAdded, 2);

    // Cùng version → alreadyInstalled, sink không bị gọi thêm.
    final again = await c.importDownloaded('p1');
    expect(again?.status, PackImportStatus.alreadyInstalled);
    expect(vocabSink.totalAdded, 2);
  });

  test('hasUpdate: catalog version mới hơn bản đã cài', () async {
    final installed = MemoryInstalledPackStore({'p1': 2});
    final base = _entry('p1');
    final newer = GlPackEntry(
      manifest: base.manifest.copyWith(version: 3),
      fileSha256: base.fileSha256,
      fileBytes: base.fileBytes,
      publishedAt: base.publishedAt,
    );
    final c = GreatLibraryController(
      catalog: GlCatalogService(
        transport: _FakeTransport(entries: [base, newer]),
        cache: GlCatalogMemoryCache(),
      ),
      downloads: PackDownloadManager(
        backend: _FakeStorageBackend(),
        store: MemoryPackDownloadStore(),
        sleeper: (_) async {},
      ),
      installedStore: installed,
    );
    await c.load();
    // Cùng id 'p1': entry v1 (≤ installed 2) → không update; entry v3 → update.
    expect(c.hasUpdate(base), isFalse);
    expect(c.hasUpdate(newer), isTrue);
    expect(c.isInstalled('p1'), isTrue);
    expect(c.isInstalled('chua-cai'), isFalse);
  });
}

// ─────────────────────── GLIB-005 helpers (top-level) ───────────────────────

/// Pack zip THẬT (2 mục vocab) để controller giải nén khi import.
final PackBuildResult kImportPack = PackFile.build(
  manifest: PackManifest(
    id: 'p1',
    type: PackType.vocab,
    title: 'Pack p1',
    srcLang: 'en',
    dstLang: 'vi',
    author: const PackAuthor(uid: 'u1', displayName: 'Tester'),
    license: PackLicense.ccBy,
  ),
  dataFiles: {
    'entries.json': utf8.encode(jsonEncode([
      {'word': 'apple', 'meaning': 'quả táo'},
      {'word': 'run', 'meaning': 'chạy'},
    ])),
  },
);

class _RecordingVocabSink implements PackVocabSink {
  int totalAdded = 0;
  @override
  Future<PackSinkResult> importVocab(VocabPackPlan plan, PackMediaLookup media,
      {required bool isUpdate}) async {
    totalAdded += plan.items.length;
    return PackSinkResult(added: plan.items.length);
  }
}

class _NoopAudioSink implements PackAudioSink {
  @override
  Future<PackSinkResult> importAudio(AudioPackPlan plan, PackMediaLookup media,
          Map<String, Uint8List> dataFiles,
          {required bool isUpdate}) async =>
      const PackSinkResult();
}

class _NoopImageSink implements PackImageSink {
  @override
  Future<PackSinkResult> importImages(ImagePackPlan plan, PackMediaLookup media,
          {required bool isUpdate}) async =>
      const PackSinkResult();
}
