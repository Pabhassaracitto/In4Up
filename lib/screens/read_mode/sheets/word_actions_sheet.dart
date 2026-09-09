// lib/screens/read_mode/sheets/word_actions_sheet.dart
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

import '../../../features/dictionary/services/dictionary_service.dart';
import '../../../features/vocab_image/vocab_image_picker.dart';
import '../../../models/vocab_context.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../widgets/selection_save_sheet.dart';
import '../../../widgets/unified_knowledge_sheet.dart';

void _openFullSave(
  BuildContext context, {
  required String text,
  required int lineIndex,
}) {
  final tp = context.read<TextProvider>();
  final title = tp.currentDocument?.title ?? 'Đọc';
  final lineContent = lineIndex < tp.lines.length
      ? tp.lines[lineIndex].content
      : text;
  SelectionSaveSheet.show(
    context,
    text: text,
    sourceLabel: title,
    contextBuilder: (sample) => VocabContext.fromStory(
      storyTitle: title,
      lineIndex: lineIndex,
      surroundingText: lineContent,
      sourceRef: tp.currentContextSourceRef,
      sourceRefType: tp.currentContextSourceRefType,
      anchorText: sample,
    ),
  );
}

class WordActionsSheet {
  WordActionsSheet._();

  static void show(
    BuildContext context,
    AnalyzedWord word,
    int lineIndex,
    int wordIndex,
  ) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: _WordActionsContent(
              word: word,
              lineIndex: lineIndex,
              wordIndex: wordIndex,
            ),
          ),
        ),
      ),
    );
  }
}

class _WordActionsContent extends StatefulWidget {
  final AnalyzedWord word;
  final int lineIndex;
  final int wordIndex;

  const _WordActionsContent({
    required this.word,
    required this.lineIndex,
    required this.wordIndex,
  });

  @override
  State<_WordActionsContent> createState() => _WordActionsContentState();
}

class _WordActionsContentState extends State<_WordActionsContent> {
  List<dynamic> _dictEntries = [];
  bool _dictLoading = true;

  @override
  void initState() {
    super.initState();
    _lookupDict();
  }

