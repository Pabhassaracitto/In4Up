// YT-MY-CHANNELS-001 (#1 owner 2026-10-28) — "Kênh của tôi".
//
// Owner đồng ý: KHÔNG đăng nhập YouTube (không khả thi + vi phạm ToS), thay
// bằng người dùng dán `@handle`/URL kênh, app lưu ở máy và liệt kê video mới
// bằng đường không cần API key. Kèm import OPML (Google Takeout) để ai đã có
// danh sách subscription không phải dán từng cái.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;

import '../models/yt_channel.dart';
import '../services/yt_channel_resolver.dart';
import '../services/yt_channel_store.dart';
import '../services/yt_initial_data_parser.dart';
import '../services/yt_search_service.dart';
import '../youtube_explorer_screen.dart' show YtExVideo;
import '../yt_player_screen.dart';

Future<void> showYtMyChannelsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _YtMyChannelsSheet(),
  );
}

class _YtMyChannelsSheet extends StatefulWidget {
  const _YtMyChannelsSheet();

  @override
  State<_YtMyChannelsSheet> createState() => _YtMyChannelsSheetState();
}

class _YtMyChannelsSheetState extends State<_YtMyChannelsSheet> {
  final _ctrl = TextEditingController();
  List<YtChannel>? _channels;
  bool _busy = false;
  String? _busyLabel;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await YtChannelStore.instance.load();
    if (!mounted) return;
    setState(() => _channels = list);
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.uiText(msg)),
      backgroundColor: color ?? const Color(0xFF1A237E),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _add() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty || _busy) return;
    // Nhận diện TRƯỚC khi gọi mạng: dán link video vào ô kênh là lỗi hay gặp.
    if (parseYtChannelInput(input) == null) {
      _snack('Đây là link video, không phải kênh — dán link kênh hoặc @handle',
          color: Colors.orange.shade800);
      return;
    }
    setState(() {
      _busy = true;
      _busyLabel = 'Đang tìm kênh...';
    });
    final channel = await YtChannelResolver.instance.resolve(input);
    if (!mounted) return;
    if (channel == null) {
      setState(() {
        _busy = false;
        _busyLabel = null;
      });
      _snack('Không tìm được kênh này — kiểm tra lại @handle hoặc link',
          color: Colors.red.shade700);
      return;
    }
    final isNew = await YtChannelStore.instance.add(channel);
    if (!mounted) return;
    _ctrl.clear();
    setState(() {
      _busy = false;
      _busyLabel = null;
    });
    await _reload();
    // Chuỗi có nội suy phải là TEMPLATE `{value0}` (không phải `$...`) để
    // `uiText` dịch được sang ngôn ngữ khác — xem chuỗi cùng khoá trong
    // `tool/legacy_ui_english_overrides.json`.
    _snack(
      isNew
          ? 'Đã thêm kênh "{value0}"'
              .replaceAll('{value0}', channel.displayTitle)
          : 'Kênh này đã có trong danh sách',
      color: isNew ? const Color(0xFF2E7D32) : null,
    );
  }

  /// Import OPML (Google Takeout `subscription_manager.opml`).
  ///
  /// Vì sao có: người dùng đã có sẵn 50–200 kênh đang theo dõi trên YouTube;
  /// bắt dán từng cái là không tinh tế. File OPML chỉ là XML, đọc tại máy.
  Future<void> _importOpml() async {
    if (_busy) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['opml', 'xml', 'txt'],
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      setState(() {
        _busy = true;
        _busyLabel = 'Đang đọc file...';
      });
      final xml = await File(path).readAsString();
      final parsed = parseYtOpml(xml);
      if (parsed.isEmpty) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
        _snack(
            'File này không có kênh YouTube nào (cần file OPML xuất từ Takeout)',
            color: Colors.orange.shade800);
        return;
      }
      final added = await YtChannelStore.instance.addAll(parsed.map(
        (c) => YtChannel(id: c.channelId, title: c.title),
      ));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
      });
      await _reload();
      _snack(
        added == 0
            ? 'Cả {value0} kênh trong file đều đã có trong danh sách'
                .replaceAll('{value0}', '${parsed.length}')
            : 'Đã thêm {value0} kênh từ file (mới: {value1})'
                .replaceAll('{value0}', '${parsed.length}')
                .replaceAll('{value1}', '$added'),
        color: const Color(0xFF2E7D32),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
      });
      _snack('Không đọc được file: chỉ hỗ trợ .opml/.xml xuất từ Takeout',
          color: Colors.red.shade700);
    }
  }

  Future<void> _remove(YtChannel c) async {
    await YtChannelStore.instance.remove(c.id);
    await _reload();
    _snack('Đã bỏ theo dõi');
  }

  Future<void> _openChannel(YtChannel c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ChannelVideosSheet(channel: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        top: false,
        child: Padding(
          // Bàn phím mở ⇒ đẩy nội dung lên, không che ô nhập.
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                child: Row(
                  children: [
                    const Icon(Icons.subscriptions_outlined,
                        size: 18, color: Color(0xFF53D6BD)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.uiText('Kênh của tôi'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: context.uiText('Nhập từ file OPML (Takeout)'),
                      onPressed: _busy ? null : _importOpml,
                      icon: const Icon(Icons.file_upload_outlined, size: 19),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.uiText(
                      'Không cần đăng nhập Google. Dán @handle hoặc link kênh, app lưu ở máy và lấy video mới bằng đường không cần API key.'),
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 10.5, height: 1.35),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        onSubmitted: (_) => _add(),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText:
                              context.uiText('@handle hoặc link kênh...'),
                          hintStyle: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _add,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF53D6BD),
                        foregroundColor: const Color(0xFF0D1117),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.uiText('Thêm'),
                              style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              if (_busy && _busyLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.uiText(_busyLabel!),
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ),
              const SizedBox(height: 8),
              Flexible(child: _buildList(channels)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<YtChannel>? channels) {
    if (channels == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (channels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subscriptions_outlined,
                size: 34, color: Colors.grey[700]),
            const SizedBox(height: 10),
            Text(
              context.uiText(
                  'Chưa theo dõi kênh nào. Dán @handle ở trên, hoặc nhập file OPML từ Google Takeout.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: channels.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, i) {
        final c = channels[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.play_circle_outline,
              color: Color(0xFF53D6BD), size: 20),
          title: Text(
            c.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            c.handle ?? c.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
          onTap: () => _openChannel(c),
          trailing: IconButton(
            tooltip: context.uiText('Bỏ theo dõi'),
            onPressed: () => _remove(c),
            icon: const Icon(Icons.remove_circle_outline,
                size: 18, color: Colors.redAccent),
          ),
        );
      },
    );
  }
}

/// Danh sách video mới nhất của MỘT kênh đã theo dõi.
class _ChannelVideosSheet extends StatefulWidget {
  const _ChannelVideosSheet({required this.channel});
  final YtChannel channel;

  @override
  State<_ChannelVideosSheet> createState() => _ChannelVideosSheetState();
}

class _ChannelVideosSheetState extends State<_ChannelVideosSheet> {
  List<YtSearchHit>? _hits;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _hits = null;
      _error = null;
    });
    try {
      final hits = await YtSearchService.instance
          .fetchChannelVideos(widget.channel.id, maxResults: 30);
      if (!mounted) return;
      setState(() => _hits = hits);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.channel.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                ],
              ),
            ),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          context.uiText('Không lấy được video của kênh này'),
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
        ),
      );
    }
    final hits = _hits;
    if (hits == null) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          context.uiText(
              'Kênh chưa có video công khai, hoặc YouTube đang chặn đọc (thử lại sau).'),
          style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final h = hits[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: h.thumb == null
              ? const Icon(Icons.play_circle_outline,
                  color: Colors.white38, size: 22)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    h.thumb!,
                    width: 52,
                    height: 30,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white38,
                        size: 22),
                  ),
                ),
          title: Text(
            h.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
          subtitle: h.duration == null
              ? null
              : Text(
                  '${h.duration!.inMinutes}m${(h.duration!.inSeconds % 60).toString().padLeft(2, '0')}s',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => YtPlayerScreen(
                  video: YtExVideo(
                    id: h.id,
                    title: h.title,
                    channelId: widget.channel.id,
                    channelTitle: h.channel.isEmpty
                        ? widget.channel.displayTitle
                        : h.channel,
                    thumb: h.thumb,
                    duration: h.duration,
                    viewCount: h.viewCount,
                    publishedAt: h.publishedAt,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
