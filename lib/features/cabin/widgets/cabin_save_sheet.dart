import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/files/export_destination.dart';
import '../../../core/files/export_destination_service.dart';
import '../../../core/files/widgets/export_destination_tile.dart';
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download_outlined),
              label: Text(context.uiText('Xuất tệp')),
              onPressed: _busy || !canSave
                  ? null
                  : () => _run(() async {
                        final saved = await _save();
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        final host = widget.hostContext;
                        if (saved != null && host.mounted) {
                          await showCabinExportSheet(host, saved);
                        }
                      }),
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

/// PSRC-204 / ADR-0029 § 6.3 — Phiên Cabin vẫn lưu nội bộ mặc định; chỉ khi
/// người dùng chủ động bấm "Xuất tệp" mới chép WAV / LRC / TXT ra nơi lưu công
/// khai (`Download/In4Up`, `On My iPhone/In4Up`, `~/Downloads/In4Up` hoặc thư
/// mục chọn qua "Đổi…").
Future<List<ExportSavedFile>> exportCabinSessionFiles({
  required CabinSession session,
  ExportDestination? destination,
  ExportDestinationService? destinationService,
  bool includeAudio = true,
  bool includeLrc = true,
  bool includeTxt = true,
}) async {
  final service = destinationService ?? ExportDestinationService.instance;
  final target =
      destination ?? (await service.resolveDefaultDestination()).destination;
  final stem = ExportDestinationPolicy.sanitizeFileName(
    session.title,
    fallbackStem: 'cabin_session',
  );
  final exported = <ExportSavedFile>[];

  if (includeAudio && session.hasAudio) {
    final wav = File(session.audioPath);
    if (await wav.exists()) {
      exported.add(
        await service.exportLocalFile(
          sourceFile: wav,
          desiredFileName: '$stem.wav',
          destination: target,
          mimeType: 'audio/wav',
        ),
      );
    }
  }
  if (includeLrc) {
    final lrc = File(session.lrcPath);
    if (await lrc.exists()) {
      exported.add(
        await service.exportLocalFile(
          sourceFile: lrc,
          desiredFileName: '$stem.lrc',
          destination: target,
          mimeType: 'text/plain',
        ),
      );
    }
  }
  if (includeTxt) {
    final txt = File(session.txtPath);
    if (await txt.exists()) {
      exported.add(
        await service.exportLocalFile(
          sourceFile: txt,
          desiredFileName: '$stem.txt',
          destination: target,
          mimeType: 'text/plain',
        ),
      );
    }
  }
  return exported;
}

/// Hộp thoại xuất phiên Cabin ra thư mục công khai (có "Đổi…" từng lần xuất +
/// thông báo sau khi lưu kèm đường dẫn hiển thị, "Mở thư mục" và "Chia sẻ").
Future<void> showCabinExportSheet(
  BuildContext context,
  CabinSession session,
) async {
  final hasWav = session.hasAudio && File(session.audioPath).existsSync();
  final hasLrc = File(session.lrcPath).existsSync();
  final hasTxt = File(session.txtPath).existsSync();
  if (!hasWav && !hasLrc && !hasTxt) return;

  final exported = await showModalBottomSheet<List<ExportSavedFile>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CabinExportSheet(
      session: session,
      hasWav: hasWav,
      hasLrc: hasLrc,
      hasTxt: hasTxt,
    ),
  );

  if (exported == null || exported.isEmpty || !context.mounted) return;
  await _offerCabinExportFollowUp(context, session, exported);
}

class _CabinExportSheet extends StatefulWidget {
  const _CabinExportSheet({
    required this.session,
    required this.hasWav,
    required this.hasLrc,
    required this.hasTxt,
  });

  final CabinSession session;
  final bool hasWav;
  final bool hasLrc;
  final bool hasTxt;

  @override
  State<_CabinExportSheet> createState() => _CabinExportSheetState();
}

class _CabinExportSheetState extends State<_CabinExportSheet> {
  late bool _includeWav;
  late bool _includeLrc;
  late bool _includeTxt;
  bool _busy = false;
  ExportDestinationSession? _destinationSession;

  @override
  void initState() {
    super.initState();
    _includeWav = widget.hasWav;
    _includeLrc = widget.hasLrc;
    _includeTxt = widget.hasTxt;
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final opened = await ExportDestinationService.instance.openSession();
      if (!mounted) return;
      setState(() => _destinationSession = opened);
    } catch (_) {}
  }

  bool get _canExport =>
      (_includeWav && widget.hasWav) ||
      (_includeLrc && widget.hasLrc) ||
      (_includeTxt && widget.hasTxt);

  Future<void> _exportNow() async {
    if (_busy || !_canExport) return;
    setState(() => _busy = true);
    try {
      ExportDestination? target;
      if (_destinationSession != null) {
        target = await ExportDestinationService.instance.commitSession(
          _destinationSession!,
        );
      }
      final saved = await exportCabinSessionFiles(
        session: widget.session,
        destination: target,
        includeAudio: _includeWav,
        includeLrc: _includeLrc,
        includeTxt: _includeTxt,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText('Xuất thất bại')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.file_download_outlined, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText('Xuất phiên Cabin'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.session.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (widget.hasWav)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _accent,
                value: _includeWav,
                onChanged: (v) => setState(() => _includeWav = v ?? false),
                title: Text(
                  context.uiText('Bản ghi âm (.wav)'),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            if (widget.hasLrc)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _accent,
                value: _includeLrc,
                onChanged: (v) => setState(() => _includeLrc = v ?? false),
                title: Text(
                  context.uiText('Phụ đề khớp giờ (.lrc)'),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            if (widget.hasTxt)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _accent,
                value: _includeTxt,
                onChanged: (v) => setState(() => _includeTxt = v ?? false),
                title: Text(
                  context.uiText('Văn bản / bản dịch (.txt)'),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            const SizedBox(height: 8),
            ExportDestinationPickerCard(
              session: _destinationSession,
              onChanged: () {
                if (mounted) setState(() {});
              },
              accentColor: _accent,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.file_download_rounded),
              label: Text(context.uiText('Bắt đầu xuất')),
              onPressed: _busy || !_canExport ? null : _exportNow,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _offerCabinExportFollowUp(
  BuildContext context,
  CabinSession session,
  List<ExportSavedFile> exported,
) async {
  final first = exported.first;
  final displaySummary = exported.length == 1
      ? first.displayPath
      : '${first.destination.displayPath} (${exported.length} ${context.uiText('file')})';

  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dialogContext.uiText('Đã xuất xong'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in exported)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item.displayPath,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop('folder'),
          icon: const Icon(Icons.folder_open_rounded, size: 18),
          label: Text(dialogContext.uiText('Mở thư mục')),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop('share'),
          icon: const Icon(Icons.share_rounded, size: 18),
          label: Text(dialogContext.uiText('Chia sẻ')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop('close'),
          child: Text(dialogContext.uiText('Xong')),
        ),
      ],
    ),
  );

  if (!context.mounted) return;
  if (choice == 'folder') {
    final opened = await ExportDestinationService.instance.openContainingFolder(
      destination: first.destination,
      localFilePath: first.localPath,
      fileUri: first.uri,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText('Đã lưu tại: $displaySummary')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } else if (choice == 'share') {
    await shareCabinSession(session);
  }
}
