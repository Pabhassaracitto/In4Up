// lib/screens/memory_mode/widgets/memory_top_bar.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../widgets/sync_status_badge.dart';
import '../controllers/memory_controller.dart';
import '../models/review_session.dart';

class MemoryTopBar extends StatelessWidget {
  const MemoryTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MemoryController>();
    final stats = controller.stats;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          _ViewToggle(
            current: controller.viewMode,
            onChanged: controller.setViewMode,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ReviewChip(
                    icon: Icons.water_drop,
                    label: 'SRS',
                    color: const Color(0xFF4CAF50),
                    count: stats.dueToday,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      controller.startReview(mode: ReviewMode.spaced);
                    },
                  ),
                  const SizedBox(width: 6),
                  _ReviewChip(
                    icon: Icons.local_fire_department,
                    label: 'Nhồi',
                    color: const Color(0xFFFF9800),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      controller.startReview(
                        mode: ReviewMode.cram,
                        maxCards: 20,
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _ReviewChip(
                    icon: Icons.warning_amber,
                    label: 'Khó',
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
          const SizedBox(width: 6),
          const SyncStatusBadge(),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showSortMenu(context, controller);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sort, size: 18, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context, MemoryController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sắp xếp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...MemorySortMode.values.map((mode) {
              final isSelected = controller.sortMode == mode;
              return ListTile(
                leading: Icon(
                  _sortIcon(mode),
                  color: isSelected ? const Color(0xFF4CAF50) : Colors.grey,
                ),
                title: Text(
                  _sortLabel(mode),
                  style: TextStyle(
                    color:
                        isSelected ? const Color(0xFF4CAF50) : Colors.white70,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check,
                        color: Color(0xFF4CAF50), size: 20)
                    : null,
                onTap: () {
                  controller.setSortMode(mode);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _sortIcon(MemorySortMode mode) {
    switch (mode) {
      case MemorySortMode.urgency:
        return Icons.priority_high;
      case MemorySortMode.alphabetical:
        return Icons.sort_by_alpha;
      case MemorySortMode.stage:
        return Icons.park;
      case MemorySortMode.newest:
        return Icons.schedule;
      case MemorySortMode.accuracy:
        return Icons.trending_up;
    }
  }

  String _sortLabel(MemorySortMode mode) {
    switch (mode) {
      case MemorySortMode.urgency:
        return 'Khẩn cấp nhất';
      case MemorySortMode.alphabetical:
        return 'A-Z';
      case MemorySortMode.stage:
        return 'Theo giai đoạn';
      case MemorySortMode.newest:
        return 'Mới nhất';
      case MemorySortMode.accuracy:
        return 'Độ chính xác';
    }
  }
}

class _ViewToggle extends StatelessWidget {
  final MemoryViewMode current;
  final ValueChanged<MemoryViewMode> onChanged;

  const _ViewToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.grid_view,
            isSelected: current == MemoryViewMode.garden,
            onTap: () => onChanged(MemoryViewMode.garden),
          ),
          _ToggleBtn(
            icon: Icons.list,
            isSelected: current == MemoryViewMode.list,
            onTap: () => onChanged(MemoryViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF4CAF50).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? const Color(0xFF4CAF50) : Colors.grey,
        ),
      ),
    );
  }
}

class _ReviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _ReviewChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
                  context.uiText('$count'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
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
