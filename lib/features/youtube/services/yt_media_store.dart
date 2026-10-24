// YT-MEDIA-STORE-001 — một chỗ duy nhất cho phụ đề `.lrc` và file âm thanh đã
// tải của chế độ YouTube.
//
// ─── Vì sao phải có file này ────────────────────────────────────────────
// Trước đây hai thứ nằm ở hai nơi KHÁC NHAU và không có gì liên kết:
//   • phụ đề → `<app>/youtube_captions/yt_<videoId>.lrc`  (đặt tên theo ID)
//   • âm thanh → `<app>/youtube_downloads/<tựa đề>.<ext>` (đặt tên theo TỰA)
// ⇒ người dùng tải xong không biết file nằm đâu, không có cách mở lại, và
// không có cách biết chúng chiếm bao nhiêu bộ nhớ để dọn.
//
// Bây giờ: `youtube_media/yt_<videoId>.lrc` + `youtube_media/yt_<videoId>.<ext>`
// ⇒ **cùng một khoá là video ID** nên luôn ghép được cặp phụ đề ↔ âm thanh,
// liệt kê được, tính được dung lượng, xoá được từng video.
//
// Không gọi mạng. Không cần quyền trên đường mặc định (`appPrivate`).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/yt_learning_settings.dart';
import 'yt_learning_settings_service.dart';

/// Một video đã tải (có thể chỉ có phụ đề, chỉ có âm thanh, hoặc cả hai).
class YtMediaItem {
  const YtMediaItem({
    required this.videoId,
    required this.title,
    required this.lrcPath,
    required this.audioPath,
    required this.bytes,
    required this.updatedAt,
  });

  final String videoId;
  final String title;
  final String? lrcPath;
  final String? audioPath;
  final int bytes;
  final DateTime updatedAt;

  bool get hasCaptions => lrcPath != null;
  bool get hasAudio => audioPath != null;

  /// Đã đủ cặp để "nạp vào tab Đọc" (phụ đề + âm thanh)?
  bool get isComplete => hasCaptions && hasAudio;
}

class YtMediaStore {
  YtMediaStore._();

  /// Tên thư mục khoá — giữ cố định để người dùng tìm lại được.
  static const String folderName = 'youtube_media';

  /// Thư mục cũ (trước YT-MEDIA-STORE-001) — chỉ dùng để DI TRÚ.
  static const String _legacyCaptionsDir = 'youtube_captions';
  static const String _legacyAudioDir = 'youtube_downloads';

  static YtSaveLocation get _location => YtLearningSettingsService.load().saveLocation;

  /// Nơi lưu đang đặt (đọc đồng bộ từ cài đặt đã nạp).
  static YtSaveLocation loadLocationSetting() =>
      YtLearningSettingsService.load().saveLocation;

  static Future<void> setLocation(YtSaveLocation location) async {
    final current = YtLearningSettingsService.load();
    await YtLearningSettingsService.save(
      current.copyWith(saveLocation: location),
    );
  }

  /// Thư mục lưu hiện hành.
  ///
  /// `externalDownloads` (Android: `Download/In4Up`) tiện cho người dùng tìm
  /// lại, nhưng **Android 11+ có thể từ chối ghi** dù manifest có xin quyền
  /// (scoped storage). Vì vậy luôn kiểm tra bằng cách ghi thử; thất bại thì
  /// lặng lẽ dùng thư mục riêng của app và [lastFallbackReason] nói ra lý do
  /// để UI báo thật, không hứa suông.
  static String? lastFallbackReason;

  static Future<Directory> folder() async {
    if (_location == YtSaveLocation.externalDownloads) {
      try {
        final ext = await _externalRoot();
        if (ext != null) {
          final dir = Directory('${ext.path}/In4Up');
          if (!await dir.exists()) await dir.create(recursive: true);
          final probe = File('${dir.path}/.write_probe');
          await probe.writeAsString('ok', flush: true);
          await probe.delete();
          lastFallbackReason = null;
          return dir;
        }
        lastFallbackReason = 'no_external_dir';
      } catch (e) {
        debugPrint('⚠️ [in4up-yt] không ghi được thư mục ngoài: $e');
        lastFallbackReason = 'write_denied';
      }
    }
    final dir = await _appPrivateDir();
    return dir;
  }

