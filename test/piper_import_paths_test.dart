import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/piper_import_paths.dart';

void main() {
  group('PiperImportPaths', () {
    test('detects onnx vs json vs tokens', () {
      expect(PiperImportPaths.isOnnxModelName('en_US-lessac-medium.onnx'), isTrue);
      expect(PiperImportPaths.isOnnxModelName('en_US-lessac-medium.ONNX'), isTrue);
      expect(
        PiperImportPaths.isOnnxModelName('en_US-lessac-medium.onnx.json'),
        isFalse,
      );
      expect(PiperImportPaths.isTokensName('tokens.txt'), isTrue);
      expect(
        PiperImportPaths.isTokensName('en_US-lessac-medium_tokens.txt'),
        isTrue,
      );
      expect(PiperImportPaths.isPiperArchiveName('vits-piper-x.tar.bz2'), isTrue);
      expect(PiperImportPaths.isEspeakLeafName('phontab'), isTrue);
    });

    test('normalizes Windows espeak relative paths', () {
      final sep = String.fromCharCode(92);
      expect(
        PiperImportPaths.espeakTail(
          'vits-piper-en${sep}espeak-ng-data${sep}phontab',
        ),
        'espeak-ng-data/phontab',
      );
      expect(
        PiperImportPaths.espeakTail('vits-piper-en/espeak-ng-data/phontab'),
        'espeak-ng-data/phontab',
      );
      expect(
        PiperImportPaths.posixRel('a${sep}b${sep}c'),
        'a/b/c',
      );
      expect(PiperImportPaths.espeakTail('readme.txt'), isNull);
      expect(PiperImportPaths.looksLikeEspeakRoot('espeak-ng-data'), isTrue);
    });
  });
}
