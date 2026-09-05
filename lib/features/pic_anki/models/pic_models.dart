/// Pic Anki / Pic Express — thuần Dart, test được, không Hive.
library;

import 'package:in4up/knowledge/models/learning_state.dart';
import 'package:in4up/models/sm2_algorithm.dart';

/// Hình chữ nhật chuẩn hoá 0–1 theo ảnh gốc (xoay/scale an toàn).
class NormRect {
  final double x;
  final double y;
  final double w;
  final double h;

  const NormRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory NormRect.fromCorners(double x0, double y0, double x1, double y1) {
    final left = x0 < x1 ? x0 : x1;
    final top = y0 < y1 ? y0 : y1;
    final right = x0 < x1 ? x1 : x0;
    final bottom = y0 < y1 ? y1 : y0;
    return NormRect(
      x: left.clamp(0.0, 1.0),
      y: top.clamp(0.0, 1.0),
      w: (right - left).clamp(0.0, 1.0),
      h: (bottom - top).clamp(0.0, 1.0),
    );
  }

  double get area => w * h;

  bool get isUsable => w >= 0.02 && h >= 0.02;

  bool contains(double nx, double ny) {
    return nx >= x && ny >= y && nx <= x + w && ny <= y + h;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  factory NormRect.fromJson(Map<String, dynamic> json) => NormRect(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        w: (json['w'] as num).toDouble(),
        h: (json['h'] as num).toDouble(),
      );
}

/// Một vùng che = một thẻ SM-2 skill Đọc.
class PicMask {
  final String id;
  final NormRect rect;
  final String label;
  final String hint;
  final SM2Snapshot reading;

  const PicMask({
    required this.id,
    required this.rect,
    this.label = '',
    this.hint = '',
    required this.reading,
  });

  bool isDue(DateTime now) => !reading.dueDate.isAfter(now);

  PicMask copyWith({
    NormRect? rect,
    String? label,
    String? hint,
    SM2Snapshot? reading,
  }) {
    return PicMask(
      id: id,
      rect: rect ?? this.rect,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      reading: reading ?? this.reading,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'rect': rect.toJson(),
        'label': label,
        'hint': hint,
        'reading': reading.toJson(),
      };

  factory PicMask.fromJson(Map<String, dynamic> json) => PicMask(
        id: json['id'] as String,
        rect: NormRect.fromJson(json['rect'] as Map<String, dynamic>),
        label: json['label'] as String? ?? '',
        hint: json['hint'] as String? ?? '',
        reading: json['reading'] == null
            ? SM2Snapshot.initial()
            : SM2Snapshot.fromJson(json['reading'] as Map<String, dynamic>),
      );
}

class PicDeck {
  final String id;
  final String title;
  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final DateTime createdAt;
  final List<PicMask> masks;

  /// Entity do user gắn — Pic Express chấm coverage (GGUF không nhìn ảnh).
  final List<String> entities;

  const PicDeck({
    required this.id,
    required this.title,
    required this.imagePath,
    this.imageWidth = 0,
    this.imageHeight = 0,
    required this.createdAt,
    this.masks = const <PicMask>[],
    this.entities = const <String>[],
  });

  int dueCount(DateTime now) =>
      masks.where((m) => m.isDue(now)).length;

  PicDeck copyWith({
    String? title,
    String? imagePath,
    int? imageWidth,
    int? imageHeight,
    List<PicMask>? masks,
    List<String>? entities,
  }) {
    return PicDeck(
      id: id,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      createdAt: createdAt,
      masks: masks ?? this.masks,
      entities: entities ?? this.entities,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'imagePath': imagePath,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'createdAt': createdAt.toIso8601String(),
        'masks': masks.map((m) => m.toJson()).toList(),
        'entities': entities,
      };

  factory PicDeck.fromJson(Map<String, dynamic> json) {
    final rawMasks = json['masks'];
    final rawEntities = json['entities'];
    return PicDeck(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      imageWidth: json['imageWidth'] as int? ?? 0,
      imageHeight: json['imageHeight'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      masks: rawMasks is List
          ? rawMasks
              .whereType<Map>()
              .map((m) => PicMask.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const <PicMask>[],
      entities: rawEntities is List
          ? rawEntities.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

/// Anki-style: Again=1, Hard=3, Good=4, Easy=5. Chỉ skill reading.
class PicReviewGrade {
  static const int again = 1;
  static const int hard = 3;
  static const int good = 4;
  static const int easy = 5;
}

class PicReviewEngine {
  PicReviewEngine._();

  static PicMask applyReading({
    required PicMask mask,
    required int quality,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final result = SM2Algorithm.calculate(
      quality: quality,
      currentEF: mask.reading.easeFactor,
      currentInterval: mask.reading.interval,
      currentReps: mask.reading.repetitions,
      now: at,
    );
    return mask.copyWith(
      reading: SM2Snapshot(
        easeFactor: result.easeFactor,
        interval: result.interval,
        repetitions: result.repetitions,
        dueDate: result.nextReview,
        lastReviewedAt: at,
      ),
    );
  }

  /// Hàng ôn: mask đến hạn, ổn định theo id. Không lộ mask khác.
  static List<PicMask> dueQueue(PicDeck deck, DateTime now) {
    final due = deck.masks.where((m) => m.isDue(now)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return List<PicMask>.unmodifiable(due);
  }

  static PicMask? hitTest(List<PicMask> masks, double nx, double ny) {
    PicMask? best;
    for (final mask in masks) {
      if (!mask.rect.contains(nx, ny)) continue;
      if (best == null || mask.rect.area < best.rect.area) {
        best = mask;
      }
    }
    return best;
  }
}