  static Future<Directory> _appPrivateDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Thư mục công khai ngoài app (Android). Nền tảng khác trả `null` —
  /// trên desktop/mobile khác `appPrivate` đã là nơi người dùng thấy được.
  static Future<Directory?> _externalRoot() async {
    if (!Platform.isAndroid) return null;
    try {
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
      return await getExternalStorageDirectory();
    } catch (e) {
      debugPrint('⚠️ [in4up-yt] getExternalStorageDirectory: $e');
      return null;
    }
  }

  /// Đường dẫn hiển thị cho người dùng (để họ tự tìm lại bằng trình quản lý).
  static Future<String> displayFolder() async => (await folder()).path;

  // ─── Ghi ────────────────────────────────────────────────────────────

  /// Lưu phụ đề thành `yt_<videoId>.lrc`. Trả `null` nếu ghi lỗi.
  static Future<String?> saveLrc({
    required String videoId,
    required String content,
  }) async {
    try {
      final dir = await folder();
      final path = '${dir.path}/${_fileBase(videoId)}.lrc';
      await File(path).writeAsString(content, flush: true);
      return path;
    } catch (e) {
      debugPrint('YtMediaStore.saveLrc: $e');
      return null;
    }
  }

  /// Đưa file âm thanh vừa tải (`yt_downloader` ghi ra thư mục tạm) vào kho,
  /// đổi tên theo video ID để ghép được với phụ đề.
  ///
  /// Dùng `rename` trước (cùng ổ đĩa ⇒ tức thời, không tốn thêm dung lượng);
  /// khác ổ đĩa thì `rename` ném lỗi ⇒ mới copy rồi xoá bản tạm.
  static Future<String?> adoptAudio({
    required String sourcePath,
    required String videoId,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final dir = await folder();
      final ext = _extOf(sourcePath);
      final destPath = '${dir.path}/${_fileBase(videoId)}$ext';
      final dest = File(destPath);
      if (await dest.exists()) await dest.delete();
      try {
        await src.rename(destPath);
      } catch (_) {
        await src.copy(destPath);
        try {
          await src.delete();
        } catch (_) {}
      }
      return destPath;
    } catch (e) {
      debugPrint('YtMediaStore.adoptAudio: $e');
      return null;
    }
  }

  // ─── Đọc ────────────────────────────────────────────────────────────

  /// Liệt kê mọi video đã tải, mới nhất trước.
  ///
  /// Tự DI TRÚ file của bản cũ (`youtube_captions/`, `youtube_downloads/`) để
  /// người dùng không mất những gì đã tải trước khi có tính năng này.
  static Future<List<YtMediaItem>> list() async {
    await _migrateLegacyOnce();
    final dir = await folder();
    final items = <String, YtMediaItem>{};
    try {
      if (!await dir.exists()) return const [];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        // Lấy tên file trực tiếp từ path: `uri.pathSegments` đã bị
        // percent-encode nên tên có dấu cách/tiếng Việt sẽ sai.
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;
        // File cũ (di trú từ `youtube_downloads/`) đặt tên theo TỰA ĐỀ, không
        // có tiền tố `yt_` ⇒ vẫn phải hiện để người dùng thấy & xoá được.
        // Khoá nhóm là phần tên không có đuôi file.
        final stem = name.contains('.')
            ? name.substring(0, name.lastIndexOf('.'))
            : name;
        if (stem.isEmpty) continue;
        final videoId =
            stem.startsWith('yt_') ? stem.substring(3) : stem;
        final isLrc = name.toLowerCase().endsWith('.lrc');

        final stat = await entity.stat();
        final existing = items[videoId];
        final title = isLrc ? await _titleOf(entity) : null;

        items[videoId] = YtMediaItem(
          videoId: videoId,
          title: title ?? existing?.title ?? videoId,
          lrcPath: isLrc ? entity.path : existing?.lrcPath,
          audioPath: isLrc ? existing?.audioPath : entity.path,
          bytes: (existing?.bytes ?? 0) + stat.size,
          updatedAt: _latest(existing?.updatedAt, stat.modified),
        );
      }
    } catch (e) {
      debugPrint('YtMediaStore.list: $e');
    }
    final out = items.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  static Future<int> totalBytes() async {
    final items = await list();
    return items.fold<int>(0, (sum, i) => sum + i.bytes);
  }

