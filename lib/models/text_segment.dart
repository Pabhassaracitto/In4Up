// lib/models/text_segment.dart
// VipSound - Text Segment Model for Learning
// Designed for Buddhism & Language Learning

/// Độ khó của đoạn văn bản
enum TextSegmentDifficulty {
  easy,    // Dễ - 1-2 lần lặp
  medium,  // Vừa - 3-4 lần lặp
  hard,    // Khó - 5-7 lần lặp
  master,  // Cần thuộc lòng - 10+ lần lặp
}

/// Loại nội dung
enum TextSegmentCategory {
  // Phật Pháp
  sutra,           // Kinh điển
  dharma,          // Pháp thoại
  mantra,          // Chú/Thần chú
  verse,           // Kệ/Thi kệ

  // Tiếng Anh
  vocabulary,      // Từ vựng
  phrase,          // Cụm từ
  idiom,           // Thành ngữ
  sentence,        // Câu hoàn chỉnh
  grammar,         // Cấu trúc ngữ pháp

  // Chung
  favorite,        // Yêu thích
  difficult,       // Điểm mù/Khó nhớ
  review,          // Cần ôn tập
  custom,          // Tùy chỉnh
}

/// Model cho đoạn văn bản được đánh dấu
class TextSegment {
  final String id;
  final String content;           // Nội dung đoạn văn
  final int startOffset;          // Vị trí bắt đầu trong fullText
  final int endOffset;            // Vị trí kết thúc
  final TextSegmentDifficulty difficulty;
  final TextSegmentCategory category;
  final int repeatCount;          // Số lần lặp khi học
  final double ttsSpeed;          // Tốc độ TTS riêng
  final double gapDuration;       // Khoảng nghỉ giữa các lần lặp (giây)
  final String? note;             // Ghi chú (nghĩa, giải thích...)
  final String? translation;      // Bản dịch
  final String? pronunciation;    // Phiên âm (IPA, Pali...)
  final DateTime createdAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;          // Số lần đã ôn
  final List<String> tags;        // Tags tùy chỉnh

  TextSegment({
    required this.id,
    required this.content,
    required this.startOffset,
    required this.endOffset,
    this.difficulty = TextSegmentDifficulty.medium,
    this.category = TextSegmentCategory.custom,
    this.repeatCount = 3,
    this.ttsSpeed = 1.0,
    this.gapDuration = 1.0,
    this.note,
    this.translation,
    this.pronunciation,
    required this.createdAt,
    this.lastReviewedAt,
    this.reviewCount = 0,
    this.tags = const [],
  });

  /// Tạo bản sao với các giá trị mới
  TextSegment copyWith({
    String? id,
    String? content,
    int? startOffset,
    int? endOffset,
    TextSegmentDifficulty? difficulty,
    TextSegmentCategory? category,
    int? repeatCount,
    double? ttsSpeed,
    double? gapDuration,
    String? note,
    String? translation,
    String? pronunciation,
    DateTime? createdAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    List<String>? tags,
  }) {
    return TextSegment(
      id: id ?? this.id,
      content: content ?? this.content,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      repeatCount: repeatCount ?? this.repeatCount,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      gapDuration: gapDuration ?? this.gapDuration,
      note: note ?? this.note,
      translation: translation ?? this.translation,
      pronunciation: pronunciation ?? this.pronunciation,
      createdAt: createdAt ?? this.createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      tags: tags ?? this.tags,
    );
  }

  /// Tính số lần lặp đề xuất theo độ khó
  static int suggestedRepeatCount(TextSegmentDifficulty difficulty) {
    switch (difficulty) {
      case TextSegmentDifficulty.easy:
        return 2;
      case TextSegmentDifficulty.medium:
        return 4;
      case TextSegmentDifficulty.hard:
        return 7;
      case TextSegmentDifficulty.master:
        return 12;
    }
  }

  /// Tính tốc độ TTS đề xuất theo độ khó
  static double suggestedTtsSpeed(TextSegmentDifficulty difficulty) {
    switch (difficulty) {
      case TextSegmentDifficulty.easy:
        return 1.0;
      case TextSegmentDifficulty.medium:
        return 0.85;
      case TextSegmentDifficulty.hard:
        return 0.7;
      case TextSegmentDifficulty.master:
        return 0.6;
    }
  }

