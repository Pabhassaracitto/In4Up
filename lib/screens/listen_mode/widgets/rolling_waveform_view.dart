// lib/widgets/rolling_waveform_view.dart
// Widget chính để hiển thị waveform dạng rolling, với playhead cố định ở giữa và waveform chạy qua lại.
// FIX: Drag mượt hơn bằng delta-based seek thay vì absolute position seek.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../controllers/rolling_waveform_controller.dart';
import 'rolling_waveform_painter.dart';

class RollingWaveformView extends StatefulWidget {
  final RollingWaveformController controller;
  final double height;
  final Function(Duration)? onSeek;
  final VoidCallback? onTap;
  final bool showControls;

  const RollingWaveformView({
    Key? key,
    required this.controller,
    this.height = 200,
    this.onSeek,
    this.onTap,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<RollingWaveformView> createState() => _RollingWaveformViewState();
}

class _RollingWaveformViewState extends State<RollingWaveformView> {
  bool _isVisible = true;

  // ── FIX: Lưu vị trí bắt đầu drag để tính delta ──
  Duration? _dragStartPosition; // Vị trí audio lúc bắt đầu drag
  double? _dragStartX; // Vị trí tay lúc bắt đầu drag

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Single tap: pause/play
      onTap: () {
        widget.onTap?.call();
      },

      // Double tap: ẩn/hiện waveform
      onDoubleTap: () {
        setState(() => _isVisible = !_isVisible);
      },

      // ── FIX: Ghi nhớ vị trí bắt đầu drag ──
      onHorizontalDragStart: (details) {
        _dragStartPosition = widget.controller.position;
        _dragStartX = details.localPosition.dx;
      },

      // ── FIX: Tính seek dựa theo delta từ điểm bắt đầu drag ──
      onHorizontalDragUpdate: (details) {
        if (widget.onSeek == null) return;
        if (_dragStartPosition == null || _dragStartX == null) return;

        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final screenWidth = renderBox.size.width;
        if (screenWidth <= 0) return;

        // Khoảng cách delta từ điểm bắt đầu (px)
        final deltaX = details.localPosition.dx - _dragStartX!;

        // Tính thời gian tương ứng với delta
        // Kéo trái = về trước, kéo phải = về sau
        // Dùng visibleDuration để scale — zoom càng cao, kéo càng chậm
        final visibleMs = widget.controller.visibleDuration.inMilliseconds;
        final msPerPixel = visibleMs / screenWidth;

        // Kéo ngược chiều: kéo phải = waveform dịch phải = position lùi lại
        final deltaMs = -deltaX * msPerPixel;

        final targetMs = (_dragStartPosition!.inMilliseconds + deltaMs)
            .round()
            .clamp(0, widget.controller.duration.inMilliseconds);

        widget.onSeek?.call(Duration(milliseconds: targetMs));
      },

      // Reset khi nhả tay
      onHorizontalDragEnd: (_) {
        _dragStartPosition = null;
        _dragStartX = null;
      },

      onHorizontalDragCancel: () {
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
                      // Pinch zoom bằng scroll wheel (desktop/trackpad)
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
            onPressed: () {
              widget.controller.setZoom(widget.controller.zoom * 0.8);
            },
            color: Colors.white70,
          ),

          // Zoom slider
          Expanded(
            child: Slider(
              value: widget.controller.zoom,
              min: 0.5,
              max: 10.0,
              divisions: 19,
              onChanged: (value) {
                widget.controller.setZoom(value);
              },
              activeColor: const Color(0xFF6C63FF),
            ),
          ),

          // Zoom in
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 18),
            onPressed: () {
              widget.controller.setZoom(widget.controller.zoom * 1.25);
            },
            color: Colors.white70,
          ),

          const SizedBox(width: 16),

          // Zoom value badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => Text(
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
