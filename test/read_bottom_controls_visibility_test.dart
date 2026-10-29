// READ-TOOLBAR-001 (v2) — seam test cho `CollapsibleBottomControls`.
//
// Artifact GPU (khối đen trên Mali/Adreno): Sau nghiệm thu v1, owner xác nhận
// icon đã ẩn nhưng khối đen vẫn còn. Bước 2 đã LOẠI BỎ TOÀN BỘ animation widget
// (AnimatedSize, AnimatedSlide, AnimatedOpacity, ClipRect).
//
// Test suite này khoá các INVARIANT v2:
//   1. CẤM TOÀN BỘ widget animation (AnimatedSize, AnimatedSlide, AnimatedOpacity,
//      ClipRect) xuất hiện trong CollapsibleBottomControls.
//   2. Trạng thái hiện: Opacity 1.0, IgnorePointer false, đúng chiều cao layout.
//   3. Trạng thái ẩn (smart-hide): Opacity 0.0, IgnorePointer true, GIỮ nguyên
//      chiều cao layout (hợp đồng không nhảy chữ khi cuộn).
//   4. Focus mode (collapsed): gập về 0 và mở lại đủ chiều cao (hợp đồng READ-FOCUS-001).
//   5. Stress ẩn/hiện + gập/mở lặp nhanh: không exception framework.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/read_mode/widgets/collapsible_bottom_controls.dart';

const double _kBarHeight = 64;

Widget _harness({required bool visible, required bool collapsed}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const Expanded(child: SizedBox.shrink()),
          CollapsibleBottomControls(
            visible: visible,
            collapsed: collapsed,
            child: Container(
              key: const Key('bottom-content'),
              height: _kBarHeight,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    ),
  );
}

Opacity _opacityOf(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity));

IgnorePointer _ignorePointerOf(WidgetTester tester) =>
    tester.widget<IgnorePointer>(find.byType(IgnorePointer));

double _wrapperHeight(WidgetTester tester) =>
    tester.getSize(find.byType(CollapsibleBottomControls)).height;

void main() {
  testWidgets('cấm 4 widget animation quay lại wrapper', (tester) async {
    await tester.pumpWidget(_harness(visible: true, collapsed: false));
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedSize), findsNothing,
        reason: 'AnimatedSize tạo RenderAnimatedSize clip layer trên GPU');
    expect(find.byType(AnimatedSlide), findsNothing,
        reason: 'AnimatedSlide tạo FractionalTranslationLayer trên GPU');
    expect(find.byType(AnimatedOpacity), findsNothing,
        reason: 'AnimatedOpacity tạo RenderOpacity saveLayer biến thiên alpha');
    expect(find.byType(ClipRect), findsNothing,
        reason: 'ClipRect tạo clip layer tường minh');
  });

  testWidgets('visible: con hiện đủ, opacity 1, IgnorePointer false', (tester) async {
    await tester.pumpWidget(_harness(visible: true, collapsed: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bottom-content')), findsOneWidget);
    expect(_opacityOf(tester).opacity, 1.0);
    expect(_ignorePointerOf(tester).ignoring, isFalse);
    expect(_wrapperHeight(tester), _kBarHeight);
  });

  testWidgets(
    'hidden (smart-hide): opacity 0, IgnorePointer true, GIỮ nguyên chiều cao layout',
    (tester) async {
      await tester.pumpWidget(_harness(visible: false, collapsed: false));
      await tester.pumpAndSettle();

      expect(_opacityOf(tester).opacity, 0.0);
      expect(_ignorePointerOf(tester).ignoring, isTrue);
      // Smart-hide KHÔNG được gập layout — tránh văn bản nhảy khi đọc.
      expect(_wrapperHeight(tester), _kBarHeight);
      expect(find.byKey(const Key('bottom-content')), findsOneWidget);
    },
  );

  testWidgets('collapsed (Focus mode): gập về 0 rồi mở lại đủ chiều cao',
      (tester) async {
    await tester.pumpWidget(_harness(visible: true, collapsed: true));
    await tester.pumpAndSettle();
    expect(_wrapperHeight(tester), 0.0,
        reason: 'Hợp đồng READ-FOCUS-001: Focus gập thanh đáy về 0');

    // Thoát Focus -> mở lại đủ chiều cao (không kẹt ở 0).
    await tester.pumpWidget(_harness(visible: true, collapsed: false));
    await tester.pumpAndSettle();
    expect(_wrapperHeight(tester), _kBarHeight);
    expect(find.byKey(const Key('bottom-content')), findsOneWidget);
  });

  testWidgets('stress: 10 vòng ẩn/hiện + 3 vòng focus không exception',
      (tester) async {
    var visible = true;
    await tester.pumpWidget(_harness(visible: visible, collapsed: false));

    // 10 vòng smart-hide toggle
    for (var i = 0; i < 10; i++) {
      visible = !visible;
      await tester.pumpWidget(_harness(visible: visible, collapsed: false));
      await tester.pump(const Duration(milliseconds: 130));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3 vòng Focus gập/mở
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(_harness(visible: true, collapsed: true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_harness(visible: true, collapsed: false));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_wrapperHeight(tester), _kBarHeight);
    expect(_opacityOf(tester).opacity, 1.0);
    expect(_ignorePointerOf(tester).ignoring, isFalse);
  });
}
