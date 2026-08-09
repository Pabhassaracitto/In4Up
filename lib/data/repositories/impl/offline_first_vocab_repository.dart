// lib/data/repositories/impl/offline_first_vocab_repository.dart
//
// Repository chính cho vocab — offline-first, composition của Local + Remote.
// Đây là implementation mặc định mà app sẽ dùng.
//
// Luồng:
//   read  -> local (Hive) tức thì 0ms
//   write -> local trước, enqueue pending -> remote khi có mạng (via VocabSyncService)
//   sync  -> pull remote nếu local rỗng hoặc có checkpoint mới hơn, flush pending
//
// Đổi backend: chỉ cần đổi RemoteDataSource từ Firestore -> Supabase ở constructor.

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../models/vocab_context.dart';
import '../../../models/vocabulary_type.dart';
import '../../../models/word_entry.dart';
import '../../../services/vocab_classifier.dart';
import '../../../services/vocab_sync_service.dart';
import '../../datasources/vocab_local_datasource.dart';
import '../../datasources/vocab_remote_datasource.dart';
import '../interfaces/vocab_repository.dart';

class OfflineFirstVocabRepository implements VocabRepository {
  OfflineFirstVocabRepository({
    VocabLocalDataSource? local,
    VocabRemoteDataSource? remote,
    VocabSyncService? syncService,
  })  : _local = local ?? VocabLocalDataSource(),
        _remote = remote ?? FirestoreVocabRemoteDataSource(),
        _sync = syncService ?? VocabSyncService();

  final VocabLocalDataSource _local;
  final VocabRemoteDataSource _remote;
  final VocabSyncService _sync;

  bool _isSyncEnabled = false;
  String? _uid;
  StreamSubscription? _hiveSub;
  final _controller = StreamController<List<WordEntry>>.broadcast();

  @override
  Future<void> init() async {
    await _local.init();
    // forward Hive watch -> stream
    _hiveSub?.cancel();
    _hiveSub = _local.watch().listen((_) {
      if (!_controller.isClosed) {
        _controller.add(getAll());
      }
    });
  }

  // ── Đọc ────────────────────────────────────────────────

  @override
  List<WordEntry> getAll() => _local.getAll();

  @override
  Stream<List<WordEntry>> watchAll() {
    // phát giá trị hiện tại ngay, sau đó mỗi khi Hive đổi sẽ phát tiếp
    return _controller.stream;
  }

  /// Lấy snapshot 1 lần, kèm phát ngay giá trị hiện tại cho UI khởi tạo
  Stream<List<WordEntry>> watchAllWithInitial() async* {
    yield getAll();
    yield* watchAll();
  }

  @override
  WordEntry? getById(String id) => _local.getById(id);

  @override
  WordEntry? findByWord(String word) => _local.findByWord(word);

  @override
  List<WordEntry> search(String query, {String? language, String? topic}) =>
      _local.search(query, language: language, topic: topic);

  @override
  List<WordEntry> getDue({Skill? skill}) {
    final all = getAll();
    if (skill == null) return all.where((w) => w.isDue).toList();
    return all.where((w) => w.isSkillDue(skill)).toList();
  }

  @override
  List<WordEntry> getByType(VocabularyType type) =>
      getAll().where((w) => w.vocabType == type).toList();

  @override
  List<WordEntry> getByLanguage(String language) =>
      getAll().where((w) => w.language == language).toList();

  @override
  List<WordEntry> getByTopic(String topic) =>
      getAll().where((w) => w.topic == topic).toList();

  // ── Ghi (local-first) ──────────────────────────────────

  @override
  Future<void> save(WordEntry entry) async {
    entry.updatedAt = DateTime.now();
    await _local.put(entry);
    if (_isSyncEnabled) {
      _sync.markDirty(entry.id);
    }
    if (!_controller.isClosed) _controller.add(getAll());
  }

  @override
  Future<void> saveAll(List<WordEntry> entries) async {
    final now = DateTime.now();
    for (final e in entries) {
      e.updatedAt = now;
    }
    await _local.putAll(entries);
    if (_isSyncEnabled) {
      for (final e in entries) {
        _sync.markDirty(e.id);
      }
    }
    if (!_controller.isClosed) _controller.add(getAll());
  }

  @override
  Future<void> delete(String id) async {
    await _local.delete(id);
    if (_isSyncEnabled) {
      _sync.markDeleted(id);
    }
    if (!_controller.isClosed) _controller.add(getAll());
  }

  @override
  Future<void> clearAll() async {
    await _local.clearAll();
    if (!_controller.isClosed) _controller.add([]);
  }

  // ── Cao cấp ────────────────────────────────────────────

