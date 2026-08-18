//lib/screens/tools/venn_tab.dart
//═══════════════════════════════════════════════════════════════
//  VENN TAB - Biểu đồ Venn 3 chiều kỹ năng
//  Nguồn: VennScreen từ mode3
//  Vị trí: Tools → Tab "Venn"
//
//  ✅ Hiển thị 8 vùng mastery (blindSpot, understandOnly, ...)
//  ✅ Drag & Drop từ giữa các vùng
//  ✅ Tap vùng để xem danh sách từ trong vùng đó
// ═══════════════════════════════════════════════════════════════

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/word_detail_sheet.dart';

class VennTab extends StatefulWidget {
  const VennTab({super.key});

  @override
  State<VennTab> createState() => _VennTabState();
}

class _VennTabState extends State<VennTab> {
  MasteryZone? _hoveredZone;
  MasteryZone? _selectedZone;

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, prov, _) {
        if (prov.total == 0) {
          return _buildEmptyState(context);
        }

        final zones = prov.wordsByZone;
        final counts = {
          for (final z in MasteryZone.values) z: zones[z]?.length ?? 0,
        };

        return Column(
          children: [
            // Venn diagram với drop targets
            Expanded(flex: 5, child: _buildVennDiagram(prov, counts)),

            // Word list (draggable)
            Expanded(flex: 4, child: _buildWordList(prov, zones)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Chưa có từ vựng',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Lưu từ từ tab Read để phân tích',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildVennDiagram(
    VocabularyProvider prov,
    Map<MasteryZone, int> counts,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final size =
            box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight;
        final radius = size * 0.25;
        final center = Offset(box.maxWidth / 2, size / 2 + 20);
        final offset = radius * 0.7;

        final cU = Offset(center.dx, center.dy - offset * 0.7);
        final cL = Offset(center.dx - offset * 0.87, center.dy + offset * 0.5);
        final cR = Offset(center.dx + offset * 0.87, center.dy + offset * 0.5);

        return Container(
          color: Colors.grey.shade50,
          child: Stack(
            children: [
              _vennCircle(cU, radius, const Color(0xFF42A5F5), 'HIỂU',
                  MasteryZone.understandOnly, prov, counts),
              _vennCircle(cL, radius, const Color(0xFF66BB6A), 'NGHE',
                  MasteryZone.listenOnly, prov, counts),
              _vennCircle(cR, radius, const Color(0xFFEF5350), 'ĐỌC',
                  MasteryZone.readOnly, prov, counts),

              // Intersection zones
              _intersectionZone(
                Offset((cU.dx + cL.dx) / 2, (cU.dy + cL.dy) / 2),
                MasteryZone.understandListen,
                'H+N',
                const Color(0xFF26C6DA),
                counts,
                prov,
              ),
              _intersectionZone(
                Offset((cU.dx + cR.dx) / 2, (cU.dy + cR.dy) / 2),
                MasteryZone.understandRead,
                'H+Đ',
                const Color(0xFFAB47BC),
                counts,
                prov,
              ),
              _intersectionZone(
                Offset((cL.dx + cR.dx) / 2, (cL.dy + cR.dy) / 2 + 10),
                MasteryZone.listenRead,
                'N+Đ',
                const Color(0xFFFFA726),
                counts,
                prov,
              ),

              _centerZone(center, counts[MasteryZone.mastered]!, prov),

              Positioned(
                right: 16,
                top: 16,
                child: _blindSpotTarget(prov, counts[MasteryZone.blindSpot]!),
              ),

              Positioned(left: 16, bottom: 16, child: _buildLegend()),

              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '👆 Tap vùng để xem từ  ·  ↕️ Kéo từ để phân loại',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vennCircle(
    Offset center,
    double radius,
    Color color,
    String label,
    MasteryZone zone,
    VocabularyProvider prov,
    Map<MasteryZone, int> counts,
  ) {
    final isHovered = _hoveredZone == zone;
    final isSelected = _selectedZone == zone;

    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          setState(() => _hoveredZone = zone);
          return true;
        },
        onLeave: (_) => setState(() => _hoveredZone = null),
        onAcceptWithDetails: (details) {
          prov.setWordZone(details.data, zone);
          setState(() => _hoveredZone = null);
        },
        builder: (context, candidateData, rejectedData) {
          return GestureDetector(
            onTap: () => setState(() {
              _selectedZone = _selectedZone == zone ? null : zone;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(isHovered ? 80 : (isSelected ? 60 : 30)),
                border: Border.all(
                  color: color.withAlpha(isHovered || isSelected ? 255 : 150),
                  width: isHovered || isSelected ? 3 : 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${counts[zone] ?? 0}',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _intersectionZone(
    Offset center,
    MasteryZone zone,
    String label,
    Color color,
    Map<MasteryZone, int> counts,
    VocabularyProvider prov,
  ) {
    final count = counts[zone] ?? 0;
    final isSelected = _selectedZone == zone;

    return Positioned(
      left: center.dx - 22,
      top: center.dy - 22,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) {
          setState(() => _hoveredZone = zone);
          return true;
        },
        onLeave: (_) => setState(() => _hoveredZone = null),
        onAcceptWithDetails: (d) {
          prov.setWordZone(d.data, zone);
          setState(() => _hoveredZone = null);
        },
        builder: (ctx, cand, rej) => GestureDetector(
          onTap: () => setState(() {
            _selectedZone = _selectedZone == zone ? null : zone;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(isSelected ? 180 : 120),
              border:
                  isSelected ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerZone(Offset center, int count, VocabularyProvider prov) {
    final isSelected = _selectedZone == MasteryZone.mastered;
    return Positioned(
      left: center.dx - 26,
      top: center.dy - 26,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) {
          setState(() => _hoveredZone = MasteryZone.mastered);
          return true;
        },
        onLeave: (_) => setState(() => _hoveredZone = null),
        onAcceptWithDetails: (d) {
          prov.setWordZone(d.data, MasteryZone.mastered);
          setState(() => _hoveredZone = null);
        },
        builder: (ctx, cand, rej) => GestureDetector(
          onTap: () => setState(() {
            _selectedZone = _selectedZone == MasteryZone.mastered
                ? null
                : MasteryZone.mastered;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFFFFD54F).withAlpha(240),
                const Color(0xFFFFA726).withAlpha(200),
              ]),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withAlpha(100),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blindSpotTarget(VocabularyProvider prov, int count) {
    final isSelected = _selectedZone == MasteryZone.blindSpot;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        setState(() => _hoveredZone = MasteryZone.blindSpot);
        return true;
      },
      onLeave: (_) => setState(() => _hoveredZone = null),
      onAcceptWithDetails: (d) {
        prov.setWordZone(d.data, MasteryZone.blindSpot);
        setState(() => _hoveredZone = null);
      },
      builder: (ctx, cand, rej) => GestureDetector(
        onTap: () => setState(() {
          _selectedZone = _selectedZone == MasteryZone.blindSpot
              ? null
              : MasteryZone.blindSpot;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade700.withAlpha(isSelected ? 220 : 160),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off, color: Colors.white, size: 16),
              const Text('Điểm mù',
                  style: TextStyle(color: Colors.white, fontSize: 9)),
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📍 Vùng Venn:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text('• Tap để xem từ', style: TextStyle(fontSize: 9)),
          Text('• Kéo từ để phân loại', style: TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ── Word list (draggable chips) ──
  Widget _buildWordList(
      VocabularyProvider prov, Map<MasteryZone, List<WordEntry>> zones) {
    final displayWords =
        _selectedZone != null ? (zones[_selectedZone] ?? []) : prov.allWords;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              if (_selectedZone != null) ...[
                CircleAvatar(
                  radius: 10,
                  backgroundColor: _selectedZone!.color,
                  child:
                      Icon(_selectedZone!.icon, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedZone!.label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: _selectedZone!.color),
                ),
                const SizedBox(width: 4),
                Text(context.uiText('(${displayWords.length} từ)'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedZone = null),
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Tất cả', style: TextStyle(fontSize: 12)),
                ),
              ] else ...[
                const Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(context.uiText('Tất cả (${displayWords.length} từ)'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ],
          ),
        ),

        // Scrollable chips
        Expanded(
          child: displayWords.isEmpty
              ? const Center(
                  child: Text('Không có từ trong vùng này',
                      style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: displayWords.map((w) {
                      return LongPressDraggable<String>(
                        data: w.id,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: w.zone.color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(w.word,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: _wordChip(w),
                        ),
                        child: GestureDetector(
                          onTap: () => _showWordDetail(context, w),
                          child: _wordChip(w),
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _wordChip(WordEntry w) {
    final maxWidth = MediaQuery.of(context).size.width * 0.42;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: w.zone.color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: w.zone.color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(w.zone.icon, size: 12, color: w.zone.color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                w.word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: w.zone.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWordDetail(BuildContext context, WordEntry w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(word: w),
    );
  }
}
