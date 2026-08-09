// lib/features/canon/canon_repository.dart
//
// Repository cho kho Kinh chuẩn — composition của Loader + FTS + personal notes.
// Đây là điểm duy nhất UI cần gọi, không cần biết .md nằm đâu hay FTS là Hive hay Drift.

import 'package:flutter/foundation.dart';

import '../../data/repositories/interfaces/canon_repository.dart';
import 'models/canon_entry.dart';
import 'models/canon_search_result.dart';
import 'services/canon_fts_service.dart';
import 'services/canon_loader.dart';

class AssetCanonRepository implements CanonRepository {
  AssetCanonRepository({
    CanonLoader? loader,
    CanonFtsService? fts,
  })  : _loader = loader ?? CanonLoader(),
        _fts = fts ?? HiveCanonFtsService();

  final CanonLoader _loader;
  final CanonFtsService _fts;

  List<CanonEntry> _entries = [];
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  int get count => _entries.length;

  @override
  Future<void> init() async {
    if (_ready) return;
    await _loader.ensureOpen();
    await _fts.init();

    final sw = Stopwatch()..start();
    _entries = await _loader.loadAll();
    // sync personal notes vào entries
    _entries = _entries.map((e) {
      final note = _loader.getPersonalNote(e.id);
      if (note != null && note.isNotEmpty) return e.copyWith(personalNote: note);
      return e;
    }).toList();

    // build FTS index nếu chưa có hoặc số lượng lệch
    await _fts.indexEntries(_entries);
    sw.stop();
    _ready = true;
    debugPrint('AssetCanonRepository ready: ${_entries.length} entries in ${sw.elapsedMilliseconds}ms');
  }

  // ── Load ───────────────────────────────────────────────

  @override
  List<CanonEntry> getAll() {
    assert(_ready, 'CanonRepository not initialized. Call init() first.');
    return List.unmodifiable(_entries);
  }

  @override
  CanonEntry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  List<CanonEntry> getByCategory(String category) =>
      _entries.where((e) => e.category == category).toList();

  @override
  List<CanonEntry> getByTag(String tag) =>
      _entries.where((e) => e.tags.contains(tag)).toList();

  @override
  Set<String> get allCategories => _entries.map((e) => e.category).toSet();

  @override
  Set<String> get allTags => _entries.expand((e) => e.tags).toSet();

  // ── Search ─────────────────────────────────────────────

  @override
  Future<CanonSearchResult> search(String query, {int limit = 20}) async {
    if (!_ready) await init();
    return _fts.search(query, limit: limit, entriesProvider: () => _entries);
  }

  @override
  List<String> suggest(String prefix, {int limit = 5}) =>
      _fts.suggest(prefix, limit: limit);

  // ── Personal notes ─────────────────────────────────────

  @override
  Future<void> savePersonalNote(String canonId, String note) async {
    await _loader.savePersonalNote(canonId, note);
    final idx = _entries.indexWhere((e) => e.id == canonId);
    if (idx != -1) {
      _entries[idx] = _entries[idx].copyWith(personalNote: note);
    }
  }

  @override
  String? getPersonalNote(String canonId) => _loader.getPersonalNote(canonId);

  // ── Helpers for UI ─────────────────────────────────────
  Future<void> refresh() async {
    _entries = await _loader.loadAll(forceRefresh: true);
    await _fts.indexEntries(_entries);
  }

  @override
  void dispose() {
    _fts.dispose();
  }
}

/// Factory để đổi source (assets vs downloaded vs Supabase) sau này
class CanonRepositoryFactory {
  static CanonRepository create({bool useSupabase = false}) {
    if (useSupabase) {
      // TODO: SupabaseCanonRepository — fetch từ bảng canon + cache Hive
      debugPrint('SupabaseCanonRepository stub — fallback to assets');
    }
    return AssetCanonRepository();
  }
}
