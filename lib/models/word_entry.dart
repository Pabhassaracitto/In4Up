import 'package:flutter/material.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

import 'vocabulary_type.dart';
import 'vocab_context.dart';

const double kThreshold = 0.6;

enum Skill { understand, listen, read }

enum MasteryZone {
  blindSpot,
  understandOnly,
  listenOnly,
  readOnly,
  understandListen,
  understandRead,
  listenRead,
  mastered,
}

extension MasteryZoneInfo on MasteryZone {
  String get label {
    switch (this) {
      case MasteryZone.blindSpot:
        return 'Điểm mù';
      case MasteryZone.understandOnly:
        return 'Chỉ Hiểu';
      case MasteryZone.listenOnly:
        return 'Chỉ Nghe';
      case MasteryZone.readOnly:
        return 'Chỉ Đọc';
      case MasteryZone.understandListen:
        return 'Hiểu + Nghe';
      case MasteryZone.understandRead:
        return 'Hiểu + Đọc';
      case MasteryZone.listenRead:
        return 'Nghe + Đọc';
      case MasteryZone.mastered:
        return 'Thành thạo';
    }
  }

  Color get color {
    switch (this) {
      case MasteryZone.blindSpot:
        return const Color(0xFF616161);
      case MasteryZone.understandOnly:
        return const Color(0xFF42A5F5);
      case MasteryZone.listenOnly:
        return const Color(0xFF66BB6A);
      case MasteryZone.readOnly:
        return const Color(0xFFEF5350);
      case MasteryZone.understandListen:
        return const Color(0xFF26C6DA);
      case MasteryZone.understandRead:
        return const Color(0xFFAB47BC);
      case MasteryZone.listenRead:
        return const Color(0xFFFFA726);
      case MasteryZone.mastered:
        return const Color(0xFFFFD54F);
    }
  }

  IconData get icon {
    switch (this) {
      case MasteryZone.blindSpot:
        return Icons.visibility_off;
      case MasteryZone.understandOnly:
        return Icons.lightbulb_outline;
      case MasteryZone.listenOnly:
        return Icons.hearing;
      case MasteryZone.readOnly:
        return Icons.auto_stories;
      case MasteryZone.understandListen:
        return Icons.psychology;
      case MasteryZone.understandRead:
        return Icons.school;
      case MasteryZone.listenRead:
        return Icons.record_voice_over;
      case MasteryZone.mastered:
        return Icons.star;
    }
  }

  String get tip {
    switch (this) {
      case MasteryZone.blindSpot:
        return 'Cần học cả 3 chiều: hiểu, nghe, đọc';
      case MasteryZone.understandOnly:
        return 'Biết nghĩa nhưng chưa nghe/đọc được';
      case MasteryZone.listenOnly:
        return 'Nghe được nhưng chưa hiểu nghĩa/đọc được';
      case MasteryZone.readOnly:
        return 'Đọc được nhưng chưa hiểu nghĩa/nghe được';
      case MasteryZone.understandListen:
        return 'Cần luyện ĐỌC thêm';
      case MasteryZone.understandRead:
        return 'Cần luyện NGHE thêm';
      case MasteryZone.listenRead:
        return 'Cần luyện HIỂU NGHĨA thêm';
      case MasteryZone.mastered:
        return 'Tuyệt vời! Đã thông thạo cả 3 chiều';
    }
  }
}

/// ═══════════════════════════════════════════════════════════════
/// SKILL REVIEW DATA — SM-2 cho từng chiều kỹ năng
/// ═══════════════════════════════════════════════════════════════
class SkillReviewData {
  double score; // 0.0 → 1.0
  double easeFactor;
  int interval; // ngày
  int repetitions;
  DateTime? nextReview;
  int totalReviews;
  int correctReviews;

  SkillReviewData({
    this.score = 0.0,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.nextReview,
    this.totalReviews = 0,
    this.correctReviews = 0,
  });

  bool get isDue {
    if (nextReview == null) return true;
    return DateTime.now().isAfter(nextReview!);
  }

