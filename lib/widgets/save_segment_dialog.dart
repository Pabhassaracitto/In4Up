import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../models/segment.dart';

class SaveSegmentDialog extends StatefulWidget {
  const SaveSegmentDialog({super.key});

  @override
  State<SaveSegmentDialog> createState() => _SaveSegmentDialogState();
}

class _SaveSegmentDialogState extends State<SaveSegmentDialog> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  SegmentType _selectedType = SegmentType.favorite;
  DifficultyLevel _selectedDifficulty = DifficultyLevel.medium;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                const Icon(Icons.bookmark_add, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Lưu đoạn này',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Loop Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeInfo('Bắt đầu', player.loopStart),
                  const Icon(Icons.arrow_forward, color: Colors.white54),
                  _buildTimeInfo('Kết thúc', player.loopEnd),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDuration(player.loopDuration ?? Duration.zero),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input Title
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tên đoạn *',
                hintText: 'Ví dụ: Tứ Diệu Đế, Câu khó số 1...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.title, color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Type Selection
            const Text(
              'Phân loại:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SegmentType.values.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getTypeColor(type)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _getTypeColor(type) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getTypeEmoji(type),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getTypeLabel(type),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Difficulty Selection
            const Text(
              'Độ khó (Số lần lặp khi ôn tập):',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: DifficultyLevel.values.map((level) {
                final isSelected = _selectedDifficulty == level;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDifficulty = level),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getDifficultyColor(level)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? _getDifficultyColor(level)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _getDifficultyEmoji(level),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getDifficultyLabel(level),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_getRepeatCount(level)}x lặp',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Note Input
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Ghi chú (Tùy chọn)',
                hintText: 'Ví dụ: Chú ý phát âm "th"...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.note, color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saveSegment,
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu đoạn', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, Duration? time) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          time != null ? _formatDuration(time) : '--:--',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getTypeEmoji(SegmentType type) {
    switch (type) {
      case SegmentType.dharma: return '☸️';
      case SegmentType.english: return '🇬🇧';
      case SegmentType.practice: return '🏋️';
      case SegmentType.favorite: return '⭐';
    }
  }

  String _getTypeLabel(SegmentType type) {
    switch (type) {
      case SegmentType.dharma: return 'Pháp thoại';
      case SegmentType.english: return 'Tiếng Anh';
      case SegmentType.practice: return 'Luyện tập';
      case SegmentType.favorite: return 'Yêu thích';
    }
  }

  Color _getTypeColor(SegmentType type) {
    switch (type) {
      case SegmentType.dharma: return Colors.amber;
      case SegmentType.english: return Colors.green;
      case SegmentType.practice: return Colors.blue;
      case SegmentType.favorite: return Colors.purple;
    }
  }

  String _getDifficultyEmoji(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy: return '😊';
      case DifficultyLevel.medium: return '🤔';
      case DifficultyLevel.hard: return '😤';
    }
  }

  String _getDifficultyLabel(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy: return 'Dễ';
      case DifficultyLevel.medium: return 'Vừa';
      case DifficultyLevel.hard: return 'Khó';
    }
  }

  Color _getDifficultyColor(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy: return Colors.green;
      case DifficultyLevel.medium: return Colors.orange;
      case DifficultyLevel.hard: return Colors.red;
    }
  }

  int _getRepeatCount(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy: return 1;
      case DifficultyLevel.medium: return 3;
      case DifficultyLevel.hard: return 5;
    }
  }

  void _saveSegment() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên đoạn!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final player = context.read<PlayerProvider>();
    final segment = player.saveLoopAsSegment(
      title: title,
      type: _selectedType,
      difficulty: _selectedDifficulty,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    Navigator.pop(context);

    if (segment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Đã lưu: ${segment.title}')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}