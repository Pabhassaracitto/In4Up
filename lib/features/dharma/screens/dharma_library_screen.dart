// lib/features/dharma/screens/dharma_library_screen.dart
//
// PLAN-042 P1 — màn danh mục pháp thoại (3 nhóm: Nghe tiếp / Theo Thầy / Theo khoá).
//
// NGUYÊN TẮC UI:
//  * Không tạo trình phát riêng — mọi lần phát đi qua `DharmaProvider.playEpisode`
//    → `PlayerProvider.startQueue` (queue PLAN-039 ⇒ có bài trước/sau).
//  * Chrome dùng `uiText(...)` (rule #5). NỘI DUNG (tên bài, tên Thầy, chủ đề
//    Pāḷi) KHÔNG dịch — giữ nguyên nguồn.
//  * Màn hẹp 360×640: danh sách dùng ListView, không cột cố định, không tràn.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../models/dharma_talk.dart';
import '../services/dharma_provider.dart';
import '../services/dharma_scanner.dart';

const Color _bg = Color(0xFF0D1520);
const Color _card = Color(0xFF1A2332);
const Color _accent = Color(0xFF8D7BFF);

class DharmaLibraryScreen extends StatefulWidget {
  const DharmaLibraryScreen({super.key});

  @override
  State<DharmaLibraryScreen> createState() => _DharmaLibraryScreenState();
}

