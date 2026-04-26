// lib/screens/listen_mode/listen_mode_screen.dart
// VipSound – Listen Mode (v6 Final)
//
// THIẾT KẾ:
//   Layer 1 (luôn hiện): Waveform + Progress slim + Seek ±10s + Play + Badges
//   Layer 2 (long-press waveform): Action Sheet — Set A / Set B / Jump
//   Layer 3 (kéo sheet lên): AB Loop chi tiết, Speed, Quick Actions
//
// NGUYÊN TẮC:
//   - Controls chính luôn visible, không ẩn sau gesture/tap bí mật
//   - AB Loop: long-press waveform → bottom sheet menu (discoverable)
//   - State AB Loop nằm ở PlayerProvider (single source of truth)
//   - Waveform 3 trạng thái: loading / error / ready

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vipsound_stt/vipsound_stt.dart';

import '../../models/loop_presets.dart';
import '../../models/waveform_data.dart';
import '../../providers/player_provider.dart';
import '../../providers/waveform_provider.dart';
import '../../widgets/ab_loop_controls.dart';
import '../../widgets/speed_control.dart';
import '../listen_mode/controllers/rolling_waveform_controller.dart';
import '../listen_mode/widgets/rolling_waveform_view.dart';
import 'widgets/listen_library_screen.dart';
import 'widgets/quick_audio_sheet.dart';

class ListenModeScreen extends StatefulWidget {
  const ListenModeScreen({super.key});

  @override
  State<ListenModeScreen> createState() => _ListenModeScreenState();
}

