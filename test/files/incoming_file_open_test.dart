// test/files/incoming_file_open_test.dart — BETA-1.29.0 · lane L7 · PSRC-222
//
// Máy bắt tự động cho luồng **"Mở bằng in4up" / "Chia sẻ tới in4up"** với tài
// liệu (`.txt`, `.pdf`, `.docx`, `.md`, `.lrc`, `.srt`), âm thanh (`.mp3`,
// `.m4a`, `.wav`, `.opus`…) và video (`.mp4`, `.mkv`, `.webm`…).
//
// Khoá 5 nhóm bất biến:
//   1. Phân loại đúng mọi định dạng hỗ trợ (theo đuôi, theo MIME khi thiếu đuôi,
//      theo chữ ký byte `%PDF-` / ZIP `word/`), chặn `.apk`/`.exe` kể cả khi giả
//      mạo `text/plain`, và báo riêng `.doc` (Word 97–2003).
//   2. Khởi động lạnh (`getInitialIncomingFile` + `argv`) xếp hàng an toàn cho
//      tới khi `MainShell` sẵn sàng rồi mở đúng màn hình.
//   3. Khi app đang chạy nền (`onNewIntent` → `onIncomingFile`), mở lần lượt
//      1 PDF, 1 MP3, 1 DOCX, 1 MP4 đều chép vào bộ nhớ bền vững của app TRƯỚC
//      khi giao cho màn hình đọc / nghe / xem (tránh hết hạn quyền `content://`).
//   4. Khử trùng lặp khi hệ điều hành bắn kép cùng intent trong < 1,2 giây,
//      nhưng cho phép mở lại cùng tệp ở lần bấm sau.
//   5. `AndroidManifest.xml` (VIEW + SEND, không có `*/*`), `IncomingFileResolver.kt`,
//      `ios/Runner/Info.plist` (`CFBundleDocumentTypes`) và 8 locale đầy đủ.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/files/incoming_file_classifier.dart';
import 'package:in4up/core/files/incoming_file_router.dart';

String _read(String path) => File(path).readAsStringSync();

