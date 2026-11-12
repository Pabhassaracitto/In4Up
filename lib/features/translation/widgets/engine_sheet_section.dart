// lib/features/translation/widgets/engine_sheet_section.dart
//
// PSRC-191 (owner 2026-11-11) — *"Sắp xếp lại UI Translation engines"*.
//
// Sheet "Engine dịch thuật" bản 1.27.0 là MỘT cột dài: khối trạng thái engine
// (nhiều pill + nút "Kiểm tra engine ngay") + DeepLX (ô URL + chú thích 2 dòng
// + nút thử) + gói ML Kit + Hy-MT + LLM + công tắc offline + glossary + nút
// Lưu — tất cả cùng một độ ưu tiên ⇒ user mở sheet ra chỉ thấy một bức tường
// chữ, không biết bắt đầu từ đâu.
//
// Cách sửa (không đổi hành vi, chỉ đổi cách trình bày):
//   • Mỗi nhóm là một THẺ có tiêu đề + mô tả NGẮN 1 dòng; chi tiết dài nằm
//     trong phần mở rộng ⇒ mặc định màn hình chỉ còn ~1 màn hình cuộn.
//   • Nhóm "Thường dùng" (gói offline + công tắc chỉ-offline) mở sẵn; nhóm
//     "Nâng cao" (DeepLX, Hy-MT, LLM API) thu gọn, bấm mới mở.
//
// Widget ở đây THUẦN trình bày (không tự gọi mạng/plugin) nên test widget
// được trên host VM.

import 'package:flutter/material.dart';

/// Thẻ một nhóm cài đặt trong sheet engine.
///
/// [title]/[subtitle] LUÔN hiện; [children] chỉ dựng khi [expanded] — nhờ vậy
/// thu gọn thật sự bớt chữ trên màn hình chứ không chỉ ẩn bằng `Visibility`
/// (vẫn chiếm chỗ khi layout).
class EngineSheetSection extends StatefulWidget {
  const EngineSheetSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.initiallyExpanded = false,
    this.trailing,
    this.dense = false,
  });

  final String title;

  /// Mô tả NGẮN (1 dòng) — trả lời "nhóm này để làm gì" mà không cần mở.
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final List<Widget> children;

  /// Nhóm "Thường dùng" mở sẵn; nhóm nâng cao để đóng.
  final bool initiallyExpanded;

  /// Badge trạng thái bên phải tiêu đề (vd "Đã tải", "Đang tải ngầm...").
  final Widget? trailing;

  /// Đệm dọc nhỏ hơn cho nhóm ít nội dung — giảm chiều cao tổng.
  final bool dense;

  @override
  State<EngineSheetSection> createState() => _EngineSheetSectionState();
}

class _EngineSheetSectionState extends State<EngineSheetSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    final hasHeaderAction = widget.subtitle != null || !widget.initiallyExpanded;
    return Container(
      margin: EdgeInsets.only(bottom: widget.dense ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            // Nhóm mở sẵn mà không có gì để thu gọn thì không bấm được — tránh
            // cảm giác "bấm không ăn".
            onTap: hasHeaderAction
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, widget.dense ? 9 : 11, 8, 9),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: accent),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.subtitle!,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                  if (hasHeaderAction)
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: Colors.grey[500],
                    ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ dùng trong thẻ (thay cho TextStyle lặp lại khắp sheet).
class EngineSheetHint extends StatelessWidget {
  const EngineSheetHint(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color ?? Colors.grey[600], fontSize: 11),
    );
  }
}
