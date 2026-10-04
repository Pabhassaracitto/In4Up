import 'package:in4up/core/language/localized_material.dart';

/// NHỚ-WORKSPACE-002 — header của workspace Nhớ, tách rõ hai tầng:
///
/// 1. HOẠT ĐỘNG CHÍNH: Ôn tập (CTA chính, kèm badge từ đến hạn) và
///    Thuộc lòng (khi route đó khả dụng). Đây là nơi việc học diễn ra.
/// 2. XEM TIẾN ĐỘ: Word List / Timeline / Thống kê / Word Map — công cụ
///    xem dữ liệu, trình bày dạng chip cuộn ngang, không che CTA chính.
///
/// Widget này thuần trình bày (nhận số liệu + callback qua constructor),
/// không đọc provider — phần kết nối VocabularyProvider nằm ở
/// remember_workspace_screen.dart. Mọi callback giữ nguyên ngữ nghĩa cũ.

/// Key của CTA chính "Ôn tập".
const Key rememberPrimaryCtaKey = Key('remember_primary_cta');

/// Key của nút "Thuộc lòng" (hoạt động học chính thứ hai).
const Key rememberLearnByHeartKey = Key('remember_learn_by_heart');

/// Key của badge "Đến hạn" trong banner.
const Key rememberDueBadgeKey = Key('remember_due_badge');

/// Key của nhóm công cụ "Xem tiến độ".
const Key rememberProgressGroupKey = Key('remember_progress_group');

/// Key từng công cụ xem dữ liệu.
const Key rememberToolWordListKey = Key('remember_tool_word_list');
const Key rememberToolTimelineKey = Key('remember_tool_timeline');
const Key rememberToolStatsKey = Key('remember_tool_stats');
const Key rememberToolWordMapKey = Key('remember_tool_word_map');
const Key rememberToolQuickActionsKey = Key('remember_tool_quick_actions');

class RememberWorkspaceHeader extends StatelessWidget {
  /// Số từ đến hạn ôn (badge trên banner + CTA chính).
  final int dueCount;

  /// Tổng số từ trong kho.
  final int totalWords;

  final VoidCallback onOpenReview;
  final VoidCallback? onOpenLearnByHeart;
  final VoidCallback onOpenWordList;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenQuickActions;

  const RememberWorkspaceHeader({
    super.key,
    required this.dueCount,
    required this.totalWords,
    required this.onOpenReview,
    required this.onOpenWordList,
    required this.onOpenTimeline,
    required this.onOpenStats,
    required this.onOpenMap,
    required this.onOpenQuickActions,
    this.onOpenLearnByHeart,
  });

  @override
  Widget build(BuildContext context) {
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
          _buildBanner(),
          const SizedBox(height: 10),
          _buildPrimaryActions(),
          const SizedBox(height: 10),
          _buildProgressTools(),
        ],
      ),
    );
  }

  // ── Tầng 0: banner nhận diện + badge số liệu ───────────────────────────
  Widget _buildBanner() {
    return Container(
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhớ · Retention Workspace',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 6),
                Text(
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
                key: rememberDueBadgeKey,
                value: '$dueCount',
                label: 'Đến hạn',
                color: const Color(0xFF81C784),
              ),
              const SizedBox(height: 8),
              _StatPill(
                value: '$totalWords',
                label: 'Tổng từ',
                color: const Color(0xFFA5D6A7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tầng 1: hoạt động học chính ────────────────────────────────────────
  Widget _buildPrimaryActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton(
            key: rememberPrimaryCtaKey,
            onPressed: onOpenReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 20),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Ôn tập ngay',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (dueCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$dueCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (onOpenLearnByHeart != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              key: rememberLearnByHeartKey,
              onPressed: onOpenLearnByHeart,
              icon: const Icon(Icons.auto_stories_rounded, size: 18),
              label: const Text(
                'Thuộc lòng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF81C784),
                side: BorderSide(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tầng 2: công cụ xem dữ liệu ("Xem tiến độ") ────────────────────────
  Widget _buildProgressTools() {
    return Column(
      key: rememberProgressGroupKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'XEM TIẾN ĐỘ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _WorkspaceChip(
                key: rememberToolWordListKey,
                icon: Icons.format_list_bulleted,
                label: 'Word List',
                color: const Color(0xFF6C63FF),
                onTap: onOpenWordList,
              ),
              const SizedBox(width: 8),
              _WorkspaceChip(
                key: rememberToolTimelineKey,
                icon: Icons.timeline,
                label: 'Timeline',
                color: const Color(0xFF9C27B0),
                onTap: onOpenTimeline,
              ),
              const SizedBox(width: 8),
              _WorkspaceChip(
                key: rememberToolStatsKey,
                icon: Icons.bar_chart_rounded,
                label: 'Thống kê',
                color: const Color(0xFF42A5F5),
                onTap: onOpenStats,
              ),
              const SizedBox(width: 8),
              _WorkspaceChip(
                key: rememberToolWordMapKey,
                icon: Icons.map_outlined,
                label: 'Word Map',
                color: const Color(0xFF26C6DA),
                onTap: onOpenMap,
              ),
              const SizedBox(width: 8),
              _WorkspaceChip(
                key: rememberToolQuickActionsKey,
                icon: Icons.auto_awesome,
                label: 'Công cụ nhanh',
                color: const Color(0xFF81C784),
                onTap: onOpenQuickActions,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WorkspaceChip({
    super.key,
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
        // Vùng chạm ≥ 40dp cao; chip nằm trong scroll ngang nên không gây
        // overflow ngang ở màn hẹp.
        constraints: const BoxConstraints(minHeight: 40),
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
    super.key,
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
        '${context.uiText(label)}: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
