import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_session_store.dart';
import 'package:in4up/features/cabin/services/cabin_wav_writer.dart';

/// CABIN-SAVE-001 — ghi một phiên Cabin đang chạy: WAV (tee từ luồng PCM mà
/// Zipformer đang dùng — KHÔNG mở micro lần 2) + journal câu đã chốt.
///
/// Mọi thứ ghi dần xuống đĩa để app bị tắt ngang vẫn khôi phục được
/// ([CabinSessionStore.recoverInterrupted]).
class CabinSessionRecorder {
  CabinSessionRecorder._(this._session, this._wav, this._journal);

  CabinSession _session;
  CabinWavWriter? _wav;
  IOSink? _journal;
  final Stopwatch _clock = Stopwatch();
  final List<CabinTranscriptEntry> _entries = [];
  Timer? _flushTimer;
  bool _finished = false;

  CabinSession get session => _session;
  bool get hasAudio => _wav != null;
  List<CabinTranscriptEntry> get entries => List.unmodifiable(_entries);

  /// Vị trí hiện tại trong phiên. Có audio ⇒ tính theo số byte đã ghi (khớp
  /// tuyệt đối với file WAV, tự "dừng" khi pause vì mic tắt); không audio ⇒
  /// đồng hồ có pause.
  Duration get elapsed => _wav?.duration ?? _clock.elapsed;

  static Future<CabinSessionRecorder> begin({
    required String sourceLang,
    required String targetLang,
    required String engine,
    required bool recordAudio,
    CabinTextMode textMode = CabinTextMode.bilingual,
  }) async {
    final store = CabinSessionStore.instance;
    final now = DateTime.now();
    final dir = await store.createSessionDir(now);
    final id = dir.path.split(RegExp(r'[\\/]')).last;
    var session = CabinSession(
      id: id,
      dirPath: dir.path,
      title: _defaultTitle(now, sourceLang, targetLang),
      createdAt: now,
      sourceLang: sourceLang,
      targetLang: targetLang,
      engine: engine,
      status: CabinSessionStatus.recording,
      hasAudio: recordAudio,
      textMode: textMode,
    );
    CabinWavWriter? wav;
    if (recordAudio) {
      try {
        wav = await CabinWavWriter.open(session.audioPath);
      } catch (e) {
        debugPrint('⚠️ CabinSessionRecorder: không mở được WAV: $e');
        session = session.copyWith(hasAudio: false);
      }
    }
    final journal = File(session.journalPath).openWrite(mode: FileMode.append);
    await store.writeMeta(session);
    final r = CabinSessionRecorder._(session, wav, journal);
    r._flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(r._wav?.flush());
      unawaited(r._journal?.flush().catchError((_) {}));
    });
    return r;
  }

  static String _defaultTitle(DateTime t, String src, String tgt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Cabin ${src.toUpperCase()}→${tgt.toUpperCase()} '
        '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  /// Tee luồng PCM: mỗi chunk được ghi vào WAV rồi chuyển nguyên cho ASR.
  Stream<Uint8List> tapPcm(Stream<Uint8List> pcm) {
    final wav = _wav;
    if (wav == null) return pcm;
    return pcm.map((chunk) {
      if (!_finished) wav.add(chunk);
      return chunk;
    });
  }

  void resumeClock() {
    if (!_finished) _clock.start();
  }

  void pauseClock() => _clock.stop();

  void addEntry(CabinTranscriptEntry e) {
    if (_finished) return;
    _entries.add(e);
    try {
      _journal?.writeln(jsonEncode(e.toJson()));
    } catch (err) {
      debugPrint('⚠️ CabinSessionRecorder journal: $err');
    }
  }

  /// Kết thúc ghi: đóng WAV (vá header), đóng journal, viết LRC/TXT tạm theo
  /// chế độ mặc định, chuyển trạng thái `unsaved` (chờ user quyết định).
  /// Phiên rỗng bị xoá luôn và trả về `null`.
  Future<CabinSession?> finish() async {
    if (_finished) return null;
    _finished = true;
    _flushTimer?.cancel();
    _clock.stop();
    final duration = elapsed;
    try {
      await _wav?.close();
    } catch (_) {}
    try {
      await _journal?.flush();
      await _journal?.close();
    } catch (_) {}
    _journal = null;

    final store = CabinSessionStore.instance;
    _session = _session.copyWith(
      status: CabinSessionStatus.unsaved,
      duration: duration,
      entryCount: _entries.length,
    );
    if (_session.isEmpty) {
      await store.delete(_session);
      return null;
    }
    try {
      await store.writeTranscripts(_session, _entries, _session.textMode);
      await store.writeMeta(_session);
    } catch (e) {
      debugPrint('⚠️ CabinSessionRecorder finish: $e');
    }
    return _session;
  }
}
