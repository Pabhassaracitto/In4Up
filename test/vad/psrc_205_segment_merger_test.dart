// test/vad/psrc_205_segment_merger_test.dart
//
// PSRC-205 (audit 1.29.0-Beta, 2026-11-15) — owner báo:
//   "Ở tab Nghe, tạo lời cho file .m4a 7 phút lặp trạng thái 'Đang chuẩn bị'
//    → 'Đang nhận diện chunk 1/1' → 'Đang chuẩn bị' → … Mỗi lượt chỉ tạo thêm
//    một dòng, quá trình rất lâu, kết quả lắt nhắt và các dòng THIẾU ĐẦU CÂU.
//    Bấm Hủy không dừng được. Thử .mp3 17 phút cũng vậy."
//
// Ba lớp lỗi và máy bắt tương ứng:
//   (1) BĂM NÁT CÂU: VAD cắt ở 100 ms khoảng lặng (giữa hai từ) ⇒ mỗi mảnh là
//       một lượt transcribe. Khoá bằng `mergeSpeechSegments` (gộp cụm + chia
//       đều ≤ 14 s) và bằng hằng số mặc định của `SherpaVadService`.
//   (2) CẮT CỤT BIÊN: `speechPadMs` 30 ms không cứu được phụ âm đầu ⇒
//       "thiếu đầu câu". Khoá bằng hằng số + quét nguồn (phải pad ở cả đường
//       sherpa, không chỉ đường fallback).
//   (3) HỦY KHÔNG TÁC DỤNG: chỉ hủy facade trong khi pipeline VAD tự lặp và
//       mỗi lượt lại reset cờ hủy ⇒ job chạy hết file. Khoá bằng quét nguồn.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/vad/models/speech_segment.dart';
import 'package:in4up/features/vad/services/sherpa_vad_service.dart';
import 'package:in4up/features/vad/services/speech_segment_merger.dart';

List<SpeechSegment> pieces(
  List<List<double>> spans, {
  double confidence = 0.95,
}) =>
    spans
        .map((s) => SpeechSegment(
              startTime: s[0],
              endTime: s[1],
              confidence: confidence,
            ))
        .toList();

