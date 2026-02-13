// lib/screens/understand_mode/widgets/speed_chip.dart

import 'package:flutter/material.dart';

class SpeedChip extends StatelessWidget {
  final double speed;
  final VoidCallback onTap;

  const SpeedChip({
    super.key,
    required this.speed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: speed != 1.0
              ? Colors.orange.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, size: 14, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              '${speed}x',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
