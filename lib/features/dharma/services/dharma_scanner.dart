// lib/features/dharma/services/dharma_scanner.dart
//
// PLAN-042 P1 — dựng catalog pháp thoại từ một thư mục người dùng chọn.
//
// Vì sao là "thư mục", không phải "danh sách file": thông tin quan trọng nhất
// (vị Thầy, khoá thiền, collection) nằm ở TÊN THƯ MỤC, không nằm trong tên
// file. `FilePicker.pickFiles` làm mất cấu trúc đó ⇒ không thể tự lập danh mục
// (xem PLAN-042 §5, F5).
//
// Hai nguồn quét:
//  1. Thiết bị: `ReadDeviceChannel.scanTree` (SAF) trên Android — dùng CHUNG
//     native channel đã có, truyền allowlist extension audio.
//  2. Máy tính: `dart:io` khi nền tảng không có SAF.
// Cả hai cùng trả `DharmaScanEntry(relativePath, source, name, sizeBytes)`, rồi
// `buildCatalog` (THUẦN, test được) biến thành `DharmaSeries`.

import 'dart:convert' show Utf8Codec;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../services/text_device_channel.dart';
import '../models/dharma_talk.dart';
import 'dharma_name_parser.dart';
import 'dharma_text.dart';

/// Một file thô đã quét được (chưa phân tích tên).
class DharmaScanEntry {
  /// Đường dẫn tương đối so với thư mục gốc, dùng `/` (kể cả Windows).
  final String relativePath;
  final String name;

  /// Địa chỉ phát: `content://…` (SAF) hoặc đường dẫn tuyệt đối.
  final String source;

  final int sizeBytes;
  final DateTime? modifiedAt;

  const DharmaScanEntry({
    required this.relativePath,
    required this.name,
    required this.source,
    this.sizeBytes = 0,
    this.modifiedAt,
  });
}

/// Danh tính nội dung của một file trên máy — dùng cho `episodeKey`.
///
/// [source] được chuẩn hoá (dấu `\` → `/`, bỏ đuôi `/`) rồi băm md5; cùng một
/// file ở hai đường dẫn khác nhau (đổi tên thư mục) vẫn khác khoá — đúng ý đồ:
/// đổi chỗ thì KHÔNG đoán, người dùng có thể sửa tay.
String localEpisodeKey(String source) {
  final normalized = source.replaceAll('\\', '/').trim();
  return 'local:${_md5Hex(normalized).substring(0, 16)}';
}

String seriesKeyFor(String relativeFolder) =>
    'local:${_md5Hex(relativeFolder.replaceAll('\\', '/')).substring(0, 12)}';

String _md5Hex(String value) =>
    md5.convert(const Utf8Codec().encode(value)).toString();

/// Có nền tảng SAF (Android) để quét thư mục đệ quy không?
bool get dharmaSafSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Quét một thư mục gốc → danh sách file audio (đệ quy).
///
/// [treeUri] = SAF tree URI (Android). [rootPath] = thư mục trên máy tính.
Future<List<DharmaScanEntry>> scanDharmaFolder({
  String? treeUri,
  String? rootPath,
  int maxFiles = 5000,
}) async {
  if (treeUri != null && treeUri.isNotEmpty) {
    // Dùng CHUNG native channel với Thư viện đọc/Video (đã có tham số
    // `extensions`) — không thêm channel mới, không cần sửa Kotlin cho P1.
    final raw = await TextDeviceChannel.scanTree(
      treeUri,
      extensions: dharmaAudioExtensions.toList(growable: false),
    );
    final out = <DharmaScanEntry>[];
    for (final item in raw) {
      final name = (item['name'] as String? ?? '').trim();
      if (name.isEmpty || !isDharmaAudioFile(name)) continue;
      final uri = item['uri'] as String? ?? '';
      if (uri.isEmpty) continue;
      // `relativeDir` do native trả về (PLAN-042) — bản build cũ không có ⇒
      // suy ra từ `relativePath` để không vỡ tương thích.
      final relativeDir = (item['relativeDir'] as String? ??
              _folderOfPath(item['relativePath'] as String? ?? name))
          .replaceAll('\\', '/');
      final relative = relativeDir.isEmpty ? name : '$relativeDir$name';
      final modifiedMs = item['dateModifiedMs'] as int? ?? 0;
      out.add(
        DharmaScanEntry(
          relativePath: relative,
          name: name,
          source: uri,
          sizeBytes: item['sizeBytes'] as int? ?? 0,
          modifiedAt: modifiedMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(modifiedMs)
              : null,
        ),
      );
      if (out.length >= maxFiles) break;
    }
    return out;
  }

  if (rootPath == null || rootPath.isEmpty) return const [];
  final root = Directory(rootPath);
  if (!await root.exists()) return const [];

  final out = <DharmaScanEntry>[];
  try {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!isDharmaAudioFile(name)) continue;
      final relative = p
          .relative(entity.path, from: root.path)
          .replaceAll('\\', '/');
      int size = 0;
      DateTime? modified;
      try {
        size = await entity.length();
        modified = (await entity.stat()).modified;
      } catch (_) {
        // File biến mất giữa lúc quét — bỏ qua, không làm hỏng cả lần quét.
      }
      out.add(
        DharmaScanEntry(
          relativePath: relative,
          name: name,
          source: entity.path.replaceAll('\\', '/'),
          sizeBytes: size,
          modifiedAt: modified,
        ),
      );
      if (out.length >= maxFiles) break;
    }
  } catch (e) {
    debugPrint('[Dharma] scanDharmaFolder lỗi: $e');
  }
  return out;
}

