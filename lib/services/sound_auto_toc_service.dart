// lib/services/sound_auto_toc_service.dart
// Soundlist – Bộ máy "Tự tạo mục lục âm thanh"
//
// BƯỚC 1 (VAD): phân tích năng lượng waveform để phát hiện khoảng lặng
//   → tự tách file dài thành các đoạn (slices) — "mục lục thô" tức thì,
//   chạy offline hoàn toàn trong Isolate, không cần model.
// BƯỚC 2 (Whisper): transcribe offline lấy text + timestamp theo từng câu
//   → tự đặt tiêu đề cho mỗi đoạn (tên "chương" như mục lục sách).
//
// Cả hai bước chạy trên hạ tầng có sẵn của app (just_waveform + in4up_stt),
// dữ liệu lưu vào Hive như mọi thành phần khác (offline-first).

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:in4up_stt/stt_model_manager.dart';
import 'package:just_waveform/just_waveform.dart' as jw;

import '../models/sound_chapter.dart';
import '../models/vad_settings.dart';
import 'audio_library_channel.dart';

/// Một lát cắt thời gian (đoạn) do VAD phát hiện.
class AudioSlice {
  final Duration start;
  final Duration end;

  const AudioSlice({required this.start, required this.end});

  Duration get duration => end - start;
}

/// Kết quả tự tạo mục lục.
class SoundAutoTocResult {
  final List<SoundChapter> chapters;
  final int sliceCount;
  final bool usedWhisper;
  final String? transcriptText;

  /// Lý do không tạo được mục lục (null = thành công) — hiển thị cho người dùng.
  final String? error;

  const SoundAutoTocResult({
    required this.chapters,
    required this.sliceCount,
    required this.usedWhisper,
    this.transcriptText,
    this.error,
  });
}

class SoundAutoTocService {
  // ─────────────────────────── BƯỚC 1: VAD ───────────────────────────

  /// Phát hiện khoảng lặng và trả về danh sách đoạn (slices).
  ///
  /// [totalDuration] có thể null — khi đó ước lượng từ số mẫu waveform.
  /// [minSilenceSec] – khoảng lặng tối thiểu để coi là ranh giới đoạn.
  /// [minSegmentSec] – đoạn tối thiểu giữa hai ranh giới.
  static Future<List<AudioSlice>> vadSplit(
    String audioPath, {
    Duration? totalDuration,
    double minSilenceSec = 0.9,
    double minSegmentSec = 6.0,
    double thresholdFactor = 0.28,
  }) async {
    // content:// (từ MediaStore/SAF) → copy sang cache để File/waveform dùng được.
    final localPath = await AudioLibraryChannel.copyContentToCache(audioPath);
    if (localPath == null) return const <AudioSlice>[];
    return _vadSplitFile(localPath,
        totalDuration: totalDuration,
        minSilenceSec: minSilenceSec,
        minSegmentSec: minSegmentSec,
        thresholdFactor: thresholdFactor);
  }

