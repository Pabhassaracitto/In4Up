import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';

import '../../knowledge/integration/vocabulary_mastery_projection.dart';
import '../../knowledge/visual/collection_scatter_painter.dart';
import '../../knowledge/visual/mastery_view_widget.dart';
import '../../models/word_entry.dart';

/// An opt-in, read-only view. It does not migrate or write vocabulary data.
class VocabularySixSkillView extends StatefulWidget {
  final List<WordEntry> words;

  const VocabularySixSkillView({super.key, required this.words});

  @override
  State<VocabularySixSkillView> createState() => _VocabularySixSkillViewState();
}

class _VocabularySixSkillViewState extends State<VocabularySixSkillView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return Center(
        child: Text(context.uiText('Chưa có từ vựng'),
            style: const TextStyle(color: Colors.white70)),
      );
    }

    final selected = widget.words.where((word) => word.id == _selectedId).firstOrNull ??
        widget.words.first;
    final current = VocabularyMasteryProjection.fromWord(selected);
    final points = <ScatterPoint>[
      for (final word in widget.words)
        ScatterPoint(
          unitId: word.id,
          mastery: VocabularyMasteryProjection.fromWord(word).values,
        ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: OutlinedButton(
            key: const Key('mastery_choose_word'),
            onPressed: _chooseWord,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search, size: 18),
                const SizedBox(width: 6),
                Text(context.uiText('Chọn từ')),
                const SizedBox(width: 8),
                Flexible(
                  child: material.Text(selected.word,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              Text(context.uiText('Điểm Hiểu, Nghe, Đọc là điểm hiện đang lưu, không phải EMA.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 3),
              Text(context.uiText('Đánh giá và lưu Dùng, Nói, Viết chưa được kết nối.'),
                  key: const Key('mastery_output_unavailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFCC80), fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: MasteryViewWidget(
            mastery: current.values,
            useIsPartial: current.useIsPartial,
            collectionPoints: points,
          ),
        ),
      ],
    );
  }

  Future<void> _chooseWord() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF192235),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _MasteryWordPicker(words: List.of(widget.words)),
      ),
    );
    if (id != null && mounted) setState(() => _selectedId = id);
  }
}

class _MasteryWordPicker extends StatefulWidget {
  final List<WordEntry> words;

  const _MasteryWordPicker({required this.words});

  @override
  State<_MasteryWordPicker> createState() => _MasteryWordPickerState();
}

class _MasteryWordPickerState extends State<_MasteryWordPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? widget.words
        : widget.words.where((word) =>
            word.word.toLowerCase().contains(q) ||
            word.meaning.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            TextField(
              key: const Key('mastery_word_search'),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                hintText: context.uiText('Tìm từ hoặc nghĩa'),
                hintStyle: const TextStyle(color: Colors.white60),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(context.uiText('Không tìm thấy từ'),
                          style: const TextStyle(color: Colors.white70)),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final word = matches[index];
                        return ListTile(
                          key: ValueKey('mastery_pick_${word.id}'),
                          title: material.Text(word.word,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: material.Text(word.meaning,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70)),
                          onTap: () => Navigator.pop(context, word.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
