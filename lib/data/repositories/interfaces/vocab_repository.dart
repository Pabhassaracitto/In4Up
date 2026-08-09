// lib/data/repositories/interfaces/vocab_repository.dart
//
// Abstraction cho mọi thao tác từ vựng.
// Hiện tại có 2 implementation:
//   - VocabRepositoryHive  : chỉ local (Hive) - mặc định, offline 100%
//   - VocabRepositorySupabase : sẽ dùng Supabase khi bạn bật flag
//   - OfflineFirstVocabRepository : Hive (local) + Firestore/Supabase (remote) + sync queue
//
// Triết lý: UI (Provider/Widget) chỉ phụ thuộc VocabRepository, không biết
// đằng sau là Hive hay Supabase hay Firestore. Đổi 1 dòng DI là đổi backend.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/word_entry.dart';
import '../../../models/vocabulary_type.dart';
import '../../../models/vocab_context.dart';
import '../../../services/vocab_sync_service.dart';

/// Kết quả phân trang / tìm kiếm, sẵn sàng cho FTS sau này
class VocabSearchResult {
  final List<WordEntry> entries;
  final int total;
  final Duration elapsed;

  const VocabSearchResult({
    required this.entries,
    required this.total,
    required this.elapsed,
  });
}

abstract class VocabRepository {
  /// Khởi tạo box, load cache. Gọi 1 lần ở main hoặc Provider init.
  Future<void> init();

  // ── Đọc ────────────────────────────────────────────────
  List<WordEntry> getAll();
  Stream<List<WordEntry>> watchAll();
  WordEntry? getById(String id);
  WordEntry? findByWord(String word);
  List<WordEntry> search(String query, {String? language, String? topic});
  List<WordEntry> getDue({Skill? skill});
  List<WordEntry> getByType(VocabularyType type);
  List<WordEntry> getByLanguage(String language);
  List<WordEntry> getByTopic(String topic);

  // ── Ghi ────────────────────────────────────────────────
  Future<void> save(WordEntry entry);
  Future<void> saveAll(List<WordEntry> entries);
  Future<void> delete(String id);
  Future<void> clearAll();

  // ── Cao cấp (phân loại, context) ───────────────────────
  WordEntry addWithAutoClassify({
    required String text,
    String meaning = '',
    String? phonetic,
    VocabContext? context,
    VocabularyType? forceType,
    String language = 'en',
    String? topic,
  });

  void addContext(String wordId, VocabContext context);

  // ── Đồng bộ ────────────────────────────────────────────
  bool get isSyncEnabled;
  SyncStatus get syncStatus;
  ValueNotifier<SyncStatus> get syncStatusNotifier;
  ValueNotifier<DateTime?> get lastSyncedNotifier;
  DateTime? get lastSyncedAt;

  Future<void> enableSync(String uid);
  void disableSync();
  Future<int> syncFromRemote({bool forceAll = false});
  Future<void> syncPendingToRemote();
  Future<void> pushAll();
  Future<void> syncNow({bool forceAll = false});

  // ── Meta (ngôn ngữ / chủ đề custom) ────────────────────
  Set<String> get customLanguages;
  Set<String> get customTopics;
  Future<void> addCustomLanguage(String lang);
  Future<void> removeCustomLanguage(String lang);
  Future<void> addCustomTopic(String topic);
  Future<void> removeCustomTopic(String topic);

  // ── Lifecycle ──────────────────────────────────────────
  void dispose();
}
