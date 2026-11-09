import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file discovered through Android's Storage Access Framework (SAF).
///
/// SAF intentionally does not expose a normal filesystem path. The URI is a
/// durable document URI covered by the selected tree/document grant.
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

class DictSafHandle {
  final String id;
  final int length;

  const DictSafHandle({required this.id, required this.length});
}

class DictDeviceChannelException implements Exception {
  final String code;
  final String? message;

  const DictDeviceChannelException(this.code, this.message);

  @override
  String toString() => message ?? code;
}

/// Android-only bridge for dictionary folders/documents selected with SAF.
class DictDeviceChannel {
  DictDeviceChannel._();

  static const MethodChannel _channel = MethodChannel('in4up/dictionary');

  @visibleForTesting
  static bool? isSupportedOverride;

  static bool get isSupported => isSupportedOverride ?? Platform.isAndroid;

  static Future<String?> pickFolder() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('pickFolder');
    } on PlatformException catch (error) {
      debugPrint('[DictionaryDevice] pickFolder: ${error.code} ${error.message}');
      throw DictDeviceChannelException(error.code, error.message);
    }
  }

  /// Native multi-document SAF picker; each returned URI has a persisted read
  /// grant so linked files remain accessible after process restart.
  static Future<List<DictDeviceFile>?> pickDocuments({
    required Set<String> extensions,
  }) async {
    if (!isSupported) return null;
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'pickDocuments',
        <String, dynamic>{
          'extensions': extensions.toList(growable: false),
        },
      );
      if (raw == null) return null;
      return [
        for (final item in raw)
          if (item is Map) DictDeviceFile.fromMap(item),
      ];
    } on PlatformException catch (error) {
      debugPrint('[DictionaryDevice] pickDocuments: ${error.code} ${error.message}');
      throw DictDeviceChannelException(error.code, error.message);
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
      throw DictDeviceChannelException(error.code, error.message);
    }
  }

  static Future<bool> isDocumentAccessible(String uri) async {
    if (!isSupported || uri.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isDocumentAccessible',
            <String, dynamic>{'uri': uri},
          ) ??
          false;
    } on PlatformException catch (error) {
      debugPrint(
        '[DictionaryDevice] isDocumentAccessible: ${error.code} ${error.message}',
      );
      return false;
    }
  }

  static Future<DictSafHandle> openRandomAccess(String uri) async {
    if (!isSupported) {
      throw const DictDeviceChannelException(
        'UNSUPPORTED',
        'SAF random access is available only on Android.',
      );
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'openRandomAccess',
        <String, dynamic>{'uri': uri},
      );
      if (raw == null || raw['id'] == null || raw['length'] == null) {
        throw const DictDeviceChannelException(
          'SOURCE_UNAVAILABLE',
          'The selected dictionary file could not be opened.',
        );
      }
      return DictSafHandle(
        id: raw['id'].toString(),
        length: (raw['length'] as num).toInt(),
      );
    } on PlatformException catch (error) {
      debugPrint(
        '[DictionaryDevice] openRandomAccess: ${error.code} ${error.message}',
      );
      throw DictDeviceChannelException(error.code, error.message);
    }
  }

  static Future<Uint8List> readRandomAccess(
    String handle, {
    required int offset,
    required int count,
  }) async {
    try {
      final raw = await _channel.invokeMethod<Uint8List>(
        'readRandomAccess',
        <String, dynamic>{
          'id': handle,
          'offset': offset,
          'count': count,
        },
      );
      return raw ?? Uint8List(0);
    } on PlatformException catch (error) {
      debugPrint(
        '[DictionaryDevice] readRandomAccess: ${error.code} ${error.message}',
      );
      throw DictDeviceChannelException(error.code, error.message);
    }
  }

  static Future<void> closeRandomAccess(String handle) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(
        'closeRandomAccess',
        <String, dynamic>{'id': handle},
      );
    } on PlatformException catch (error) {
      debugPrint(
        '[DictionaryDevice] closeRandomAccess: ${error.code} ${error.message}',
      );
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
      throw DictDeviceChannelException(error.code, error.message);
    }
  }
}
