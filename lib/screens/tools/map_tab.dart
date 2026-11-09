// Vocabulary map: mastery on X, balance of the three skills on Y.
import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/word_detail_sheet.dart';
import 'vocabulary_map_clusters.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  MasteryZone? _filterZone;
  String? _selectedWordId;

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(builder: (context, prov, _) {
      if (prov.total == 0) {
        return const Center(child: Text('Chưa có từ vựng', style: TextStyle(color: Colors.grey)));
      }
      final words = prov.allWords
          .where((word) => _filterZone == null || word.zone == _filterZone)
          .toList();
      final selected = prov.allWords.where((word) => word.id == _selectedWordId).toList();
      return Column(
        children: [
          _buildFilterBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(context.uiText('Chạm cụm để chọn từng từ'),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          Expanded(child: _buildMap(words)),
          if (selected.isNotEmpty) _buildWordPanel(selected.first),
        ],
      );
    });
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _filterChip(null, context.uiText('Tất cả'), Icons.apps, Colors.blueGrey),
          const SizedBox(width: 6),
          ...MasteryZone.values.map((zone) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _filterChip(zone, context.uiText(zone.label), zone.icon, zone.color),
              )),
        ],
      ),
    );
  }

  Widget _filterChip(MasteryZone? zone, String label, IconData icon, Color color) {
    final selected = _filterZone == zone;
    return GestureDetector(
      onTap: () => setState(() {
        _filterZone = selected ? null : zone;
        _selectedWordId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.22) : const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? color : Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: selected ? color : Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(List<WordEntry> words) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size.isEmpty) return const SizedBox.shrink();
      final clusters = clusterVocabularyMapPoints([
        for (final word in words) VocabularyMapPoint(word, vocabularyWordMapPosition(word, size)),
      ]);
      return Container(
        color: const Color(0xFF0D1526),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MapAxesPainter(
                  needsLearningLabel: context.uiText('← Cần học'),
                  masteredLabel: context.uiText('Thành thạo →'),
                  imbalancedLabel: context.uiText('Mất cân bằng ↑'),
                  balancedLabel: context.uiText('Cân bằng ↓'),
                ),
              ),
            ),
            if (words.isEmpty)
              Center(child: Text(context.uiText('Không có từ trong vùng này'),
                  style: const TextStyle(color: Colors.white70))),
            for (final cluster in clusters)
              Positioned(
                left: cluster.center.dx - cluster.diameter / 2,
                top: cluster.center.dy - cluster.diameter / 2,
                child: VocabularyClusterMarker(
                  key: ValueKey('word_map_cluster_${cluster.words.first.id}'),
                  cluster: cluster,
                  selectedWordId: _selectedWordId,
                  onTap: () => _selectCluster(cluster),
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _selectCluster(VocabularyMapCluster cluster) async {
    final word = cluster.words.length == 1
        ? cluster.words.first
        : await showVocabularyClusterSheet(context, cluster.words);
    if (mounted && word != null) setState(() => _selectedWordId = word.id);
  }

  Widget _buildWordPanel(WordEntry word) {
    return Container(
      key: const Key('word_map_selected_panel'),
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: word.zone.color, radius: 20,
              child: Icon(word.zone.icon, color: Colors.black87, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                material.Text(word.word, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                material.Text(word.meaning, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, children: [
                  _mini(context.uiText('Hiểu'), word.understand, const Color(0xFF42A5F5)),
                  _mini(context.uiText('Nghe'), word.listen, const Color(0xFF66BB6A)),
                  _mini(context.uiText('Đọc'), word.read, const Color(0xFFEF5350)),
                ]),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: context.uiText('Chi tiết'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => WordDetailSheet(word: word),
                ),
                icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
              ),
              IconButton(
                tooltip: context.uiText('Đóng'),
                onPressed: () => setState(() => _selectedWordId = null),
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, double value, Color color) => Text(
        '$label ${(value * 100).round()}%',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      );
}

class _MapAxesPainter extends CustomPainter {
  const _MapAxesPainter({
    required this.needsLearningLabel,
    required this.masteredLabel,
    required this.imbalancedLabel,
    required this.balancedLabel,
  });

  final String needsLearningLabel;
  final String masteredLabel;
  final String imbalancedLabel;
  final String balancedLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2B354C)..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(size.width * i / 4, 0), Offset(size.width * i / 4, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), paint);
    }
    void label(String value, Offset offset, Color color, {bool right = false}) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: TextStyle(fontSize: 10, color: color)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width / 2);
      painter.paint(canvas, right ? Offset(size.width - painter.width - 8, offset.dy) : offset);
    }

    label(imbalancedLabel, const Offset(8, 6), const Color(0xFFFFC170));
    label(balancedLabel, Offset(8, size.height - 34), const Color(0xFF80DEEA));
    label(needsLearningLabel, Offset(8, size.height - 18), const Color(0xFFFF8A80));
    label(masteredLabel, Offset(0, size.height - 18), const Color(0xFFA5D6A7), right: true);
  }

  @override
  bool shouldRepaint(covariant _MapAxesPainter old) =>
      old.needsLearningLabel != needsLearningLabel ||
      old.masteredLabel != masteredLabel ||
      old.imbalancedLabel != imbalancedLabel ||
      old.balancedLabel != balancedLabel;
}
