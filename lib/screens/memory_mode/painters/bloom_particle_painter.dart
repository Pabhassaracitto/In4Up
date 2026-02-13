// lib/screens/memory_mode/painters/bloom_particle_painter.dart

import 'dart:math';
import 'package:flutter/material.dart';

/// Hiệu ứng particle khi từ lên stage Bloom (🌺)
/// Tạo hiệu ứng hoa nở, confetti dopamine reward
class BloomParticlePainter extends CustomPainter {
  final double progress; // 0.0 - 1.0
  final Color baseColor;
  final int particleCount;
  final Random _random;

  BloomParticlePainter({
    required this.progress,
    this.baseColor = const Color(0xFF9C27B0),
    this.particleCount = 30,
  }) : _random = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < particleCount; i++) {
      _drawParticle(canvas, centerX, centerY, i, size);
    }
  }

  void _drawParticle(
    Canvas canvas,
    double centerX,
    double centerY,
    int index,
    Size size,
  ) {
    final seed = Random(index * 7 + 13);

    // Direction angle
    final angle = seed.nextDouble() * pi * 2;

    // Distance from center (expands with progress)
    final maxRadius = size.width * 0.5;
    final distance = maxRadius * progress * (0.3 + seed.nextDouble() * 0.7);

    // Position
    final x = centerX + cos(angle) * distance;
    final y = centerY + sin(angle) * distance - progress * 50; // Float up

    // Size (shrinks as it moves out)
    final particleSize = (3 + seed.nextDouble() * 5) * (1.0 - progress * 0.5);

    // Opacity (fade out)
    final opacity = (1.0 - progress * 0.8).clamp(0.0, 1.0);

    // Color variations
    final colors = [
      baseColor,
      const Color(0xFFE91E63), // Pink
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF4CAF50), // Green
      Colors.white,
    ];
    final color = colors[index % colors.length];

    // Draw
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.fill;

    // Alternate shapes: circle, diamond, star
    if (index % 3 == 0) {
      // Diamond
      final path = Path()
        ..moveTo(x, y - particleSize)
        ..lineTo(x + particleSize * 0.6, y)
        ..lineTo(x, y + particleSize)
        ..lineTo(x - particleSize * 0.6, y)
        ..close();
      canvas.drawPath(path, paint);
    } else if (index % 3 == 1) {
      // Circle
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    } else {
      // Small star/dot with glow
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, particleSize * 0.5);
      canvas.drawCircle(Offset(x, y), particleSize * 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(BloomParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Widget bọc BloomParticlePainter với animation
class BloomParticleEffect extends StatefulWidget {
  final bool trigger;
  final Widget child;
  final VoidCallback? onComplete;

  const BloomParticleEffect({
    super.key,
    required this.trigger,
    required this.child,
    this.onComplete,
  });

  @override
  State<BloomParticleEffect> createState() => _BloomParticleEffectState();
}

class _BloomParticleEffectState extends State<BloomParticleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isPlaying = false);
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(BloomParticleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _play();
    }
  }

  void _play() {
    setState(() => _isPlaying = true);
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPlaying)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: BloomParticlePainter(
                        progress: _controller.value,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
