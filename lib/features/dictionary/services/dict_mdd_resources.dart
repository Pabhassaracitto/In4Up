import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import '../models/dict_info.dart';
import 'dict_bundle_scanner.dart';
import 'mdd_reader.dart';
import 'random_access_source.dart';

/// Resource lookup for one registered dictionary. Only paths assigned to that
/// dictionary at import/relink are eligible. No HTML-provided filesystem paths
/// or network URLs are opened. Not yet suitable to call from a UI isolate:
/// indexing/decompression must first be moved off the main isolate.
class DictMddResources {
  static const int maxLegacyDirectoryEntries = 4000;
  final DictInfo info;

  const DictMddResources(this.info);

  /// Return MDD parts in precedence order. Null/empty legacy manifests are
  /// different: an explicit empty list never discovers newly added files.
  Future<List<String>> locations() async {
    if (info.mddPaths != null) return List.unmodifiable(info.mddPaths!);

    // Older SAF manifests already contain only files assigned to this set.
    if (info.sourceUris.isNotEmpty) {
      final files = <DictScannedFile>[
        for (final name in info.sourceUris.keys)
          if (DictBundleScanner.isMddName(name)) DictScannedFile(name),
      ];
      return [for (final file in DictBundleScanner.sortMddFiles(files)) info.sourceUris[file.path]!];
    }
    // Old filesystem manifests didn't record files explicitly. Conservatively
    // discover only exact MDX-stem matches in the recorded directory; never
    // guess arbitrary fallback files or recurse into other dictionaries.
    final directory = info.resourcePath;
    final mdxName = info.sourceFileName;
    if (directory == null || mdxName == null ||
        !path.isAbsolute(directory) || !DictBundleScanner.isMdxName(mdxName)) {
      return const [];
    }
    final stem = DictBundleScanner.mdxStem(mdxName);
    final candidates = <DictScannedFile>[];
    var seen = 0;
    try {
      await for (final entity in Directory(directory).list(followLinks: false)) {
        if (++seen > maxLegacyDirectoryEntries) {
          throw const FormatException('MDD legacy directory exceeds limit');
        }
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        if (DictBundleScanner.isMddName(name) &&
            DictBundleScanner.mddStem(name) == stem) {
          candidates.add(DictScannedFile(entity.path));
        }
      }
    } on FileSystemException catch (error) {
      throw RandomAccessSourceException('SOURCE_UNAVAILABLE', error.message);
    }
    return [for (final file in DictBundleScanner.sortMddFiles(candidates)) file.path];
  }

  /// Missing key/part returns null. Unreadable, unsupported or corrupt parts
  /// propagate errors, including SAF revocation; they are never called missing.
  Future<Uint8List?> read(String key) async {
    if (MddReader.normalizeKey(key) == null) return null;
    final paths = await locations();
    if (paths.length > MddParts.maxParts) throw const FormatException('Too many MDD parts');
    return MddParts([
      for (final location in paths) () => openLocation(location),
    ]).readResource(key);
  }

  /// Opens only an already-registered location; never pass an HTML resource key.
  static Future<RandomAccessSource> openLocation(String location) {
    final uri = Uri.tryParse(location);
    if (uri?.scheme == 'content' && uri!.host.isNotEmpty) {
      return SafRandomAccessSource.open(location);
    }
    if (path.isAbsolute(location) && (uri == null || uri.scheme.isEmpty ||
        (Platform.isWindows && uri.scheme.length == 1))) {
      return FileRandomAccessSource.open(location);
    }
    throw const FormatException('Invalid MDD source location');
  }
}
