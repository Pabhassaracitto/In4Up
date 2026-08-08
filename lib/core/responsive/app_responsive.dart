import 'package:flutter/material.dart';

/// Responsive helpers cho layout và text scale.

enum AppWindowClass {
  compact,
  medium,
  expanded,
  large,
}

class AppResponsive {
  static const double compactWidth = 360;
  static const double mediumWidth = 600;
  static const double expandedWidth = 1024;
  static const double largeWidth = 1440;

  static AppWindowClass classify(double width) {
    if (width < mediumWidth) return AppWindowClass.compact;
    if (width < expandedWidth) return AppWindowClass.medium;
    if (width < largeWidth) return AppWindowClass.expanded;
    return AppWindowClass.large;
  }

  static bool isCompact(double width) => classify(width) == AppWindowClass.compact;
  static bool isMedium(double width) => classify(width) == AppWindowClass.medium;
  static bool isExpanded(double width) => classify(width) == AppWindowClass.expanded;
  static bool isLarge(double width) => classify(width) == AppWindowClass.large;

  static double clampTextScale(double scale) {
    return scale.clamp(0.95, 1.15).toDouble();
  }

  static TextScaler clampTextScaler(TextScaler scaler) {
    return scaler.clamp(minScaleFactor: 0.95, maxScaleFactor: 1.15);
  }

  static int adaptiveGridColumns(
    double width, {
    int compact = 1,
    int medium = 2,
    int expanded = 3,
    int large = 4,
  }) {
    switch (classify(width)) {
      case AppWindowClass.compact:
        return compact;
      case AppWindowClass.medium:
        return medium;
      case AppWindowClass.expanded:
        return expanded;
      case AppWindowClass.large:
        return large;
    }
  }

  static double pageHorizontalPadding(double width) {
    switch (classify(width)) {
      case AppWindowClass.compact:
        return width < compactWidth ? 12 : 16;
      case AppWindowClass.medium:
        return 20;
      case AppWindowClass.expanded:
        return 24;
      case AppWindowClass.large:
        return 32;
    }
  }

  static double pageMaxContentWidth(double width) {
    switch (classify(width)) {
      case AppWindowClass.compact:
        return width;
      case AppWindowClass.medium:
        return 920;
      case AppWindowClass.expanded:
        return 1180;
      case AppWindowClass.large:
        return 1360;
    }
  }
}

class ResponsiveContentFrame extends StatelessWidget {
  final Widget child;
  final Alignment alignment;

  const ResponsiveContentFrame({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxWidth = AppResponsive.pageMaxContentWidth(width);
        final horizontalPadding = AppResponsive.pageHorizontalPadding(width);

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
