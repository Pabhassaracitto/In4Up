import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/battery_prompt_gate.dart';

void main() {
  group('BatteryPromptGate', () {
    test('allows only one request across startup and Settings at a time', () {
      final gate = BatteryPromptGate();

      expect(gate.tryEnter(), isTrue);
      expect(gate.tryEnter(), isFalse);

      gate.leave();
      expect(gate.tryEnter(), isTrue);
    });

    test('releases the gate after a completed request', () {
      final gate = BatteryPromptGate();

      expect(gate.tryEnter(), isTrue);
      gate.leave();
      expect(gate.tryEnter(), isTrue);
    });
  });
}
