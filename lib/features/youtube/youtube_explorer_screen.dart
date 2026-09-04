// Language Reactor-style YouTube Explorer
// Trang 1 PDF: sidebar rank slider + sort + kênh, main: info kênh + video list

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'models/yt_video.dart';
import 'services/yt_service.dart';
import 'yt_player_screen.dart';

const _kYtApi = 'https://www.googleapis.com/youtube/v3';
const _kDefaultApiKey = '';

/// Giữ tên cũ cho test / chỗ gọi — uỷ quyền `YtVideo.isUsableDataApiKey`.
bool ytApiKeyIsUsable(String? key) => YtVideo.isUsableDataApiKey(key);

class YtExChannel {
  final String id;
  String title;
  final String? thumb;
  final String? description;
  final int? videoCount;
  bool isPinned;

  YtExChannel({
    required this.id,
    required this.title,
    this.thumb,
    this.description,
    this.videoCount,
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
  final Duration? duration;
  final int? langRank;

  YtExVideo({
    required this.id,
    required this.title,
    required this.channelId,
    required this.channelTitle,
    this.thumb,
    this.publishedAt,
    this.viewCount,
    this.duration,
    this.langRank,
  });

  String get viewLabel {
    final v = viewCount ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M lượt xem';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K lượt xem';
    return '$v lượt xem';
  }

  String get dateLabel {
    if (publishedAt == null) return '';
    final d = DateTime.now().difference(publishedAt!);
    if (d.inDays > 365) return '${d.inDays ~/ 365} năm trước';
    if (d.inDays > 30) return '${d.inDays ~/ 30} tháng trước';
    if (d.inDays > 0) return '${d.inDays} ngày trước';
    return 'Hôm nay';
  }

  String get durationLabel {
    if (duration == null) return '';
    final total = duration!.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }
}

enum YtSortMode { date, viewCount }

const _kDefaultChannels = [
  ('UCVd9ExaFGD8VEmWDKDCMa2Q', "Rachel's English"),
  ('UCo6iNXKMZqCFbo4xJqRuarQ', 'Steve Kaufmann'),
  ('UC7Gxz4kOFWNZcqQi7EFhPAA', 'Speak English With Vanessa'),
  ('UCNbngWUqL2eqXRnEF4mU8MA', 'English with Lucy'),
  ('UCHaHD477h-FeBbVh9Sh7syA', 'English Addict with Mr Steve'),
  ('UCVHFbw7woebKtfvug_Nzpig', 'BBC Learning English'),
  ('UCoHNRmS7dRNgkfY9m3R_GGQ', 'The Real Daytime'),
];

class YoutubeExplorerScreen extends StatefulWidget {
  final String apiKey;
  const YoutubeExplorerScreen({super.key, this.apiKey = _kDefaultApiKey});

  @override
  State<YoutubeExplorerScreen> createState() => _YoutubeExplorerScreenState();
}

class _YoutubeExplorerScreenState extends State<YoutubeExplorerScreen> {
  final List<YtExChannel> _channels = [];
  String? _selChannelId;
  final List<YtExVideo> _videos = [];
  bool _loading = false;
  String? _nextPageToken;
  bool _hasMore = false;
  YtSortMode _sortMode = YtSortMode.date;
  double _rankMin = 0;
  double _rankMax = 100000;
  final _scrollCtrl = ScrollController();
  final _urlCtrl = TextEditingController();
  bool _openingUrl = false;
  String? _urlError;

  bool get _hasApiKey => YtVideo.isUsableDataApiKey(widget.apiKey);

  @override
  void initState() {
    super.initState();
    _init();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 300 &&
          _hasMore &&
          !_loading) {
        _loadVideos(reset: false);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _channels
        ..clear()
        ..addAll(
            _kDefaultChannels.map((e) => YtExChannel(id: e.$1, title: e.$2)));
    });
    if (_hasApiKey) await _enrichChannels();
    await _loadVideos();
  }

