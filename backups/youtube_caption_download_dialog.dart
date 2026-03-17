//
// Dialog tích hợp vào TextLibraryDrawer:
//  - Dán URL → fetch video info + danh sách ngôn ngữ
//  - Download captions → convert → .lrc file
//  - Load ngay vào TextProvider (Understand Mode)
//  - Hoặc chỉ lưu file .lrc xuống máy

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../lib/providers/text_provider.dart';
import 'youtube_download_service.dart';

class YoutubeCaptionDownloadDialog extends StatefulWidget {
  const YoutubeCaptionDownloadDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TextProvider>(),
        child: const YoutubeCaptionDownloadDialog(),
      ),
    );
  }

  @override
  State<YoutubeCaptionDownloadDialog> createState() =>
      _YoutubeCaptionDownloadDialogState();
}

class _YoutubeCaptionDownloadDialogState
    extends State<YoutubeCaptionDownloadDialog> {
  final _urlCtrl = TextEditingController();
  final _svc = YoutubeDownloadService();

  String _phase = 'input'; // input | info | fetching | done | error

  YtVideoInfo? _videoInfo;
  List<YtCaptionLine> _captions = [];
  List<({String code, String name})> _availableLangs = [];
  String _selectedLang = 'en';
  bool _isFetchingLangs = false;
  bool _isFetchingCaptions = false;
  String? _savedLrcPath;
  String? _errorMessage;

  final _langOptions = [
    ('en', '🇺🇸 English'),
    ('vi', '🇻🇳 Tiếng Việt'),
    ('zh-Hans', '🇨🇳 中文 (Giản thể)'),
    ('zh-Hant', '🇹🇼 中文 (Phồn thể)'),
    ('ja', '🇯🇵 日本語'),
    ('ko', '🇰🇷 한국어'),
    ('fr', '🇫🇷 Français'),
    ('de', '🇩🇪 Deutsch'),
    ('es', '🇪🇸 Español'),
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: Fetch video info ──────────────────────────────

  Future<void> _fetchInfo() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _phase = 'info';
      _errorMessage = null;
      _videoInfo = null;
      _availableLangs = [];
      _isFetchingLangs = true;
    });

    try {
      // Fetch video info + available languages in parallel
      final results = await Future.wait([
        _svc.fetchVideoInfo(url),
        _svc.getAvailableLanguages(url),
      ]);

      if (!mounted) return;

      final info = results[0] as YtVideoInfo?;
      final langs = results[1] as List<({String code, String name})>;

      if (info == null) {
        setState(() {
          _errorMessage =
              'Không tải được thông tin video.\nKiểm tra URL và kết nối mạng.';
          _phase = 'error';
        });
        return;
      }

      setState(() {
        _videoInfo = info;
        _availableLangs = langs;
        _isFetchingLangs = false;
        _phase = 'info';

        // Tự chọn 'en' nếu có, nếu không chọn cái đầu
        if (langs.isNotEmpty && !langs.any((l) => l.code == _selectedLang)) {
          _selectedLang = langs.first.code;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _phase = 'error';
      });
    }
  }

  // ── Step 2: Download captions ─────────────────────────────

  Future<void> _downloadCaptions() async {
    if (_videoInfo == null) return;

    setState(() {
      _isFetchingCaptions = true;
      _phase = 'fetching';
    });

    try {
      final captions = await _svc.fetchCaptions(
        _videoInfo!.id,
        languageCode: _selectedLang,
      );

      if (!mounted) return;

      if (captions.isEmpty) {
        setState(() {
          _errorMessage = 'Không có captions cho ngôn ngữ "$_selectedLang".\n'
              'Thử chọn ngôn ngữ khác hoặc video không có phụ đề.';
          _phase = 'error';
          _isFetchingCaptions = false;
        });
        return;
      }

      // Lưu .lrc file
      final lrcPath = await _svc.saveCaptionsAsLrc(captions, _videoInfo!);

      setState(() {
        _captions = captions;
        _savedLrcPath = lrcPath;
        _isFetchingCaptions = false;
        _phase = 'done';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi tải captions: $e';
        _phase = 'error';
        _isFetchingCaptions = false;
      });
    }
  }

  // ── Load into TextProvider ────────────────────────────────

  void _loadIntoTextStudio(BuildContext ctx) {
    if (_captions.isEmpty || _videoInfo == null) return;

    final plain = _captions.map((c) => c.text).join('\n');
    ctx.read<TextProvider>().loadText(plain, title: _videoInfo!.title);

    Navigator.pop(context);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('✅ Loaded "${_videoInfo!.title}" vào Text Studio'),
      backgroundColor: const Color(0xFF2196F3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _loadLrcIntoSyncMode(BuildContext ctx) {
    if (_savedLrcPath == null) return;

    ctx.read<TextProvider>().loadTextFile(_savedLrcPath!);

    Navigator.pop(context);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content:
          const Text('✅ LRC loaded — dùng được trong Understand Mode (sync)'),
      backgroundColor: const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _reset() {
    setState(() {
      _phase = 'input';
      _videoInfo = null;
      _captions = [];
      _availableLangs = [];
      _savedLrcPath = null;
      _errorMessage = null;
      _urlCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(Icons.subtitles, color: Color(0xFF2196F3), size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tải Lyrics / Captions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('YouTube → LRC với timestamps',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
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
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case 'input':
        return _buildInputPhase();
      case 'info':
        return _buildInfoPhase();
      case 'fetching':
        return _buildFetchingPhase();
      case 'done':
        return _buildDonePhase();
      case 'error':
        return _buildErrorPhase();
      default:
        return _buildInputPhase();
    }
  }

  // ── Phase: Input ─────────────────────────────────────────

  Widget _buildInputPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // URL field
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.link, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Dán URL YouTube vào đây...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (_) => _fetchInfo(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.content_paste,
                    color: Colors.grey, size: 18),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _urlCtrl.text = data!.text!.trim();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Language selector
        Row(
          children: [
            const Text('Ngôn ngữ:',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _langOptions.take(5).map((opt) {
                    final isSelected = _selectedLang == opt.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedLang = opt.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2196F3)
                              : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _fetchInfo,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Tìm kiếm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Phase: Show info ──────────────────────────────────────

  Widget _buildInfoPhase() {
    final info = _videoInfo;
    if (info == null || _isFetchingLangs) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF2196F3))),
            SizedBox(height: 12),
            Text('Đang lấy thông tin...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Video card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: info.thumbnailUrl != null
                    ? Image.network(
                        info.thumbnailUrl!,
                        width: 72,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title.length > 55
                          ? '${info.title.substring(0, 53)}...'
                          : info.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 3),
                    Text('${info.author} · ${info.formattedDuration}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Available languages (nếu có)
        if (_availableLangs.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.subtitles_outlined,
                  size: 14, color: Color(0xFF4CAF50)),
              const SizedBox(width: 6),
              Text(
                '${_availableLangs.length} ngôn ngữ có sẵn:',
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _availableLangs.map((l) {
                final isSelected = _selectedLang == l.code;
                return GestureDetector(
                  onTap: () => setState(() => _selectedLang = l.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          isSelected ? null : Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      l.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: Colors.amber),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Không tìm thấy captions. Thử tải thử — YouTube có thể có auto-captions.',
                    style: TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('← Quay lại',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _downloadCaptions,
                icon: const Icon(Icons.download, size: 16),
                label: Text('Tải captions ($_selectedLang)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Phase: Fetching captions ──────────────────────────────

  Widget _buildFetchingPhase() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF4CAF50)),
          ),
          SizedBox(height: 16),
          Text('Đang tải captions...', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 6),
          Text('Có thể mất vài giây',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Phase: Done ───────────────────────────────────────────

  Widget _buildDonePhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          '${_captions.length} dòng captions đã tải!',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _videoInfo?.title ?? '',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),

        // Preview 3 lines
        if (_captions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _captions.take(3).map((c) {
                final mm =
                    c.start.inMinutes.remainder(60).toString().padLeft(2, '0');
                final ss =
                    c.start.inSeconds.remainder(60).toString().padLeft(2, '0');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$mm:$ss ',
                          style: const TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 10,
                              fontFamily: 'monospace')),
                      Expanded(
                        child: Text(
                          c.text,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Action buttons
        const Text('Dùng captions này:',
            style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.menu_book,
                label: 'Text Studio',
                color: const Color(0xFF2196F3),
                onTap: () => _loadIntoTextStudio(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.sync,
                label: 'Sync Mode',
                color: const Color(0xFF4CAF50),
                onTap: () => _loadLrcIntoSyncMode(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // File path info
        if (_savedLrcPath != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.save_alt, size: 12, color: Color(0xFF6C63FF)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lưu: ${_savedLrcPath!.split('/').last}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _reset,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tải video khác',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // ── Phase: Error ──────────────────────────────────────────

  Widget _buildErrorPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Đã xảy ra lỗi',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 72,
        height: 50,
        color: Colors.grey[900],
        child:
            const Icon(Icons.play_circle_outline, color: Colors.grey, size: 24),
      );
}

// ── Helper widget ─────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
