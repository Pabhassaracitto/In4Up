import 'package:flutter/material.dart';
import 'package:in4up/core/language/tr_extension.dart';

class KnowledgeGraphPreview extends StatelessWidget {
  const KnowledgeGraphPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        children: [
          // Background "Graph" pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: CustomPaint(
                painter: _MiniGraphPainter(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'MẠNG LƯỚI LIÊN KẾT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Icon(Icons.hub, color: Colors.blue[200], size: 16),
                  ],
                ),
                const Spacer(),
                const TrText('124 liên kết nơ-ron', style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const TrText('Khám phá thế giới từ vựng của bạn', style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Xem Knowledge Graph →',
                    style: TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    final nodePaint = Paint()..color = Colors.blue.withValues(alpha: 0.4);

    final points = [
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width * 0.4, size.height * 0.7),
      Offset(size.width * 0.7, size.height * 0.8),
    ];

    // Draw lines
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        if ((i - j).abs() <= 2) {
          canvas.drawLine(points[i], points[j], paint);
        }
      }
    }

    // Draw nodes
    for (final p in points) {
      canvas.drawCircle(p, 4, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}