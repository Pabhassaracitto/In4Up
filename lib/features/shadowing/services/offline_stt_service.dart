import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';

/// Explicit outcomes keep microphone/silence problems separate from an STT
/// engine failure. A successful-but-empty engine result is not a score.
class ShadowingTranscription {
  const ShadowingTranscription({this.text, this.errorCode});

  final String? text;
  final String? errorCode;

  bool get hasText => text?.trim().isNotEmpty == true;
}

enum RecordedAudioSignal { missing, silent, audible, unknown }

/// Minimal signal check for the PCM WAV produced by Shadowing's recorder.
/// Unsupported containers are left to STT rather than incorrectly reported as
/// silence. This is a signal-presence check, not a speech recognizer.
class RecordedAudioInspector {
  static Future<RecordedAudioSignal> inspect(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() <= 44) {
      return RecordedAudioSignal.missing;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length < 44 || !_hasAscii(bytes, 0, 'RIFF') || !_hasAscii(bytes, 8, 'WAVE')) {
      return RecordedAudioSignal.unknown;
    }

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    var offset = 12;
    var format = 0;
    var bitsPerSample = 0;
    var dataStart = -1;
    var dataLength = 0;
    while (offset + 8 <= bytes.length) {
      final chunkLength = data.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      if (chunkLength > bytes.length - chunkStart) return RecordedAudioSignal.unknown;
      if (_hasAscii(bytes, offset, 'fmt ') && chunkLength >= 16) {
        format = data.getUint16(chunkStart, Endian.little);
        bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
      } else if (_hasAscii(bytes, offset, 'data')) {
        dataStart = chunkStart;
        dataLength = chunkLength;
        break;
      }
      offset = chunkStart + chunkLength + (chunkLength.isOdd ? 1 : 0);
    }
    if (dataStart < 0 || dataLength == 0) return RecordedAudioSignal.missing;
    if (!((format == 1 && (bitsPerSample == 16 || bitsPerSample == 8)) ||
        (format == 3 && bitsPerSample == 32))) {
      return RecordedAudioSignal.unknown;
    }

    var peak = 0.0;
    final bytesPerSample = bitsPerSample ~/ 8;
    final end = dataStart + dataLength - bytesPerSample;
    for (var i = dataStart; i <= end; i += bytesPerSample) {
      final sample = switch ((format, bitsPerSample)) {
        (1, 16) => data.getInt16(i, Endian.little).abs() / 32768.0,
        (1, 8) => (data.getUint8(i) - 128).abs() / 128.0,
        (3, 32) => data.getFloat32(i, Endian.little).abs(),
        _ => 0.0,
      };
      if (sample > peak) peak = sample;
      if (peak >= 0.006) return RecordedAudioSignal.audible;
    }
    // Ignore tiny codec/ADC noise below roughly -44 dBFS, but do not demand
    // speech-level RMS; quiet speakers still pass if there is real signal.
    return RecordedAudioSignal.silent;
  }

  static bool _hasAscii(List<int> bytes, int offset, String value) {
    if (offset + value.length > bytes.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (bytes[offset + i] != value.codeUnitAt(i)) return false;
    }
    return true;
  }
}

/// Shadowing-specific adapter to the shared STT facade. The shared engine
/// defaults remain untouched; file transcription locally enables its intended
/// native-empty -> Whisper fallback and bypasses cache for each new recording.
class OfflineSTTService {
  static final _facade = SttServiceFacade();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _facade.initialize(config: SttConfig.quickNote);
    _initialized = true;
    debugPrint('✅ OfflineSTTService (via SttFacade) initialized');
  }

  static Future<ShadowingTranscription> transcribe(String audioPath) async {
    try {
      final signal = await RecordedAudioInspector.inspect(audioPath);
      if (signal == RecordedAudioSignal.missing || signal == RecordedAudioSignal.silent) {
        return const ShadowingTranscription(errorCode: 'no_audio');
      }
      if (!_initialized) await initialize();

      final output = await _facade.transcribeFile(
        audioPath,
        // Native STT deliberately does not support file transcription. Without
        // this local fallback the quickNote config returned an empty native
        // result (success=true) and every practice was mislabeled "check mic".
        config: SttConfig.quickNote.copyWith(
          autoFallback: true,
          cacheResults: false,
        ),
      );

      if (!output.success) {
        debugPrint('⚠️ Shadowing STT failed: ${output.errorMessage}');
        return const ShadowingTranscription(errorCode: 'recognition_error');
      }
      final text = output.result.fullText.trim();
      if (text.isEmpty) {
        debugPrint('⚠️ Shadowing STT returned no transcript for audible audio');
        return const ShadowingTranscription(errorCode: 'unrecognized');
      }
      debugPrint('🎤 Real STT: "$text"');
      return ShadowingTranscription(text: text);
    } catch (e) {
      debugPrint('❌ OfflineSTTService.transcribe error: $e');
      return const ShadowingTranscription(errorCode: 'recognition_error');
    }
  }

  static void dispose() {
    _facade.dispose();
    _initialized = false;
  }
}
