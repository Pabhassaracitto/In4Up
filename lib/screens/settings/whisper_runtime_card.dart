// lib/screens/settings/whisper_runtime_card.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — THẺ "BỘ CHẠY WHISPER" trong màn
// Quản lý Model AI.
//
// Vì sao cần thẻ này (đối chiếu đúng lỗi người dùng báo):
//   1. `Bad state: Khong tim thay whisper binary: whisper-cli.exe`
//      ⇒ app Windows không đóng kèm whisper.cpp. Trước đây chỉ có hướng dẫn
//        chép tay trong câu lỗi; nay có nút tải + cài tự động vào
//        `documents/whisper_runtime` và đăng ký với engine ngay.
//   2. `exit -1073741515` với STDOUT/STDERR rỗng sau khi chép "4 file"
//      ⇒ 0xC0000135 STATUS_DLL_NOT_FOUND: thiếu `whisper.dll` (bộ đầy đủ là
//        6 file). Thẻ này soi import table của binary đang có và liệt kê
//        CHÍNH XÁC file còn thiếu — không để người dùng đoán.

import 'dart:io';

import 'package:flutter/material.dart'
    show
        AlertDialog,
        BorderRadius,
        Container,
        BoxDecoration,
        BuildContext,
        Colors,
        Column,
        CrossAxisAlignment,
        EdgeInsets,
        ElevatedButton,
        FontWeight,
        Icon,
        Icons,
        LinearProgressIndicator,
        MainAxisSize,
        Navigator,
        OutlinedButton,
        Padding,
        Row,
        RoundedRectangleBorder,
        ScaffoldMessenger,
        SingleChildScrollView,
        SizedBox,
        SnackBar,
        State,
        StatefulWidget,
        TextButton,
        TextStyle,
        Theme,
        Widget,
        showDialog;
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up_stt/utils/src/whisper_cli_locator.dart';
import 'package:in4up_stt/utils/src/whisper_cli_runtime.dart';

import '../../features/media_tools/services/whisper_runtime_bootstrap.dart';
import '../../features/media_tools/services/whisper_runtime_installer.dart';

/// Thẻ "Bộ chạy Whisper (whisper-cli.exe)" — chỉ hiện trên desktop.
class WhisperRuntimeCard extends StatefulWidget {
  const WhisperRuntimeCard({super.key});

  /// Mobile/Web: không có đường CLI (Android dùng plugin, iOS/macOS plugin).
  static bool get isSupported => !Platform.isAndroid && !Platform.isIOS;

  @override
  State<WhisperRuntimeCard> createState() => _WhisperRuntimeCardState();
}

class _WhisperRuntimeCardState extends State<WhisperRuntimeCard> {
  final WhisperRuntimeInstaller _installer = WhisperRuntimeInstaller();
  WhisperInstallProgress? _progress;
  String? _error;
  bool _busy = false;

