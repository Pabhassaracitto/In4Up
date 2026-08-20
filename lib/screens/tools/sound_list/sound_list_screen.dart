// lib/screens/tools/sound_list/sound_list_screen.dart
// Soundlist – Màn hình "Âm mục" chính (thư viện toàn bộ âm thanh đã đánh dấu).
//
// Liệt kê mọi file audio có dữ liệu Âm mục (điểm / chương / đoạn):
//   • Tìm kiếm theo tên file, nhãn, ghi chú, tag, tên đoạn.
//   • Lọc theo loại (Quan trọng, Khó, Chưa hiểu, Yêu thích, Câu hay,
//     Pháp thoại, Tiếng Anh).
//   • Mỗi file mở rộng ra thành "cuốn sách": mục lục + điểm + đoạn.
//   • Chạm bất kỳ mục nào → nhảy đến vị trí đó trong trình nghe.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/segment.dart';
import '../../../models/sound_chapter.dart';
import '../../../models/sound_mark.dart';
import '../../../models/sound_transcript.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/soundlist_provider.dart';
import '../../../widgets/sound_auto_toc_dialog.dart';
import '../../../widgets/sound_mark_edit_sheet.dart';

enum _SoundFilter {
  all('Tất cả', null),
  important('⭐ Quan trọng', SoundMarkKind.important),
  hard('💪 Khó', SoundMarkKind.hard),
  question('❓ Chưa hiểu', SoundMarkKind.question),
  favorite('❤️ Yêu thích', SoundMarkKind.favorite),
  quote('💬 Câu hay', SoundMarkKind.quote),
  dharma('🙏 Pháp thoại', null),
  english('🇬🇧 Tiếng Anh', null);

  final String label;
  final SoundMarkKind? kind;
  const _SoundFilter(this.label, this.kind);
}

class SoundListScreen extends StatefulWidget {
  const SoundListScreen({super.key});

  @override
  State<SoundListScreen> createState() => _SoundListScreenState();
}

class _SoundListScreenState extends State<SoundListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _SoundFilter _filter = _SoundFilter.all;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final soundlist = context.read<SoundlistProvider>();
    if (!soundlist.isLoaded) {
      await soundlist.load();
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final soundlist = context.watch<SoundlistProvider>();
    final player = context.watch<PlayerProvider>();

    var files = soundlist.buildFileIndex();
    files = _applyFilter(files);
    files = _applySearch(files);

    final totalMarks = soundlist.marks.length;
    final totalChapters = soundlist.chapters.length;
    final totalSegments = soundlist.getAllSegments().length;

    return Scaffold(
      backgroundColor: const Color(0xFF141824),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141824),
        title: const Text(
          'Âm mục — Thư viện âm thanh',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await soundlist.reload();
              if (mounted) setState(() => _loaded = true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Thống kê ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Row(
              children: [
                _StatChip(icon: Icons.album_outlined, count: files.length, label: 'file'),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.push_pin_outlined, count: totalMarks, label: 'điểm'),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.menu_book_outlined, count: totalChapters, label: 'mục'),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.vertical_align_bottom, count: totalSegments, label: 'đoạn'),
              ],
            ),
          ),

          // ── Tìm kiếm ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: '🔍  Tìm tên file, nhãn, ghi chú, tag…',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF232841),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),

          // ── Bộ lọc ──
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _SoundFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final f = _SoundFilter.values[i];
                final selected = _filter == f;
                return ChoiceChip(
                  selected: selected,
                  label: Text(f.label, style: const TextStyle(fontSize: 12)),
                  selectedColor: const Color(0xFF6C63FF),
                  backgroundColor: const Color(0xFF232841),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                  onSelected: (_) => setState(() => _filter = f),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // ── Danh sách file ──
          Expanded(
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  )
                : files.isEmpty
                    ? const _EmptyLibrary()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
                        itemCount: files.length,
                        itemBuilder: (context, i) => _FileCard(
                          file: files[i],
                          player: player,
                          soundlist: soundlist,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  List<SoundFileIndex> _applyFilter(List<SoundFileIndex> files) {
    if (_filter == _SoundFilter.all) return files;
    final kind = _filter.kind;
    return files.where((f) {
      if (kind != null) {
        return f.marks.any((m) => m.kind == kind);
      }
      switch (_filter) {
        case _SoundFilter.dharma:
          return f.segments.any((s) => s.type == SegmentType.dharma) ||
              f.marks.any((m) => m.kind == SoundMarkKind.quote);
        case _SoundFilter.english:
          return f.segments.any((s) => s.type == SegmentType.english);
        default:
          return true;
      }
    }).toList();
  }

  List<SoundFileIndex> _applySearch(List<SoundFileIndex> files) {
    if (_query.isEmpty) return files;
    return files.where((f) {
      if (f.title.toLowerCase().contains(_query)) return true;
      // Tìm trong toàn bộ transcript (nội dung lời nói trong audio).
      if (f.transcriptText != null &&
          f.transcriptText!.toLowerCase().contains(_query)) {
        return true;
      }
      for (final m in f.marks) {
        if (m.label.toLowerCase().contains(_query)) return true;
        if ((m.note ?? '').toLowerCase().contains(_query)) return true;
        if (m.tags.any((t) => t.toLowerCase().contains(_query))) return true;
      }
      for (final c in f.chapters) {
        if (c.title.toLowerCase().contains(_query)) return true;
        if ((c.note ?? '').toLowerCase().contains(_query)) return true;
      }
      for (final s in f.segments) {
        if (s.title.toLowerCase().contains(_query)) return true;
        if ((s.note ?? '').toLowerCase().contains(_query)) return true;
      }
      return false;
    }).toList();
  }
}

// ─────────────────────────────── CHIP THỐNG KÊ ───────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _StatChip({required this.icon, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF232841),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── THẺ FILE ───────────────────────────────

class _FileCard extends StatefulWidget {
  final SoundFileIndex file;
  final PlayerProvider player;
  final SoundlistProvider soundlist;

  const _FileCard({
    required this.file,
    required this.player,
    required this.soundlist,
  });

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final isCurrent = widget.player.currentSongPath != null &&
        _norm(widget.player.currentSongPath!) == _norm(file.path);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? const Color(0xFF6C63FF).withValues(alpha: 0.6) : Colors.white10,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF26C6DA), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${file.contentKindLabel}'
                          ' · ${file.markCount} điểm · ${file.segmentCount} đoạn · ${file.chapterCount} mục'
                          '${file.hotRangeCount > 0 ? ' · 🔥 ${file.hotRangeCount} lặp nhiều' : ''}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.play_circle_fill, color: Color(0xFF6C63FF), size: 18),
                    ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            _FileContents(file: file, player: widget.player, soundlist: widget.soundlist),
        ],
      ),
    );
  }

  static String _norm(String p) => p.replaceAll('\\', '/');
}