  @override
  WordEntry addWithAutoClassify({
    required String text,
    String meaning = '',
    String? phonetic,
    VocabContext? context,
    VocabularyType? forceType,
    String language = 'en',
    String? topic,
  }) {
    final normalized = text.trim();
    final existing = findByWord(normalized);
    if (existing != null) {
      if (context != null) {
        existing.addContext(context);
        // fire-and-forget save
        save(existing);
      }
      return existing;
    }
    final type = forceType ?? VocabClassifier.classify(normalized);
    final entry = WordEntry(
      id: 'v_${DateTime.now().millisecondsSinceEpoch}_${getAll().length}',
      word: normalized,
      meaning: meaning,
      phonetic: phonetic,
      vocabType: type,
      contexts: context != null ? [context] : [],
      isUnborn: meaning.trim().isEmpty,
      language: language,
      topic: topic,
    );
    // fire-and-forget
    save(entry);
    return entry;
  }

  @override
  void addContext(String wordId, VocabContext context) {
    final w = getById(wordId);
    if (w == null) return;
    w.addContext(context);
    save(w);
  }

  // ── Sync ───────────────────────────────────────────────

  @override
  bool get isSyncEnabled => _isSyncEnabled;

  @override
  SyncStatus get syncStatus => _sync.status.value;

  @override
  ValueNotifier<SyncStatus> get syncStatusNotifier => _sync.status;

  @override
  ValueNotifier<DateTime?> get lastSyncedNotifier => _sync.lastSyncedAt;

  @override
  DateTime? get lastSyncedAt => _sync.lastSyncedAt.value;

  @override
  Future<void> enableSync(String uid) async {
    if (_isSyncEnabled && _uid == uid) return;
    _uid = uid;
    _isSyncEnabled = true;
    await _sync.initialize(uid);
    // pull nếu local rỗng hoặc có checkpoint mới
    final isLocalEmpty = _local.count == 0;
    final pulled = await _sync.pullFromFirestore(forceAll: isLocalEmpty);
    if (pulled > 0 && !_controller.isClosed) {
      _controller.add(getAll());
    }
    await _sync.flushPending();
  }

  @override
  void disableSync() {
    _isSyncEnabled = false;
    _uid = null;
    _sync.dispose();
  }

  @override
  Future<int> syncFromRemote({bool forceAll = false}) async {
    if (!_isSyncEnabled) return 0;
    final pulled = await _sync.pullFromFirestore(forceAll: forceAll);
    if (pulled > 0 && !_controller.isClosed) {
      _controller.add(getAll());
    }
    return pulled;
  }

  @override
  Future<void> syncPendingToRemote() async {
    if (!_isSyncEnabled) return;
    await _sync.flushPending();
  }

  @override
  Future<void> pushAll() async => _sync.pushAll();

  @override
  Future<void> syncNow({bool forceAll = false}) async {
    if (!_isSyncEnabled) return;
    final pulled = await _sync.pullFromFirestore(forceAll: forceAll);
    if (pulled > 0 && !_controller.isClosed) {
      _controller.add(getAll());
    }
    await _sync.flushPending();
  }

  // ── Meta ───────────────────────────────────────────────

  @override
  Set<String> get customLanguages => _local.customLanguages;

  @override
  Set<String> get customTopics => _local.customTopics;

  @override
  Future<void> addCustomLanguage(String lang) async {
    final set = customLanguages..add(lang.trim());
    await _local.saveMetaSet(VocabLocalDataSource.customLanguagesKey, set);
  }

  @override
  Future<void> removeCustomLanguage(String lang) async {
    final set = customLanguages..remove(lang);
    await _local.saveMetaSet(VocabLocalDataSource.customLanguagesKey, set);
  }

  @override
  Future<void> addCustomTopic(String topic) async {
    final set = customTopics..add(topic.trim());
    await _local.saveMetaSet(VocabLocalDataSource.customTopicsKey, set);
  }

  @override
  Future<void> removeCustomTopic(String topic) async {
    final set = customTopics..remove(topic);
    await _local.saveMetaSet(VocabLocalDataSource.customTopicsKey, set);
  }

  @override
  void dispose() {
    _hiveSub?.cancel();
    _controller.close();
    _sync.dispose();
  }
}

/// Factory helper để chọn backend bằng flag (DI)
class VocabRepositoryFactory {
  /// Đổi backend chỉ bằng cách đổi `useSupabase` hoặc inject RemoteDataSource
  static VocabRepository create({
    bool useSupabase = false,
    VocabSyncService? syncService,
  }) {
    final remote = useSupabase
        ? SupabaseVocabRemoteDataSource()
        : FirestoreVocabRemoteDataSource();
    return OfflineFirstVocabRepository(
      remote: remote,
      syncService: syncService,
    );
  }
}
