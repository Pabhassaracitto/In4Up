// Language Reactor-style YouTube Explorer
// Trang 1 PDF: sidebar rank slider + sort + kênh, main: info kênh + video list

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'models/yt_channel.dart';
import 'models/yt_video.dart';
import 'widgets/yt_video_card.dart' show YtHistoryItem;
import 'services/yt_channel_store.dart';
import 'services/yt_coverage_service.dart';
import 'services/yt_initial_data_parser.dart';
import 'services/yt_search_service.dart';
import 'services/yt_service.dart';
import 'widgets/yt_my_channels_sheet.dart';
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

  // YT1-04: KHÔNG dựng câu tiếng Việt ở đây rồi mới bọc `uiText` — chuỗi có
  // nội suy không bao giờ khớp template nên locale ≠ vi vẫn ra tiếng Việt.
  // Trả SỐ + ĐƠN VỊ, câu hoàn chỉnh do UI ghép qua template `{value0}…`.

  /// `(số, hậu tố)` cho lượt xem — hậu tố `''`, `'K'`, `'M'`.
  (String, String) get viewCountParts {
    final v = viewCount ?? 0;
    if (v >= 1000000) return ((v / 1000000).toStringAsFixed(1), 'M');
    if (v >= 1000) return ((v / 1000).toStringAsFixed(0), 'K');
    return ('$v', '');
  }

  /// `(số, khoá đơn vị)` cho ngày đăng: `day` / `month` / `year` / `today`.
  (String, String) get dateParts {
    final p = publishedAt;
    if (p == null) return ('', '');
    final d = DateTime.now().difference(p);
    if (d.inDays > 365) return ('${d.inDays ~/ 365}', 'year');
    if (d.inDays > 30) return ('${d.inDays ~/ 30}', 'month');
    if (d.inDays > 0) return ('${d.inDays}', 'day');
    return ('', 'today');
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

  // YT-LEVEL-001 (#YT1-01): thanh trượt "Cấp độ từ vựng" CŨ là điều khiển giả
  // (`_rankMin/_rankMax` không được `_loadVideos` đọc, `langRank` không bao giờ
  // được gán). Nay lọc theo **độ phủ từ đã biết** đo từ phụ đề trên máy —
  // xem `YtCoverageService`. `null` = không lọc.
  YtCoverageBand? _bandFilter;

  /// Đang chạy "Phân tích cả trang" (tải phụ đề còn thiếu để đo).
  bool _analyzing = false;
  int _analyzeDone = 0;
  int _analyzeTotal = 0;

  /// YT1-02: kênh người dùng theo dõi (`YtChannelStore`) — hiện THÀNH MỤC RIÊNG
  /// **sau** danh sách gợi ý (quyết định của owner 2026-11-09).
  List<YtChannel> _myChannels = const [];

  /// YT1-03: chống "nuốt" truy vấn mới — mỗi lần tải tăng số này và bỏ kết quả
  /// của lần cũ về muộn.
  int _reqId = 0;
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _openingUrl = false;
  String? _urlError;

  // YT-LR-004 (IN4-94): tầng 2 thay tầng 1 cũ ⇒ phải giữ lại Lịch sử xem
  // (tầng 1 cũ có tab Lịch sử) để không mất tính năng.
  List<YtVideo> _history = const [];

  // ── Tìm kiếm không cần API key (gợi ý từ khoá + submit) ──
  final _searchFocus = FocusNode();
  Timer? _suggestDebounce;

  /// YT1-03 (phần gợi ý): cùng bệnh với `_loadVideos` — gõ nhanh thì phản hồi
  /// của chuỗi CŨ có thể về sau và đè lên gợi ý mới.
  int _suggestReq = 0;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  bool get _hasApiKey => YtVideo.isUsableDataApiKey(widget.apiKey);

  @override
  void initState() {
    super.initState();
    // IN4-77: mở YouTube → vào THẲNG tìm kiếm (ô tìm kiếm có focus,
    // con trỏ nhảy vào ô) thay vì phải cuộn/tap mới tìm được.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
    });
    _init();
    _loadHistory();
    // YT1-02 / YT1-01: nạp kênh theo dõi + số đo cấp độ đã lưu (đều là đọc đĩa,
    // không chạm mạng).
    _loadMyChannels();
    _loadCoverage();
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
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _suggestDebounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _channels
        ..clear()
        ..addAll(
            _kDefaultChannels.map((e) => YtExChannel(id: e.$1, title: e.$2)));
    });
    if (_hasApiKey) {
      await _enrichChannels();
    } else if (_channels.isNotEmpty) {
      // Không có key: chọn sẵn kênh đầu tiên để có nội dung xem ngay —
      // danh sách kênh và tìm kiếm đều chạy không cần key (YtSearchService).
      _selChannelId ??= _channels.first.id;
    }
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
    // YT1-03: KHÔNG `return` khi đang tải nữa — đổi kênh/gõ tìm kiếm trong lúc
    // tải trước đây bị nuốt im lặng. Nay lần gọi mới được chạy, và kết quả của
    // lần cũ (về muộn) bị bỏ theo `_reqId`.
    final req = ++_reqId;
    final query = _searchQuery.trim();
    // Chế độ không cần Data API key: search theo từ khoá hoặc xem kênh.
    final keylessSearch = query.isNotEmpty && !_hasApiKey;
    final keylessChannel =
        query.isEmpty && !_hasApiKey && _selChannelId != null;
    if (!_hasApiKey && !keylessSearch && !keylessChannel) {
      // Không key, không từ khoá, không chọn kênh → không có gì để tải
      if (reset && mounted) {
        setState(() {
          _videos.clear();
          _nextPageToken = null;
          _hasMore = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      if (reset) {
        _videos.clear();
        _nextPageToken = null;
      }
    });
    try {
      if (keylessSearch || keylessChannel) {
        // Keyless: một trang kết quả, không phân trang tiếp
        final hits = keylessSearch
            ? await YtSearchService.instance.searchVideos(query)
            : await YtSearchService.instance
                .fetchChannelVideos(_selChannelId!);
        // Bỏ kết quả của truy vấn đã bị thay thế.
        if (!mounted || req != _reqId) return;
        setState(() {
          _videos.addAll(hits.map(_hitToEx));
          _hasMore = false;
        });
        unawaited(_loadCoverage());
      } else {
        final (vids, next) = await _fetch(_nextPageToken);
        if (!mounted || req != _reqId) return;
        setState(() {
          _videos.addAll(vids);
          _nextPageToken = next;
          _hasMore = next != null;
        });
        unawaited(_loadCoverage());
      }
    } catch (e) {
      debugPrint('loadVideos: $e');
    } finally {
      if (mounted && req == _reqId) setState(() => _loading = false);
    }
  }

  // ── YT1-02: kênh người dùng theo dõi ─────────────────────────────────

  Future<void> _loadMyChannels() async {
    try {
      final list = await YtChannelStore.instance.load();
      if (!mounted) return;
      setState(() => _myChannels = list);
    } catch (e) {
      debugPrint('[in4up-yt] my channels load failed: $e');
    }
  }

  /// Tìm kênh theo id ở CẢ danh sách gợi ý lẫn kênh theo dõi — trước đây
  /// `_mainPanel` chỉ `firstWhere` trong `_channels` nên chọn kênh của tôi sẽ
  /// hiện nhầm header của kênh đầu tiên.
  YtExChannel? _channelById(String? id) {
    if (id == null) return null;
    for (final c in _channels) {
      if (c.id == id) return c;
    }
    for (final c in _myChannels) {
      if (c.id == id) {
        return YtExChannel(id: c.id, title: c.title);
      }
    }
    return null;
  }

  // ── YT1-01: cấp độ từ vựng = độ phủ từ đã biết ──────────────────────

  Future<void> _loadCoverage() async {
    await YtCoverageService.instance.ensureLoaded();
    if (!mounted) return;
    final missing = _videos
        .where((v) => YtCoverageService.instance.of(v.id) == null)
        .map((v) => v.id)
        .toList();
    if (missing.isEmpty) {
      setState(() {});
      return;
    }
    // Đo từ phụ đề ĐÃ CÓ trên máy — 0 byte mạng.
    await YtCoverageService.instance.primeLocalIndex();
    for (final id in missing) {
      await YtCoverageService.instance.analyzeLocal(id);
    }
    if (mounted) setState(() {});
  }

  /// Danh sách đang hiện sau khi áp bộ lọc cấp độ.
  List<YtExVideo> get _visibleVideos {
    final band = _bandFilter;
    if (band == null) return _videos;
    return _videos
        .where((v) =>
            (YtCoverageService.instance.of(v.id)?.band ??
                YtCoverageBand.unknown) ==
            band)
        .toList();
  }

  /// Tải phụ đề còn thiếu rồi đo — nút "Phân tích cả trang".
  ///
  /// Chi phí: ~20–60 KB mỗi video (chỉ phụ đề, KHÔNG tải audio). Hỏi trước để
  /// người dùng quyết định; phụ đề tải về được lưu vào kho media nên hiện trong
  /// "Thư viện đã tải" và xoá được (quyết định (c) của owner).
  Future<void> _analyzePage() async {
    if (_analyzing) return;
    final targets = _videos
        .where((v) => YtCoverageService.instance.of(v.id) == null)
        .toList();
    if (targets.isEmpty) {
      _snack(context.uiText('Cả trang đã có số đo cấp độ'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: Text(
          dctx.uiText('Phân tích cấp độ cả trang?'),
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: Text(
          dctx
              .uiText('Sẽ tải phụ đề của {value0} video (chỉ chữ, không tải âm thanh) '
                  '— khoảng {value1} KB, {value2} giây trên Wi-Fi.')
              .replaceAll('{value0}', '${targets.length}')
              .replaceAll('{value1}', '${(targets.length * 40).clamp(40, 4000)}')
              .replaceAll('{value2}', '${(targets.length * 2).clamp(2, 240)}'),
          style: TextStyle(color: Colors.grey[300], fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(dctx.uiText('Huỷ'),
                style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0)),
            child: Text(dctx.uiText('Bắt đầu')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _analyzing = true;
      _analyzeDone = 0;
      _analyzeTotal = targets.length;
    });
    for (final v in targets) {
      if (!mounted) return;
      await YtCoverageService.instance.analyzeByDownloading(v.id);
      if (!mounted) return;
      setState(() => _analyzeDone++);
    }
    if (!mounted) return;
    setState(() => _analyzing = false);
    final measured = targets
        .where((v) => YtCoverageService.instance.of(v.id) != null)
        .length;
    _snack(context
        .uiText('Đã đo cấp độ {value0}/{value1} video')
        .replaceAll('{value0}', '$measured')
        .replaceAll('{value1}', '${targets.length}'));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  YtExVideo _hitToEx(YtSearchHit h) => YtExVideo(
        id: h.id,
        title: h.title,
        channelId: h.channelId,
        channelTitle: h.channel,
        thumb: h.thumb,
        publishedAt: h.publishedAt,
        viewCount: h.viewCount,
        duration: h.duration,
      );

  Future<(List<YtExVideo>, String?)> _fetch(String? pageToken) async {
    if (!_hasApiKey) return (<YtExVideo>[], null);
    final order = _sortMode == YtSortMode.viewCount ? 'viewCount' : 'date';
    final chanParam = _selChannelId != null ? '&channelId=$_selChannelId' : '';
    final queryParam = _searchQuery.trim().isEmpty
        ? ''
        : '&q=${Uri.encodeQueryComponent(_searchQuery.trim())}';
    final url = '$_kYtApi/search?part=snippet&type=video$chanParam$queryParam&order=$order'
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
    // YT-ONE-BAR-001: chỉ còn MỘT ô cho cả URL và từ khoá.
    final input = (raw ?? _searchCtrl.text).trim();
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

  /// YT-AUDIT-07 (IN4-99): player ghi lịch sử khi mở (xem
  /// `YtPlayerScreen._recordHistory`), nên sau khi quay lại đây chỉ cần
  /// nạp lại danh sách — nếu không, danh sách Lịch sử vẫn là bản cũ đọc
  /// lúc `initState`.
  Future<void> _openVideo(YtExVideo v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => YtPlayerScreen(video: v)),
    );
    if (!mounted) return;
    await _loadHistory();
  }

  // ── Lịch sử xem (việc của tab Lịch sử ở tầng 1 cũ) ─────────

  Future<void> _loadHistory() async {
    await YtHistory.ensureOpen();
    if (!mounted) return;
    setState(() => _history = YtHistory.load());
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      context.uiText('Lịch sử'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                        child: Text(
                          context.uiText('Chưa có lịch sử'),
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: _history.length,
                        itemBuilder: (_, i) {
                          final v = _history[i];
                          return YtHistoryItem(
                            video: v,
                            onTap: () {
                              Navigator.pop(context);
                              _openVideo(
                                YtExVideo(
                                  id: v.id,
                                  title: v.title,
                                  channelId: '',
                                  channelTitle: v.channel,
                                  thumb: v.thumb,
                                ),
                              );
                            },
                            onDelete: () async {
                              await YtHistory.remove(v.id);
                              if (!mounted) return;
                              setState(() => _history = YtHistory.load());
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bộ lọc dạng bottom sheet (màn hẹp thay cho sidebar) ─────

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: _sidebarContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Thanh tìm kiếm (luôn hiện, chạy không cần Data API key) ──

  Widget _searchArea() => Column(
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  // YT-ONE-BAR-001: nói rõ MỘT ô làm được HAI việc — nếu chỉ
                  // ghi "Tìm kiếm" thì người dùng vẫn đi tìm ô dán URL như cũ.
                  hintText: context.uiText(
                      'Tìm bài, hoặc dán URL/ID YouTube vào đây...'),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.grey, size: 18),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.uiText('Dán từ bộ nhớ tạm'),
                        icon: const Icon(Icons.content_paste,
                            color: Colors.grey, size: 16),
                        onPressed: _pasteAndSubmit,
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          tooltip: context.uiText('Xoá tìm kiếm'),
                          icon: const Icon(Icons.close,
                              color: Colors.grey, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _submitSearch('');
                          },
                        ),
                    ],
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _submitSearch(),
                onTapOutside: (_) => setState(() => _showSuggestions = false),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: context.uiText('Tìm kiếm'),
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => _submitSearch(),
            ),
          ]),
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading:
                          const Icon(Icons.history, color: Colors.grey, size: 14),
                      title: Text(s,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                      onTap: () {
                        _searchCtrl.text = s;
                        _submitSearch(s);
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      );

  void _onSearchChanged(String v) {
    _suggestDebounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    // Gợi ý từ khoá của YouTube (keyless) — debounce 350ms
    final req = ++_suggestReq;
    _suggestDebounce = Timer(const Duration(milliseconds: 350), () async {
      final s = await YtSearchService.instance.getSuggestions(q);
      // Bỏ phản hồi của lần gõ trước (hoặc khi ô đã đổi nội dung).
      if (!mounted || req != _suggestReq) return;
      setState(() {
        _suggestions = s.take(6).toList();
        _showSuggestions = _suggestions.isNotEmpty && _searchFocus.hasFocus;
      });
    });
    // Cập nhật nút xoá (X) khi nội dung ô thay đổi
    setState(() {});
  }

  /// Dán clipboard vào ô duy nhất rồi chạy luôn — dùng cho cả URL và từ khoá
  /// nên người dùng không phải dán rồi bấm thêm lần nữa.
  Future<void> _pasteAndSubmit() async {
    final d = await Clipboard.getData('text/plain');
    final text = d?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    setState(() {
      _searchCtrl.text = text;
      _urlError = null;
    });
    _submitSearch(text);
  }

  /// YT-ONE-BAR-001 (#2 owner: "có 2 thanh, 1 tìm kiếm 1 dán URL — có cơ chế
  /// thông minh nào để dán URL vẫn được mà gõ tìm kiếm vẫn được không?")
  ///
  /// Có — và nên gộp thành MỘT ô. Không cần người dùng chọn chế độ trước:
  ///  • Nội dung nhận ra là URL / ID YouTube ⇒ mở thẳng video đó;
  ///  • Còn lại ⇒ tìm theo từ khoá như cũ.
  ///
  /// Ưu điểm so với 2 thanh: người dùng không phải "nhìn xem mình đang gõ vào
  /// ô nào"; dán từ clipboard xong Enter là chạy, dù dán URL hay tên bài.
  void _submitSearch([String? query]) {
    _suggestDebounce?.cancel();
    FocusScope.of(context).unfocus();
    final text = (query ?? _searchCtrl.text).trim();
    setState(() => _showSuggestions = false);

    // URL/ID YouTube ⇒ mở video. Kiểm trước để "youtube.com/..." không bị
    // đem đi tìm kiếm (kết quả sẽ là rác).
    final id = ytVideoIdFromSearchInput(text);
    if (id != null) {
      unawaited(_openFromUrl(text));
      return;
    }

    setState(() => _searchQuery = text);
    _loadVideos();
  }

  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        // YT-LR-004 (IN4-94): tầng 2 giờ là cửa vào YouTube DUY NHẤT từ icon
        // YouTube ⇒ phải dùng được trên điệnthoại đứng. Sidebar cố định 195px
        // sẽ ép vùng kết quả còn ~165px trên màn 360dp ⇒ khi hẹp, bỏ sidebar
        // và đưa bộ lọc vào bottom sheet (nút "Bộ lọc" trên thanh trên cùng).
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 560;
            return Column(
              children: [
                _topBar(isWide: isWide),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWide) _sidebar(),
                      if (isWide)
                        Container(
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.07)),
                      Expanded(child: _mainPanel()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar({required bool isWide}) => Container(
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
                // YT-MY-CHANNELS-001 (#1 owner 2026-10-28): "Kênh của tôi" —
                // theo dõi kênh bằng @handle/link hoặc import OPML, KHÔNG cần
                // đăng nhập Google. Đặt cạnh Lịch sử vì cùng là "chỗ quay lại".
                IconButton(
                  tooltip: context.uiText('Kênh của tôi'),
                  icon: const Icon(Icons.subscriptions_outlined,
                      color: Colors.grey, size: 18),
                  onPressed: () => showYtMyChannelsSheet(context),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // YT-LR-004: Lịch sử xem — việc của tab Lịch sử ở tầng 1 cũ.
                IconButton(
                  tooltip: context.uiText('Lịch sử'),
                  icon: const Icon(Icons.history, color: Colors.grey, size: 18),
                  onPressed: _showHistory,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // Màn hẹp: bộ lọc (cấp độ từ vựng / sắp xếp / kênh) xuống
                // bottom sheet thay vì chiếm ngang 195px.
                if (!isWide)
                  IconButton(
                    tooltip: context.uiText('Bộ lọc'),
                    icon: const Icon(Icons.tune, color: Colors.grey, size: 18),
                    onPressed: _showFilters,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                const SizedBox(width: 4),
                Text(
                  context.uiText(_hasApiKey ? 'Data API' : 'Không cần key'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _searchArea(),
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

  /// Bộ lọc (dùng cả ở sidebar rộng 195px lẫn bottom sheet khi màn hẹp).
  Widget _sidebar() => SizedBox(
        width: 195,
        child: _sidebarContent(),
      );

  Widget _sidebarContent() => Container(
        color: const Color(0xFF161B22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.uiText('Cấp độ từ vựng'),
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  // YT-LEVEL-001 (#YT1-01): bộ lọc THẬT theo độ phủ từ đã biết
                  // đo từ phụ đề trên máy (0 byte mạng). Trước đây là
                  // RangeSlider 0..100000 không nối với dữ liệu nào cả.
                  _bandFilterRow(),
                  const SizedBox(height: 6),
                  // Chi phí nói trước; phụ đề tải về nằm trong kho media nên
                  // hiện dung lượng và xoá được.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _analyzing
                              ? context
                                  .uiText('Đang đo {value0}/{value1} video')
                                  .replaceAll('{value0}', '$_analyzeDone')
                                  .replaceAll('{value1}', '$_analyzeTotal')
                              : context.uiText('Đo từ phụ đề trên máy (0 MB)'),
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 9),
                        ),
                      ),
                      SizedBox(
                        height: 26,
                        child: TextButton(
                          onPressed: _analyzing ? null : _analyzePage,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 26),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: const Color(0xFF53D6BD),
                          ),
                          child: Text(
                            _analyzing
                                ? context.uiText('Đang tải…')
                                : context.uiText('Phân tích cả trang'),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.uiText('Sắp xếp theo'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    _sortBtn(YtSortMode.date, Icons.calendar_today,
                        context.uiText('Ngày')),
                    const SizedBox(width: 6),
                    _sortBtn(YtSortMode.viewCount, Icons.visibility_outlined,
                        context.uiText('Lượt xem')),
                  ]),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Text(
                    context.uiText('Kênh'),
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
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
              context.uiText('Tất cả các kênh'),
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
            // Quyết định owner 2026-11-09: GỢI Ý trước, "Kênh của tôi" sau.
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                    child: Text(
                      context
                          .uiText('GỢI Ý: 1 - {value0}')
                          .replaceAll('{value0}', '${_channels.length}'),
                      style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 8,
                          letterSpacing: 0.4),
                    ),
                  ),
                  for (var i = 0; i < _channels.length; i++)
                    _chanTile(
                      _channels[i].id,
                      _channels[i].title,
                      _channels[i].thumb,
                      _channels[i].videoCount,
                      _selChannelId == _channels[i].id,
                      _channels[i].isPinned,
                      () {
                        setState(() => _selChannelId = _channels[i].id);
                        _loadVideos();
                      },
                      () => setState(() =>
                          _channels[i].isPinned = !_channels[i].isPinned),
                    ),
                  if (_myChannels.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                      child: Row(
                        children: [
                          Text(
                            context.uiText('Kênh của tôi'),
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              await showYtMyChannelsSheet(context);
                              if (!mounted) return;
                              await _loadMyChannels();
                              setState(() {});
                            },
                            child: Icon(Icons.tune,
                                color: Colors.grey[600], size: 14),
                          ),
                        ],
                      ),
                    ),
                    for (final c in _myChannels)
                      _chanTile(
                        c.id,
                        c.title,
                        null,
                        null,
                        _selChannelId == c.id,
                        false,
                        () {
                          setState(() => _selChannelId = c.id);
                          _loadVideos();
                        },
                        null,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  /// Hàng chip lọc theo nhóm cấp độ (đo từ phụ đề trên máy).
  Widget _bandFilterRow() {
    Widget chip(String label, YtCoverageBand? band) {
      final sel = _bandFilter == band;
      return Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: GestureDetector(
          onTap: () => setState(() => _bandFilter = band),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFF9C27B0).withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel
                    ? const Color(0xFF9C27B0)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: sel ? Colors.white : Colors.grey[400],
                fontSize: 10,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      children: [
        chip(context.uiText('Tất cả'), null),
        chip(context.uiText('Dễ ≥95%'), YtCoverageBand.easy),
        chip(context.uiText('Vừa 85–95%'), YtCoverageBand.fair),
        chip(context.uiText('Khó <85%'), YtCoverageBand.hard),
        chip(context.uiText('Chưa rõ'), YtCoverageBand.unknown),
      ],
    );
  }

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
                Text(context.uiText('$videoCount'),
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
    // YT1-02: kênh đang chọn có thể là kênh NGƯỜI DÙNG theo dõi (không nằm
    // trong danh sách gợi ý) ⇒ tra ở cả hai danh sách.
    final sel = _channelById(_selChannelId);
    final videos = _visibleVideos;
    return Column(
      children: [
        if (sel != null) _chanHeader(sel),
        Expanded(
          child: _loading && _videos.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF9C27B0))))
              : videos.isEmpty
                  ? (_videos.isNotEmpty && _bandFilter != null
                      // Có video nhưng bộ lọc cấp độ loại hết — phải nói rõ,
                      // không được hiện "chưa có video" chung chung.
                      ? _empty(msg: context.uiText(
                          'Không video nào khớp bộ lọc cấp độ. Chọn "Tất cả" để xem lại.'))
                      : _empty())
                  : ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: videos.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == videos.length) {
                          return const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)));
                        }
                        return _videoTile(videos[i]);
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
                    Text(_viewLabel(v),
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 11)),
                    Text(_dateLabel(v),
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 10)),
                    // YT1-08: nhãn trạng thái ngay trên thẻ (đã tải phụ đề /
                    // đã đo cấp độ). Người dùng biết video dùng được offline
                    // TRƯỚC khi bấm vào.
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        if (v.channelTitle.isNotEmpty)
                          _tag(v.channelTitle),
                        _coverageBadge(v),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// Nhãn cấp độ của video: `Đã biết 87%` (màu theo nhóm) hoặc `Chưa rõ`.
  Widget _coverageBadge(YtExVideo v) {
    final c = YtCoverageService.instance.of(v.id);
    if (c == null || c.tokens == 0) {
      return GestureDetector(
        onTap: () => _analyzeOne(v),
        child: _tag(context.uiText('Chưa rõ cấp độ · đo'), color: Colors.grey),
      );
    }
    final color = switch (c.band) {
      YtCoverageBand.easy => const Color(0xFF4CAF50),
      YtCoverageBand.fair => const Color(0xFFFF9800),
      YtCoverageBand.hard => const Color(0xFFF44336),
      YtCoverageBand.unknown => Colors.grey,
    };
    return _tag(
      context
          .uiText('Đã biết {value0}%')
          .replaceAll('{value0}', '${c.percent}'),
      color: color,
    );
  }

  Future<void> _analyzeOne(YtExVideo v) async {
    final c = await YtCoverageService.instance.analyzeByDownloading(v.id);
    if (!mounted) return;
    setState(() {});
    if (c == null) {
      _snack(context.uiText('Video này không có phụ đề để đo'));
    }
  }

  /// `1.2M lượt xem` — ghép từ template để dịch được.
  String _viewLabel(YtExVideo v) {
    final (num, unit) = v.viewCountParts;
    final key = switch (unit) {
      'M' => '{value0}M lượt xem',
      'K' => '{value0}K lượt xem',
      _ => '{value0} lượt xem',
    };
    return context.uiText(key).replaceAll('{value0}', num);
  }

  /// `3 ngày trước` / `Hôm nay` — cùng lý do.
  String _dateLabel(YtExVideo v) {
    final (num, unit) = v.dateParts;
    final key = switch (unit) {
      'day' => '{value0} ngày trước',
      'month' => '{value0} tháng trước',
      'year' => '{value0} năm trước',
      'today' => 'Hôm nay',
      _ => '',
    };
    if (key.isEmpty) return '';
    return context.uiText(key).replaceAll('{value0}', num);
  }

  Widget _empty({String? msg}) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 44, color: Colors.grey[700]),
            const SizedBox(height: 10),
            Text(
              msg ?? context.uiText('Tìm video ở thanh trên hoặc dán URL YouTube'),
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
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
                context.uiText(_hasApiKey
                    ? 'Không có video cho bộ lọc này.'
                    : 'Tìm kiếm và danh sách kênh chạy không cần Data API key — gõ từ khoá ở trên hoặc chọn kênh bên trái.'),
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
        title: Text(context.uiText('Thêm kênh'),
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
              child: Text(context.uiText('Huỷ'),
                  style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () async {
              final input = ctrl.text.trim();
              if (input.isEmpty) return;
              final id = input.contains('/channel/')
                  ? input.split('/channel/').last.split('/').first
                  : input;
              // YT1-02: kênh thêm tay cũng phải vào CÙNG một kho với "Kênh của
              // tôi" — trước đây chỉ nằm trong RAM của Explorer nên thoát màn
              // là mất, và không bao giờ thấy ở hộp "Kênh của tôi".
              try {
                await YtChannelStore.instance
                    .add(YtChannel(id: id, title: id));
              } catch (e) {
                debugPrint('[in4up-yt] add channel failed: $e');
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              await _loadMyChannels();
              if (!mounted) return;
              setState(() => _selChannelId = id);
              await _loadVideos();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000)),
            child: Text(context.uiText('Thêm')),
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

Widget _tag(String label, {VoidCallback? onTap, Color? color}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey)
              .withValues(alpha: color == null ? 0.07 : 0.18),
          borderRadius: BorderRadius.circular(4),
          border: color == null
              ? null
              : Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color ?? Colors.grey[400],
                fontSize: 10,
                fontWeight: color == null ? FontWeight.normal : FontWeight.w600)),
      ),
    );
