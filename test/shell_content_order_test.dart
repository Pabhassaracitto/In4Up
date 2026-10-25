import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/shell_content_order.dart';

void main() {
  group('ShellContentOrder', () {
    test('Listen then Read keeps library sides aligned (non-default)', () {
      const order = ShellContentOrder.listenRead;

      expect(order.isListenFirst, isTrue);
      expect(order.listenOnLeft, isTrue);
      expect(order.readOnLeft, isFalse);
      expect(order.toggled, ShellContentOrder.readListen);
      expect(order.storageValue, 'listenRead');
    });

    test('Read then Listen puts the Read library on the left', () {
      const order = ShellContentOrder.readListen;

      expect(order.isReadFirst, isTrue);
      expect(order.listenOnLeft, isFalse);
      expect(order.readOnLeft, isTrue);
      expect(order.toggled, ShellContentOrder.listenRead);
      expect(order.storageValue, 'readListen');
    });

    // Owner 2026-10-25: mặc định ĐỔI sang Đọc-trước-Nghe. Giá trị lạ/thiếu
    // phải rơi về mặc định MỚI (Read first), không phải mặc định cũ.
    test('unknown persisted values fail safe to the default order', () {
      expect(
        shellContentOrderFromStorage(null),
        ShellContentOrder.readListen,
      );
      expect(
        shellContentOrderFromStorage('old-or-corrupt-value'),
        ShellContentOrder.readListen,
      );
      expect(
        shellContentOrderFromStorage(42),
        ShellContentOrder.readListen,
      );
      expect(
        shellContentOrderFromStorage('readListen'),
        ShellContentOrder.readListen,
      );
      expect(
        shellContentOrderFromStorage('listenRead'),
        ShellContentOrder.listenRead,
      );
    });
  });
}
