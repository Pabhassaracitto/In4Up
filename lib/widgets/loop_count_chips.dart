// lib/widgets/loop_count_chips.dart
//
// AUDIT-1.21.0 #8 — điều khiển số lần lặp ngay trên popup A-B BÊN NGOÀI
// (trước đây chỉ có dropdown nằm sâu trong sheet "Thêm" / ABLoopControls
// không-compact). Dùng chung 1 nguồn `LoopPresets.dropdownValues` để KHÔNG
// bao giờ sinh lại 2 icon `∞`.

import 'package:in4up/core/language/localized_material.dart';

import '../models/loop_presets.dart';

class LoopCountChips extends StatelessWidget {
  const LoopCountChips({
    super.key,
    required this.maxLoopCount,
    required this.onChanged,
    this.dense = false,
  });

  final int maxLoopCount;
  final ValueChanged<int> onChanged;
  final bool dense;

  /// Key ổn định cho test / automation.
  static Key keyFor(int count) => ValueKey('loop_count_chip_$count');

  @override
  Widget build(BuildContext context) {
    final selected = LoopPresets.safeDropdownValue(maxLoopCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.uiText('Lặp lại'),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: dense ? 4 : 6,
          runSpacing: dense ? 2 : 4,
          children: [
            for (final count in LoopPresets.dropdownValues)
              ChoiceChip(
                key: keyFor(count),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                label: Text(
                  LoopPresets.labelFor(count),
                  style: TextStyle(
                    fontSize: dense ? 10.5 : 11.5,
                    color: selected == count
                        ? const Color(0xFF81C784)
                        : Colors.white70,
                    fontWeight: selected == count
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                selected: selected == count,
                selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.22),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(
                  color: selected == count
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.12),
                ),
                onSelected: (_) => onChanged(count),
              ),
          ],
        ),
      ],
    );
  }
}
