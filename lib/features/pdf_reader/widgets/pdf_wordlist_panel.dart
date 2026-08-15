// ═══════════════════════════════════════════════════════════════
//  WORDLIST MINI PANEL — hiện trong Split View PDF
//  Hiển thị từ đã lưu từ file PDF hiện tại
//  Compact list với TTS + mastery bar
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/tts/tts_service.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';
import 'package:in4up/core/language/tr_extension.dart';

class PdfWordlistPanel extends StatefulWidget {
  final String pdfFileName;

  const PdfWordlistPanel({super.key, required this.pdfFileName});

  @override
  State<PdfWordlistPanel> createState() => _PdfWordlistPanelState();
}

class _PdfWordlistPanelState extends State<PdfWordlistPanel> {
  final _tts = TtsService();
  String _sortMode = 'added'; // 'added' | 'alpha' | 'mastery'

  List<WordEntry> _getWordsFromFile(VocabularyProvider p) {
    final words = p.allWords
        .where((w) => w.contexts.any(
              (c) => c.sourceName == widget.pdfFileName,
            ))
        .toList();

    switch (_sortMode) {
      case 'alpha':
        words.sort(
            (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      case 'mastery':
        words.sort((a, b) => b.mastery.compareTo(a.mastery));
      default: // 'added'
        words.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return words;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<VocabularyProvider, int>(
      selector: (_, prov) => prov.allWords.length,
      builder: (context, wordCount, child) {
        final provider = context.read<VocabularyProvider>();
        final words = _getWordsFromFile(provider);

        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF080B1A),
              border: Border(
                left: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(words.length),
                _buildSortBar(),
                Expanded(
                  child: words.isEmpty
                      ? _buildEmpty()
                      : _buildList(words, provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.library_books, size: 14, color: Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Saved',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF9C8FFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: const Color(0xFF0A0F1A),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SortBtn(
              label: context.tr('Mới'),
              isSelected: _sortMode == 'added',
              onTap: () => setState(() => _sortMode = 'added'),
            ),
            _SortBtn(
              label: 'A-Z',
              isSelected: _sortMode == 'alpha',
              onTap: () => setState(() => _sortMode = 'alpha'),
            ),
            _SortBtn(
              label: context.tr('Thuần thục'),
              isSelected: _sortMode == 'mastery',
              onTap: () => setState(() => _sortMode = 'mastery'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 36, color: Colors.grey[800]),
          const SizedBox(height: 8),
          Text(
            'Chưa có từ\nnào được lưu',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap từ trên PDF\nhoặc bôi đen → 🔖',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[800], fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<WordEntry> words, VocabularyProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: words.length,
      itemBuilder: (_, i) {
        final word = words[i];
        return _MiniWordItem(
          word: word,
          tts: _tts,
          onDelete: () => provider.removeWord(word.id),
        );
      },
    );
  }
}

// ── Mini Word Item ─────────────────────────────────────────

class _MiniWordItem extends StatelessWidget {
  final WordEntry word;
  final TtsService tts;
  final VoidCallback onDelete;

  const _MiniWordItem({
    required this.word,
    required this.tts,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = word.vocabType.color;

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Type badge
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  word.vocabType.badge,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  word.word,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // TTS
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  tts.speak(word.word);
                },
                child: Icon(Icons.volume_up, size: 14, color: Colors.grey[600]),
              ),
              const SizedBox(width: 4),
              // Delete
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close, size: 12, color: Colors.grey[700]),
              ),
            ],
          ),
          // Meaning
          if (word.meaning.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              word.meaning,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Mastery bar
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: word.mastery,
              minHeight: 2,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                  word.zone.color.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? Color(0xFF6C63FF).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? Color(0xFF6C63FF).withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF9C8FFF) : Colors.grey[600],
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      );
}