// lib/models/segment.dart
import 'package:hive/hive.dart';

part 'segment.g.dart';

@HiveType(typeId: 0)
class Segment extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String audioPath; // File audio chứa segment này

  @HiveField(2)
  String title; // "Tứ Diệu Đế", "Câu khó số 1"

  @HiveField(3)
  Duration startTime;

  @HiveField(4)
  Duration endTime;

  @HiveField(5)
  SegmentType type; // pháp, english, favorite

  @HiveField(6)
  DifficultyLevel difficulty; // easy, medium, hard

  @HiveField(7)
  int repeatCount; // Số lần lặp mặc định: 1, 3, 5

  @HiveField(8)
  String? note; // Ghi chú

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  List<String> tags; // ["từ vựng", "ngữ pháp", "phát âm"]

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