class _DharmaLibraryScreenState extends State<DharmaLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dharma = context.watch<DharmaProvider>();
    if (!dharma.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final children = <Widget>[
      _ContinueTab(dharma: dharma),
      _SpeakerTab(dharma: dharma),
      _SeriesTab(dharma: dharma),
    ];

    return Container(
      color: _bg,
      child: Column(
        children: [
          _Header(dharma: dharma),
          if (dharma.error != null) _ErrorBanner(dharma: dharma),
          if (!dharma.hasSource)
            Expanded(child: _NoSourcePanel(dharma: dharma))
          else ...[
            TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: _accent,
              tabs: [
                Tab(text: context.uiText('Nghe tiếp')),
                Tab(text: context.uiText('Theo Thầy')),
                Tab(text: context.uiText('Theo khoá')),
              ],
            ),
            Expanded(
              child: TabBarView(controller: _tabs, children: children),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DharmaProvider dharma;
  const _Header({required this.dharma});

  @override
  Widget build(BuildContext context) {
    final done = dharma.completedCount;
    final total = dharma.episodeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.self_improvement, color: _accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.uiText('Pháp thoại'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (total > 0)
                  Text(
                    context.uiText('{done}/{total} buổi đã nghe xong')
                        .replaceAll('{done}', '$done')
                        .replaceAll('{total}', '$total'),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (dharma.isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: context.uiText('Quét lại thư mục'),
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
              onPressed: () => dharma.rescan(),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final DharmaProvider dharma;
  const _ErrorBanner({required this.dharma});

  @override
  Widget build(BuildContext context) {
    final code = dharma.error ?? '';
    final message = switch (code) {
      'empty' => 'Không tìm thấy file audio trong thư mục này',
      'no_source' => 'Chưa chọn thư mục pháp thoại',
      'unsupported' => 'Chọn thư mục chỉ hỗ trợ trên Android. Trên máy tính, hãy nhập đường dẫn thư mục.',
      _ => code,
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA726).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFA726).withValues(alpha: 0.4)),
      ),
      child: Text(
        context.uiText(message),
        style: const TextStyle(color: Color(0xFFFFCC80), fontSize: 12),
      ),
    );
  }
}

class _NoSourcePanel extends StatelessWidget {
  final DharmaProvider dharma;
  const _NoSourcePanel({required this.dharma});

  @override
  Widget build(BuildContext context) {
    final saf = dharmaSafSupported;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.folder_open, color: _accent, size: 40),
          const SizedBox(height: 12),
          Text(
            context.uiText('Chọn thư mục chứa pháp thoại'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.uiText(
              'Ứng dụng đọc tên thư mục (vị Thầy, khoá thiền) và tên file '
              '(chủ đề, số buổi) để lập danh mục. Không tải gì lên mạng.',
            ),
            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (saf)
            FilledButton.icon(
              onPressed: () => dharma.pickDeviceFolder(),
              icon: const Icon(Icons.folder, size: 18),
              label: Text(context.uiText('Chọn thư mục trên thiết bị')),
            ),
          const SizedBox(height: 8),
          if (!saf) ...[
            Text(
              context.uiText(
                'Trên máy tính: dùng nút bên dưới để trỏ tới thư mục đã '
                'đồng bộ Sao lưu & Đồng bộ của Drive.',
              ),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pickDesktopFolder(dharma),
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(context.uiText('Chọn thư mục trên thiết bị')),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chọn thư mục trên máy tính (Windows/Linux/macOS) bằng hộp thoại hệ thống.
///
/// Android không đi qua đây (đã có SAF). `file_picker` trả null khi người dùng
/// hủy — không coi là lỗi.
Future<void> _pickDesktopFolder(DharmaProvider dharma) async {
  try {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || path.isEmpty) return;
    await dharma.setDesktopFolder(path);
  } catch (e) {
    debugPrint('[Dharma] chọn thư mục máy tính lỗi: $e');
  }
}

class _ContinueTab extends StatelessWidget {
  final DharmaProvider dharma;
  const _ContinueTab({required this.dharma});

  @override
  Widget build(BuildContext context) {
    final entries = dharma.continueListening();
    if (entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.uiText('Chưa có buổi nào đang nghe dở'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            context.uiText(
              'Mở "Theo Thầy" hoặc "Theo khoá" để chọn một buổi. Vị trí nghe '
              'được lưu theo nội dung, nên đổi nơi lưu file cũng không mất.',
            ),
            style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final progress = entry.progress!;
        return _EpisodeTile(
          series: entry.series,
          episode: entry.episode,
          progress: progress,
          subtitle: _fmt(progress.lastPosition) +
              ' / ' +
              _fmt(progress.duration),
          trailingPercent: progress.listenProgress,
        );
      },
    );
  }
}

class _SpeakerTab extends StatelessWidget {
  final DharmaProvider dharma;
  const _SpeakerTab({required this.dharma});

  @override
  Widget build(BuildContext context) {
    final groups = dharma.speakerGroups();
    if (groups.isEmpty) {
      return Center(
        child: Text(
          context.uiText('Chưa có dữ liệu — chạm ⟳ để quét lại'),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          color: _card,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              group.isUnknown ? context.uiText('Chưa rõ vị Thầy') : group.label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              context.uiText('{series} khoá · {episodes} buổi · {done} xong')
                  .replaceAll('{series}', '${group.seriesCount}')
                  .replaceAll('{episodes}', '${group.episodeCount}')
                  .replaceAll('{done}', '${group.completedCount}'),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DharmaSeriesListScreen(
                    title: group.isUnknown
                        ? context.uiText('Chưa rõ vị Thầy')
                        : group.label,
                    series: dharma.seriesOfSpeaker(group.key),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SeriesTab extends StatelessWidget {
  final DharmaProvider dharma;
  const _SeriesTab({required this.dharma});

  @override
  Widget build(BuildContext context) {
    final series = dharma.series;
    if (series.isEmpty) {
      return Center(
        child: Text(
          context.uiText('Chưa có dữ liệu — chạm ⟳ để quét lại'),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: series.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = series[index];
        final done = dharma.completedIn(s);
        return Card(
          color: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _accent.withValues(alpha: 0.18),
              child: Text(
                s.orderIndex?.toString().padLeft(2, '0') ?? '•',
                style: const TextStyle(color: _accent, fontSize: 12),
              ),
            ),
            title: Text(
              s.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
            subtitle: Text(
              [
                if (s.speakerGroupLabel.isNotEmpty) s.speakerGroupLabel,
                context
                    .uiText('{n} buổi')
                    .replaceAll('{n}', '${s.episodeCount}'),
                if (done > 0) context.uiText('{n} xong').replaceAll('{n}', '$done'),
                if (s.year != null) '${s.year}',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DharmaEpisodeListScreen(series: s),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Danh sách series của một vị Thầy.
class DharmaSeriesListScreen extends StatelessWidget {
  final String title;
  final List<DharmaSeries> series;

  const DharmaSeriesListScreen({
    super.key,
    required this.title,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    final dharma = context.watch<DharmaProvider>();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 15)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: series.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final s = series[index];
          return Card(
            color: _card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(
                s.title,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
              subtitle: Text(
                [
                  context.uiText('{n} buổi').replaceAll('{n}', '${s.episodeCount}'),
                  if (s.venue != null) s.venue!,
                  if (s.year != null) '${s.year}',
                  if (s.language == DharmaLanguage.bilingual)
                    context.uiText('Song ngữ'),
                ].join(' · '),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              trailing: TextButton(
                onPressed: () {
                  final next = dharma.nextEpisodeOf(s);
                  if (next == null) return;
                  dharma.playEpisode(s, next);
                  Navigator.of(context).pop();
                },
                child: Text(context.uiText('Nghe tiếp')),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DharmaEpisodeListScreen(series: s),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Danh sách buổi của một series.
class DharmaEpisodeListScreen extends StatelessWidget {
  final DharmaSeries series;
  const DharmaEpisodeListScreen({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final dharma = context.watch<DharmaProvider>();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Text(
          series.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            tooltip: context.uiText('Sửa tên vị Thầy'),
            icon: const Icon(Icons.edit_note),
            onPressed: () => _editSpeaker(context, dharma),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: series.episodes.length,
        itemBuilder: (context, index) {
          final episode = series.episodes[index];
          final progress = dharma.progressFor(episode.episodeKey);
          return _EpisodeTile(
            series: series,
            episode: episode,
            progress: progress,
            showDate: true,
          );
        },
      ),
    );
  }

  Future<void> _editSpeaker(BuildContext context, DharmaProvider dharma) async {
    final controller =
        TextEditingController(text: series.speakerDisplay ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.uiText('Vị Thầy giảng')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Bản sửa tay được dùng cho mọi lần quét sau.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.uiText('Ví dụ: Sayadaw U Kovida'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(context.uiText('Hủy')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(context.uiText('Lưu')),
          ),
        ],
      ),
    );
    if (value == null) return;
    await dharma.overrideSpeaker(series, value);
  }
}

class _EpisodeTile extends StatelessWidget {
  final DharmaSeries series;
  final DharmaEpisode episode;
  final DharmaProgress? progress;
  final String? subtitle;
  final double? trailingPercent;
  final bool showDate;

  const _EpisodeTile({
    required this.series,
    required this.episode,
    required this.progress,
    this.subtitle,
    this.trailingPercent,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSongPath == episode.source;
    final isCompleted = progress?.isCompleted ?? false;
    final isInProgress = progress?.isInProgress ?? false;

    final label = episode.episodeLabel;
    final cleanTitle = episode.title.isEmpty ? episode.rawName : episode.title;

    String? sub = subtitle;
    if (sub == null) {
      final bits = <String>[];
      if (showDate && episode.confidentDate != null) {
        final d = episode.confidentDate!;
        bits.add('${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}');
      }
      if (episode.durationHintMin != null && !isCompleted) {
        bits.add('~${episode.durationHintMin}′');
      }
      if (episode.housekeeping) bits.add(context.uiText('file phụ'));
      if (episode.episodeEnd != null &&
          episode.episodeStart != null &&
          episode.episodeEnd != episode.episodeStart) {
        bits.add(context.uiText('gộp nhiều buổi'));
      }
      if (bits.isNotEmpty) sub = bits.join(' · ');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: _accent.withValues(alpha: 0.8))
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 34,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (label.isNotEmpty)
                Text(
                  label,
                  style: TextStyle(
                    color: isCompleted ? Colors.white38 : _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (isCompleted)
                const Icon(Icons.check_circle, size: 15, color: Color(0xFF66BB6A))
              else if (isInProgress)
                const Icon(Icons.play_circle_outline, size: 15, color: Colors.white54),
            ],
          ),
        ),
        title: Text(
          cleanTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCompleted ? Colors.white54 : Colors.white,
            fontSize: 13,
            height: 1.25,
          ),
        ),
        subtitle: sub == null
            ? null
            : Text(
                sub,
                style: const TextStyle(color: Colors.white38, fontSize: 10.5),
              ),
        trailing: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.white38),
          onSelected: (value) async {
            final dharma = context.read<DharmaProvider>();
            switch (value) {
              case 'complete':
                await dharma.markCompleted(episode, completed: !isCompleted);
              case 'reset':
                await dharma.resetProgress(episode);
              case 'raw':
                await showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(context.uiText('Tên gốc')),
                    content: SelectableText(episode.rawName),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(context.uiText('Đóng')),
                      ),
                    ],
                  ),
                );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'complete',
              child: Text(
                isCompleted
                    ? context.uiText('Bỏ đánh dấu đã nghe')
                    : context.uiText('Đã nghe xong'),
              ),
            ),
            PopupMenuItem(
              value: 'reset',
              child: Text(context.uiText('Xóa vị trí đã nghe')),
            ),
            PopupMenuItem(
              value: 'raw',
              child: Text(context.uiText('Xem tên gốc')),
            ),
          ],
        ),
        // Không tự đóng màn: người dùng thường muốn chọn buổi khác ngay sau
        // khi bắt đầu nghe (và mini player đã hiện ở shell).
        onTap: () => context.read<DharmaProvider>().playEpisode(series, episode),
      ),
    );
  }
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