const List<String> _psrc222UiStrings = <String>[
  'Định dạng .doc (Word 97–2003) chưa hỗ trợ — hãy lưu lại thành .docx hoặc .txt.',
  'Định dạng tệp này chưa được In4Up hỗ trợ ({value0}).',
  'Không mở được tệp: {value0}',
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

class _RecordedOpen {
  const _RecordedOpen(this.route, this.localPath, this.displayName);

  final String route;
  final String localPath;
  final String displayName;
}

class _FakeOpenHost implements IncomingFileOpenHost {
  _FakeOpenHost({this.ready = true});

  bool ready;
  final List<_RecordedOpen> opened = <_RecordedOpen>[];
  final List<(IncomingUnsupportedReason, String)> unsupported =
      <(IncomingUnsupportedReason, String)>[];
  final List<String> errors = <String>[];

  @override
  bool get isReady => ready;

  @override
  Future<void> openPdf({
    required String localPath,
    required String displayName,
  }) async {
    opened.add(_RecordedOpen('pdf', localPath, displayName));
  }

  @override
  Future<void> openTextDocument({
    required String localPath,
    required String displayName,
  }) async {
    opened.add(_RecordedOpen('text', localPath, displayName));
  }

  @override
  Future<void> openAudio({
    required String localPath,
    required String displayName,
  }) async {
    opened.add(_RecordedOpen('audio', localPath, displayName));
  }

  @override
  Future<void> openVideo({
    required String localPath,
    required String displayName,
  }) async {
    opened.add(_RecordedOpen('video', localPath, displayName));
  }

  @override
  Future<void> openDictionary({
    required String localPath,
    required String displayName,
  }) async {
    opened.add(_RecordedOpen('dict', localPath, displayName));
  }

  @override
  void showUnsupportedMessage({
    required IncomingUnsupportedReason reason,
    required String displayName,
  }) {
    unsupported.add((reason, displayName));
  }

  @override
  void showOpenError({required String displayName}) {
    errors.add(displayName);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PSRC-222 — phân loại tệp thuần (IncomingFileClassifier)', () {
    test('nhận đúng tài liệu, PDF, âm thanh, video và từ điển theo đuôi tệp', () {
      expect(
        IncomingFileClassifier.classify(displayName: 'bai_hoc.pdf').category,
        IncomingFileCategory.pdf,
      );
      for (final doc in <String>[
        'ghi_chu.txt',
        'giao_trinh.docx',
        'README.md',
        'phu_de.lrc',
        'tap_1.srt',
      ]) {
        expect(
          IncomingFileClassifier.classify(displayName: doc).category,
          IncomingFileCategory.textDocument,
          reason: doc,
        );
      }
      for (final audio in <String>[
        'bai_nghe.mp3',
        'ghi_am.m4a',
        'mau.wav',
        'sach_noi.opus',
        'nhac.flac',
      ]) {
        expect(
          IncomingFileClassifier.classify(displayName: audio).category,
          IncomingFileCategory.audio,
          reason: audio,
        );
      }
      for (final video in <String>['bai_giang.mp4', 'phim.mkv', 'clip.webm']) {
        expect(
          IncomingFileClassifier.classify(displayName: video).category,
          IncomingFileCategory.video,
          reason: video,
        );
      }
      expect(
        IncomingFileClassifier.classify(displayName: 'anh_viet.mdx').category,
        IncomingFileCategory.dictionary,
      );
    });

    test('URI content:// thiếu đuôi tệp vẫn nhận diện qua chữ ký byte hoặc MIME', () {
      final byDocxMime = IncomingFileClassifier.classify(
        displayName: 'document_9921',
        originalUri:
            'content://com.google.android.apps.docs.storage/document/acc%3D1%3Bdoc%3D9921',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(byDocxMime.category, IncomingFileCategory.textDocument);
      expect(byDocxMime.canonicalExtension, 'docx');
      expect(
        IncomingFileClassifier.ensureFileNameHasExtension(
          'document_9921',
          byDocxMime.canonicalExtension,
        ),
        'document_9921.docx',
      );

      final byPdfMagic = IncomingFileClassifier.classify(
        displayName: 'attachment.bin',
        headerBytes: ascii.encode('%PDF-1.7\n'),
      );
      expect(byPdfMagic.category, IncomingFileCategory.pdf);
      expect(
        IncomingFileClassifier.ensureFileNameHasExtension(
          'attachment.bin',
          byPdfMagic.canonicalExtension,
        ),
        'attachment.pdf',
      );

      final fakeDocxZip = <int>[
        0x50,
        0x4B,
        0x03,
        0x04,
        ...List<int>.filled(26, 0),
        ...ascii.encode('word/document.xml'),
      ];
      final byDocxMagic = IncomingFileClassifier.classify(
        displayName: 'shared_stream',
        headerBytes: fakeDocxZip,
      );
      expect(byDocxMagic.category, IncomingFileCategory.textDocument);
      expect(byDocxMagic.canonicalExtension, 'docx');
    });

    test('chặn tệp thực thi dù giả mạo text/plain và báo riêng .doc cũ', () {
      final apk = IncomingFileClassifier.classify(
        displayName: 'installer.apk',
        mimeType: 'text/plain',
      );
      expect(apk.isSupported, isFalse);
      expect(apk.unsupportedReason, IncomingUnsupportedReason.blockedExecutable);

      final legacyDoc = IncomingFileClassifier.classify(
        displayName: 'cu.doc',
        mimeType: 'application/msword',
      );
      expect(legacyDoc.isSupported, isFalse);
      expect(legacyDoc.unsupportedReason, IncomingUnsupportedReason.legacyDoc);

      final wildcard = IncomingFileClassifier.classify(
        displayName: 'khong_duoi',
        mimeType: '*/*',
      );
      expect(wildcard.isSupported, isFalse);
    });
  });

  group('PSRC-222 — khởi động lạnh & đang chạy nền (IncomingFileRouter)', () {
    late Directory tempRoot;
    late Directory appDocs;
    late Directory incomingStage;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('in4up_psrc222_');
      appDocs = Directory('${tempRoot.path}/app_docs')..createSync(recursive: true);
      incomingStage = Directory('${tempRoot.path}/files/in4up_incoming')
        ..createSync(recursive: true);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('khởi động lạnh: giữ tệp chờ cho tới khi MainShell sẵn sàng, chép vào bộ nhớ app rồi mở', () async {
      const channelName = 'in4up_test/files_222_cold';
      const channel = MethodChannel(channelName);

      final stagedPdf = File('${incomingStage.path}/giao_trinh.pdf')
        ..writeAsBytesSync(ascii.encode('%PDF-1.7 sample content'));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialIncomingFile') {
          return <String, Object?>{
            'localPath': stagedPdf.path,
            'displayName': 'giao_trinh.pdf',
            'mimeType': 'application/pdf',
            'originalUri': 'content://com.android.providers.downloads.documents/document/77',
            'source': 'android_view',
          };
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final router = IncomingFileRouter(
        channel: channel,
        appDocumentsDirProvider: () async => appDocs,
        audioPersister: ({required sourcePath, required displayName}) async =>
            sourcePath,
      );

      final host = _FakeOpenHost(ready: false);
      await router.attachHost(host);
      await router.start(const <String>[]);

      // Giao diện chưa sẵn sàng ⇒ chưa được gọi mở sớm.
      expect(host.opened, isEmpty);

      host.ready = true;
      await router.attachHost(host);

      expect(host.opened, hasLength(1));
      expect(host.opened.single.route, 'pdf');
      expect(host.opened.single.localPath, contains('/in4up_pdfs/giao_trinh.pdf'));
      expect(File(host.opened.single.localPath).existsSync(), isTrue);
      // Tệp tạm trong in4up_incoming đã được dọn sau khi chép vào in4up_pdfs.
      expect(stagedPdf.existsSync(), isFalse);
    });

    test('khi app đang chạy nền (onNewIntent): mở đúng PDF, MP3, DOCX và MP4 + khử bắn kép', () async {
      const channelName = 'in4up_test/files_222_warm';
      const channel = MethodChannel(channelName);

      var now = DateTime(2026, 11, 13, 10, 0, 0);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final router = IncomingFileRouter(
        channel: channel,
        appDocumentsDirProvider: () async => appDocs,
        clock: () => now,
        audioPersister: ({required sourcePath, required displayName}) async {
          final audioDir = Directory('${appDocs.path}/audio_imports')
            ..createSync(recursive: true);
          final dest = File('${audioDir.path}/$displayName');
          await File(sourcePath).copy(dest.path);
          return dest.path;
        },
      );

      final host = _FakeOpenHost(ready: true);
      router.attachHost(host);
      await router.start(const <String>[]);

      Future<void> pushFromOs(Map<String, Object?> payload) async {
        final encoded = const StandardMethodCodec().encodeMethodCall(
          MethodCall('onIncomingFile', payload),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(channelName, encoded, (_) {});
      }

      final pdfStage = File('${incomingStage.path}/sach.pdf')
        ..writeAsBytesSync(ascii.encode('%PDF-1.5 body'));
      final mp3Stage = File('${incomingStage.path}/bai_nghe.mp3')
        ..writeAsBytesSync(List<int>.filled(128, 3));
      final docxStage = File('${incomingStage.path}/bai_doc.docx')
        ..writeAsBytesSync(List<int>.filled(128, 5));
      final mp4Stage = File('${incomingStage.path}/bai_xem.mp4')
        ..writeAsBytesSync(List<int>.filled(256, 9));

      await pushFromOs(<String, Object?>{
        'localPath': pdfStage.path,
        'displayName': 'sach.pdf',
        'mimeType': 'application/pdf',
        'originalUri': 'content://provider/doc/1',
        'source': 'android_view',
      });
      // Hệ điều hành bắn trùng cùng một intent sau 100 ms ⇒ chỉ mở 1 lần.
      now = now.add(const Duration(milliseconds: 100));
      await pushFromOs(<String, Object?>{
        'localPath': pdfStage.path,
        'displayName': 'sach.pdf',
        'mimeType': 'application/pdf',
        'originalUri': 'content://provider/doc/1',
        'source': 'android_view',
      });

      now = now.add(const Duration(seconds: 2));
      await pushFromOs(<String, Object?>{
        'localPath': mp3Stage.path,
        'displayName': 'bai_nghe.mp3',
        'mimeType': 'audio/mpeg',
        'originalUri': 'content://provider/audio/2',
        'source': 'android_view',
      });

      now = now.add(const Duration(seconds: 2));
      await pushFromOs(<String, Object?>{
        'localPath': docxStage.path,
        'displayName': 'bai_doc.docx',
        'mimeType':
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'originalUri': 'content://provider/doc/3',
        'source': 'android_send',
      });

      now = now.add(const Duration(seconds: 2));
      await pushFromOs(<String, Object?>{
        'localPath': mp4Stage.path,
        'displayName': 'bai_xem.mp4',
        'mimeType': 'video/mp4',
        'originalUri': 'content://provider/video/4',
        'source': 'android_view',
      });

      expect(
        host.opened.map((e) => e.route).toList(),
        <String>['pdf', 'audio', 'text', 'video'],
      );
      for (final item in host.opened) {
        expect(item.localPath, startsWith(appDocs.path),
            reason: 'Mọi tệp phải nằm trong bộ nhớ bền vững của app trước khi mở');
        expect(File(item.localPath).existsSync(), isTrue);
      }
    });

    test('tham số dòng lệnh Desktop bỏ qua cờ --flag và mở đúng tệp .md', () async {
      const channel = MethodChannel('in4up_test/files_222_cli');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final externalMd = File('${tempRoot.path}/note.md')
        ..writeAsStringSync('# Xin chào\nNội dung thử nghiệm.');

      final router = IncomingFileRouter(
        channel: channel,
        appDocumentsDirProvider: () async => appDocs,
      );
      final host = _FakeOpenHost(ready: true);
      router.attachHost(host);

      await router.start(<String>[
        '--enable-logging',
        'in4up://dict?w=dhamma',
        externalMd.path,
      ]);

      expect(host.opened, hasLength(1));
      expect(host.opened.single.route, 'text');
      expect(host.opened.single.displayName, 'note.md');
      expect(File(host.opened.single.localPath).existsSync(), isTrue);
      // Tệp gốc của người dùng bên ngoài KHÔNG bị xoá.
      expect(externalMd.existsSync(), isTrue);
    });
  });

  group('PSRC-222 — bất biến AndroidManifest, Kotlin, Info.plist & 8 locale', () {
    test('AndroidManifest có ACTION_VIEW (content + file) & ACTION_SEND cho tài liệu/audio/video, không có */*', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android.intent.action.VIEW'));
      expect(manifest, contains('android.intent.action.SEND'));
      expect(manifest, contains('android:scheme="content"'));
      expect(manifest, contains('android:scheme="file"'));
      expect(manifest, contains('android:mimeType="text/*"'));
      expect(manifest, contains('android:mimeType="application/pdf"'));
      expect(
        manifest,
        contains(
          'android:mimeType="application/vnd.openxmlformats-officedocument.wordprocessingml.document"',
        ),
      );
      expect(manifest, contains('android:mimeType="audio/*"'));
      expect(manifest, contains('android:mimeType="video/*"'));
      expect(manifest.contains('android:mimeType="*/*"'), isFalse,
          reason: 'Cấm khai báo đại diện mọi loại tệp trong Mở bằng');
    });

    test('IncomingFileResolver.kt & MainActivity.kt xử lý cả onCreate + onNewIntent và chép vào bộ nhớ app', () {
      final resolver =
          _read('android/app/src/main/kotlin/com/in4up/IncomingFileResolver.kt');
      expect(resolver.contains('/*'), isFalse,
          reason: 'Tránh bẫy nested block comment của Kotlin');
      expect(resolver, contains('Intent.ACTION_VIEW'));
      expect(resolver, contains('Intent.ACTION_SEND'));
      expect(resolver, contains('Intent.EXTRA_STREAM'));
      expect(resolver, contains('in4up_incoming'));
      expect(resolver, contains('output.fd.sync()'));

      final mainKt =
          _read('android/app/src/main/kotlin/com/in4up/MainActivity.kt');
      expect(mainKt, contains('captureIncomingFileIntent(intent, isInitialLaunch = true)'));
      expect(mainKt, contains('captureIncomingFileIntent(intent, isInitialLaunch = false)'));
      expect(mainKt, contains('"getInitialIncomingFile"'));
      expect(mainKt, contains('"onIncomingFile"'));
    });

    test('iOS Info.plist khai báo CFBundleDocumentTypes cho PDF, DOCX, văn bản, âm thanh, video', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(plist, contains('<key>CFBundleDocumentTypes</key>'));
      expect(plist, contains('<string>com.adobe.pdf</string>'));
      expect(
        plist,
        contains('<string>org.openxmlformats.wordprocessingml.document</string>'),
      );
      expect(plist, contains('<string>public.audio</string>'));
      expect(plist, contains('<string>public.movie</string>'));
      expect(plist.contains('<string>public.item</string>'), isFalse);
      expect(plist.contains('<string>public.data</string>'), isFalse);
    });

    test('mọi chuỗi UI mới của PSRC-222 có đủ 8 locale trong pack + file generated', () {
      final pack = jsonDecode(
        _read('tool/priority_native_pack.json'),
      ) as Map<String, dynamic>;
      final generated =
          _read('lib/core/language/generated_priority_native_pack.dart');

      for (final source in _psrc222UiStrings) {
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
