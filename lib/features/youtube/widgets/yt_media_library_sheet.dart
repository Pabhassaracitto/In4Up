// YT-MEDIA-STORE-001 — "Thư viện đã tải" của chế độ YouTube.
//
// Owner (2026-10-24): tải phụ đề xong thì file nằm ở `.../youtube_captions/`
// nhưng **không biết lấy lại bằng cách nào**, cũng không biết chiếm bao nhiêu
// bộ nhớ để dọn. Bảng này trả lời đúng ba câu đó:
//   1. Đã tải những video nào, file ở đâu, nặng bao nhiêu.
//   2. Xoá từng video / xoá hết khi sắp đầy bộ nhớ.
//   3. Nạp lại vào tab Đọc (phụ đề + âm thanh cùng lúc nếu có đủ cặp).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:share_plus/share_plus.dart';

import '../models/yt_learning_settings.dart';
import '../services/yt_media_store.dart';
import '../services/yt_read_bridge.dart';

Future<void> showYtMediaLibrarySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _YtMediaLibrarySheet(),
  );
}

class _YtMediaLibrarySheet extends StatefulWidget {
  const _YtMediaLibrarySheet();

  @override
  State<_YtMediaLibrarySheet> createState() => _YtMediaLibrarySheetState();
}

class _YtMediaLibrarySheetState extends State<_YtMediaLibrarySheet> {
  List<YtMediaItem>? _items;
  int _total = 0;
  String _folder = '';
  YtSaveLocation _location = YtSaveLocation.appPrivate;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final settings = YtMediaStore.loadLocationSetting();
    final folder = await YtMediaStore.displayFolder();
    final items = await YtMediaStore.list();
    final total = items.fold<int>(0, (s, i) => s + i.bytes);
    if (!mounted) return;
    setState(() {
      _items = items;
      _total = total;
      _folder = folder;
      _location = settings;
    });
  }

  String _size(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
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

  Future<void> _open(YtMediaItem item) async {
    // YT-RD-CRASH-001: giữ messenger + chuỗi đã dịch TRƯỚC khi nạp, vì cầu
    // nối kết thúc bằng `popUntil(route.isFirst)` ⇒ sheet bị unmount và
    // `_snack()` (guard `mounted`) sẽ im lặng.
    final messenger = ScaffoldMessenger.of(context);
    final msgNoCaptions = context.uiText('Video này chưa có phụ đề đã lưu');
    final msgFail = context.uiText('Không nạp được vào tab Đọc');
    final msgAudioFail =
        context.uiText('Đã nạp phụ đề, nhưng file âm thanh không mở được');

    void show(String msg, Color color) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    }

    final result = await YtReadBridge.openInRead(context, item);
    if (!result.ok) {
      final base = result.reason == 'no_captions' ? msgNoCaptions : msgFail;
      show(
        result.reason == 'exception' && result.detail != null
            ? '$base (${result.detail})'
            : base,
        Colors.red.shade700,
      );
      return;
    }
    if (!result.loadedAudio && item.audioPath != null) {
      show(msgAudioFail, Colors.orange.shade800);
    }
  }

  Future<void> _share(YtMediaItem item) async {
    final files = <XFile>[];
    for (final p in [item.audioPath, item.lrcPath]) {
      if (p != null && await File(p).exists()) files.add(XFile(p));
    }
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: files, subject: item.title),
    );
  }

  Future<void> _delete(YtMediaItem item) async {
    setState(() => _busyId = item.videoId);
    await YtMediaStore.deleteItem(item);
    await _reload();
    if (mounted) setState(() => _busyId = null);
    _snack('Đã xoá');
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(context.uiText('Xoá tất cả file đã tải?')),
        content: Text(
          context.uiText(
              'Toàn bộ phụ đề và âm thanh đã tải trong chế độ YouTube sẽ bị xoá khỏi máy.'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.uiText('Huỷ')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.uiText('Xoá hết')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await YtMediaStore.deleteAll();
    await _reload();
    _snack('Đã xoá tất cả');
  }

  Future<void> _changeLocation(YtSaveLocation next) async {
    await YtMediaStore.setLocation(next);
    await _reload();
    final reason = YtMediaStore.lastFallbackReason;
    if (next == YtSaveLocation.externalDownloads && reason != null) {
      // Nói THẬT: Android 11+ có thể chặn, đừng để người dùng tưởng đã đổi.
      _snack(
        'Hệ thống không cho ghi ra thư mục công khai — vẫn lưu trong bộ nhớ của app',
        color: Colors.orange.shade800,
      );
    } else {
      _snack('Đã đổi nơi lưu');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
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
                  const Icon(Icons.folder_special,
                      size: 18, color: Color(0xFF53D6BD)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.uiText('Thư viện đã tải'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if ((_items?.isNotEmpty ?? false))
                    IconButton(
                      tooltip: context.uiText('Xoá hết'),
                      onPressed: _deleteAll,
                      icon: const Icon(Icons.delete_sweep,
                          size: 20, color: Colors.redAccent),
                    ),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
            ),
            // ── Dung lượng + nơi lưu ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.uiText('Tổng dung lượng')}: ${_size(_total)}'
                      ' · ${_items?.length ?? 0} ${context.uiText('video')}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _folder,
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.uiText('Nơi lưu phụ đề và âm thanh đã tải'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 10.5),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(
                            context.uiText('Bộ nhớ riêng của app (an toàn)'),
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          selected: _location == YtSaveLocation.appPrivate,
                          selectedColor:
                              const Color(0xFF53D6BD).withValues(alpha: 0.2),
                          onSelected: (_) =>
                              _changeLocation(YtSaveLocation.appPrivate),
                        ),
                        ChoiceChip(
                          label: Text(
                            context.uiText('Thư mục công khai (dễ tìm)'),
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          selected:
                              _location == YtSaveLocation.externalDownloads,
                          selectedColor:
                              const Color(0xFF53D6BD).withValues(alpha: 0.2),
                          onSelected: (_) =>
                              _changeLocation(YtSaveLocation.externalDownloads),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ── Danh sách ────────────────────────────────────────
            Expanded(child: _buildList()),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.uiText(
                    'Bấm "Nạp vào tab Đọc" để mở phụ đề (kèm âm thanh nếu đã tải) trong tab Đọc, đồng bộ theo mốc thời gian.'),
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 10, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_outlined,
                  size: 36, color: Colors.grey[700]),
              const SizedBox(height: 10),
              Text(
                context.uiText('Chưa có phụ đề hay âm thanh nào được tải'),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, i) {
        final item = items[i];
        final busy = _busyId == item.videoId;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            item.isComplete
                ? Icons.check_circle_outline
                : (item.hasAudio ? Icons.audiotrack : Icons.subtitles_outlined),
            color: item.isComplete ? const Color(0xFF53D6BD) : Colors.grey,
            size: 20,
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${_size(item.bytes)} · '
            '${item.hasCaptions ? context.uiText('phụ đề') : ''}'
            '${item.hasCaptions && item.hasAudio ? ' + ' : ''}'
            '${item.hasAudio ? context.uiText('âm thanh') : ''}',
            style: TextStyle(color: Colors.grey[500], fontSize: 10.5),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.uiText('Nạp vào tab Đọc'),
                      onPressed:
                          item.hasCaptions ? () => _open(item) : null,
                      icon: const Icon(Icons.menu_book, size: 18),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.uiText('Xuất / chia sẻ'),
                      onPressed: () => _share(item),
                      icon: const Icon(Icons.ios_share, size: 18),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.uiText('Xoá'),
                      onPressed: () => _delete(item),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
