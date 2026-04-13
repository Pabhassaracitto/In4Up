// lib/screens/listen_mode/listen_mode_screen.dart
// VipSound – Listen Mode (Progressive Disclosure Redesign)
//
// TRIẾT LÝ:
//   Mặc định: tối giản — Waveform + nút Play + thời gian
//   Nâng cao:  ẩn sau bottom sheet kéo lên — Loop, Speed, Bookmarks, Sleep timer
//
// PHÂN TẦNG:
//   Layer 1 (always visible) : Waveform + Play/Pause + seek thô bằng drag
//   Layer 2 (tap song info)  : Hiện progress bar + skip ±10s
//   Layer 3 (kéo sheet lên) : AB-Loop, Speed, Quick Actions

import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/waveform_data.dart';
import '../../providers/player_provider.dart';
import '../../providers/waveform_provider.dart';
import '../../widgets/ab_loop_controls.dart';
import '../../widgets/speed_control.dart';
import '../listen_mode/controllers/rolling_waveform_controller.dart';
import '../listen_mode/widgets/rolling_waveform_view.dart';

class ListenModeScreen extends StatefulWidget {
  const ListenModeScreen({super.key});

  @override
  State<ListenModeScreen> createState() => _ListenModeScreenState();
}

class _ListenModeScreenState extends State<ListenModeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late RollingWaveformController _waveformController;

  // Layer 2 toggle – tap song info để hiện/ẩn progress bar + skip
  bool _showProgressBar = false;

  // Bottom sheet controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _sheetExpanded = false;

  String? _lastSyncedPath;
  PlayerProvider? _playerProvider;
  WaveformProvider? _waveformProvider;

  // ★ FIX: Throttling để tránh tràn buffer đồ họa trên Windows
  DateTime _lastUiUpdate = DateTime.now();
  Duration _lastPosition = Duration.zero;

  // Trạng thái hiển thị của ứng dụng để giảm tải GPU
  bool _isAppVisible = true;
  bool _isUserSeeking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveformController = RollingWaveformController();
    // Đăng ký listener sau khi build frame đầu tiên để có context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // ★ FIX: Kiểm tra mounted trước khi dùng context
      _setupListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppVisible = state == AppLifecycleState.resumed;
    });
  }

  void _setupListeners() {
    final player = context.read<PlayerProvider>();
    final waveform = context.read<WaveformProvider>();

    _playerProvider = player;
    _waveformProvider = waveform;

    player.addListener(_onPlayerChange);
    waveform.addListener(_onWaveformChange);

    // Init state ban đầu
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
    _waveformController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ── LOGIC HANDLERS (Chạy ngoài build để tránh rebuild UI) ──

  void _onPlayerChange() {
    // ★ FIX: Bảo vệ Engine khi mất Context hoặc ứng dụng ẩn
    if (!mounted || !_isAppVisible) return;

    // ★ MỚI: Kiểm tra xem màn hình này có đang ở trên cùng không
    // Nếu có màn hình khác (Tools, Sheets) đè lên, ngừng cập nhật Waveform
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrentRoute) return;

    // Nếu người dùng đang kéo waveform, không cập nhật vị trí từ player
    // để tránh xung đột buffer và hiện tượng "giật ngược"
    if (_isUserSeeking) return;

    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null || !player.isPlaying) return;

    final now = DateTime.now();
    // ★ TỐI ƯU: Nâng ngưỡng lên 32ms (30fps) để giải phóng Buffer Queue trên các máy yếu
    if (now.difference(_lastUiUpdate).inMilliseconds < 32) return;

    // ★ FIX: Chỉ cập nhật nếu vị trí thực sự thay đổi (tránh spam khi đứng yên)
    if (player.state.position == _lastPosition) return;

    _lastUiUpdate = now;
    _lastPosition = player.state.position;

    // 1. Sync Waveform Loading
    if (player.currentSongPath != null &&
        waveform.currentFilePath != player.currentSongPath &&
        !waveform.isLoading) {
      waveform.loadWaveform(player.currentSongPath!, player.state.duration);
    }

    // 2. Update Position (High frequency)
    // Chỉ update controller, KHÔNG gọi setState
    _waveformController.updatePosition(player.state.position);

    // 3. Sync Loop Regions
    if (player.loopStart != null && player.loopEnd != null) {
      // Chỉ update khi có sự thay đổi để tối ưu
      if (_waveformController.loopRegions.isEmpty ||
          _waveformController.loopRegions.first.start != player.loopStart ||
          _waveformController.loopRegions.first.end != player.loopEnd) {
        _waveformController.clearLoopRegions();
        _waveformController.addLoopRegion(
            LoopRegion(start: player.loopStart!, end: player.loopEnd!));
      }
    } else if (_waveformController.loopRegions.isNotEmpty) {
      _waveformController.clearLoopRegions();
    }
  }

  void _onWaveformChange() {
    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null) return;

    // Sync Data to Controller
    if (waveform.waveformData.isNotEmpty &&
        waveform.currentFilePath == player.currentSongPath &&
        _lastSyncedPath != player.currentSongPath) {
      _lastSyncedPath = player.currentSongPath;
      _waveformController.setWaveformData(WaveformData(
        samples: waveform.waveformData,
        duration: player.state.duration,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng Selector để chỉ rebuild khi path thay đổi (load bài mới)
    // Các update position sẽ chạy ngầm qua controller
    return Selector<PlayerProvider, String?>(
      selector: (_, p) => p.currentSongPath,
      builder: (context, currentPath, _) {
        final player = context.read<PlayerProvider>();
        if (player.currentSongPath == null) {
          return _buildEmptyState(context);
        }

        return Stack(
          children: [
            // ── MAIN CONTENT ──────────────────────────────────
            Column(
              children: [
                // LAYER 1 + 2: Song Info (tapable)
                // Dùng Consumer riêng để chỉ rebuild phần này khi metadata đổi
                _SongInfoBar(
                  player: player,
                  showProgressBar: _showProgressBar,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showProgressBar = !_showProgressBar);
                  },
                ),

                // LAYER 1: Waveform – trái tim của màn hình
                Expanded(
                  child: Padding(
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
                        ),
                      ),
                    ),
                  ),
                ),

                // LAYER 1: Nút Play trung tâm + skip minimal
                // Dùng Consumer riêng
                Consumer<PlayerProvider>(
                  builder: (_, p, __) => _CorePlayerControls(
                    player: p,
                    sheetController: _sheetController,
                  ),
                ),

                // Spacer để nhường chỗ cho bottom sheet (collapsed)
                const SizedBox(height: 72),
              ],
            ),

            // ── BOTTOM SHEET (LAYER 3) ─────────────────────────
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.10, // Collapsed: chỉ thấy handle + label
              minChildSize: 0.10,
              maxChildSize: 0.55, // Expanded: hiện đủ controls nâng cao
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

  // ─────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text('Chưa có audio', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _pickAudioFile(context),
            icon: const Icon(Icons.add),
            label: const Text('Chọn file Audio'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null &&
          context.mounted) {
        await context.read<PlayerProvider>().loadSong(
              path: result.files.first.path!,
              title: result.files.first.name,
              autoPlay: true,
            );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// SONG INFO BAR – Layer 1 + 2
// Tap để toggle progress bar + skip buttons
// ═══════════════════════════════════════════════════════════════

class _SongInfoBar extends StatelessWidget {
  final PlayerProvider player;
  final bool showProgressBar;
  final VoidCallback onTap;

  const _SongInfoBar({
    required this.player,
    required this.showProgressBar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Song info row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // Album art
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

                  // Title + artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.currentSongTitle ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          player.currentSongArtist ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Indicator: kéo để xem thêm
                  AnimatedRotation(
                    turns: showProgressBar ? 0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_less,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Layer 2: Progress bar + skip (ẩn/hiện)
            if (showProgressBar) _buildLayer2(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLayer2(BuildContext context) {
    final position = player.state.position;
    final duration = player.state.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skip ±10 + thời gian
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Spacer(),
              // Skip -10
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  player.seek(
                    position - const Duration(seconds: 10) < Duration.zero
                        ? Duration.zero
                        : position - const Duration(seconds: 10),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.replay_10, color: Colors.white70, size: 22),
                ),
              ),
              // Skip +10
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  player.seek(position + const Duration(seconds: 10));
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child:
                      Icon(Icons.forward_10, color: Colors.white70, size: 22),
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Slim slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            thumbColor: const Color(0xFF6C63FF),
            activeTrackColor: const Color(0xFF6C63FF),
            inactiveTrackColor: Colors.white12,
            overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
          ),
          child: Slider(
            value: progress,
            onChanged: (v) => player.seekToPercent(v),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════════════
// CORE PLAYER CONTROLS – Layer 1
// Chỉ: Play/Pause ở giữa. Cực kỳ đơn giản.
// ═══════════════════════════════════════════════════════════════

class _CorePlayerControls extends StatelessWidget {
  final PlayerProvider player;
  final DraggableScrollableController sheetController;

  const _CorePlayerControls({
    required this.player,
    required this.sheetController,
  });

  void _toggleSheet(bool expand) {
    if (!sheetController.isAttached) return;
    
    sheetController.animateTo(
      expand ? 0.55 : 0.10,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
    );
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 100, // Tăng chiều cao để chứa chỉ báo chevron
        width: double
            .infinity, // ★ FIX: Mở rộng chiều ngang để badge dạt sang 2 bên
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // INDICATOR: Ký hiệu ^^ (Double Chevron)
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () => _toggleSheet(true),
                child: Column(
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_up,
                      size: 20,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            // CENTER: PLAY / PAUSE
            Positioned(
              top: 25,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  // Vuốt lên (velocity âm) -> Mở
                  if (details.primaryVelocity! < -300) {
                    _toggleSheet(true);
                  }
                  // Vuốt xuống (velocity dương) -> Đóng
                  else if (details.primaryVelocity! > 300) {
                    _toggleSheet(false);
                  }
                },
                onTap: () {
                  HapticFeedback.mediumImpact();
                  player.togglePlayPause();
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                    size: 32,
                  ),
                ),
              ),
            ),

            // LEFT: Loop badge
            if (player.isLooping)
              Positioned(
                left: 24,
                top: 40,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    player.clearLoop();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.loop,
                            size: 13, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 4),
                        Text(
                          '${player.loopCount}×',
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // RIGHT: Speed badge
            if (player.state.speed != 1.0)
              Positioned(
                right: 24,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${player.state.speed}×',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADVANCED SHEET – Layer 3
// DraggableScrollableSheet: kéo lên để xem AB-Loop, Speed, Actions
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
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          },
        ),
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle ──────────────────────────────────────
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

                  // ── FIX: Dùng AnimatedCrossFade thay vì if/else ──
                  // Tránh text bị "kẹt" khi sheet đang animate
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    // First: collapsed hint
                    firstChild: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune, size: 13, color: Colors.grey[600]),
                          const SizedBox(width: 5),
                          Text(
                            'Kéo lên để xem thêm',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Second: expanded content
                    secondChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Section: Loop
                        const _SheetSection(
                          title: 'AB Loop',
                          icon: Icons.loop,
                          iconColor: Color(0xFF4CAF50),
                          child: ABLoopControls(),
                        ),

                        const _Divider(),

                        // Section: Speed
                        const _SheetSection(
                          title: 'Tốc độ',
                          icon: Icons.speed,
                          iconColor: Colors.orange,
                          child: SpeedControlWidget(),
                        ),

                        const _Divider(),

                        // Section: Quick Actions
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

// ─────────────────────────────────────────────────────────────
// Sheet Section wrapper – title + icon + content
// ─────────────────────────────────────────────────────────────

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
      color: Colors.white.withOpacity(0.06),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Quick Actions Row
// ─────────────────────────────────────────────────────────────

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
            // TODO: add marker
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
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: sleep timer sheet
          },
        ),
        const SizedBox(width: 12),
        _QuickBtn(
          icon: Icons.share_outlined,
          label: 'Chia sẻ',
          color: const Color(0xFF2196F3),
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: share current position
          },
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
              : Colors.white.withOpacity(0.05),
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
