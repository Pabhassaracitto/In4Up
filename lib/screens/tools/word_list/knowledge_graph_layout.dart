import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../models/vocabulary_type.dart';
import '../../../models/word_entry.dart';

/// The graph is laid out in fixed-size cells. This keeps disconnected nodes,
/// cycles and nodes with multiple parents visible without overlapping them.
enum KnowledgeGraphArrangement { connected, force, layered, grid }

class KnowledgeGraphLink {
  const KnowledgeGraphLink(this.from, this.to);

  final String from;
  final String to;
}

class KnowledgeGraphLayout {
  const KnowledgeGraphLayout({
    required this.centers,
    required this.links,
    required this.size,
  });

  final Map<String, Offset> centers;
  final List<KnowledgeGraphLink> links;
  final Size size;

  static const double cellSize = 150;
  static const double padding = 24;
  static const int columns = 6;

  /// Places related entries close together before splitting a large graph into
  /// pages. Neither the page limit nor a filter changes the stored relations.
  static List<WordEntry> orderByConnections(List<WordEntry> words) {
    final byId = {for (final word in words) word.id: word};
    final neighbours = {for (final word in words) word.id: <String>{}};
    for (final link in _links(words, byId.keys.toSet())) {
      neighbours[link.from]!.add(link.to);
      neighbours[link.to]!.add(link.from);
    }
    final visited = <String>{};
    final ordered = <WordEntry>[];
    for (final word in words) {
      if (!visited.add(word.id)) continue;
      final pending = Queue<String>()..add(word.id);
      while (pending.isNotEmpty) {
        final id = pending.removeFirst();
        ordered.add(byId[id]!);
        for (final neighbour in neighbours[id]!) {
          if (visited.add(neighbour)) pending.add(neighbour);
        }
      }
    }
    return ordered;
  }

