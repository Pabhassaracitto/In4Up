import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_core/heavy_task_monitor.dart';

void main() {
  setUp(() {
    HeavyTaskMonitor.instance.debugReset();
  });

  test('begin/end theo đúng cặp không để lại state thừa', () {
    final monitor = HeavyTaskMonitor.instance;
    expect(monitor.activeCount, 0);

    monitor.begin(HeavyTaskKind.aiChatLocal);
    expect(monitor.isActive(HeavyTaskKind.aiChatLocal), isTrue);
    expect(monitor.activeCount, 1);

    monitor.end(HeavyTaskKind.aiChatLocal);
    expect(monitor.isActive(HeavyTaskKind.aiChatLocal), isFalse);
    expect(monitor.activeCount, 0);
  });

  test('end() thừa (không khớp begin) không làm số đếm âm', () {
    final monitor = HeavyTaskMonitor.instance;
    monitor.end(HeavyTaskKind.sttWhisper);
    expect(monitor.countOf(HeavyTaskKind.sttWhisper), 0);
    expect(monitor.activeCount, 0);
  });

  test('2 lượt CÙNG loại nối tiếp nhau không bị coi là chồng chéo', () async {
    final monitor = HeavyTaskMonitor.instance;
    await monitor.track(HeavyTaskKind.sttWhisper, () async => 1);
    await monitor.track(HeavyTaskKind.sttWhisper, () async => 2);
    expect(monitor.hasOverlappingHeavyTasks, isFalse);
    expect(monitor.activeCount, 0);
  });

  test('2 LOẠI khác nhau chạy chồng ⇒ hasOverlappingHeavyTasks = true',
      () async {
    final monitor = HeavyTaskMonitor.instance;
    monitor.begin(HeavyTaskKind.aiChatLocal);
    monitor.begin(HeavyTaskKind.translateOffline);

    expect(monitor.hasOverlappingHeavyTasks, isTrue);
    expect(
      monitor.activeKinds,
      {HeavyTaskKind.aiChatLocal, HeavyTaskKind.translateOffline},
    );

    monitor.end(HeavyTaskKind.aiChatLocal);
    expect(monitor.hasOverlappingHeavyTasks, isFalse);

    monitor.end(HeavyTaskKind.translateOffline);
    expect(monitor.activeCount, 0);
  });

  test('track() luôn gọi end() kể cả khi action throw', () async {
    final monitor = HeavyTaskMonitor.instance;
    await expectLater(
      monitor.track(HeavyTaskKind.ttsSynthesis, () async {
        throw StateError('boom');
      }),
      throwsStateError,
    );
    // Dù action lỗi, "end" vẫn phải chạy — không bị kẹt ở trạng thái busy.
    expect(monitor.isActive(HeavyTaskKind.ttsSynthesis), isFalse);
    expect(monitor.activeCount, 0);
  });

  test('track() trả đúng giá trị của action khi thành công', () async {
    final monitor = HeavyTaskMonitor.instance;
    final result = await monitor.track(
      HeavyTaskKind.aiAnalysisLocal,
      () async => 'ok',
    );
    expect(result, 'ok');
    expect(monitor.activeCount, 0);
  });

  test('notifyListeners được gọi khi begin/end', () {
    final monitor = HeavyTaskMonitor.instance;
    var notifyCount = 0;
    void listener() => notifyCount++;
    monitor.addListener(listener);
    monitor.begin(HeavyTaskKind.sttWhisper);
    monitor.end(HeavyTaskKind.sttWhisper);
    monitor.removeListener(listener);
    expect(notifyCount, 2);
  });
}
