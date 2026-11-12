// test/media_tools/whisper_chunk_guard_test.dart
//
// PSRC-198 (audit v1.27.0) — MÁY BẮT cho lỗi "Tạo lời" chạy gần xong mới báo
//   `Failed to create LRC — Exception: failed to process audio`.
//
// Gốc (tái hiện trên Linux bằng chính mã native của whisper_flutter_new 1.0.1
// + ffmpeg thật, xem card PSRC-198):
//   • ffmpeg cắt chunk ĐUÔI nằm tại/sau điểm hết file ⇒ WAV 78 byte chỉ có
//     header (0 mẫu). Mảng `_ffmpegEmptyChunk` bên dưới là NGUYÊN VĂN file đó.
//   • chốt cũ `size < 44` cho nó lọt xuống native; với ngôn ngữ `auto`
//     whisper.cpp từ chối đầu vào < 160 mẫu ⇒ "failed to process audio";
//   • vòng lặp chunk không có `catch` ⇒ cả job hỏng ở chunk cuối.
//
// Plugin native không chạy được trên host VM nên test gồm hai lớp:
//   (1) hành vi của các hàm THUẦN trong `whisper_chunk_guard.dart`;
//   (2) quét NGUỒN `stt_engine_whisper.dart` (đã bỏ comment) để khẳng định
//       vòng lặp chunk thật sự dùng các hàm đó.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/src/whisper_chunk_guard.dart';

/// Nguyên văn 78 byte ffmpeg ghi ra cho
/// `ffmpeg -ss 120 -i a120.ogg -t 15 -ar 16000 -ac 1 -c:a pcm_s16le out.wav`
/// (file nguồn dài đúng 2:00 ⇒ không còn mẫu nào sau giây 120).
const List<int> _ffmpegEmptyChunk = <int>[
  0x52, 0x49, 0x46, 0x46, 0x46, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45, //
  0x66, 0x6d, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, //
  0x80, 0x3e, 0x00, 0x00, 0x00, 0x7d, 0x00, 0x00, 0x02, 0x00, 0x10, 0x00, //
  0x4c, 0x49, 0x53, 0x54, 0x1a, 0x00, 0x00, 0x00, 0x49, 0x4e, 0x46, 0x4f, //
  0x49, 0x53, 0x46, 0x54, 0x0d, 0x00, 0x00, 0x00, 0x4c, 0x61, 0x76, 0x66, //
  0x36, 0x33, 0x2e, 0x31, 0x2e, 0x31, 0x30, 0x32, 0x00, 0x00, 0x64, 0x61, //
  0x74, 0x61, 0x00, 0x00, 0x00, 0x00,
];

/// Dựng một file WAV PCM trong bộ nhớ.
///
/// [dataBytes] là số byte PCM THẬT nối sau header; [declaredDataBytes] là con
/// số ghi trong header (mặc định = [dataBytes]). [withListChunk] chèn chunk
/// `LIST` trước `data` đúng như ffmpeg làm.
Uint8List _wav({
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
  required int dataBytes,
  int? declaredDataBytes,
  bool withListChunk = false,
}) {
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final builder = BytesBuilder();

  void ascii(String text) => builder.add(text.codeUnits);
  void u32(int value) {
    final b = ByteData(4)..setUint32(0, value, Endian.little);
    builder.add(b.buffer.asUint8List());
  }

  void u16(int value) {
    final b = ByteData(2)..setUint16(0, value, Endian.little);
    builder.add(b.buffer.asUint8List());
  }

  final listBody = <int>[
    ...'INFOISFT'.codeUnits,
    0x0d, 0x00, 0x00, 0x00, //
    ...'Lavf63.1.102'.codeUnits,
    0x00, 0x00,
  ];
  final listSize = withListChunk ? 8 + listBody.length : 0;

  ascii('RIFF');
  u32(4 + 24 + listSize + 8 + dataBytes);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * blockAlign);
  u16(blockAlign);
  u16(bitsPerSample);
  if (withListChunk) {
    ascii('LIST');
    u32(listBody.length);
    builder.add(listBody);
  }
  ascii('data');
  u32(declaredDataBytes ?? dataBytes);
  builder.add(Uint8List(dataBytes));
  return builder.toBytes();
}

