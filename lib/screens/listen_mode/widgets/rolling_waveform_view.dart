// lib/screens/listen_mode/widgets/rolling_waveform_view.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../controllers/rolling_waveform_controller.dart';
import 'rolling_waveform_painter.dart';

class RollingWaveformView extends StatefulWidget {
  final RollingWaveformController controller;
  final double height;
  final Function(Duration)? onSeek;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Function(Duration)? onLongPressPosition;
  final bool showControls;

  const RollingWaveformView({
    super.key,
    required this.controller,
    this.height = 200,
    this.onSeek,
    this.onTap,
    this.onDoubleTap,
    this.onLongPressPosition,
    this.showControls = true,
  });

  @override
  State<RollingWaveformView> createState() => _RollingWaveformViewState();
}

class _RollingWaveformViewState extends State<RollingWaveformView> {
  Duration? _dragStartPosition;
  double? _dragStartX;
  bool _isDragging = false;

  // ── Map x → Duration (đúng sign convention với drag seek) ──
  Duration _xToPosition(double x) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return Duration.zero;
    final width = renderBox.size.width;
    if (width <= 0) return Duration.zero;

    final playheadX = width / 2;
    final visibleMs = widget.controller.visibleDuration.inMilliseconds;
    if (visibleMs == 0) return Duration.zero;

    final msPerPixel = visibleMs / width;

    final deltaMs = (x - playheadX) * msPerPixel;

    final targetMs = (widget.controller.position.inMilliseconds + deltaMs)
        .round()
        .clamp(0, widget.controller.duration.inMilliseconds);

    return Duration(milliseconds: targetMs);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTap?.call(),

      // ★ SỬA 2: Double tap — chỉ gọi callback, KHÔNG toggle visibility
      onDoubleTap: () => (widget.onDoubleTap ?? widget.onTap)?.call(),

      onLongPressStart: (details) {
        if (_isDragging) return;
        final pos = _xToPosition(details.localPosition.dx);
        widget.onLongPressPosition?.call(pos);
      },

      onHorizontalDragStart: (details) {
        _isDragging = true;
        _dragStartPosition = widget.controller.position;
        _dragStartX = details.localPosition.dx;
      },

      onHorizontalDragUpdate: (details) {
        if (widget.onSeek == null) return;
        if (_dragStartPosition == null || _dragStartX == null) return;

        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final screenWidth = renderBox.size.width;
        if (screenWidth <= 0) return;

        final deltaX = details.localPosition.dx - _dragStartX!;
        final visibleMs = widget.controller.visibleDuration.inMilliseconds;
        final msPerPixel = visibleMs / screenWidth;

        final deltaMs = -deltaX * msPerPixel;

        final targetMs = (_dragStartPosition!.inMilliseconds + deltaMs)
            .round()
            .clamp(0, widget.controller.duration.inMilliseconds);

        widget.onSeek?.call(Duration(milliseconds: targetMs));
      },

      onHorizontalDragEnd: (_) {
        _isDragging = false;
        _dragStartPosition = null;
        _dragStartX = null;
      },

      onHorizontalDragCancel: () {
        _isDragging = false;
        _dragStartPosition = null;
        _dragStartX = null;
      },

      // ★ SỬA 3: Luôn hiện — SizedBox thay AnimatedContainer
      child: SizedBox(
        height: widget.height,
        child: Column(
          children: [
            // Waveform canvas
            Expanded(
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final newZoom =
                        widget.controller.zoom + event.scrollDelta.dy * -0.001;
                    widget.controller.setZoom(newZoom);
                  }
                },
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, child) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: RollingWaveformPainter(
                          controller: widget.controller,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Controls (giữ nguyên, điều khiển bằng showControls)
            if (widget.showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  // ★ GIỮ NGUYÊN _buildControls() — không xóa, không sửa
  Widget _buildControls() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 18),
            onPressed: () =>
                widget.controller.setZoom(widget.controller.zoom * 0.8),
            color: Colors.white70,
          ),
          Expanded(
            child: Slider(
              value: widget.controller.zoom,
              min: 0.5,
              max: 10.0,
              divisions: 19,
              onChanged: widget.controller.setZoom,
              activeColor: const Color(0xFF6C63FF),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 18),
            onPressed: () =>
                widget.controller.setZoom(widget.controller.zoom * 1.25),
            color: Colors.white70,
          ),
          const SizedBox(width: 16),
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.controller.zoom.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
