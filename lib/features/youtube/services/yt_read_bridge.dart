// YT-MEDIA-STORE-001 — "Nạp phụ đề + âm thanh vào tab Đọc".
//
// Vì sao cần cầu nối này: người dùng tải phụ đề (và có thể cả âm thanh) ở chế
// độ YouTube, nhưng file nằm trong bộ nhớ riêng của app nên **không có đường
// quay lại**. Ở đây đi đúng luồng sẵn có mà tab Đọc đã dùng:
//
//   TextProvider.loadTextFile(lrc)      → nạp lời (đồng bộ theo mốc thời gian)
//   PlayerProvider.loadSong(audio)      → nạp âm thanh để phát song song
//   RecentFilesService.addOrUpdate(...) → lần sau mở lại từ "Gần đây"
//   ShellNavigationRequest.openRead()   → chuyển sang tab Đọc
//
// Cùng pattern với `CabinReadBridge` (CABIN-SAVE-001) để chỉ có MỘT cách hiểu
// "mở một phiên học trong tab Đọc".

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:in4up/core/navigation/shell_navigation_request.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/screens/read_mode/models/recent_file.dart';
import 'package:in4up/screens/read_mode/services/recent_files_service.dart';

import 'yt_media_store.dart';

/// Kết quả một lần nạp — để UI nói ĐÚNG phần nào đã vào, phần nào thiếu.
class YtReadLoadResult {
  const YtReadLoadResult({
    required this.ok,
    required this.loadedCaptions,
    required this.loadedAudio,
    this.reason,
  });

  final bool ok;
  final bool loadedCaptions;
  final bool loadedAudio;

  /// Mã máy (không phải câu tiếng Anh thô) để UI tự dịch: `no_captions`,
  /// `audio_failed`, `load_failed`.
  final String? reason;
}

class YtReadBridge {
  const YtReadBridge._();

  /// Nạp [item] (phụ đề + âm thanh nếu có) vào tab Đọc rồi chuyển tab.
  ///
  /// `openShell`: đặt `false` khi màn gọi đã tự điều hướng (vd từ trong sheet
  /// cần đóng trước) — mặc định `true` cho hành vi "một cú bấm là sang tab Đọc".
  static Future<YtReadLoadResult> openInRead(
    BuildContext context,
    YtMediaItem item, {
    bool openShell = true,
  }) async {
    final lrcPath = item.lrcPath;
    if (lrcPath == null || !await File(lrcPath).exists()) {
      return const YtReadLoadResult(
        ok: false,
        loadedCaptions: false,
        loadedAudio: false,
        reason: 'no_captions',
      );
    }
    if (!context.mounted) {
      return const YtReadLoadResult(
        ok: false,
        loadedCaptions: false,
        loadedAudio: false,
        reason: 'load_failed',
      );
    }

    final tp = context.read<TextProvider>();
    final okText = await tp.loadTextFile(lrcPath, title: item.title);
    if (!okText) {
      return const YtReadLoadResult(
        ok: false,
        loadedCaptions: false,
        loadedAudio: false,
        reason: 'load_failed',
      );
    }

    // Âm thanh: lỗi ở đây KHÔNG được làm hỏng việc nạp phụ đề — người dùng
    // vẫn đọc được, chỉ là không có tiếng.
    var audioOk = false;
    final audioPath = item.audioPath;
    if (audioPath != null && await File(audioPath).exists()) {
      try {
        // `loadSong` trả `false` khi file hỏng/định dạng lạ — phải đọc giá
        // trị đó, không được coi "không ném lỗi" là thành công.
        audioOk = await context.read<PlayerProvider>().loadSong(
              path: audioPath,
              title: item.title,
              artist: '',
              autoPlay: false,
            );
      } catch (e) {
        debugPrint('⚠️ [in4up-yt] nạp âm thanh vào tab Đọc lỗi: $e');
      }
    }

    try {
      final file = RecentFile.fromLocalText(lrcPath).copyWith(
        title: item.title,
        totalLines: tp.lines.length,
      );
      await RecentFilesService().addOrUpdate(file);
    } catch (e) {
      debugPrint('⚠️ YtReadBridge recent: $e');
    }

    if (openShell && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ShellNavigationRequest.openRead();
    }
    return YtReadLoadResult(
      ok: true,
      loadedCaptions: true,
      loadedAudio: audioOk,
      reason: audioOk || item.audioPath == null ? null : 'audio_failed',
    );
  }
}
