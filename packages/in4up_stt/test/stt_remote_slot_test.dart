// packages/in4up_stt/test/stt_remote_slot_test.dart
//
// WP2 (API-003) mục 4 — Single-flight cho STT qua API: 1 job tại một thời
// điểm, request kế tiếp báo "busy" (không treo). Cùng khuôn mẫu
// test/hymt_slot_test.dart (app layer) cho HyMtSlot.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/stt_remote_slot.dart';

void main() {
  group('SttRemoteSlot', () {
    test('first caller acquires immediately; release frees the slot',
        () async {
      final slot = SttRemoteSlot(maxWait: const Duration(milliseconds: 50));
      expect(slot.isHeld, isFalse);
      expect(await slot.acquire(), isTrue);
      expect(slot.isHeld, isTrue);
      slot.release();
      expect(slot.isHeld, isFalse);
    });

    test('concurrent callers serialize: never more than one holder',
        () async {
      final slot = SttRemoteSlot(maxWait: const Duration(seconds: 2));
      var holders = 0;
      var maxHolders = 0;

      Future<void> worker() async {
        expect(await slot.acquire(), isTrue);
        holders++;
        if (holders > maxHolders) maxHolders = holders;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        holders--;
        slot.release();
      }

      await Future.wait(<Future<void>>[
        worker(),
        worker(),
        worker(),
      ]);
      expect(maxHolders, 1);
      expect(slot.isHeld, isFalse);
    });

    test('busy after maxWait: acquire returns false fast, no hang', () async {
      final slot = SttRemoteSlot(maxWait: const Duration(milliseconds: 50));
      expect(await slot.acquire(), isTrue);
      final sw = Stopwatch()..start();
      final busy = await slot.acquire();
      sw.stop();
      expect(busy, isFalse);
      expect(sw.elapsedMilliseconds, lessThan(500));
      slot.release();
      // Không deadlock sau "busy": caller kế tiếp vẫn lấy được slot.
      expect(await slot.acquire(), isTrue);
      slot.release();
      expect(slot.isHeld, isFalse);
    });

    test('queue is FIFO: waiting caller runs after the first releases',
        () async {
      final slot = SttRemoteSlot(maxWait: const Duration(seconds: 2));
      final order = <String>[];
      expect(await slot.acquire(), isTrue);

      final second = slot.acquire().then((ok) {
        expect(ok, isTrue);
        order.add('second');
        slot.release();
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      order.add('first-done');
      slot.release();
      await second;
      expect(order, <String>['first-done', 'second']);
      expect(slot.isHeld, isFalse);
    });

    test('a waiter that times out is NOT handed the slot later', () async {
      final slot = SttRemoteSlot(maxWait: const Duration(milliseconds: 30));
      expect(await slot.acquire(), isTrue);
      final timedOut = slot.acquire();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await timedOut, isFalse);
      slot.release();
      expect(slot.isHeld, isFalse);
      expect(slot.pendingCount, 0);
    });

    test('default maxWait rất ngắn (job STT dài, caller kế tiếp không nên '
        'bị chặn chờ lâu)', () {
      final slot = SttRemoteSlot();
      expect(slot.maxWait, lessThanOrEqualTo(const Duration(seconds: 5)));
    });
  });
}
