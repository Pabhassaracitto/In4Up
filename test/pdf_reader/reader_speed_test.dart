import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/reader_speed.dart';
void main() {
  test('reader multiplier stays unscaled for TtsService engine mapping', () {
    expect(readerSpeed(1.5), 1.5);
    expect(readerSpeed(0), 0.25);
    expect(readerSpeed(5), 2.0);
    expect(readerSpeed(double.nan), 1.0);
  });
  test('labels preserve quarter steps and cycle reaches 1.5 exactly', () {
    expect(readerSpeedLabel(1.25), '1.25x');
    expect(readerSpeedLabel(1.5), '1.5x');
    expect(nextReaderSpeed(1.25), 1.5);
    expect(nextReaderSpeed(2), 0.75);
    expect(nextReaderSpeed(0.9), 1);
  });
}
