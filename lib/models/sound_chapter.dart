// lib/models/sound_chapter.dart
// Soundlist – "Chương / Mục" của cây mục lục âm thanh (Sound TOC)
//
// Giống mục lục sách: file audio = cuốn sách, chương/mục = các cấp của mục lục.
// Mỗi chương có thể neo vào một mốc thời gian (position) để nhảy đến ngay
// khi người dùng chạm. parentId cho phép tạo cây linh hoạt (chương → mục → đoạn).

class SoundChapter {
  final String id;
  final String audioPath;
  String title;
  String? note;

  /// Mốc neo trong file audio (null = chương không neo thời gian, chỉ là
  /// nhóm tổ chức cho các mục con).
  Duration? position;

  /// null = mục gốc (cấp 1 của cây).
  String? parentId;

  /// Thứ tự hiển thị trong cùng một cha.
  int order;

  final DateTime createdAt;

  SoundChapter({
    required this.id,
    required this.audioPath,
    required this.title,
    this.note,
    this.position,
    this.parentId,
    this.order = 0,
    required this.createdAt,
  });

  bool get isRoot => parentId == null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audioPath': audioPath,
      'title': title,
      'note': note,
      'position': position?.inMilliseconds,
      'parentId': parentId,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SoundChapter.fromJson(Map<String, dynamic> json) {
    return SoundChapter(
      id: json['id'] as String,
      audioPath: json['audioPath'] as String,
      title: (json['title'] as String?) ?? 'Chưa đặt tên',
      note: json['note'] as String?,
      position: json['position'] == null
          ? null
          : Duration(milliseconds: (json['position'] as num).toInt()),
      parentId: json['parentId'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
