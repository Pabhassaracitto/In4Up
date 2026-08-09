// lib/features/canon/services/canon_fts_service.dart
//
// FTS (Full-Text Search) cho Canon — phiên bản Hive (pure Dart).
// Thiết kế tương thích với SQLite FTS5 để sau này có thể thay backend
// bằng Drift/SQFlite mà không đổi API.
//
// Hiện tại: Inverted Index trong Hive box `canon_fts_index`:
//   token (không dấu) -> { docId: tf }
// + docStore để tính score TF-IDF đơn giản + snippet.
//
// Sau này nếu muốn dùng SQLite FTS5 (Drift), chỉ cần tạo class
// `CanonFtsSqlite implements CanonFtsService` và đổi 1 dòng factory.
//
// Performance: với 3-1000 docs, search < 20ms trên mobile. Với 10k+ docs
// nên migrate sang Drift FTS5 để có ranking BM25 chuẩn.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/canon_entry.dart';
import '../models/canon_search_result.dart';
import 'canon_tokenizer.dart';

abstract class CanonFtsService {
  Future<void> init();
  Future<void> indexEntries(List<CanonEntry> entries);
  Future<void> addEntry(CanonEntry entry);
  Future<void> removeEntry(String id);
  Future<void> clear();
  Future<CanonSearchResult> search(String query, {int limit = 20, List<CanonEntry> Function()? entriesProvider});
  List<String> suggest(String prefix, {int limit = 5});
  void dispose();
}

/// Hive-based inverted index (default)
class HiveCanonFtsService implements CanonFtsService {
  static const String _indexBoxName = 'canon_fts_index';
  static const String _metaBoxName = 'canon_fts_meta';
  static const String _docLengthsKey = 'docLengths'; // Map docId -> length
  static const String _docCountKey = 'docCount';

  Box<String> get _indexBox => Hive.box<String>(_indexBoxName);
  Box<String> get _metaBox => Hive.box<String>(_metaBoxName);

