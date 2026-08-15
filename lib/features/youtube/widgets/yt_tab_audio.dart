//
// FIX kẹt 5%: dùng YtDownloader mới với await for trực tiếp
// THÊM: chọn chất lượng audio trước khi tải
// THÊM: hiển thị quality badge trên nút tải

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show AudioOnlyStreamInfo;

import '../../../providers/player_provider.dart';
import '../models/yt_video.dart';
import '../services/yt_downloader.dart';
import 'yt_video_card.dart';
import 'package:in4up/core/language/tr_extension.dart';

enum _DlState { idle, fetchingQualities, fetching, downloading, done, failed }

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
  String _savedQuality = '';

  // Chất lượng đã chọn
  YtAudioQuality _selectedQuality = YtAudioQuality.highest;
  AudioOnlyStreamInfo? _selectedStream; // null = dùng preset
  List<AudioOnlyStreamInfo> _availableStreams = [];

  StreamSubscription<YtDownloadEvent>? _sub;

  @override
  void didUpdateWidget(YtTabAudio old) {
    super.didUpdateWidget(old);
    if (old.video?.id != widget.video?.id) {
      setState(() {
        _showPreview = false;
        _dlState = _DlState.idle;
        _dlError = null;
        _savedPath = null;
        _savedQuality = '';
        _availableStreams = [];
        _selectedStream = null;
        _selectedQuality = YtAudioQuality.highest;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ─── Fetch danh sách chất lượng ──────────────────────
  Future<void> _fetchQualities() async {
    if (widget.video == null) return;
    setState(() {
      _dlState = _DlState.fetchingQualities;
      _dlError = null;
    });

    final streams = await YtDownloader.instance.getAudioStreams(widget.video!.id);
    if (!mounted) return;

    if (streams.isEmpty) {
      setState(() {
        _dlState = _DlState.idle;
        _dlError = 'Content';
      });
      return;
    }

    setState(() {
      _availableStreams = streams;
      _dlState = _DlState.idle;
    });

    _showQualitySheet();
  }

  // ─── Hiện sheet chọn chất lượng ──────────────────────
  void _showQualitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QualitySheet(
        streams: _availableStreams,
        selectedQuality: _selectedQuality,
        selectedStream: _selectedStream,
        onSelectPreset: (q) {
          setState(() {
            _selectedQuality = q;
            _selectedStream = null;
          });
          Navigator.pop(context);
          _startDownload();
        },
        onSelectStream: (s) {
          setState(() {
            _selectedStream = s;
            _selectedQuality = YtAudioQuality.highest;
          });
          Navigator.pop(context);
          _startDownload();
        },
      ),
    );
  }

  // ─── Bắt đầu download ────────────────────────────────
  Future<void> _startDownload({bool skipQualityPick = false}) async {
    if (widget.video == null) return;

    // Nếu chưa có danh sách streams và muốn chọn chất lượng → fetch trước
    if (!skipQualityPick && _availableStreams.isEmpty) {
      await _fetchQualities();
      return;
    }

    setState(() {
      _dlState = _DlState.fetching;
      _dlProgress = 0;
      _dlProgressText = 'Content';
      _dlError = null;
    });

    _sub?.cancel();
    _sub = YtDownloader.instance
        .download(
          widget.video!,
          quality: _selectedQuality,
          specificStream: _selectedStream,
        )
        .listen(
          (event) async {
            if (!mounted) return;
            switch (event) {
              case YtDownloadProgress():
                setState(() {
                  _dlState = event.progress < 0.11
                      ? _DlState.fetching
                      : _DlState.downloading;
                  _dlProgress = event.progress;
                  _dlProgressText = event.progressText;
                });
              case YtDownloadDone():
                setState(() {
                  _dlState = _DlState.done;
                  _dlProgress = 1.0;
                  _savedPath = event.filePath;
                  _savedQuality = event.quality;
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
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _dlState = _DlState.failed;
              _dlError = e.toString();
            });
          },
        );
  }

  void _cancelDownload() {
    YtDownloader.instance.cancel();
    _sub?.cancel();
    setState(() {
      _dlState = _DlState.idle;
      _dlProgress = 0;
      _dlProgressText = '';
    });
  }

  // ─── Build ────────────────────────────────────────────
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
          YtVideoCard(
            video: widget.video!,
            showPreview: _showPreview,
            onPreviewToggle: () =>
                setState(() => _showPreview = !_showPreview),
          ),
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
        Row(
          children: [
            const TrText('📥 Tải Audio', style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            // Badge chất lượng hiện tại
            if (_dlState == _DlState.idle ||
                _dlState == _DlState.failed ||
                _dlState == _DlState.fetchingQualities)
              _QualityBadge(
                quality: _selectedQuality,
                specificStream: _selectedStream,
                onTap: _availableStreams.isNotEmpty
                    ? _showQualitySheet
                    : _fetchQualities,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildInfoBanner(),
        const SizedBox(height: 12),
        _buildDlBody(),
      ],
    );
  }

  Widget _buildInfoBanner() {
    String label;
    if (_selectedStream != null) {
      final kbps = _selectedStream!.bitrate.bitsPerSecond ~/ 1000;
      final ext = _selectedStream!.container.name.toUpperCase();
      label = 'Content';
    } else {
      switch (_selectedQuality) {
        case YtAudioQuality.highest:
          label = 'Content';
          break;
        case YtAudioQuality.medium:
          label = 'MP4 · ~128kbps';
          break;
        case YtAudioQuality.low:
          label = 'Content';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 13, color: Color(0xFF2196F3)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.blue, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDlBody() {
    switch (_dlState) {
      case _DlState.idle:
      case _DlState.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_dlError != null) ...[
              _ErrorBox(_dlError!),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                // Nút tải nhanh (không chọn chất lượng)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _startDownload(skipQualityPick: true),
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(_dlState == _DlState.failed
                        ? 'Retry'
                        : 'Content'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: BorderSide(color: Colors.grey.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Nút chọn chất lượng rồi tải
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _fetchQualities,
                    icon: const Icon(Icons.high_quality, size: 16),
                    label: const TrTrText('Chọn chất lượng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case _DlState.fetchingQualities:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(Color(0xFF6C63FF))),
                SizedBox(height: 8),
                Text(context.l10n.ytQualityList, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );

      case _DlState.fetching:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(Color(0xFF6C63FF))),
                SizedBox(height: 8),
                TrText('Đang chuẩn bị...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );

      case _DlState.downloading:
        return Column(
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
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
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
              label: const Text(context.l10n.commonCancel, style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );

      case _DlState.done:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Color(0xFF4CAF50).withValues(alpha: 0.3)),
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
                        const Text(context.l10n.ytDownloadedPlaying, style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold)),
                        if (_savedQuality.isNotEmpty)
                          Text('Content',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
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
                      _savedQuality = '';
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(context.l10n.ytDownloadAnother, style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                    child: const TrText(context.l10n.commonClose),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildLoading() => const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFF0000))),
            SizedBox(height: 12),
            Text(context.l10n.ytFetchingInfo, style: TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.music_video_outlined, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 12),
            const Text(context.l10n.ytPasteToStart, style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════
//  Quality Badge
// ══════════════════════════════════════════════════════════

class _QualityBadge extends StatelessWidget {
  final YtAudioQuality quality;
  final AudioOnlyStreamInfo? specificStream;
  final VoidCallback onTap;

  const _QualityBadge({
    required this.quality,
    this.specificStream,
    required this.onTap,
  });

  String get _label {
    if (specificStream != null) {
      final kbps = specificStream!.bitrate.bitsPerSecond ~/ 1000;
      return '${kbps}kbps ▾';
    }
    switch (quality) {
      case YtAudioQuality.highest:
        return 'Content';
      case YtAudioQuality.medium:
        return '~128kbps ▾';
      case YtAudioQuality.low:
        return '~64kbps ▾';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFF6C63FF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Color(0xFF6C63FF).withValues(alpha: 0.4)),
        ),
        child: Text(_label,
            style: const TextStyle(
                color: Color(0xFF9C8FFF),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Quality Sheet
// ══════════════════════════════════════════════════════════

class _QualitySheet extends StatelessWidget {
  final List<AudioOnlyStreamInfo> streams;
  final YtAudioQuality selectedQuality;
  final AudioOnlyStreamInfo? selectedStream;
  final ValueChanged<YtAudioQuality> onSelectPreset;
  final ValueChanged<AudioOnlyStreamInfo> onSelectStream;

  const _QualitySheet({
    required this.streams,
    required this.selectedQuality,
    this.selectedStream,
    required this.onSelectPreset,
    required this.onSelectStream,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(context.l10n.ytSelectQuality, style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(context.l10n.ytHigherBigger, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 16),

          // ── Presets ──────────────────────────────────
          ...YtAudioQuality.values.map((q) {
            final isSelected = selectedStream == null && selectedQuality == q;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectPreset(q);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Color(0xFF6C63FF).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: Color(0xFF6C63FF).withValues(alpha: 0.5))
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(
                      q == YtAudioQuality.highest
                          ? Icons.high_quality
                          : q == YtAudioQuality.medium
                              ? Icons.graphic_eq
                              : Icons.compress,
                      color: isSelected
                          ? const Color(0xFF9C8FFF)
                          : Colors.grey[500],
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.label,
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[300],
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13)),
                          Text(
                            q == YtAudioQuality.highest
                                ? 'Content'
                                : q == YtAudioQuality.medium
                                    ? 'Content'
                                    : 'Content',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check,
                          color: Color(0xFF9C8FFF), size: 16),
                  ],
                ),
              ),
            );
          }),

          // ── Chọn cụ thể (tối đa 6 stream) ───────────
          if (streams.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Divider(color: Colors.grey[800])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(context.l10n.ytChooseSpecific, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ),
                Expanded(child: Divider(color: Colors.grey[800])),
              ]),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: streams.take(6).map((s) {
                final isSelected = selectedStream == s;
                final kbps = s.bitrate.bitsPerSecond ~/ 1000;
                final ext = s.container.name.toUpperCase();
                final sizeLabel = s.size.totalBytes > 0
                    ? ' · ${(s.size.totalBytes / 1048576).toStringAsFixed(0)}MB'
                    : '';
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelectStream(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFF6C63FF).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Color(0xFF6C63FF).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      '$ext · ${kbps}kbps$sizeLabel',
                      style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF9C8FFF)
                              : Colors.grey[400],
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Error Box ────────────────────────────────────────────
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
        child:
            Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)),
      );
}