import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_entry.dart';
import '../utils/text_parser.dart';

class VocabularyProvider extends ChangeNotifier {
  List<WordEntry> _words = [];
  MasteryZone? _filterZone;
  String _searchQuery = '';
  bool _isLoading = false;

  // ═══════════════════════════════════════
  //  GETTERS
  // ═══════════════════════════════════════

  List<WordEntry> get allWords => _words;
  MasteryZone? get filterZone => _filterZone;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  List<WordEntry> get displayedWords {
    var list = _words;

    if (_filterZone != null) {
      list = list.where((w) => w.zone == _filterZone).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (w) =>
                w.word.toLowerCase().contains(q) ||
                w.meaning.toLowerCase().contains(q),
          )
          .toList();
    }

    return list;
  }

  Map<MasteryZone, List<WordEntry>> get wordsByZone {
    final m = {for (final z in MasteryZone.values) z: <WordEntry>[]};
    for (final w in _words) {
      m[w.zone]!.add(w);
    }
    return m;
  }

  // ═══════════════════════════════════════
  //  REVIEW QUEUE (SM-2)
  // ═══════════════════════════════════════

  /// Từ cần review hôm nay
  List<WordEntry> get dueWords {
    return _words.where((w) => w.isDue).toList()..sort((a, b) {
      // Ưu tiên: overdue nhiều nhất, mastery thấp nhất
      final aDays = a.daysUntilDue;
      final bDays = b.daysUntilDue;
      if (aDays != bDays) return aDays.compareTo(bDays);
      return a.mastery.compareTo(b.mastery);
    });
  }

  /// Số từ cần review
  int get dueCount => dueWords.length;

  /// Từ mới (chưa review lần nào)
  List<WordEntry> get newWords =>
      _words.where((w) => w.totalReviews == 0).toList();

  /// Từ đang học (đã review nhưng chưa thành thạo)
  List<WordEntry> get learningWords =>
      _words.where((w) => w.totalReviews > 0 && w.mastery < 0.8).toList();

  /// Từ đã thành thạo
  List<WordEntry> get masteredWords =>
      _words.where((w) => w.mastery >= 0.8).toList();

  // ═══════════════════════════════════════
  //  STATISTICS
  // ═══════════════════════════════════════

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
    final wordsWithReviews = _words.where((w) => w.totalReviews > 0);
    if (wordsWithReviews.isEmpty) return 0;
    return wordsWithReviews.fold(0.0, (s, w) => s + w.accuracy) /
        wordsWithReviews.length;
  }

  // ═══════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════

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

  // ── Thêm từ mới ──
  void addWord(WordEntry w) {
    _words.add(w);
    _saveData();
    notifyListeners();
  }

  // ── Thêm nhiều từ ──
  void addWords(List<WordEntry> words) {
    _words.addAll(words);
    _saveData();
    notifyListeners();
  }

  // ── Cập nhật từ ──
  void updateWord(
    String id, {
    String? word,
    String? meaning,
    String? phonetic,
    String? example,
  }) {
    final w = _words.firstWhere((w) => w.id == id);
    if (word != null) w.word = word;
    if (meaning != null) w.meaning = meaning;
    if (phonetic != null) w.phonetic = phonetic;
    if (example != null) w.example = example;
    _saveData();
    notifyListeners();
  }

  // ── Xóa từ ──
  void removeWord(String id) {
    _words.removeWhere((w) => w.id == id);
    _saveData();
    notifyListeners();
  }

  // ── Cập nhật điểm trực tiếp ──
  void updateWordScore(String id, Skill skill, double value) {
    final w = _words.firstWhere((w) => w.id == id);
    w.updateScore(skill, value);
    _saveData();
    notifyListeners();
  }

  // ── Cập nhật đồng loạt cả 3 chiều ──
  void updateWordAllScores(String id, double u, double l, double r) {
    final w = _words.firstWhere((w) => w.id == id);
    w.updateAllScores(u, l, r);
    _saveData();
    notifyListeners();
  }

  // ── Đánh giá nhanh ──
  void quickAnswerWord(String id, Skill skill, bool correct) {
    final w = _words.firstWhere((w) => w.id == id);
    w.quickAnswer(skill, correct);
    _saveData();
    notifyListeners();
  }

  // ── SM-2 Review ──
  void reviewWord(String id, int quality) {
    final w = _words.firstWhere((w) => w.id == id);
    w.review(quality: quality);
    _saveData();
    notifyListeners();
  }

  // ── Đặt vùng Venn (drag & drop) ──
  void setWordZone(String id, MasteryZone zone) {
    final w = _words.firstWhere((w) => w.id == id);
    w.setZone(zone);
    _saveData();
    notifyListeners();
  }

  // Thêm method này vào class VocabularyProvider

  /// SM-2 Review cho skill cụ thể
  void reviewWordSkill(String id, Skill skill, int quality) {
    final w = _words.firstWhere((w) => w.id == id);
    w.reviewSkill(skill, quality);
    _saveData();
    notifyListeners();
  }

  /// Lấy từ cần review cho skill cụ thể
  List<WordEntry> getDueForSkill(Skill skill) {
    return _words.where((w) => w.isSkillDue(skill)).toList()..sort(
      (a, b) =>
          a.skillDaysUntilDue(skill).compareTo(b.skillDaysUntilDue(skill)),
    );
  }

  /// Đếm tổng số review cần làm
  int get totalDueCount {
    return _words.fold(0, (sum, w) => sum + w.dueSkills.length);
  }

  // ── Lấy từ yếu nhất theo skill ──
  List<WordEntry> weakest(Skill skill, {int count = 10}) {
    final sorted = List<WordEntry>.from(_words)
      ..sort((a, b) => a.scoreOf(skill).compareTo(b.scoreOf(skill)));
    return sorted.take(count).toList();
  }

  // ── Tìm từ theo text ──
  WordEntry? findByWord(String word) {
    final normalized = word.toLowerCase().trim();
    try {
      return _words.firstWhere((w) => w.word.toLowerCase() == normalized);
    } catch (_) {
      return null;
    }
  }

  // ── Kiểm tra từ đã tồn tại chưa ──
  bool hasWord(String word) => findByWord(word) != null;

  // ═══════════════════════════════════════
  //  TEXT IMPORT
  // ═══════════════════════════════════════

  /// Phân tích text để tìm từ đã biết/chưa biết
  Map<String, WordEntry?> analyzeText(String text) {
    final uniqueWords = TextParser.extractUniqueWords(text);
    final result = <String, WordEntry?>{};

    for (final word in uniqueWords) {
      result[word] = findByWord(word);
    }

    return result;
  }

  /// Import từ từ text (chỉ thêm từ chưa có)
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

    if (newWords.isNotEmpty) {
      addWords(newWords);
    }

    return newWords;
  }

  // ═══════════════════════════════════════
  //  PERSISTENCE
  // ═══════════════════════════════════════

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _words.map((w) => w.toJson()).toList();
    await prefs.setString('vocabulary_data', jsonEncode(json));
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('vocabulary_data');

      if (data != null) {
        final json = jsonDecode(data) as List;
        _words = json.map((j) => WordEntry.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vocabulary_data');
    _words.clear();
    notifyListeners();
  }

  // ═══════════════════════════════════════
  //  SAMPLE DATA
  // ═══════════════════════════════════════

  // ═══════════════════════════════════════
  //  SAMPLE DATA - Cập nhật cho cấu trúc mới
  // ═══════════════════════════════════════
  void loadSample() {
    final rng = Random(42);
    final raw = <Map<String, String>>[
      {'w': 'apple', 'm': 'quả táo', 'p': '/ˈæp.əl/'},
      {'w': 'book', 'm': 'quyển sách', 'p': '/bʊk/'},
      {'w': 'cat', 'm': 'con mèo', 'p': '/kæt/'},
      {'w': 'dangerous', 'm': 'nguy hiểm', 'p': '/ˈdeɪn.dʒər.əs/'},
      {'w': 'elephant', 'm': 'con voi', 'p': '/ˈel.ɪ.fənt/'},
      {'w': 'flower', 'm': 'bông hoa', 'p': '/ˈflaʊ.ər/'},
      {'w': 'guitar', 'm': 'đàn ghi-ta', 'p': '/ɡɪˈtɑːr/'},
      {'w': 'house', 'm': 'ngôi nhà', 'p': '/haʊs/'},
      {'w': 'island', 'm': 'hòn đảo', 'p': '/ˈaɪ.lənd/'},
      {'w': 'jungle', 'm': 'rừng rậm', 'p': '/ˈdʒʌŋ.ɡəl/'},
      {'w': 'knowledge', 'm': 'kiến thức', 'p': '/ˈnɒl.ɪdʒ/'},
      {'w': 'language', 'm': 'ngôn ngữ', 'p': '/ˈlæŋ.ɡwɪdʒ/'},
      {'w': 'mountain', 'm': 'ngọn núi', 'p': '/ˈmaʊn.tɪn/'},
      {'w': 'notebook', 'm': 'vở ghi', 'p': '/ˈnəʊt.bʊk/'},
      {'w': 'ocean', 'm': 'đại dương', 'p': '/ˈəʊ.ʃən/'},
      {'w': 'pencil', 'm': 'bút chì', 'p': '/ˈpen.sɪl/'},
      {'w': 'question', 'm': 'câu hỏi', 'p': '/ˈkwes.tʃən/'},
      {'w': 'rainbow', 'm': 'cầu vồng', 'p': '/ˈreɪn.bəʊ/'},
      {'w': 'sunrise', 'm': 'bình minh', 'p': '/ˈsʌn.raɪz/'},
      {'w': 'tree', 'm': 'cái cây', 'p': '/triː/'},
      {'w': 'umbrella', 'm': 'cái ô', 'p': '/ʌmˈbrel.ə/'},
      {'w': 'violin', 'm': 'đàn vĩ cầm', 'p': '/ˌvaɪ.əˈlɪn/'},
      {'w': 'water', 'm': 'nước', 'p': '/ˈwɔː.tər/'},
      {'w': 'xylophone', 'm': 'đàn phiến gỗ', 'p': '/ˈzaɪ.lə.fəʊn/'},
      {'w': 'yesterday', 'm': 'hôm qua', 'p': '/ˈjes.tə.deɪ/'},
      {'w': 'zero', 'm': 'số không', 'p': '/ˈzɪə.rəʊ/'},
      {'w': 'beautiful', 'm': 'đẹp', 'p': '/ˈbjuː.tɪ.fəl/'},
      {'w': 'comfortable', 'm': 'thoải mái', 'p': '/ˈkʌm.fə.tə.bəl/'},
      {'w': 'environment', 'm': 'môi trường', 'p': '/ɪnˈvaɪ.rən.mənt/'},
      {'w': 'government', 'm': 'chính phủ', 'p': '/ˈɡʌv.ən.mənt/'},
    ];

    // 8 profiles tương ứng với 8 vùng Venn
    final profiles = <List<double>>[
      [0.1, 0.1, 0.1], // blind spot
      [0.8, 0.2, 0.2], // understand only
      [0.2, 0.8, 0.2], // listen only
      [0.2, 0.2, 0.8], // read only
      [0.8, 0.8, 0.2], // understand + listen
      [0.8, 0.2, 0.8], // understand + read
      [0.2, 0.8, 0.8], // listen + read
      [0.9, 0.9, 0.9], // mastered
    ];

    _words = List.generate(raw.length, (i) {
      final p = profiles[i % profiles.length];
      double jitter(double v) =>
          (v + (rng.nextDouble() - 0.5) * 0.25).clamp(0.0, 1.0);

      final uScore = jitter(p[0]);
      final lScore = jitter(p[1]);
      final rScore = jitter(p[2]);

      // Tạo review data cho mỗi skill với lịch review ngẫu nhiên
      final reviewDays = rng.nextInt(7) - 3; // -3 to 3 days

      return WordEntry(
        id: 'w$i',
        word: raw[i]['w']!,
        meaning: raw[i]['m']!,
        phonetic: raw[i]['p'],
        understandData: SkillReviewData(
          score: uScore,
          totalReviews: rng.nextInt(10),
          correctReviews: rng.nextInt(8),
          nextReview: DateTime.now().add(
            Duration(days: reviewDays + rng.nextInt(3)),
          ),
          interval: rng.nextInt(7) + 1,
          easeFactor: 2.5,
          repetitions: rng.nextInt(5),
        ),
        listenData: SkillReviewData(
          score: lScore,
          totalReviews: rng.nextInt(10),
          correctReviews: rng.nextInt(8),
          nextReview: DateTime.now().add(
            Duration(days: reviewDays + rng.nextInt(3) - 1),
          ),
          interval: rng.nextInt(7) + 1,
          easeFactor: 2.5,
          repetitions: rng.nextInt(5),
        ),
        readData: SkillReviewData(
          score: rScore,
          totalReviews: rng.nextInt(10),
          correctReviews: rng.nextInt(8),
          nextReview: DateTime.now().add(
            Duration(days: reviewDays + rng.nextInt(3) + 1),
          ),
          interval: rng.nextInt(7) + 1,
          easeFactor: 2.5,
          repetitions: rng.nextInt(5),
        ),
      );
    });

    notifyListeners();
  }
}
