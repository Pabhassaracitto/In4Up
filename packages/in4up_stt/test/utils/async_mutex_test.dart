import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/async_mutex.dart';

void main() {
  test('chạy tuần tự — lượt sau luôn bắt đầu sau khi lượt trước kết thúc',
      () async {
    final mutex = AsyncMutex();
    final log = <String>[];

    Future<void> job(String name, Duration delay) {
      return mutex.run(() async {
        log.add('start:$name');
        await Future<void>.delayed(delay);
        log.add('end:$name');
      });
    }

    final f1 = job('A', const Duration(milliseconds: 30));
    final f2 = job('B', const Duration(milliseconds: 10));
    await Future.wait([f1, f2]);

    // B KHÔNG được bắt đầu trước khi A kết thúc, dù B có delay ngắn hơn —
    // đây chính là điểm khác biệt so với chạy song song (Future.wait trần).
    expect(log, ['start:A', 'end:A', 'start:B', 'end:B']);
  });

  test('lỗi của 1 lượt không làm kẹt hàng đợi (lượt sau vẫn chạy)', () async {
    final mutex = AsyncMutex();

    final failing = mutex.run<void>(() async {
      throw StateError('boom');
    });

    final following = mutex.run(() async => 42);

    await expectLater(failing, throwsStateError);
    expect(await following, 42);
  });

  test('trả đúng giá trị/isolate kết quả cho từng caller (không trộn lẫn)',
      () async {
    final mutex = AsyncMutex();
    final results = await Future.wait([
      mutex.run(() async => 1),
      mutex.run(() async => 2),
      mutex.run(() async => 3),
    ]);
    expect(results, [1, 2, 3]);
  });

  test('isBusy phản ánh đúng có lượt nào đang chờ/chạy không', () async {
    final mutex = AsyncMutex();
    expect(mutex.isBusy, isFalse);

    final completer = Completer<void>();
    final running = mutex.run(() => completer.future);
    expect(mutex.isBusy, isTrue);

    completer.complete();
    await running;
    expect(mutex.isBusy, isFalse);
  });
}
