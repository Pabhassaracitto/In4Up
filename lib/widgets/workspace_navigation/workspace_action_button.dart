import 'package:flutter/material.dart';

/// A workspace action with a mobile-sized target and optional compact layout.
class WorkspaceActionButton extends StatelessWidget {
  const WorkspaceActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compact = false,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = compact
        ? IconButton.filledTonal(
            onPressed: onPressed,
            icon: Icon(icon),
            tooltip: tooltip ?? label,
          )
        : FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label, overflow: TextOverflow.ellipsis),
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: button,
    );
  }
}
