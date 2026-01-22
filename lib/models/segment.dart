class Segment {
  final String id;
  final String audioPath;
  final String title;
  final Duration startTime;
  final Duration endTime;
  final SegmentType type;
  final DifficultyLevel difficulty;
  final int repeatCount;
  final String? note;
  final DateTime createdAt;
  final List<String> tags;

  Segment({
    required this.id,
    required this.audioPath,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.type = SegmentType.favorite,
    this.difficulty = DifficultyLevel.medium,
    this.repeatCount = 1,
    this.note,
    required this.createdAt,
    this.tags = const [],
  });

  Duration get duration => endTime - startTime;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audioPath': audioPath,
      'title': title,
      'startTime': startTime.inMilliseconds,
      'endTime': endTime.inMilliseconds,
      'type': type.name,
      'difficulty': difficulty.name,
      'repeatCount': repeatCount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      id: json['id'],
      audioPath: json['audioPath'],
      title: json['title'],
      startTime: Duration(milliseconds: json['startTime']),
      endTime: Duration(milliseconds: json['endTime']),
      type: SegmentType.values.firstWhere((e) => e.name == json['type']),
      difficulty: DifficultyLevel.values.firstWhere((e) => e.name == json['difficulty']),
      repeatCount: json['repeatCount'],
      note: json['note'],
      createdAt: DateTime.parse(json['createdAt']),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

enum SegmentType {
  dharma,    // Pháp thoại
  english,   // Luyện tiếng Anh
  favorite,  // Yêu thích
  practice,  // Cần luyện tập
}

enum DifficultyLevel {
  easy,    // Dễ - lặp 1 lần
  medium,  // Vừa - lặp 3 lần
  hard,    // Khó - lặp 5 lần
}