import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../models/yt_video.dart';
import '../services/yt_downloader.dart';
import 'yt_video_card.dart';

enum _DlState { idle, fetching, downloading, done, failed }

class YtTabAudio extends StatefulWidget {
  final YtVideo? video;
  final bool isLoadingVideo;

  const YtTabAudio({
    super.key,
    required this.video,
    required this.isLoadingVideo,
  });

  @override
  State<YtTabAudio> createState() => _YtTabAudioState();
}

class _YtTabAudioState extends State<YtTabAudio>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _showPreview = false;
  _DlState _dlState = _DlState.idle;
  double _dlProgress = 0;
  String _dlProgressText = '';
  String? _dlError;
  String? _savedPath;
  StreamSubscription<YtDownloadEvent>? _sub;

  @override
  void didUpdateWidget(YtTabAudio old) {
    super.didUpdateWidget(old);
    // Reset khi video đổi
    if (old.video?.id != widget.video?.id) {
      setState(() {
        _showPreview = false;
        _dlState = _DlState.idle;
        _dlError = null;
        _savedPath = null;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (widget.video == null) return;
    setState(() {
      _dlState = _DlState.fetching;
      _dlError = null;
    });

    _sub?.cancel();
    _sub = YtDownloader.instance.download(widget.video!).listen(
      (event) async {
        if (!mounted) return;
        switch (event) {
          case YtDownloadProgress():
            setState(() {
              _dlState = _DlState.downloading;
              _dlProgress = event.progress;
              _dlProgressText = event.progressText;
            });
          case YtDownloadDone():
            setState(() {
              _dlState = _DlState.done;
              _dlProgress = 1.0;
              _savedPath = event.filePath;
            });
            if (context.mounted) {
              await context.read<PlayerProvider>().loadSong(
                    path: event.filePath,
                    title: widget.video!.title,
                    artist: widget.video!.channel,
                    autoPlay: true,
                  );
            }
          case YtDownloadFailed():
            setState(() {
              _dlState = _DlState.failed;
              _dlError = event.message;
            });
        }
      },
    );
  }

  void _cancelDownload() {
    YtDownloader.instance.cancel();
    _sub?.cancel();
    setState(() {
      _dlState = _DlState.idle;
      _dlProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Empty / Loading / Video card ──────────────────
        if (widget.isLoadingVideo)
          _LoadingCard('Đang lấy thông tin...')
        else if (widget.video == null)
          _EmptyHint(
            icon: Icons.music_video_outlined,
            text: 'Dán URL YouTube ở trên để bắt đầu',
          )
        else ...[
          YtVideoCard(
            video: widget.video!,
            showPreview: _showPreview,
            onPreviewToggle: () =>
                setState(() => _showPreview = !_showPreview),
          ),

          // Preview WebView
          if (_showPreview) ...[
            const SizedBox(height: 12),
            YtPreviewWebView(embedUrl: widget.video!.embedUrl),
          ],

          const SizedBox(height: 16),
          _buildDownloadSection(),
        ],
      ],
    );
  }

  Widget _buildDownloadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📥 Tải Audio',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2137),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: Color(0xFF2196F3)),
              SizedBox(width: 6),
              Text('M4A · Chất lượng cao nhất',
                  style: TextStyle(color: Colors.blue, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildDlBody(),
      ],
    );
  }

  Widget _buildDlBody() {
    return switch (_dlState) {
      _DlState.idle || _DlState.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_dlError != null) ...[
              _ErrorBox(_dlError!),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: _startDownload,
              icon: const Icon(Icons.download, size: 18),
              label: Text(
                  _dlState == _DlState.failed ? 'Thử lại' : 'Tải xuống'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      _DlState.fetching => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF))),
                SizedBox(height: 8),
                Text('Đang chuẩn bị...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      _DlState.downloading => Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _dlProgress,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_dlProgressText,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text('${(_dlProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.cancel_outlined,
                  size: 16, color: Colors.red),
              label: const Text('Hủy', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      _DlState.done => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF4CAF50), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tải xong! Đang phát...',
                            style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold)),
                        if (_savedPath != null)
                          Text(_savedPath!.split('/').last,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _dlState = _DlState.idle;
                      _savedPath = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Tải video khác',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ],
        ),
    };
  }
}

// ─── Local helpers ────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  final String msg;
  const _LoadingCard(this.msg);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFF0000))),
            const SizedBox(height: 12),
            Text(msg, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox(this.msg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)),
      );
}
