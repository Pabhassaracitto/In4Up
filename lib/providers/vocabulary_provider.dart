import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/vocab_context.dart';
import '../models/vocabulary_type.dart';
import '../models/word_entry.dart';
import '../services/vocab_classifier.dart';
import '../services/vocab_sync_service.dart';

class VocabularyProvider extends ChangeNotifier {
  static const String _boxName = 'vocabulary_v2';

  final List<WordEntry> _words = [];
  MasteryZone? _filterZone;
  VocabularyType? _filterType;
  String? _filterSource;
  String _searchQuery = '';
  bool _isLoading = false;

  String? _filterLanguage;
  String? _filterTopic;
  String? _filterLearningStatus;

  final VocabSyncService _sync = VocabSyncService();
  bool _isSyncEnabled = false;
  StreamSubscription<User?>? _authSub;
  bool _isEnablingSync = false;
  String? _syncUid;

  // ─── Getters ─────────────────────────────────────────────
  List<WordEntry> get allWords => _words;
  bool get isLoading => _isLoading;
  bool get isSyncEnabled => _isSyncEnabled;
  VocabularyType? get filterType => _filterType;
  String? get filterLanguage => _filterLanguage;
  String? get filterTopic => _filterTopic;
  String? get filterLearningStatus => _filterLearningStatus;
  String? get filterSource => _filterSource;
  String get searchQuery => _searchQuery;

  SyncStatus get syncStatus => _sync.status.value;
  DateTime? get lastSyncedAt => _sync.lastSyncedAt.value;

  Set<String> get allLanguages {
    final Set<String> langs = _words.map((w) => w.language).where((l) => l.isNotEmpty).toSet();
    if (langs.isEmpty) return {'en'};
    return langs;
  }

  Set<String> get allTopics {
    return _words.map((w) => w.topic).whereType<String>().where((t) => t.isNotEmpty).toSet();
  }

  ValueNotifier<SyncStatus> get syncStatusNotifier => _sync.status;
  ValueNotifier<DateTime?> get lastSyncedNotifier => _sync.lastSyncedAt;

  Future<void> syncNow({bool forceAll = false}) async {
    if (!_isSyncEnabled) return;
    try {
      final pulledCount = await _sync.pullFromFirestore(forceAll: forceAll);
      if (pulledCount > 0) {
        await _reloadFromHive();
      }
      await _sync.flushPending();
    } catch (e, stack) {
      debugPrint('❌ syncNow error: $e\n$stack');
    }
  }

