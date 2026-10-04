import 'dart:io';

// localized_material = material.dart (hide Text) + Text/uiText đã locale-hóa.
// Rule #5 (AGENTS.md): chrome không được để tiếng Việt ở locale ≠ vi.
import '../../core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../providers/vocabulary_provider.dart';
import 'vocab_image_picker_sheet.dart';
import 'vocab_image_service.dart';

/// Widget hiển thị + chọn hình ảnh cho từ vựng.
///
/// IMG-WEB-001: một chạm mở [VocabImagePickerSheet] — tab mặc định là TÌM ẢNH
/// TRÊN MẠNG (Pexels/Unsplash qua API key, fallback Openverse/Wikimedia
/// Commons), vì gallery máy gần như không có sẵn ảnh minh họa cho từ. Ảnh
/// trong máy vẫn là đường thứ hai trong sheet. Chạm giữ (long press) = bỏ ảnh.
class VocabImagePicker extends StatefulWidget {
  final String? wordId;

  /// Từ đang sửa — dùng làm từ khóa tìm ảnh (ưu tiên ảnh trên mạng).
  final String? word;

  /// Nghĩa của từ — ghép vào từ khóa khi từ đơn nghĩa mơ hồ.
  final String? meaning;

  final String? currentImageUrl;
  final ValueChanged<String?> onImageChanged;
  final double size;

  const VocabImagePicker({
    super.key,
    this.wordId,
    this.word,
    this.meaning,
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

  bool get _hasRemoteUrl {
    final url = widget.currentImageUrl ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Future<void> _openPicker() async {
    final result = await VocabImagePickerSheet.show(
      context,
      word: widget.word,
      meaning: widget.meaning,
      hasExistingImage:
          (widget.currentImageUrl ?? '').isNotEmpty || _hasRemoteUrl,
    );
    if (!mounted || result == null) return;

    if (result.removed) {
      await _apply(null);
      return;
    }
    final path = result.imagePath;
    if (path == null || path.isEmpty) return;
    await _apply(path);
  }

  /// Ghi path vào provider (nếu có wordId) + báo caller + nạp lại ảnh.
  Future<void> _apply(String? path) async {
    setState(() {
      _isLoading = path != null;
      _localImagePath = null;
    });
    widget.onImageChanged(path);

    if (widget.wordId != null) {
      context
          .read<VocabularyProvider>()
          .updateImageUrl(widget.wordId!, path);
    }

    if (path == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final resolved = await VocabImageService.instance.resolvePath(path);
    if (!mounted) return;
    setState(() {
      _localImagePath = resolved;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: _openPicker,
      onLongPress:
          (_localImagePath != null || _hasRemoteUrl) ? () => _apply(null) : null,
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
                ? _buildImage(
                    context,
                    child: Image.file(
                      File(_localImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(
                        context,
                        icon: Icons.broken_image,
                        label: context.uiText('Lỗi ảnh'),
                      ),
                    ),
                    removable: true,
                  )
                : _hasRemoteUrl
                    ? _buildImage(
                        context,
                        child: Image.network(
                          widget.currentImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(
                            context,
                            icon: Icons.broken_image,
                            label: context.uiText('Lỗi ảnh'),
                          ),
                        ),
                        removable: true,
                      )
                    : _buildPlaceholder(
                        context,
                        icon: Icons.public,
                        label: context.uiText('Thêm ảnh'),
                      ),
      ),
    );
  }

  Widget _buildImage(
    BuildContext context, {
    required Widget child,
    required bool removable,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (removable)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _apply(null),
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