  int get daysUntilDue {
    if (nextReview == null) return 0;
    final diff = nextReview!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  double get accuracy => totalReviews > 0 ? correctReviews / totalReviews : 0;

  void review(int quality) {
    // ADR-0001 / Task 2: gọi HÀM SM-2 DUY NHẤT — không tự giữ công thức
    // inline ở đây nữa. Ngữ nghĩa giữ nguyên hệ nghĩa cũ của chính file
    // này (đường ghi dữ liệu thật) ⇒ due date hiện tại không đổi.
    final result = SM2Algorithm.calculate(
      quality: quality,
      currentEF: easeFactor,
      currentInterval: interval,
      currentReps: repetitions,
    );
    easeFactor = result.easeFactor;
    interval = result.interval;
    repetitions = result.repetitions;
    nextReview = result.nextReview;

    // Bookkeeping mastery-score (0..1) — không phải SM-2, giữ nguyên hệ cũ.
    totalReviews++;
    if (quality >= 3) {
      correctReviews++;
      final delta = (quality - 2) * 0.1;
      score = (score + delta).clamp(0.0, 1.0);
    } else {
      final delta = (quality - 2) * 0.05;
      score = (score + delta).clamp(0.0, 1.0);
    }
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'easeFactor': easeFactor,
        'interval': interval,
        'repetitions': repetitions,
        'nextReview': nextReview?.toIso8601String(),
        'totalReviews': totalReviews,
        'correctReviews': correctReviews,
      };

  factory SkillReviewData.fromJson(Map<String, dynamic> json) =>
      SkillReviewData(
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval'] as int? ?? 0,
        repetitions: json['repetitions'] as int? ?? 0,
        nextReview: json['nextReview'] != null
            ? DateTime.parse(json['nextReview'] as String)
            : null,
        totalReviews: json['totalReviews'] as int? ?? 0,
        correctReviews: json['correctReviews'] as int? ?? 0,
      );
}

/// ═══════════════════════════════════════════════════════════════
/// WORD ENTRY — 3 chiều SM-2 + Hierarchical Vocabulary
/// ═══════════════════════════════════════════════════════════════
class WordEntry {
  final String id;
  String word;
  String meaning;
  String? phonetic;
  String? example;
  String? imageUrl;
  List<String> tags;

  // ── 3 chiều kỹ năng với SM-2 riêng ──
  SkillReviewData understandData;
  SkillReviewData listenData;
  SkillReviewData readData;

  DateTime lastReviewed;
  DateTime createdAt;
  DateTime updatedAt;

  // ── ★ MỚI: Hierarchical fields ──
  VocabularyType vocabType;
  List<VocabContext> contexts;
  List<String> parentIds;
  List<String> childIds;
  String? personalNotes;
  DifficultyLevel? userDifficulty;
  bool isUnborn;

  // ── ★ MỚI: Ma trận Ngôn ngữ và Chủ đề ──
  String language;
  String? topic;

  WordEntry({
    required this.id,
    required this.word,
    required this.meaning,
    this.phonetic,
    this.example,
    this.imageUrl,
    List<String>? tags,
    double understand = 0.0,
    double listen = 0.0,
    double read = 0.0,
    SkillReviewData? understandData,
    SkillReviewData? listenData,
    SkillReviewData? readData,
    DateTime? lastReviewed,
    DateTime? createdAt,
    DateTime? updatedAt,
    VocabularyType? vocabType,
    List<VocabContext>? contexts,
    List<String>? parentIds,
    List<String>? childIds,
    this.personalNotes,
    this.userDifficulty,
    this.isUnborn = false,
    this.language = 'en',
    this.topic,
  })  : tags = tags ?? [],
        understandData = understandData ?? SkillReviewData(score: understand),
        listenData = listenData ?? SkillReviewData(score: listen),
        readData = readData ?? SkillReviewData(score: read),
        lastReviewed = lastReviewed ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now(),
        vocabType = vocabType ?? VocabularyType.word,
        contexts = contexts ?? [],
        parentIds = parentIds ?? [],
        childIds = childIds ?? [];

  // ═══════════════════════════════════════
  // SKILL SCORE GETTERS
  // ═══════════════════════════════════════

  double get understand => understandData.score;
  set understand(double v) => understandData.score = v.clamp(0.0, 1.0);

  double get listen => listenData.score;
  set listen(double v) => listenData.score = v.clamp(0.0, 1.0);

  double get read => readData.score;
  set read(double v) => readData.score = v.clamp(0.0, 1.0);

