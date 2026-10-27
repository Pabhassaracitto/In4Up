import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import 'legacy_audio_data_button.dart';

/// The queue belongs to the player session; this sheet is only a view of it.
Future<void> showPlaybackQueueSheet(BuildContext context) {
  final player = context.read<PlayerProvider>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF151E30),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ChangeNotifierProvider<PlayerProvider>.value(
      value: player,
      child: const PlaybackQueueSheet(),
    ),
  );
}

class PlaybackQueueSheet extends StatelessWidget {
  const PlaybackQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final items = player.queueItems;
    final failed = player.queueFailedIndices;
    final index = player.isQueueLoading ? player.queueCursor : player.queueIndex;
    final progress = index < 0 ? 0 : index + 1;
    return SafeArea(
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .72).clamp(200.0, 620.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.uiText('Danh sách đang phát'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text('$progress/${items.length}',
                      style: const TextStyle(color: Colors.white70)),
                  LegacyAudioDataButton(player: player),
                  IconButton(
                    tooltip: context.uiText('Đóng'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        context.uiText('Chưa có bài trong danh sách phát'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = index == player.queueIndex &&
                            player.currentSongPath != null;
                        final loading = player.isQueueLoading &&
                            index == player.queueCursor;
                        final unavailable = failed.contains(index) || item.isMissing;
                        final subtitle = unavailable
                            ? context.uiText(item.isMissing
                                ? 'Bài không còn trong thư viện'
                                : 'Không phát được bài này')
                            : item.artist;
                        return ListTile(
                          key: ValueKey('queue-item-$index'),
                          selected: selected,
                          selectedTileColor: const Color(0x266C63FF),
                          leading: SizedBox(
                            width: 32,
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  )
                                : selected
                                    ? const Icon(Icons.graphic_eq,
                                        color: Color(0xFF9D96FF))
                                    : unavailable
                                        ? const Icon(Icons.error_outline,
                                            color: Colors.orangeAccent)
                                        : Center(
                                            child: Text('${index + 1}',
                                                style: const TextStyle(
                                                    color: Colors.white60)),
                                          ),
                          ),
                          title: material.Text(item.isMissing
                              ? context.uiText('Bài không còn trong thư viện')
                              : item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: subtitle == null || subtitle.isEmpty
                              ? null
                              : material.Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60)),
                          onTap: () => player.selectQueueItem(index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
