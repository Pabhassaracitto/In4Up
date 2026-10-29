import 'package:sqflite/sqflite.dart';

import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/models/tipitaka_source_anchor.dart';

class TipitakaSourceLocation {
  final int bookId;
  final String bookCode;
  final String bookName;
  final TipitakaSegment segment;
  final String strategy;
  final bool databaseChanged;

  const TipitakaSourceLocation({
    required this.bookId,
    required this.bookCode,
    required this.bookName,
    required this.segment,
    required this.strategy,
    required this.databaseChanged,
  });

  bool get isExact => strategy == 'segment_id';
}

/// Resolves a saved Worklist anchor against the currently installed DB.
///
/// IDs are preferred when the DB fingerprint is unchanged. When a DB was
/// replaced, the resolver falls back to source row/reference, paragraph and
/// finally selected text so the user gets a useful location instead of a
/// broken link.
class TipitakaSourceResolver {
  const TipitakaSourceResolver();

  Future<TipitakaSourceLocation?> resolve(
    TipitakaSourceAnchor anchor,
  ) async {
    final db = await TipitakaDb.openReady();
    final currentIdentity = await TipitakaDb.sourceIdentity();
    final databaseChanged = anchor.sourceDatabaseId.isNotEmpty &&
        anchor.sourceDatabaseId != currentIdentity;

    Map<String, dynamic>? row;
    var strategy = 'segment_id';
    row = await _queryOne(
      db,
      'WHERE s.id = ? AND b.id = ?',
      [anchor.segmentId, anchor.bookId],
    );
    if (row != null &&
        (!databaseChanged || _textMatches(row, anchor.selectedText))) {
      return _location(row, strategy, databaseChanged);
    }

    if (anchor.sourceRowKey.isNotEmpty && anchor.sourceTable.isNotEmpty) {
      strategy = 'source_row';
      row = await _queryOne(
        db,
        'WHERE UPPER(b.code) = UPPER(?) AND s.source_table = ? AND s.source_row_key = ?',
        [anchor.bookCode, anchor.sourceTable, anchor.sourceRowKey],
      );
      if (row != null) return _location(row, strategy, databaseChanged);
    }

    if (anchor.reference.trim().isNotEmpty) {
      strategy = 'reference';
      row = await _queryOne(
        db,
        'WHERE UPPER(b.code) = UPPER(?) AND s.reference = ?',
        [anchor.bookCode, anchor.reference],
      );
      if (row != null && _textMatches(row, anchor.selectedText)) {
        return _location(row, strategy, databaseChanged);
      }
    }

    if (anchor.paragraphNo != null) {
      strategy = 'paragraph';
      row = await _queryOne(
        db,
        'WHERE UPPER(b.code) = UPPER(?) AND s.paragraph_no = ?',
        [anchor.bookCode, anchor.paragraphNo],
      );
      if (row != null && _textMatches(row, anchor.selectedText)) {
        return _location(row, strategy, databaseChanged);
      }
    }

    final selected = anchor.selectedText.trim();
    if (selected.isNotEmpty) {
      strategy = 'selected_text';
      final needle = selected.length > 80 ? selected.substring(0, 80) : selected;
      row = await _queryOne(
        db,
        'WHERE UPPER(b.code) = UPPER(?) AND ('
        's.pali_text LIKE ? OR s.translation_vi LIKE ? OR '
        's.translation_en LIKE ? OR s.translation_my LIKE ? OR '
        's.translation_th LIKE ? OR EXISTS ('
        'SELECT 1 FROM tipitaka_translations t '
        'WHERE t.segment_id = s.id AND t.text LIKE ?))',
        [
          anchor.bookCode,
          '%$needle%',
          '%$needle%',
          '%$needle%',
          '%$needle%',
          '%$needle%',
          '%$needle%',
        ],
      );
      if (row != null) return _location(row, strategy, databaseChanged);
    }

    return null;
  }

  Future<Map<String, dynamic>?> _queryOne(
    Database db,
    String where,
    List<Object?> args,
  ) async {
    final rows = await db.rawQuery('''
      SELECT s.*, b.id AS _resolved_book_id, b.code AS _resolved_book_code,
             b.name_en AS _resolved_book_name_en,
             b.name_vi AS _resolved_book_name_vi,
             b.name_pali AS _resolved_book_name_pali
      FROM tipitaka_segments s
      JOIN tipitaka_books b ON b.id = s.book_id
      $where
      ORDER BY s.order_index ASC, s.id ASC
      LIMIT 1
    ''', args);
    return rows.isEmpty ? null : rows.first;
  }

  TipitakaSourceLocation _location(
    Map<String, dynamic> row,
    String strategy,
    bool databaseChanged,
  ) {
    final vi = '${row['_resolved_book_name_vi'] ?? ''}'.trim();
    final en = '${row['_resolved_book_name_en'] ?? ''}'.trim();
    final pali = '${row['_resolved_book_name_pali'] ?? ''}'.trim();
    return TipitakaSourceLocation(
      bookId: (row['_resolved_book_id'] as num?)?.toInt() ??
          (row['book_id'] as num?)?.toInt() ??
          0,
      bookCode: '${row['_resolved_book_code'] ?? ''}',
      bookName: vi.isNotEmpty ? vi : (en.isNotEmpty ? en : pali),
      segment: TipitakaSegment.fromMap(row),
      strategy: strategy,
      databaseChanged: databaseChanged,
    );
  }

  bool _textMatches(Map<String, dynamic> row, String selectedText) {
    final selected = selectedText.trim();
    if (selected.isEmpty) return true;
    final candidates = <String>[
      '${row['pali_text'] ?? ''}',
      '${row['translation_vi'] ?? ''}',
      '${row['translation_en'] ?? ''}',
      '${row['translation_my'] ?? ''}',
      '${row['translation_th'] ?? ''}',
    ].where((text) => text.isNotEmpty);
    return candidates.any(
      (text) => text.contains(selected) || selected.contains(text),
    );
  }
}
