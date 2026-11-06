// lib/features/media_tools/models/media_export_models.dart
//
// AVTOOL-002 (PLAN-046 P1) — model PURE cho công cụ media: preset định dạng,
// yêu cầu xuất, kết quả, lỗi, tiến trình.
//
// Tách khỏi tầng I/O để CI (`flutter test` trên host VM) kiểm được toàn bộ
// phần "khó đúng": chọn tham số codec, ước lượng dung lượng, đặt tên file,
// ánh xạ lỗi FFmpeg → thông báo cho người dùng.

/// Preset xuất file. Mỗi preset = (phần mở rộng, tham số codec, bitrate ước
/// lượng). `bitrateKbps == null` nghĩa là bitrate lấy từ nguồn (chế độ copy).
enum MediaExportPreset {
  /// MP3 VBR mức 3 (~130 kbps) — đủ tốt cho giọng nói, file nhỏ.
  mp3Voice('mp3', ['-c:a', 'libmp3lame', '-q:a', '3'], 130, false, true),

  /// MP3 192 kbps — mặc định khuyến nghị cho clip học tập / chia sẻ.
  mp3Standard('mp3', ['-c:a', 'libmp3lame', '-b:a', '192k'], 192, false, true),

  /// MP3 256 kbps — khi nguồn là nhạc / cần chất lượng cao hơn.
  mp3High('mp3', ['-c:a', 'libmp3lame', '-b:a', '256k'], 256, false, true),

  /// M4A sao chép luồng (AAC) — KHÔNG mã hoá lại, nhanh nhất, giữ nguyên chất
  /// lượng gốc. Chỉ hợp lệ khi nguồn đã là AAC/MP4.
  m4aCopy('m4a', ['-c:a', 'copy'], null, true, false),

  /// M4A/AAC 96 kbps — dùng khi phải mã hoá lại (nguồn không phải AAC, hoặc
  /// cắt/nối cần mốc chính xác).
  m4aAac('m4a', ['-c:a', 'aac', '-b:a', '96k'], 96, false, true),

  /// WAV PCM 16-bit 44.1 kHz stereo — không mất dữ liệu, dùng để xử lý tiếp.
  wavPcm('wav', ['-c:a', 'pcm_s16le', '-ar', '44100', '-ac', '2'], 1411, true, false),

  /// Opus 48 kbps — nhỏ nhất trong nhóm "nghe được", tốt cho giọng nói dài.
  opus('opus', ['-c:a', 'libopus', '-b:a', '48k'], 48, false, true);

  const MediaExportPreset(
    this.extension,
    this.encodeArgs,
    this.estimatedBitrateKbps,
    this.lossless,
    this.isLossyEncode,
  );

  /// Phần mở rộng file (không có dấu chấm).
  final String extension;

  /// Tham số codec đưa vào lệnh FFmpeg.
  final List<String> encodeArgs;

  /// Bitrate trung bình để ước lượng dung lượng (kbps). `null` = lấy từ nguồn.
  final int? estimatedBitrateKbps;

  /// Không mất dữ liệu (WAV).
  final bool lossless;

  /// Có mã hoá lại (false = copy luồng, gần như tức thời).
  final bool isLossyEncode;

  bool get isCopy => !isLossyEncode && !lossless;

  /// Nhãn hiển thị — qua `uiText` ở lớp UI, đây chỉ là khoá tiếng Việt nguồn
  /// (theo luật i18n #5, chuỗi chrome đi qua catalog, không hard-code).
  String get labelKey {
    switch (this) {
      case MediaExportPreset.mp3Voice:
        return 'MP3 · giọng nói (nhỏ)';
      case MediaExportPreset.mp3Standard:
        return 'MP3 · 192 kbps (khuyến nghị)';
      case MediaExportPreset.mp3High:
        return 'MP3 · 256 kbps';
      case MediaExportPreset.m4aCopy:
        return 'M4A · giữ nguyên (nhanh nhất)';
      case MediaExportPreset.m4aAac:
        return 'M4A · AAC 96 kbps';
      case MediaExportPreset.wavPcm:
        return 'WAV · không mất dữ liệu';
      case MediaExportPreset.opus:
        return 'Opus · 48 kbps (nhỏ nhất)';
    }
  }

  /// Preset mặc định theo ngữ cảnh.
  ///
  /// - Clip học tập (đoạn A–B): MP3 192 kbps — mở được ở mọi máy nghe nhạc,
  ///   kích thước vừa phải, và `didactic` hơn AAC cho người dùng phổ thông.
  /// - Chuyển đổi cả file: nếu nguồn đã là AAC/MP4 thì `m4aCopy` (tức thời);
  ///   ngược lại MP3 192 kbps.
  static MediaExportPreset recommended({
    required String inputExtension,
    bool isClip = false,
  }) {
    if (isClip) return MediaExportPreset.mp3Standard;
    final ext = inputExtension.toLowerCase().replaceFirst('.', '');
    const alreadyAac = {'m4a', 'mp4', 'm4b', 'aac'};
    if (alreadyAac.contains(ext)) return MediaExportPreset.m4aCopy;
    return MediaExportPreset.mp3Standard;
  }
}

/// Phạm vi xuất.
enum MediaExportScope {
  /// Toàn bộ file.
  full,

  /// Một đoạn [start, start + duration).
  clip,

  /// Tách theo danh sách mốc (chương của Âm mục).
  chapters,
}

/// Loại nguồn — quyết định việc chỉ lấy luồng âm thanh hay cắt cả video.
enum MediaExportInputKind { audio, video }

/// Một chặng cắt (dùng cho tách theo chương / tách theo khoảng).
class MediaExportSlice {
  const MediaExportSlice({
    required this.start,
    this.duration,
    this.title,
  });

