// lib/features/media_tools/services/media_export_service.dart
//
// AVTOOL-002/003 (PLAN-047 P1–P2) — ĐIỀU PHỐI xuất media.
//
// Trách nhiệm duy nhất của lớp này: biến một [MediaExportRequest] thành file
// THẬT trên đĩa và (tuỳ chọn) đăng ký file đó thành "nguồn học tập" của app.
// Không vẽ UI, không giữ state của màn hình.
//
// Thứ tự cố định (mỗi bước đều có lý do):
//   1. `materialize` — content:// → file thật (FFmpeg không đọc content://).
//   2. `probe` — biết duration/bitrate/codec TRƯỚC khi chạy.
//   3. kiểm dung lượng trống (chặn trước khi ghi rác).
//   4. chạy FFmpeg (có tiến trình + huỷ).
//   5. hậu kỳ: LRC dịch mốc · AudioImportService · RecentAudioService.
//   6. dọn file tạm do CHÍNH nó tạo (không bao giờ xoá nguồn người dùng).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/utils/audio_converter.dart';
import 'package:in4up_stt/utils/free_space.dart';
import 'package:in4up_stt/utils/src/ffmpeg_runner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../screens/listen_mode/models/recent_audio.dart';
import '../../../screens/listen_mode/services/recent_audio_service.dart';
import '../../../services/audio_library_channel.dart';
import '../../../services/audio_import_service.dart';
import '../../../services/source_artifact_store.dart';
import '../models/media_export_models.dart';
import 'lrc_time_shifter.dart';
import 'media_command_builder.dart';
import 'media_estimates.dart';
import 'media_export_naming.dart';
import 'media_ffmpeg_engine.dart';
import 'media_probe_parser.dart';

/// Cổng ra tối thiểu để test được (không cần Hive / path_provider / player).
abstract class MediaExportHost {
  /// Thư mục ghi đầu ra: `documents/media_exports/` (bền vững, không cache).
  Future<Directory> outputDirectory();

  /// Đưa file xuất vào thư viện app (path ổn định) — trả path sau khi import.
  Future<String> adopt(AudioImportResult result);

  /// HỢP ĐỒNG với service: nhận file đã ghi xong (đường dẫn TẠM `.part`) và
  /// trả về đường dẫn BỀN VỮNG để thư viện dùng.
  ///
  /// Vì sao cần seam riêng `adoptPath` bên cạnh `adopt`: service chỉ có
  /// `String` chứ không giữ `AudioImportResult`, còn bản thật thì gọi
  /// `AudioImportService.ensurePersistent` (tự dedupe theo nội dung) rồi mới
  /// chạm tới `adopt`. Tách ra để test bơm được host giả mà không dựng
  /// `AudioImportService` (đòi `path_provider` + kênh native).
  Future<String> adoptPath({
    required String tempPath,
    required String fileName,
  });

  /// Đăng ký "Gần đây" của tab Nghe.
  Future<void> addRecent(RecentAudio audio);

  /// Ghi LRC cạnh file + đăng ký danh tính.
  Future<void> rememberLrc({required String audioPath, required String lrcPath});

  /// Đọc LRC hiện có của nguồn (null nếu không có).
  Future<String?> readSourceLrc(String audioPath);
}

/// Bản thật, dùng các service đã có của app.
class DefaultMediaExportHost implements MediaExportHost {
  const DefaultMediaExportHost();

  @override
  Future<Directory> outputDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'media_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> adopt(AudioImportResult imported) async => imported.path;

  @override
  Future<String> adoptPath({
    required String tempPath,
    required String fileName,
  }) async {
    final imported = await AudioImportService.instance.ensurePersistent(
      sourcePath: tempPath,
      displayName: fileName,
    );
    return adopt(imported);
  }

  @override
  Future<void> addRecent(RecentAudio audio) =>
      RecentAudioService().addOrUpdate(audio);

  @override
  Future<void> rememberLrc({
    required String audioPath,
    required String lrcPath,
  }) =>
      SourceArtifactStore.instance.rememberLrc(
        audioPath: audioPath,
        lrcPath: lrcPath,
      );

  @override
  Future<String?> readSourceLrc(String audioPath) async {
    try {
      final hit = await SourceArtifactStore.instance
          .findLrc(audioPath, durationMs: 0);
      final path = hit?.lrcPath;
      if (path == null) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      return file.readAsString();
    } catch (e) {
      debugPrint('[MediaTools] readSourceLrc error: $e');
      return null;
    }
  }
}

