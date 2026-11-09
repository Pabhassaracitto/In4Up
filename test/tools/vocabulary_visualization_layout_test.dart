import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/screens/tools/vocabulary_map_clusters.dart';
import 'package:in4up/screens/tools/word_list/knowledge_graph_layout.dart';

WordEntry word(String id, {
  double understand = 0,
  double listen = 0,
  double read = 0,
  List<String>? children,
  List<String>? parents,
  VocabularyType type = VocabularyType.word,
}) => WordEntry(
  id: id,
  word: id,
  meaning: id,
  understand: understand,
  listen: listen,
  read: read,
  childIds: children,
  parentIds: parents,
  vocabType: type,
);

void main() {
  group('Knowledge Graph layout', () {
    test('disconnected entries, multi-parent links and cycles all remain visible', () {
      final words = [
        word('a', children: ['b', 'c']),
        word('b', children: ['d']),
        word('c', children: ['d']),
        word('d', children: ['b']), // cycle and multiple parents
        word('e', parents: ['a']), // old one-sided parent relation
        for (var i = 0; i < 85; i++) word('isolated$i', type: VocabularyType.paragraph),
      ];
      final ordered = KnowledgeGraphLayout.orderByConnections(words);
      expect(ordered.map((w) => w.id).toSet(), words.map((w) => w.id).toSet());
      for (final arrangement in KnowledgeGraphArrangement.values) {
        final layout = KnowledgeGraphLayout.build(ordered, arrangement: arrangement);
        expect(layout.centers.length, words.length);
        expect(layout.links.map((edge) => '${edge.from}>${edge.to}').toSet(),
            containsAll(['a>b', 'a>c', 'b>d', 'c>d', 'd>b', 'a>e']));
        for (var i = 0; i < words.length; i++) {
          final first = layout.centers[words[i].id]!;
          expect(first.dx, greaterThan(0));
          expect(first.dy, greaterThan(0));
          expect(first.dx, lessThan(layout.size.width));
          expect(first.dy, lessThan(layout.size.height));
          for (var j = i + 1; j < words.length; j++) {
            final second = layout.centers[words[j].id]!;
            final minimum = (knowledgeGraphNodeSize(words[i]) + knowledgeGraphNodeSize(words[j])) / 2;
            expect((first - second).distance, greaterThanOrEqualTo(minimum),
                reason: '${words[i].id} overlaps ${words[j].id}');
          }
        }
      }
    });

    test('reciprocal stored links are drawn only once and missing links are ignored', () {
      final layout = KnowledgeGraphLayout.build([
        word('a', children: ['b', 'missing', 'a']),
        word('b', parents: ['a']),
      ]);
      expect(layout.links, hasLength(1));
      expect(layout.links.single.from, 'a');
      expect(layout.links.single.to, 'b');
    });
  });

  group('Word map', () {
    test('stronger is right; balanced is lower than unbalanced', () {
      const size = Size(400, 400);
      final weak = vocabularyWordMapPosition(word('weak', understand: .1, listen: .1, read: .1), size);
      final strong = vocabularyWordMapPosition(word('strong', understand: .9, listen: .9, read: .9), size);
      final unbalanced = vocabularyWordMapPosition(word('unbalanced', understand: 1), size);
      final balanced = vocabularyWordMapPosition(word('balanced', understand: 1 / 3, listen: 1 / 3, read: 1 / 3), size);
      expect(weak.dx, lessThan(strong.dx));
      expect(unbalanced.dy, lessThan(balanced.dy));
      expect(unbalanced.dx, closeTo(balanced.dx, .001));
    });

    test('overlapping markers form an accessible group without losing words', () {
      final points = [
        for (var i = 0; i < 20; i++) VocabularyMapPoint(word('same$i'), const Offset(100, 100)),
        VocabularyMapPoint(word('other'), const Offset(250, 250)),
      ];
      final clusters = clusterVocabularyMapPoints(points);
      expect(clusters, hasLength(2));
      expect(clusters.expand((cluster) => cluster.words).map((w) => w.id).toSet(),
          points.map((point) => point.word.id).toSet());
      expect(clusters.map((cluster) => cluster.words.length).reduce(math.max), 20);
      final distance = (clusters.first.center - clusters.last.center).distance;
      expect(distance, greaterThanOrEqualTo((clusters.first.diameter + clusters.last.diameter) / 2));
    });
  });
}
