import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';
import 'package:in4up_stt/stt_engine_sherpa.dart';

void main() {
  group('Sherpa PCM Conversion Tests', () {
    test('pcm16ToFloat32 converts silence correctly', () {
      // 4 samples of silence (16-bit 0)
      final pcmBytes = Uint8List(8);
      final floats = pcm16ToFloat32(pcmBytes);

      expect(floats.length, 4);
      for (final s in floats) {
        expect(s, closeTo(0.0, 0.0001));
      }
    });

    test('pcm16ToFloat32 converts full-scale amplitudes correctly', () {
      // 2 samples: +32767, -32768 in little endian
      final pcmBytes = Uint8List(4);
      final bd = ByteData.sublistView(pcmBytes);
      bd.setInt16(0, 32767, Endian.little);
      bd.setInt16(2, -32768, Endian.little);

      final floats = pcm16ToFloat32(pcmBytes);
      expect(floats.length, 2);
      expect(floats[0], closeTo(32767 / 32768.0, 0.0001));
      expect(floats[1], closeTo(-1.0, 0.0001));
    });

    test('pcm16ToFloat32 handles empty byte list gracefully', () {
      final floats = pcm16ToFloat32([]);
      expect(floats.length, 0);
    });
  });

  group('Sherpa Model Paths & Profiles Tests', () {
    test('SherpaModelPaths fromOptions creates valid config', () {
      final options = {
        'sherpaModels': {
          'encoder': '/path/to/encoder.onnx',
          'decoder': '/path/to/decoder.onnx',
          'joiner': '/path/to/joiner.onnx',
          'tokens': '/path/to/tokens.txt',
          'numThreads': 4,
          'isStreaming': true,
        }
      };

      final paths = SherpaModelPaths.fromOptions(options);
      expect(paths, isNotNull);
      expect(paths!.encoder, '/path/to/encoder.onnx');
      expect(paths.decoder, '/path/to/decoder.onnx');
      expect(paths.joiner, '/path/to/joiner.onnx');
      expect(paths.tokens, '/path/to/tokens.txt');
      expect(paths.numThreads, 4);
      expect(paths.isStreaming, isTrue);
    });

    test('SherpaModelPaths returns null on incomplete options', () {
      final options = {
        'sherpaModels': {
          'encoder': '/path/to/encoder.onnx',
          // missing decoder, joiner, tokens
        }
      };

      final paths = SherpaModelPaths.fromOptions(options);
      expect(paths, isNull);
    });

    test('Predefined ASR profiles contain VI and EN configurations', () {
      final profiles = SherpaModelManager.predefinedAsrProfiles;
      expect(profiles.length, 2);

      final vi = profiles.firstWhere((p) => p.language == 'vi');
      expect(vi.id, 'asr-vi-30M-int8');
      expect(vi.isStreaming, isFalse);
      expect(vi.approxSizeMB, 32);
      expect(vi.downloadUrl, contains('zipformer-vi-30M-int8'));

      final en = profiles.firstWhere((p) => p.language == 'en');
      expect(en.id, 'asr-en-20M-streaming-int8');
      expect(en.isStreaming, isTrue);
      expect(en.approxSizeMB, 20);
      expect(en.downloadUrl, contains('streaming-zipformer-en-20M'));
    });

    test('SherpaAsrInfo state management', () {
      final asrInfo = SherpaAsrInfo(
        profileStates: {
          'asr-vi-30M-int8': const SherpaModelInfo(
            status: SherpaModelStatus.ready,
            localPath: '/data/models/vi',
          ),
          'asr-en-20M-streaming-int8': const SherpaModelInfo(
            status: SherpaModelStatus.downloading,
            downloadProgress: 0.45,
          ),
        },
      );

      expect(asrInfo.isReady('asr-vi-30M-int8'), isTrue);
      expect(asrInfo.stateFor('asr-vi-30M-int8').localPath, '/data/models/vi');

      expect(asrInfo.isReady('asr-en-20M-streaming-int8'), isFalse);
      expect(asrInfo.stateFor('asr-en-20M-streaming-int8').isDownloading, isTrue);
      expect(asrInfo.stateFor('asr-en-20M-streaming-int8').downloadProgress, 0.45);

      expect(asrInfo.isReady('unknown_profile'), isFalse);
    });
  });

  group('SttResult isFinal compatibility tests', () {
    test('SttResult defaults isFinal to true', () {
      final res = SttResult(
        fullText: 'Test text',
        segments: const [],
        engineUsed: SttEngineType.sherpa,
        language: 'en',
        processingTime: Duration.zero,
        audioFingerprint: '',
      );

      expect(res.isFinal, isTrue);
      expect(res.fullText, 'Test text');
    });

    test('SttResult supports partial results with isFinal false', () {
      final res = SttResult(
        fullText: 'Partial speech',
        segments: const [],
        engineUsed: SttEngineType.sherpa,
        language: 'vi',
        processingTime: Duration.zero,
        audioFingerprint: '',
        isFinal: false,
      );

      expect(res.isFinal, isFalse);
      expect(res.fullText, 'Partial speech');
    });
  });
}
