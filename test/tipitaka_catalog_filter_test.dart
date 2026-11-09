import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> createSchema() async {
    await db.execute('''
      CREATE TABLE tipitaka_collections (
        id INTEGER PRIMARY KEY,
        name_pali TEXT, name_en TEXT, name_vi TEXT, order_index INTEGER
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
    await db.execute('''
      CREATE TABLE tipitaka_highlights (
        id INTEGER PRIMARY KEY, book_id INTEGER, segment_id INTEGER,
        color TEXT, note TEXT, updated_at INTEGER
      )
    ''');
    await db.insert('tipitaka_collections', {
      'id': 1,
      'name_pali': 'Demo collection',
      'name_en': 'Demo collection',
      'name_vi': 'Bộ mẫu demo',
      'order_index': 0,
    });
    await db.insert('tipitaka_collections', {
      'id': 2,
      'name_pali': 'Majjhima Nikāya',
      'name_en': 'Middle Length Discourses',
      'name_vi': 'Trung Bộ Kinh',
      'order_index': 1,
    });
    await db.insert('tipitaka_collections', {
      'id': 3,
      'name_pali': 'Vinaya Piṭaka',
      'name_en': 'Vinaya Piṭaka',
      'name_vi': 'Tạng Luật',
      'order_index': 2,
    });
    await db.insert('tipitaka_collections', {
      'id': 4,
      'name_pali': 'Abhidhamma Piṭaka',
      'name_en': 'Abhidhamma Piṭaka',
      'name_vi': 'Tạng Vi Diệu Pháp',
      'order_index': 3,
    });
    await db.insert('tipitaka_books', {
      'id': 1,
      'collection_id': 1,
      'code': 'DEMO',
      'name_pali': 'Demo book',
      'name_en': 'Demo book',
      'name_vi': 'Bài mẫu demo',
      'order_index': 0,
      'metadata_json': null,
    });
    await db.insert('tipitaka_books', {
      'id': 2,
      'collection_id': 2,
      'code': 'VISUDDHIMAGGA',
      'name_pali': 'Visuddhimagga',
      'name_en': 'Path of Purification',
      'name_vi': 'Thanh Tịnh Đạo',
      'order_index': 0,
      'metadata_json': null,
    });
    await db.insert('tipitaka_books', {
      'id': 3,
      'collection_id': 3,
      'code': 'VIN01M_MUL',
      'name_pali': 'Vinaya',
      'name_en': 'Vinaya Basket',
      'name_vi': 'Tạng Luật',
      'order_index': 0,
      'metadata_json': null,
    });
    await db.insert('tipitaka_books', {
      'id': 4,
      'collection_id': 4,
      'code': 'ABH01M_MUL',
      'name_pali': 'Abhidhamma',
      'name_en': 'Abhidhamma Basket',
      'name_vi': 'Tạng Vi Diệu Pháp',
      'order_index': 0,
      'metadata_json': null,
    });
    await db.insert('tipitaka_segments', {
      'id': 1,
      'book_id': 1,
      'reference': 'DEMO 1',
      'paragraph_no': 1,
      'block_type': 'paragraph',
      'pali_text': 'Demo sample text',
      'translation_en': 'Demo sample translation',
      'translation_vi': 'Bản dịch mẫu demo',
      'order_index': 0,
    });
    await db.insert('tipitaka_segments', {
      'id': 2,
      'book_id': 2,
      'reference': 'VM 0',
      'paragraph_no': 1,
      'block_type': 'center',
      'pali_text': 'Namo Tassa Bhagavato Arahato Sammāsambuddhassa',
      'translation_en': '',
      'translation_vi': '',
      'order_index': 0,
    });
    await db.insert('tipitaka_segments', {
      'id': 4,
      'book_id': 2,
      'reference': 'VM 0 heading',
      'paragraph_no': 1,
      'block_type': 'book',
      'pali_text': 'Namo Tassa Bhagavato Arahato Sammāsambuddhassa',
      'translation_en': 'Namo Tassa Bhagavato Arahato Sammāsambuddhassa',
      'translation_vi': '',
      'order_index': 0,
    });
    await db.insert('tipitaka_segments', {
      'id': 3,
      'book_id': 2,
      'reference': 'VM 1',
      'paragraph_no': 2,
      'block_type': 'book',
      'pali_text': '<p rend="book">Visuddhimagga</p>',
      'translation_en': '<p rend="book">Path of Purification</p>',
      'translation_vi': '<p rend="book">Thanh Tịnh Đạo</p>',
      'order_index': 1,
    });
    await db.insert('tipitaka_segments', {
      'id': 5,
      'book_id': 3,
      'reference': 'VIN 1',
      'paragraph_no': 1,
      'block_type': 'paragraph',
      'pali_text': 'Vinaya text',
      'translation_en': 'Discipline text',
      'translation_vi': 'Luật tạng',
      'order_index': 0,
    });
    await db.insert('tipitaka_segments', {
      'id': 6,
      'book_id': 4,
      'reference': 'ABH 1',
      'paragraph_no': 1,
      'block_type': 'paragraph',
      'pali_text': 'Abhidhamma text',
      'translation_en': 'Higher doctrine text',
      'translation_vi': 'Vi diệu pháp',
      'order_index': 0,
    });
    for (final highlight in [
      {'id': 1, 'book_id': 1, 'segment_id': 1},
      {'id': 2, 'book_id': 2, 'segment_id': 3},
    ]) {
      await db.insert('tipitaka_highlights', {
        ...highlight,
        'color': 'yellow',
        'note': '',
        'updated_at': 1,
      });
    }
  }

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await createSchema();
  });

  tearDown(() async {
    await db.close();
  });

  test('real catalogue hides bundled demo without hiding Sutta in a legacy demo collection',
      () async {
    await db.update(
      'tipitaka_collections',
      {'name_en': 'Demo Sutta Piṭaka'},
      where: 'id = ?',
      whereArgs: [2],
    );
    final collections = await TipitakaDb.getCollections(db);
    expect(collections.map((item) => item.id), [2, 3, 4]);
    final indexBooks = await TipitakaDb.getCatalogIndexBooks(db);
    expect(indexBooks.map((item) => item.id), [2, 3, 4]);
    expect(
      indexBooks.singleWhere((item) => item.id == 2).catalogSection,
      TipitakaCatalogSection.extraCanonical,
    );
    expect(await TipitakaDb.getBooksByCollection(db, 1), isEmpty);
    expect((await TipitakaDb.getBooksByCollection(db, 3)).single.code,
        'VIN01M_MUL');
    expect((await TipitakaDb.getBooksByCollection(db, 4)).single.code,
        'ABH01M_MUL');
    expect(await TipitakaDb.getBookById(db, 1), isNull);

    final books = await TipitakaDb.getBooksByCollection(db, 2, languageCode: 'vi');
    expect(books, hasLength(1));
    expect(books.single.displayTitle('vi'), 'Thanh Tịnh Đạo');

    final outline = await TipitakaDb.getBookOutline(db, 2);
    expect(outline.map((item) => item.id), [3]);
    expect(outline.any((item) => item.canonicalPaliText.contains('Namo Tassa')),
        isFalse);

    expect(await TipitakaDb.searchSegments(db, 'Demo sample'), isEmpty);
    expect(await TipitakaDb.getHighlights(db), hasLength(1));
    expect((await TipitakaDb.getHighlights(db)).single.bookId, 2);
  });

  test('demo remains visible when it is the only available fallback', () async {
    await db.delete('tipitaka_books', where: 'id = ?', whereArgs: [2]);
    await db.delete('tipitaka_books', where: 'id IN (?, ?)', whereArgs: [3, 4]);
    await db.delete('tipitaka_collections',
        where: 'id IN (?, ?, ?)', whereArgs: [2, 3, 4]);

    final collections = await TipitakaDb.getCollections(db);
    expect(collections.map((item) => item.id), [1]);
    final books = await TipitakaDb.getBooksByCollection(db, 1);
    expect(books.map((item) => item.id), [1]);
  });
}
