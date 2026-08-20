// lib/screens/listen_mode/widgets/soundlist_panel.dart
// Panel "Âm mục" mở ngay trong Listen Mode — mục lục âm thanh của file đang nghe.
//
// 3 tab:
//   • Mục lục — cây chương/mục (như mục lục sách), chạm để nhảy đến.
//   • Điểm    — các mốc đánh dấu (nhãn, tag, ghi chú, loại).
//   • Đoạn    — các đoạn A–B đã lưu (phát lặp, xóa).
//
// Tương tác 1 chạm: tạo điểm, tạo chương, lưu đoạn A–B đang chọn.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/sound_chapter.dart';
import '../../../models/sound_loop_stat.dart';
import '../../../models/sound_mark.dart';
import '../../../models/sound_transcript.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/soundlist_provider.dart';
import '../../../screens/understand_mode/understand_provider.dart';
import '../../../widgets/save_segment_dialog.dart';
import '../../../widgets/sound_auto_toc_dialog.dart';
import '../../../widgets/sound_mark_edit_sheet.dart';

/// Mở panel Âm mục cho file đang phát.
Future<void> showSoundlistPanel(BuildContext context) async {
  final player = context.read<PlayerProvider>();
  final path = player.currentSongPath;
  if (path == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Chưa có file âm thanh nào đang phát'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  final soundlist = context.read<SoundlistProvider>();
  if (!soundlist.isLoaded) {
    await soundlist.load();
  }
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const SoundlistPanel(),
  );
}

class SoundlistPanel extends StatefulWidget {
  const SoundlistPanel({super.key});

  @override
  State<SoundlistPanel> createState() => _SoundlistPanelState();
}

class _SoundlistPanelState extends State<SoundlistPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final soundlist = context.watch<SoundlistProvider>();
    final path = player.currentSongPath;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2235),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          // ── Handle + tiêu đề ──
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Color(0xFF26C6DA), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Âm mục',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        player.currentSongTitle ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Hàng hành động nhanh ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _QuickAction(
                  icon: Icons.push_pin_outlined,
                  label: 'Điểm',
                  color: const Color(0xFFFFB300),
                  onTap: () async {
                    final pos = player.state.position;
                    await showCreateMarkSheet(
                      context,
                      soundlist: soundlist,
                      audioPath: path!,
                      position: pos,
                    );
                    await soundlist.reload();
                  },
                ),
                const SizedBox(width: 6),
                _QuickAction(
                  icon: Icons.menu_book_outlined,
                  label: 'Chương',
                  color: const Color(0xFF26C6DA),
                  onTap: () => _addChapterDialog(player, soundlist, path!),
                ),
                const SizedBox(width: 6),
                _QuickAction(
                  icon: Icons.vertical_align_bottom,
                  label: 'Đoạn A–B',
                  color: const Color(0xFF6C63FF),
                  enabled: player.hasCompletedLoop,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SaveSegmentDialog(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Banner: Tự tạo mục lục (VAD + Whisper) ──
          if (path != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => runSoundAutoToc(
                context,
                audioPath: path,
                totalDuration: player.state.duration,
                hasExistingChapters:
                    soundlist.chaptersForSong(path).isNotEmpty,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E4D5C), Color(0xFF123A4D)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF26C6DA).withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 15, color: Color(0xFF26C6DA)),
                    SizedBox(width: 6),
                    Text(
                      'Tự tạo mục lục  ·  VAD + Whisper',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Gợi ý thông minh: các vùng lặp nhiều ──
          if (path != null && soundlist.suggestionsForSong(path).isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final stat in soundlist.suggestionsForSong(path))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _SuggestionChip(
                        stat: stat,
                        player: player,
                        soundlist: soundlist,
                        audioPath: path,
                      ),
                    ),
                ],
              ),
            ),

          // ── Tabs ──
          Container(
            color: const Color(0xFF191D2E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6C63FF),
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: 'Mục lục'),
                Tab(text: 'Điểm'),
                Tab(text: 'Đoạn'),
                Tab(text: 'Tìm kiếm'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ChapterTab(player: player, soundlist: soundlist, path: path),
                _MarkTab(player: player, soundlist: soundlist, path: path),
                _SegmentTab(player: player, path: path),
                _SearchTab(player: player, soundlist: soundlist, path: path),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addChapterDialog(
    PlayerProvider player,
    SoundlistProvider soundlist,
    String path,
  ) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232841),
        title: const Text('Thêm chương/mục', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Tên chương (VD: "Bài 1 – Tứ niệm xứ")',
            hintStyle: TextStyle(color: Colors.white30),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    await soundlist.addChapter(
      audioPath: path,
      title: title,
      position: player.state.position,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📖 Đã thêm chương "$title" tại ${SoundMark.formatTime(player.state.position)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF26C6DA),
        ),
      );
    }
  }
}

