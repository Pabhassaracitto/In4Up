// test/media_tools/transcript_route_policy_test.dart
//
// PSRC-205 (audit 1.28.0) — "tạo lời cho file âm thanh DÀI báo lỗi không xác
// định; một số file .m4a cũng đôi khi lỗi, nhưng không phải tất cả".
//
// Ba lớp của lỗi và máy bắt tương ứng:
//   (1) CHỌN SAI ĐƯỜNG theo dung lượng file (bitrate ≠ độ dài) ⇒ cùng một bài
//       mà .m4a chạy được còn .mp3 thì không. Khoá bằng test hàm thuần
//       `decideTranscriptRoute`.
//   (2) CHUNK CẮT HỎNG với mọi nguồn KHÔNG phải .wav: `ChunkAudioExtractor`
//       đặt tên chunk theo phần mở rộng của NGUỒN (`.m4a`, `.mp3`…) trong
//       khi `AudioConverter.cutSegment` LUÔN ghi `pcm_s16le` ⇒ FFmpeg từ chối
//       container ⇒ mọi đoạn bị bỏ. Khoá bằng test hằng số + quét nguồn.
//   (3) THẤT BẠI KHÔNG CÓ LÝ DO: `SttTranscribeOutput(success: false)` mà
//       `errorMessage == null` ⇒ màn Tạo lời hiện "Lỗi không xác định". Khoá
//       bằng test câu thông điệp + quét nguồn (không được trả success:false
//       mà thiếu lý do).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/vad/pipeline/vad_failure_reason.dart';
import 'package:in4up/features/vad/services/chunk_audio_extractor.dart';
import 'package:in4up/screens/listen_mode/services/transcript_route_policy.dart';

