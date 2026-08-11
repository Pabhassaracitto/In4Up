import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/vocabulary_provider.dart';
import '../../widgets/auto_hide_banner.dart';
import 'memory_tab_connector.dart';

class RememberWorkspaceScreen extends StatelessWidget {
  final VoidCallback onOpenReview;
  final VoidCallback onOpenWordList;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenQuickActions;

  const RememberWorkspaceScreen({
    super.key,
    required this.onOpenReview,
    required this.onOpenWordList,
    required this.onOpenTimeline,
    required this.onOpenStats,
    required this.onOpenMap,
    required this.onOpenQuickActions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AutoHideInfoBanner(
          storageKey: 'remember_workspace_header',
          autoHideAfter: const Duration(seconds: 5),
          child: _RememberWorkspaceHeader(
            onOpenReview: onOpenReview,
            onOpenWordList: onOpenWordList,
            onOpenTimeline: onOpenTimeline,
            onOpenStats: onOpenStats,
            onOpenMap: onOpenMap,
            onOpenQuickActions: onOpenQuickActions,
          ),
        ),
        const Expanded(
          child: MemoryTabConnector(),
        ),
      ],
    );
  }
}

class _RememberWorkspaceHeader extends StatelessWidget {
  final VoidCallback onOpenReview;
  final VoidCallback onOpenWordList;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenQuickActions;

  const _RememberWorkspaceHeader({
    required this.onOpenReview,
    required this.onOpenWordList,
    required this.onOpenTimeline,
    required this.onOpenStats,
    required this.onOpenMap,
    required this.onOpenQuickActions,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, vocab, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4CAF50).withValues(alpha: 0.16),
                      const Color(0xFF4CAF50).withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nhớ · Retention Workspace',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tập trung vào ôn tập, duy trì ký ức dài hạn và nhìn lại tiến độ từ vựng.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StatPill(
                          value: '${vocab.dueCount}',
                          label: 'Đến hạn',
                          color: const Color(0xFF81C784),
                        ),
                        const SizedBox(height: 8),
                        _StatPill(
                          value: '${vocab.wordCount}',
                          label: 'Tổng từ',
                          color: const Color(0xFFA5D6A7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _WorkspaceChip(
                      icon: Icons.school,
                      label: 'Ôn tập',
                      color: const Color(0xFF66BB6A),
                      onTap: onOpenReview,
                    ),
                    const SizedBox(width: 8),
                    _WorkspaceChip(
                      icon: Icons.format_list_bulleted,
                      label: 'Word List',
                      color: const Color(0xFF6C63FF),
                      onTap: onOpenWordList,
                    ),
                    const SizedBox(width: 8),
                    _WorkspaceChip(
                      icon: Icons.timeline,
                      label: 'Timeline',
                      color: const Color(0xFF9C27B0),
                      onTap: onOpenTimeline,
                    ),
                    const SizedBox(width: 8),
                    _WorkspaceChip(
                      icon: Icons.bar_chart_rounded,
                      label: 'Thống kê',
                      color: const Color(0xFF42A5F5),
                      onTap: onOpenStats,
                    ),
                    const SizedBox(width: 8),
                    _WorkspaceChip(
                      icon: Icons.map_outlined,
                      label: 'Word Map',
                      color: const Color(0xFF26C6DA),
                      onTap: onOpenMap,
                    ),
                    const SizedBox(width: 8),
                    _WorkspaceChip(
                      icon: Icons.auto_awesome,
                      label: 'Công cụ nhanh',
                      color: const Color(0xFF81C784),
                      onTap: onOpenQuickActions,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WorkspaceChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
