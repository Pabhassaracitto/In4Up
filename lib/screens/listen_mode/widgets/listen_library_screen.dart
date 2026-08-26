// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, prefer_const_constructors_in_immutables, prefer_const_literals_to_create_immutables, sort_child_properties_last, avoid_unnecessary_containers, sized_box_for_whitespace, use_build_context_synchronously, avoid_print
import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/audio_library_provider.dart';
import '../../../providers/player_provider.dart';
import '../models/recent_audio.dart';
import '../services/recent_audio_service.dart';
import 'audio_library_view.dart';
import 'recent_audio_card.dart';

class ListenLibraryScreen extends StatefulWidget {
  const ListenLibraryScreen({super.key});

  @override
  State<ListenLibraryScreen> createState() => _ListenLibraryScreenState();
}

class _ListenLibraryScreenState extends State<ListenLibraryScreen>
    with TickerProviderStateMixin {
  final _service = RecentAudioService();
  List<RecentAudio> _files = [];
  bool _isLoading = true;

  late final AnimationController _fabAnim;
  late final Animation<double> _fabScale;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fabScale = CurvedAnimation(
      parent: _fabAnim,
      curve: Curves.elasticOut,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  // ── Load ─────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final files = await _service.getAll();
    if (!mounted) return;
    setState(() {
      _files = files;
      _isLoading = false;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) _fabAnim.forward();
  }

  // ── Grouped ──────────────────────────────────────────────────
  List<RecentAudio> get _inProgress =>
      _files.where((f) => f.isInProgress).toList();
  List<RecentAudio> get _newFiles => _files.where((f) => f.isNew).toList();
  List<RecentAudio> get _completed =>
      _files.where((f) => f.isCompleted).toList();

  // ── Open audio ───────────────────────────────────────────────
  Future<void> _openAudio(RecentAudio audio) async {
    final player = context.read<PlayerProvider>();

    switch (audio.type) {
      case RecentAudioType.local:
        if (audio.localPath == null) return;

        await player.loadSong(
          path: audio.localPath!,
          title: audio.title,
          autoPlay: false, // ★ THAY: false để seek trước khi play
        );
        if (!mounted) return;

        // Resume vị trí đã nghe
        if (audio.lastPosition > Duration.zero &&
            audio.lastPosition.inSeconds > 5) {
          await player.seek(audio.lastPosition);

          // Thông báo resume
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.uiText('Tiếp tục từ ${_fmtDuration(audio.lastPosition)}'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF6C63FF),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: context.uiText('Từ đầu'),
                textColor: Colors.white70,
                onPressed: () => player.seek(Duration.zero),
              ),
            ),
          );
        }

        // Play sau khi đã seek
        await player.play();

        if (!mounted) return;

        // Cập nhật recent
        await _service.addOrUpdate(
          audio.copyWith(
            lastOpened: DateTime.now(),
          ),
        );
        break;

      case RecentAudioType.youtube:
        if (!mounted) return;
        _showSnack(
          icon: Icons.swipe_left_alt,
          message: 'Vuốt từ phải → để mở Thư viện âm thanh / YouTube',
          color: const Color(0xFFCC0000),
        );
        break;
    }
  }

