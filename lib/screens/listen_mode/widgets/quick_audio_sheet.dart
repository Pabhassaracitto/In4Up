// Tương tự QuickLibrarySheet nhưng cho audio

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../models/recent_audio.dart';
import '../services/recent_audio_service.dart';
import 'package:in4up/core/language/tr_extension.dart';

class QuickAudioSheet extends StatefulWidget {
  const QuickAudioSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const QuickAudioSheet(),
    );
  }

  @override
  State<QuickAudioSheet> createState() => _QuickAudioSheetState();
}

class _QuickAudioSheetState extends State<QuickAudioSheet> {
  final _service = RecentAudioService();
  List<RecentAudio> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _service.getAll();
    if (!mounted) return;
    setState(() {
      _files = all.take(5).toList();
      _isLoading = false;
    });
  }

  // ── Mở audio ─────────────────────────────────────────────────
  Future<void> _openAudio(RecentAudio audio) async {
    final player = context.read<PlayerProvider>();
    final nav = Navigator.of(context);

    nav.pop(); // Đóng sheet trước

    if (audio.type == RecentAudioType.local && audio.localPath != null) {
      await player.loadSong(
        path: audio.localPath!,
        title: audio.title,
        autoPlay: true,
      );
      if (!mounted) return;
      if (audio.lastPosition > Duration.zero) {
        await player.seek(audio.lastPosition);
      }
      await _service.addOrUpdate(
        audio.copyWith(lastOpened: DateTime.now()),
      );
    }
  }

  // ── Về thư viện đầy đủ ──────────────────────────────────────
  void _openFullLibrary() {
    final player = context.read<PlayerProvider>();
    Navigator.pop(context);
    // ★ Dùng clearCurrentSong() thay vì stop()
    // clearCurrentSong() set currentSongPath = null
    // → ListenModeScreen.build() thấy currentPath == null
    // → hiện ListenLibraryScreen
    player.clearCurrentSong();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(color: Colors.white12, height: 1),
          _buildBody(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
      child: Row(
        children: [
          const Text('🎧', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText('Đổi audio', style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TrText('Gần đây nhất', style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white54, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.music_off,
                color: Colors.white.withValues(alpha: 0.2), size: 36),
            const SizedBox(height: 8),
            Text(context.l10n.listenNoAudio, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _files.length,
      separatorBuilder: (_, __) => const Divider(
        color: Colors.white10,
        height: 1,
        indent: 72,
      ),
      itemBuilder: (_, i) => _AudioRow(
        audio: _files[i],
        onTap: () => _openAudio(_files[i]),
      ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: GestureDetector(
          onTap: _openFullLibrary,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Color(0xFF6C63FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF6C63FF).withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_view_rounded,
                    color: Color(0xFF6C63FF), size: 16),
                SizedBox(width: 6),
                TrText('Xem tất cả', style: TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Audio Row ─────────────────────────────────────────────────
class _AudioRow extends StatelessWidget {
  final RecentAudio audio;
  final VoidCallback onTap;

  const _AudioRow({required this.audio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: audio.type == RecentAudioType.youtube
                      ? [const Color(0xFF8B0000), const Color(0xFFCC0000)]
                      : [const Color(0xFF1A0D3F), const Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  audio.thumbnailEmoji ?? audio.typeEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    audio.progressText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Circular progress
            if (audio.totalDuration != Duration.zero) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  value: audio.listenProgress.clamp(0.0, 1.0),
                  strokeWidth: 2.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6C63FF),
                  ),
                ),
              ),
            ],

            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}