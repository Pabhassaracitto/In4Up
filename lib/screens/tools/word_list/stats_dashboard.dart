import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/vocabulary_type.dart';
import '../../../providers/vocabulary_provider.dart';
import 'package:in4up/core/language/tr_extension.dart';

class StatsDashboard extends StatelessWidget {
  const StatsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (_, p, __) => Scaffold(
        backgroundColor: const Color(0xFF080B1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1520),
          title: const Text('📊 Wordlist Stats',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Summary Cards ──
            _SummaryRow(provider: p),
            const SizedBox(height: 16),

            // ── Progress Bar ──
            _ProgressSection(provider: p),
            const SizedBox(height: 16),

            // ── Streak + This Week ──
            _ActivitySection(provider: p),
            const SizedBox(height: 16),

            // ── Skill Breakdown ──
            _SkillBreakdown(provider: p),
            const SizedBox(height: 16),

            // ── Most Forgotten ──
            _MostForgotten(provider: p),
            const SizedBox(height: 16),

            // ── Frequently Encountered ──
            _FrequentSection(provider: p),
          ],
        ),
      ),
    );
  }
}

// ── Summary Row ──
class _SummaryRow extends StatelessWidget {
  final VocabularyProvider provider;
  const _SummaryRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryCard(
            value: '${provider.total}',
            label: context.tr('Tổng'),
            color: const Color(0xFF6C63FF)),
        const SizedBox(width: 8),
        _SummaryCard(
            value: '${provider.wordCount}',
            label: context.l10n.vocabWord,
            color: VocabularyType.word.color),
        const SizedBox(width: 8),
        _SummaryCard(
            value: '${provider.phraseCount}',
            label: context.tr('Cụm'),
            color: VocabularyType.phrase.color),
        const SizedBox(width: 8),
        _SummaryCard(
            value: '${provider.sentenceCount}',
            label: context.l10n.vocabSentence,
            color: VocabularyType.sentence.color),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _SummaryCard(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Progress ──
class _ProgressSection extends StatelessWidget {
  final VocabularyProvider provider;
  const _ProgressSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final pct = (provider.progress * 100).toInt();
    final reviewed = provider.totalReviewsAllTime;

    return _Card(
      title: context.tr('Tiến độ'),
      child: Column(
        children: [
          Row(
            children: [
              Text('Content',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Content',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: provider.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(
                  icon: Icons.alarm,
                  label: 'Content',
                  color: const Color(0xFFFF5722)),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.star,
                  label: 'Content',
                  color: const Color(0xFFFFD54F)),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.visibility_off,
                  label: 'Content',
                  color: const Color(0xFF616161)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Activity ──
class _ActivitySection extends StatelessWidget {
  final VocabularyProvider provider;
  const _ActivitySection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final thisWeekAdded = provider.wordsAddedInLastDays(7);
    final thisWeekReviewed = provider.reviewsInLastDays(7);

    return _Card(
      title: context.tr('Tuần này'),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('+$thisWeekAdded',
                      style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const TrText('từ mới', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('$thisWeekReviewed',
                      style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const TrText('lượt ôn', style: TextStyle(color: Color(0xFF2196F3), fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFF9800).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('${(provider.avgAccuracy * 100).toInt()}%',
                      style: const TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const TrText('chính xác', style: TextStyle(color: Color(0xFFFF9800), fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skill Breakdown ──
class _SkillBreakdown extends StatelessWidget {
  final VocabularyProvider provider;
  const _SkillBreakdown({required this.provider});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: context.tr('3 Chiều Kỹ Năng'),
      child: Row(
        children: [
          _SkillGauge(
              label: context.l10n.commonUnderstanding,
              value: provider.avgUnderstand,
              color: const Color(0xFF42A5F5)),
          const SizedBox(width: 16),
          _SkillGauge(
              label: 'Nghe',
              value: provider.avgListen,
              color: const Color(0xFF66BB6A)),
          const SizedBox(width: 16),
          _SkillGauge(
              label: context.tr('Đọc'),
              value: provider.avgRead,
              color: const Color(0xFFEF5350)),
        ],
      ),
    );
  }
}

class _SkillGauge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SkillGauge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toInt();
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text('$pct%',
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Most Forgotten ──
class _MostForgotten extends StatelessWidget {
  final VocabularyProvider provider;
  const _MostForgotten({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Words with lowest accuracy and at least 2 reviews
    final forgotten = provider.allWords
        .where((w) => w.totalReviews >= 2)
        .toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    if (forgotten.isEmpty) return const SizedBox.shrink();

    return _Card(
      title: context.tr('Từ hay quên nhất'),
      child: Column(
        children: forgotten.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final w = e.value;
          final wrong = w.totalReviews - w.correctReviews;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(0xFFEF5350).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(w.word,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                Text('Content',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Frequently Encountered ──
class _FrequentSection extends StatelessWidget {
  final VocabularyProvider provider;
  const _FrequentSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final frequent = provider.frequentlyEncountered;
    if (frequent.isEmpty) return const SizedBox.shrink();

    return _Card(
      title: 'Content',
      child: Column(
        children: frequent
            .take(5)
            .map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFB300).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${w.encounterCount}×',
                            style: const TextStyle(
                                color: Color(0xFFFFB300),
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.word,
                                style: TextStyle(
                                    color: w.vocabType.color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(w.meaning,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text('Content',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 10)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Helpers ──
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}