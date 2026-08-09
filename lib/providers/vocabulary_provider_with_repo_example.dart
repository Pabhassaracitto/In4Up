// lib/providers/vocabulary_provider_with_repo_example.dart
//
// VÍ DỤ MIGRATION: Cách VocabularyProvider sẽ gọn hơn khi dùng VocabRepository.
// File này là TÀI LIỆU MẪU, không được dùng trực tiếp (VocabularyProvider cũ vẫn chạy).
// Khi bạn sẵn sàng, hãy refactor VocabularyProvider theo mẫu này.
//
// BEFORE (hiện tại):
//   class VocabularyProvider extends ChangeNotifier {
//     final _box = Hive.box<String>('vocabulary_v2');
//     final _sync = VocabSyncService();
//     Future<void> _saveWord(WordEntry w) async {
//       _box.put(w.id, jsonEncode(w.toJson()));
//       if (_isSyncEnabled) _sync.markDirty(w.id);
//     }
//   }
//
// AFTER (với Repository):
//   class VocabularyProviderWithRepo extends ChangeNotifier {
//     VocabularyProviderWithRepo(this._repo);
//     final VocabRepository _repo;
//     Future<void> _saveWord(WordEntry w) => _repo.save(w);
//     Future<void> syncNow() => _repo.syncNow();
//   }
//
// Lợi ích:
//   - Provider không biết Hive hay Firestore hay Supabase
//   - Test dễ: mock VocabRepository
//   - Đổi backend chỉ cần đổi 1 dòng DI trong main.dart

import 'package:flutter/foundation.dart';
import '../data/repositories/interfaces/vocab_repository.dart';
import '../models/word_entry.dart';
import '../models/vocabulary_type.dart';
import '../models/vocab_context.dart';
import '../services/vocab_sync_service.dart';

/// Provider mẫu — minh họa cách dùng VocabRepository
/// Bạn có thể copy logic filter/search từ VocabularyProvider cũ vào đây
/// và thay các gọi _box/_sync thành _repo.
class VocabularyProviderWithRepo extends ChangeNotifier {
  VocabularyProviderWithRepo(this._repo) {
    _init();
  }

  final VocabRepository _repo;

  // ── State (copy từ VocabularyProvider cũ) ─────────────
  final List<WordEntry> _words = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<WordEntry> get allWords => List.unmodifiable(_words);
  bool get isLoading => _isLoading;
  bool get isSyncEnabled => _repo.isSyncEnabled;
  SyncStatus get syncStatus => _repo.syncStatus;
  ValueNotifier<SyncStatus> get syncStatusNotifier => _repo.syncStatusNotifier;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    await _repo.init();
    _words
      ..clear()
      ..addAll(_repo.getAll());
    _isLoading = false;
    notifyListeners();

    // lắng stream từ repo (Hive watch -> repo stream -> provider)
    _repo.watchAll().listen((latest) {
      _words
        ..clear()
        ..addAll(latest);
      notifyListeners();
    });
  }

  // ── CRUD — ủy thác cho repo (offline-first) ───────────

  Future<void> save(WordEntry entry) async {
    await _repo.save(entry);
    // _words sẽ được cập nhật qua watchAll, nhưng cũng có thể cập nhật optimistic:
    final idx = _words.indexWhere((w) => w.id == entry.id);
    if (idx != -1) {
      _words[idx] = entry;
    } else {
      _words.add(entry);
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _words.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  WordEntry addWithAutoClassify({
    required String text,
    String meaning = '',
    String? phonetic,
    VocabContext? context,
    VocabularyType? forceType,
    String language = 'en',
    String? topic,
  }) {
    final entry = _repo.addWithAutoClassify(
      text: text,
      meaning: meaning,
      phonetic: phonetic,
      context: context,
      forceType: forceType,
      language: language,
      topic: topic,
    );
    // repo đã save, watch sẽ cập nhật _words
    return entry;
  }

  List<WordEntry> search(String query) => _repo.search(query);

  // ── Sync ───────────────────────────────────────────────

  Future<void> enableSync(String uid) => _repo.enableSync(uid);
  void disableSync() => _repo.disableSync();
  Future<void> syncNow({bool forceAll = false}) => _repo.syncNow(forceAll: forceAll);

  // ── Filter (giữ nguyên logic cũ, chỉ đọc từ _words) ───
  List<WordEntry> get displayedWords {
    if (_searchQuery.isEmpty) return List.from(_words);
    final q = _searchQuery.toLowerCase();
    return _words
        .where((w) =>
            w.word.toLowerCase().contains(q) ||
            w.meaning.toLowerCase().contains(q) ||
            w.contexts.any((c) => c.surroundingText.toLowerCase().contains(q)))
        .toList();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }
}

// ── Cách đăng ký trong main.dart ─────────────────────────
//
// MultiProvider(
//   providers: [
//     Provider<VocabRepository>(create: (_) => createVocabRepository()),
//     ChangeNotifierProvider<VocabularyProviderWithRepo>(
//       create: (ctx) => VocabularyProviderWithRepo(ctx.read<VocabRepository>()),
//     ),
//   ],
// )
//
// Trong widget:
//   final vocab = context.watch<VocabularyProviderWithRepo>();
//   vocab.search('niệm');
//
