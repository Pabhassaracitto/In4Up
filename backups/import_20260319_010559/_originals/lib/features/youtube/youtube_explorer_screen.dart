//
// YouTube Explorer — Language Reactor style
// • Đăng nhập Google (OAuth2) → xem subscriptions
// • Hoặc dùng anonymous → tìm kiếm kênh/video học tiếng Anh
// • Filter theo cấp độ từ vựng (rank)
// • Sắp xếp: ngày / lượt xem
// • Danh sách kênh với số video tương ứng

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ── Config ────────────────────────────────────────────────
// YouTube Data API v3 — free quota: 10,000 units/day
// Key này chỉ dùng cho search + video list (không cần OAuth)
const _kYtApiBase = 'https://www.googleapis.com/youtube/v3';

// ── Models ────────────────────────────────────────────────

class YtChannel {
  final String id;
  final String title;
  final String? thumb;
  final int? videoCount;
  final int? subscriberCount;
  bool isPinned;

  YtChannel({
    required this.id,
    required this.title,
    this.thumb,
    this.videoCount,
    this.subscriberCount,
    this.isPinned = false,
  });
}

class YtExVideo {
  final String id;
  final String title;
  final String channelId;
  final String channelTitle;
  final String? thumb;
  final DateTime? publishedAt;
  final int? viewCount;
  final int? likeCount;
  final Duration? duration;

  YtExVideo({
    required this.id,
    required this.title,
    required this.channelId,
    required this.channelTitle,
    this.thumb,
    this.publishedAt,
    this.viewCount,
    this.likeCount,
    this.duration,
  });

  String get viewCountLabel {
    if (viewCount == null) return '';
    if (viewCount! >= 1000000) {
      return '${(viewCount! / 1000000).toStringAsFixed(1)}M lượt xem';
    }
    if (viewCount! >= 1000) {
      return '${(viewCount! / 1000).toStringAsFixed(0)}K lượt xem';
    }
    return '$viewCount lượt xem';
  }

  String get publishedLabel {
    if (publishedAt == null) return '';
    final diff = DateTime.now().difference(publishedAt!);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365} năm trước';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30} tháng trước';
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    return '${diff.inMinutes} phút trước';
  }
}

enum YtSortMode { date, viewCount }

// ── Rank ranges (like Language Reactor) ────────────────────
const _kRankRanges = [
  (label: 'Tất cả', min: 0, max: 100000),
  (label: 'Top 400', min: 0, max: 400),
  (label: '400–2500', min: 400, max: 2500),
  (label: '2500–7K', min: 2500, max: 7000),
  (label: '7K–15K', min: 7000, max: 15000),
  (label: '15K+', min: 15000, max: 100000),
];

// ── Default English learning channels ─────────────────────
const _kDefaultChannels = [
  ('UCVd9ExaFGD8VEmWDKDCMa2Q', 'Rachel\'s English'),
  ('UC7Gxz4kOFWNZcqQi7EFhPAA', 'Speak English With Vanessa'),
  ('UCNbngWUqL2eqXRnEF4mU8MA', 'English with Lucy'),
  ('UCo6iNXKMZqCFbo4xJqRuarQ', 'Steve Kaufmann - lingosteve'),
  ('UCsT0YIqwnpJCM-mx7-gSA4Q', 'TEDx Talks'),
  ('UCVHFbw7woebKtfvug_Nzpig', 'BBC Learning English'),
  ('UCHaHD477h-FeBbVh9Sh7syA', 'English Addict with Mr Steve'),
];

// ══════════════════════════════════════════════════════════
//  MAIN SCREEN
// ══════════════════════════════════════════════════════════

class YoutubeExplorerScreen extends StatefulWidget {
  /// YouTube Data API v3 key (set trong app settings)
  final String? apiKey;

  const YoutubeExplorerScreen({super.key, this.apiKey});

  @override
  State<YoutubeExplorerScreen> createState() => _YoutubeExplorerScreenState();
}

