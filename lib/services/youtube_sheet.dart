// lib/screens/tools/youtube/youtube_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/text_provider.dart';
import '../../../services/youtube_download_service.dart';

class YoutubeSheet extends StatefulWidget {
  final bool captionsFirst;

  const YoutubeSheet({super.key, this.captionsFirst = false});

  static Future<String?> show(BuildContext context, {bool captionsFirst = false}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: context.read<PlayerProvider>()),
            ChangeNotifierProvider.value(value: context.read<TextProvider>()),
          ],
          child: YoutubeSheet(captionsFirst: captionsFirst),
        ),
      ),
    );
  }

  @override
  State<YoutubeSheet> createState() => _YoutubeSheetState();
}

class _YoutubeSheetState extends State<YoutubeSheet> {
  final _urlCtrl = TextEditingController();
  final _svc = YoutubeDownloadService();

  String _phase = 'input'; // input | info | download_audio | download_caption | done | error

  YtVideoInfo? _videoInfo;
  DownloadProgress? _audioProgress;
  String? _errorMessage;
  
  // Audio
  StreamSubscription<DownloadProgress>? _audioSub;

  // Captions
  List<YtCaptionLine> _captions = [];
  List<({String code, String name})> _availableLangs = [];
  String _selectedLang = 'en';
  bool _isFetchingLangs = false;
  bool _isFetchingCaptions = false;

  @override
  void initState() {
    super.initState();
    // Auto-paste if clipboard has youtube link
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      final text = data!.text!.trim();
      if (text.contains('youtu')) {
        _urlCtrl.text = text;
        _fetchInfo();
      }
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _audioSub?.cancel();
    super.dispose();
  }

  // ── Step 1: Fetch Info ──────────────────────────────────────
  Future<void> _fetchInfo() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _phase = 'info';
      _errorMessage = null;
      _isFetchingLangs = true;
    });

    try {
      final results = await Future.wait([
        _svc.fetchVideoInfo(url),
        if (widget.captionsFirst) _svc.getAvailableLanguages(url),
      ]);

      final info = results[0] as YtVideoInfo?;
      final langs = widget.captionsFirst ? (results[1] as List<({String code, String name})>) : <({String code, String name})>[];

      if (info == null) {
        setState(() {
          _errorMessage = 'Không tìm thấy video';
          _phase = 'error';
        });
        return;
      }

      setState(() {
        _videoInfo = info;
        _availableLangs = langs;
        if (langs.isNotEmpty && !langs.any((l) => l.code == _selectedLang)) {
          _selectedLang = langs.first.code;
        }
        _isFetchingLangs = false;
        
        // If captions first mode, stay on info screen to select language
        // If audio mode, maybe auto start? No, let user confirm.
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _phase = 'error';
      });
    }
  }

  // ── Step 2A: Download Audio ──────────────────────────────
  Future<void> _downloadAudio() async {
    if (_videoInfo == null) return;

    setState(() {
      _phase = 'download_audio';
      _audioProgress = DownloadProgress(videoId: _videoInfo!.id, title: _videoInfo!.title, status: DownloadStatus.fetchingInfo);
    });

    final stream = _svc.downloadAudio(_videoInfo!.id);
    _audioSub = stream.listen((progress) {
      if (!mounted) return;
      setState(() => _audioProgress = progress);

      if (progress.status == DownloadStatus.completed && progress.savedPath != null) {
        context.read<PlayerProvider>().loadSong(
          path: progress.savedPath!,
          title: progress.title,
          autoPlay: true,
        );
        Navigator.pop(context, progress.savedPath);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã tải và phát audio')),
        );
      } else if (progress.status == DownloadStatus.failed) {
        setState(() {
          _errorMessage = progress.errorMessage;
          _phase = 'error';
        });
      }
    });
  }

  // ── Step 2B: Download Captions ───────────────────────────
  Future<void> _downloadCaptions() async {
    if (_videoInfo == null) return;

    setState(() {
      _isFetchingCaptions = true;
      _phase = 'download_caption';
    });

    try {
      // Ensure langs are fetched if not yet
      if (_availableLangs.isEmpty) {
        final langs = await _svc.getAvailableLanguages(_urlCtrl.text);
        if (langs.isEmpty) {
           throw Exception('Video không có phụ đề');
        }
        _availableLangs = langs;
        // Pick lang logic
      }

      final captions = await _svc.fetchCaptions(_videoInfo!.id, languageCode: _selectedLang);
      
      if (captions.isEmpty) throw Exception('Không tải được phụ đề $_selectedLang');

      final lrcPath = await _svc.saveCaptionsAsLrc(captions, _videoInfo!);
      
      if (mounted) {
        context.read<TextProvider>().loadTextFile(lrcPath!);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã tải và mở phụ đề')),
        );
      }

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _phase = 'error';
        _isFetchingCaptions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.download_for_offline, color: Color(0xFFFF0000), size: 28),
              const SizedBox(width: 12),
              const Text('YouTube Downloader',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Body based on phase
          if (_phase == 'input') _buildInput(),
          if (_phase == 'info') _buildInfo(),
          if (_phase == 'download_audio') _buildAudioProgress(),
          if (_phase == 'download_caption') _buildCaptionProgress(),
          if (_phase == 'error') _buildError(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      children: [
        TextField(
          controller: _urlCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Dán link YouTube (youtu.be, shorts...)',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.white.withAlpha(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _fetchInfo,
            ),
          ),
          onSubmitted: (_) => _fetchInfo(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _fetchInfo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Lấy thông tin', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfo() {
    final info = _videoInfo!;
    return Column(
      children: [
        // Video Info Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(info.thumbnailUrl ?? '', width: 80, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => Container(width: 80, height: 60, color: Colors.grey[800]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2),
                    Text(info.author, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            Expanded(
              child: _OptionBtn(
                icon: Icons.headphones,
                label: 'Tải Audio',
                color: const Color(0xFF6C63FF),
                onTap: _downloadAudio,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OptionBtn(
                icon: Icons.subtitles,
                label: 'Tải Lyrics',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  if (_availableLangs.isEmpty) {
                    // Fetch langs first if not yet (when started from Audio side)
                    setState(() => widget.captionsFirst ? null : null); // trigger rebuild/fetch logic if needed
                    // Simple hack: call _downloadCaptions which will fetch langs if empty
                  }
                  _downloadCaptions();
                },
              ),
            ),
          ],
        ),
        
        if (widget.captionsFirst && _availableLangs.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedLang,
            dropdownColor: const Color(0xFF2A2A3E),
            items: _availableLangs.map((l) => DropdownMenuItem(
              value: l.code,
              child: Text(l.name, style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedLang = v!),
            decoration: const InputDecoration(labelText: 'Ngôn ngữ phụ đề'),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioProgress() {
    final p = _audioProgress;
    return Column(
      children: [
        const CircularProgressIndicator(color: Color(0xFF6C63FF)),
        const SizedBox(height: 16),
        Text(p?.status == DownloadStatus.downloading ? 'Đang tải audio...' : 'Đang xử lý...',
            style: const TextStyle(color: Colors.white)),
        if (p != null) Text(p.progressText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildCaptionProgress() {
    return const Column(
      children: [
        CircularProgressIndicator(color: Color(0xFF4CAF50)),
        SizedBox(height: 16),
        Text('Đang tải phụ đề...', style: TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(_errorMessage ?? 'Lỗi không xác định',
            style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => setState(() => _phase = 'input'),
          child: const Text('Thử lại'),
        ),
      ],
    );
  }
}

class _OptionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(76)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}