  double get mastery => (understand + listen + read) / 3.0;

  bool get _u => understand >= kThreshold;
  bool get _l => listen >= kThreshold;
  bool get _r => read >= kThreshold;

  MasteryZone get zone {
    if (_u && _l && _r) return MasteryZone.mastered;
    if (_u && _l) return MasteryZone.understandListen;
    if (_u && _r) return MasteryZone.understandRead;
    if (_l && _r) return MasteryZone.listenRead;
    if (_u) return MasteryZone.understandOnly;
    if (_l) return MasteryZone.listenOnly;
    if (_r) return MasteryZone.readOnly;
    return MasteryZone.blindSpot;
  }

  Skill get weakestSkill {
    if (understand <= listen && understand <= read) return Skill.understand;
    if (listen <= read) return Skill.listen;
    return Skill.read;
  }

  // ═══════════════════════════════════════
  // SM-2 PER SKILL
  // ═══════════════════════════════════════

  SkillReviewData getSkillData(Skill skill) {
    switch (skill) {
      case Skill.understand:
        return understandData;
      case Skill.listen:
        return listenData;
      case Skill.read:
        return readData;
    }
  }

  bool isSkillDue(Skill skill) => getSkillData(skill).isDue;
  int skillDaysUntilDue(Skill skill) => getSkillData(skill).daysUntilDue;

  bool get hasAnyDue =>
      understandData.isDue || listenData.isDue || readData.isDue;

  List<Skill> get dueSkills {
    final list = <Skill>[];
    if (understandData.isDue) list.add(Skill.understand);
    if (listenData.isDue) list.add(Skill.listen);
    if (readData.isDue) list.add(Skill.read);
    return list;
  }

  bool get isDue => hasAnyDue;

  int get daysUntilDue {
    final days = [
      understandData.daysUntilDue,
      listenData.daysUntilDue,
      readData.daysUntilDue,
    ];
    return days.reduce((a, b) => a < b ? a : b);
  }

  int get totalReviews =>
      understandData.totalReviews +
      listenData.totalReviews +
      readData.totalReviews;

  int get correctReviews =>
      understandData.correctReviews +
      listenData.correctReviews +
      readData.correctReviews;

  double get accuracy => totalReviews > 0 ? correctReviews / totalReviews : 0;

  int get interval => [
        understandData.interval,
        listenData.interval,
        readData.interval,
      ].reduce((a, b) => a > b ? a : b);

  double get easeFactor =>
      (understandData.easeFactor +
          listenData.easeFactor +
          readData.easeFactor) /
      3;

  int get repetitions => [
        understandData.repetitions,
        listenData.repetitions,
        readData.repetitions,
      ].reduce((a, b) => a < b ? a : b);

