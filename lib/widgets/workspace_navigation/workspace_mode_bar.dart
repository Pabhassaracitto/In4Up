import 'package:flutter/material.dart';

import '../../models/workspace_navigation.dart';

/// A stateless, typed selector for a workspace's learning mode.
class WorkspaceModeBar<T> extends StatelessWidget {
  const WorkspaceModeBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.enabled = true,
    this.presentation = WorkspaceNavigationPresentation.adaptive,
    this.menuBreakpoint = 360,
    this.menuTooltip = 'Choose mode',
  });

  final List<WorkspaceNavigationItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final WorkspaceNavigationPresentation presentation;
  final double menuBreakpoint;
  final String menuTooltip;

  bool get _canChange => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useMenu = presentation == WorkspaceNavigationPresentation.menu ||
            (presentation == WorkspaceNavigationPresentation.adaptive &&
                constraints.maxWidth < menuBreakpoint);
        return useMenu ? _buildMenu(context) : _buildChips();
      },
    );
  }

  Widget _buildChips() {
    return SingleChildScrollView(
      key: const Key('workspace-mode-chips'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            ChoiceChip(
              key: ValueKey<Object?>('workspace-mode-${items[index].value}'),
              avatar: Icon(items[index].icon, size: 18),
              label: Text(items[index].label),
              selected: items[index].value == selectedValue,
              onSelected: _canChange && items[index].enabled
                  ? (selected) {
                      if (selected) onChanged!(items[index].value);
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final selected = _selectedItem;
    return PopupMenuButton<T>(
      key: const Key('workspace-mode-menu'),
      enabled: _canChange && items.any((item) => item.enabled),
      tooltip: menuTooltip,
      initialValue: selectedValue,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            child: Row(
              children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(item.label)),
                if (item.value == selectedValue)
                  Icon(
                    Icons.check,
                    key: const Key('workspace-mode-selected-check'),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected != null) ...[
              Icon(selected.icon, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  selected.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              Flexible(
                child: Text(
                  menuTooltip,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  WorkspaceNavigationItem<T>? get _selectedItem {
    for (final item in items) {
      if (item.value == selectedValue) return item;
    }
    return null;
  }
}
