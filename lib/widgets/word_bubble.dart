import 'package:flutter/material.dart';

import '../models/word_entry.dart';

class WordBubble extends StatelessWidget {
  final WordEntry word;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool dragging;

  const WordBubble({
    super.key,
    required this.word,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.dragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: word.visualSize * 0.3,
          vertical: word.visualSize * 0.15,
        ),
        decoration: BoxDecoration(
          color: selected
              ? word.visualColor.withValues(alpha: 0.3)
              : word.visualColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(word.visualSize * 0.4),
          border: Border.all(
            color: selected ? Colors.white : word.visualColor,
            width: selected ? 3.0 : (word.mastery < 0.3 ? 2.0 : 0.5),
          ),
          boxShadow: [
            if (word.mastery < 0.3 || selected || dragging)
              BoxShadow(
                color: word.visualColor.withValues(alpha: dragging ? 0.6 : 0.4),
                blurRadius: dragging ? 12 : 8,
                spreadRadius: dragging ? 2 : 1,
              ),
          ],
        ),
        transform:
            dragging ? (Matrix4.identity()..scale(1.1)) : Matrix4.identity(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word.word,
              style: TextStyle(
                fontSize: word.visualSize * 0.35,
                fontWeight: word.visualWeight,
                color: word.visualColor,
                letterSpacing: word.mastery < 0.3 ? 1.0 : 0,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(word.understand, const Color(0xFF42A5F5)),
                const SizedBox(width: 2),
                _dot(word.listen, const Color(0xFF66BB6A)),
                const SizedBox(width: 2),
                _dot(word.read, const Color(0xFFEF5350)),
              ],
            ),
            // Due indicator
            if (word.isDue)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  word.daysUntilDue < 0
                      ? '${-word.daysUntilDue}d overdue'
                      : 'Due',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot(double score, Color color) {
    final s = word.visualSize * 0.1 + 2;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: score >= kThreshold ? color : color.withValues(alpha: 0.2),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
    );
  }
}
