import 'dart:math';

import 'package:in4up/core/language/localized_material.dart';

import '../models/word_entry.dart';

class SkillTriangle extends StatelessWidget {
  final WordEntry word;
  final double size;
  final bool showLabels;
  final bool interactive;
  final Function(Skill, double)? onScoreChanged;

  const SkillTriangle({
    super.key,
    required this.word,
    this.size = 120,
    this.showLabels = true,
    this.interactive = false,
    this.onScoreChanged,
  });

  String _localizedInitial(BuildContext context, String source) {
    final translated = context.uiText(source).trim();
    return translated.isEmpty ? '' : String.fromCharCode(translated.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TrianglePainter(
          understand: word.understand,
          listen: word.listen,
          read: word.read,
          showLabels: showLabels,
          labels: [
            _localizedInitial(context, 'HIỂU'),
            _localizedInitial(context, 'NGHE'),
            _localizedInitial(context, 'ĐỌC'),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final double understand, listen, read;
  final bool showLabels;
  final List<String> labels;

  _TrianglePainter({
    required this.understand,
    required this.listen,
    required this.read,
    required this.labels,
    this.showLabels = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide * 0.42;

    final vertices = <Offset>[
      Offset(cx, cy - r),
      Offset(cx - r * cos(pi / 6), cy + r * sin(pi / 6)),
      Offset(cx + r * cos(pi / 6), cy + r * sin(pi / 6)),
    ];

    // Frame
    final framePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final framePath = Path()..addPolygon(vertices, true);
    canvas.drawPath(framePath, framePaint);

    for (final v in vertices) {
      canvas.drawLine(Offset(cx, cy), v, framePaint);
    }

    // Data area
    final scores = [understand, listen, read];
    final dataPoints = List.generate(3, (i) {
      final dx = cx + (vertices[i].dx - cx) * scores[i];
      final dy = cy + (vertices[i].dy - cy) * scores[i];
      return Offset(dx, dy);
    });

    final fillPaint = Paint()
      ..color = _getAreaColor().withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = _getAreaColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final dataPath = Path()..addPolygon(dataPoints, true);
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Dots
    final dotColors = [
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFEF5350),
    ];
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        dataPoints[i],
        4,
        Paint()..color = dotColors[i],
      );
    }

    // Labels
    if (showLabels) {
      final labelOffsets = [
        Offset(cx - 4, cy - r - 16),
        Offset(cx - r * cos(pi / 6) - 14, cy + r * sin(pi / 6) + 4),
        Offset(cx + r * cos(pi / 6) + 4, cy + r * sin(pi / 6) + 4),
      ];

      for (int i = 0; i < 3; i++) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              color: dotColors[i],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, labelOffsets[i]);
      }
    }
  }

  Color _getAreaColor() {
    final avg = (understand + listen + read) / 3;
    if (avg > 0.7) return const Color(0xFFFFD54F);
    if (avg > 0.4) return const Color(0xFF42A5F5);
    return const Color(0xFFEF5350);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) =>
      old.understand != understand ||
      old.listen != listen ||
      old.read != read ||
      old.showLabels != showLabels ||
      old.labels[0] != labels[0] ||
      old.labels[1] != labels[1] ||
      old.labels[2] != labels[2];
}
