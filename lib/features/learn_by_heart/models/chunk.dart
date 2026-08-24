// lib/features/learn_by_heart/models/chunk.dart

import 'review_state.dart';

class Chunk {
  /// Số thứ tự chunk (1, 2, 3...)
  final int index;

  /// Tên hoặc nhãn chunk (ví dụ: "Nhân", "Quả", "Kết", "Chunk 1")
  final String label;

  /// Danh sách số dòng thuộc chunk này (1-based: [1, 2])
  final List<int> lineRange;

  /// Trạng thái ôn tập riêng của chunk
  final ReviewState chunkReviewState;

  /// Từ khóa gợi ý cho chunk này
  final List<String> keywords;

  /// Gợi ý ngắn cho chunk
  final String? clue;

  const Chunk({
    required this.index,
    required this.label,
    required this.lineRange,
    this.chunkReviewState = ReviewState.newItem,
    this.keywords = const [],
    this.clue,
  });

  Chunk copyWith({
    int? index,
    String? label,
    List<int>? lineRange,
    ReviewState? chunkReviewState,
    List<String>? keywords,
    String? clue,
  }) {
    return Chunk(
      index: index ?? this.index,
      label: label ?? this.label,
      lineRange: lineRange ?? this.lineRange,
      chunkReviewState: chunkReviewState ?? this.chunkReviewState,
      keywords: keywords ?? this.keywords,
      clue: clue ?? this.clue,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'label': label,
        'lineRange': lineRange,
        'chunkReviewState': chunkReviewState.name,
        'keywords': keywords,
        if (clue != null) 'clue': clue,
      };

  factory Chunk.fromJson(Map<String, dynamic> json) {
    return Chunk(
      index: json['index'] as int? ?? 1,
      label: json['label'] as String? ?? 'Chunk',
      lineRange: (json['lineRange'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [1],
      chunkReviewState: ReviewState.values.firstWhere(
        (s) => s.name == json['chunkReviewState'],
        orElse: () => ReviewState.newItem,
      ),
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      clue: json['clue'] as String?,
    );
  }
}
