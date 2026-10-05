import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file discovered through Android's Storage Access Framework (SAF).
///
/// SAF intentionally does not expose a normal filesystem path.  The
/// dictionary parser needs seekable files, so the import flow stages these
/// documents into app storage before handing them to the platform-independent
/// MDX parser.
class DictDeviceFile {
  final String uri;
  final String name;
  final String relativePath;
  final int sizeBytes;
  final String extension;

  const DictDeviceFile({
    required this.uri,
    required this.name,
    required this.relativePath,
    required this.sizeBytes,
    required this.extension,
  });

  factory DictDeviceFile.fromMap(Map<dynamic, dynamic> map) {
    final name = (map['name'] ?? '').toString();
    final relativePath = (map['relativePath'] ?? name).toString();
    return DictDeviceFile(
      uri: (map['uri'] ?? '').toString(),
      name: name,
      relativePath: relativePath,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      extension: (map['ext'] ?? '').toString().toLowerCase(),
    );
  }
}

/// Android-only bridge for dictionary folders selected with SAF.
class DictDeviceChannel {
  DictDeviceChannel._();

  static const MethodChannel _channel = MethodChannel('in4up/dictionary');

  static bool get isSupported => Platform.isAndroid;

  static Future<String?> pickFolder() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('pickFolder');
    } on PlatformException catch (error) {
      debugPrint('[DictionaryDevice] pickFolder: ${error.code} ${error.message}');
      rethrow;
    }
  }

  static Future<List<DictDeviceFile>> scanFolder(
    String treeUri, {
    required Set<String> extensions,
  }) async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'scanFolder',
        <String, dynamic>{
          'treeUri': treeUri,
          'extensions': extensions.toList(growable: false),
        },
      );
      return [
        for (final item in raw ?? const <dynamic>[])
          if (item is Map) DictDeviceFile.fromMap(item),
      ];
    } on PlatformException catch (error) {
      debugPrint('[DictionaryDevice] scanFolder: ${error.code} ${error.message}');
      rethrow;
    }
  }

  static Future<bool> copyDocumentToPath(
    String uri,
    String destination,
  ) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'copyDocumentToPath',
            <String, dynamic>{'uri': uri, 'destination': destination},
          ) ??
          false;
    } on PlatformException catch (error) {
      debugPrint(
        '[DictionaryDevice] copyDocumentToPath: '
        '${error.code} ${error.message}',
      );
      rethrow;
    }
  }
}
