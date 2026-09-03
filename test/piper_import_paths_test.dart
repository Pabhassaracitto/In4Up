import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/piper_import_paths.dart';
import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';

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

  group('SherpaPiperTtsCore.langFromVoiceName', () {
    test('detects standard, prefixed, and community Vietnamese model names', () {
      expect(
        SherpaPiperTtsCore.langFromVoiceName('vi_VN-vais1000-medium'),
        'vi-VN',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('vits-piper-vi_VN-25hours-medium'),
        'vi-VN',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('sherpa-onnx-vits-piper-vi_VN-25hours-medium.onnx'),
        'vi-VN',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('vi_25hours-medium'),
        'vi-VN',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('vi_vais1000'),
        'vi-VN',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('vais1000'),
        'vi-VN',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('25hours'),
        'vi-VN',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('vietnamese_female'),
        'vi-VN',
      );
    });

    test('detects English and other languages correctly', () {
      expect(
        SherpaPiperTtsCore.langFromVoiceName('en_US-lessac-medium'),
        'en-US',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('vits-piper-en_US-libritts_r-medium'),
        'en-US',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('en_GB-alan-medium'),
        'en-GB',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('fr_FR-siwis-medium'),
        'fr-FR',
      );
      expect(
        SherpaPiperTtsCore.langFromVoiceName('calmwoman3688'),
        '',
      );
    });
  });
}
