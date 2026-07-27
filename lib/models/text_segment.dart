// lib/models/text_segment.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Độ khó của đoạn text
enum TextSegmentDifficulty {
  easy,
  medium,
  hard,
}

/// Loại đoạn text
enum TextSegmentType {
  vocabulary,
  phrase,
  sentence,
  paragraph,
  dharma,
  grammar,
}

/// Đoạn text đã đánh dấu để học
class TextSegment {
  final String id;
  final String name; // ← MỚI: tên hiển thị
  final String content;
  final int startOffset;
  final int endOffset;
  final int startLine; // ← MỚI: dòng bắt đầu
  final int endLine; // ← MỚI: dòng kết thúc
  final Color color; // ← MỚI: màu đánh dấu
  final TextSegmentDifficulty difficulty;
  final TextSegmentType type;
  final int repeatCount;
  final double ttsSpeed;
  final String? note;
  final String? ipa; // ★ THÊM DÒNG NÀY
  final String? translation;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? lastPracticed;
  final int practiceCount;
  final double masteryLevel;

  TextSegment({
    required this.id,
    String? name,
    required this.content,
    this.startOffset = 0,
    this.endOffset = 0,
    this.startLine = 0,
    this.endLine = 0,
    this.color = const Color(0xFF2196F3),
    this.difficulty = TextSegmentDifficulty.medium,
    this.type = TextSegmentType.phrase,
    this.repeatCount = 3,
    this.ttsSpeed = 1.0,
    this.note,
    this.ipa, // ★ THÊM DÒNG NÀY
    this.translation,
    this.tags = const [],
    DateTime? createdAt,
    this.lastPracticed,
    this.practiceCount = 0,
    this.masteryLevel = 0.0,
  })  : name = name ?? content,
        createdAt = createdAt ?? DateTime.now();

  int get lineCount => endLine - startLine + 1;

  TextSegment copyWith({
    String? id,
    String? name,
    String? content,
    int? startOffset,
    int? endOffset,
    int? startLine,
    int? endLine,
    Color? color,
    TextSegmentDifficulty? difficulty,
    TextSegmentType? type,
    int? repeatCount,
    double? ttsSpeed,
    String? note,
    String? translation,
    String? ipa, // ★ THÊM DÒNG NÀY
    List<String>? tags,
    DateTime? createdAt,
    DateTime? lastPracticed,
    int? practiceCount,
    double? masteryLevel,
  }) {
    return TextSegment(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      startLine: startLine ?? this.startLine,
      endLine: endLine ?? this.endLine,
      color: color ?? this.color,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      repeatCount: repeatCount ?? this.repeatCount,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      note: note ?? this.note,
      ipa: ipa ?? this.ipa, // ★ THÊM DÒNG NÀY
      translation: translation ?? this.translation,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      lastPracticed: lastPracticed ?? this.lastPracticed,
      practiceCount: practiceCount ?? this.practiceCount,
      masteryLevel: masteryLevel ?? this.masteryLevel,
    );
  }

  /// Màu theo độ khó
  Color get difficultyColor {
    switch (difficulty) {
      case TextSegmentDifficulty.easy:
        return const Color(0xFF4CAF50);
      case TextSegmentDifficulty.medium:
        return const Color(0xFFFF9800);
      case TextSegmentDifficulty.hard:
        return const Color(0xFFF44336);
    }
  }

  /// Icon theo loại
  IconData get typeIcon {
    switch (type) {
      case TextSegmentType.vocabulary:
        return Icons.abc;
      case TextSegmentType.phrase:
        return Icons.format_quote;
      case TextSegmentType.sentence:
        return Icons.short_text;
      case TextSegmentType.paragraph:
        return Icons.subject;
      case TextSegmentType.dharma:
        return Icons.spa;
      case TextSegmentType.grammar:
        return Icons.rule;
    }
  }

  /// Label tiếng Việt cho type
  String typeLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case TextSegmentType.vocabulary:
        return l10n.typeVocabulary;
      case TextSegmentType.phrase:
        return l10n.typePhrase;
      case TextSegmentType.sentence:
        return l10n.typeSentence;
      case TextSegmentType.paragraph:
        return l10n.typeParagraph;
      case TextSegmentType.dharma:
        return l10n.typeDharma;
      case TextSegmentType.grammar:
        return l10n.typeGrammar;
    }
  }

  /// Label tiếng Việt cho difficulty
  String difficultyLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (difficulty) {
      case TextSegmentDifficulty.easy:
        return l10n.diffEasy;
      case TextSegmentDifficulty.medium:
        return l10n.diffMedium;
      case TextSegmentDifficulty.hard:
        return l10n.diffHard;
    }
  }

  /// SRS - next review date
  DateTime? get nextReviewDate {
    if (lastPracticed == null) return DateTime.now();
    final intervals = [1, 1, 2, 3, 5, 8, 13, 21, 34];
    final intervalIndex = (masteryLevel * (intervals.length - 1)).round();
    final days = intervals[intervalIndex.clamp(0, intervals.length - 1)];
    return lastPracticed!.add(Duration(days: days));
  }

  bool get needsReview {
    if (lastPracticed == null) return true;
    final nextDate = nextReviewDate;
    if (nextDate == null) return true;
    return DateTime.now().isAfter(nextDate);
  }

  Duration get estimatedDuration {
    final wordCount = content.split(' ').length;
    final seconds = (wordCount / 150 * 60 / ttsSpeed).round();
    return Duration(seconds: seconds.clamp(1, 300));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'startLine': startLine,
      'endLine': endLine,
      'color': color.toARGB32(),
      'difficulty': difficulty.name,
      'type': type.name,
      'repeatCount': repeatCount,
      'ttsSpeed': ttsSpeed,
      'note': note,
      'ipa': ipa, // ★ THÊM
      'translation': translation,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'lastPracticed': lastPracticed?.toIso8601String(),
      'practiceCount': practiceCount,
      'masteryLevel': masteryLevel,
    };
  }

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      id: json['id'] as String,
      name: json['name'] as String?,
      content: json['content'] as String? ?? '',
      startOffset: json['startOffset'] as int? ?? 0,
      endOffset: json['endOffset'] as int? ?? 0,
      startLine: json['startLine'] as int? ?? 0,
      endLine: json['endLine'] as int? ?? 0,
      ipa: json['ipa'] as String?, // ★ THÊM
      color: json['color'] != null
          ? Color(json['color'] as int)
          : const Color(0xFF2196F3),
      difficulty: TextSegmentDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () => TextSegmentDifficulty.medium,
      ),
      type: TextSegmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TextSegmentType.phrase,
      ),
      repeatCount: json['repeatCount'] as int? ?? 3,
      ttsSpeed: (json['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
      note: json['note'] as String?,
      translation: json['translation'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      lastPracticed: json['lastPracticed'] != null
          ? DateTime.parse(json['lastPracticed'] as String)
          : null,
      practiceCount: json['practiceCount'] as int? ?? 0,
      masteryLevel: (json['masteryLevel'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Thông tin về đoạn text đang được chọn
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
