//
// Entry point duy nhất — ghép 3 tab lại:
//  Tab 0: Audio   (download audio)
//  Tab 1: Captions (fetch + sử dụng)
//  Tab 2: Lịch sử
//
// Gọi: YoutubeSheet.show(context)
//      YoutubeSheet.show(context, captionsFirst: true)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import 'models/yt_video.dart';
import 'services/yt_service.dart';
import 'widgets/yt_tab_audio.dart';
import 'widgets/yt_tab_captions.dart';
import 'widgets/yt_video_card.dart';
import 'package:in4up/core/language/tr_extension.dart';

class YoutubeSheet extends StatefulWidget {
  final bool captionsFirst;

  const YoutubeSheet({super.key, this.captionsFirst = false});

  static Future<String?> show(BuildContext context,
      {bool captionsFirst = false}) {
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<PlayerProvider>()),
          ChangeNotifierProvider.value(value: context.read<TextProvider>()),
        ],
        child: YoutubeSheet(captionsFirst: captionsFirst),
      ),
    );
  }

  @override
  State<YoutubeSheet> createState() => _YoutubeSheetState();
}

class _YoutubeSheetState extends State<YoutubeSheet>
    with SingleTickerProviderStateMixin {
  // ── URL / Video ───────────────────────────────────────────
  final _urlCtrl = TextEditingController();
  YtVideo? _video;
  bool _isFetchingVideo = false;
  String? _urlError;

  // ── Downloaded audio path (shared giữa Audio và Captions tab) ──
  String? _downloadedAudioPath;

  // ── History ───────────────────────────────────────────────
  List<YtVideo> _history = [];

  // ── Tabs ──────────────────────────────────────────────────
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.captionsFirst ? 1 : 0,
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    await YtHistory.ensureOpen();
    setState(() => _history = YtHistory.load());
  }

  // ─── Fetch video info ─────────────────────────────────────

  Future<void> _fetchVideo() async {
    final input = _urlCtrl.text.trim();
    if (input.isEmpty) return;
    FocusScope.of(context).unfocus();

    final id = YtVideo.extractId(input);
    if (id == null) {
      setState(() => _urlError = 'Content');
      return;
    }

    setState(() {
      _isFetchingVideo = true;
      _urlError = null;
      _video = null;
      _downloadedAudioPath = null;
    });

    final video = await YtService.instance.fetchInfo(id);

    if (!mounted) return;

    if (video == null) {
      setState(() {
        _urlError = 'Search';
        _isFetchingVideo = false;
      });
      return;
    }

    setState(() {
      _video = video;
      _isFetchingVideo = false;
    });

    await YtHistory.add(video);
    setState(() => _history = YtHistory.load());
  }

  void _selectFromHistory(YtVideo v) {
    _urlCtrl.text = v.id;
    setState(() {
      _video = v;
      _urlError = null;
      _downloadedAudioPath = null;
    });
    _tabCtrl.animateTo(widget.captionsFirst ? 1 : 0);
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            _buildUrlBar(),
            const SizedBox(height: 2),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Tab 0 — Audio
                  YtTabAudio(
                    video: _video,
                    isLoadingVideo: _isFetchingVideo,
                  ),

                  // Tab 1 — Captions
                  YtTabCaptions(
                    video: _video,
                    isLoadingVideo: _isFetchingVideo,
                    downloadedAudioPath: _downloadedAudioPath,
                  ),

                  // Tab 2 — History
                  _buildHistoryTab(scroll),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFFF0000).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_circle_fill,
                  color: Color(0xFFFF0000), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YouTube',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(context.l10n.ytAudioCaptionsHistory, style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );

  Widget _buildUrlBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
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
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: context.l10n.ytPasteUrl,
                          hintStyle:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          errorText: _urlError,
                          errorStyle:
                              const TextStyle(color: Colors.red, fontSize: 10),
                        ),
                        onSubmitted: (_) => _fetchVideo(),
                      ),
                    ),
                    // Paste
                    IconButton(
                      icon: const Icon(Icons.content_paste,
                          color: Colors.grey, size: 16),
                      onPressed: () async {
                        final d = await Clipboard.getData('text/plain');
                        if (d?.text != null) {
                          _urlCtrl.text = d!.text!.trim();
                          if (mounted) _fetchVideo();
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _fetchVideo,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _isFetchingVideo
                      ? Colors.grey.withValues(alpha: 0.2)
                      : Color(0xFFFF0000).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isFetchingVideo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Icon(Icons.search, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );

  Widget _buildTabBar() => TabBar(
        controller: _tabCtrl,
        labelColor: const Color(0xFFFF0000),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFFFF0000),
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.audio_file, size: 15), text: 'Audio'),
          Tab(icon: Icon(Icons.subtitles, size: 15), text: 'Captions'),
          Tab(icon: Icon(Icons.history, size: 15), text: context.l10n.ytHistory),
        ],
      );

  Widget _buildHistoryTab(ScrollController scroll) {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(context.l10n.ytNoHistory, style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (_, i) {
        final v = _history[i];
        return YtHistoryItem(
          video: v,
          onTap: () => _selectFromHistory(v),
          onDelete: () async {
            await YtHistory.remove(v.id);
            setState(() => _history = YtHistory.load());
          },
        );
      },
    );
  }
}