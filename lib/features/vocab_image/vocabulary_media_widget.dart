// lib/features/vocab_image/vocabulary_media_widget.dart
//
// LOTTIE-001 — Widget minh họa từ vựng HYBRID: nhận `imageUrl` (relative
// path local HOẶC URL http), TỰ phân loại và render đúng:
//
//   • Lottie local (*.json/*.lottie)   → Lottie.file
//   • Lottie http                      → Lottie.network + materialize nền
//   • Ảnh tĩnh local                   → Image.file (kế thừa VocabImageThumbnail)
//   • Ảnh tĩnh http                    → Image.network + materialize nền
//
// "Materialize nền" = tải về app storage (VocabImageService) rồi chuyển
// widget sang file local + báo caller qua [onMaterialized] để ghi path mới
// vào WordEntry/MemoryItem → lần xem sau chạy hoàn toàn OFFLINE (offline-first
// giống hệ ảnh tĩnh hiện có của dự án).
//
// QUY TẮC HIỆU NĂNG (bắt buộc theo blueprint docs/lottie_flashcard_plan.md):
//   • ListView/tile: truyền animate=false → Lottie đứng frame đầu, 0 ticker.
//   • Chỉ flashcard/màn chi tiết animate=true; 1 thẻ animate tại 1 thởi điểm.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'vocab_image_service.dart';
import 'vocab_media_type.dart';

class VocabularyMediaWidget extends StatefulWidget {
  /// `WordEntry.imageUrl` / `MemoryItem.imageUrl`: relative path local hoặc
  /// URL http(s). null/rỗng → widget thu về SizedBox.shrink().
  final String? imageUrl;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// false = Lottie đứng yên frame đầu (dùng trong danh sách).
  final bool animate;

  /// true = Lottie lặp vô hạn; false = chạy 1 lần (vd lật thẻ).
  final bool repeat;

  final BorderRadius? borderRadius;

  /// URL http vừa được tải về local xong → caller lưu path mới vào model
  /// (VocabularyProvider.updateImageUrl / MemoryController.updateImageUrl).
  final ValueChanged<String>? onMaterialized;

  const VocabularyMediaWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.animate = true,
    this.repeat = true,
    this.borderRadius,
    this.onMaterialized,
  });

  @override
  State<VocabularyMediaWidget> createState() => _VocabularyMediaWidgetState();
}

class _VocabularyMediaWidgetState extends State<VocabularyMediaWidget> {
  /// URL http đang được tải về trong phiên — chống tải trùng khi nhiều
  /// widget cùng hiển thị 1 link (trang chi tiết + flashcard…).
  static final Set<String> _inFlight = <String>{};

  /// Absolute path local sau khi resolve (null = chưa xong / giá trị là URL).
  String? _resolvedPath;

  /// Đã resolve xong (kết quả có thể null = file mất) → đổi spinner → icon lỗi.
  bool _resolveDone = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(VocabularyMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedPath = null;
      _resolveDone = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final raw = (widget.imageUrl ?? '').trim();
    if (raw.isEmpty) {
      _resolveDone = true;
      return;
    }
    if (isNetworkMediaUrl(raw)) {
      // Hiển thị trực tiếp từ mạng ngay; materialize chạy nền sau.
      unawaited(_materialize(raw));
      _resolveDone = true;
      if (mounted) setState(() {});
      return;
    }
    final path = await VocabImageService.instance.resolvePath(raw);
    if (!mounted) return;
    setState(() {
      _resolvedPath = path;
      _resolveDone = true;
    });
  }

  /// Tải media ngoài mạng về app storage, chuyển render sang file local và
  /// báo caller cập nhật path vào DB (offline cho lần sau).
  Future<void> _materialize(String url) async {
    if (widget.onMaterialized == null) return;
    if (!_inFlight.add(url)) return;
    try {
      final relative = await VocabImageService.instance.saveFromUrl(url);
      if (relative == null || relative.isEmpty) return;
      final abs = await VocabImageService.instance.resolvePath(relative);
      if (!mounted) return;
      if (abs != null) setState(() => _resolvedPath = abs);
      widget.onMaterialized?.call(relative);
    } finally {
      _inFlight.remove(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = (widget.imageUrl ?? '').trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    final local = _resolvedPath;
    Widget child;
    if (local != null) {
      // File local: phân loại theo ĐUÔI FILE THỰC TẾ trên đĩa (URL gốc có
      // thể đuôi lạ nhưng service đã lưu đúng extension theo magic bytes).
      child = isLottieMediaUrl(local)
          ? Lottie.file(
              File(local),
              key: ValueKey('lottie-file:$local'),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              animate: widget.animate,
              repeat: widget.repeat,
              frameBuilder: _lottieLoading,
              errorBuilder: _lottieBroken,
            )
          : Image.file(
              File(local),
              fit: widget.fit,
              errorBuilder: _imageBroken,
            );
    } else if (isNetworkMediaUrl(raw)) {
      child = isLottieMediaUrl(raw)
          ? Lottie.network(
              raw,
              key: ValueKey('lottie-net:$raw'),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              animate: widget.animate,
              repeat: widget.repeat,
              frameBuilder: _lottieLoading,
              errorBuilder: _lottieBroken,
            )
          : Image.network(
              raw,
              fit: widget.fit,
              errorBuilder: _imageBroken,
              loadingBuilder: _imageLoading,
            );
    } else {
      // Relative path: đang chờ resolve (spinner) hoặc file đã mất (icon lỗi).
      child = _resolveDone ? _brokenIcon(context) : _spinner(context);
    }

    final radius = widget.borderRadius;
    if (radius != null) {
      child = ClipRRect(borderRadius: radius, child: child);
    }
    return SizedBox(width: widget.width, height: widget.height, child: child);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Widget _lottieLoading(
    BuildContext context,
    Widget child,
    LottieComposition? composition,
  ) {
    // composition == null → network/file chưa parse xong.
    return composition == null ? _spinner(context) : child;
  }

  Widget _lottieBroken(BuildContext context, Object error, StackTrace? stack) =>
      _brokenIcon(context);

  Widget _imageBroken(
    BuildContext context,
    Object error,
    StackTrace? stack,
  ) =>
      _brokenIcon(context);

  Widget _imageLoading(
    BuildContext context,
    Widget child,
    ImageChunkEvent? progress,
  ) =>
      progress == null ? child : _spinner(context);

  Widget _spinner(BuildContext context) => Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );

  Widget _brokenIcon(BuildContext context) {
    final h = widget.height;
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: (h != null && h < 64) ? 16 : 24,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
