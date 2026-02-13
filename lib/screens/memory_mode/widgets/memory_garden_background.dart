// lib/screens/memory_mode/widgets/memory_garden_background.dart

import 'package:flutter/material.dart';
import '../models/memory_stage.dart';
import '../painters/garden_painter.dart';

/// Background widget cho garden view
/// Animated breathing effect nhẹ nhàng
class MemoryGardenBackground extends StatefulWidget {
  final Map<MemoryStage, int> distribution;
  final Widget child;

  const MemoryGardenBackground({
    super.key,
    required this.distribution,
    required this.child,
  });

  @override
  State<MemoryGardenBackground> createState() => _MemoryGardenBackgroundState();
}

class _MemoryGardenBackgroundState extends State<MemoryGardenBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
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
        // Animated garden background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: GardenPainter(
                    distribution: widget.distribution,
                    animationValue: _controller.value,
                  ),
                ),
              );
            },
          ),
        ),
        // Content
        widget.child,
      ],
    );
  }
}
