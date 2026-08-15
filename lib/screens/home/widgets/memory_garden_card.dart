import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../memory_mode/controllers/memory_controller.dart';
import '../../memory_mode/models/memory_stage.dart';
import 'package:in4up/core/language/tr_extension.dart';

class MemoryGardenCard extends StatelessWidget {
  final VoidCallback onStartReview;
  const MemoryGardenCard({super.key, required this.onStartReview});

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryController>(
      builder: (context, controller, _) {
        final stats = controller.stats;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withValues(alpha: 0.15),
                const Color(0xFF2E7D32).withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VƯỜN TRÍ NHỚ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      TrText('Trạng thái sinh trưởng', style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  _GardenSummary(distribution: stats.stageDistribution),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SimpleStat(
                      label: context.tr('Cần ôn ngay'),
                      value: '${stats.dueToday}',
                      icon: Icons.water_drop,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SimpleStat(
                      label: context.l10n.wordListBlindSpot,
                      value: '${_calculateBlindSpots(controller)}',
                      icon: Icons.visibility_off,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onStartReview,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text('TƯỚI NƯỚC (${stats.dueToday} TỪ)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _calculateBlindSpots(MemoryController ctrl) {
    // Basic logic for blind spots: high usage but low accuracy or stage
    return ctrl.allItems
        .where((i) => i.stage == MemoryStage.seed && i.totalReviews > 2)
        .length;
  }
}

class _GardenSummary extends StatelessWidget {
  final Map<MemoryStage, int> distribution;
  const _GardenSummary({required this.distribution});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StageIcon(MemoryStage.seed, distribution[MemoryStage.seed] ?? 0),
        const SizedBox(width: 8),
        _StageIcon(MemoryStage.bloom, distribution[MemoryStage.bloom] ?? 0),
      ],
    );
  }
}

class _StageIcon extends StatelessWidget {
  final MemoryStage stage;
  final int count;
  const _StageIcon(this.stage, this.count);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (stage) {
      case MemoryStage.seed:
        icon = Icons.eco;
        color = Colors.brown;
        break;
      case MemoryStage.bloom:
        icon = Icons.local_florist;
        color = Colors.pinkAccent;
        break;
      default:
        icon = Icons.park;
        color = Colors.green;
    }

    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
        Text(
          '$count',
          style: const TextStyle(
              fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SimpleStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SimpleStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}