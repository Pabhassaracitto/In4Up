import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/waveform_provider.dart';
import '../providers/player_provider.dart';
import '../providers/waveform_provider.dart';
import '../models/audio_marker.dart';
import 'advanced_waveform_painter.dart';

class WaveformEditor extends StatefulWidget {
  final double height;
  final bool showControls;

  const WaveformEditor({
    super.key,
    this.height = 200,
    this.showControls = true,
  });

  @override
  State<WaveformEditor> createState() => _WaveformEditorState();
}

class _WaveformEditorState extends State<WaveformEditor> {
  // Gesture tracking
  double _startZoom = 1.0;
  double _startScroll = 0.0;
  Offset? _tapPosition;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, WaveformProvider>(
      builder: (context, player, waveform, child) {
        // Load waveform khi có file mới
        if (player.currentSongPath != null &&
            waveform.currentFilePath != player.currentSongPath) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            waveform.loadWaveform(
              player.currentSongPath!,
              player.state.duration,
            );
          });
        }

        return Column(
          children: [
            // Zoom controls
            if (widget.showControls) _buildZoomControls(waveform),

            // Waveform display
            _buildWaveformView(player, waveform),

            // Marker controls
            if (widget.showControls) _buildMarkerControls(waveform, player),

            // Markers list
            if (waveform.markers.isNotEmpty)
              _buildMarkersList(waveform, player),
          ],
        );
      },
    );
  }

  Widget _buildZoomControls(WaveformProvider waveform) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Zoom:', style: TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(
            child: Slider(
              value: waveform.zoomLevel,
              min: WaveformProvider.minZoom,
              max: 50, // UI max
              onChanged: (value) => waveform.setZoom(value),
            ),
          ),
          Text(
            '${waveform.zoomLevel.toStringAsFixed(1)}x',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 8),
          _ZoomButton(
            icon: Icons.remove,
            onTap: () => waveform.zoomOut(),
          ),
          const SizedBox(width: 4),
          _ZoomButton(
            icon: Icons.add,
            onTap: () => waveform.zoomIn(),
          ),
          const SizedBox(width: 4),
          _ZoomButton(
            icon: Icons.fit_screen,
            onTap: () => waveform.zoomToFit(),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformView(PlayerProvider player, WaveformProvider waveform) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: waveform.isLoading
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
          onScaleStart: (details) {
            _startZoom = waveform.zoomLevel;
            _startScroll = waveform.scrollOffset;
          },
          onScaleUpdate: (details) {
            // Pinch to zoom
            if (details.scale != 1.0) {
              waveform.setZoom(_startZoom * details.scale);
            }
            // Drag to scroll
            final delta = details.focalPointDelta.dx;
            final scrollDelta = delta / (context.size?.width ?? 300) / waveform.zoomLevel;
            waveform.scrollBy(-scrollDelta);
          },
          onTapDown: (details) {
            _tapPosition = details.localPosition;
          },
          onTapUp: (details) {
            if (_tapPosition != null) {
              final width = context.size?.width ?? 300;
              final time = waveform.positionToDuration(
                details.localPosition.dx,
                width - 32, // account for margin
              );

              // Check if tapped on a marker
              final marker = waveform.findMarkerAtPosition(time);
              if (marker != null) {
                waveform.selectMarker(marker);
              } else {
                // Seek to position
                player.seek(time);
              }
            }
          },
          onLongPressStart: (details) {
            final width = context.size?.width ?? 300;
            final time = waveform.positionToDuration(
              details.localPosition.dx,
              width - 32,
            );
            waveform.startSelection(time);
          },
          onLongPressMoveUpdate: (details) {
            final width = context.size?.width ?? 300;
            final time = waveform.positionToDuration(
              details.localPosition.dx,
              width - 32,
            );
            waveform.updateSelection(time);
          },
          onLongPressEnd: (details) {
            waveform.endSelection();
            if (waveform.hasSelection) {
              _showAddMarkerDialog(context, waveform);
            }
          },
          onDoubleTap: () {
            // Double tap to add point marker
            if (_tapPosition != null) {
              final width = context.size?.width ?? 300;
              final time = waveform.positionToDuration(
                _tapPosition!.dx,
                width - 32,
              );
              _showQuickAddMarkerDialog(context, waveform, time);
            }
          },
          child: Listener(
            onPointerSignal: (event) {
              // Mouse wheel zoom
              if (event is PointerScrollEvent) {
                if (event.scrollDelta.dy < 0) {
                  waveform.zoomIn();
                } else {
                  waveform.zoomOut();
                }
              }
            },
            child: CustomPaint(
              size: Size(double.infinity, widget.height),
              painter: AdvancedWaveformPainter(
                waveformData: waveform.waveformData,
                zoomLevel: waveform.zoomLevel,
                scrollOffset: waveform.scrollOffset,
                audioDuration: player.state.duration,
                currentPosition: player.state.position,
                selectionStart: waveform.selectionStart,
                selectionEnd: waveform.selectionEnd,
                markers: waveform.markers,
                selectedMarker: waveform.selectedMarker,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkerControls(WaveformProvider waveform, PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.add_location,
            label: 'Điểm',
            onTap: () {
              waveform.addMarker(
                startTime: player.state.position,
                label: 'Marker ${waveform.markers.length + 1}',
                type: MarkerType.point,
              );
            },
          ),
          _ControlButton(
            icon: Icons.select_all,
            label: 'Đoạn',
            onTap: () {
              if (player.loopStart != null && player.loopEnd != null) {
                waveform.addMarker(
                  startTime: player.loopStart!,
                  endTime: player.loopEnd!,
                  label: 'Region ${waveform.markers.length + 1}',
                  type: MarkerType.region,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đặt A-B loop trước để tạo đoạn'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
          _ControlButton(
            icon: Icons.flag,
            label: 'Khó',
            color: Colors.red,
            onTap: () {
              waveform.addMarker(
                startTime: player.state.position,
                label: 'Khó',
                type: MarkerType.difficult,
                color: Colors.red,
              );
            },
          ),
          if (waveform.hasSelection)
            _ControlButton(
              icon: Icons.save,
              label: 'Lưu',
              color: Colors.green,
              onTap: () => _showAddMarkerDialog(context, waveform),
            ),
          if (waveform.selectedMarker != null)
            _ControlButton(
              icon: Icons.delete,
              label: 'Xóa',
              color: Colors.red,
              onTap: () {
                waveform.removeMarker(waveform.selectedMarker!.id);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMarkersList(WaveformProvider waveform, PlayerProvider player) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: waveform.markers.length,
        itemBuilder: (context, index) {
          final marker = waveform.markers[index];
          final isSelected = marker.id == waveform.selectedMarker?.id;

          return GestureDetector(
            onTap: () {
              waveform.selectMarker(marker);
              player.seek(marker.startTime);
              if (marker.isRegion) {
                player.setLoop(marker.startTime, marker.endTime!);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? marker.color.withOpacity(0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? marker.color : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    marker.type.icon,
                    color: marker.color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marker.label.isNotEmpty
                              ? marker.label
                              : marker.type.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          marker.isRegion
                              ? '${_formatDuration(marker.startTime)} - ${_formatDuration(marker.endTime!)}'
                              : _formatDuration(marker.startTime),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 20),
                    color: marker.color,
                    onPressed: () {
                      player.seek(marker.startTime);
                      if (marker.isRegion) {
                        player.setLoop(marker.startTime, marker.endTime!);
                      }
                      player.play();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    color: Colors.grey,
                    onPressed: () => _showEditMarkerDialog(context, waveform, marker),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQuickAddMarkerDialog(
      BuildContext context,
      WaveformProvider waveform,
      Duration time,
      ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Thêm điểm đánh dấu', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nhập nhãn...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              waveform.addMarker(
                startTime: time,
                label: controller.text.trim(),
                type: MarkerType.point,
              );
              Navigator.pop(context);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showAddMarkerDialog(BuildContext context, WaveformProvider waveform) {
    final controller = TextEditingController();
    MarkerType selectedType = MarkerType.region;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tạo đánh dấu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                waveform.hasSelection
                    ? '${_formatDuration(waveform.selectionStart!)} → ${_formatDuration(waveform.selectionEnd!)}'
                    : _formatDuration(waveform.selectionStart ?? Duration.zero),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nhãn',
                  hintText: 'Ví dụ: "The path to..."',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Loại:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  MarkerType.region,
                  MarkerType.word,
                  MarkerType.sentence,
                  MarkerType.difficult,
                  MarkerType.important,
                ].map((type) {
                  final isSelected = selectedType == type;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type.icon, size: 16, color: isSelected ? Colors.white : type.defaultColor),
                        const SizedBox(width: 4),
                        Text(type.displayName),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: type.defaultColor,
                    onSelected: (_) => setState(() => selectedType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        waveform.clearSelection();
                        Navigator.pop(context);
                      },
                      child: const Text('Hủy'),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        waveform.createMarkerFromSelection(
                          label: controller.text.trim(),
                          type: selectedType,
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType.defaultColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMarkerDialog(
      BuildContext context,
      WaveformProvider waveform,
      AudioMarker marker,
      ) {
    final controller = TextEditingController(text: marker.label);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Sửa đánh dấu', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nhãn',
            labelStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              waveform.removeMarker(marker.id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              waveform.updateMarker(marker.id, label: controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    final ms = d.inMilliseconds % 1000 ~/ 10;
    return '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }
}

// Helper widgets
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF6C63FF),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}