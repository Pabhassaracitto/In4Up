// PSRC-158 — Sau khi import dữ liệu thật, bản "Tipiṭaka — bản Demo" phải biến
// mất hoàn toàn (không chỉ bị lọc ở vài câu query), và sách mới không được gắn
// vào collection tên Demo như các bản cũ.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String targetPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> createTarget({required bool withOfficialBook}) async {
    final db = await databaseFactoryFfi.openDatabase(targetPath);
    await db.execute('''
      CREATE TABLE tipitaka_import_history (
        source_sha256 TEXT PRIMARY KEY, source_name TEXT NOT NULL DEFAULT '',
        imported_at INTEGER NOT NULL, imported_rows INTEGER NOT NULL DEFAULT 0
      )
    ''');
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
        translation_th TEXT, source_table TEXT, source_row_key TEXT,
        order_index INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE tipitaka_translations (
        segment_id INTEGER, language_code TEXT, text TEXT,
        PRIMARY KEY (segment_id, language_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE tipitaka_highlights (
        id INTEGER PRIMARY KEY, book_id INTEGER, segment_id INTEGER,
        color TEXT, note TEXT, updated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE tipitaka_user_notes (
        id INTEGER PRIMARY KEY, segment_id INTEGER, note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE tipitaka_learning_items (
        id INTEGER PRIMARY KEY, segment_id INTEGER
      )
    ''');
    await db.insert('tipitaka_collections', {
      'id': 1,
      'name_pali': 'Tipiṭaka — demo import',
      'name_en': 'Tipiṭaka — demo import',
      'name_vi': 'Tipiṭaka — bản demo',
      'order_index': 0,
    });
    await db.insert('tipitaka_books', {
      'id': 1,
      'collection_id': 1,
      'code': 'DEMO',
      'name_pali': 'Pāḷi source (demo)',
      'name_en': 'Pāli source (demo)',
      'name_vi': 'Nguồn Pāli (demo)',
      'order_index': 0,
      'metadata_json': '{"source":"OpenTipitaka import demo"}',
    });
    await db.insert('tipitaka_segments', {
      'id': 1,
      'book_id': 1,
      'reference': 'SEG 1',
      'block_type': 'paragraph',
      'pali_text': 'Demo sample text',
      'translation_vi': 'Bản dịch mẫu demo',
      'order_index': 0,
    });
    await db.insert('tipitaka_segments', {
      'id': 2,
      'book_id': 1,
      'reference': 'SEG 2',
      'block_type': 'paragraph',
      'pali_text': 'Demo sample text 2',
      'order_index': 1,
    });
    await db.insert('tipitaka_translations', {
      'segment_id': 1,
      'language_code': 'vi',
      'text': 'Bản dịch mẫu demo',
    });
    await db.insert('tipitaka_highlights', {
      'id': 1,
      'book_id': 1,
      'segment_id': 1,
      'color': 'yellow',
      'note': '',
      'updated_at': 1,
    });
    if (withOfficialBook) {
      await db.insert('tipitaka_collections', {
        'id': 2,
        'name_pali': 'Sutta Piṭaka',
        'name_en': 'Sutta Piṭaka',
        'name_vi': 'Tạng Kinh',
        'order_index': 1,
      });
      await db.insert('tipitaka_books', {
        'id': 2,
        'collection_id': 2,
        'code': 'MN01M_MUL',
        'name_pali': 'Mūlapariyāyasuttaṃ',
        'name_en': '',
        'name_vi': '',
        'order_index': 0,
        'metadata_json': null,
      });
      await db.insert('tipitaka_segments', {
        'id': 3,
        'book_id': 2,
        'reference': 'MN 1',
        'block_type': 'paragraph',
        'pali_text': 'Evaṃ me sutaṃ.',
        'order_index': 0,
      });
    }
    await db.close();
  }

  Future<String> createVietnameseSource() async {
    final path = '${directory.path}/tipitaka_vietnamese.sqlite';
    final db = await databaseFactoryFfi.openDatabase(path);
    await db.execute('''
      CREATE TABLE mn01m_mul (
        id INTEGER PRIMARY KEY,
        reference TEXT NOT NULL,
        vietnamese TEXT NOT NULL
      )
    ''');
    await db.insert('mn01m_mul', {
      'id': 1,
      'reference': 'MN 1',
      'vietnamese': '<p rend="book">Kinh Mẫu Tiếng Việt</p>',
    });
    await db.insert('mn01m_mul', {
      'id': 2,
      'reference': 'MN 2',
      'vietnamese': 'Nội dung tiếng Việt.',
    });
    await db.close();
    return path;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('in4up-demo-purge-');
    targetPath = '${directory.path}/tipitaka.sqlite';
  });

  tearDown(() async {
    await TipitakaDb.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('dọn Demo xoá sạch sách/đoạn/dịch và giữ nguyên dữ liệu thật', () async {
    await createTarget(withOfficialBook: true);
    final removed = await TipitakaDb.purgeDemoData(destinationPath: targetPath);
    expect(removed.removedBooks, 1);
    expect(removed.removedSegments, 2);
    expect(removed.removedTranslations, 1);
    expect(removed.removedCollections, 1);

    final db = await TipitakaDb.openAt(targetPath);
    expect(await TipitakaDb.hasDemoData(db), isFalse);
    final collections = await TipitakaDb.getCollections(db);
    expect(collections.map((item) => item.id), [2]);
    final info = await TipitakaDb.info(db);
    expect(info.segmentCount, 1);
    expect(info.bookCount, 1);
    expect(
      (await TipitakaDb.getSegmentsByBook(db, 2)).single.paliText,
      'Evaṃ me sutaṃ.',
    );
    expect(await TipitakaDb.getHighlights(db), isEmpty);
    expect(await TipitakaDb.searchSegments(db, 'Demo sample'), isEmpty);
  });

  test('import gói tiếng Việt vào DB Demo không để lại dòng Demo nào', () async {
    await createTarget(withOfficialBook: false);
    final sourcePath = await createVietnameseSource();
    await TipitakaDb.importSourceDatabase(
      sourcePath,
      languageCode: 'vi',
      destinationPath: targetPath,
    );

    final db = await TipitakaDb.openAt(targetPath);
    expect(await TipitakaDb.hasDemoData(db), isFalse);
    final collections = await TipitakaDb.getCollections(db);
    expect(collections, isNotEmpty);
    for (final collection in collections) {
      final names = '${collection.namePali} ${collection.nameEn} '
          '${collection.nameVi}'.toLowerCase();
      expect(names.contains('demo'), isFalse,
          reason: 'Collection vẫn mang nhãn Demo: $names');
    }
    final books = await TipitakaDb.getCatalogIndexBooks(db);
    expect(books.every((book) => book.code != 'DEMO'), isTrue);
    final info = await TipitakaDb.info(db);
    expect(info.availableLanguages, contains('vi'));
    expect(info.segmentCount, 2);
    final segments = await TipitakaDb.getSegmentsByBook(db, books.single.id);
    expect(segments.last.translationFor('vi'), 'Nội dung tiếng Việt.');
  });

  test('mọi nhánh import đều gọi dọn Demo trước khi copy dữ liệu', () {
    final source = File('lib/features/tipitaka/services/db_service.dart')
        .readAsStringSync();
    expect(
      'await _purgeDemoCatalog(transaction);'.allMatches(source).length,
      3,
      reason: 'Thiếu dọn Demo ở Pāli / bản dịch / normalized DB.',
    );
    expect(source, contains('if (_isDemoCatalogName(names)) continue;'));
  });
}
