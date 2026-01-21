class CategoryTabs extends StatelessWidget {
  final AudioCategory selected;
  final Function(AudioCategory) onSelect;

  const CategoryTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: AudioCategory.values.map((category) {
          final isSelected = category == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.emoji),
                  const SizedBox(width: 4),
                  Text(category.label),
                ],
              ),
              selectedColor: category.color.withOpacity(0.3),
              checkmarkColor: category.color,
              onSelected: (_) => onSelect(category),
            ),
          );
        }).toList(),
      ),
    );
  }
}