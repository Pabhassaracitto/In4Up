// lib/features/dictionary/services/dict_sqlite_importer.dart
//
// DICT-SQLITE-001 (2026-10-28) — import từ điển dạng **file SQLite**
// (`.db`, `.sqlite`, `.sqlite3`) thay vì chỉ `.mdx`.
//
// Vì sao cần: trước bản này đường import CHỈ nhận MDict (`.mdx` + `.mdd` +
// `.css`). Người dùng có sẵn `*.db` (GoldenDict/StarDict-Wiktionary export,
// hoặc chính file `.dict.sqlite` app này từng sinh ra) bấm "Import" thì
// **file bị bộ chọn lọc bỏ ngay từ đầu** — không có thông báo nào, chỉ thấy
// "không chọn được file".
//
// Thiết kế:
//   * KHÔNG đoán mò schema: đọc `sqlite_master` + `PRAGMA table_info` rồi
//     chấm điểm tên bảng/cột theo bảng từ khoá phổ biến.
//   * `pickDefinitionMapping()` là hàm THUẦN (không I/O) ⇒ test được trên
//     host VM, và là nơi duy nhất chứa luật đoán.
//   * Dữ liệu được chép sang index NỘI BỘ của app (`dict_entries`), không
//     sửa file nguồn (mở read-only) và không giữ đường dẫn tới nguồn ⇒ xoá
//     file nguồn sau đó vẫn tra được.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'dict_database_platform.dart';
import 'dict_db_service.dart';

/// Một bảng trong file SQLite nguồn (tên + cột + số dòng ước lượng).
class SqliteSourceTable {
  const SqliteSourceTable({
    required this.name,
    required this.columns,
    this.rowCount = 0,
  });

  final String name;
  final List<String> columns;
  final int rowCount;

  @override
  String toString() => 'SqliteSourceTable($name, $columns, $rowCount)';
}

/// Ánh xạ đã chọn: bảng nào, cột nào là từ khoá / nghĩa / phiên âm / loại từ.
class SqliteDefinitionMapping {
  const SqliteDefinitionMapping({
    required this.table,
    required this.headwordColumn,
    required this.definitionColumn,
    this.phoneticColumn,
    this.partOfSpeechColumn,
    required this.confidence,
  });

  final String table;
  final String headwordColumn;
  final String definitionColumn;
  final String? phoneticColumn;
  final String? partOfSpeechColumn;

  /// 0–100 — dùng để chọn giữa nhiều bảng và để UI nói mức tin cậy.
  final int confidence;

  bool get isConfident => confidence >= 60;

  @override
  String toString() => 'SqliteDefinitionMapping($table.$headwordColumn → '
      '$definitionColumn, confidence=$confidence)';
}

/// Cột được coi là "từ khoá" (xếp theo độ ưu tiên giảm dần).
const List<String> _headwordNames = [
  'headword',
  'word',
  'term',
  'keyword',
  'entry',
  'title',
  'lemma',
  'key',
  'spelling',
  'form',
  'name',
  'vocab',
  'source',
];

/// Cột được coi là "nghĩa" (xếp theo độ ưu tiên giảm dần).
const List<String> _definitionNames = [
  'definition',
  'meaning',
  'def',
  'gloss',
  'translation',
  'explanation',
  'content',
  'body',
  'html',
  'value',
  'text',
  'description',
  'detail',
  'note',
];

const List<String> _phoneticNames = [
  'phonetic',
  'ipa',
  'pronunciation',
  'pron',
  'pinyin',
  'reading',
];

const List<String> _partOfSpeechNames = [
  'part_of_speech',
  'partofspeech',
  'pos',
  'wordtype',
  'word_type',
  'type',
  'category',
];

