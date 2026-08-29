import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../models/vocabulary_type.dart';
import '../models/word_entry.dart';
import '../providers/vocabulary_provider.dart';

/// ═══════════════════════════════════════════════════════════════
/// VOCAB ENTRY META — hiện + sửa thông tin từ đã lưu
/// (READ-630-02)
///
/// Dùng chung cho tap sheet của PDF + Web reader:
///  * `VocabEntryMetaInfo`  — hàng thông tin đầy đủ (IPA, loại,
///    chủ đề, ngôn ngữ) khi entry đã có sẵn.
///  * `VocabEntryEditSheet` — sửa IPA / loại / thêm-bớt chủ đề /
///    thêm-bớt ngôn ngữ NGAY TẠI ĐÓ.
///
/// BẢO ĐẢM KHÔNG MẤT DỮ LIỆU: chỉ đụng phonetic/vocabType/topics/
/// languages — word, context, SM-2, ghi chú KHÔNG thay đổi.
/// Xóa 1 chủ đề/ngôn ngữ chỉ gỡ tag ("mất đi 1 tab mà thôi").
/// ═══════════════════════════════════════════════════════════════

/// Ngôn ngữ nền luôn gợi ý (beyond những ngôn ngữ đã có trong list).
const List<String> kBaseLanguages = ['en', 'vi', 'pali', 'my'];

String labelForLanguage(String code) {
  switch (code) {
    case 'en':
      return 'Tiếng Anh';
    case 'vi':
      return 'Tiếng Việt';
    case 'pali':
      return 'Pali';
    case 'my':
      return 'Burmese';
    default:
      return code;
  }
}

/// Hàng thông tin đầy đủ cho entry đã lưu (hiện trong tap sheet).
class VocabEntryMetaInfo extends StatelessWidget {
  final WordEntry entry;
  final VoidCallback? onEdit;

  const VocabEntryMetaInfo({super.key, required this.entry, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final phonetic = (entry.phonetic ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              'Thông tin từ đã lưu',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (onEdit != null)
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64B5F6),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 13),
                    SizedBox(width: 3),
                    Text(
                      'Sửa',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // IPA
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.record_voice_over_outlined, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'IPA',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phonetic.isEmpty ? '—' : phonetic,
                  style: TextStyle(
                    color: phonetic.isEmpty ? Colors.white24 : const Color(0xFF90CAF9),
                    fontSize: 12,
                    fontStyle: phonetic.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Loại từ/cụm/câu
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.category_outlined, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              Text('Loại', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.vocabType.bgColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  entry.vocabType.label(context),
                  style: TextStyle(
                    color: entry.vocabType.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Chủ đề
        _MetaTagRow(
          icon: Icons.folder_outlined,
          label: 'Chủ đề',
          values: entry.topics,
          color: const Color(0xFFFFB74D),
        ),
        const SizedBox(height: 6),
        // Ngôn ngữ
        _MetaTagRow(
          icon: Icons.language_outlined,
          label: 'Ngôn ngữ',
          values: entry.languages
              .map((l) => labelForLanguage(l))
              .toList(),
          color: const Color(0xFF81C784),
        ),
      ],
    );
  }
}

class _MetaTagRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> values;
  final Color color;

  const _MetaTagRow({
    required this.icon,
    required this.label,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white38),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: values.isEmpty
                ? const Text(
                    '—',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  )
                : Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: values
                        .map((v) => _MetaTag(label: v, color: color))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Sheet sửa thông tin entry đã lưu — IPA, loại, chủ đề, ngôn ngữ.
/// Chỉ sửa meta + tag; word/context/SM-2/ghi chú giữ nguyên.
class VocabEntryEditSheet {
  static Future<void> show(BuildContext context, WordEntry entry) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _VocabEntryEditSheet(entry: entry),
    );
  }
}

class _VocabEntryEditSheet extends StatefulWidget {
  final WordEntry entry;

  const _VocabEntryEditSheet({required this.entry});

  @override
  State<_VocabEntryEditSheet> createState() => _VocabEntryEditSheetState();
}

class _VocabEntryEditSheetState extends State<_VocabEntryEditSheet> {
  late final TextEditingController _ipaCtrl;
  late VocabularyType _selectedType;
  late Set<String> _topics;
  late Set<String> _languages;
  final TextEditingController _newTopicCtrl = TextEditingController();
  final TextEditingController _newLangCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipaCtrl = TextEditingController(text: widget.entry.phonetic ?? '');
    _selectedType = widget.entry.vocabType;
    _topics = widget.entry.topics.toSet();
    _languages = widget.entry.languages.toSet();
  }

