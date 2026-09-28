import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../providers/vocabulary_provider.dart';
import '../services/vocab_batch/vocab_batch_models.dart';
import 'difficulty_level_chips.dart';
import 'vocab_entry_meta.dart';

/// Shared per-item editor for the Web and PDF batch import sheets.
///
/// Meaning, IPA, topic and example can be reviewed before import; difficulty
/// can be assigned here or directly from the candidate list.
class VocabBatchCandidateEditor {
  VocabBatchCandidateEditor._();

  static Future<bool> show(
    BuildContext context, {
    required WebExtractionCandidate candidate,
  }) async {
    final meaningCtrl = TextEditingController(text: candidate.meaning);
    final phoneticCtrl = TextEditingController(text: candidate.phonetic ?? '');
    final topicCtrl = TextEditingController(text: candidate.topic ?? '');
    final exampleCtrl = TextEditingController(
      text: (candidate.example ?? '').trim().isEmpty
          ? candidate.sampleContext
          : candidate.example,
    );
    final provider = context.read<VocabularyProvider>();
    final languageOptions = <String>{
      ...provider.allLanguages,
      ...kBaseLanguages,
      candidate.language,
    }.where((value) => value.trim().isNotEmpty).toList()
      ..sort();
    var selectedLanguage = candidate.language;
    var selectedDifficulty = candidate.difficulty;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: Text(
            context.uiText('Sửa thông tin mục'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.text,
                    style: const TextStyle(
                      color: Color(0xFF90CAF9),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    context,
                    controller: meaningCtrl,
                    label: 'Nghĩa / giải thích',
                    hint: 'Nghĩa ngắn hoặc định nghĩa',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    context,
                    controller: phoneticCtrl,
                    label: 'Phiên âm / IPA',
                    hint: '/.../',
                  ),
                  const SizedBox(height: 10),
                  _field(
                    context,
                    controller: topicCtrl,
                    label: 'Chủ đề',
                    hint: 'news / travel / study...',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.uiText('Độ khó'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  DifficultyLevelChips(
                    value: selectedDifficulty,
                    dense: true,
                    onChanged: (value) =>
                        setDialogState(() => selectedDifficulty = value),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.uiText('Ngôn ngữ'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final language in languageOptions)
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          selected: selectedLanguage == language,
                          label: Text(
                            labelForLanguage(language),
                            style: TextStyle(
                              color: selectedLanguage == language
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 10.5,
                            ),
                          ),
                          selectedColor: const Color(0xFF42A5F5),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => selectedLanguage = language);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _field(
                    context,
                    controller: exampleCtrl,
                    label: 'Câu ví dụ / ngữ cảnh',
                    hint: 'Một câu tự nhiên có chứa từ hoặc cụm này',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.uiText('Mặc định dùng câu đang đọc làm ví dụ.'),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.uiText('Hủy')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.uiText('Lưu')),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true) {
      candidate.meaning = meaningCtrl.text.trim();
      candidate.phonetic = phoneticCtrl.text.trim().isEmpty
          ? null
          : phoneticCtrl.text.trim();
      candidate.topic =
          topicCtrl.text.trim().isEmpty ? null : topicCtrl.text.trim();
      candidate.example = exampleCtrl.text.trim().isEmpty
          ? null
          : exampleCtrl.text.trim();
      candidate.language = selectedLanguage;
      candidate.difficulty = selectedDifficulty;
      candidate.enriched = true;
      candidate.enrichSource = 'manual';
    }

    meaningCtrl.dispose();
    phoneticCtrl.dispose();
    topicCtrl.dispose();
    exampleCtrl.dispose();
    return shouldSave == true;
  }

  static Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: context.uiText(label),
        hintText: context.uiText(hint),
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF64B5F6)),
        ),
      ),
    );
  }
}
