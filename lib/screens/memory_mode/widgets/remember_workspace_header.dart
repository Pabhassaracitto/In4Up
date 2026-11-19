import 'package:in4up/core/language/localized_material.dart';

import '../../../widgets/collapsible_action_bar.dart';

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

class RememberWorkspaceHeader extends StatefulWidget {
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
    required this.onOpenLearnByHeart,
    required this.onOpenWordList,
    required this.onOpenTimeline,
    required this.onOpenStats,
    required this.onOpenMap,
    required this.onOpenQuickActions,
  });

  @override
  State<RememberWorkspaceHeader> createState() =>
      _RememberWorkspaceHeaderState();
}

class _RememberWorkspaceHeaderState extends State<RememberWorkspaceHeader> {
  /// PSRC-255 — mặc định GỌN: chỉ tiêu đề + số đến hạn. Mô tả và tổng số từ
  /// mở ra khi cần, không ép người dùng cuộn qua cả banner dài.
  bool _detailsExpanded = false;

  /// Nhóm công cụ "Xem tiến độ" cũng gọn: một dòng + mũi tên; bấm mới hiện
  /// các chip. Không xoá/bỏ callback nào.
  bool _toolsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(context),
          const SizedBox(height: 8),
          _buildPrimaryActions(context),
          const SizedBox(height: 8),
          _buildProgressTools(context),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withValues(alpha: 0.16),
            const Color(0xFF4CAF50).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.uiText('Nhớ · Retention Workspace'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatPill(
                key: rememberDueBadgeKey,
                value: '${widget.dueCount}',
                label: 'Đến hạn',
                color: const Color(0xFF81C784),
              ),
              IconButton(
                key: rememberDetailsToggleKey,
                tooltip: context.uiText(
                  _detailsExpanded ? 'Thu gọn chi tiết' : 'Xem chi tiết',
                ),
                icon: Icon(
                  _detailsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.white70,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () =>
                    setState(() => _detailsExpanded = !_detailsExpanded),
              ),
            ],
          ),
          if (_detailsExpanded) ...[
            const SizedBox(height: 6),
            Text(
              context.uiText(
                'Tập trung vào ôn tập, duy trì ký ức dài hạn và nhìn lại tiến độ từ vựng.',
              ),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            _StatPill(
              value: '${widget.totalWords}',
              label: 'Tổng từ',
              color: const Color(0xFFA5D6A7),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    final review = SizedBox(
      height: 46,
      child: ElevatedButton(
        key: rememberPrimaryCtaKey,
        onPressed: widget.onOpenReview,
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
            const Icon(Icons.school, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.uiText('Ôn tập ngay'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.dueCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.uiText('${widget.dueCount}'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final learn = widget.onOpenLearnByHeart == null
        ? null
        : SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              key: rememberLearnByHeartKey,
              onPressed: widget.onOpenLearnByHeart,
              icon: const Icon(Icons.auto_stories_rounded, size: 18),
              label: const Text(
                'Thuộc lòng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
          );

    // Màn đủ rộng: các hoạt động học chính đứng cạnh nhau, tiết kiệm chiều
    // cao. Màn hẹp (≤480dp): xếp dọc để chữ không bị ép.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 480 && learn != null
          ? Row(
              children: [
                Expanded(child: review),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: learn,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                review,
                if (learn != null) ...[
                  const SizedBox(height: 6),
                  learn,
                ],
              ],
            ),
    );
  }

  Widget _buildProgressTools(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: rememberProgressGroupKey,
          onTap: () => setState(() => _toolsExpanded = !_toolsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  context.uiText('Xem tiến độ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.uiText('5 công cụ'),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(
                  _toolsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_toolsExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CollapsibleActionBar(
              actions: [
                CollapsibleAction(
                  widgetKey: rememberToolWordListKey,
                  label: 'Word List',
                  icon: Icons.format_list_bulleted,
                  active: true,
                  activeColor: const Color(0xFF6C63FF),
                  onPressed: widget.onOpenWordList,
                ),
                CollapsibleAction(
                  widgetKey: rememberToolTimelineKey,
                  label: 'Timeline',
                  icon: Icons.timeline,
                  active: true,
                  activeColor: const Color(0xFF9C27B0),
                  onPressed: widget.onOpenTimeline,
                ),
                CollapsibleAction(
                  widgetKey: rememberToolStatsKey,
                  label: context.uiText('Thống kê'),
                  icon: Icons.bar_chart_rounded,
                  active: true,
                  activeColor: const Color(0xFF42A5F5),
                  onPressed: widget.onOpenStats,
                ),
                CollapsibleAction(
                  widgetKey: rememberToolWordMapKey,
                  label: 'Word Map',
                  icon: Icons.map_outlined,
                  active: true,
                  activeColor: const Color(0xFF26C6DA),
                  onPressed: widget.onOpenMap,
                ),
                CollapsibleAction(
                  widgetKey: rememberToolQuickActionsKey,
                  label: context.uiText('Công cụ nhanh'),
                  icon: Icons.auto_awesome,
                  active: true,
                  activeColor: const Color(0xFF81C784),
                  onPressed: widget.onOpenQuickActions,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Nút bật/tắt phần chi tiết của banner (mặc định gọn).
const Key rememberDetailsToggleKey = Key('remember_details_toggle');

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
