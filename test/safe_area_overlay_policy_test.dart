import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/responsive/safe_area_overlay_policy.dart';

void main() {
  test('effective inset uses the larger runtime inset', () {
    expect(
      I4uSafeAreaPolicy.effectiveBottomInset(
        safeAreaBottom: 34,
        viewInsetBottom: 0,
      ),
      34,
    );
    expect(
      I4uSafeAreaPolicy.effectiveBottomInset(
        safeAreaBottom: 20,
        viewInsetBottom: 300,
      ),
      300,
    );
  });

  test('floating offset combines inset, navigation and spacing', () {
    expect(
      I4uSafeAreaPolicy.floatingBottomOffset(
        safeAreaBottom: 34,
        viewInsetBottom: 0,
        navigationHeight: 64,
        spacing: 12,
      ),
      110,
    );
  });

  test('mobile layer policy hides foreground mini player correctly', () {
    expect(
      I4uOverlayPolicy.miniPlayerVisibleInForeground(
        quickActionsOpen: true,
        largeSheetOpen: false,
        expandedPlayerOpen: false,
      ),
      isFalse,
    );
    expect(
      I4uOverlayPolicy.audioContinuesInBackground(
        largeSheetOpen: true,
        expandedPlayerOpen: false,
      ),
      isTrue,
    );
    expect(
      I4uOverlayPolicy.isAbove(
        I4uOverlayLayer.sheet,
        I4uOverlayLayer.miniPlayer,
      ),
      isTrue,
    );
  });
}