class MediaExportService {
  MediaExportService({
    MediaFfmpegEngine? engine,
    MediaExportHost? host,
    Future<String?> Function(String uri)? materializeUri,
    int? Function(String dirPath)? freeSpaceProbe,
  })  : _engine = engine ?? MediaFfmpegEngine(),
        _host = host ?? const DefaultMediaExportHost(),
        _materializeUri = materializeUri ?? _defaultMaterialize,
        _freeSpaceProbe = freeSpaceProbe ?? probeFreeSpaceMB;

  /// Desktop đọc tiến trình từ `-progress pipe:2`; mobile/Web lấy từ
  /// Statistics của FFmpegKit nên thêm cờ chỉ làm bẩn log.
  static bool get _supportsProgressPipe =>
      kIsWeb ? false : (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  final MediaFfmpegEngine _engine;
  final MediaExportHost _host;
  final Future<String?> Function(String uri) _materializeUri;
  final int? Function(String dirPath) _freeSpaceProbe;

  static Future<String?> _defaultMaterialize(String uri) async {
    if (!uri.startsWith('content://')) return uri;
    return AudioLibraryChannel.copyContentToCache(uri);
  }

  /// Chạy xuất file, phát tiến trình qua [onProgress].
  ///
  /// Ném [MediaExportException] khi thất bại/huỷ — người gọi (UI) chỉ cần bắt
  /// và ánh xạ `kind` sang chuỗi i18n.
  Future<MediaExportResult> export(
    MediaExportRequest request, {
    void Function(MediaExportProgress progress)? onProgress,
    FfmpegCancelToken? token,
  }) async {
    void emit(MediaExportProgress progress) => onProgress?.call(progress);

    // Huy phai co hieu luc o MOI buoc, khong chi luc FFmpeg dang chay: probe
    // mot file 2 gio tren may cham mat vai giay, `materialize` tu `content://`
    // copy ca file. Truoc day chi `_runSingle` biet token ⇒ bam Huy som thi
    // service van chay tiep toi luc goi FFmpeg (hoac toi het neu huy trong luc
    // probe), UI dung o "Dang huy..." vo han.
    void throwIfCancelled() {
      if (token?.isCancelled ?? false) {
        throw const MediaExportException(MediaExportErrorKind.cancelled);
      }
    }

    emit(const MediaExportProgress(phase: MediaExportPhase.preparing));

    // 1 — nguồn
    final materialized = await _materializeUri(request.inputPath);
    throwIfCancelled();
    if (materialized == null || materialized.isEmpty) {
      throw const MediaExportException(MediaExportErrorKind.inputUnreadable);
    }
    final input = File(materialized);
    if (!await input.exists() || await input.length() == 0) {
      throw const MediaExportException(MediaExportErrorKind.inputUnreadable);
    }

    // 2 — probe
    final probeLog = await _engine.probe(materialized);
    throwIfCancelled();
    final info = MediaProbeParser.parse(probeLog);

    var preset = request.preset;
    final warnings = <String>[];

    // PSRC-177: KHÔNG tự chặn khi probe rỗng. Trước đây có thêm một điều kiện
    // `!hasAudio && audioStreamCount == 0 && probeLog.isNotEmpty` ⇒ nguồn video
    // câm bị chặn đúng, nhưng probe rỗng/lỗi lại rơi vào nhánh `adjustPreset`
    // và cũng bị báo "không có âm thanh". Nay chỉ còn MỘT chỗ kết luận
    // (`adjustPreset`), và nó phân biệt "biết chắc câm" với "không biết".
    final adjustment = MediaProbeParser.adjustPreset(
      info: info,
      wantsCopy: preset.isCopy,
      outputExtension: preset.extension,
    );
    if (adjustment != null) {
      if (adjustment.blocked) {
        throw const MediaExportException(MediaExportErrorKind.noAudioTrack);
      }
      preset = preset == MediaExportPreset.m4aCopy
          ? MediaExportPreset.m4aAac
          : MediaExportPreset.mp3Standard;
      warnings.add(adjustment.technicalMessage);
    }

    // 3 — dung lượng
    final outDir = await _host.outputDirectory();
    final totalDuration = info.durationMs == null
        ? null
        : Duration(milliseconds: info.durationMs!);
    final effectiveDuration = _effectiveDuration(request, totalDuration);
    final estimate = MediaEstimates.estimateBytes(
      preset: preset,
      duration: effectiveDuration,
      sourceBitrateKbps: info.bitrateKbps,
    );
    final verdict = MediaEstimates.checkSpace(
      estimateBytes: estimate,
      freeSpaceMb: _safeFreeSpace(outDir.path),
    );
    if (!verdict.allowed) {
      throw MediaExportException(
        MediaExportErrorKind.noSpace,
        detail: verdict.blockedMessage,
      );
    }

    // 4 — chạy
    throwIfCancelled();
    final title = request.title ?? p.basename(materialized);
    final produced = <String>[];
    try {
      switch (request.scope) {
        case MediaExportScope.full:
          produced.add(await _runSingle(
            input: materialized,
            outDir: outDir.path,
            baseName: MediaExportNaming.sanitize(
              MediaExportNaming.sanitize(p.basenameWithoutExtension(title)),
            ),
            preset: preset,
            start: Duration.zero,
            duration: null,
            totalMs: totalDuration?.inMilliseconds ?? 0,
            sliceIndex: 0,
            sliceCount: 1,
            token: token,
            emit: emit,
          ));
        case MediaExportScope.clip:
          final clipBase = MediaExportNaming.clipBaseName(
            sourceTitle: title,
            start: request.start,
            duration: request.duration,
          );
          produced.add(await _runSingle(
            input: materialized,
            outDir: outDir.path,
            baseName: clipBase,
            preset: preset,
            start: request.start,
            duration: request.duration,
            totalMs: (request.duration?.inMilliseconds ??
                (totalDuration == null
                    ? 0
                    : (totalDuration - request.start).inMilliseconds)),
            sliceIndex: 0,
            sliceCount: 1,
            token: token,
            emit: emit,
          ));
        case MediaExportScope.chapters:
          final slices = request.slices.isEmpty
              ? _evenSlices(totalDuration)
              : request.slices;
          for (var i = 0; i < slices.length; i++) {
            // Giữa 2 chương người dùng vẫn phải huỷ được (tách 40 chương =
            // 40 lần chạy FFmpeg liên tiếp).
            throwIfCancelled();
            final slice = slices[i];
            final base = MediaExportNaming.chapterBaseName(
              sourceTitle: title,
              index: i,
              chapterTitle: slice.title,
              start: slice.start,
            );
            produced.add(await _runSingle(
              input: materialized,
              outDir: outDir.path,
              baseName: base,
              preset: preset,
              start: slice.start,
              duration: slice.duration,
              totalMs: slice.duration?.inMilliseconds ??
                  (totalDuration == null
                      ? 0
                      : (totalDuration - slice.start).inMilliseconds),
              sliceIndex: i,
              sliceCount: slices.length,
              token: token,
              emit: emit,
            ));
          }
      }
    } finally {
      // Nếu huỷ/lỗi giữa đường: dọn file đã xuất xong của CHÍNH lần chạy này.
      //
      // `produced` chỉ chứa file service vừa tạo (đã adopt/temp), KHÔNG bao
      // giờ là file nguồn ⇒ xoá an toàn. Trước đây khối này vô dụng vì
      // `produced.add(...)` chạy SAU `await _runSingle` — khi lệnh ném lỗi thì
      // `produced` vẫn rỗng, nên không xoá được gì và chương đã tách xong nằm
      // lại trong thư viện của một lần xuất bị huỷ.
      if (token?.isCancelled ?? false) {
        for (final path in produced) {
          try {
            final file = File(path);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
        produced.clear();
      }
    }

    // Huỷ thắng mọi lỗi khác: người dùng bấm Huỷ thì phải thấy "Đã huỷ",
    // không phải "Có lỗi khi xuất file" (FFmpeg bị kill luôn trả exit != 0
    // kèm log rác, dễ bị phân loại thành `failed`).
    throwIfCancelled();

    if (produced.isEmpty) {
      throw const MediaExportException(MediaExportErrorKind.failed);
    }

    // 5 — hậu kỳ
    emit(const MediaExportProgress(phase: MediaExportPhase.finalizing));

    final lrcPaths = <String>[];
    if (request.keepLrc) {
      final sourceLrc = await _host.readSourceLrc(materialized);
      if (sourceLrc != null && sourceLrc.trim().isNotEmpty) {
        final parsed = LrcTimeShifter.parse(sourceLrc);
        if (parsed.isNotEmpty) {
          if (request.scope == MediaExportScope.chapters) {
            final slices = request.slices.isEmpty
                ? _evenSlices(totalDuration)
                : request.slices;
            for (var i = 0; i < produced.length && i < slices.length; i++) {
              final shifted = LrcTimeShifter.shiftForClip(
                parsed,
                start: slices[i].start,
                duration: slices[i].duration,
              );
              if (shifted.isEmpty) continue;
              // Chèn ĐÚNG chỉ số của chặng (không dùng `add`) để `lrcPaths[i]`
              // luôn khớp `produced[i]` — chặng không có lời để lại chuỗi rỗng.
              while (lrcPaths.length < i) {
                lrcPaths.add('');
              }
              lrcPaths.add(await _writeLrc(
                audioPath: produced[i],
                lines: shifted,
                title: slices[i].title,
                duration: slices[i].duration,
              ));
            }
          } else {
            final shifted = LrcTimeShifter.shiftForClip(
              parsed,
              start: request.scope == MediaExportScope.clip
                  ? request.start
                  : Duration.zero,
              duration: request.scope == MediaExportScope.clip
                  ? request.duration
                  : null,
            );
            if (shifted.isNotEmpty) {
              while (lrcPaths.length < produced.length - 1) {
                lrcPaths.add('');
              }
              lrcPaths.add(await _writeLrc(
                audioPath: produced.first,
                lines: shifted,
                title: title,
                duration: effectiveDuration,
              ));
            }
          }
        }
      }
    }

    var totalBytes = 0;
    for (final path in produced) {
      try {
        totalBytes += await File(path).length();
      } catch (_) {}
    }

    if (request.registerInRecent) {
      for (final path in produced) {
        try {
          await _host.addRecent(RecentAudio.fromLocalFile(
            path: path,
            totalDuration: _durationOfFile(produced, path, effectiveDuration),
          ));
        } catch (e) {
          debugPrint('[MediaTools] addRecent error: $e');
        }
      }
    }

    emit(const MediaExportProgress(
      phase: MediaExportPhase.done,
      fraction: 1,
    ));

    return MediaExportResult(
      outputPaths: produced,
      sizeBytes: totalBytes,
      lrcPaths: lrcPaths,
      warnings: warnings,
    );
  }

  /// Chạy một chặng, ghi ra `*.part` rồi đổi tên ⇒ không bao giờ để lại file
  /// nửa vời mà player/thư viện có thể mở nhầm.
  Future<String> _runSingle({
    required String input,
    required String outDir,
    required String baseName,
    required MediaExportPreset preset,
    required Duration start,
    required Duration? duration,
    required int totalMs,
    required int sliceIndex,
    required int sliceCount,
    required FfmpegCancelToken? token,
    required void Function(MediaExportProgress) emit,
  }) async {
    final finalPath = MediaExportNaming.uniqueFileName(
      baseName: baseName,
      extension: preset.extension,
      directory: outDir,
      exists: (path) => File(path).existsSync(),
    );
    // replaceFirst does not expand capture references in Dart. Keep the
    // real extension at the end so FFmpeg can infer its output muxer.
    final partPath = p.join(
      p.dirname(finalPath),
      '${p.basenameWithoutExtension(finalPath)}.part${p.extension(finalPath)}',
    );

    final args = MediaCommandBuilder.trimAudio(
      inputPath: input,
      outputPath: partPath,
      start: start,
      duration: duration,
      preset: preset,
      // Trước đây luôn `false` ⇒ trên DESKTOP không có `-progress pipe:2` nên
      // `onElapsed` không bao giờ được gọi: thanh tiến trình đứng ở 0% suốt
      // 30 phút và người dùng tưởng app treo (rồi bấm Huỷ).
      useProgress: _supportsProgressPipe,
    );

    emit(MediaExportProgress(
      phase: MediaExportPhase.running,
      fraction: MediaEstimates.progressFraction(
        elapsedMs: 0,
        totalMs: totalMs,
        sliceStartFraction: sliceCount <= 1 ? 0 : sliceIndex / sliceCount,
        sliceSpanFraction: sliceCount <= 1 ? 1 : 1 / sliceCount,
      ),
      totalMs: totalMs,
      currentSlice: sliceIndex,
      totalSlices: sliceCount,
    ));

    try {
      await _engine.run(
        args,
        token: token,
        onElapsed: (elapsedMs) => emit(MediaExportProgress(
          phase: MediaExportPhase.running,
          fraction: MediaEstimates.progressFraction(
            elapsedMs: elapsedMs,
            totalMs: totalMs,
            sliceStartFraction: sliceCount <= 1 ? 0 : sliceIndex / sliceCount,
            sliceSpanFraction: sliceCount <= 1 ? 1 : 1 / sliceCount,
          ),
          elapsedMs: elapsedMs,
          totalMs: totalMs,
          currentSlice: sliceIndex,
          totalSlices: sliceCount,
        )),
      );
    } catch (_) {
      try {
        final part = File(partPath);
        if (await part.exists()) await part.delete();
      } catch (_) {}
      rethrow;
    }

    // Huy ngay sau khi FFmpeg ghi xong: file `.part` da co tren dia nen phai
    // xoa TRUOC khi nem, neu khong se nam lai vinh vien (khong ai adopt no).
    if (token?.isCancelled ?? false) {
      try {
        final part = File(partPath);
        if (await part.exists()) await part.delete();
      } catch (_) {}
      throw const MediaExportException(MediaExportErrorKind.cancelled);
    }

    final produced = File(partPath);
    if (!await produced.exists() || await produced.length() < 512) {
      try {
        if (await produced.exists()) await produced.delete();
      } catch (_) {}
      throw const MediaExportException(MediaExportErrorKind.failed);
    }

    // Đưa vào thư viện app (path bền vững) qua hợp đồng `adoptPath` của host.
    // Bản thật dùng `AudioImportService.ensurePersistent` (tự dedupe theo nội
    // dung) ⇒ gọi trước khi rename sẽ tránh ghi đè nhầm.
    try {
      final adopted = await _host.adoptPath(
        tempPath: partPath,
        fileName: p.basename(finalPath),
      );
      if (adopted.isNotEmpty && adopted != partPath) {
        try {
          if (await produced.exists()) await produced.delete();
        } catch (_) {}
        return adopted;
      }
      // Host không di chuyển file (hoặc trả lại đúng đường dẫn tạm) ⇒ rơi
      // xuống nhánh đổi tên bên dưới để KHÔNG trả về file `.part`.
    } catch (e) {
      debugPrint('[MediaTools] import exported file failed: $e');
    }

    // Không import được (ví dụ ổ đầy) → vẫn trả file trong `media_exports/`.
    try {
      await produced.rename(finalPath);
    } catch (e) {
      try {
        if (await produced.exists()) await produced.delete();
      } catch (_) {}
      throw MediaExportException(MediaExportErrorKind.failed, detail: '$e');
    }
    return finalPath;
  }

  Future<String> _writeLrc({
    required String audioPath,
    required List<ShiftedLrcLine> lines,
    String? title,
    Duration? duration,
  }) async {
    final lrcPath = SourceArtifactStore.sidecarLrcPath(audioPath);
    // Vài engine (Windows) không đổi tên file đang mở ⇒ ghi chắc chắn vào thư
    // mục cha trước (thư mục thư viện đã tồn tại, đây chỉ là lưới an toàn).
    final parent = Directory(p.dirname(lrcPath));
    if (!await parent.exists()) await parent.create(recursive: true);
    final content = LrcTimeShifter.buildLrc(
      lines,
      title: title == null ? null : p.basenameWithoutExtension(title),
      totalDuration: duration,
    );
    await File(lrcPath).writeAsString(content, flush: true);
    try {
      await _host.rememberLrc(audioPath: audioPath, lrcPath: lrcPath);
    } catch (e) {
      debugPrint('[MediaTools] rememberLrc error: $e');
    }
    return lrcPath;
  }

  int? _safeFreeSpace(String dirPath) {
    try {
      return _freeSpaceProbe(dirPath);
    } catch (e) {
      debugPrint('[MediaTools] freeSpace error: $e');
      return null;
    }
  }

  Duration _effectiveDuration(
    MediaExportRequest request,
    Duration? total,
  ) {
    switch (request.scope) {
      case MediaExportScope.full:
        return total ?? Duration.zero;
      case MediaExportScope.clip:
        if (request.duration != null) return request.duration!;
        if (total != null) return total - request.start;
        return Duration.zero;
      case MediaExportScope.chapters:
        if (request.slices.isEmpty) return total ?? Duration.zero;
        var sum = Duration.zero;
        for (final s in request.slices) {
          sum += s.duration ?? Duration.zero;
        }
        return sum;
    }
  }

  Duration _durationOfFile(
    List<String> produced,
    String path,
    Duration fallback,
  ) {
    if (produced.length > 1) return Duration.zero;
    return fallback;
  }

  static List<MediaExportSlice> _evenSlices(Duration? total) {
    if (total == null || total.inMilliseconds <= 0) return const [];
    return [MediaExportSlice(start: Duration.zero, duration: total)];
  }

  /// Đọc thử LRC nguồn (dùng ở UI để biết có nên hiện tuỳ chọn "kèm lời").
  Future<String?> sourceLrcPreview(String audioPath) =>
      _host.readSourceLrc(audioPath);

  /// Tiện ích cho P1 self-test: chuyển 1 file sang preset, không đăng ký gì.
  Future<String> convertOnly({
    required String inputPath,
    required MediaExportPreset preset,
    FfmpegCancelToken? token,
  }) async {
    final result = await export(
      MediaExportRequest(
        inputPath: inputPath,
        preset: preset,
        keepLrc: false,
        registerInRecent: false,
      ),
      token: token,
    );
    return result.primaryPath;
  }
}
