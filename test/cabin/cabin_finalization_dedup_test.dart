// AUDIT-1.21.0 #3 — Cabin: đang dịch mà nói thêm ⇒ 2 dòng trùng.
// Test THUẦN (không mic/plugin) cho lớp chống trùng thay thế delayed 3s.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_finalization_dedup.dart';

void main() {
  group('CabinFinalizationDeduper', () {
    test('chặn finalization trùng khi bản dịch CÒN ĐANG BAY (> 3s)', () {
      var now = DateTime(2026, 1, 1, 9);
      final d = CabinFinalizationDeduper(now: () => now);

      expect(d.shouldFinalize('Xin chào.'), isTrue);
      d.begin('Xin chào.');
      expect(d.hasInFlight, isTrue);

      // Engine replay isFinal của câu CŨ lúc dịch vẫn chưa xong.
      now = now.add(const Duration(seconds: 12));
      expect(d.shouldFinalize('xin chào'), isFalse,
          reason: 'in-flight phải thắng cả cửa sổ 3s kiểu cũ');

      // Câu MỚI (user nói thêm) không bị nuốt.
      expect(d.shouldFinalize('Tôi vẫn nói tiếp'), isTrue);
    });

    test('complete() đưa vào cửa sổ nhớ, hết 8s thì nói lại được', () {
      var now = DateTime(2026, 1, 1, 9);
      final d = CabinFinalizationDeduper(now: () => now);
      d.begin('Câu A');
      d.complete('Câu A');
      expect(d.hasInFlight, isFalse);
      expect(d.shouldFinalize('Câu A!'), isFalse);

      now = now.add(const Duration(seconds: 9));
      expect(d.shouldFinalize('Câu A'), isTrue,
          reason: 'user cố ý nói lại cùng câu vẫn phải được ghi nhận');
    });

    test('normalize bỏ hoa thường / dấu câu / khoảng trắng thừa', () {
      expect(CabinFinalizationDeduper.normalize('  Xin,   chào! '), 'xin chào');
      expect(CabinFinalizationDeduper.normalize('Xin chào'),
          CabinFinalizationDeduper.normalize('xin chào.'));
      expect(CabinFinalizationDeduper.normalize('...'), isEmpty);
      expect(CabinFinalizationDeduper.normalize('   '), isEmpty);
    });

    test('cancel + reset quên đúng phạm vi', () {
      final d = CabinFinalizationDeduper();
      d.begin('A');
      d.cancel('A');
      expect(d.hasInFlight, isFalse);
      expect(d.shouldFinalize('A'), isTrue);
      d.begin('A');
      d.complete('A');
      d.reset();
      expect(d.shouldFinalize('A'), isTrue);
    });

    test('finish(false): câu bị bỏ qua KHÔNG được nhớ ⇒ replay vẫn chốt', () {
      // AUDIT-1.21.0 #3 recheck: final tới đúng lúc `_state == speaking` ⇒
      // `_finalizeCurrentChunk` return sớm, KHÔNG tạo caption. Nếu vẫn gọi
      // `complete()` thì replay final trong 8s bị nuốt ⇒ MẤT CÂU.
      final d = CabinFinalizationDeduper();
      expect(d.shouldFinalize('Câu bị bỏ qua'), isTrue);
      d.begin('Câu bị bỏ qua');
      d.finish('Câu bị bỏ qua', createdCaption: false);
      expect(d.hasInFlight, isFalse);
      expect(d.shouldFinalize('Câu bị bỏ qua'), isTrue,
          reason: 'phải quên in-flight mà KHÔNG đưa vào _recent');
    });

    test('finish(true) tương đương complete()', () {
      final d = CabinFinalizationDeduper();
      d.begin('Câu đã chốt');
      d.finish('Câu đã chốt', createdCaption: true);
      expect(d.hasInFlight, isFalse);
      expect(d.shouldFinalize('câu đã chốt!'), isFalse);
    });

    test('outcome mặc định false, chỉ bật khi caption thật sự được tạo', () {
      final o = CabinFinalizationOutcome();
      expect(o.createdCaption, isFalse);
      o.createdCaption = true;
      expect(o.createdCaption, isTrue);
    });

    test('chuỗi text rỗng không bao giờ được chốt', () {
      final d = CabinFinalizationDeduper();
      expect(d.shouldFinalize(''), isFalse);
      expect(d.shouldFinalize('  '), isFalse);
      expect(d.shouldFinalize('...'), isFalse);
      d.begin('');
      expect(d.hasInFlight, isFalse);
    });
  });
}
