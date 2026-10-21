// ignore_for_file: unintended_html_in_doc_comment
//
// YT-AUDIT-01 (IN4-97): tải audio bằng HTTP **có Range** — resume được khi
//                       YouTube đóng kết nối giữa chừng (bug "chỉ tải một
//                       xíu xong dừng": file CỤT vẫn bị báo thành công).
//                       Ghi ra `.part` + watchdog kẹt tiến trình 20s + chỉ
//                       emit Done khi nhận ĐỦ `totalBytes`.
// FIX kẹt 5%: dùng await for trực tiếp trên stream (theo cách của yt_service_explode.dart)
//             Bỏ StreamController trung gian gây race condition
// THÊM: chọn chất lượng audio (cao/trung/thấp + chọn cụ thể)
// THÊM: cancel thực sự bằng flag check trong await for

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/yt_video.dart';
import 'yt_dlp_sidecar.dart';

// ─── Audio Quality ────────────────────────────────────────

enum YtAudioQuality {
  highest('Cao nhất', null),
  medium('Trung bình', 128000),
  low('Thấp / Nhỏ', 64000);

  final String label;
  final int? maxBitrateBps;

  const YtAudioQuality(this.label, this.maxBitrateBps);
}

// ─── Events ──────────────────────────────────────────────

sealed class YtDownloadEvent {}

class YtDownloadProgress extends YtDownloadEvent {
  final double progress; // 0.0 → 1.0
  final String progressText;
  YtDownloadProgress(this.progress, this.progressText);
}

class YtDownloadDone extends YtDownloadEvent {
  final String filePath;
  final String quality; // e.g. "128kbps"
  YtDownloadDone(this.filePath, {this.quality = ''});
}

class YtDownloadFailed extends YtDownloadEvent {
  final String message;
  YtDownloadFailed(this.message);
}

// ─── Downloader ───────────────────────────────────────────

class YtDownloader {
  YtDownloader._();
  static final YtDownloader instance = YtDownloader._();

  bool _cancelled = false;

