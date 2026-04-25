// lib/screens/memory_mode/sheets/memory_stats_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/memory_stage.dart';
import '../models/memory_stats.dart';

/// Thống kê chi tiết vườn trí nhớ
class MemoryStatsSheet extends StatelessWidget {
  final MemoryStats stats;

  const MemoryStatsSheet({super.key, required this.stats});

  static void show(BuildContext context, {required MemoryStats stats}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MemoryStatsSheet(stats: stats),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Row(
                    children: [
                      Text('📊', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 8),
                      Text(
                        'Thống kê Vườn Nhớ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ===== OVERVIEW CARDS =====
                  Row(
                    children: [
                      _OverviewCard(
                        label: 'Tổng từ',
                        value: '${stats.totalItems}',
                        icon: Icons.local_florist,
                        color: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 12),
                      _OverviewCard(
                        label: 'Cần ôn',
                        value: '${stats.dueToday}',
                        icon: Icons.water_drop,
                        color: const Color(0xFFFF9800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _OverviewCard(
                        label: 'Đã ôn hôm nay',
                        value: '${stats.reviewedToday}',
                        icon: Icons.done_all,
                        color: const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 12),
                      _OverviewCard(
                        label: 'Chính xác',
                        value: '${(stats.averageAccuracy * 100).round()}%',
                        icon: Icons.trending_up,
                        color: const Color(0xFF9C27B0),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ===== STAGE DISTRIBUTION =====
                  Text(
                    'Phân bổ giai đoạn',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...MemoryStage.values.map((stage) {
                    final count = stats.getStageCount(stage);
                    final ratio =
                        stats.totalItems > 0 ? count / stats.totalItems : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          // Emoji
                          SizedBox(
                            width: 32,
                            child: Text(
                              stage.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),

                          // Label
                          SizedBox(
                            width: 64,
                            child: Text(
                              stage.label,
                              style: TextStyle(
                                color: stage.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // Bar
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.05),
                                valueColor:
                                    AlwaysStoppedAnimation(stage.primaryColor),
                                minHeight: 16,
                              ),
                            ),
                          ),

                          // Count
                          SizedBox(
                            width: 40,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: stage.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // ===== COMPLETION RATE =====
                  _CompletionCircle(
                    rate: stats.completionRate,
                    reviewedToday: stats.reviewedToday,
                    dueToday: stats.dueToday,
                  ),

                  const SizedBox(height: 24),

                  // ===== SCIENCE NOTE =====
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF2196F3).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFF2196F3).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 18,
                              color: Color(0xFF2196F3),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Khoa học trí nhớ',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đường cong quên Ebbinghaus cho thấy:\n'
                          '• 1 giờ sau học: quên 56%\n'
                          '• 1 ngày sau: quên 67%\n'
                          '• 1 tháng sau: quên 79%\n\n'
                          'Ôn tập đúng lúc sắp quên giúp củng cố\n'
                          'kết nối thần kinh, chuyển từ hippocampus\n'
                          'sang neocortex → nhớ lâu dài.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionCircle extends StatelessWidget {
  final double rate;
  final int reviewedToday;
  final int dueToday;

  const _CompletionCircle({
    required this.rate,
    required this.reviewedToday,
    required this.dueToday,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Tiến độ hôm nay',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(
                    rate >= 1.0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(rate * 100).round()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: rate >= 1.0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF9800),
                      ),
                    ),
                    Text(
                      '$reviewedToday/$dueToday',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (rate >= 1.0) ...[
            const SizedBox(height: 8),
            const Text(
              '🎉 Hoàn thành!',
              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
