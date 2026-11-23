// lib/features/great_library/services/gl_catalog_service.dart
//
// GLIB-003 — Thư Viện Chung I4U (PLAN-049, ADR-0031 D2/D5).
// Catalog service: đọc danh mục pack PUBLISHED (public — không cần đăng nhập,
// D5), cache local có TTL (offline-first: lỗi mạng → dùng cache cũ), và tầng
// query/filter/sort THUẦN để UI gọi.
//
// Tách 2 interface nhỏ để test thuần:
//   GlCatalogTransport  — nguồn dữ liệu (impl thật: gl_catalog_transport_firestore.dart)
//   GlCatalogCacheStore — snapshot JSON local (impl file/SharedPrefs nối ở GLIB-004)

import 'dart:convert';

import '../models/gl_pack_entry.dart';
import '../models/pack_manifest.dart';

/// Lỗi tầng catalog (khi không có cache cũ để cứu).
class GlCatalogException implements Exception {
  const GlCatalogException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'GlCatalogException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Nguồn dữ liệu catalog (Firestore REST public ở bản thật).
abstract class GlCatalogTransport {
  /// Fields (đã decode về Dart thường) của mọi doc gl_packs status=published.
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs();
}

/// Nơi lưu snapshot catalog local (JSON string).
abstract class GlCatalogCacheStore {
  Future<String?> read();
  Future<void> write(String snapshotJson);
}

/// Cache in-memory — dùng cho test và wiring sớm (GLIB-004 có thể giữ instance
/// sống theo session app; persist file sẽ nối sau).
class GlCatalogMemoryCache implements GlCatalogCacheStore {
  String? _json;

  @override
  Future<String?> read() async => _json;

  @override
  Future<void> write(String snapshotJson) async {
    _json = snapshotJson;
  }
}

/// Cách sắp xếp kết quả trong thư viện.
enum GlPackSort { newest, mostDownloaded, topRated }

/// Bộ lọc + sắp xếp THUẦN trên danh sách entry — không IO, test trực tiếp.
class GlCatalogQuery {
  const GlCatalogQuery({
    this.type,
    this.srcLang,
    this.dstLang,
    this.level,
    this.tag,
    this.text,
    this.sort = GlPackSort.newest,
  });

  final PackType? type;
  final String? srcLang;
  final String? dstLang;
  final String? level;
  final String? tag;
  final String? text;
  final GlPackSort sort;

  bool get isEmpty =>
      type == null &&
      srcLang == null &&
      dstLang == null &&
      level == null &&
      tag == null &&
      (text == null || text!.trim().isEmpty);

  List<GlPackEntry> apply(List<GlPackEntry> entries) {
    // Copy ra list mutable: `_entries` trong controller/cache có thể là
    // unmodifiable (toList(growable:false)) — sort in-place sẽ ném.
    var result = entries.toList();
    final t = type;
    if (t != null) {
      result = result.where((e) => e.manifest.type == t).toList();
    }
    final src = srcLang;
    if (src != null && src.isNotEmpty) {
      result = result.where((e) => e.manifest.srcLang == src).toList();
    }
    final dst = dstLang;
    if (dst != null && dst.isNotEmpty) {
      result = result.where((e) => e.manifest.dstLang == dst).toList();
    }
    final lv = level;
    if (lv != null && lv.isNotEmpty) {
      result = result.where((e) => e.manifest.level == lv).toList();
    }
    final tg = tag;
    if (tg != null && tg.isNotEmpty) {
      final needle = tg.toLowerCase();
      result = result
          .where((e) =>
              e.manifest.tags.any((tag) => tag.toLowerCase() == needle))
          .toList();
    }
    final tx = text;
    if (tx != null && tx.trim().isNotEmpty) {
      // P0: lowercase contains. TODO(P2): bỏ dấu tiếng Việt khi tìm.
      final needle = tx.trim().toLowerCase();
      result = result.where((e) {
        final m = e.manifest;
        return m.title.toLowerCase().contains(needle) ||
            m.description.toLowerCase().contains(needle) ||
            m.author.displayName.toLowerCase().contains(needle) ||
            m.tags.any((tag) => tag.toLowerCase().contains(needle));
      }).toList();
    }
    switch (sort) {
      case GlPackSort.newest:
        result.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
        break;
      case GlPackSort.mostDownloaded:
        result.sort(
            (a, b) => b.manifest.stats.downloads.compareTo(a.manifest.stats.downloads));
        break;
      case GlPackSort.topRated:
        result.sort((a, b) {
          final byRating =
              b.manifest.stats.rating.compareTo(a.manifest.stats.rating);
          if (byRating != 0) return byRating;
          return b.manifest.stats.ratings.compareTo(a.manifest.stats.ratings);
        });
        break;
    }
    return result;
  }