class _ListenModeScreenState extends State<ListenModeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late RollingWaveformController _waveformController;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _sheetExpanded = false;

  String? _lastSyncedPath;
  PlayerProvider? _playerProvider;
  WaveformProvider? _waveformProvider;

  bool _isAppVisible = true;
  bool _isUserSeeking = false;
  bool _isCurrentRoute = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveformController = RollingWaveformController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupListeners();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _isAppVisible = state == AppLifecycleState.resumed);
  }

  void _setupListeners() {
    final player = context.read<PlayerProvider>();
    final waveform = context.read<WaveformProvider>();

    _playerProvider = player;
    _waveformProvider = waveform;

    player.addListener(_onPlayerChange);
    waveform.addListener(_onWaveformChange);

    _onWaveformChange();
    if (player.currentSongPath != null) {
      waveform.loadWaveform(player.currentSongPath!, player.state.duration);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerProvider?.removeListener(_onPlayerChange);
    _waveformProvider?.removeListener(_onWaveformChange);
    _waveformController.setWaveformData(null);
    _waveformController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ── LOGIC HANDLERS ──────────────────────────────────────────

  void _onPlayerChange() {
    if (!mounted || !_isAppVisible || !_isCurrentRoute) return;
    if (_isUserSeeking) return;

    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null) return;

    // Reload waveform nếu cần
    final needsReload = player.currentSongPath != null &&
        (waveform.currentFilePath != player.currentSongPath ||
            (waveform.waveformData.isEmpty &&
                player.state.duration > Duration.zero &&
                !waveform.isLoading));

    if (needsReload) {
      waveform.loadWaveform(player.currentSongPath!, player.state.duration);
      return;
    }

    // Luôn update position khi playing (throttle nằm trong controller)
    if (player.isPlaying) {
      _waveformController.updatePosition(player.state.position);
    }
    _syncLoopRegions(player);
  }

  void _syncLoopRegions(PlayerProvider player) {
    if (player.loopStart != null && player.loopEnd != null) {
      final regions = _waveformController.loopRegions;
      if (regions.isEmpty ||
          regions.first.start != player.loopStart ||
          regions.first.end != player.loopEnd) {
        _waveformController.clearLoopRegions();
        _waveformController.addLoopRegion(
            LoopRegion(start: player.loopStart!, end: player.loopEnd!));
      }
    } else if (_waveformController.loopRegions.isNotEmpty) {
      _waveformController.clearLoopRegions();
    }
  }

  void _onWaveformChange() {
    if (!mounted || !_isAppVisible || !_isCurrentRoute) return;

    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null) return;

    if (player.currentSongPath != null &&
        waveform.currentFilePath == player.currentSongPath) {
      _waveformController.setWaveformData(WaveformData(
        samples: waveform.displayWaveform,
        duration: player.state.duration,
      ));
      _lastSyncedPath = player.currentSongPath;
    }
  }

  // ── LONG-PRESS ACTION SHEET ─────────────────────────────────

  void _showWaveformActionSheet(Duration position) {
    final player = _playerProvider;
    if (player == null) return;

    final hasA = player.pendingLoopA != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2235),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text('📍', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Tại ${_fmtDuration(position)}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: Colors.white12, height: 16),

            // Set A
            ListTile(
              dense: true,
              leading: Text('🅰️', style: TextStyle(fontSize: 18)),
              title: Text('Đặt điểm A',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                player.setLoopPointA(position);
                HapticFeedback.selectionClick();
                _showSnack('✅ Điểm A tại ${_fmtDuration(position)}');
              },
            ),

            // Set B
            ListTile(
              dense: true,
              leading: Text('🅱️', style: TextStyle(fontSize: 18)),
              title: Text(
                'Đặt điểm B',
                style: TextStyle(
                  color: hasA ? Colors.white : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              subtitle: hasA
                  ? null
                  : Text('Cần đặt điểm A trước',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              enabled: hasA,
              onTap: hasA
                  ? () {
                      Navigator.pop(ctx);
                      player.setLoopPointB(position);
                      HapticFeedback.mediumImpact();
                      _showSnack('✅ Vùng lặp A→B đã tạo');
                    }
                  : null,
            ),

            // Jump here
            ListTile(
              dense: true,
              leading: Icon(Icons.my_location,
                  color: Colors.blue.shade300, size: 20),
              title: Text('Nhảy đến đây',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                player.seek(position);
                HapticFeedback.lightImpact();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6C63FF),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, String?>(
      selector: (_, p) => p.currentSongPath,
      builder: (context, currentPath, _) {
        final player = context.read<PlayerProvider>();
        if (player.currentSongPath == null) {
          return const ListenLibraryScreen();
        }

        return Stack(
          children: [
            Column(
              children: [
                // Song info bar
                _SongInfoBar(
                  player: player,
                  onTitleTap: () => QuickAudioSheet.show(context),
                ),

                // Waveform (3-state)
                Expanded(
                  child: _buildWaveform(player),
                ),

                // Core controls (always visible)
                Consumer<PlayerProvider>(
                  builder: (_, p, __) => _CorePlayerControls(
                    player: p,
                    sheetController: _sheetController,
                  ),
                ),

                const SizedBox(height: 72),
              ],
            ),

            // Bottom sheet (advanced)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.10,
              minChildSize: 0.10,
              maxChildSize: 0.55,
              snap: true,
              snapSizes: const [0.10, 0.55],
              builder: (context, scrollController) {
                return NotificationListener<DraggableScrollableNotification>(
                  onNotification: (n) {
                    final wasExpanded = _sheetExpanded;
                    final nowExpanded = n.extent > 0.20;
                    if (wasExpanded != nowExpanded) {
                      setState(() => _sheetExpanded = nowExpanded);
                    }
                    return false;
                  },
                  child: _AdvancedSheet(
                    scrollController: scrollController,
                    player: player,
                    isExpanded: _sheetExpanded,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ── WAVEFORM (3-state) ──────────────────────────────────────

  Widget _buildWaveform(PlayerProvider player) {
    return Consumer2<PlayerProvider, WaveformProvider>(
      builder: (context, p, waveform, _) {
        // State: Error (empty after load)
        if (waveform.waveformData.isEmpty &&
            !waveform.isLoading &&
            p.currentSongPath != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, color: Colors.grey[700], size: 36),
                const SizedBox(height: 8),
                Text(
                  'Không hiển thị được sóng',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () => waveform.loadWaveform(
                    p.currentSongPath!,
                    p.state.duration,
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        // State: Ready
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RepaintBoundary(
                child: Listener(
                  onPointerUp: (_) => _isUserSeeking = false,
                  onPointerCancel: (_) => _isUserSeeking = false,
                  child: RollingWaveformView(
                    controller: _waveformController,
                    onSeek: (pos) {
                      _isUserSeeking = true;
                      player.seek(pos);
                    },
                    onTap: () {
                      HapticFeedback.lightImpact();
                      player.togglePlayPause();
                    },
                    onLongPressPosition: (position) {
                      HapticFeedback.mediumImpact();
                      _showWaveformActionSheet(position);
                    },
                    showControls: true,
                  ),
                ),
              ),
            ),

            // Loading indicator nhỏ ở góc — không che waveform
            if (waveform.isLoading)
              Positioned(
                top: 8,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF),
                          strokeWidth: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Đang phân tích...',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SONG INFO BAR
// ═══════════════════════════════════════════════════════════════

class _SongInfoBar extends StatelessWidget {
  final PlayerProvider player;
  final VoidCallback onTitleTap;

  const _SongInfoBar({required this.player, required this.onTitleTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTitleTap();
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF5B52CC)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      player.isPlaying ? Icons.equalizer : Icons.music_note,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                player.currentSongTitle ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Color(0xFF6C63FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          player.currentSongArtist ?? 'Nhấn để đổi audio',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Speed badge
          if (player.state.speed != 1.0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${player.state.speed}×',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CORE PLAYER CONTROLS (always visible)
// ═══════════════════════════════════════════════════════════════

class _CorePlayerControls extends StatelessWidget {
  final PlayerProvider player;
  final DraggableScrollableController sheetController;

  const _CorePlayerControls({
    required this.player,
    required this.sheetController,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 360;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar (always visible)
          const _SlimProgress(),
          SizedBox(height: isNarrow ? 4 : 8),

          // Responsive layout
          if (isNarrow) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusBadge.repeat(player),
                _StatusBadge.abLoop(player),
              ],
            ),
            const SizedBox(height: 6),
            _SeekAndPlayRow(player: player),
          ] else ...[
            Row(
              children: [
                _StatusBadge.repeat(player),
                const Spacer(),
                _SeekAndPlayRow(player: player),
                const Spacer(),
                _StatusBadge.abLoop(player),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Slim Progress Bar ──────────────────────────────────────────

class _SlimProgress extends StatelessWidget {
  const _SlimProgress();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final pos = player.state.position;
        final dur = player.state.duration;

        // ── FIX: Guard chặt hơn tránh NaN/Infinity ──
        final durMs = dur.inMilliseconds;
        final posMs = pos.inMilliseconds;

        final pct =
            (durMs > 0 && posMs >= 0) ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

        // Double-check NaN
        final safePct = pct.isNaN || pct.isInfinite ? 0.0 : pct;

        return Row(
          children: [
            Text(_fmt(pos),
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 10),
                  thumbColor: const Color(0xFF6C63FF),
                  activeTrackColor: const Color(0xFF6C63FF),
                  inactiveTrackColor: Colors.white12,
                ),
                child: Slider(
                  value: safePct, // ← dùng safePct
                  min: 0.0, // ← thêm min explicit
                  max: 1.0, // ← thêm max explicit
                  onChanged: durMs > 0 // ← disable khi chưa load
                      ? (v) => player.seekToPercent(v)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(_fmt(dur),
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Seek + Play Row ────────────────────────────────────────────

class _SeekAndPlayRow extends StatelessWidget {
  final PlayerProvider player;
  const _SeekAndPlayRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeekBtn(
          icon: Icons.replay_10,
          onTap: () => _seek(-10),
        ),
        const SizedBox(width: 16),
        _PlayButton(player: player),
        const SizedBox(width: 16),
        _SeekBtn(
          icon: Icons.forward_10,
          onTap: () => _seek(10),
        ),
      ],
    );
  }

  void _seek(int sec) {
    HapticFeedback.lightImpact();
    final target = player.state.position + Duration(seconds: sec);
    player.seek(target.isNegative ? Duration.zero : target);
  }
}

class _SeekBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SeekBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white70, size: 26),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final PlayerProvider player;
  const _PlayButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        player.togglePlayPause();
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          player.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

// ── Unified Status Badge ───────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const _StatusBadge({
    required this.emoji,
    required this.label,
    required this.color,
    required this.isActive,
    this.onTap,
  });

  factory _StatusBadge.repeat(PlayerProvider player) {
    const modes = [0, 1, 3, 5, -1];
    const labels = ['Lặp', '1×', '3×', '5×', '∞'];

    // ✅ maxLoopCount = mục tiêu, loopCount = đã đạt được
    final idx = modes.indexOf(player.maxLoopCount).clamp(0, modes.length - 1);
    final isActive = player.maxLoopCount != 0;

    return _StatusBadge(
      emoji: '🔁',
      label: labels[idx],
      color: const Color(0xFF4CAF50),
      isActive: isActive,
      onTap: () {
        HapticFeedback.selectionClick();
        final nextIdx = (idx + 1) % modes.length;
        player.setLoopCount(modes[nextIdx]);
      },
    );
  }

  factory _StatusBadge.abLoop(PlayerProvider player) {
    final hasPending = player.pendingLoopA != null;
    final hasComplete = player.hasCompletedLoop;

    return _StatusBadge(
      emoji: '📍',
      label: hasComplete
          ? 'A══B'
          : hasPending
              ? 'A…'
              : 'A──B',
      color: const Color(0xFF6C63FF),
      isActive: hasPending || hasComplete,
      onTap: (hasComplete || hasPending)
          ? () {
              HapticFeedback.lightImpact();
              player.clearLoopPoints();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: isActive ? Border.all(color: color.withOpacity(0.35)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.grey[600],
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GENERATE LRC BUTTON (giữ nguyên)
// ═══════════════════════════════════════════════════════════════

class GenerateLrcButton extends StatelessWidget {
  const GenerateLrcButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return StreamBuilder<SttProgress>(
          stream: provider.sttProgressStream,
          initialData: SttProgress.idle,
          builder: (context, snapshot) {
            final progress = snapshot.data ?? SttProgress.idle;
            final isActive = progress.isActive;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCrossFade(
                  firstChild: const SizedBox(height: 4),
                  secondChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: progress.progress,
                        backgroundColor: Colors.grey.shade800,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress.status == SttFacadeStatus.error
                              ? Colors.red
                              : Colors.blue.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress.message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  crossFadeState: isActive
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
                const SizedBox(height: 8),
                _LrcModelSelector(
                  isProcessing: isActive,
                  onGenerate: (level) =>
                      provider.generateLrcForCurrentAudio(level: level),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LrcModelSelector extends StatefulWidget {
  final bool isProcessing;
  final Future<SttTranscribeOutput?> Function(WhisperModelLevel) onGenerate;

  const _LrcModelSelector(
      {required this.isProcessing, required this.onGenerate});

  @override
  State<_LrcModelSelector> createState() => _LrcModelSelectorState();
}

class _LrcModelSelectorState extends State<_LrcModelSelector> {
  WhisperModelLevel _selectedLevel = WhisperModelLevel.base;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          children: WhisperModelLevel.values.map((level) {
            final info = context.read<PlayerProvider>().getSttModelInfo(level);
            return FilterChip(
              label: Text(
                  '${level.name.toUpperCase()} (${level.sizeInMB}MB)${info.isReady ? ' ✓' : ''}'),
              selected: _selectedLevel == level,
              onSelected: widget.isProcessing
                  ? null
                  : (_) => setState(() => _selectedLevel = level),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: widget.isProcessing
              ? null
              : () => widget.onGenerate(_selectedLevel),
          icon: widget.isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.subtitles_outlined),
          label: Text(
              widget.isProcessing ? 'Đang xử lý...' : 'Tạo lời thoại (LRC)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADVANCED SHEET (Layer 3)
// ═══════════════════════════════════════════════════════════════

class _AdvancedSheet extends StatelessWidget {
  final ScrollController scrollController;
  final PlayerProvider player;
  final bool isExpanded;

  const _AdvancedSheet({
    required this.scrollController,
    required this.player,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune, size: 13, color: Colors.grey[600]),
                          const SizedBox(width: 5),
                          Text(
                            'AB Loop · Tốc độ · Hẹn giờ',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    secondChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _SheetSection(
                          title: 'AB Loop',
                          icon: Icons.loop,
                          iconColor: Color(0xFF4CAF50),
                          child: ABLoopControls(),
                        ),
                        const _Divider(),
                        const _SheetSection(
                          title: 'Tốc độ',
                          icon: Icons.speed,
                          iconColor: Colors.orange,
                          child: SpeedControlWidget(),
                        ),
                        const _Divider(),
                        _SheetSection(
                          title: 'Nhanh',
                          icon: Icons.bolt,
                          iconColor: const Color(0xFF6C63FF),
                          child: _QuickActionsRow(player: player),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SheetSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final PlayerProvider player;
  const _QuickActionsRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickBtn(
          icon: Icons.bookmark_add_outlined,
          label: 'Đánh dấu',
          color: const Color(0xFFFFB300),
          onTap: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã đánh dấu vị trí hiện tại'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _QuickBtn(
          icon: player.hasSleepTimer ? Icons.bedtime : Icons.bedtime_outlined,
          label: player.hasSleepTimer ? 'Huỷ hẹn' : 'Hẹn giờ',
          color: const Color(0xFF9C27B0),
          isActive: player.hasSleepTimer,
          onTap: () => HapticFeedback.lightImpact(),
        ),
        const SizedBox(width: 12),
        _QuickBtn(
          icon: Icons.share_outlined,
          label: 'Chia sẻ',
          color: const Color(0xFF2196F3),
          onTap: () => HapticFeedback.lightImpact(),
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border:
              isActive ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? color : Colors.grey[400]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? color : Colors.grey[400],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
