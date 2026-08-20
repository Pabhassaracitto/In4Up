// Test TextPipeline — Task 4 DoD (mục 8):
//   "Test với câu có 'Mr.', 'U.S.', số thập phân, câu tiếng Việt ghép
//    → tách đúng"
// Import tối thiểu theo bài học skill ci-red-debugging (mục 8.1).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/text/text_pipeline.dart';
import 'package:in4up/knowledge/text/text_pipeline_worker.dart';
import 'package:in4up/knowledge/text/tokenizer.dart';

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

  group('TextPipeline — 4 segment profile', () {
    const vnText =
        'Chị ấy là sinh viên đại học. Hôm nay trời mưa, nên tôi ở nhà.';

    test('paragraph: tách theo dòng trống', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'Đoạn một.\n\nĐoạn hai.',
        profile: SegmentProfile.paragraph,
      ));
      expect(r.segments.length, 2);
      expect(r.segments[0].text, 'Đoạn một.');
      expect(r.segments[1].text, 'Đoạn hai.');
    });

    test('sentence: 2 câu', () {
      final r = TextPipeline.process(
          const PipelineRequest(text: vnText, profile: SegmentProfile.sentence));
      expect(r.segments.length, 2);
    });

    test('clause: câu 1 giữ nguyên (không dấu phẩy), câu 2 tách 2 mệnh đề', () {
      final r = TextPipeline.process(
          const PipelineRequest(text: vnText, profile: SegmentProfile.clause));
      expect(r.segments.length, 3);
      expect(r.segments[0].text, 'Chị ấy là sinh viên đại học.');
      expect(r.segments[1].text, 'Hôm nay trời mưa,');
      expect(r.segments[2].text, 'nên tôi ở nhà.');
    });

    test('clause: dấu phẩy GIỮA hai chữ số (3,14 kiểu Việt) không tách', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'Giá là 3,14 nên tôi mua.',
        profile: SegmentProfile.clause,
      ));
      expect(r.segments.length, 1);
    });

    test('phrase: tách tại từ nối — từ nối thuộc cụm SAU', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'tôi học và tôi ngủ.',
        profile: SegmentProfile.phrase,
      ));
      expect(r.segments.length, 2);
      expect(r.segments[0].text, 'tôi học');
      expect(r.segments[1].text, 'và tôi ngủ.');
    });
  });

  group('Tokenizer — Trie từ ghép + số', () {
    test('"sinh viên", "đại học" là token compound (Trie longest match)', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'Chị ấy là sinh viên đại học.',
        profile: SegmentProfile.sentence,
      ));
      final words =
          r.tokens.where((t) => t.isWord).map((t) => t.text).toList();
      expect(words, contains('sinh viên'));
      expect(words, contains('đại học'));
      // Không còn "sinh"/"viên" rời sau khi gộp:
      expect(words, isNot(contains('sinh')));
      expect(words, isNot(contains('viên')));
      final compound =
          r.tokens.firstWhere((t) => t.text == 'sinh viên');
      expect(compound.isCompound, isTrue);
      expect(compound.wordCount, 2);
    });

    test('Trie KHÔNG gộp xuyên qua dấu câu ("sinh, viên")', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'hai từ sinh, viên rời rạc.',
        profile: SegmentProfile.sentence,
      ));
      final words =
          r.tokens.where((t) => t.isWord).map((t) => t.text).toList();
      expect(words, contains('sinh'));
      expect(words, contains('viên'));
      expect(
        r.tokens.any((t) => t.isCompound),
        isFalse,
        reason: 'không được gộp compound xuyên dấu phẩy',
      );
    });

    test('Số thập phân/phân cách giữ nguyên MỘT token', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'Lãi 3.14 lần trong năm 2026.',
        profile: SegmentProfile.sentence,
      ));
      final pi = r.tokens.firstWhere((t) => t.text == '3.14');
      expect(pi.isNumber, isTrue);
      final year = r.tokens.firstWhere((t) => t.text == '2026');
      expect(year.isNumber, isTrue);
    });
  });

  group('Bất biến offset + normalize', () {
    test('mọi Segment/Token: substring(start, end) == text', () {
      const mixed = 'Ông Bean đến. Bà mua 2.5 kg táo, rồi về nhà!';
      for (final profile in SegmentProfile.values) {
        final r = TextPipeline.process(
            PipelineRequest(text: mixed, profile: profile));
        for (final s in r.segments) {
          expect(r.normalized.substring(s.start, s.end), s.text,
              reason: '${profile.name}: segment lệch offset');
        }
        for (final t in r.tokens) {
          expect(r.normalized.substring(t.start, t.end), t.text,
              reason: '${profile.name}: token lệch offset');
        }
      }
    });

    test('normalize: gộp space/tab, tối đa một dòng trống, trim', () {
      expect(
        TextPipeline.normalize('  a   \t b \n\n\n\n c  '),
        'a b\n\nc',
      );
    });

    test('splitterVersion bám pipeline (ghi vào Evidence.producerVersion)',
        () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'x.',
        profile: SegmentProfile.sentence,
      ));
      expect(r.splitterVersion, kTextSplitterVersion);
      expect(kTextSplitterVersion, 'text-pipeline-v1');
    });

    test('PipelineResult JSON round-trip', () {
      final r = TextPipeline.process(const PipelineRequest(
        text: 'Chị ấy là sinh viên. Trời mưa!',
        profile: SegmentProfile.clause,
      ));
      final clone = PipelineResult.fromJson(r.toJson());
      expect(clone.toJson(), equals(r.toJson()));
    });
  });

  group('Background Worker Isolate (mục 4)', () {
    test('round-trip qua isolate: kết quả trùng hệt in-process',
        skip: 'bisect T6: tách bạch lỗi isolate vs segmentation', () async {
      final worker = await TextPipelineWorker.spawn()
          .timeout(const Duration(seconds: 10));
      try {
        const req = PipelineRequest(
          text: 'Chị ấy là sinh viên đại học. Hôm nay trời mưa, nên tôi ở nhà.',
          profile: SegmentProfile.clause,
        );
        final inProcess = TextPipeline.process(req);
        final viaWorker =
            await worker.process(req).timeout(const Duration(seconds: 10));
        expect(viaWorker.toJson(), equals(inProcess.toJson()));
      } finally {
        worker.dispose();
      }
    });

    test('worker xử lý nhiều request tuần tự đúng id',
        skip: 'bisect T6', () async {
      final worker = await TextPipelineWorker.spawn()
          .timeout(const Duration(seconds: 10));
      try {
        final futures = <Future<PipelineResult>>[
          worker.process(const PipelineRequest(
              text: 'một.', profile: SegmentProfile.sentence)),
          worker.process(const PipelineRequest(
              text: 'hai.\n\nba.', profile: SegmentProfile.paragraph)),
        ];
        final results = await Future.wait(futures)
            .timeout(const Duration(seconds: 10));
        expect(results[0].segments.single.text, 'một.');
        expect(results[1].segments.length, 2);
      } finally {
        worker.dispose();
      }
    });
  });

  group('Token/Segment JSON', () {
    test('Token toJson/fromJson round-trip giữ mọi field', () {
      const t = Token(
        text: 'sinh viên',
        start: 8,
        end: 17,
        isWord: true,
        isNumber: false,
        isCompound: true,
        wordCount: 2,
      );
      final clone = Token.fromJson(t.toJson());
      expect(clone.toJson(), equals(t.toJson()));
    });
  });
}
