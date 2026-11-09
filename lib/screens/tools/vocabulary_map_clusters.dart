import 'dart:math' as math;

import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import '../../models/word_entry.dart';

/// A plotted word keeps its true position. Only overlapping markers are grouped;
/// selecting a group exposes every word rather than hiding all but the top one.
class VocabularyMapPoint {
  const VocabularyMapPoint(this.word, this.position);

  final WordEntry word;
  final Offset position;
}

class VocabularyMapCluster {
  VocabularyMapCluster(VocabularyMapPoint point)
      : words = [point.word],
        center = point.position;

  final List<WordEntry> words;
  Offset center;

  double get diameter => words.length > 1 ? 46 : words.first.visualSize.clamp(28.0, 52.0).toDouble();

  void add(VocabularyMapCluster other) {
    final total = words.length + other.words.length;
    center = Offset(
      (center.dx * words.length + other.center.dx * other.words.length) / total,
      (center.dy * words.length + other.center.dy * other.words.length) / total,
    );
    words.addAll(other.words);
  }
}

List<VocabularyMapCluster> clusterVocabularyMapPoints(List<VocabularyMapPoint> points) {
  final clusters = <VocabularyMapCluster>[];
  for (final point in points) {
    final next = VocabularyMapCluster(point);
    // Merging can move the center; check again after each merge. A cluster
    // always represents all members and no individual entry is discarded.
    var merged = true;
    while (merged) {
      merged = false;
      for (var i = 0; i < clusters.length; i++) {
        final other = clusters[i];
        final minimumDistance = (next.diameter + other.diameter) / 2 + 4;
        if ((next.center - other.center).distance < minimumDistance) {
          next.add(other);
          clusters.removeAt(i);
          merged = true;
          break;
        }
      }
    }
    clusters.add(next);
  }
  return clusters;
}

/// X grows with mastery; Y grows downwards as the skills become more balanced.
Offset vocabularyWordMapPosition(WordEntry word, Size size) {
  final insetX = math.min(36.0, size.width / 2);
  final insetY = math.min(36.0, size.height / 2);
  final values = [word.understand, word.listen, word.read];
  final variance = values
          .map((value) => math.pow(value - word.mastery, 2))
          .reduce((a, b) => a + b) /
      3;
  // Maximum standard deviation of three scores in [0,1] is sqrt(2)/3.
  final imbalance = (math.sqrt(variance) / (math.sqrt(2) / 3)).clamp(0.0, 1.0);
  return Offset(
    insetX + word.mastery.clamp(0.0, 1.0) * math.max(0, size.width - 2 * insetX),
    insetY + (1 - imbalance) * math.max(0, size.height - 2 * insetY),
  );
}

class VocabularyClusterMarker extends StatelessWidget {
  const VocabularyClusterMarker({
    super.key,
    required this.cluster,
    required this.selectedWordId,
    required this.onTap,
  });

  final VocabularyMapCluster cluster;
  final String? selectedWordId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final multiple = cluster.words.length > 1;
    final selected = cluster.words.any((word) => word.id == selectedWordId);
    final color = multiple ? const Color(0xFF6C63FF) : cluster.words.first.visualColor;
    final foreground = color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
    return Semantics(
      button: true,
      label: multiple
          ? context.uiText('${cluster.words.length} từ trong cụm')
          : cluster.words.first.word,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cluster.diameter,
          height: cluster.diameter,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: selected ? Colors.white : color.withValues(alpha: 0.7), width: selected ? 2.5 : 1),
          ),
          child: Center(
            child: material.Text(
              multiple ? '${cluster.words.length}' : cluster.words.first.word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: multiple ? 14 : (cluster.diameter * 0.22).clamp(8, 11),
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<WordEntry?> showVocabularyClusterSheet(
  BuildContext context,
  List<WordEntry> words,
) {
  return showModalBottomSheet<WordEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF151D30),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: SizedBox(
        height: math.min(MediaQuery.sizeOf(context).height * 0.65, 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(context.uiText('${words.length} từ trong cụm'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final word = words[index];
                  return ListTile(
                    key: ValueKey('cluster_word_${word.id}'),
                    leading: Icon(word.zone.icon, color: word.zone.color),
                    title: material.Text(word.word, style: const TextStyle(color: Colors.white)),
                    subtitle: material.Text(word.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70)),
                    onTap: () => Navigator.pop(context, word),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
