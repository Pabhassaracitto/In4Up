import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Đọc WAV file → float32 samples [-1.0, 1.0]
/// Yêu cầu: WAV PCM 16-bit, 16kHz, Mono (đã convert bằng ffmpeg)
class WavReader {
  static Future<List<double>?> readPcmFloat32(String wavPath) async {
    try {
      final file = File(wavPath);
      if (!await file.exists()) {
        debugPrint('❌ WAV not found: $wavPath');
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.length < 44) {
        debugPrint('❌ File quá nhỏ, không phải WAV hợp lệ');
        return null;
      }

      final data = ByteData.view(bytes.buffer);

      // Validate RIFF header
      final riff = String.fromCharCodes(bytes.sublist(0, 4));
      final wave = String.fromCharCodes(bytes.sublist(8, 12));
      if (riff != 'RIFF' || wave != 'WAVE') {
        debugPrint('❌ Không phải WAV file hợp lệ');
        return null;
      }

      final sampleRate = data.getUint32(24, Endian.little);
      final bitsPerSample = data.getUint16(34, Endian.little);
      final numChannels = data.getUint16(22, Endian.little);

      debugPrint('📊 WAV info: ${sampleRate}Hz, '
          '${numChannels}ch, ${bitsPerSample}bit');

      // Tìm "data" chunk
      int offset = 12;
      int dataOffset = -1;
      int dataSize = 0;

      while (offset < bytes.length - 8) {
        final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final chunkSize = data.getUint32(offset + 4, Endian.little);

        if (chunkId == 'data') {
          dataOffset = offset + 8;
          dataSize = chunkSize;
          break;
        }
        offset += 8 + chunkSize;
        // Align to 2-byte boundary
        if (chunkSize % 2 != 0) offset++;
      }

      if (dataOffset < 0 || dataSize == 0) {
        debugPrint('❌ Không tìm thấy data chunk trong WAV');
        return null;
      }

      // Chỉ xử lý PCM 16-bit
      if (bitsPerSample != 16) {
        debugPrint('❌ Chỉ hỗ trợ 16-bit PCM, file này: ${bitsPerSample}bit');
        return null;
      }

      final nSamples = dataSize ~/ (bitsPerSample ~/ 8);
      final samples = List<double>.filled(nSamples, 0.0);

      for (int i = 0; i < nSamples; i++) {
        final byteOffset = dataOffset + i * 2;
        if (byteOffset + 1 >= bytes.length) break;
        final int16Val = data.getInt16(byteOffset, Endian.little);
        samples[i] = int16Val / 32768.0;
      }

      debugPrint('✅ WAV đọc xong: $nSamples samples '
          '(${(nSamples / sampleRate).toStringAsFixed(1)}s)');
      return samples;
    } catch (e, stack) {
      debugPrint('❌ WavReader error: $e\n$stack');
      return null;
    }
  }
}