  static DateTime _sortTime(GlPackEntry e) =>
      e.publishedAt ?? e.manifest.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Snapshot cache: thời điểm fetch + entries.
class _GlCatalogSnapshot {
  _GlCatalogSnapshot({required this.fetchedAt, required this.entries});

  final DateTime fetchedAt;
  final List<GlPackEntry> entries;

  String toJsonString() => jsonEncode(<String, dynamic>{
        'fetchedAt': fetchedAt.toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      });

  static _GlCatalogSnapshot? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final fetchedAt = DateTime.tryParse('${map['fetchedAt'] ?? ''}');
      if (fetchedAt == null) return null;
      final rawEntries = map['entries'] as List<dynamic>? ?? const [];
      return _GlCatalogSnapshot(
        fetchedAt: fetchedAt,
        entries: rawEntries
            .whereType<Map<String, dynamic>>()
            .map(GlPackEntry.fromJson)
            .toList(),
      );
    } on Object {
      return null; // cache hỏng → coi như không có
    }
  }
}

class GlCatalogService {
  GlCatalogService({
    required GlCatalogTransport transport,
    required GlCatalogCacheStore cache,
    this.ttl = const Duration(hours: 6),
    DateTime Function()? now,
  })  : _transport = transport,
        _cache = cache,
        _now = now ?? DateTime.now;

  final GlCatalogTransport _transport;
  final GlCatalogCacheStore _cache;
  final Duration ttl;
  final DateTime Function() _now;

  List<GlPackEntry>? _lastGood;

  /// Lấy catalog: cache còn hạn → trả ngay; hết hạn/force → fetch, ghi cache;
  /// fetch lỗi mà có cache → trả cache cũ (offline-first); không có gì → ném
  /// [GlCatalogException].
  Future<List<GlPackEntry>> getCatalog({bool forceRefresh = false}) async {
    final snapshot = _GlCatalogSnapshot.tryParse(await _cache.read());
    final fresh = snapshot != null &&
        _now().difference(snapshot.fetchedAt) < ttl;
    if (!forceRefresh && fresh) {
      _lastGood = snapshot.entries;
      return snapshot.entries;
    }
    try {
      final docs = await _transport.fetchPublishedPackDocs();
      final entries =
          docs.map(GlPackEntry.fromCatalogDoc).toList(growable: false);
      await _cache.write(
          _GlCatalogSnapshot(fetchedAt: _now(), entries: entries)
              .toJsonString());
      _lastGood = entries;
      return entries;
    } on Object catch (e) {
      final fallback = _lastGood ?? snapshot?.entries;
      if (fallback != null) return fallback;
      throw GlCatalogException(
          'Không tải được catalog và không có bản cache', cause: e);
    }
  }

  /// Một pack theo id (đi qua catalog đã load — có thể force refresh).
  Future<GlPackEntry?> getPack(String packId, {bool forceRefresh = false}) async {
    final entries = await getCatalog(forceRefresh: forceRefresh);
    for (final entry in entries) {
      if (entry.packId == packId) return entry;
    }
    return null;
  }

  /// Query thuần trên catalog đã load (tiện cho UI).
  List<GlPackEntry> query(List<GlPackEntry> entries, GlCatalogQuery q) =>
      q.apply(entries);
}
