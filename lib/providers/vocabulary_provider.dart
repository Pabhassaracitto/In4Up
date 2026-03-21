// ═══════════════════════════════════════════════════════════════
//  UNIFIED VOCABULARY PROVIDER — v2 with Cloud Sync
//  - Single source of truth
//  - Hive = local (instant, offline-safe)
//  - Firestore = mirror (async, eventual consistency)
//  - SM-2 per skill (understand / listen / read)
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/word_entry.dart';
import '../services/vocab_sync_service.dart';
import '../utils/text_parser.dart';

class VocabularyProvider extends ChangeNotifier {
  static const String _boxName = 'vocabulary_v2';

  List<WordEntry> _words = [];
  MasteryZone? _filterZone;
  String _searchQuery = '';
  bool _isLoading = false;

  final VocabSyncService _sync = VocabSyncService();
  bool _isSyncEnabled = false;

  // ─── Getters ─────────────────────────────────────────────────
  List<WordEntry> get allWords => _words;
  bool get isLoading => _isLoading;
  bool get isSyncEnabled => _isSyncEnabled;

  List<WordEntry> get displayedWords {
    var list = _words;
    if (_filterZone != null)
      list = list.where((w) => w.zone == _filterZone).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((w) =>
              w.word.toLowerCase().contains(q) ||
              w.meaning.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Map<MasteryZone, List<WordEntry>> get wordsByZone {
    final m = {for (final z in MasteryZone.values) z: <WordEntry>[]};
    for (final w in _words) m[w.zone]!.add(w);
    return m;
  }

  // ─── Review queue ─────────────────────────────────────────────
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

  // ─── Statistics ───────────────────────────────────────────────
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

  // ═══════════════════════════════════════════════════════════════
  //  PERSISTENCE
  // ═══════════════════════════════════════════════════════════════

  static Future<void> ensureBoxOpen() async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox<String>(_boxName);
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  // ── Bật cloud sync sau khi user đăng nhập ─────────────────────
  Future<void> enableSync(String uid) async {
    _isSyncEnabled = true;
    await _sync.initialize(uid);
    final pulled = await _sync.pullFromFirestore();
    if (pulled > 0) await _reloadFromHive();
    notifyListeners();
  }

  void disableSync() {
    _isSyncEnabled = false;
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
      _words = _box.values
          .map((json) {
            try {
              return WordEntry.fromJson(
                  jsonDecode(json) as Map<String, dynamic>);
            } catch (e) {
              debugPrint('⚠️ VocabularyProvider: corrupt entry skipped: $e');
              return null;
            }
          })
          .whereType<WordEntry>()
          .toList();
      debugPrint('VocabularyProvider: loaded ${_words.length} words');
    } catch (e) {
      debugPrint('VocabularyProvider._reloadFromHive error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════════

  void setFilter(MasteryZone? zone) {
    _filterZone = _filterZone == zone ? null : zone;
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

  void addWord(WordEntry w) {
    if (_words.any((e) => e.word.toLowerCase() == w.word.toLowerCase())) return;
    _words.add(w);
    _saveWord(w);
    notifyListeners();
  }

  void addWords(List<WordEntry> words) {
    bool changed = false;
    for (final w in words) {
      if (_words.any((e) => e.word.toLowerCase() == w.word.toLowerCase()))
        continue;
      _words.add(w);
      _saveWord(w);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void updateWord(String id,
      {String? word, String? meaning, String? phonetic, String? example}) {
    final w = _words.firstWhere((w) => w.id == id);
    if (word != null) w.word = word;
    if (meaning != null) w.meaning = meaning;
    if (phonetic != null) w.phonetic = phonetic;
    if (example != null) w.example = example;
    _saveWord(w);
    notifyListeners();
  }

  void removeWord(String id) {
    _words.removeWhere((w) => w.id == id);
    _box.delete(id);
    if (_isSyncEnabled) _sync.markDeleted(id);
    notifyListeners();
  }

  void updateWordScore(String id, Skill skill, double value) {
    final w = _words.firstWhere((w) => w.id == id);
    w.updateScore(skill, value);
    _saveWord(w);
    notifyListeners();
  }

  void updateWordAllScores(String id, double u, double l, double r) {
    final w = _words.firstWhere((w) => w.id == id);
    w.updateAllScores(u, l, r);
    _saveWord(w);
    notifyListeners();
  }

  void quickAnswerWord(String id, Skill skill, bool correct) {
    final w = _words.firstWhere((w) => w.id == id);
    w.quickAnswer(skill, correct);
    _saveWord(w);
    notifyListeners();
  }

  void reviewWord(String id, int quality) {
    final w = _words.firstWhere((w) => w.id == id);
    w.review(quality: quality);
    _saveWord(w);
    notifyListeners();
  }

  void reviewWordSkill(String id, Skill skill, int quality) {
    final w = _words.firstWhere((w) => w.id == id);
    w.reviewSkill(skill, quality);
    _saveWord(w);
    notifyListeners();
  }

  void setWordZone(String id, MasteryZone zone) {
    final w = _words.firstWhere((w) => w.id == id);
    w.setZone(zone);
    _saveWord(w);
    notifyListeners();
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
    final uniqueWords = TextParser.extractUniqueWords(text);
    final newWords = <WordEntry>[];
    for (final word in uniqueWords) {
      if (!hasWord(word)) {
        final entry = WordEntry(
          id: 'w${DateTime.now().millisecondsSinceEpoch}_${newWords.length}',
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
    _sync.dispose();
    super.dispose();
  }
}
