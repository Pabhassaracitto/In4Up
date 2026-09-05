import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/localized_material.dart';
import '../../providers/vocabulary_provider.dart';
import 'vocab_image_service.dart';

/// Widget hiển thị và cho phép chọn hình ảnh cho từ vựng
class VocabImagePicker extends StatefulWidget {
  final String? wordId;
  final String? currentImageUrl;
  final ValueChanged<String?> onImageChanged;
  final double size;

  const VocabImagePicker({
    super.key,
    this.wordId,
    required this.currentImageUrl,
    required this.onImageChanged,
    this.size = 120,
  });

  @override
  State<VocabImagePicker> createState() => _VocabImagePickerState();
}

class _VocabImagePickerState extends State<VocabImagePicker> {
  String? _localImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(VocabImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentImageUrl != widget.currentImageUrl) {
      _resolveImage();
    }
  }

  Future<void> _resolveImage() async {
    final path = await VocabImageService.instance
        .resolvePath(widget.currentImageUrl);
    if (mounted) setState(() => _localImagePath = path);
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);
    try {
      final path = await VocabImageService.instance.pickFromGallery();
      if (path != null) {
        setState(() => _localImagePath = null);
        widget.onImageChanged(path);

        // Cập nhật provider nếu có wordId
        if (widget.wordId != null && mounted) {
          context.read<VocabularyProvider>().updateImageUrl(widget.wordId!, path);
        }

        // Resolve path để hiển thị
        final resolved = await VocabImageService.instance.resolvePath(path);
        if (mounted) setState(() => _localImagePath = resolved);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _localImagePath = null;
      _isLoading = false;
    });
    widget.onImageChanged(null);

    if (widget.wordId != null) {
      context.read<VocabularyProvider>().updateImageUrl(widget.wordId!, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: _pickImage,
      onLongPress: _localImagePath != null ? _removeImage : null,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1.5,
          ),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        clipBehavior: Clip.antiAlias,
        child: _isLoading
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              )
            : _localImagePath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(_localImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(
                          context,
                          icon: Icons.broken_image,
                          label: context.uiText('Lỗi ảnh', 'Image error'),
                        ),
                      ),
                      // Nút xóa
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _removeImage,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildPlaceholder(
                    context,
                    icon: Icons.add_photo_alternate_outlined,
                    label: context.uiText('Thêm ảnh', 'Add image'),
                  ),
      ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 28, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
