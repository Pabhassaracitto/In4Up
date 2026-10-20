// lib/widgets/pulsing_icon.dart
//
// Icon "đang phát" — nhấp nháy nhẹ (scale) để user **thấy ngay** app đang
// phát âm thanh, thay vì bấm xong mà không biết có chạy hay không.
//
// AUDIT-2026-10-20 (mục 6, owner): "khi nhấn mà đang phát thì đổi màu hay
// loa chuyển động ngay icon này và khi chạm lần 2 thì nó dừng".
//
// Dùng `Transform.scale` (transform, không phải Opacity/Size) để nhẹ với GPU
// — cùng lý do READ-TOOLBAR-001 bỏ AnimatedSize/AnimatedOpacity.
import 'package:flutter/material.dart';

/// Icon có trạng thái "đang phát": khi [active] = true thì nhấp nháy (scale).
class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  /// Đang phát ⇒ nhấp nháy.
  final bool active;

  /// Biên độ scale (1.0 = không đổi).
  final double maxScale;

  final Duration duration;

  const PulsingIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 22,
    this.active = false,
    this.maxScale = 1.16,
    this.duration = const Duration(milliseconds: 850),
  });

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: widget.color, size: widget.size);
    if (!widget.active) return icon;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1 + (widget.maxScale - 1) * t,
          child: child,
        );
      },
      child: icon,
    );
  }
}
