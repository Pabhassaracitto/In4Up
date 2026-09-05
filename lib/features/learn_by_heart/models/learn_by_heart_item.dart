// lib/features/learn_by_heart/models/learn_by_heart_item.dart

import 'chunk.dart';
import 'fsrs_models.dart';
import 'line_timestamp.dart';
import 'recitation_category.dart';
import 'recitation_language.dart';
import 'review_state.dart';

/// Model chính đại diện cho một bài học thuộc lòng (Kệ Pháp Cú, Kinh Tụng, Sutta...)
class LearnByHeartItem {
  // ===== CORE CONTENT =====
  final String id;
  final String title;
  final String subtitle;
  final RecitationCategory category;
  /// Canonical/source text. JSON key stays `paliText` for old items.
  final String paliText;
  /// Translation/meaning text. JSON key stays `vietnameseText` for old items.
  final String vietnameseText;
  final String? audioUrl;
  final String ttsLanguage;
  /// Language of [paliText] (`pi`, `en`, …). Default Pali.
  final String sourceLang;
  /// Language of [vietnameseText] (`vi`, `en`, …). Default Vietnamese.
  final String targetLang;
  /// Which side cloze / voice / chunking recites.
  final MemorizeSide memorizeSide;
  final List<LineTimestamp> lineTimestamps;
  final List<Chunk> chunkList;

  /// Số lần lặp TTS RIÊNG cho từng dòng (1-based line → count 1…999).
  final Map<int, int> lineRepeatOverrides;

  // ===== ELABORATIVE FIELDS =====
  final List<String> keywords;
  final String shortMeaning;
  final String lifeConnection;
  final String? cueImageUrl;

  // ===== SRS / FSRS STATE =====
  final ReviewState reviewState;
  final FSRSParams fsrsParams;
  final DateTime? nextReviewDate;
  final int consecutiveSuccesses;
  final int totalReviews;
  final int totalAssessments;
  final int lapseCount;
  final DateTime? lastAssessmentDate;
  final DateTime createdAt;
  final DateTime? lastReviewedAt;
  final bool isFavorite;
  final String? notes;
  final List<ReviewLog> reviewHistory;

