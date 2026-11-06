import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/network_policy.dart';

void main() {
  group('NetworkPolicy — ADR-0021 (SIMPLIFIED)', () {
    test('alwaysOnline: online mọi lúc, bỏ qua kết nối', () {
      final cheap = NetworkPolicy.decide(
        op: OpCost.cheap, mode: NetworkMode.alwaysOnline, hasConnection: false,
      );
      expect(cheap.allowOnline, isTrue);
      expect(cheap.useCache, isFalse);

      final expensive = NetworkPolicy.decide(
        op: OpCost.expensive, mode: NetworkMode.alwaysOnline, hasConnection: false,
      );
      expect(expensive.allowOnline, isTrue);
    });

    test('alwaysOffline: không online, chỉ cache', () {
      final cheap = NetworkPolicy.decide(
        op: OpCost.cheap, mode: NetworkMode.alwaysOffline, hasConnection: true,
      );
      expect(cheap.allowOnline, isFalse);
      expect(cheap.useCache, isTrue);

      final expensive = NetworkPolicy.decide(
        op: OpCost.expensive, mode: NetworkMode.alwaysOffline, hasConnection: true,
      );
      expect(expensive.allowOnline, isFalse);
      expect(expensive.useCache, isTrue);
    });

    test('auto + có mạng + cheap → online', () {
      final d = NetworkPolicy.decide(
        op: OpCost.cheap, mode: NetworkMode.auto, hasConnection: true,
      );
      expect(d.allowOnline, isTrue);
      expect(d.useCache, isFalse);
    });

    test('auto + có mạng + expensive → user-gate (cache)', () {
      final d = NetworkPolicy.decide(
        op: OpCost.expensive, mode: NetworkMode.auto, hasConnection: true,
      );
      expect(d.allowOnline, isFalse);
      expect(d.useCache, isTrue);
    });

    test('auto + mất mạng → offline/cache (cả cheap/expensive)', () {
      final cheap = NetworkPolicy.decide(
        op: OpCost.cheap, mode: NetworkMode.auto, hasConnection: false,
      );
      expect(cheap.allowOnline, isFalse);
      expect(cheap.useCache, isTrue);

      final expensive = NetworkPolicy.decide(
        op: OpCost.expensive, mode: NetworkMode.auto, hasConnection: false,
      );
      expect(expensive.allowOnline, isFalse);
      expect(expensive.useCache, isTrue);
    });

    test('defaultForOp — auto khi có mạng', () {
      final cheap = NetworkPolicy.defaultForOp(OpCost.cheap, hasConnection: true);
      expect(cheap.allowOnline, isTrue);

      final expensive = NetworkPolicy.defaultForOp(OpCost.expensive, hasConnection: true);
      expect(expensive.allowOnline, isFalse);
      expect(expensive.useCache, isTrue);
    });

    test('Decision toString — có reason', () {
      final d = NetworkPolicy.decide(
        op: OpCost.cheap, mode: NetworkMode.auto, hasConnection: true,
      );
      expect(d.toString().contains('online'), isTrue);
    });
  });
}
