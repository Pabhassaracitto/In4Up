// lib/screens/memory_mode/widgets/memory_bottom_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/memory_controller.dart';
import '../models/review_session.dart';
import 'package:in4up/core/language/tr_extension.dart';

class MemoryBottomBar extends StatelessWidget {
  const MemoryBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MemoryController>();
    final stats = controller.stats;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  if (stats.totalItems > 0)
                    Text(
                      'Content',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                ],
              ),
              const Spacer(),
              _ReviewModeButton(
                icon: Icons.water_drop,
                label: 'SRS',
                color: const Color(0xFF4CAF50),
                count: stats.dueToday,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  controller.startReview(mode: ReviewMode.spaced);
                },
              ),
              const SizedBox(width: 8),
              _ReviewModeButton(
                icon: Icons.local_fire_department,
                label: context.tr('Nhồi'),
                color: const Color(0xFFFF9800),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  controller.startReview(mode: ReviewMode.cram, maxCards: 20);
                },
              ),
              const SizedBox(width: 8),
              _ReviewModeButton(
                icon: Icons.warning_amber,
                label: context.l10n.diffHard,
                color: const Color(0xFFF44336),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  controller.startReview(mode: ReviewMode.difficult);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _ReviewModeButton({
    required this.icon,
    required this.label,
    required this.color,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}