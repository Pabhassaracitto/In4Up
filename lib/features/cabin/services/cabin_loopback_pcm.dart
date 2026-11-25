import 'dart:typed_data';

/// Converts interleaved float PCM from a loopback device to 16 kHz mono PCM16.
///
/// Keep one instance for the entire capture: interpolation and the sample
/// clock cross packet boundaries. [convert] accepts whole input frames only.
/// Linear interpolation is intentionally lightweight; it is not an anti-alias
/// filter, so a higher-quality low-pass filter may be needed for some sources.
class CabinLoopbackPcmConverter {
  CabinLoopbackPcmConverter({
    required this.inputSampleRate,
    required this.channels,
  }) {
    if (inputSampleRate <= 0 || channels <= 0) {
      throw ArgumentError('Sample rate and channel count must be positive');
    }
  }

  static const int outputSampleRate = 16000;
  final int inputSampleRate;
  final int channels;

  // Output position is an integer in units of 1/outputSampleRate input frames.
  // Integer arithmetic prevents phase drift even for 44.1 kHz streams.
  int _frameIndex = 0;
  int _nextOutputPosition = 0;
  double _previous = 0;

  Uint8List convert(Float32List interleaved) {
    if (interleaved.length % channels != 0) {
      throw ArgumentError('PCM packet must contain complete interleaved frames');
    }
    final output = BytesBuilder(copy: false);
    for (var offset = 0; offset < interleaved.length; offset += channels) {
      var mono = 0.0;
      for (var channel = 0; channel < channels; channel++) {
        final value = interleaved[offset + channel];
        // Broken device samples must not make integer conversion throw.
        mono += value.isFinite ? value : 0.0;
      }
      mono /= channels;
      final currentPosition = _frameIndex * outputSampleRate;
      while (_nextOutputPosition <= currentPosition) {
        final fraction = _frameIndex == 0
            ? 1.0
            : (_nextOutputPosition - (currentPosition - outputSampleRate)) /
                outputSampleRate;
        final sample = _previous + (mono - _previous) * fraction;
        final bounded = sample.clamp(-1.0, 1.0);
        final pcm = bounded < 0
            ? (bounded * 32768).round()
            : (bounded * 32767).round();
        output.add([pcm & 0xff, (pcm >> 8) & 0xff]);
        _nextOutputPosition += inputSampleRate;
      }
      _previous = mono;
      _frameIndex++;
    }
    return output.takeBytes();
  }

  /// Forget the sample clock when a different capture session starts.
  void reset() {
    _frameIndex = 0;
    _nextOutputPosition = 0;
    _previous = 0;
  }
}
