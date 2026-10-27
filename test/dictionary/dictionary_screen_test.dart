// ADR-0018 (P1) — màn Từ điển riêng: ô tìm + gợi ý + lịch sử + trang kết quả.
//
// Test chạy SQLite THẬT qua `sqflite_common_ffi` (cùng khuôn với
// `dict_import_lookup_test.dart`) và `SharedPreferences` giả, nên kiểm được cả
// luồng: gõ → gợi ý → chọn → nghĩa hiện ra → lịch sử được lưu.
//
// Vì sao phải có test này: trước ADR-0018 KHÔNG có màn tra cứu nào — chỉ có ô
// tra một từ ở màn quản lý. Nếu ai đó "sửa" màn mới thành trang cài đặt, hoặc
// bỏ bước lưu lịch sử, test này đỏ.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/services/dict_history.dart';
import 'package:in4up/features/dictionary/services/dictionary_service.dart';
import 'package:in4up/features/dictionary/widgets/dictionary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mdx_test_builder.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  String? initialQuery,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DictionaryScreen(initialQuery: initialQuery),
    ),
  );
  // Nạp manifest + (nếu có) tra từ ban đầu.
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;
  late Directory docsDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('in4up-dict-screen-');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    DictionaryService.documentsDirectoryOverride = docsDir;
    DictionaryService.resetForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    DictionaryService.resetForTest();
    DictionaryService.documentsDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> installDictionary(Map<String, String> entries) async {
    final mdx = MdxTestBuilder(entries: entries)
        .writeToFile('${tempDir.path}/en_vi_screen.mdx');
    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: <String>[mdx],
      rootPath: '',
      mode: DictStorageMode.imported,
    );
    expect(outcome.isSuccess, isTrue, reason: 'cài từ điển mẫu phải thành công');
  }

  group('chưa có bộ từ điển', () {
    testWidgets('hiện onboarding thay vì ô tra trống', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('No dictionaries yet'), findsOneWidget);
      expect(find.text('Download dictionary packs'), findsOneWidget);
    });
  });

  group('tra từ', () {
    testWidgets('submit từ khoá ⇒ hiện nghĩa + nhãn nguồn', (tester) async {
      await installDictionary(<String, String>{
        'hello': '<div>n. lời chào</div><div>v. chào hỏi</div>',
        'world': 'thế giới',
      });
      await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Headword + nghĩa đã qua DictTextCleaner (không còn thẻ <div>).
      expect(find.text('hello'), findsWidgets);
      expect(find.textContaining('lời chào'), findsOneWidget);
      expect(find.textContaining('chào hỏi'), findsOneWidget);
      // Nhãn nguồn (tên bộ) — "Source: …" ở locale en.
      expect(find.textContaining('Source:'), findsOneWidget);
    });

    testWidgets('gõ ⇒ gợi ý theo tiền tố (dùng lookupPrefix chưa ai gọi)',
        (tester) async {
      await installDictionary(<String, String>{
        'hello': 'lời chào',
        'help': 'giúp đỡ',
        'world': 'thế giới',
      });
      await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'hel');
      // Debounce 220 ms + truy vấn SQLite.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('hello'), findsOneWidget);
      expect(find.text('help'), findsOneWidget);
      expect(find.text('world'), findsNothing);
    });

    testWidgets('bấm gợi ý ⇒ mở đúng từ', (tester) async {
      await installDictionary(<String, String>{
        'read': 'đọc',
        'reading': 'việc đọc',
      });
      await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'rea');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('reading').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('việc đọc'), findsOneWidget);
    });

    testWidgets('không tìm thấy ⇒ thông báo + gợi ý "có phải bạn muốn"',
        (tester) async {
      await installDictionary(<String, String>{
        'reading': 'việc đọc',
      });
      await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'readin');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Locale en: 'Không tìm thấy "{value0}"' → '"{value0}" not found'.
      expect(find.textContaining('not found'), findsOneWidget);
      expect(find.text('Did you mean:'), findsOneWidget);
    });
  });

  group('lịch sử', () {
    testWidgets('tra được thì lưu vào lịch sử, mở lại màn vẫn còn',
        (tester) async {
      await installDictionary(<String, String>{'hello': 'lời chào'});
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Lưu vào SharedPreferences (khoá của DictHistory).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(DictHistory.prefsKey), contains('hello'));
    });

    testWidgets('từ KHÔNG tra được không vào lịch sử', (tester) async {
      await installDictionary(<String, String>{'hello': 'lời chào'});
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(DictHistory.prefsKey) ?? const <String>[],
          isEmpty);
    });

    testWidgets('mở màn với initialQuery (đường vào từ link/file) ⇒ tra ngay',
        (tester) async {
      await installDictionary(<String, String>{'hello': 'lời chào'});
      await _pumpScreen(tester, initialQuery: 'hello');

      expect(find.textContaining('lời chào'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(DictHistory.prefsKey), contains('hello'));
    });
  });
}
