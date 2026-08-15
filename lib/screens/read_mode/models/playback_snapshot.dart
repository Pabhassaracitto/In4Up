import '../../../core/language/app_language.dart';

class PlaybackSnapshot {
  final int line;
  final int totalLines;
  final int pass;
  final int totalPasses;
  final int lineRepeat;
  final int totalLineRepeats;

  /// Backward-compatible name: true now means the original/source phase,
  /// not specifically English.
  final bool isEN;
  final int enRepeats;
  final int viRepeats;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  const PlaybackSnapshot({
    required this.line,
    required this.totalLines,
    required this.pass,
    required this.totalPasses,
    required this.lineRepeat,
    required this.totalLineRepeats,
    required this.isEN,
    required this.enRepeats,
    required this.viRepeats,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  bool get isSource => isEN;
  int get sourceRepeats => enRepeats;
  int get targetRepeats => viRepeats;

  AppLanguage get sourceLanguage =>
      AppLanguageCatalog.fromCode(sourceLanguageCode);
  AppLanguage get targetLanguage =>
      AppLanguageCatalog.fromCode(targetLanguageCode);
  AppLanguage get activeLanguage => isSource ? sourceLanguage : targetLanguage;

  String get statusText {
    final language = activeLanguage;
    final repeats = isSource ? sourceRepeats : targetRepeats;
    final lineText = '${line + 1}/$totalLines';
    final passText = totalPasses == 0
        ? '${pass + 1}/∞'
        : '${pass + 1}/$totalPasses';
    return '${language.flag} ${language.translationCode} ×$repeats  •  '
        'Content';
  }

  double get lineProgress =>
      totalLines > 0 ? (line + 1) / totalLines : 0.0;
}