import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sheet chọn số lần phát mỗi từ
/// [allowInfinite]: false = chỉ 1-N (per-word), true = có ∞ (list-level)
class LoopCountPickerSheet extends StatefulWidget {
  final int current;
  final ValueChanged<int> onChanged;
  final bool allowInfinite;

  const LoopCountPickerSheet({
    super.key,
    required this.current,
    required this.onChanged,
    this.allowInfinite = false,
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
          24, 16, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Số lần phát',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            widget.allowInfinite
                ? 'Từ khó phát nhiều lần  •  ∞ = lặp mãi'
                : 'Từ khó phát nhiều lần để ghi nhớ',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Presets
          Row(
            children: [
              if (widget.allowInfinite) ...[
                _PresetItem(
                  label: '∞',
                  sublabel: 'mãi',
                  value: 0,
                  current: widget.current,
                  color: const Color(0xFFEF5350),
                  onTap: _select,
                ),
                const SizedBox(width: 8),
              ],
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

          // Custom input toggle
          GestureDetector(
            onTap: () =>
                setState(() => _showCustomInput = !_showCustomInput),
            child: Row(children: [
              Icon(
                  _showCustomInput
                      ? Icons.expand_less
                      : Icons.edit_outlined,
                  color: Colors.grey[500],
                  size: 15),
              const SizedBox(width: 6),
              Text(
                  _showCustomInput ? 'Ẩn' : 'Nhập số khác...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ]),
          ),

          if (_showCustomInput) ...[
            const SizedBox(height: 12),
            Row(children: [
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
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFB300), width: 1.5)),
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
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _select(int value) => widget.onChanged(value);

  void _applyCustom() {
    final text = _customCtrl.text.trim();
    final value = int.tryParse(text);
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số hợp lệ'),
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

class _PresetItem extends StatelessWidget {
  final String label, sublabel;
  final int value, current;
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
                    colors: [color.withValues(alpha: 0.8), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[400],
                      fontSize: label == '∞' ? 22 : 18,
                      fontWeight: FontWeight.w800)),
              Text(sublabel,
                  style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.grey[600],
                      fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}
