// test/media_tools/export_follow_up_flow_test.dart
//
// PSRC-202 (audit 1.28.0) — "tách audio từ video rồi chọn mở trong tab Nghe:
// audio không tự mở, rồi bị dish".
//
// GỐC (đọc đường xuất file, không cần thiết bị):
//   `media_export_sheet._start()` gọi `Navigator.pop()` để đóng sheet rồi
//   NGAY SAU ĐÓ dùng chính `context` của sheet để `showDialog` hộp thoại
//   "Đã xuất xong". Context đó thuộc route vừa bị gỡ ⇒ `showDialog` đi tìm
//   Navigator qua một element đang bị deactivate: lúc được lúc không (tuỳ
//   frame), và khi đang chạy hiệu ứng đóng thì hộp thoại hiện ra rồi biến mất
//   theo route. Người dùng thấy "không có gì xảy ra" ⇒ không có chỗ bấm
//   "Mở trong tab Nghe" ⇒ audio không bao giờ tự mở.
//
// Máy bắt:
//   1. Quét NGUỒN `media_export_sheet.dart`: sheet không được tự mở follow-up
//      (chặn tái phát đúng dòng gây lỗi).
//   2. Test WIDGET luồng thật: lối vào mở follow-up bằng context còn sống,
//      nút "Mở trong tab Nghe" gọi callback với `primaryPath`, và khi tệp đã
//      biến mất thì KHÔNG mở (báo lý do + đường thay thế).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/media_export_actions.dart';
import 'package:in4up/features/media_tools/models/media_export_models.dart';
import 'package:in4up/services/external_open_service.dart';

/// Tạo tệp mẫu bằng I/O ĐỒNG BỘ.
///
/// `testWidgets` chạy trong `FakeAsync`: `await Directory.systemTemp.createTemp`
/// / `await file.writeAsBytes` cần event loop thật nên future KHÔNG BAO GIỜ
/// hoàn tất — `flutter test` treo im lặng (đã xảy ra ở CI: run 43488523702).
/// Hàm vẫn trả `Future` để chỗ gọi `await` giữ nguyên.
Future<File> _tempAudio(String name) async {
  final dir = Directory.systemTemp.createTempSync('psrc202_');
  final file = File('${dir.path}/$name')
    ..writeAsBytesSync(List<int>.filled(2048, 0));
  return file;
}

Widget _host(Future<void> Function(BuildContext context) run) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => run(context),
            child: const Text('run'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PSRC-202 — follow-up thuộc về lối vào, không phải sheet đã đóng', () {
    test('media_export_sheet.dart không tự mở follow-up sau Navigator.pop', () {
      final source = File(
        'lib/features/media_tools/widgets/media_export_sheet.dart',
      ).readAsStringSync();
      expect(
        source.contains('offerExportFollowUp'),
        isFalse,
        reason: 'Sheet xuất không được tự mở hộp thoại follow-up: context của '
            'sheet vừa bị pop nên showDialog sẽ chạy trên route đang bị gỡ '
            '(PSRC-202). Hãy để lối vào gọi completeExportWithFollowUp.',
      );
    });

    testWidgets('lối vào mở follow-up sau khi sheet trả kết quả', (tester) async {
      final file = await _tempAudio('clip.mp3');
      final result = MediaExportResult(
        outputPaths: [file.path],
        sizeBytes: 2048,
      );
      var openedPath = '';

      await tester.pumpWidget(_host((context) async {
        await completeExportWithFollowUp(
          context,
          () async => result,
          openInListenTab: (path) async => openedPath = path,
        );
      }));
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();

      // Hộp thoại "Đã xuất xong" phải xuất hiện trên context của lối vào.
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.headphones_rounded));
      await tester.pumpAndSettle();

      expect(openedPath, file.path,
          reason: 'Nút "Mở trong tab Nghe" phải mở đúng tệp vừa xuất');
    });

    testWidgets('tệp đã biến mất: không mở, báo lý do + mở thư mục',
        (tester) async {
      final file = await _tempAudio('gone.mp3');
      final result = MediaExportResult(
        outputPaths: [file.path],
        sizeBytes: 2048,
      );
      var opened = false;
      file.deleteSync();

      await tester.pumpWidget(_host((context) async {
        await completeExportWithFollowUp(
          context,
          () async => result,
          openInListenTab: (path) async => opened = true,
        );
      }));
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.headphones_rounded));
      await tester.pumpAndSettle();

      expect(opened, isFalse,
          reason: 'Không được nạp một đường dẫn không còn tồn tại');
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget,
          reason: 'Phải có đường thay thế: mở thư mục chứa tệp');
    });

    testWidgets('huỷ sheet (null) thì không có follow-up', (tester) async {
      await tester.pumpWidget(_host((context) async {
        await completeExportWithFollowUp(context, () async => null);
      }));
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.headphones_rounded), findsNothing);
      expect(find.byIcon(Icons.share_rounded), findsNothing);
    });
  });

  group('external open — lệnh mở ngoài app (thuần, không chạy tiến trình)', () {
    test('Linux: mở thư mục chứa tệp bằng xdg-open', () {
      final command = buildExternalOpenCommand(
        platform: ExternalOpenPlatform.linux,
        path: '/home/me/media_exports/clip.mp3',
        revealInFolder: true,
      );
      expect(command, isNotNull);
      expect(command!.executable, 'xdg-open');
      expect(command.arguments, ['/home/me/media_exports']);
    });

    test('Windows: chọn đúng tệp trong Explorer', () {
      final command = buildExternalOpenCommand(
        platform: ExternalOpenPlatform.windows,
        path: r'C:\Users\me\media_exports\clip.mp3',
        revealInFolder: true,
      );
      expect(command!.executable, 'explorer.exe');
      expect(command.arguments.first, '/select,');
    });

    test('macOS: mở tệp bằng open', () {
      final command = buildExternalOpenCommand(
        platform: ExternalOpenPlatform.macOS,
        path: '/Users/me/clip.mp3',
      );
      expect(command!.executable, 'open');
      expect(command.arguments, ['/Users/me/clip.mp3']);
    });

    test('Mobile/Web: không có API mở tệp ⇒ trả null (UI phải nói thật)', () {
      for (final platform in [
        ExternalOpenPlatform.android,
        ExternalOpenPlatform.iOS,
        ExternalOpenPlatform.web,
        ExternalOpenPlatform.unknown,
      ]) {
        expect(
          buildExternalOpenCommand(
            platform: platform,
            path: '/tmp/clip.mp3',
            revealInFolder: true,
          ),
          isNull,
        );
      }
    });

    test('đường dẫn rỗng ⇒ không dựng lệnh', () {
      expect(
        buildExternalOpenCommand(
          platform: ExternalOpenPlatform.linux,
          path: '   ',
        ),
        isNull,
      );
    });
  });
}
