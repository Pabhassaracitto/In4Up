// lib/widgets/collapsible_action_bar.dart
//
// Thanh chức năng 2 TẦNG (GỘP ⇄ BUNG) bằng phím mũi tên — pattern "con dao
// xếp": gọn (chỉ icon) khi người dùng chưa cần, bung (có nhãn) khi cần.
//
// AUDIT-2026-10-20 (owner):
//   * mục 2 — tab Đọc: thanh chức năng TRÊN chiếm quá nhiều không gian trên
//     điện thoại nhỏ (chữ bị giới hạn) ⇒ áp dụng pattern 2 tầng này.
//   * mục 3 — tab Nhớ: bỏ chế độ tự ẩn sau N giây (người dùng chưa kịp
//     chọn) ⇒ thay bằng bung/gộp bằng mũi tên.
//   * mục 5 — header chung Nghe/Đọc/Hiểu: gọn gàng, tiết kiệm không gian
//     nhưng giữ đồng bộ giữa 3 tab.
//
// Hợp đồng:
//   * HẸP  (< [breakpoint]) → mặc định GỘP: mỗi nút chỉ còn ICON, nhãn làm
//     tooltip; cuộn ngang nếu nhiều nút. Nút mũi tên ở cuối để BUNG.
//   * RỘNG (>= [breakpoint]) → luôn BUNG (có nhãn), không hiện mũi tên.
//   * Mũi tên: lên = bung, xuống = gộp. Nhãn/tip lấy từ i18n (rule #5).
//
// Không dùng AnimatedSize/AnimatedOpacity (theo READ-TOOLBAR-001: tránh
// khối đen GPU Mali/Adreno) — chỉ đổi cây widget, không animation.
import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart';

import 'workspace_navigation/workspace_action_button.dart';

/// Một nút trong [CollapsibleActionBar].
class CollapsibleAction {
  /// Nhãn hiển thị khi BUNG (đã qua i18n của caller).
  final String label;

  /// Icon (luôn hiện, kể cả khi gộp).
  final IconData icon;

  final VoidCallback? onPressed;

  /// Tooltip khi gộp; mặc định lấy [label].
  final String? tooltip;

  /// Đang BẬT (ví dụ chế độ tô màu đang bật) ⇒ icon/nền được tô đậm.
  final bool active;

  /// Màu nhấn khi [active] (mặc định tím ứng dụng).
  final Color? activeColor;

  /// Badge nhỏ CHỈ hiện khi BUNG (vd tên preset ngữ pháp).
  final Widget? badge;

  /// Key gắn vào nút (để test tìm theo key).
  final Key? widgetKey;

  const CollapsibleAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.active = false,
    this.activeColor,
    this.badge,
    this.widgetKey,
  });
}

/// Key của nút mũi tên bung/gộp (dùng cho test).
const Key collapsibleActionBarToggleKey = Key('collapsible_action_bar_toggle');

/// Key của thanh gộp.
const Key collapsibleActionBarKey = Key('collapsible_action_bar');

/// Thanh chức năng 2 tầng: gộp (icon-only) ⇄ bung (có nhãn).
class CollapsibleActionBar extends StatefulWidget {
  final List<CollapsibleAction> actions;

  /// Mặc định bung hay gộp khi khởi tạo (chỉ áp dụng khi màn hình hẹp).
  final bool startExpanded;

  /// Từ chiều rộng này trở lên → luôn bung (có nhãn), không hiện mũi tên.
  final double breakpoint;

  /// Khoảng cách giữa các nút khi bung.
  final double spacing;

  const CollapsibleActionBar({
    super.key,
    required this.actions,
    this.startExpanded = false,
    this.breakpoint = 600,
    this.spacing = 6,
  });

  @override
  State<CollapsibleActionBar> createState() => _CollapsibleActionBarState();
}

class _CollapsibleActionBarState extends State<CollapsibleActionBar> {
  late bool _expanded = widget.startExpanded;

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= widget.breakpoint;
        // Rộng ⇒ luôn bung; hẹp ⇒ theo trạng thái gộp/bung.
        final expanded = wide || _expanded;

        final children = <Widget>[
          for (final a in widget.actions)
            expanded
                ? _LabelledAction(action: a, spacing: widget.spacing)
                : _IconAction(action: a),
        ];

        return SingleChildScrollView(
          key: collapsibleActionBarKey,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: widget.spacing),
                children[i],
              ],
              if (!wide) ...[
                SizedBox(width: widget.spacing),
                _ToggleButton(
                  expanded: expanded,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Nút có nhãn (trạng thái BUNG) — dùng chung kiểu nút với phần còn lại app
/// (`WorkspaceActionButton.dense`) để 3 tab trông đồng bộ.
class _LabelledAction extends StatelessWidget {
  final CollapsibleAction action;
  final double spacing;

  const _LabelledAction({required this.action, required this.spacing});

  @override
  Widget build(BuildContext context) {
    final button = WorkspaceActionButton(
      key: action.widgetKey,
      label: action.label,
      icon: action.icon,
      onPressed: action.onPressed,
      dense: true,
      tooltip: action.tooltip,
      active: action.active,
      activeColor: action.activeColor,
    );
    if (action.badge == null) return button;
    // Badge chỉ hiện khi BUNG (vd tên preset ngữ pháp đang dùng).
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(width: 5),
        action.badge!,
      ],
    );
  }
}

/// Nút chỉ có ICON (trạng thái GỘP) — nhãn làm tooltip.
class _IconAction extends StatelessWidget {
  final CollapsibleAction action;

  const _IconAction({required this.action});

  @override
  Widget build(BuildContext context) {
    return WorkspaceActionButton(
      key: action.widgetKey,
      label: action.label,
      icon: action.icon,
      onPressed: action.onPressed,
      compact: true,
      tooltip: action.tooltip,
      active: action.active,
      activeColor: action.activeColor,
    );
  }
}

/// Nút mũi tên bung/gộp.
class _ToggleButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ToggleButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tip = expanded
        ? context.uiText('Thu gọn')
        : context.uiText('Mở rộng');
    return Tooltip(
      message: tip,
      child: Material(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          key: collapsibleActionBarToggleKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 34,
            height: 38,
            child: Icon(
              expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 19,
              color: const Color(0xFF6C63FF),
            ),
          ),
        ),
      ),
    );
  }
}
