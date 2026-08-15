//
// Widget duyệt và phát âm thanh từ Google Drive
// Tích hợp vào AudioLibraryDrawer (tab Drive)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../services/google_drive_service.dart';
import 'package:in4up/core/language/tr_extension.dart';

class GoogleDriveBrowser extends StatefulWidget {
  const GoogleDriveBrowser({super.key});

  @override
  State<GoogleDriveBrowser> createState() => _GoogleDriveBrowserState();
}

class _GoogleDriveBrowserState extends State<GoogleDriveBrowser>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _driveService = GoogleDriveService();
  final _searchCtrl = TextEditingController();

  List<DriveItem> _items = [];
  bool _loading = false;
  bool _searching = false;
  String? _downloadingId;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _driveService.addListener(_onServiceUpdate);
    // Nếu đã đăng nhập → load ngay
    if (_driveService.isSignedIn) {
      _loadItems();
    }
  }

  @override
  void dispose() {
    _driveService.removeListener(_onServiceUpdate);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadItems() async {
    if (_loading) return;
    setState(() => _loading = true);

    final items = await _driveService.listItems(audioOnly: true);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadItems();
      return;
    }
    setState(() => _searching = true);
    final results = await _driveService.searchAudio(query.trim());
    if (mounted) {
      setState(() {
        _items = results;
        _searching = false;
      });
    }
  }

  // ── Phát file từ Drive ──────────────────────────────
  Future<void> _playFile(DriveItem item) async {
    if (item.isFolder) {
      _driveService.enterFolder(item);
      await _loadItems();
      return;
    }

    HapticFeedback.mediumImpact();
    final player = context.read<PlayerProvider>();

    // Hiện dialog: Stream hoặc Download
    final choice = await _showPlayDialog(item);
    if (choice == null) return;

    if (choice == 'stream') {
      await _streamFile(item, player);
    } else {
      await _downloadAndPlay(item, player);
    }
  }

  Future<String?> _showPlayDialog(DriveItem item) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // File info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.audio_file,
                      color: Color(0xFF4CAF50), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (item.sizeLabel.isNotEmpty)
                        Text(item.sizeLabel,
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Options
            _PlayOption(
              icon: Icons.stream,
              title: context.tr('Stream trực tiếp'),
              subtitle: context.tr('Phát ngay, cần mạng'),
              color: const Color(0xFF2196F3),
              onTap: () => Navigator.pop(context, 'stream'),
            ),
            const SizedBox(height: 10),
            _PlayOption(
              icon: Icons.download_for_offline,
              title: context.tr('Tải về & phát'),
              subtitle: context.tr('Chất lượng tốt hơn, cần thời gian tải'),
              color: const Color(0xFF6C63FF),
              onTap: () => Navigator.pop(context, 'download'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _streamFile(DriveItem item, PlayerProvider player) async {
    final info = await _driveService.getStreamInfo(item.id);
    if (info == null) {
      _showSnack(context.tr('❌ Không thể stream file này'));
      return;
    }

    // Tạo URL có auth token embed (just_audio hỗ trợ custom headers)
    // Cách đơn giản: dùng URL với Bearer token
    final token = info.headers['Authorization'] ?? '';
    final urlWithToken =
        '${info.url}&access_token=${token.replaceFirst('Bearer ', '')}';

    await player.loadSong(
      path: urlWithToken,
      title: item.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      artist: 'Google Drive',
      autoPlay: true,
    );

    if (context.mounted) {
      Navigator.pop(context); // Đóng drawer
      _showSnack('🎵 Đang stream: ${item.name}');
    }
  }

  Future<void> _downloadAndPlay(DriveItem item, PlayerProvider player) async {
    setState(() {
      _downloadingId = item.id;
      _downloadProgress = 0;
    });

    final path = await _driveService.downloadToCache(
      item,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );

    setState(() => _downloadingId = null);

    if (path == null) {
      _showSnack(context.tr('❌ Tải thất bại'));
      return;
    }

    await player.loadSong(
      path: path,
      title: item.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      artist: 'Google Drive',
      autoPlay: true,
    );

    if (context.mounted) {
      Navigator.pop(context);
      _showSnack('Content');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A237E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Chưa đăng nhập
    if (!_driveService.isSignedIn) {
      return _buildSignInScreen();
    }

    return Column(
      children: [
        _buildSearchBar(),
        _buildBreadcrumb(),
        Expanded(
          child: _loading || _searching
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF4285F4), strokeWidth: 2))
              : _items.isEmpty
                  ? _buildEmpty()
                  : _buildFileList(),
        ),
        _buildBottomBar(),
      ],
    );
  }

  // ── Sign In Screen ────────────────────────────────────
  Widget _buildSignInScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google Drive icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📂', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Google Drive',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TrText('Kết nối Drive để duyệt\nvà phát file âm thanh của bạn', style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (_driveService.isLoading)
              const CircularProgressIndicator(color: Color(0xFF4285F4))
            else ...[
              _GoogleSignInButton(
                onTap: () async {
                  final ok = await _driveService.signIn();
                  if (ok) _loadItems();
                },
              ),
              if (_driveService.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _driveService.error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],

            const SizedBox(height: 20),
            TrText('Chỉ đọc file — không chỉnh sửa hay xóa', style: TextStyle(color: Colors.grey[700], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search Bar ────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.search, color: Colors.grey[600], size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: context.tr('Tìm file âm thanh trên Drive...'),
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onSubmitted: _search,
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _loadItems();
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.close, color: Colors.grey[600], size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Breadcrumb ────────────────────────────────────────
  Widget _buildBreadcrumb() {
    final breadcrumb = _driveService.breadcrumb;
    if (breadcrumb.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (int i = 0; i < breadcrumb.length; i++) ...[
              GestureDetector(
                onTap: () async {
                  _driveService.navigateToIndex(i);
                  await _loadItems();
                },
                child: Text(
                  breadcrumb[i].name,
                  style: TextStyle(
                    color: i == breadcrumb.length - 1
                        ? Colors.white
                        : const Color(0xFF4285F4),
                    fontSize: 12,
                    fontWeight: i == breadcrumb.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (i < breadcrumb.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child:
                      Icon(Icons.chevron_right, color: Colors.grey, size: 14),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── File List ─────────────────────────────────────────
  Widget _buildFileList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      itemCount: _items.length,
      itemBuilder: (_, i) => _DriveItemTile(
        item: _items[i],
        isDownloading: _downloadingId == _items[i].id,
        downloadProgress:
            _downloadingId == _items[i].id ? _downloadProgress : 0,
        onTap: () => _playFile(_items[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.audio_file_outlined, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            _searchCtrl.text.isNotEmpty
                ? 'Search'
                : 'Content',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (_driveService.breadcrumb.length > 1) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                _driveService.goBack();
                await _loadItems();
              },
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const TrText(context.l10n.webReaderGoBack),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Row(
        children: [
          // Avatar + name
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF4285F4),
            child: Text(
              _driveService.account?.displayName?.substring(0, 1) ?? '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _driveService.account?.email ?? '',
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
            onPressed: _loadItems,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Sign out
          IconButton(
            icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
            onPressed: () async {
              await _driveService.signOut();
              setState(() => _items = []);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Tile mỗi file/thư mục ───────────────────────────────
class _DriveItemTile extends StatelessWidget {
  final DriveItem item;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onTap;

  const _DriveItemTile({
    required this.item,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onTap,
  });

  Color get _iconColor {
    if (item.isFolder) return const Color(0xFF4285F4);
    final ext = item.extension;
    if (ext == 'mp3') return const Color(0xFFFF5722);
    if ({'m4a', 'mp4', 'm4b'}.contains(ext)) return const Color(0xFF9C27B0);
    if (ext == 'flac') return const Color(0xFF4CAF50);
    if (ext == 'wav') return const Color(0xFF2196F3);
    return const Color(0xFF4CAF50);
  }

  IconData get _icon {
    if (item.isFolder) return Icons.folder_rounded;
    return Icons.audio_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDownloading
                ? Color(0xFF6C63FF).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_icon, color: _iconColor, size: 18),
                ),
                const SizedBox(width: 12),

                // Name + info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (!item.isFolder && item.extension.isNotEmpty) ...[
                            _Badge(
                              item.extension.toUpperCase(),
                              _iconColor,
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (item.sizeLabel.isNotEmpty)
                            Text(item.sizeLabel,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow for folder / play for file
                Icon(
                  item.isFolder
                      ? Icons.chevron_right
                      : Icons.play_circle_outline,
                  color: Colors.grey[600],
                  size: 18,
                ),
              ],
            ),

            // Download progress bar
            if (isDownloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: downloadProgress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Loading ${(downloadProgress * 100).toInt()}%...',
                style: const TextStyle(color: Color(0xFF9C8FFF), fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Google Sign-In button ───────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Google G logo
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            const TrText('Đăng nhập với Google', style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Play option button ───────────────────────────────────
class _PlayOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PlayOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}