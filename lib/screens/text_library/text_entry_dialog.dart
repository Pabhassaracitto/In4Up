//
// Dialog thêm mới hoặc chỉnh sửa một mục trong thư viện văn bản.
// Dùng cho cả hai trường hợp: entry == null → thêm mới, entry != null → sửa.

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/text_provider.dart';
import '../../services/text_library_service.dart';

class TextEntryDialog extends StatefulWidget {
  final TextLibraryEntry? entry; // null = thêm mới
  final String? initialTitle;
  final String? initialContent;
  final String? initialCategory;
  final bool preferInitialValues;

  const TextEntryDialog({
    super.key,
    this.entry,
    this.initialTitle,
    this.initialContent,
    this.initialCategory,
    this.preferInitialValues = false,
  });

  @override
  State<TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<TextEntryDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _categoryCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final seedTitle = widget.preferInitialValues
        ? (widget.initialTitle ?? widget.entry?.title ?? '')
        : (widget.entry?.title ?? widget.initialTitle ?? '');
    final seedContent = widget.preferInitialValues
        ? (widget.initialContent ?? widget.entry?.content ?? '')
        : (widget.entry?.content ?? widget.initialContent ?? '');
    final seedCategory = widget.preferInitialValues
        ? (widget.initialCategory ?? widget.entry?.category ?? '')
        : (widget.entry?.category ?? widget.initialCategory ?? '');

    _titleCtrl = TextEditingController(text: seedTitle);
    _contentCtrl = TextEditingController(text: seedContent);
    _categoryCtrl = TextEditingController(text: seedCategory);
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final svc = TextLibraryService();
    TextLibraryEntry? result;

    if (_isEditing) {
      // Cập nhật
      final updated = widget.entry!.copyWith(
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        category: _categoryCtrl.text.isEmpty ? null : _categoryCtrl.text,
      );
      final ok = await svc.update(updated);
      result = ok ? updated : null;
    } else {
      // Thêm mới
      result = await svc.add(
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        category: _categoryCtrl.text.isEmpty ? null : _categoryCtrl.text,
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu thất bại. Kiểm tra kết nối mạng.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1520),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────
            _buildHeader(),

            // ── Fields ─────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề
                    const _FieldLabel(label: 'Tiêu đề *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hint: 'VD: Hội thoại tại quầy Check-in',
                        icon: Icons.title,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.uiText('Nhập tiêu đề')
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Chủ đề / Category (tuỳ chọn)
                    const _FieldLabel(label: 'Chủ đề (tuỳ chọn)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _categoryCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hint: 'VD: Du lịch, Kinh doanh, Hội thoại...',
                        icon: Icons.label_outline,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Nội dung
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
                      decoration: _inputDecoration(
                        hint: 'Dán nội dung văn bản vào đây...',
                        icon: Icons.article_outlined,
                      ).copyWith(
                        alignLabelWithHint: true,
                      ),
                      maxLines: 12,
                      minLines: 6,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nhập nội dung'
                          : null,
                    ),

                    // Word count hint
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _contentCtrl,
                      builder: (_, val, __) {
                        final wc = val.text
                            .split(RegExp(r'\s+'))
                            .where((w) => w.isNotEmpty)
                            .length;
                        final lc = val.text
                            .split('\n')
                            .where((l) => l.trim().isNotEmpty)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            context.uiText('$wc từ · $lc dòng'),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Actions ────────────────────────────────────
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF2196F3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isEditing ? Icons.edit_note : Icons.post_add,
              color: const Color(0xFF2196F3),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Chỉnh sửa văn bản' : 'Thêm văn bản mới',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Cancel
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Save
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2196F3).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isEditing
                                  ? Icons.save
                                  : Icons.cloud_upload_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isEditing ? 'Lưu' : 'Lưu lên Cloud',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: context.uiText(hint),
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
        borderSide: const BorderSide(color: Color(0xFF2196F3)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
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
        letterSpacing: 0.3,
      ),
    );
  }
}