  static Future<void> deleteItem(YtMediaItem item) async {
    for (final p in [item.lrcPath, item.audioPath]) {
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('YtMediaStore.deleteItem($p): $e');
      }
    }
  }

  /// Xoá mọi thứ trong kho (không xoá thư mục).
  static Future<void> deleteAll() async {
    for (final item in await list()) {
      await deleteItem(item);
    }
  }

  // ─── Tiện ích ───────────────────────────────────────────────────────

  /// `yt_<videoId>` — videoId chỉ giữ ký tự an toàn cho tên file.
  ///
  /// Công khai để `yt_downloader` đặt tên file NGAY TỪ ĐẦU (ghi `.part` vào
  /// đúng kho) thay vì ghi chỗ tạm rồi đổi tên — nhờ vậy resume sau khi mạng
  /// đứt vẫn tìm đúng file dở.
  static String fileBaseFor(String videoId) => _fileBase(videoId);

  static String _fileBase(String videoId) {
    final safe = videoId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return 'yt_${safe.isEmpty ? 'clip' : safe}';
  }

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot < path.length - 6) return '';
    return path.substring(dot);
  }

  static DateTime _latest(DateTime? a, DateTime b) {
    if (a == null) return b;
    return a.isAfter(b) ? a : b;
  }

  /// Đọc `[ti:...]` trong LRC để hiện tựa đề thay vì mã video.
  static Future<String?> _titleOf(File lrc) async {
    try {
      final raw = await lrc.readAsString();
      final m = RegExp(r'^\[ti:(.*)\]$', multiLine: true).firstMatch(raw);
      final t = m?.group(1)?.trim();
      return (t == null || t.isEmpty) ? null : t;
    } catch (_) {
      return null;
    }
  }

  static bool _migrated = false;

  /// Di trú một lần: `youtube_captions/*.lrc` + `youtube_downloads/*` → kho.
  ///
  /// Chỉ DI CHUYỂN khi đích chưa có; lỗi thì bỏ qua (không được làm hỏng
  /// danh sách chỉ vì file cũ đang bị khoá).
  static Future<void> _migrateLegacyOnce() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = await folder();

      final lrcDir = Directory('${base.path}/$_legacyCaptionsDir');
      if (await lrcDir.exists()) {
        await for (final f in lrcDir.list()) {
          if (f is! File || !f.path.toLowerCase().endsWith('.lrc')) continue;
          final name = f.path.split('/').last;
          final stem = name.substring(0, name.length - 4); // yt_<id>
          if (!stem.startsWith('yt_')) continue;
          final dest = File('${dir.path}/$stem.lrc');
          if (await dest.exists()) {
            await _safeDelete(f);
          } else {
            try {
              await f.rename(dest.path);
            } catch (_) {}
          }
        }
      }

      final audioDir = Directory('${base.path}/$_legacyAudioDir');
      if (await audioDir.exists()) {
        await for (final f in audioDir.list()) {
          if (f is! File) continue;
          if (f.path.toLowerCase().endsWith('.part')) continue;
          final name = f.path.split('/').last;
          // Bản cũ đặt tên theo tựa đề ⇒ không suy ra được videoId. Giữ
          // nguyên tên gốc nhưng chuyển vào kho để người dùng thấy & xoá được
          // (mục sẽ hiện theo tên file thay vì tiêu đề).
          final dest = File('${dir.path}/$name');
          if (await dest.exists()) {
            await _safeDelete(f);
          } else {
            try {
              await f.rename(dest.path);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('YtMediaStore._migrateLegacyOnce: $e');
    }
  }

  static Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
