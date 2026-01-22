import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../providers/player_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/synced_lyrics_view.dart';

class SyncHubScreen extends StatefulWidget {
  const SyncHubScreen({super.key});

  @override
  State<SyncHubScreen> createState() => _SyncHubScreenState();
}

class _SyncHubScreenState extends State<SyncHubScreen> {
  @override
  void initState() {
    super.initState();
    // Attach player to sync provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncProvider = context.read<SyncProvider>();
      final playerProvider = context.read<PlayerProvider>();
      syncProvider.attachPlayer(playerProvider);
    });
  }

  @override
  void dispose() {
    // Detach khi thoát
    context.read<SyncProvider>().detachPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Consumer2<PlayerProvider, SyncProvider>(
          builder: (context, player, sync, child) {
            return Column(
              children: [
                // App Bar
                _buildAppBar(context, sync),

                // Main Content based on layout
                Expanded(
                  child: _buildContent(context, player, sync),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, SyncProvider sync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sync,
              color: Color(0xFF6C63FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Music + Text đồng bộ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Import LRC/SRT
          IconButton(
            onPressed: () => _importLyrics(context),
            icon: const Icon(Icons.subtitles),
            tooltip: 'Import LRC/SRT',
          ),
          // Layout toggle
          PopupMenuButton<SyncLayout>(
            icon: const Icon(Icons.view_agenda),
            tooltip: 'Bố cục',
            onSelected: (layout) => sync.setLayout(layout),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SyncLayout.split,
                child: Row(
                  children: [
                    Icon(Icons.view_agenda),
                    SizedBox(width: 12),
                    Text('Chia đôi'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SyncLayout.miniPlayer,
                child: Row(
                  children: [
                    Icon(Icons.picture_in_picture),
                    SizedBox(width: 12),
                    Text('Mini Player'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SyncLayout.musicFull,
                child: Row(
                  children: [
                    Icon(Icons.music_note),
                    SizedBox(width: 12),
                    Text('Chỉ Music'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SyncLayout.textFull,
                child: Row(
                  children: [
                    Icon(Icons.text_fields),
                    SizedBox(width: 12),
                    Text('Chỉ Text'),
                  ],
                ),
              ),
            ],
          ),
          // Settings
          IconButton(
            onPressed: () => _showSettings(context, sync),
            icon: const Icon(Icons.settings),
            tooltip: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, PlayerProvider player, SyncProvider sync) {
    // Nếu chưa có audio
    if (player.currentSongPath == null) {
      return _buildNoAudioState(context);
    }

    // Nếu chưa có lyrics
    if (!sync.hasDocument) {
      return _buildNoLyricsState(context, player);
    }

    // Hiển thị theo layout
    switch (sync.layout) {
      case SyncLayout.musicFull:
        return _buildMusicFullLayout(context, player);
      case SyncLayout.textFull:
        return _buildTextFullLayout(context, player, sync);
      case SyncLayout.miniPlayer:
        return _buildMiniPlayerLayout(context, player, sync);
      case SyncLayout.split:
      default:
        return _buildSplitLayout(context, player, sync);
    }
  }

  Widget _buildNoAudioState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có audio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vui lòng mở file audio trước',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Quay lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLyricsState(BuildContext context, PlayerProvider player) {
    return Column(
      children: [
        // Mini player ở trên
        const MiniPlayer(),

        // Empty state
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.subtitles_off,
                  size: 64,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có lyrics/text',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Import file LRC, SRT hoặc nhập text',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _importLyrics(context),
                      icon: const Icon(Icons.file_open),
                      label: const Text('Import file'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () => _showPasteDialog(context),
                      icon: const Icon(Icons.paste),
                      label: const Text('Nhập text'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitLayout(BuildContext context, PlayerProvider player, SyncProvider sync) {
    return Column(
      children: [
        // Music section
        SizedBox(
          height: MediaQuery.of(context).size.height * sync.musicHeight,
          child: const MiniPlayer(expanded: true),
        ),

        // Divider with drag handle
        GestureDetector(
          onVerticalDragUpdate: (details) {
            final newHeight = sync.musicHeight + details.delta.dy / MediaQuery.of(context).size.height;
            sync.setMusicHeight(newHeight);
          },
          child: Container(
            height: 20,
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),

        // Lyrics section
        Expanded(
          child: SyncedLyricsView(
            lines: sync.lines,
            currentIndex: sync.currentLineIndex,
            autoScroll: sync.autoScroll,
            showTimestamps: sync.showTimestamps,
            fontSize: sync.fontSize,
            onLineTap: (index) => sync.goToLine(index),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPlayerLayout(BuildContext context, PlayerProvider player, SyncProvider sync) {
    return Column(
      children: [
        // Mini player bar
        const MiniPlayer(expanded: false),

        // Full lyrics
        Expanded(
          child: SyncedLyricsView(
            lines: sync.lines,
            currentIndex: sync.currentLineIndex,
            autoScroll: sync.autoScroll,
            showTimestamps: sync.showTimestamps,
            fontSize: sync.fontSize + 2,
            onLineTap: (index) => sync.goToLine(index),
          ),
        ),
      ],
    );
  }

  Widget _buildMusicFullLayout(BuildContext context, PlayerProvider player) {
    return const MiniPlayer(expanded: true, fullScreen: true);
  }

  Widget _buildTextFullLayout(BuildContext context, PlayerProvider player, SyncProvider sync) {
    return SyncedLyricsView(
      lines: sync.lines,
      currentIndex: sync.currentLineIndex,
      autoScroll: sync.autoScroll,
      showTimestamps: sync.showTimestamps,
      fontSize: sync.fontSize + 4,
      onLineTap: (index) => sync.goToLine(index),
    );
  }

  // ==================== DIALOGS ====================

  Future<void> _importLyrics(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['lrc', 'srt', 'txt'],
      );

      if (result != null && result.files.isNotEmpty && context.mounted) {
        final file = File(result.files.first.path!);
        final content = await file.readAsString();
        final fileName = result.files.first.name.toLowerCase();
        final sync = context.read<SyncProvider>();

        if (fileName.endsWith('.lrc')) {
          sync.loadLrcContent(content, title: result.files.first.name);
        } else if (fileName.endsWith('.srt')) {
          sync.loadSrtContent(content, title: result.files.first.name);
        } else {
          sync.loadPlainText(content, title: result.files.first.name);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã import lyrics thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  void _showPasteDialog(BuildContext context) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập lyrics/text',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hỗ trợ định dạng LRC, SRT hoặc text thuần',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 10,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '[00:00.00]Dòng đầu tiên\n[00:03.00]Dòng thứ hai\n...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final content = controller.text.trim();
                      if (content.isNotEmpty) {
                        final sync = context.read<SyncProvider>();

                        // Detect format
                        if (content.contains(RegExp(r'\[\d{2}:\d{2}'))) {
                          sync.loadLrcContent(content, title: 'Pasted Lyrics');
                        } else if (content.contains('-->')) {
                          sync.loadSrtContent(content, title: 'Pasted Subtitles');
                        } else {
                          sync.loadPlainText(content, title: 'Pasted Text');
                        }

                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                    ),
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, SyncProvider sync) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cài đặt Sync Hub',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Auto scroll
              SwitchListTile(
                secondary: const Icon(Icons.autorenew, color: Colors.grey),
                title: const Text('Tự động cuộn', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Cuộn theo dòng hiện tại', style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: sync.autoScroll,
                onChanged: (_) {
                  sync.toggleAutoScroll();
                  setState(() {});
                },
              ),
              // Show timestamps
              SwitchListTile(
                secondary: const Icon(Icons.access_time, color: Colors.grey),
                title: const Text('Hiện timestamp', style: TextStyle(color: Colors.white)),
                value: sync.showTimestamps,
                onChanged: (_) {
                  sync.toggleTimestamps();
                  setState(() {});
                },
              ),
              // Font size
              ListTile(
                leading: const Icon(Icons.format_size, color: Colors.grey),
                title: const Text('Cỡ chữ', style: TextStyle(color: Colors.white)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        sync.setFontSize(sync.fontSize - 2);
                        setState(() {});
                      },
                      icon: const Icon(Icons.remove, color: Colors.white),
                    ),
                    Text(
                      '${sync.fontSize.toInt()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () {
                        sync.setFontSize(sync.fontSize + 2);
                        setState(() {});
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}