// QA-PERF-001 — Widget test cho HeavyTaskWarningBanner: banner chỉ hiện khi
// HeavyTaskMonitor phát hiện ≥2 loại tác vụ nặng chạy chồng, và tự ẩn khi
// hết chồng chéo — không phụ thuộc UI thật (an toàn thêm vào bất kỳ màn
// hình nào mà không đổi hành vi).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/widgets/heavy_task_warning_banner.dart';
import 'package:in4up_core/heavy_task_monitor.dart';

void main() {
  setUp(() {
    HeavyTaskMonitor.instance.debugReset();
  });

  tearDown(() {
    HeavyTaskMonitor.instance.debugReset();
  });

  Widget harness() => const MaterialApp(
        home: Scaffold(
          body: HeavyTaskWarningBanner(message: 'Multiple heavy tasks running'),
        ),
      );

  testWidgets('ẩn khi không có tác vụ nặng nào chạy chồng', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('Multiple heavy tasks running'), findsNothing);
  });

  testWidgets('ẩn khi chỉ 1 LOẠI tác vụ nặng đang chạy', (tester) async {
    await tester.pumpWidget(harness());
    HeavyTaskMonitor.instance.begin(HeavyTaskKind.sttWhisper);
    await tester.pump();
    expect(find.text('Multiple heavy tasks running'), findsNothing);
    HeavyTaskMonitor.instance.end(HeavyTaskKind.sttWhisper);
  });

  testWidgets('hiện khi ≥2 LOẠI tác vụ nặng chạy chồng', (tester) async {
    await tester.pumpWidget(harness());
    HeavyTaskMonitor.instance.begin(HeavyTaskKind.aiChatLocal);
    HeavyTaskMonitor.instance.begin(HeavyTaskKind.translateOffline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Multiple heavy tasks running'), findsOneWidget);

    HeavyTaskMonitor.instance.end(HeavyTaskKind.aiChatLocal);
    HeavyTaskMonitor.instance.end(HeavyTaskKind.translateOffline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Multiple heavy tasks running'), findsNothing);
  });

  testWidgets('nút dismiss gọi onDismiss khi được truyền', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeavyTaskWarningBanner(
          message: 'Heavy tasks overlapping',
          onDismiss: () => dismissed = true,
        ),
      ),
    ));
    HeavyTaskMonitor.instance.begin(HeavyTaskKind.aiChatLocal);
    HeavyTaskMonitor.instance.begin(HeavyTaskKind.sttWhisper);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(dismissed, isTrue);

    HeavyTaskMonitor.instance.end(HeavyTaskKind.aiChatLocal);
    HeavyTaskMonitor.instance.end(HeavyTaskKind.sttWhisper);
  });
}
