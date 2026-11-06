// lib/features/media_tools/widgets/ffmpeg_install_sheet.dart
//
// AVTOOL-002 (PLAN-046 P1) — Sheet "Tải FFmpeg" cho DESKTOP.
//
// Chỉ hiện trên Windows/macOS (mobile đã có FFmpegKit; Linux dùng apt). Nêu rõ
// 3 điều trước khi bấm: nguồn tải, dung lượng, và "chỉ tải khi bạn dùng" —
// đúng quyết định của owner 2026-11-06.

import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/material.dart' show AlertDialog, BorderRadius,
    BoxDecoration, BuildContext, Colors, Column, Container, CrossAxisAlignment,
    EdgeInsets, FilledButton, FontWeight, Icon, Icons, LinearProgressIndicator,
    MainAxisSize, Navigator, Row, RoundedRectangleBorder, SizedBox, Text,
    TextButton, TextStyle, Widget, showDialog, showModalBottomSheet;
import 'package:in4up_stt/utils/src/ffmpeg_runner.dart';

import '../services/ffmpeg_runtime_bootstrap.dart';
import '../services/ffmpeg_runtime_installer.dart';

Future<void> showFfmpegInstallSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FfmpegInstallSheet(),
  );
}

class _FfmpegInstallSheet extends StatefulWidget {
  const _FfmpegInstallSheet();

  @override
  State<_FfmpegInstallSheet> createState() => _FfmpegInstallSheetState();
}

class _FfmpegInstallSheetState extends State<_FfmpegInstallSheet> {
  final FfmpegRuntimeInstaller _installer = FfmpegRuntimeInstaller();
  FfmpegInstallProgress? _progress;
  String? _error;
  bool _installing = false;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    final result = await _installer.downloadAndInstall(
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    if (result.success && result.executablePath != null) {
      // Đăng ký ngay + ghi nhớ vào settings để lần khởi động sau khỏi dò lại.
      await FfmpegRuntimeBootstrap.rememberInstalled(result.executablePath);
      final messenger = ScaffoldMessenger.maybeOf(context);
      final message =
          context.uiText('Đã cài FFmpeg — sẵn sàng xuất file');
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF00E676),
        ),
      );
      return;
    }
    setState(() {
      _installing = false;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        !Platform.isAndroid && !Platform.isIOS && !Platform.isLinux;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF141D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_rounded,
                    color: Color(0xFF26C6DA), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.uiText('Tải FFmpeg'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.uiText(
                'FFmpeg là công cụ chuyển đổi/cắt file media. App KHÔNG đóng gói sẵn để giữ dung lượng nhẹ — chỉ tải khi bạn dùng.',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _bullet(context, 'Nguồn: github.com/BtbN/FFmpeg-Builds (GPL)'),
            _bullet(context, 'Dung lượng tải: khoảng 90 MB'),
            _bullet(context, 'Kiểm tra SHA-256 trước khi giải nén'),
            if (!supported) ...[
              const SizedBox(height: 10),
              Text(
                context.uiText(
                  'Trên Linux, hãy cài bằng trình quản lý gói: sudo apt install ffmpeg',
                ),
                style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12),
              ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _progress!.fraction <= 0 ? null : _progress!.fraction,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: const Color(0xFF26C6DA),
              ),
              const SizedBox(height: 6),
              Text(
                _stageLabel(context, _progress!),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _installing ? null : () => Navigator.of(context).pop(),
                  child: Text(context.uiText('Để sau')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (_installing || !supported) ? null : _install,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _installing
                          ? context.uiText('Đang tải…')
                          : context.uiText('Tải ngay'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ', style: TextStyle(color: Colors.white38)),
            Expanded(
              child: Text(
                context.uiText(value),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      );

  String _stageLabel(BuildContext context, FfmpegInstallProgress progress) {
    switch (progress.stage) {
      case FfmpegInstallStage.downloading:
        return '${context.uiText('Đang tải')} '
            '${(progress.fraction * 100).toStringAsFixed(0)}%';
      case FfmpegInstallStage.verifying:
        return context.uiText('Đang kiểm tra SHA-256…');
      case FfmpegInstallStage.extracting:
        return '${context.uiText('Đang giải nén')} '
            '${(progress.fraction * 100).toStringAsFixed(0)}%';
      case FfmpegInstallStage.done:
        return context.uiText('Xong');
    }
  }
}

/// Hộp thoại hỏi có tải FFmpeg không — dùng trước khi mở công cụ trên desktop.
Future<bool> ensureFfmpegReady(BuildContext context) async {
  if (await FfmpegRunner.isAvailable()) return true;
  if (!context.mounted) return false;
  final install = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        dialogContext.uiText('Cần FFmpeg để xuất file'),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Text(
        dialogContext.uiText(
          'Máy này chưa có FFmpeg. Tải một lần (~90 MB) rồi dùng được mọi công cụ media.',
        ),
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.uiText('Để sau')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
          child: Text(dialogContext.uiText('Tải FFmpeg')),
        ),
      ],
    ),
  );
  if (install != true) return false;
  if (!context.mounted) return false;
  await showFfmpegInstallSheet(context);
  return FfmpegRunner.isAvailable();
}
