// packages/in4up_stt/test/stt_remote_response_parser_test.dart
//
// WP2 (API-003) mục 5 — parse response OpenAI-compatible verbose_json →
// SttSegment, offset đúng theo chunk, KHÔNG fake word-level timestamps
// (nguyên tắc MeetilyAdapter).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/models/content_id.dart';
import 'package:in4up_stt/stt_remote_response_parser.dart';

void main() {
  group('SttRemoteResponseParser.parseSegments', () {
    test('verbose_json đầy đủ: dịch timestamp theo offsetMs của chunk', () {
      final json = {
        'text': 'xin chào các bạn',
        'segments': [
          {
            'start': 0.0,
            'end': 2.5,
            'text': 'xin chào',
            'avg_logprob': -0.1,
          },
          {
            'start': 2.5,
            'end': 5.0,
            'text': 'các bạn',
            'avg_logprob': -0.2,
          },
        ],
      };

      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 720000, // chunk thứ 2, bắt đầu ở phút 12
        audioFingerprint: 'fp-abc',
      );

      expect(segments, hasLength(2));
      expect(segments[0].text, 'xin chào');
      expect(segments[0].startSeconds, 720.0);
      expect(segments[0].endSeconds, 722.5);
      expect(segments[1].text, 'các bạn');
      expect(segments[1].startSeconds, 722.5);
      expect(segments[1].endSeconds, 725.0);
      // id liên tục bắt đầu từ idOffset mặc định (0).
      expect(segments[0].id, 0);
      expect(segments[1].id, 1);
    });

    test('idOffset khác 0 (ghép nối tiếp các chunk) → id tiếp tục tăng dần',
        () {
      final json = {
        'segments': [
          {'start': 0.0, 'end': 1.0, 'text': 'một'},
          {'start': 1.0, 'end': 2.0, 'text': 'hai'},
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 0,
        audioFingerprint: 'fp',
        idOffset: 7,
      );
      expect(segments[0].id, 7);
      expect(segments[1].id, 8);
    });

    test('KHÔNG fake word-level timestamps: words luôn rỗng dù input có gì',
        () {
      final json = {
        'segments': [
          {
            'start': 0.0,
            'end': 1.0,
            'text': 'hello',
            'words': [
              {'word': 'hello', 'start': 0.0, 'end': 1.0}
            ],
          },
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 0,
        audioFingerprint: 'fp',
      );
      expect(segments, hasLength(1));
      expect(segments.first.words, isEmpty);
    });

    test('avg_logprob → confidence quy đổi và clamp đúng [0,1] (double, '
        'không phải num)', () {
      final json = {
        'segments': [
          {'start': 0.0, 'end': 1.0, 'text': 'a', 'avg_logprob': -0.05},
          {'start': 1.0, 'end': 2.0, 'text': 'b', 'avg_logprob': -5.0},
          {'start': 2.0, 'end': 3.0, 'text': 'c', 'avg_logprob': 5.0},
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 0,
        audioFingerprint: 'fp',
      );
      expect(segments[0].avgConfidence, closeTo(0.95, 1e-9));
      expect(segments[1].avgConfidence, 0.0); // clamp dưới
      expect(segments[2].avgConfidence, 1.0); // clamp trên
      for (final s in segments) {
        // Đảm bảo kiểu double thật (nếu lỡ là num, phép gán vẫn có thể
        // biên dịch được ở đây do Dart infer, nhưng field avgConfidence
        // trên SttSegment là double tường minh — so sánh runtimeType để
        // chắc chắn không có giá trị num "trốn" qua được).
        expect(s.avgConfidence, isA<double>());
      }
    });

    test('avg_logprob vắng mặt → confidence mặc định 1.0', () {
      final json = {
        'segments': [
          {'start': 0.0, 'end': 1.0, 'text': 'no logprob here'},
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 0,
        audioFingerprint: 'fp',
      );
      expect(segments.single.avgConfidence, 1.0);
    });

    test('segment text rỗng/blank bị loại bỏ (không tạo dòng LRC trống)', () {
      final json = {
        'segments': [
          {'start': 0.0, 'end': 1.0, 'text': '   '},
          {'start': 1.0, 'end': 2.0, 'text': 'nội dung thật'},
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 0,
        audioFingerprint: 'fp',
      );
      expect(segments, hasLength(1));
      expect(segments.single.text, 'nội dung thật');
    });

    test('phần tử segments không phải Map bị bỏ qua an toàn (không crash)',
        () {
      final json = {
        'segments': [
          'not-a-map',
          42,
          {'start': 0.0, 'end': 1.0, 'text': 'hợp lệ'},
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 0,
        audioFingerprint: 'fp',
      );
      expect(segments, hasLength(1));
      expect(segments.single.text, 'hợp lệ');
    });

    test('không có field segments (hoặc rỗng) nhưng có text phẳng → fallback '
        '1 segment phủ hết chunk, mốc = biên chunk (không bịa thời lượng)',
        () {
      final json = {'text': '  câu trả lời phẳng  '};
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 60000,
        audioFingerprint: 'fp-x',
      );
      expect(segments, hasLength(1));
      final seg = segments.single;
      expect(seg.text, 'câu trả lời phẳng');
      expect(seg.startSeconds, 60.0);
      expect(seg.endSeconds, 60.0); // không biết thời lượng thật → 0 độ dài
      expect(seg.words, isEmpty);
      expect(seg.avgConfidence, 1.0);
    });

    test('segments là list rỗng → coi như không có, fallback theo text', () {
      final json = {'text': 'fallback text', 'segments': <dynamic>[]};
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 0,
        audioFingerprint: 'fp',
      );
      expect(segments, hasLength(1));
      expect(segments.single.text, 'fallback text');
    });

    test('không có segments lẫn text (hoặc text rỗng) → trả về rỗng, không '
        'bịa nội dung', () {
      expect(
        SttRemoteResponseParser.parseSegments(
          <String, dynamic>{},
          offsetMs: 0,
          audioFingerprint: 'fp',
        ),
        isEmpty,
      );
      expect(
        SttRemoteResponseParser.parseSegments(
          {'text': '   '},
          offsetMs: 0,
          audioFingerprint: 'fp',
        ),
        isEmpty,
      );
    });

    test('uid được tính bằng đúng ContentId.segmentUid (offset đã áp dụng, '
        'khớp cache/transcript search hiện có)', () {
      final json = {
        'segments': [
          {'start': 1.0, 'end': 2.0, 'text': 'kiểm tra uid'},
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 5000,
        audioFingerprint: 'fp-uid',
      );
      final expectedUid = ContentId.segmentUid(
        audioFingerprint: 'fp-uid',
        startMs: 6000, // 5000 (offset) + 1000 (start*1000)
        text: 'kiểm tra uid',
      );
      expect(segments.single.uid, expectedUid);
    });

    test('start/end thiếu → mặc định 0, end = start (không âm thời lượng)',
        () {
      final json = {
        'segments': [
          {'text': 'thiếu mốc thời gian'},
        ],
      };
      final segments = SttRemoteResponseParser.parseSegments(
        json,
        offsetMs: 3000,
        audioFingerprint: 'fp',
      );
      final seg = segments.single;
      expect(seg.startSeconds, 3.0);
      expect(seg.endSeconds, 3.0);
    });
  });
}