  static Future<List<AudioSlice>> _vadSplitFile(
    String audioPath, {
    Duration? totalDuration,
    double minSilenceSec = 0.9,
    double minSegmentSec = 6.0,
    double thresholdFactor = 0.28,
  }) {
    return Isolate.run(() async {
      try {
        final file = File(audioPath);
        if (!await file.exists()) return const <AudioSlice>[];

        // Zoom 200 px/s → mỗi mẫu = 5ms âm thanh (đủ phân giải cho VAD).
        final waveFile = File('$audioPath.vad_toc.waveform');
        jw.Waveform? waveform;
        final stream = jw.JustWaveform.extract(
          audioInFile: file,
          waveOutFile: waveFile,
          zoom: jw.WaveformZoom.pixelsPerSecond(200),
        );
        await for (final progress in stream) {
          if (progress.waveform != null) waveform = progress.waveform;
        }

        try {
          if (await waveFile.exists()) await waveFile.delete();
        } catch (_) {}

        if (waveform == null || waveform.data.isEmpty) {
          return const <AudioSlice>[];
        }

        final samples = waveform.data;
        const sampleMs = 5; // 200 px/s
        final inferredMs = samples.length * sampleMs;

        final durationMs =
            totalDuration != null && totalDuration.inMilliseconds > 0
                ? totalDuration.inMilliseconds
                : inferredMs;

        // Chuẩn hóa biên độ theo p95 (chống phụ thuộc volume / nhiễu nền).
        final sorted = [...samples.map((v) => v.abs())]..sort();
        final p95 = sorted.isEmpty
            ? 1.0
            : sorted[(sorted.length * 0.95)
                    .floor()
                    .clamp(0, sorted.length - 1)
                    .toInt()];
        final norm = p95 > 0 ? p95 : 1.0;

        // Năng lượng theo cửa sổ 100ms (20 mẫu).
        const winSize = 20;
        final energies = <double>[];
        for (int i = 0; i + winSize <= samples.length; i += winSize) {
          double sum = 0;
          for (int j = i; j < i + winSize; j++) {
            sum += samples[j].abs() / norm;
          }
          energies.add(sum / winSize);
        }

        if (energies.length < 6) return const <AudioSlice>[];

        final meanEnergy = energies.reduce((a, b) => a + b) / energies.length;
        final threshold = math.max(0.045, meanEnergy * thresholdFactor);

        // Chạy các cửa sổ im lặng liên tiếp.
        final runs = <(int, int)>[]; // (startWin, endWin)
        int? runStart;
        for (int i = 0; i < energies.length; i++) {
          if (energies[i] < threshold) {
            runStart ??= i;
          } else {
            if (runStart != null) {
              runs.add((runStart, i - 1));
              runStart = null;
            }
          }
        }
        if (runStart != null) runs.add((runStart, energies.length - 1));

        const silenceMsPerWin = winSize * sampleMs; // 100ms

        // Ranh giới = điểm giữa của khoảng lặng đủ dài.
        final boundaries = <int>[];
        for (final (s, e) in runs) {
          final runMs = (e - s + 1) * silenceMsPerWin;
          if (runMs < minSilenceSec * 1000) continue;
          final mid = ((s + e + 1) ~/ 2) * silenceMsPerWin;
          // Bỏ ranh giới quá sát đầu/cuối file.
          if (mid < minSegmentSec * 1000) continue;
          if (mid > durationMs - minSegmentSec * 1000) continue;
          boundaries.add(mid);
        }
        boundaries.sort();

        // Ghép slices: giữ ranh giới khi cả hai bên ≥ minSegmentSec.
        final slices = <AudioSlice>[];
        var prev = 0;
        for (final b in boundaries) {
          if (b - prev >= minSegmentSec * 1000) {
            slices.add(AudioSlice(
              start: Duration(milliseconds: prev),
              end: Duration(milliseconds: b),
            ));
            prev = b;
          }
        }
        if (durationMs - prev >= minSegmentSec * 1000) {
          slices.add(AudioSlice(
            start: Duration(milliseconds: prev),
            end: Duration(milliseconds: durationMs),
          ));
        }

        // Fallback: audio liền mạch (không có khoảng lặng đủ) → chia đều
        // theo thời lượng (~60s/đoạn, tối đa 8 đoạn) để vẫn có "mục lục thô".
        // (Fix: trước đây trả [] → "không tạo được mục lục" dù file nghe bình thường.)
        if (slices.length < 2 && durationMs >= minSegmentSec * 1000 * 2) {
          const targetSec = 60;
          var n = (durationMs / (targetSec * 1000)).ceil();
          if (n < 2) n = 2;
          if (n > 8) n = 8;
          final stepMs = durationMs ~/ n;
          final fallback = <AudioSlice>[];
          for (int i = 0; i < n; i++) {
            final s = i * stepMs;
            final e = i == n - 1 ? durationMs : (i + 1) * stepMs;
            if (e - s >= minSegmentSec * 1000) {
              fallback.add(AudioSlice(
                start: Duration(milliseconds: s),
                end: Duration(milliseconds: e),
              ));
            }
          }
          if (fallback.length >= 2) return fallback;
        }

        if (slices.length < 2) return const <AudioSlice>[];
        return slices;
      } catch (e) {
        debugPrint('❌ VAD split error: $e');
        return const <AudioSlice>[];
      }
    });
  }

  // ─────────────────────────── BƯỚC 2: WHISPER ───────────────────────────

