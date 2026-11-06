import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/collection.dart';

/// Lightweight catalogue snapshot and expanded-node state for the Tipiṭaka
/// library. The snapshot is keyed by the installed DB fingerprint, so import
/// or replacement automatically invalidates stale catalogue data.
class TipitakaLibraryStateStore {
  TipitakaLibraryStateStore._();

  static const _snapshotKey = 'tipitaka.library_snapshot.v1';
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> _enqueueWrite(Future<void> Function() write) {
    final next = _writeQueue.then((_) => write());
    _writeQueue = next.catchError((_) {});
    return next;
  }

  static String _expandedKey(String databaseIdentity) =>
      'tipitaka.expanded_nodes.v1:$databaseIdentity';

  static Future<TipitakaLibrarySnapshot?> loadSnapshot(
    String databaseIdentity,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_snapshotKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['identity'] != databaseIdentity) {
        return null;
      }
      return TipitakaLibrarySnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSnapshot(TipitakaLibrarySnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // The snapshot only accelerates startup; the SQLite database is canonical.
    }
  }

  static Future<Set<String>?> loadExpandedNodes(String databaseIdentity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _expandedKey(databaseIdentity);
      if (!prefs.containsKey(key)) return null;
      return prefs.getStringList(key)?.toSet() ?? <String>{};
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveExpandedNodes(
    String databaseIdentity,
    Set<String> expandedNodes,
  ) =>
      _enqueueWrite(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final values = expandedNodes.toList()..sort();
          await prefs.setStringList(_expandedKey(databaseIdentity), values);
        } catch (_) {
          // Expansion state is optional and must never block reading.
        }
      });

  static Future<void> setNodeExpanded(
    String databaseIdentity,
    String nodeKey,
    bool expanded,
  ) =>
      _enqueueWrite(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = _expandedKey(databaseIdentity);
          final values = (prefs.getStringList(key) ?? <String>[]).toSet();
          if (expanded) {
            values.add(nodeKey);
          } else {
            values.remove(nodeKey);
          }
          await prefs.setStringList(key, values.toList()..sort());
        } catch (_) {
          // Expansion state is optional and must never block reading.
        }
      });
}

class TipitakaLibrarySnapshot {
  final String databaseIdentity;
  final List<TipitakaCollection> collections;
  final List<TipitakaBook> books;
  final Set<String> languages;

  const TipitakaLibrarySnapshot({
    required this.databaseIdentity,
    required this.collections,
    required this.books,
    required this.languages,
  });

  factory TipitakaLibrarySnapshot.fromJson(Map<String, dynamic> json) =>
      TipitakaLibrarySnapshot(
        databaseIdentity: json['identity'] as String,
        collections: [
          for (final item in json['collections'] as List? ?? const [])
            if (item is Map)
              TipitakaCollection.fromMap(Map<String, dynamic>.from(item)),
        ],
        books: [
          for (final item in json['books'] as List? ?? const [])
            if (item is Map)
              TipitakaBook.fromMap(Map<String, dynamic>.from(item)),
        ],
        languages: (json['languages'] as List? ?? const [])
            .whereType<String>()
            .toSet(),
      );

  Map<String, dynamic> toJson() => {
        'identity': databaseIdentity,
        'collections': [
          for (final collection in collections)
            {
              'id': collection.id,
              'name_pali': collection.namePali,
              'name_en': collection.nameEn,
              'name_vi': collection.nameVi,
              'order_index': collection.orderIndex,
            },
        ],
        'books': [
          for (final book in books)
            {
              'id': book.id,
              'collection_id': book.collectionId,
              'code': book.code,
              'name_pali': book.namePali,
              'name_en': book.nameEn,
              'name_vi': book.nameVi,
              'order_index': book.orderIndex,
              'metadata_json': book.metadataJson,
            },
        ],
        'languages': languages.toList()..sort(),
      };
}
