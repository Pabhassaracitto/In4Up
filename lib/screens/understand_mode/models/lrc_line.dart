/// Represents a single line in an LRC file, with its timestamp and text.
class LrcLine {
  final Duration timestamp;
  final String text;

  const LrcLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => 'LrcLine(${timestamp.inSeconds}s: "$text")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LrcLine &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          text == other.text;

  @override
  int get hashCode => timestamp.hashCode ^ text.hashCode;
}