  factory KnowledgeGraphLayout.build(
    List<WordEntry> words, {
    KnowledgeGraphArrangement arrangement = KnowledgeGraphArrangement.connected,
  }) {
    if (words.isEmpty) {
      return const KnowledgeGraphLayout(
        centers: {},
        links: [],
        size: Size.zero,
      );
    }
    final ids = words.map((word) => word.id).toSet();
    final links = _links(words, ids);
    final centers = <String, Offset>{};

    if (arrangement == KnowledgeGraphArrangement.force) {
      return _forceLayout(words, links);
    }

    if (arrangement == KnowledgeGraphArrangement.grid) {
      final usedColumns = math.min(columns, words.length);
      final rows = (words.length / columns).ceil();
      for (var i = 0; i < words.length; i++) {
        centers[words[i].id] = Offset(
          padding + (i % columns + 0.5) * cellSize,
          padding + (i ~/ columns + 0.5) * cellSize,
        );
      }
      return KnowledgeGraphLayout(
        centers: centers,
        links: links,
        size: Size(usedColumns * cellSize + padding * 2,
            rows * cellSize + padding * 2),
      );
    }

    final neighbours = {for (final id in ids) id: <String>{}};
    final children = {for (final id in ids) id: <String>{}};
    final incoming = {for (final id in ids) id: 0};
    for (final link in links) {
      neighbours[link.from]!.add(link.to);
      neighbours[link.to]!.add(link.from);
      children[link.from]!.add(link.to);
      incoming[link.to] = incoming[link.to]! + 1;
    }

    if (arrangement == KnowledgeGraphArrangement.layered) {
      final depths = <String, int>{};
      void walk(String root) {
        if (depths.containsKey(root)) return;
        depths[root] = 0;
        final queue = Queue<String>()..add(root);
        while (queue.isNotEmpty) {
          final id = queue.removeFirst();
          for (final child in children[id]!) {
            if (!depths.containsKey(child)) {
              depths[child] = depths[id]! + 1;
              queue.add(child);
            }
          }
        }
      }

      for (final word in words.where((word) => incoming[word.id] == 0)) {
        walk(word.id);
      }
      for (final word in words) {
        walk(word.id);
      }
      final layers = <int, List<String>>{};
      for (final word in words) {
        layers.putIfAbsent(depths[word.id]!, () => <String>[]).add(word.id);
      }
      final usedColumns = math.min(columns, layers.values.map((layer) => layer.length).reduce(math.max));
      var row = 0;
      final layerKeys = layers.keys.toList()..sort();
      for (final depth in layerKeys) {
        final layer = layers[depth]!;
        for (var start = 0; start < layer.length; start += columns) {
          final count = math.min(columns, layer.length - start);
          final inset = (usedColumns - count) / 2;
          for (var i = 0; i < count; i++) {
            centers[layer[start + i]] = Offset(
              padding + (inset + i + 0.5) * cellSize,
              padding + (row + 0.5) * cellSize,
            );
          }
          row++;
        }
      }
      return KnowledgeGraphLayout(
        centers: centers,
        links: links,
        size: Size(usedColumns * cellSize + padding * 2, row * cellSize + padding * 2),
      );
    }

    final visited = <String>{};
    var shelfX = 0;
    var shelfY = 0;
    var shelfHeight = 0;
    var usedWidth = 0;

    for (final word in words) {
      if (!visited.add(word.id)) continue;
      final component = <String>[];
      final pending = Queue<String>()..add(word.id);
      while (pending.isNotEmpty) {
        final id = pending.removeFirst();
        component.add(id);
        for (final next in neighbours[id]!) {
          if (visited.add(next)) pending.add(next);
        }
      }

      // Use all roots when a component is a DAG; seed any unvisited cycle so
      // malformed or circular links cannot hide a word or loop forever.
      final depths = <String, int>{};
      final roots = component.where((id) => incoming[id] == 0).toList();
      if (roots.isEmpty) roots.add(component.first);
      void walk(String root) {
        if (depths.containsKey(root)) return;
        depths[root] = 0;
        final queue = Queue<String>()..add(root);
        while (queue.isNotEmpty) {
          final id = queue.removeFirst();
          for (final child in children[id]!) {
            if (!depths.containsKey(child)) {
              depths[child] = depths[id]! + 1;
              queue.add(child);
            }
          }
        }
      }

      for (final root in roots) {
        walk(root);
      }
      for (final id in component) {
        walk(id);
      }
      final layers = <int, List<String>>{};
      for (final id in component) {
        layers.putIfAbsent(depths[id]!, () => <String>[]).add(id);
      }
      final layerKeys = layers.keys.toList()..sort();
      final componentColumns = math.min(
        columns,
        layers.values.map((layer) => layer.length).reduce(math.max),
      );
      final componentRows = layers.values
          .map((layer) => (layer.length / columns).ceil())
          .reduce((a, b) => a + b);

      if (shelfX + componentColumns > columns) {
        shelfY += shelfHeight;
        shelfX = 0;
        shelfHeight = 0;
      }
      var row = 0;
      for (final depth in layerKeys) {
        final layer = layers[depth]!;
        for (var start = 0; start < layer.length; start += columns) {
          final count = math.min(columns, layer.length - start);
          final inset = (componentColumns - count) / 2;
          for (var i = 0; i < count; i++) {
            centers[layer[start + i]] = Offset(
              padding + (shelfX + inset + i + 0.5) * cellSize,
              padding + (shelfY + row + 0.5) * cellSize,
            );
          }
          row++;
        }
      }
      shelfX += componentColumns;
      usedWidth = math.max(usedWidth, shelfX);
      shelfHeight = math.max(shelfHeight, componentRows);
    }
    return KnowledgeGraphLayout(
      centers: centers,
      links: links,
      size: Size(usedWidth * cellSize + padding * 2,
          (shelfY + shelfHeight) * cellSize + padding * 2),
    );
  }

