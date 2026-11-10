// lib/features/media_tools/services/media_probe_parser.dart
//
// AVTOOL-002 (PLAN-047 P1) — ĐỌC KẾT QUẢ PROBE. HÀM THUẦN.
//
// `ffmpeg -i file` in ra stderr (và `ffprobe` in JSON). Ở đây chỉ parse phần
// TEXT mà app đã có sẵn đường lấy: `AudioConverter.probeDurationMs` đã có logic
// tương tự nhưng KHÔNG trả codec/tần số/kênh — mà đó lại đúng là thứ quyết định
// "nối bằng copy được không".
//
// Trích từ log thật:
//   Duration: 01:23:45.67, start: 0.000000, bitrate: 128 kb/s
//   Stream #0:0[0x1](und): Audio: aac (LC) (mp4a / 0x6134706D), 44100 Hz, stereo, fltp, 128 kb/s
//   Stream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s
//   Stream #0:1: Video: h264 (High), yuv420p, 1920x1080, 30 fps
//   Stream #0:0: Audio: pcm_s16le ([1][0][0][0] / 0x0001), 16000 Hz, mono, s16, 256 kb/s

import 'media_command_builder.dart' show MediaStreamSignature;

class MediaProbeInfo {
  const MediaProbeInfo({
    this.durationMs,
    this.bitrateKbps,
    this.signature,
    this.hasVideo = false,
    this.audioStreamCount = 0,
    this.videoStreamCount = 0,
  });

  final int? durationMs;
  final int? bitrateKbps;

  /// Chữ ký của luồng audio ĐẦU TIÊN (thứ mà lệnh của app sẽ lấy: `-map 0:a:0`).
  final MediaStreamSignature? signature;

  final bool hasVideo;
  final int audioStreamCount;
  final int videoStreamCount;

  bool get hasAudio => audioStreamCount > 0;

  /// Probe CÓ đọc được danh sách luồng hay không.
  ///
  /// PSRC-177: trước đây `hasAudio == false` được dùng cho MỌI trường hợp —
  /// kể cả khi probe không trả về log nào (plugin trả kết quả rỗng, log bị
  /// xoá, `ffmpeg -i` chưa kịp in header). Hệ quả: mọi lần xuất đều báo
  /// "File nguồn không có âm thanh" — sai, vì "không biết" không phải "không
  /// có". Chỉ khi thấy ít nhất một dòng `Stream #...` mới được kết luận.
  bool get streamsKnown => audioStreamCount > 0 || videoStreamCount > 0;

  /// Nguồn CHẮC CHẮN không có tiếng (biết rõ luồng mà không có luồng audio).
  bool get definitelySilent => streamsKnown && audioStreamCount == 0;
}

class MediaProbeParser {
  const MediaProbeParser._();

  static final RegExp _durationRe =
      RegExp(r'Duration:\s*(\d+):(\d{2}):(\d{2})\.(\d{1,3})');
  static final RegExp _overallBitrateRe = RegExp(r'bitrate:\s*(\d+)\s*kb/s');
  static final RegExp _audioStreamRe = RegExp(r'Stream #\d+:\d+.*?:\s*Audio:\s*([^,\n]+)');
  static final RegExp _videoStreamRe = RegExp(r'Stream #\d+:\d+.*?:\s*Video:');
  static final RegExp _sampleRateRe = RegExp(r'(\d{4,6})\s*Hz');
  static final RegExp _channelsRe = RegExp(r'Hz,\s*(mono|stereo|\d+\s*channels)');

  /// Parse toàn bộ log probe (stderr của `ffmpeg -i`, hoặc output ffprobe dạng text).
  static MediaProbeInfo parse(String log) {
    if (log.isEmpty) return const MediaProbeInfo();

    int? durationMs;
    final d = _durationRe.firstMatch(log);
    if (d != null) {
      final h = int.parse(d.group(1)!);
      final mi = int.parse(d.group(2)!);
      final s = int.parse(d.group(3)!);
      final frac = d.group(4)!.padRight(3, '0').substring(0, 3);
      durationMs = ((h * 3600) + (mi * 60) + s) * 1000 + int.parse(frac);
    }

    int? bitrateKbps;
    final overall = _overallBitrateRe.firstMatch(log);
    if (overall != null) bitrateKbps = int.tryParse(overall.group(1)!);

    final audioStreams = _audioStreamRe.allMatches(log).toList();
    MediaStreamSignature? signature;
    if (audioStreams.isNotEmpty) {
      final lineStart = audioStreams.first.start;
      final lineEnd = log.indexOf('\n', lineStart);
      final audioLine =
          log.substring(lineStart, lineEnd < 0 ? log.length : lineEnd);
      final codec = _codecOf(audioLine, audioStreams.first.group(1) ?? '');
      final rate = _sampleRateRe.firstMatch(audioLine);
      final channels = _channelsRe.firstMatch(audioLine);
      if (codec.isNotEmpty) {
        signature = MediaStreamSignature(
          codec: codec,
          sampleRate: rate == null ? 0 : int.parse(rate.group(1)!),
          channels: _channelCount(channels?.group(1)),
        );
      }
    }

    return MediaProbeInfo(
      durationMs: durationMs,
      bitrateKbps: bitrateKbps,
      signature: signature,
      hasVideo: _videoStreamRe.hasMatch(log),
      audioStreamCount: audioStreams.length,
      videoStreamCount: _videoStreamRe.allMatches(log).length,
    );
  }

