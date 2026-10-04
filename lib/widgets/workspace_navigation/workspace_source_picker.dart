import 'package:flutter/material.dart';

import '../../models/workspace_navigation.dart';
import 'workspace_mode_bar.dart';

/// A typed source selector that can use chips or a compact menu.
class WorkspaceSourcePicker<T> extends StatelessWidget {
  const WorkspaceSourcePicker({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.enabled = true,
    this.presentation = WorkspaceNavigationPresentation.adaptive,
    this.menuBreakpoint = 360,
    this.menuTooltip = 'Choose source',
  });

  final List<WorkspaceNavigationItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final WorkspaceNavigationPresentation presentation;
  final double menuBreakpoint;
  final String menuTooltip;

  @override
  Widget build(BuildContext context) {
    return WorkspaceModeBar<T>(
      key: const Key('workspace-source-picker'),
      items: items,
      selectedValue: selectedValue,
      onChanged: onChanged,
      enabled: enabled,
      presentation: presentation,
      menuBreakpoint: menuBreakpoint,
      menuTooltip: menuTooltip,
    );
  }
}
