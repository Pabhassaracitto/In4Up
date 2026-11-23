// test/great_library/great_library_screen_test.dart
//
// GLIB-004 — widget test màn Thư Viện Chung với controller giả:
// hiển thị danh sách, tìm kiếm, empty state, lỗi + retry, điều hướng detail.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:in4up/l10n/app_localizations.dart';
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
import 'package:in4up/features/great_library/ui/great_library_screen.dart';

/// Pack thật (zip) để luồng import giải nén được — build 1 lần cho cả file test.
final PackBuildResult kRealPack = PackFile.build(
  manifest: PackManifest(
    id: 'p1',
    type: PackType.vocab,
    title: 'NGSL 1200',
    srcLang: 'en',
    dstLang: 'vi',
    level: 'A2',
    author: const PackAuthor(uid: 'u1', displayName: 'Tester'),
    license: PackLicense.ccBy,
    storage: const PackStorageRef(backend: 'firebase', path: 'packs/p1.i4upack'),
  ),
  dataFiles: {
    'entries.json': utf8.encode(jsonEncode([
      {'word': 'apple', 'meaning': 'quả táo'},
      {'word': 'run', 'meaning': 'chạy'},
    ])),
  },
);

final Uint8List kPayload = kRealPack.bytes;
final String kPayloadSha = kRealPack.fileSha256;

class _CountingVocabSink implements PackVocabSink {
  @override
  Future<PackSinkResult> importVocab(VocabPackPlan plan, PackMediaLookup media,
          {required bool isUpdate}) async =>
      PackSinkResult(added: plan.items.length);
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

GlPackEntry _entry(String id,
    {PackType type = PackType.vocab, String title = 'Pack'}) {
  final published = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
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
      storage: PackStorageRef(backend: 'firebase', path: 'packs/$id.i4upack'),
      createdAt: published,
      updatedAt: published,
    ),
    fileSha256: kPayloadSha,
    fileBytes: kPayload.length,
    publishedAt: published,
  );
}

class _FakeTransport implements GlCatalogTransport {
  _FakeTransport({this.entries = const [], this.error});
  final List<GlPackEntry> entries;
  final Object? error;

  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() async {
    final e = error;
    if (e != null) throw e;
    return [
      for (final entry in entries)
        <String, dynamic>{
          ...entry.manifest.toJson(),
          'fileSha256': entry.fileSha256,
          'fileBytes': entry.fileBytes,
          'publishedAt': entry.publishedAt,
        }
    ];
  }
}

class _FakeStorageBackend implements PackStorageBackend {
  @override
  String get backendId => 'firebase';
  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) async =>
      kPayload;
  @override
  Future<int> contentLength(PackStorageRef ref) async => kPayload.length;
  @override
  Future<void> upload(PackStorageRef ref, List<int> bytes,
      {void Function(int, int)? onProgress}) async {}
  @override
  Uri publicUrl(PackStorageRef ref) =>
      Uri.parse('https://example.com/${ref.path}');
}

GreatLibraryController _controller(
    {List<GlPackEntry> entries = const [],
    Object? error,
    bool withImport = false}) {
  final store = MemoryPackDownloadStore();
  final installed = MemoryInstalledPackStore();
  return GreatLibraryController(
    catalog: GlCatalogService(
      transport: _FakeTransport(entries: entries, error: error),
      cache: GlCatalogMemoryCache(),
    ),
    downloads: PackDownloadManager(
      backend: _FakeStorageBackend(),
      store: store,
      sleeper: (_) async {},
    ),
    downloadStore: store,
    importService: withImport
        ? PackImportService(
            vocabSink: _CountingVocabSink(),
            audioSink: _NoopAudioSink(),
            imageSink: _NoopImageSink(),
            installedStore: installed,
          )
        : null,
    installedStore: installed,
  );
}

Widget _app(GreatLibraryController controller) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: GreatLibraryScreen(controller: controller),
  );
}

void main() {
  testWidgets('hiển thị danh sách pack sau khi load', (tester) async {
    final c = _controller(entries: [
      _entry('p1', title: 'NGSL 1200'),
      _entry('p2', type: PackType.audio, title: 'Dhamma Talk'),
    ]);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    expect(find.text('NGSL 1200'), findsOneWidget);
    expect(find.text('Dhamma Talk'), findsOneWidget);
    expect(find.text('Thư Viện Chung'), findsOneWidget);
  });

  testWidgets('tìm kiếm theo tiêu đề lọc danh sách', (tester) async {
    final c = _controller(entries: [
      _entry('p1', title: 'NGSL 1200'),
      _entry('p2', title: 'Dhamma Talk'),
    ]);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ngsl');
    await tester.pumpAndSettle();
    expect(find.text('NGSL 1200'), findsOneWidget);
    expect(find.text('Dhamma Talk'), findsNothing);
  });

  testWidgets('empty state khi không có pack', (tester) async {
    final c = _controller();
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có pack nào'), findsOneWidget);
  });

  testWidgets('lỗi mạng → thông báo + nút Thử lại', (tester) async {
    final c = _controller(error: const GlCatalogException('offline'));
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Không tải được thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được thư viện'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('chạm pack → mở màn chi tiết, hiển thị metadata + nút Tải về',
      (tester) async {
    final c = _controller(entries: [_entry('p1', title: 'NGSL 1200')]);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGSL 1200'));
    await tester.pumpAndSettle();
    expect(find.text('Tải về'), findsOneWidget);
    expect(find.text('Giấy phép: cc-by'), findsOneWidget);
  });

  testWidgets('bấm Tải về → hoàn tất → trạng thái Đã tải về máy',
      (tester) async {
    final c = _controller(entries: [_entry('p1', title: 'NGSL 1200')]);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGSL 1200'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải về'));
    await tester.pumpAndSettle();
    expect(find.text('Đã tải về máy'), findsOneWidget);
  });

  testWidgets('GLIB-005: sau tải → Nhập vào Studio → Đã nhập 2 mục',
      (tester) async {
    final c = _controller(
        entries: [_entry('p1', title: 'NGSL 1200')], withImport: true);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGSL 1200'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải về'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập vào Studio'), findsOneWidget);
    await tester.tap(find.text('Nhập vào Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Đã nhập 2 mục'), findsOneWidget);
    expect(c.isInstalled('p1'), isTrue);
  });

  testWidgets('GLIB-004b: sau tải → hiện Xem trước nội dung + thẻ từ',
      (tester) async {
    final c = _controller(
        entries: [_entry('p1', title: 'NGSL 1200')], withImport: true);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGSL 1200'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải về'));
    await tester.pumpAndSettle();
    expect(find.text('Xem trước nội dung'), findsOneWidget);
    // Thẻ từ đầu tiên trong data/entries.json của pack thật.
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('quả táo'), findsOneWidget);
  });
}
