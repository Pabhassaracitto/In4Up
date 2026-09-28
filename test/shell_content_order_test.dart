import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/shell_content_order.dart';

void main() {
  group('ShellContentOrder', () {
    test('defaults to Listen then Read and keeps library sides aligned', () {
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

    test('unknown persisted values fail safe to the default order', () {
      expect(
        shellContentOrderFromStorage(null),
        ShellContentOrder.listenRead,
      );
      expect(
        shellContentOrderFromStorage('old-or-corrupt-value'),
        ShellContentOrder.listenRead,
      );
      expect(
        shellContentOrderFromStorage(42),
        ShellContentOrder.listenRead,
      );
      expect(
        shellContentOrderFromStorage('readListen'),
        ShellContentOrder.readListen,
      );
    });
  });
}
