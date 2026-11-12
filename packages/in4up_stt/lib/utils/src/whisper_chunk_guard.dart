// packages/in4up_stt/lib/utils/src/whisper_chunk_guard.dart
//
// PSRC-198 (audit 1.27.0) — "Tạo lời" chạy gần xong mới báo
//   `Exception: failed to process audio`.
//
// GỐC (đã tái hiện bằng chính mã native của plugin whisper_flutter_new 1.0.1
// build trên Linux + ffmpeg thật — xem card PSRC-198 trong KANBAN):
//
//   1. `AudioConverter.getChunkCount` chia file theo lưới 15 s dựa trên
//      `Duration:` mà ffmpeg IN RA. Con số đó thường dài hơn phần âm thanh
//      giải mã được vài mili-giây (Opus/OGG 2:00 ⇒ `00:02:00.01`; MP3/AAC có
//      padding…) ⇒ sinh thêm MỘT chunk cuối bắt đầu đúng tại/sau điểm hết
//      file.
//   2. `ffmpeg -ss <hết file> … out.wav` vẫn "thành công" và ghi ra file WAV
//      78 byte CHỈ CÓ HEADER (0 mẫu). Chốt cũ `size < 44` không bắt được.
//   3. Plugin gọi `whisper_full()` với 0 mẫu. Khi ngôn ngữ = `auto` (mặc định
//      của màn Tạo lời), whisper.cpp chạy nhận diện ngôn ngữ TRƯỚC và từ chối
//      `seek(0) >= n_len_org(0)` ("offset 0ms is past the end of the audio")
//      ⇒ `whisper_full` trả -3 ⇒ plugin trả
//      `{"@type":"error","message":"failed to process audio"}`.
//      Biên chính xác: < 160 mẫu (10 ms @16 kHz). Ngôn ngữ chỉ định tay thì
//      cùng chunk đó trả về rỗng, không lỗi — nên lỗi chỉ lộ ở `auto`.
//   4. `transcribeMobileChunked` không bắt lỗi theo từng chunk ⇒ MỘT chunk
//      đuôi rỗng làm hỏng cả job ở đúng bước cuối, vứt hết các chunk đã xong.
//
// File này là hàm THUẦN (chỉ `dart:typed_data`) để test được trên host VM:
//   • đọc header WAV ⇒ số mẫu THẬT của chunk;
//   • quyết định chunk nào không được đưa xuống native;
//   • sổ lỗi theo chunk: một chunk hỏng không được giết cả job, nhưng lỗi lặp
//     lại thì phải dừng (mỗi lần native báo lỗi, plugin RÒ nguyên một
//     `whisper_context` — nó `return` trước `whisper_free`).

import 'dart:typed_data';

/// Tần số lấy mẫu của chunk mà app cắt cho Whisper (`ffmpeg -ar 16000`).
const int kWhisperChunkSampleRate = 16000;

/// Chunk ngắn hơn ngưỡng này (tính theo mẫu @16 kHz) KHÔNG được đưa xuống
/// native.
///
/// 1600 mẫu = 0,1 s: gấp 10 lần biên gây lỗi của whisper.cpp (160 mẫu) và
/// không thể chứa một tiếng nói nào. Cố ý KHÔNG nâng lên 1 s (mức mà bản
/// whisper.cpp trong plugin hiện bỏ qua không nhận diện): nếu plugin sau này
/// nhận diện được đoạn dưới 1 s thì ngưỡng này vẫn đúng.
const int kWhisperMinChunkFrames = 1600;

/// Đọc bấy nhiêu byte đầu file là đủ thấy chunk `data` của WAV do ffmpeg ghi
/// (header thật dài 78 byte).
const int kWhisperChunkHeaderProbeBytes = 4096;

/// Số chunk tối đa được phép lỗi ở tầng native trong MỘT job trước khi dừng.
///
/// Không để vô hạn: mỗi lần `whisper_full` lỗi, plugin rò cả model đã nạp
/// (tiny ~75 MB, base ~142 MB, small ~466 MB).
const int kWhisperMaxNativeChunkFailures = 2;

