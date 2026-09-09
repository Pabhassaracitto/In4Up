// lib/screens/listen_mode/listen_mode_screen.dart
// in4up – Listen Mode (v11 LRC Fix)
//
// CHANGELOG v11:
//   1. Double-tap: không ẩn waveform (sửa ở rolling_waveform_view.dart)
//   2. LRC display: widget lyrics đơn giản, nằm ngay dưới waveform, không overflow
//   3. Zoom controls: giữ nguyên auto-hide từ v10

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:in4up_stt/models/stt_config.dart';
import 'package:in4up_stt/models/stt_model_info.dart';
import 'package:in4up_stt/stt_service_facade.dart';
import 'package:in4up_stt/diarization/speaker_sidecar.dart';
import 'package:in4up_stt/models/content_id.dart';
import 'package:provider/provider.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up/providers/karaoke_settings_provider.dart';
import 'package:in4up/widgets/karaoke_lyrics_line.dart';
import 'package:in4up/widgets/karaoke_settings_sheet.dart';
import 'package:in4up/widgets/lrc_editor_panel.dart';

import '../../models/waveform_data.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/soundlist_provider.dart';
import '../../providers/text_provider.dart';
import '../../providers/waveform_provider.dart';
import '../../widgets/ab_loop_controls.dart';
import '../../widgets/sound_mark_edit_sheet.dart';
import '../../widgets/speed_control.dart';
import '../listen_mode/controllers/rolling_waveform_controller.dart';
import '../listen_mode/widgets/rolling_waveform_view.dart';
import '../listen_mode/widgets/rolling_waveform_painter.dart';
import '../understand_mode/services/lrc_translation_resolver.dart';
import 'widgets/generate_lrc_actions.dart';
import 'widgets/listen_library_screen.dart';
import 'widgets/quick_audio_sheet.dart';
import 'widgets/soundlist_panel.dart';
import '../../features/voice_command/voice_command_service.dart';
import '../../features/voice_command/voice_command_parser.dart';
import '../../features/voice_command/voice_command_localizations.dart';

enum _InlinePanel { repeat, speed, sleep, ab }

