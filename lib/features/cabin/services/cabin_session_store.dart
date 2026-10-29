import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_transcript_exporter.dart';
import 'package:in4up/features/cabin/services/cabin_wav_writer.dart';

/// CABIN-SAVE-001 — kho phiên Cabin trên đĩa:
/// `AppDocuments/cabin_sessions/<id>/{session.json, captions.jsonl,
/// cabin_<id>.wav, cabin_<id>.lrc, cabin_<id>.txt}`.
class CabinSessionStore {
  CabinSessionStore._();
  static final CabinSessionStore instance = CabinSessionStore._();

  /// Ghi đè thư mục gốc (test).
  @visibleForTesting
  String? debugRootOverride;

  Future<Directory> rootDir() async {
    final override = debugRootOverride;
    final path = override ??
        '${(await getApplicationDocumentsDirectory()).path}/cabin_sessions';
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String newId(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  Future<Directory> createSessionDir(DateTime t) async {
    final root = await rootDir();
    var id = newId(t);
    var dir = Directory('${root.path}/$id');
    var n = 1;
    while (await dir.exists()) {
      id = '${newId(t)}_$n';
      dir = Directory('${root.path}/$id');
      n++;
    }
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> writeMeta(CabinSession s) async {
    final file = File(s.metaPath);
    final tmp = File('${s.metaPath}.tmp');
    await tmp.writeAsString(jsonEncode(s.toJson()), flush: true);
    await tmp.rename(file.path);
  }

  Future<CabinSession?> readMeta(Directory dir) async {
    try {
      final file = File('${dir.path}/session.json');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return CabinSession.fromJson(json, dir.path);
    } catch (e) {
      debugPrint('⚠️ CabinSessionStore readMeta ${dir.path}: $e');
      return null;
    }
  }

  Future<List<CabinTranscriptEntry>> loadEntries(CabinSession s) async {
    final file = File(s.journalPath);
    if (!await file.exists()) return const [];
    final out = <CabinTranscriptEntry>[];
    for (final line in await file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final j = jsonDecode(line);
        if (j is Map<String, dynamic>) out.add(CabinTranscriptEntry.fromJson(j));
      } catch (_) {
        // Dòng cuối có thể cụt nếu app bị tắt ngang — bỏ qua.
      }
    }
    return out;
  }

  /// Danh sách phiên (mới nhất trước). Bỏ phiên [excludeId] đang ghi.
  Future<List<CabinSession>> list({String? excludeId}) async {
    final root = await rootDir();
    final out = <CabinSession>[];
    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      final s = await readMeta(e);
      if (s == null || s.id == excludeId) continue;
      out.add(s);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// Phiên còn trạng thái `recording` mà không phải phiên đang chạy ⇒ app bị
  /// tắt ngang. Vá header WAV + dựng lại LRC từ journal, chuyển `unsaved`.
  Future<List<CabinSession>> recoverInterrupted({String? activeId}) async {
    final recovered = <CabinSession>[];
    for (final s in await list(excludeId: activeId)) {
      if (s.status != CabinSessionStatus.recording) continue;
      try {
        var duration = s.duration;
        if (s.hasAudio) {
          final bytes = await CabinWavWriter.repairHeader(s.audioPath);
          duration = CabinWavWriter.durationForBytes(bytes);
        }
        final entries = await loadEntries(s);
        if (!s.hasAudio && entries.isNotEmpty) {
          duration = entries.last.offset;
        }
        final next = s.copyWith(
          status: CabinSessionStatus.unsaved,
          duration: duration,
          entryCount: entries.length,
          recovered: true,
        );
        if (next.isEmpty) {
          await delete(next);
          continue;
        }
        await writeTranscripts(next, entries, next.textMode);
        await writeMeta(next);
        recovered.add(next);
      } catch (e) {
        debugPrint('⚠️ CabinSessionStore recover ${s.id}: $e');
      }
    }
    return recovered;
  }

  Future<void> writeTranscripts(
    CabinSession s,
    List<CabinTranscriptEntry> entries,
    CabinTextMode mode,
  ) async {
    await File(s.lrcPath).writeAsString(
      CabinTranscriptExporter.buildLrc(entries, mode, title: s.title),
      flush: true,
    );
    await File(s.txtPath).writeAsString(
      CabinTranscriptExporter.buildTxt(entries, mode),
      flush: true,
    );
  }

  /// User bấm Lưu. Trả về `null` nếu user bỏ cả audio lẫn text (⇒ xoá phiên).
  Future<CabinSession?> save(
    CabinSession s, {
    required String title,
    required CabinTextMode textMode,
    bool keepAudio = true,
    bool keepText = true,
  }) async {
    final hasAudio = s.hasAudio && keepAudio;
    if (!hasAudio && !keepText) {
      await delete(s);
      return null;
    }
    final next = s.copyWith(
      title: title.trim().isEmpty ? s.title : title.trim(),
      textMode: textMode,
      hasAudio: hasAudio,
      status: CabinSessionStatus.saved,
    );
    if (s.hasAudio && !keepAudio) {
      try {
        await File(s.audioPath).delete();
      } catch (_) {}
    }
    if (keepText) {
      await writeTranscripts(next, await loadEntries(next), textMode);
    } else {
      for (final p in [next.lrcPath, next.txtPath]) {
        try {
          await File(p).delete();
        } catch (_) {}
      }
    }
    await writeMeta(next);
    return next;
  }

  Future<CabinSession> rename(CabinSession s, String title) async {
    final next = s.copyWith(title: title.trim().isEmpty ? s.title : title);
    await writeMeta(next);
    if (await File(next.lrcPath).exists()) {
      await writeTranscripts(next, await loadEntries(next), next.textMode);
    }
    return next;
  }

  Future<void> delete(CabinSession s) async {
    try {
      final dir = Directory(s.dirPath);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('⚠️ CabinSessionStore delete ${s.id}: $e');
    }
  }
}