class _YoutubeExplorerScreenState extends State<YoutubeExplorerScreen>
    with SingleTickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────
  final List<YtChannel> _channels = [];
  final List<YtExVideo> _videos = [];
  String? _selectedChannelId; // null = all channels
  YtSortMode _sortMode = YtSortMode.date;
  int _rankMin = 0;
  int _rankMax = 100000;
  bool _loading = false;
  String? _error;
  String? _nextPageToken;
  bool _hasMore = false;

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDefaultChannels();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (_hasMore && !_loading) _loadMoreVideos();
    }
  }

  // ── Load channels ────────────────────────────────────────
  Future<void> _loadDefaultChannels() async {
    final channels =
        _kDefaultChannels.map((e) => YtChannel(id: e.$1, title: e.$2)).toList();

    setState(() {
      _channels.clear();
      _channels.addAll(channels);
    });

    // Load thumbnails + stats if API key available
    if (widget.apiKey != null) {
      await _enrichChannels();
    }

    await _fetchVideos();
  }

  Future<void> _enrichChannels() async {
    if (widget.apiKey == null) return;
    final ids = _channels.map((c) => c.id).join(',');
    try {
      final uri = Uri.parse(
          '$_kYtApiBase/channels?part=snippet,statistics&id=$ids&key=${widget.apiKey}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map;
      final items = (data['items'] as List?) ?? [];

      for (final item in items) {
        final id = item['id'] as String;
        final idx = _channels.indexWhere((c) => c.id == id);
        if (idx == -1) continue;

        final snippet = item['snippet'] as Map;
        final stats = item['statistics'] as Map?;
        final thumb =
            (snippet['thumbnails'] as Map?)?['default']?['url'] as String?;
        final subCount =
            int.tryParse(stats?['subscriberCount']?.toString() ?? '');
        final vidCount = int.tryParse(stats?['videoCount']?.toString() ?? '');

        setState(() {
          _channels[idx] = YtChannel(
            id: id,
            title: snippet['title'] as String? ?? _channels[idx].title,
            thumb: thumb,
            videoCount: vidCount,
            subscriberCount: subCount,
            isPinned: _channels[idx].isPinned,
          );
        });
      }
    } catch (e) {
      debugPrint('enrichChannels error: $e');
    }
  }

  // ── Fetch videos ─────────────────────────────────────────
  Future<void> _fetchVideos({bool reset = true}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _videos.clear();
        _nextPageToken = null;
      }
    });

    try {
      final newVideos = await _searchVideos(pageToken: _nextPageToken);
      setState(() {
        _videos.addAll(newVideos.videos);
        _nextPageToken = newVideos.nextPageToken;
        _hasMore = newVideos.nextPageToken != null;
      });
    } catch (e) {
      setState(() => _error = 'Lỗi tải video: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreVideos() => _fetchVideos(reset: false);

  Future<({List<YtExVideo> videos, String? nextPageToken})> _searchVideos(
      {String? pageToken}) async {
    // Nếu không có API key → dùng dữ liệu mẫu
    if (widget.apiKey == null || widget.apiKey!.isEmpty) {
      return (videos: _getMockVideos(), nextPageToken: null);
    }

    final order = _sortMode == YtSortMode.viewCount ? 'viewCount' : 'date';

    String query = _searchCtrl.text.trim().isNotEmpty
        ? _searchCtrl.text.trim()
        : 'english learning';

    // Nếu chọn kênh cụ thể
    final channelParam =
        _selectedChannelId != null ? '&channelId=$_selectedChannelId' : '';

    final params = StringBuffer('$_kYtApiBase/search?part=snippet&type=video'
        '&q=${Uri.encodeComponent(query)}'
        '$channelParam'
        '&order=$order'
        '&maxResults=20'
        '&relevanceLanguage=en'
        '&key=${widget.apiKey}');

    if (pageToken != null) {
      params.write('&pageToken=$pageToken');
    }

    final res = await http
        .get(Uri.parse(params.toString()))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('API error ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map;
    final items = (data['items'] as List?) ?? [];
    final nextToken = data['nextPageToken'] as String?;

    // Lấy video IDs để fetch details (viewCount, duration)
    final videoIds =
        items.map((i) => i['id']?['videoId'] as String?).whereType<String>();

    Map<String, Map> videoDetails = {};
    if (videoIds.isNotEmpty) {
      videoDetails = await _fetchVideoDetails(videoIds.toList());
    }

    final videos = items
        .where((i) => i['id']?['videoId'] != null)
        .map((i) {
          final vid = i['id']['videoId'] as String;
          final snippet = i['snippet'] as Map;
          final details = videoDetails[vid] ?? {};
          final stats = details['statistics'] as Map?;
          final contentDetails = details['contentDetails'] as Map?;

          return YtExVideo(
            id: vid,
            title: snippet['title'] as String? ?? '',
            channelId: snippet['channelId'] as String? ?? '',
            channelTitle: snippet['channelTitle'] as String? ?? '',
            thumb:
                (snippet['thumbnails'] as Map?)?['medium']?['url'] as String?,
            publishedAt:
                DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
            viewCount: int.tryParse(stats?['viewCount']?.toString() ?? ''),
            likeCount: int.tryParse(stats?['likeCount']?.toString() ?? ''),
            duration: _parseDuration(contentDetails?['duration'] as String?),
          );
        })
        .where((v) => _matchesRankFilter(v))
        .toList();

    return (videos: videos, nextPageToken: nextToken);
  }

  Future<Map<String, Map>> _fetchVideoDetails(List<String> ids) async {
    if (widget.apiKey == null) return {};
    try {
      final uri = Uri.parse('$_kYtApiBase/videos?part=statistics,contentDetails'
          '&id=${ids.join(',')}&key=${widget.apiKey}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {};

      final data = jsonDecode(res.body) as Map;
      final items = (data['items'] as List?) ?? [];
      return {
        for (final item in items) item['id'] as String: item as Map,
      };
    } catch (_) {
      return {};
    }
  }

  bool _matchesRankFilter(YtExVideo v) {
    if (_rankMin == 0 && _rankMax == 100000) return true;
    final vc = v.viewCount ?? 0;
    return vc >= _rankMin && vc < _rankMax;
  }

  Duration? _parseDuration(String? iso) {
    if (iso == null) return null;
    // PT1H23M45S
    final h = RegExp(r'(\d+)H').firstMatch(iso)?.group(1) ?? '0';
    final m = RegExp(r'(\d+)M').firstMatch(iso)?.group(1) ?? '0';
    final s = RegExp(r'(\d+)S').firstMatch(iso)?.group(1) ?? '0';
    return Duration(
      hours: int.parse(h),
      minutes: int.parse(m),
      seconds: int.parse(s),
    );
  }

  // ── Mock data (khi không có API key) ─────────────────────
  List<YtExVideo> _getMockVideos() {
    return [
      YtExVideo(
        id: 'demo1',
        title: 'Learn English: 10 Common Phrases',
        channelId: 'UCVd9ExaFGD8VEmWDKDCMa2Q',
        channelTitle: "Rachel's English",
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
        viewCount: 50000,
      ),
      YtExVideo(
        id: 'demo2',
        title: 'How to Sound like a Native Speaker',
        channelId: 'UCHaHD477h-FeBbVh9Sh7syA',
        channelTitle: 'English Addict',
        publishedAt: DateTime.now().subtract(const Duration(days: 12)),
        viewCount: 200000,
      ),
      YtExVideo(
        id: 'demo3',
        title: 'English Vocabulary: Advanced Words',
        channelId: 'UC7Gxz4kOFWNZcqQi7EFhPAA',
        channelTitle: 'Speak English With Vanessa',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
        viewCount: 8000,
      ),
    ];
  }

  // ── Open video in YouTube ────────────────────────────────
  void _openVideo(YtExVideo v) {
    final url = Uri.parse('https://www.youtube.com/watch?v=${v.id}');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // ── Left: Channel list ──────────────────────────
          _buildChannelSidebar(),

          // Divider
          Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),

          // ── Right: Video list ───────────────────────────
          Expanded(child: _buildVideoPanel()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1117),
      elevation: 0,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Row(
        children: [
          Icon(Icons.play_circle_fill, color: Color(0xFFFF0000), size: 22),
          SizedBox(width: 8),
          Text(
            'YouTube Explorer',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        // Sort toggle
        _SortChip(
          mode: _sortMode,
          onChanged: (m) {
            setState(() => _sortMode = m);
            _fetchVideos();
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: _buildRankFilter(),
      ),
    );
  }

  // ── Rank filter bar ──────────────────────────────────────
  Widget _buildRankFilter() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text('Cấp độ từ vựng:',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kRankRanges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final r = _kRankRanges[i];
                final selected = _rankMin == r.min && _rankMax == r.max;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _rankMin = r.min;
                      _rankMax = r.max;
                    });
                    _fetchVideos();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      r.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.grey[500],
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Channel sidebar ──────────────────────────────────────
  Widget _buildChannelSidebar() {
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Text('Kênh',
                    style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: _showAddChannelDialog,
                  child: Icon(Icons.add_circle_outline,
                      color: Colors.grey[600], size: 18),
                ),
              ],
            ),
          ),

          // All channels
          _ChannelRow(
            id: null,
            title: 'Tất cả các kênh',
            thumb: null,
            videoCount: _channels.fold(0, (s, c) => s! + (c.videoCount ?? 0)),
            isSelected: _selectedChannelId == null,
            isPinned: true,
            onTap: () {
              setState(() => _selectedChannelId = null);
              _fetchVideos();
            },
            onPin: null,
          ),

          const Divider(height: 1, color: Color(0xFF1A2235)),

          // ĐƯỢC KHUYẾN NGHỊ label
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'ĐƯỢC KHUYẾN NGHỊ: 1 - ${_channels.length}',
              style: TextStyle(
                  color: Colors.grey[700], fontSize: 9, letterSpacing: 0.5),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _channels.length,
              itemBuilder: (_, i) {
                final c = _channels[i];
                return _ChannelRow(
                  id: c.id,
                  title: c.title,
                  thumb: c.thumb,
                  videoCount: c.videoCount,
                  isSelected: _selectedChannelId == c.id,
                  isPinned: c.isPinned,
                  onTap: () {
                    setState(() => _selectedChannelId = c.id);
                    _fetchVideos();
                  },
                  onPin: () {
                    setState(() => _channels[i].isPinned = !c.isPinned);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Video panel ──────────────────────────────────────────
  Widget _buildVideoPanel() {
    return Column(
      children: [
        // Search bar
        _buildSearchBar(),

        // Videos
        Expanded(
          child: _loading && _videos.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                  ),
                )
              : _error != null
                  ? _buildError()
                  : _videos.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _videos.length + (_hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _videos.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Color(0xFF6C63FF)),
                                  ),
                                ),
                              );
                            }
                            return _VideoCard(
                              video: _videos[i],
                              onTap: () => _openVideo(_videos[i]),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm video...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.grey[600], size: 16),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onSubmitted: (_) => _fetchVideos(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _fetchVideos,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Tìm',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
          const SizedBox(height: 12),
          Text(_error ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 16),
          if (widget.apiKey == null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.key, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Text('Cần YouTube API Key',
                          style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vào console.cloud.google.com → tạo project → bật YouTube Data API v3 → tạo API key',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(
                          'https://console.cloud.google.com/apis/library/youtube.googleapis.com'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      '→ Mở Google Console',
                      style: const TextStyle(
                          color: Color(0xFF2196F3), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined, size: 52, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text('Không có video',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  void _showAddChannelDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Text('Thêm kênh YouTube',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Channel ID hoặc URL...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Huỷ', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () {
              final input = ctrl.text.trim();
              if (input.isNotEmpty) {
                // Extract channel ID from URL if needed
                final id = input.contains('youtube.com/channel/')
                    ? input.split('channel/').last.split('/').first
                    : input;
                setState(() {
                  _channels.add(YtChannel(id: id, title: id));
                });
                Navigator.pop(context);
                if (widget.apiKey != null) _enrichChannels();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000)),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS
// ══════════════════════════════════════════════════════════

class _ChannelRow extends StatelessWidget {
  final String? id;
  final String title;
  final String? thumb;
  final int? videoCount;
  final bool isSelected;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onPin;

  const _ChannelRow({
    required this.id,
    required this.title,
    required this.thumb,
    required this.videoCount,
    required this.isSelected,
    required this.isPinned,
    required this.onTap,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
              : Colors.transparent,
          border: isSelected
              ? const Border(
                  left: BorderSide(color: Color(0xFF6C63FF), width: 2))
              : null,
        ),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: thumb != null
                  ? Image.network(
                      thumb!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(title),
                    )
                  : _defaultAvatar(title),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (videoCount != null && videoCount! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$videoCount',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ),
            if (onPin != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onPin,
                child: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 14,
                  color: isPinned ? const Color(0xFF6C63FF) : Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String name) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _colorFromName(name),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _colorFromName(String name) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF5722),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}

class _VideoCard extends StatelessWidget {
  final YtExVideo video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 120,
                height: 68,
                child: video.thumb != null
                    ? Image.network(
                        video.thumb!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.channelTitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (video.viewCountLabel.isNotEmpty)
                        Text(
                          video.viewCountLabel,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 10),
                        ),
                      if (video.viewCountLabel.isNotEmpty &&
                          video.publishedLabel.isNotEmpty)
                        Text('  •  ',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 10)),
                      if (video.publishedLabel.isNotEmpty)
                        Text(
                          video.publishedLabel,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Open icon
            Icon(Icons.open_in_new, color: Colors.grey[700], size: 14),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.grey, size: 28),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final YtSortMode mode;
  final ValueChanged<YtSortMode> onChanged;

  const _SortChip({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(YtSortMode.date, Icons.calendar_today, 'Ngày'),
        const SizedBox(width: 6),
        _chip(YtSortMode.viewCount, Icons.visibility_outlined, 'Lượt xem'),
      ],
    );
  }

  Widget _chip(YtSortMode m, IconData icon, String label) {
    final selected = mode == m;
    return GestureDetector(
      onTap: () => onChanged(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[600],
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
