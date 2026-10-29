import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/grammar/grammar.dart';

void main() {
  final service = SentenceStructureService.instance;

  group('READ-GRAM-001 golden corpus', () {
    test('corpus.json + holdout.json: 95 case khớp các trường vàng', () {
      final failures = <String>[];
      for (final path in const [
        'tool/grammar_probe/corpus.json',
        'tool/grammar_probe/holdout.json',
      ]) {
        for (final caseData in _loadCases(path)) {
          final analysis = _analyze(service, caseData);
          final bad = _diff(caseData, analysis);
          if (bad.isNotEmpty) {
            failures.add('${caseData.id}: ${caseData.text}\n  ${bad.join('\n  ')}');
          }
        }
      }
      if (failures.isNotEmpty) {
        for (final failure in failures.take(25)) {
          print('::error file=test/sentence_structure_golden_test.dart::${_ghaEscape(failure)}');
        }
      }
      expect(
        failures,
        isEmpty,
        reason: 'Bản Dart phải giữ parity 95 case dev/holdout.\n${failures.join('\n')}',
      );
    });

    test('holdout2: không thấp hơn mốc đóng băng 17/25; known-gap registry chính xác', () {
      const knownGaps = <String>{'F01', 'F05', 'F09', 'F14', 'F15', 'F17', 'F21'};
      expect(knownGaps.length, 7);

      var correct = 0;
      final unexpected = <String>[];
      for (final caseData in _loadCases('tool/grammar_probe/holdout2.json')) {
        final analysis = _analyze(service, caseData);
        final bad = _diff(caseData, analysis);
        if (bad.isEmpty) {
          correct++;
          continue;
        }
        if (!knownGaps.contains(caseData.id)) {
          unexpected.add('${caseData.id}: ${bad.join('; ')}');
        }
      }
      if (unexpected.isNotEmpty) {
        for (final failure in unexpected.take(25)) {
          print('::error file=test/sentence_structure_golden_test.dart::holdout2 unexpected ${_ghaEscape(failure)}');
        }
      }
      expect(unexpected, isEmpty,
          reason: 'holdout2 chỉ được lệch ở known gaps A–D.');
      expect(correct, greaterThanOrEqualTo(17),
          reason: 'Mốc tổng quát hoá đóng băng là 17/25; sau quy ước hỏi đuôi là 18/25.');
    });
  });
}

_StructureCase _analyzeCase(dynamic raw) {
  final map = Map<String, dynamic>.from(raw as Map);
  return _StructureCase(
    id: map['id'] as String,
    text: map['text'] as String,
    anchor: map['anchor'] as String? ?? '',
    expectMap: Map<String, dynamic>.from(map['expect'] as Map),
  );
}

List<_StructureCase> _loadCases(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (json['cases'] as List).map(_analyzeCase).toList(growable: false);
}

StructureAnalysis _analyze(SentenceStructureService service, _StructureCase caseData) {
  final lowerText = caseData.text.toLowerCase();
  final lowerAnchor = caseData.anchor.toLowerCase();
  final index = lowerText.indexOf(lowerAnchor);
  expect(index, greaterThanOrEqualTo(0), reason: 'anchor not found: ${caseData.id}');
  return service.analyzeLine(
    caseData.text,
    anchorStart: index,
    anchorEnd: index + caseData.anchor.length,
  );
}

List<String> _diff(_StructureCase caseData, StructureAnalysis got) {
  final bad = <String>[];
  final exp = caseData.expectMap;

  if (exp.containsKey('supported')) {
    final want = exp['supported'] == true;
    if (got.supported != want) {
      bad.add('supported got=${got.supported} want=$want');
    }
  }
  if (exp.containsKey('phrase')) {
    final want = Map<String, dynamic>.from(exp['phrase'] as Map);
    final phrase = got.phrase;
    if (phrase == null) {
      bad.add('phrase got=null want=${want['kind']} ${want['span']}');
    } else {
      if (phrase.kind.wireName != want['kind']) {
        bad.add('phrase.kind got=${phrase.kind.wireName} want=${want['kind']}');
      }
      final span = phrase.textIn(got.sourceText).trim();
      if (span != want['span']) {
        bad.add('phrase.span got="$span" want="${want['span']}"');
      }
    }
  }
  if (exp.containsKey('outer')) {
    final want = Map<String, dynamic>.from(exp['outer'] as Map);
    final outer = got.outer;
    if (outer == null) {
      bad.add('outer got=null want=${want['kind']} ${want['span']}');
    } else {
      if (want.containsKey('kind') && outer.kind.wireName != want['kind']) {
        bad.add('outer.kind got=${outer.kind.wireName} want=${want['kind']}');
      }
      final span = outer.textIn(got.sourceText).trim();
      if (span != want['span']) {
        bad.add('outer.span got="$span" want="${want['span']}"');
      }
    }
  }
  if (exp.containsKey('sentence')) {
    final want = Map<String, dynamic>.from(exp['sentence'] as Map);
    final sentence = got.sentence;
    if (sentence == null) {
      bad.add('sentence got=null want=$want');
    } else {
      for (final entry in want.entries) {
        final have = _sentenceField(sentence, entry.key);
        if (have != entry.value) {
          bad.add('sentence.${entry.key} got=$have want=${entry.value}');
        }
      }
    }
  }
  if (exp.containsKey('clause_role')) {
    final have = got.clauseRole?.wireName;
    if (have != exp['clause_role']) {
      bad.add('clause_role got=$have want=${exp['clause_role']}');
    }
  }
  if (exp.containsKey('conditional')) {
    if (got.conditionalType != exp['conditional']) {
      bad.add('conditional got=${got.conditionalType} want=${exp['conditional']}');
    }
  }
  if (exp.containsKey('sentence_span')) {
    if (got.sentenceSpanText.trim() != exp['sentence_span']) {
      bad.add('sentence_span got="${got.sentenceSpanText.trim()}" want="${exp['sentence_span']}"');
    }
  }
  return bad;
}

String _ghaEscape(String value) => value
    .replaceAll('%', '%25')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A')
    .replaceAll(':', '%3A');

String? _sentenceField(SentenceStructure sentence, String key) {
  switch (key) {
    case 'type':
      return sentence.type.wireName;
    case 'question':
      return sentence.question.wireName;
    case 'polarity':
      return sentence.polarity.wireName;
    case 'tense':
      return sentence.tense.wireName;
    case 'aspect':
      return sentence.aspect.wireName;
    case 'voice':
      return sentence.voice.wireName;
    case 'pattern':
      return sentence.pattern;
  }
  return null;
}

class _StructureCase {
  final String id;
  final String text;
  final String anchor;
  final Map<String, dynamic> expectMap;

  const _StructureCase({
    required this.id,
    required this.text,
    required this.anchor,
    required this.expectMap,
  });
}
