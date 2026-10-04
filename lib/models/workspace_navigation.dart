import 'package:flutter/widgets.dart';

/// A typed choice displayed by workspace navigation controls.
///
/// The model deliberately contains presentation metadata only. Selection and
/// persistence remain owned by the workspace using the control.
@immutable
class WorkspaceNavigationItem<T> {
  const WorkspaceNavigationItem({
    required this.value,
    required this.label,
    required this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool enabled;
}

/// Controls how choices are presented.
enum WorkspaceNavigationPresentation {
  /// Chips when enough width is available, otherwise a popup menu.
  adaptive,

  /// A horizontally scrollable row of chips.
  chips,

  /// A compact popup menu.
  menu,
}
