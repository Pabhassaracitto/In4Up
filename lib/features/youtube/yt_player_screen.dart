//
// Language Reactor-style video player:
// • Trái: YouTube iframe + subtitle lớn + dịch
// • Phải: Tab VĂN BẢN (transcript song ngữ) | TỪ (word analysis)
// • Click từ → popup nghĩa (động từ, danh từ...)
// • Nút ✓ Known | 📖 Learning
// • Tab TỪ: Known 36 / Learning 3 / Ignored 7, rank filter

import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../features/translation/translation_service.dart';
import '../../models/vocab_context.dart';
import '../../models/word_analysis.dart';
import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import '../../providers/vocabulary_bridge.dart';
import '../../services/syntax_highlighter_service.dart';
import '../word_lookup/word_analysis_sheet.dart';
import 'models/yt_video.dart';
import 'services/yt_service.dart';
import 'youtube_explorer_screen.dart';

// ─── Word knowledge state ─────────────────────────────────
enum WordState { unknown, known, learning, ignored }

class LrWord {
  final String text;
  final String type; // noun, verb, adj, adv, prep, conj, other
  final int langRank;
  WordState state;

  LrWord({
    required this.text,
    required this.type,
    required this.langRank,
    this.state = WordState.unknown,
  });

  Color get typeColor {
    switch (type) {
      case 'verb':
        return const Color(0xFF4CAF50); // xanh lá
      case 'noun':
        return const Color(0xFFFF9800); // cam
      case 'proper':
        return const Color(0xFF9C27B0); // tím
      case 'adj':
        return const Color(0xFF2196F3); // xanh
      case 'adv':
        return const Color(0xFFFFCA28); // vàng
      case 'prep':
      case 'conj':
        return const Color(0xFF78909C); // xám
      default:
        return Colors.white;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'verb':
        return 'động từ';
      case 'noun':
        return 'danh từ';
      case 'proper':
        return 'tên riêng';
      case 'adj':
        return 'tính từ';
      case 'adv':
        return 'trạng từ';
      case 'prep':
        return 'giới từ';
      case 'conj':
        return 'liên từ';
      default:
        return 'từ';
    }
  }
}

// ─── Embed wrapper (IN4-78 — YouTube error 153) ─────────────
// Hàm top-level (không phụ thuộc widget) để test thuần bắt được.

/// Base URL cho wrapper page nhúng YouTube.
///
/// WebView load wrapper bằng `loadHtml(html, baseUrl:)` (Android:
/// `loadDataWithBaseURL`) → request iframe player mang Referer = base này.
/// YouTube (từ ~10/2025) bắt buộc Referer hợp lệ cho video nhúng; load
/// thẳng `youtube.com/embed/...` không có Referer → "mã 153".
const Uri kYtEmbedBase = Uri.parse('https://in4up.app/embed');

