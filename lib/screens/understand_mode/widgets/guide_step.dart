// lib/screens/understand_mode/widgets/guide_step.dart

import 'package:flutter/material.dart';

class GuideStep extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;

  const GuideStep({
    super.key,
    required this.number,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
