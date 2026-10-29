//
// yt-dlp sidecar — WP-Z của PLAN-020.
//
// CHỈ desktop (Windows/Linux/macOS), user TỰ CÀI binary `yt-dlp` (và ffmpeg
// nếu muốn chuyển định dạng), app gọi bằng Process.run/Process.start.
// Không nhét binary vào APK, không server, không GitHub Actions, ẩn trên
// Android/iOS/Web. Dùng khi youtube_explode_dart gãy (YouTube đổi client):
//   - Tải audio:   tầng 2 trong YtDownloader (explode = tầng 1)
//   - Phụ đề:      tầng 4 trong YtService.fetchCaptions (3 tầng đã có sẵn)
//
// Sự kiện của sidecar (YtDlpEvent) cố ý KHÔNG import yt_downloader để tránh
// import vòng — YtDownloader map sang YtDownloadEvent của nó.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../video/services/subtitle_parser.dart';
import '../models/yt_video.dart';

// ─── Events ───────────────────────────────────────────────

sealed class YtDlpEvent {
  const YtDlpEvent();
}

class YtDlpProgress extends YtDlpEvent {
  final double progress; // 0.0 → 1.0
  final String text;
  const YtDlpProgress(this.progress, this.text);
}

class YtDlpDone extends YtDlpEvent {
  final String filePath;
  const YtDlpDone(this.filePath);
}

class YtDlpFailed extends YtDlpEvent {
  final String message;
  const YtDlpFailed(this.message);
}

// ─── Sidecar ──────────────────────────────────────────────

class YtDlpSidecar {
  YtDlpSidecar._();
  static final YtDlpSidecar instance = YtDlpSidecar._();

  Process? _currentProcess;
  bool _cancelRequested = false;
  static Future<bool>? _availability;

  /// Chỉ desktop mới có thể chạy yt-dlp sidecar (không web, không mobile).
  static bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Có yt-dlp trong PATH không — kết quả được cache (gọi `yt-dlp --version`).
  static Future<bool> isAvailable() {
    _availability ??= _checkAvailability();
    return _availability!;
  }

  static Future<bool> _checkAvailability() async {
    if (!isDesktopPlatform) return false;
    try {
      final result = await Process.run('yt-dlp', ['--version'])
          .timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('YtDlpSidecar: không tìm thấy yt-dlp ($e)');
      return false;
    }
  }

  /// Hủy tác vụ đang chạy (kill process). Gọi từ YtDownloader.cancel().
  void cancel() {
    _cancelRequested = true;
    try {
      _currentProcess?.kill();
    } catch (_) {}
  }

  // ─── Tải audio (tầng 2 của YtDownloader) ────────────────

  /// Tải audio của video bằng yt-dlp. Trả về stream sự kiện YtDlpEvent.
  /// [audioQuality] theo thang yt-dlp 0–10 (0 = tốt nhất).
  Stream<YtDlpEvent> downloadAudio(String videoId, {int audioQuality = 0}) {
    _cancelRequested = false;
    final ctrl = StreamController<YtDlpEvent>();
    _runAudioDownload(ctrl, videoId, audioQuality);
    return ctrl.stream;
  }