/// Wrapper page chứa YouTube IFrame API trên host
/// `youtube-nocookie.com` (domain nhúng chuẩn, ít cookie) + meta referrer
/// phòng khi nền tảng WebView bỏ qua base URL.
String buildYtEmbedHtml(String videoId) {
  // videoId đến từ ID video của YouTube (A-Za-z0-9_-) — an toàn khi nhúng
  // vào JS string không nháy kép dưới đây; vẫn escape phòng thủ.
  final id = videoId.replaceAll('"', '');
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html,body{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden}
  #yt{position:fixed;inset:0;width:100%;height:100%}
  #yt iframe{width:100% !important;height:100% !important}
</style>
</head>
<body>
<div id="yt"></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
(function() {
  var VIDEO_ID = "$id";
  function post(msg) {
    try { if (window.YtSync) YtSync.postMessage(msg); } catch (e) {}
  }
  window._in4upSeek = function(s) {
    try { window.player.seekTo(s, true); } catch (e) {}
  };
  window._in4upPause = function() {
    try { window.player.pauseVideo(); } catch (e) {}
  };
  window._in4upPlay = function() {
    try { window.player.playVideo(); } catch (e) {}
  };
  function tick() {
    try {
      if (window.player && window.player.getCurrentTime) {
        post('t:' + window.player.getCurrentTime().toFixed(3));
      }
    } catch (e) {}
  }
  window.onYouTubeIframeAPIReady = function() {
    try {
      window.player = new YT.Player('yt', {
        width: '100%',
        height: '100%',
        videoId: VIDEO_ID,
        host: 'https://www.youtube-nocookie.com',
        // cc_load_policy: 0 — giữ hành vi cũ: không tải CC của player (app
        // có hệ thống phụ đề riêng; tránh phụ đề chồng 2 lớp).
        playerVars: { rel: 0, playsinline: 1, cc_load_policy: 0 },
        events: {
          onReady: function() {
            post('ready');
            try { window.player.playVideo(); } catch (e) {}
            setInterval(tick, 250);
          },
          onStateChange: function(e) { post('state:' + e.data); },
          onError: function(e) { post('err:' + e.data); }
        }
      });
    } catch (e) { post('err:-1'); }
  };
})();
</script>
</body>
</html>
''';
}

/// Mô tả tiếng Việt theo mã lỗi IFrame API của YouTube
/// (https://developers.google.com/youtube/iframe_api_reference#Error_Codes).
String describeYtPlayerError(String code) {
  switch (code) {
    case '2':
      return 'Video không phát được (tham số không hợp lệ).';
    case '5':
      return 'Video không phát được bằng trình phát HTML5 của thiết bị này.';
    case '100':
    case '120':
      return 'Không tìm thấy video — có thể video riêng tư hoặc đã bị xóa.';
    case '101':
    case '150':
      return 'Chủ video không cho phép phát ở trình nhúng.';
    case '153':
      return 'YouTube từ chối phát do chính sách referrer (mã 153). Bấm Thử lại — nếu vẫn lỗi, kiểm tra mạng/VPN.';
    case '-1':
      return 'Không khởi tạo được trình phát YouTube (lỗi nội bộ).';
    default:
      return 'Lỗi trình phát YouTube (mã $code).';
  }
}

/// Parse tin vị trí phát từ wrapper page: `t:<seconds>` → giây (null nếu
/// không phải tin thời gian hoặc không parse được).
double? ytParseTimeMessage(String message) {
  if (!message.startsWith('t:')) return null;
  return double.tryParse(message.substring(2));
}

// ─── Subtitle line ────────────────────────────────────────
class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;
  final String? translation;
  final List<LrWord> words;

  SubtitleLine({
    required this.start,
    required this.end,
    required this.text,
    this.translation,
    required this.words,
  });
}

// ══════════════════════════════════════════════════════════
//  YT PLAYER SCREEN
// ══════════════════════════════════════════════════════════
class YtPlayerScreen extends StatefulWidget {
  final YtExVideo video;
  final String? audioPath;
  const YtPlayerScreen({super.key, required this.video, this.audioPath});

  @override
  State<YtPlayerScreen> createState() => _YtPlayerScreenState();
}

class _YtPlayerScreenState extends State<YtPlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late WebViewController _ytCtrl;
  bool _isLoading = true;

  /// Lỗi trình phát YouTube (mã IFrame API) — null = không lỗi.
  /// IN4-78: YouTube yêu cầu Referer hợp lệ cho video nhúng (thay đổi chính
  /// sách ~10/2025) → WebView không có base URL bị trả mã 153. Sửa: load
  /// wrapper page bằng `loadHtml(baseUrl:)` (tạo Referer) + host
  /// `youtube-nocookie.com` + meta referrer.
  String? _playerError;

  // ── Subtitle state ────────────────────────────────────────
  final List<SubtitleLine> _lines = [];
  int _currentLineIdx = 0;
  double _currentTime = 0;

  // ── Word knowledge ────────────────────────────────────────
  final Map<String, WordState> _wordStates = {};
  bool _looping = false;
  static const _kWordBox = 'yt_lr_word_states';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _initWebView();
    unawaited(_loadWordStates());
    unawaited(_loadRealSubtitles());
    // (IN4-78) Không còn timer Dart đọc vị trí: wrapper page tự post
    // 't:<seconds>' mỗi 250ms qua kênh YtSync (IFrame API getCurrentTime).
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _embedHtml() => buildYtEmbedHtml(widget.video.id);

  void _initWebView() {
    _ytCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint('[in4up-yt] page finished: $url');
          },
        ),
      )
      ..addJavaScriptChannel(
        'YtSync',
        onMessageReceived: (msg) {
          _handlePlayerMessage(msg.message);
        },
      )
      ..loadHtml(_embedHtml(), baseUrl: kYtEmbedBase);
  }

  void _reloadPlayer() {
    debugPrint('[in4up-yt] reload player');
    setState(() => _playerError = null);
    _ytCtrl.loadHtml(_embedHtml(), baseUrl: kYtEmbedBase);
  }

  /// Tin từ wrapper page: `t:<s>` (vị trí phát), `ready`, `state:<n>`,
  /// `err:<mã>` (lỗi IFrame API: 2/5/100/101/120/150/153/200...).
  void _handlePlayerMessage(String m) {
    if (!mounted) return;
    final time = ytParseTimeMessage(m);
    if (time != null) {
      _updateTime(time);
      return;
    }
    if (m.startsWith('err:')) {
      final code = m.substring(4).trim();
      debugPrint('[in4up-yt] player error code=$code');
      if (_playerError == null) {
        // Báo lần đầu; lần sau (nếu user bấm Thử lại rồi vẫn lỗi) giữ nguyên.
        setState(() => _playerError = describeYtPlayerError(code));
      }
    }
  }

  void _updateTime(double time) {
    if (!mounted) return;
    if (_looping && _lines.isNotEmpty) {
      final line = _lines[_currentLineIdx.clamp(0, _lines.length - 1)];
      if (time * 1000 >= line.end.inMilliseconds - 60) {
        _seekTo(line.start.inMilliseconds / 1000.0);
        return;
      }
    }
    final ms = (time * 1000).round();
    var idx = _currentLineIdx;
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (ms >= l.start.inMilliseconds && ms < l.end.inMilliseconds) {
        idx = i;
        break;
      }
      if (ms >= l.start.inMilliseconds) idx = i;
    }
    if (idx != _currentLineIdx || (time - _currentTime).abs() > 0.45) {
      setState(() {
        _currentTime = time;
        _currentLineIdx = idx;
      });
    } else {
      _currentTime = time;
    }
  }

  Future<void> _loadWordStates() async {
    try {
      if (!Hive.isBoxOpen(_kWordBox)) {
        await Hive.openBox<String>(_kWordBox);
      }
      final raw = Hive.box<String>(_kWordBox).get('map');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        final k = key.toString().toLowerCase();
        final label = value.toString();
        if (label == 'known') {
          _wordStates[k] = WordState.known;
        } else if (label == 'learning') {
          _wordStates[k] = WordState.learning;
        } else if (label == 'ignored') {
          _wordStates[k] = WordState.ignored;
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('yt_lr load word states: $e');
    }
  }

  Future<void> _persistWordStates() async {
    try {
      if (!Hive.isBoxOpen(_kWordBox)) {
        await Hive.openBox<String>(_kWordBox);
      }
      final map = <String, String>{};
      _wordStates.forEach((k, v) {
        if (v != WordState.unknown) map[k] = v.name;
      });
      await Hive.box<String>(_kWordBox).put('map', jsonEncode(map));
    } catch (e) {
      debugPrint('yt_lr persist word states: $e');
    }
  }

  Future<void> _loadRealSubtitles() async {
    setState(() => _isLoading = true);
    try {
      final target = TranslationService().targetLang.toLowerCase();
      final lang2 = target.isEmpty || target == 'en' ? 'vi' : target;
      final captions = await YtService.instance.fetchBilingualCaptions(
        widget.video.id,
        lang1: 'en',
        lang2: lang2,
      );

      if (!mounted) return;

      setState(() {
        _lines.clear();
        for (final c in captions) {
          _lines.add(SubtitleLine(
            start: c.start,
            end: c.end,
            text: c.text,
            translation: c.translation,
            words: _parseWords(c.text),
          ));
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load subtitles error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LrWord> _parseWords(String text) {
    final analyzed = SyntaxHighlighterService.analyzeLine(text);
    final words = <LrWord>[];
    var rank = 100;
    for (final w in analyzed) {
      final token = w.originalWord.trim();
      if (token.isEmpty) continue;
      if (w.wordType == WordType.punctuation) continue;
      final lower = token.toLowerCase();
      final type = switch (w.wordType) {
        WordType.verb => 'verb',
        WordType.noun => 'noun',
        WordType.adjective => 'adj',
        WordType.adverb => 'adv',
        WordType.preposition => 'prep',
        WordType.conjunction => 'conj',
        _ => 'other',
      };
      var state = _wordStates[lower] ?? WordState.unknown;
      if (state == WordState.unknown && VocabularyBridge.hasWord(lower)) {
        state = WordState.learning;
      }
      words.add(LrWord(
        text: token,
        type: type,
        langRank: rank,
        state: state,
      ));
      rank += 40;
    }
    return words;
  }

  // ─── Word actions ─────────────────────────────────────────
  void _setWordState(String word, WordState state) {
    final lower = word.toLowerCase();
    setState(() {
      _wordStates[lower] = state;
      for (final line in _lines) {
        for (final w in line.words) {
          if (w.text.toLowerCase() == lower) {
            w.state = state;
          }
        }
      }
    });
    unawaited(_persistWordStates());
    if (state == WordState.learning) {
      final line = _lines.isEmpty
          ? null
          : _lines[_currentLineIdx.clamp(0, _lines.length - 1)];
      VocabularyBridge.addContextual(
        text: word,
        example: line?.text,
        context: VocabContext.fromStory(
          storyTitle: widget.video.title,
          lineIndex: _currentLineIdx,
          surroundingText: line?.text ?? word,
          sourceRef: 'youtube:${widget.video.id}',
          sourceRefType: 'youtube',
          anchorText: word,
          textStartOffset: line?.start.inMilliseconds,
          textEndOffset: line?.end.inMilliseconds,
        ),
        language: 'en',
        topic: 'YouTube',
      );
    }
  }

  int get _knownCount =>
      _wordStates.values.where((s) => s == WordState.known).length;
  int get _learningCount =>
      _wordStates.values.where((s) => s == WordState.learning).length;
  int get _ignoredCount =>
      _wordStates.values.where((s) => s == WordState.ignored).length;

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: isLandscape ? _buildLandscape() : _buildPortrait(),
      ),
    );
  }

  Widget _buildPortrait() {
    return Column(
      children: [
        // Title Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF161B22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Học trong tab Nghe',
                icon: Icon(
                  Icons.headphones,
                  color: widget.audioPath == null
                      ? Colors.white24
                      : const Color(0xFF4CAF50),
                  size: 20,
                ),
                onPressed: _openInListen,
              ),
            ],
          ),
        ),
        // Video player
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildVideoPlayer(),
        ),
        // Subtitle
        _buildSubtitleArea(),
        // Tabs
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildLandscape() {
    return Column(
      children: [
        // Title Bar (Compact)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: const Color(0xFF161B22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.video.title,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Left: video + subtitle
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Expanded(child: _buildVideoPlayer()),
                    _buildSubtitleArea(),
                  ],
                ),
              ),
              // Right: tabs
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildTabBar(),
                    Expanded(child: _buildTabContent()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Video Player ──────────────────────────────────────────
  Widget _buildVideoPlayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _ytCtrl),
        if (_playerError != null)
          Container(
            color: const Color(0xCC000000),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                const SizedBox(height: 10),
                Text(
                  _playerError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _reloadPlayer,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Subtitle area ─────────────────────────────────────────
  Widget _buildSubtitleArea() {
    if (_isLoading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_lines.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child:
            const Text('Không có phụ đề', style: TextStyle(color: Colors.grey)),
      );
    }
    final line = _lines[_currentLineIdx.clamp(0, _lines.length - 1)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action buttons row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              _ActionBtn(
                icon: Icons.check,
                label: 'Biết hết',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  for (final w in line.words) {
                    _setWordState(w.text, WordState.known);
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.menu_book,
                label: 'Học cả câu',
                color: const Color(0xFF9C27B0),
                onTap: () {
                  for (final w in line.words) {
                    if (w.state == WordState.unknown) {
                      _setWordState(w.text, WordState.learning);
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: _looping ? Icons.repeat_on : Icons.repeat,
                label: _looping ? 'Lặp câu' : 'Lặp câu',
                color: _looping
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF607D8B),
                onTap: () {
                  setState(() => _looping = !_looping);
                  if (_looping) {
                    _seekTo(line.start.inMilliseconds / 1000.0);
                  }
                },
              ),
              const Spacer(),
              // Navigation
              Row(children: [
                _navBtn(
                  Icons.replay_10,
                  () => _seekTo(_currentTime - 10),
                ),
                const SizedBox(width: 10),
                _navBtn(
                  Icons.skip_previous,
                  () {
                    if (_currentLineIdx > 0) {
                      _seekTo(_lines[_currentLineIdx - 1].start.inMilliseconds /
                          1000);
                    }
                  },
                ),
                const SizedBox(width: 10),
                _navBtn(
                  Icons.skip_next,
                  () {
                    if (_currentLineIdx < _lines.length - 1) {
                      _seekTo(_lines[_currentLineIdx + 1].start.inMilliseconds /
                          1000);
                    }
                  },
                ),
              ]),
            ],
          ),
          ),
          const SizedBox(height: 12),
          // Colored words subtitle
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: line.words
                .map((w) => _WordChip(
                      word: w,
                      onTap: () => _showWordPopup(w),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          // Translation
          if (line.translation != null)
            Text(
              line.translation!,
              style: TextStyle(
                color: Colors.amber.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: Colors.grey[400], size: 20),
      ),
    );
  }

  void _seekTo(double seconds) {
    if (seconds < 0) seconds = 0;
    _ytCtrl.runJavaScript('window._in4upSeek && window._in4upSeek($seconds);');
  }

  void _pauseVideo() {
    _ytCtrl.runJavaScript('window._in4upPause && window._in4upPause();');
  }

  Future<void> _openInListen() async {
    final audio = widget.audioPath;
    if (audio == null || audio.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText(
            'Tải audio ở YouTube → tab Audio, rồi mở lại Học video.',
          )),
        ),
      );
      return;
    }
    final asYt = YtVideo(
      id: widget.video.id,
      title: widget.video.title,
      channel: widget.video.channelTitle,
      thumb: widget.video.thumb,
    );
    final captions = _lines
        .map((l) => YtCaptionLine(l.start, l.end, l.text,
            translation: l.translation))
        .toList();
    final lrcPath = captions.isEmpty
        ? null
        : await YtService.instance.saveLrc(captions, asYt);
    if (!mounted) return;
    await context.read<PlayerProvider>().loadSong(
          path: audio,
          title: widget.video.title,
          artist: widget.video.channelTitle,
          autoPlay: true,
        );
    if (lrcPath != null && mounted) {
      await context.read<TextProvider>().loadTextFile(lrcPath);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showWordPopup(LrWord word) {
    _pauseVideo();
    String? contextSentence;
    if (_lines.isNotEmpty && _currentLineIdx < _lines.length) {
      contextSentence = _lines[_currentLineIdx].text;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordAnalysisSheet(
        selectedWord: word.text,
        sentenceContext: contextSentence,
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          // Toggle sidebar arrow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ),
          // Tabs
          Expanded(
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: false,
              indicatorColor: const Color(0xFF9C27B0),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: context.uiText('VĂN BẢN')),
                Tab(text: context.uiText('TỪ')),
              ],
            ),
          ),
          // Search icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.search, color: Colors.grey[600], size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildTranscriptTab(),
        _buildWordTab(),
      ],
    );
  }

  // ── Transcript tab ────────────────────────────────────────
  Widget _buildTranscriptTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _lines.length,
      itemBuilder: (_, i) {
        final line = _lines[i];
        final isActive = i == _currentLineIdx;
        return GestureDetector(
          onTap: () {
            setState(() => _currentLineIdx = i);
            _seekTo(line.start.inMilliseconds / 1000.0);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              border: Border(
                  left: BorderSide(
                      color: isActive
                          ? const Color(0xFF9C27B0)
                          : Colors.transparent,
                      width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9C27B0),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Colored words
                      Wrap(
                        spacing: 3,
                        runSpacing: 2,
                        children: line.words
                            .map((w) => GestureDetector(
                                  onTap: () => _showWordPopup(w),
                                  child: Text(
                                    '${w.text} ',
                                    style: TextStyle(
                                      color: w.type == 'other'
                                          ? Colors.white
                                          : w.typeColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 3),
                      // Translation
                      if (line.translation != null)
                        Text(
                          line.translation!,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Word tab ──────────────────────────────────────────────
  Widget _buildWordTab() {
    // Collect all unique words from all lines
    final allWords = <String, LrWord>{};
    for (final line in _lines) {
      for (final w in line.words) {
        final key = w.text.toLowerCase();
        allWords.putIfAbsent(key, () => w);
      }
    }

    // Count per word
    final countMap = <String, int>{};
    for (final line in _lines) {
      for (final w in line.words) {
        countMap[w.text.toLowerCase()] =
            (countMap[w.text.toLowerCase()] ?? 0) + 1;
      }
    }

    // Group by rank
    final total = allWords.length;
    final known = _knownCount;
    final learning = _learningCount;
    final ignored = _ignoredCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          _WordStatsRow(
            known: known,
            learning: learning,
            ignored: ignored,
            total: total,
          ),
          const SizedBox(height: 12),

          // Word groups by rank
          _buildWordGroup('1 - 100', allWords, countMap, 1, 100),
          _buildWordGroup('101 - 200', allWords, countMap, 101, 200),
          _buildWordGroup('201 - 300', allWords, countMap, 201, 300),
          _buildWordGroup('301+', allWords, countMap, 301, 999999),
        ],
      ),
    );
  }

  Widget _buildWordGroup(String label, Map<String, LrWord> allWords,
      Map<String, int> countMap, int minRank, int maxRank) {
    final words = allWords.values
        .where((w) => w.langRank >= minRank && w.langRank <= maxRank)
        .toList()
      ..sort((a, b) => countMap[b.text.toLowerCase()]!
          .compareTo(countMap[a.text.toLowerCase()]!));

    if (words.isEmpty) return const SizedBox.shrink();

    // Group by count
    final byCount = <int, List<LrWord>>{};
    for (final w in words) {
      final c = countMap[w.text.toLowerCase()] ?? 1;
      byCount.putIfAbsent(c, () => []).add(w);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        ...byCount.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Count badge
                  Container(
                    width: 30,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${e.key}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: e.value
                          .map((w) => GestureDetector(
                                onTap: () => _showWordPopup(w),
                                child: Text(
                                  w.text.toLowerCase(),
                                  style: TextStyle(
                                    color: w.state == WordState.known
                                        ? const Color(0xFF4CAF50)
                                        : w.state == WordState.learning
                                            ? const Color(0xFF9C27B0)
                                            : w.typeColor,
                                    fontSize: 13,
                                    fontWeight: w.state != WordState.unknown
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    decoration: w.state == WordState.ignored
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ══════════════════════════════════════════════════════════

class _WordChip extends StatelessWidget {
  final LrWord word;
  final VoidCallback onTap;
  const _WordChip({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = word.type == 'other' || word.type == 'prep'
        ? Colors.white
        : word.typeColor;

    return GestureDetector(
      onTap: onTap,
      child: Text(
        '${word.text} ',
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
          decoration:
              word.state == WordState.known ? TextDecoration.underline : null,
          decorationColor: Color(0xFF4CAF50).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _WordStatsRow extends StatefulWidget {
  final int known, learning, ignored, total;
  const _WordStatsRow(
      {required this.known,
      required this.learning,
      required this.ignored,
      required this.total});

  @override
  State<_WordStatsRow> createState() => _WordStatsRowState();
}

class _WordStatsRowState extends State<_WordStatsRow> {
  String? _tooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatChip(
              label: '✓ ${widget.known}',
              color: const Color(0xFF4CAF50),
              bgColor: const Color(0xFF1B5E20),
              onTap: () => setState(
                  () => _tooltip = _tooltip == 'known' ? null : 'known'),
            ),
            const SizedBox(width: 6),
            _StatChip(
              label: '📖 ${widget.learning}',
              color: const Color(0xFF9C27B0),
              bgColor: const Color(0xFF4A148C),
              onTap: () => setState(
                  () => _tooltip = _tooltip == 'learning' ? null : 'learning'),
            ),
            const SizedBox(width: 6),
            _StatChip(
              label: '⊘ ${widget.ignored}',
              color: Colors.grey,
              bgColor: Colors.grey.withValues(alpha: 0.2),
              onTap: () => setState(
                  () => _tooltip = _tooltip == 'ignored' ? null : 'ignored'),
            ),
            const SizedBox(width: 8),
            Text('/ ${widget.total}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
        if (_tooltip != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _tooltip == 'known'
                  ? 'Known\n(Click to show / hide)'
                  : _tooltip == 'learning'
                      ? 'Learning\n(Click to show / hide)'
                      : 'Ignored\n(Click to show / hide)',
              style: TextStyle(color: Colors.grey[300], fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
