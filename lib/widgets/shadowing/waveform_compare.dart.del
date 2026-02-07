// lib/widgets/shadowing/waveform_compare.dart
// NEW - Widget so sánh dạng sóng giữa bản gốc và bản thu âm của người dùng
import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveformCompare extends StatelessWidget {
  final List<double> originalWaveform;
  final List<double> userWaveform;
  final double similarity;

  const WaveformCompare({
    super.key,
    required this.originalWaveform,
    required this.userWaveform,
    required this.similarity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.graphic_eq, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Waveform Comparison',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              _buildSimilarityBadge(),
            ],
          ),

          const SizedBox(height: 16),

          // Original waveform
          _buildWaveformRow(
            label: 'Original',
            waveform: originalWaveform,
            color: const Color(0xFF2196F3),
          ),

          const SizedBox(height: 12),

          // User waveform
          _buildWaveformRow(
            label: 'Your Recording',
            waveform: userWaveform,
            color: const Color(0xFFFF5722),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarityBadge() {
    final score = (similarity * 100).round();
    final color = score >= 80
        ? const Color(0xFF4CAF50)
        : score >= 60
            ? const Color(0xFFFFB300)
            : const Color(0xFFF44336);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        'Match: $score%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildWaveformRow({
    required String label,
    required List<double> waveform,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 60,
          child: CustomPaint(
            size: Size.infinite,
            painter: _WaveformPainter(
              waveform: waveform,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;

  _WaveformPainter({
    required this.waveform,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final barWidth = size.width / math.max(waveform.length, 1);

    for (int i = 0; i < waveform.length; i++) {
      final amplitude = waveform[i].clamp(0.0, 1.0);
      final barHeight = amplitude * (size.height / 2);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * barWidth,
          centerY - barHeight / 2,
          barWidth * 0.8,
          barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