  DateTime? get nextReview {
    final dates = [
      understandData.nextReview,
      listenData.nextReview,
      readData.nextReview,
    ].whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  // ═══════════════════════════════════════
  // HIERARCHICAL GETTERS
  // ═══════════════════════════════════════

  int get encounterCount => contexts.length;
  bool get isRoot => parentIds.isEmpty;
  bool get hasChildren => childIds.isNotEmpty;
  bool get hasParents => parentIds.isNotEmpty;

  Set<String> get sourceFiles => contexts
      .where((c) => c.sourceName != null)
      .map((c) => c.sourceName!)
      .toSet();

  VocabContext? get latestContext {
    if (contexts.isEmpty) return null;
    final sorted = List<VocabContext>.from(contexts)
      ..sort((a, b) => b.encounteredAt.compareTo(a.encounteredAt));
    return sorted.first;
  }

  void addContext(VocabContext ctx) {
    final existingIndex = contexts.indexWhere((c) => c.isLikelyDuplicateOf(ctx));
    if (existingIndex >= 0) {
      contexts[existingIndex] = contexts[existingIndex].mergeWith(ctx);
      updatedAt = DateTime.now();
      return;
    }

    contexts.add(ctx);
    updatedAt = DateTime.now();
  }

  void addParent(String parentId) {
    if (!parentIds.contains(parentId)) {
      parentIds.add(parentId);
      updatedAt = DateTime.now();
    }
  }

  void addChild(String childId) {
    if (!childIds.contains(childId)) {
      childIds.add(childId);
      updatedAt = DateTime.now();
    }
  }

  void removeParent(String parentId) {
    if (parentIds.remove(parentId)) {
      updatedAt = DateTime.now();
    }
  }

  void removeChild(String childId) {
    if (childIds.remove(childId)) {
      updatedAt = DateTime.now();
    }
  }

  // ═══════════════════════════════════════
  // VISUAL PROPERTIES
  // ═══════════════════════════════════════

  double get visualSize => 52.0 - mastery * 39.0;
  double get visualOpacity => 1.0 - mastery * 0.65;

  Color get visualColor {
    final base = zone.color;
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withSaturation((0.95 - mastery * 0.7).clamp(0.15, 0.95))
        .withLightness((0.45 + mastery * 0.2).clamp(0.35, 0.65))
        .toColor();
  }

  FontWeight get visualWeight =>
      mastery < 0.4 ? FontWeight.w800 : FontWeight.w400;

  // ═══════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════

  void updateScore(Skill skill, double value) {
    switch (skill) {
      case Skill.understand:
        understandData.score = value.clamp(0.0, 1.0);
      case Skill.listen:
        listenData.score = value.clamp(0.0, 1.0);
      case Skill.read:
        readData.score = value.clamp(0.0, 1.0);
    }
    updatedAt = DateTime.now();
  }

  void updateAllScores(double uScore, double lScore, double rScore) {
    understandData.score = uScore.clamp(0.0, 1.0);
    listenData.score = lScore.clamp(0.0, 1.0);
    readData.score = rScore.clamp(0.0, 1.0);
    updatedAt = DateTime.now();
  }

  void quickAnswer(Skill skill, bool correct) {
    final delta = correct ? 0.15 : -0.1;
    final data = getSkillData(skill);
    data.score = (data.score + delta).clamp(0.0, 1.0);
    data.totalReviews++;
    if (correct) data.correctReviews++;
    lastReviewed = DateTime.now();
    updatedAt = DateTime.now();
  }

  void reviewSkill(Skill skill, int quality) {
    getSkillData(skill).review(quality);
    lastReviewed = DateTime.now();
    updatedAt = DateTime.now();
  }

  void review({required int quality}) {
    reviewSkill(weakestSkill, quality);
  }

  void setZone(MasteryZone newZone) {
    switch (newZone) {
      case MasteryZone.blindSpot:
        understandData.score = 0.2;
        listenData.score = 0.2;
        readData.score = 0.2;
      case MasteryZone.understandOnly:
        understandData.score = 0.8;
        listenData.score = 0.2;
        readData.score = 0.2;
      case MasteryZone.listenOnly:
        understandData.score = 0.2;
        listenData.score = 0.8;
        readData.score = 0.2;
      case MasteryZone.readOnly:
        understandData.score = 0.2;
        listenData.score = 0.2;
        readData.score = 0.8;
      case MasteryZone.understandListen:
        understandData.score = 0.8;
        listenData.score = 0.8;
        readData.score = 0.2;
      case MasteryZone.understandRead:
        understandData.score = 0.8;
        listenData.score = 0.2;
        readData.score = 0.8;
      case MasteryZone.listenRead:
        understandData.score = 0.2;
        listenData.score = 0.8;
        readData.score = 0.8;
      case MasteryZone.mastered:
        understandData.score = 0.9;
        listenData.score = 0.9;
        readData.score = 0.9;
    }
    lastReviewed = DateTime.now();
    updatedAt = DateTime.now();
  }

  double scoreOf(Skill s) {
    switch (s) {
      case Skill.understand:
        return understand;
      case Skill.listen:
        return listen;
      case Skill.read:
        return read;
    }
  }

  // ═══════════════════════════════════════
  // SERIALIZATION
  // ═══════════════════════════════════════

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'meaning': meaning,
        'phonetic': phonetic,
        'example': example,
        'imageUrl': imageUrl,
        'tags': tags,
        'understandData': understandData.toJson(),
        'listenData': listenData.toJson(),
        'readData': readData.toJson(),
        'lastReviewed': lastReviewed.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'vocabType': vocabType.name,
        'contexts': contexts.map((c) => c.toJson()).toList(),
        'parentIds': parentIds,
        'childIds': childIds,
        'personalNotes': personalNotes,
        'userDifficulty': userDifficulty?.name,
        'isUnborn': isUnborn,
        'language': language,
        'topic': topic,
      };

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    // Parse vocabType
    VocabularyType type = VocabularyType.word;
    if (json['vocabType'] != null) {
      type = VocabularyType.values.firstWhere(
        (t) => t.name == json['vocabType'],
        orElse: () => VocabularyType.word,
      );
    }

