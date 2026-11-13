// lib/features/media_tools/widgets/media_export_follow_up.dart
//
// AVTOOL-003 (PLAN-047 P2) — SAU KHI XUẤT: 3 lựa chọn đúng ngữ cảnh.
//
// Vì sao cần bước này thay vì "xong rồi tự mở": người dùng xuất clip A–B vì
// muốn nghe trên đường (⇒ Chia sẻ), hoặc muốn học lại ngay (⇒ Mở trong tab
// Nghe), hoặc chỉ muốn lưu trữ. Đoán sai một trong ba là bực mình; hỏi 1 lần
// thì rẻ hơn.
//
// PSRC-202 — AI gọi bước này: **lối vào** (`media_export_actions.dart`), bằng
// context còn sống của nó. Trước đây sheet xuất tự gọi follow-up ngay sau
// `Navigator.pop` ⇒ `showDialog` chạy trên context của một route đang bị gỡ
// (có lúc hiện rồi tự biến mất). Nay sheet chỉ trả `MediaExportResult`.
//
// Dùng `share_plus` (đã có) theo đúng khuôn `pdf_export_service._writeAndShare`
// và `cabin_save_sheet.shareCabinSession` ⇒ không thêm dependency.

import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
// KHÔNG `show Text` từ material — xem ghi chú ở `media_tools_screen.dart`.
import 'package:flutter/material.dart' hide Text;
import 'package:share_plus/share_plus.dart';

import '../../../services/external_open_service.dart';
import '../models/media_export_models.dart';
import '../services/media_estimates.dart';

/// Lựa chọn của người dùng ở hộp thoại "Đã xuất xong".
enum ExportFollowUpChoice {
  /// Mở file vừa xuất ngay trong tab Nghe.
  open,

  /// Mở share sheet của hệ điều hành.
  share,

  /// Đóng — file đã nằm trong thư viện.
  close,

  /// Không có kết quả (người dùng bấm ra ngoài).
  dismissed,
}

/// Hỏi người dùng muốn làm gì tiếp với file vừa xuất.
///
/// [openInListenTab]: lối vào tự cung cấp (null = không có nút "Mở ...").
/// [share]: cổng chia sẻ thay được trong test; mặc định [shareExportedFiles].
Future<ExportFollowUpChoice> offerExportFollowUp(
  BuildContext context,
  MediaExportResult result, {
  Future<void> Function(String path)? openInListenTab,
  Future<void> Function(MediaExportResult result)? share,
}) async {
  if (result.isEmpty) return ExportFollowUpChoice.dismissed;

  final choice = await showDialog<ExportFollowUpChoice>(
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
          if (result.warnings.isNotEmpty) ... [
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
          const SizedBox(height: 6),
          Text(
            result.primaryPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        if (openInListenTab != null)
          TextButton.icon(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ExportFollowUpChoice.open),
            icon: const Icon(Icons.headphones_rounded, size: 18),
            label: Text(dialogContext.uiText('Mở trong tab Nghe')),
          ),
        TextButton.icon(
          onPressed: () =>
              Navigator.of(dialogContext).pop(ExportFollowUpChoice.share),
          icon: const Icon(Icons.share_rounded, size: 18),
          label: Text(dialogContext.uiText('Chia sẻ')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(ExportFollowUpChoice.close),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
          ),
          child: Text(dialogContext.uiText('Xong')),
        ),
      ],
    ),
  );

  if (choice == null) return ExportFollowUpChoice.dismissed;

  switch (choice) {
    case ExportFollowUpChoice.share:
      if (!context.mounted) return choice;
      await (share ?? shareExportedFiles)(result);
    case ExportFollowUpChoice.open:
      if (openInListenTab == null || !context.mounted) return choice;
      // PSRC-202: file có thể đã bị dời/xoá sau khi xuất (thư viện dọn, người
      // dùng xoá). Báo lý do + đường thay thế thay vì mở một path rỗng.
      final missing = await missingExportFiles(result);
      if (!context.mounted) return choice;
      if (missing.isNotEmpty) {
        await showMissingExportFiles(context, result, missing);
        return choice;
      }
      await openInListenTab(result.primaryPath);
    case ExportFollowUpChoice.close:
    case ExportFollowUpChoice.dismissed:
      break;
  }
  return choice;
}

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

/// Danh sách file của [result] đã KHÔNG còn trên đĩa.
///
/// Chỉ trả các path thật (bỏ LRC rỗng). Dùng cho cả nút "Mở trong tab Nghe"
/// và bước chia sẻ — nhờ vậy hai lối đi cùng một phép kiểm.
Future<List<String>> missingExportFiles(MediaExportResult result) async {
  final missing = <String>[];
  for (final path in [...result.outputPaths, ...result.lrcPaths]) {
    if (path.isEmpty) continue;
    try {
      // `existsSync`: kiểm tra này nằm trên đường UI ngay sau khi xuất (1–3
      // tệp) nên đồng bộ là đủ nhanh, và quan trọng hơn: nó chạy được TRONG
      // widget test. `await File(...).exists()` cần event loop thật, còn
      // `testWidgets` chạy trong FakeAsync ⇒ future không bao giờ hoàn tất và
      // `flutter test` treo (bài học từ CI: run 43488523702).
      if (!File(path).existsSync()) missing.add(path);
    } catch (_) {
      missing.add(path);
    }
  }
  return missing;
}

/// Chia sẻ các file đã xuất (+ LRC đi kèm). Bỏ qua file không còn tồn tại.
Future<void> shareExportedFiles(MediaExportResult result) async {
  final files = <XFile>[];
  for (final path in [...result.outputPaths, ...result.lrcPaths]) {
    if (path.isEmpty) continue; // LRC rỗng = chặng không có lời
    try {
      // Cùng lý do như `missingExportFiles`: tránh I/O bất đồng bộ trong
      // FakeAsync (widget test) — kiểm tra đồng bộ trên vài tệp là rẻ.
      if (File(path).existsSync()) files.add(XFile(path));
    } catch (_) {}
  }
  if (files.isEmpty) return;
  await SharePlus.instance.share(ShareParams(files: files));
}

/// Báo file của bản xuất đã biến mất, kèm đường thay thế.
Future<void> showMissingExportFiles(
  BuildContext context,
  MediaExportResult result,
  List<String> missing,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        dialogContext.uiText('Tệp không còn trên máy'),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dialogContext.uiText(
                'Bản xuất đã bị dời hoặc xoá sau khi tạo. Hãy xuất lại, hoặc mở thư mục để kiểm tra.'),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            missing.first,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.uiText('Đóng')),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await openExportFolder(result.primaryPath);
          },
          icon: const Icon(Icons.folder_open_rounded, size: 18),
          label: Text(dialogContext.uiText('Mở thư mục chứa tệp')),
        ),
      ],
    ),
  );
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
