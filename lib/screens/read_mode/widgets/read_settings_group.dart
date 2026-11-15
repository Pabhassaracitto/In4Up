// lib/screens/read_mode/widgets/read_settings_group.dart
//
// PSRC-236 / ADR-0030 D1 — khối dựng của «Cài đặt Text Studio» dạng nhóm gập.
//
//   * [ReadSettingsGroup]   — nhóm GẬP/MỞ tại chỗ, tiêu đề luôn hiện cùng một
//     dòng tóm tắt giá trị đang chọn; nội dung chỉ dựng khi mở.
//   * [ReadSettingsLinkRow] — dòng mở một TRANG CON (mũi tên phải).
//
// Tách thành file công khai (không `_private` trong sheet) để widget test
// dựng được mà không cần `TextProvider` / plugin.
//
// Hợp đồng kỹ thuật:
//   * KHÔNG AnimatedSize / AnimatedCrossFade / ExpansionTile: gập/mở = build
//     điều kiện, đổi cây widget tức thời (cùng lý do READ-TOOLBAR-001 — khối
//     đen trên GPU Mali/Adreno).
//   * Tiêu đề và tóm tắt đi qua `Text` của `localized_material` ⇒ chuỗi nguồn
//     tiếng Việt tự dịch theo locale (quy tắc vàng #5).

import 'package:in4up/core/language/localized_material.dart';

/// PSRC-236 / ADR-0030 D1 — hàng tiêu đề dùng chung cho nhóm gập và dòng mở
/// trang con: icon + tên + dòng tóm tắt + mũi tên. Cao tối thiểu 56 px (đủ
/// vùng chạm), dòng tóm tắt 1 dòng có «…» để nhãn dài ở 26 ngôn ngữ không
/// đẩy vỡ bố cục.
class _SettingsRowHeader extends StatelessWidget {
  const _SettingsRowHeader({
    required this.tapKey,
    required this.icon,
    required this.title,
    required this.summary,
    required this.trailing,
    required this.onTap,
    this.summaryColor,
  });

  final Key tapKey;
  final IconData icon;
  final String title;
  final String summary;
  final IconData trailing;
  final VoidCallback onTap;
  final Color? summaryColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tapKey,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF2196F3)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: summaryColor ?? Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(trailing, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhóm gập: tiêu đề luôn hiện, nội dung chỉ dựng khi [open].
class ReadSettingsGroup extends StatelessWidget {
  const ReadSettingsGroup({
    super.key,
    required this.tapKey,
    required this.icon,
    required this.title,
    required this.summary,
    required this.open,
    required this.onToggle,
    required this.children,
    this.summaryColor,
  });

  final Key tapKey;
  final IconData icon;
  final String title;
  final String summary;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Color? summaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: open
              ? const Color(0xFF2196F3).withValues(alpha: 0.45)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsRowHeader(
            tapKey: tapKey,
            icon: icon,
            title: title,
            summary: summary,
            summaryColor: summaryColor,
            trailing: open ? Icons.expand_less : Icons.expand_more,
            onTap: onToggle,
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}

/// Dòng mở TRANG CON (không gập/mở tại chỗ) — mũi tên phải thay cho mũi tên
/// xuống để người dùng đoán đúng điều sắp xảy ra.
class ReadSettingsLinkRow extends StatelessWidget {
  const ReadSettingsLinkRow({
    super.key,
    required this.tapKey,
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  final Key tapKey;
  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: _SettingsRowHeader(
        tapKey: tapKey,
        icon: icon,
        title: title,
        summary: summary,
        trailing: Icons.chevron_right,
        onTap: onTap,
      ),
    );
  }
}