    // Parse contexts
    List<VocabContext> contexts = [];
    if (json['contexts'] is List) {
      contexts = (json['contexts'] as List)
          .map((c) => VocabContext.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    // Backward compatibility: old format without understandData
    if (json.containsKey('understand') && !json.containsKey('understandData')) {
      return WordEntry(
        id: json['id'] as String,
        word: json['word'] as String,
        meaning: json['meaning'] as String,
        phonetic: json['phonetic'] as String?,
        example: json['example'] as String?,
        imageUrl: json['imageUrl'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        understand: (json['understand'] as num?)?.toDouble() ?? 0.0,
        listen: (json['listen'] as num?)?.toDouble() ?? 0.0,
        read: (json['read'] as num?)?.toDouble() ?? 0.0,
        lastReviewed: json['lastReviewed'] != null
            ? DateTime.parse(json['lastReviewed'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        vocabType: type,
        contexts: contexts,
        parentIds: (json['parentIds'] as List?)?.cast<String>() ?? [],
        childIds: (json['childIds'] as List?)?.cast<String>() ?? [],
        personalNotes: json['personalNotes'] as String?,
        userDifficulty: json['userDifficulty'] != null
            ? DifficultyLevel.values.firstWhere(
                (d) => d.name == json['userDifficulty'],
                orElse: () => DifficultyLevel.medium,
              )
            : null,
        isUnborn: json['isUnborn'] as bool? ?? false,
        language: json['language'] as String? ?? 'en',
        topic: json['topic'] as String?,
      );
    }

    return WordEntry(
      id: json['id'] as String,
      word: json['word'] as String,
      meaning: json['meaning'] as String,
      phonetic: json['phonetic'] as String?,
      example: json['example'] as String?,
      imageUrl: json['imageUrl'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      understandData: json['understandData'] != null
          ? SkillReviewData.fromJson(json['understandData'])
          : null,
      listenData: json['listenData'] != null
          ? SkillReviewData.fromJson(json['listenData'])
          : null,
      readData: json['readData'] != null
          ? SkillReviewData.fromJson(json['readData'])
          : null,
      lastReviewed: json['lastReviewed'] != null
          ? DateTime.parse(json['lastReviewed'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      vocabType: type,
      contexts: contexts,
      parentIds: (json['parentIds'] as List?)?.cast<String>() ?? [],
      childIds: (json['childIds'] as List?)?.cast<String>() ?? [],
      personalNotes: json['personalNotes'] as String?,
      userDifficulty: json['userDifficulty'] != null
          ? DifficultyLevel.values.firstWhere(
              (d) => d.name == json['userDifficulty'],
              orElse: () => DifficultyLevel.medium,
            )
          : null,
      isUnborn: json['isUnborn'] as bool? ?? false,
      language: json['language'] as String? ?? 'en',
      topic: json['topic'] as String?,
    );
  }

  WordEntry copyWith({
    String? word,
    String? meaning,
    String? phonetic,
    String? example,
    VocabularyType? vocabType,
    String? personalNotes,
    DifficultyLevel? userDifficulty,
    bool? isUnborn,
    String? language,
    String? topic,
  }) =>
      WordEntry(
        id: id,
        word: word ?? this.word,
        meaning: meaning ?? this.meaning,
        phonetic: phonetic ?? this.phonetic,
        example: example ?? this.example,
        imageUrl: imageUrl,
        tags: tags,
        understandData: understandData,
        listenData: listenData,
        readData: readData,
        lastReviewed: lastReviewed,
        createdAt: createdAt,
        vocabType: vocabType ?? this.vocabType,
        contexts: contexts,
        parentIds: parentIds,
        childIds: childIds,
        personalNotes: personalNotes ?? this.personalNotes,
        userDifficulty: userDifficulty ?? this.userDifficulty,
        isUnborn: isUnborn ?? this.isUnborn,
        language: language ?? this.language,
        topic: topic ?? this.topic,
      );
}
