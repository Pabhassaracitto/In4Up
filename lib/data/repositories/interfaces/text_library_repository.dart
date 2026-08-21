// lib/data/repositories/interfaces/text_library_repository.dart
//
// Abstraction cho thư viện văn bản do user tạo.
// Trước đây TextLibraryService gọi trực tiếp Firestore.
// Giờ qua repository để có thể:
//   - local-first với Hive cache (offline)
//   - đổi remote sang Supabase chỉ bằng 1 flag
//   - dễ test (mock repository)

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/foundation.dart';

import '../../../services/text_library_service.dart';

abstract class TextLibraryRepository {
  Future<void> init();

  // ── Đọc ────────────────────────────────────────────────
  Stream<List<TextLibraryEntry>> watchAll();
  Future<List<TextLibraryEntry>> fetchAll();
  Future<TextLibraryEntry?> getById(String id);
  Future<List<TextLibraryEntry>> search(String query);
  List<TextLibraryEntry> getCached(); // đọc từ cache local tức thì (0ms)

  // ── Ghi ────────────────────────────────────────────────
  Future<TextLibraryEntry?> add({
    required String title,
    required String content,
    String? category,
  });

  Future<bool> update(TextLibraryEntry entry);
  Future<bool> delete(String id);
  Future<void> clearCache();

  // ── Sync ───────────────────────────────────────────────
  bool get isAvailable;
  Future<int> syncFromRemote({bool force = false});
  Future<void> syncPendingToRemote();
  ValueNotifier<bool> get isSyncing;

  void dispose();
}
