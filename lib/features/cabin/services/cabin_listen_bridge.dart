import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/screens/listen_mode/models/recent_audio.dart';
import 'package:in4up/screens/listen_mode/services/recent_audio_service.dart';

/// Copy a saved Cabin recording and its selected LRC to Listen's recent list.
/// Copies are independent of the Cabin folder and published only when complete.
class CabinListenBridge {
  CabinListenBridge({this.documentsDir});

  /// Injectable for host tests; production uses app documents.
  final Future<Directory> Function()? documentsDir;

  Future<String> _digest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  /// Returns the persistent audio path. Throws if source is unavailable or
  /// changes while being copied; never publishes a partially copied item.
  Future<String> sync(CabinSession session) async {
    if (session.status != CabinSessionStatus.saved || !session.hasAudio) {
      throw StateError('A saved session with audio is required');
    }
    final audio = File(session.audioPath);
    if (!await audio.exists()) throw StateError('Cabin audio is missing');
    final lrc = File(session.lrcPath);
    final hasText = await lrc.exists();
    final audioHash = await _digest(audio);
    final textHash = hasText ? await _digest(lrc) : '';
    final key = sha256.convert(utf8.encode(
        '${session.dirPath}\n$audioHash\n$textHash')).toString();
    final docs = await (documentsDir?.call() ?? getApplicationDocumentsDirectory());
    final root = Directory(p.join(docs.path, 'cabin_listen_exports'));
    await root.create(recursive: true);
    final destination = Directory(p.join(root.path, key));
    final outputAudio = File(p.join(destination.path, 'cabin.wav'));
    final outputLrc = File(p.join(destination.path, 'cabin.lrc'));

    if (await destination.exists()) {
      if (!await outputAudio.exists() || await _digest(outputAudio) != audioHash ||
          (hasText && (!await outputLrc.exists() || await _digest(outputLrc) != textHash)) ||
          (!hasText && await outputLrc.exists())) {
        throw StateError('Existing Cabin Listen copy is incomplete');
      }
    } else {
      final staging = await root.createTemp('pending-');
      try {
        final tempAudio = await audio.copy(p.join(staging.path, 'cabin.wav'));
        if (await _digest(tempAudio) != audioHash || await _digest(audio) != audioHash) {
          throw StateError('Cabin audio changed while copying');
        }
        if (hasText) {
          final tempLrc = await lrc.copy(p.join(staging.path, 'cabin.lrc'));
          if (await _digest(tempLrc) != textHash || await _digest(lrc) != textHash) {
            throw StateError('Cabin text changed while copying');
          }
        }
        try {
          await staging.rename(destination.path);
        } on FileSystemException {
          // Another concurrent sync may have published the identical snapshot.
          if (!await outputAudio.exists() || await _digest(outputAudio) != audioHash ||
              (hasText && (!await outputLrc.exists() || await _digest(outputLrc) != textHash))) {
            rethrow;
          }
        }
      } finally {
        if (await staging.exists()) await staging.delete(recursive: true);
      }
    }

    await RecentAudioService().addOrUpdate(
      RecentAudio.fromLocalFile(
        path: outputAudio.path,
        title: session.title,
        totalDuration: session.duration,
      ),
      preservePositionIfZero: true,
    );
    return outputAudio.path;
  }
}

/// Sync only after saving. A failed copy does not undo the saved session and
/// must be reported independently so the user can retry from saved sessions.
Future<bool> syncSavedCabinForListen(
  CabinSession? saved, {
  required bool enabled,
  Future<String> Function(CabinSession)? sync,
}) async {
  if (!enabled || saved == null || !saved.hasAudio) return true;
  try {
    await (sync ?? CabinListenBridge().sync)(saved);
    return true;
  } catch (error) {
    debugPrint('Cabin Listen sync: $error');
    return false;
  }
}
