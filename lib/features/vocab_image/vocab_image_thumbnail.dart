import 'dart:io';

import 'package:flutter/material.dart';

import 'vocab_image_service.dart';
import 'vocab_media_type.dart';
import 'vocabulary_media_widget.dart';

/// Widget hiển thị thumbnail hình ảnh từ vựng (compact, dùng trong list)
class VocabImageThumbnail extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const VocabImageThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.borderRadius,
    this.onTap,
  });

  @override
  State<VocabImageThumbnail> createState() => _VocabImageThumbnailState();
}

class _VocabImageThumbnailState extends State<VocabImageThumbnail> {
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(VocabImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final path = await VocabImageService.instance.resolvePath(widget.imageUrl);
    if (mounted) setState(() => _resolvedPath = path);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final radius = widget.borderRadius ?? BorderRadius.circular(8);

    // LOTTIE-IMPORT-002 (audit mục 2): thumbnail cũ chỉ biết `Image.file`
    // nên một animation Lottie đã lưu thành công vẫn hiện icon "ảnh hỏng"
    // trong danh sách từ — người dùng tưởng import thất bại. Lottie giao
    // cho VocabularyMediaWidget (animate: false = đứng frame đầu, 0 ticker
    // trong ListView theo blueprint hiệu năng).
    if (isLottieMediaUrl(widget.imageUrl)) {
      final media = VocabularyMediaWidget(
        imageUrl: widget.imageUrl,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        animate: false,
        repeat: false,
        borderRadius: radius,
      );
      return widget.onTap == null
          ? media
          : GestureDetector(onTap: widget.onTap, child: media);
    }

    final image = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: _resolvedPath != null
          ? Image.file(
              File(_resolvedPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image,
                size: widget.size * 0.4,
                color: Colors.grey,
              ),
            )
          : Center(
              child: SizedBox(
                width: widget.size * 0.3,
                height: widget.size * 0.3,
                child: const CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
    );

    if (widget.onTap != null) {
      return GestureDetector(onTap: widget.onTap, child: image);
    }
    return image;
  }
}
