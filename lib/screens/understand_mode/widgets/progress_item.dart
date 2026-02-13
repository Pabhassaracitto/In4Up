// lib/screens/understand_mode/widgets/progress_item.dart

import 'package:flutter/material.dart';

class ProgressItem extends StatelessWidget {
  final String label;
  final int? current;
  final int? target;
  final String? value;
  final Color color;

  const ProgressItem({
    super.key,
    required this.label,
    this.current,
    this.target,
    this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? '$current/$target';
    final progress = (current != null && target != null && target! > 0)
        ? current! / target!
        : 0.0;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          displayValue,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (value == null) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3,
          ),
        ],
      ],
    );
  }
}