WhisperChunkVerdict _verdictOf(Uint8List file) => assessWhisperChunk(
      head: file.length > kWhisperChunkHeaderProbeBytes
          ? Uint8List.sublistView(file, 0, kWhisperChunkHeaderProbeBytes)
          : file,
      fileLength: file.length,
    );

/// Bỏ comment dòng + comment khối để quét nguồn không "pass giả".
String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  }).join('\n');
}

const _enginePath = 'packages/in4up_stt/lib/stt_engine_whisper.dart';

void main() {
  group('PSRC-198 — chunk đuôi rỗng của ffmpeg', () {
    final file = Uint8List.fromList(_ffmpegEmptyChunk);

    test('file thật của ffmpeg dài 78 byte ⇒ chốt cũ `size < 44` KHÔNG bắt được',
        () {
      expect(file.length, 78);
      expect(file.length < 44, isFalse,
          reason: 'đây chính là lý do chunk rỗng lọt xuống native');
    });

    test('header đọc ra đúng: 16 kHz mono 16-bit, 0 mẫu', () {
      final info = parseWavPcmHeader(file, fileLength: file.length);
      expect(info, isNotNull);
      expect(info!.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.blockAlign, 2);
      expect(info.dataOffset, 78);
      expect(info.declaredDataBytes, 0);
      expect(info.availableDataBytes, 0);
      expect(info.frames, 0);
      expect(info.durationSeconds, 0);
    });

    test('phán quyết: skipEmpty — KHÔNG đưa xuống native', () {
      final verdict = _verdictOf(file);
      expect(verdict, WhisperChunkVerdict.skipEmpty);
      expect(verdict.shouldTranscribe, isFalse);
    });
  });

  group('PSRC-198 — ngưỡng số mẫu', () {
    test('biên gây lỗi của whisper.cpp (160 mẫu) nằm DƯỚI ngưỡng bỏ qua', () {
      // whisper.cpp: n_len_org = n_samples / 160; auto-detect từ chối khi
      // n_len_org == 0. Ngưỡng của app phải lớn hơn hẳn biên này.
      expect(kWhisperMinChunkFrames, greaterThan(160));
      expect(kWhisperMinChunkFrames, 1600);
    });

    test('0 / 80 / 159 / 1599 mẫu ⇒ bỏ qua; 1600 / 16000 mẫu ⇒ nhận diện', () {
      expect(_verdictOf(_wav(dataBytes: 0)), WhisperChunkVerdict.skipEmpty);
      for (final frames in [80, 159, 1599]) {
        expect(
          _verdictOf(_wav(dataBytes: frames * 2)),
          WhisperChunkVerdict.skipTooShort,
          reason: '$frames mẫu',
        );
      }
      for (final frames in [1600, 16000, 240000]) {
        expect(
          _verdictOf(_wav(dataBytes: frames * 2)),
          WhisperChunkVerdict.transcribe,
          reason: '$frames mẫu',
        );
      }
    });

    test('chunk có chunk LIST của ffmpeg + 0,4 s âm thanh ⇒ nhận diện', () {
      final file = _wav(dataBytes: 12800, withListChunk: true);
      final info = parseWavPcmHeader(file, fileLength: file.length)!;
      expect(info.dataOffset, 78);
      expect(info.frames, 6400);
      expect(info.durationSeconds, closeTo(0.4, 1e-9));
      expect(_verdictOf(file), WhisperChunkVerdict.transcribe);
    });

    test('ngưỡng quy đổi theo tần số lấy mẫu thật của chunk', () {
      // 0,1 s @48 kHz = 4800 mẫu.
      expect(
        _verdictOf(_wav(sampleRate: 48000, dataBytes: 4799 * 2)),
        WhisperChunkVerdict.skipTooShort,
      );
      expect(
        _verdictOf(_wav(sampleRate: 48000, dataBytes: 4800 * 2)),
        WhisperChunkVerdict.transcribe,
      );
    });

    test('stereo: frame = 4 byte', () {
      final file = _wav(channels: 2, dataBytes: 1600 * 4);
      final info = parseWavPcmHeader(file, fileLength: file.length)!;
      expect(info.blockAlign, 4);
      expect(info.frames, 1600);
      expect(_verdictOf(file), WhisperChunkVerdict.transcribe);
      expect(
        _verdictOf(_wav(channels: 2, dataBytes: 1599 * 4)),
        WhisperChunkVerdict.skipTooShort,
      );
    });
  });

  group('PSRC-198 — header không khớp file thật', () {
    test('header khai lớn hơn file (ffmpeg bị ngắt) ⇒ tính theo byte thật', () {
      final file = _wav(dataBytes: 200, declaredDataBytes: 32000);
      final info = parseWavPcmHeader(file, fileLength: file.length)!;
      expect(info.declaredDataBytes, 32000);
      expect(info.availableDataBytes, 200);
      expect(info.frames, 100);
      expect(_verdictOf(file), WhisperChunkVerdict.skipTooShort);
    });

    test('header khai 0xFFFFFFFF (chưa chốt) nhưng file có đủ dữ liệu', () {
      final file = _wav(dataBytes: 32000, declaredDataBytes: 0xFFFFFFFF);
      final info = parseWavPcmHeader(file, fileLength: file.length)!;
      expect(info.frames, 16000);
      expect(_verdictOf(file), WhisperChunkVerdict.transcribe);
    });

    test('header khai 0 dù file có dữ liệu ⇒ native đọc ra 0 mẫu ⇒ bỏ qua', () {
      final file = _wav(dataBytes: 32000, declaredDataBytes: 0);
      expect(parseWavPcmHeader(file, fileLength: file.length)!.frames, 0);
      expect(_verdictOf(file), WhisperChunkVerdict.skipEmpty);
    });

    test('file < 44 byte ⇒ skipCorrupt (giữ luật cũ)', () {
      expect(
        assessWhisperChunk(head: Uint8List(0), fileLength: 0),
        WhisperChunkVerdict.skipCorrupt,
      );
      expect(
        assessWhisperChunk(head: Uint8List(43), fileLength: 43),
        WhisperChunkVerdict.skipCorrupt,
      );
    });

    test('không phải RIFF/WAVE ⇒ "không biết" ⇒ để native tự báo lỗi', () {
      final junk = Uint8List.fromList(List<int>.filled(4096, 0x41));
      expect(looksLikeRiffWave(junk), isFalse);
      expect(parseWavPcmHeader(junk, fileLength: junk.length), isNull);
      expect(_verdictOf(junk), WhisperChunkVerdict.transcribe);
    });

    test('chưa thấy chunk data trong phần header đã đọc ⇒ "không biết"', () {
      final file = _wav(dataBytes: 32000, withListChunk: true);
      // Chỉ đưa 40 byte đầu: có `fmt ` nhưng chưa tới `data`.
      final head = Uint8List.sublistView(file, 0, 40);
      expect(parseWavPcmHeader(head, fileLength: file.length), isNull);
      expect(
        assessWhisperChunk(head: head, fileLength: file.length),
        WhisperChunkVerdict.transcribe,
      );
    });

    test('kích thước chunk rác không làm vòng đọc header chạy mãi', () {
      final file = _wav(dataBytes: 0, withListChunk: true);
      // Ghi đè size của chunk LIST thành 0xFFFFFFFF.
      final broken = Uint8List.fromList(file);
      broken.setRange(40, 44, const [0xFF, 0xFF, 0xFF, 0xFF]);
      expect(parseWavPcmHeader(broken, fileLength: broken.length), isNull);
    });
  });

  group('PSRC-198 — sổ lỗi theo chunk', () {
    test('chỉ có chunk bị bỏ qua ⇒ job hoàn tất, không ném', () {
      final budget = WhisperChunkFailureBudget();
      budget.recordSkipped();
      budget.recordSkipped();
      expect(budget.skipped, 2);
      expect(budget.nativeFailures, 0);
      expect(budget.throwIfNothingTranscribed, returnsNormally);
    });

    test('chunk đuôi lỗi SAU khi các chunk trước đã xong ⇒ job vẫn hoàn tất',
        () {
      final budget = WhisperChunkFailureBudget();
      for (var i = 0; i < 8; i++) {
        budget.recordTranscribed();
      }
      final mayContinue =
          budget.recordNativeFailure(Exception('failed to process audio'));
      expect(mayContinue, isTrue);
      expect(budget.transcribed, 8);
      expect(budget.nativeFailures, 1);
      expect(budget.exhausted, isFalse);
      expect(budget.throwIfNothingTranscribed, returnsNormally);
    });

    test('lỗi lặp lại quá ngưỡng ⇒ dừng job bằng lỗi ĐẦU TIÊN', () {
      final budget = WhisperChunkFailureBudget();
      final first = Exception('failed to process audio');
      budget.recordTranscribed();
      expect(budget.recordNativeFailure(first), isTrue);
      expect(budget.recordNativeFailure(Exception('second')), isTrue);
      expect(budget.recordNativeFailure(Exception('third')), isFalse);
      expect(budget.exhausted, isTrue);
      expect(budget.nativeFailures, kWhisperMaxNativeChunkFailures + 1);
      expect(budget.firstError, same(first));
      expect(budget.throwFirstError, throwsA(same(first)));
    });

    test('không chunk nào ra chữ mà có chunk lỗi ⇒ ném lại lỗi đó', () {
      final budget = WhisperChunkFailureBudget();
      final error = Exception('failed to process audio');
      budget.recordSkipped();
      expect(budget.recordNativeFailure(error), isTrue);
      expect(budget.throwIfNothingTranscribed, throwsA(same(error)));
    });

    test('ngưỡng tuỳ chỉnh = 0 ⇒ lỗi đầu tiên đã phải dừng', () {
      final budget = WhisperChunkFailureBudget(maxNativeFailures: 0);
      expect(budget.recordNativeFailure(StateError('x')), isFalse);
      expect(budget.throwFirstError, throwsStateError);
    });
  });

  group('PSRC-198 — vòng lặp chunk trong stt_engine_whisper.dart', () {
    late final String code;

    setUpAll(() {
      final file = File(_enginePath);
      expect(file.existsSync(), isTrue, reason: 'thiếu $_enginePath');
      code = _stripComments(file.readAsStringSync());
    });

    String chunkedBody() {
      final start = code.indexOf('transcribeMobileChunked(');
      expect(start, greaterThanOrEqualTo(0));
      final end = code.indexOf('_buildChunkPartial({', start);
      expect(end, greaterThan(start));
      return code.substring(start, end);
    }

    test('soi chunk bằng header WAV TRƯỚC khi gọi native', () {
      final body = chunkedBody();
      final inspect = body.indexOf('inspectChunkFile(chunkPath)');
      final native = body.indexOf('whisper.transcribe(');
      expect(inspect, greaterThanOrEqualTo(0),
          reason: 'vòng lặp phải soi chunk bằng inspectChunkFile');
      expect(native, greaterThan(inspect),
          reason: 'phải soi TRƯỚC khi đưa chunk xuống whisper.transcribe');
      expect(body.contains('chunkBytes < 44'), isFalse,
          reason: 'chốt `size < 44` cũ không bắt được WAV rỗng 78 byte');
    });

    test('lỗi của một chunk được bắt và ghi sổ, không ném thẳng ra ngoài', () {
      final body = chunkedBody();
      final native = body.indexOf('whisper.transcribe(');
      final caught = body.indexOf('recordNativeFailure(', native);
      expect(caught, greaterThan(native),
          reason: 'sau lời gọi native phải có nhánh catch ghi vào sổ lỗi');
      expect(body.contains('throwIfNothingTranscribed()'), isTrue,
          reason: 'không được trả "thành công rỗng" khi mọi chunk đều lỗi');
    });

    test('mốc thời gian chunk là hàm của chỉ số, không cộng dồn', () {
      final body = chunkedBody();
      expect(body.contains('chunkMsOffset +='), isFalse,
          reason: 'cộng dồn sẽ lệch 15 s khi một chunk lỗi không tăng mốc');
      expect(
        RegExp(r'chunkMsOffset\s*=\s*i\s*\*\s*effectiveChunkDuration\s*\*\s*1000')
            .hasMatch(body),
        isTrue,
      );
    });
  });
}
