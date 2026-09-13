import 'package:flutter/material.dart';

import '../models/dict_entry.dart';

/// Bottom sheet hiển thị kết quả tra từ điển
class DictResultSheet extends StatelessWidget {
  final String word;
  final List<DictEntry> entries;

  const DictResultSheet({
    super.key,
    required this.word,
    required this.entries,
  });

  static void show(BuildContext context, String word, List<DictEntry> entries) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.6,
        child: DictResultSheet(word: word, entries: entries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.menu_book,
                  color: Color(0xFF2196F3), size: 20),
              const SizedBox(width: 8),
              Text(
                'Từ điển: $word',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${entries.length} kết quả',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1E2A3A), height: 1),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'Không tìm thấy "$word"',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _EntryCard(entry: entry);
                  },
                ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final DictEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.headword,
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (entry.partOfSpeech != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.partOfSpeech!,
                    style: const TextStyle(
                      color: Color(0xFF9C27B0),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          if (entry.phonetic != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.phonetic!,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            entry.plainDefinition,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
