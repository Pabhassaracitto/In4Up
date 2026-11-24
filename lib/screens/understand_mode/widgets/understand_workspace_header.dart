// lib/screens/understand_mode/widgets/understand_workspace_header.dart
//
// Header của workspace tab Hiểu — tách khỏi understand_workspace_screen.dart
// để test được độc lập (không cần dựng cả UnderstandTabConnector/PlayerProvider).
//
// "Hỏi AI" là MỘT ACTION trong hàng chip (cùng cấp Qua Nói / YouGlish / Ôn
// tập / Công cụ nhanh) — KHÔNG phải tab/mode thứ ba. TabBar bên dưới vẫn chỉ
// có Đồng bộ / Shadowing.

// NOTE: chỉ import localized_material.dart (export material + Text shim +
// uiText). Import thêm material trực tiếp sẽ làm tên `Text` ambiguous.
import 'package:in4up/core/language/localized_material.dart';

class UnderstandWorkspaceHeader extends StatelessWidget {
  final VoidCallback onOpenSpeakMode;
  final VoidCallback onOpenYouGlish;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenQuickActions;

  /// Action "Hỏi AI" — mở sheet Trợ lý hiểu bài (AI Coach).
  final VoidCallback onOpenAiCoach;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  const UnderstandWorkspaceHeader({
    super.key,
    required this.onOpenSpeakMode,
    required this.onOpenYouGlish,
    required this.onOpenReview,
    required this.onOpenQuickActions,
    required this.onOpenAiCoach,
    this.expanded = true,
    this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          if (expanded)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _WorkspaceChip(
                      icon: Icons.record_voice_over,
                      label: 'YouGlish',
                      color: const Color(0xFF00BCD4),
                      onTap: onOpenYouGlish,
                    ),
                    const SizedBox(width: 8),
                    _WorkspaceChip(
                      icon: Icons.school,
                      label: 'Ôn tập',
                      color: const Color(0xFF66BB6A),
                      onTap: onOpenReview,
                    ),
                    const SizedBox(width: 8),
                    // AI Coach — action theo ngữ cảnh, không phải mode thứ ba.
                    _WorkspaceChip(
                      icon: Icons.psychology_outlined,
                      label: 'Hỏi AI',
                      color: const Color(0xFF7DD3FC),
                      onTap: onOpenAiCoach,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                context.uiText('Công cụ hiểu'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (onToggleExpanded != null)
            IconButton(
              tooltip:
                  context.uiText(expanded ? 'Thu gọn công cụ' : 'Mở công cụ'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onToggleExpanded,
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: Colors.white70,
              ),
            ),
        ],
      ),
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
