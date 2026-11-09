// Đợt A — khảo sát YouTube tầng 1 (owner chốt 2026-11-09).
//
// Test thuần (không WebView / không mạng / không Flutter binding) cho:
//   • YT-LEVEL-001 (#YT1-01): "cấp độ từ vựng" = độ phủ từ đã biết, tính từ
//     chữ phụ đề; thay cho thanh trượt GIẢ trước đây.
//   • YT1-02: "Kênh của tôi" đi qua `YtChannelStore`, không còn danh sách RAM
//     riêng trong Explorer.
//   • YT1-03: không còn `if (_loading) return;` — truy vấn mới không bị nuốt.
//   • YT1-04: không dựng câu tiếng Việt có nội suy rồi mới bọc `uiText`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/services/yt_coverage_service.dart';

void main() {
  final cov = YtCoverageService.instance;
  final explorer =
      File('lib/features/youtube/youtube_explorer_screen.dart').readAsStringSync();

  group('YT-LEVEL-001 — độ phủ từ đã biết', () {
    test('bỏ mốc LRC/SRT rồi tách từ nội dung, giữ viết tắt', () {
      final tokens = cov.contentTokens(
        '[00:01.20]Don\'t worry, the teacher will explain it again.\n'
        '[00:04.00]<i>Well-known books</i> are here.',
      );
      // "the", "will", "it", "are" là từ chức năng ⇒ bị loại.
      expect(tokens, contains("don't"));
      expect(tokens, contains('worry'));
      expect(tokens, contains('teacher'));
      expect(tokens, contains('explain'));
      expect(tokens, contains('well-known'));
      expect(tokens, isNot(contains('the')));
      expect(tokens, isNot(contains('will')));
      expect(tokens, isNot(contains('are')));
      // Không còn sót mốc thời gian dạng số.
      expect(tokens.any((t) => RegExp(r'^\d').hasMatch(t)), isFalse);
    });

    test('không có từ nội dung ⇒ tokens = 0, nhóm "chưa rõ"', () {
      final c = cov.computeCoverage(id: 'v0', rawCaptionText: '[00:01.00]the a of');
      expect(c, isNotNull);
      expect(c!.tokens, 0);
      expect(c.band, YtCoverageBand.unknown);
    });

    test('VocabularyBridge chưa init ⇒ không crash, known = 0', () {
      final c = cov.computeCoverage(
        id: 'v1',
        rawCaptionText: 'teacher explains grammar clearly',
      );
      expect(c, isNotNull);
      expect(c!.tokens, greaterThan(0));
      expect(c.known, 0);
      expect(c.ratio, 0);
      expect(c.band, YtCoverageBand.hard);
    });

    test('ngưỡng nhóm: ≥95% dễ · 85–95% vừa · <85% khó', () {
      YtVideoCoverage make(int known, int total) => YtVideoCoverage(
            videoId: 'x',
            known: known,
            tokens: total,
            at: DateTime(2026, 11, 9),
          );
      expect(make(95, 100).band, YtCoverageBand.easy);
      expect(make(94, 100).band, YtCoverageBand.fair);
      expect(make(85, 100).band, YtCoverageBand.fair);
      expect(make(84, 100).band, YtCoverageBand.hard);
      expect(make(0, 0).band, YtCoverageBand.unknown);
      expect(make(19, 20).percent, 95);
    });

    test('JSON khứ hồi giữ đúng số đo', () {
      final c = YtVideoCoverage(
        videoId: 'abc',
        known: 42,
        tokens: 100,
        at: DateTime.fromMillisecondsSinceEpoch(1762700000000),
      );
      final back = YtVideoCoverage.fromJson(c.toJson())!;
      expect(back.videoId, 'abc');
      expect(back.known, 42);
      expect(back.tokens, 100);
      expect(back.at, c.at);
      expect(back.percent, 42);
    });
  });

  group('YT1-01 — bộ lọc thật thay thanh trượt giả', () {
    test('Explorer KHÔNG còn RangeSlider rank giả', () {
      // So MÃ, không so chữ trong chú thích (chú thích cũng nhắc `_rankMin`).
      expect(explorer.contains('_rankMin ='), isFalse);
      expect(explorer.contains('_rankMax ='), isFalse);
      expect(explorer.contains('RangeSlider('), isFalse);
      expect(explorer.contains('RangeValues('), isFalse);
    });

    test('lọc theo nhóm cấp độ + đo được', () {
      expect(explorer.contains('YtCoverageBand? _bandFilter;'), isTrue);
      expect(explorer.contains('List<YtExVideo> get _visibleVideos'), isTrue);
      expect(explorer.contains('YtCoverageService.instance.of('), isTrue);
      expect(explorer.contains('Future<void> _analyzePage() async'), isTrue);
    });

    test('hỏi trước khi tải phụ đề cả trang (nói rõ chỉ chữ, không âm thanh)', () {
      expect(explorer.contains('Phân tích cấp độ cả trang?'), isTrue);
      expect(explorer.contains('không tải âm thanh'), isTrue);
    });

    test('video chưa đo hiện nhãn "Chưa rõ" + đo được từng cái', () {
      expect(explorer.contains('_coverageBadge('), isTrue);
      expect(explorer.contains('_analyzeOne('), isTrue);
    });
  });

  group('YT1-02 — Kênh của tôi trong Explorer', () {
    test('nạp từ YtChannelStore (một nguồn sự thật)', () {
      expect(explorer.contains('YtChannelStore.instance.load()'), isTrue);
      expect(explorer.contains('List<YtChannel> _myChannels'), isTrue);
    });

    test('kênh theo dõi nằm SAU danh sách gợi ý (quyết định owner)', () {
      // Chỉ so TRONG sidebar: chuỗi "Kênh của tôi" còn xuất hiện ở tooltip
      // thanh trên cùng (nút mở sheet) nên so toàn file sẽ sai.
      final side = explorer.indexOf('Widget _sidebarContent()');
      expect(side, greaterThan(-1));
      final body = explorer.substring(side);
      final recAt = body.indexOf("'GỢI Ý: 1 - {value0}'");
      final mineAt = body.indexOf("uiText('Kênh của tôi')");
      expect(recAt, greaterThan(-1));
      expect(mineAt, greaterThan(-1));
      expect(recAt, lessThan(mineAt),
          reason: 'gợi ý phải đứng trước "Kênh của tôi" trong sidebar');
    });

    test('chọn kênh của tôi không rơi về header kênh đầu tiên', () {
      expect(explorer.contains('YtExChannel? _channelById(String? id)'), isTrue);
      expect(explorer.contains('_channelById(_selChannelId)'), isTrue);
    });
  });

  group('YT1-03 — truy vấn mới không bị nuốt', () {
    test('không còn chặn cứng khi đang tải', () {
      expect(explorer.contains('if (_loading) return;'), isFalse);
      expect(explorer.contains('final req = ++_reqId;'), isTrue);
      expect(explorer.contains('req != _reqId'), isTrue);
    });

    test('gợi ý tìm kiếm cũng chống đè kết quả cũ', () {
      expect(explorer.contains('_suggestReq'), isTrue);
    });
  });

  group('YT1-04 — i18n nhãn Explorer', () {
    test('không dựng câu tiếng Việt có nội suy rồi mới uiText', () {
      expect(explorer.contains('uiText(v.viewLabel)'), isFalse);
      expect(explorer.contains('uiText(v.dateLabel)'), isFalse);
      expect(explorer.contains('_viewLabel('), isTrue);
      expect(explorer.contains('_dateLabel('), isTrue);
    });

    test('nhãn hard-code cũ đã đi qua uiText', () {
      for (final needle in <String>[
        "context.uiText('Cấp độ từ vựng')",
        "context.uiText('Sắp xếp theo')",
        "context.uiText('Kênh')",
        "context.uiText('Tất cả các kênh')",
        "context.uiText('Thêm kênh')",
      ]) {
        expect(explorer.contains(needle), isTrue, reason: needle);
      }
      // `uiText('X')` CŨNG chứa chuỗi `Text('X')` ⇒ phải khử tiền tố "ui",
      // nếu không assertion luôn sai.
      final leftovers = <String>[];
      for (final label in <String>[
        'Cấp độ từ vựng',
        'Thêm kênh',
        'Sắp xếp theo',
      ]) {
        var i = explorer.indexOf("Text('$label'");
        while (i >= 0) {
          final before = i >= 2 ? explorer.substring(i - 2, i) : '';
          if (before != 'ui') {
            leftovers.add(label);
            break;
          }
          i = explorer.indexOf("Text('$label'", i + 1);
        }
      }
      expect(leftovers, isEmpty, reason: 'còn Text() không qua uiText');
    });

    test('template có bản dịch (en/hi/zh/zh_TW/si)', () {
      final cat =
          File('lib/core/language/priority_ui_overrides.dart').readAsStringSync();
      for (final key in <String>[
        'Phân tích cả trang',
        'Đã biết {value0}%',
        'Chưa rõ cấp độ · đo',
        'Đo từ phụ đề trên máy (0 MB)',
        'GỢI Ý: 1 - {value0}',
        'Không video nào khớp bộ lọc cấp độ. Chọn "Tất cả" để xem lại.',
      ]) {
        expect(cat.contains("'$key':"), isTrue, reason: key);
      }
    });
  });
}