// ─────────────────────────────── HÀNH ĐỘNG NHANH ───────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.14) : const Color(0xFF232841),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.5) : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: enabled ? color : Colors.white24),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? color : Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── TAB: MỤC LỤC ───────────────────────────────

class _ChapterTab extends StatelessWidget {
  final PlayerProvider player;
  final SoundlistProvider soundlist;
  final String? path;

  const _ChapterTab({
    required this.player,
    required this.soundlist,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return const _EmptyHint(icon: Icons.menu_book_outlined, text: 'Chưa có file âm thanh');
    }
    final chapters = soundlist.chaptersForSong(path!);
    if (chapters.isEmpty) {
      return const _EmptyHint(
        icon: Icons.auto_awesome_outlined,
        text: 'Chưa có mục lục.\nNhấn "⚡ Tự tạo mục lục" phía trên để app\n'
            'tự tách đoạn theo khoảng lặng (VAD)\nvà đặt tên chương (Whisper).\n\n'
            'Hoặc nhấn "＋ Chương" để tạo thủ công\n(tự neo vào vị trí đang nghe).',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      itemCount: chapters.length,
      itemBuilder: (context, i) {
        final chapter = chapters[i];
        final depth = _depthOf(chapter, soundlist);
        return _ChapterTile(
          chapter: chapter,
          depth: depth,
          player: player,
          soundlist: soundlist,
          path: path!,
        );
      },
    );
  }

  int _depthOf(SoundChapter chapter, SoundlistProvider soundlist) {
    int depth = 0;
    var current = chapter;
    var guard = 0;
    while (current.parentId != null && guard < 20) {
      final parent = soundlist.chapters
          .where((c) => c.id == current.parentId)
          .firstOrNull;
      if (parent == null) break;
      depth++;
      current = parent;
      guard++;
    }
    return depth;
  }
}

class _ChapterTile extends StatelessWidget {
  final SoundChapter chapter;
  final int depth;
  final PlayerProvider player;
  final SoundlistProvider soundlist;
  final String path;

  const _ChapterTile({
    required this.chapter,
    required this.depth,
    required this.player,
    required this.soundlist,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final childCount = soundlist.childCountOf(chapter.id);
    return Padding(
      padding: EdgeInsets.only(left: (depth * 14).toDouble(), bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          HapticFeedback.selectionClick();
          if (chapter.position != null) {
            await player.seek(chapter.position!);
            if (!player.isPlaying) await player.play();
          }
        },
        onLongPress: () => _showMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: depth == 0 ? const Color(0xFF232841) : const Color(0xFF1A1F31),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: depth == 0 ? const Color(0xFF26C6DA).withValues(alpha: 0.35) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                depth == 0 ? Icons.menu_book_rounded : Icons.subdirectory_arrow_right,
                size: depth == 0 ? 17 : 14,
                color: const Color(0xFF26C6DA).withValues(alpha: depth == 0 ? 1 : 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    if (chapter.note != null)
                      Text(
                        chapter.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                      ),
                  ],
                ),
              ),
              if (chapter.position != null)
                Text(
                  SoundMark.formatTime(chapter.position!),
                  style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                ),
              if (childCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '$childCount',
                    style: const TextStyle(color: Color(0xFF26C6DA), fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF232841),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Color(0xFF26C6DA)),
              title: const Text('Đổi tên', style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.library_add_outlined, color: Color(0xFF66BB6A)),
              title: const Text('Thêm mục con tại đây', style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, 'child'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined, color: Color(0xFFFFB300)),
              title: const Text('Ghi chú', style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, 'note'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
              title: const Text('Xóa (cả mục con)', style: TextStyle(color: Color(0xFFEF5350), fontSize: 14)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    switch (result) {
      case 'rename':
        final controller = TextEditingController(text: chapter.title);
        final title = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF232841),
            title: const Text('Đổi tên mục', style: TextStyle(color: Colors.white, fontSize: 15)),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
        if (title != null && title.isNotEmpty) {
          await soundlist.renameChapter(chapter.id, title);
        }
        break;
      case 'child':
        final controller = TextEditingController();
        final title = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF232841),
            title: const Text('Thêm mục con', style: TextStyle(color: Colors.white, fontSize: 15)),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Tên mục con',
                hintStyle: TextStyle(color: Colors.white30),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Thêm'),
              ),
            ],
          ),
        );
        if (title != null && title.isNotEmpty) {
          await soundlist.addChapter(
            audioPath: path,
            title: title,
            position: player.state.position,
            parentId: chapter.id,
          );
        }
        break;
      case 'note':
        final controller = TextEditingController(text: chapter.note ?? '');
        final note = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF232841),
            title: const Text('Ghi chú mục', style: TextStyle(color: Colors.white, fontSize: 15)),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
        if (note != null) {
          await soundlist.setChapterNote(chapter.id, note.isEmpty ? null : note);
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF232841),
            title: const Text('Xóa mục này?', style: TextStyle(color: Colors.white, fontSize: 15)),
            content: Text(
              '"${chapter.title}" và toàn bộ mục con sẽ bị xóa.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await soundlist.deleteChapter(chapter.id);
        }
        break;
    }
  }
}

