/// Pure helpers for Piper import (folder + file). Tested without Flutter IO.
class PiperImportPaths {
  static const espeakFolder = 'espeak-ng-data';

  /// ASCII backslash — Windows path separator. Avoid `'\\\\'` in Dart source
  /// (that is TWO backslashes and never matches `espeak-ng-data\phontab`).
  static final String _winSep = String.fromCharCode(92);

  static String posixRel(String rel) => rel.replaceAll(_winSep, '/');

  static bool isOnnxModelName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.onnx') && !lower.endsWith('.onnx.json');
  }

  static bool isTokensName(String name) {
    final lower = name.toLowerCase();
    return lower == 'tokens.txt' || lower.endsWith('_tokens.txt');
  }

  static bool isOnnxJsonName(String name) =>
      name.toLowerCase().endsWith('.onnx.json');

  static bool isPiperArchiveName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz');
  }

  /// Phonemizer files that live inside `espeak-ng-data/` (k2-fsa bundle).
  static bool isEspeakLeafName(String name) {
    switch (name.toLowerCase()) {
      case 'phontab':
      case 'phonindex':
      case 'phondata':
      case 'intonations':
        return true;
      default:
        return name.toLowerCase().endsWith('_dict');
    }
  }

  /// Relative path inside dest starting at `espeak-ng-data/…`, or null.
  static String? espeakTail(String relativePath) {
    final posix = posixRel(relativePath);
    final lower = posix.toLowerCase();
    const needle = '$espeakFolder/';
    final idx = lower.indexOf(needle);
    if (idx < 0) {
      if (lower == espeakFolder || lower.endsWith('/$espeakFolder')) {
        return espeakFolder;
      }
      return null;
    }
    return posix.substring(idx);
  }

  static bool looksLikeEspeakRoot(String folderName) =>
      folderName.toLowerCase() == espeakFolder;
}