  final Duration start;

  /// `null` = tới hết file.
  final Duration? duration;

  /// Tiêu đề dùng để đặt tên file (tiêu đề chương, "Phần 3"…).
  final String? title;

  @override
  String toString() =>
      'MediaExportSlice(start=$start, duration=$duration, title="$title")';
}

/// Yêu cầu xuất file.
class MediaExportRequest {
  const MediaExportRequest({
    required this.inputPath,
    required this.preset,
    this.scope = MediaExportScope.full,
    this.inputKind = MediaExportInputKind.audio,
    this.start = Duration.zero,
    this.duration,
    this.slices = const [],
    this.title,
    this.keepLrc = true,
    this.registerInRecent = true,
  });

  /// Đường dẫn FILE THẬT (đã "materialize" nếu nguồn là `content://`).
  final String inputPath;

  final MediaExportPreset preset;
  final MediaExportScope scope;
  final MediaExportInputKind inputKind;

  /// Mốc bắt đầu (chỉ dùng với [MediaExportScope.clip]).
  final Duration start;

  /// Độ dài đoạn (null = tới hết).
  final Duration? duration;

  /// Danh sách chặng (chỉ dùng với [MediaExportScope.chapters]).
  final List<MediaExportSlice> slices;

  /// Tiêu đề người đọc được (dùng đặt tên file/thư viện).
  final String? title;

  /// Xuất kèm LRC đã dịch mốc nếu nguồn có LRC.
  final bool keepLrc;

  /// Thêm kết quả vào "Gần đây" của tab Nghe.
  final bool registerInRecent;

  MediaExportRequest copyWith({
    String? inputPath,
    MediaExportPreset? preset,
    MediaExportScope? scope,
    MediaExportInputKind? inputKind,
    Duration? start,
    Duration? duration,
    List<MediaExportSlice>? slices,
    String? title,
    bool? keepLrc,
    bool? registerInRecent,
  }) {
    return MediaExportRequest(
      inputPath: inputPath ?? this.inputPath,
      preset: preset ?? this.preset,
      scope: scope ?? this.scope,
      inputKind: inputKind ?? this.inputKind,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      slices: slices ?? this.slices,
      title: title ?? this.title,
      keepLrc: keepLrc ?? this.keepLrc,
      registerInRecent: registerInRecent ?? this.registerInRecent,
    );
  }
}

/// Lỗi đã chuẩn hoá — lớp UI chỉ cần ánh xạ enum → chuỗi i18n.
enum MediaExportErrorKind {
  /// Desktop không có ffmpeg (mobile không bao giờ gặp).
  ffmpegMissing,

  /// File nguồn không tồn tại / không đọc được.
  inputUnreadable,

  /// File nguồn không có luồng âm thanh (video câm).
  noAudioTrack,

  /// Định dạng/ codec không hỗ trợ.
  unsupported,

  /// Không đủ dung lượng trống.
  noSpace,

  /// Người dùng huỷ.
  cancelled,

  /// Lỗi khác từ FFmpeg.
  failed,
}

class MediaExportError {
  const MediaExportError(this.kind, {this.detail});

  final MediaExportErrorKind kind;

  /// Log kỹ thuật (30 dòng cuối) — chỉ hiển thị trong "Chi tiết".
  final String? detail;

  /// Thông điệp canonical tiếng Anh (tầng service không có BuildContext).
  String get technicalMessage {
    switch (kind) {
      case MediaExportErrorKind.ffmpegMissing:
        return 'FFmpeg is not available on this device.';
      case MediaExportErrorKind.inputUnreadable:
        return 'The source file cannot be read.';
      case MediaExportErrorKind.noAudioTrack:
        return 'The source file has no audio track.';
      case MediaExportErrorKind.unsupported:
        return 'This format is not supported.';
      case MediaExportErrorKind.noSpace:
        return 'Not enough free space for the output file.';
      case MediaExportErrorKind.cancelled:
        return 'Cancelled.';
      case MediaExportErrorKind.failed:
        return 'Export failed.';
    }
  }

  @override
  String toString() => 'MediaExportError(${kind.name}): $technicalMessage';
}

/// Trạng thái tác vụ, phát qua `Stream`.
enum MediaExportPhase { preparing, running, finalizing, done, failed, cancelled }

class MediaExportProgress {
  const MediaExportProgress({
    required this.phase,
    this.fraction = 0,
    this.elapsedMs = 0,
    this.totalMs = 0,
    this.currentSlice = 0,
    this.totalSlices = 1,
    this.message,
  });

  final MediaExportPhase phase;

  /// 0..1 — đã clamp, luôn tính cả tiến trình của các chặng trước.
  final double fraction;
  final int elapsedMs;
  final int totalMs;
  final int currentSlice;
  final int totalSlices;
  final String? message;

  bool get isTerminal =>
      phase == MediaExportPhase.done ||
      phase == MediaExportPhase.failed ||
      phase == MediaExportPhase.cancelled;
}

/// Kết quả một lần xuất.
class MediaExportResult {
  const MediaExportResult({
    required this.outputPaths,
    required this.sizeBytes,
    this.lrcPaths = const [],
    this.warnings = const [],
  });

  /// Một đường dẫn (xuất cả file / 1 clip) hoặc nhiều (tách chương).
  final List<String> outputPaths;
  final int sizeBytes;

  /// LRC đi kèm (cùng thứ tự với [outputPaths] khi có).
  final List<String> lrcPaths;

  /// Cảnh báo không chặn (ví dụ: "phải mã hoá lại vì khác tần số lấy mẫu").
  final List<String> warnings;

  String get primaryPath => outputPaths.isEmpty ? '' : outputPaths.first;

  bool get isEmpty => outputPaths.isEmpty;
}
