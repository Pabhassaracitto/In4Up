//lib/screens/tools/stats_tab.dart═══════════════════════════════════════════════════════════════

//  STATS TAB - Thống kê tổng quan
//  Nguồn: DashboardScreen từ mode3
//  Vị trí: Tools → Tab "Thống kê"
// ═══════════════════════════════════════════════════════════════

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/skill_triangle.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, prov, _) {
        if (prov.total == 0) {
          return _buildEmptyState(context);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProgressCard(prov: prov),
            const SizedBox(height: 12),
            _SkillBarsCard(prov: prov),
            const SizedBox(height: 12),
            _ReviewStatsCard(prov: prov),
            const SizedBox(height: 12),
            _ZoneDistribution(prov: prov),
            const SizedBox(height: 12),
            _AttentionWords(prov: prov),
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
          Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Chưa có từ vựng',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lưu từ từ tab Read để xem thống kê',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Card tiến độ tổng ──
class _ProgressCard extends StatelessWidget {
  final VocabularyProvider prov;
  const _ProgressCard({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_graph,
                      size: 24, color: Color(0xFF6C63FF)),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tiến độ tổng thể',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${(prov.progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6C63FF),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: prov.progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(context, 'Tổng từ', '${prov.total}', Icons.library_books),
                _divider(),
                _stat(context, 'Điểm mù', '${prov.blindSpots}',
                    Icons.visibility_off,
                    color: Colors.red),
                _divider(),
                _stat(
                    context, 'Thành thạo', '${prov.masteredCount}', Icons.star,
                    color: Colors.amber),
                _divider(),
                _stat(context, 'Cần ôn', '${prov.dueCount}', Icons.alarm,
                    color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(height: 36, width: 1, color: Colors.grey.shade200);

  Widget _stat(BuildContext context, String label, String value, IconData icon,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── 3 thanh kỹ năng ──
class _SkillBarsCard extends StatelessWidget {
  final VocabularyProvider prov;
  const _SkillBarsCard({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined,
                    size: 20, color: Color(0xFF26C6DA)),
                const SizedBox(width: 8),
                Text('Liên kết 3 chiều',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            _bar(context.uiText('🔵 HIỂU'), prov.avgUnderstand, const Color(0xFF42A5F5)),
            const SizedBox(height: 10),
            _bar(context.uiText('🟢 NGHE'), prov.avgListen, const Color(0xFF66BB6A)),
            const SizedBox(height: 10),
            _bar(context.uiText('🔴 ĐỌC'), prov.avgRead, const Color(0xFFEF5350)),
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: color.withAlpha(25),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(value * 100).toInt()}%',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ],
    );
  }
}

// ── Review statistics ──
class _ReviewStatsCard extends StatelessWidget {
  final VocabularyProvider prov;
  const _ReviewStatsCard({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined,
                    size: 20, color: Color(0xFFEF5350)),
                const SizedBox(width: 8),
                Text('Thống kê ôn tập',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _reviewStat(
                    context,
                    label: 'Tổng lượt',
                    value: '${prov.totalReviewsAllTime}',
                    icon: Icons.repeat_rounded,
                    color: const Color(0xFF6C63FF),
                  ),
                ),
                Expanded(
                  child: _reviewStat(
                    context,
                    label: 'Độ chính xác',
                    value: '${(prov.avgAccuracy * 100).toInt()}%',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF66BB6A),
                  ),
                ),
                Expanded(
                  child: _reviewStat(
                    context,
                    label: 'Đang học',
                    value: '${prov.learningWords.length}',
                    icon: Icons.trending_up,
                    color: const Color(0xFFFFA726),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStat(BuildContext context,
      {required String label,
      required String value,
      required IconData icon,
      required Color color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ── Phân bổ 8 vùng Venn ──
class _ZoneDistribution extends StatelessWidget {
  final VocabularyProvider prov;
  const _ZoneDistribution({required this.prov});

  @override
  Widget build(BuildContext context) {
    final zones = prov.wordsByZone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined,
                    size: 20, color: Color(0xFF26C6DA)),
                const SizedBox(width: 8),
                Text('Phân bổ 8 vùng',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),

            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: MasteryZone.values.map((z) {
                    final count = zones[z]?.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: count,
                      child: Container(color: z.color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Legend grid
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: MasteryZone.values.map((z) {
                final count = zones[z]?.length ?? 0;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: z.color,
                    radius: 8,
                    child: Icon(z.icon, size: 10, color: Colors.white),
                  ),
                  label: Text('${context.uiText(z.label)}: $count',
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: count > 0 ? z.color.withAlpha(15) : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Từ cần chú ý (blind spots + yếu nhất) ──
class _AttentionWords extends StatelessWidget {
  final VocabularyProvider prov;
  const _AttentionWords({required this.prov});

  @override
  Widget build(BuildContext context) {
    final weak = List<WordEntry>.from(prov.allWords)
      ..sort((a, b) => a.mastery.compareTo(b.mastery));
    final top5 = weak.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Từ cần luyện nhất',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(context.uiText('${top5.length} từ'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            ...top5.map((w) => ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: w.zone.color.withAlpha(30),
                    child: Icon(w.zone.icon, color: w.zone.color, size: 16),
                  ),
                  title: Text(w.word,
                      style: TextStyle(
                          fontWeight: w.visualWeight,
                          color: w.visualColor,
                          fontSize: 15)),
                  subtitle:
                      Text(w.meaning, style: const TextStyle(fontSize: 12)),
                  trailing: SizedBox(
                    width: 48,
                    height: 48,
                    child: SkillTriangle(word: w, size: 48),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
