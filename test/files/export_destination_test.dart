// test/files/export_destination_test.dart — BETA-1.29.0 · lane L7 · PSRC-204
//
// Máy bắt tự động cho **một nơi lưu mặc định + nút "Đổi…" từng lần xuất**
// theo ADR-0029 (`docs/adr/0029-noi-luu-tep-mac-dinh-va-doi-tung-lan.md`).
//
// Khoá 6 nhóm bất biến:
//   1. Mặc định gốc đúng tên `In4Up` trên cả 4 nền tảng (Android API ≥ 29 dùng
//      MediaStore `Download/In4Up`, API ≤ 28 dùng Downloads công khai, iOS
//      `On My iPhone/In4Up`, Desktop `<Downloads>/In4Up` lùi về `~/In4Up`).
//   2. "Đổi…" mặc định CHỈ áp dụng cho lần xuất hiện tại; phiên xuất kế tiếp
//      tự quay về mặc định. Chỉ khi đánh dấu "Luôn lưu vào thư mục này" mới
//      ghi nhớ làm mặc định mới.
//   3. Thư mục đã ghi nhớ bị xoá / mất quyền SAF ⇒ tự quay về mặc định gốc và
//      chỉ báo MỘT lần duy nhất, không crash.
//   4. Ghi nguyên tử (`.part` → `flush` → `rename`), không để rác `.part`;
//      trùng tên ⇒ thêm ` (2)`, ` (3)`… không bao giờ ghi đè tệp cũ.
//   5. Phiên Cabin giữ nội bộ (`cabin_sessions`), chỉ chép ra đích công khai
//      khi xuất tường minh; Android không xin `MANAGE_EXTERNAL_STORAGE`.
//   6. Mọi chuỗi UI mới đều đi qua `localized_material.dart` và có đủ 8 locale.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/files/export_destination.dart';
import 'package:in4up/core/files/export_destination_service.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/widgets/cabin_save_sheet.dart';

String _read(String path) => File(path).readAsStringSync();

String _codeOnly(String src) => src
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const List<String> _psrc204UiStrings = <String>[
  'Lưu vào: {value0}',
  'Đổi…',
  'Thư mục đã lưu không còn truy cập được — đã quay về mặc định ({value0}).',
  'Luôn lưu vào thư mục này',
  'Chỉ áp dụng cho lần xuất này — lần sau tự quay về mặc định.',
  'Về mặc định gốc',
  'Mở thư mục',
  'Đã lưu tại: {value0}',
  'Xuất tệp',
  'Xuất phiên Cabin',
  'Bản ghi âm (.wav)',
  'Phụ đề khớp giờ (.lrc)',
  'Văn bản / bản dịch (.txt)',
];