  // cache in-memory để search nhanh (<5ms)
  final Map<String, Map<String, int>> _inverted = {}; // token -> {docId: tf}
  final Map<String, int> _docLengths = {}; // docId -> token count
  int _docCount = 0;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (!Hive.isBoxOpen(_indexBoxName)) {
      await Hive.openBox<String>(_indexBoxName);
    }
    if (!Hive.isBoxOpen(_metaBoxName)) {
      await Hive.openBox<String>(_metaBoxName);
    }
    await _loadToMemory();
    _ready = true;
    debugPrint('HiveCanonFtsService ready: $_docCount docs, ${_inverted.length} tokens');
  }

  Future<void> _loadToMemory() async {
    _inverted.clear();
    _docLengths.clear();
    for (final k in _indexBox.keys) {
      final token = k.toString();
      final json = _indexBox.get(k);
      if (json == null) continue;
      try {
        final map = (jsonDecode(json) as Map).cast<String, dynamic>();
        _inverted[token] = map.map((dk, dv) => MapEntry(dk, (dv as num).toInt()));
      } catch (_) {}
    }
    try {
      final dlRaw = _metaBox.get(_docLengthsKey);
      if (dlRaw != null) {
        final m = (jsonDecode(dlRaw) as Map).cast<String, dynamic>();
        _docLengths.addAll(m.map((k, v) => MapEntry(k, (v as num).toInt())));
      }
      final dcRaw = _metaBox.get(_docCountKey);
      if (dcRaw != null) {
        _docCount = int.tryParse(dcRaw) ?? _docLengths.length;
      } else {
        _docCount = _docLengths.length;
      }
    } catch (_) {}
  }

  Future<void> _persistToken(String token, Map<String, int> postings) async {
    await _indexBox.put(token, jsonEncode(postings));
  }

  Future<void> _persistMeta() async {
    await _metaBox.put(_docLengthsKey, jsonEncode(_docLengths));
    await _metaBox.put(_docCountKey, _docCount.toString());
  }

  // ── Indexing ───────────────────────────────────────────

  @override
  Future<void> indexEntries(List<CanonEntry> entries) async {
    if (!_ready) await init();
    // clear old
    await clear();
    for (final e in entries) {
      await _indexOne(e, persist: false);
    }
    // persist batch
    for (final entry in _inverted.entries) {
      await _persistToken(entry.key, entry.value);
    }
    await _persistMeta();
    debugPrint('Canon FTS indexed ${entries.length} entries -> ${_inverted.length} tokens');
  }

  @override
  Future<void> addEntry(CanonEntry entry) async {
    if (!_ready) await init();
    await _removeDocFromIndex(entry.id, persist: false);
    await _indexOne(entry, persist: true);
    await _persistMeta();
  }

  @override
  Future<void> removeEntry(String id) async {
    if (!_ready) await init();
    await _removeDocFromIndex(id, persist: true);
    await _persistMeta();
  }

  Future<void> _indexOne(CanonEntry e, {required bool persist}) async {
    // gộp title + pali + tags + content để index
    final combined = [
      e.title,
      e.titlePali,
      e.tags.join(' '),
      e.paliRef,
      e.category,
      e.collection,
      e.plainText,
    ].join(' ');

    final tokens = CanonTokenizer.tokenize(combined);
    if (tokens.isEmpty) return;

    final tf = <String, int>{};
    for (final t in tokens) {
      tf[t] = (tf[t] ?? 0) + 1;
    }

    _docLengths[e.id] = tokens.length;
    _docCount = _docLengths.length;

    for (final kv in tf.entries) {
      final token = kv.key;
      final freq = kv.value;
      final postings = _inverted.putIfAbsent(token, () => {});
      postings[e.id] = freq;
      if (persist) {
        await _persistToken(token, postings);
      }
    }
  }

  Future<void> _removeDocFromIndex(String docId, {required bool persist}) async {
    final tokensToUpdate = <String>[];
    for (final kv in _inverted.entries) {
      if (kv.value.containsKey(docId)) {
        tokensToUpdate.add(kv.key);
      }
    }
    for (final t in tokensToUpdate) {
      _inverted[t]!.remove(docId);
      if (_inverted[t]!.isEmpty) {
        _inverted.remove(t);
        if (persist) await _indexBox.delete(t);
      } else {
        if (persist) await _persistToken(t, _inverted[t]!);
      }
    }
    _docLengths.remove(docId);
    _docCount = _docLengths.length;
  }

  @override
  Future<void> clear() async {
    _inverted.clear();
    _docLengths.clear();
    _docCount = 0;
    await _indexBox.clear();
    await _metaBox.clear();
  }

  // ── Search ─────────────────────────────────────────────

  @override
  Future<CanonSearchResult> search(
    String query, {
    int limit = 20,
    List<CanonEntry> Function()? entriesProvider,
  }) async {
    final sw = Stopwatch()..start();
    if (!_ready) await init();
    if (query.trim().isEmpty || _inverted.isEmpty) {
      sw.stop();
      return CanonSearchResult(query: query, hits: [], total: 0, elapsed: sw.elapsed);
    }

    final qTokens = CanonTokenizer.tokenize(query);
    if (qTokens.isEmpty) {
      sw.stop();
      return CanonSearchResult(query: query, hits: [], total: 0, elapsed: sw.elapsed);
    }

    // Lấy postings cho từng token, AND hoặc OR?
    // Chiến lược: ưu tiên AND (tất cả token phải có), nếu không ra kết quả thì fallback OR
    final postingsPerToken = <String, Map<String, int>>{};
    for (final t in qTokens) {
      postingsPerToken[t] = _inverted[t] ?? {};
    }

    // Tìm candidate docIds
    Set<String>? candidateIds;
    for (final postings in postingsPerToken.values) {
      if (postings.isEmpty) continue;
      if (candidateIds == null) {
        candidateIds = Set.from(postings.keys);
      } else {
        candidateIds = candidateIds.intersection(postings.keys.toSet());
      }
    }

    // Nếu AND ra rỗng, fallback OR (union)
    if (candidateIds == null || candidateIds.isEmpty) {
      candidateIds = {};
      for (final p in postingsPerToken.values) {
        candidateIds.addAll(p.keys);
      }
    }

    if (candidateIds.isEmpty) {
      sw.stop();
      return CanonSearchResult(query: query, hits: [], total: 0, elapsed: sw.elapsed);
    }

    // Tính score TF-IDF cho mỗi candidate
    final scores = <String, double>{};
    final matchedTermsPerDoc = <String, List<String>>{};

    for (final docId in candidateIds) {
      double score = 0;
      final matched = <String>[];
      for (final qTok in qTokens) {
        final postings = postingsPerToken[qTok];
        if (postings == null || !postings.containsKey(docId)) continue;
        final tf = postings[docId]!.toDouble();
        final df = postings.length.toDouble();
        // TF normalized by doc length, IDF smooth
        final tfNorm = tf / (_docLengths[docId] ?? 1);
        final idf = math.log(1 + _docCount / (df + 1));
        // Bonus nếu token xuất hiện trong tiêu đề/tags sẽ được tính 2 lần do đã index gộp,
        // nhưng ta có thể boost thêm bằng cách kiểm tra riêng (đơn giản: +0.5 nếu match raw)
        score += tfNorm * idf * 100;
        matched.add(qTok);
      }
      if (score > 0) {
        scores[docId] = score;
        matchedTermsPerDoc[docId] = matched;
      }
    }

    // Sort theo score giảm dần
    final sortedIds = scores.keys.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final topIds = sortedIds.take(limit).toList();

    // Map id -> entry nếu có provider
    final entryMap = <String, CanonEntry>{};
    if (entriesProvider != null) {
      for (final e in entriesProvider()) {
        if (candidateIds.contains(e.id)) entryMap[e.id] = e;
      }
    }

    final hits = <CanonSearchHit>[];
    for (final id in topIds) {
      final entry = entryMap[id];
      if (entry == null) continue;
      final snippet = _buildSnippet(entry.plainText, qTokens);
      hits.add(CanonSearchHit(
        entry: entry,
        score: scores[id]!,
        matchedTerms: matchedTermsPerDoc[id] ?? [],
        snippet: snippet,
      ));
    }

    sw.stop();
    return CanonSearchResult(
      query: query,
      hits: hits,
      total: sortedIds.length,
      elapsed: sw.elapsed,
    );
  }

  String _buildSnippet(String text, List<String> qTokens) {
    final lower = CanonTokenizer.stripDiacritics(text.toLowerCase());
    int bestPos = -1;
    String bestTok = '';
    for (final tok in qTokens) {
      final pos = lower.indexOf(tok);
      if (pos != -1 && (bestPos == -1 || pos < bestPos)) {
        bestPos = pos;
        bestTok = tok;
      }
    }
    if (bestPos == -1) {
      final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.length > 160 ? '${t.substring(0, 157)}...' : t;
    }
    // map stripped pos -> original pos (xấp xỉ, vì strip không đổi độ dài nhiều)
    final start = (bestPos - 60).clamp(0, text.length);
    final end = (bestPos + bestTok.length + 100).clamp(0, text.length);
    var snippet = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';
    return snippet;
  }

  @override
  List<String> suggest(String prefix, {int limit = 5}) {
    if (!_ready || prefix.trim().isEmpty) return [];
    final p = CanonTokenizer.stripDiacritics(prefix.toLowerCase().trim());
    final matches = _inverted.keys.where((t) => t.startsWith(p)).toList()
      ..sort((a, b) {
        // ưu tiên token có df cao (phổ biến)
        final da = _inverted[a]!.length;
        final db = _inverted[b]!.length;
        return db.compareTo(da);
      });
    return matches.take(limit).toList();
  }

  @override
  void dispose() {}
}

