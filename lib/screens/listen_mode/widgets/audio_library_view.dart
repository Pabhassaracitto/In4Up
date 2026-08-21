// lib/screens/listen_mode/widgets/audio_library_view.dart
// Tab "Thư viện" trong ListenLibraryScreen — toàn bộ audio máy (P1).
//
// Luồng: mở tab → xin quyền (permission_handler) → quét MediaStore qua
// MethodChannel → danh sách (tìm kiếm, sắp xếp) → chạm để phát (just_audio
// phát content://) + cập nhật RecentAudio.

// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, prefer_const_constructors_in_immutables, prefer_const_literals_to_create_immutables, sort_child_properties_last, avoid_unnecessary_containers, sized_box_for_whitespace, use_build_context_synchronously, avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/audio_library_entry.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/player_provider.dart';
import '../models/recent_audio.dart';
import '../services/recent_audio_service.dart';

class AudioLibraryView extends StatefulWidget {
  const AudioLibraryView({super.key});

  @override
  State<AudioLibraryView> createState() => _AudioLibraryViewState();
}

class _AudioLibraryViewState extends State<AudioLibraryView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    final provider = context.read<AudioLibraryProvider>();
    await provider.load();
    final granted = await provider.ensurePermission();
    if (granted) {
      await provider.scan();
    }
  }

  Future<void> _openEntry(AudioLibraryEntry entry) async {
    HapticFeedback.selectionClick();
    final player = context.read<PlayerProvider>();
    await player.loadSong(
      path: entry.uri,
      title: entry.title,
      artist: entry.artist,
      autoPlay: true,
    );
    if (!mounted) return;
    // Cập nhật thời gian đã nghe trong chỉ mục + RecentAudio.
    await context.read<AudioLibraryProvider>().markPlayed(entry);
    await RecentAudioService().addOrUpdate(
      RecentAudio.fromLocalFile(
        path: entry.uri,
        title: entry.title,
        totalDuration: Duration(milliseconds: entry.durationMs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioLibraryProvider>();

    if (!provider.hasPermission) {
      return _PermissionGate(
        onGrant: () async {
          final granted = await provider.ensurePermission();
          if (granted) await provider.scan();
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '🔍  Tìm trong thư viện máy…',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
              filled: true,
              fillColor: const Color(0xFF1A2235),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: provider.isScanning
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(child: _buildList(provider)),
      ],
    );
  }

  Widget _buildList(AudioLibraryProvider provider) {
    if (provider.isScanning && provider.entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'Đang quét thư viện âm thanh…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '⚠️ Lỗi quét: ${provider.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEF5350), fontSize: 13),
          ),
        ),
      );
    }

    final results = provider.search(_query);
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_music_outlined, size: 46, color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                provider.entries.isEmpty
                    ? 'Không tìm thấy file âm thanh nào trên máy.\n\n'
                        'Kiểm tra quyền truy cập, hoặc dùng "Thêm audio" '
                        'ở tab Gần đây để import thủ công.'
                    : 'Không có kết quả cho từ khóa này.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => provider.scan(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Quét lại'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.scan(),
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1A2235),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 110),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final entry = results[i];
          final isRecent =
              entry.lastPlayed != null &&
              DateTime.now().difference(entry.lastPlayed!) <
                  const Duration(days: 14);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openEntry(entry),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2235),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isRecent
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.music_note, color: Color(0xFF6C63FF), size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            [
                              if (entry.artist != null) entry.artist!,
                              entry.durationLabel,
                              entry.source.label,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    if (isRecent)
                      const Icon(Icons.history, color: Color(0xFF6C63FF), size: 15),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cổng quyền — hiển thị khi chưa được cấp quyền truy cập audio.
class _PermissionGate extends StatelessWidget {
  final Future<void> Function() onGrant;

  const _PermissionGate({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phonelink_lock, size: 48, color: Colors.white24),
            const SizedBox(height: 14),
            const Text(
              'Cần quyền truy cập âm thanh',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Để quét và liệt kê toàn bộ file âm thanh trên máy.\n'
              'Dữ liệu chỉ lưu cục bộ (offline-first).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.6),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.lock_open, size: 18, color: Colors.white),
              label: const Text(
                'Cấp quyền & quét',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