  /// Lấy danh sách stream audio có sẵn để hiển thị lựa chọn chất lượng
  Future<List<AudioOnlyStreamInfo>> getAudioStreams(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest =
          await yt.videos.streamsClient.getManifest(videoId);
      final streams = manifest.audioOnly.toList()
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      return streams;
    } catch (e) {
      debugPrint('getAudioStreams error: $e');
      return [];
    } finally {
      yt.close();
    }
  }

  /// Download audio — trả về Stream<YtDownloadEvent>
  Stream<YtDownloadEvent> download(
    YtVideo video, {
    YtAudioQuality quality = YtAudioQuality.highest,
    AudioOnlyStreamInfo? specificStream,
  }) {
    final ctrl = StreamController<YtDownloadEvent>();
    _doDownload(ctrl, video,
        quality: quality, specificStream: specificStream);
    return ctrl.stream;
  }

  /// YT-AUDIT-01 (IN4-97) — Bản cũ **không kiểm tra `downloaded ==
  /// totalBytes`**: YouTube thường đóng kết nối giữa chừng *mà không ném
  /// lỗi* ⇒ vòng `await for` kết thúc sớm, file còn cụt nhưng vẫn `emit(
  /// YtDownloadDone)` (vì `finalSize` vẫn > 1000 byte) → đúng triệu chứng
  /// "chỉ tải một xíu xong dừng".
  ///
  /// Bản mới: tải bằng HTTP **có `Range`** (resume được), ghi ra file
  /// `.part`, có **watchdog kẹt tiến trình**, và chỉ báo xong khi đã nhận
  /// ĐỦ `totalBytes`.
  static const int _maxAttempts = 8;
  static const Duration _stallTimeout = Duration(seconds: 20);

  Future<void> _doDownload(
    StreamController<YtDownloadEvent> ctrl,
    YtVideo video, {
    required YtAudioQuality quality,
    AudioOnlyStreamInfo? specificStream,
  }) async {
    _cancelled = false;
    final yt = YoutubeExplode();

    void emit(YtDownloadEvent e) {
      if (!ctrl.isClosed) ctrl.add(e);
    }

    void fail(String msg) {
      emit(YtDownloadFailed(msg));
      if (!ctrl.isClosed) ctrl.close();
    }

    try {
      emit(YtDownloadProgress(0.03, 'Đang lấy thông tin video...'));

      // ── Step 1: Video info ──────────────────────────────
      final videoObj = await yt.videos.get(video.id);
      if (_cancelled) {
        yt.close();
        fail('Đã hủy');
        return;
      }

      emit(YtDownloadProgress(0.07, 'Đang phân tích stream...'));

      // ── Step 2: Manifest ───────────────────────────────
      final manifest =
          await yt.videos.streamsClient.getManifest(video.id);
      if (_cancelled) {
        yt.close();
        fail('Đã hủy');
        return;
      }

      final allAudio = manifest.audioOnly.toList()
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      if (allAudio.isEmpty) {
        yt.close();
        fail('Không tìm thấy stream audio');
        return;
      }

      // ── Step 3: Chọn stream ────────────────────────────
      final streamInfo =
          specificStream ?? _selectStream(allAudio, quality);
      final totalBytes = streamInfo.size.totalBytes;
      final ext = streamInfo.container.name;
      final kbps = streamInfo.bitrate.bitsPerSecond ~/ 1000;
      final itag = streamInfo.tag;

      emit(YtDownloadProgress(
          0.10, 'Chuẩn bị · ${kbps}kbps · ${_sizeLabel(totalBytes)}'));

      // ── Step 4: Chuẩn bị file ─────────────────────────
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/youtube_downloads');
      if (!await folder.exists()) await folder.create(recursive: true);

      final safeTitle = _sanitize(videoObj.title);
      final filePath = '${folder.path}/$safeTitle.$ext';
      final partPath = '$filePath.part';
      final part = File(partPath);

      // Xoá file đích cũ để `rename` không vấp (file .part là file tạm).
      final target = File(filePath);
      if (await target.exists()) await target.delete();

      // URL của YouTube có HẠN (~6 giờ) ⇒ cần hàm xin URL MỚI khi gặp 403.
      Future<Uri> refreshUrl() async {
        final m = await yt.videos.streamsClient.getManifest(video.id);
        final list = m.audioOnly.toList()
          ..sort((a, b) =>
              b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        final same = list.where((s) => s.tag == itag).toList();
        final picked = same.isNotEmpty
            ? same.first
            : (specificStream ?? _selectStream(list, quality));
        return picked.url;
      }

      // ── Step 5: Tải CÓ RESUME ─────────────────────────
      final ok = await _downloadResumable(
        uri: streamInfo.url,
        refreshUrl: refreshUrl,
        part: part,
        totalBytes: totalBytes,
        emit: emit,
      );

      yt.close();

      // ── Step 6: Kết quả ───────────────────────────────
      if (_cancelled) {
        await _safeDelete(part);
        fail('Đã hủy');
        return;
      }

      if (!ok) {
        final got = await part.length();
        debugPrint(
          '❌ [in4up-yt] tải chưa hoàn tất: $got / $totalBytes bytes '
          'sau $_maxAttempts lần thử.',
        );
        // Biết trước kích thước ⇒ GIỮ file .part để lần tải sau nối tiếp
        // đúng chỗ dở (đúng như dòng thông báo bên dưới). Không biết kích
        // thước thì không có gì để nối ⇒ dọn đi.
        if (totalBytes <= 0) await _safeDelete(part);
        fail(
          'Tải chưa xong (${_sizeLabel(got)} / ${_sizeLabel(totalBytes)}). '
          'Mạng bị ngắt — bấm tải lại, sẽ nối tiếp từ chỗ dở.',
        );
        return;
      }

      // Đủ byte ⇒ mới chuyển .part thành file thật.
      if (await target.exists()) await target.delete();
      await part.rename(filePath);

      final finalSize = await File(filePath).length();
      if (finalSize < 1000) {
        await _safeDelete(File(filePath));
        fail('File tải về quá nhỏ, thử lại');
        return;
      }

      emit(YtDownloadDone(filePath, quality: '${kbps}kbps'));
      if (!ctrl.isClosed) ctrl.close();
    } catch (e) {
      yt.close();
      // WP-Z (PLAN-020): tầng 2 — yt-dlp sidecar (desktop, user tự cài)
      // khi explode gãy (YouTube đổi client). Không có sidecar thì báo lỗi gốc.
      final ok = await _trySidecarDownload(ctrl, video, quality);
      if (!ok) fail(_friendlyError(e.toString()));
    }
  }

  /// Tải một stream về [part] bằng HTTP `Range`, tự nối tiếp khi đứt.
  ///
  /// Trả `true` **chỉ khi** nhận đủ [totalBytes].
  Future<bool> _downloadResumable({
    required Uri uri,
    required Future<Uri> Function() refreshUrl,
    required File part,
    required int totalBytes,
    required void Function(YtDownloadEvent) emit,
  }) async {
    var currentUri = uri;

    // Không biết trước kích thước ⇒ không thể verify, nhưng vẫn có thể
    // resume nhờ `Range` (server sẽ trả 416 khi đã xong — xử lý bên dưới).
    final knownSize = totalBytes > 0;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (_cancelled) return false;

      var offset = await part.length();
      if (knownSize && offset >= totalBytes) {
        debugPrint('✅ [in4up-yt] resume: đã đủ $offset / $totalBytes bytes');
        return true;
      }
      // File .part còn sót từ một stream KHÁC (đổi chất lượng) ⇒ xoá.
      if (knownSize && offset > totalBytes) {
        await _safeDelete(part);
        offset = 0;
      }

      final client = http.Client();
      IOSink? sink;
      try {
        final req = http.Request('GET', currentUri);
        // Nối tiếp từ byte đã có. Server không hỗ trợ Range sẽ trả 200 —
        // khi đó ghi lại từ đầu (`offset = 0`).
        if (offset > 0) {
          req.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
        }
        final resp = await client.send(req);

        if (resp.statusCode == 416) {
          // Range vượt quá kích thước ⇒ thực ra đã tải xong.
          if (knownSize) return true;
          client.close();  // http.Client.close() trả void — không await được.
          await Future<void>.delayed(_retryDelay(attempt));
          continue;
        }

        if (resp.statusCode == 403) {
          // URL stream hết hạn ⇒ xin URL MỚI rồi thử lại ngay.
          debugPrint('↻ [in4up-yt] stream URL hết hạn (403) — xin URL mới');
          try {
            currentUri = await refreshUrl();
          } catch (_) {}
          client.close();  // http.Client.close() trả void — không await được.
          await Future<void>.delayed(_retryDelay(attempt));
          continue;
        }

        if (resp.statusCode != 206 && resp.statusCode != 200) {
          debugPrint(
              '❌ [in4up-yt] HTTP ${resp.statusCode} khi tải (thử $attempt)');
          client.close();  // http.Client.close() trả void — không await được.
          await Future<void>.delayed(_retryDelay(attempt));
          continue;
        }

        if (resp.statusCode == 200) {
          // KHÔNG hỗ trợ Range ⇒ ghi đè từ đầu.
          offset = 0;
          await _safeDelete(part);
        }

        if (!await part.exists()) await part.create(recursive: true);
        sink = part.openWrite(mode: FileMode.writeOnlyAppend);

        var received = offset;
        var lastEmit = 0;

        // `Stream.timeout` reset đồng hồ sau MỖI chunk ⇒ đúng nghĩa
        // "watchdog kẹt tiến trình": 20 giây không có byte nào ⇒ đóng
        // stream (không ném lỗi) ⇒ vòng lặp ngoài thử lại từ `received`.
        await for (final chunk in resp.stream.timeout(
          _stallTimeout,
          onTimeout: (EventSink<List<int>> timedOut) {
            debugPrint('⏱️ [in4up-yt] không nhận byte nào trong '
                '${_stallTimeout.inSeconds}s ⇒ thử lại');
            timedOut.close();
          },
        )) {
          if (_cancelled) break;
          sink.add(chunk);
          received += chunk.length;

          final pct = knownSize ? received / totalBytes : 0.5;
          if (received - lastEmit > 65536) {
            lastEmit = received;
            emit(YtDownloadProgress(
              (0.10 + pct * 0.88).clamp(0.0, 0.98),
              '${_sizeLabel(received)} / ${_sizeLabel(totalBytes)}'
              '${attempt > 0 ? ' · lần ${attempt + 1}' : ''}',
            ));
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;
        client.close();  // http.Client.close() trả void — không await được.

        if (_cancelled) return false;

        if (knownSize && received >= totalBytes) {
          debugPrint(
              '✅ [in4up-yt] tải xong $received / $totalBytes bytes '
              '(số lần nối: $attempt)');
          return true;
        }

        // Chưa đủ: stream kết thúc SỚM mà không báo lỗi (đúng bug cũ).
        debugPrint(
            '⚠️ [in4up-yt] stream kết thúc sớm ở $received / $totalBytes '
            'bytes ⇒ nối tiếp (lần ${attempt + 1})');
        await Future<void>.delayed(_retryDelay(attempt));
      } catch (e) {
        debugPrint('⚠️ [in4up-yt] lỗi tải (lần ${attempt + 1}): $e');
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}
        try {
          client.close();
        } catch (_) {}
        if (_cancelled) return false;
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }

    // Hết số lần thử: chấp nhận nếu đã đủ (trường hợp không biết size thì
    // coi là xong khi stream tự kết thúc).
    if (!knownSize) return await part.length() > 1000;
    return await part.length() >= totalBytes;
  }

  /// Backoff đơn giản 400ms → 4s. (Không dùng `Duration.clamp` — toán tử
  /// đó không có trong `dart:core`.)
  Duration _retryDelay(int attempt) {
    final ms = 400 * (attempt + 1);
    return Duration(milliseconds: ms > 4000 ? 4000 : ms);
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Hủy download đang chạy
  void cancel() {
    _cancelled = true;
  }

  /// yt-dlp (thang 0–10, 0 = tốt nhất) tương ứng [YtAudioQuality]
  int _sidecarAudioQuality(YtAudioQuality q) => switch (q) {
        YtAudioQuality.highest => 0,
        YtAudioQuality.medium => 5,
        YtAudioQuality.low => 8,
      };

  /// Tầng 2: tải bằng yt-dlp sidecar. Trả về true nếu đã có kết quả
  /// (thành công hoặc tự xử lý sự kiện hủy).
  Future<bool> _trySidecarDownload(
    StreamController<YtDownloadEvent> ctrl,
    YtVideo video,
    YtAudioQuality quality,
  ) async {
    final sidecar = YtDlpSidecar.instance;
    if (!await YtDlpSidecar.isAvailable()) return false;
    debugPrint('⬇️ explode gãy — thử yt-dlp sidecar cho ${video.id}');
    try {
      await for (final ev in sidecar.downloadAudio(
        video.id,
        audioQuality: _sidecarAudioQuality(quality),
      )) {
        if (_cancelled) {
          sidecar.cancel();
          break;
        }
        if (ctrl.isClosed) return false;
        if (ev is YtDlpProgress) {
          ctrl.add(YtDownloadProgress(ev.progress, ev.text));
        } else if (ev is YtDlpDone) {
          ctrl.add(YtDownloadDone(ev.filePath, quality: 'yt-dlp'));
          if (!ctrl.isClosed) ctrl.close();
          return true;
        } else if (ev is YtDlpFailed) {
          debugPrint('yt-dlp sidecar fail: ${ev.message}');
          break;
        }
      }
      if (_cancelled) {
        if (!ctrl.isClosed) {
          ctrl.add(YtDownloadFailed('Đã hủy'));
          ctrl.close();
        }
        return true; // đã tự kết thúc bằng sự kiện hủy
      }
      return false;
    } catch (e) {
      debugPrint('yt-dlp sidecar error: $e');
      return false;
    }
  }

  // ─── Helpers ─────────────────────────────────────────

  AudioOnlyStreamInfo _selectStream(
    List<AudioOnlyStreamInfo> streams,
    YtAudioQuality quality,
  ) {
    if (quality == YtAudioQuality.highest) {
      // Ưu tiên mp4/aac — tương thích tốt hơn với just_audio
      final mp4 = streams
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList();
      return mp4.isNotEmpty ? mp4.first : streams.first;
    }

    final maxBps = quality.maxBitrateBps!;
    final candidates =
        streams.where((s) => s.bitrate.bitsPerSecond <= maxBps).toList();

    // Lấy bitrate cao nhất trong giới hạn; không có → lấy thấp nhất
    return candidates.isNotEmpty ? candidates.first : streams.last;
  }

  String _sizeLabel(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _sanitize(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .substring(0, name.length.clamp(0, 80));

  String _friendlyError(String raw) {
    if (raw.contains('unplayable') || raw.contains('Unplayable')) {
      return 'Video bị giới hạn tải xuống';
    }
    if (raw.contains('unavailable')) return 'Video không khả dụng';
    if (raw.contains('SocketException') || raw.contains('Network')) {
      return 'Lỗi mạng — kiểm tra kết nối';
    }
    if (raw.contains('403')) return 'Truy cập bị từ chối (403)';
    if (raw.contains('429')) return 'Rate limit, thử lại sau';
    return 'Lỗi: ${raw.substring(0, raw.length.clamp(0, 100))}';
  }
}
