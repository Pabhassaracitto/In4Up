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
  final Function(Duration)? onLongPressPosition;
  final bool showControls;

  const RollingWaveformView({
    super.key,
    required this.controller,
    this.height = 200,
    this.onSeek,
    this.onTap,
    this.onLongPressPosition,
    this.showControls = true,
  });

  @override
  State<RollingWaveformView> createState() => _RollingWaveformViewState();
}

class _RollingWaveformViewState extends State<RollingWaveformView> {
  final bool _isVisible = true;
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

    // Drag seek dùng: deltaMs = -deltaX * msPerPixel (kéo phải = lùi)
    // Long-press map trực tiếp x → position theo visual:
    // bar tại x < playheadX = quá khứ, x > playheadX = tương lai
    // => dùng dấu THUẬN (không đảo) vì đây là "nhảy đến vị trí này trên màn hình"
    final deltaMs = (x - playheadX) * msPerPixel;

    final targetMs = (widget.controller.position.inMilliseconds + deltaMs)
        .round()
        .clamp(0, widget.controller.duration.inMilliseconds);

    return Duration(milliseconds: targetMs);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap: play/pause
      onTap: () => widget.onTap?.call(),

      /*// Double tap: ẩn/hiện waveform
      onDoubleTap: () => setState(() => _isVisible = !_isVisible),
*/
      // Double tap: reset zoom
      onDoubleTap: () => widget.controller.setZoom(1.0),
      // Long press: action sheet
      onLongPressStart: (details) {
        if (_isDragging) return; // Block long-press khi đang drag seek
        final pos = _xToPosition(details.localPosition.dx);
        widget.onLongPressPosition?.call(pos);
      },

      // Drag start
      onHorizontalDragStart: (details) {
        _isDragging = true;
        _dragStartPosition = widget.controller.position;
        _dragStartX = details.localPosition.dx;
      },

      // Drag update (delta-based, kéo phải = lùi)
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

        // Kéo phải = waveform dịch phải = position lùi lại → dấu âm
        final deltaMs = -deltaX * msPerPixel;

        final targetMs = (_dragStartPosition!.inMilliseconds + deltaMs)
            .round()
            .clamp(0, widget.controller.duration.inMilliseconds);

        widget.onSeek?.call(Duration(milliseconds: targetMs));
      },

      // Drag end
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

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isVisible ? widget.height : 0,
        child: _isVisible
            ? Column(
                children: [
                  // Waveform canvas
                  Expanded(
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          final newZoom = widget.controller.zoom +
                              event.scrollDelta.dy * -0.001;
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

                  // Controls (optional)
                  if (widget.showControls) _buildControls(),
                ],
              )
            : null,
      ),
    );
  }

  // ── Zoom controls ────────────────────────────────────────────
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
          // Zoom out
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 18),
            onPressed: () =>
                widget.controller.setZoom(widget.controller.zoom * 0.8),
            color: Colors.white70,
          ),

          // Zoom slider
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

          // Zoom in
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 18),
            onPressed: () =>
                widget.controller.setZoom(widget.controller.zoom * 1.25),
            color: Colors.white70,
          ),

          const SizedBox(width: 16),

          // Zoom badge
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
} // ← class _RollingWaveformViewState đóng đúng chỗ
