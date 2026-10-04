import 'dart:math' as math;

import 'package:in4up/core/language/localized_material.dart';

/// Khung nhìn PDF luôn giữ `viewer` ở đúng một nhánh của tree. Bật/tắt panel
/// chỉ đẩy một lớp phủ trượt vào/ra bên phải, tránh unmount `PdfViewer` rồi
/// mount lại (nguồn gốc của việc nhảy về trang 1 ở PDF-PAGE-001).
class PdfReaderViewportShell extends StatelessWidget {
  const PdfReaderViewportShell({
    super.key,
    required this.viewer,
    required this.sidePanel,
    required this.showSidePanel,
    this.sidePanelWidthFactor = 0.35,
    this.maxSidePanelWidth = 420,
    this.animationDuration = const Duration(milliseconds: 220),
    this.animationCurve = Curves.easeOutCubic,
  });

  final Widget viewer;
  final Widget sidePanel;
  final bool showSidePanel;
  final double sidePanelWidthFactor;
  final double maxSidePanelWidth;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = math.min(
          constraints.maxWidth * sidePanelWidthFactor,
          maxSidePanelWidth,
        );

        return Stack(
          children: [
            Positioned.fill(child: viewer),
            AnimatedPositioned(
              duration: animationDuration,
              curve: animationCurve,
              top: 0,
              bottom: 0,
              right: showSidePanel ? 0 : -panelWidth,
              width: panelWidth,
              child: IgnorePointer(
                ignoring: !showSidePanel,
                child: AnimatedOpacity(
                  duration: animationDuration,
                  curve: animationCurve,
                  opacity: showSidePanel ? 1 : 0,
                  child: RepaintBoundary(child: sidePanel),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
