// lib/features/media_tools/services/media_command_builder.dart
//
// AVTOOL-002 (PLAN-047 P1) — BỘ DỰNG LỆNH FFMPEG. HÀM THUẦN, không I/O.
//
// Vì sao trả `List<String>` chứ không phải chuỗi lệnh:
//   1. Không phải escaping tay. Bản cũ (`ffmpeg_kit_impl.dart` trước P0) ghép
//      chuỗi + `quotePath()` chỉ escape `"` ⇒ tên file có `'` (rất phổ biến:
//      "Don't stop.mp3", "Thầy's talk.mp3") làm FFmpegKit tách sai tham số.
//   2. Test được trên host VM: so từng argv thay vì so chuỗi.
//
// Các quyết định kỹ thuật đều có lý do (đừng "tối giản" lại):
//   - `-ss` TRƯỚC `-i`: seek nhanh (demuxer nhảy thẳng), đúng mốc tới ms.
//   - Luôn `-vn -sn -dn -map 0:a:0`: MP4 quay bằng điện thoại có thể có 2 track
//     audio (mic + system) ⇒ không map là FFmpeg tự chọn track đầu tiên.
//   - Luôn `-nostdin`: thiếu nó FFmpeg treo chờ stdin trong app GUI/Windows.
//   - Luôn `-hide_banner`: log gọn, dễ parse lỗi.
//   - `-map_metadata 0`: giữ title/artist ⇒ file xuất ra có tên bài.
//   - `-progress pipe:2 -nostats` (khi bật tiến trình): FFmpeg ghi
//     `out_time_us=` liên tục, tầng engine parse (desktop). Mobile dùng
//     Statistics của FFmpegKit nên KHÔNG cần 2 tham số này.

import '../models/media_export_models.dart';

/// Chuyển [Duration] → chuỗi `HH:MM:SS.mmm` cho FFmpeg.
String ffmpegTimestamp(Duration d) {
  final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final milli = ms % 1000;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}.'
      '${milli.toString().padLeft(3, '0')}';
}

class MediaCommandBuilder {
  const MediaCommandBuilder._();

  /// Tham số chung đứng trước `-i` cho mọi lệnh.
  static List<String> get _globalIn => ['-hide_banner', '-nostdin', '-y'];

  /// Bỏ mọi luồng không phải âm thanh + chọn track audio đầu tiên.
  static List<String> get _audioOnly => ['-vn', '-sn', '-dn', '-map', '0:a:0'];

  /// Lệnh chuyển đổi / tách âm thanh CẢ FILE.
  ///
  /// [useProgress] = true ⇒ thêm `-progress pipe:2 -nostats` (chỉ desktop dùng;
  /// mobile dùng Statistics nên để false cho log sạch).
  static List<String> extractAudio({
    required String inputPath,
    required String outputPath,
    required MediaExportPreset preset,
    bool useProgress = false,
  }) {
    return [
      ..._globalIn,
      '-i', inputPath,
      ..._audioOnly,
      ...preset.encodeArgs,
      '-map_metadata', '0',
      if (useProgress) ...['-progress', 'pipe:2', '-nostats'],
      outputPath,
    ];
  }

  /// Lệnh cắt một đoạn (âm thanh) — `-ss` TRƯỚC `-i`.
  ///
  /// `-c copy` chỉ dùng khi preset là copy ([MediaExportPreset.m4aCopy]);
  /// đoạn A–B để luyện phát âm nên mã hoá lại để đúng mốc tới ms.
  static List<String> trimAudio({
    required String inputPath,
    required String outputPath,
    required Duration start,
    Duration? duration,
    required MediaExportPreset preset,
    bool useProgress = false,
  }) {
    return [
      ..._globalIn,
      '-ss', ffmpegTimestamp(start),
      '-i', inputPath,
      if (duration != null) ...['-t', ffmpegTimestamp(duration)],
      ..._audioOnly,
      ...preset.encodeArgs,
      if (useProgress) ...['-progress', 'pipe:2', '-nostats'],
      outputPath,
    ];
  }

  /// Lệnh cắt một đoạn VIDEO (giữ cả hình) — chỉ Android/iOS/desktop có codec
  /// phù hợp mới chạy được; `-c copy` chỉ dùng khi preset copy.
  static List<String> trimVideo({
    required String inputPath,
    required String outputPath,
    required Duration start,
    Duration? duration,
    bool copyOnly = true,
    bool useProgress = false,
  }) {
    return [
      ..._globalIn,
      '-ss', ffmpegTimestamp(start),
      '-i', inputPath,
      if (duration != null) ...['-t', ffmpegTimestamp(duration)],
      if (copyOnly) ...['-c', 'copy'] else ...['-c:v', 'libx264', '-c:a', 'aac'],
      if (useProgress) ...['-progress', 'pipe:2', '-nostats'],
      outputPath,
    ];
  }

