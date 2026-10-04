import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

/// Inline difficulty controls shared by the Read batch import flows.
///
/// Tapping the currently selected level clears it, so a user can undo a
/// classification before importing without opening a separate editor.
class DifficultyLevelChips extends StatelessWidget {
  final DifficultyLevel? value;
  final ValueChanged<DifficultyLevel?> onChanged;
  final bool dense;

  const DifficultyLevelChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: dense ? 4 : 6,
      runSpacing: dense ? 2 : 4,
      children: [
        for (final level in DifficultyLevel.values)
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: EdgeInsets.symmetric(horizontal: dense ? 2 : 4),
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 3 : 6,
              vertical: dense ? 0 : 2,
            ),
            selected: value == level,
            onSelected: (_) => onChanged(value == level ? null : level),
            backgroundColor: level.color.withValues(alpha: 0.08),
            selectedColor: level.color.withValues(alpha: 0.28),
            side: BorderSide(
              color: level.color.withValues(alpha: value == level ? 0.9 : 0.32),
            ),
            label: Text(
              context.uiText(level.label),
              style: TextStyle(
                color: value == level ? level.color : Colors.white70,
                fontSize: dense ? 10 : 11.5,
                fontWeight: value == level ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// One-tap action chips used to apply the same difficulty to all selected
/// candidates in a batch.
class DifficultyLevelActionChips extends StatelessWidget {
  final ValueChanged<DifficultyLevel> onSelected;
  final bool dense;

  const DifficultyLevelActionChips({
    super.key,
    required this.onSelected,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: dense ? 4 : 6,
      runSpacing: dense ? 2 : 4,
      children: [
        for (final level in DifficultyLevel.values)
          ActionChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: EdgeInsets.symmetric(horizontal: dense ? 2 : 4),
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 3 : 6,
              vertical: dense ? 0 : 2,
            ),
            onPressed: () => onSelected(level),
            backgroundColor: level.color.withValues(alpha: 0.13),
            side: BorderSide(color: level.color.withValues(alpha: 0.35)),
            label: Text(
              context.uiText(level.label),
              style: TextStyle(
                color: level.color,
                fontSize: dense ? 10 : 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
