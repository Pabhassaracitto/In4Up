import 'dart:async';
import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/cabin_session.dart';
import '../services/cabin_read_bridge.dart';
import '../services/cabin_session_store.dart';
import '../services/stts_cabin_service.dart';
import '../widgets/cabin_save_sheet.dart';

/// CABIN-SAVE-001 — danh sách phiên Cabin đã lưu / chưa lưu: nghe lại, mở
/// trong Tab Đọc, chia sẻ, đổi tên, xoá.
class CabinSessionsScreen extends StatefulWidget {
  const CabinSessionsScreen({super.key});

  @override
  State<CabinSessionsScreen> createState() => _CabinSessionsScreenState();
}

class _CabinSessionsScreenState extends State<CabinSessionsScreen> {
  final _store = CabinSessionStore.instance;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  List<CabinSession>? _sessions;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingId = null);
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final activeId = SttsCabinService().sessionRecorder?.session.id;
    await _store.recoverInterrupted(activeId: activeId);
    final list = await _store.list(excludeId: activeId);
    if (mounted) setState(() => _sessions = list);
  }

  Future<void> _togglePlay(CabinSession s) async {
    if (_playingId == s.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    try {
      await _player.stop();
      await _player.setFilePath(s.audioPath);
      setState(() => _playingId = s.id);
      unawaited(_player.play());
    } catch (e) {
      debugPrint('⚠️ CabinSessionsScreen play: $e');
      if (mounted) setState(() => _playingId = null);
    }
  }

  Future<void> _rename(CabinSession s) async {
    final ctrl = TextEditingController(text: s.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.uiText('Đổi tên')),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.uiText('Huỷ')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(ctx.uiText('Lưu')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (title == null || title.trim().isEmpty) return;
    await _store.rename(s, title.trim());
    await _reload();
  }

  Future<void> _delete(CabinSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.uiText('Xoá phiên này?')),
        content: Text(s.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.uiText('Huỷ')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.uiText('Xoá')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_playingId == s.id) await _player.stop();
    await _store.delete(s);
    await _reload();
  }

  Future<void> _openRead(CabinSession s) async {
    await _player.stop();
    if (!mounted) return;
    final ok = await CabinReadBridge.openInRead(context, s);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.uiText('Không mở được văn bản trong Tab Đọc')),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _finishUnsaved(CabinSession s) async {
    await handleFinishedCabinSession(context, s);
    await _reload();
  }

  String _fmtDate(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A32),
        title: Text(context.uiText('Phiên đã lưu')),
      ),
      body: sessions == null
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
              ? Center(
                  child: Text(
                    context.uiText('Chưa có phiên nào'),
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tile(sessions[i]),
                  ),
                ),
    );
  }

  Widget _tile(CabinSession s) {
    final hasAudio = s.hasAudio && File(s.audioPath).existsSync();
    final hasText = File(s.lrcPath).existsSync();
    final playing = _playingId == s.id;
    final unsaved = s.status != CabinSessionStatus.saved;
    return Card(
      color: const Color(0xFF141A32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (unsaved)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      context.uiText('Chưa lưu'),
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ),
                PopupMenuButton<String>(
                  iconColor: Colors.white70,
                  onSelected: (v) {
                    switch (v) {
                      case 'rename':
                        _rename(s);
                      case 'share':
                        shareCabinSession(s);
                      case 'delete':
                        _delete(s);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                        value: 'rename', child: Text(ctx.uiText('Đổi tên'))),
                    PopupMenuItem(
                        value: 'share', child: Text(ctx.uiText('Chia sẻ'))),
                    PopupMenuItem(
                        value: 'delete', child: Text(ctx.uiText('Xoá'))),
                  ],
                ),
              ],
            ),
            Text(
              '${_fmtDate(s.createdAt)} · ${s.sourceLang.toUpperCase()}→'
              '${s.targetLang.toUpperCase()} · ${cabinFmtDuration(s.duration)}'
              ' · ${s.entryCount}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                if (hasAudio)
                  TextButton.icon(
                    onPressed: () => _togglePlay(s),
                    icon: Icon(playing
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline_rounded),
                    label: Text(context.uiText(playing ? 'Dừng nghe' : 'Nghe lại')),
                  ),
                if (hasText)
                  TextButton.icon(
                    onPressed: () => _openRead(s),
                    icon: const Icon(Icons.chrome_reader_mode_outlined),
                    label: Text(context.uiText('Mở trong Tab Đọc')),
                  ),
                if (unsaved)
                  TextButton.icon(
                    onPressed: () => _finishUnsaved(s),
                    icon: const Icon(Icons.save_alt_rounded),
                    label: Text(context.uiText('Lưu')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