  const LearnByHeartItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.category = RecitationCategory.dhammapada,
    required this.paliText,
    required this.vietnameseText,
    this.audioUrl,
    this.ttsLanguage = 'vi',
    this.sourceLang = 'pi',
    this.targetLang = 'vi',
    this.memorizeSide = MemorizeSide.target,
    this.lineTimestamps = const [],
    this.chunkList = const [],
    this.lineRepeatOverrides = const {},
    this.keywords = const [],
    this.shortMeaning = '',
    this.lifeConnection = '',
    this.cueImageUrl,
    this.reviewState = ReviewState.newItem,
    this.fsrsParams = const FSRSParams(),
    this.nextReviewDate,
    this.consecutiveSuccesses = 0,
    this.totalReviews = 0,
    this.totalAssessments = 0,
    this.lapseCount = 0,
    this.lastAssessmentDate,
    required this.createdAt,
    this.lastReviewedAt,
    this.isFavorite = false,
    this.notes,
    this.reviewHistory = const [],
  });

  // ==================== COMPUTED PROPERTIES ====================

  /// Đã đến hạn ôn tập chưa?
  bool get isDue {
    if (reviewState == ReviewState.newItem) return true;
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  /// Đủ điều kiện kích hoạt bài Kiểm tra thực chất (Assessment Layer)
  /// Trigger: Khi có 5 lần liên tiếp đánh giá Được / Dễ
  bool get isReadyForAssessment {
    return consecutiveSuccesses >= 5;
  }

  /// Đã thuộc lòng vững chắc (Mastered)
  bool get isMastered {
    return fsrsParams.stability >= 21.0 && reviewState == ReviewState.review;
  }

  List<String> get vietnameseLines => _splitLines(vietnameseText);

  List<String> get paliLines => _splitLines(paliText);

  String get sourceText => paliText;
  String get targetText => vietnameseText;

  String get memorizeText =>
      memorizeSide == MemorizeSide.source ? paliText : vietnameseText;

  String get supportText =>
      memorizeSide == MemorizeSide.source ? vietnameseText : paliText;

  List<String> get memorizeLines => _splitLines(memorizeText);

  List<String> get supportLines => _splitLines(supportText);

  String get memorizeLang =>
      memorizeSide == MemorizeSide.source ? sourceLang : targetLang;

  RecitationLanguage get sourceLanguage =>
      RecitationLanguage.fromCode(sourceLang);

  RecitationLanguage get targetLanguage =>
      RecitationLanguage.fromCode(targetLang);

  static List<String> _splitLines(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  // ==================== COPY WITH ====================

  LearnByHeartItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    RecitationCategory? category,
    String? paliText,
    String? vietnameseText,
    String? audioUrl,
    String? ttsLanguage,
    String? sourceLang,
    String? targetLang,
    MemorizeSide? memorizeSide,
    List<LineTimestamp>? lineTimestamps,
    List<Chunk>? chunkList,
    Map<int, int>? lineRepeatOverrides,
    List<String>? keywords,
    String? shortMeaning,
    String? lifeConnection,
    String? cueImageUrl,
    ReviewState? reviewState,
    FSRSParams? fsrsParams,
    DateTime? nextReviewDate,
    int? consecutiveSuccesses,
    int? totalReviews,
    int? totalAssessments,
    int? lapseCount,
    DateTime? lastAssessmentDate,
    DateTime? createdAt,
    DateTime? lastReviewedAt,
    bool? isFavorite,
    String? notes,
    List<ReviewLog>? reviewHistory,
  }) {
    return LearnByHeartItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      paliText: paliText ?? this.paliText,
      vietnameseText: vietnameseText ?? this.vietnameseText,
      audioUrl: audioUrl ?? this.audioUrl,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      memorizeSide: memorizeSide ?? this.memorizeSide,
      lineTimestamps: lineTimestamps ?? this.lineTimestamps,
      chunkList: chunkList ?? this.chunkList,
      lineRepeatOverrides: lineRepeatOverrides ?? this.lineRepeatOverrides,
      keywords: keywords ?? this.keywords,
      shortMeaning: shortMeaning ?? this.shortMeaning,
      lifeConnection: lifeConnection ?? this.lifeConnection,
      cueImageUrl: cueImageUrl ?? this.cueImageUrl,
      reviewState: reviewState ?? this.reviewState,
      fsrsParams: fsrsParams ?? this.fsrsParams,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      totalReviews: totalReviews ?? this.totalReviews,
      totalAssessments: totalAssessments ?? this.totalAssessments,
      lapseCount: lapseCount ?? this.lapseCount,
      lastAssessmentDate: lastAssessmentDate ?? this.lastAssessmentDate,
      createdAt: createdAt ?? this.createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
      reviewHistory: reviewHistory ?? this.reviewHistory,
    );
  }

  // ==================== SERIALIZATION ====================

  /// Parse `lineRepeatOverrides` từ JSON (key stringified, value num/string)
  /// — TOLERANT: bỏ entry rác (key không parse được / count ngoài 1…999).
  /// Item cũ không có key → const {}.
  static Map<int, int> _parseLineRepeatOverrides(dynamic raw) {
    final map = raw as Map<dynamic, dynamic>?;
    if (map == null) return const {};
    final out = <int, int>{};
    map.forEach((k, v) {
      final line = int.tryParse('$k') ?? -1;
      final count = (v is num ? v : int.tryParse('$v') ?? 0).toInt();
      if (line >= 1 && line <= 999 && count >= 1 && count <= 999) {
        out[line] = count;
      }
    });
    return out;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'category': category.name,
      'paliText': paliText,
      'vietnameseText': vietnameseText,
      'audioUrl': audioUrl,
      'ttsLanguage': ttsLanguage,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
      'memorizeSide': memorizeSide.name,
      'lineTimestamps': lineTimestamps.map((t) => t.toJson()).toList(),
      'chunkList': chunkList.map((c) => c.toJson()).toList(),
      // JSON không có int key → stringified.
      'lineRepeatOverrides': {
        for (final e in lineRepeatOverrides.entries) '${e.key}': e.value,
      },
      'keywords': keywords,
      'shortMeaning': shortMeaning,
      'lifeConnection': lifeConnection,
      'cueImageUrl': cueImageUrl,
      'reviewState': reviewState.name,
      'fsrsParams': fsrsParams.toJson(),
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'consecutiveSuccesses': consecutiveSuccesses,
      'totalReviews': totalReviews,
      'totalAssessments': totalAssessments,
      'lapseCount': lapseCount,
      'lastAssessmentDate': lastAssessmentDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'notes': notes,
      'reviewHistory': reviewHistory.map((h) => h.toJson()).toList(),
    };
  }

  factory LearnByHeartItem.fromJson(Map<String, dynamic> json) {
    return LearnByHeartItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Chưa đặt tên',
      subtitle: json['subtitle'] as String? ?? '',
      category: RecitationCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => RecitationCategory.dhammapada,
      ),
      paliText: json['paliText'] as String? ?? '',
      vietnameseText: json['vietnameseText'] as String? ?? '',
      audioUrl: json['audioUrl'] as String?,
      ttsLanguage: json['ttsLanguage'] as String? ?? 'vi',
      sourceLang: json['sourceLang'] as String? ?? 'pi',
      targetLang: json['targetLang'] as String? ?? 'vi',
      memorizeSide: MemorizeSide.values.firstWhere(
        (s) => s.name == json['memorizeSide'],
        orElse: () => MemorizeSide.target,
      ),
      lineTimestamps: (json['lineTimestamps'] as List<dynamic>?)
              ?.map((t) => LineTimestamp.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
      chunkList: (json['chunkList'] as List<dynamic>?)
              ?.map((c) => Chunk.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      // Tolerant: key JSON là string; bỏ entry rác — item cũ không có
      // key này → const {}.
      lineRepeatOverrides:
          _parseLineRepeatOverrides(json['lineRepeatOverrides']),
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((k) => k as String)
              .toList() ??
          const [],
      shortMeaning: json['shortMeaning'] as String? ?? '',
      lifeConnection: json['lifeConnection'] as String? ?? '',
      cueImageUrl: json['cueImageUrl'] as String?,
      reviewState: ReviewState.values.firstWhere(
        (s) => s.name == json['reviewState'],
        orElse: () => ReviewState.newItem,
      ),
      fsrsParams: json['fsrsParams'] != null
          ? FSRSParams.fromJson(json['fsrsParams'] as Map<String, dynamic>)
          : const FSRSParams(),
      nextReviewDate: json['nextReviewDate'] != null
          ? DateTime.parse(json['nextReviewDate'] as String)
          : null,
      consecutiveSuccesses: json['consecutiveSuccesses'] as int? ?? 0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      totalAssessments: json['totalAssessments'] as int? ?? 0,
      lapseCount: json['lapseCount'] as int? ?? 0,
      lastAssessmentDate: json['lastAssessmentDate'] != null
          ? DateTime.parse(json['lastAssessmentDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      notes: json['notes'] as String?,
      reviewHistory: (json['reviewHistory'] as List<dynamic>?)
              ?.map((h) => ReviewLog.fromJson(h as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearnByHeartItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
