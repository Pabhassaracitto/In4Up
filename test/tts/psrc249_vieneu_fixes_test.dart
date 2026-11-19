import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/vieneu_model_files.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PSRC-249 VieNeu fixes', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('psrc249_test_');
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('findVieneuVoiceFolders scans recursively to find nested TXT voice',
        () async {
      final voiceDir = Directory(p.join(tmp.path, 'bundle', 'voices', 'Minh'));
      await voiceDir.create(recursive: true);
      await File(p.join(voiceDir.path, 'ref_codes.txt'))
          .writeAsString('1 2 3 4 5\n');
      await File(p.join(voiceDir.path, 'speaker.emb.txt'))
          .writeAsString('${List.filled(192, '0.1').join(' ')}\n');

      final found = await findVieneuVoiceFolders(tmp);
      expect(found.map((d) => p.basename(d.path)).toList(), ['Minh']);
    });

    test('describeVieneuFolderContents lists files and subdirs for diagnostics',
        () async {
      await File(p.join(tmp.path, 'notes.txt')).writeAsString('hi');
      await Directory(p.join(tmp.path, 'empty_sub')).create();

      final desc = await describeVieneuFolderContents(tmp);
      expect(desc, contains('notes.txt'));
      expect(desc, contains('empty_sub'));
    });

    test('resolveVieneuVoiceFiles marks WAV-only as isVoice=true', () async {
      final wavDir = Directory(p.join(tmp.path, 'wav_voice'));
      await wavDir.create(recursive: true);
      await File(p.join(wavDir.path, 'sample.wav'))
          .writeAsBytes(List<int>.filled(64, 0));

      final resolved = await resolveVieneuVoiceFiles(wavDir);
      expect(resolved.isVoice, isTrue);
      expect(resolved.samplePath, isNotNull);
    });

    test('engine and service contracts include PSRC-249 fixes', () {
      final engineSrc =
          File('lib/features/tts/engines/vieneu_tts_engine.dart')
              .readAsStringSync();
      expect(engineSrc, contains('if (!resolved.isVoice) continue;'));
      expect(engineSrc, contains('for (final candidate in VieneuModelVariant.values)'));

      final serviceSrc =
          File('lib/features/tts/tts_service.dart').readAsStringSync();
      expect(serviceSrc, contains('_lastVieneuFallbackReason'));
      expect(serviceSrc, contains("p.basename(file.path).toLowerCase() == 'sea_g2p.bin'"));
      expect(serviceSrc, contains('describeVieneuFolderContents(chosen)'));
    });
  });
}
