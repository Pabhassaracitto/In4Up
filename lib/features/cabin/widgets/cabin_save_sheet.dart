import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cabin_session.dart';
import '../services/cabin_read_bridge.dart';
import '../services/cabin_session_settings.dart';
import '../services/cabin_session_store.dart';

const _bg = Color(0xFF141A32);
const _accent = Color(0xFF00E676);

String cabinFmtDuration(Duration d) {
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String cabinTextModeLabel(CabinTextMode m) => switch (m) {
      CabinTextMode.bilingual => 'Song ngữ',
      CabinTextMode.source => 'Chỉ câu gốc',
      CabinTextMode.target => 'Chỉ bản dịch',
    };

/// Chia sẻ các file của phiên (WAV + LRC + TXT nếu có).
Future<void> shareCabinSession(CabinSession s) async {
  final files = <XFile>[];
  for (final p in [s.audioPath, s.lrcPath, s.txtPath]) {
    if (await File(p).exists()) files.add(XFile(p));
  }
  if (files.isEmpty) return;
  await SharePlus.instance.share(ShareParams(files: files, subject: s.title));
}

/// CABIN-SAVE-001 — xử lý phiên vừa dừng: tự lưu (nếu bật trong cài đặt)
/// hoặc hiện sheet hỏi lưu.
Future<void> handleFinishedCabinSession(
  BuildContext context,
  CabinSession session,
) async {
  final settings = CabinSessionSettings.instance;
  await settings.ensureLoaded();
  if (!context.mounted) return;
  if (settings.autoSave) {
    final saved = await CabinSessionStore.instance.save(
      session,
      title: session.title,
      textMode: settings.textMode,
    );
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.uiText('Đã lưu phiên Cabin')),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.uiText('Mở trong Tab Đọc'),
          onPressed: () => CabinReadBridge.openInRead(context, saved),
        ),
      ));
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: _bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CabinSaveSheet(session: session, hostContext: context),
  );
}

class CabinSaveSheet extends StatefulWidget {
  final CabinSession session;

  /// Context của màn Cabin (còn sống sau khi sheet đóng) — dùng để mở Tab Đọc
  /// và hiện snackbar.
  final BuildContext hostContext;

  const CabinSaveSheet({
    super.key,
    required this.session,
    required this.hostContext,
  });

  @override
  State<CabinSaveSheet> createState() => _CabinSaveSheetState();
}

