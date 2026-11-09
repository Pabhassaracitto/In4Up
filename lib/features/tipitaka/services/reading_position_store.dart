import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A saved reading position: scroll offset (logical pixels) inside one book.
///
/// Storing pixels (not a segment id) is a deliberate best-effort choice:
/// restoring the exact visual spot survives font-scale/theme changes
/// reasonably well on the same device, and the reader re-pages forward if the
/// saved offset sits beyond the initially loaded window.
class TipitakaReadingPosition {
  final int bookId;
  final double pixels;
  final int totalCount;
  final int updatedAt;

  const TipitakaReadingPosition({
    required this.bookId,
    required this.pixels,
    required this.totalCount,
    required this.updatedAt,
  });

  factory TipitakaReadingPosition.fromJson(Map<String, dynamic> json) {
    return TipitakaReadingPosition(
      bookId: (json['book_id'] as num?)?.toInt() ?? 0,
      pixels: (json['pixels'] as num?)?.toDouble() ?? 0,
      totalCount: (json['total'] as num?)?.toInt() ?? 0,
      updatedAt: (json['at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'book_id': bookId,
        'pixels': pixels,
        'total': totalCount,
        'at': updatedAt,
      };

  DateTime get savedAt => DateTime.fromMillisecondsSinceEpoch(updatedAt);
}

/// Persisted "Đọc tiếp" (continue reading) store.
///
/// Keeps the newest scroll position per book (most recent entries first,
/// capped) so the reader can silently restore where the user stopped and the
/// library can surface resume entry points. All persistence is best-effort:
/// failures degrade to "start from the top", never to a broken read.
class TipitakaReadingPositions {
  TipitakaReadingPositions._();

  static const _kPositions = 'tipitaka.reading_positions.v1';
  static const _maxEntries = 16;

  /// Minimum offset worth remembering/restoring — everything above is
  /// effectively "still at the title page".
  static const minMeaningfulPixels = 160.0;

  static Future<List<TipitakaReadingPosition>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPositions);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final positions = <TipitakaReadingPosition>[
        for (final item in decoded)
          if (item is Map)
            TipitakaReadingPosition.fromJson(
              Map<String, dynamic>.from(item),
            ),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return positions;
    } catch (_) {
      return const [];
    }
  }

  static Future<TipitakaReadingPosition?> load(int bookId) async {
    for (final position in await loadAll()) {
      if (position.bookId == bookId) return position;
    }
    return null;
  }

  static Future<void> save(int bookId, double pixels, int totalCount) async {
    if (bookId <= 0) return;
    try {
      final positions = [...await loadAll()]
        ..removeWhere((position) => position.bookId == bookId);
      positions.insert(
        0,
        TipitakaReadingPosition(
          bookId: bookId,
          pixels: pixels,
          totalCount: totalCount,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (positions.length > _maxEntries) {
        positions.removeRange(_maxEntries, positions.length);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPositions,
        jsonEncode([for (final position in positions) position.toJson()]),
      );
    } catch (_) {
      // Resume data is auxiliary; never let a write failure affect reading.
    }
  }

  static Future<void> remove(int bookId) async {
    try {
      final positions = [...await loadAll()]
        ..removeWhere((position) => position.bookId == bookId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPositions,
        jsonEncode([for (final position in positions) position.toJson()]),
      );
    } catch (_) {}
  }
}