String _norm(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

int _rank(List<String> candidates, String column) {
  final norm = _norm(column);
  for (var i = 0; i < candidates.length; i++) {
    final c = _norm(candidates[i]);
    if (norm == c) return 100 - i;
  }
  for (var i = 0; i < candidates.length; i++) {
    final c = _norm(candidates[i]);
    if (norm.contains(c)) return 60 - i;
  }
  return 0;
}

/// Chọn bảng + cột để đọc entry.
///
/// Hàm THUẦN: input là danh sách bảng đã đọc metadata. Trả `null` khi
/// không có bảng nào dùng được (mọi bảng < 2 cột hoặc rỗng).
SqliteDefinitionMapping? pickDefinitionMapping(
  List<SqliteSourceTable> tables,
) {
  SqliteDefinitionMapping? best;
  var bestScore = 0;

  for (final table in tables) {
    if (table.columns.length < 2) continue;
    // Bảng hệ thống/sổ cái không phải dữ liệu tra cứu.
    final tableName = _norm(table.name);
    if (tableName.startsWith('sqlite') ||
        tableName == 'androidmetadata' ||
        tableName.startsWith('roommastertable')) {
      continue;
    }

    // Ưu tiên bảng có tên gợi ý (dict_entries/entries/words…).
    var tableBonus = 0;
    if (tableName.contains('dict') && tableName.contains('entr')) {
      tableBonus = 30;
    } else if (tableName.contains('entr')) {
      tableBonus = 20;
    } else if (tableName.contains('word') || tableName.contains('dict')) {
      tableBonus = 15;
    }

    String? headword;
    var headScore = 0;
    for (final column in table.columns) {
      final score = _rank(_headwordNames, column);
      if (score > headScore) {
        headScore = score;
        headword = column;
      }
    }

    String? definition;
    var defScore = 0;
    for (final column in table.columns) {
      if (column == headword) continue;
      final score = _rank(_definitionNames, column);
      if (score > defScore) {
        defScore = score;
        definition = column;
      }
    }

    // Không nhận ra tên cột nào: dùng 2 cột đầu (nhiều file .db cũ đặt cột
    // vô danh kiểu `c1`, `c2`) nhưng hạ độ tin cậy.
    var fallbackBonus = 0;
    if (headword == null || definition == null) {
      final textish = table.columns
          .where((c) => !_norm(c).contains('id'))
          .toList(growable: false);
      if (textish.length < 2) continue;
      headword ??= textish[0];
      definition ??= textish[1];
      headScore = headScore == 0 ? 10 : headScore;
      defScore = defScore == 0 ? 10 : defScore;
      fallbackBonus = 0;
    }

    // Cột ID tự tăng không bao giờ là từ khoá.
    if (_norm(headword) == 'id' || _norm(headword).endsWith('id')) {
      // Cho phép 'wordid'? Không — ID không phải chữ để tra.
      final textish = table.columns
          .where((c) => _norm(c) != 'id')
          .toList(growable: false);
      if (textish.isNotEmpty) headword = textish.first;
    }

    final score = headScore +
        defScore +
        tableBonus +
        fallbackBonus +
        // Bảng nhiều dòng thường là bảng chính (log10 để không lấn hết).
        (table.rowCount > 0 ? (table.rowCount.clamp(1, 1000000)).toString().length : 0);

    if (score > bestScore) {
      bestScore = score;
      best = SqliteDefinitionMapping(
        table: table.name,
        headwordColumn: headword,
        definitionColumn: definition,
        phoneticColumn: _firstMatch(table.columns, _phoneticNames),
        partOfSpeechColumn: _firstMatch(table.columns, _partOfSpeechNames),
        confidence: score.clamp(0, 100),
      );
    }
  }

  return best;
}

String? _firstMatch(List<String> columns, List<String> candidates) {
  for (final candidate in candidates) {
    for (final column in columns) {
      if (_norm(column) == _norm(candidate)) return column;
    }
  }
  return null;
}

/// Kết quả import 1 file SQLite.
class DictSqliteImportResult {
  const DictSqliteImportResult({
    required this.entryCount,
    required this.mapping,
    this.warning,
  });

  final int entryCount;
  final SqliteDefinitionMapping? mapping;

  /// Mã máy cho UI tự dịch: `no_table`, `empty`, `read_failed`.
  final String? warning;

  bool get isSuccess => entryCount > 0;
}

/// Đọc file SQLite nguồn (READ-ONLY) và chép entry sang index của app.
///
/// Không bao giờ ghi/sửa file nguồn. Bảng đích do [DictDbService] tạo với
/// schema `dict_entries` — cùng schema với MDX ⇒ phần tra cứu không cần biết
/// từ điển này có nguồn gốc là `.mdx` hay `.db`.
Future<DictSqliteImportResult> importSqliteDictionary({
  required String sourcePath,
  required String targetDbPath,
  required String dictId,
  void Function(double progress, String message)? onProgress,
}) async {
  ensureDictionaryDatabaseFactory();

  Database? source;
  try {
    source = await openDatabase(sourcePath, readOnly: true);
  } catch (_) {
    // Không mở được ⇒ có thể không phải SQLite (đuôi .db nhưng là DB khác,
    // vd Berkeley DB của StarDict). Báo mã rõ thay vì im lặng.
    return const DictSqliteImportResult(
      entryCount: 0,
      mapping: null,
      warning: 'read_failed',
    );
  }

  try {
    final tableRows = await source.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%'",
    );
    final tables = <SqliteSourceTable>[];
    for (final row in tableRows) {
      final name = row['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final info = await source.rawQuery(
        'PRAGMA table_info("${name.replaceAll('"', '""')}")',
      );
      final columns = <String>[
        for (final column in info)
          if (column['name'] != null) column['name'].toString(),
      ];
      if (columns.isEmpty) continue;
      int rowCount = 0;
      try {
        final countRows = await source.rawQuery(
          'SELECT COUNT(*) AS c FROM "${name.replaceAll('"', '""')}"',
        );
        rowCount = (countRows.first['c'] as num?)?.toInt() ?? 0;
      } catch (_) {
        // COUNT lỗi (view hỏng/quyền) — vẫn thử import.
      }
      tables.add(
        SqliteSourceTable(name: name, columns: columns, rowCount: rowCount),
      );
    }

    final mapping = pickDefinitionMapping(tables);
    if (mapping == null) {
      return const DictSqliteImportResult(
        entryCount: 0,
        mapping: null,
        warning: 'no_table',
      );
    }

    final escapedTable = mapping.table.replaceAll('"', '""');
    final head = mapping.headwordColumn.replaceAll('"', '""');
    final def = mapping.definitionColumn.replaceAll('"', '""');
    final phon = mapping.phoneticColumn?.replaceAll('"', '""');
    final pos = mapping.partOfSpeechColumn?.replaceAll('"', '""');

    final selectColumns = <String>[
      '"$head" AS headword',
      '"$def" AS definition',
      if (phon != null) '"$phon" AS phonetic',
      if (pos != null) '"$pos" AS part_of_speech',
    ].join(', ');

    const batchSize = 2000;
    var offset = 0;
    var scanned = 0;
    var inserted = 0;
    List<Map<String, dynamic>> pending = [];

    Future<void> flush() async {
      if (pending.isEmpty) return;
      await DictDbService.createDb(targetDbPath);
      await DictDbService.insertBatch(targetDbPath, pending);
      inserted += pending.length;
      pending = [];
    }

    while (true) {
      final rows = await source.rawQuery(
        'SELECT $selectColumns FROM "$escapedTable" '
        'LIMIT $batchSize OFFSET $offset',
      );
      if (rows.isEmpty) break;
      offset += rows.length;

      for (final row in rows) {
        final headword = _clean(row['headword']);
        if (headword.isEmpty) continue;
        var definition = _clean(row['definition']);
        if (definition.isEmpty) definition = '—';
        pending.add({
          'headword': headword,
          'definition': definition,
          'phonetic': _cleanOrNull(row['phonetic']),
          'audio_path': null,
          'part_of_speech': _cleanOrNull(row['part_of_speech']),
          'dict_id': dictId,
        });
      }
      scanned += rows.length;
      onProgress?.call(
        0.1 + 0.8 * (scanned.clamp(0, 1000000) / 1000000),
        // Chuỗi tiến trình: dùng đúng mẫu đã có trong catalog.
        'Đang import từ điển…',
      );
      if (pending.length >= batchSize) await flush();
      if (rows.length < batchSize) break;
    }

    await flush();

    if (inserted == 0) {
      // Không chèn được dòng nào ⇒ KHÔNG để lại file index rỗng (sẽ thành
      // "từ điển ma" nếu ai đó liệt kê thư mục).
      try {
        await DictDbService.deleteDb(targetDbPath);
      } catch (_) {}
      return DictSqliteImportResult(
        entryCount: 0,
        mapping: mapping,
        warning: 'empty',
      );
    }
    return DictSqliteImportResult(entryCount: inserted, mapping: mapping);
  } finally {
    try {
      await source.close();
    } catch (_) {}
  }
}