  Future<void> _enrichChannels() async {
    if (!mounted) return;
    final ids = _channels.map((c) => c.id).join(',');
    try {
      final res = await http
          .get(Uri.parse(
              '$_kYtApi/channels?part=snippet,statistics&id=$ids&key=${widget.apiKey.trim()}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || !mounted) return;
      final data = jsonDecode(res.body) as Map;
      for (final item in (data['items'] as List? ?? [])) {
        final idx = _channels.indexWhere((c) => c.id == item['id'] as String);
        if (idx == -1) continue;
        final sn = item['snippet'] as Map;
        final st = (item['statistics'] as Map?) ?? {};
        final thumb = (sn['thumbnails'] as Map?)?['default']?['url'] as String?;
        setState(() {
          _channels[idx] = YtExChannel(
            id: _channels[idx].id,
            title: sn['title'] as String? ?? _channels[idx].title,
            thumb: thumb,
            description: sn['description'] as String?,
            videoCount: int.tryParse(st['videoCount']?.toString() ?? ''),
            isPinned: _channels[idx].isPinned,
          );
        });
      }
    } catch (e) {
      debugPrint('enrichChannels: $e');
    }
  }

  Future<void> _loadVideos({bool reset = true}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _videos.clear();
        _nextPageToken = null;
      }
    });
    try {
      final (vids, next) = await _fetch(_nextPageToken);
      if (!mounted) return;
      setState(() {
        _videos.addAll(vids);
        _nextPageToken = next;
        _hasMore = next != null;
      });
    } catch (e) {
      debugPrint('loadVideos: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<(List<YtExVideo>, String?)> _fetch(String? pageToken) async {
    if (!_hasApiKey) return (<YtExVideo>[], null);
    final order = _sortMode == YtSortMode.viewCount ? 'viewCount' : 'date';
    final chanParam = _selChannelId != null ? '&channelId=$_selChannelId' : '';
    final url = '$_kYtApi/search?part=snippet&type=video$chanParam&order=$order'
        '&maxResults=20&relevanceLanguage=en&key=${widget.apiKey.trim()}'
        '${pageToken != null ? '&pageToken=$pageToken' : ''}';
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return (<YtExVideo>[], null);
    final data = jsonDecode(res.body) as Map;
    final items = (data['items'] as List?) ?? [];
    final next = data['nextPageToken'] as String?;
    final ids = items
        .map((i) => i['id']?['videoId'] as String?)
        .whereType<String>()
        .toList();
    final details = ids.isNotEmpty ? await _fetchDetails(ids) : {};
    return (
      items.where((i) => i['id']?['videoId'] != null).map((i) {
        final vid = i['id']['videoId'] as String;
        final sn = i['snippet'] as Map;
        final det = details[vid] ?? {};
        final st = (det['statistics'] as Map?) ?? {};
        final cd = (det['contentDetails'] as Map?) ?? {};
        return YtExVideo(
          id: vid,
          title: sn['title'] as String? ?? '',
          channelId: sn['channelId'] as String? ?? '',
          channelTitle: sn['channelTitle'] as String? ?? '',
          thumb: (sn['thumbnails'] as Map?)?['medium']?['url'] as String?,
          publishedAt: DateTime.tryParse(sn['publishedAt'] as String? ?? ''),
          viewCount: int.tryParse(st['viewCount']?.toString() ?? ''),
          duration: _parseDur(cd['duration'] as String?),
        );
      }).toList(),
      next
    );
  }

  Future<Map<String, dynamic>> _fetchDetails(List<String> ids) async {
    try {
      final res = await http
          .get(Uri.parse(
              '$_kYtApi/videos?part=statistics,contentDetails&id=${ids.join(',')}&key=${widget.apiKey.trim()}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body) as Map;
      return {
        for (final i in (data['items'] as List? ?? [])) i['id'] as String: i
      };
    } catch (_) {
      return {};
    }
  }

  Duration? _parseDur(String? iso) {
    if (iso == null) return null;
    final h = RegExp(r'(\d+)H').firstMatch(iso)?.group(1) ?? '0';
    final m = RegExp(r'(\d+)M').firstMatch(iso)?.group(1) ?? '0';
    final s = RegExp(r'(\d+)S').firstMatch(iso)?.group(1) ?? '0';
    return Duration(
        hours: int.parse(h), minutes: int.parse(m), seconds: int.parse(s));
  }

  Future<void> _openFromUrl([String? raw]) async {
    final input = (raw ?? _urlCtrl.text).trim();
    if (input.isEmpty) return;
    final id = YtVideo.extractId(input);
    if (id == null) {
      setState(() => _urlError = 'URL không hợp lệ');
      return;
    }
    setState(() {
      _urlError = null;
      _openingUrl = true;
    });
    final info = await YtService.instance.fetchInfo(id);
    if (!mounted) return;
    setState(() => _openingUrl = false);
    _openVideo(YtExVideo(
      id: id,
      title: (info != null && info.title.isNotEmpty) ? info.title : id,
      channelId: '',
      channelTitle: info?.channel ?? '',
      thumb: info?.thumb,
    ));
  }

  void _openVideo(YtExVideo v) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => YtPlayerScreen(video: v)));

  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sidebar(),
                  Container(
                      width: 1, color: Colors.white.withValues(alpha: 0.07)),
                  Expanded(child: _mainPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        color: const Color(0xFF161B22),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.play_circle_filled,
                    color: Color(0xFFFF0000), size: 20),
                const SizedBox(width: 8),
                const Text('YouTube',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  _hasApiKey ? 'API' : 'Dán URL',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _urlError != null
                            ? Colors.red.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        const Icon(Icons.link, color: Colors.grey, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _urlCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: context.uiText('Dán URL YouTube...'),
                              hintStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => _openFromUrl(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_paste,
                              color: Colors.grey, size: 16),
                          onPressed: () async {
                            final d = await Clipboard.getData('text/plain');
                            if (d?.text != null) {
                              _urlCtrl.text = d!.text!.trim();
                              if (mounted) _openFromUrl();
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openingUrl ? null : _openFromUrl,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _openingUrl
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Icon(Icons.school,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            if (_urlError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_urlError!,
                      style:
                          const TextStyle(color: Colors.redAccent, fontSize: 11)),
                ),
              ),
          ],
        ),
      );

  Widget _sidebar() => Container(
        width: 195,
        color: const Color(0xFF161B22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cấp độ từ vựng',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                  RangeSlider(
                    values: RangeValues(_rankMin, _rankMax),
                    min: 0,
                    max: 100000,
                    divisions: 20,
                    activeColor: const Color(0xFF9C27B0),
                    inactiveColor: Colors.white.withValues(alpha: 0.12),
                    onChanged: (v) => setState(() {
                      _rankMin = v.start;
                      _rankMax = v.end;
                    }),
                    onChangeEnd: (_) => _loadVideos(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['0', '400', '2500', '100000']
                        .map((l) => Text(l,
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 8)))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text('Sắp xếp theo',
                      style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _sortBtn(YtSortMode.date, Icons.calendar_today, 'Ngày'),
                    const SizedBox(width: 6),
                    _sortBtn(YtSortMode.viewCount, Icons.visibility_outlined,
                        'Lượt xem'),
                  ]),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Text('Kênh',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showAddChannel,
                    child: Icon(Icons.add, color: Colors.grey[600], size: 16),
                  ),
                ],
              ),
            ),
            _chanTile(
              null,
              'Tất cả các kênh',
              null,
              null,
              _selChannelId == null,
              false,
              () {
                setState(() => _selChannelId = null);
                _loadVideos();
              },
              null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 2),
              child: Text(
                context.uiText('ĐƯỢC KHUYẾN NGHỊ: 1 - ${_channels.length}'),
                style: TextStyle(
                    color: Colors.grey[700], fontSize: 8, letterSpacing: 0.4),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _channels.length,
                itemBuilder: (_, i) {
                  final c = _channels[i];
                  return _chanTile(
                    c.id,
                    c.title,
                    c.thumb,
                    c.videoCount,
                    _selChannelId == c.id,
                    c.isPinned,
                    () {
                      setState(() => _selChannelId = c.id);
                      _loadVideos();
                    },
                    () => setState(() => _channels[i].isPinned = !c.isPinned),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _sortBtn(YtSortMode m, IconData icon, String label) {
    final sel = _sortMode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _sortMode = m);
          _loadVideos();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: sel
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: sel
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 10, color: sel ? Colors.white : Colors.grey[500]),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : Colors.grey[500],
                      fontSize: 10,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chanTile(
    String? id,
    String title,
    String? thumb,
    int? videoCount,
    bool isSelected,
    bool isPinned,
    VoidCallback onTap,
    VoidCallback? onPin,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.transparent,
            border: isSelected
                ? const Border(
                    left: BorderSide(color: Color(0xFF9C27B0), width: 2))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: thumb != null
                      ? Image.network(thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _av(title, 26))
                      : _av(title, 26),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (videoCount != null)
                Text('$videoCount',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10)),
              if (onPin != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onPin,
                  child: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 12,
                    color:
                        isPinned ? const Color(0xFF9C27B0) : Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _mainPanel() {
    final sel = _selChannelId != null
        ? _channels.firstWhere((c) => c.id == _selChannelId,
            orElse: () => _channels.first)
        : null;
    return Column(
      children: [
        if (sel != null) _chanHeader(sel),
        Expanded(
          child: _loading && _videos.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF9C27B0))))
              : _videos.isEmpty
                  ? _empty()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: _videos.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _videos.length) {
                          return const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)));
                        }
                        return _videoTile(_videos[i]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _chanHeader(YtExChannel c) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4CAF50), width: 2)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SizedBox(
                    width: 56,
                    height: 56,
                    child: c.thumb != null
                        ? Image.network(c.thumb!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _av(c.title, 56))
                        : _av(c.title, 56)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (c.videoCount != null) _tag('${c.videoCount} video'),
                    const SizedBox(width: 6),
                    _tag('YouTube ↗',
                        onTap: () => launchUrl(
                              Uri.parse(
                                  'https://www.youtube.com/channel/${c.id}'),
                              mode: LaunchMode.externalApplication,
                            )),
                  ]),
                  if (c.description != null) ...[
                    const SizedBox(height: 4),
                    Text(c.description!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _videoTile(YtExVideo v) => GestureDetector(
        onTap: () => _openVideo(v),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 130,
                    height: 73,
                    child: v.thumb != null
                        ? Image.network(v.thumb!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _thumbHolder())
                        : _thumbHolder(),
                  ),
                ),
                if (v.durationLabel.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(v.durationLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(context.uiText(v.viewLabel),
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 11)),
                    Text(context.uiText(v.dateLabel),
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 10)),
                    if (v.langRank != null) ...[
                      const SizedBox(height: 4),
                      _rankBar(v.langRank!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _rankBar(int rank) => Row(children: [
        SizedBox(
          width: 55,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (rank / 100000).clamp(0.01, 1.0),
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(Colors.grey[500]!),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text('#$rank', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
      ]);

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 44, color: Colors.grey[700]),
            const SizedBox(height: 10),
            Text(
              'Dán URL YouTube ở thanh trên',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.25)),
              ),
              child: Text(
                _hasApiKey
                    ? 'Không có video cho bộ lọc này.'
                    : 'Học video không cần Data API key. Khám phá kênh cần key thật — không dùng YOUR_KEY_HERE.',
                style: TextStyle(color: Colors.purple[100], fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );

  void _showAddChannel() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Text('Thêm kênh',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: context.uiText('Channel ID hoặc URL...'),
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
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
                final id = input.contains('/channel/')
                    ? input.split('/channel/').last.split('/').first
                    : input;
                setState(() => _channels.add(YtExChannel(id: id, title: id)));
                Navigator.pop(context);
                if (_hasApiKey) _enrichChannels();
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

// ── Helpers ───────────────────────────────────────────────
Widget _thumbHolder() => Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.grey, size: 26),
      ),
    );

Widget _av(String name, double size) => Container(
      color: _col(name),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.38,
              fontWeight: FontWeight.bold),
        ),
      ),
    );

Color _col(String n) {
  const cs = [
    Color(0xFF6C63FF),
    Color(0xFFFF5722),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
  ];
  return cs[n.hashCode.abs() % cs.length];
}

Widget _tag(String label, {VoidCallback? onTap}) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ),
    );
