// I4U TIPI-PERF-01 — Tipiṭaka must open fast on demo data *and* on a merged
// multi-language canon.
//
// Two regressions are pinned here:
//  1. The catalogue title subqueries (four correlated `ORDER BY … LIMIT 1`
//     scans per book) must keep producing exactly the same titles they always
//     did, now that they are resolved once per book and skipped when the
//     database has no structural headings at all.
//  2. `openReady`'s usability probe must stay O(1) (EXISTS), not O(rows), and
//     the reader's paging index must be creatable on demand.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('tipitaka_perf_test');
    databasePath = '${directory.path}/tipitaka.sqlite';
    await TipitakaDb.close();
  });

  tearDown(() async {
    await TipitakaDb.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<Database> createDatabase({
    required List<String> segmentBlockTypes,
  }) async {
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    await raw.execute('''
      CREATE TABLE tipitaka_collections (
        id INTEGER PRIMARY KEY, name_pali TEXT, name_en TEXT, name_vi TEXT,
        order_index INTEGER
      )
    ''');
    await raw.execute('''
      CREATE TABLE tipitaka_books (
        id INTEGER PRIMARY KEY, collection_id INTEGER, code TEXT,
        name_pali TEXT, name_en TEXT, name_vi TEXT, order_index INTEGER,
        metadata_json TEXT
      )
    ''');
    await raw.execute('''
      CREATE TABLE tipitaka_segments (
        id INTEGER PRIMARY KEY, book_id INTEGER, section_id INTEGER,
        reference TEXT, paragraph_no INTEGER, block_type TEXT, pali_text TEXT,
        translation_en TEXT, translation_vi TEXT, translation_my TEXT,
        translation_th TEXT, order_index INTEGER
      )
    ''');
    await raw.execute('''
      CREATE TABLE tipitaka_translations (
        segment_id INTEGER, language_code TEXT, text TEXT,
        PRIMARY KEY (segment_id, language_code)
      )
    ''');
    await raw.insert('tipitaka_collections', {
      'id': 1,
      'name_pali': 'Sutta Piṭaka',
      'name_en': 'Sutta Piṭaka',
      'name_vi': 'Tạng Kinh',
      'order_index': 1,
    });
    await raw.insert('tipitaka_books', {
      'id': 1,
      'collection_id': 1,
      'code': 'MN01M_MUL',
      'name_pali': 'Majjhima Nikāya',
      'name_en': 'Middle Length Discourses',
      'name_vi': 'Trung Bộ Kinh',
      'order_index': 0,
    });
    // A structural heading row, exactly what the catalogue resolves titles
    // from, followed by ordinary paragraphs.
    await raw.insert('tipitaka_segments', {
      'id': 1,
      'book_id': 1,
      'reference': 'MN 1',
      'paragraph_no': 0,
      'block_type': segmentBlockTypes.first,
      'pali_text': 'Majjhima Nikāya',
      'translation_en': 'Middle Length Discourses',
      'translation_vi': 'Trung Bộ Kinh',
      'order_index': 0,
    });
    for (var index = 1; index < segmentBlockTypes.length; index++) {
      await raw.insert('tipitaka_segments', {
        'id': index + 1,
        'book_id': 1,
        'reference': 'MN ${index + 1}',
        'paragraph_no': index,
        'block_type': segmentBlockTypes[index],
        'pali_text': 'Evaṃ me sutaṃ $index',
        'translation_en': 'Thus have I heard $index',
        'translation_vi': 'Ta đã nghe như vầy $index',
        'order_index': index,
      });
    }
    await raw.insert('tipitaka_translations', {
      'segment_id': 1,
      'language_code': 'fr',
      'text': 'Majjhima Nikāya (français)',
    });
    await raw.close();
    return TipitakaDb.openAt(databasePath);
  }

  test('catalogue titles keep resolving from structural headings', () async {
    final db = await createDatabase(
      segmentBlockTypes: ['book', 'paragraph', 'paragraph'],
    );

    final viBooks = await TipitakaDb.getBooksByCollection(
      db,
      1,
      languageCode: 'vi',
    );
    final book = viBooks.single;
    expect(book.contentTitlePali, 'Majjhima Nikāya');
    expect(book.contentTitleEn, 'Middle Length Discourses');
    expect(book.contentTitleVi, 'Trung Bộ Kinh');
    expect(book.contentTitleLocale, 'Trung Bộ Kinh');
    expect(book.displayTitle('vi'), 'Trung Bộ Kinh');

    final enBooks = await TipitakaDb.getBooksByCollection(
      db,
      1,
      languageCode: 'en',
    );
    expect(enBooks.single.contentTitleLocale, 'Middle Length Discourses');

    // A language with no fixed column resolves through the dynamic pack.
    final frBooks = await TipitakaDb.getBooksByCollection(
      db,
      1,
      languageCode: 'fr',
    );
    expect(frBooks.single.contentTitleLocale, 'Majjhima Nikāya (français)');

    // Deep-link lookup must agree with the tree.
    final byId = await TipitakaDb.getBookById(db, 1, languageCode: 'vi');
    expect(byId, isNotNull);
    expect(byId!.contentTitleLocale, 'Trung Bộ Kinh');
    expect(byId.displayTitle('vi'), 'Trung Bộ Kinh');
  });

  test('flat databases skip title subqueries but keep book names', () async {
    final db = await createDatabase(
      segmentBlockTypes: ['paragraph', 'paragraph', 'paragraph'],
    );

    final books = await TipitakaDb.getBooksByCollection(
      db,
      1,
      languageCode: 'vi',
    );
    final book = books.single;
    expect(book.contentTitleLocale, isEmpty);
    expect(book.contentTitlePali, isEmpty);
    // Fallback order is unchanged: content title → name_vi.
    expect(book.displayTitle('vi'), 'Trung Bộ Kinh');
    expect(book.displayTitle('en'), 'Middle Length Discourses');
  });

  test('language detection is memoised and matches the raw database', () async {
    final db = await createDatabase(
      segmentBlockTypes: ['book', 'paragraph', 'paragraph'],
    );

    final languages = await TipitakaDb.availableLanguages(db);
    expect(languages, containsAll(<String>['pi', 'en', 'vi', 'fr']));
    expect(languages, isNot(contains('my')));

    // Second call must be served from the cache (same instance, same set).
    final again = await TipitakaDb.availableLanguages(db);
    expect(again, languages);

    // `info()` must agree and still report exact counts.
    final info = await TipitakaDb.info(db);
    expect(info.availableLanguages, languages);
    expect(info.segmentCount, 3);
    expect(info.bookCount, 1);
    expect(info.collectionCount, 1);
    expect(info.isReady, isTrue);
  });

  test('reader paging index can be built on an existing database', () async {
    final db = await createDatabase(
      segmentBlockTypes: ['book', 'paragraph', 'paragraph'],
    );
    await TipitakaDb.ensurePerformanceIndexes(db, force: true);
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'idx_segments_book_order'",
    );
    expect(indexes, hasLength(1));

    // Paging still returns rows in reading order with the index in place.
    final page = await TipitakaDb.getSegmentsByBook(db, 1, limit: 2);
    expect(page.map((item) => item.id), [1, 2]);
  });

  test('open path uses O(1) probes and a cached readiness fingerprint', () {
    final source = File('lib/features/tipitaka/services/db_service.dart')
        .readAsStringSync();
    // Presence checks must not count every segment row.
    expect(
      source,
      contains("SELECT 1 FROM tipitaka_segments LIMIT 1"),
      reason: 'Usability probe reverted to COUNT(*) — full scan on a canon.',
    );
    expect(source, contains('_verifiedFingerprint'));
    expect(source, contains('static Future<String> fileFingerprint'));
    expect(source, contains('static Future<bool> prewarm()'));
    expect(source, contains('idx_segments_book_order'));
    // The old one-shot catalogue query must not come back.
    expect(
      source.contains('final arguments = <Object?>[language, collectionId];'),
      isFalse,
      reason: 'getBooksByCollection is back to per-book correlated subqueries '
          'in a single statement.',
    );
  });

  test('library paints from a fingerprint snapshot before opening SQLite', () {
    final source =
        File('lib/features/tipitaka/screens/library_screen.dart').readAsStringSync();
    expect(source, contains('TipitakaDb.fileFingerprint()'));
    expect(source, contains('_refreshing'));
    expect(source, contains('availableLanguages'));
  });
}
