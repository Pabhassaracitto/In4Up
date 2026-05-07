// lib/screens/memory_mode/widgets/memory_top_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../widgets/sync_status_badge.dart';
import '../controllers/memory_controller.dart';

class MemoryTopBar extends StatelessWidget {
  const MemoryTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MemoryController>();
    final stats = controller.stats;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF4CAF50).withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '🌱 Vườn Nhớ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          if (stats.dueToday > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(0xFFFF5252).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${stats.dueToday} cần ôn',
                style: const TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          const SyncStatusBadge(),
          const Spacer(),
          _ViewToggle(
            current: controller.viewMode,
            onChanged: controller.setViewMode,
          ),
          const SizedBox(width: 8),
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
