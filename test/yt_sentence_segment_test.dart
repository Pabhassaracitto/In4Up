// YT-AUDIT-11 (IN4-106) — Chia phụ đề thành CÂU HOÀN CHỈNH.
//
// Triệu chứng owner báo (2026-10-20):
//   "Âm thanh và chữ … chưa tối ưu: xuống dòng vô tội vạ, không chia câu rõ
//    ràng. Muốn: phân câu hoàn chỉnh, dấu đầy đủ, viết hoa đầu câu."
//
// Test thuần — không cần thiết bị / mạng / WebView.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_video.dart';
import 'package:in4up/features/youtube/services/yt_sentence_segmenter.dart';

YtCaptionLine cue(int startMs, int endMs, String text, {String? translation}) =>
    YtCaptionLine(
      Duration(milliseconds: startMs),
      Duration(milliseconds: endMs),
      text,
      translation: translation,
    );

void main() {
  group('normalizeWhitespace — dọn khoảng trắng', () {
    test('xuống dòng vô tội vạ ⇒ đúng 1 dấu cách', () {
      expect(YtSentenceSegmenter.normalizeWhitespace('hello\nworld'),
          'hello world');
      expect(YtSentenceSegmenter.normalizeWhitespace('a\r\n  b \t c'), 'a b c');
      expect(YtSentenceSegmenter.normalizeWhitespace('   x   '), 'x');
      expect(YtSentenceSegmenter.normalizeWhitespace(''), '');
    });
  });

  group('endsSentence — nhận dấu kết thúc câu', () {
    test('chấm / hỏi / cảm / lửng ⇒ true', () {
      expect(YtSentenceSegmenter.endsSentence('Hello world.'), isTrue);
      expect(YtSentenceSegmenter.endsSentence('What?'), isTrue);
      expect(YtSentenceSegmenter.endsSentence('Wow!'), isTrue);
      expect(YtSentenceSegmenter.endsSentence('Hmm…'), isTrue);
    });

    test('chưa có dấu ⇒ false', () {
      expect(YtSentenceSegmenter.endsSentence('Hello world'), isFalse);
      expect(YtSentenceSegmenter.endsSentence(''), isFalse);
    });

    test('ngoặc kép sau dấu chấm vẫn tính (vd: He said "hi.")', () {
      expect(YtSentenceSegmenter.endsSentence('He said "hi."'), isTrue);
    });
  });

  group('looksLikeAbbreviation — không cắt nhầm viết tắt', () {
    test('viết tắt / số thập phân / tên viết tắt ⇒ true', () {
      expect(YtSentenceSegmenter.looksLikeAbbreviation('Dr.'), isTrue);
      expect(YtSentenceSegmenter.looksLikeAbbreviation('etc.'), isTrue);
      expect(YtSentenceSegmenter.looksLikeAbbreviation('U.S.'), isTrue);
      expect(YtSentenceSegmenter.looksLikeAbbreviation('e.g.'), isTrue);
      expect(YtSentenceSegmenter.looksLikeAbbreviation('J.'), isTrue);
      expect(YtSentenceSegmenter.looksLikeAbbreviation('3.5'), isTrue);
    });

    test('từ thường kết thúc bằng dấu chấm ⇒ false', () {
      expect(YtSentenceSegmenter.looksLikeAbbreviation('world.'), isFalse);
      expect(YtSentenceSegmenter.looksLikeAbbreviation('Hello world.'), isFalse);
      expect(YtSentenceSegmenter.looksLikeAbbreviation('Yes.'), isFalse);
    });
  });

  group('ensureSentenceEnding — dấu đầy đủ', () {
    test('thiếu dấu ⇒ chấm thêm', () {
      expect(YtSentenceSegmenter.ensureSentenceEnding('Hello world'),
          'Hello world.');
    });

    test('đã có dấu ⇒ giữ nguyên (không chấm chồng)', () {
      expect(YtSentenceSegmenter.ensureSentenceEnding('Hello world.'),
          'Hello world.');
      expect(YtSentenceSegmenter.ensureSentenceEnding('What?'), 'What?');
    });

    test('dấu phẩy ở cuối ⇒ thay bằng chấm, không thành ",.', () {
      expect(YtSentenceSegmenter.ensureSentenceEnding('Hello world,'),
          'Hello world.');
    });
  });

  group('capitalizeFirst — viết hoa đầu câu', () {
    test('chữ cái đầu thường ⇒ hoa', () {
      expect(YtSentenceSegmenter.capitalizeFirst('hello world'),
          'Hello world');
    });

    test('bỏ qua ngoặc kép ở đầu', () {
      expect(YtSentenceSegmenter.capitalizeFirst('"hello"'), '"Hello"');
    });

    test('bắt đầu bằng số ⇒ giữ nguyên (không hóa chữ sau)', () {
      expect(YtSentenceSegmenter.capitalizeFirst('3 ways to'), '3 ways to');
    });

    test('rỗng ⇒ rỗng', () {
      expect(YtSentenceSegmenter.capitalizeFirst(''), '');
    });
  });

  group('tidy — chuẩn hoá đầy đủ', () {
    test('1 dấu cách + viết hoa + dấu chấm', () {
      expect(YtSentenceSegmenter.tidy('  hello   world  '), 'Hello world.');
      expect(YtSentenceSegmenter.tidy('what?'), 'What?');
    });
  });

  group('isCumulativeTrack — nhận track rolling window', () {
    test('cue sau chứa trọn cue trước ⇒ true', () {
      expect(
        YtSentenceSegmenter.isCumulativeTrack([
          cue(0, 1000, 'Hello'),
          cue(1000, 2000, 'Hello world.'),
          cue(2000, 3000, 'Hello world. Bye.'),
        ]),
        isTrue,
      );
    });

    test('cue độc lập ⇒ false', () {
      expect(
        YtSentenceSegmenter.isCumulativeTrack([
          cue(0, 1000, 'Hello'),
          cue(1000, 2000, 'world.'),
          cue(2000, 3000, 'Bye.'),
        ]),
        isFalse,
      );
    });

    test('dưới 3 cue ⇒ false (không đủ bằng chứng)', () {
      expect(
        YtSentenceSegmenter.isCumulativeTrack([
          cue(0, 1000, 'Hello'),
          cue(1000, 2000, 'Hello world.'),
        ]),
        isFalse,
      );
    });
  });

  group('incrementalTexts — tách phần chữ MỚI', () {
    test('track rolling window ⇒ chỉ lấy phần thêm', () {
      expect(
        YtSentenceSegmenter.incrementalTexts([
          cue(0, 1000, 'Hello'),
          cue(1000, 2000, 'Hello world.'),
          cue(2000, 3000, 'Hello world. Bye.'),
        ]),
        ['Hello', 'world.', 'Bye.'],
      );
    });

    test('track bình thường ⇒ giữ nguyên', () {
      expect(
        YtSentenceSegmenter.incrementalTexts([
          cue(0, 1000, 'Hello'),
          cue(1000, 2000, 'world.'),
        ]),
        ['Hello', 'world.'],
      );
    });
  });

  group('segmentCaptions — gộp cue thành câu', () {
    test('3 cue vụn ⇒ 2 câu hoàn chỉnh', () {
      final out = YtSentenceSegmenter.segmentCaptions([
        cue(0, 1000, 'Hello'),
        cue(1000, 2000, 'world.'),
        cue(2000, 2500, 'Bye.'),
      ]);
      expect(out.length, 2);
      expect(out[0].text, 'Hello world.');
      expect(out[0].start.inMilliseconds, 0);
      expect(out[0].end.inMilliseconds, 2000);
      expect(out[1].text, 'Bye.');
      expect(out[1].start.inMilliseconds, 2000);
    });

    test('khoảng lặng dài (> 1,5 s) ⇒ ngắt câu dù chưa có dấu chấm', () {
      final out = YtSentenceSegmenter.segmentCaptions([
        cue(0, 1000, 'First'),
        cue(3000, 4000, 'second.'),
      ]);
      expect(out.length, 2, reason: 'khoảng lặng 2000 ms > 1500 ms');
      expect(out[0].text, 'First.');
      expect(out[1].text, 'Second.');
    });

    test('vượt maxChars ⇒ đóng câu để không hiện khối chữ khổng lồ', () {
      final out = YtSentenceSegmenter.segmentCaptions(
        [
          cue(0, 1000, 'aaaa aaaa aaaa'),
          cue(1000, 2000, 'bbbb bbbb bbbb'),
          cue(2000, 3000, 'cccc.'),
        ],
        maxChars: 20,
      );
      expect(out.length, 2);
      expect(out[0].text, 'Aaaa aaaa aaaa bbbb bbbb bbbb.');
      expect(out[1].text, 'Cccc.');
    });

    test('vượt maxDurationMs ⇒ đóng câu', () {
      final out = YtSentenceSegmenter.segmentCaptions(
        [
          cue(0, 1000, 'a'),
          cue(1000, 1600, 'b'),
          cue(1600, 3000, 'c.'),
        ],
        maxDurationMs: 1500,
      );
      expect(out.length, 3);
      expect(out.map((e) => e.text).toList(), ['A.', 'B.', 'C.']);
    });

    test('KHÔNG cắt sau viết tắt (Dr. Smith said hi.)', () {
      final out = YtSentenceSegmenter.segmentCaptions([
        cue(0, 1000, 'Dr.'),
        cue(1000, 2000, 'Smith said hi.'),
      ]);
      expect(out.length, 1);
      expect(out[0].text, 'Dr. Smith said hi.');
    });

    test('track rolling window ⇒ gộp theo phần chữ MỚI', () {
      final out = YtSentenceSegmenter.segmentCaptions([
        cue(0, 1000, 'Hello'),
        cue(1000, 2000, 'Hello world.'),
        cue(2000, 3000, 'Hello world. Bye.'),
      ]);
      expect(out.length, 2);
      expect(out[0].text, 'Hello world.');
      expect(out[0].end.inMilliseconds, 2000);
      expect(out[1].text, 'Bye.');
    });

    test('không để câu này lấn sang mốc bắt đầu câu sau', () {
      // Dùng 'Alpha.'/'Beta.' thay vì 'A.'/'B.': chữ cái ĐƠN + dấu chấm bị
      // xem là tên viết tắt (J. R. R.) nên sẽ không đóng câu — dùng nó để test
      // kẹp mốc thời gian sẽ ra 1 dòng thay vì 2.
      final out = YtSentenceSegmenter.segmentCaptions([
        cue(0, 2000, 'Alpha.'),
        cue(1000, 3000, 'Beta.'),
      ]);
      expect(out.length, 2);
      expect(out[0].end.inMilliseconds, 1000,
          reason: 'cue gốc đè lên nhau ⇒ kẹp lại, chữ không đổi sớm');
      expect(out[1].start.inMilliseconds, 1000);
    });

    test('bản dịch được nối theo câu (không mất)', () {
      final out = YtSentenceSegmenter.segmentCaptions([
        cue(0, 1000, 'Hello', translation: 'Xin chào'),
        cue(1000, 2000, 'world.', translation: 'thế giới'),
      ]);
      expect(out.length, 1);
      expect(out[0].text, 'Hello world.');
      expect(out[0].translation, 'Xin chào thế giới');
    });

    test('rỗng ⇒ rỗng (không crash)', () {
      expect(YtSentenceSegmenter.segmentCaptions(const <YtCaptionLine>[]),
          isEmpty);
    });

    test('câu đã hoàn chỉnh sẵn ⇒ giữ nguyên số dòng', () {
      final out = YtSentenceSegmenter.segmentCaptions([
        cue(0, 1000, 'Hello world.'),
        cue(1000, 2000, 'Bye bye.'),
      ]);
      expect(out.length, 2);
      expect(out[0].text, 'Hello world.');
      expect(out[1].text, 'Bye bye.');
    });
  });
}