  @override
  void dispose() {
    _ipaCtrl.dispose();
    _newTopicCtrl.dispose();
    _newLangCtrl.dispose();
    super.dispose();
  }

  List<String> get _suggestedTopics {
    final provider = context.read<VocabularyProvider>();
    return provider.allTopics.where((t) => !_topics.contains(t)).toList()
      ..sort();
  }

  List<String> get _suggestedLanguages {
    final provider = context.read<VocabularyProvider>();
    final set = <String>{...provider.allLanguages, ...kBaseLanguages}
      ..removeAll(_languages);
    return set.toList()..sort();
  }

  void _save() {
    final provider = context.read<VocabularyProvider>();
    provider.updateWord(
      widget.entry.id,
      phonetic: _ipaCtrl.text.trim(),
      vocabType: _selectedType,
      topics: _topics.toList(),
      languages: _languages.toList(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.entry.word,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.lock_outline, size: 14, color: Colors.white24),
                const SizedBox(width: 4),
                Text(
                  'từ + ngữ cảnh giữ nguyên',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── IPA ────────────────────────────────────────
            TextField(
              controller: _ipaCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _fieldDecoration('Phiên âm / IPA', hint: '/.../'),
            ),
            const SizedBox(height: 14),

            // ── Loại từ/cụm/câu ─────────────────────────────
            _sectionLabel('Loại (từ / cụm / câu / đoạn)'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: VocabularyType.values.map((type) {
                final selected = _selectedType == type;
                return ChoiceChip(
                  label: Text(
                    type.label(context),
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey,
                      fontSize: 11.5,
                    ),
                  ),
                  selected: selected,
                  selectedColor: type.color,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: BorderSide.none,
                  onSelected: (value) {
                    if (value) setState(() => _selectedType = type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // ── Chủ đề ──────────────────────────────────────
            _sectionLabel('Chủ đề (thêm / bớt — không mất từ)'),
            const SizedBox(height: 6),
            ..._buildTagEditor(
              selected: _topics,
              suggestions: _suggestedTopics,
              labelFor: (v) => v,
              color: const Color(0xFFFFB74D),
              inputCtrl: _newTopicCtrl,
              newHint: 'Tạo chủ đề mới…',
              onToggle: (value, add) {
                setState(() {
                  if (add) {
                    _topics.add(value);
                  } else {
                    _topics.remove(value);
                  }
                });
              },
            ),
            const SizedBox(height: 14),

            // ── Ngôn ngữ ────────────────────────────────────
            _sectionLabel('Ngôn ngữ (thêm / bớt — không mất từ)'),
            const SizedBox(height: 6),
            ..._buildTagEditor(
              selected: _languages,
              suggestions: _suggestedLanguages,
              labelFor: labelForLanguage,
              color: const Color(0xFF81C784),
              inputCtrl: _newLangCtrl,
              newHint: 'Ngôn ngữ mới…',
              onToggle: (value, add) {
                setState(() {
                  if (add) {
                    _languages.add(value);
                  } else {
                    _languages.remove(value);
                  }
                });
              },
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 18),
                label: const Text(
                  'Lưu thông tin',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTagEditor({
    required Set<String> selected,
    required List<String> suggestions,
    required String Function(String) labelFor,
    required Color color,
    required TextEditingController inputCtrl,
    required String newHint,
    required void Function(String value, bool add) onToggle,
  }) {
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // Đã chọn — có nút × để gỡ tag
          for (final value in selected)
            ActionChip(
              avatar: Icon(Icons.close, size: 12, color: color),
              label: Text(
                labelFor(value),
                style: TextStyle(color: color, fontSize: 11.5),
              ),
              backgroundColor: color.withValues(alpha: 0.14),
              side: BorderSide(color: color.withValues(alpha: 0.35)),
              onPressed: () => onToggle(value, false),
            ),
          // Gợi ý có sẵn trong WordList — tap để thêm
          for (final value in suggestions)
            ChoiceChip(
              label: Text(
                '+ ${labelFor(value)}',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              selected: false,
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              onSelected: (_) => onToggle(value, true),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: inputCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: _fieldDecoration('', hint: newHint),
              onSubmitted: (value) {
                final v = value.trim();
                if (v.isEmpty) return;
                onToggle(v, true);
                inputCtrl.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () {
              final v = inputCtrl.text.trim();
              if (v.isEmpty) return;
              onToggle(v, true);
              inputCtrl.clear();
            },
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    ];
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 11.5,
          fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2196F3)),
      ),
    );
  }
}