  /// A small deterministic force simulation followed by collision-free cell
  /// snapping. Connected nodes attract, all nodes repel, and even a graph of
  /// isolated entries has distinct accessible targets. Work is bounded by the
  /// screen's page size rather than the size of the user's vocabulary.
  static KnowledgeGraphLayout _forceLayout(List<WordEntry> words, List<KnowledgeGraphLink> links) {
    final count = words.length;
    final usedColumns = math.min(columns, count);
    final rows = (count / columns).ceil();
    final width = usedColumns * cellSize;
    final height = rows * cellSize;
    final positions = List<Offset>.generate(count, (i) => Offset(
      (i % columns + 0.5) * cellSize,
      (i ~/ columns + 0.5) * cellSize,
    ));
    final indexes = {for (var i = 0; i < count; i++) words[i].id: i};
    final degrees = List<int>.filled(count, 0);
    for (final link in links) {
      degrees[indexes[link.from]!]++;
      degrees[indexes[link.to]!]++;
    }
    const optimal = cellSize;
    for (var iteration = 0; iteration < 55; iteration++) {
      final forces = List<Offset>.filled(count, Offset.zero);
      for (var i = 0; i < count; i++) {
        for (var j = i + 1; j < count; j++) {
          var delta = positions[i] - positions[j];
          if (delta.distance < 0.01) delta = Offset(i.isEven ? 1 : -1, 1);
          final distance = delta.distance;
          final force = delta / distance * (optimal * optimal / distance);
          forces[i] += force;
          forces[j] -= force;
        }
      }
      for (final link in links) {
        final from = indexes[link.from]!;
        final to = indexes[link.to]!;
        final delta = positions[from] - positions[to];
        final distance = math.max(0.01, delta.distance);
        final force = delta / distance * (distance * distance / optimal * 0.25);
        forces[from] -= force;
        forces[to] += force;
      }
      final temperature = 28.0 * (1 - iteration / 55);
      for (var i = 0; i < count; i++) {
        final distance = forces[i].distance;
        if (distance == 0) continue;
        final proposed = positions[i] + forces[i] / distance * math.min(distance, temperature);
        positions[i] = Offset(
          proposed.dx.clamp(cellSize / 2, width - cellSize / 2).toDouble(),
          proposed.dy.clamp(cellSize / 2, height - cellSize / 2).toDouble(),
        );
      }
    }
    final slots = <Offset>[
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < usedColumns; col++)
          Offset((col + 0.5) * cellSize, (row + 0.5) * cellSize),
    ];
    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) {
        final byDegree = degrees[b].compareTo(degrees[a]);
        return byDegree != 0 ? byDegree : a.compareTo(b);
      });
    final centers = <String, Offset>{};
    for (final i in order) {
      var best = 0;
      var bestDistance = double.infinity;
      for (var slot = 0; slot < slots.length; slot++) {
        final distance = (positions[i] - slots[slot]).distanceSquared;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = slot;
        }
      }
      centers[words[i].id] = slots.removeAt(best) + const Offset(padding, padding);
    }
    return KnowledgeGraphLayout(
      centers: centers,
      links: links,
      size: Size(width + padding * 2, height + padding * 2),
    );
  }

  static List<KnowledgeGraphLink> _links(List<WordEntry> words, Set<String> ids) {
    final seen = <(String, String)>{};
    final result = <KnowledgeGraphLink>[];
    void add(String from, String to) {
      if (from == to || !ids.contains(from) || !ids.contains(to)) return;
      if (seen.add((from, to))) result.add(KnowledgeGraphLink(from, to));
    }

    for (final word in words) {
      for (final child in word.childIds) {
        add(word.id, child);
      }
      // Old data may only have one side of the relationship.
      for (final parent in word.parentIds) {
        add(parent, word.id);
      }
    }
    return result;
  }
}

double knowledgeGraphNodeSize(WordEntry word) {
  final base = switch (word.vocabType) {
    VocabularyType.paragraph => 105.0,
    VocabularyType.sentence => 90.0,
    VocabularyType.phrase => 75.0,
    VocabularyType.word => 60.0,
  };
  return base + (word.encounterCount * 2).clamp(0, 20);
}
