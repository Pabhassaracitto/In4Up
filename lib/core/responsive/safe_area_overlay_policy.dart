import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shortcuts/shortcut_registry.dart';

/// Shared spacing used by floating surfaces. It is intentionally not a
/// screen-specific pixel offset.
class I4uSafeAreaPolicy {
  const I4uSafeAreaPolicy._();

  static double effectiveBottomInset({
    required double safeAreaBottom,
    required double viewInsetBottom,
  }) => math.max(0, math.max(safeAreaBottom, viewInsetBottom));

  static double floatingBottomOffset({
    required double safeAreaBottom,
    required double viewInsetBottom,
    required double navigationHeight,
    double spacing = 12,
  }) {
    return effectiveBottomInset(
          safeAreaBottom: safeAreaBottom,
          viewInsetBottom: viewInsetBottom,
        ) +
        navigationHeight +
        spacing;
  }
}

enum I4uOverlayLayer { content, navigation, miniPlayer, panel, sheet, dialog, fullScreenModal }

/// Centralized ordering prevents each screen from inventing its own z-index.
class I4uOverlayPolicy {
  const I4uOverlayPolicy._();

  static int order(I4uOverlayLayer layer) => layer.index;

  static bool isAbove(I4uOverlayLayer a, I4uOverlayLayer b) => order(a) > order(b);

  static bool miniPlayerVisibleInForeground({
    required bool quickActionsOpen,
    required bool largeSheetOpen,
    required bool expandedPlayerOpen,
  }) {
    if (expandedPlayerOpen || largeSheetOpen) return false;
    return !quickActionsOpen;
  }

  static bool audioContinuesInBackground({
    required bool largeSheetOpen,
    required bool expandedPlayerOpen,
  }) => largeSheetOpen && !expandedPlayerOpen;

  static I4uOverlayLayer layerForShortcutScope(I4uShortcutScope scope) {
    switch (scope) {
      case I4uShortcutScope.global:
      case I4uShortcutScope.workspace:
        return I4uOverlayLayer.content;
      case I4uShortcutScope.player:
        return I4uOverlayLayer.miniPlayer;
      case I4uShortcutScope.modal:
        return I4uOverlayLayer.dialog;
    }
  }
}

/// A small primitive for surfaces that must avoid both safe-area and keyboard
/// insets. It consumes runtime MediaQuery values rather than fixed offsets.
class I4uSafeAreaFloatingHost extends StatelessWidget {
  const I4uSafeAreaFloatingHost({
    super.key,
    required this.child,
    this.navigationHeight = 0,
    this.spacing = 12,
    this.alignment = Alignment.bottomCenter,
  });

  final Widget child;
  final double navigationHeight;
  final double spacing;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = I4uSafeAreaPolicy.floatingBottomOffset(
      safeAreaBottom: media.padding.bottom,
      viewInsetBottom: media.viewInsets.bottom,
      navigationHeight: navigationHeight,
      spacing: spacing,
    );

    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: child,
      ),
    );
  }
}
