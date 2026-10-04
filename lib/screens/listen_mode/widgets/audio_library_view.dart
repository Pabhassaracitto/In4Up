// lib/screens/listen_mode/widgets/audio_library_view.dart
// Tab "Thư viện" trong ListenLibraryScreen — toàn bộ audio máy (P1) +
// I4U18-LISTEN-LIB-001: lọc album/tác giả/thư mục/yêu thích, smart playlist
// (Gần đây / Yêu thích / Chưa nghe), playlist thủ công.
//
// Luồng: mở tab → xin quyền (permission_handler) → quét MediaStore qua
// MethodChannel → danh sách (tìm kiếm, lọc, smart) → chạm để phát (just_audio
// phát content://) + cập nhật RecentAudio.
//
// KHÔNG đụng transcript/LRC/reopen: chỉ đọc/ghi chỉ mục + playlist (libraryId).

// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, prefer_const_constructors_in_immutables, prefer_const_literals_to_create_immutables, sort_child_properties_last, avoid_unnecessary_containers, sized_box_for_whitespace, use_build_context_synchronously, avoid_print
// localized_material export material (hide Text) + Text localized + uiText
// (rule 5: chrome không tiếng Việt khi locale ≠ vi) — KHÔNG import material
// trực tiếp (conflict tên Text).
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/audio_library_entry.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../services/audio_library_service.dart';
import '../models/recent_audio.dart';
import '../services/recent_audio_service.dart';
import 'audio_playlists_sheet.dart';

class AudioLibraryView extends StatefulWidget {
  const AudioLibraryView({super.key});

  @override
  State<AudioLibraryView> createState() => _AudioLibraryViewState();
}

class _AudioLibraryViewState extends State<AudioLibraryView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _initialized = false;

  SmartPlaylist _smart = SmartPlaylist.all;
  String? _album;
  String? _artist;
  String? _folder;

  static const _accent = Color(0xFF6C63FF);

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
    // content:// → copy sang cache trước khi phát (just_audio không phát
    // content:// ổn định) — Fix "mở bài hát không chạy được".
    final playable = await AudioLibraryService().resolvePlayablePath(entry.uri);
    if (!mounted) return;
    await player.loadSong(
      path: playable,
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

  void _clearFacets() {
    setState(() {
      _album = null;
      _artist = null;
      _folder = null;
    });
  }

  Future<void> _pickFacet(
    String title,
    List<String> values,
    String? current,
    void Function(String?) onPick,
  ) async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: const Color(0xFF141D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.white54),
              title: Text(context.uiText('Tất cả'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final v in values)
              ListTile(
                leading: Icon(
                  v == current ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: v == current ? _accent : Colors.white38,
                  size: 18,
                ),
                title: Text(v,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    onPick(chosen.isEmpty ? null : chosen);
  }

  Future<void> _addToPlaylist(AudioLibraryEntry entry) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141D2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AddToPlaylistSheet(entry: entry),
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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: context.uiText('🔍  Tìm trong thư viện máy…'),
                    hintStyle:
                        const TextStyle(color: Colors.white30, fontSize: 12.5),
                    filled: true,
                    fillColor: const Color(0xFF1A2235),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
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
                                color: _accent,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconPill(
                icon: Icons.queue_music,
                tooltip: context.uiText('Playlist'),
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF141D2E),
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  builder: (_) => const AudioPlaylistsSheet(),
                ),
              ),
            ],
          ),
        ),
        _buildSmartChips(provider),
        _buildFacetBar(provider),
        Expanded(child: _buildList(provider)),
      ],
    );
  }

  Widget _buildSmartChips(AudioLibraryProvider provider) {
    Widget chip(SmartPlaylist s, String label, IconData icon) {
      final sel = _smart == s;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: sel,
          onSelected: (_) => setState(() => _smart = s),
          backgroundColor: const Color(0xFF1A2235),
          selectedColor: _accent.withValues(alpha: 0.3),
          side: BorderSide(color: sel ? _accent : Colors.white12),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: sel ? _accent : Colors.white54),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : Colors.white54,
                      fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          chip(SmartPlaylist.all, context.uiText('Tất cả'), Icons.library_music),
          chip(SmartPlaylist.recent, context.uiText('Gần đây'), Icons.history),
          chip(SmartPlaylist.favorite, context.uiText('Yêu thích'),
              Icons.favorite),
          chip(SmartPlaylist.unplayed, context.uiText('Chưa nghe'),
              Icons.fiber_new),
        ],
      ),
    );
  }

  Widget _buildFacetBar(AudioLibraryProvider provider) {
    final hasFacet = _album != null || _artist != null || _folder != null;
    Widget facet(String label, String? value, VoidCallback onTap) {
      final active = value != null;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          onPressed: onTap,
          backgroundColor:
              active ? _accent.withValues(alpha: 0.25) : const Color(0xFF1A2235),
          side: BorderSide(color: active ? _accent : Colors.white12),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(active ? value : label,
                  style: TextStyle(
                      color: active ? Colors.white : Colors.white54,
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(width: 3),
              Icon(Icons.arrow_drop_down,
                  size: 16, color: active ? _accent : Colors.white38),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          facet(
            context.uiText('Album'),
            _album,
            () => _pickFacet(context.uiText('Chọn album'), provider.albums,
                _album, (v) => setState(() => _album = v)),
          ),
          facet(
            context.uiText('Tác giả'),
            _artist,
            () => _pickFacet(context.uiText('Chọn tác giả'), provider.artists,
                _artist, (v) => setState(() => _artist = v)),
          ),
          facet(
            context.uiText('Thư mục'),
            _folder,
            () => _pickFacet(context.uiText('Chọn thư mục'), provider.folders,
                _folder, (v) => setState(() => _folder = v)),
          ),
          if (hasFacet)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                onPressed: _clearFacets,
                backgroundColor: const Color(0xFF1A2235),
                side: const BorderSide(color: Colors.white12),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close, size: 13, color: Colors.white54),
                    const SizedBox(width: 3),
                    Text(context.uiText('Xóa lọc'),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(AudioLibraryProvider provider) {
    if (provider.isScanning && provider.entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _accent, strokeWidth: 2),
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

    final results = provider.filtered(
      query: _query,
      smart: _smart,
      album: _album,
      artist: _artist,
      folder: _folder,
    );
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_music_outlined,
                  size: 46, color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                provider.entries.isEmpty
                    ? 'Không tìm thấy file âm thanh nào trên máy.\n\n'
                        'Kiểm tra quyền truy cập, hoặc dùng "Thêm audio" '
                        'ở tab Gần đây để import thủ công.'
                    : 'Không có kết quả cho bộ lọc này.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => provider.scan(),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.uiText('Quét lại')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.scan(),
      color: _accent,
      backgroundColor: const Color(0xFF1A2235),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 110),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final entry = results[i];
          final isRecent = entry.lastPlayed != null &&
              DateTime.now().difference(entry.lastPlayed!) <
                  const Duration(days: 14);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openEntry(entry),
              onLongPress: () => _addToPlaylist(entry),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2235),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isRecent
                        ? _accent.withValues(alpha: 0.4)
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.music_note,
                          color: _accent, size: 17),
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
                              if (entry.album != null) entry.album!,
                              entry.durationLabel,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      icon: Icon(
                        entry.favorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: entry.favorite ? _accent : Colors.white24,
                        size: 18,
                      ),
                      onPressed: () => context
                          .read<AudioLibraryProvider>()
                          .toggleFavorite(entry),
                    ),
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

class _IconPill extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconPill(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        ),
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
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
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
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
