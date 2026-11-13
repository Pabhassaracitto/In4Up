// ignore_for_file: unnecessary_brace_in_string_interps
// I4U18-VIDEO-LIB-001 — Màn hình phát video THẬT (video_player) với:
//  - Phụ đề overlay (SRT/VTT/ASS/LRC) đồng bộ theo vị trí phát.
//  - Reopen đúng vị trí: seek tới lastPositionMs khi mở, lưu vị trí khi
//    tạm dừng / thoát.
//  - Điều khiển: play/pause, tua ±10s, thanh tiến độ, tốc độ 0.5×–2×.
import 'dart:async';
import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:video_player/video_player.dart';

import '../../../services/external_open_service.dart';
import '../../../utils/system_insets.dart';
import '../../media_tools/media_export_actions.dart';
import '../models/video_ab_loop_state.dart';
import '../models/video_info.dart';
import '../services/subtitle_parser.dart';
import '../services/video_device_channel.dart';
import '../services/video_library_logic.dart';
import '../services/video_playback_support.dart';
import '../services/video_library_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoInfo video;
  final Future<bool> Function(String path, String title)? onOpenAudioInListen;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.onOpenAudioInListen,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _initFailed = false;
  /// PSRC-220 — nền tảng này KHÔNG có plugin `video_player` (Linux/Windows):
  /// không thử khởi tạo controller, phát bằng trình phát của hệ điều hành.
  bool _externalOnly = false;
  bool _showControls = true;
  double _speed = 1.0;
  List<SubtitleCue> _cues = const [];
  SubtitleCue? _currentCue;
  VideoAbLoopState _abLoop = VideoAbLoopState.empty;
  bool _loopRewindPending = false;
  bool _resumed = false;
  Timer? _saveTimer;

  static const _accent = Color(0xFF9C27B0);

  @override
  void initState() {
    super.initState();
    // PSRC-220 (audit 1.28.0): trên Linux/Windows `video_player` chưa có
    // plugin ⇒ `VideoPlayerController.initialize()` ném `UnimplementedError`
    // và màn hình chỉ hiện "Không phát được video này". Biết trước điều đó để
    // KHÔNG đi vào nhánh lỗi và đưa ra đường xem được thật.
    if (!VideoPlaybackSupport.supportsInAppPlayback) {
      _externalOnly = true;
    } else {
      _initPlayer();
    }
    _loadSubtitle();
  }

  /// Mở tệp bằng trình phát của hệ điều hành (`xdg-open` / `explorer` / `open`).
  Future<void> _openExternally() async {
    final opened = await openFileExternally(widget.video.filePath);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText('Không mở được trình phát hệ thống')),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _initPlayer() async {
    try {
      // A physical video can be indexed through both SAF and MediaStore.
      // If one permission was revoked, try its other known URI without
      // changing the stable library id or saved playback position.
      VideoPlayerController? selected;
      final candidates = <String>{
        widget.video.filePath,
        ...widget.video.effectiveSourceUris.values,
      };
      for (final path in candidates) {
        final candidate = path.startsWith('content://')
            ? VideoPlayerController.contentUri(Uri.parse(path))
            : VideoPlayerController.file(File(path));
        try {
          await candidate.initialize();
          selected = candidate;
          break;
        } catch (_) {
          await candidate.dispose();
        }
      }
      if (selected == null) throw StateError('No accessible video source');
      final controller = selected;
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      setState(() => _controller = controller);

      // Reopen đúng vị trí: seek tới vị trí phát gần nhất (nếu đáng kể).
      final resumeMs = widget.video.lastPositionMs;
      if (resumeMs > 5000 &&
          resumeMs < controller.value.duration.inMilliseconds - 3000) {
        await controller.seekTo(Duration(milliseconds: resumeMs));
      }
      _resumed = true;
      await controller.play();
      // Lưu vị trí định kỳ để không mất khi app bị kill.
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persistPosition());
    } catch (e) {
      if (!mounted) return;
      setState(() => _initFailed = true);
    }
  }

  Future<void> _loadSubtitle() async {
    final sub = widget.video.subtitlePath;
    if (sub == null || sub.isEmpty) return;
    try {
      String? readable = sub;
      if (sub.startsWith('content://')) {
        readable = await VideoDeviceChannel.copyContentToCache(sub);
      }
      if (readable == null) return;
      final content = await File(readable).readAsString();
      final ext = VideoLibraryLogic.extensionOf(sub);
      final cues = SubtitleParser.parse(content, ext: ext);
      if (!mounted) return;
      setState(() => _cues = cues);
    } catch (_) {
      // Phụ đề lỗi → bỏ qua, video vẫn phát.
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final position = c.value.position;
    if (_cues.isNotEmpty) {
      final cue = SubtitleParser.cueAt(_cues, position);
      if (cue != _currentCue && mounted) {
        setState(() => _currentCue = cue);
      }
    } else if (mounted) {
      setState(() {});
    }

    // The native player position is the loop clock. Wait until its seek back
    // to A is reflected before allowing another wrap (avoids seek storms).
    final start = _abLoop.a;
    if (_loopRewindPending && start != null &&
        position <= start + const Duration(milliseconds: 250)) {
      _loopRewindPending = false;
    }
    final target = _abLoop.wrapTarget(position);
    if (target != null && !_loopRewindPending) {
      _loopRewindPending = true;
      unawaited(c.seekTo(target));
    }
  }

  void _markLoopA() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      _abLoop = _abLoop.markA(c.value.position, c.value.duration);
      _loopRewindPending = false;
    });
  }

  void _markLoopB() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final next = _abLoop.markB(c.value.position, c.value.duration);
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText('Đặt B cách A ít nhất 0,3 giây')),
        ),
      );
      return;
    }
    setState(() {
      _abLoop = next;
      _loopRewindPending = true;
    });
    unawaited(c.seekTo(next.a!));
  }

  void _loopCurrentCue() {
    final c = _controller;
    final cue = _currentCue;
    if (c == null || cue == null || !c.value.isInitialized) return;
    final next = VideoAbLoopState.empty
        .markA(cue.start, c.value.duration)
        .markB(cue.end, c.value.duration);
    if (next == null) return;
    setState(() {
      _abLoop = next;
      _loopRewindPending = true;
    });
    unawaited(c.seekTo(next.a!));
  }

  void _clearLoop() {
    setState(() {
      _abLoop = VideoAbLoopState.empty;
      _loopRewindPending = false;
    });
  }

  Future<void> _openExportedAudioInListen(
    String path, {
    Duration? sourceStart,
  }) async {
    final openInListen = widget.onOpenAudioInListen;
    if (openInListen == null) return;
    final controller = _controller;
    if (controller != null && controller.value.isPlaying) {
      await controller.pause();
      await _persistPosition();
    }
    final timestamp = sourceStart == null ? '' : ' · ${_fmt(sourceStart)}';
    final opened = await openInListen(
      path,
      '${widget.video.title}$timestamp',
    );
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Không mở được trình phát'))),
      );
    }
  }

  Future<void> _persistPosition() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !_resumed) return;
    await VideoLibraryService.instance.updatePlayback(
      widget.video.id,
      position: c.value.position,
      duration: c.value.duration,
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_persistPosition());
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _persistPosition();
      } else {
        c.play();
      }
    });
  }

  void _seekBy(Duration delta) {
    final c = _controller;
    if (c == null) return;
    var target = c.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
  }

  Future<void> _setSpeed(double s) async {
    final c = _controller;
    if (c == null) return;
    await c.setPlaybackSpeed(s);
    setState(() => _speed = s);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.video.title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // AVTOOL-003 (PLAN-047 P2) — video → âm thanh (nghe trên đường).
          // PSRC-220: vẫn cho tách âm thanh khi không phát được trong app —
          // đây chính là đường dùng được trên Linux.
          if (ready || _externalOnly)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF1A1A2E),
              onSelected: (value) async {
                switch (value) {
                  case 'extract_audio':
                    await exportAudioFromVideo(
                      context,
                      widget.video,
                      openInListenTab: widget.onOpenAudioInListen == null
                          ? null
                          : (path) => _openExportedAudioInListen(path),
                    );
                  case 'clip_ab_audio':
                    if (c == null) return; // không có timeline trong app
                    final start = _abLoop.a;
                    final end = _abLoop.b;
                    if (start != null && end != null && end > start) {
                      await exportAudioFromVideo(
                        context,
                        widget.video,
                        clipStart: start,
                        clipDuration: end - start,
                        openInListenTab:
                            widget.onOpenAudioInListen == null
                                ? null
                                : (path) => _openExportedAudioInListen(
                                      path,
                                      sourceStart: start,
                                    ),
                      );
                    }
                  case 'clip_audio':
                    if (c == null) return; // không có timeline trong app
                    final position = c.value.position;
                    final duration = c.value.duration - position;
                    await exportAudioFromVideo(
                      context,
                      widget.video,
                      clipStart: position,
                      clipDuration: duration > const Duration(seconds: 1)
                          ? duration
                          : const Duration(seconds: 30),
                      openInListenTab: widget.onOpenAudioInListen == null
                          ? null
                          : (path) => _openExportedAudioInListen(
                                path,
                                sourceStart: position,
                              ),
                    );
                }
              },
              itemBuilder: (_) => [
                if (ready && _abLoop.isActive)
                  PopupMenuItem(
                    value: 'clip_ab_audio',
                    child: Text(
                      context.uiText('Xuất đoạn A-B'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                PopupMenuItem(
                  value: 'extract_audio',
                  child: Text(
                    context.uiText('Tách âm thanh (toàn bộ video)'),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                if (ready)
                  PopupMenuItem(
                    value: 'clip_audio',
                    child: Text(
                      context.uiText('Tách âm thanh từ vị trí hiện tại'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
          if (ready)
            PopupMenuButton<double>(
              icon: const Icon(Icons.speed, color: Colors.white),
              color: const Color(0xFF1A1A2E),
              onSelected: _setSpeed,
              itemBuilder: (_) => [
                for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  PopupMenuItem(
                    value: s,
                    child: Text(
                      context.uiText('${s}×${s == _speed ? '  ✓' : ''}'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Container(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (ready)
                      Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
                      )
                    else if (_externalOnly)
                      _buildExternalOnly()
                    else if (_initFailed)
                      _buildError()
                    else
                      const CircularProgressIndicator(color: _accent),

                    // Phụ đề overlay.
                    if (_currentCue != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        // SAFE-INSET-001: phụ đề không được chìm dưới thanh
                        // điều hướng hệ thống ở chế độ toàn màn hình.
                        bottom: bottomInsetOffset(context, 16),
                        child: _SubtitleText(text: _currentCue!.text),
                      ),

                    // Nút play lớn khi đang tạm dừng.
                    if (ready && !c.value.isPlaying)
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 40),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showControls && ready) _buildControls(c),
        ],
      ),
    );
  }

  /// PSRC-220 — màn hình thay thế khi nền tảng không có bộ phát trong app.
  ///
  /// Nói đúng nguyên nhân (thiếu backend, không phải file hỏng) và đưa ra
  /// việc làm được ngay: mở bằng trình phát của hệ điều hành. Tách âm thanh
  /// vẫn dùng được qua menu ⋮ vì việc đó do FFmpeg làm, không cần bộ phát.
  Widget _buildExternalOnly() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            context.uiText(VideoPlaybackSupport.externalOnlyReasonKey),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[300], fontSize: 14),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new),
            label: Text(context.uiText('Mở bằng trình phát của hệ thống')),
          ),
          const SizedBox(height: 8),
          Text(
            context.uiText(
              'Vẫn tách được âm thanh bằng menu ⋮ để nghe trong tab Nghe.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            context.uiText('Không phát được video này'),
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(VideoPlayerController c) {
    final pos = c.value.position;
    final dur = c.value.duration;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFF111827),
      child: Column(
        children: [
          Row(
            children: [
              Text(_fmt(pos),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _accent,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: _accent,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (v) => c.seekTo(
                        Duration(milliseconds: (v * dur.inMilliseconds).toInt())),
                  ),
                ),
              ),
              Text(_fmt(dur),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 0,
            children: [
              Tooltip(
                message: context.uiText('Đặt A tại vị trí phát'),
                child: TextButton.icon(
                  onPressed: _markLoopA,
                  icon: const Icon(Icons.looks_one_rounded, size: 18),
                  label: const Text('A'),
                  style: TextButton.styleFrom(
                    foregroundColor: _abLoop.hasA ? Colors.amber : Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              Tooltip(
                message: context.uiText('Đặt B tại vị trí phát'),
                child: TextButton.icon(
                  onPressed: _abLoop.hasA ? _markLoopB : null,
                  icon: const Icon(Icons.looks_two_rounded, size: 18),
                  label: const Text('B'),
                  style: TextButton.styleFrom(
                    foregroundColor: _abLoop.isActive ? Colors.amber : Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              if (_abLoop.isActive)
                Chip(
                  avatar: const Icon(Icons.repeat_rounded, size: 16),
                  label: Text(
                    '${_fmt(_abLoop.a!)} → ${_fmt(_abLoop.b!)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _accent.withValues(alpha: 0.22),
                  side: BorderSide.none,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (_abLoop.hasA)
                IconButton(
                  tooltip: context.uiText('Xóa A-B'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: Colors.white70,
                  onPressed: _clearLoop,
                ),
              if (_currentCue != null && _cues.isNotEmpty)
                TextButton.icon(
                  onPressed: _loopCurrentCue,
                  icon: const Icon(Icons.subtitles_rounded, size: 18),
                  label: Text(context.uiText('Lặp câu')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10,
                    color: Colors.white, size: 28),
                onPressed: () => _seekBy(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10,
                    color: Colors.white, size: 28),
                onPressed: () => _seekBy(const Duration(seconds: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  final String text;
  const _SubtitleText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}