// ★ THÊM helper format duration
  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  // ── Pick audio file ──────────────────────────────────────────
  Future<void> _pickAudioFile() async {
    final player = context.read<PlayerProvider>();

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
    } catch (e) {
      debugPrint('[ListenLibrary] FilePicker error: $e');
      return;
    }

    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    final file = result.files.single;
    final path = file.path!;

    // Load và phát
    await player.loadSong(
      path: path,
      title: file.name,
      autoPlay: true,
    );
    if (!mounted) return;

    // Lưu vào recent
    final audio = RecentAudio.fromLocalFile(
      path: path,
      title: file.name,
      totalDuration: player.state.duration,
    );
    await _service.addOrUpdate(audio);
    if (!mounted) return;
    await _load();
  }

  // ── File options ─────────────────────────────────────────────
  void _showAudioOptions(RecentAudio audio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(audio.typeEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      audio.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: Colors.white12,
              height: 24,
              indent: 20,
              endIndent: 20,
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline,
                  color: Color(0xFF6C63FF)),
              title: const Text('Phát audio',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openAudio(audio);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Xóa khỏi danh sách',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                HapticFeedback.heavyImpact();
                await _service.remove(audio.id);
                if (mounted) await _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Snackbar ─────────────────────────────────────────────────
  void _showSnack({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.uiText(message),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentBody(),
                const AudioLibraryView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isRecentTab = _tabController.index == 0;
          return ScaleTransition(
            scale: _fabScale,
            child: FloatingActionButton.extended(
              onPressed: isRecentTab ? _pickAudioFile : _scanLibrary,
              backgroundColor: const Color(0xFF6C63FF),
              elevation: 4,
              icon: Icon(
                isRecentTab ? Icons.add_rounded : Icons.refresh_rounded,
                color: Colors.white,
              ),
              label: Text(
                isRecentTab ? 'Thêm audio' : 'Quét thư viện',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// FAB tab "Thư viện": quét lại MediaStore.
  void _scanLibrary() {
    context.read<AudioLibraryProvider>().scan();
  }

  // ── Tab bar (Gần đây / Thư viện) ─────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0D1520),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF6C63FF),
        indicatorWeight: 2.5,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'Gần đây'),
          Tab(text: 'Thư viện'),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎧 Thư viện nghe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isLoading
                      ? 'Đang tải...'
                      : _files.isEmpty
                          ? 'Chưa có audio nào'
                          : '${_files.length} audio',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Gợi ý mở drawer
          GestureDetector(
            onTap: () => _showSnack(
              icon: Icons.swipe_left_alt,
              message: 'Vuốt từ phải → Thư viện · Drive · YouTube',
              color: const Color(0xFF6C63FF),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF6C63FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Color(0xFF6C63FF).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.library_music_rounded,
                color: Color(0xFF6C63FF),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body tab "Gần đây" ───────────────────────────────────────
  Widget _buildRecentBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6C63FF),
          strokeWidth: 2,
        ),
      );
    }

    if (_files.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1A2235),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 120),
        children: [
          // ── Đang nghe dang dở
          if (_inProgress.isNotEmpty) ...[
            _SectionHeader(
              emoji: '🎵',
              title: 'Đang nghe',
              count: _inProgress.length,
            ),
            ..._inProgress.map((a) => RecentAudioCard(
                  audio: a,
                  onTap: () => _openAudio(a),
                  onLongPress: () => _showAudioOptions(a),
                )),
            const SizedBox(height: 4),
          ],

          // ── Chưa nghe
          if (_newFiles.isNotEmpty) ...[
            _SectionHeader(
              emoji: '🆕',
              title: 'Chưa nghe',
              count: _newFiles.length,
            ),
            ..._newFiles.map((a) => RecentAudioCard(
                  audio: a,
                  onTap: () => _openAudio(a),
                  onLongPress: () => _showAudioOptions(a),
                )),
            const SizedBox(height: 4),
          ],

          // ── Đã xong
          if (_completed.isNotEmpty) ...[
            _SectionHeader(
              emoji: '✅',
              title: 'Đã nghe xong',
              count: _completed.length,
            ),
            ..._completed.map((a) => RecentAudioCard(
                  audio: a,
                  onTap: () => _openAudio(a),
                  onLongPress: () => _showAudioOptions(a),
                )),
          ],
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────
  // Responsive to avoid yellow-black overflow on small screens
  Widget _buildEmptyState() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVerySmall = constraints.maxWidth < 360;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 20 : 40),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Text(
                      '🎧',
                      style: TextStyle(fontSize: isVerySmall ? 56 : 72),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Thư viện nghe trống',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isVerySmall ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhấn "Thêm audio" để bắt đầu\nhoặc vuốt từ phải để mở Thư viện',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: isVerySmall ? 12 : 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.9,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickAudioFile,
                          icon:
                              const Icon(Icons.add_rounded, color: Colors.white),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isVerySmall
                                  ? 'Thêm audio'
                                  : 'Thêm audio đầu tiên',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: EdgeInsets.symmetric(
                              horizontal: isVerySmall ? 20 : 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final int count;

  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
