// lib/widgets/rolling_waveform_view.dart
// Widget chính để hiển thị waveform dạng rolling, với playhead cố định ở giữa và waveform chạy qua lại. Hỗ trợ highlight vùng hiện tại, màu sắc khác nhau cho quá khứ và tương lai, và hiển thị loop regions.
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'rolling_waveform_controller.dart';
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
  double _lastZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Single tap: pause/play hoặc custom action
      onTap: () {
        widget.onTap?.call();
      },

      // Double tap: ẩn/hiện waveform
      onDoubleTap: () {
        setState(() => _isVisible = !_isVisible);
      },

      // Drag: seek
      onHorizontalDragUpdate: (details) {
        if (widget.onSeek == null) return;

        final renderBox = context.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(details.globalPosition);
        final screenWidth = renderBox.size.width;

        final targetPosition = widget.controller.screenXToPosition(
          localPosition.dx,
          screenWidth,
        );

        widget.onSeek?.call(targetPosition);
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
                      // Pinch zoom
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
                          return CustomPaint(
                            size: Size.infinite,
                            painter: RollingWaveformPainter(
                              controller: widget.controller,
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
        color: Colors.black.withOpacity(0.3),
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

          // Zoom indicator
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

          // Zoom value
          Container(
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
        ],
      ),
    );
  }
}
