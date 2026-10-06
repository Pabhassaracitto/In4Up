// XLAT-MIX-001 — audit 0.10.3 mục 1.h: "văn bản tiếng Việt lẫn tiếng Anh
// được giữ nguyên thay vì dịch sang ngôn ngữ đích (tiếng Việt)".
//
// Gốc lỗi là nhận diện ngôn ngữ ở mức TÀI LIỆU: 24 dòng đầu gộp thành một
// mẫu ⇒ tiếng Việt thắng ⇒ nguồn == đích ⇒ chặn dịch. Bộ tách dưới đây
// nhận diện theo TỪNG MẨU CÂU nên mẩu tiếng Anh vẫn được nhận ra.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/features/translation/mixed_language_segmenter.dart';

void main() {
  final vi = AppLanguageCatalog.fromCode('VI');
  final en = AppLanguageCatalog.fromCode('EN');

  group('segmentByLanguage', () {
    test('đoạn thuần tiếng Việt: không có mẩu ngoại ngữ', () {
      const text = 'Hôm nay trời rất đẹp. Tôi đi học bài ở thư viện.';
      final segments = segmentByLanguage(text, target: vi);
      expect(segments.any((segment) => segment.isForeign), isFalse);
      expect(segments.map((segment) => segment.text).join(), text);
    });

    test('câu tiếng Anh xen giữa tiếng Việt được nhận ra (bug 1.h)', () {
      const text = 'Hôm nay tôi học bài mới. '
          'The quick brown fox jumps over the lazy dog. '
          'Bài học này rất thú vị.';
      final segments = segmentByLanguage(text, target: vi);
      final foreign =
          segments.where((segment) => segment.isForeign).toList(growable: false);

      expect(foreign, hasLength(1));
      expect(foreign.first.core, contains('quick brown fox'));
      expect(foreign.first.language.translationCode, 'EN');
      expect(containsForeignSegment(text, target: vi), isTrue);
    });

    test('ghép lại các mẩu phải ra đúng nguyên văn (không mất ký tự)', () {
      const text = 'Dòng một.\nThis is an English line here.\nDòng ba!';
      final segments = segmentByLanguage(text, target: vi);
      expect(segments.map((segment) => segment.text).join(), text);
    });

    test('đích là tiếng Anh thì câu tiếng Việt mới là ngoại ngữ', () {
      const text = 'This is the first sentence. '
          'Câu tiếng Việt nằm giữa đoạn văn. '
          'And the last one is English again.';
      final foreign = segmentByLanguage(text, target: en)
          .where((segment) => segment.isForeign)
          .toList(growable: false);
      expect(foreign, hasLength(1));
      expect(foreign.first.language.translationCode, 'VI');
    });

    test('mẩu quá ngắn được gộp, không tự nhận là ngoại ngữ', () {
      const text = 'Xin chào. OK. Hẹn gặp lại bạn nhé.';
      expect(containsForeignSegment(text, target: vi), isFalse);
    });

    test('đoạn rỗng/trắng → không có mẩu nào', () {
      expect(segmentByLanguage('   ', target: vi), isEmpty);
      expect(containsForeignSegment('', target: vi), isFalse);
    });

    test('nhiều câu tiếng Anh liền nhau được gộp thành một mẩu', () {
      const text = 'Mở đầu bằng tiếng Việt. '
          'This is the first English sentence. '
          'And this is the second English sentence. '
          'Kết lại bằng tiếng Việt.';
      final foreign = segmentByLanguage(text, target: vi)
          .where((segment) => segment.isForeign)
          .toList(growable: false);
      expect(foreign, hasLength(1),
          reason: 'gộp để gọi engine ít lần và có ngữ cảnh dài hơn');
      expect(foreign.first.core, contains('first English'));
      expect(foreign.first.core, contains('second English'));
    });

    // Giới hạn đã biết, ghi lại để người sau không "sửa nhầm": tiếng Việt
    // viết KHÔNG DẤU là mơ hồ thật sự ("di" là giới từ tiếng Indonesia/Ý,
    // "toi" là đại từ tiếng Pháp) nên có thể bị coi là ngoại ngữ. Hậu quả
    // chỉ là dòng đó được dịch thừa — nguyên văn không bao giờ bị thay —
    // nên chấp nhận được, đổi lại tài liệu lẫn lộn thật sự được dịch.
    test('tiếng Việt CÓ DẤU không bao giờ bị coi là ngoại ngữ', () {
      const text = 'Tôi đi học bài mới. Hôm nay cô giáo dạy rất kỹ. '
          'Buổi chiều tôi ôn lại toàn bộ bài.';
      expect(containsForeignSegment(text, target: vi), isFalse);
    });

    test('nguyên văn luôn được giữ nguyên ký tự khi ghép lại', () {
      const text = 'Toi di hoc bai moi. The lesson was very useful today.';
      final segments = segmentByLanguage(text, target: vi);
      expect(segments.map((segment) => segment.text).join(), text);
    });
  });
}