// ─────────────────────────────────────────────────────────────
// Drift/SQLite FTS5 alternative — chỉ cần thêm drift + sqlite3_flutter_libs
// thì bật implementation này. Để sẵn code mẫu, không kích hoạt mặc định
// để tránh tăng APK size khi chưa cần.
// ─────────────────────────────────────────────────────────────
//
// import 'package:drift/drift.dart' as drift;
// import 'package:drift_flutter/drift_flutter.dart';
//
// @DriftDatabase(tables: [CanonDocs])
// class CanonDatabase extends _$CanonDatabase {
//   CanonDatabase() : super(driftDatabase(name: 'canon_fts'));
//   @override int get schemaVersion => 1;
//   // CREATE VIRTUAL TABLE canon_fts USING fts5(id, title, content, tokenize='porter unicode61');
//   // SELECT * FROM canon_fts WHERE canon_fts MATCH ? ORDER BY rank LIMIT ?
// }
//
// class DriftCanonFtsService implements CanonFtsService {
//   final CanonDatabase _db = CanonDatabase();
//   @override Future<CanonSearchResult> search(String query, {int limit=20, List<CanonEntry> Function()? entriesProvider}) async {
//     final rows = await _db.customSelect("SELECT id, rank FROM canon_fts WHERE canon_fts MATCH ? ORDER BY rank LIMIT ?", variables: [drift.Variable.withString(query), drift.Variable.withInt(limit)]).get();
//     // map rows -> hits
//   }
//   // ... indexEntries: batch insert + triggers
// }
//
// TO ENABLE: đổi factory trong canon_repository.dart từ HiveCanonFtsService -> DriftCanonFtsService
// và thêm vào pubspec.yaml:
//   drift: ^2.20.0
//   drift_flutter: ^0.2.0
//   sqlite3_flutter_libs: ^0.5.0
// ─────────────────────────────────────────────────────────────
