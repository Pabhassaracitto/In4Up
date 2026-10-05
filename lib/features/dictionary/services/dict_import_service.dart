import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/dict_info.dart';
import 'dict_bundle_scanner.dart';
import 'dict_device_channel.dart';
import 'dictionary_service.dart';

/// Service import file từ điển từ device (I4U18-DICT-001).
///
/// Hỗ trợ 2 nguồn: **thư mục** (walk đệ quy → scanner ghép set mdx+mdd+css)
/// và **nhiều file** (multi-file pick phẳng), qua 2 chế độ: link/index
/// (không copy dữ liệu lớn) hoặc import/copy vào app storage.
class DictImportService {
  /// Chọn và import file .mdx đơn lẻ (đường cũ — giữ tương thích).
  static Future<DictInfo?> pickAndImportMdx({
    void Function(double progress, String message)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx'],
    );

    if (result == null || result.files.isEmpty) return null;
    final mdxPath = result.files.single.path;
    if (mdxPath == null) return null;

    return await DictionaryService.instance.importMdx(
      mdxPath,
      onProgress: onProgress,
    );
  }

  /// Chọn THƯ MỤC chứa bộ từ điển (mdx + mdd + css/asset) → import theo
  /// [mode]. Trả outcome để UI báo phần import được + file phụ còn thiếu.
  static Future<DictImportOutcome> pickFolderAndImport(
    DictStorageMode mode, {
    void Function(double progress, String message)? onProgress,
  }) async {
    // Android's file_picker directory API returns a raw /storage path.  On
    // scoped-storage devices that path is not readable by dart:io even though
    // the user just granted access.  Use the app's SAF bridge there, then
    // stage seekable copies for the common MDX parser.
    if (Platform.isAndroid) {
      return _pickAndroidSafFolderAndImport(
        onProgress: onProgress,
      );
    }

    final dirPath = await FilePicker.getDirectoryPath();
    if (dirPath == null || dirPath.isEmpty) {
      return const DictImportOutcome(error: 'Chưa chọn thư mục');
    }

    onProgress?.call(0.05, 'Đang quét thư mục…');
    final files = await _walkFiles(dirPath);
    if (files.isEmpty) {
      return const DictImportOutcome(
        error: 'Thư mục rỗng hoặc app không đọc được (quyền truy cập). '
            'Thử chọn nhiều file thay vì thư mục.',
      );
    }

    return DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: files,
      rootPath: DictBundleScanner.normSep(dirPath),
      mode: mode,
      onProgress: onProgress,
    );
  }

  static const Set<String> _androidDictionaryExtensions = {
    'mdx',
    'mdd',
    'css',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'svg',
    'bmp',
    'wav',
    'mp3',
    'ogg',
    'm4a',
    'ttf',
    'otf',
    'woff',
    'woff2',
  };

  /// Android SAF does not give Dart a seekable path.  Copy the selected
  /// documents into a private staging folder, import them with the normal
  /// service, and remove the staging folder afterwards.  The final import is
  /// deliberately [DictStorageMode.imported]: a cache/content URI is not a
  /// durable "linked" source after the app or provider is restarted.
  static Future<DictImportOutcome> _pickAndroidSafFolderAndImport({
    void Function(double progress, String message)? onProgress,
  }) async {
    String? treeUri;
    try {
      treeUri = await DictDeviceChannel.pickFolder();
      if (treeUri == null || treeUri!.isEmpty) {
        return const DictImportOutcome(error: 'Chưa chọn thư mục');
      }

      onProgress?.call(0.05, 'Đang quét thư mục…');
      final files = await DictDeviceChannel.scanFolder(
        treeUri!,
        extensions: _androidDictionaryExtensions,
      );
      if (files.isEmpty) {
        return const DictImportOutcome(
          error: 'Thư mục rỗng hoặc không có file từ điển (.mdx)',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final staging = Directory(
        '${tempDir.path}/in4up_dictionary_${DateTime.now().microsecondsSinceEpoch}',
      );
      await staging.create(recursive: true);
      try {
        final stagedPaths = <String>[];
        var copied = 0;
        for (final file in files) {
          final relative = _safeRelativePath(file.relativePath, file.name);
          if (relative == null || file.uri.isEmpty) continue;
          final destination = '${staging.path}/$relative';
          onProgress?.call(
            0.10 + 0.55 * (copied / files.length),
            'Đang chuẩn bị ${file.name}…',
          );
          final ok = await DictDeviceChannel.copyDocumentToPath(
            file.uri,
            destination,
          );
          if (ok) {
            stagedPaths.add(destination);
          } else if (file.extension == 'mdx') {
            return DictImportOutcome(
              error: 'Không thể đọc file MDX qua bộ nhớ thiết bị: ${file.name}',
            );
          }
          copied++;
        }

        if (!stagedPaths.any(
          (path) => DictBundleScanner.isMdxName(path),
        )) {
          return const DictImportOutcome(
            error: 'Không thể đọc file .mdx trong thư mục đã chọn',
          );
        }

        // SAF grants are valid only through the provider URI.  The service
        // copies the staged set into documents/ before this temporary folder
        // is removed, so the manifest never points at cache storage.
        return DictionaryService.instance.importDictionaryBundle(
          absoluteFilePaths: stagedPaths,
          rootPath: DictBundleScanner.normSep(staging.path),
          mode: DictStorageMode.imported,
          onProgress: onProgress,
        );
      } finally {
        try {
          if (await staging.exists()) {
            await staging.delete(recursive: true);
          }
        } catch (_) {
          // Cache cleanup is best effort; it must not hide an import result.
        }
      }
    } on Exception catch (error) {
      return DictImportOutcome(
        error: 'Không thể đọc thư mục từ thiết bị: $error',
      );
    }
  }

  /// Keep provider paths inside the private staging root.  SAF providers are
  /// not expected to return `..`, but rejecting it avoids turning a display
  /// name into a path traversal when copying user-controlled files.
  static String? _safeRelativePath(String raw, String fallbackName) {
    final candidate = DictBundleScanner.normSep(
      raw.trim().isEmpty ? fallbackName : raw,
    );
    final parts = candidate
        .split('/')
        .where((part) => part.isNotEmpty && part != '.')
        .toList();
    if (parts.isEmpty || parts.any((part) => part == '..')) return null;
    return parts.join('/');
  }

  /// Chọn NHIỀU FILE (mdx + mdd + css chọn tay) → import theo [mode].
  ///
  /// File phụ thiếu (quên chọn .mdd/.css) được báo rõ trong outcome;
  /// từ điển vẫn dùng được ở chế độ giảm cấp.
  static Future<DictImportOutcome> pickFilesAndImport(
    DictStorageMode mode, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx', 'mdd', 'css'],
      allowMultiple: true,
      // Android providers may return a content URI without a usable path.
      // Keep a stream available as a fallback without loading a large MDX
      // into PlatformFile.bytes.
      withData: false,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) {
      return const DictImportOutcome(error: 'Chưa chọn file nào');
    }

    final paths = <String>[
      for (final f in result.files)
        if (f.path != null && f.path!.isNotEmpty) f.path!,
    ];
    if (paths.isEmpty || paths.length != result.files.length) {
      final streamPaths = await _materializePickedStreams(result.files);
      paths.addAll(streamPaths);
    }
    if (paths.isEmpty) {
      return const DictImportOutcome(
        error: 'Không đọc được file (SAF). Thử chọn cả thư mục.',
      );
    }

    // A file_picker Android path is normally a temporary cache copy.  Treat
    // it as an import even when the caller requested link mode; otherwise the
    // manifest would point to a cache file that disappears after restart.
    final effectiveMode = Platform.isAndroid
        ? DictStorageMode.imported
        : mode;
    final stagedStreamPaths = [
      ...paths.where((path) => path.contains('/in4up_dictionary_files_')),
    ];
    try {
      return await DictionaryService.instance.importDictionaryBundle(
        absoluteFilePaths: paths,
        rootPath: '',
        mode: effectiveMode,
        onProgress: onProgress,
      );
    } finally {
      final stagingRoots = <String>{
        for (final path in stagedStreamPaths)
          File(path).parent.path,
      };
      for (final root in stagingRoots) {
        try {
          final dir = Directory(root);
          if (await dir.exists()) await dir.delete(recursive: true);
        } catch (_) {
          // Cache cleanup is best effort.
        }
      }
    }
  }

  /// Materialize only the files for which file_picker could not provide a
  /// normal path.  `withReadStream` keeps this fallback safe for large MDX
  /// files; unlike `withData`, it never allocates the whole file in Dart.
  static Future<List<String>> _materializePickedStreams(
    List<PlatformFile> files,
  ) async {
    final needsMaterializing = files.where(
      (file) => file.path == null && file.readStream != null,
    );
    if (needsMaterializing.isEmpty) return const [];

    final tempDir = await getTemporaryDirectory();
    final root = Directory(
      '${tempDir.path}/in4up_dictionary_files_${DateTime.now().microsecondsSinceEpoch}',
    );
    await root.create(recursive: true);
    final paths = <String>[];
    try {
      for (final file in needsMaterializing) {
        final safeName = _safeFileName(file.name);
        if (safeName == null) continue;
        final target = File('${root.path}/$safeName');
        final sink = target.openWrite();
        try {
          await for (final chunk in file.readStream!) {
            sink.add(chunk);
          }
          await sink.flush();
          await sink.close();
          paths.add(target.path);
        } catch (_) {
          await sink.close();
          try {
            await target.delete();
          } catch (_) {
            // Best effort cleanup.
          }
        }
      }
      return paths;
    } catch (_) {
      return paths;
    }
  }

  static String? _safeFileName(String name) {
    final normalized = DictBundleScanner.normSep(name);
    final leaf = normalized.split('/').last.trim();
    if (leaf.isEmpty || leaf == '.' || leaf == '..' || leaf.contains('\\')) {
      return null;
    }
    return leaf;
  }

  /// Walk đệ quy (giới hạn độ sâu + số file → không treo trên folder lớn
  /// kiểu Downloads nặng, vẫn bắt được mdx/mdd/css ở 1-2 tầng con).
  static Future<List<String>> _walkFiles(String rootPath) async {
    final out = <String>[];
    Future<void> walk(Directory dir, int depth) async {
      if (depth > 4 || out.length > 4000) return;
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (out.length > 4000) return;
          if (entity is Directory) {
            await walk(entity, depth + 1);
          } else if (entity is File) {
            out.add(entity.path);
          }
        }
      } catch (_) {
        // folder con không đọc được (quyền) → bỏ qua, không fail cả lượt.
      }
    }

    await walk(Directory(rootPath), 0);
    return out;
  }
}
