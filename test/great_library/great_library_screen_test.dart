// test/great_library/great_library_screen_test.dart
//
// GLIB-004 — widget test màn Thư Viện Chung với controller giả:
// hiển thị danh sách, tìm kiếm, empty state, lỗi + retry, điều hướng detail.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/great_library_controller.dart';
import 'package:in4up/features/great_library/models/gl_pack_entry.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/gl_catalog_service.dart';
import 'package:in4up/features/great_library/services/pack_download_manager.dart';
import 'package:in4up/features/great_library/services/pack_download_store_memory.dart';
import 'package:in4up/features/great_library/services/pack_storage_backend.dart';
import 'package:in4up/features/great_library/ui/great_library_screen.dart';

final Uint8List kPayload = Uint8List.fromList(List<int>.filled(64, 3));
final String kPayloadSha = sha256.convert(kPayload).toString();

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
    {List<GlPackEntry> entries = const [], Object? error}) {
  final store = MemoryPackDownloadStore();
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
}
