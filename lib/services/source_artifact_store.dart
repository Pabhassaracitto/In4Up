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
  final String audioPath;
  final int lineCount;
  final DateTime? savedAt;

  const CachedLrcHit({
    required this.lrcPath,
    required this.audioPath,
    this.lineCount = 0,
    this.savedAt,
  });
}

class SourceArtifactStore {
  SourceArtifactStore._() : _directoryOverride = null;

  @visibleForTesting
  SourceArtifactStore.forTesting(String directory) : _directoryOverride = directory;

  static final SourceArtifactStore instance = SourceArtifactStore._();
  final String? _directoryOverride;

  static const _indexFileName = 'index.json';
  Future<void> _indexWriteTail = Future<void>.value();

  Future<String> lrcDirectory() async {
    final directoryOverride = _directoryOverride;
    final dir = directoryOverride == null
        ? Directory(p.join((await getApplicationDocumentsDirectory()).path, '.in4up_lrc'))
        : Directory(directoryOverride);
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
    final index = await _readIndex();
    final normalized = normalizePath(audioPath);
    final exact = index[_exactPathKey(audioPath)];
    final candidates = <String>[sidecarLrcPath(audioPath)];

    void addBoundEntry(Object? value, {required bool requireExact}) {
      if (value is! Map) return;
      final storedSource = requireExact ? value['sourcePath'] : value['audioPath'];
      final expected = requireExact ? _exactPath(audioPath) : normalized;
      if (storedSource != expected) return;
      final stored = value['lrcPath'];
      if (stored is String && stored.isNotEmpty) candidates.insert(0, stored);
    }

    addBoundEntry(exact, requireExact: true);
    if (exact == null && !await _hasCaseCollision(audioPath)) {
      // Older indices stored a normalized full path. Do not use an unbound
      // basename/size fingerprint from another source as proof of ownership.
      addBoundEntry(index[normalized], requireExact: false);
      final fp = await fingerprint(audioPath, durationMs: durationMs);
      addBoundEntry(index[fp], requireExact: false);
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
        return CachedLrcHit(
          lrcPath: candidate,
          audioPath: audioPath,
          lineCount: lines,
        );
      }
    }
    return null;
  }

  Future<List<String>> _unverifiedLrcPaths(
    String audioPath, {
    int durationMs = 0,
  }) async {
    final dir = await lrcDirectory();
    final fp = await fingerprint(audioPath, durationMs: durationMs);
    final base = basenameNoExt(audioPath);
    final paths = <String>{p.join(dir, '$fp.lrc'), p.join(dir, '$base.lrc')};
    final index = await _readIndex();
    final bound = index.values.whereType<Map>().map((entry) => entry['lrcPath']).toSet();
    final existing = <String>[];
    for (final path in paths) {
      // Already-bound LRCs belong to a known source, not an orphan candidate.
      if (!bound.contains(path) && await File(path).exists()) existing.add(path);
    }
    return existing;
  }

  /// Detect legacy files for a user-visible recovery prompt, never as proof
  /// that the current source owns them.
  Future<bool> hasUnverifiedLrc(String audioPath, {int durationMs = 0}) async =>
      (await _unverifiedLrcPaths(audioPath, durationMs: durationMs)).isNotEmpty;

  /// Candidates are shown to the user; basename/fingerprint alone never
  /// associates a legacy transcript with the current audio automatically.
  Future<List<CachedLrcHit>> unverifiedLrcCandidates(String audioPath) async {
    final paths = await _unverifiedLrcPaths(audioPath);
    return paths.map((path) => CachedLrcHit(lrcPath: path, audioPath: audioPath)).toList();
  }

  /// Associate only a candidate the user explicitly chose.
  Future<bool> bindUnverifiedLrc(CachedLrcHit hit) async {
    final paths = await _unverifiedLrcPaths(hit.audioPath);
    if (!paths.contains(hit.lrcPath)) return false;
    await rememberLrc(audioPath: hit.audioPath, lrcPath: hit.lrcPath);
    return true;
  }

  /// Called only after the user explicitly associates legacy data. Multiple
  /// orphan files are left untouched rather than guessing which one is right.
  Future<bool> bindSingleUnverifiedLrc(String audioPath) async {
    if (await findLrc(audioPath) != null) return true;
    final paths = await _unverifiedLrcPaths(audioPath);
    if (paths.isEmpty) return true;
    if (paths.length != 1) return false;
    await rememberLrc(audioPath: audioPath, lrcPath: paths.single);
    return true;
  }

  static String _exactPath(String path) {
    final normalized = path.replaceAll(r'\', '/').trim();
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static String _exactPathKey(String path) => 'source-v2:${_exactPath(path)}';

  static Future<bool> _hasCaseCollision(String audioPath) async {
    if (Platform.isWindows) return false;
    try {
      final file = File(audioPath);
      final expected = file.path.toLowerCase();
      var matches = 0;
      await for (final child in file.parent.list(followLinks: false)) {
        if (child.path.toLowerCase() == expected && ++matches > 1) return true;
      }
    } catch (_) {
      // If the directory cannot be checked, do not guess case-folded identity.
      return true;
    }
    return false;
  }

  Future<void> rememberLrc({
    required String audioPath,
    required String lrcPath,
    int lineCount = 0,
    int durationMs = 0,
  }) {
    final operation = _indexWriteTail.then((_) async {
      final fp = await fingerprint(audioPath, durationMs: durationMs);
      final index = await _readIndex();
      final entry = {
        'lrcPath': lrcPath,
        'audioPath': normalizePath(audioPath),
        'sourcePath': _exactPath(audioPath),
        'basename': basenameNoExt(audioPath),
        'lineCount': lineCount,
        'savedAt': DateTime.now().toIso8601String(),
      };
      index[fp] = entry;
      index[normalizePath(audioPath)] = entry;
      index[_exactPathKey(audioPath)] = entry;
      await _writeIndex(index);
    });
    _indexWriteTail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
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
