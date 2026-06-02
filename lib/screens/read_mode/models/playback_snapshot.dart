import '../../../features/translation/translation_service.dart';

class PlaybackSnapshot {
  final int line;
  final int totalLines;
  final int pass;
  final int totalPasses;
  final int lineRepeat;
  final int totalLineRepeats;
  final bool isEN;
  final int enRepeats;
  final int viRepeats;

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
  });

  String get statusText {
    final flag = TranslationService().targetLangFlag;
    final label = TranslationService().targetLangLabel;
    final lang    = isEN ? '🇬🇧 EN' : '$flag $label';
    final rep     = isEN ? enRepeats : viRepeats;
    final lineStr = '${line + 1}/$totalLines';
    final passStr = totalPasses == 0
        ? '${pass + 1}/∞'
        : '${pass + 1}/$totalPasses';
    return '$lang ×$rep  •  Câu $lineStr  •  Vòng $passStr';
  }

  double get lineProgress =>
      totalLines > 0 ? (line + 1) / totalLines : 0.0;
}
