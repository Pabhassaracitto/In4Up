// lib/screens/read_mode/sheets/create_segment_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';

class CreateSegmentSheet {
  CreateSegmentSheet._();

  /// Show sheet to create segment from a single line
  static void showFromLine(BuildContext context, int lineIndex) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _CreateSegmentContent(
        startLine: lineIndex,
        endLine: lineIndex,
      ),
    );
  }

  /// Show sheet to create segment from a range of lines
  static void showFromRange(
    BuildContext context,
    int startLine,
    int endLine,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _CreateSegmentContent(
        startLine: startLine,
        endLine: endLine,
      ),
    );
  }
}

class _CreateSegmentContent extends StatefulWidget {
  final int startLine;
  final int endLine;

  const _CreateSegmentContent({
    required this.startLine,
    required this.endLine,
  });

  @override
  State<_CreateSegmentContent> createState() => _CreateSegmentContentState();
}

class _CreateSegmentContentState extends State<_CreateSegmentContent> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  late int _startLine;
  late int _endLine;
  Color _selectedColor = const Color(0xFF2196F3);
  bool _isCreating = false;

  static const List<Color> _colorOptions = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFE91E63), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _startLine = widget.startLine;
    _endLine = widget.endLine;

    // Auto-generate name from first line content
    final tp = context.read<TextProvider>();
    if (tp.lines.isNotEmpty && _startLine < tp.lines.length) {
      final firstLineContent = tp.lines[_startLine].content;
      final preview = firstLineContent.length > 30
          ? '${firstLineContent.substring(0, 30)}...'
          : firstLineContent;
      _nameController.text = preview;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TextProvider>();
    final totalLines = tp.lines.length;
    final lineCount = _endLine - _startLine + 1;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== DRAG HANDLE =====
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ===== HEADER =====
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bookmark_add,
                  color: _selectedColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tạo Segment mới',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$lineCount dòng (${_startLine + 1} → ${_endLine + 1})',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ===== NAME INPUT =====
          _buildLabel('Tên segment'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              hint: 'Nhập tên cho segment...',
              icon: Icons.label_outline,
            ),
            maxLength: 50,
          ),

          const SizedBox(height: 12),

          // ===== LINE RANGE =====
          _buildLabel('Phạm vi dòng'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildLineSelector(
                  label: 'Từ dòng',
                  value: _startLine + 1,
                  onChanged: (val) {
                    setState(() {
                      _startLine = val - 1;
                      if (_startLine > _endLine) _endLine = _startLine;
                    });
                  },
                  min: 1,
                  max: totalLines,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward,
                    color: Colors.grey[600], size: 20),
              ),
              Expanded(
                child: _buildLineSelector(
                  label: 'Đến dòng',
                  value: _endLine + 1,
                  onChanged: (val) {
                    setState(() {
                      _endLine = val - 1;
                      if (_endLine < _startLine) _startLine = _endLine;
                    });
                  },
                  min: 1,
                  max: totalLines,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ===== PREVIEW =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = _startLine;
                      i <= _endLine && i < tp.lines.length;
                      i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${i + 1}. ${tp.lines[i].content}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ===== COLOR PICKER =====
          _buildLabel('Màu đánh dấu'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorOptions.map((color) {
              final isSelected = _selectedColor.value == color.value;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedColor = color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // ===== NOTE INPUT =====
          _buildLabel('Ghi chú (tùy chọn)'),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Ghi chú về segment này...',
              icon: Icons.note_alt_outlined,
            ),
            maxLines: 2,
            maxLength: 200,
          ),

          const SizedBox(height: 20),

          // ===== CREATE BUTTON =====
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreating ? null : () => _createSegment(context),
              icon: _isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bookmark_add, size: 20),
              label: Text(_isCreating ? 'Đang tạo...' : 'Tạo Segment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[300],
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _selectedColor, width: 1.5),
      ),
      counterStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildLineSelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required int min,
    required int max,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: value > min
                    ? () {
                        HapticFeedback.selectionClick();
                        onChanged(value - 1);
                      }
                    : null,
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 22,
                  color: value > min
                      ? _selectedColor
                      : Colors.grey[700],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: value < max
                    ? () {
                        HapticFeedback.selectionClick();
                        onChanged(value + 1);
                      }
                    : null,
                child: Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: value < max
                      ? _selectedColor
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createSegment(BuildContext context) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên segment'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final tp = context.read<TextProvider>();
      await tp.createSegment(
        name: name,
        startLine: _startLine,
        endLine: _endLine,
        color: _selectedColor,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.bookmark_added, color: _selectedColor, size: 18),
                const SizedBox(width: 8),
                Text('Đã tạo segment "$name"'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2A2A3E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo segment: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red[900],
          ),
        );
      }
    }
  }
}