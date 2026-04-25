import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/vocabulary_type.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (_, provider, __) {
        final dateGroups = provider.wordsByDate;

        if (dateGroups.isEmpty) {
          return _buildEmpty();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF080B1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D1520),
            title: const Text('Timeline',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('${provider.total} từ',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: dateGroups.length,
            itemBuilder: (_, i) {
              final dateKey = dateGroups.keys.elementAt(i);
              final entries = dateGroups[dateKey]!;
              return _DateGroup(
                dateKey: dateKey,
                entries: entries,
                provider: provider,
                isFirst: i == 0,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1520),
        title: const Text('Timeline'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 52, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text('Chưa có lịch sử',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _DateGroup extends StatelessWidget {
  final String dateKey;
  final List<WordEntry> entries;
  final VocabularyProvider provider;
  final bool isFirst;

  const _DateGroup({
    required this.dateKey,
    required this.entries,
    required this.provider,
    required this.isFirst,
  });

  String get _displayDate {
    final now = DateTime.now();
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    if (y == now.year && m == now.month && d == now.day) return 'Hôm nay';
    if (y == now.year && m == now.month && d == now.day - 1) return 'Hôm qua';
    return '$d/$m/$y';
  }

  /// Tìm tất cả source files cho ngày này
  Set<String> get _sources {
    final s = <String>{};
    for (final e in entries) {
      for (final ctx in e.contexts) {
        if (ctx.sourceName != null) s.add(ctx.sourceName!);
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline line + dot ──
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst
                        ? const Color(0xFF6C63FF)
                        : Color(0xFF6C63FF).withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                                color: const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.4),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                ),
                Container(
                  width: 2,
                  height: entries.length * 52.0 + 40,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Row(
                  children: [
                    Text('📅 $_displayDate',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFF6C63FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('+${entries.length}',
                          style: const TextStyle(
                              color: Color(0xFF9C8FFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                // Sources
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(sources.join(' · '),
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],

                const SizedBox(height: 8),

                // Entries
                ...entries.map((entry) => _TimelineEntry(
                      entry: entry,
                      encounterCount: entry.encounterCount,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final WordEntry entry;
  final int encounterCount;

  const _TimelineEntry({
    required this.entry,
    required this.encounterCount,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = entry.vocabType.color;
    final isReencounter = encounterCount > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReencounter
              ? Color(0xFFFFB300).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Type icon
          Text(
            entry.vocabType == VocabularyType.word
                ? '📖'
                : entry.vocabType == VocabularyType.phrase
                    ? '📝'
                    : '📄',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),

          // Word + meaning
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(entry.word,
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    if (entry.vocabType != VocabularyType.word) ...[
                      const SizedBox(width: 4),
                      Text('(${entry.vocabType.label})',
                          style: TextStyle(
                              color: typeColor.withValues(alpha: 0.6),
                              fontSize: 9)),
                    ],
                  ],
                ),
                Text('— ${entry.meaning}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // Re-encounter badge
          if (isReencounter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFFFFB300).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Gặp lần $encounterCount!',
                  style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
