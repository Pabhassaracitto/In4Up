// lib/features/video/services/video_library_logic.dart
// I4U18-VIDEO-LIB-001 — LOGIC THUẦN (test được, không I/O, không Flutter).
//
// Chứa mọi phần "khó đúng" của thư viện video để kiểm bằng unit test:
//  - Nhận diện video/phụ đề theo extension.
//  - Tách folder key + basename từ file path lẫn content:// (SAF) URI.
//  - Ghép phụ đề cùng tên/thư mục (matchSubtitle).
//  - Hợp nhất kết quả quét với chỉ mục cũ, GIỮ favorite / vị trí phát /
//    lastPlayed / phụ đề đã ghép (mergeScanned) → không mất dữ liệu, không
//    trùng lặp khi quét lại.
//  - Lọc / sắp xếp / tìm kiếm (filterAndSort).

import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart';

import '../models/video_info.dart';

/// Extension video hỗ trợ (chữ thường, không dấu chấm).
const Set<String> kVideoExtensions = {
  'mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v', '3gp', 'flv', 'ts', 'mpg', 'mpeg',
  'wmv', 'ogv',
};

/// Extension phụ đề hỗ trợ.
const Set<String> kSubtitleExtensions = {
  'srt', 'vtt', 'ass', 'ssa', 'sub', 'lrc',
};

/// Extension truyền xuống native scanTree (video + phụ đề trong một lượt).
List<String> get videoScanExtensions =>
    [...kVideoExtensions, ...kSubtitleExtensions];

/// Item thô trả về từ scanTree native: { uri, name, sizeBytes, dateModifiedMs, ext }.
class VideoScanItem {
  final String uri;
  final String name;
  final int sizeBytes;
  final int dateModifiedMs;
  final String ext;

  const VideoScanItem({
    required this.uri,
    required this.name,
    required this.sizeBytes,
    required this.dateModifiedMs,
    required this.ext,
  });

  factory VideoScanItem.fromMap(Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString();
    var ext = (m['ext'] ?? '').toString().toLowerCase();
    if (ext.isEmpty) ext = VideoLibraryLogic.extensionOf(name);
    return VideoScanItem(
      uri: (m['uri'] ?? '').toString(),
      name: name,
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
      dateModifiedMs: (m['dateModifiedMs'] as num?)?.toInt() ?? 0,
      ext: ext,
    );
  }

  bool get isVideo => kVideoExtensions.contains(ext);
  bool get isSubtitle => kSubtitleExtensions.contains(ext);
}

class VideoLibraryLogic {
  const VideoLibraryLogic._();

  /// Extension chữ thường (không dấu chấm) suy ra từ tên file.
  static String extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot >= name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Bỏ extension khỏi tên file → "movie.mp4" → "movie".
  static String stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  /// ID ổn định cho một URI (không phụ thuộc mtime → quét lại không đổi id →
  /// không trùng lặp). Chuẩn hoá \\ → / và về chữ thường.
  static String stableId(String uri) {
    final norm = uri.replaceAll('\\', '/').toLowerCase();
    return 'vid_${md5.convert(utf8.encode(norm)).toString().substring(0, 16)}';
  }

  /// URI chuẩn hoá (\\ → /) — khoá de-dupe.
  static String normalizeUri(String uri) => uri.replaceAll('\\', '/');

  /// Tách "khoá thư mục" từ path hoặc content:// URI.
  ///
  /// - File path: thư mục cha (chuẩn hoá \\ → /).
  /// - content:// SAF: giải mã document id sau "/document/" (hoặc "/tree/")
  ///   rồi lấy phần trước tên file. Vd
  ///   `.../document/primary%3AMovies%2Fsub%2Fa.mp4` → `primary:Movies/sub`.
  static String folderKey(String uri) {
    final u = normalizeUri(uri);
    if (u.startsWith('content://')) {
      final docId = _safDocId(u);
      if (docId.isEmpty) return '';
      final slash = docId.lastIndexOf('/');
      return slash >= 0 ? docId.substring(0, slash) : docId;
    }
    final slash = u.lastIndexOf('/');
    return slash > 0 ? u.substring(0, slash) : '';
  }

