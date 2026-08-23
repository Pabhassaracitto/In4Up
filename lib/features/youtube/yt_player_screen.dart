//
// Language Reactor-style video player:
// • Trái: YouTube iframe + subtitle lớn + dịch
// • Phải: Tab VĂN BẢN (transcript song ngữ) | TỪ (word analysis)
// • Click từ → popup nghĩa (động từ, danh từ...)
// • Nút ✓ Known | 📖 Learning
// • Tab TỪ: Known 36 / Learning 3 / Ignored 7, rank filter

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../word_lookup/word_analysis_sheet.dart';

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
  const YtPlayerScreen({super.key, required this.video});

  @override
  State<YtPlayerScreen> createState() => _YtPlayerScreenState();
}

class _YtPlayerScreenState extends State<YtPlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late WebViewController _ytCtrl;
  Timer? _timer;
  bool _isLoading = true;

  // ── Subtitle state ────────────────────────────────────────
  final List<SubtitleLine> _lines = [];
  int _currentLineIdx = 0;
  double _currentTime = 0;

  // ── Word knowledge ────────────────────────────────────────
  final Map<String, WordState> _wordStates = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _initWebView();
    _loadRealSubtitles();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _initWebView() {
    _ytCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _injectSyncScript();
          },
        ),
      )
      ..addJavaScriptChannel(
        'YtSync',
        onMessageReceived: (msg) {
          final time = double.tryParse(msg.message) ?? 0;
          _updateTime(time);
        },
      )
      ..loadRequest(Uri.parse(
          'https://www.youtube.com/embed/${widget.video.id}?enablejsapi=1&cc_load_policy=0&rel=0&autoplay=1'));
  }

  void _injectSyncScript() {
    const js = """
      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

      var player;
      function onYouTubeIframeAPIReady() {
        player = new YT.Player(document.querySelector('iframe') || window, {
          events: {
            'onReady': onPlayerReady
          }
        });
      }

      function onPlayerReady(event) {
        setInterval(function() {
          if (player && player.getCurrentTime) {
            YtSync.postMessage(player.getCurrentTime().toString());
          }
        }, 500);
      }
      
      // Fallback nếu api không ready
      setInterval(function() {
        var video = document.querySelector('video');
        if (video) {
          YtSync.postMessage(video.currentTime.toString());
        }
      }, 500);
    """;
    _ytCtrl.runJavaScript(js);
  }

  void _updateTime(double time) {
    if (!mounted) return;
    setState(() {
      _currentTime = time;
      // Find current line
      final ms = (time * 1000).round();
      final idx = _lines.indexWhere(
          (l) => ms >= l.start.inMilliseconds && ms <= l.end.inMilliseconds);
      if (idx != -1 && idx != _currentLineIdx) {
        _currentLineIdx = idx;
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Script injection fallback if needed
      _ytCtrl.runJavaScript(
          "if(document.querySelector('video')) YtSync.postMessage(document.querySelector('video').currentTime.toString())");
    });
  }

  Future<void> _loadRealSubtitles() async {
    setState(() => _isLoading = true);
    try {
      final captions = await YtService.instance.fetchBilingualCaptions(
        widget.video.id,
        lang1: 'en',
        lang2: 'vi',
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
    // Simple word type assignment (simplified)
    const verbWords = {
      'need',
      'grab',
      'working',
      'means',
      'shifts',
      'know',
      'go',
      'said',
      'make',
      'take',
      'get',
      'see',
      'come',
      'think'
    };
    const nounWords = {
      'school',
      'noun',
      'double',
      'shift',
      'row',
      'verb',
      'day',
      'time'
    };
    const adjWords = {'little', 'proper', 'another', 'two'};
    const prepWords = {'in', 'after', 'because', 'a', 'an', 'the'};
    const conjWords = {'and', 'but', 'or', 'so', 'because', 'if'};
    const properNames = {'liam', "rachel's"};

    final words = <LrWord>[];
    final tokens = text
        .replaceAll("'", "'")
        .split(RegExp(r"[\s,;.!?]+"))
        .where((w) => w.isNotEmpty);

    int rank = 100;
    for (final token in tokens) {
      final lower = token.toLowerCase().replaceAll("'", '');
      if (lower.isEmpty) continue;

      String type = 'other';
      if (properNames.contains(lower)) {
        type = 'proper';
      } else if (verbWords.contains(lower)) {
        type = 'verb';
      } else if (nounWords.contains(lower)) {
        type = 'noun';
      } else if (adjWords.contains(lower)) {
        type = 'adj';
      } else if (prepWords.contains(lower)) {
        type = 'prep';
      } else if (conjWords.contains(lower)) {
        type = 'conj';
      } else if (lower.length > 3) {
        type = 'noun';
      }

      words.add(LrWord(
        text: token,
        type: type,
        langRank: rank,
        state: _wordStates[lower] ?? WordState.unknown,
      ));
      rank += 50;
    }
    return words;
  }

  // ─── Word actions ─────────────────────────────────────────
  void _setWordState(String word, WordState state) {
    setState(() {
      _wordStates[word.toLowerCase()] = state;
      // Update in all lines
      for (final line in _lines) {
        for (final w in line.words) {
          if (w.text.toLowerCase() == word.toLowerCase()) {
            w.state = state;
          }
        }
      }
    });
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
    return WebViewWidget(controller: _ytCtrl);
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
          Row(
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
    _ytCtrl.runJavaScript(
        "if(player && player.seekTo) player.seekTo($seconds, true); else if(document.querySelector('video')) document.querySelector('video').currentTime = $seconds;");
  }

  void _showWordPopup(LrWord word) {
    // Lấy context câu từ subtitle đang phát
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
          onTap: () => setState(() => _currentLineIdx = i),
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
//  WORD POPUP
// ══════════════════════════════════════════════════════════
class _WordPopup extends StatelessWidget {
  final LrWord word;
  final ValueChanged<WordState> onSetState;

  const _WordPopup({required this.word, required this.onSetState});

  @override
  Widget build(BuildContext context) {
    // Mô phỏng các nghĩa (thực tế fetch từ dictionary API)
    final meanings = _getMeanings(word.text.toLowerCase());

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    word.text,
                    style: TextStyle(
                        color: word.typeColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(word.typeLabel,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.grey[600], size: 18),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

            // Meanings list
            ...meanings.map((m) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: word.typeColor.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(m,
                            style: TextStyle(
                                color: Colors.grey[300], fontSize: 13)),
                      ),
                    ],
                  ),
                )),

            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: _PopupBtn(
                      label: '✓ Đã biết',
                      color: const Color(0xFF4CAF50),
                      onTap: () => onSetState(WordState.known),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PopupBtn(
                      label: '📖 Đang học',
                      color: const Color(0xFF9C27B0),
                      onTap: () => onSetState(WordState.learning),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PopupBtn(
                      label: '⊘ Bỏ qua',
                      color: Colors.grey,
                      onTap: () => onSetState(WordState.ignored),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getMeanings(String word) {
    // Mock meanings — thực tế gọi dictionary API
    const dict = {
      'need': ['cần, cần thiết', 'nhu cầu (danh từ)'],
      'grab': ['nắm lấy, túm lấy', 'lấy nhanh, đón'],
      'working': ['đang làm việc', 'hoạt động'],
      'double': ['gấp đôi', 'ca kép (2 ca liên tiếp)', 'đồng dạng'],
      'shift': ['ca làm việc', 'thay đổi, dịch chuyển'],
      'school': ['trường học', 'sau giờ học'],
      'verb': ['động từ'],
      'noun': ['danh từ'],
      'proper': ['đúng đắn, phù hợp', 'tên riêng (proper noun)'],
      'little': ['nhỏ, ít', 'một chút'],
      'after': ['sau, sau khi'],
    };
    return dict[word] ?? ['(không có trong từ điển)'];
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

class _PopupBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PopupBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
