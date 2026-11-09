// lib/screens/listen_mode/widgets/audio_playlists_sheet.dart
// I4U18-LISTEN-LIB-001 — UI Playlist thủ công:
//  - AudioPlaylistsSheet: liệt kê / tạo / đổi tên / xoá / mở playlist.
//  - AddToPlaylistSheet: thêm một bài vào playlist (tạo mới nếu cần).
//
// Playlist chỉ chứa libraryId (không đụng transcript/LRC/reopen). Phát một
// bài trong playlist đi qua đúng luồng _openEntry (resolvePlayablePath +
// markPlayed + RecentAudio) như tab Thư viện.

// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/audio_library_entry.dart';
import '../../../models/audio_playlist.dart';
import '../../../models/audio_queue_item.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/player_provider.dart';

const _accent = Color(0xFF6C63FF);

Future<String?> _promptName(BuildContext context, {String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(dialogCtx.uiText('Tên playlist'),
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: dialogCtx.uiText('Ví dụ: Pháp thoại buổi sáng'),
          hintStyle: const TextStyle(color: Colors.white30),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _accent)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(dialogCtx.uiText('Hủy')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _accent),
          onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
          child: Text(dialogCtx.uiText('Lưu'),
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class AudioPlaylistsSheet extends StatelessWidget {
  const AudioPlaylistsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioLibraryProvider>();
    final playlists = provider.playlists;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
              child: Row(
                children: [
                  const Icon(Icons.queue_music, color: _accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.uiText('Playlist của bạn'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final name = await _promptName(context);
                      if (name == null || name.isEmpty) return;
                      await provider.createPlaylist(name);
                    },
                    icon: const Icon(Icons.add, color: _accent, size: 18),
                    label: Text(context.uiText('Tạo mới'),
                        style: const TextStyle(color: _accent)),
                  ),
                ],
              ),
            ),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                child: Text(
                  context.uiText('Chưa có playlist. Chạm "Tạo mới" để bắt đầu, '
                      'hoặc giữ một bài trong Thư viện để thêm vào playlist.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, i) {
                    final pl = playlists[i];
                    return ListTile(
                      leading: const Icon(Icons.playlist_play,
                          color: _accent),
                      title: material.Text(pl.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        context.uiText('${pl.length} bài'),
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white38),
                        color: const Color(0xFF1A2235),
                        onSelected: (v) async {
                          if (v == 'rename') {
                            final name =
                                await _promptName(context, initial: pl.name);
                            if (name != null && name.isNotEmpty) {
                              await provider.renamePlaylist(pl.id, name);
                            }
                          } else if (v == 'delete') {
                            await provider.deletePlaylist(pl.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(context.uiText('Đổi tên'),
                                style: const TextStyle(color: Colors.white)),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.uiText('Xóa'),
                                style: const TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class AddToPlaylistSheet extends StatelessWidget {
  final AudioLibraryEntry entry;
  const AddToPlaylistSheet({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioLibraryProvider>();
    return SafeArea(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.uiText('Thêm "${entry.title}" vào playlist'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: _accent),
            title: Text(context.uiText('Tạo playlist mới'),
                style: const TextStyle(color: Colors.white)),
            onTap: () async {
              final name = await _promptName(context);
              if (name == null || name.isEmpty) return;
              final pl = await provider.createPlaylist(name);
              await provider.addToPlaylist(pl.id, entry.libraryId);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final pl in provider.playlists)
                  ListTile(
                    leading: Icon(
                      pl.contains(entry.libraryId)
                          ? Icons.check_circle
                          : Icons.playlist_add,
                      color: pl.contains(entry.libraryId)
                          ? _accent
                          : Colors.white54,
                    ),
                    title: material.Text(pl.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(context.uiText('${pl.length}'),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                    onTap: () async {
                      await provider.addToPlaylist(pl.id, entry.libraryId);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioLibraryProvider>();
    final AudioPlaylist? playlist = provider.playlists
        .cast<AudioPlaylist?>()
        .firstWhere((p) => p?.id == playlistId, orElse: () => null);
    final items = playlist == null
        ? const <AudioQueueItem>[]
        : AudioQueueItem.fromPlaylist(playlist, provider.entries);
    final entries = {for (final entry in provider.entries) entry.libraryId: entry};

    Future<void> playAt(int index, {bool skipFailures = false}) async {
      HapticFeedback.selectionClick();
      await context.read<PlayerProvider>().startQueue(
        items,
        startIndex: index,
        skipFailures: skipFailures,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141D2E),
        title: material.Text(playlist?.name ?? context.uiText('Playlist'),
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: context.uiText('Phát tất cả'),
            onPressed: items.isEmpty ? null : () => playAt(0, skipFailures: true),
            icon: const Icon(Icons.playlist_play),
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                context.uiText('Playlist trống — giữ một bài trong Thư viện để thêm.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 30),
              itemCount: items.length,
              onReorder: (oldI, newI) =>
                  provider.reorderPlaylist(playlistId, oldI, newI),
              itemBuilder: (context, i) {
                final item = items[i];
                final entry = entries[item.libraryId];
                return Padding(
                  key: ValueKey(item.libraryId),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: const Color(0xFF1A2235),
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      leading: Icon(
                        item.isMissing ? Icons.error_outline : Icons.music_note,
                        color: item.isMissing ? Colors.orangeAccent : _accent,
                      ),
                      title: material.Text(
                        item.isMissing
                            ? context.uiText('Bài không còn trong thư viện')
                            : item.title,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: entry == null
                          ? null
                          : material.Text(
                              [
                                if (entry.artist != null) entry.artist!,
                                entry.durationLabel,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                      onTap: item.isMissing ? null : () => playAt(i),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.white38, size: 20),
                        onPressed: () => provider.removeFromPlaylist(
                            playlistId, item.libraryId!),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