class _FileContents extends StatelessWidget {
  final SoundFileIndex file;
  final PlayerProvider player;
  final SoundlistProvider soundlist;

  const _FileContents({
    required this.file,
    required this.player,
    required this.soundlist,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 6),

          // ── Hành động ──
          Row(
            children: [
              _FileAction(
                icon: Icons.play_arrow_rounded,
                label: 'Phát',
                color: const Color(0xFF66BB6A),
                onTap: () => _playFile(context),
              ),
              const SizedBox(width: 6),
              _FileAction(
                icon: Icons.push_pin_outlined,
                label: 'Đánh dấu',
                color: const Color(0xFFFFB300),
                onTap: () async {
                  final pos = player.state.position;
                  final mark = await showCreateMarkSheet(
                    context,
                    soundlist: soundlist,
                    audioPath: file.path,
                    position: player.currentSongPath != null &&
                            _norm(player.currentSongPath!) == _norm(file.path)
                        ? pos
                        : Duration.zero,
                  );
                  if (mark != null) await soundlist.reload();
                },
              ),
              const SizedBox(width: 6),
              _FileAction(
                icon: Icons.menu_book_outlined,
                label: 'Thêm mục',
                color: const Color(0xFF26C6DA),
                onTap: () => _addChapter(context),
              ),
              const SizedBox(width: 6),
              _FileAction(
                icon: Icons.auto_awesome,
                label: 'Tự tạo',
                color: const Color(0xFF00BCD4),
                onTap: () => runSoundAutoToc(
                  context,
                  audioPath: file.path,
                  hasExistingChapters: file.chapters.isNotEmpty,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Mục lục ──
          if (file.chapters.isNotEmpty) ...[
            const _SectionTitle('Mục lục', Icons.menu_book_outlined, Color(0xFF26C6DA)),
            for (final chapter in file.chapters)
              _LibraryChapterTile(
                chapter: chapter,
                depth: _depthOf(chapter),
                file: file,
                player: player,
                soundlist: soundlist,
              ),
            const SizedBox(height: 6),
          ],

          // ── Điểm ──
          if (file.marks.isNotEmpty) ...[
            const _SectionTitle('Điểm', Icons.push_pin_outlined, Color(0xFFFFB300)),
            for (final mark in file.marks)
              _LibraryMarkTile(mark: mark, file: file, player: player, soundlist: soundlist),
            const SizedBox(height: 6),
          ],

          // ── Đoạn ──
          if (file.segments.isNotEmpty) ...[
            const _SectionTitle('Đoạn', Icons.vertical_align_bottom, Color(0xFF6C63FF)),
            for (final segment in file.segments)
              _LibrarySegmentTile(segment: segment, file: file, player: player, soundlist: soundlist),
          ],

          // ── Nội dung (transcript) ──
          if (file.transcriptLines.isNotEmpty) ...[
            const _SectionTitle('Nội dung', Icons.notes_rounded, Color(0xFF26C6DA)),
            for (final line in file.transcriptLines.take(5))
              _LibraryTranscriptLine(line: line, file: file, player: player),
            if (file.transcriptLines.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '… và ${file.transcriptLines.length - 5} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ),
            const SizedBox(height: 6),
          ],

          if (file.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'File chưa có dữ liệu — mở trong Listen Mode và đánh dấu.',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _depthOf(SoundChapter chapter) {
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

  Future<void> _playFile(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await player.loadSong(path: file.path, autoPlay: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('▶️ Đang phát: ${file.title}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
    }
  }

  Future<void> _addChapter(BuildContext context) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232841),
        title: const Text('Thêm mục cho file', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Tên chương/mục',
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
    await soundlist.addChapter(audioPath: file.path, title: title);
  }

  static String _norm(String p) => p.replaceAll('\\', '/');
}

// ─────────────────────────────── HÀNH ĐỘNG FILE ───────────────────────────────

class _FileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FileAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── TILE THƯ VIỆN ───────────────────────────────

class _LibraryChapterTile extends StatelessWidget {
  final SoundChapter chapter;
  final int depth;
  final SoundFileIndex file;
  final PlayerProvider player;
  final SoundlistProvider soundlist;

  const _LibraryChapterTile({
    required this.chapter,
    required this.depth,
    required this.file,
    required this.player,
    required this.soundlist,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        HapticFeedback.selectionClick();
        if (player.currentSongPath == null ||
            _norm(player.currentSongPath!) != _norm(file.path)) {
          await player.loadSong(path: file.path);
        }
        if (chapter.position != null) {
          await player.seek(chapter.position!);
          if (!player.isPlaying) await player.play();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(left: (depth * 14).toDouble(), top: 2, bottom: 2),
        child: Row(
          children: [
            Icon(
              depth == 0 ? Icons.menu_book_rounded : Icons.subdirectory_arrow_right,
              size: depth == 0 ? 15 : 13,
              color: const Color(0xFF26C6DA).withValues(alpha: depth == 0 ? 1 : 0.7),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
            if (chapter.position != null)
              Text(
                SoundMark.formatTime(chapter.position!),
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  static String _norm(String p) => p.replaceAll('\\', '/');
}

class _LibraryMarkTile extends StatelessWidget {
  final SoundMark mark;
  final SoundFileIndex file;
  final PlayerProvider player;
  final SoundlistProvider soundlist;

  const _LibraryMarkTile({
    required this.mark,
    required this.file,
    required this.player,
    required this.soundlist,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        HapticFeedback.selectionClick();
        if (player.currentSongPath == null ||
            _norm(player.currentSongPath!) != _norm(file.path)) {
          await player.loadSong(path: file.path);
        }
        await player.seek(mark.position);
        if (!player.isPlaying) await player.play();
      },
      onLongPress: () async {
        final updated = await showEditMarkSheet(context, soundlist: soundlist, mark: mark);
        if (updated != null) await soundlist.reload();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(mark.kind.icon, size: 14, color: mark.kind.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                mark.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
            Text(
              mark.timeLabel,
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static String _norm(String p) => p.replaceAll('\\', '/');
}

class _LibrarySegmentTile extends StatelessWidget {
  final Segment segment;
  final SoundFileIndex file;
  final PlayerProvider player;
  final SoundlistProvider soundlist;

  const _LibrarySegmentTile({
    required this.segment,
    required this.file,
    required this.player,
    required this.soundlist,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        HapticFeedback.mediumImpact();
        await player.playSegment(segment);
      },
      onLongPress: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF232841),
            title: const Text('Xóa đoạn?', style: TextStyle(color: Colors.white, fontSize: 15)),
            content: Text(
              '"${segment.title}"',
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
          await soundlist.reload();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.vertical_align_bottom, size: 14, color: Color(0xFF6C63FF)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                segment.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
            Text(
              '${SoundMark.formatTime(segment.startTime)} → ${SoundMark.formatTime(segment.endTime)}',
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTranscriptLine extends StatelessWidget {
  final TranscriptLine line;
  final SoundFileIndex file;
  final PlayerProvider player;

  const _LibraryTranscriptLine({
    required this.line,
    required this.file,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        HapticFeedback.selectionClick();
        if (player.currentSongPath == null ||
            _norm(player.currentSongPath!) != _norm(file.path)) {
          await player.loadSong(path: file.path);
        }
        await player.seek(line.start);
        if (!player.isPlaying) await player.play();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SoundMark.formatTime(line.start),
              style: const TextStyle(color: Color(0xFF26C6DA), fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                line.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _norm(String p) => p.replaceAll('\\', '/');
}

// ─────────────────────────────── TRẠNG THÁI RỖNG ───────────────────────────────

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, size: 52, color: Colors.white24),
            const SizedBox(height: 14),
            const Text(
              'Âm mục còn trống',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mở Listen Mode, nghe file bất kỳ rồi:\n'
              '• Chạm 📌 "Dấu" để đánh dấu một điểm\n'
              '• Chọn A–B rồi lưu thành đoạn học tập\n'
              '• Mở "Âm mục" để tạo mục lục như sách\n\n'
              'Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
