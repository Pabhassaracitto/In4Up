// lib/core/platform/system_tts/system_tts_pcm.dart
//
// PSRC-221 — đổi WAV (thứ các engine TTS của app trả về) thành PCM 16-bit
// mono, định dạng duy nhất service native khai với Android
// (`SynthesisCallback.start(rate, ENCODING_PCM_16BIT, 1)`).
//
// THUẦN Dart để test trên host VM.

import 'dart:typed_data';

/// PCM 16-bit little-endian, mono.
class SystemTtsPcm {
  const SystemTtsPcm({required this.sampleRate, required this.bytes});

  final int sampleRate;
  final Uint8List bytes;

  int get sampleCount => bytes.length ~/ 2;
}

/// Đọc WAV (RIFF) → PCM 16-bit mono. Trả `null` nếu không phải WAV hoặc định
/// dạng mẫu không hỗ trợ.
///
/// Hỗ trợ: PCM nguyên 16-bit (format 1) và float 32-bit (format 3), số kênh
/// bất kỳ (trộn trung bình về mono). Chunk lạ (`LIST`, `fact`…) được bỏ qua;
/// `data` khai kích thước 0 / 0xFFFFFFFF (WAV ghi theo luồng) ⇒ lấy tới hết.
SystemTtsPcm? decodeWavToPcm16Mono(Uint8List wav) {
  if (wav.length < 12) return null;
  final data = ByteData.sublistView(wav);
  if (_tag(wav, 0) != 'RIFF' || _tag(wav, 8) != 'WAVE') return null;

  int? format;
  int channels = 0;
  int sampleRate = 0;
  int bits = 0;
  var offset = 12;
  while (offset + 8 <= wav.length) {
    final id = _tag(wav, offset);
    var size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      if (body + 16 > wav.length) return null;
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
      // WAVE_FORMAT_EXTENSIBLE: định dạng thật nằm ở 2 byte đầu của SubFormat.
      if (format == 0xFFFE && size >= 40 && body + 26 <= wav.length) {
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      if (format == null || channels <= 0 || sampleRate <= 0) return null;
      final available = wav.length - body;
      if (size == 0 || size == 0xFFFFFFFF || size > available) size = available;
      return _convert(
        data,
        body,
        size,
        format: format,
        channels: channels,
        sampleRate: sampleRate,
        bits: bits,
      );
    }
    // Chunk RIFF luôn căn chẵn byte.
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes, offset, offset + 4);

SystemTtsPcm? _convert(
  ByteData data,
  int start,
  int size, {
  required int format,
  required int channels,
  required int sampleRate,
  required int bits,
}) {
  final bool isInt16 = format == 1 && bits == 16;
  final bool isFloat32 = format == 3 && bits == 32;
  if (!isInt16 && !isFloat32) return null;

  final bytesPerSample = bits ~/ 8;
  final frameSize = bytesPerSample * channels;
  final frames = size ~/ frameSize;
  final out = ByteData(frames * 2);
  for (var frame = 0; frame < frames; frame++) {
    final base = start + frame * frameSize;
    var sum = 0.0;
    for (var ch = 0; ch < channels; ch++) {
      final at = base + ch * bytesPerSample;
      sum += isInt16
          ? data.getInt16(at, Endian.little).toDouble()
          : data.getFloat32(at, Endian.little) * 32767.0;
    }
    final mixed = sum / channels;
    final int value =
        mixed.isFinite ? mixed.round().clamp(-32768, 32767).toInt() : 0;
    out.setInt16(frame * 2, value, Endian.little);
  }
  return SystemTtsPcm(
    sampleRate: sampleRate,
    bytes: out.buffer.asUint8List(),
  );
}
