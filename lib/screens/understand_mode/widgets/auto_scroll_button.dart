// lib/screens/understand_mode/widgets/auto_scroll_button.dart

import 'package:flutter/material.dart';

class AutoScrollButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const AutoScrollButton({
    super.key,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFFB300).withOpacity(0.2)
              : Colors.black45,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFFB300).withOpacity(0.5)
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.vertical_align_center,
              size: 14,
              color: isActive ? const Color(0xFFFFB300) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'Auto',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFFFFB300) : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
