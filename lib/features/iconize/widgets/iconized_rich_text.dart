// lib/features/iconize/widgets/iconized_rich_text.dart
//
// ICONIZE-001d — tầng render thuần của Iconize (blueprint Khối B):
// IconizeResult → Text.rich với WidgetSpan icon thay cho từ.
//
// Nguyên tắc:
//  - EPHEMERAL: widget chỉ vẽ, không ghi gì — plain text gốc luôn là
//    nguồn sự thật (nguyên tắc #1 của ADR-0013).
//  - KEEP-TEXT: bất kỳ lỗi nào ở tầng icon (tên không có trong bundle,
//    file ảnh user đã bị xóa, SVG hỏng) → render LẠI CHỮ, không ô vuông
//    trống, không throw.
//  - A11y: mỗi icon bọc Semantics(label: từ gốc, image: true) — screen
//    reader đọc ĐÚNG TỪ, không đọc "hình ảnh" (blueprint nguyên tắc #6).
//  - Tap icon → tooltip hiện từ gốc (neo nghĩa ngay khi user quên).
//
// [iconBuilderOverride] cho widget test: thay SvgPicture/Image.file bằng
// widget giả — test cấu trúc span không cần decode SVG thật.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/iconize_binary.dart';
import '../models/iconize_span.dart';

typedef IconizeIconBuilder = Widget? Function(
    BuildContext context, IconizeSpan span, double size);

class IconizedRichText extends StatelessWidget {
  final IconizeResult result;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Bundle Twemoji để tra "bundle:<tên>" → bytes SVG; null → mọi span
  /// bundle giữ chữ (an toàn khi engine chưa sẵn sàng).
  final IconsBundle? iconsBundle;

  /// Test-only: thay widget icon thật. Trả null = rơi về giữ chữ.
  final IconizeIconBuilder? iconBuilderOverride;

  const IconizedRichText({
    super.key,
    required this.result,
    this.style,
    this.maxLines,
    this.overflow,
    this.iconsBundle,
    this.iconBuilderOverride,
  });

  @override
  Widget build(BuildContext context) {
    final text = result.plainText;
    if (result.spans.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final iconSize = ((style?.fontSize) ?? 14.0) * 1.3;
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final span in result.spans) {
      if (span.start < cursor || span.end > text.length) continue; // hỏng → bỏ
      if (span.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, span.start)));
      }
      final icon = _buildIcon(context, span, iconSize);
      children.add(
        icon == null
            ? TextSpan(text: span.surfaceForm)
            : WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Semantics(
                  label: span.surfaceForm,
                  image: true,
                  child: Tooltip(
                    message: span.surfaceForm,
                    triggerMode: TooltipTriggerMode.tap,
                    child: icon,
                  ),
                ),
              ),
      );
      cursor = span.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: children),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Widget icon cho span — null = giữ chữ.
  Widget? _buildIcon(BuildContext context, IconizeSpan span, double size) {
    final override = iconBuilderOverride;
    if (override != null) return override(context, span, size);

    final ref = span.iconAssetRef;
    if (ref == null) return null;

    if (ref.startsWith('bundle:')) {
      final bundle = iconsBundle;
      if (bundle == null) return null;
      final id = bundle.idForName(ref.substring('bundle:'.length));
      if (id == null) return null;
      try {
        return SvgPicture.memory(
          bundle.svgBytes(id),
          width: size,
          height: size,
        );
      } catch (_) {
        return null; // TOC hỏng giữa chừng → giữ chữ
      }
    }

    if (ref.startsWith('file:')) {
      final path = ref.substring('file:'.length);
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Ảnh user đã bị xóa sau khi map được dựng → giữ chữ.
        errorBuilder: (_, __, ___) => Text(span.surfaceForm, style: style),
      );
    }

    return null; // ref lạ (CDN tier chưa kích hoạt) → giữ chữ
  }
}