  Future<void> _lookupDict() async {
    try {
      final entries =
          await DictionaryService.instance.lookup(widget.word.word);
      if (mounted) {
        setState(() {
          _dictEntries = entries;
          _dictLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _dictLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TextProvider>();
    final existingWord =
        context.read<VocabularyProvider>().findByWord(widget.word.word);

    String? bestMeaning = widget.word.meaning;
    if (_dictEntries.isNotEmpty) {
      bestMeaning = _dictEntries.first.plainDefinition;
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== DRAG HANDLE =====
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ===== WORD HEADER =====
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.word.wordType.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.word.wordType.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  widget.word.word,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.word.wordType.color,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          label: widget.word.wordType.labelVi,
                          color: widget.word.wordType.color,
                        ),
                        _Badge(
                          label: widget.word.cefrLevel.shortLabel,
                          color: widget.word.cefrLevel.color,
                        ),
                        if (widget.word.userDifficulty != null)
                          _Badge(
                            label: widget.word.userDifficulty!.label,
                            color: widget.word.userDifficulty!.color,
                          ),
                      ],
                    ),
                    if (bestMeaning != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        bestMeaning,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Speak button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  tp.speak(widget.word.word);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ===== DICTIONARY RESULTS (MDX) =====
          if (_dictEntries.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book,
                          size: 14, color: Color(0xFF2196F3)),
                      const SizedBox(width: 6),
                      Text(
                        'T\u1EEB \u0111i\u1EC3n MDX (${_dictEntries.length} k\u1EBFt qu\u1EA3)',
                        style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(_dictEntries.take(3).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          e.plainDefinition,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))),
                  if (_dictEntries.length > 3)
                    Text(
                      '+ ${_dictEntries.length - 3} k\u1EBFt qu\u1EA3 kh\u00E1c...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ] else if (_dictLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\u0110ang tra t\u1EEB \u0111i\u1EC3n...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),

          // ===== PHONETIC / EXAMPLE =====
          if (widget.word.phonetic != null || widget.word.example != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.word.phonetic != null) ...[
                    Row(
                      children: [
                        Icon(Icons.record_voice_over,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          widget.word.phonetic!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.word.phonetic != null &&
                      widget.word.example != null)
                    const SizedBox(height: 8),
                  if (widget.word.example != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.word.example!,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          if (existingWord != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  UnifiedKnowledgeSheet.show(context, word: existingWord);
                },
                icon: const Icon(Icons.hub_outlined, size: 18),
                label: const Text('M\u1EDF h\u1ED3 s\u01A1 tri th\u1EE9c h\u1EE3p nh\u1EA5t'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  side: BorderSide(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ===== DIFFICULTY MARKING =====
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '\u0110\u00E1nh d\u1EA5u \u0111\u1ED9 kh\u00F3:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DifficultyLevel.values.map((level) {
              final isSelected = widget.word.userDifficulty == level;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  tp.markWordDifficulty(
                      widget.lineIndex, widget.wordIndex, level);
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: level.color, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '"${widget.word.word}" \u2192 ${context.uiText(level.label)} (${level.repeatCount}x)',
                          ),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF2A2A3E),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? level.color
                        : level.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: level.color.withValues(
                        alpha: isSelected ? 1.0 : 0.4,
                      ),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        level.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : level.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        context.uiText('${level.repeatCount}x l\u1EB7p'),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : level.color.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ===== IMAGE PICKER =====
          if (existingWord != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'H\u00ECnh \u1EA3nh ghi nh\u1EDD:',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: VocabImagePicker(
                wordId: existingWord.id,
                currentImageUrl: existingWord.imageUrl,
                onImageChanged: (path) {},
                size: 140,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ch\u1EA5m \u0111\u1EC3 ch\u1ECDn \u00B7 Gi\u1EE5 \u0111\u1EC3 x\u00F3a',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],

          // ===== QUICK ACTIONS =====
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.word.word));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('\uD83D\uDCCB \u0110\u00E3 sao ch\u00E9p!'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Sao ch\u00E9p'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[300],
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SaveToWordlistButton(
                  word: widget.word,
                  lineIndex: widget.lineIndex,
                  onSaved: () => Navigator.pop(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _openFullSave(
                  context,
                  text: widget.word.word,
                  lineIndex: widget.lineIndex,
                );
              },
              icon: const Icon(Icons.library_add_check, size: 18),
              label: const Text('L\u01B0u \u0111\u1EA7y \u0111\u1EE7 (ch\u1EE7 \u0111\u1EC1 \u00B7 ng\u00F4n ng\u1EEF)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9C27B0),
                side: BorderSide(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final line = widget.lineIndex < tp.lines.length
                    ? tp.lines[widget.lineIndex].content
                    : widget.word.word;
                _openFullSave(
                  context,
                  text: line,
                  lineIndex: widget.lineIndex,
                );
              },
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('L\u01B0u c\u1EA3 d\u00F2ng (nh\u01B0 ch\u1EBF \u0111\u1ED9 kh\u00F4ng m\u00E0u)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF26C6DA),
                side: BorderSide(
                  color: const Color(0xFF26C6DA).withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ===== WORD STATS =====
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Xu\u1EA5t hi\u1EC7n',
                  value: '${widget.word.frequency ?? 1}x',
                  icon: Icons.repeat,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                _StatItem(
                  label: 'D\u00F2ng',
                  value: '${widget.lineIndex + 1}',
                  icon: Icons.format_list_numbered,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                _StatItem(
                  label: 'K\u00FD t\u1EF1',
                  value: '${widget.word.word.length}',
                  icon: Icons.text_fields,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== REUSABLE BADGE WIDGET =====
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ===== STAT ITEM WIDGET =====
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SAVE TO WORDLIST BUTTON
// ═══════════════════════════════════════════════════════════════

class _SaveToWordlistButton extends StatefulWidget {
  final AnalyzedWord word;
  final int lineIndex;
  final VoidCallback onSaved;

  const _SaveToWordlistButton({
    required this.word,
    required this.lineIndex,
    required this.onSaved,
  });

  @override
  State<_SaveToWordlistButton> createState() =>
      _SaveToWordlistButtonState();
}

class _SaveToWordlistButtonState extends State<_SaveToWordlistButton> {
  bool _showMeaningInput = false;
  final _meaningCtrl = TextEditingController();

  @override
  void dispose() {
    _meaningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabProvider = context.read<VocabularyProvider>();
    final alreadyExists = vocabProvider.hasWord(widget.word.word);

    if (alreadyExists) {
      return _buildExistsButton(vocabProvider);
    }

    if (_showMeaningInput) {
      return _buildMeaningInput(vocabProvider);
    }

    return _buildSaveButton(vocabProvider);
  }

  Widget _buildSaveButton(VocabularyProvider vocabProvider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _saveQuick(vocabProvider),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('L\u01B0u nhanh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              side: const BorderSide(
                  color: Color(0xFF4CAF50), width: 0.8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                setState(() => _showMeaningInput = true),
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('+ Ngh\u0129a'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2196F3),
              side: const BorderSide(
                  color: Color(0xFF2196F3), width: 0.8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeaningInput(VocabularyProvider vocabProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final actions = [
          GestureDetector(
            onTap: () => _saveWithMeaning(vocabProvider),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check,
                  color: Colors.white, size: 18),
            ),
          ),
          GestureDetector(
            onTap: () =>
                setState(() => _showMeaningInput = false),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close,
                  color: Colors.grey, size: 18),
            ),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              TextField(
                controller: _meaningCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: context.uiText(
                      'Nh\u1EADp ngh\u0129a ti\u1EBFng Vi\u1EC7t...'),
                  hintStyle: TextStyle(
                      color: Colors.grey[600], fontSize: 12),
                  filled: true,
                  fillColor:
                      Colors.white.withValues(alpha: 0.05),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF2196F3), width: 1.5),
                  ),
                ),
                onSubmitted: (_) =>
                    _saveWithMeaning(vocabProvider),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  actions[0],
                  const SizedBox(width: 4),
                  actions[1],
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _meaningCtrl,
                      autofocus: true,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: context.uiText(
                            'Nh\u1EADp ngh\u0129a ti\u1EBFng Vi\u1EC7t...'),
                        hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12),
                        filled: true,
                        fillColor: Colors.white
                            .withValues(alpha: 0.05),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF2196F3),
                              width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) =>
                          _saveWithMeaning(vocabProvider),
                    ),
                  ),
                  const SizedBox(width: 8),
                  actions[0],
                  const SizedBox(width: 4),
                  actions[1],
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildExistsButton(VocabularyProvider vocabProvider) {
    return OutlinedButton.icon(
      onPressed: () => _addContextOnly(vocabProvider),
      icon: const Icon(Icons.add_location_alt, size: 16),
      label: const Text('+ Th\u00EAm ng\u1EEF c\u1EA3nh'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFFB300),
        side: const BorderSide(
            color: Color(0xFFFFB300), width: 0.8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _saveQuick(VocabularyProvider vocabProvider) {
    final tp = context.read<TextProvider>();
    final ctx = _buildContext(tp);

    vocabProvider.addWithAutoClassify(
      text: widget.word.word,
      meaning: widget.word.meaning ?? '',
      phonetic: widget.word.phonetic,
      context: ctx,
    );

    tp.saveWord(widget.word);
    widget.onSaved();
    _showSavedSnack(context, widget.word.word);
  }

  void _saveWithMeaning(VocabularyProvider vocabProvider) {
    final tp = context.read<TextProvider>();
    final ctx = _buildContext(tp);
    final meaning = _meaningCtrl.text.trim();

    vocabProvider.addWithAutoClassify(
      text: widget.word.word,
      meaning: meaning.isNotEmpty
          ? meaning
          : (widget.word.meaning ?? ''),
      phonetic: widget.word.phonetic,
      context: ctx,
    );

    tp.saveWord(widget.word);
    widget.onSaved();
    _showSavedSnack(context, widget.word.word);
  }

  void _addContextOnly(VocabularyProvider vocabProvider) {
    final tp = context.read<TextProvider>();
    final ctx = _buildContext(tp);
    final existing =
        vocabProvider.findByWord(widget.word.word);
    if (existing != null) {
      vocabProvider.addContextToWord(existing.id, ctx);
    }
    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText(
              '\uD83D\uDCCC \u0110\u00E3 th\u00EAm ng\u1EEF c\u1EA3nh m\u1EDBi cho "${widget.word.word}"')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2A2A3E),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  VocabContext _buildContext(TextProvider tp) {
    final title =
        tp.currentDocument?.title ?? 'Text Studio';
    final lineContent =
        widget.lineIndex < tp.lines.length
            ? tp.lines[widget.lineIndex].content
            : widget.word.word;
    final selectedInfo = tp.selectedTextInfo;
    final selectedNormalized = (selectedInfo?.text ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w']"), '')
        .trim();
    final wordNormalized = widget.word.word
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w']"), '')
        .trim();
    final useSelectionAnchor = selectedInfo != null &&
        selectedInfo.lineIndex == widget.lineIndex &&
        selectedNormalized == wordNormalized;

    return VocabContext.fromStory(
      storyTitle: title,
      lineIndex: widget.lineIndex,
      surroundingText: lineContent,
      sourceRef: tp.currentContextSourceRef,
      sourceRefType: tp.currentContextSourceRefType,
      anchorText: widget.word.word,
      textStartOffset: useSelectionAnchor
          ? selectedInfo.startOffset
          : null,
      textEndOffset: useSelectionAnchor
          ? selectedInfo.endOffset
          : null,
    );
  }

  static void _showSavedSnack(
      BuildContext context, String word) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added,
                color: Color(0xFF4CAF50), size: 18),
            const SizedBox(width: 8),
            Text(context.uiText(
                '"$word" \u0111\u00E3 l\u01B0u v\u00E0o Wordlist')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
