// Persistent lookup for STT/LRC (and later document cases).
// LRC files live in app-documents `.in4up_lrc/` (see SttServiceFacade).
// Opening the same MP3 again must find that file — not hashCode next to the
// original (often unwritable / unstable on Android SAF).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CachedLrcHit {
  final String lrcPath;
  final int lineCount;
  final DateTime? savedAt;

  const CachedLrcHit({
    required this.lrcPath,
    this.lineCount = 0,
    this.savedAt,
  });
}

class SourceArtifactStore {
  SourceArtifactStore._();
  static final SourceArtifactStore instance = SourceArtifactStore._();

  static const _indexFileName = 'index.json';

  Future<String> lrcDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, '.in4up_lrc'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static String normalizePath(String path) {
    try {
      return Uri.decodeFull(path.replaceAll(r'\', '/').toLowerCase().trim());
    } catch (_) {
      return path.replaceAll(r'\', '/').toLowerCase().trim();
    }
  }

  static String basenameNoExt(String path) {
    final name = normalizePath(path).split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static String sidecarLrcPath(String audioPath) {
    final n = audioPath.replaceAll(r'\', '/');
    final dot = n.lastIndexOf('.');
    final slash = n.lastIndexOf('/');
    if (dot > slash && dot >= 0) return '${n.substring(0, dot)}.lrc';
    return '$n.lrc';
  }

  /// Stable fingerprint: size + basename (+ duration when known).
  /// Matches ContentId / AudioFingerprintUtil idea without depending on player.
  static Future<String> fingerprint(
    String audioPath, {
    int durationMs = 0,
  }) async {
    final base = basenameNoExt(audioPath);
    var size = 0;
    try {
      final file = File(audioPath);
      if (await file.exists()) size = await file.length();
    } catch (_) {}
    final raw = '$size|$durationMs|$base';
    return md5.convert(utf8.encode(raw)).toString().substring(0, 16);
  }

  Future<CachedLrcHit?> findLrc(
    String audioPath, {
    int durationMs = 0,
  }) async {
    final dir = await lrcDirectory();
    final fp = await fingerprint(audioPath, durationMs: durationMs);
    final base = basenameNoExt(audioPath);
    final candidates = <String>[
      p.join(dir, '$fp.lrc'),
      p.join(dir, '$base.lrc'),
      sidecarLrcPath(audioPath),
    ];

    final index = await _readIndex();
    final fromIndex = index[fp] ?? index[normalizePath(audioPath)];
    if (fromIndex is Map) {
      final stored = fromIndex['lrcPath'] as String?;
      if (stored != null && stored.isNotEmpty) {
        candidates.insert(0, stored);
      }
    }

    final seen = <String>{};
    for (final candidate in candidates) {
      if (candidate.isEmpty || !seen.add(candidate)) continue;
      final file = File(candidate);
      if (await file.exists()) {
        var lines = 0;
        try {
          lines = (await file.readAsString())
              .split('\n')
              .where((l) => l.trim().startsWith('['))
              .length;
        } catch (_) {}
        debugPrint('[SourceArtifact] LRC hit: $candidate ($lines lines)');
        return CachedLrcHit(lrcPath: candidate, lineCount: lines);
      }
    }
    return null;
  }

  Future<void> rememberLrc({
    required String audioPath,
    required String lrcPath,
    int lineCount = 0,
    int durationMs = 0,
  }) async {
    final fp = await fingerprint(audioPath, durationMs: durationMs);
    final index = await _readIndex();
    final entry = {
      'lrcPath': lrcPath,
      'audioPath': normalizePath(audioPath),
      'basename': basenameNoExt(audioPath),
      'lineCount': lineCount,
      'savedAt': DateTime.now().toIso8601String(),
    };
    index[fp] = entry;
    index[normalizePath(audioPath)] = entry;
    await _writeIndex(index);
  }

  Future<Map<String, dynamic>> _readIndex() async {
    try {
      final dir = await lrcDirectory();
      final file = File(p.join(dir, _indexFileName));
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      debugPrint('[SourceArtifact] index read: $e');
    }
    return {};
  }

  Future<void> _writeIndex(Map<String, dynamic> index) async {
    try {
      final dir = await lrcDirectory();
      final file = File(p.join(dir, _indexFileName));
      await file.writeAsString(jsonEncode(index));
    } catch (e) {
      debugPrint('[SourceArtifact] index write: $e');
    }
  }
}