void main() {
  group('PSRC-205 — chọn đường chạy theo ĐỘ DÀI, không theo dung lượng', () {
    test('file ngắn đi đường chunk thường', () {
      final decision = decideTranscriptRoute(
        durationMs: 45 * 1000,
        fileSizeBytes: 900 * 1024,
        preferSherpa: false,
      );
      expect(decision.route, TranscriptRoute.inlineShort);
      expect(decision.reason, 'duration');
      expect(decision.usedSizeFallback, isFalse);
    });

    test('file dài đi VAD pipeline', () {
      final decision = decideTranscriptRoute(
        durationMs: 42 * 60 * 1000,
        fileSizeBytes: 30 * 1024 * 1024,
        preferSherpa: false,
      );
      expect(decision.route, TranscriptRoute.vadLong);
      expect(decision.durationMs, 42 * 60 * 1000);
    });

    test('cùng ĐỘ DÀI ⇒ cùng đường, bất kể .m4a hay .mp3 (bỏ phụ thuộc bitrate)', () {
      const tenMinutes = 10 * 60 * 1000;
      final asM4a = decideTranscriptRoute(
        durationMs: tenMinutes,
        fileSizeBytes: 7 * 1024 * 1024, // AAC ~96 kbps
        preferSherpa: false,
      );
      final asMp3 = decideTranscriptRoute(
        durationMs: tenMinutes,
        fileSizeBytes: 18 * 1024 * 1024, // MP3 ~256 kbps
        preferSherpa: false,
      );
      expect(asM4a.route, asMp3.route);
      expect(asM4a.route, TranscriptRoute.vadLong);
    });

    test('đúng ngưỡng 5 phút coi là dài (không có vùng mơ hồ)', () {
      expect(
        decideTranscriptRoute(
          durationMs: kTranscriptVadThresholdMs,
          fileSizeBytes: 1,
          preferSherpa: false,
        ).route,
        TranscriptRoute.vadLong,
      );
      expect(
        decideTranscriptRoute(
          durationMs: kTranscriptVadThresholdMs - 1,
          fileSizeBytes: 1,
          preferSherpa: false,
        ).route,
        TranscriptRoute.inlineShort,
      );
    });

    test('không probe được độ dài ⇒ phỏng đoán theo dung lượng, ghi rõ lý do',
        () {
      final big = decideTranscriptRoute(
        durationMs: null,
        fileSizeBytes: kTranscriptUnknownDurationProxyBytes,
        preferSherpa: false,
      );
      expect(big.route, TranscriptRoute.vadLong);
      expect(big.reason, 'unknown-duration');
      expect(big.usedSizeFallback, isTrue);

      final small = decideTranscriptRoute(
        durationMs: null,
        fileSizeBytes: 1024,
        preferSherpa: false,
      );
      expect(small.route, TranscriptRoute.inlineShort);
      expect(small.usedSizeFallback, isTrue);
    });

    test('người dùng chọn sherpa ⇒ không đi VAD/Whisper dù file dài', () {
      final decision = decideTranscriptRoute(
        durationMs: 90 * 60 * 1000,
        fileSizeBytes: 80 * 1024 * 1024,
        preferSherpa: true,
      );
      expect(decision.route, TranscriptRoute.sherpaOffline);
      expect(decision.reason, 'sherpa');
    });
  });

  group('PSRC-205 — cắt chunk phải luôn là WAV (mọi nguồn)', () {
    test('hằng số phần mở rộng chunk là .wav', () {
      expect(kVadChunkExtension, '.wav');
    });

    test('ChunkAudioExtractor KHÔNG đặt tên chunk theo phần mở rộng nguồn', () {
      final source = File(
        'lib/features/vad/services/chunk_audio_extractor.dart',
      ).readAsStringSync();
      expect(
        source.contains('p.extension(originalPath)'),
        isFalse,
        reason: 'Chunk được mã hoá pcm_s16le; đặt tên .m4a/.mp3 làm FFmpeg từ '
            'chối container ⇒ mọi đoạn bị bỏ và job "xong" với 0 dòng '
            '(PSRC-205).',
      );
      expect(source.contains('kVadChunkExtension'), isTrue);
    });
  });

  group('PSRC-205 — thất bại phải có lý do, không "Lỗi không xác định"', () {
    test('câu lỗi nêu số đoạn không cắt được', () {
      final message = vadNothingTranscribedMessage(
        totalSegments: 40,
        cutFailures: 40,
        transcribeFailures: 0,
      );
      expect(message, contains('40/40'));
      expect(message, contains('FFmpeg'));
    });

    test('câu lỗi nêu số đoạn nhận diện lỗi', () {
      final message = vadNothingTranscribedMessage(
        totalSegments: 12,
        cutFailures: 0,
        transcribeFailures: 3,
      );
      expect(message, contains('3/12'));
      expect(message.contains('cắt'), isFalse,
          reason: 'Không cắt hỏng thì không được đổ lỗi cho FFmpeg cắt');
    });

    test('VAD không tìm thấy tiếng nói ⇒ nói đúng chuyện đó', () {
      final message = vadNothingTranscribedMessage(
        totalSegments: 0,
        cutFailures: 0,
        transcribeFailures: 0,
      );
      expect(message, contains('Không tìm thấy đoạn nói'));
    });

    test('pipeline dùng câu lỗi này thay vì "completed" với 0 dòng', () {
      final pipeline = File(
        'lib/features/vad/pipeline/vad_whisper_pipeline.dart',
      ).readAsStringSync();
      expect(pipeline.contains('vadNothingTranscribedMessage'), isTrue);
      expect(pipeline.contains('VadPipelineStatus.error'), isTrue);
    });

    test('integration không trả success:false mà thiếu errorMessage', () {
      final integration = File(
        'lib/features/vad/pipeline/vad_pipeline_integration.dart',
      ).readAsStringSync();
      expect(integration.contains('SttTranscribeOutput.failure'), isTrue);
      expect(
        integration.contains('success: finalResult.segments.isNotEmpty'),
        isFalse,
        reason: 'Trả success:false không kèm lý do chính là nguồn của câu '
            '"Lỗi không xác định" ở màn Tạo lời (PSRC-205).',
      );
    });
  });
}