  WhisperCliLocation? _location;
  WhisperBinaryProbe? _probe;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final location = WhisperCliLocator.resolve(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _location = location;
      _probe = location.probe;
    });
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _installer.downloadAndInstall(
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
    );
    if (!mounted) return;

    if (result.success && result.binaryPath != null) {
      // Đăng ký NGAY: người dùng không phải khởi động lại app.
      await WhisperRuntimeBootstrap.rememberInstalled(result.binaryPath!);
      _refresh();
      setState(() {
        _busy = false;
        _progress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText('✅ Đã cài bộ chạy Whisper — thử tạo mục lục lại.')),
        ),
      );
      return;
    }

    final probe = result.probe;
    final detail = result.error == 'incomplete-runtime' && probe != null
        ? describeDllLoadFailure(
            probe: probe,
            binaryDir: File(result.binaryPath ?? '').parent.path,
            exitCode: kStatusDllNotFound,
          )
        : (result.error ?? 'unknown');
    setState(() {
      _busy = false;
      _progress = null;
      _error = detail;
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final probe = _probe;
    final found = location?.found ?? false;
    final ok = probe?.isRunnable ?? false;

    final Color tone = ok
        ? const Color(0xFF66BB6A)
        : found
            ? const Color(0xFFFFB300)
            : const Color(0xFFEF5350);
    final IconData icon = ok
        ? Icons.check_circle_rounded
        : found
            ? Icons.warning_amber_rounded
            : Icons.error_outline_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: tone.withValues(alpha: 0.10),
          border: Border.all(color: tone.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: tone),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.uiText('Bộ chạy Whisper (whisper-cli.exe)'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ok
                  ? context.uiText('Đã sẵn sàng: app tìm thấy đủ file để chạy.')
                  : found
                      ? context.uiText(
                          'Tìm thấy binary nhưng THIẾU file chạy được — '
                          'xem danh sách bên dưới rồi bấm Cài lại.',
                        )
                      : context.uiText(
                          'Chưa có whisper-cli.exe trên máy. Tạo mục lục/lời '
                          'thoại bằng Whisper sẽ báo lỗi cho tới khi cài.',
                        ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
            if (found) ...[
              const SizedBox(height: 6),
              Text(
                location!.binaryPath,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.white70,
                ),
              ),
            ],
            if (found && !ok && probe != null) ...[
              const SizedBox(height: 6),
              if (probe.missing.isNotEmpty)
                Text(
                  context.uiText(
                    'Thiếu: ${probe.missing.map((i) => i.name).join(', ')}',
                  ),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFEF5350)),
                ),
              if (probe.emptyDlls.isNotEmpty)
                Text(
                  context.uiText(
                    'File rỗng 0 byte: '
                    '${probe.emptyDlls.map((e) => e.name).join(', ')}',
                  ),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFFFB300)),
                ),
              for (final note in probe.notes)
                Text(
                  note,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _progress!.fraction <= 0 ? null : _progress!.fraction,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: const Color(0xFF6C63FF),
              ),
              const SizedBox(height: 4),
              Text(
                _stageLabel(context, _progress!),
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFEF5350)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(context.uiText('Kiểm tra lại')),
                ),
                const SizedBox(width: 8),
                if (WhisperRuntimeInstaller.assetNameForPlatform() != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _install,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        _busy
                            ? context.uiText('Đang tải…')
                            : context.uiText(ok
                                ? 'Cài lại bộ chạy'
                                : 'Cài bộ chạy Whisper'),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      context.uiText(
                        'Linux: cài bằng trình quản lý gói '
                        '(vd. sudo apt install whisper.cpp).',
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy ? null : () => _showHelp(context),
                  child: Text(context.uiText('Cách khác')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _stageLabel(BuildContext context, WhisperInstallProgress p) {
    switch (p.stage) {
      case WhisperInstallStage.downloading:
        return context.uiText(
          'Đang tải bộ chạy (~25 MB)… ${(p.fraction * 100).toStringAsFixed(0)}%',
        );
      case WhisperInstallStage.extracting:
        return context.uiText('Đang giải nén…');
      case WhisperInstallStage.verifying:
        return context.uiText('Đang kiểm tra đủ file…');
      case WhisperInstallStage.done:
        return context.uiText('Xong.');
    }
  }

  Future<void> _showHelp(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.uiText('Cài bộ chạy Whisper bằng tay')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctx.uiText(
                  '1. Tải file whisper-bin-x64.zip từ trang release whisper.cpp '
                  '(nút dưới).',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ctx.uiText(
                  '2. Giải nén, rồi chép ĐỦ 6 file vào cùng một thư mục: '
                  'whisper-cli.exe, whisper.dll, ggml.dll, ggml-base.dll, '
                  'ggml-cpu-*.dll, SDL2.dll.',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ctx.uiText(
                  '3. Chép cả 6 file đó vào thư mục chứa in4up.exe, hoặc đặt '
                  'biến môi trường WHISPER_PATH trỏ tới whisper-cli.exe.',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ctx.uiText(
                  'Lưu ý: thiếu whisper.dll sẽ báo "exit -1073741515" và không '
                  'có log nào — Windows không nạp nổi file .exe.',
                ),
                style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.uiText('Đóng')),
          ),
        ],
      ),
    );
  }
}