  /// Transcribe offline (Whisper qua isolate). Trả về [SttResult] nếu thành công.
  ///
  /// [language]: 'vi' | 'en' | 'auto' (D16). Lưu ý: in4up_stt chưa hỗ trợ
  /// auto-detect qua SttConfig.language='auto' (whisper.cpp nhận mã ngôn ngữ
  /// cụ thể) — nên 'auto' được map về 'en' (giữ hành vi cũ), không đổi package.
  ///
  /// [level] null → dùng `transcribeAuto` (tự chọn model TỐT NHẤT có sẵn:
  /// base→tiny→small→medium→large, giống luồng Tạo lời thoại LRC). Trước đây
  /// cứng `WhisperModelLevel.base` + `transcribeFile` → máy không có model base
  /// (chỉ tiny/small) thì Whisper fail → "không tạo được mục lục".
  static Future<SttResult?> transcribe(
    String audioPath, {
    WhisperModelLevel? level,
    String language = 'auto',
    SttSegmentGrouping grouping = SttSegmentGrouping.sentence,
  }) async {
    // content:// → copy sang cache (ffmpeg/whisper dùng File-based).
    final localPath = await AudioLibraryChannel.copyContentToCache(audioPath);
    final effectivePath = localPath ?? audioPath;
    try {
      final facade = SttServiceFacade();
      final effectiveLanguage = language == 'auto' ? 'en' : language;
      final SttTranscribeOutput output;
      if (level == null) {
        output = await facade.transcribeAuto(
          effectivePath,
          language: effectiveLanguage,
          generateLrc: false,
          grouping: grouping,
        );
      } else {
        final cfg = SttConfig.deepLearning.copyWith(
          whisperModel: level,
          language: effectiveLanguage,
          generateLrc: false,
          grouping: grouping,
        );
        output = await facade.transcribeFile(
          effectivePath,
          config: cfg,
          generateLrc: false,
        );
      }
      if (output.success && output.result.fullText.isNotEmpty) {
        return output.result;
      }
      debugPrint('⚠️ Auto-TOC transcribe: empty/failed — '
          '${output.errorMessage ?? 'no text'}');
      return null;
    } catch (e) {
      debugPrint('❌ Auto-TOC transcribe error: $e');
      return null;
    }
  }

  /// Kiểm tra model Whisper đã sẵn sàng chưa (để UI báo cần tải trước).
  static bool isWhisperModelReady(WhisperModelLevel level) {
    try {
      return SttModelManager().isModelReady(level);
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────── XÂY DANH SÁCH CHƯƠNG ───────────────────────

  /// Gộp VAD slices + STT segments thành danh sách [SoundChapter].
  ///
  /// - Có slices + text: mỗi slice 1 chương, tiêu đề = câu mở đầu (trích từ STT),
  ///   ghi chú = toàn bộ câu. Neo position = đầu slice.
  /// - Có slices, không text: tiêu đề = "Đoạn N · mm:ss".
  /// - Không slices, có text: gom STT segments thành ≤ 80 chương.
  static List<SoundChapter> buildChapters({
    required String audioPath,
    required List<AudioSlice> slices,
    List<SttSegment>? sttSegments,
    bool useWhisper = false,
  }) {
    final now = DateTime.now();
    final chapters = <SoundChapter>[];
    final segments = sttSegments ?? const <SttSegment>[];

    if (slices.isNotEmpty) {
      for (int i = 0; i < slices.length; i++) {
        final slice = slices[i];
        final stt = _findSegmentForSlice(slice, segments);
        final fallback = 'Đoạn ${i + 1} · ${_fmt(slice.start)}';
        final title = useWhisper && stt != null
            ? _cleanTitle(stt.text)
            : fallback;
        chapters.add(SoundChapter(
          id: 'chapter_${now.microsecondsSinceEpoch}_$i',
          audioPath: audioPath,
          title: title.isEmpty ? fallback : title,
          note: useWhisper && stt != null ? _cleanText(stt.text) : null,
          position: slice.start,
          order: i,
          createdAt: now,
        ));
      }
      return chapters;
    }

    // Không có VAD → dùng chính STT segments làm chương (gom nếu quá nhiều).
    if (segments.isNotEmpty) {
      final groups = _groupSegments(segments, maxChapters: 80);
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];
        final fullText = group.map((s) => s.text.trim()).join(' ');
        final title = _cleanTitle(fullText);
        chapters.add(SoundChapter(
          id: 'chapter_${now.microsecondsSinceEpoch}_stt_$i',
          audioPath: audioPath,
          title: title.isEmpty ? 'Chương ${i + 1}' : title,
          note: _cleanText(fullText),
          position: group.first.startDuration,
          order: i,
          createdAt: now,
        ));
      }
      return chapters;
    }

    return chapters;
  }

