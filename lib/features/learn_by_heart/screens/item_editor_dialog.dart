// lib/features/learn_by_heart/screens/item_editor_dialog.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:uuid/uuid.dart';
import '../models/chunk.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../models/line_timestamp.dart';
import '../models/recitation_category.dart';
import '../models/review_state.dart';

class ItemEditorDialog extends StatefulWidget {
  final LearnByHeartItem? initialItem;

  const ItemEditorDialog({super.key, this.initialItem});

  @override
  State<ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _paliCtrl;
  late TextEditingController _viCtrl;
  late TextEditingController _shortMeaningCtrl;
  late TextEditingController _keywordsCtrl;
  late TextEditingController _lifeConnectionCtrl;

  RecitationCategory _category = RecitationCategory.dhammapada;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _subtitleCtrl = TextEditingController(text: item?.subtitle ?? '');
    _paliCtrl = TextEditingController(text: item?.paliText ?? '');
    _viCtrl = TextEditingController(text: item?.vietnameseText ?? '');
    _shortMeaningCtrl = TextEditingController(text: item?.shortMeaning ?? '');
    _keywordsCtrl = TextEditingController(text: item?.keywords.join(', ') ?? '');
    _lifeConnectionCtrl = TextEditingController(text: item?.lifeConnection ?? '');
    if (item != null) {
      _category = item.category;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _paliCtrl.dispose();
    _viCtrl.dispose();
    _shortMeaningCtrl.dispose();
    _keywordsCtrl.dispose();
    _lifeConnectionCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final viText = _viCtrl.text.trim();
    final paliText = _paliCtrl.text.trim();
    final viLines = viText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final paliLines = paliText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final lineCount = viLines.length > paliLines.length ? viLines.length : paliLines.length;

    // Tự sinh timestamps nếu chưa có
    final lineTimestamps = <LineTimestamp>[];
    double currentSec = 0.0;
    for (int i = 1; i <= lineCount; i++) {
      final vi = i - 1 < viLines.length ? viLines[i - 1] : '';
      final pi = i - 1 < paliLines.length ? paliLines[i - 1] : '';
      final dur = 3.0 + (vi.length + pi.length) * 0.05;
      lineTimestamps.add(LineTimestamp(
        line: i,
        start: currentSec,
        end: currentSec + dur,
        text: vi,
        paliText: pi,
      ));
      currentSec += dur;
    }

    // Tự sinh chunks (2 dòng mỗi chunk)
    final chunks = <Chunk>[];
    int chunkIdx = 1;
    for (int i = 1; i <= lineCount; i += 2) {
      final lines = <int>[i];
      if (i + 1 <= lineCount) lines.add(i + 1);
      chunks.add(Chunk(
        index: chunkIdx,
        label: 'Đoạn $chunkIdx',
        lineRange: lines,
        clue: 'Đọc theo nhịp 2 dòng',
      ));
      chunkIdx++;
    }

    final keywords = _keywordsCtrl.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final item = LearnByHeartItem(
      id: widget.initialItem?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      category: _category,
      paliText: paliText,
      vietnameseText: viText,
      shortMeaning: _shortMeaningCtrl.text.trim(),
      keywords: keywords,
      lifeConnection: _lifeConnectionCtrl.text.trim(),
      lineTimestamps: lineTimestamps,
      chunkList: chunks,
      createdAt: widget.initialItem?.createdAt ?? DateTime.now(),
      reviewState: widget.initialItem?.reviewState ?? ReviewState.newItem,
      fsrsParams: widget.initialItem?.fsrsParams ?? const FSRSParams(),
      consecutiveSuccesses: widget.initialItem?.consecutiveSuccesses ?? 0,
      totalReviews: widget.initialItem?.totalReviews ?? 0,
      totalAssessments: widget.initialItem?.totalAssessments ?? 0,
      lapseCount: widget.initialItem?.lapseCount ?? 0,
      nextReviewDate: widget.initialItem?.nextReviewDate,
      lastReviewedAt: widget.initialItem?.lastReviewedAt,
      isFavorite: widget.initialItem?.isFavorite ?? false,
      reviewHistory: widget.initialItem?.reviewHistory ?? const [],
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                    color: const Color(0xFF6C63FF),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Chỉnh sửa bài học thuộc' : 'Thêm bài học thuộc lòng mới',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Picker
                      const Text(
                        'Thể loại',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: RecitationCategory.values.map((cat) {
                          final isSelected = _category == cat;
                          return ChoiceChip(
                            label: Text(cat.displayName),
                            selected: isSelected,
                            selectedColor: cat.color.withValues(alpha: 0.3),
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            labelStyle: TextStyle(
                              color: isSelected ? cat.color : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _category = cat),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Title
                      _buildTextField(
                        controller: _titleCtrl,
                        label: 'Tiêu đề bài kinh / kệ ngôn',
                        hint: 'Ví dụ: Kệ Pháp Cú 01, Bát Nhã Tâm Kinh...',
                        required: true,
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      _buildTextField(
                        controller: _subtitleCtrl,
                        label: 'Phụ đề / Chủ đề ngắn',
                        hint: 'Ví dụ: Tâm dẫn đầu các pháp...',
                      ),
                      const SizedBox(height: 12),

                      // Pali Text
                      _buildTextField(
                        controller: _paliCtrl,
                        label: 'Nguyên văn Pali / Tiếng gốc (mỗi dòng một câu)',
                        hint: 'Manopubbaṅgamā dhammā,\nmanoseṭṭhā manomayā...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),

                      // Vietnamese Text
                      _buildTextField(
                        controller: _viCtrl,
                        label: 'Bản dịch Tiếng Việt (mỗi dòng một câu)',
                        hint: 'Ý dẫn đầu các pháp,\nÝ làm chủ, ý tạo...',
                        maxLines: 4,
                        required: true,
                      ),
                      const SizedBox(height: 12),

                      // Short Meaning
                      _buildTextField(
                        controller: _shortMeaningCtrl,
                        label: 'Ý nghĩa cốt lõi (≤ 15 từ)',
                        hint: 'Hành động từ tâm ô nhiễm đem lại khổ đau.',
                      ),
                      const SizedBox(height: 12),

                      // Keywords
                      _buildTextField(
                        controller: _keywordsCtrl,
                        label: 'Từ khóa ghi nhớ (phân cách bằng dấu phẩy)',
                        hint: 'Ý dẫn đầu, Ý ô nhiễm, Khổ não',
                      ),
                      const SizedBox(height: 12),

                      // Life Connection
                      _buildTextField(
                        controller: _lifeConnectionCtrl,
                        label: 'Liên hệ thực tế đời sống (1 câu)',
                        hint: 'Cẩn trọng trong từng suy nghĩ và lời nói hàng ngày.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(isEditing ? 'Cập nhật' : 'Lưu bài'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${required ? ' *' : ''}',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
      ],
    );
  }
}
