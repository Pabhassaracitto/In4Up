// test/mascot/mascot_search_index_test.dart
//
// MASCOT-002 — test thuần Dart cho chỉ mục tìm kiếm hợp nhất của palette
// «Mở nhanh» (PLAN-050 §7). Không Flutter/plugin — chạy được cả trong sandbox.

import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/features/mascot/mascot_search_index.dart';

MascotSearchEntry _entry(
  String id,
  String title, {
  String? subtitle,
  double boost = 0,
  MascotSearchKind kind = MascotSearchKind.tool,
}) {
  return MascotSearchEntry(
    id: id,
    kind: kind,
    title: title,
    subtitle: subtitle,
    boost: boost,
  );
}

void main() {
  group('search', () {
    test('exact cộng boost xếp trên', () {
      final index = MascotSearchIndex([
        _entry('pdf_reader', 'PDF Reader'),
        _entry('fast_pdf', 'PDF', boost: 0.5),
      ]);
      final results = index.search('pdf');
      expect(results.first.entry.id, 'fast_pdf',
          reason: 'đồng điểm exact (100) — boost cao hơn đứng trước');
      expect(results.last.entry.id, 'pdf_reader');
    });

    test('gõ không dấu vẫn khớp tiêu đề có dấu', () {
      final index = MascotSearchIndex([
        _entry('youglish', 'Phát âm YouGlish'),
      ]);
      final results = index.search('phat am');
      expect(results, isNotEmpty);
      expect(results.first.entry.id, 'youglish');
    });

    test('tiền tố từ khớp («tu» → «Từ điển MDX»)', () {
      final index = MascotSearchIndex([
        _entry('dictionary', 'Từ điển MDX'),
      ]);
      final results = index.search('tu');
      expect(results, isNotEmpty);
      expect(results.first.entry.id, 'dictionary');
    });

    test('fuzzy subsequence («tamg» → «Tam giác»)', () {
      final index = MascotSearchIndex([
        _entry('triangle', 'Tam giác'),
      ]);
      final results = index.search('tamg');
      expect(results, isNotEmpty);
      expect(results.first.entry.id, 'triangle');
    });

    test('khớp phụ đề khi tiêu đề không khớp', () {
      final index = MascotSearchIndex([
        _entry('tool_x', 'Công cụ X', subtitle: 'Piper TTS'),
      ]);
      final results = index.search('piper');
      expect(results, isNotEmpty);
      expect(results.first.entry.id, 'tool_x');
    });

    test('truy vấn rỗng → gợi ý theo boost', () {
      final index = MascotSearchIndex([
        _entry('a', 'Alpha', boost: 0.1),
        _entry('b', 'Beta', boost: 0.9),
        _entry('c', 'Gamma', boost: 0.5),
      ]);
      final results = index.search('');
      expect(results.map((r) => r.entry.id).toList(), ['b', 'c', 'a']);
    });

    test('limit được tôn trọng', () {
      final index = MascotSearchIndex([
        for (var i = 0; i < 10; i++) _entry('t$i', 'Mục tiêu $i'),
      ]);
      expect(index.search('muc', limit: 3).length, 3);
    });

    test('không khớp → rỗng', () {
      final index = MascotSearchIndex([
        _entry('a', 'Alpha'),
      ]);
      expect(index.search('zzzzz'), isEmpty);
    });

    test('đồng điểm giữ thứ tự khai báo (ổn định cho UI)', () {
      final index = MascotSearchIndex([
        _entry('first', 'Nghe bài học'),
        _entry('second', 'Nghe nhạc'),
      ]);
      final results = index.search('nghe');
      expect(results.length, 2);
      expect(results.first.entry.id, 'first');
    });
  });

  group('hiệu năng', () {
    test('1000 mục × 25 truy vấn vẫn nhanh', () {
      final entries = <MascotSearchEntry>[
        for (var i = 0; i < 1000; i++)
          _entry('e$i', 'Mục thử nghiệm số $i',
              subtitle: 'nhóm ${i % 20}', boost: (i % 10) / 10),
      ];
      final index = MascotSearchIndex(entries);
      final watch = Stopwatch()..start();
      for (var q = 0; q < 25; q++) {
        index.search('muc thu $q', limit: 14);
      }
      index.search('');
      watch.stop();
      // Trần rộng để không flake trên CI chậm — thực tế chỉ vài chục ms.
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });
}
