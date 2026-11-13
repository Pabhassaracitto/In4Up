// lib/features/media_tools/widgets/media_export_follow_up.dart
//
// AVTOOL-003 (PLAN-047 P2) — SAU KHI XUẤT: 3 lựa chọn đúng ngữ cảnh.
//
// Vì sao cần bước này thay vì "xong rồi tự mở": người dùng xuất clip A–B vì
// muốn nghe trên đường (⇒ Chia sẻ), hoặc muốn học lại ngay (⇒ Mở trong tab
// Nghe), hoặc chỉ muốn lưu trữ. Đoán sai một trong ba là bực mình; hỏi 1 lần
// thì rẻ hơn.
//
// Dùng `share_plus` (đã có) theo đúng khuôn `pdf_export_service._writeAndShare`
// và `cabin_save_sheet.shareCabinSession` ⇒ không thêm dependency.

import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
// KHÔNG `show Text` từ material — xem ghi chú ở `media_tools_screen.dart`.
import 'package:flutter/material.dart' hide Text;
import 'package:share_plus/share_plus.dart';

import '../../../core/files/export_destination.dart';
import '../../../core/files/export_destination_service.dart';
import '../models/media_export_models.dart';
import '../services/media_estimates.dart';

/// Hỏi người dùng muốn làm gì tiếp với file vừa xuất.
Future<void> offerExportFollowUp(
  BuildContext context,
  MediaExportResult result, {
  Future<void> Function(String path)? openInListenTab,
}) async {
  if (result.isEmpty) return;

  final action = await showDialog<_FollowUp>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF00E676), size: 20),
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
          Text(
            _summary(dialogContext, result),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final warning in result.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFFFB300), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.folder_outlined,
                  color: Color(0xFF26C6DA),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    result.primaryDisplayPath,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        if (openInListenTab != null)
          TextButton.icon(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_FollowUp.open),
            icon: const Icon(Icons.headphones_rounded, size: 18),
            label: Text(dialogContext.uiText('Mở trong tab Nghe')),
          ),
        TextButton.icon(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_FollowUp.openFolder),
          icon: const Icon(Icons.folder_open_rounded, size: 18),
          label: Text(dialogContext.uiText('Mở thư mục')),
        ),
        TextButton.icon(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_FollowUp.share),
          icon: const Icon(Icons.share_rounded, size: 18),
          label: Text(dialogContext.uiText('Chia sẻ')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(_FollowUp.close),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
          ),
          child: Text(dialogContext.uiText('Xong')),
        ),
      ],
    ),
  );

  if (!context.mounted) return;
  switch (action) {
    case _FollowUp.openFolder:
      final dest = result.destination ??
          (await ExportDestinationService.instance.resolveDefaultDestination())
              .destination;
      final opened =
          await ExportDestinationService.instance.openContainingFolder(
        destination: dest,
        localFilePath: result.primaryPublicLocalPath ?? result.primaryPath,
        fileUri: result.primaryFileUri,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.uiText('Đã lưu tại: ${result.primaryDisplayPath}'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    case _FollowUp.share:
      await shareExportedFiles(result);
    case _FollowUp.open:
      if (openInListenTab != null) {
        await openInListenTab(result.primaryPath);
      }
    case _FollowUp.close:
    case null:
      break;
  }
}

enum _FollowUp { open, openFolder, share, close }

String _summary(BuildContext context, MediaExportResult result) {
  final parts = <String>[];
  if (result.outputPaths.length > 1) {
    parts.add('${result.outputPaths.length} ${context.uiText('file')}');
  }
  parts.add(MediaEstimates.formatBytes(result.sizeBytes));
  if (result.lrcPaths.any((path) => path.isNotEmpty)) {
    parts.add(context.uiText('kèm lời (LRC)'));
  }
  return parts.join(' · ');
}

/// Chia sẻ các file đã xuất (+ LRC đi kèm). Bỏ qua file không còn tồn tại.
Future<void> shareExportedFiles(MediaExportResult result) async {
  final files = <XFile>[];
  for (final path in [...result.outputPaths, ...result.lrcPaths]) {
    if (path.isEmpty) continue; // LRC rỗng = chặng không có lời
    try {
      if (await File(path).exists()) files.add(XFile(path));
    } catch (_) {}
  }
  if (files.isEmpty) return;
  await SharePlus.instance.share(ShareParams(files: files));
}

/// Hộp thoại lỗi tối giản cho nơi không dùng progress dialog (ví dụ menu).
Future<void> showMediaExportFailure(
  BuildContext context,
  MediaExportError error,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        dialogContext.uiText('Xuất thất bại'),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Text(
        error.technicalMessage,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.uiText('Đóng')),
        ),
      ],
    ),
  );
}

/// Khung "thẻ gợi ý" dùng lại ở nhiều bề mặt (chip nhỏ dưới player…).
class MediaExportHintCard extends StatelessWidget {
  const MediaExportHintCard({
    super.key,
    required this.titleKey,
    required this.onTap,
    this.icon = Icons.content_cut,
  });

  final String titleKey;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: const Color(0xFF26C6DA), size: 20),
        title: Text(
          context.uiText(titleKey),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