  Future<void> _runAudioDownload(
    StreamController<YtDlpEvent> ctrl,
    String videoId,
    int audioQuality,
  ) async {
    void emit(YtDlpEvent e) {
      if (!ctrl.isClosed) ctrl.add(e);
    }

    try {
      final dir = await _downloadDir();
      // Thử 1: -x --audio-format m4a (cần ffmpeg).
      // Thử 2: tải thẳng bestaudio (không cần ffmpeg) — tăng tỉ lệ thành công
      // trên máy chỉ cài yt-dlp mà chưa cài ffmpeg.
      final attempts = [
        buildAudioArgs(
            videoId: videoId,
            outDir: dir.path,
            audioQuality: audioQuality,
            extract: true),
        buildAudioArgs(
            videoId: videoId,
            outDir: dir.path,
            audioQuality: audioQuality,
            extract: false),
      ];
      for (final args in attempts) {
        if (_cancelRequested) break;
        emit(const YtDlpProgress(0.02, 'yt-dlp'));
        final ok = await _runAudioProcess(args, emit);
        if (_cancelRequested) break;
        if (ok) {
          final path = _findAudioFile(dir, videoId);
          if (path != null) {
            emit(YtDlpDone(path));
            if (!ctrl.isClosed) ctrl.close();
            return;
          }
          // exit 0 mà không thấy file — thử tiếp attempt sau
        }
      }
      emit(YtDlpFailed(
          _cancelRequested ? 'Đã hủy' : 'yt-dlp không tải được video này'));
    } catch (e) {
      emit(YtDlpFailed('yt-dlp lỗi: $e'));
    } finally {
      if (!ctrl.isClosed) ctrl.close();
    }
  }

  Future<bool> _runAudioProcess(
    List<String> args,
    void Function(YtDlpEvent) emit,
  ) async {
    Process? process;
    Timer? watchdog;
    try {
      process = await Process.start('yt-dlp', args);
      _currentProcess = process;
      // Watchdog 10 phút — yt-dlp treo thì kill
      watchdog = Timer(const Duration(minutes: 10), () {
        debugPrint('YtDlpSidecar: watchdog 10 phút — kill yt-dlp');
        try {
          process?.kill();
        } catch (_) {}
      });
      // Đọc stderr đồng thời để process không bị nghẽn vì buffer đầy
      final errFuture = process.stderr.transform(utf8.decoder).join();
      await for (final line in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_cancelRequested) break;
        final pct = parseProgressPercent(line);
        if (pct != null) {
          emit(YtDlpProgress(
            pct.clamp(0.0, 0.95),
            '${(pct * 100).toStringAsFixed(0)}%',
          ));
        }
      }
      final errText = await errFuture;
      final code = await process.exitCode;
      if (_cancelRequested) return false;
      if (code != 0) {
        final tail =
            errText.length > 300 ? errText.substring(0, 300) : errText;
        debugPrint('YtDlpSidecar: yt-dlp exit $code — $tail');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('YtDlpSidecar process error: $e');
      return false;
    } finally {
      watchdog?.cancel();
      _currentProcess = null;
    }
  }

  String? _findAudioFile(Directory dir, String videoId) {
    try {
      const audioExts = ['.m4a', '.mp3', '.webm', '.opus', '.ogg'];
      final matches = dir
          .listSync()
          .whereType<File>()
          .where((f) {
            final name = f.path.split(RegExp(r'[/\\]')).last;
            return name.contains('[$videoId].') &&
                audioExts.any((e) => name.endsWith(e));
          })
          .toList();
      if (matches.isEmpty) return null;
      matches
          .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return matches.first.path;
    } catch (e) {
      debugPrint('YtDlpSidecar._findAudioFile: $e');
      return null;
    }
  }