  static SttSegment? _findSegmentForSlice(
    AudioSlice slice,
    List<SttSegment> segments,
  ) {
    if (segments.isEmpty) return null;
    final startMs = slice.start.inMilliseconds;
    final endMs = slice.end.inMilliseconds;

    // Ưu tiên segment đầu tiên nằm trong slice.
    for (final s in segments) {
      if (s.startMs >= startMs && s.startMs < endMs && s.text.trim().isNotEmpty) {
        return s;
      }
    }
    // Nếu không: segment gần start nhất.
    SttSegment? best;
    var bestDist = 1 << 30;
    for (final s in segments) {
      if (s.text.trim().isEmpty) continue;
      final dist = (s.startMs - startMs).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = s;
      }
    }
    return best;
  }

  /// Gom segments thành các nhóm, không vượt quá [maxChapters].
  static List<List<SttSegment>> _groupSegments(
    List<SttSegment> segments, {
    required int maxChapters,
  }) {
    final list = segments.where((s) => s.text.trim().isNotEmpty).toList();
    if (list.length <= maxChapters) {
      return list.map((s) => [s]).toList();
    }
    final perGroup = (list.length / maxChapters).ceil();
    final groups = <List<SttSegment>>[];
    for (int i = 0; i < list.length; i += perGroup) {
      final end = i + perGroup < list.length ? i + perGroup : list.length;
      groups.add(list.sublist(i, end));
    }
    return groups;
  }

  static String _cleanTitle(String text) {
    var t = _cleanText(text);
    if (t.length > 64) t = '${t.substring(0, 64).trimRight()}…';
    return t;
  }

  static String _cleanText(String text) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');
    return t;
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// PURE — tính các mốc cắt (ms) từ dãy peak waveform (0..1) + cài đặt VAD.
  /// Dùng cho preview "mini waveform" trong dialog để người dùng THẤY
  /// ranh giới đoạn sẽ nằm ở đâu trước khi chạy.
  static List<int> computeBoundaryMs(
    List<double> peaks,
    int durationMs, {
    required VadSettings settings,
  }) {
    if (peaks.length < 6 || durationMs <= 0) return const [];

    // Cửa sổ ~100ms: số mẫu mỗi cửa sổ theo tỷ lệ.
    final winSize = math.max(1, (peaks.length / durationMs * 100).round());
    final energies = <double>[];
    for (int i = 0; i + winSize <= peaks.length; i += winSize) {
      double sum = 0;
      for (int j = i; j < i + winSize; j++) {
        sum += peaks[j].abs();
      }
      energies.add(sum / winSize);
    }
    if (energies.length < 4) return const [];

    final mean = energies.reduce((a, b) => a + b) / energies.length;
    final threshold = math.max(0.045, mean * settings.thresholdFactor);

    // Chạy im lặng liên tiếp.
    final runs = <(int, int)>[];
    int? runStart;
    for (int i = 0; i < energies.length; i++) {
      if (energies[i] < threshold) {
        runStart ??= i;
      } else {
        if (runStart != null) {
          runs.add((runStart, i - 1));
          runStart = null;
        }
      }
    }
    if (runStart != null) runs.add((runStart, energies.length - 1));

    final msPerWin = (durationMs / energies.length).round();
    final boundaries = <int>[];
    for (final (s, e) in runs) {
      final runMs = (e - s + 1) * msPerWin;
      if (runMs < settings.minSilenceSec * 1000) continue;
      final mid = ((s + e + 1) ~/ 2) * msPerWin;
      if (mid < settings.minSegmentSec * 1000) continue;
      if (mid > durationMs - settings.minSegmentSec * 1000) continue;
      boundaries.add(mid);
    }
    boundaries.sort();
    return boundaries;
  }
}