  /// Tên thư mục hiển thị (segment cuối của folderKey, sau dấu ':').
  static String folderLabel(String uri) {
    final key = folderKey(uri);
    if (key.isEmpty) return '';
    final colon = key.lastIndexOf(':');
    final tail = colon >= 0 ? key.substring(colon + 1) : key;
    final segs = tail.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.isNotEmpty) return segs.last;
    // Root của ổ (vd "primary:") → tên ổ.
    return key.split(':').first;
  }

  static String _safDocId(String uri) {
    final marker = uri.contains('/document/') ? '/document/' : '/tree/';
    final idx = uri.indexOf(marker);
    if (idx < 0) return '';
    final raw = uri.substring(idx + marker.length);
    return _safeDecode(raw);
  }

  /// Giải mã %XX AN TOÀN — giữ nguyên % lỗi (không throw).
  static String _safeDecode(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      final bytes = <int>[];
      var i = 0;
      while (i < s.length) {
        final c = s[i];
        if (c == '%' && i + 2 < s.length) {
          final code = int.tryParse(s.substring(i + 1, i + 3), radix: 16);
          if (code != null) {
            bytes.add(code);
            i += 3;
            continue;
          }
        }
        bytes.addAll(utf8.encode(c));
        i++;
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// Ghép phụ đề cho một video: ưu tiên
  ///   1) cùng thư mục + cùng basename (không tính extension ngôn ngữ);
  ///   2) cùng basename bất kỳ thư mục;
  ///   3) trong cùng thư mục có đúng 1 phụ đề → dùng.
  /// Trả URI phụ đề hoặc null.
  ///
  /// Xử lý phụ đề đa ngữ: `movie.en.srt` khớp `movie.mp4` (so khớp phần
  /// đầu trước dấu chấm ngôn ngữ).
  static String? matchSubtitle(
    VideoScanItem video,
    List<VideoScanItem> subtitles, {
    bool allowLooseSingle = true,
  }) {
    if (subtitles.isEmpty) return null;
    final vBase = stripExtension(video.name).toLowerCase();
    final vFolder = folderKey(video.uri);

    VideoScanItem? sameFolderExact;
    VideoScanItem? anyExact;
    VideoScanItem? sameFolderPrefix;
    final sameFolder = <VideoScanItem>[];

    for (final s in subtitles) {
      final sBase = stripExtension(s.name).toLowerCase();
      final sFolder = folderKey(s.uri);
      final inSameFolder = sFolder == vFolder;
      if (inSameFolder) sameFolder.add(s);

      if (sBase == vBase) {
        if (inSameFolder) {
          sameFolderExact ??= s;
        } else {
          anyExact ??= s;
        }
        continue;
      }
      // Đa ngữ: "movie.en" bắt đầu bằng "movie." → khớp prefix.
      if (inSameFolder &&
          sBase.startsWith('$vBase.') &&
          sameFolderPrefix == null) {
        sameFolderPrefix = s;
      }
    }

    if (sameFolderExact != null) return sameFolderExact.uri;
    if (sameFolderPrefix != null) return sameFolderPrefix.uri;
    if (anyExact != null) return anyExact.uri;
    // Fallback lỏng: thư mục có đúng 1 phụ đề → dùng, NHƯNG chỉ khi caller cho
    // phép (buildFromScan chỉ bật khi thư mục có đúng 1 video → tránh gán
    // nhầm phụ đề của video khác).
    if (allowLooseSingle && sameFolder.length == 1) return sameFolder.first.uri;
    return null;
  }

  /// Dựng VideoInfo từ item quét được + phụ đề đã ghép.
  static VideoInfo toVideoInfo(
    VideoScanItem item, {
    String? subtitleUri,
  }) {
    final uri = normalizeUri(item.uri);
    return VideoInfo(
      id: stableId(uri),
      title: stripExtension(item.name),
      filePath: uri,
      duration: Duration.zero,
      addedAt: DateTime.now(),
      sizeBytes: item.sizeBytes,
      dateModified: item.dateModifiedMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(item.dateModifiedMs)
          : null,
      folder: folderLabel(uri),
      source: VideoSource.folder,
      subtitlePath: subtitleUri,
    );
  }

  /// Chuyển toàn bộ kết quả quét (video + phụ đề) → danh sách VideoInfo có
  /// phụ đề ghép sẵn.
  static List<VideoInfo> buildFromScan(List<VideoScanItem> items) {
    final videos = items.where((e) => e.isVideo).toList();
    final subs = items.where((e) => e.isSubtitle).toList();
    // Đếm số video theo thư mục → chỉ cho phép fallback "1 phụ đề trong thư
    // mục" khi thư mục đó có đúng 1 video (tránh gán nhầm sang video khác).
    final videoPerFolder = <String, int>{};
    for (final v in videos) {
      final f = folderKey(v.uri);
      videoPerFolder[f] = (videoPerFolder[f] ?? 0) + 1;
    }
    return [
      for (final v in videos)
        toVideoInfo(
          v,
          subtitleUri: matchSubtitle(
            v,
            subs,
            allowLooseSingle: (videoPerFolder[folderKey(v.uri)] ?? 0) <= 1,
          ),
        ),
    ];
  }

  /// Hợp nhất kết quả quét mới với chỉ mục cũ.
  ///
  /// - De-dupe theo URI chuẩn hoá (quét lại KHÔNG tạo bản trùng).
  /// - Entry đã có: GIỮ favorite, lastPositionMs, lastPlayed, thumbnail,
  ///   duration; cập nhật phụ đề nếu quét mới tìm được (không xoá phụ đề cũ
  ///   nếu quét mới không thấy).
  /// - Entry cũ nguồn `picked` (import thủ công) LUÔN giữ dù không còn trong
  ///   thư mục quét.
  /// - Entry cũ nguồn `folder` biến mất khỏi lần quét mới → bỏ (file đã xoá).
  static List<VideoInfo> mergeScanned(
    List<VideoInfo> scanned,
    List<VideoInfo> existing,
  ) {
    final byUri = <String, VideoInfo>{
      for (final e in existing) normalizeUri(e.filePath): e,
    };

    final merged = <VideoInfo>[];
    final seen = <String>{};

    for (final entry in scanned) {
      final key = normalizeUri(entry.filePath);
      if (seen.contains(key)) continue;
      seen.add(key);
      final old = byUri[key];
      if (old != null) {
        merged.add(old.copyWith(
          title: entry.title,
          duration: old.duration.inMilliseconds > 0 ? old.duration : entry.duration,
          sizeBytes: entry.sizeBytes,
          dateModified: entry.dateModified,
          folder: entry.folder,
          source: entry.source,
          subtitlePath: entry.subtitlePath ?? old.subtitlePath,
        ));
        byUri.remove(key);
      } else {
        merged.add(entry);
      }
    }

    // Giữ các entry import thủ công (picked) dù không còn trong thư mục quét.
    for (final old in byUri.values) {
      if (old.source == VideoSource.picked && !seen.contains(normalizeUri(old.filePath))) {
        merged.add(old);
      }
    }

    return merged;
  }
}

/// Tiêu chí sắp xếp thư viện video.
enum VideoSort { titleAsc, dateNewest, durationLongest, folder }

/// Chế độ lọc nhanh.
enum VideoFilter { all, favorites, recent, hasSubtitle }

extension VideoLibraryQuery on List<VideoInfo> {
  /// Lọc + tìm + sắp xếp (không đột biến danh sách gốc).
  List<VideoInfo> query({
    String search = '',
    VideoFilter filter = VideoFilter.all,
    VideoSort sort = VideoSort.dateNewest,
    String? folder,
  }) {
    final q = search.trim().toLowerCase();
    final now = DateTime.now();

    var list = where((v) {
      if (q.isNotEmpty &&
          !v.title.toLowerCase().contains(q) &&
          !v.folder.toLowerCase().contains(q)) {
        return false;
      }
      if (folder != null && folder.isNotEmpty && v.folder != folder) {
        return false;
      }
      switch (filter) {
        case VideoFilter.favorites:
          return v.favorite;
        case VideoFilter.recent:
          return v.lastPlayed != null &&
              now.difference(v.lastPlayed!) < const Duration(days: 30);
        case VideoFilter.hasSubtitle:
          return v.hasSubtitle;
        case VideoFilter.all:
          return true;
      }
    }).toList();

    switch (sort) {
      case VideoSort.titleAsc:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case VideoSort.dateNewest:
        list.sort((a, b) {
          final da = a.dateModified ?? a.addedAt;
          final db = b.dateModified ?? b.addedAt;
          return db.compareTo(da);
        });
        break;
      case VideoSort.durationLongest:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case VideoSort.folder:
        list.sort((a, b) {
          final f = a.folder.toLowerCase().compareTo(b.folder.toLowerCase());
          if (f != 0) return f;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
    return list;
  }

  /// Danh sách thư mục duy nhất (đã sắp xếp) — cho bộ lọc theo thư mục.
  List<String> get folders {
    final set = <String>{};
    for (final v in this) {
      if (v.folder.isNotEmpty) set.add(v.folder);
    }
    final list = set.toList()..sort();
    return list;
  }
}
