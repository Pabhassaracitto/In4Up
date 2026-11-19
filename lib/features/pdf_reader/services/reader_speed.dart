/// Reader speed is an engine-independent multiplier. TtsService owns the
/// engine-specific conversion (e.g. system TTS divides by two, Edge uses SSML).
double readerSpeed(double value) =>
    value.isFinite ? value.clamp(0.25, 2.0).toDouble() : 1.0;

String readerSpeedLabel(double value) =>
    '${readerSpeed(value).toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';

double nextReaderSpeed(double value) {
  const stops = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  return stops.firstWhere((stop) => stop > value + 0.001,
      orElse: () => stops.first);
}
