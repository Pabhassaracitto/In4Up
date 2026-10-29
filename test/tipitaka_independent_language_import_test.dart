import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_markup.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/models/tipitaka_source_anchor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late String targetPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'in4up-tipitaka-import-',
    );
    targetPath = '${temporaryDirectory.path}/installed.sqlite';
  });

  tearDown(() async {
    await TipitakaDb.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<String> createSource({
    required String filename,
    required String textColumn,
    required List<String> texts,
  }) async {
    final path = '${temporaryDirectory.path}/$filename';
    final db = await databaseFactoryFfi.openDatabase(path);
    await db.execute('''
      CREATE TABLE mn01m_mul (
        id INTEGER PRIMARY KEY,
        reference TEXT NOT NULL,
        $textColumn TEXT NOT NULL
      )
    ''');
    for (var index = 0; index < texts.length; index++) {
      await db.insert('mn01m_mul', {
        'id': index + 1,
        'reference': 'MN ${index + 1}',
        textColumn: texts[index],
      });
    }
    await db.close();
    return path;
  }

  test('detects Vietnamese from the source schema when the DB was renamed',
      () async {
    final path = await createSource(
      filename: 'renamed-download.db',
      textColumn: 'vietnamese',
      texts: const [
        '<p rend="book">Bài kinh tiếng Việt</p>',
        'Nội dung đọc được.',
      ],
    );
    await TipitakaDb.importSourceDatabase(path, destinationPath: targetPath);
    final db = await TipitakaDb.openAt(targetPath);
    final info = await TipitakaDb.info(db);
    expect(info.availableLanguages, contains('vi'));
    final collections = await TipitakaDb.getCollections(db);
    final books = await TipitakaDb.getBooksByCollection(
      db,
      collections.single.id,
      languageCode: 'vi',
    );
    expect(books.single.displayTitle('vi'), 'Bài kinh tiếng Việt');
  });

  test('Vietnamese imports and reads before Pāli, then Pāli enriches it',
      () async {
    final vietnamesePath = await createSource(
      filename: 'tipitaka_vietnamese.sqlite',
      textColumn: 'vietnamese',
      texts: const [
        '<p rend="book">Kinh Mẫu Tiếng Việt</p>',
        'Đây là nội dung có thể đọc mà không cần Pāli.',
      ],
    );

    await TipitakaDb.importSourceDatabase(
      vietnamesePath,
      languageCode: 'vi',
      destinationPath: targetPath,
    );

    var db = await TipitakaDb.openAt(targetPath);
    var info = await TipitakaDb.info(db);
    expect(info.availableLanguages, contains('vi'));
    expect(info.availableLanguages, isNot(contains('pi')));

    final collections = await TipitakaDb.getCollections(db);
    expect(collections, hasLength(1));
    var books = await TipitakaDb.getBooksByCollection(db, collections.single.id);
    expect(books, hasLength(1));
    expect(books.single.displayTitle('vi'), 'Kinh Mẫu Tiếng Việt');
    expect(books.single.displayTitle('vi'), isNot('MN01M_MUL'));

    var segments = await TipitakaDb.getSegmentsByBook(db, books.single.id);
    expect(segments, hasLength(2));
    expect(segments.last.paliText, isEmpty);
    expect(
      segments.last.translationFor('vi'),
      'Đây là nội dung có thể đọc mà không cần Pāli.',
    );

    await TipitakaDb.close();
    final paliPath = await createSource(
      filename: 'tipitaka_pali.sqlite',
      textColumn: 'pali_text',
      texts: const [
        '<p rend="book">Mūlapariyāyasuttaṃ</p>',
        'Evaṃ me sutaṃ.',
      ],
    );
    await TipitakaDb.importSourceDatabase(
      paliPath,
      languageCode: 'pi',
      destinationPath: targetPath,
    );

    db = await TipitakaDb.openAt(targetPath);
    info = await TipitakaDb.info(db);
    expect(info.availableLanguages, containsAll(<String>['pi', 'vi']));

    books = await TipitakaDb.getBooksByCollection(db, collections.single.id);
    segments = await TipitakaDb.getSegmentsByBook(db, books.single.id);
    expect(segments, hasLength(2));
    expect(segments.last.paliText, 'Evaṃ me sutaṃ.');
    expect(
      segments.last.translationFor('vi'),
      'Đây là nội dung có thể đọc mà không cần Pāli.',
    );
  });

  test('Vietnamese joins Pāli when source table casing and numeric IDs differ',
      () async {
    final paliPath = '${temporaryDirectory.path}/tipitaka_pali_base.sqlite';
    final pali = await databaseFactoryFfi.openDatabase(paliPath);
    await pali.execute('''
      CREATE TABLE MN01M_MUL (
        id INTEGER PRIMARY KEY,
        reference TEXT NOT NULL,
        pali_text TEXT NOT NULL
      )
    ''');
    await pali.insert('MN01M_MUL', {
      'id': 1,
      'reference': 'MN 1',
      'pali_text': 'Evaṃ me sutaṃ.',
    });
    await pali.close();
    await TipitakaDb.importSourceDatabase(
      paliPath,
      languageCode: 'pi',
      destinationPath: targetPath,
    );

    final vietnamesePath = '${temporaryDirectory.path}/tipitaka_vietnamese.sqlite';
    final vietnamese = await databaseFactoryFfi.openDatabase(vietnamesePath);
    await vietnamese.execute('''
      CREATE TABLE mn01m_mul (
        id TEXT PRIMARY KEY,
        reference TEXT NOT NULL,
        vietnamese TEXT NOT NULL
      )
    ''');
    await vietnamese.insert('mn01m_mul', {
      'id': '0001',
      'reference': 'different reference forces the source-key join',
      'vietnamese': 'Nội dung tiếng Việt đã khớp.',
    });
    await vietnamese.close();

    final revisionBefore = TipitakaDb.importRevision.value;
    await TipitakaDb.importSourceDatabase(
      vietnamesePath,
      languageCode: 'vi',
      destinationPath: targetPath,
    );
    expect(TipitakaDb.importRevision.value, revisionBefore + 1);

    final db = await TipitakaDb.openAt(targetPath);
    final collections = await TipitakaDb.getCollections(db);
    final books = await TipitakaDb.getBooksByCollection(
      db,
      collections.single.id,
    );
    final segments = await TipitakaDb.getSegmentsByBook(db, books.single.id);
    expect(segments, hasLength(1));
    expect(segments.single.paliText, 'Evaṃ me sutaṃ.');
    expect(
      segments.single.translationFor('vi'),
      'Nội dung tiếng Việt đã khớp.',
    );
  });

  test('normalized one-book DB merges transactionally and repeated import is idempotent', () async {
    final basePath = await createSource(
      filename: 'tipitaka_base_en.sqlite',
      textColumn: 'english',
      texts: const ['<p rend="book">Base book</p>', 'Base paragraph.'],
    );
    await TipitakaDb.importSourceDatabase(
      basePath,
      languageCode: 'en',
      destinationPath: targetPath,
    );

    final personalPath = '${temporaryDirectory.path}/personal-book.sqlite';
    final personal = await databaseFactoryFfi.openDatabase(personalPath);
    await personal.execute('''
      CREATE TABLE tipitaka_collections (
        id INTEGER PRIMARY KEY, name_pali TEXT, name_en TEXT, name_vi TEXT,
        order_index INTEGER
      )
    ''');
    await personal.execute('''
      CREATE TABLE tipitaka_books (
        id INTEGER PRIMARY KEY, collection_id INTEGER, code TEXT, name_pali TEXT,
        name_en TEXT, name_vi TEXT, order_index INTEGER, metadata_json TEXT
      )
    ''');
    await personal.execute('''
      CREATE TABLE tipitaka_segments (
        id INTEGER PRIMARY KEY, book_id INTEGER, section_id INTEGER,
        reference TEXT, paragraph_no INTEGER, block_type TEXT, pali_text TEXT,
        translation_en TEXT, translation_vi TEXT, translation_my TEXT,
        translation_th TEXT, source_table TEXT, source_row_key TEXT,
        order_index INTEGER
      )
    ''');
    await personal.execute('''
      CREATE TABLE tipitaka_translations (
        segment_id INTEGER, language_code TEXT, text TEXT,
        PRIMARY KEY(segment_id, language_code)
      )
    ''');
    await personal.insert('tipitaka_collections', {
      'id': 7, 'name_pali': 'Sutta', 'name_en': 'Sutta Piṭaka',
      'name_vi': 'Tạng Kinh', 'order_index': 1,
    });
    await personal.insert('tipitaka_books', {
      'id': 70, 'collection_id': 7, 'code': 'SN99M_MUL',
      'name_pali': 'Personal Pāḷi book', 'name_en': 'Personal English book',
      'name_vi': 'Sách riêng', 'order_index': 1,
      'metadata_json': '{"source_table":"sn99m_mul"}',
    });
    await personal.insert('tipitaka_segments', {
      'id': 700, 'book_id': 70, 'reference': 'SN 99',
      'paragraph_no': 1, 'block_type': 'paragraph',
      'pali_text': 'Evaṃ me sutaṃ.', 'translation_en': '',
      'translation_vi': '', 'translation_my': '', 'translation_th': '',
      'source_table': 'sn99m_mul', 'source_row_key': '0001', 'order_index': 0,
    });
    await personal.insert('tipitaka_translations', {
      'segment_id': 700, 'language_code': 'zh_TW', 'text': '繁體中文段落',
    });
    await personal.insert('tipitaka_translations', {
      'segment_id': 700, 'language_code': 'pi', 'text': 'Evaṃ me sutaṃ.',
    });
    await personal.close();

    await TipitakaDb.installDatabaseFile(personalPath, destinationPath: targetPath);
    final afterFirstImport = await TipitakaDb.openAt(targetPath);
    final firstInfo = await TipitakaDb.info(afterFirstImport);
    expect(firstInfo.bookCount, 2);
    expect(firstInfo.segmentCount, 3);
    expect(firstInfo.availableLanguages, containsAll(['zh-tw', 'pi']));
    final personalBook = (await TipitakaDb.getCatalogIndexBooks(afterFirstImport))
        .singleWhere((book) => book.code == 'SN99M_MUL');
    final personalSegments = await TipitakaDb.getSegmentsByBook(
      afterFirstImport,
      personalBook.id,
    );
    expect(personalSegments.single.translationFor('zh-TW'), '繁體中文段落');
    expect(personalSegments.single.canonicalPaliText, 'Evaṃ me sutaṃ.');

    final revision = TipitakaDb.importRevision.value;
    await TipitakaDb.close();
    await TipitakaDb.installDatabaseFile(personalPath, destinationPath: targetPath);
    final afterSecondImport = await TipitakaDb.openAt(targetPath);
    final secondInfo = await TipitakaDb.info(afterSecondImport);
    expect(secondInfo.bookCount, firstInfo.bookCount);
    expect(secondInfo.segmentCount, firstInfo.segmentCount);
    expect(TipitakaDb.importRevision.value, revision);
  });

  test('markup cleaner handles literal and escaped CSCD block tags', () {
    expect(cleanTipitakaText('<p rend="book">Mahavamsapali</p>'), 'Mahavamsapali');
    expect(
      cleanTipitakaText('&lt;p rend="book"&gt;Mahavamsapali&lt;/p&gt;'),
      'Mahavamsapali',
    );
  });

  test('raw book title markup is stripped before it reaches the catalogue', () {
    const book = TipitakaBook(
      id: 9,
      collectionId: 1,
      code: 'MAHAVAMSA',
      namePali: '<p rend="book">Mahavamsapali</p>',
      nameEn: '',
      nameVi: '',
      orderIndex: 0,
    );
    expect(book.displayTitle('en'), 'Mahavamsapali');
  });

  test('dynamic language translations are case-insensitive and flexible', () {
    final segment = TipitakaSegment(
      id: 1,
      bookId: 1,
      reference: 'MN 1',
      paliText: '',
      orderIndex: 0,
      translations: const {'vi': 'Bản dịch', 'zh_TW': '繁體中文'},
    );
    expect(segment.translationFor('VI'), 'Bản dịch');
    expect(segment.translationFor('zh-TW'), '繁體中文');
  });

  test('technical identifiers are never primary book titles', () {
    const book = TipitakaBook(
      id: 1,
      collectionId: 1,
      code: 'ABH01A_ATT',
      namePali: 'ABH01A_ATT',
      nameEn: 'ABH01A_ATT',
      nameVi: 'ABH01A_ATT',
      orderIndex: 0,
      contentTitleVi: 'Pháp Tụ Luận',
    );

    expect(book.displayTitle('vi'), 'Pháp Tụ Luận');
    expect(book.catalogIndex.normalizedCode, 'ABH01A_ATT');
  });

  test('Learn by Heart round-trip keeps its durable Tipiṭaka source link', () {
    final capturedAt = DateTime.utc(2026, 9, 30);
    final anchor = TipitakaSourceAnchor(
      sourceDatabaseId: 'tipitaka:test',
      bookId: 7,
      bookCode: 'MN01M_MUL',
      segmentId: 11,
      reference: 'MN 1',
      paragraphNo: 1,
      startOffset: 0,
      endOffset: 18,
      selectedText: 'Bản dịch độc lập',
      sourceTable: 'mn01m_mul',
      sourceRowKey: '1',
    );
    final snapshot = TipitakaContextSnapshot(
      paliText: '',
      translationText: 'Bản dịch độc lập',
      translationLanguage: 'vi',
      capturedAt: capturedAt,
    );
    final item = LearnByHeartItem(
      id: 'tipitaka-7-11',
      title: 'Kinh Mẫu Tiếng Việt',
      paliText: '',
      vietnameseText: 'Bản dịch độc lập',
      sourceAnchor: anchor,
      contextSnapshot: snapshot,
      createdAt: capturedAt,
    );

    final restored = LearnByHeartItem.fromJson(item.toJson());
    expect(restored.sourceAnchor?.stableKey, anchor.stableKey);
    expect(restored.sourceAnchor?.sourceRowKey, '1');
    expect(restored.contextSnapshot?.translationText, 'Bản dịch độc lập');
  });
}
