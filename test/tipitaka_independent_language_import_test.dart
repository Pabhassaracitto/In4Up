import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
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
