import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/memory_mode/widgets/remember_workspace_header.dart';

Widget _host() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RememberWorkspaceHeader(
            dueCount: 3,
            totalWords: 42,
            onOpenReview: () {},
            onOpenLearnByHeart: () {},
            onOpenWordList: () {},
            onOpenTimeline: () {},
            onOpenStats: () {},
            onOpenMap: () {},
            onOpenQuickActions: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('mặc định gọn: giữ CTA chính + badge, ẩn chi tiết/công cụ',
      (tester) async {
    await tester.pumpWidget(_host());

    expect(find.byKey(rememberPrimaryCtaKey), findsOneWidget);
    expect(find.byKey(rememberLearnByHeartKey), findsOneWidget);
    expect(find.byKey(rememberDueBadgeKey), findsOneWidget);
    expect(find.byKey(rememberProgressGroupKey), findsOneWidget);
    expect(find.byKey(rememberDetailsToggleKey), findsOneWidget);

    expect(find.byKey(rememberToolWordListKey), findsNothing);
    expect(find.byKey(rememberToolQuickActionsKey), findsNothing);
    expect(find.text('Tổng từ: 42'), findsNothing);
  });

  testWidgets('mở chi tiết và nhóm công cụ khi cần — không mất chức năng',
      (tester) async {
    await tester.pumpWidget(_host());

    await tester.tap(find.byKey(rememberDetailsToggleKey));
    await tester.pump();
    expect(find.text('Tổng từ: 42'), findsOneWidget);

    await tester.tap(find.byKey(rememberProgressGroupKey));
    await tester.pump();
    expect(find.byKey(rememberToolWordListKey), findsOneWidget);
    expect(find.byKey(rememberToolTimelineKey), findsOneWidget);
    expect(find.byKey(rememberToolStatsKey), findsOneWidget);
    expect(find.byKey(rememberToolWordMapKey), findsOneWidget);
    expect(find.byKey(rememberToolQuickActionsKey), findsOneWidget);
  });

  testWidgets('màn hẹp 320dp: CTA vẫn dùng được, không overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());

    expect(tester.takeException(), isNull);
    expect(find.byKey(rememberPrimaryCtaKey), findsOneWidget);
    await tester.tap(find.byKey(rememberPrimaryCtaKey));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