double _inlinePanelMaxHeight(double viewportHeight) {
  final factor = viewportHeight < 600
      ? 0.26
      : viewportHeight < 800
          ? 0.28
          : 0.30;
  return (viewportHeight * factor).clamp(104.0, 280.0);
}

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
  final DraggableScrollableController _aiSheetController =
      DraggableScrollableController();

  String? _lastSyncedPath;
  String? _visibleAudioPath;
  PlayerProvider? _playerProvider;
  WaveformProvider? _waveformProvider;
  SoundlistProvider? _soundlistProvider;
  bool _prevAutoTocRunning = false;

  bool _isAppVisible = true;
  bool _isUserSeeking = false;
  bool _isCurrentRoute = true;
  late final VoiceCommandService _voiceCommandService;
  bool _voiceListening = false;
  String _lastVoiceText = '';

  // ★ LRC state - curtain style
  List<String> _lrcLines = [];
  bool _showLrcOnMain = false;
  Map<String, int> _speakerColorMap = const {};
  bool _lrcAutoScroll = true;
  double _lrcHeight = 220.0; // current curtain height - responsive, smaller default for SE
  static const double _lrcMinHeight = 64.0; // when collapsed, show handle
  static const double _lrcDefaultHeight = 220.0;
  double _lrcDragStartHeight = 320.0;

  // LISTEN-630-01: panel inline (AB loop / tốc độ / AI) đang mở —
  // rèm LRC phải nhường chỗ để không bottom overflow che thanh điều hướng
  bool _inlinePanelOpen = false;

  // LRC ScrollController for sophisticated LRC display
  late ScrollController _lrcScrollController;
  bool _autoScroll = true;

  /// Khi người dùng đang tự kéo danh sách → tạm tắt auto-scroll để không
  /// giật ngược vị trí (issue: kéo thủ công không được).
  bool _userScrollingLrc = false;

  bool _sheetOpen = false;
  bool _aiSheetOpen = false;
  bool _aiSheetClosing = false;
  bool _listenersSetup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveformController = RollingWaveformController();
    _voiceCommandService = VoiceCommandService();
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

  /// Theo dõi job "Tự tạo mục lục" chạy nền → snackbar khi hoàn tất.
  void _onSoundlistChange() {
    final soundlist = _soundlistProvider;
    if (soundlist == null) return;
    final running = soundlist.autoTocRunning;
    if (_prevAutoTocRunning && !running) {
      final err = soundlist.autoTocError;
      final result = soundlist.lastAutoTocResult;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      if (err != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('⚠️ Không tạo được mục lục: $err'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 170),
          backgroundColor: const Color(0xFFEF5350),
        ));
      } else if (result != null && result.chapters.isNotEmpty) {
        messenger.showSnackBar(SnackBar(
          content: Text('✅ Đã tạo ${result.chapters.length} mục lục'
              '${result.usedWhisper ? ' (Whisper tự đặt tên)' : ''}'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 170),
          backgroundColor: const Color(0xFF26C6DA),
        ));
      } else {
        messenger.showSnackBar(const SnackBar(
          content: Text('⚠️ Không tạo được mục lục (không rõ nguyên nhân)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFEF5350),
        ));
      }
    }
    _prevAutoTocRunning = running;
  }

  void _setupListeners() {
    if (_listenersSetup) return;

    final player = context.read<PlayerProvider>();
    final waveform = context.read<WaveformProvider>();
    final understand = context.read<UnderstandProvider>();
    final soundlist = context.read<SoundlistProvider>();

    _playerProvider = player;
    _waveformProvider = waveform;
    _visibleAudioPath = player.currentSongPath;
    _soundlistProvider = soundlist;

    player.addListener(_onPlayerChange);
    waveform.addListener(_onWaveformChange);
    understand.addListener(_onUnderstandChange);
    soundlist.addListener(_onSoundlistChange);

    _listenersSetup = true;

    // Load LRC nếu đã có
    if (player.lastGeneratedLrcPath != null) {
      _loadLrcFile(player.lastGeneratedLrcPath!);
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

    // FIX OOM v4: neu dang transcribe thi KHONG reload waveform de tranh double FFmpeg + ExoPlayer ton RAM
    try {
      if (player.isGeneratingLrc) {
        debugPrint('⏭️ Skip waveform reload during transcription to save RAM');
        return;
      }
    } catch (_) {}

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
    _soundlistProvider?.removeListener(_onSoundlistChange);
    try {
      context.read<UnderstandProvider>().removeListener(_onUnderstandChange);
    } catch (_) {}
    // FIX (Nghe→Viết màn đỏ): dispose TRƯỚC — setWaveformData sau dispose
    // là no-op nhờ guard _disposed của controller. Gọi setWaveformData
    // TRƯỚC dispose (như cũ) = notifyListeners() giữa pha unmount →
    // AnimatedBuilder còn sống gọi setState during build → màn đỏ vài giây.
    _waveformController.dispose();
    _voiceCommandService.dispose();
    _lrcScrollController.dispose(); // Cleanup LRC scroll controller
    _sheetController.dispose();
    _aiSheetController.dispose();
    _listenersSetup = false;
    super.dispose();
  }

  // Auto-scroll to active LRC line - improved, không trật màn hình
  void _scrollToLine(int index) {
    if (!_lrcScrollController.hasClients || index < 0) return;
    if (_lrcHeight < _lrcMinHeight) return; // panel đang ẩn hoặc quá nhỏ

    try {
      final position = _lrcScrollController.position;
      if (!position.hasContentDimensions) return;

      final viewportHeight = position.viewportDimension;
      if (viewportHeight <= 0) return;

      const estimatedLineHeight = 52.0;
      final targetOffset = index * estimatedLineHeight;
      // Karaoke centered in middle for best visibility (was 0.35 top, hidden above)
      final desiredCenter = viewportHeight * 0.5;
      final centerOffset =
          targetOffset - desiredCenter + (estimatedLineHeight / 2);

      if (position.maxScrollExtent <= 0) return;
      final clamped = centerOffset.clamp(0.0, position.maxScrollExtent);

      // Luôn scroll để dòng karaoke ở giữa, không skip khi inView (fix ẩn trên nhiều)
      if ((position.pixels - clamped).abs() > 8) {
        _lrcScrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      debugPrint('[LRC] scrollToLine error: $e');
    }
  }

  String _normalizePath(String path) {
    try {
      return Uri.decodeFull(path.replaceAll("\\", "/").toLowerCase().trim());
    } catch (_) {
      // Fallback khi path chứa ký tự % không hợp lệ (ví dụ file .m4a có ’ hoặc %)
      return path.replaceAll("\\", "/").toLowerCase().trim();
    }
  }

  void _onPlayerChange() {
    if (!mounted) return;

    final player = _playerProvider;
    final waveform = _waveformProvider;
    if (player == null || waveform == null) return;

    final currentPath = player.currentSongPath;
    final audioChanged = (_visibleAudioPath == null) != (currentPath == null) ||
        (_visibleAudioPath != null &&
            currentPath != null &&
            _normalizePath(_visibleAudioPath!) != _normalizePath(currentPath));
    if (audioChanged) {
      _visibleAudioPath = currentPath;
      // Dispose the old editor/panel state together with its transcript. This
      // prevents an old AI editor from applying audio A's text to audio B.
      setState(() {
        _showLrcOnMain = false;
        _lrcHeight = _lrcDefaultHeight;
        _inlinePanelOpen = false;
        _aiSheetOpen = false;
        _aiSheetClosing = false;
      });
    }

    if (_isUserSeeking || currentPath == null) return;
    if (player.isGeneratingLrc) return; // FIX OOM v4: skip reload during transcription

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
    } else if (!hasLrcLines && _showLrcOnMain) {
      // Đã đổi bài / clear → ẩn panel lyrics cũ đi, tránh giữ chữ bài cũ.
      setState(() {
        _showLrcOnMain = false;
      });
    }

    // Auto-scroll to current line (from UnderstandModeScreen logic)
    final idx = understand.currentLineIndex;
    // Chỉ auto-scroll khi user KHÔNG đang tự kéo danh sách.
    if (idx >= 0 && _autoScroll && !_userScrollingLrc && hasLrcLines) {
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
      final segments = <WaveformSegmentRef>[];

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
            final min = int.parse(match.group(1)!);
            final sec = int.parse(match.group(2)!);
            final fraction = match.group(3)!;
            final ms = min * 60000 + sec * 1000 +
                int.parse(fraction) * (fraction.length == 2 ? 10 : 1);
            segments.add(WaveformSegmentRef(
              uid: '',
              joinKey: ContentId.joinKey(startMs: ms, text: text),
              startMs: ms,
              endSeconds: (ms + 3000) / 1000.0,
            ));
          }
        } else if (!trimmed.startsWith('[')) {
          // Plain text line
          lines.add(trimmed);
        }
      }

      final speakerMap = await SpeakerSidecar.loadSpeakerMap(lrcPath);
      if (mounted && lines.isNotEmpty) {
        setState(() {
          _lrcLines = lines;
          _speakerColorMap = speakerMap;
          _showLrcOnMain = true;
        });
        final data = _waveformController.waveformData;
        if (data != null && segments.isNotEmpty) {
          _waveformController.setWaveformData(data.withSegments(segments));
        }
      }
    } catch (e) {
      debugPrint('Error loading LRC: $e');
    }
  }

  Widget _buildSpeakerLegend() {
    final speakers = _speakerColorMap.values.where((id) => id > 0).toSet().toList()
      ..sort();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: speakers.map((id) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: kSpeakerColors[id], shape: BoxShape.circle,
              )),
              const SizedBox(width: 4),
              Text('Người $id', style: const TextStyle(color: Colors.white, fontSize: 10)),
            ]),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildVoiceCommandButton() {
    final locale = context.read<LocaleProvider>().locale?.languageCode ?? 'vi';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _voiceListening ? null : _startVoiceCommands,
          icon: Icon(_voiceListening ? Icons.mic : Icons.mic_none, size: 14),
          label: Text(
            _voiceListening
                ? voiceCommandLabel(locale, 'listening')
                : 'Voice commands',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        if (_lastVoiceText.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            '${voiceCommandLabel(locale, 'received')}: $_lastVoiceText',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ],
    );
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

  void _openAiSheet() {
    if (_aiSheetOpen) return;
    setState(() {
      _aiSheetOpen = true;
      _aiSheetClosing = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_aiSheetController.isAttached) return;
      _aiSheetController.jumpTo(0.55);
    });
  }

  void _closeAiSheet({bool animate = true}) {
    if (!_aiSheetOpen || _aiSheetClosing) return;
    _aiSheetClosing = true;

    if (animate && _aiSheetController.isAttached) {
      _aiSheetController
          .animateTo(
            0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInCubic,
          )
          .whenComplete(() {
        if (!mounted) return;
        setState(() {
          _aiSheetOpen = false;
          _aiSheetClosing = false;
        });
      });
      return;
    }

    setState(() {
      _aiSheetOpen = false;
      _aiSheetClosing = false;
    });
  }

  void _toggleAiSheet(bool open) {
    if (open) {
      _openAiSheet();
    } else {
      _closeAiSheet();
    }
  }

  void _handleLrcGenerated() {
    if (!mounted) return;
    setState(() {
      _showLrcOnMain = true;
      // Builder clamps this sentinel to the exact local maximum, so the LRC
      // curtain touches the waveform regardless of device/shell height.
      _lrcHeight = double.maxFinite;
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
              Text(context.uiText('Tại ${_fmtDuration(position)}'),
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
          content: Text(context.uiText(message)),
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

  Future<void> _startVoiceCommands() async {
    if (_voiceListening) return;
    final locale = context.read<LocaleProvider>().locale?.languageCode ?? 'vi';

    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(voiceCommandLabel(locale, 'permissionDenied'))),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ VoiceCommands mic permission check exception: $e');
    }

    setState(() => _voiceListening = true);
    final player = context.read<PlayerProvider>();
    final sttLang = locale == 'vi' ? 'vi-VN' : 'en-US';

    final started = await _voiceCommandService.start(
      language: sttLang,
      onPartial: (text) { if (mounted) setState(() => _lastVoiceText = text); },
      onCommand: (command) async {
        switch (command.type) {
          case VoiceCommandType.play:
          case VoiceCommandType.pause: await player.togglePlayPause(); break;
          case VoiceCommandType.next: player.playNextSegment(); break;
          case VoiceCommandType.previous: await player.playPreviousSegment(); break;
          case VoiceCommandType.faster: await player.increaseSpeed(); break;
          case VoiceCommandType.slower: await player.decreaseSpeed(); break;
          case VoiceCommandType.toggleLyrics:
            if (mounted) setState(() => _showLrcOnMain = !_showLrcOnMain); break;
          case VoiceCommandType.translate: break;
        }
      },
    );
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(voiceCommandLabel(locale, 'noModel'))),
      );
    }
    if (mounted) setState(() => _voiceListening = false);
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
          child: LayoutBuilder(
            builder: (context, listenConstraints) {
              final listenViewportH = listenConstraints.maxHeight;
              return Stack(
                children: [
              Column(
                children: [
                  // Song info
                  _SongInfoBar(
                    player: player,
                    onTitleTap: () => QuickAudioSheet.show(context),
                  ),

                  // ★ Waveform — chiếm phần còn lại, khi LRC mở thì tự thu nhỏ
                  Expanded(
                    child: _buildWaveform(player),
                  ),

                  // ★ LRC CURTAIN: kéo được như rèm, chạm chân sóng, ẩn hiện linh hoạt
                  // Thay vì Flexible cố định, dùng Container với _lrcHeight có thể kéo
                  if (_showLrcOnMain)
                    Consumer<UnderstandProvider>(
                      builder: (context, understand, _) {
                        final hasLines = understand!.lrcLines.isNotEmpty;
                        // LISTEN-630-01: budget chiều cao rèm LRC = màn hình
                        // trừ (song info + controls + panel inline đang mở +
                        // bottom padding + waveform tối thiểu) — hết bottom
                        // overflow che thanh điều hướng khi bật lặp AB.
                        // Dùng đúng chiều cao viewport của tab Nghe, không dùng
                        // MediaQuery toàn màn hình (bao gồm app bar + bottom
                        // navigation). Sai lệch đó chính là nguồn overflow ~126px.
                        final bottomPad =
                            MediaQuery.of(context).padding.bottom + 4;
                        const controlsBase = 178.0;
                        const waveformMin = 64.0;
                        const songInfoH = 68.0;
                        final panelReserve = _inlinePanelOpen
                            ? _inlinePanelMaxHeight(listenViewportH) + 14
                            : 0.0;
                        final maxH = (listenViewportH -
                                songInfoH -
                                controlsBase -
                                panelReserve -
                                bottomPad -
                                waveformMin)
                            .clamp(_lrcMinHeight, 650.0);
                        final dragAction = context.uiText(
                          _lrcHeight > maxH * 0.8 ? 'thu nhỏ' : 'mở rộng',
                        );
                        final tapAction = context.uiText(
                          _lrcHeight < maxH * 0.9 ? 'mở toàn màn hình' : 'thu gọn',
                        );

                        // Clamp current height
                        if (_lrcHeight > maxH) _lrcHeight = maxH;
                        if (_lrcHeight < _lrcMinHeight) _lrcHeight = _lrcMinHeight;

                        if (!hasLines) {
                          return Container(
                            height: 120,
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
                          );
                        }

                        return Container(
                          height: _lrcHeight,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Drag handle - curtain: kéo như rèm
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (d) {
                                  _lrcDragStartHeight = _lrcHeight;
                                },
                                onVerticalDragUpdate: (d) {
                                  // Kéo lên => tăng height, kéo xuống => giảm
                                  // Dùng delta.dy: kéo lên delta âm, nên -delta => tăng
                                  final delta = -d.delta.dy;
                                  setState(() {
                                    _lrcHeight = (_lrcHeight + delta)
                                        .clamp(_lrcMinHeight, maxH);
                                  });
                                },
                                onVerticalDragEnd: (d) {
                                  final velocity = d.primaryVelocity ?? 0;
                                  // Vuốt xuống nhanh (velocity >0) -> ẩn
                                  if (velocity > 700) {
                                    setState(() {
                                      _showLrcOnMain = false;
                                      _lrcHeight = _lrcDefaultHeight;
                                    });
                                    HapticFeedback.mediumImpact();
                                  } else if (_lrcHeight < 96) {
                                    // Kéo thấp quá -> ẩn
                                    setState(() {
                                      _showLrcOnMain = false;
                                      _lrcHeight = _lrcDefaultHeight;
                                    });
                                    HapticFeedback.lightImpact();
                                  } else if (_lrcHeight < 180) {
                                    // Snap về min
                                    setState(() {
                                      _lrcHeight = _lrcMinHeight + 32;
                                    });
                                  }
                                },
                                onTap: () {
                                  // Tap handle để toggle full / default
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (_lrcHeight < maxH * 0.85) {
                                      _lrcHeight = maxH;
                                    } else {
                                      _lrcHeight = _lrcDefaultHeight;
                                    }
                                  });
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.03),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14)),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.keyboard_arrow_up_rounded,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.uiText('Kéo để $dragAction • chạm để $tapAction'),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Header với title + actions
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.06)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lyrics_outlined,
                                        size: 14,
                                        color: Color(0xFF6C63FF)),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        context.uiText("LRC ${understand.lrcLines.length} dòng"),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Spacer(),
                                    // Auto-scroll toggle compact
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _autoScroll = !_autoScroll;
                                        });
                                        HapticFeedback.selectionClick();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _autoScroll
                                              ? const Color(0xFF4CAF50)
                                                  .withValues(alpha: 0.15)
                                              : Colors.white
                                                  .withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _autoScroll
                                                  ? Icons.auto_awesome_mosaic
                                                  : Icons
                                                      .auto_awesome_mosaic_outlined,
                                              size: 10,
                                              color: _autoScroll
                                                  ? const Color(0xFF4CAF50)
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              _autoScroll ? "Auto" : "Off",
                                              style: TextStyle(
                                                color: _autoScroll
                                                    ? const Color(0xFF4CAF50)
                                                    : Colors.grey,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _LrcIconBtn(
                                      icon: Icons.tune,
                                      tooltip: context.uiText('Tuỳ chỉnh'),
                                      onTap: () =>
                                          KaraokeSettingsSheet.show(context),
                                    ),
                                    _LrcIconBtn(
                                      icon: Icons.close_fullscreen_rounded,
                                      tooltip: context.uiText('Thu nhỏ'),
                                      onTap: () {
                                        setState(() {
                                          if (_lrcHeight > 140) {
                                            _lrcHeight = 140;
                                          } else {
                                            _showLrcOnMain = false;
                                            _lrcHeight = _lrcDefaultHeight;
                                          }
                                        });
                                      },
                                    ),
                                    _LrcIconBtn(
                                      icon: Icons.close,
                                      tooltip: context.uiText('Ẩn'),
                                      onTap: () => setState(() {
                                        _showLrcOnMain = false;
                                        _lrcHeight = _lrcDefaultHeight;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              // LRC List
                              Expanded(
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    if (n is ScrollStartNotification) {
                                      _userScrollingLrc = true;
                                    } else if (n is ScrollEndNotification) {
                                      _userScrollingLrc = false;
                                      // Sau 2.5s không kéo thì bật lại auto-scroll
                                      Future.delayed(
                                          const Duration(milliseconds: 2500),
                                          () {
                                        if (mounted &&
                                            !_userScrollingLrc) {
                                          // không làm gì, chỉ reset cờ cho lần sau
                                        }
                                      });
                                    }
                                    return false;
                                  },
                                  child: ListView.builder(
                                    controller: _lrcScrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding:
                                        const EdgeInsets.only(bottom: 72),
                                    itemCount: understand.lrcLines.length,
                                    itemBuilder: (context, index) {
                                      final line =
                                          understand.lrcLines[index];
                                      final isActive = index ==
                                          understand.currentLineIndex;

                                      // Dùng cùng resolver với tab Hiểu để bản
                                      // dịch đã tạo ở tab Đọc hiển thị nhất quán.
                                      final lrcTranslation =
                                          resolveLrcTranslation(
                                        context.read<TextProvider>().lines,
                                        line.text,
                                      );

                                      return GestureDetector(
                                        onTap: () {
                                          context
                                              .read<PlayerProvider>()
                                              .seek(line.timestamp);
                                          HapticFeedback.selectionClick();
                                        },
                                        onLongPress: () {
                                          // Copy text
                                          Clipboard.setData(ClipboardData(
                                              text: line.text));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    "Đã copy lời thoại"),
                                                duration:
                                                    Duration(seconds: 1)),
                                          );
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 220),
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? const Color(0xFF6C63FF)
                                                    .withValues(alpha: 0.14)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: isActive
                                                ? Border.all(
                                                    color:
                                                        const Color(0xFF6C63FF)
                                                            .withValues(
                                                                alpha: 0.25),
                                                    width: 1)
                                                : null,
                                          ),
                                          child: Consumer<
                                              KaraokeSettingsProvider>(
                                            builder: (_, karaoke, __) =>
                                                KaraokeLyricsLine(
                                              line: line,
                                              isActive: isActive,
                                              words: understand
                                                  .wordsForLine(index),
                                              activeWordIndex: isActive
                                                  ? understand
                                                      .currentWordIndex
                                                  : -1,
                                              style: karaoke.style,
                                              translation: lrcTranslation,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Bottom hint to drag down to close
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  "Vuốt xuống để ẩn • Nhấn dòng để nhảy tới",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 9,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  // Khi ẩn nhưng vẫn có LRC -> hiện pill để mở lại
                  Consumer<UnderstandProvider>(
                    builder: (context, understand, _) {
                      if (_showLrcOnMain) return const SizedBox.shrink();
                      if (understand!.lrcLines.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _showLrcOnMain = true;
                            _lrcHeight = _lrcDefaultHeight;
                          }),
                          onVerticalDragUpdate: (d) {
                            if (d.delta.dy < -6) {
                              // kéo lên
                              setState(() {
                                _showLrcOnMain = true;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lyrics,
                                    size: 16, color: Color(0xFF8B83FF)),
                                const SizedBox(width: 8),
                                Text(
                                  context.uiText("Hiện LRC • ${understand.lrcLines.length} dòng • Kéo lên để mở"),
                                  style: const TextStyle(
                                    color: Color(0xFF8B83FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.keyboard_arrow_up_rounded,
                                    size: 16, color: Color(0xFF8B83FF)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Controls
                  Consumer<PlayerProvider>(
                    builder: (_, p, __) => _CorePlayerControls(
                      key: ValueKey('listen-controls-${p.currentSongPath}'),
                      player: p,
                      viewportHeight: listenViewportH,
                      aiPanelOpen: _aiSheetOpen,
                      onAiPanelChanged: _toggleAiSheet,
                      onLrcGenerated: _handleLrcGenerated,
                      onOpenSheet: _openSheet,
                      onPanelChanged: (open) {
                        if (mounted && _inlinePanelOpen != open) {
                          setState(() => _inlinePanelOpen = open);
                        }
                      },
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
                ],
              ),

              // AI là một sheet độc lập: nội dung cuộn trước; khi đã về đầu,
              // kéo tiếp xuống sẽ kéo cả sheet và đóng. Chạm vùng mờ cũng đóng.
              if (_aiSheetOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeAiSheet,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.38),
                    ),
                  ),
                ),
                DraggableScrollableSheet(
                  controller: _aiSheetController,
                  initialChildSize: 0.55,
                  minChildSize: 0.0,
                  maxChildSize: 0.90,
                  snap: true,
                  snapSizes: const [0.0, 0.55, 0.90],
                  builder: (context, scrollController) {
                    return NotificationListener<
                        DraggableScrollableNotification>(
                      onNotification: (notification) {
                        if (notification.extent <= 0.04 &&
                            !_aiSheetClosing) {
                          _aiSheetClosing = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _aiSheetOpen = false;
                              _aiSheetClosing = false;
                            });
                          });
                        }
                        return false;
                      },
                      child: _AiDraggableSheet(
                        scrollController: scrollController,
                        onClose: _closeAiSheet,
                      ),
                    );
                  },
                ),
              ],

              // Sheet công cụ nâng cao.
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
              // Bong bóng tiến trình "Tự tạo mục lục" (chạy nền — không block)
              Consumer<SoundlistProvider>(
                builder: (_, soundlist, __) {
                  if (!soundlist.autoTocRunning) {
                    return const SizedBox.shrink();
                  }
                  return _AutoTocBubble(
                    status: soundlist.autoTocStatus,
                    progress: soundlist.autoTocProgress,
                    onTap: () => showSoundlistPanel(context),
                  );
                },
              ),
                ],
              );
            },
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
                    speakerColorMap: _speakerColorMap,
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
            if (_speakerColorMap.isNotEmpty)
              Positioned(
                top: 6,
                left: 18,
                child: _buildSpeakerLegend(),
              ),

            if (!_voiceListening && !isLoading)
              Positioned(
                top: 6,
                right: 18,
                child: _buildVoiceCommandButton(),
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

class _LrcIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _LrcIconBtn({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: Colors.grey),
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
  final double viewportHeight;
  final bool aiPanelOpen;
  final ValueChanged<bool> onAiPanelChanged;
  final VoidCallback onLrcGenerated;
  final VoidCallback onOpenSheet;
  final ValueChanged<bool>? onPanelChanged;

  const _CorePlayerControls({
    super.key,
    required this.player,
    required this.viewportHeight,
    required this.aiPanelOpen,
    required this.onAiPanelChanged,
    required this.onLrcGenerated,
    required this.onOpenSheet,
    this.onPanelChanged,
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
        _SmartActionBar(
          player: player,
          viewportHeight: viewportHeight,
          aiPanelOpen: aiPanelOpen,
          onAiPanelChanged: onAiPanelChanged,
          onLrcGenerated: onLrcGenerated,
          onOpenSheet: onOpenSheet,
          onPanelChanged: onPanelChanged,
        ),
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
          label: context.uiText('$minutes phút'),
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
                Text(context.uiText('Đặt $minutes phút'), style: const TextStyle(fontSize: 12)),
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

class _AiDraggableSheet extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onClose;

  const _AiDraggableSheet({
    required this.scrollController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.width < 430 || screenSize.height < 780;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white30,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.uiText('Trí tuệ nhân tạo'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.uiText('Ẩn'),
                          onPressed: onClose,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GenerateLrcButton(),
                        SizedBox(height: compact ? 10 : 12),
                        LrcEditorPanel(
                          initiallyExpanded: true,
                          compact: compact,
                        ),
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

// ═══════════════════════════════════════════════════════════════
// SMART ACTION BAR
// ═══════════════════════════════════════════════════════════════

class _SmartActionBar extends StatefulWidget {
  final PlayerProvider player;
  final double viewportHeight;
  final bool aiPanelOpen;
  final ValueChanged<bool> onAiPanelChanged;
  final VoidCallback onLrcGenerated;
  final VoidCallback onOpenSheet;

  /// LISTEN-630-01: báo ra màn hình khi panel inline mở/đóng để rèm
  /// LRC nhường chiều cao (tránh bottom overflow).
  final ValueChanged<bool>? onPanelChanged;

  const _SmartActionBar({
    required this.player,
    required this.viewportHeight,
    required this.aiPanelOpen,
    required this.onAiPanelChanged,
    required this.onLrcGenerated,
    required this.onOpenSheet,
    this.onPanelChanged,
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

    var openAi = false;
    if (widget.player.shouldOpenAiPanel) {
      widget.player.consumeShouldOpenAiPanel();
      openAi = true;
    }

    if (widget.player.lrcJustGenerated) {
      widget.player.consumeLrcJustGenerated();
      widget.onLrcGenerated();
      openAi = true;
    }

    if (openAi) {
      if (_openPanel != null) {
        _openPanel = null;
        widget.onPanelChanged?.call(false);
        setState(() {});
      }
      widget.onAiPanelChanged(true);
    }
  }

  void _togglePanel(_InlinePanel panel) {
    HapticFeedback.selectionClick();
    if (widget.aiPanelOpen) {
      widget.onAiPanelChanged(false);
    }
    final willOpen = _openPanel != panel;
    setState(() => _openPanel = _openPanel == panel ? null : panel);
    widget.onPanelChanged?.call(willOpen);
  }

  void _toggleAiPanel() {
    HapticFeedback.selectionClick();
    if (_openPanel != null) {
      setState(() => _openPanel = null);
      widget.onPanelChanged?.call(false);
    }
    widget.onAiPanelChanged(!widget.aiPanelOpen);
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
                    onTap: () => _saveMark(player),
                    onLongPress: () => showSoundlistPanel(context),
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Âm mục',
                    color: const Color(0xFF26C6DA),
                    isActive: false,
                    onTap: () => showSoundlistPanel(context),
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
                    isActive: widget.aiPanelOpen,
                    onTap: _toggleAiPanel,
                  ),
                  const SizedBox(width: 6),
                  _ActionTile(
                    icon: Icons.tune,
                    label: 'Thêm',
                    color: Colors.grey,
                    isActive: false,
                    onTap: () {
                      if (widget.aiPanelOpen) {
                        widget.onAiPanelChanged(false);
                      }
                      setState(() => _openPanel = null);
                      widget.onPanelChanged?.call(false);
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
    // Tính theo viewport thật của tab (không theo toàn màn hình có shell).
    final maxH = _inlinePanelMaxHeight(widget.viewportHeight);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: switch (_openPanel!) {
          _InlinePanel.repeat => _RepeatPanel(player: player),
          _InlinePanel.speed => _SpeedPanel(player: player),
          _InlinePanel.sleep => _SleepPanel(player: player),
          _InlinePanel.ab => const _ABLoopWithSilencePanel(),
        },
      ),
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

  /// 📌 Lưu một "Điểm" vào Âm mục tại vị trí đang phát.
  /// Giữ lâu nút này → mở panel Âm mục.
  Future<void> _saveMark(PlayerProvider player) async {
    final path = player.currentSongPath;
    if (path == null) {
      _showSnack('⚠️ Chưa có file âm thanh nào');
      return;
    }
    HapticFeedback.lightImpact();
    final soundlist = context.read<SoundlistProvider>();
    if (!soundlist.isLoaded) {
      await soundlist.load();
    }
    final mark = await soundlist.addMark(
      audioPath: path,
      position: player.state.position,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('📌 Đã đánh dấu ${_fmt(player.state.position)}'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 170),
          backgroundColor: const Color(0xFFFFB300),
          duration: const Duration(milliseconds: 2600),
          action: SnackBarAction(
            label: 'Ghi chú',
            textColor: Colors.black,
            onPressed: () {
              showEditMarkSheet(
                context,
                soundlist: soundlist,
                mark: mark,
              );
            },
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.uiText(msg)),
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

  String _formatEta(int chunkIndex, int chunkCount, double progress) {
    if (chunkCount <= 0 || chunkIndex < 0) return '';
    final done = chunkIndex + 1;
    if (done <= 0) return '';
    final percent = (done / chunkCount * 100).toStringAsFixed(1);
    final remaining = chunkCount - done;
    return 'Chunk $done/$chunkCount ($percent%) - $remaining left';
  }

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
            final hasChunkInfo = progress.chunkCount > 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedCrossFade(
                  firstChild: const SizedBox(height: 4),
                  secondChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress bar with chunk info
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: hasChunkInfo
                                  ? (progress.chunkIndex + 1) / progress.chunkCount
                                  : progress.progress,
                              backgroundColor: Colors.grey.shade800,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress.status == SttFacadeStatus.error
                                    ? Colors.red
                                    : Colors.blue.shade400,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (hasChunkInfo)
                            Text(
                              '${((progress.chunkIndex + 1) / progress.chunkCount * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.blue.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Main message
                      Text(
                        progress.message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[300], fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasChunkInfo) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top, size: 14, color: Colors.blue),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatEta(progress.chunkIndex, progress.chunkCount, progress.progress),
                                  style: TextStyle(
                                    color: Colors.blue.shade300,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.memory, size: 12, color: Colors.orange),
                              const SizedBox(width: 2),
                              Text(
                                'RAM safe: lazy chunk',
                                style: TextStyle(color: Colors.orange.shade300, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  // REOPEN FIX: đã có LRC lưu sẵn → hỏi Dùng bản đã lưu /
                  // Tạo lại, không auto chạy Whisper nữa.
                  // Ngôn ngữ: 'auto' (mặc định) = Whisper tự nhận diện
                  // đa ngữ; hoặc ép cụ thể (vi/en/zh/ja/ko/pi...).
                  onGenerate: (level, grouping, language) =>
                      confirmAndGenerateLrc(
                        context,
                        provider,
                        level,
                        grouping,
                        language: language,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Shadowing mic — TOGGLE. Trước đây chỉ startListening()
                    // fire-and-forget: mic native chạy treo → CABIN/flow
                    // khác bấm mic bị plugin từ chối ("Không thể khởi động
                    // micro"). Giờ: đang nghe → bấm = dừng; + dùng chế độ
                    // hội thoại (không tự chết sau 2 phút).
                    // SttServiceFacade là SINGLETON (factory) — không
                    // register làm Provider, nên KHÔNG dùng context.read
                    // (gặp thì crash ProviderNotFoundException).
                    AnimatedBuilder(
                      animation: SttServiceFacade(),
                      builder: (context, _) {
                        final facade = SttServiceFacade();
                        final micOn = facade.isLiveListening;
                        return ElevatedButton.icon(
                          onPressed: () async {
                            if (micOn) {
                              await facade.stopListening();
                            } else {
                              await facade.startConversation();
                            }
                          },
                          icon: Icon(micOn ? Icons.stop_circle : Icons.mic),
                          label: Text(micOn ? 'Dừng mic' : 'Shadowing'),
                          style: micOn
                              ? ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  )
                              : null,
                        );
                      },
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
  /// (level, grouping, language) — 'auto' = Whisper tự nhận diện ngôn ngữ.
  final Future<SttTranscribeOutput?> Function(
      WhisperModelLevel?, SttSegmentGrouping, String) onGenerate;

  const _LrcModelSelector(
      {required this.isProcessing, required this.onGenerate});

  @override
  State<_LrcModelSelector> createState() => _LrcModelSelectorState();
}

/// Ngôn ngữ Whisper hỗ trợ cho tạo LRC — 'auto' = tự nhận diện (đa ngữ).
/// (Whisper multilingual: mọi model tiny/base/... đều hiểu cả danh sách này.)
const Map<String, String> _lrcSttLanguages = {
  'auto': 'Tự động',
  'vi': 'Tiếng Việt',
  'en': 'English',
  'zh': 'Tiếng Trung',
  'ja': 'Tiếng Nhật',
  'ko': 'Tiếng Hàn',
  'th': 'Tiếng Thái',
  'es': 'Tiếng Tây Ban Nha',
  'fr': 'Tiếng Pháp',
  'de': 'Tiếng Đức',
  'ru': 'Tiếng Nga',
  'id': 'Tiếng Indonesia',
  'hi': 'Tiếng Hindi',
  'pi': 'Pali',
};

class _LrcModelSelectorState extends State<_LrcModelSelector> {
  WhisperModelLevel? _selectedLevel;
  SttSegmentGrouping _grouping = SttSegmentGrouping.sentence;
  String _language = 'auto';

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
        const SizedBox(height: 8),
        // Ngôn ngữ STT — mặc định 'Tự động' (Whisper tự nhận diện đa ngữ).
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in _lrcSttLanguages.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: _language == entry.key,
              onSelected: widget.isProcessing
                  ? null
                  : (_) => setState(() => _language = entry.key),
            ),
        ]),
        const SizedBox(height: 12),
        if (!widget.isProcessing)
          SegmentedButton<SttSegmentGrouping>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: SttSegmentGrouping.sentence,
                label: Text('Theo câu',
                    style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: SttSegmentGrouping.phrase,
                label: Text('Theo cụm',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_grouping},
            onSelectionChanged: (s) =>
                setState(() => _grouping = s.first),
          ),
        const SizedBox(height: 12),
        if (widget.isProcessing)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              const Text('Đang xử lý...'),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () =>
                    context.read<PlayerProvider>().cancelLrcGeneration(),
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Hủy'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
              ),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: () =>
                widget.onGenerate(_selectedLevel, _grouping, _language),
            icon: const Icon(Icons.subtitles_outlined),
            label: Text(
              _language == 'auto'
                  ? 'Tạo lời thoại (LRC — ngôn ngữ tự động)'
                  : 'Tạo lời thoại (LRC — ${_lrcSttLanguages[_language]})',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

// ═══════════════════════════════════════════════════════════════
// BONG BÓNG TIẾN TRÌNH TỰ TẠO MỤC LỤC (chạy nền)
// ═══════════════════════════════════════════════════════════════

class _AutoTocBubble extends StatelessWidget {
  final String status;
  final double progress;
  final VoidCallback onTap;

  const _AutoTocBubble({
    required this.status,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 52),
          child: Material(
            color: const Color(0xFF0E4D5C),
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF26C6DA).withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF26C6DA),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '⚡ $status',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (progress > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF26C6DA),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    const Icon(Icons.menu_book, color: Color(0xFF26C6DA), size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
