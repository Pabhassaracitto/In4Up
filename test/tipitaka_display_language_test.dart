// PSRC-159 — v1.24.0 chỉ hiện Pāli dù đã import gói ngôn ngữ đích.
//
// Hai nguyên nhân được khoá lại ở đây:
//  1. Màn hình dùng thẳng `Localizations.localeOf(context).languageCode` (UI
//     có thể là en trong khi chỉ có pack vi) ⇒ rớt về tiêu đề Pāli.
//  2. `getBooksByCollection/getBookById` COALESCE tiêu đề theo đúng ngôn ngữ
//     yêu cầu rồi bỏ cuộc ⇒ không bao giờ thử bản dịch đã import khác.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_language_resolver.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('resolveTipitakaDisplayLanguage', () {
    test('UI en nhưng chỉ có Pāli + Việt ⇒ chọn Việt', () {
      expect(
        resolveTipitakaDisplayLanguage(
          availableLanguages: const {'pi', 'vi'},
          uiLanguage: 'en',
        ),
        'vi',
      );
    });

    test('ngôn ngữ đang chọn được giữ nếu vẫn còn trong DB', () {
      expect(
        resolveTipitakaDisplayLanguage(
          availableLanguages: const {'pi', 'vi', 'my'},
          preferredLanguage: 'my',
          uiLanguage: 'en',
        ),
        'my',
      );
    });

    test('lựa chọn cũ đã bị xoá ⇒ rớt sang ngôn ngữ đích có thật', () {
      expect(
        resolveTipitakaDisplayLanguage(
          availableLanguages: const {'pi', 'vi'},
          preferredLanguage: 'en',
          uiLanguage: 'en',
        ),
        'vi',
      );
    });

    test('gói động zh_TW và locale zh-TW khớp nhau', () {
      expect(
        resolveTipitakaDisplayLanguage(
          availableLanguages: const {'pi', 'zh_TW'},
          uiLanguage: 'zh-TW',
        ),
        'zh-tw',
      );
      expect(
        resolveTipitakaDisplayLanguage(
          availableLanguages: const {'pi', 'zh'},
          uiLanguage: 'zh-TW',
        ),
        'zh',
      );
    });

    test('DB chỉ có Pāli ⇒ pi; DB rỗng ⇒ en', () {
      expect(
        resolveTipitakaDisplayLanguage(
          availableLanguages: const {'pi'},
          uiLanguage: 'vi',
        ),
        'pi',
      );
      expect(
        resolveTipitakaDisplayLanguage(
          availableLanguages: const <String>{},
          uiLanguage: 'vi',
        ),
        'en',
      );
    });
  });

  group('catalogue fallback to an imported translation', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE tipitaka_collections (
          id INTEGER PRIMARY KEY, name_pali TEXT, name_en TEXT, name_vi TEXT,
          order_index INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE tipitaka_books (
          id INTEGER PRIMARY KEY, collection_id INTEGER, code TEXT,
          name_pali TEXT, name_en TEXT, name_vi TEXT, order_index INTEGER,
          metadata_json TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE tipitaka_segments (
          id INTEGER PRIMARY KEY, book_id INTEGER, section_id INTEGER,
          reference TEXT, paragraph_no INTEGER, block_type TEXT, pali_text TEXT,
          translation_en TEXT, translation_vi TEXT, translation_my TEXT,
          translation_th TEXT, order_index INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE tipitaka_translations (
          segment_id INTEGER, language_code TEXT, text TEXT,
          PRIMARY KEY (segment_id, language_code)
        )
      ''');
      await db.insert('tipitaka_collections', {
        'id': 1,
        'name_pali': 'Sutta Piṭaka',
        'name_en': 'Sutta Piṭaka',
        'name_vi': 'Tạng Kinh',
        'order_index': 1,
      });
      await db.insert('tipitaka_books', {
        'id': 1,
        'collection_id': 1,
        'code': 'MN01M_MUL',
        'name_pali': '',
        'name_en': '',
        'name_vi': '',
        'order_index': 0,
        'metadata_json': null,
      });
      await db.insert('tipitaka_segments', {
        'id': 1,
        'book_id': 1,
        'reference': 'MN 1',
        'paragraph_no': 1,
        'block_type': 'book',
        'pali_text': '<p rend="book">Mūlapariyāyasuttaṃ</p>',
        'translation_en': '',
        'translation_vi': '<p rend="book">Kinh Phương Đế</p>',
        'translation_my': '',
        'translation_th': '',
        'order_index': 0,
      });
      await db.insert('tipitaka_segments', {
        'id': 2,
        'book_id': 1,
        'reference': 'MN 2',
        'paragraph_no': 2,
        'block_type': 'paragraph',
        'pali_text': 'Evaṃ me sutaṃ.',
        'translation_en': '',
        'translation_vi': 'Ta đã nghe như vầy.',
        'translation_my': '',
        'translation_th': '',
        'order_index': 1,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('yêu cầu en vẫn hiện tiêu đề Việt đã import (cả tree lẫn deep-link)',
        () async {
      final books =
          await TipitakaDb.getBooksByCollection(db, 1, languageCode: 'en');
      expect(books, hasLength(1));
      expect(books.single.displayTitle('en'), 'Kinh Phương Đế');

      final viBooks =
          await TipitakaDb.getBooksByCollection(db, 1, languageCode: 'vi');
      expect(viBooks.single.displayTitle('vi'), 'Kinh Phương Đế');

      final byId =
          await TipitakaDb.getBookById(db, 1, languageCode: 'en');
      expect(byId, isNotNull);
      expect(byId!.displayTitle('en'), 'Kinh Phương Đế');
    });

    test('đoạn kinh trả đúng bản dịch đích', () async {
      final segments = await TipitakaDb.getSegmentsByBook(db, 1);
      expect(segments.last.translationFor('vi'), 'Ta đã nghe như vầy.');
    });
  });

  test('mọi màn hình Tipiṭaka dùng resolver ngôn ngữ đích', () {
    const screens = [
      'lib/features/tipitaka/screens/library_screen.dart',
      'lib/features/tipitaka/screens/workspace_screen.dart',
      'lib/features/tipitaka/screens/search_screen.dart',
      'lib/features/tipitaka/screens/reader_screen.dart',
    ];
    for (final path in screens) {
      expect(
        File(path).readAsStringSync(),
        contains('resolveTipitakaDisplayLanguage'),
        reason: '$path vẫn dùng locale UI thô.',
      );
    }
    expect(
      File('lib/features/tipitaka/services/db_service.dart').readAsStringSync(),
      contains('_anyTranslationTitleSql'),
    );
  });
}
