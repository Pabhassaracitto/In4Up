// lib/data/repositories/interfaces/canon_repository.dart
//
// Kho Kinh điển chuẩn (Phật pháp) — lưu dạng .md local + FTS.
// Khác với TextLibrary (do user tự tạo, sync cloud), Canon là
// dữ liệu CHUẨN, offline 100%, đóng gói theo app hoặc tải về.

import '../../../features/canon/models/canon_entry.dart';
import '../../../features/canon/models/canon_search_result.dart';

abstract class CanonRepository {
  Future<void> init();

  // ── Load ───────────────────────────────────────────────
  List<CanonEntry> getAll();
  CanonEntry? getById(String id);
  List<CanonEntry> getByCategory(String category);
  List<CanonEntry> getByTag(String tag);
  Set<String> get allCategories;
  Set<String> get allTags;

  // ── Search (FTS) ───────────────────────────────────────
  /// Tìm kiếm full-text (FTS5-like) trên title + pali + content
  /// Hỗ trợ tiếng Việt có dấu / không dấu, Pali.
  Future<CanonSearchResult> search(String query, {int limit = 20});

  /// Gợi ý prefix (autocomplete)
  List<String> suggest(String prefix, {int limit = 5});

  // ── Ghi chú cá nhân (lưu local, sync riêng) ────────────
  Future<void> savePersonalNote(String canonId, String note);
  String? getPersonalNote(String canonId);

  // ── Stats ──────────────────────────────────────────────
  int get count;
  bool get isReady;

  void dispose();
}
