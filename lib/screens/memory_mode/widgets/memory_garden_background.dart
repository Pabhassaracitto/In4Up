// lib/screens/memory_mode/widgets/memory_garden_background.dart

import 'package:flutter/material.dart';
import '../models/memory_stage.dart';
import '../painters/garden_painter.dart';

/// Background widget cho garden view
/// Animated breathing effect nhẹ nhàng
class MemoryGardenBackground extends StatelessWidget {
  final Map<MemoryStage, int> distribution;
  final Widget child;

  const MemoryGardenBackground({
    super.key,
    required this.distribution,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Static garden background (Disabled animation to save CPU/GPU and fix buffer errors)
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: GardenPainter(
                distribution: distribution,
                animationValue:
                    0.5, // Fixed value instead of animated controller
              ),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
