// lib/screens/tools/word_list/loop_count_picker.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sheet chọn số lần lặp TTS
/// count = 0 → vô hạn (∞)
/// count = 1-5 → preset
/// count > 5 → nhập thủ công
class LoopCountPickerSheet extends StatefulWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const LoopCountPickerSheet({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  State<LoopCountPickerSheet> createState() => _LoopCountPickerSheetState();
}

class _LoopCountPickerSheetState extends State<LoopCountPickerSheet> {
  final _customCtrl = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Số lần phát',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Từ khó phát nhiều lần để ghi nhớ  •  ∞ = lặp mãi không dừng',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Preset row: ∞  1  2  3  4  5
          Row(
            children: [
              _PresetItem(
                label: '∞',
                sublabel: 'mãi',
                value: 0,
                current: widget.current,
                color: const Color(0xFFEF5350),
                onTap: _select,
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (i) {
                final v = i + 1;
                return Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
                  child: _PresetItem(
                    label: '$v',
                    sublabel: 'lần',
                    value: v,
                    current: widget.current,
                    color: const Color(0xFFFFB300),
                    onTap: _select,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Toggle custom input
          GestureDetector(
            onTap: () => setState(() => _showCustomInput = !_showCustomInput),
            child: Row(
              children: [
                Icon(
                  _showCustomInput ? Icons.expand_less : Icons.edit_outlined,
                  color: Colors.grey[500],
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  _showCustomInput ? 'Ẩn nhập thủ công' : 'Nhập số khác...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),

          if (_showCustomInput) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'VD: 7, 10, 20...',
                      hintStyle:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFB300), width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _applyCustom(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyCustom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _select(int value) {
    widget.onChanged(value);
  }

  void _applyCustom() {
    final text = _customCtrl.text.trim();
    final value = int.tryParse(text);
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số hợp lệ (0 = vô hạn)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    widget.onChanged(value);
    Navigator.pop(context);
  }
}

// ── Preset item ──────────────────────────────────────────
class _PresetItem extends StatelessWidget {
  final String label;
  final String sublabel;
  final int value;
  final int current;
  final Color color;
  final ValueChanged<int> onTap;

  const _PresetItem({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.current,
    required this.color,
    required this.onTap,
  });

  bool get selected => current == value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? null
                : Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[400],
                  fontSize: label == '∞' ? 22 : 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: selected
                      ? Colors.white.withOpacity(0.8)
                      : Colors.grey[600],
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