const List<String> _requiredLocales = <String>[
  'en',
  'hi',
  'zh',
  'zh_TW',
  'si',
  'my',
  'th',
  'ja',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ADR-0029 — đích lưu mặc định theo từng nền tảng', () {
    test('Android 10+ (API ≥ 29) dùng MediaStore Download/In4Up', () {
      final dest = ExportDestinationPolicy.buildAndroidDefault(sdkInt: 34);
      expect(dest.kind, ExportDestinationKind.androidMediaStoreDownloads);
      expect(dest.location, 'Download/In4Up');
      expect(dest.displayPath, 'Download/In4Up');
      expect(dest.isBuiltInDefault, isTrue);
    });

    test('Android ≤ 9 (API ≤ 28) lùi về thư mục Downloads/In4Up', () {
      final dest = ExportDestinationPolicy.buildAndroidDefault(
        sdkInt: 28,
        legacyDownloadsRoot: '/storage/emulated/0/Download',
      );
      expect(dest.kind, ExportDestinationKind.androidLegacyDownloads);
      expect(dest.location, '/storage/emulated/0/Download/In4Up');
      expect(dest.displayPath, 'Download/In4Up');
      expect(dest.isBuiltInDefault, isTrue);
    });

    test('iOS dùng Documents/In4Up (hiện On My iPhone/In4Up trong Files)', () {
      final dest = ExportDestinationPolicy.buildIosDefault(
        appDocumentsPath: '/var/mobile/Containers/Data/Application/X/Documents',
      );
      expect(dest.kind, ExportDestinationKind.iosDocumentsFolder);
      expect(
        dest.location,
        '/var/mobile/Containers/Data/Application/X/Documents/In4Up',
      );
      expect(dest.displayPath, 'On My iPhone/In4Up');
      expect(dest.isBuiltInDefault, isTrue);
    });

    test('Desktop ưu tiên <Downloads>/In4Up và lùi về ~/In4Up khi thiếu Downloads', () {
      final linuxWithDownloads = ExportDestinationPolicy.buildDesktopDefault(
        downloadsPath: '/home/alice/Downloads',
        homePath: '/home/alice',
        fallbackAppDocumentsPath: '/home/alice/.local/share/in4up',
      );
      expect(linuxWithDownloads.kind, ExportDestinationKind.directoryPath);
      expect(linuxWithDownloads.location, '/home/alice/Downloads/In4Up');
      expect(linuxWithDownloads.displayPath, '~/Downloads/In4Up');

      final linuxFallbackHome = ExportDestinationPolicy.buildDesktopDefault(
        downloadsPath: null,
        homePath: '/home/alice',
        fallbackAppDocumentsPath: '/home/alice/.local/share/in4up',
      );
      expect(linuxFallbackHome.location, '/home/alice/In4Up');
      expect(linuxFallbackHome.displayPath, '~/In4Up');

      final windowsDefault = ExportDestinationPolicy.buildDesktopDefault(
        downloadsPath: r'C:\Users\Alice\Downloads',
        homePath: r'C:\Users\Alice',
        fallbackAppDocumentsPath: r'C:\Users\Alice\Documents',
        isWindows: true,
      );
      expect(windowsDefault.location, r'C:\Users\Alice\Downloads\In4Up');
    });

    test('nhãn SAF tree URI đọc được bằng mắt thường', () {
      expect(
        ExportDestinationPolicy.formatSafTreeLabel(
          'content://com.android.externalstorage.documents/tree/primary%3ADownload%2FBaiHoc',
        ),
        'Download/BaiHoc',
      );
      expect(
        ExportDestinationPolicy.formatSafTreeLabel(
          'content://com.android.externalstorage.documents/tree/3033-3963%3AAudio%2FIn4Up',
        ),
        '3033-3963/Audio/In4Up',
      );
    });
  });

  group('PSRC-204 — logic chọn đích: "Đổi…" từng lần vs "Luôn lưu"', () {
    late InMemoryExportDestinationStore store;
    late Set<String> accessibleLocations;
    late ExportDestinationPolicy policy;

    const builtIn = ExportDestination(
      kind: ExportDestinationKind.androidMediaStoreDownloads,
      location: 'Download/In4Up',
      displayPath: 'Download/In4Up',
      isBuiltInDefault: true,
    );

    const safFolderA = ExportDestination(
      kind: ExportDestinationKind.androidSafTree,
      location:
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2FA',
      displayPath: 'Music/A',
    );

    const safFolderB = ExportDestination(
      kind: ExportDestinationKind.androidSafTree,
      location:
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2FB',
      displayPath: 'Music/B',
    );

    setUp(() {
      store = InMemoryExportDestinationStore();
      accessibleLocations = <String>{
        safFolderA.location,
        safFolderB.location,
      };
      policy = ExportDestinationPolicy(
        store: store,
        builtInDefaultProvider: () async => builtIn,
        isDestinationAccessible: (dest) async =>
            dest.isBuiltInDefault || accessibleLocations.contains(dest.location),
      );
    });

    test('"Đổi…" KHÔNG tick ghi nhớ ⇒ chỉ đổi lần xuất đó, lần sau về mặc định', () async {
      final session1 = await policy.openSession();
      expect(session1.effectiveDestination, builtIn);
      expect(session1.hasOverride, isFalse);

      session1.selectOverride(safFolderA);
      expect(session1.hasOverride, isTrue);
      expect(session1.rememberAsDefault, isFalse);
      expect(session1.effectiveDestination.location, safFolderA.location);

      final committed1 = await policy.commitSession(session1);
      expect(committed1.location, safFolderA.location);

      // Mở hộp thoại xuất lần kế tiếp: PHẢI tự quay lại Download/In4Up.
      final session2 = await policy.openSession();
      expect(session2.hasOverride, isFalse);
      expect(session2.effectiveDestination, builtIn);
    });

    test('"Đổi…" CÓ tick "Luôn lưu vào thư mục này" ⇒ lưu làm mặc định mới', () async {
      final session1 = await policy.openSession();
      session1.selectOverride(safFolderB);
      session1.rememberAsDefault = true;

      final committed = await policy.commitSession(session1);
      expect(committed.location, safFolderB.location);

      final session2 = await policy.openSession();
      expect(session2.hasOverride, isFalse);
      expect(session2.effectiveDestination.location, safFolderB.location);
      expect(session2.resolution.fellBackToBuiltInDefault, isFalse);
    });

    test('thư mục đã lưu bị xoá / mất quyền SAF ⇒ lùi về mặc định + báo đúng 1 lần', () async {
      final s1 = await policy.openSession();
      s1.selectOverride(safFolderB);
      s1.rememberAsDefault = true;
      await policy.commitSession(s1);

      // Giả lập người dùng xoá thư mục trong Files hoặc thu hồi quyền SAF.
      accessibleLocations.remove(safFolderB.location);

      final afterDelete = await policy.openSession();
      expect(afterDelete.effectiveDestination, builtIn);
      expect(afterDelete.resolution.fellBackToBuiltInDefault, isTrue);
      expect(afterDelete.resolution.deadDestinationDisplayPath, 'Music/B');

      // Lần mở kế tiếp KHÔNG được cảnh báo lặp lại nữa.
      final nextTime = await policy.openSession();
      expect(nextTime.effectiveDestination, builtIn);
      expect(nextTime.resolution.fellBackToBuiltInDefault, isFalse);
      expect(nextTime.resolution.deadDestinationDisplayPath, isNull);
    });
  });

  group('ADR-0029 — ghi nguyên tử (.part → fsync → rename) & không ghi đè', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('in4up_psrc204_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('trùng tên tự thêm (2), (3), giữ nguyên nội dung cũ và không để lại .part', () async {
      final downloadsDir = Directory('${tempRoot.path}/Downloads');
      await downloadsDir.create(recursive: true);

      final service = ExportDestinationService(
        store: InMemoryExportDestinationStore(),
        platformOverride: ExportHostPlatform.linux,
        downloadsDirProvider: () async => downloadsDir,
        homeDirProvider: () => tempRoot.path,
        appDocumentsDirProvider: () async => Directory('${tempRoot.path}/docs'),
      );

      final first = await service.exportText(
        content: 'Bản một',
        desiredFileName: 'bai_hoc.txt',
      );
      final second = await service.exportText(
        content: 'Bản hai',
        desiredFileName: 'bai_hoc.txt',
      );
      final third = await service.exportText(
        content: 'Bản ba',
        desiredFileName: 'bai_hoc.txt',
      );

      expect(first.fileName, 'bai_hoc.txt');
      expect(second.fileName, 'bai_hoc (2).txt');
      expect(third.fileName, 'bai_hoc (3).txt');
      expect(first.displayPath, '~/Downloads/In4Up/bai_hoc.txt');
      expect(second.displayPath, '~/Downloads/In4Up/bai_hoc (2).txt');

      expect(File(first.localPath!).readAsStringSync(), 'Bản một');
      expect(File(second.localPath!).readAsStringSync(), 'Bản hai');
      expect(File(third.localPath!).readAsStringSync(), 'Bản ba');

      final leftovers = Directory('${downloadsDir.path}/In4Up')
          .listSync()
          .where((e) => e.path.endsWith('.part'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('nguồn đọc lỗi giữa chừng ⇒ không tạo file hỏng, không để rác .part', () async {
      final outDir = Directory('${tempRoot.path}/Out');
      final service = ExportDestinationService(
        store: InMemoryExportDestinationStore(),
        platformOverride: ExportHostPlatform.linux,
        downloadsDirProvider: () async => outDir,
        homeDirProvider: () => tempRoot.path,
        appDocumentsDirProvider: () async => Directory('${tempRoot.path}/docs'),
      );

      final missingSource = File('${tempRoot.path}/khong_ton_tai.mp3');
      await expectLater(
        service.exportLocalFile(
          sourceFile: missingSource,
          desiredFileName: 'clip.mp3',
        ),
        throwsA(isA<FileSystemException>()),
      );

      final publicFolder = Directory('${outDir.path}/In4Up');
      if (publicFolder.existsSync()) {
        expect(publicFolder.listSync(), isEmpty);
      }
    });

    test('Android API ≥ 29 gọi saveFileToDownloads qua channel in4up/files, không xin quyền bộ nhớ', () async {
      const channel = MethodChannel('in4up_test/files_204');
      final calls = <MethodCall>[];
      var storagePermissionAsked = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'saveFileToDownloads':
            return <String, Object?>{
              'uri': 'content://media/external/downloads/42',
              'fileName': 'clip.mp3',
              'displayPath': 'Download/In4Up/clip.mp3',
              'localPath': null,
            };
          case 'openExportLocation':
            return true;
          default:
            return null;
        }
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final src = File('${tempRoot.path}/src.mp3')
        ..writeAsBytesSync(List<int>.filled(1024, 7));

      final service = ExportDestinationService(
        store: InMemoryExportDestinationStore(),
        channel: channel,
        platformOverride: ExportHostPlatform.android,
        androidSdkIntProvider: () async => 34,
        legacyStoragePermissionRequester: () async {
          storagePermissionAsked = true;
          return true;
        },
      );

      final saved = await service.exportLocalFile(
        sourceFile: src,
        desiredFileName: 'clip.mp3',
      );
      expect(storagePermissionAsked, isFalse,
          reason: 'Android 10+ ghi MediaStore không cần quyền lưu trữ');
      expect(saved.displayPath, 'Download/In4Up/clip.mp3');
      expect(saved.uri, 'content://media/external/downloads/42');
      expect(calls.single.method, 'saveFileToDownloads');

      final opened = await service.openContainingFolder(
        destination: saved.destination,
        fileUri: saved.uri,
      );
      expect(opened, isTrue);
      expect(calls.last.method, 'openExportLocation');
    });

    test('Cabin giữ nguyên bản lưu nội bộ và chỉ chép WAV/LRC/TXT sang đích công khai khi xuất', () async {
      final privateSessionDir = Directory('${tempRoot.path}/cabin_sessions/s1')
        ..createSync(recursive: true);
      final publicDownloads = Directory('${tempRoot.path}/Downloads')
        ..createSync(recursive: true);

      final wav = File('${privateSessionDir.path}/cabin_s1.wav')
        ..writeAsBytesSync(List<int>.filled(256, 1));
      final lrc = File('${privateSessionDir.path}/cabin_s1.lrc')
        ..writeAsStringSync('[00:01.00]Xin chào\n[00:01.01]Hello\n');
      final txt = File('${privateSessionDir.path}/cabin_s1.txt')
        ..writeAsStringSync('Xin chào\nHello\n');

      final session = CabinSession(
        id: 's1',
        title: 'Bài giảng sáng',
        createdAt: DateTime(2026, 11, 13, 8, 30),
        duration: const Duration(minutes: 2),
        sourceLang: 'vi',
        targetLang: 'en',
        entryCount: 1,
        hasAudio: true,
        status: CabinSessionStatus.saved,
        dirPath: privateSessionDir.path,
      );

      final service = ExportDestinationService(
        store: InMemoryExportDestinationStore(),
        platformOverride: ExportHostPlatform.linux,
        downloadsDirProvider: () async => publicDownloads,
        homeDirProvider: () => tempRoot.path,
        appDocumentsDirProvider: () async => Directory('${tempRoot.path}/docs'),
      );

      final exported = await exportCabinSessionFiles(
        session: session,
        destinationService: service,
      );

      expect(exported.map((e) => e.fileName).toList(), <String>[
        'Bài giảng sáng.wav',
        'Bài giảng sáng.lrc',
        'Bài giảng sáng.txt',
      ]);
      for (final f in exported) {
        expect(File(f.localPath!).existsSync(), isTrue);
      }
      // Dữ liệu nội bộ của Cabin vẫn còn nguyên trong thư mục riêng của app.
      expect(wav.existsSync(), isTrue);
      expect(lrc.existsSync(), isTrue);
      expect(txt.existsSync(), isTrue);
    });
  });

  group('ADR-0029 & Rule 5 — bất biến cấu hình hệ thống + i18n 8 locale', () {
    test('AndroidManifest KHÔNG thêm quyền MANAGE_EXTERNAL_STORAGE', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('MANAGE_EXTERNAL_STORAGE'), isFalse);
    });

    test('ExportStorageHelper.kt dùng IS_PENDING + sync() và không mở block comment nguy hiểm', () {
      final kt = _read('android/app/src/main/kotlin/com/in4up/ExportStorageHelper.kt');
      expect(kt.contains('/*'), isFalse,
          reason: 'Tránh bẫy nested block comment trong Kotlin');
      expect(kt, contains('MediaStore.Downloads.EXTERNAL_CONTENT_URI'));
      expect(kt, contains('MediaStore.MediaColumns.IS_PENDING'));
      expect(kt, contains('descriptor.fileDescriptor.sync()'));
      expect(kt, contains('DocumentsContract.createDocument'));
    });

    test('iOS Info.plist bật UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(plist, contains('<key>UIFileSharingEnabled</key>'));
      expect(plist, contains('<key>LSSupportsOpeningDocumentsInPlace</key>'));
    });

    test('CabinSessionStore vẫn giữ dữ liệu phiên thô trong thư mục nội bộ cabin_sessions', () {
      final storeSrc = _codeOnly(
        _read('lib/features/cabin/services/cabin_session_store.dart'),
      );
      expect(storeSrc, contains('getApplicationDocumentsDirectory()'));
      expect(storeSrc, contains('cabin_sessions'));
    });

    test('mọi chuỗi UI mới của PSRC-204 có đủ 8 locale trong pack + file generated', () {
      final pack = jsonDecode(
        _read('tool/priority_native_pack.json'),
      ) as Map<String, dynamic>;
      final generated =
          _read('lib/core/language/generated_priority_native_pack.dart');

      for (final source in _psrc204UiStrings) {
        final entry = pack[source];
        expect(entry, isNotNull, reason: 'Thiếu key trong pack: $source');
        for (final locale in _requiredLocales) {
          final value = (entry as Map)[locale];
          expect(value, isA<String>(), reason: '$source [$locale]');
          expect(
            (value as String).trim(),
            isNotEmpty,
            reason: '$source [$locale] rỗng',
          );
        }
        expect(
          generated,
          contains(source),
          reason: 'Chưa chạy generate_priority_native_pack.py cho: $source',
        );
      }
    });
  });
}
