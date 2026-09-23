// lib/features/video/widgets/video_library_screen.dart
// VIDEO-ADD-001 — Màn hình thư viện video với chế độ quét (học theo thư viện
// nghe + đọc). Trước đây chỉ có danh sách rỗng + "Thêm video để bắt đầu học"
// mà KHÔNG CÓ nút thêm/quét anywhere.
//
// Thiết kế mới (copy khuôn AudioLibraryView):
//  - Permission gate: Android cần quyền READ_MEDIA_VIDEO (API 33+) hoặc
//    READ_EXTERNAL_STORAGE (≤ 32) — hiện nút "Cấp quyền" nếu chưa có.
//  - Search: trường tìm kiếm + indicator đang quét.
//  - Empty state: hướng dẫn 2 lựa chọn — quét toàn máy (MediaStore) hoặc
//    chọn file thủ công.
//  - RefreshIndicator: kéo để quét lại (dùng trong Mobile).
//  - Bottom sheet ở chế độ đã-quét: quét lại / chọn thư mục khác / bỏ
//    chọn thư mục (copy khuôn library_screen.dart _DeviceTab).
//  - FAB: thêm video thủ công (file_picker, mọi nền tảng).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/video_info.dart';
import '../services/video_library_service.dart';
import 'video_player_screen.dart';

/// Màn hình thư viện video
class VideoLibraryScreen extends StatefulWidget {
  /// False khi nhúng trong IndexedStack của shell (tab phụ "Xem"): khi đó
  /// không có route để pop — nút back sẽ pop nhầm route gốc gây đen màn hình
  /// (LISTEN-VIEW-001). True khi push như một route độc lập (quick actions).
  final bool showBackButton;