/// Thông số PCM đọc từ header WAV (RIFF/WAVE).
class WavPcmInfo {
  const WavPcmInfo({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.blockAlign,
    required this.dataOffset,
    required this.declaredDataBytes,
    required this.availableDataBytes,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;

  /// Số byte của một frame (mọi kênh).
  final int blockAlign;

  /// Vị trí byte đầu tiên của dữ liệu PCM trong file.
  final int dataOffset;

  /// Kích thước chunk `data` GHI TRONG HEADER.
  final int declaredDataBytes;

  /// Số byte THẬT còn lại trong file sau [dataOffset].
  final int availableDataBytes;

  /// Phần dữ liệu dùng được: không tin header hơn những gì file thật có
  /// (ffmpeg bị ngắt giữa chừng để lại header 0xFFFFFFFF hoặc lớn hơn file),
  /// và cũng không tin file hơn header (header = 0 ⇒ native đọc ra 0 mẫu).
  int get usableDataBytes => declaredDataBytes < availableDataBytes
      ? declaredDataBytes
      : availableDataBytes;

  /// Số frame PCM dùng được.
  int get frames => blockAlign <= 0 ? 0 : usableDataBytes ~/ blockAlign;

  /// Thời lượng (giây) của phần dùng được.
  double get durationSeconds =>
      sampleRate <= 0 ? 0.0 : frames / sampleRate;
}

/// File có mở đầu bằng `RIFF….WAVE` không.
bool looksLikeRiffWave(Uint8List head) {
  if (head.length < 12) return false;
  return head[0] == 0x52 && // R
      head[1] == 0x49 && // I
      head[2] == 0x46 && // F
      head[3] == 0x46 && // F
      head[8] == 0x57 && // W
      head[9] == 0x41 && // A
      head[10] == 0x56 && // V
      head[11] == 0x45; // E
}

/// Đọc header WAV từ [head] (các byte ĐẦU của file dài [fileLength] byte).
///
/// Trả `null` khi không kết luận được: không phải RIFF/WAVE, thiếu chunk
/// `fmt `, hoặc chưa thấy chunk `data` trong phần đã đọc. `null` nghĩa là
/// "không biết", KHÔNG phải "rỗng".
WavPcmInfo? parseWavPcmHeader(Uint8List head, {required int fileLength}) {
  if (!looksLikeRiffWave(head)) return null;
  final view = ByteData.sublistView(head);

  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  int? blockAlign;

  var pos = 12;
  while (pos + 8 <= head.length) {
    final id = String.fromCharCodes(head, pos, pos + 4);
    final size = view.getUint32(pos + 4, Endian.little);
    final body = pos + 8;

    if (id == 'fmt ') {
      if (size < 16 || body + 16 > head.length) return null;
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      blockAlign = view.getUint16(body + 12, Endian.little);
      bitsPerSample = view.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (channels == null ||
          sampleRate == null ||
          bitsPerSample == null ||
          blockAlign == null) {
        return null;
      }
      var align = blockAlign;
      if (align <= 0) align = channels * ((bitsPerSample + 7) ~/ 8);
      return WavPcmInfo(
        channels: channels,
        sampleRate: sampleRate,
        bitsPerSample: bitsPerSample,
        blockAlign: align,
        dataOffset: body,
        declaredDataBytes: size,
        availableDataBytes: fileLength > body ? fileLength - body : 0,
      );
    }

    // Chunk RIFF được đệm cho chẵn byte.
    pos = body + size + (size & 1);
  }
  return null;
}

/// Phán quyết cho một chunk WAV trước khi đưa xuống whisper.cpp.
enum WhisperChunkVerdict {
  /// Đưa xuống native như bình thường.
  transcribe,

  /// File thiếu hoặc nhỏ hơn một header WAV tối thiểu (44 byte).
  skipCorrupt,

  /// WAV hợp lệ nhưng 0 mẫu — chunk đuôi nằm sau điểm hết file.
  skipEmpty,

  /// WAV hợp lệ nhưng ngắn hơn [kWhisperMinChunkFrames].
  skipTooShort,
}

extension WhisperChunkVerdictX on WhisperChunkVerdict {
  bool get shouldTranscribe => this == WhisperChunkVerdict.transcribe;
}

/// Quyết định có đưa chunk xuống native hay không.
///
/// [head] là các byte đầu của file (xem [kWhisperChunkHeaderProbeBytes]),
/// [fileLength] là kích thước file thật. [minFrames] tính theo 16 kHz và được
/// quy đổi theo tần số lấy mẫu thật của chunk.
///
/// Chỉ bỏ qua khi CHẮC CHẮN chunk không có gì để nhận diện. Header không đọc
/// được ⇒ vẫn [WhisperChunkVerdict.transcribe] để native tự báo lỗi cụ thể
/// (lỗi đó đi qua [WhisperChunkFailureBudget], không còn giết cả job).
WhisperChunkVerdict assessWhisperChunk({
  required Uint8List head,
  required int fileLength,
  int minFrames = kWhisperMinChunkFrames,
}) {
  if (fileLength < 44) return WhisperChunkVerdict.skipCorrupt;
  final info = parseWavPcmHeader(head, fileLength: fileLength);
  if (info == null) return WhisperChunkVerdict.transcribe;
  if (info.frames <= 0) return WhisperChunkVerdict.skipEmpty;

  var threshold = minFrames;
  if (info.sampleRate > 0 && info.sampleRate != kWhisperChunkSampleRate) {
    threshold =
        (minFrames * info.sampleRate / kWhisperChunkSampleRate).ceil();
  }
  if (info.frames < threshold) return WhisperChunkVerdict.skipTooShort;
  return WhisperChunkVerdict.transcribe;
}

/// Sổ theo dõi chunk của MỘT job transcribe (PSRC-198).
///
/// Luật:
///   • chunk bị bỏ qua ở khâu soi (rỗng/quá ngắn/không cắt được) KHÔNG phải
///     lỗi — job vẫn hoàn tất;
///   • native báo lỗi ở một chunk ⇒ bỏ qua chunk đó, chạy tiếp (đường VAD cho
///     file > 5 MB vốn đã làm vậy);
///   • quá [maxNativeFailures] chunk lỗi ⇒ dừng job bằng lỗi ĐẦU TIÊN (lỗi
///     lặp lại là lỗi hệ thống, và mỗi lần lỗi plugin rò một model);
///   • hết vòng lặp mà KHÔNG chunk nào nhận diện được trong khi có chunk lỗi
///     ⇒ ném lại lỗi đầu tiên, không trả "thành công rỗng".
class WhisperChunkFailureBudget {
  WhisperChunkFailureBudget({
    this.maxNativeFailures = kWhisperMaxNativeChunkFailures,
  });

  /// Số chunk lỗi native được phép bỏ qua.
  final int maxNativeFailures;

  int _transcribed = 0;
  int _skipped = 0;
  int _nativeFailures = 0;
  Object? _firstError;
  StackTrace? _firstStack;

  /// Số chunk đã nhận diện xong.
  int get transcribed => _transcribed;

  /// Số chunk bỏ qua ở khâu soi (không xuống native).
  int get skipped => _skipped;

  /// Số chunk native báo lỗi.
  int get nativeFailures => _nativeFailures;

  /// Lỗi native đầu tiên của job (nếu có).
  Object? get firstError => _firstError;

  /// Đã vượt số chunk lỗi cho phép ⇒ job phải dừng.
  bool get exhausted => _nativeFailures > maxNativeFailures;

  void recordTranscribed() => _transcribed++;

  void recordSkipped() => _skipped++;

  /// Ghi nhận một chunk native báo lỗi.
  ///
  /// Trả `true` nếu job ĐƯỢC chạy tiếp chunk kế; `false` nếu phải dừng (gọi
  /// [throwFirstError]).
  bool recordNativeFailure(Object error, [StackTrace? stackTrace]) {
    _nativeFailures++;
    _firstError ??= error;
    _firstStack ??= stackTrace;
    return !exhausted;
  }

  /// Ném lại lỗi native đầu tiên (giữ nguyên object + stack gốc).
  Never throwFirstError() {
    final error = _firstError ?? StateError('Whisper chunk failed');
    Error.throwWithStackTrace(error, _firstStack ?? StackTrace.current);
  }

  /// Gọi SAU vòng lặp: không chunk nào ra chữ mà có chunk lỗi ⇒ đó là lỗi
  /// thật của job, người dùng phải thấy.
  void throwIfNothingTranscribed() {
    if (_transcribed == 0 && _firstError != null) throwFirstError();
  }
}
