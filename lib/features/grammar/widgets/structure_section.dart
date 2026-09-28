import 'package:in4up/core/language/localized_material.dart';

import '../models/phrase_info.dart';
import '../models/sentence_structure.dart';
import '../models/structure_analysis.dart';
import '../services/sentence_structure_service.dart';

class StructureSection extends StatelessWidget {
  final String lineText;
  final int anchorStart;
  final int anchorEnd;
  final SentenceStructureService? service;

  const StructureSection({
    super.key,
    required this.lineText,
    required this.anchorStart,
    required this.anchorEnd,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    if (anchorStart < 0 || anchorEnd <= anchorStart || lineText.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final analysis = (service ?? SentenceStructureService.instance).analyzeLine(
      lineText,
      anchorStart: anchorStart,
      anchorEnd: anchorEnd,
    );
    if (analysis.notes.contains('anchor_not_found')) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7E57C2).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7E57C2).withValues(alpha: 0.22),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: const Color(0xFFB39DDB),
          collapsedIconColor: const Color(0xFFB39DDB),
          leading: const Icon(
            Icons.account_tree_outlined,
            color: Color(0xFFB39DDB),
            size: 18,
          ),
          title: Text(
            context.uiText('Cấu trúc câu'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: _subtitle(context, analysis),
          children: [_body(context, analysis)],
        ),
      ),
    );
  }

  Widget? _subtitle(BuildContext context, StructureAnalysis analysis) {
    if (!analysis.supported) {
      return Text(
        context.uiText('Chưa hỗ trợ phân tích cấu trúc cho ngôn ngữ này'),
        style: TextStyle(color: Colors.grey[500], fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final parts = <String>[];
    if (analysis.phrase != null) parts.add(analysis.phrase!.kind.wireName);
    if (analysis.sentence?.pattern != null) parts.add(analysis.sentence!.pattern!);
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: TextStyle(color: Colors.grey[500], fontSize: 11),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _body(BuildContext context, StructureAnalysis analysis) {
    if (!analysis.supported) {
      return _Notice(
        icon: Icons.language_outlined,
        text: context.uiText('Chưa hỗ trợ phân tích cấu trúc cho ngôn ngữ này'),
      );
    }

    final rows = <Widget>[];
    if (analysis.phrase != null) {
      rows.add(_PhraseRow(
        label: context.uiText('Cụm từ'),
        phrase: analysis.phrase!,
        sourceText: analysis.sourceText,
      ));
    }
    if (analysis.outer != null) {
      rows.add(_PhraseRow(
        label: context.uiText('Cụm rộng hơn'),
        phrase: analysis.outer!,
        sourceText: analysis.sourceText,
      ));
    }

    final sentence = analysis.sentence;
    final showSentence = sentence != null && sentence.confidence >= 0.6;
    if (showSentence && sentence.pattern != null) {
      rows.add(_ValueRow(
        label: context.uiText('Công thức câu'),
        child: _ChipText(_formatPattern(sentence.pattern!)),
      ));
    }
    if (showSentence) {
      rows.add(_ValueRow(
        label: context.uiText('Câu'),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _sentenceChips(context, sentence),
        ),
      ));
    }
    if (analysis.clauseRole != null) {
      rows.add(_ValueRow(
        label: context.uiText('Mệnh đề'),
        child: _ChipText(context.uiText(analysis.clauseRole!.labelKey)),
      ));
    }
    if (analysis.conditionalType != null) {
      rows.add(_ValueRow(
        label: context.uiText('Câu điều kiện'),
        child: _ChipText('Type ${analysis.conditionalType}'),
      ));
    }
    if (analysis.hasLineContinuationNote) {
      rows.add(_Notice(
        icon: Icons.keyboard_double_arrow_down,
        text: context.uiText('Câu có thể tiếp tục ở dòng dưới'),
      ));
    }
    if (rows.isEmpty) {
      rows.add(_Notice(
        icon: Icons.info_outline,
        text: context.uiText('Chưa đủ tin cậy để phân tích'),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
      ],
    );
  }

  List<Widget> _sentenceChips(BuildContext context, SentenceStructure sentence) {
    final chips = <Widget>[];
    if (sentence.polarity == Polarity.negative) {
      chips.add(_ChipText(context.uiText(sentence.polarity.labelKey)));
    } else {
      chips.add(_ChipText(context.uiText(sentence.type.labelKey)));
    }
    if (sentence.question != QuestionKind.none) {
      chips.add(_ChipText(context.uiText(sentence.question.labelKey)));
    }
    if (sentence.tense != Tense.none) {
      chips.add(_ChipText(context.uiText(sentence.tense.labelKey)));
      chips.add(_ChipText(context.uiText(sentence.aspect.labelKey)));
      chips.add(_ChipText(context.uiText(sentence.voice.labelKey)));
    }
    if (sentence.modal != null && sentence.tense == Tense.modal) {
      chips.add(_ChipText(sentence.modal!));
    }
    return chips;
  }

  String _formatPattern(String pattern) {
    if (pattern.contains('+')) return pattern;
    if (pattern == 'IT-CLEFT') return pattern;
    if (pattern == 'There+V+S') return pattern;
    return pattern.split('').join(' + ');
  }
}

class _PhraseRow extends StatelessWidget {
  final String label;
  final PhraseInfo phrase;
  final String sourceText;

  const _PhraseRow({
    required this.label,
    required this.phrase,
    required this.sourceText,
  });

  @override
  Widget build(BuildContext context) {
    final span = phrase.textIn(sourceText).trim();
    return _ValueRow(
      label: label,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ChipText(context.uiText(phrase.kind.labelKey)),
          Text(
            '“$span”',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _ValueRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _ChipText extends StatelessWidget {
  final String text;

  const _ChipText(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFB39DDB).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFB39DDB).withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD1C4E9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[500], size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}