  /// Màu sắc theo độ khó
  static int difficultyColorValue(TextSegmentDifficulty difficulty) {
    switch (difficulty) {
      case TextSegmentDifficulty.easy:
        return 0xFF4CAF50; // Green
      case TextSegmentDifficulty.medium:
        return 0xFFFF9800; // Orange
      case TextSegmentDifficulty.hard:
        return 0xFFF44336; // Red
      case TextSegmentDifficulty.master:
        return 0xFF9C27B0; // Purple
    }
  }

  /// Icon theo category
  static int categoryIconCodePoint(TextSegmentCategory category) {
    switch (category) {
      case TextSegmentCategory.sutra:
        return 0xe3ae; // Icons.menu_book
      case TextSegmentCategory.dharma:
        return 0xe578; // Icons.spa
      case TextSegmentCategory.mantra:
        return 0xef3e; // Icons.auto_awesome
      case TextSegmentCategory.verse:
        return 0xe26b; // Icons.format_quote
      case TextSegmentCategory.vocabulary:
        return 0xe0c9; // Icons.abc
      case TextSegmentCategory.phrase:
        return 0xe8e2; // Icons.short_text
      case TextSegmentCategory.idiom:
        return 0xea72; // Icons.lightbulb
      case TextSegmentCategory.sentence:
        return 0xe8e3; // Icons.subject
      case TextSegmentCategory.grammar:
        return 0xf06c1; // Icons.rule
      case TextSegmentCategory.favorite:
        return 0xe87d; // Icons.favorite
      case TextSegmentCategory.difficult:
        return 0xe153; // Icons.flag
      case TextSegmentCategory.review:
        return 0xe5d5; // Icons.refresh
      case TextSegmentCategory.custom:
        return 0xe8b8; // Icons.label
    }
  }

  /// Chuyển đổi sang Map (cho lưu trữ)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'difficulty': difficulty.index,
      'category': category.index,
      'repeatCount': repeatCount,
      'ttsSpeed': ttsSpeed,
      'gapDuration': gapDuration,
      'note': note,
      'translation': translation,
      'pronunciation': pronunciation,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastReviewedAt': lastReviewedAt?.millisecondsSinceEpoch,
      'reviewCount': reviewCount,
      'tags': tags,
    };
  }

  /// Tạo từ Map
  factory TextSegment.fromMap(Map<String, dynamic> map) {
    return TextSegment(
      id: map['id'],
      content: map['content'],
      startOffset: map['startOffset'],
      endOffset: map['endOffset'],
      difficulty: TextSegmentDifficulty.values[map['difficulty'] ?? 1],
      category: TextSegmentCategory.values[map['category'] ?? 12],
      repeatCount: map['repeatCount'] ?? 3,
      ttsSpeed: map['ttsSpeed'] ?? 1.0,
      gapDuration: map['gapDuration'] ?? 1.0,
      note: map['note'],
      translation: map['translation'],
      pronunciation: map['pronunciation'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastReviewedAt: map['lastReviewedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastReviewedAt'])
          : null,
      reviewCount: map['reviewCount'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }
}

/// Thông tin về đoạn text được chọn
class SelectedTextInfo {
  final String text;
  final int startOffset;
  final int endOffset;
  final int lineIndex;

  SelectedTextInfo({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.lineIndex,
  });
}

/// Thống kê học tập
class TextLearningStats {
  final int totalSegments;
  final int easyCount;
  final int mediumCount;
  final int hardCount;
  final int masterCount;
  final int totalReviews;
  final Duration totalStudyTime;

  TextLearningStats({
    this.totalSegments = 0,
    this.easyCount = 0,
    this.mediumCount = 0,
    this.hardCount = 0,
    this.masterCount = 0,
    this.totalReviews = 0,
    this.totalStudyTime = Duration.zero,
  });

  double get completionRate {
    if (totalSegments == 0) return 0;
    return (easyCount + mediumCount * 0.5) / totalSegments;
  }
}