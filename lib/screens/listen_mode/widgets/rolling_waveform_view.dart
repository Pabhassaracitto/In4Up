// in4up1.0 — View với speakerColorMap parameter

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../controllers/rolling_waveform_controller.dart';
import 'rolling_waveform_painter.dart';

class RollingWaveformView extends StatefulWidget {
  final RollingWaveformController controller;
  final double height;
  final Function(Duration)? onSeek;
  final Function(Duration)? onSeekUpdate;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Function(Duration)? onLongPressPosition;
  final bool showControls;

  /// Speaker map: key = joinKey|uid → speakerId (0–4)
  /// Default {} = mono-color (backward compatible)
  final Map<String, int> speakerColorMap;

  const RollingWaveformView({
    super.key,
    required this.controller,
    this.height = 200,
    this.onSeek,
    this.onSeekUpdate,
    this.onTap,
    this.onDoubleTap,
    this.onLongPressPosition,
    this.showControls = true,
    this.speakerColorMap = const {},
  });

  @override
  State<RollingWaveformView> createState() => _RollingWaveformViewState();
}

class _RollingWaveformViewState extends State<RollingWaveformView> {
  Duration? _dragStart;
  double? _dragStartX;
  bool _isDragging = false;

  Duration _xToPos(double x) {
    final rb = context.findRenderObject() as RenderBox?;
    if (rb == null) return Duration.zero;
    final w = rb.size.width;
    if (w <= 0) return Duration.zero;

    final visMs = widget.controller.visibleDuration.inMilliseconds;
    if (visMs == 0) return Duration.zero;

    final msPerPx = visMs / w;
    final delta = (x - w / 2) * msPerPx;
    final target = (widget.controller.position.inMilliseconds + delta)
        .round()
        .clamp(0, widget.controller.duration.inMilliseconds);

    return Duration(milliseconds: target);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTap?.call(),
      onDoubleTap: () => (widget.onDoubleTap ?? widget.onTap)?.call(),
      onLongPressStart: (d) {
        if (_isDragging) return;
        widget.onLongPressPosition?.call(_xToPos(d.localPosition.dx));
      },
      onHorizontalDragStart: (d) {
        _isDragging = true;
        _dragStart = widget.controller.position;
        _dragStartX = d.localPosition.dx;
      },
      onHorizontalDragUpdate: (d) {
        if (_dragStart == null || _dragStartX == null) return;
        final rb = context.findRenderObject() as RenderBox?;
        if (rb == null) return;
        final w = rb.size.width;
        if (w <= 0) return;

        final deltaX = d.localPosition.dx - _dragStartX!;
        final visMs = widget.controller.visibleDuration.inMilliseconds;
        final deltaMs = -(deltaX * visMs / w);
        final target = (_dragStart!.inMilliseconds + deltaMs)
            .round()
            .clamp(0, widget.controller.duration.inMilliseconds);

        final pos = Duration(milliseconds: target);
        widget.controller.updatePosition(pos);
        widget.onSeekUpdate?.call(pos);
      },
      onHorizontalDragEnd: (_) {
        if (_isDragging) {
          widget.onSeek?.call(widget.controller.position);
        }
        _isDragging = false;
        _dragStart = null;
        _dragStartX = null;
      },
      onHorizontalDragCancel: () {
        if (_isDragging) {
          widget.onSeek?.call(widget.controller.position);
        }
        _isDragging = false;
        _dragStart = null;
        _dragStartX = null;
      },
      child: SizedBox(
        height: widget.height,
        child: Column(
          children: [
            Expanded(
              child: Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) {
                    widget.controller.setZoom(
                      widget.controller.zoom + e.scrollDelta.dy * -0.001,
                    );
                  }
                },
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (_, __) => RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: RollingWaveformPainter(
                        controller: widget.controller,
                        speakerColorMap: widget.speakerColorMap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 18),
            color: Colors.white70,
            onPressed: () =>
                widget.controller.setZoom(widget.controller.zoom * 0.8),
          ),
          Expanded(
            child: Slider(
              value: widget.controller.zoom,
              min: 0.5,
              max: 10.0,
              divisions: 19,
              activeColor: const Color(0xFF6C63FF),
              onChanged: widget.controller.setZoom,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 18),
            color: Colors.white70,
            onPressed: () =>
                widget.controller.setZoom(widget.controller.zoom * 1.25),
          ),
          AnimatedBuilder(
            animation: widget.controller,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
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