  /// Lệnh TÁCH thành nhiều phần theo thời lượng cố định (segment muxer).
  ///
  /// `-reset_timestamps 1` BẮT BUỘC: thiếu nó, mỗi phần mang mốc thời gian
  /// tuyệt đối ⇒ player hiển thị sai và một số máy không phát được phần 2+.
  static List<String> splitByDuration({
    required String inputPath,
    required String outputPattern,
    required int segmentSeconds,
    required MediaExportPreset preset,
    bool useProgress = false,
  }) {
    final whole = segmentSeconds < 1 ? 1 : segmentSeconds;
    return [
      ..._globalIn,
      '-i', inputPath,
      ..._audioOnly,
      ...preset.encodeArgs,
      '-f', 'segment',
      '-segment_time', '$whole',
      '-reset_timestamps', '1',
      if (useProgress) ...['-progress', 'pipe:2', '-nostats'],
      outputPattern,
    ];
  }

  /// Lệnh tách theo danh sách chặng (chương) — dựng nhiều lệnh `trimAudio`,
  /// ở đây chỉ để một chỗ quyết định "chặng nào tới đâu".
  static List<List<String>> splitBySlices({
    required String inputPath,
    required List<MediaExportSlice> slices,
    required String Function(int index, MediaExportSlice slice) outputPathFor,
    required MediaExportPreset preset,
    bool useProgress = false,
  }) {
    final commands = <List<String>>[];
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      commands.add(trimAudio(
        inputPath: inputPath,
        outputPath: outputPathFor(i, slice),
        start: slice.start,
        duration: slice.duration,
        preset: preset,
        useProgress: useProgress,
      ));
    }
    return commands;
  }

  /// Lệnh NỐI nhiều file (concat demuxer) — KHÔNG mã hoá lại.
  ///
  /// Chỉ dùng khi `areConcatCompatible(...)` trả true. File danh sách
  /// ([listFile]) phải do [buildConcatList] sinh ra.
  static List<String> concatCopy({
    required String listFile,
    required String outputPath,
    bool useProgress = false,
  }) {
    return [
      ..._globalIn,
      '-f', 'concat',
      '-safe', '0',
      '-i', listFile,
      '-c', 'copy',
      if (useProgress) ...['-progress', 'pipe:2', '-nostats'],
      outputPath,
    ];
  }

  /// Lệnh NỐI có mã hoá lại — dùng khi các file khác codec/tần số/channel.
  ///
  /// Đây là chỗ tư vấn "chỉ cần `-c copy`, hoạt động hoàn hảo với cả mp3, m4a,
  /// wav" SAI: nối mp3 44.1 kHz với wav 16 kHz bằng copy cho ra file hỏng im
  /// lặng (một số player còn crash). Mã hoá lại về một chuẩn chung là an toàn.
  static List<String> concatReencode({
    required String listFile,
    required String outputPath,
    required MediaExportPreset preset,
    bool useProgress = false,
  }) {
    return [
      ..._globalIn,
      '-f', 'concat',
      '-safe', '0',
      '-i', listFile,
      ...preset.encodeArgs,
      '-ar', '44100',
      '-ac', '2',
      if (useProgress) ...['-progress', 'pipe:2', '-nostats'],
      outputPath,
    ];
  }

  /// Nội dung file danh sách cho concat demuxer.
  ///
  /// `concat` đọc từng dòng `file '<path>'`; dấu `'` bên trong đường dẫn phải
  /// viết thành `'\''` (đóng nháy, escape, mở nháy). Dùng `\` trên Windows phải
  /// đổi thành `/` vì demuxer coi `\` là ký tự escape.
  static String buildConcatList(List<String> paths) {
    final buffer = StringBuffer();
    for (final raw in paths) {
      final normalized = raw.replaceAll(r'\', '/').replaceAll("'", r"'\''");
      buffer.writeln("file '$normalized'");
    }
    return buffer.toString();
  }
}

/// Thông tin luồng cần cho việc quyết định copy hay mã hoá lại.
class MediaStreamSignature {
  const MediaStreamSignature({
    required this.codec,
    required this.sampleRate,
    required this.channels,
  });

  final String codec;
  final int sampleRate;
  final int channels;

  /// Hai file nối được bằng `-c copy` khi cùng codec + tần số + số kênh.
  ///
  /// (Chuẩn thực tế còn cần cùng profile/level của AAC và cùng bitrate với một
  /// số container, nhưng ba tiêu chí này bắt được ~99% lỗi thực tế; nếu vẫn
  /// lỗi, tầng service có fallback mã hoá lại.)
  bool isConcatCompatibleWith(MediaStreamSignature other) {
    return codec.toLowerCase() == other.codec.toLowerCase() &&
        sampleRate == other.sampleRate &&
        channels == other.channels;
  }

  @override
  String toString() => '$codec/${sampleRate}Hz/${channels}ch';
}

/// Danh sách chữ ký có nối copy được không.
bool areConcatCompatible(List<MediaStreamSignature> signatures) {
  if (signatures.length < 2) return true;
  final first = signatures.first;
  for (final sig in signatures.skip(1)) {
    if (!first.isConcatCompatibleWith(sig)) return false;
  }
  return true;
}
