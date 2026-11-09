// PSRC-160 — Tipiṭaka cho phép thêm DB nhưng chưa có cơ chế xóa. Test khoá
// 3 hợp đồng: (1) xóa 1 gói ngôn ngữ giữ nguyên Pāli + gói khác, (2) xóa toàn
// bộ DB + sidecar, (3) lịch sử import ghi nhận đúng mã gói để quản lý/import lại.
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

  Future<void> createTarget() async {
    final db = await databaseFactoryFfi.openDatabase(targetPath);
    await db.execute('''
      CREATE TABLE tipitaka_import_history (
        source_sha256 TEXT PRIMARY KEY,
        source_name TEXT NOT NULL DEFAULT '',
        language_code TEXT NOT NULL DEFAULT '',
        imported_at INTEGER NOT NULL,
        imported_rows INTEGER NOT NULL DEFAULT 0
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
      'name_pali': 'Mūlapariyāyasuttaṃ',
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
      'block_type': 'paragraph',
      'pali_text': 'Evaṃ me sutaṃ.',
      'translation_vi': 'Ta đã nghe như vầy.',
      'order_index': 0,
    });
    await db.insert('tipitaka_translations', {
      'segment_id': 1,
      'language_code': 'zh_TW',
      'text': '如是我聞',
    });
    await db.insert('tipitaka_import_history', {
      'source_sha256': 'hash-vi',
      'source_name': 'tipitaka_vietnamese.db',
      'language_code': 'vi',
      'imported_at': 1000,
      'imported_rows': 1,
    });
    await db.insert('tipitaka_import_history', {
      'source_sha256': 'hash-pi',
      'source_name': 'tipitaka_pali.db',
      'language_code': 'pi',
      'imported_at': 900,
      'imported_rows': 1,
    });
    await db.insert('tipitaka_import_history', {
      'source_sha256': 'hash-legacy',
      'source_name': 'old_unknown.db',
      'language_code': '',
      'imported_at': 800,
      'imported_rows': 1,
    });
    await db.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('in4up-db-removal-');
    targetPath = '${directory.path}/tipitaka.sqlite';
    await createTarget();
  });

  tearDown(() async {
    await TipitakaDb.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('xóa gói tiếng Việt giữ Pāli, gói khác và lịch sử Pāli', () async {
    final revision = TipitakaDb.importRevision.value;
    final removed = await TipitakaDb.deleteLanguagePack(
      'vi',
      destinationPath: targetPath,
    );
    expect(removed.removedTranslations, greaterThan(0));
    expect(removed.removedImports, 1); // only the vi row; legacy/Pāli kept
    expect(TipitakaDb.importRevision.value, revision + 1);

    final db = await TipitakaDb.openAt(targetPath);
    final segments = await TipitakaDb.getSegmentsByBook(db, 1);
    expect(segments.single.canonicalPaliText, 'Evaṃ me sutaṃ.');
    expect(segments.single.translationFor('vi'), isEmpty);
    expect(segments.single.translationFor('zh-TW'), '如是我聞');
    final history = await TipitakaDb.importHistory(db);
    final hashes = history.map((item) => item.sourceSha256).toList();
    expect(hashes, isNot(contains('hash-vi')));
    expect(hashes, contains('hash-pi'));
    expect(hashes, contains('hash-legacy'));
    expect(history.first.languageCode, 'pi');
  });

  test('xóa gói động zh_TW chỉ xóa đúng bản dịch động', () async {
    await TipitakaDb.deleteLanguagePack(
      'zh_TW',
      destinationPath: targetPath,
    );
    final db = await TipitakaDb.openAt(targetPath);
    final segments = await TipitakaDb.getSegmentsByBook(db, 1);
    expect(segments.single.translationFor('zh-TW'), isEmpty);
    expect(segments.single.translationFor('vi'), 'Ta đã nghe như vầy.');
  });

  test('import ghi mã gói vào lịch sử để quản lý/xóa sau này', () async {
    final sourcePath = '${directory.path}/tipitaka_english.sqlite';
    final source = await databaseFactoryFfi.openDatabase(sourcePath);
    await source.execute('''
      CREATE TABLE mn02m_mul (
        id INTEGER PRIMARY KEY,
        reference TEXT NOT NULL,
        english TEXT NOT NULL
      )
    ''');
    await source.insert('mn02m_mul', {
      'id': 1,
      'reference': 'MN 2',
      'english': 'Thus have I heard.',
    });
    await source.close();

    await TipitakaDb.importSourceDatabase(
      sourcePath,
      languageCode: 'en',
      destinationPath: targetPath,
    );
    final db = await TipitakaDb.openAt(targetPath);
    final history = await TipitakaDb.importHistory(db);
    expect(history.any((item) => item.languageCode == 'en'), isTrue);
  });

  test('xóa toàn bộ DB dọn cả backup, swap và file import dở', () async {
    for (final suffix in const ['.bak', '.swap', '.part', '.importing-123']) {
      await File('$targetPath$suffix').writeAsString('stale');
    }
    final revision = TipitakaDb.importRevision.value;
    final removed = await TipitakaDb.deleteDatabase(
      destinationPath: targetPath,
    );
    expect(await File(targetPath).exists(), isFalse);
    for (final suffix in const ['.bak', '.swap', '.part', '.importing-123']) {
      expect(await File('$targetPath$suffix').exists(), isFalse);
    }
    expect(removed.removedFiles, 5);
    expect(removed.removedBytes, greaterThan(0));
    expect(removed.isEmpty, isFalse);
    expect(TipitakaDb.importRevision.value, revision + 1);
  });

  test('data manager có đủ 3 thao tác quản lý DB', () {
    final service = File('lib/features/tipitaka/services/db_service.dart')
        .readAsStringSync();
    final screen = File('lib/features/tipitaka/screens/download_screen.dart')
        .readAsStringSync();
    for (final symbol in const [
      'deleteDatabase(',
      'deleteLanguagePack(',
      'restoreBundledDemo(',
      'isBundledDemoDisabled()',
      'purgeDemoData(',
    ]) {
      expect(service, contains(symbol), reason: 'Thiếu API $symbol');
    }
    // Xóa phải dính: không được tự nạp lại bản demo ở lần mở sau.
    expect(service, contains('_demoDisabledMarker'));
    expect(service, contains('_disableBundledDemo()'));
    expect(service, contains('_clearBundledDemoMarker()'));
    expect(
      service,
      contains('if (!force && await isBundledDemoDisabled()) return null;'),
    );
    for (final label in const [
      'Xóa toàn bộ cơ sở dữ liệu',
      'Xóa gói ngôn ngữ',
      'Dọn bản Demo',
      'Khôi phục bản mẫu',
    ]) {
      expect(screen, contains(label), reason: 'Thiếu nút $label');
    }
  });
}
