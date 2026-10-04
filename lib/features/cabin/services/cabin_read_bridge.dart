import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:in4up/core/navigation/shell_navigation_request.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/screens/read_mode/models/recent_file.dart';
import 'package:in4up/screens/read_mode/services/recent_files_service.dart';

/// CABIN-SAVE-001 — đưa transcript LRC của phiên Cabin vào Tab Đọc, dùng
/// đúng luồng `.lrc` sẵn có (TextProvider.loadTextFile + RecentFilesService).
class CabinReadBridge {
  const CabinReadBridge._();

  /// Trả về `false` nếu không nạp được (không có LRC / LRC rỗng).
  static Future<bool> openInRead(
    BuildContext context,
    CabinSession session,
  ) async {
    if (!await File(session.lrcPath).exists()) return false;
    if (!context.mounted) return false;
    final tp = context.read<TextProvider>();
    final ok = await tp.loadTextFile(session.lrcPath, title: session.title);
    if (!ok) return false;
    try {
      final file = RecentFile.fromLocalText(session.lrcPath).copyWith(
        title: session.title,
        totalLines: tp.lines.length,
      );
      await RecentFilesService().addOrUpdate(file);
    } catch (e) {
      debugPrint('⚠️ CabinReadBridge recent: $e');
    }
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    ShellNavigationRequest.openRead();
    return true;
  }
}