  Future<Directory> _downloadDir() async {
    final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/youtube_downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ─── Phụ đề (tầng 4 của YtService.fetchCaptions) ────────

  /// Lấy phụ đề của video bằng yt-dlp (--write-sub --write-auto-sub).
  /// Trả về [] nếu không có sidecar / không có phụ đề.
  Future<List<YtCaptionLine>> fetchCaptions(
    String videoId, {
    String lang = 'en',
  }) async {
    if (!await isAvailable()) return [];
    final tmp = Directory(
        '${(await getTemporaryDirectory()).path}/in4up_ytdlp_${videoId}_${DateTime.now().millisecondsSinceEpoch}');
    await tmp.create(recursive: true);
    try {
      final args =
          buildCaptionArgs(videoId: videoId, outDir: tmp.path, lang: lang);
      final result = await Process.run('yt-dlp', args)
          .timeout(const Duration(minutes: 2));
      if (result.exitCode != 0) {
        debugPrint('YtDlpSidecar: captions exit ${result.exitCode}');
        return [];
      }
      final files = tmp
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList();
      final subPath = pickSubtitleFile(files, videoId, lang);
      if (subPath == null) return [];
      final content = await File(subPath).readAsString();
      final ext = subPath.endsWith('.srt') ? 'srt' : 'vtt';
      return cuesToCaptionLines(SubtitleParser.parse(content, ext: ext));
    } catch (e) {
      debugPrint('YtDlpSidecar.fetchCaptions: $e');
      return [];
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }

  // ─── Hàm thuần (unit test, không cần yt-dlp/mạng) ──────

  /// Đọc phần trăm từ dòng progress của yt-dlp:
  /// `[download]  45.3% of    3.21MiB at  1.20MiB/s ETA 00:02` → 0.453
  /// Dòng không phải tiến độ (Destination, ERROR, …) → null.
  static double? parseProgressPercent(String line) {
    final m = RegExp(r'\[download\]\s+(\d+(?:\.\d+)?)%').firstMatch(line);
    if (m == null) return null;
    final pct = double.tryParse(m.group(1) ?? '');
    if (pct == null) return null;
    return (pct / 100).clamp(0.0, 1.0);
  }

  /// Args tải phụ đề: chỉ ghi sub, không tải video.
  static List<String> buildCaptionArgs({
    required String videoId,
    required String outDir,
    required String lang,
  }) =>
      [
        '--write-sub',
        '--write-auto-sub',
        '--skip-download',
        '--sub-langs',
        lang,
        '--sub-format',
        'vtt',
        '--no-progress',
        '--no-warnings',
        '-o',
        '$outDir/%(id)s.%(ext)s',
        'https://www.youtube.com/watch?v=$videoId',
      ];

  /// Args tải audio. [extract] = true → `-x --audio-format m4a` (cần ffmpeg);
  /// false → tải thẳng bestaudio (m4a/webm, không cần ffmpeg).
  static List<String> buildAudioArgs({
    required String videoId,
    required String outDir,
    int audioQuality = 0,
    bool extract = true,
  }) =>
      [
        if (extract) ...[
          '-x',
          '--audio-format',
          'm4a',
          '--audio-quality',
          '$audioQuality',
        ] else ...[
          '-f',
          'bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio',
        ],
        '--newline',
        '--no-warnings',
        '-o',
        '$outDir/%(title)s [%(id)s].%(ext)s',
        'https://www.youtube.com/watch?v=$videoId',
      ];

  /// Chọn file phụ đề trong danh sách đường dẫn:
  /// ưu tiên đúng ngôn ngữ (`<id>.<lang>.vtt`), rồi cùng id khác ngôn ngữ.
  static String? pickSubtitleFile(
    List<String> files,
    String videoId,
    String lang,
  ) {
    String base(String f) => f.split(RegExp(r'[/\\]')).last;
    final subs = files
        .where((f) => base(f).endsWith('.vtt') || base(f).endsWith('.srt'))
        .toList();
    if (subs.isEmpty) return null;
    for (final f in subs) {
      final b = base(f);
      if (b == '$videoId.$lang.vtt' || b == '$videoId.$lang.srt') return f;
    }
    for (final f in subs) {
      final b = base(f);
      if (b.contains('.$lang.') || b.contains('.$lang-')) return f;
    }
    for (final f in subs) {
      if (base(f).contains(videoId)) return f;
    }
    return null;
  }

  /// Map cue của SubtitleParser → YtCaptionLine, bỏ dòng trống.
  static List<YtCaptionLine> cuesToCaptionLines(List<SubtitleCue> cues) =>
      cues
          .where((c) => c.text.trim().isNotEmpty)
          .map((c) => YtCaptionLine(c.start, c.end, c.text.trim()))
          .toList();
}
