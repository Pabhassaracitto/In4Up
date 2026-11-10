// test/media_tools/media_probe_parser_test.dart
//
// AVTOOL-002 (PLAN-047 P1) — máy bắt cho việc đọc log probe.
//
// Log mẫu lấy từ output THẬT của FFmpeg (không phải log tự nghĩ ra), vì định
// dạng dòng `Stream #0:0(und): Audio: aac (LC) (mp4a / 0x6134706D), 44100 Hz,
// stereo, fltp, 128 kb/s` là thứ quyết định "copy được không".

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/services/media_probe_parser.dart';

const _aacLog = '''
ffmpeg version 6.0 Copyright (c) 2000-2023 the FFmpeg developers
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'talk.m4a':
  Duration: 01:23:45.67, start: 0.000000, bitrate: 129 kb/s
  Stream #0:0[0x1](und): Audio: aac (LC) (mp4a / 0x6134706D), 44100 Hz, stereo, fltp, 128 kb/s
At least one output file must be specified
''';

const _videoLog = '''
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'clip.mp4':
  Duration: 00:00:30.00, start: 0.000000, bitrate: 900 kb/s
  Stream #0:0[0x1](und): Video: h264 (High), yuv420p, 1920x1080, 30 fps
  Stream #0:1[0x2](und): Audio: aac (LC) (mp4a / 0x6134706D), 48000 Hz, stereo, fltp, 128 kb/s
''';

const _mono16kLog = '''
Input #0, wav, from 'voice.wav':
  Duration: 00:00:05.00, start: 0.000000, bitrate: 256 kb/s
  Stream #0:0: Audio: pcm_s16le ([1][0][0][0] / 0x0001), 16000 Hz, mono, s16, 256 kb/s
''';

const _noAudioLog = '''
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'silent.mp4':
  Duration: 00:00:10.00, start: 0.000000, bitrate: 500 kb/s
  Stream #0:0[0x1](und): Video: h264 (High), yuv420p, 1280x720, 25 fps
''';

void main() {
  group('parse', () {
    test('đọc duration + bitrate + codec m4a', () {
      final info = MediaProbeParser.parse(_aacLog);
      expect(info.durationMs, ((1 * 3600) + (23 * 60) + 45) * 1000 + 670);
      expect(info.bitrateKbps, 129);
      expect(info.hasAudio, isTrue);
      expect(info.signature?.codec, 'aac');
      expect(info.signature?.sampleRate, 44100);
      expect(info.signature?.channels, 2);
      expect(info.hasVideo, isFalse);
    });

    test('video có cả hình lẫn tiếng: nhận đúng luồng audio đầu tiên', () {
      final info = MediaProbeParser.parse(_videoLog);
      expect(info.hasVideo, isTrue);
      expect(info.audioStreamCount, 1);
      expect(info.signature?.codec, 'aac');
      expect(info.signature?.sampleRate, 48000);
    });

    test('wav 16 kHz mono đọc đúng kênh + tần số', () {
      final info = MediaProbeParser.parse(_mono16kLog);
      expect(info.signature?.codec, 'pcm_s16le');
      expect(info.signature?.sampleRate, 16000);
      expect(info.signature?.channels, 1);
    });

    test('video câm: hasAudio false (để UI báo lỗi thay vì chạy câm)', () {
      final info = MediaProbeParser.parse(_noAudioLog);
      expect(info.hasAudio, isFalse);
      expect(info.audioStreamCount, 0);
    });

    test('log rỗng không ném lỗi', () {
      final info = MediaProbeParser.parse('');
      expect(info.durationMs, isNull);
      expect(info.hasAudio, isFalse);
      // PSRC-177: "không đọc được" KHÁC "không có tiếng".
      expect(info.streamsKnown, isFalse);
      expect(info.definitelySilent, isFalse);
    });

    test('PSRC-177: log không có dòng Stream ⇒ không kết luận được', () {
      final info = MediaProbeParser.parse(
        'Input #0, mp3, from \'in.mp3\':\n'
        '  Duration: 00:01:00.00, bitrate: 192 kb/s\n',
      );
      expect(info.durationMs, 60000);
      expect(info.streamsKnown, isFalse);
      expect(info.definitelySilent, isFalse,
          reason: 'thiếu bằng chứng KHÔNG phải bằng chứng không có');
    });
  });

  group('adjustPreset', () {
    test('copy AAC → m4a được phép', () {
      expect(
        MediaProbeParser.adjustPreset(
          info: MediaProbeParser.parse(_aacLog),
          wantsCopy: true,
          outputExtension: 'm4a',
        ),
        isNull,
      );
    });

    test('copy AAC → mp3 phải mã hoá lại', () {
      final adjustment = MediaProbeParser.adjustPreset(
        info: MediaProbeParser.parse(_aacLog),
        wantsCopy: true,
        outputExtension: 'mp3',
      );
      expect(adjustment, isNotNull);
      expect(adjustment!.blocked, isFalse);
      expect(
        adjustment.reason,
        MediaPresetAdjustmentReason.containerMismatch,
      );
    });

    test('không có audio ⇒ CHẶN (không có gì để xuất)', () {
      final adjustment = MediaProbeParser.adjustPreset(
        info: MediaProbeParser.parse(_noAudioLog),
        wantsCopy: false,
        outputExtension: 'mp3',
      );
      expect(adjustment, isNotNull);
      expect(adjustment!.blocked, isTrue);
      expect(adjustment.reason, MediaPresetAdjustmentReason.noAudioTrack);
    });

    test('PSRC-177: probe RỖNG không được chặn (không đọc được ≠ không có)',
        () {
      for (final ext in ['mp3', 'm4a', 'wav', 'opus']) {
        expect(
          MediaProbeParser.adjustPreset(
            info: MediaProbeParser.parse(''),
            wantsCopy: false,
            outputExtension: ext,
          ),
          isNull,
          reason: 'mã hoá lại $ext không cần biết codec nguồn',
        );
      }
    });

    test('PSRC-177: probe rỗng + copy ⇒ hạ xuống mã hoá lại (không chặn)', () {
      final adjustment = MediaProbeParser.adjustPreset(
        info: MediaProbeParser.parse(''),
        wantsCopy: true,
        outputExtension: 'm4a',
      );
      expect(adjustment, isNotNull);
      expect(adjustment!.blocked, isFalse);
      expect(adjustment.reason, MediaPresetAdjustmentReason.probeUnavailable);
      expect(adjustment.technicalMessage, contains('re-encoded'));
    });

    test('mp3 → wav bằng copy phải mã hoá lại', () {
      final info = MediaProbeParser.parse(
        "Input #0, mp3:\n  Duration: 00:01:00.00, bitrate: 192 kb/s\n"
        '  Stream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s\n',
      );
      final adjustment = MediaProbeParser.adjustPreset(
        info: info,
        wantsCopy: true,
        outputExtension: 'wav',
      );
      expect(adjustment?.blocked, isFalse);
    });
  });
}
