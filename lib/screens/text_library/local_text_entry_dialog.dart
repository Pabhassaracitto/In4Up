import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/text_provider.dart';

class LocalTextDraft {
  final String title;
  final String content;
  final String? category;
  final bool uploadToCloud;

  const LocalTextDraft({
    required this.title,
    required this.content,
    this.category,
    this.uploadToCloud = false,
  });
}

class LocalTextEntryDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final String? initialCategory;
  final bool allowUploadToCloud;
  final bool initialUploadToCloud;
  final String titleText;
  final String confirmText;

  const LocalTextEntryDialog({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.initialCategory,
    this.allowUploadToCloud = false,
    this.initialUploadToCloud = false,
    this.titleText = 'Nhập văn bản thủ công',
    this.confirmText = 'Nạp vào Đọc',
  });

  @override
  State<LocalTextEntryDialog> createState() => _LocalTextEntryDialogState();
}

class _LocalTextEntryDialogState extends State<LocalTextEntryDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _categoryCtrl;
  final _formKey = GlobalKey<FormState>();
  late bool _uploadToCloud;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _contentCtrl = TextEditingController(text: widget.initialContent ?? '');
    _categoryCtrl = TextEditingController(text: widget.initialCategory ?? '');
    _uploadToCloud = widget.allowUploadToCloud && widget.initialUploadToCloud;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    _seedFromContent(text);
  }

  void _fillFromCurrentText() {
    final tp = context.read<TextProvider>();
    final text = tp.fullText.trim().isNotEmpty
        ? tp.fullText.trim()
        : tp.lines.map((e) => e.content).join('\n').trim();
    if (text.isEmpty) return;
    _seedFromContent(
      text,
      preferredTitle: tp.currentDocument?.title,
      preferredCategory: tp.currentTextCategory,
    );
  }

  void _seedFromContent(
    String text, {
    String? preferredTitle,
    String? preferredCategory,
  }) {
    setState(() {
      _contentCtrl.text = text;
      if ((preferredCategory ?? '').trim().isNotEmpty &&
          _categoryCtrl.text.trim().isEmpty) {
        _categoryCtrl.text = preferredCategory!.trim();
      }
      if (_titleCtrl.text.trim().isEmpty) {
        if ((preferredTitle ?? '').trim().isNotEmpty) {
          _titleCtrl.text = preferredTitle!.trim();
        } else {
          final firstLine = text
              .split('\n')
              .map((e) => e.trim())
              .firstWhere((e) => e.isNotEmpty, orElse: () => 'Văn bản mới');
          final clipped = firstLine.length > 48
              ? '${firstLine.substring(0, 48).trim()}...'
              : firstLine;
          _titleCtrl.text = clipped;
        }
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      LocalTextDraft(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty
            ? null
            : _categoryCtrl.text.trim(),
        uploadToCloud: _uploadToCloud,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1520),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_note,
                        color: Color(0xFF26C6DA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel(label: 'Tiêu đề *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hint: 'VD: Nội dung từ AI / ghi chú web',
                          icon: Icons.title,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập tiêu đề'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel(label: 'Chủ đề / Thuộc tính'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _categoryCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hint: 'VD: AI, Du lịch, Hội thoại, Ghi chú...',
                          icon: Icons.label_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const _FieldLabel(label: 'Nội dung *'),
                          TextButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_go_outlined, size: 16),
                            label: const Text('Dán clipboard'),
                          ),
                          TextButton.icon(
                            onPressed: _fillFromCurrentText,
                            icon: const Icon(Icons.copy_all_outlined, size: 16),
                            label: const Text('Lấy văn bản hiện tại'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contentCtrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.6,
                        ),
                        maxLines: 12,
                        minLines: 6,
                        decoration: _inputDecoration(
                          hint: 'Dán hoặc gõ nội dung vào đây...',
                          icon: Icons.article_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập nội dung'
                            : null,
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentCtrl,
                        builder: (_, value, __) {
                          final words = value.text
                              .split(RegExp(r'\s+'))
                              .where((w) => w.isNotEmpty)
                              .length;
                          final lines = value.text
                              .split('\n')
                              .where((l) => l.trim().isNotEmpty)
                              .length;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '$words từ · $lines dòng',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                      if (widget.allowUploadToCloud) ...[
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          value: _uploadToCloud,
                          onChanged: (value) => setState(() => _uploadToCloud = value),
                          activeColor: const Color(0xFF2196F3),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Đồng thời lưu lên cloud',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Giữ nội dung để đọc ngay trên máy và đồng bộ vào thư viện cloud.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save_alt),
                        label: Text(widget.confirmText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey[600], size: 18),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF26C6DA)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
