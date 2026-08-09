import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../services/google_drive_service.dart';

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

  Future<void> _playFile(DriveItem item) async {
    if (item.isFolder) {
      _driveService.enterFolder(item);
      await _loadItems();
      return;
    }

    HapticFeedback.mediumImpact();
    final player = context.read<PlayerProvider>();

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
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
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
            _PlayOption(
              icon: Icons.stream,
              title: 'Stream trực tiếp',
              subtitle: 'Phát ngay, cần mạng',
              color: const Color(0xFF2196F3),
              onTap: () => Navigator.pop(context, 'stream'),
            ),
            const SizedBox(height: 10),
            _PlayOption(
              icon: Icons.download_for_offline,
              title: 'Tải về & phát',
              subtitle: 'Chất lượng tốt hơn, cần thời gian tải',
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
      _showSnack('❌ Không thể stream file này');
      return;
    }

    final token = info.headers['Authorization'] ?? '';
    final urlWithToken = info.url.contains('?')
        ? '${info.url}&access_token=${token.replaceFirst('Bearer ', '')}'
        : '${info.url}?access_token=${token.replaceFirst('Bearer ', '')}';

    await player.loadSong(
      path: urlWithToken,
      title: item.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      artist: 'Google Drive',
      autoPlay: true,
    );

    if (context.mounted) {
      Navigator.pop(context);
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

    if (!mounted) return;
    setState(() => _downloadingId = null);

    if (path == null) {
      _showSnack('❌ Tải thất bại');
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
      _showSnack('✅ Đang phát: ${item.name}');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A237E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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

  Widget _buildSignInScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            Text(
              'Kết nối Drive để duyệt\nvà phát file âm thanh của bạn',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
            Text(
              'Chỉ đọc file — không chỉnh sửa hay xóa',
              style: TextStyle(color: Colors.grey[700], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

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
                  hintText: 'Tìm file âm thanh trên Drive...',
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
                ? 'Không tìm thấy file âm thanh'
                : 'Không có file âm thanh trong thư mục này',
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
              label: const Text('Quay lại'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Row(
        children: [
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
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
            onPressed: _loadItems,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
            onPressed: () async {
              await _driveService.signOut();
              if (mounted) {
                setState(() {
                  _items = [];
                  _searchCtrl.clear();
                });
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

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
                ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
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
                Icon(
                  item.isFolder
                      ? Icons.chevron_right
                      : Icons.play_circle_outline,
                  color: Colors.grey[600],
                  size: 18,
                ),
              ],
            ),
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
                'Đang tải ${(downloadProgress * 100).toInt()}%...',
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
            const Text(
              'Đăng nhập với Google',
              style: TextStyle(
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