String _clean(Object? value) {
  if (value == null) return '';
  // Một số file .db lưu nghĩa dạng BLOB (StarDict cũ) — giải mã UTF-8 thay vì
  // in ra "[104, 101, ...]".
  if (value is List<int>) {
    try {
      return utf8.decode(value, allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }
  if (value is! String) return value.toString().trim();
  // Một số file .db lưu nghĩa dạng bytes/BLOB đọc ra chuỗi UTF-8 lẫn NUL.
  return value.replaceAll('\u0000', ' ').trim();
}

String? _cleanOrNull(Object? value) {
  final text = _clean(value);
  return text.isEmpty ? null : text;
}

/// Nhận diện cặp ngôn ngữ từ TÊN FILE (vd `en-vi.db`, `anh_viet.db`).
///
/// Hàm THUẦN, chỉ để điền nhãn ngôn ngữ (không ảnh hưởng tra cứu).
({String? source, String? target}) detectLangPairFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  const table = <String, String>{
    'anh': 'EN',
    'viet': 'VI',
    'việt': 'VI',
    'phap': 'FR',
    'pháp': 'FR',
    'duc': 'DE',
    'đức': 'DE',
    'nhat': 'JA',
    'nhật': 'JA',
    'han': 'KO',
    'hàn': 'KO',
    'trung': 'ZH',
    'pali': 'PI',
    'english': 'EN',
    'vietnamese': 'VI',
    'french': 'FR',
    'german': 'DE',
    'japanese': 'JA',
    'korean': 'KO',
    'chinese': 'ZH',
  };

  // (vị trí trong tên file, mã ngôn ngữ) — sắp theo VỊ TRÍ rồi mới lấy 2 mã
  // đầu: `Pháp-Việt.db` phải là FR→VI (không phụ thuộc thứ tự khai báo map).
  final found = <(int, String)>[];
  for (final entry in table.entries) {
    final at = lower.indexOf(entry.key);
    if (at >= 0) found.add((at, entry.value));
  }
  for (final match in RegExp(r'(^|[^a-z])([a-z]{2})(?=[^a-z]|$)').allMatches(lower)) {
    final code = match.group(2)!.toUpperCase();
    if (_knownCodes.contains(match.group(2))) {
      found.add((match.start, code));
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));

  String? source;
  String? target;
  for (final item in found) {
    if (source == null) {
      source = item.$2;
    } else if (target == null && item.$2 != source) {
      target = item.$2;
      break;
    }
  }
  return (source: source, target: target);
}

const Set<String> _knownCodes = {
  'en', 'vi', 'fr', 'de', 'ja', 'ko', 'zh', 'th', 'ru', 'es', 'it',
  'pt', 'hi', 'si', 'my', 'km', 'lo', 'mn', 'bn', 'ta', 'te', 'mr',
  'ar', 'id', 'pi',
};
