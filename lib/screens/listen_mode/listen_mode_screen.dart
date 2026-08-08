// lib/screens/listen_mode/listen_mode_screen.dart
// in2up – Listen Mode (v11 LRC Fix)
//
// CHANGELOG v11:
//   1. Double-tap: không ẩn waveform (sửa ở rolling_waveform_view.dart)
//   2. LRC display: widget lyrics đơn giản, nằm ngay dưới waveform, không overflow
//   3. Zoom controls: giữ nguyên auto-hide từ v10

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in2up_stt/models/stt_model_info.dart';
import 'package:in2up_stt/stt_service_facade.dart';
import 'package:provider/provider.dart';
import 'package:in2up/screens/understand_mode/understand_provider.dart';
import 'package:in2up/widgets/lrc_editor_panel.dart';

import '../../models/waveform_data.dart';
import '../../providers/player_provider.dart';
import '../../providers/waveform_provider.dart';
import '../../widgets/ab_loop_controls.dart';
import '../../widgets/speed_control.dart';
import '../listen_mode/controllers/rolling_waveform_controller.dart';
import '../listen_mode/widgets/rolling_waveform_view.dart';
import 'widgets/listen_library_screen.dart';
import 'widgets/quick_audio_sheet.dart';

enum _InlinePanel { repeat, speed, sleep, ab, ai }

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

  String? _lastSyncedPath;
  PlayerProvider? _playerProvider;
  WaveformProvider? _waveformProvider;

  bool _isAppVisible = true;
  bool _isUserSeeking = false;
  bool _isCurrentRoute = true;

  // ★ LRC state
  List<String> _lrcLines = [];
  bool _showLrcOnMain = false;
  bool _lrcAutoScroll = true;

  // LRC ScrollController for sophisticated LRC display
  late ScrollController _lrcScrollController;
  bool _autoScroll = true;

  bool _sheetOpen = false;
  bool _listenersSetup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveformController = RollingWaveformController();
    _lrcScrollController =
        ScrollController(); // Initialize LRC scroll controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupListeners();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;

    if (_isCurrentRoute && !_listenersSetup) {
      _setupListeners();
    }
    if (_isCurrentRoute && _listenersSetup) {
      _forceReloadWaveformIfNeeded();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _isAppVisible = state == AppLifecycleState.resumed);
  }

  void _setupListeners() {
    if (_listenersSetup) return;

    final player = context.read<PlayerProvider>();
    final waveform = context.read<WaveformProvider>();
    final understand = context.read<UnderstandProvider>();

    _playerProvider = player;
    _waveformProvider = waveform;

    player.addListener(_onPlayerChange);
    waveform.addListener(_onWaveformChange);
    understand.addListener(_onUnderstandChange);

    _listenersSetup = true;

    // Load LRC nếu đã có
    if (player.lastGeneratedLrcPath != null) {
      final understandProvider = context.read<UnderstandProvider>();
      if (understandProvider!.lrcLines.isNotEmpty) {
        _showLrcOnMain = true;
      }
    }

    _forceReloadWaveformIfNeeded();
  }

  void _forceReloadWaveformIfNeeded() {
    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null) return;

    final currentPath = player.currentSongPath;
    if (currentPath == null) return;

    final normalizedCurrent = _normalizePath(currentPath);
    final normalizedLoaded = _normalizePath(waveform.currentFilePath ?? '');

    final needsLoad = normalizedCurrent != normalizedLoaded ||
        waveform.waveformData.isEmpty ||
        _lastSyncedPath != currentPath;

    if (needsLoad && !waveform.isLoading) {
      debugPrint('🔄 Force loading waveform for: $currentPath');
      waveform.loadWaveform(currentPath, player.state.duration);

      // ★ FIX 1: Retry chain — 500ms, 1500ms, 3000ms
      _retryWaveformLoad(currentPath, 500);
      _retryWaveformLoad(currentPath, 1500);
      _retryWaveformLoad(currentPath, 3000);
    }

    // Sync data nếu đã có
    if (waveform.waveformData.isNotEmpty &&
        normalizedCurrent == normalizedLoaded) {
      _waveformController.setWaveformData(WaveformData(
        samples: waveform.displayWaveform,
        duration: player.state.duration,
      ));
      _lastSyncedPath = currentPath;
    }
  }

  void _retryWaveformLoad(String path, int delayMs) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      final p = _playerProvider;
      final w = _waveformProvider;
      if (p == null || w == null) return;
      // Chỉ retry nếu vẫn cùng bài và chưa có data
      if (p.currentSongPath == path &&
          (w.waveformData.isEmpty || _lastSyncedPath != path) &&
          !w.isLoading) {
        final duration = p.state.duration;
        if (duration > Duration.zero) {
          debugPrint('🔄 Retry waveform load (${delayMs}ms): $path');
          w.loadWaveform(path, duration);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerProvider?.removeListener(_onPlayerChange);
    _waveformProvider?.removeListener(_onWaveformChange);
    try {
      context.read<UnderstandProvider>().removeListener(_onUnderstandChange);
    } catch (_) {}
    _waveformController.setWaveformData(null);
    _waveformController.dispose();
    _lrcScrollController.dispose(); // Cleanup LRC scroll controller
    _sheetController.dispose();
    _listenersSetup = false;
    super.dispose();
  }

  // Auto-scroll to active LRC line (from UnderstandModeScreen)
  void _scrollToLine(int index) {
    if (!_lrcScrollController.hasClients || index < 0) return;

    const double estimatedLineHeight = 52.0; // Average height of a line item

    final targetOffset = index * estimatedLineHeight;
    final viewportHeight = _lrcScrollController.position.viewportDimension;
    final centerOffset =
        targetOffset - (viewportHeight / 2) + (estimatedLineHeight / 2);

    _lrcScrollController.animateTo(
      centerOffset.clamp(0.0, _lrcScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _normalizePath(String path) {
    return Uri.decodeFull(path.replaceAll('\\', '/').toLowerCase().trim());
  }

  void _onPlayerChange() {
    if (!mounted) return;
    if (_isUserSeeking) return;

    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null) return;

    final currentPath = player.currentSongPath;
    if (currentPath == null) return;

    final normalizedCurrent = _normalizePath(currentPath);
    final normalizedLoaded = _normalizePath(waveform.currentFilePath ?? '');

    // ★ FIX 1: Reload khi path khác, HOẶC khi duration thay đổi (file vừa load xong)
    final needsReload = normalizedCurrent != normalizedLoaded ||
        (waveform.waveformData.isEmpty &&
            !waveform.isLoading &&
            player.state.duration > Duration.zero) ||
        // ★ THÊM: Reload nếu duration đã có nhưng waveform load lần trước với duration=0
        (waveform.waveformData.isNotEmpty &&
            waveform.audioDuration == Duration.zero &&
            player.state.duration > Duration.zero);

    if (needsReload) {
      debugPrint('🔄 Triggering waveform reload: path=$normalizedCurrent');
      waveform.loadWaveform(currentPath, player.state.duration);
    }

    if (player.isPlaying) {
      _waveformController.updatePosition(player.state.position);
    }
    _syncLoopRegions(player);

    // ★ Update UnderstandProvider position cho synced lyrics
    if (_showLrcOnMain) {
      try {
        final understandProvider = context.read<UnderstandProvider>();
        understandProvider.updatePosition(player.state.position);
      } catch (_) {}
    }
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
    if (!mounted) return;

    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null) return;

    if (player.currentSongPath != null &&
        waveform.waveformData.isNotEmpty &&
        _normalizePath(waveform.currentFilePath ?? '') ==
            _normalizePath(player.currentSongPath!)) {
      _waveformController.setWaveformData(WaveformData(
        samples: waveform.displayWaveform,
        duration: player.state.duration,
      ));
      _lastSyncedPath = player.currentSongPath;
    }
  }

  void _onUnderstandChange() {
    if (!mounted) return;

    final understand = context.read<UnderstandProvider>();
    final hasLrcLines = understand.lrcLines.isNotEmpty;

    // Tự động hiển thị LRC panel khi có lyrics mới
    if (hasLrcLines && !_showLrcOnMain) {
      setState(() {
        _showLrcOnMain = true;
      });
    }

    // Auto-scroll to current line (from UnderstandModeScreen logic)
    final idx = understand.currentLineIndex;
    if (idx >= 0 && _autoScroll && hasLrcLines) {
      _scrollToLine(idx);
    }
  }

  // ★ Load LRC file và parse thành danh sách dòng text
  Future<void> _loadLrcFile(String lrcPath) async {
    try {
      final file = File(lrcPath);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final lines = <String>[];

      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Parse LRC format: [mm:ss.xx] text
        final match =
            RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(trimmed);
        if (match != null) {
          final text = match.group(4)?.trim() ?? '';
          if (text.isNotEmpty) {
            lines.add(text);
          }
        } else if (!trimmed.startsWith('[')) {
          // Plain text line
          lines.add(trimmed);
        }
      }

      if (mounted && lines.isNotEmpty) {
        setState(() {
          _lrcLines = lines;
          _showLrcOnMain = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading LRC: $e');
    }
  }

  void _openSheet() {
    setState(() => _sheetOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(0.55,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _closeSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(0.0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeIn);
    }
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _showWaveformActionSheet(Duration position) {
    final player = _playerProvider;
    if (player == null) return;
    final hasA = player.pendingLoopA != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(children: [
              const Text('📍', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('Tại ${_fmtDuration(position)}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          const Divider(color: Colors.white12, height: 16),
          ListTile(
            dense: true,
            leading: const Text('🅰️', style: TextStyle(fontSize: 18)),
            title: const Text('Đặt điểm A',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              player.setLoopPointA(position);
              HapticFeedback.selectionClick();
              _showSnack('✅ Điểm A tại ${_fmtDuration(position)}');
            },
          ),
          ListTile(
            dense: true,
            leading: const Text('🅱️', style: TextStyle(fontSize: 18)),
            title: Text('Đặt điểm B',
                style: TextStyle(
                    color: hasA ? Colors.white : Colors.grey[600],
                    fontSize: 14)),
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
          ListTile(
            dense: true,
            leading:
                Icon(Icons.my_location, color: Colors.blue.shade300, size: 20),
            title: const Text('Nhảy đến đây',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              player.seek(position);
              HapticFeedback.lightImpact();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 170),
          backgroundColor: const Color(0xFF6C63FF),
          duration: const Duration(milliseconds: 1200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, String?>(
      selector: (_, p) => p.currentSongPath,
      builder: (context, currentPath, _) {
        final player = context.read<PlayerProvider>();
        if (player.currentSongPath == null) {
          return const ListenLibraryScreen();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _forceReloadWaveformIfNeeded();
        });

        return SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // Song info
                  _SongInfoBar(
                    player: player,
                    onTitleTap: () => QuickAudioSheet.show(context),
                  ),

                  // ★ Waveform — chiếm ít hơn khi có LRC
                  Expanded(
                    flex: _showLrcOnMain ? 2 : 4,
                    child: _buildWaveform(player),
                  ),

                  // ★ FIX 3: Hiển thị Lyrics từ UnderstandProvider ngay khi có
                  if (_showLrcOnMain)
                    Consumer<UnderstandProvider>(
                      builder: (context, understand, _) {
                        if (understand!.lrcLines.isEmpty) {
                          return Flexible(
                            flex: 3,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  "Chưa có nội dung\nHãy tạo LRC từ STT",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          );
                        }

                        return Flexible(
                          flex: 3,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Header với nút đóng
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "LRC Lyrics",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.grey),
                                        onPressed: () => setState(
                                            () => _showLrcOnMain = false),
                                      ),
                                    ],
                                  ),
                                ),
                                // Sophisticated LRC ListView (from UnderstandModeScreen)
                                Expanded(
                                  child: ListView.builder(
                                    controller: _lrcScrollController,
                                    itemCount: understand!.lrcLines.length,
                                    itemBuilder: (context, index) {
                                      final line = understand.lrcLines[index];
                                      final isActive =
                                          index == understand.currentLineIndex;

                                      return GestureDetector(
                                        onTap: () {
                                          context
                                              .read<PlayerProvider>()
                                              .seek(line.timestamp);
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? const Color(0xFF6C63FF)
                                                    .withValues(alpha: 0.15)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            line.text,
                                            style: TextStyle(
                                              color: isActive
                                                  ? Colors.white
                                                  : Colors.grey[500],
                                              fontSize: isActive ? 16 : 14,
                                              fontWeight: isActive
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                              height: 1.4,
                                            ),
                                          )
                                        ),
                                        );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Controls
                  Consumer<PlayerProvider>(
                    builder: (_, p, __) => _CorePlayerControls(
                      player: p,
                      onOpenSheet: _openSheet,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
                ],
              ),

              // Sheet overlay (giữ nguyên)
              if (_sheetOpen) ...[
                GestureDetector(
                  onTap: _closeSheet,
                  child: Container(color: Colors.black54),
                ),
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.55,
                  minChildSize: 0.0,
                  maxChildSize: 0.85,
                  snap: true,
                  snapSizes: const [0.0, 0.55, 0.85],
                  builder: (context, scrollController) {
                    return NotificationListener<
                        DraggableScrollableNotification>(
                      onNotification: (n) {
                        if (n.extent <= 0.05) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _sheetOpen = false);
                          });
                        }
                        return false;
                      },
                      child: _AdvancedSheet(
                        scrollController: scrollController,
                        player: player,
                        onClose: _closeSheet,
                        onLrcApplied: () {
                          setState(() => _showLrcOnMain = true);
                          _closeSheet();
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveform(PlayerProvider player) {
    return Consumer2<PlayerProvider, WaveformProvider>(
      builder: (context, p, waveform, _) {
        final hasPath = p.currentSongPath != null;
        final isEmpty = waveform.waveformData.isEmpty;
        final isLoading = waveform.isLoading;
        final pathMismatch = hasPath &&
            _normalizePath(waveform.currentFilePath ?? '') !=
                _normalizePath(p.currentSongPath ?? '');

        if (isLoading || (isEmpty && hasPath && pathMismatch)) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    color: Color(0xFF6C63FF), strokeWidth: 2),
                SizedBox(height: 12),
                Text('Đang phân tích âm thanh...',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        if (isEmpty && hasPath && !isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, color: Colors.grey[700], size: 36),
                const SizedBox(height: 8),
                Text('Không hiển thị được sóng âm',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => waveform.loadWaveform(
                      p.currentSongPath!, p.state.duration),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

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
                    onSeekUpdate: (pos) {
                      _isUserSeeking = true;
                    },
                    onSeek: (pos) {
                      player.seek(pos);
                      _isUserSeeking = false;
                    },
                    onTap: () {
                      HapticFeedback.lightImpact();
                      player.togglePlayPause();
                    },
                    onDoubleTap: () {
                      HapticFeedback.lightImpact();
                      player.togglePlayPause();
                    },
                    onLongPressPosition: (position) {
                      HapticFeedback.mediumImpact();
                      _showWaveformActionSheet(position);
                    },
                    // ★ showControls = false vì zoom đã có _AutoHideZoomControls
                    showControls: false,
                  ),
                ),
              ),
            ),

            // Zoom controls
            Positioned(
              top: 6,
              left: 16,
              child: _AutoHideZoomControls(controller: _waveformController),
            ),

            if (isLoading)
              Positioned(
                top: 8,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF), strokeWidth: 1.5),
                    ),
                    const SizedBox(width: 6),
                    Text('Đang phân tích...',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 10)),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ★ FIX 2: LRC LYRICS PANEL — hiển thị text đơn giản, không overflow
// ═══════════════════════════════════════════════════════════════

// _LrcLyricsPanel removed - replaced with sophisticated LRC display from UnderstandModeScreen

// ═══════════════════════════════════════════════════════════════
// AUTO-HIDE ZOOM CONTROLS
// ═══════════════════════════════════════════════════════════════

class _AutoHideZoomControls extends StatefulWidget {
  final RollingWaveformController controller;
  const _AutoHideZoomControls({required this.controller});

  @override
  State<_AutoHideZoomControls> createState() => _AutoHideZoomControlsState();
}

class _AutoHideZoomControlsState extends State<_AutoHideZoomControls> {
  double _zoom = 1.0;
  bool _showSlider = false;
  Timer? _hideTimer;

  static const double _minZoom = 0.5;
  static const double _maxZoom = 8.0;

  void _setZoom(double z) {
    final clamped = z.clamp(_minZoom, _maxZoom);
    setState(() {
      _zoom = clamped;
      _showSlider = true;
    });
    widget.controller.setZoom(clamped);
    HapticFeedback.selectionClick();
    _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSlider = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(
            icon: Icons.remove,
            onTap: () => _setZoom(_zoom / 1.5),
            enabled: _zoom > _minZoom,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showSlider
                ? SizedBox(
                    width: 80,
                    height: 20,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 8),
                        thumbColor: const Color(0xFF6C63FF),
                        activeTrackColor: const Color(0xFF6C63FF),
                        inactiveTrackColor: Colors.white24,
                      ),
                      child: Slider(
                        value: _zoom,
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: (v) => _setZoom(v),
                        onChangeEnd: (_) => _restartHideTimer(),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => _setZoom(1.0),
                      child: Text(
                        '${_zoom.toStringAsFixed(1)}×',
                        style: TextStyle(
                          color: _zoom == 1.0 ? Colors.grey[500] : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
          _ZoomBtn(
            icon: Icons.add,
            onTap: () => _setZoom(_zoom * 1.5),
            enabled: _zoom < _maxZoom,
          ),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _ZoomBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 14, color: enabled ? Colors.white70 : Colors.white24),
      ),
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
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF5B52CC)]),
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
                      Row(children: [
                        Flexible(
                          child: Text(
                            player.currentSongTitle ?? 'Unknown',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: Color(0xFF6C63FF)),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        player.currentSongArtist ?? 'Nhấn để đổi audio',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          if (player.state.speed != 1.0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text('${player.state.speed}×',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CORE PLAYER CONTROLS
// ═══════════════════════════════════════════════════════════════

class _CorePlayerControls extends StatelessWidget {
  final PlayerProvider player;
  final VoidCallback onOpenSheet;

  const _CorePlayerControls({
    required this.player,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _SlimProgress(),
        ),
        const SizedBox(height: 6),
        _SeekAndPlayRow(player: player),
        const SizedBox(height: 2),
        _SmartActionBar(player: player, onOpenSheet: onOpenSheet),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ACTION TILE
// ═══════════════════════════════════════════════════════════════

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isActive;
  final String? badge;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: isActive ? 0.2 : 0.08);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: color.withValues(alpha: 0.35), width: 0.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                )),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!,
                    style: const TextStyle(fontSize: 9, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// INLINE PANELS
// ═══════════════════════════════════════════════════════════════

class _RepeatPanel extends StatelessWidget {
  final PlayerProvider player;
  const _RepeatPanel({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lặp lại',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          _LoopOptionChip(label: 'Tắt', value: 0, player: player),
          _LoopOptionChip(label: '1×', value: 1, player: player),
          _LoopOptionChip(label: '3×', value: 3, player: player),
          _LoopOptionChip(label: '5×', value: 5, player: player),
          _LoopOptionChip(label: '∞', value: -1, player: player),
        ]),
      ],
    );
  }
}

class _LoopOptionChip extends StatelessWidget {
  final String label;
  final int value;
  final PlayerProvider player;

  const _LoopOptionChip(
      {required this.label, required this.value, required this.player});

  @override
  Widget build(BuildContext context) {
    final isSelected = player.maxLoopCount == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => player.setLoopCount(value),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.2),
      labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.white70),
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  final PlayerProvider player;
  const _SpeedPanel({required this.player});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
      child: const SingleChildScrollView(child: SpeedControlWidget()),
    );
  }
}

class _SleepPanel extends StatelessWidget {
  final PlayerProvider player;
  const _SleepPanel({required this.player});

  @override
  Widget build(BuildContext context) {
    final minutes = (player.sleepDuration?.inMinutes ?? 30).clamp(5, 120);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hẹn giờ ngủ',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Slider(
          value: minutes.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          label: '$minutes phút',
          activeColor: const Color(0xFF6C63FF),
          onChanged: (v) => player.setSleepTimerMinutes(v.round()),
        ),
        Row(children: [
          ElevatedButton(
            onPressed: () => player.setSleepTimerMinutes(minutes),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child:
                Text('Đặt $minutes phút', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          if (player.hasSleepTimer)
            TextButton(
              onPressed: () => player.cancelSleepTimer(),
              child: const Text('Hủy',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ]),
      ],
    );
  }
}

class _ABLoopWithSilencePanel extends StatefulWidget {
  const _ABLoopWithSilencePanel();

  @override
  State<_ABLoopWithSilencePanel> createState() =>
      _ABLoopWithSilencePanelState();
}

class _ABLoopWithSilencePanelState extends State<_ABLoopWithSilencePanel> {
  bool _showSilenceOptions = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ABLoopControls(compact: true),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showSilenceOptions = !_showSilenceOptions);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _showSilenceOptions
                  ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: _showSilenceOptions
                  ? Border.all(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _showSilenceOptions
                    ? Icons.volume_off
                    : Icons.volume_off_outlined,
                size: 14,
                color: _showSilenceOptions
                    ? const Color(0xFFFF9800)
                    : Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text('Khoảng lặng',
                  style: TextStyle(
                    fontSize: 11,
                    color: _showSilenceOptions
                        ? const Color(0xFFFF9800)
                        : Colors.grey[500],
                    fontWeight: _showSilenceOptions
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
              const SizedBox(width: 4),
              Icon(
                _showSilenceOptions
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 14,
                color: Colors.grey[600],
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _showSilenceOptions
              ? _SilenceOptionsBox()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SilenceOptionsBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final silenceSec = player.silenceDuration.inSeconds;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thêm khoảng lặng giữa các lần lặp',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [0, 1, 2, 3, 5, 10].map((sec) {
                  final isSelected = silenceSec == sec;
                  return ChoiceChip(
                    label: Text(sec == 0 ? 'Tắt' : '${sec}s'),
                    selected: isSelected,
                    onSelected: (_) =>
                        player.setSilenceDuration(Duration(seconds: sec)),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    selectedColor:
                        const Color(0xFFFF9800).withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color:
                          isSelected ? const Color(0xFFFF9800) : Colors.white70,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AIPanel extends StatelessWidget {
  const _AIPanel();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GenerateLrcButton(),
            SizedBox(height: 12),
            LrcEditorPanel(
              initiallyExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SMART ACTION BAR
// ═══════════════════════════════════════════════════════════════

class _SmartActionBar extends StatefulWidget {
  final PlayerProvider player;
  final VoidCallback onOpenSheet;

  const _SmartActionBar({
    required this.player,
    required this.onOpenSheet,
  });

  @override
  State<_SmartActionBar> createState() => _SmartActionBarState();
}

class _SmartActionBarState extends State<_SmartActionBar> {
  _InlinePanel? _openPanel;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onPlayerStateChange);
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerStateChange);
    super.dispose();
  }

  void _onPlayerStateChange() {
    if (!mounted) return;

    bool needsUpdate = false;
    if (widget.player.shouldOpenAiPanel) {
      widget.player.consumeShouldOpenAiPanel();
      if (_openPanel != _InlinePanel.ai) {
        _openPanel = _InlinePanel.ai;
        needsUpdate = true;
      }
    }

    if (widget.player.lrcJustGenerated) {
      widget.player.consumeLrcJustGenerated();
      if (_openPanel != _InlinePanel.ai) {
        _openPanel = _InlinePanel.ai;
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      setState(() {});
    }
  }

  void _togglePanel(_InlinePanel panel) {
    HapticFeedback.selectionClick();
    setState(() => _openPanel = _openPanel == panel ? null : panel);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _openPanel != null
                  ? _buildInlinePanel(player)
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _ActionTile(
                    icon: Icons.repeat,
                    label: _repeatLabel(player),
                    color: const Color(0xFF4CAF50),
                    isActive: player.maxLoopCount != 0 ||
                        _openPanel == _InlinePanel.repeat,
                    onTap: () => _cycleRepeat(player),
                    onLongPress: () => _togglePanel(_InlinePanel.repeat),
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: Icons.straighten,
                    label: _abLabel(player),
                    color: const Color(0xFF6C63FF),
                    isActive: player.pendingLoopA != null ||
                        player.hasCompletedLoop ||
                        _openPanel == _InlinePanel.ab,
                    onTap: () => _handleAbTap(player),
                    onLongPress: () => _togglePanel(_InlinePanel.ab),
                    badge:
                        player.pendingLoopA != null && !player.hasCompletedLoop
                            ? 'A…'
                            : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: Icons.speed,
                    label: player.state.speed == 1.0
                        ? '1×'
                        : '${player.state.speed}×',
                    color: Colors.orange,
                    isActive: player.state.speed != 1.0 ||
                        _openPanel == _InlinePanel.speed,
                    onTap: () => _togglePanel(_InlinePanel.speed),
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: Icons.bookmark_add_outlined,
                    label: 'Dấu',
                    color: const Color(0xFFFFB300),
                    isActive: false,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSnack(
                          '📌 Đã đánh dấu ${_fmt(player.state.position)}');
                    },
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: player.hasSleepTimer
                        ? Icons.bedtime
                        : Icons.bedtime_outlined,
                    label: player.hasSleepTimer ? 'Huỷ' : '💤',
                    color: const Color(0xFF9C27B0),
                    isActive: player.hasSleepTimer ||
                        _openPanel == _InlinePanel.sleep,
                    onTap: () => _togglePanel(_InlinePanel.sleep),
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: Icons.auto_awesome,
                    label: 'AI',
                    color: Colors.blue,
                    isActive: _openPanel == _InlinePanel.ai,
                    onTap: () => _togglePanel(_InlinePanel.ai),
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: Icons.tune,
                    label: 'Thêm',
                    color: Colors.grey,
                    isActive: false,
                    onTap: () {
                      setState(() => _openPanel = null);
                      widget.onOpenSheet();
                    },
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlinePanel(PlayerProvider player) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: switch (_openPanel!) {
        _InlinePanel.repeat => _RepeatPanel(player: player),
        _InlinePanel.speed => _SpeedPanel(player: player),
        _InlinePanel.sleep => _SleepPanel(player: player),
        _InlinePanel.ab => const _ABLoopWithSilencePanel(),
        _InlinePanel.ai => const _AIPanel(),
      },
    );
  }

  void _cycleRepeat(PlayerProvider player) {
    HapticFeedback.selectionClick();
    if (player.hasCompletedLoop || player.pendingLoopA != null) {
      player.clearLoopPoints();
      player.setLoopCount(0);
      return;
    }
    const modes = [0, 1, 3, 5, -1];
    final idx = modes.indexOf(player.maxLoopCount).clamp(0, modes.length - 1);
    player.setLoopCount(modes[(idx + 1) % modes.length]);
  }

  void _handleAbTap(PlayerProvider player) {
    final pos = player.state.position;
    if (!player.hasCompletedLoop && player.pendingLoopA == null) {
      player.setLoopPointA(pos);
      HapticFeedback.selectionClick();
      _showSnack('🅰️ Điểm A: ${_fmt(pos)}');
    } else if (player.pendingLoopA != null && !player.hasCompletedLoop) {
      player.setLoopPointB(pos);
      HapticFeedback.mediumImpact();
      _showSnack('✅ Vùng A→B đã tạo – giữ để xem chi tiết');
    } else {
      _togglePanel(_InlinePanel.ab);
    }
  }

  String _repeatLabel(PlayerProvider player) {
    if (player.hasCompletedLoop || player.pendingLoopA != null) return 'A→B';
    return switch (player.maxLoopCount) {
      0 => 'Lặp',
      1 => '1×',
      3 => '3×',
      5 => '5×',
      -1 => '∞',
      _ => '${player.maxLoopCount}×',
    };
  }

  String _abLabel(PlayerProvider p) {
    if (p.hasCompletedLoop) return 'A══B';
    if (p.pendingLoopA != null) return 'A…B';
    return 'A─B';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 170),
          backgroundColor: const Color(0xFF6C63FF),
          duration: const Duration(milliseconds: 1200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════════════
// SLIM PROGRESS
// ═══════════════════════════════════════════════════════════════

class _SlimProgress extends StatelessWidget {
  const _SlimProgress();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final pos = player.state.position;
        final dur = player.state.duration;
        final durMs = dur.inMilliseconds;
        final posMs = pos.inMilliseconds;
        final pct =
            (durMs > 0 && posMs >= 0) ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
        final safePct = pct.isNaN || pct.isInfinite ? 0.0 : pct;

        return Row(children: [
          Text(_fmt(pos),
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                thumbColor: const Color(0xFF6C63FF),
                activeTrackColor: const Color(0xFF6C63FF),
                inactiveTrackColor: Colors.white12,
              ),
              child: Slider(
                value: safePct,
                min: 0.0,
                max: 1.0,
                onChanged: durMs > 0 ? (v) => player.seekToPercent(v) : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(_fmt(dur),
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]);
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════════════
// SEEK + PLAY
// ═══════════════════════════════════════════════════════════════

class _SeekAndPlayRow extends StatelessWidget {
  final PlayerProvider player;
  const _SeekAndPlayRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeekBtn(icon: Icons.replay_10, onTap: () => _seek(-10)),
        const SizedBox(width: 16),
        _PlayButton(player: player),
        const SizedBox(width: 16),
        _SeekBtn(icon: Icons.forward_10, onTap: () => _seek(10)),
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
              colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)]),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
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

// ═══════════════════════════════════════════════════════════════
// GENERATE LRC BUTTON
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Text(progress.message,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[400]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  crossFadeState: isActive
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
                const SizedBox(height: 8),
                _LrcModelSelector(
                  isProcessing: isActive || provider.isGeneratingLrc,
                  onGenerate: (level) =>
                      provider.generateLrcForCurrentAudio(level: level),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.read<SttServiceFacade>().startListening(),
                      icon: const Icon(Icons.mic),
                      label: const Text('Shadowing'),
                    ),
                  ],
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
  final Future<SttTranscribeOutput?> Function(WhisperModelLevel?) onGenerate;

  const _LrcModelSelector(
      {required this.isProcessing, required this.onGenerate});

  @override
  State<_LrcModelSelector> createState() => _LrcModelSelectorState();
}

class _LrcModelSelectorState extends State<_LrcModelSelector> {
  WhisperModelLevel? _selectedLevel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: const Text('AUTO'),
            selected: _selectedLevel == null,
            onSelected: widget.isProcessing
                ? null
                : (_) => setState(() => _selectedLevel = null),
          ),
          ...WhisperModelLevel.values.map((level) {
            final info = context.read<PlayerProvider>().getSttModelInfo(level);
            final isSelected = _selectedLevel == level;
            return FilterChip(
              label: Text(
                '${level.name.toUpperCase()} (${level.sizeInMB}MB)'
                '${info.isReady ? ' ✓' : ''}',
              ),
              selected: isSelected,
              onSelected: widget.isProcessing
                  ? null
                  : (_) => setState(
                      () => _selectedLevel = isSelected ? null : level),
            );
          }),
        ]),
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
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADVANCED SHEET
// ═══════════════════════════════════════════════════════════════

class _AdvancedSheet extends StatelessWidget {
  final ScrollController scrollController;
  final PlayerProvider player;
  final VoidCallback onClose;
  final VoidCallback onLrcApplied;

  const _AdvancedSheet({
    required this.scrollController,
    required this.player,
    required this.onClose,
    required this.onLrcApplied,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 40),
                        Container(
                          width: 36,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onClose,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.close,
                                size: 16, color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _SheetSection(
                    title: 'AB Loop',
                    icon: Icons.loop,
                    iconColor: Color(0xFF4CAF50),
                    child: ABLoopControls(),
                  ),
                  const _SheetDivider(),
                  _SheetSection(
                    title: 'Tốc độ',
                    icon: Icons.speed,
                    iconColor: Colors.orange,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: const SingleChildScrollView(
                          child: SpeedControlWidget()),
                    ),
                  ),
                  const _SheetDivider(),
                  const _SheetSection(
                    title: 'Trí tuệ nhân tạo',
                    icon: Icons.auto_awesome,
                    iconColor: Colors.blue,
                    child: GenerateLrcButton(),
                  ),
                  const SizedBox(height: 12),
                  LrcEditorPanel(
                    initiallyExpanded: true,
                    title: 'LRC Editor',
                    onLrcApplied: onLrcApplied,
                  ),
                  const SizedBox(height: 16),
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
          Row(children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                )),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

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
