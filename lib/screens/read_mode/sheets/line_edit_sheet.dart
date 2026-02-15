// lib/screens/read_mode/sheets/line_edit_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';

class LineEditSheet {
  LineEditSheet._();

  static void show(BuildContext context, int lineIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TextProvider>(),
        child: _LineEditSheet(lineIndex: lineIndex),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHEET WIDGET
// ═══════════════════════════════════════════════════════════════

class _LineEditSheet extends StatefulWidget {
  final int lineIndex;
  const _LineEditSheet({required this.lineIndex});

  @override
  State<_LineEditSheet> createState() => _LineEditSheetState();
}

class _LineEditSheetState extends State<_LineEditSheet> {
  late TextEditingController _contentCtrl;
  late TextEditingController _translationCtrl;
  late FocusNode _contentFocus;
  late FocusNode _translationFocus;

  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final tp = context.read<TextProvider>();
    // Guard check index
    if (widget.lineIndex < 0 || widget.lineIndex >= tp.lines.length) {
      return;
    }
    final line = tp.lines[widget.lineIndex];

    _contentCtrl = TextEditingController(text: line.content);
    _translationCtrl = TextEditingController(text: line.translation ?? '');
    _contentFocus = FocusNode();
    _translationFocus = FocusNode();

    _contentCtrl.addListener(() => setState(() => _isDirty = true));
    _translationCtrl.addListener(() => setState(() => _isDirty = true));

    // Auto focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _contentFocus.requestFocus();
        // Đặt cursor cuối dòng
        _contentCtrl.selection = TextSelection.collapsed(
          offset: _contentCtrl.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _translationCtrl.dispose();
    _contentFocus.dispose();
    _translationFocus.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // SAVE: cập nhật dòng hiện tại trong TextProvider
  // ─────────────────────────────────────────────────────────

  void _save() {
    final tp = context.read<TextProvider>();
    final contentText = _contentCtrl.text;
    final translationText = _translationCtrl.text.trim();

    // Tách theo newline trong ô content
    final contentLines = contentText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final translationLines = translationText.isEmpty
        ? <String>[]
        : translationText.split('\n').map((l) => l.trim()).toList();

    if (contentLines.isEmpty) {
      // Xóa dòng nếu content trống
      tp.deleteLine(widget.lineIndex);
    } else if (contentLines.length == 1) {
      // Sửa dòng hiện tại
      tp.editLine(
        index: widget.lineIndex,
        content: contentLines.first,
        translation: translationLines.isEmpty ? null : translationLines.first,
      );
    } else {
      // Nhiều dòng → replace dòng hiện tại + chèn thêm
      tp.splitLine(
        index: widget.lineIndex,
        contentLines: contentLines,
        translationLines: translationLines,
      );
    }

    Navigator.pop(context);

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Text(contentLines.length > 1
                ? 'Đã tách thành ${contentLines.length} dòng'
                : 'Đã lưu chỉnh sửa'),
          ],
        ),
        backgroundColor: const Color(0xFF2A2A3E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    if (widget.lineIndex >= tp.lines.length) return const SizedBox.shrink();

    final line = tp.lines[widget.lineIndex];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Dòng ${widget.lineIndex + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2196F3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (line.startTime != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(line.startTime!),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                  const Spacer(),
                  // Nút xóa dòng
                  GestureDetector(
                    onTap: _confirmDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Field: Văn bản gốc ───────────────────────────
              _FieldLabel(
                icon: Icons.article_outlined,
                label: 'Văn bản gốc',
                hint: 'Enter để tách dòng mới',
                color: Colors.white70,
              ),
              const SizedBox(height: 6),
              _EditField(
                controller: _contentCtrl,
                focusNode: _contentFocus,
                nextFocus: _translationFocus,
                hintText: 'Nhập nội dung dòng...',
                accentColor: const Color(0xFF2196F3),
              ),

              const SizedBox(height: 12),

              // ── Field: Bản dịch ──────────────────────────────
              _FieldLabel(
                icon: Icons.translate,
                label: 'Bản dịch',
                hint: 'Tuỳ chọn · Enter để tách theo dòng gốc',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 6),
              _EditField(
                controller: _translationCtrl,
                focusNode: _translationFocus,
                hintText: 'Nhập bản dịch... (bỏ trống nếu không cần)',
                accentColor: const Color(0xFF4CAF50),
              ),

              const SizedBox(height: 6),

              // ── Hint ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 13, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Nhấn Enter trong ô để tách thành nhiều dòng. '
                        'Bản dịch sẽ ghép theo thứ tự dòng tương ứng.',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Buttons ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey[700]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Huỷ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isDirty ? _save : null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Lưu'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        disabledBackgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Confirm delete
  // ─────────────────────────────────────────────────────────

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Xoá dòng?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          '"${_contentCtrl.text.substring(0, _contentCtrl.text.length.clamp(0, 60))}..."',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // đóng dialog
              context.read<TextProvider>().deleteLine(widget.lineIndex);
              Navigator.pop(context); // đóng sheet
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;

  const _FieldLabel({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          hint,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final String hintText;
  final Color accentColor;

  const _EditField({
    required this.controller,
    required this.focusNode,
    this.nextFocus,
    required this.hintText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        // Cho phép multiline – Enter tạo newline thật
        maxLines: null,
        minLines: 2,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onSubmitted: (_) {
          // Tab/Done → chuyển sang field tiếp theo nếu có
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          }
        },
      ),
    );
  }
}
