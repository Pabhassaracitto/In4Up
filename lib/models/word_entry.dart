import 'package:flutter/material.dart';
import 'sm2_algorithm.dart';

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
      case MasteryZone.blindSpot: return 'Điểm mù';
      case MasteryZone.understandOnly: return 'Chỉ Hiểu';
      case MasteryZone.listenOnly: return 'Chỉ Nghe';
      case MasteryZone.readOnly: return 'Chỉ Đọc';
      case MasteryZone.understandListen: return 'Hiểu + Nghe';
      case MasteryZone.understandRead: return 'Hiểu + Đọc';
      case MasteryZone.listenRead: return 'Nghe + Đọc';
      case MasteryZone.mastered: return 'Thành thạo';
    }
  }

  Color get color {
    switch (this) {
      case MasteryZone.blindSpot: return const Color(0xFF616161);
      case MasteryZone.understandOnly: return const Color(0xFF42A5F5);
      case MasteryZone.listenOnly: return const Color(0xFF66BB6A);
      case MasteryZone.readOnly: return const Color(0xFFEF5350);
      case MasteryZone.understandListen: return const Color(0xFF26C6DA);
      case MasteryZone.understandRead: return const Color(0xFFAB47BC);
      case MasteryZone.listenRead: return const Color(0xFFFFA726);
      case MasteryZone.mastered: return const Color(0xFFFFD54F);
    }
  }

  IconData get icon {
    switch (this) {
      case MasteryZone.blindSpot: return Icons.visibility_off;
      case MasteryZone.understandOnly: return Icons.lightbulb_outline;
      case MasteryZone.listenOnly: return Icons.hearing;
      case MasteryZone.readOnly: return Icons.auto_stories;
      case MasteryZone.understandListen: return Icons.psychology;
      case MasteryZone.understandRead: return Icons.school;
      case MasteryZone.listenRead: return Icons.record_voice_over;
      case MasteryZone.mastered: return Icons.star;
    }
  }

  String get tip {
    switch (this) {
      case MasteryZone.blindSpot: return 'Cần học cả 3 chiều: hiểu, nghe, đọc';
      case MasteryZone.understandOnly: return 'Biết nghĩa nhưng chưa nghe/đọc được';
      case MasteryZone.listenOnly: return 'Nghe được nhưng chưa hiểu nghĩa/đọc được';
      case MasteryZone.readOnly: return 'Đọc được nhưng chưa hiểu nghĩa/nghe được';
      case MasteryZone.understandListen: return 'Cần luyện ĐỌC thêm';
      case MasteryZone.understandRead: return 'Cần luyện NGHE thêm';
      case MasteryZone.listenRead: return 'Cần luyện HIỂU NGHĨA thêm';
      case MasteryZone.mastered: return 'Tuyệt vời! Đã thông thạo cả 3 chiều';
    }
  }
}

/// ═══════════════════════════════════════════════════════════════
///  SKILL REVIEW DATA - Dữ liệu SM-2 cho từng chiều kỹ năng
/// ═══════════════════════════════════════════════════════════════
class SkillReviewData {
  double score;           // 0.0 → 1.0
  double easeFactor;
  int interval;           // ngày
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

  bool get isDue => SM2Algorithm.isDue(nextReview);
  int get daysUntilDue => SM2Algorithm.daysUntilDue(nextReview);
  double get accuracy => totalReviews > 0 ? correctReviews / totalReviews : 0;

  void review(int quality) {
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

  factory SkillReviewData.fromJson(Map<String, dynamic> json) => SkillReviewData(
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
///  WORD ENTRY - Mô hình từ vựng 3 chiều + SM-2 riêng mỗi chiều
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
  })  : tags = tags ?? [],
        understandData = understandData ?? SkillReviewData(score: understand),
        listenData = listenData ?? SkillReviewData(score: listen),
        readData = readData ?? SkillReviewData(score: read),
        lastReviewed = lastReviewed ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  // ═══════════════════════════════════════
  //  GETTERS cho compatibility
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
  //  SM-2 per skill
  // ═══════════════════════════════════════
  
  SkillReviewData getSkillData(Skill skill) {
    switch (skill) {
      case Skill.understand: return understandData;
      case Skill.listen: return listenData;
      case Skill.read: return readData;
    }
  }

  bool isSkillDue(Skill skill) => getSkillData(skill).isDue;
  
  int skillDaysUntilDue(Skill skill) => getSkillData(skill).daysUntilDue;

  /// Từ có cần review skill nào không
  bool get hasAnyDue => 
      understandData.isDue || listenData.isDue || readData.isDue;

  /// Danh sách skill cần review
  List<Skill> get dueSkills {
    final list = <Skill>[];
    if (understandData.isDue) list.add(Skill.understand);
    if (listenData.isDue) list.add(Skill.listen);
    if (readData.isDue) list.add(Skill.read);
    return list;
  }

  // Backwards compatibility
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

  double get easeFactor => (
    understandData.easeFactor + 
    listenData.easeFactor + 
    readData.easeFactor
  ) / 3;

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
  //  VISUAL PROPERTIES
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
  //  ACTIONS
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
  }

  void updateAllScores(double uScore, double lScore, double rScore) {
    understandData.score = uScore.clamp(0.0, 1.0);
    listenData.score = lScore.clamp(0.0, 1.0);
    readData.score = rScore.clamp(0.0, 1.0);
  }

  void quickAnswer(Skill skill, bool correct) {
    final delta = correct ? 0.15 : -0.1;
    final data = getSkillData(skill);
    data.score = (data.score + delta).clamp(0.0, 1.0);
    data.totalReviews++;
    if (correct) data.correctReviews++;
    lastReviewed = DateTime.now();
  }

  /// Review với SM-2 cho một skill cụ thể
  void reviewSkill(Skill skill, int quality) {
    getSkillData(skill).review(quality);
    lastReviewed = DateTime.now();
  }

  /// Backwards compatibility
  void review({required int quality}) {
    // Review skill yếu nhất
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
  }

  double scoreOf(Skill s) {
    switch (s) {
      case Skill.understand: return understand;
      case Skill.listen: return listen;
      case Skill.read: return read;
    }
  }

  // ═══════════════════════════════════════
  //  SERIALIZATION
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
  };

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    // Handle old format
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
    );
  }

  WordEntry copyWith({
    String? word,
    String? meaning,
    String? phonetic,
    String? example,
  }) => WordEntry(
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
  );
}