// ─────────────────────────────── TAB: ĐIỂM ───────────────────────────────

class _MarkTab extends StatelessWidget {
  final PlayerProvider player;
  final SoundlistProvider soundlist;
  final String? path;

  const _MarkTab({
    required this.player,
    required this.soundlist,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return const _EmptyHint(icon: Icons.push_pin_outlined, text: 'Chưa có file âm thanh');
    }
    final marks = soundlist.marksForSong(path!);
    if (marks.isEmpty) {
      return const _EmptyHint(
        icon: Icons.push_pin_outlined,
        text: 'Chưa có điểm nào.\nChạm "＋ Điểm" hoặc nút "Dấu" 📌\nở thanh điều khiển để đánh dấu vị trí đang nghe.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      itemCount: marks.length,
      itemBuilder: (context, i) {
        final mark = marks[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              HapticFeedback.selectionClick();
              await player.seek(mark.position);
              if (!player.isPlaying) await player.play();
            },
            onLongPress: () async {
              final updated = await showEditMarkSheet(
                context,
                soundlist: soundlist,
                mark: mark,
              );
              if (updated != null) await soundlist.reload();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF232841),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: mark.kind.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(mark.kind.icon, color: mark.kind.color, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mark.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        if (mark.note != null)
                          Text(
                            mark.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                          ),
                        if (mark.tags.isNotEmpty)
                          Text(
                            mark.tags.map((t) => '#$t').join('  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: mark.kind.color.withValues(alpha: 0.8), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mark.timeLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────── TAB: ĐOẠN ───────────────────────────────

class _SegmentTab extends StatelessWidget {
  final PlayerProvider player;
  final String? path;

  const _SegmentTab({required this.player, required this.path});

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return const _EmptyHint(icon: Icons.vertical_align_bottom, text: 'Chưa có file âm thanh');
    }
    final segments = player.getSegmentsForCurrentSong();
    if (segments.isEmpty) {
      return const _EmptyHint(
        icon: Icons.vertical_align_bottom,
        text: 'Chưa có đoạn nào.\nChọn vùng A–B rồi bấm "Đoạn A–B" để lưu\nthành đoạn học tập (phát lặp, đánh dấu khó…).',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      itemCount: segments.length,
      itemBuilder: (context, i) {
        final segment = segments[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              HapticFeedback.mediumImpact();
              await player.playSegment(segment, index: i);
            },
            onLongPress: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF232841),
                  title: const Text('Xóa đoạn?', style: TextStyle(color: Colors.white, fontSize: 15)),
                  content: Text(
                    '"${segment.title}" (${SoundMark.formatTime(segment.startTime)} – ${SoundMark.formatTime(segment.endTime)})',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                player.deleteSegment(segment.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF232841),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vertical_align_bottom, color: Color(0xFF6C63FF), size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          segment.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${SoundMark.formatTime(segment.startTime)} → ${SoundMark.formatTime(segment.endTime)}'
                          ' · ${segment.difficulty.name} · lặp ×${segment.repeatCount}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                        ),
                        if (segment.note != null)
                          Text(
                            segment.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_outline, color: Color(0xFF6C63FF), size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────── GỢI Ý THÔNG MINH ───────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final SoundLoopStat stat;
  final PlayerProvider player;
  final SoundlistProvider soundlist;
  final String audioPath;

  const _SuggestionChip({
    required this.stat,
    required this.player,
    required this.soundlist,
    required this.audioPath,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF3A2A00),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 13, color: Color(0xFFFFB300)),
            const SizedBox(width: 5),
            Text(
              '💪 Lặp ${stat.count}× · ${stat.timeLabel}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF232841),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                '💡 Bạn đã lặp đoạn ${stat.timeLabel} ${stat.count} lần',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center, color: Color(0xFFEF5350)),
              title: const Text('Đánh dấu 💪 Khó tại đây',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, 'hard'),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined, color: Color(0xFFFFB300)),
              title: const Text('Tạo điểm tại đầu đoạn',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, 'mark'),
            ),
            ListTile(
              leading: const Icon(Icons.not_interested, color: Colors.white38),
              title: const Text('Bỏ qua gợi ý này',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, 'dismiss'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    switch (action) {
      case 'hard':
        await soundlist.addMark(
          audioPath: audioPath,
          position: stat.start,
          kind: SoundMarkKind.hard,
          label: 'Khó – lặp ${stat.count} lần',
          note: 'Vùng ${stat.timeLabel} bị lặp ${stat.count} lần.',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('💪 Đã đánh dấu Khó'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFEF5350),
          ));
        }
        break;
      case 'mark':
        await soundlist.addMark(
          audioPath: audioPath,
          position: stat.start,
          label: 'Lặp ${stat.count}×',
        );
        break;
      case 'dismiss':
        await soundlist.dismissSuggestion(stat.id);
        break;
    }
  }
}

// ─────────────────────────────── TAB: TÌM KIẾM TRONG AUDIO ───────────────────────────────

class _SearchTab extends StatefulWidget {
  final PlayerProvider player;
  final SoundlistProvider soundlist;
  final String? path;

  const _SearchTab({
    required this.player,
    required this.soundlist,
    required this.path,
  });

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _lrcChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTranscript());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Nếu chưa có transcript lưu, thử dựng từ LRC đang có trong Understand.
  Future<void> _ensureTranscript() async {
    if (_lrcChecked) return;
    _lrcChecked = true;
    final path = widget.path;
    if (path == null) return;
    if (widget.soundlist.transcriptFor(path) != null) return;
    final understand = context.read<UnderstandProvider>();
    if (understand.lrcLines.isEmpty) return;
    final t = widget.soundlist.transcriptFromLrcLines(path, understand.lrcLines);
    if (t != null) {
      await widget.soundlist.saveTranscript(t);
    }
  }

  List<TranscriptLine> _results() {
    final path = widget.path;
    if (path == null) return const [];
    final t = widget.soundlist.transcriptFor(path);
    if (t == null) return const [];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return t.lines.where((l) => l.text.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final transcript = path == null ? null : widget.soundlist.transcriptFor(path);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '🔍  Tìm chữ trong audio…',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
              filled: true,
              fillColor: const Color(0xFF232841),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: transcript == null
              ? const _EmptyHint(
                  icon: Icons.search_off,
                  text: 'Chưa có bản ghi nội dung (transcript).\n\n'
                      'Chạy "⚡ Tự tạo mục lục" (VAD + Whisper)\n'
                      'hoặc tạo LRC trong tab AI —\nsau đó tìm chữ là nhảy tới đúng chỗ.',
                )
              : _buildResults(transcript),
        ),
      ],
    );
  }

  Widget _buildResults(SoundTranscript transcript) {
    if (_query.trim().isEmpty) {
      return _EmptyHint(
        icon: Icons.notes_rounded,
        text: 'Có ${transcript.lineCount} dòng nội dung.\n'
            'Gõ từ khóa (VD: "Tứ Niệm Xứ", "the") để tìm —\n'
            'chạm kết quả để nhảy tới đúng vị trí.',
      );
    }
    final results = _results();
    if (results.isEmpty) {
      return const _EmptyHint(
        icon: Icons.search_off,
        text: 'Không tìm thấy kết quả cho từ khóa này.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final line = results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              HapticFeedback.selectionClick();
              await widget.player.seek(line.start);
              if (!widget.player.isPlaying) await widget.player.play();
            },
            onLongPress: () async {
              final mark = await showCreateMarkSheet(
                context,
                soundlist: widget.soundlist,
                audioPath: widget.path!,
                position: line.start,
              );
              if (mark != null) await widget.soundlist.reload();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF232841),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SoundMark.formatTime(line.start),
                    style: const TextStyle(color: Color(0xFF26C6DA), fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────── CHUNG ───────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