  void bindAuthState() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        disableSync();
        return;
      }
      await enableSync(user.uid);
    });
  }

  List<WordEntry> get displayedWords {
    var list = List<WordEntry>.from(_words);

    if (_filterZone != null) {
      list = list.where((w) => w.zone == _filterZone).toList();
    }
    if (_filterType != null) {
      list = list.where((w) => w.vocabType == _filterType).toList();
    }
    if (_filterSource != null && _filterSource!.isNotEmpty) {
      list = list
          .where((w) => w.contexts.any((c) => c.sourceName == _filterSource))
          .toList();
    }
    if (_filterLanguage != null) {
      list = list.where((w) => w.language == _filterLanguage).toList();
    }
    if (_filterTopic != null) {
      list = list.where((w) => w.topic == _filterTopic).toList();
    }
    if (_filterLearningStatus != null) {
      switch (_filterLearningStatus) {
        case 'due':
          list = list.where((w) => w.understandData.isDue || w.listenData.isDue || w.readData.isDue).toList();
          break;
        case 'learning':
          list = list.where((w) => w.mastery > 0.0 && w.mastery < 0.9).toList();
          break;
        case 'mastered':
          list = list.where((w) => w.mastery >= 0.9).toList();
          break;
        case 'blindSpot':
          list = list.where((w) => w.zone == MasteryZone.blindSpot).toList();
          break;
      }
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((w) =>
              w.word.toLowerCase().contains(q) ||
              w.meaning.toLowerCase().contains(q) ||
              w.contexts
                  .any((c) => c.surroundingText.toLowerCase().contains(q)))
          .toList();
    }
    return list;
  }

  // ─── By Type ─────────────────────────────────────────────
  Map<VocabularyType, List<WordEntry>> get wordsByType {
    final m = {for (final t in VocabularyType.values) t: <WordEntry>[]};
    for (final w in _words) {
      m[w.vocabType]!.add(w);
    }
    return m;
  }

  int get wordCount =>
      _words.where((w) => w.vocabType == VocabularyType.word).length;
  int get phraseCount =>
      _words.where((w) => w.vocabType == VocabularyType.phrase).length;
  int get sentenceCount =>
      _words.where((w) => w.vocabType == VocabularyType.sentence).length;

  // ─── By Source ─────────────────────────────────────────────
  Map<String, List<WordEntry>> get wordsBySource {
    final m = <String, List<WordEntry>>{};
    for (final w in _words) {
      for (final ctx in w.contexts) {
        final source = ctx.sourceName ?? 'Manual';
        m.putIfAbsent(source, () => []);
        if (!m[source]!.any((e) => e.id == w.id)) {
          m[source]!.add(w);
        }
      }
      if (w.contexts.isEmpty) {
        m.putIfAbsent('Manual', () => []).add(w);
      }
    }
    return m;
  }

  List<String> get allSources => wordsBySource.keys.toList()..sort();

  // ─── By Date ─────────────────────────────────────────────
  Map<String, List<WordEntry>> get wordsByDate {
    final m = <String, List<WordEntry>>{};
    for (final w in _words) {
      final key = _dateKey(w.createdAt);
      m.putIfAbsent(key, () => []).add(w);
    }
    return Map.fromEntries(
        m.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // ─── Frequent ─────────────────────────────────────────────
  List<WordEntry> get frequentlyEncountered =>
      _words.where((w) => w.encounterCount > 1).toList()
        ..sort((a, b) => b.encounterCount.compareTo(a.encounterCount));

  List<WordEntry> get addedToday {
    final now = DateTime.now();
    return _words
        .where((w) =>
            w.createdAt.year == now.year &&
            w.createdAt.month == now.month &&
            w.createdAt.day == now.day)
        .toList();
  }

  List<WordEntry> get addedThisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _words.where((w) => w.createdAt.isAfter(cutoff)).toList();
  }

  // ─── By Zone ─────────────────────────────────────────────
  Map<MasteryZone, List<WordEntry>> get wordsByZone {
    final m = {for (final z in MasteryZone.values) z: <WordEntry>[]};
    for (final w in _words) {
      m[w.zone]!.add(w);
    }
    return m;
  }

  // ─── Review queue ─────────────────────────────────────────
  List<WordEntry> get dueWords => _words.where((w) => w.isDue).toList()
    ..sort((a, b) {
      final d = a.daysUntilDue.compareTo(b.daysUntilDue);
      return d != 0 ? d : a.mastery.compareTo(b.mastery);
    });

  int get dueCount => dueWords.length;
  int get totalDueCount => _words.fold(0, (s, w) => s + w.dueSkills.length);

  List<WordEntry> get learningWords =>
      _words.where((w) => w.totalReviews > 0 && w.mastery < 0.8).toList();

  List<WordEntry> get masteredWords =>
      _words.where((w) => w.mastery >= 0.8).toList();

  // ─── Statistics ─────────────────────────────────────────────
  int get total => _words.length;
  int get blindSpots => wordsByZone[MasteryZone.blindSpot]!.length;
  int get masteredCount => wordsByZone[MasteryZone.mastered]!.length;

  double get progress =>
      _words.isEmpty ? 0 : _words.fold(0.0, (s, w) => s + w.mastery) / total;
  double get avgUnderstand =>
      _words.isEmpty ? 0 : _words.fold(0.0, (s, w) => s + w.understand) / total;
  double get avgListen =>
      _words.isEmpty ? 0 : _words.fold(0.0, (s, w) => s + w.listen) / total;
  double get avgRead =>
      _words.isEmpty ? 0 : _words.fold(0.0, (s, w) => s + w.read) / total;

  int get totalReviewsAllTime => _words.fold(0, (s, w) => s + w.totalReviews);

  double get avgAccuracy {
    final r = _words.where((w) => w.totalReviews > 0);
    if (r.isEmpty) return 0;
    return r.fold(0.0, (s, w) => s + w.accuracy) / r.length;
  }

  int reviewsInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _words
        .where((w) => w.lastReviewed.isAfter(cutoff) && w.totalReviews > 0)
        .length;
  }

  int wordsAddedInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _words.where((w) => w.createdAt.isAfter(cutoff)).length;
  }

  // ═══════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════

  static Future<void> ensureBoxOpen() async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox<String>(_boxName);
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  Future<void> enableSync(String uid) async {
    if (_isEnablingSync) return;
    if (_isSyncEnabled && _syncUid == uid) return;

    _isEnablingSync = true;
    try {
      await _sync.initialize(uid);

      // ★ CHIẾN LƯỢC: Pull before Push
      final isLocalEmpty = _box.isEmpty;
      final pulledCount = await _sync.pullFromFirestore(forceAll: isLocalEmpty);

      if (isLocalEmpty && pulledCount > 0) {
        debugPrint('🔄 Local rỗng, đã kéo $pulledCount từ vựng từ Firebase.');
      }

      _isSyncEnabled = true;
      _syncUid = uid;

      // Reload lại list để hiển thị dữ liệu mới kéo về
      if (pulledCount > 0) {
        await _reloadFromHive();
      }

      // Sau khi đã Pull an toàn, mới xử lý các thay đổi đang chờ (nếu có)
      await _sync.flushPending();
    } catch (e, stack) {
      _isSyncEnabled = false;
      _syncUid = null;
      debugPrint('❌ enableSync error: $e\n$stack');
    } finally {
      _isEnablingSync = false;
      notifyListeners();
    }
  }

  void disableSync() {
    _isSyncEnabled = false;
    _syncUid = null;
    _isEnablingSync = false;
    _sync.dispose();
    notifyListeners();
  }

  Future<void> forcePushAll() => _sync.pushAll();

  Future<void> _saveWord(WordEntry w) async {
    try {
      _box.put(w.id, jsonEncode(w.toJson()));
      if (_isSyncEnabled) _sync.markDirty(w.id);
    } catch (e) {
      debugPrint('VocabularyProvider._saveWord error: $e');
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    await _reloadFromHive();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reloadFromHive() async {
    try {
      await ensureBoxOpen();
      _words.clear();
      _words.addAll(_box.values.map((json) {
        try {
          return WordEntry.fromJson(jsonDecode(json) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('⚠️ VocabularyProvider: corrupt entry skipped: $e');
          return null;
        }
      }).whereType<WordEntry>());
      debugPrint('VocabularyProvider: loaded ${_words.length} words');
    } catch (e) {
      debugPrint('VocabularyProvider._reloadFromHive error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // FILTER ACTIONS
  // ═══════════════════════════════════════════════════════

  void setFilter(MasteryZone? zone) {
    _filterZone = _filterZone == zone ? null : zone;
    notifyListeners();
  }

  void setFilterType(VocabularyType? type) {
    _filterType = _filterType == type ? null : type;
    notifyListeners();
  }

  void setFilterSource(String? source) {
    _filterSource = _filterSource == source ? null : source;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void clearAllFilters() {
    _filterZone = null;
    _filterType = null;
    _filterSource = null;
    _filterLanguage = null;
    _filterTopic = null;
    _filterLearningStatus = null;
    _searchQuery = '';
    notifyListeners();
  }

  void setFilterLanguage(String? lang) {
    _filterLanguage = _filterLanguage == lang ? null : lang;
    notifyListeners();
  }

  void setFilterTopic(String? topic) {
    _filterTopic = _filterTopic == topic ? null : topic;
    notifyListeners();
  }

  void setFilterLearningStatus(String? status) {
    _filterLearningStatus = _filterLearningStatus == status ? null : status;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  // CRUD ACTIONS
  // ═══════════════════════════════════════════════════════

  void addWord(WordEntry w) {
    // Kiểm tra trùng lặp dựa trên ID hoặc từ (normalize)
    if (_words.any(
        (e) => e.id == w.id || e.word.toLowerCase() == w.word.toLowerCase())) {
      debugPrint('Word already exists: ${w.word}');
      return;
    }
    _words.add(w);
    _saveWord(w);
    notifyListeners();
  }

  void addWords(List<WordEntry> words) {
    bool changed = false;
    for (final w in words) {
      if (_words.any((e) => e.word.toLowerCase() == w.word.toLowerCase())) {
        continue;
      }
      _words.add(w);
      _saveWord(w);
      changed = true;
    }
    if (changed) notifyListeners();
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
    final normalized = text.trim();

    final existing = findByWord(normalized);
    if (existing != null) {
      if (context != null) {
        existing.addContext(context);
        _saveWord(existing);
        notifyListeners();
      }
      return existing;
    }

    final type = forceType ?? VocabClassifier.classify(normalized);

    final entry = WordEntry(
      id: 'v_${DateTime.now().millisecondsSinceEpoch}_${_words.length}',
      word: normalized,
      meaning: meaning,
      phonetic: phonetic,
      vocabType: type,
      contexts: context != null ? [context] : [],
      isUnborn: meaning.trim().isEmpty,
      language: language,
      topic: topic,
    );

    _words.add(entry);
    _saveWord(entry);
    notifyListeners();
    return entry;
  }

  void addContextToWord(String wordId, VocabContext context) {
    try {
      final w = _words.firstWhere((w) => w.id == wordId);
      w.addContext(context);
      _saveWord(w);
      notifyListeners();
    } catch (_) {
      debugPrint('addContextToWord: word $wordId not found');
    }
  }

  DecomposeResult autoDecompose(String text, VocabularyType type) {
    return VocabClassifier.decompose(text, type);
  }

  List<WordEntry> saveDecomposeResults({
    required String parentId,
    required List<String> selectedWords,
    required List<String> selectedPhrases,
    required Map<String, String> meanings,
    VocabContext? sharedContext,
  }) {
    final created = <WordEntry>[];

    for (final word in selectedWords) {
      final entry = addWithAutoClassify(
        text: word,
        meaning: meanings[word] ?? '',
        forceType: VocabularyType.word,
        context: sharedContext,
      );
      _linkParentChild(parentId, entry.id);
      created.add(entry);
    }

    for (final phrase in selectedPhrases) {
      final entry = addWithAutoClassify(
        text: phrase,
        meaning: meanings[phrase] ?? '',
        forceType: VocabularyType.phrase,
        context: sharedContext,
      );
      _linkParentChild(parentId, entry.id);
      created.add(entry);
    }

    notifyListeners();
    return created;
  }

  void _linkParentChild(String parentId, String childId) {
    if (parentId == childId) return;
    try {
      final parent = _words.firstWhere((w) => w.id == parentId);
      final child = _words.firstWhere((w) => w.id == childId);
      parent.addChild(childId);
      child.addParent(parentId);
      _saveWord(parent);
      _saveWord(child);
    } catch (_) {
      debugPrint('_linkParentChild: parent or child not found');
    }
  }

  List<WordEntry> getChildren(String parentId) {
    try {
      final parent = _words.firstWhere((w) => w.id == parentId);
      return _words.where((w) => parent.childIds.contains(w.id)).toList();
    } catch (_) {
      return [];
    }
  }

  List<WordEntry> getParents(String childId) {
    try {
      final child = _words.firstWhere((w) => w.id == childId);
      return _words.where((w) => child.parentIds.contains(w.id)).toList();
    } catch (_) {
      return [];
    }
  }

  List<WordEntry> getRelated(String wordId) {
    return [...getParents(wordId), ...getChildren(wordId)];
  }

  void updateWord(String id,
      {String? word, String? meaning, String? phonetic, String? example, String? language, String? topic, VocabularyType? vocabType}) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      if (word != null) w.word = word;
      if (meaning != null) {
        w.meaning = meaning;
        if (meaning.trim().isNotEmpty) w.isUnborn = false;
      }
      if (phonetic != null) {
        w.phonetic = phonetic;
        if (phonetic.trim().isNotEmpty) w.isUnborn = false;
      }
      if (example != null) {
        w.example = example;
        if (example.trim().isNotEmpty) w.isUnborn = false;
      }
      if (language != null) w.language = language;
      if (topic != null) w.topic = topic.trim().isEmpty ? null : topic;
      if (vocabType != null) {
        w.vocabType = vocabType;
      }
      w.updatedAt = DateTime.now();
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  void updateNotes(String id, String notes) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      w.personalNotes = notes;
      w.updatedAt = DateTime.now();
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  void removeWord(String id) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      for (final pid in w.parentIds) {
        try {
          final parent = _words.firstWhere((p) => p.id == pid);
          parent.removeChild(id);
          _saveWord(parent);
        } catch (_) {}
      }
      for (final cid in w.childIds) {
        try {
          final child = _words.firstWhere((c) => c.id == cid);
          child.removeParent(id);
          _saveWord(child);
        } catch (_) {}
      }
    } catch (_) {}

    _words.removeWhere((w) => w.id == id);
    _box.delete(id);
    if (_isSyncEnabled) _sync.markDeleted(id);
    notifyListeners();
  }

  void updateWordScore(String id, Skill skill, double value) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      w.updateScore(skill, value);
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  void updateWordAllScores(String id, double u, double l, double r) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      w.updateAllScores(u, l, r);
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  void quickAnswerWord(String id, Skill skill, bool correct) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      w.quickAnswer(skill, correct);
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  void reviewWord(String id, int quality) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      w.review(quality: quality);
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  void reviewWordSkill(String id, Skill skill, int quality) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      w.reviewSkill(skill, quality);
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  void setWordZone(String id, MasteryZone zone) {
    try {
      final w = _words.firstWhere((w) => w.id == id);
      w.setZone(zone);
      _saveWord(w);
      notifyListeners();
    } catch (_) {}
  }

  WordEntry? findByWord(String word) {
    final normalized = word.toLowerCase().trim();
    try {
      return _words.firstWhere((w) => w.word.toLowerCase() == normalized);
    } catch (_) {
      return null;
    }
  }

  bool hasWord(String word) => findByWord(word) != null;

  List<WordEntry> getDueForSkill(Skill skill) =>
      _words.where((w) => w.isSkillDue(skill)).toList()
        ..sort((a, b) =>
            a.skillDaysUntilDue(skill).compareTo(b.skillDaysUntilDue(skill)));

  List<WordEntry> weakest(Skill skill, {int count = 10}) =>
      (List<WordEntry>.from(_words)
            ..sort((a, b) => a.scoreOf(skill).compareTo(b.scoreOf(skill))))
          .take(count)
          .toList();

  List<WordEntry> importFromText(String text, {String defaultMeaning = ''}) {
    final words = text
        .split(RegExp(r'\s+'))
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.length > 1)
        .toSet()
        .toList();

    final newWords = <WordEntry>[];
    for (final word in words) {
      if (!hasWord(word)) {
        final entry = WordEntry(
          id: 'w_${DateTime.now().millisecondsSinceEpoch}_${newWords.length}',
          word: word,
          meaning: defaultMeaning,
        );
        newWords.add(entry);
      }
    }
    if (newWords.isNotEmpty) addWords(newWords);
    return newWords;
  }

  Future<void> clearAllData() async {
    await _box.clear();
    _words.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sync.dispose();
    super.dispose();
  }
}
