// lib/widgets/waveform_editor.dart
// VipSound - Enhanced Waveform Editor với Shadowing Integration

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/waveform_provider.dart';
import '../providers/player_provider.dart';
import '../providers/shadowing_provider.dart'; // THÊM IMPORT
import '../models/audio_marker.dart';
import 'advanced_waveform_painter.dart';
import 'shadowing_widget.dart'; // THÊM IMPORT

/// Theme colors cho từng mode
class WaveformTheme {
  final Color primary;
  final Color secondary;
  final Color waveformColor;
  final Color waveformPlayedColor;
  final Color selectionColor;
  final Color markerColor;
  final Color backgroundColor;
  final Color gridColor;

  const WaveformTheme({
    required this.primary,
    required this.secondary,
    required this.waveformColor,
    required this.waveformPlayedColor,
    required this.selectionColor,
    required this.markerColor,
    required this.backgroundColor,
    required this.gridColor,
  });

  // Buddhism Mode - Warm, meditative colors
  static const buddhism = WaveformTheme(
    primary: Color(0xFFFFB300),
    secondary: Color(0xFFFF8F00),
    waveformColor: Color(0xFFFFE082),
    waveformPlayedColor: Color(0xFFFFB300),
    selectionColor: Color(0x40FFB300),
    markerColor: Color(0xFFFFD54F),
    backgroundColor: Color(0xFF1A1510),
    gridColor: Color(0x20FFB300),
  );

  // English Mode - Cool, focused colors
  static const english = WaveformTheme(
    primary: Color(0xFF2196F3),
    secondary: Color(0xFF1976D2),
    waveformColor: Color(0xFF90CAF9),
    waveformPlayedColor: Color(0xFF2196F3),
    selectionColor: Color(0x402196F3),
    markerColor: Color(0xFF64B5F6),
    backgroundColor: Color(0xFF0D1520),
    gridColor: Color(0x202196F3),
  );

  // Music Mode - Vibrant, creative colors
  static const music = WaveformTheme(
    primary: Color(0xFF6C63FF),
    secondary: Color(0xFF5B52CC),
    waveformColor: Color(0xFFB39DDB),
    waveformPlayedColor: Color(0xFF6C63FF),
    selectionColor: Color(0x406C63FF),
    markerColor: Color(0xFF9575CD),
    backgroundColor: Color(0xFF1A1A2E),
    gridColor: Color(0x206C63FF),
  );

  static WaveformTheme forMode(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return buddhism;
      case VipMode.english:
        return english;
      case VipMode.music:
        return music;
    }
  }
}

class WaveformEditor extends StatefulWidget {
  final double height;
  final bool showControls;
  final bool showMarkersList;
  final bool showShadowingArea;
  final bool showTranscript;

  const WaveformEditor({
    super.key,
    this.height = 200,
    this.showControls = true,
    this.showMarkersList = true,
    this.showShadowingArea = false,
    this.showTranscript = false,
  });

  @override
  State<WaveformEditor> createState() => _WaveformEditorState();
}

