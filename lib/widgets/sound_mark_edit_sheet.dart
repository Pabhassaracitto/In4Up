// lib/widgets/sound_mark_edit_sheet.dart
// Sheet tạo / sửa một "Điểm" trong Âm mục (Soundlist).
// Dùng chung cho nút "Dấu" trong Listen Mode và panel Âm mục.

import 'package:flutter/material.dart';

import '../models/sound_mark.dart';
import '../providers/soundlist_provider.dart';

/// Hiển thị sheet tạo điểm mới tại [position].
/// Trả về [SoundMark] vừa tạo (hoặc null nếu hủy).
Future<SoundMark?> showCreateMarkSheet(
  BuildContext context, {
  required SoundlistProvider soundlist,
  required String audioPath,
  required Duration position,
}) {
  return showModalBottomSheet<SoundMark>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SoundMarkEditSheet(
      soundlist: soundlist,
      audioPath: audioPath,
      createPosition: position,
    ),
  );
}

/// Hiển thị sheet sửa một điểm có sẵn.
Future<SoundMark?> showEditMarkSheet(
  BuildContext context, {
  required SoundlistProvider soundlist,
  required SoundMark mark,
}) {
  return showModalBottomSheet<SoundMark>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SoundMarkEditSheet(
      soundlist: soundlist,
      existing: mark,
    ),
  );
}

class _SoundMarkEditSheet extends StatefulWidget {
  final SoundlistProvider soundlist;
  final String? audioPath;
  final Duration? createPosition;
  final SoundMark? existing;

  const _SoundMarkEditSheet({
    required this.soundlist,
    this.audioPath,
    this.createPosition,
    this.existing,
  }) : assert(existing != null || (audioPath != null && createPosition != null));

  @override
  State<_SoundMarkEditSheet> createState() => _SoundMarkEditSheetState();
}

class _SoundMarkEditSheetState extends State<_SoundMarkEditSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;
  late SoundMarkKind _kind;
  late List<String> _tags;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final pos = existing?.position ?? widget.createPosition!;
    _labelController =
        TextEditingController(text: existing?.label ?? SoundMark.defaultLabel(pos));
    _noteController = TextEditingController(text: existing?.note ?? '');
    _tagController = TextEditingController();
    _kind = existing?.kind ?? SoundMarkKind.other;
    _tags = List.of(existing?.tags ?? const []);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    final note = _noteController.text.trim();
    final mark = widget.existing;
    final soundlist = widget.soundlist;

    if (mark != null) {
      final updated = mark.copyWith(
        label: label.isEmpty ? mark.label : label,
        note: note.isEmpty ? null : note,
        tags: List.of(_tags),
        kind: _kind,
      );
      await soundlist.updateMark(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      final created = await soundlist.addMark(
        audioPath: widget.audioPath!,
        position: widget.createPosition!,
        kind: _kind,
        label: label,
        note: note.isEmpty ? null : note,
        tags: List.of(_tags),
      );
      if (mounted) Navigator.pop(context, created);
    }
  }

  void _addTag() {
    final t = _tagController.text.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!_tags.contains(t)) _tags.add(t);
      _tagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final pos = widget.existing?.position ?? widget.createPosition!;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E2235),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _kind.icon,
                    color: _kind.color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Sửa điểm · ${SoundMark.formatTime(pos)}' : 'Đánh dấu · ${SoundMark.formatTime(pos)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
                      onPressed: () async {
                        await widget.soundlist.deleteMark(widget.existing!.id);
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Loại ──
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: SoundMarkKind.values.map((k) {
                  final selected = _kind == k;
                  return ChoiceChip(
                    selected: selected,
                    avatar: Icon(k.icon, size: 15, color: selected ? Colors.black : k.color),
                    label: Text(k.label, style: TextStyle(fontSize: 12)),
                    selectedColor: k.color,
                    backgroundColor: const Color(0xFF2A3050),
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : Colors.white70,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                    onSelected: (_) => setState(() => _kind = k),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // ── Nhãn ──
              TextField(
                controller: _labelController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('Nhãn (VD: "Tứ niệm xứ", "Câu 3 khó")'),
              ),
              const SizedBox(height: 10),

              // ── Ghi chú ──
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 3,
                minLines: 1,
                decoration: _inputDecoration('Ghi chú thêm…'),
              ),
              const SizedBox(height: 10),

              // ── Tag ──
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags.map((t) {
                      return Chip(
                        label: Text('#$t', style: const TextStyle(fontSize: 12)),
                        labelStyle: const TextStyle(color: Colors.white),
                        backgroundColor: const Color(0xFF6C63FF),
                        deleteIconColor: Colors.white70,
                        onDeleted: () => setState(() => _tags.remove(t)),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _inputDecoration('Thêm tag (enter)'),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addTag,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Lưu ──
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _save,
                  child: const Text(
                    'Lưu điểm',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF2A3050),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}
