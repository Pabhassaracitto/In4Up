/// ═══════════════════════════════════════════════════════════════
/// MASTERY GEOMETRY — hình học hexagram + scatter (ADR-0019)
///
/// Pure functions — không I/O, deterministic, test đơn giản.
/// Painter (P3 UI) tiêu thụ module này.
///
/// Hexagram (Word view):
///   6 đỉnh trên 3 đường kính xuyên tâm (mirror pairs):
///     Hiểu (90°)    ↔ Dùng (270°)   — trục dọc
///     Nghe (150°)   ↔ Nói (330°)    — chéo trái
///     Đọc (30°)    ↔ Viết (210°)   — chéo phải
///   Input tam giác trong (Hiểu/Nghe/Đọc), Output tam giác ngoài.
///   Khoảng cách từ tâm = mastery × R.
///   Production gap = khoảng cách giữa 2 đỉnh mirror.
///
/// Null-vertex contract:
///   Đỉnh chưa có bằng chứng → vị trí null (không tính gap, envelope
///   không nội suy qua null). Painter vẽ vòng rỗng nét đứt ở R.
///
/// Scatter (Collection view):
///   x = Input mastery (avg hiểu/nghe/đọc), y = Output mastery
///   (avg dùng/nói/viết). Đường chéo = cân bằng. Production gap =
///   khoảng cách tới đường chéo.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:math' as math;

import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;

/// Góc (độ) của mỗi đỉnh hexagram. Input trên, Output dưới.
/// 3 đường kính 60° apart.
const Map<SkillDimension, double> kVertexAngle = {
  SkillDimension.understanding: 90.0,  // top
  SkillDimension.listening: 150.0,    // upper-left
  SkillDimension.reading: 30.0,       // upper-right
  SkillDimension.use: 270.0,          // bottom
  SkillDimension.speak: 330.0,        // lower-right
  SkillDimension.write: 210.0,        // lower-left
};

/// Cặp mirror (đường kính xuyên tâm).
const List<List<SkillDimension>> kMirrorPairs = [
  [SkillDimension.understanding, SkillDimension.use],
  [SkillDimension.listening, SkillDimension.speak],
  [SkillDimension.reading, SkillDimension.write],
];

/// Convert degree → radian.
double _deg2rad(double deg) => deg * math.pi / 180.0;

/// Vị trí đỉnh hexagram.
///
/// [center] tâm hexagram.
/// [radius] bán kính ngoài (R).
/// [mastery] giá trị mastery ∈ [0,1] — null/không có → null.
///
/// Khi mastery null → trả null (null-vertex contract).
/// Khi mastery ∈ [0,1] → Offset ở khoảng cách R×mastery từ tâm.
Offset? vertexPosition({
  required Offset center,
  required double radius,
  required SkillDimension dim,
  required double? mastery,
}) {
  if (mastery == null) return null;
  final angle = _deg2rad(kVertexAngle[dim]!);
  final r = radius * mastery.clamp(0.0, 1.0);
  return Offset(
    center.dx + r * math.cos(angle),
    center.dy - r * math.sin(angle), // y-down screen
  );
}

/// Production gap = khoảng cách giữa 2 đỉnh mirror.
///
/// Nếu cả 2 đều có mastery → khoảng cách thực tế.
/// Nếu 1 null → trả null (envelope không nội suy qua null).
/// Nếu cả 2 null → null.
double? productionGap({
  required Offset center,
  required double radius,
  required List<SkillDimension> mirrorPair,
  required Map<SkillDimension, double?> masteryMap,
}) {
  final a = mirrorPair[0];
  final b = mirrorPair[1];
  final posA = vertexPosition(
    center: center, radius: radius, dim: a,
    mastery: masteryMap[a],
  );
  final posB = vertexPosition(
    center: center, radius: radius, dim: b,
    mastery: masteryMap[b],
  );
  if (posA == null || posB == null) return null;
  return (posA - posB).distance;
}

/// Input mastery = trung bình hiểu/nghe/đọc (chỉ tính có evidence).
/// Không bù 0 — không có bằng chứng → không tính.
double? inputMastery(Map<SkillDimension, double?> masteryMap) {
  final parts = <double>[];
  for (final dim in SkillDimension.values) {
    if (dim == SkillDimension.use ||
        dim == SkillDimension.speak ||
        dim == SkillDimension.write) continue;
    final v = masteryMap[dim];
    if (v != null) parts.add(v);
  }
  if (parts.isEmpty) return null;
  return parts.fold<double>(0, (a, b) => a + b) / parts.length;
}

/// Output mastery = trung bình dùng/nói/viết (chỉ tính có evidence).
double? outputMastery(Map<SkillDimension, double?> masteryMap) {
  final parts = <double>[];
  for (final dim in SkillDimension.values) {
    if (dim == SkillDimension.understanding ||
        dim == SkillDimension.listening ||
        dim == SkillDimension.reading) continue;
    final v = masteryMap[dim];
    if (v != null) parts.add(v);
  }
  if (parts.isEmpty) return null;
  return parts.fold<double>(0, (a, b) => a + b) / parts.length;
}

/// Scatter position: x = Input, y = Output.
/// Trả null nếu thiếu input hoặc output evidence.
Offset? scatterPosition({
  required Offset origin,
  required double scale,
  required Map<SkillDimension, double?> masteryMap,
}) {
  final inp = inputMastery(masteryMap);
  final out = outputMastery(masteryMap);
  if (inp == null || out == null) return null;
  return Offset(origin.dx + inp * scale, origin.dy - out * scale);
}

/// Production gap scatter = khoảng cách tới đường chéo (y = x).
/// Đường chéo = cân bằng. Khoảng cách lớn → mất cân bằng.
/// Trả null nếu thiếu input hoặc output.
double? scatterGap({required Map<SkillDimension, double?> masteryMap}) {
  final inp = inputMastery(masteryMap);
  final out = outputMastery(masteryMap);
  if (inp == null || out == null) return null;
  // Khoảng cách từ (inp, out) tới đường chéo y = x (trong [0,1]²).
  // d = |out - inp| / √2
  return (out - inp).abs() / math.sqrt(2);
}
