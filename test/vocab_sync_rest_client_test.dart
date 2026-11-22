// PSRC-262 — Worklist thiếu từ đã lưu trên cloud.
//
// Hai bảo đảm ở tầng dữ liệu/sync (chạy thuần Dart, không cần thiết bị):
//   1) Firestore REST value codec phải vòng-tròn đúng cho MỌI kiểu WordEntry
//      dùng (string/int/bool/double/list/map/timestamp). Nếu encode/decode
//      làm rơi một kiểu, document kéo về sẽ mất field → bản ghi "có mà
//      như không" — một nguồn gốc khả dĩ của "thiếu từ".
//   2) VocabSyncDiagnostic phân biệt rõ "cloud KHÔNG đọc được" (null) với
//      "cloud rỗng/nhiều hơn" để UI không đoán sai và gợi ý re-sync đúng lúc.
//
// Lưu ý: phần PHÂN TRANG của runQuery (vòng lặp startAt) không gọi được trong
// test offline vì nó đi qua HTTP; nó được bảo vệ bằng review + cấu trúc
// (điều kiện dừng: trang < pageSize hoặc con trỏ không tiến). Các test dưới
// đây khóa phần pure/deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/firestore_rest_client.dart';
import 'package:in4up/services/vocab_sync_service.dart';

void main() {
  group('FirestoreRestClient — value codec vòng-tròn (không rơi kiểu)', () {
    final client = FirestoreRestClient();

    test('các kiểu nguyên thủy vòng-tròn đúng', () {
      expect(client.decodeValue(client.encodeValue('hello')), 'hello');
      expect(client.decodeValue(client.encodeValue(42)), 42);
      expect(client.decodeValue(client.encodeValue(3.5)), 3.5);
      expect(client.decodeValue(client.encodeValue(true)), isTrue);
      expect(client.decodeValue(client.encodeValue(null)), isNull);
    });

    test('list & map lồng nhau vòng-tròn (WordEntry.contexts/topics)', () {
      final original = <String, dynamic>{
        'word': 'abhidhamma',
        'encounterCount': 3,
        'mastery': 0.42,
        'isUnborn': false,
        'topics': ['Phật Pháp', 'Pali'],
        'contexts': [
          {'sourceName': 'book.pdf', 'page': 12},
          {'sourceName': 'web', 'url': 'https://example.com'},
        ],
      };
      final round = client.decodeFields(client.encodeFields(original));
      expect(round['word'], 'abhidhamma');
      expect(round['encounterCount'], 3);
      expect(round['mastery'], closeTo(0.42, 1e-9));
      expect(round['isUnborn'], isFalse);
      expect(round['topics'], ['Phật Pháp', 'Pali']);
      final contexts = round['contexts'] as List;
      expect(contexts.length, 2);
      expect((contexts[0] as Map)['sourceName'], 'book.pdf');
    });

    test('timestamp (DateTime) vòng-tròn — cần cho quy tắc "updatedAt thắng"',
        () {
      final t = DateTime.utc(2026, 11, 22, 8, 30, 0);
      final decoded = client.decodeValue(client.encodeValue(t));
      expect(decoded, isA<DateTime>());
      expect((decoded as DateTime).toUtc(), t);
    });
  });

  group('VocabSyncDiagnostic — phân biệt đã lưu / không đọc được / hiển thị',
      () {
    test('cloudHasMore chỉ đúng khi cloud ĐỌC ĐƯỢC và nhiều hơn local', () {
      expect(
        const VocabSyncDiagnostic(localCount: 100, cloudCount: 1500, pendingCount: 0)
            .cloudHasMore,
        isTrue,
        reason: 'cloud 1500 > local 100 → Worklist đang thiếu từ',
      );
      expect(
        const VocabSyncDiagnostic(localCount: 1500, cloudCount: 1500, pendingCount: 0)
            .cloudHasMore,
        isFalse,
      );
      // local nhiều hơn cloud (chưa đẩy hết) KHÔNG phải "thiếu".
      expect(
        const VocabSyncDiagnostic(localCount: 200, cloudCount: 50, pendingCount: 160)
            .cloudHasMore,
        isFalse,
      );
    });

    test('cloudCount = null (offline) KHÔNG được báo là "thiếu"', () {
      const diag = VocabSyncDiagnostic(
          localCount: 100, cloudCount: null, pendingCount: 0);
      expect(diag.cloudHasMore, isFalse);
      expect(diag.toString(), contains('null'),
          reason: 'UI phải hiển thị "không đọc được", không phải con số 0');
    });

    test('toString tóm tắt đủ 3 con số để đối chiếu', () {
      const diag = VocabSyncDiagnostic(
          localCount: 320, cloudCount: 1500, pendingCount: 4);
      expect(diag.toString(), allOf(contains('320'), contains('1500'), contains('4')));
    });
  });
}