  const VideoLibraryScreen({super.key, this.showBackButton = true});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  bool _isLoading = true;
  bool _loadError = false;
  List<VideoInfo> _videos = [];
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    try {
      await VideoLibraryService.instance.ensureInitialized();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _videos = VideoLibraryService.instance.videos;
      _isLoading = false;
      _loadError = false;
    });
  }

  Future<void> _retryLoad() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });
    await _loadVideos();
  }

  // ─── Quét toàn máy (MediaStore) ────────────────────────────────────

  Future<void> _scanDevice() async {
    final svc = VideoLibraryService.instance;
    final granted = await Permission.videos.isGranted ||
        await Permission.storage.isGranted;
    if (!granted) {
      final req = await Permission.videos.request();
      if (!req.isGranted) {
        // Fallback cho Android ≤ 12.
        final storage = await Permission.storage.request();
        if (!storage.isGranted && mounted) {
          _showSnack(
            context.uiText('Cần cấp quyền để quét video'),
            icon: Icons.warning_amber,
            color: Colors.orange,
          );
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = true);
    final count = await svc.scanDevice(requirePermission: false);
    if (!mounted) return;
    setState(() {
      _videos = svc.videos;
      _isLoading = false;
    });
    _showSnack('${context.uiText('Đã tìm thấy')} $count ${context.uiText('video')}',
        icon: Icons.video_library, color: const Color(0xFF9C27B0));
  }

  // ─── Chọn thư mục (SAF tree) ──────────────────────────────────────

  Future<void> _pickFolder() async {
    if (!VideoLibraryService.instance.canScanDevice) {
      _showSnack(
        context.uiText('Chức năng này chỉ hỗ trợ trên Android'),
        icon: Icons.info_outline,
        color: Colors.orange,
      );
      return;
    }
    setState(() => _isLoading = true);
    final picked = await VideoLibraryService.instance.pickFolder();
    if (!mounted) return;
    setState(() {
      _videos = VideoLibraryService.instance.videos;
      _isLoading = false;
    });
    if (picked) {
      _showSnack(
        '${context.uiText('Đã quét thư mục')} (${VideoLibraryService.instance.count})',
        icon: Icons.folder_open,
        color: const Color(0xFF9C27B0),
      );
    }
  }

  Future<void> _scanFolder() async {
    setState(() => _isLoading = true);
    await VideoLibraryService.instance.scanFolder();
    if (!mounted) return;
    setState(() {
      _videos = VideoLibraryService.instance.videos;
      _isLoading = false;
    });
  }

  // ─── Chọn file thủ công (mọi nền tảng) ──────────────────────────────

  Future<void> _pickVideoFile() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
    } catch (e) {
      debugPrint('[VideoLibrary] pickFiles error: $e');
    }
    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;

    final picks = picked.files
        .where((f) => f.path != null)
        .map((f) => VideoPick(
              path: f.path!,
              name: f.name,
              originalUri: null,
            ))
        .toList();
    if (picks.isEmpty) return;

    setState(() => _isLoading = true);
    final added = await VideoLibraryService.instance.addPickedFiles(picks);
    if (!mounted) return;
    setState(() {
      _videos = VideoLibraryService.instance.videos;
      _isLoading = false;
    });
    _showSnack(
      added > 0
          ? '${context.uiText('Đã thêm')} $added ${context.uiText('video')} '
            '(${context.uiText('đã lưu vào bộ nhớ ứng dụng')})'
          : context.uiText('Video đã có trong thư viện'),
      icon: added > 0 ? Icons.check_circle : Icons.info_outline,
      color: added > 0 ? const Color(0xFF4CAF50) : Colors.orange,
    );
  }

  // ─── Bottom sheet (copy khuôn library_screen.dart _DeviceTab) ──────

  void _showFolderSheet() {
    final svc = VideoLibraryService.instance;
    final hasFolder = svc.hasFolder;
    final label = svc.folderLabel;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasFolder) ...[
                ListTile(
                  leading:
                      const Icon(Icons.refresh, color: Color(0xFF9C27B0)),
                  title: Text(context.uiText('Quét lại thư mục')),
                  subtitle: Text(label, maxLines: 1),
                  onTap: () {
                    Navigator.pop(ctx);
                    _scanFolder();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open,
                      color: Color(0xFF2196F3)),
                  title: Text(context.uiText('Chọn thư mục khác')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFolder();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_off,
                      color: Color(0xFFEF5350)),
                  title: Text(context.uiText('Bỏ chọn thư mục')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await svc.forgetFolder();
                    if (!mounted) return;
                    setState(() => _videos = svc.videos);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.phone_android,
                      color: Color(0xFF9C27B0)),
                  title: Text(context.uiText('Quét toàn bộ video trên máy')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _scanDevice();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open,
                      color: Color(0xFF2196F3)),
                  title: Text(context.uiText('Chọn thư mục video')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFolder();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message,
      {IconData icon = Icons.info, Color color = const Color(0xFF2196F3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────

  List<VideoInfo> get _filtered {
    if (_query.isEmpty) return _videos;
    return VideoLibraryService.instance.search(_query);
  }

  @override
  Widget build(BuildContext context) {
    final svc = VideoLibraryService.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(context.uiText('Video'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: widget.showBackButton
            ? IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Color(0xFF9C27B0)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (_videos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF9C27B0)),
              onPressed: () => _showSearchBar(),
              tooltip: context.uiText('Tìm kiếm'),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF9C27B0)),
            onPressed: _showFolderSheet,
            tooltip: context.uiText('Tùy chọn quét'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError
              ? _buildErrorState()
              : _videos.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: svc.hasFolder ? _scanFolder : _loadVideos,
                      child: Column(
                        children: [
                          if (_query.isNotEmpty) _buildSearchBar(),
                          if (svc.isScanning) _buildScanningBanner(),
                          Expanded(child: _buildVideoList()),
                        ],
                      ),
                    ),
      floatingActionButton: _videos.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF9C27B0),
              onPressed: _pickVideoFile,
              tooltip: context.uiText('Thêm video'),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // ─── Search bar (copy khuôn AudioLibraryView) ──────────────────────

  void _showSearchBar() {
    setState(() => _query = '');
    _searchController.clear();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A1A2E),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: context.uiText('Tìm kiếm…'),
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
            onPressed: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
          filled: true,
          fillColor: const Color(0xFF111827),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  Widget _buildScanningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF9C27B0)),
          ),
          const SizedBox(width: 10),
          Text(
            context.uiText('Đang quét…'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── States ─────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            context.uiText('Không tải được thư viện video'),
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _retryLoad,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(context.uiText('Thử lại')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              context.uiText('Chưa có video nào'),
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText('Thêm video để bắt đầu học'),
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickVideoFile,
                  icon: const Icon(Icons.file_open,
                      size: 18, color: Colors.white),
                  label: Text(context.uiText('Chọn file video'),
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (VideoLibraryService.instance.canScanDevice)
                  ElevatedButton.icon(
                    onPressed: _scanDevice,
                    icon: const Icon(Icons.phone_android,
                        size: 18, color: Colors.white),
                    label: Text(context.uiText('Quét video trên máy'),
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoList() {
    final list = _filtered;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final video = list[index];
        return _VideoCard(
          video: video,
          onTap: () async {
            final path =
                await VideoLibraryService.instance.resolvePlayablePath(video);
            if (!mounted) return;
            await VideoLibraryService.instance.markPlayed(video.id);
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(video: video),
              ),
            );
          },
          onDelete: () async {
            await VideoLibraryService.instance.removeVideo(video.id);
            if (!mounted) return;
            setState(() => _videos = VideoLibraryService.instance.videos);
          },
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _VideoCard({
    required this.video,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(video.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A2235),
            title: Text(context.uiText('Xóa video?'),
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: Text(video.title,
                style: const TextStyle(color: Colors.grey)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.uiText('Hủy')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF5350)),
                child: Text(context.uiText('Xóa'),
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 56,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF9C27B0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_circle_outline,
                    color: Color(0xFF9C27B0), size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          video.durationText.isNotEmpty
                              ? video.durationText
                              : video.sizeText,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                        if (video.source != VideoSource.picked) ...[
                          const SizedBox(width: 6),
                          Icon(
                            video.source == VideoSource.media
                                ? Icons.phone_android
                                : Icons.folder,
                            size: 12,
                            color: Colors.grey[700],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[700]),
            ],
          ),
        ),
      ),
    );
  }
}
