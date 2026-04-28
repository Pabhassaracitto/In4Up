import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/text_provider.dart';
import '../models/yt_video.dart';
import '../services/yt_service.dart';
import '../youtube_explorer_screen.dart';
import '../yt_player_screen.dart';
import 'yt_video_card.dart';

class YtTabCaptions extends StatefulWidget {
  final YtVideo? video;
  final bool isLoadingVideo;

  /// Path audio đã tải (từ tab Audio) — dùng cho "Link + Phát"
  final String? downloadedAudioPath;

  const YtTabCaptions({
    super.key,
    required this.video,
    required this.isLoadingVideo,
    this.downloadedAudioPath,
  });

  @override
  State<YtTabCaptions> createState() => _YtTabCaptionsState();
}

class _YtTabCaptionsState extends State<YtTabCaptions>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _langs = [
    ('en', '🇺🇸 EN'),
    ('vi', '🇻🇳 VI'),
    ('zh-Hans', '🇨🇳 ZH'),
    ('ja', '🇯🇵 JA'),
    ('ko', '🇰🇷 KO'),
  ];

  String _lang = 'en';
  List<YtCaptionLine> _captions = [];
  bool _isFetching = false;
  String? _error;
  String? _savedLrcPath;

  @override
  void didUpdateWidget(YtTabCaptions old) {
    super.didUpdateWidget(old);
    if (old.video?.id != widget.video?.id) {
      setState(() {
        _captions = [];
        _error = null;
        _savedLrcPath = null;
      });
    }
  }

  Future<void> _fetchCaptions() async {
    if (widget.video == null) return;
    setState(() {
      _isFetching = true;
      _error = null;
    });

    final lines =
        await YtService.instance.fetchCaptions(widget.video!.id, lang: _lang);

    if (!mounted) return;

    if (lines.isEmpty) {
      setState(() {
        _error = 'Không có captions cho "$_lang".\nThử ngôn ngữ khác.';
        _isFetching = false;
      });
      return;
    }

    setState(() {
      _captions = lines;
      _isFetching = false;
    });
  }

  Future<String?> _ensureLrcSaved() async {
    if (_savedLrcPath != null) return _savedLrcPath;
    final path = await YtService.instance.saveLrc(_captions, widget.video!);
    if (path != null) setState(() => _savedLrcPath = path);
    return path;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF1A237E),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.isLoadingVideo)
          _buildLoading()
        else if (widget.video == null)
          _buildEmpty()
        else ...[
          // Video card (non-interactive preview — mở preview ở tab Audio)
          YtVideoCard(
            video: widget.video!,
            showPreview: false,
            onPreviewToggle: () {}, // Preview chỉ ở tab Audio
          ),
          const SizedBox(height: 16),
          _buildLangSelector(),
          const SizedBox(height: 10),
          if (_error != null) _buildError(),
          _buildFetchButton(),
          if (_captions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPreview(),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ],
      ],
    );
  }

  Widget _buildLoading() => const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFF0000))),
            SizedBox(height: 12),
            Text('Đang lấy thông tin...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.subtitles_outlined, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 12),
            const Text('Dán URL YouTube ở trên để bắt đầu',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _buildLangSelector() => Row(
        children: [
          const Text('Ngôn ngữ:',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          ..._langs.map((l) {
            final sel = _lang == l.$1;
            return GestureDetector(
              onTap: () => setState(() => _lang = l.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF2196F3)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(l.$2,
                    style: TextStyle(
                        color: sel ? Colors.white : Colors.grey, fontSize: 11)),
              ),
            );
          }),
        ],
      );

  Widget _buildError() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(color: Colors.amber, fontSize: 11)),
              ),
            ],
          ),
        ),
      );

  Widget _buildFetchButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isFetching ? null : _fetchCaptions,
          icon: _isFetching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white)),
                )
              : const Icon(Icons.download, size: 16),
          label: Text(_isFetching ? 'Đang tải...' : 'Lấy captions ($_lang)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _buildPreview() {
    final preview = _captions.take(6).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                const Icon(Icons.subtitles_outlined,
                    size: 14, color: Color(0xFF4CAF50)),
                const SizedBox(width: 6),
                Text('${_captions.length} dòng',
                    style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...preview.map((c) {
            final mm =
                c.start.inMinutes.remainder(60).toString().padLeft(2, '0');
            final ss =
                c.start.inSeconds.remainder(60).toString().padLeft(2, '0');
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: Text('$mm:$ss',
                        style: const TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 10,
                            fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(c.text,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }),
          if (_captions.length > 6)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text('... và ${_captions.length - 6} dòng nữa',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: YtActionBtn(
                icon: Icons.menu_book,
                label: 'Text Studio',
                color: const Color(0xFF2196F3),
                onTap: () {
                  final plain = _captions.map((c) => c.text).join('\n');
                  context
                      .read<TextProvider>()
                      .loadText(plain, title: widget.video!.title);
                  Navigator.pop(context);
                  _snack('✅ Loaded vào Text Studio');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: YtActionBtn(
                icon: Icons.sync,
                label: 'Sync Mode',
                color: const Color(0xFF4CAF50),
                onTap: () async {
                  final path = await _ensureLrcSaved();
                  if (path != null && context.mounted) {
                    await context.read<TextProvider>().loadTextFile(path);
                    Navigator.pop(context);
                    _snack('✅ LRC loaded → Understand Mode');
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: YtActionBtn(
                icon: Icons.school,
                label: 'Smart Study',
                color: const Color(0xFFE91E63),
                onTap: () {
                  final exVideo = YtExVideo(
                    id: widget.video!.id,
                    title: widget.video!.title,
                    channelId: '',
                    channelTitle: widget.video!.channel,
                    thumb: widget.video!.thumb,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => YtPlayerScreen(video: exVideo),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: YtActionBtn(
                icon: Icons.link,
                label: widget.downloadedAudioPath != null
                    ? 'Link + Phát ✅'
                    : 'Link + Phát',
                color: const Color(0xFFFF9800),
                onTap: () async {
                  if (widget.downloadedAudioPath == null) {
                    _snack('Hãy tải audio ở tab "Audio" trước');
                    return;
                  }
                  final lrcPath = await _ensureLrcSaved();
                  await context.read<PlayerProvider>().loadSong(
                        path: widget.downloadedAudioPath!,
                        title: widget.video!.title,
                        artist: widget.video!.channel,
                        autoPlay: true,
                      );
                  if (lrcPath != null && context.mounted) {
                    await context.read<TextProvider>().loadTextFile(lrcPath);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    _snack('🎵 Audio + Lyrics đã link!');
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
