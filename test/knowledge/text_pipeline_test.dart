// BISECT T7 — chỉ 4 test DoD tách câu.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/text/text_pipeline.dart';

void main() {
  group('TextPipeline — DoD Task 4: tách câu', () {
    test('"Mr." KHÔNG bị chặt nhầm thành kết thúc câu', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'Mr. Smith arrived. He left early.',
        profile: SegmentProfile.sentence,
      ));
      expect(r.segments.length, 2);
      expect(r.segments[0].text, 'Mr. Smith arrived.');
      expect(r.segments[1].text, 'He left early.');
    });

    test('"U.S." (acronym chấm) KHÔNG bị chặt nhầm', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'U.S. stocks fell. Buyers returned.',
        profile: SegmentProfile.sentence,
      ));
      expect(r.segments.length, 2);
      expect(r.segments[0].text, 'U.S. stocks fell.');
      expect(r.segments[1].text, 'Buyers returned.');
    });

    test('Số thập phân "3.14" và hàng nghìn "1.000" không vỡ câu', () {
      final r1 = TextPipeline.process(const PipelineRequest(
        text: 'Pi is about 3.14 exactly.',
        profile: SegmentProfile.sentence,
      ));
      expect(r1.segments.length, 1);

      final r2 = TextPipeline.process(const PipelineRequest(
        text: 'Có 1.000 người ở đây.',
        profile: SegmentProfile.sentence,
      ));
      expect(r2.segments.length, 1);
      expect(r2.segments[0].text, 'Có 1.000 người ở đây.');
    });

    test('Câu tiếng Việt ghép: tách đúng ranh giới câu', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'Chị ấy là sinh viên đại học. Hôm nay trời mưa, nên tôi ở nhà.',
        profile: SegmentProfile.sentence,
      ));
      expect(r.segments.length, 2);
      expect(r.segments[0].text, 'Chị ấy là sinh viên đại học.');
      expect(r.segments[1].text, 'Hôm nay trời mưa, nên tôi ở nhà.');
    });
  });
}