class _WaveformEditorState extends State<WaveformEditor>
    with SingleTickerProviderStateMixin {
  // Animation
  late AnimationController _pulseController;

  // Shadowing expanded state
  bool _shadowingExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PlayerProvider, WaveformProvider, ShadowingProvider>(
      builder: (context, player, waveform, shadowing, child) {
        final theme = WaveformTheme.forMode(player.currentMode);

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

        return Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Mode Header
              _ModeHeader(player: player, theme: theme),

              // Zoom controls
              if (widget.showControls)
                _ZoomControls(waveform: waveform, theme: theme),

              // Waveform display
              _WaveformView(
                player: player,
                waveform: waveform,
                theme: theme,
                height: widget.height,
                onSeek: (time) => player.seek(time),
                onMarkerTap: (marker) {
                  waveform.selectMarker(marker);
                  HapticFeedback.selectionClick();
                },
                onSelectionComplete: () {
                  if (waveform.hasSelection) {
                    _showAddMarkerDialog(context, waveform, player);
                  }
                },
                onDoubleTap: (time) {
                  _showQuickAddMarkerDialog(context, waveform, time, player);
                },
              ),

              // Shadowing Toggle Button (cho English Mode)
              if (player.isEnglishMode || widget.showShadowingArea)
                _ShadowingToggle(
                  isExpanded: _shadowingExpanded,
                  hasLoop: player.loopStart != null && player.loopEnd != null,
                  shadowingState: shadowing.state,
                  theme: theme,
                  onToggle: () {
                    setState(() {
                      _shadowingExpanded = !_shadowingExpanded;
                    });

                    // Auto-setup segment nếu có loop
                    if (_shadowingExpanded &&
                        player.loopStart != null &&
                        player.loopEnd != null &&
                        shadowing.state == ShadowingState.idle) {
                      shadowing.setSegment(
                        start: player.loopStart!,
                        end: player.loopEnd!,
                        audioPath: player.currentSongPath ?? '',
                        waveform: waveform.waveformData,
                      );
                    }
                  },
                ),

              // Shadowing Widget (Expandable)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _shadowingExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: const Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: ShadowingWidget(),
                ),
              ),

              // Transcript Display
              if (widget.showTranscript || player.modeSettings.showTranscript)
                _TranscriptDisplay(
                    player: player, waveform: waveform, theme: theme),

              // Quick Actions (mode-specific)
              if (widget.showControls && !_shadowingExpanded)
                _QuickActions(
                  player: player,
                  waveform: waveform,
                  theme: theme,
                  onShadowingTap: () {
                    setState(() {
                      _shadowingExpanded = true;
                    });
                  },
                ),

              // Marker controls
              if (widget.showControls && !_shadowingExpanded)
                _MarkerControls(
                  waveform: waveform,
                  player: player,
                  theme: theme,
                ),

              // Markers list
              if (widget.showMarkersList &&
                  waveform.markers.isNotEmpty &&
                  !_shadowingExpanded)
                _MarkersList(
                  waveform: waveform,
                  player: player,
                  theme: theme,
                ),
            ],
          ),
        );
      },
    );
  }

  void _showQuickAddMarkerDialog(
    BuildContext context,
    WaveformProvider waveform,
    Duration time,
    PlayerProvider player,
  ) {
    final theme = WaveformTheme.forMode(player.currentMode);
    final controller = TextEditingController();

    String hintText;
    MarkerType defaultType;

    switch (player.currentMode) {
      case VipMode.buddhism:
        hintText = 'Ví dụ: "Tứ Diệu Đế", "Lời dạy quan trọng"...';
        defaultType = MarkerType.important;
        break;
      case VipMode.english:
        hintText = 'Ví dụ: "Phrasal verb", "Pronunciation"...';
        defaultType = MarkerType.word;
        break;
      case VipMode.music:
        hintText = 'Ví dụ: "Điệp khúc", "Solo hay"...';
        defaultType = MarkerType.point;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.primary.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.add_location, color: theme.primary),
            const SizedBox(width: 8),
            const Text(
              'Thêm điểm đánh dấu',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 16, color: theme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(time),
                    style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              waveform.addMarker(
                startTime: time,
                label: controller.text.trim(),
                type: defaultType,
                color: theme.primary,
              );
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showAddMarkerDialog(
    BuildContext context,
    WaveformProvider waveform,
    PlayerProvider player,
  ) {
    final theme = WaveformTheme.forMode(player.currentMode);
    final controller = TextEditingController();
    MarkerType selectedType = MarkerType.region;

    List<MarkerType> suggestedTypes;
    switch (player.currentMode) {
      case VipMode.buddhism:
        suggestedTypes = [
          MarkerType.important,
          MarkerType.region,
          MarkerType.sentence,
          MarkerType.difficult,
        ];
        break;
      case VipMode.english:
        suggestedTypes = [
          MarkerType.sentence,
          MarkerType.word,
          MarkerType.difficult,
          MarkerType.region,
        ];
        break;
      case VipMode.music:
        suggestedTypes = [
          MarkerType.region,
          MarkerType.point,
          MarkerType.important,
          MarkerType.difficult,
        ];
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundColor,
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
              Row(
                children: [
                  Icon(Icons.bookmark_add, color: theme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Tạo đánh dấu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timelapse, size: 16, color: theme.primary),
                    const SizedBox(width: 8),
                    Text(
                      waveform.hasSelection
                          ? '${_formatDuration(waveform.selectionStart!)} → ${_formatDuration(waveform.selectionEnd!)}'
                          : _formatDuration(
                              waveform.selectionStart ?? Duration.zero),
                      style: TextStyle(color: theme.primary),
                    ),
                    if (waveform.hasSelection) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(waveform.selectionEnd! -
                              waveform.selectionStart!),
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nhãn',
                  hintText: _getHintForMode(player.currentMode),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  labelStyle: TextStyle(color: theme.primary),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary),
                  ),
                  prefixIcon: Icon(Icons.label, color: theme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loại đánh dấu:',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedTypes.map((type) {
                  final isSelected = selectedType == type;
                  return GestureDetector(
                    onTap: () => setState(() => selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? type.defaultColor.withOpacity(0.3)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected ? type.defaultColor : Colors.white24,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type.icon,
                            size: 16,
                            color: isSelected ? type.defaultColor : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type.displayName,
                            style: TextStyle(
                              color:
                                  isSelected ? type.defaultColor : Colors.grey,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      child: Text(
                        'Hủy',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        waveform.createMarkerFromSelection(
                          label: controller.text.trim(),
                          type: selectedType,
                        );
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType.defaultColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  String _getHintForMode(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return 'Ví dụ: "Bát Chánh Đạo", "Lời dạy về từ bi"...';
      case VipMode.english:
        return 'Ví dụ: "Check it out", "Difficult pronunciation"...';
      case VipMode.music:
        return 'Ví dụ: "Điệp khúc", "Bridge hay"...';
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    final ms = d.inMilliseconds % 1000 ~/ 10;
    return '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }
}

// ==================== SHADOWING TOGGLE ====================

class _ShadowingToggle extends StatelessWidget {
  final bool isExpanded;
  final bool hasLoop;
  final ShadowingState shadowingState;
  final WaveformTheme theme;
  final VoidCallback onToggle;

  const _ShadowingToggle({
    required this.isExpanded,
    required this.hasLoop,
    required this.shadowingState,
    required this.theme,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = shadowingState == ShadowingState.recording ||
        shadowingState == ShadowingState.countdown ||
        shadowingState == ShadowingState.waiting;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
                ? [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)]
                : isExpanded
                    ? [
                        const Color(0xFF2196F3).withOpacity(0.3),
                        const Color(0xFF2196F3).withOpacity(0.1)
                      ]
                    : [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02)
                      ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.red.withOpacity(0.5)
                : isExpanded
                    ? const Color(0xFF2196F3).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.red.withOpacity(0.2)
                    : const Color(0xFF2196F3).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.mic : Icons.record_voice_over,
                size: 20,
                color: isActive ? Colors.red : const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shadowing Mode',
                    style: TextStyle(
                      color: isActive ? Colors.red : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isActive
                        ? _getStateText(shadowingState)
                        : hasLoop
                            ? 'Nhấn để luyện shadowing'
                            : 'Chọn A-B Loop trước',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Status/Arrow
            if (isActive)
              const _PulsingDot(color: Colors.red)
            else
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.grey[500],
              ),
          ],
        ),
      ),
    );
  }

  String _getStateText(ShadowingState state) {
    switch (state) {
      case ShadowingState.waiting:
        return 'Đang chờ...';
      case ShadowingState.countdown:
        return 'Đếm ngược...';
      case ShadowingState.recording:
        return 'Đang ghi âm...';
      case ShadowingState.processing:
        return 'Đang xử lý...';
      case ShadowingState.comparing:
        return 'Đang so sánh...';
      default:
        return '';
    }
  }
}

// ==================== MODE HEADER ====================

class _ModeHeader extends StatelessWidget {
  final PlayerProvider player;
  final WaveformTheme theme;

  const _ModeHeader({required this.player, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.2),
            theme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getModeIcon(),
              size: 18,
              color: theme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getModeName(),
                  style: TextStyle(
                    color: theme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _getModeSubtitle(),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (player.isLooping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.loop, size: 14, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 4),
                  Text(
                    '${player.loopCount}x',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${player.state.speed.toStringAsFixed(2)}x',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon() {
    switch (player.currentMode) {
      case VipMode.buddhism:
        return Icons.self_improvement;
      case VipMode.english:
        return Icons.school;
      case VipMode.music:
        return Icons.music_note;
    }
  }

  String _getModeName() {
    switch (player.currentMode) {
      case VipMode.buddhism:
        return '🙏 Chế độ Phật Pháp';
      case VipMode.english:
        return '📚 Chế độ Tiếng Anh';
      case VipMode.music:
        return '🎵 Chế độ Âm Nhạc';
    }
  }

  String _getModeSubtitle() {
    switch (player.currentMode) {
      case VipMode.buddhism:
        return 'Lắng nghe, suy ngẫm, thấm nhuần';
      case VipMode.english:
        return 'Nghe chậm, lặp lại, ghi nhớ';
      case VipMode.music:
        return 'Thưởng thức âm nhạc';
    }
  }
}

// ==================== ZOOM CONTROLS ====================

class _ZoomControls extends StatelessWidget {
  final WaveformProvider waveform;
  final WaveformTheme theme;

  const _ZoomControls({required this.waveform, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.zoom_in, size: 18, color: theme.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            'Zoom:',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: theme.primary,
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                thumbColor: theme.primary,
                overlayColor: theme.primary.withOpacity(0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: waveform.zoomLevel,
                min: WaveformProvider.minZoom,
                max: 50,
                onChanged: (value) => waveform.setZoom(value),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${waveform.zoomLevel.toStringAsFixed(1)}x',
              style: TextStyle(
                color: theme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ZoomButton(
              icon: Icons.remove,
              onTap: () => waveform.zoomOut(),
              theme: theme),
          const SizedBox(width: 4),
          _ZoomButton(
              icon: Icons.add, onTap: () => waveform.zoomIn(), theme: theme),
          const SizedBox(width: 4),
          _ZoomButton(
              icon: Icons.fit_screen,
              onTap: () => waveform.zoomToFit(),
              theme: theme),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final WaveformTheme theme;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.primary.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 18, color: theme.primary),
      ),
    );
  }
}

// ==================== WAVEFORM VIEW ====================

class _WaveformView extends StatelessWidget {
  final PlayerProvider player;
  final WaveformProvider waveform;
  final WaveformTheme theme;
  final double height;
  final Function(Duration) onSeek;
  final Function(AudioMarker) onMarkerTap;
  final VoidCallback onSelectionComplete;
  final Function(Duration) onDoubleTap;

  const _WaveformView({
    required this.player,
    required this.waveform,
    required this.theme,
    required this.height,
    required this.onSeek,
    required this.onMarkerTap,
    required this.onSelectionComplete,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: waveform.isLoading
            ? _LoadingIndicator(theme: theme)
            : _InteractiveWaveform(
                player: player,
                waveform: waveform,
                theme: theme,
                height: height,
                onSeek: onSeek,
                onMarkerTap: onMarkerTap,
                onSelectionComplete: onSelectionComplete,
                onDoubleTap: onDoubleTap,
              ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final WaveformTheme theme;

  const _LoadingIndicator({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'Đang phân tích sóng âm...',
            style: TextStyle(
              color: theme.primary.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveWaveform extends StatefulWidget {
  final PlayerProvider player;
  final WaveformProvider waveform;
  final WaveformTheme theme;
  final double height;
  final Function(Duration) onSeek;
  final Function(AudioMarker) onMarkerTap;
  final VoidCallback onSelectionComplete;
  final Function(Duration) onDoubleTap;

  const _InteractiveWaveform({
    required this.player,
    required this.waveform,
    required this.theme,
    required this.height,
    required this.onSeek,
    required this.onMarkerTap,
    required this.onSelectionComplete,
    required this.onDoubleTap,
  });

  @override
  State<_InteractiveWaveform> createState() => _InteractiveWaveformState();
}

class _InteractiveWaveformState extends State<_InteractiveWaveform> {
  double _startZoom = 1.0;
  Offset? _lastTapPosition;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _startZoom = widget.waveform.zoomLevel;
      },
      onScaleUpdate: (details) {
        if (details.scale != 1.0) {
          widget.waveform.setZoom(_startZoom * details.scale);
        }
        final delta = details.focalPointDelta.dx;
        final scrollDelta =
            delta / (context.size?.width ?? 300) / widget.waveform.zoomLevel;
        widget.waveform.scrollBy(-scrollDelta);
      },
      onTapDown: (details) {
        _lastTapPosition = details.localPosition;
      },
      onTapUp: (details) {
        if (_lastTapPosition != null) {
          final width = context.size?.width ?? 300;
          final time = widget.waveform.positionToDuration(
            details.localPosition.dx,
            width,
          );
          final marker = widget.waveform.findMarkerAtPosition(time);
          if (marker != null) {
            widget.onMarkerTap(marker);
          } else {
            widget.onSeek(time);
          }
        }
      },
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        final width = context.size?.width ?? 300;
        final time = widget.waveform.positionToDuration(
          details.localPosition.dx,
          width,
        );
        widget.waveform.startSelection(time);
      },
      onLongPressMoveUpdate: (details) {
        final width = context.size?.width ?? 300;
        final time = widget.waveform.positionToDuration(
          details.localPosition.dx,
          width,
        );
        widget.waveform.updateSelection(time);
      },
      onLongPressEnd: (details) {
        widget.waveform.endSelection();
        widget.onSelectionComplete();
      },
      onDoubleTap: () {
        if (_lastTapPosition != null) {
          final width = context.size?.width ?? 300;
          final time = widget.waveform.positionToDuration(
            _lastTapPosition!.dx,
            width,
          );
          widget.onDoubleTap(time);
        }
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dy < 0) {
              widget.waveform.zoomIn();
            } else {
              widget.waveform.zoomOut();
            }
          }
        },
        child: widget.player.state.duration.inMilliseconds == 0
            ? SizedBox(height: widget.height)
            : CustomPaint(
                size: Size(double.infinity, widget.height),
                painter: AdvancedWaveformPainter(
                  waveformData: widget.waveform.waveformData,
                  zoomLevel: widget.waveform.zoomLevel,
                  scrollOffset: widget.waveform.scrollOffset,
                  audioDuration: widget.player.state.duration,
                  currentPosition: widget.player.state.position,
                  selectionStart: widget.waveform.selectionStart,
                  selectionEnd: widget.waveform.selectionEnd,
                  markers: widget.waveform.markers,
                  selectedMarker: widget.waveform.selectedMarker,
                  waveformColor: widget.theme.waveformColor,
                  waveformPlayedColor: widget.theme.waveformPlayedColor,
                  selectionColor: widget.theme.selectionColor,
                  gridColor: widget.theme.gridColor,
                  playheadColor: widget.theme.secondary,
                  backgroundColor: widget.theme.backgroundColor,
                  loopStart: widget.player.loopStart,
                  loopEnd: widget.player.loopEnd,
                  isLooping: widget.player.isLooping,
                ),
              ),
      ),
    );
  }
}

// ==================== TRANSCRIPT DISPLAY ====================

class _TranscriptDisplay extends StatelessWidget {
  final PlayerProvider player;
  final WaveformProvider waveform;
  final WaveformTheme theme;

  const _TranscriptDisplay({
    required this.player,
    required this.waveform,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    String? transcript;
    if (waveform.selectedMarker != null) {
      transcript = waveform.selectedMarker!.label;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subtitles, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'Transcript',
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transcript ?? 'Chọn một đoạn đánh dấu để xem nội dung...',
            style: TextStyle(
              color: transcript != null ? Colors.white : Colors.grey[500],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== QUICK ACTIONS ====================

class _QuickActions extends StatelessWidget {
  final PlayerProvider player;
  final WaveformProvider waveform;
  final WaveformTheme theme;
  final VoidCallback? onShadowingTap;

  const _QuickActions({
    required this.player,
    required this.waveform,
    required this.theme,
    this.onShadowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _getActionsForMode(context),
      ),
    );
  }

  List<Widget> _getActionsForMode(BuildContext context) {
    switch (player.currentMode) {
      case VipMode.buddhism:
        return [
          _QuickActionButton(
            icon: Icons.self_improvement,
            label: 'Suy ngẫm',
            color: theme.primary,
            onTap: () {
              player.pause();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.self_improvement, color: theme.primary),
                      const SizedBox(width: 8),
                      const Text('Hãy dành thời gian suy ngẫm...'),
                    ],
                  ),
                  backgroundColor: theme.backgroundColor,
                  duration: const Duration(seconds: 5),
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.bookmark,
            label: 'Quan trọng',
            color: const Color(0xFFFFD700),
            onTap: () {
              waveform.addMarker(
                startTime: player.state.position,
                label: 'Quan trọng',
                type: MarkerType.important,
                color: const Color(0xFFFFD700),
              );
              HapticFeedback.mediumImpact();
            },
          ),
          _QuickActionButton(
            icon: Icons.speed,
            label: '0.85x',
            color: theme.secondary,
            onTap: () => player.setSpeed(0.85),
          ),
        ];

      case VipMode.english:
        return [
          _QuickActionButton(
            icon: Icons.mic,
            label: 'Shadowing',
            color: const Color(0xFF2196F3),
            onTap: onShadowingTap,
          ),
          _QuickActionButton(
            icon: Icons.warning_amber,
            label: 'Khó',
            color: const Color(0xFFF44336),
            onTap: () {
              waveform.addMarker(
                startTime: player.state.position,
                label: 'Khó',
                type: MarkerType.difficult,
                color: const Color(0xFFF44336),
              );
              HapticFeedback.mediumImpact();
            },
          ),
          _QuickActionButton(
            icon: Icons.speed,
            label: '0.7x',
            color: theme.secondary,
            onTap: () => player.setSpeed(0.7),
          ),
        ];

      case VipMode.music:
        return [
          _QuickActionButton(
            icon: Icons.favorite,
            label: 'Yêu thích',
            color: const Color(0xFFE91E63),
            onTap: () {
              waveform.addMarker(
                startTime: player.state.position,
                label: 'Yêu thích',
                type: MarkerType.point,
                color: const Color(0xFFE91E63),
              );
              HapticFeedback.mediumImpact();
            },
          ),
          _QuickActionButton(
            icon: Icons.loop,
            label: 'Loop',
            color: theme.primary,
            onTap: () {
              if (player.loopStart == null) {
                player.setLoopStart();
              } else {
                player.setLoopEnd();
              }
            },
          ),
          _QuickActionButton(
            icon: Icons.speed,
            label: '1.0x',
            color: theme.secondary,
            onTap: () => player.setSpeed(1.0),
          ),
        ];
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap?.call();
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MARKER CONTROLS ====================

class _MarkerControls extends StatelessWidget {
  final WaveformProvider waveform;
  final PlayerProvider player;
  final WaveformTheme theme;

  const _MarkerControls({
    required this.waveform,
    required this.player,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.add_location,
            label: 'Điểm',
            theme: theme,
            onTap: () {
              waveform.addMarker(
                startTime: player.state.position,
                label: 'Marker ${waveform.markers.length + 1}',
                type: MarkerType.point,
              );
              HapticFeedback.mediumImpact();
            },
          ),
          _ControlButton(
            icon: Icons.select_all,
            label: 'Từ Loop',
            theme: theme,
            onTap: () {
              if (player.loopStart != null && player.loopEnd != null) {
                waveform.addMarker(
                  startTime: player.loopStart!,
                  endTime: player.loopEnd!,
                  label: 'Region ${waveform.markers.length + 1}',
                  type: MarkerType.region,
                );
                HapticFeedback.mediumImpact();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đặt A-B loop trước để tạo đoạn'),
                    backgroundColor: theme.primary,
                  ),
                );
              }
            },
          ),
          if (waveform.selectedMarker != null)
            _ControlButton(
              icon: Icons.delete,
              label: 'Xóa',
              color: const Color(0xFFF44336),
              theme: theme,
              onTap: () {
                waveform.removeMarker(waveform.selectedMarker!.id);
                HapticFeedback.mediumImpact();
              },
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final WaveformTheme theme;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? theme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: buttonColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: buttonColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: buttonColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MARKERS LIST ====================

class _MarkersList extends StatelessWidget {
  final WaveformProvider waveform;
  final PlayerProvider player;
  final WaveformTheme theme;

  const _MarkersList({
    required this.waveform,
    required this.player,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(Icons.list, size: 16, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  'Đánh dấu (${waveform.markers.length})',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (waveform.markers.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: theme.backgroundColor,
                          title: const Text(
                            'Xóa tất cả?',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'Bạn có chắc muốn xóa tất cả đánh dấu?',
                            style: TextStyle(color: Colors.grey),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () {
                                waveform.clearMarkers();
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Xóa hết',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      'Xóa hết',
                      style: TextStyle(
                        color: Colors.red[300],
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: waveform.markers.length,
              itemBuilder: (context, index) {
                final marker = waveform.markers[index];
                final isSelected = marker.id == waveform.selectedMarker?.id;

                return _MarkerItem(
                  marker: marker,
                  isSelected: isSelected,
                  theme: theme,
                  onTap: () {
                    waveform.selectMarker(marker);
                    player.seek(marker.startTime);
                    if (marker.isRegion) {
                      player.setLoop(marker.startTime, marker.endTime!);
                    }
                    HapticFeedback.selectionClick();
                  },
                  onPlay: () {
                    player.seek(marker.startTime);
                    if (marker.isRegion) {
                      player.setLoop(marker.startTime, marker.endTime!);
                    }
                    player.play();
                  },
                  onDelete: () {
                    waveform.removeMarker(marker.id);
                    HapticFeedback.mediumImpact();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkerItem extends StatelessWidget {
  final AudioMarker marker;
  final bool isSelected;
  final WaveformTheme theme;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _MarkerItem({
    required this.marker,
    required this.isSelected,
    required this.theme,
    required this.onTap,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? marker.color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? marker.color : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: marker.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                marker.type.icon,
                color: marker.color,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    marker.isRegion
                        ? '${_formatDuration(marker.startTime)} → ${_formatDuration(marker.endTime!)}'
                        : _formatDuration(marker.startTime),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconButton(
                  icon: Icons.play_arrow,
                  color: marker.color,
                  onTap: onPlay,
                ),
                _IconButton(
                  icon: Icons.delete_outline,
                  color: Colors.red[300]!,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ==================== PULSING DOT ====================

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.5 + _controller.value * 0.5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5),
                blurRadius: 6 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
