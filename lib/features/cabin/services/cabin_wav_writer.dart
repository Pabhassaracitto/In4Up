import 'dart:io';
import 'dart:typed_data';

/// CABIN-SAVE-001 — ghi PCM16 streaming xuống WAV trên đĩa (không giữ trong
/// RAM). Header được ghi placeholder lúc mở và vá kích thước lúc đóng; nếu
/// app bị tắt ngang, [repairHeader] vá lại theo độ dài file thật.
class CabinWavWriter {
  CabinWavWriter._(this.path, this._sink, this.sampleRate, this.channels);

  static const headerBytes = 44;
  static const bitsPerSample = 16;

  final String path;
  final int sampleRate;
  final int channels;
  IOSink? _sink;
  int _dataBytes = 0;

  int get dataBytes => _dataBytes;
  int get bytesPerSecond => sampleRate * channels * bitsPerSample ~/ 8;

  Duration get duration => durationForBytes(_dataBytes,
      sampleRate: sampleRate, channels: channels);

  static Duration durationForBytes(int dataBytes,
      {int sampleRate = 16000, int channels = 1}) {
    final bps = sampleRate * channels * bitsPerSample ~/ 8;
    if (bps <= 0) return Duration.zero;
    return Duration(microseconds: (dataBytes * 1000000) ~/ bps);
  }

  /// Mở file mới (ghi đè) hoặc nối tiếp file cũ nếu [append] (phiên khôi phục).
  static Future<CabinWavWriter> open(
    String path, {
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final sink = file.openWrite(mode: FileMode.writeOnly);
    sink.add(buildHeader(0, sampleRate: sampleRate, channels: channels));
    return CabinWavWriter._(path, sink, sampleRate, channels);
  }

  /// Nhận một chunk PCM16 LE. Đồng bộ (IOSink tự đệm) để dùng được trong
  /// `Stream.map` mà không chặn luồng đưa vào ASR.
  void add(List<int> pcm) {
    final sink = _sink;
    if (sink == null || pcm.isEmpty) return;
    sink.add(pcm);
    _dataBytes += pcm.length;
  }

  Future<void> flush() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  /// Đóng file và vá header theo số byte đã ghi.
  Future<void> close() async {
    final sink = _sink;
    _sink = null;
    if (sink == null) return;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
    await repairHeader(path, sampleRate: sampleRate, channels: channels);
  }

  /// Vá RIFF/data size theo độ dài file thật. Trả về số byte PCM (0 nếu file
  /// không hợp lệ). Bỏ byte lẻ cuối (PCM16 phải chẵn).
  static Future<int> repairHeader(
    String path, {
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    final length = await file.length();
    if (length < headerBytes) return 0;
    var dataBytes = length - headerBytes;
    if (dataBytes.isOdd) dataBytes -= 1;
    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.setPosition(0);
      await raf.writeFrom(
          buildHeader(dataBytes, sampleRate: sampleRate, channels: channels));
      if (length - headerBytes != dataBytes) {
        await raf.truncate(headerBytes + dataBytes);
      }
    } finally {
      await raf.close();
    }
    return dataBytes;
  }

  /// Header WAV PCM chuẩn 44 byte (little-endian).
  static Uint8List buildHeader(
    int dataBytes, {
    int sampleRate = 16000,
    int channels = 1,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final h = ByteData(headerBytes);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        h.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    h.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little); // PCM
    h.setUint16(22, channels, Endian.little);
    h.setUint32(24, sampleRate, Endian.little);
    h.setUint32(28, byteRate, Endian.little);
    h.setUint16(32, blockAlign, Endian.little);
    h.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    h.setUint32(40, dataBytes, Endian.little);
    return h.buffer.asUint8List();
  }
}
