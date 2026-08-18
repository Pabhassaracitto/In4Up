// lib/screens/memory_mode/widgets/stage_progress_bar.dart

import 'package:in4up/core/language/localized_material.dart';
import '../models/memory_stage.dart';
import '../models/memory_stats.dart';

class StageProgressBar extends StatelessWidget {
  final MemoryStats stats;
  const StageProgressBar({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalItems;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: MemoryStage.values.map((stage) {
                final count = stats.getStageCount(stage);
                final ratio = count / total;
                if (ratio == 0) return const SizedBox.shrink();

                return Flexible(
                  flex: (ratio * 1000).round().clamp(1, 1000),
                  child: Container(
                    color: stage.primaryColor,
                    child: const SizedBox.expand(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.uiText('${stats.totalItems} từ'),
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
            Row(
              children: [
                _LegendDot(
                  color: MemoryStage.seed.primaryColor,
                  label: '${stats.getStageCount(MemoryStage.seed)}',
                ),
                const SizedBox(width: 8),
                _LegendDot(
                  color: MemoryStage.bloom.primaryColor,
                  label: '${stats.getStageCount(MemoryStage.bloom)} thuộc',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          context.uiText(label),
          style: TextStyle(color: Colors.grey[500], fontSize: 10),
        ),
      ],
    );
  }
}
