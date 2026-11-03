// lib/services/saf_model_folder_service.dart
// M4U-IMPORT-002 — Stage model (STT/Piper) từ THƯ MỤC SAF của Android.
//
// Vì sao cần:
// - `FilePicker.getDirectoryPath()` trả path/URI mà `dart:io` KHÔNG đọc được
//   (Android SAF trả `content://…`; bản cũ trả raw `/storage/…` bị scoped
//   storage chặn) ⇒ import thư mục báo "Thư mục rỗng" dù thư mục CÓ file.
// - Repo ĐÃ có native SAF đầy đủ (`in4up/textlib`: pickFolder / scanTree /
//   copyDocumentToPath) dùng cho Thư viện đọc + Từ điển → import model tái
//   dùng đúng hạ tầng đó, KHÔNG tự viết picker thứ hai.
//
// Luồng: pickFolder (native) → scanTree (đệ quy) → copy từng file về thư mục
// tạm (giữ cấu trúc thư mục con để scanner group đúng bundle) → caller
// đưa danh sách path cho `SherpaModelManager` (copy sang thư mục model) →
// xoá thư mục tạm.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'text_device_channel.dart';

/// Kết quả bước "chọn thư mục + stage file" cho luồng import model.
enum SafModelFolderOutcome {
  /// User bấm hủy / đóng picker.
  cancelled,

  /// Nền tảng không có SAF native (iOS/Desktop) — caller fallback picker
  /// thường (FilePicker) vì đó vẫn trả path thật.
  unsupported,

  /// Có lỗi (mất quyền, URI hỏng, copy lỗi) — [SafModelFolderPick.error].
  failed,

  /// Đã stage xong — [SafModelFolderPick.paths] là path thật.
  staged,
}

/// Kết quả stage thư mục model.
class SafModelFolderPick {
  final SafModelFolderOutcome outcome;

  /// Đường dẫn file thật sau khi stage (chỉ khi [outcome] == staged).
  final List<String> paths;

  /// Thư mục tạm chứa bản stage (để xoá sau khi import xong).
  final Directory? stagingDir;

  /// Tên thư mục GỐC user vừa chọn (vd `sherpa-onnx-nemo-parakeet-…`) —
  /// bằng chứng nhận diện loại model (tên bị mất khi stage về cache).
  final String? folderName;

  /// Mô tả lỗi kỹ thuật (chỉ khi [outcome] == failed).
  final String? error;

  const SafModelFolderPick._({
    required this.outcome,
    this.paths = const [],
    this.stagingDir,
    this.folderName,
    this.error,
  });

  const SafModelFolderPick.cancelled()
      : this._(outcome: SafModelFolderOutcome.cancelled);

  const SafModelFolderPick.unsupported()
      : this._(outcome: SafModelFolderOutcome.unsupported);

  const SafModelFolderPick.failed({String? error})
      : this._(outcome: SafModelFolderOutcome.failed, error: error);

  const SafModelFolderPick.staged(
    List<String> paths,
    Directory stagingDir, {
    String? folderName,
  }) : this._(
          outcome: SafModelFolderOutcome.staged,
          paths: paths,
          stagingDir: stagingDir,
          folderName: folderName,
        );

  bool get isStaged => outcome == SafModelFolderOutcome.staged;
}

/// Stage model từ thư mục SAF — dùng chung cho import STT + Piper.
class SafModelFolderService {
  /// Mở picker thư mục rồi copy file model về thư mục tạm.
  ///
  /// [extensions] — danh sách đuôi file cần lấy (chữ thường, không dấu
  /// chấm). Truyền `''` để lấy cả file không đuôi (espeak-ng-data).
  static Future<SafModelFolderPick> pickAndStage({
    required List<String> extensions,
  }) async {
    String? uri;
    try {
      uri = await TextDeviceChannel.pickFolder();
    } on MissingPluginException {
      // Không có native SAF (iOS/Desktop) → caller dùng picker thường.
      return const SafModelFolderPick.unsupported();
    } catch (e) {
      debugPrint('[SafModelFolder] pickFolder error: $e');
      return const SafModelFolderPick.failed(error: '$e');
    }
    if (uri == null || uri.isEmpty) {
      return const SafModelFolderPick.cancelled();
    }

    final List<Map<String, dynamic>> entries;
    try {
      entries = await TextDeviceChannel.scanTree(
        uri,
        extensions: extensions,
      );
    } on TextDeviceScanException catch (e) {
      return SafModelFolderPick.failed(error: e.message);
    } catch (e) {
      debugPrint('[SafModelFolder] scanTree error: $e');
      return const SafModelFolderPick.failed(error: '$e');
    }
    if (entries.isEmpty) {
      return const SafModelFolderPick.failed(error: 'no-model-files');
    }

    final staging = await _createStagingDir();
    final paths = <String>[];
    for (final entry in entries) {
      final fileUri = (entry['uri'] ?? '').toString();
      if (fileUri.isEmpty) continue;
      final relative = _safeRelativePath(
        (entry['relativePath'] ?? entry['name'] ?? '').toString(),
      );
      if (relative == null) continue;
      final destination = p.join(staging.path, relative);
      final ok = await TextDeviceChannel.copyDocumentToPath(
        fileUri,
        destination,
      );
      if (!ok) continue;
      paths.add(destination);
    }

    if (paths.isEmpty) {
      await deleteStaging(staging);
      return const SafModelFolderPick.failed(error: 'copy-failed');
    }
    return SafModelFolderPick.staged(
      paths,
      staging,
      folderName: _treeFolderName(uri),
    );
  }

  /// Tên thư mục gốc từ tree URI (best-effort).
  ///
  /// `content://…/tree/primary%3ADownload%2Fmy-model` → `my-model`.
  /// Chỉ dùng làm BẰNG CHỨNG nhận diện loại model (tên thư mục gốc bị mất
  /// khi stage về cache) — không dùng để đọc file.
  static String? _treeFolderName(String treeUri) {
    final idx = treeUri.indexOf('/tree/');
    if (idx < 0) return null;
    var docId = treeUri.substring(idx + '/tree/'.length);
    try {
      docId = Uri.decodeComponent(docId);
    } catch (_) {
      return null; // percent-encoding hỏng → không đoán
    }
    final slash = docId.lastIndexOf('/');
    final name = (slash >= 0 ? docId.substring(slash + 1) : docId).trim();
    // Dạng `primary:Download` (chưa có tên thư mục con) → không dùng.
    if (name.isEmpty || name.contains(':')) return null;
    return name;
  }

  /// Thư mục tạm cho bản stage (tự dọn sau khi import).
  static Future<Directory> _createStagingDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(
      p.join(
        base.path,
        'in4up_model_import_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Xoá thư mục tạm (best-effort, không làm app crash).
  static Future<void> deleteStaging(Directory? dir) async {
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('[SafModelFolder] xoá staging lỗi: $e');
    }
  }

  /// Đường dẫn tương đối AN TOÀN (không `..`, không tuyệt đối) — tên file do
  /// hệ điều hành trả về, không tin tuyệt đối.
  static String? _safeRelativePath(String raw) {
    var rel = raw.replaceAll('\\', '/').trim();
    if (rel.isEmpty) return null;
    final parts = <String>[];
    for (final part in rel.split('/')) {
      final clean = part.trim();
      if (clean.isEmpty || clean == '.' || clean == '..') continue;
      parts.add(clean);
    }
    if (parts.isEmpty) return null;
    return parts.join('/');
  }
}