void main() {
  group('PSRC-205 — gộp mảnh VAD thành câu trước khi transcribe', () {
    test('mảnh vụn trong CÙNG một câu được gộp thành MỘT đoạn', () {
      // Một câu 6 s bị VAD băm thành 6 mảnh, mỗi chỗ ngắt 0,1-0,3 s.
      final fragments = pieces(<List<double>>[
        [0.0, 1.0],
        [1.2, 2.1],
        [2.3, 3.4],
        [3.6, 4.4],
        [4.6, 5.2],
        [5.4, 6.0],
      ]);
      final merged = mergeSpeechSegments(fragments);
      expect(merged, hasLength(1),
          reason: 'Ngắt 0,1-0,3 s là ngắt GIỮA TỪ — tách ở đây chính là '
              'nguyên nhân "mỗi lượt thêm một dòng, thiếu đầu câu".');
      expect(merged.single.startTime, 0.0);
      expect(merged.single.endTime, 6.0);
    });

    test('khoảng lặng THẬT (>= 0,45 s) vẫn tách thành hai đoạn', () {
      final merged = mergeSpeechSegments(pieces(<List<double>>[
        [0.0, 3.0],
        [4.5, 7.0],
      ]));
      expect(merged, hasLength(2));
      expect(merged[0].endTime, 3.0);
      expect(merged[1].startTime, 4.5);
    });

    test('đoạn chồng lấn (gap âm) được gộp, không nhân đôi thời gian', () {
      // EnergyVadFallback cắt cửa sổ 14 s chồng nhau 0,1 s.
      final merged = mergeSpeechSegments(pieces(<List<double>>[
        [0.0, 14.3],
        [14.2, 28.5],
      ]));
      expect(merged.first.startTime, 0.0);
      expect(merged.last.endTime, 28.5);
      for (final segment in merged) {
        expect(segment.duration, lessThanOrEqualTo(kVadMaxMergedSegmentSeconds));
        expect(segment.duration, greaterThan(1.0),
            reason: 'Không được sinh mẩu đuôi vài phần trăm giây (chỉ đủ một '
                'phụ âm) — đó là kiểu "kết quả lắt nhắt".');
      }
    });

    test('cụm dài bị chia BẰNG NHAU, mỗi mảnh <= 14 s, phủ kín 0..40 s', () {
      final merged = mergeSpeechSegments(pieces(<List<double>>[[0.0, 40.0]]));
      expect(merged.length, 3);
      for (final segment in merged) {
        expect(segment.duration, lessThanOrEqualTo(kVadMaxMergedSegmentSeconds));
      }
      expect(merged.first.startTime, 0.0);
      expect(merged.last.endTime, 40.0);
      // Liền mạch: không có lỗ hổng giữa các mảnh.
      for (var i = 1; i < merged.length; i++) {
        expect(merged[i].startTime, closeTo(merged[i - 1].endTime, 0.0001));
      }
      expect(merged.every((s) => s.duration > 1.0), isTrue);
    });

    test('bỏ đoạn không phải speech và tự sắp xếp theo thời gian', () {
      final merged = mergeSpeechSegments(<SpeechSegment>[
        const SpeechSegment(startTime: 8.0, endTime: 9.0),
        const SpeechSegment(startTime: 1.0, endTime: 2.0),
        const SpeechSegment(startTime: 3.0, endTime: 4.0, isSpeech: false),
        const SpeechSegment(startTime: 20.0, endTime: 20.0),
      ]);
      expect(merged, hasLength(2));
      expect(merged[0].startTime, 1.0);
      expect(merged[1].startTime, 8.0);
    });

    test('confidence của mảnh = giá trị nhỏ nhất trong cụm', () {
      final merged = mergeSpeechSegments(pieces(<List<double>>[[0.0, 2.0]]));
      expect(merged.single.confidence, 0.95);
      final mixed = mergeSpeechSegments(<SpeechSegment>[
        const SpeechSegment(startTime: 0.0, endTime: 1.0, confidence: 0.9),
        const SpeechSegment(startTime: 1.1, endTime: 2.0, confidence: 0.4),
      ]);
      expect(mixed.single.confidence, 0.4);
    });

    test('danh sách rỗng trả về rỗng (không ném)', () {
      expect(mergeSpeechSegments(const <SpeechSegment>[]), isEmpty);
    });
  });

  group('PSRC-205 — mặc định của bộ cắt VAD', () {
    test('khoảng lặng tối thiểu không còn 100 ms (ngắt giữa từ)', () {
      expect(SherpaVadService.defaultMinSilenceDurationMs, greaterThanOrEqualTo(400),
          reason: '100 ms là ngắt giữa hai TỪ; cắt ở đó làm mỗi dòng chỉ còn '
              'một mảnh giữa câu.');
      expect(SherpaVadService.singleton().minSilenceDurationMs,
          SherpaVadService.defaultMinSilenceDurationMs);
    });

    test('pad biên đủ để không cụt phụ âm đầu', () {
      expect(SherpaVadService.defaultSpeechPadMs, greaterThanOrEqualTo(200),
          reason: '30 ms là quá nhỏ — tiếng Việt mở đầu bằng phụ âm, cắt sát '
              'biên là mất chữ đầu.');
      expect(SherpaVadService.singleton().speechPadMs,
          SherpaVadService.defaultSpeechPadMs);
    });

    test('chặn trên 14 s vẫn giữ (hợp đồng RAM của handover)', () {
      expect(SherpaVadService.defaultMaxSpeechDurationS,
          kVadMaxMergedSegmentSeconds);
      expect(SherpaVadService.singleton().maxSpeechDurationS, 14);
    });

    test('đường sherpa CÓ pad biên (không chỉ đường fallback)', () {
      final source =
          File('lib/features/vad/services/sherpa_vad_service.dart').readAsStringSync();
      expect(source.contains('final padSeconds = speechPadMs / 1000.0;'), isTrue,
          reason: 'Silero trả biên năng lượng; không pad thì mất âm tiết đầu.');
      expect(source.contains('paddedSegments'), isTrue);
    });
  });

  group('PSRC-205 — pipeline & hủy', () {
    String readSource(String path) => File(path).readAsStringSync();

    test('pipeline gộp đoạn TRƯỚC khi vào vòng transcribe', () {
      final source =
          readSource('lib/features/vad/pipeline/vad_whisper_pipeline.dart');
      final merge = source.indexOf('mergeSpeechSegments(');
      final loop = source.indexOf('for (var i = 0; i < chunksToTranscribe.length; i++)');
      expect(merge, isNonNegative,
          reason: 'Thiếu bước gộp là quay lại đúng lỗi PSRC-205.');
      expect(loop, greaterThan(merge));
      expect(source.contains('chunksToTranscribe[i]'), isTrue);
    });

    test('mỗi lượt transcribe có nhãn "Đoạn i/N" cho UI', () {
      final pipeline =
          readSource('lib/features/vad/pipeline/vad_whisper_pipeline.dart');
      expect(pipeline.contains("progressContext = 'Đoạn \${i + 1}/\$totalChunks · '"),
          isTrue,
          reason: 'Không có nhãn thì UI lặp "Đang chuẩn bị…/chunk 1/1" vô nghĩa.');
      final facade = File('packages/in4up_stt/lib/stt_service_facade.dart')
          .readAsStringSync();
      expect(facade.contains('set progressContext(String? value)'), isTrue);
      expect(facade.contains("'\$context\$message'"), isTrue);
    });

    test('Hủy phải hủy CẢ pipeline VAD, không chỉ facade', () {
      final source = readSource('lib/providers/player/player_stt_mixin.dart');
      final cancelBody = source.substring(
        source.indexOf('Future<void> cancelLrcGeneration() async {'),
      );
      final bodyEnd = cancelBody.indexOf('Future<String> transcribeForShadowing');
      final body = cancelBody.substring(0, bodyEnd);
      expect(body.contains('_sttService.cancelTranscription()'), isTrue);
      expect(body.contains('_vadIntegration.cancel()'), isTrue,
          reason: 'Pipeline tự lặp qua từng đoạn và mỗi lượt transcribeFile lại '
              'reset cờ hủy của facade ⇒ chỉ hủy facade thì job chạy hết file '
              '(đúng báo cáo "Bấm Hủy không dừng được").');
    });
  });
}