class _CabinSaveSheetState extends State<CabinSaveSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.session.title);
  late CabinTextMode _mode = CabinSessionSettings.instance.textMode;
  bool _keepAudio = true;
  bool _keepText = true;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<CabinSession?> _save() {
    return CabinSessionStore.instance.save(
      widget.session,
      title: _title.text,
      textMode: _mode,
      keepAudio: _keepAudio,
      keepText: _keepText,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    final host = widget.hostContext;
    if (!host.mounted) return;
    ScaffoldMessenger.of(host).showSnackBar(SnackBar(
      content: Text(host.uiText(msg)),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final canSave = (s.hasAudio && _keepAudio) || _keepText;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.save_alt_rounded, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText('Lưu phiên Cabin'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                _Stat(icon: Icons.timer_outlined, text: cabinFmtDuration(s.duration)),
                const SizedBox(width: 10),
                _Stat(icon: Icons.notes_rounded, text: '${s.entryCount}'),
              ],
            ),
            if (s.recovered) ...[
              const SizedBox(height: 8),
              Text(
                context.uiText('Phiên khôi phục sau khi ứng dụng bị tắt ngang'),
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.uiText('Tên phiên'),
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: _accent)),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _accent,
              value: s.hasAudio && _keepAudio,
              onChanged: s.hasAudio
                  ? (v) => setState(() => _keepAudio = v)
                  : null,
              title: Text(context.uiText('Giữ ghi âm'),
                  style: const TextStyle(color: Colors.white)),
              subtitle: s.hasAudio
                  ? null
                  : Text(
                      context.uiText(
                          'Phiên này không có ghi âm (engine hệ thống không cho ghi song song).'),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _accent,
              value: _keepText,
              onChanged: (v) => setState(() => _keepText = v),
              title: Text(context.uiText('Giữ văn bản'),
                  style: const TextStyle(color: Colors.white)),
            ),
            if (_keepText) ...[
              Text(context.uiText('Nội dung văn bản'),
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in CabinTextMode.values)
                    ChoiceChip(
                      label: Text(context.uiText(cabinTextModeLabel(m))),
                      selected: _mode == m,
                      selectedColor: _accent.withValues(alpha: 0.3),
                      onSelected: (_) => setState(() => _mode = m),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.black),
              icon: const Icon(Icons.chrome_reader_mode_rounded),
              label: Text(context.uiText('Lưu & mở trong Tab Đọc')),
              onPressed: _busy || !_keepText
                  ? null
                  : () => _run(() async {
                        final saved = await _save();
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        final host = widget.hostContext;
                        if (saved == null || !host.mounted) return;
                        final ok =
                            await CabinReadBridge.openInRead(host, saved);
                        if (!ok) {
                          _snack('Không mở được văn bản trong Tab Đọc');
                        }
                      }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: Text(context.uiText('Lưu')),
                    onPressed: _busy || !canSave
                        ? null
                        : () => _run(() async {
                              final saved = await _save();
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              if (saved != null) _snack('Đã lưu phiên Cabin');
                            }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: Text(context.uiText('Chia sẻ')),
                    onPressed: _busy || !canSave
                        ? null
                        : () => _run(() async {
                              final saved = await _save();
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              if (saved != null) await shareCabinSession(saved);
                            }),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(context.uiText('Bỏ phiên')),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await CabinSessionStore.instance.delete(s);
                        if (mounted) Navigator.of(context).pop();
                      }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Stat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

/// Sheet cài đặt lưu phiên Cabin.
Future<void> showCabinSaveSettingsSheet(BuildContext context) async {
  final settings = CabinSessionSettings.instance;
  await settings.ensureLoaded();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: _bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ListenableBuilder(
      listenable: settings,
      builder: (ctx, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.uiText('Cài đặt lưu phiên'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _accent,
              value: settings.recordAudio,
              onChanged: settings.setRecordAudio,
              title: Text(ctx.uiText('Ghi âm khi dịch (engine Offline)'),
                  style: const TextStyle(color: Colors.white)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _accent,
              value: settings.autoSave,
              onChanged: settings.setAutoSave,
              title: Text(ctx.uiText('Tự lưu khi dừng, không hỏi'),
                  style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Text(ctx.uiText('Định dạng ghi âm'),
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: Text(ctx.uiText('WAV (không nén)')),
                selected: settings.audioFormat == CabinAudioFormat.wav,
                selectedColor: _accent.withValues(alpha: 0.3),
                onSelected: (_) =>
                    settings.setAudioFormat(CabinAudioFormat.wav),
              ),
              ChoiceChip(
                label: Text(ctx.uiText('Nén (sắp có)')),
                selected: settings.audioFormat == CabinAudioFormat.compressed,
                onSelected: CabinSessionSettings.compressedAvailable
                    ? (_) =>
                        settings.setAudioFormat(CabinAudioFormat.compressed)
                    : null,
              ),
            ]),
            const SizedBox(height: 12),
            Text(ctx.uiText('Văn bản mặc định'),
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final m in CabinTextMode.values)
                ChoiceChip(
                  label: Text(ctx.uiText(cabinTextModeLabel(m))),
                  selected: settings.textMode == m,
                  selectedColor: _accent.withValues(alpha: 0.3),
                  onSelected: (_) => settings.setTextMode(m),
                ),
            ]),
          ],
        ),
      ),
    ),
  );
}
