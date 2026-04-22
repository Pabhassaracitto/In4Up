import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pdf_annotation.dart';
import '../pdf_reader_controller.dart';

/// Sheet để xem/sửa/xóa annotation
class PdfAnnotationSheet {
  static void show(
    BuildContext context,
    PdfAnnotation annotation,
    PdfReaderController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _AnnotationSheet(annotation: annotation, controller: controller),
    );
  }

  /// Sheet để thêm annotation mới từ selection
  static void showAdd(
    BuildContext context,
    String selectedText,
    Rect selectionRect,
    int pageIndex,
    PdfReaderController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddAnnotationSheet(
        selectedText: selectedText,
        selectionRect: selectionRect,
        pageIndex: pageIndex,
        controller: controller,
      ),
    );
  }
}

// ── View/Edit Sheet ───────────────────────────────────────

class _AnnotationSheet extends StatefulWidget {
  final PdfAnnotation annotation;
  final PdfReaderController controller;
  const _AnnotationSheet({required this.annotation, required this.controller});

  @override
  State<_AnnotationSheet> createState() => _AnnotationSheetState();
}

class _AnnotationSheetState extends State<_AnnotationSheet> {
  late TextEditingController _noteCtrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.annotation.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.annotation.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Ghi chú',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                  onPressed: () => setState(() => _isEditing = true),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
                onPressed: () async {
                  await widget.controller
                      .deleteAnnotation(widget.annotation.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Selected text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.annotation.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: widget.annotation.color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '"${widget.annotation.selectedText}"',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Note field
          if (_isEditing) ...[
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Thêm ghi chú...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child:
                        const Text('Hủy', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.controller.updateAnnotationNote(
                          widget.annotation.id, _noteCtrl.text);
                      setState(() => _isEditing = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ] else if (widget.annotation.note?.isNotEmpty == true) ...[
            Text(
              widget.annotation.note!,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.5),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => setState(() => _isEditing = true),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      style: BorderStyle.solid),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 8),
                    Text('Thêm ghi chú...',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ],

          // Speak
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () =>
                widget.controller.speakText(widget.annotation.selectedText),
            icon: const Icon(Icons.volume_up, size: 16),
            label: const Text('Đọc đoạn này'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
        ],
      ),
    );
  }
}

// ── Add New Annotation Sheet ──────────────────────────────

class _AddAnnotationSheet extends StatefulWidget {
  final String selectedText;
  final Rect selectionRect;
  final int pageIndex;
  final PdfReaderController controller;

  const _AddAnnotationSheet({
    required this.selectedText,
    required this.selectionRect,
    required this.pageIndex,
    required this.controller,
  });

  @override
  State<_AddAnnotationSheet> createState() => _AddAnnotationSheetState();
}

class _AddAnnotationSheetState extends State<_AddAnnotationSheet> {
  final _noteCtrl = TextEditingController();
  Color _selectedColor = const Color(0xFFFFD54F);

  static const _colors = [
    Color(0xFFFFD54F), // Yellow
    Color(0xFF81C784), // Green
    Color(0xFF64B5F6), // Blue
    Color(0xFFE57373), // Red
    Color(0xFFCE93D8), // Purple
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Thêm ghi chú',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),

          const SizedBox(height: 12),

          // Selected text preview
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _selectedColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '"${widget.selectedText}"',
              style: const TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          // Color picker
          Row(
            children: _colors
                .map((c) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: _selectedColor == c ? 32 : 24,
                        height: _selectedColor == c ? 32 : 24,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: _selectedColor == c
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 12),

          // Note field
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ghi chú (tùy chọn)...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await widget.controller.addAnnotation(
                      pageIndex: widget.pageIndex,
                      bounds: widget.selectionRect,
                      text: widget.selectedText,
                      color: _selectedColor,
                      note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Lưu ghi chú'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
