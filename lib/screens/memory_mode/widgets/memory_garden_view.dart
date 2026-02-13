// lib/screens/memory_mode/widgets/memory_garden_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/memory_controller.dart';
import '../models/memory_item.dart';
import '../models/memory_stage.dart';
import 'memory_card_widget.dart';
import 'memory_garden_background.dart';
import 'stage_progress_bar.dart';

class MemoryGardenView extends StatelessWidget {
  const MemoryGardenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryController>(
      builder: (context, controller, _) {
        final items = controller.filteredItems;
        final stats = controller.stats;

        return MemoryGardenBackground(
          distribution: stats.stageDistribution,
          child: Column(
            children: [
              _StageFilterBar(
                selectedStage: controller.filterStage,
                distribution: stats.stageDistribution,
                onSelect: controller.setFilterStage,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: StageProgressBar(stats: stats),
              ),
              if (stats.dueToday > 0)
                _DueIndicator(
                  dueCount: stats.dueToday,
                  onTap: () => controller.startReview(),
                ),
              Expanded(
                child: items.isEmpty
                    ? _buildFilterEmpty(controller.filterStage)
                    : _buildGardenGrid(context, items),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGardenGrid(BuildContext context, List<MemoryItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildAdaptiveRow(context, items, index);
                },
                childCount: _calculateRowCount(items),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateRowCount(List<MemoryItem> items) {
    int count = 0;
    int i = 0;
    while (i < items.length) {
      final item = items[i];
      final perRow = _itemsPerRow(item.stage);
      i += perRow;
      count++;
    }
    return count;
  }

  int _itemsPerRow(MemoryStage stage) {
    switch (stage) {
      case MemoryStage.seed:
        return 1;
      case MemoryStage.sprout:
        return 2;
      case MemoryStage.tree:
        return 2;
      case MemoryStage.branch:
        return 3;
      case MemoryStage.bud:
        return 3;
      case MemoryStage.bloom:
        return 4;
    }
  }

  Widget _buildAdaptiveRow(
      BuildContext context, List<MemoryItem> items, int rowIndex) {
    int startIdx = 0;
    for (int r = 0; r < rowIndex && startIdx < items.length; r++) {
      startIdx += _itemsPerRow(items[startIdx].stage);
    }

    if (startIdx >= items.length) return const SizedBox.shrink();

    final firstItem = items[startIdx];
    final perRow = _itemsPerRow(firstItem.stage);
    final endIdx = (startIdx + perRow).clamp(0, items.length);
    final rowItems = items.sublist(startIdx, endIdx);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: rowItems.map((item) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MemoryCardWidget(
                item: item,
                onTap: () {
                  HapticFeedback.selectionClick();
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterEmpty(MemoryStage? stage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            stage?.emoji ?? '🌱',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            stage != null
                ? 'Chưa có từ nào ở giai đoạn "${stage.label}"'
                : 'Chưa có từ nào',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _StageFilterBar extends StatelessWidget {
  final MemoryStage? selectedStage;
  final Map<MemoryStage, int> distribution;
  final ValueChanged<MemoryStage?> onSelect;

  const _StageFilterBar({
    required this.selectedStage,
    required this.distribution,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _FilterChip(
            label: 'Tất cả',
            emoji: '🌍',
            count: distribution.values.fold(0, (a, b) => a + b),
            isSelected: selectedStage == null,
            color: Colors.white,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 6),
          ...MemoryStage.values.map((stage) {
            final count = distribution[stage] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: stage.label,
                emoji: stage.emoji,
                count: count,
                isSelected: selectedStage == stage,
                color: stage.primaryColor,
                onTap: () => onSelect(selectedStage == stage ? null : stage),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueIndicator extends StatelessWidget {
  final int dueCount;
  final VoidCallback onTap;

  const _DueIndicator({required this.dueCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4CAF50).withValues(alpha: 0.2),
              const Color(0xFF4CAF50).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.water_drop, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$dueCount từ cần tưới hôm nay',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Tưới ngay',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
