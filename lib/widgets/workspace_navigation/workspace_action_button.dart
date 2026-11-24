import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A workspace action with a mobile-sized target and optional compact layout.
///
/// READ-ACT-001 adds [dense]: a labelled button that still reads as a button
/// but fits a single scrollable row on a phone. The default (`false`) keeps
/// the original 48 dp `FilledButton.tonalIcon` so no existing header changes
/// size.
class WorkspaceActionButton extends StatelessWidget {
  const WorkspaceActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compact = false,
    this.dense = false,
    this.tooltip,
    this.active = false,
    this.activeColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Icon-only button (label becomes the tooltip).
  final bool compact;

  /// Labelled, but shorter and tighter — for headers with 4+ actions.
  final bool dense;

  final String? tooltip;

  /// Đang BẬT ⇒ nền/icon được tô đậm (dùng cho nút bật/tắt trong header).
  final bool active;

  /// Màu nhấn khi [active].
  final Color? activeColor;

  /// Height of a dense button — meets Apple HIG 44pt minimum touch target.
  static const double denseHeight = AppSpacing.minTouchTarget;

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? AppColors.accentPrimary;

    if (compact) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon, color: active ? accent : null),
          tooltip: tooltip ?? label,
          style: active
              ? IconButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.18),
                )
              : null,
        ),
      );
    }

    if (dense) {
      final button = FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: active ? accent : null),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: AppTypography.footnoteSize,
            fontWeight: FontWeight.w600,
            color: active ? accent : null,
          ),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(AppSpacing.minTouchTarget, denseHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: active
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          textStyle: const TextStyle(
            fontSize: AppTypography.footnoteSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      final wrapped = SizedBox(height: denseHeight, child: button);
      final message = tooltip ?? label;
      return message.isEmpty
          ? wrapped
          : Tooltip(message: message, child: wrapped);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, color: active ? accent : null),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: active ? accent : null),
        ),
        style: active
            ? FilledButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.18),
              )
            : null,
      ),
    );
  }
}