  /// `aac (LC) (mp4a / 0x6134706D)` → `aac`; `pcm_s16le ([1][0][0][0] / 0x0001)`
  /// → `pcm_s16le`; `mp3` → `mp3`.
  static String _codecOf(String line, String rawName) {
    final name = rawName.trim();
    final paren = name.indexOf('(');
    final base = (paren > 0 ? name.substring(0, paren) : name).trim();
    if (base.isNotEmpty) return base.toLowerCase();
    final m = RegExp(r'Audio:\s*([A-Za-z0-9_]+)').firstMatch(line);
    return (m?.group(1) ?? '').toLowerCase();
  }

  static int _channelCount(String? raw) {
    if (raw == null) return 0;
    final v = raw.trim().toLowerCase();
    if (v == 'mono') return 1;
    if (v == 'stereo') return 2;
    final m = RegExp(r'(\d+)').firstMatch(v);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  /// Kết luận tiền kiểm cho một yêu cầu xuất (thuần, dùng ở service + UI).
  ///
  /// Trả `null` nếu ổn; trả lý do (enum) nếu phải chặn/đổi preset.
  ///
  /// Ba nhánh, theo thứ tự "biết chắc → không biết":
  ///   1. Biết rõ nguồn **không có luồng tiếng** ⇒ CHẶN (không có gì để xuất).
  ///   2. **Không đọc được** thông tin nguồn (probe rỗng/lỗi) ⇒ KHÔNG chặn:
  ///      chỉ hạ `copy` xuống mã hoá lại cho an toàn. Trước đây nhánh này bị
  ///      gộp vào (1) ⇒ mọi lần xuất đều báo "File nguồn không có âm thanh"
  ///      (PSRC-177).
  ///   3. Biết rõ có tiếng ⇒ chỉ kiểm tương thích khi `wantsCopy`.
  static MediaPresetAdjustment? adjustPreset({
    required MediaProbeInfo info,
    required bool wantsCopy,
    required String outputExtension,
  }) {
    if (!info.streamsKnown) {
      // Không có bằng chứng KHÔNG phải bằng chứng không có. Copy mà không
      // biết codec nguồn thì rất dễ ra file câm/không mở được ⇒ mã hoá lại.
      return wantsCopy
          ? const MediaPresetAdjustment.reencode(
              MediaPresetAdjustmentReason.probeUnavailable,
            )
          : null;
    }
    if (!info.hasAudio) {
      return const MediaPresetAdjustment.blocked(
        MediaPresetAdjustmentReason.noAudioTrack,
      );
    }
    if (wantsCopy) {
      // Copy chỉ hợp lệ khi container đích chứa được codec nguồn.
      // aac → m4a: OK. mp3 → mp3: OK. pcm → wav: OK. Còn lại: phải mã hoá lại.
      final codec = info.signature?.codec ?? '';
      final ext = outputExtension.toLowerCase();
      final compatible = switch (ext) {
        'm4a' || 'mp4' || 'm4b' => codec.startsWith('aac') || codec == 'alac',
        'mp3' => codec == 'mp3',
        'wav' => codec.startsWith('pcm'),
        'opus' || 'ogg' => codec == 'opus' || codec == 'vorbis',
        _ => false,
      };
      if (!compatible) {
        return const MediaPresetAdjustment.reencode(
          MediaPresetAdjustmentReason.containerMismatch,
        );
      }
    }
    return null;
  }
}

enum MediaPresetAdjustmentReason {
  noAudioTrack,
  containerMismatch,

  /// PSRC-177: không đọc được thông tin nguồn (probe rỗng/lỗi) ⇒ hạ về mã
  /// hoá lại thay vì chặn oan bằng "không có âm thanh".
  probeUnavailable,
}

class MediaPresetAdjustment {
  const MediaPresetAdjustment.reencode(this.reason) : blocked = false;
  const MediaPresetAdjustment.blocked(this.reason) : blocked = true;

  final MediaPresetAdjustmentReason reason;
  final bool blocked;

  /// Thông điệp canonical tiếng Anh (UI dịch qua catalog).
  String get technicalMessage => switch (reason) {
        MediaPresetAdjustmentReason.noAudioTrack =>
          'The source file has no audio track.',
        MediaPresetAdjustmentReason.containerMismatch =>
          'This format needs re-encoding instead of a direct copy.',
        MediaPresetAdjustmentReason.probeUnavailable =>
          'Source information could not be read — the file is re-encoded '
              'instead of copied.',
      };
}
