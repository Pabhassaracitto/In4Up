// READ-TOOLBAR-001 — seam test cho `CollapsibleBottomControls`.
//
// Artifact GPU (khối đen/sọc trên Mali/Adreno) KHÔNG tái hiện được trên
// sandbox/test env — theo lane A4, test này khoá các INVARIANT khiến artifact
// không thể trở lại mà không phá test:
//   1. Trạng thái ẩn (smart-hide): offset slide ≤ 1.0 chiều cao con (bỏ
//      overshoot phân số 1.2 — nghi phạm khối đen), opacity về 0, và GIỮ
//      nguyên chiều cao layout (hợp đồng "không nhảy chữ khi cuộn").
//   2. Trạng thái hiện: offset zero, opacity 1, đủ chiều cao.
//   3. Focus mode (collapsed): gập đúng về 0 và mở lại đủ chiều cao
//      (hợp đồng READ-FOCUS-001 giữ nguyên).
//   4. Stress ẩn/hiện + gập/mở lặp nhanh: không exception framework.
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

AnimatedSlide _slideOf(WidgetTester tester) =>
    tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));

AnimatedOpacity _opacityOf(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));

double _wrapperHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AnimatedSize)).height;

void main() {
  testWidgets('visible: con hiện đủ, offset zero, opacity 1', (tester) async {
    await tester.pumpWidget(_harness(visible: true, collapsed: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bottom-content')), findsOneWidget);
    expect(_slideOf(tester).offset, Offset.zero);
    expect(_opacityOf(tester).opacity, 1.0);
    expect(_wrapperHeight(tester), _kBarHeight);
  });

  testWidgets(
    'hidden (smart-hide): offset ≤ 1.0 chiều cao (không overshoot 1.2 cũ), '
    'opacity 0, GIỮ nguyên chiều cao layout',
    (tester) async {
      await tester.pumpWidget(_harness(visible: false, collapsed: false));
      await tester.pumpAndSettle();

      final slide = _slideOf(tester).offset;
      // Invariant READ-TOOLBAR-001: offset phân số > 1.0 chiều cao tạo pixel
      // vẽ ngoài vùng clip trên GPU yếu (nghi phạm khối đen).
      expect(slide.dy, lessThanOrEqualTo(1.0),
          reason: 'READ-TOOLBAR-001: offset ẩn vượt 1.0 chiều cao con — '
              'overshoot phân số sinh artifact GPU (khối đen)');
      expect(slide.dy, greaterThanOrEqualTo(0.0));
      expect(_opacityOf(tester).opacity, 0.0);
      // Smart-hide KHÔ được gập layout — tránh văn bản nhảy khi đọc.
      expect(_wrapperHeight(tester), _kBarHeight);
      // Con vẫn trong tree (state/animation giữ nguyên), chỉ bị trượt ra
      // ngoài + opacity 0.
      expect(find.byKey(const Key('bottom-content')), findsOneWidget);
    },
  );

  testWidgets('collapsed (Focus mode): gập về 0 rồi mở lại đủ chiều cao',
      (tester) async {
    await tester.pumpWidget(_harness(visible: true, collapsed: true));
    await tester.pumpAndSettle();
    expect(_wrapperHeight(tester), 0.0,
        reason: 'Hợp đồng READ-FOCUS-001: Focus gập thanh đáy về 0');

    // Thoát Focus → mở lại đủ chiều cao (không kẹt ở 0).
    await tester.pumpWidget(_harness(visible: true, collapsed: false));
    await tester.pumpAndSettle();
    expect(_wrapperHeight(tester), _kBarHeight);
    expect(find.byKey(const Key('bottom-content')), findsOneWidget);
  });

  testWidgets('stress: 10 vòng ẩn/hiện + 3 vòng focus không exception',
      (tester) async {
    var visible = true;
    await tester.pumpWidget(_harness(visible: visible, collapsed: false));

    // 10 vòng smart-hide toggle (mô phỏng cuộn lên/xuống liên tục — AT card).
    for (var i = 0; i < 10; i++) {
      visible = !visible;
      await tester.pumpWidget(_harness(visible: visible, collapsed: false));
      await tester.pump(const Duration(milliseconds: 130)); // giữa animation
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3 vòng Focus gập/mở nhanh (giữ AT của READ-FOCUS-001).
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(_harness(visible: true, collapsed: true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_harness(visible: true, collapsed: false));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_wrapperHeight(tester), _kBarHeight);
    expect(_slideOf(tester).offset, Offset.zero);
    expect(_opacityOf(tester).opacity, 1.0);
  });
}
