// lib/screens/tools/venn_tab.dart
// ═══════════════════════════════════════════════════════════════
//  MAP TAB - Bản đồ từ vựng 2D
//  Nguồn: WordMapScreen từ mode3
//  Vị trí: Tools → Tab "Bản đồ"
//
//  ✅ Hiển thị từng từ dạng bubble trên bản đồ 2D
//  ✅ Trục X = Mastery (trái=yếu, phải=mạnh)
//  ✅ Trục Y = balance 3 skill
//  ✅ Tap để xem chi tiết; filter theo vùng
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/word_detail_sheet.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  MasteryZone? _filterZone;
// 'mastery' | 'understand' | 'listen' | 'read'
  WordEntry? _selectedWord;

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, prov, _) {
        if (prov.total == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Chưa có từ vựng',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Text('Lưu từ từ tab Read để xem bản đồ',
                    style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        var words = prov.allWords;
        if (_filterZone != null) {
          words = words.where((w) => w.zone == _filterZone).toList();
        }

        return Column(
          children: [
            _buildFilterBar(prov),
            Expanded(
              child: Stack(
                children: [
                  _buildMap(context, prov, words),
                  if (_selectedWord != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildWordPanel(context, prov, _selectedWord!),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(VocabularyProvider prov) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All filter
            _filterChip(null, 'Tất cả', Icons.apps, Colors.grey),
            const SizedBox(width: 6),
            // Zone filters
            ...MasteryZone.values.map((z) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _filterChip(z, z.label, z.icon, z.color),
                )),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
      MasteryZone? zone, String label, IconData icon, Color color) {
    final isSelected = _filterZone == zone;
    return GestureDetector(
      onTap: () => setState(() => _filterZone = isSelected ? null : zone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? color : Colors.grey.shade700,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(
      BuildContext context, VocabularyProvider prov, List<WordEntry> words) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight - (_selectedWord != null ? 120 : 0);
        if (h <= 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => setState(() => _selectedWord = null),
          child: Container(
            width: w,
            height: h,
            color: Colors.grey.shade50,
            child: Stack(
              children: [
                // Axis labels
                _buildAxesDecor(w, h),

                // Word bubbles
                ...words.map((word) {
                  final pos = _wordPosition(word, w, h);
                  return Positioned(
                    left: pos.dx - word.visualSize / 2,
                    top: pos.dy - word.visualSize / 2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedWord = word);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: word.visualSize,
                        height: word.visualSize,
                        decoration: BoxDecoration(
                          color: word.visualColor
                              .withAlpha((word.visualOpacity * 220).toInt()),
                          shape: BoxShape.circle,
                          border: _selectedWord?.id == word.id
                              ? Border.all(color: Colors.black, width: 2.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            word.word.length > 5
                                ? word.word.substring(0, 4)
                                : word.word,
                            style: TextStyle(
                              fontSize: (word.visualSize * 0.22).clamp(7, 11),
                              fontWeight: word.visualWeight,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Offset _wordPosition(WordEntry word, double w, double h) {
    // X = mastery (0=left/bad, 1=right/good)
    // Y = skill imbalance (0=top/unbalanced, 1=bottom/balanced)
    final x = (1 - word.mastery) * w * 0.85 + w * 0.075;

    // Y: balance between 3 skills
    final skillValues = [word.understand, word.listen, word.read];
    final avg = word.mastery;
    final variance =
        skillValues.map((v) => (v - avg) * (v - avg)).reduce((a, b) => a + b) /
            3;
    final imbalance = (variance * 10).clamp(0.0, 1.0);
    final y = imbalance * h * 0.8 + h * 0.1;

    return Offset(x, y);
  }

  Widget _buildAxesDecor(double w, double h) {
    return CustomPaint(
      size: Size(w, h),
      painter: _MapAxesPainter(),
    );
  }

  Widget _buildWordPanel(
      BuildContext context, VocabularyProvider prov, WordEntry word) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: word.zone.color,
            radius: 22,
            child: Icon(word.zone.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(word.word,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(word.meaning,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _mini('H', word.understand, const Color(0xFF42A5F5)),
                    const SizedBox(width: 6),
                    _mini('N', word.listen, const Color(0xFF66BB6A)),
                    const SizedBox(width: 6),
                    _mini('Đ', word.read, const Color(0xFFEF5350)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => WordDetailSheet(word: word),
                  );
                },
                child: const Text('Chi tiết'),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedWord = null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(width: 2),
        SizedBox(
          width: 36,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: color.withAlpha(40),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Text('${(value * 100).toInt()}%',
            style: TextStyle(fontSize: 9, color: color)),
      ],
    );
  }
}

class _MapAxesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    // Grid lines
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Axis labels
    final tp = TextPainter(textDirection: TextDirection.ltr);

    tp.text = const TextSpan(
      text: '← Cần học',
      style: TextStyle(fontSize: 10, color: Color(0x88EF5350)),
    );
    tp.layout();
    tp.paint(canvas, Offset(8, size.height - 18));

    tp.text = const TextSpan(
      text: 'Thành thạo →',
      style: TextStyle(fontSize: 10, color: Color(0x8866BB6A)),
    );
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width - 8, size.height - 18));

    tp.text = const TextSpan(
      text: 'Mất cân bằng ↑',
      style: TextStyle(fontSize: 9, color: Color(0x88FFA726)),
    );
    tp.layout();
    tp.paint(canvas, const Offset(4, 4));

    tp.text = const TextSpan(
      text: 'Cân bằng ↓',
      style: TextStyle(fontSize: 9, color: Color(0x8826C6DA)),
    );
    tp.layout();
    tp.paint(canvas, Offset(4, size.height - 34));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