/// PURE — biến danh sách file thô thành catalog series.
///
/// Luật nhóm: mỗi THƯ MỤC chứa audio trực tiếp = một series. File nằm ngay ở
/// thư mục gốc được gom vào series `__root__` để không bị bỏ sót.
///
/// [rootName] dùng làm tên cho series gốc; [speakerOverrides] là bản sửa tay
/// của người dùng (khoá = seriesKey).
DharmaCatalog buildDharmaCatalog({
  required List<DharmaScanEntry> entries,
  required Map<String, String> speakerOverrides,
  String rootName = '',
  DateTime? scannedAt,
}) {
  final parser = const DharmaNameParser();
  final byFolder = <String, List<DharmaScanEntry>>{};
  for (final entry in entries) {
    final dir = _folderOf(entry.relativePath);
    byFolder.putIfAbsent(dir, () => <DharmaScanEntry>[]).add(entry);
  }

  final series = <DharmaSeries>[];
  for (final folderEntry in byFolder.entries) {
    final relativeFolder = folderEntry.key;
    final folderName = relativeFolder.isEmpty
        ? (rootName.isEmpty ? 'Pháp thoại' : rootName)
        : _lastSegment(relativeFolder);
    final seriesKey = seriesKeyFor(
      relativeFolder.isEmpty ? '__root__' : relativeFolder,
    );
    final refs = folderEntry.value.map((e) {
      return DharmaFileRef(
        name: e.name,
        source: e.source,
        episodeKey: localEpisodeKey(e.source),
        sourceKind: DharmaSourceKind.local,
        sizeBytes: e.sizeBytes,
        modifiedAt: e.modifiedAt,
      );
    });

    series.add(
      parser.buildSeries(
        folderName: folderName,
        relativeFolder: relativeFolder,
        seriesKey: seriesKey,
        files: refs,
        speakerOverride: speakerOverrides[seriesKey],
      ),
    );
  }

  // Thứ tự hiển thị: collection → số thứ tự → tên (natural).
  series.sort((a, b) {
    final byCollection = a.collection.index.compareTo(b.collection.index);
    if (byCollection != 0) return byCollection;
    final oa = a.orderIndex;
    final ob = b.orderIndex;
    if (oa != null && ob != null && oa != ob) return oa.compareTo(ob);
    if (oa != null && ob == null) return -1;
    if (oa == null && ob != null) return 1;
    return naturalCompare(a.title, b.title);
  });

  return DharmaCatalog(
    series: List.unmodifiable(series),
    scannedAt: scannedAt ?? DateTime.now(),
  );
}

/// Kết quả một lần quét.
class DharmaCatalog {
  final List<DharmaSeries> series;
  final DateTime scannedAt;

  const DharmaCatalog({required this.series, required this.scannedAt});

  int get episodeCount =>
      series.fold<int>(0, (sum, s) => sum + s.episodeCount);

  bool get isEmpty => episodeCount == 0;

  /// Gom series theo vị Thầy đã chuẩn hoá — bộ lọc "Theo Thầy".
  Map<String, List<DharmaSeries>> groupBySpeaker() {
    final out = <String, List<DharmaSeries>>{};
    for (final s in series) {
      out.putIfAbsent(s.speakerGroupKey, () => <DharmaSeries>[]).add(s);
    }
    return out;
  }

  /// Tra một buổi theo `episodeKey` (điểm vào từ thông báo/xem lại).
  DharmaEpisode? findEpisode(String episodeKey) {
    for (final s in series) {
      for (final e in s.episodes) {
        if (e.episodeKey == episodeKey) return e;
      }
    }
    return null;
  }

  DharmaSeries? findSeriesOfEpisode(String episodeKey) {
    for (final s in series) {
      if (s.episodes.any((e) => e.episodeKey == episodeKey)) return s;
    }
    return null;
  }
}

String _folderOfPath(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  if (idx < 0) return '';
  return normalized.substring(0, idx + 1);
}

String _folderOf(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  if (idx < 0) return '';
  return normalized.substring(0, idx);
}

String _lastSegment(String folder) {
  final normalized = folder.replaceAll('\\', '/');
  final parts = normalized.split('/').where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? folder : parts.last;
}
