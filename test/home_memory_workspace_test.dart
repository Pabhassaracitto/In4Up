import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/home/widgets/continue_learning_section.dart';
import 'package:in4up/screens/memory_mode/widgets/remember_workspace_header.dart';

/// NHỚ-WORKSPACE-002 / HOME-CONTINUE-001 — kiểm chứng:
/// - CTA chính "Ôn tập" của workspace Nhớ;
/// - nhóm "Xem tiến độ" đủ công cụ, callback không bị hoán đổi;
/// - badge từ đến hạn không bị mất;
/// - khu vực "Tiếp tục học" của Home chỉ hiện entry khi có dữ liệu thật.

class _MemoryCalls {
  int review = 0;
  int learnByHeart = 0;
  int wordList = 0;
  int timeline = 0;
  int stats = 0;
  int map = 0;
  int quickActions = 0;
}

Widget _memoryHost({
  required _MemoryCalls calls,
  int dueCount = 0,
  int totalWords = 0,
  bool withLearnByHeart = true,
  double width = 800,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: width,
            child: RememberWorkspaceHeader(
              dueCount: dueCount,
              totalWords: totalWords,
              onOpenReview: () => calls.review++,
              onOpenLearnByHeart:
                  withLearnByHeart ? () => calls.learnByHeart++ : null,
              onOpenWordList: () => calls.wordList++,
              onOpenTimeline: () => calls.timeline++,
              onOpenStats: () => calls.stats++,
              onOpenMap: () => calls.map++,
              onOpenQuickActions: () => calls.quickActions++,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _homeHost(List<ContinueLearningEntry> entries, {double width = 800}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: width,
            child: ContinueLearningSection(entries: entries),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('RememberWorkspaceHeader — hoạt động học chính', () {
    testWidgets('CTA chính Ôn tập hiển thị và chỉ gọi onOpenReview',
        (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(_memoryHost(calls: calls, dueCount: 7));

      expect(find.byKey(rememberPrimaryCtaKey), findsOneWidget);

      await tester.tap(find.byKey(rememberPrimaryCtaKey));
      await tester.pump();

      expect(calls.review, 1);
      expect(calls.learnByHeart, 0);
      expect(calls.wordList, 0);
      expect(calls.timeline, 0);
      expect(calls.stats, 0);
      expect(calls.map, 0);
      expect(calls.quickActions, 0);
    });

    testWidgets('CTA chính hiện badge số từ đến hạn khi dueCount > 0',
        (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(_memoryHost(calls: calls, dueCount: 12));

      expect(
        find.descendant(
          of: find.byKey(rememberPrimaryCtaKey),
          matching: find.text('12'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('CTA chính không hiện badge khi dueCount = 0', (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(_memoryHost(calls: calls, dueCount: 0));

      expect(
        find.descendant(
          of: find.byKey(rememberPrimaryCtaKey),
          matching: find.text('0'),
        ),
        findsNothing,
      );
    });

    testWidgets('badge Đến hạn trong banner không bị mất', (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(
        _memoryHost(calls: calls, dueCount: 7, totalWords: 42),
      );

      expect(find.byKey(rememberDueBadgeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(rememberDueBadgeKey),
          matching: find.textContaining('7'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Thuộc lòng hiển thị khi có callback và gọi đúng callback',
        (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(_memoryHost(calls: calls));

      expect(find.byKey(rememberLearnByHeartKey), findsOneWidget);

      await tester.tap(find.byKey(rememberLearnByHeartKey));
      await tester.pump();

      expect(calls.learnByHeart, 1);
      expect(calls.review, 0);
    });

    testWidgets('Thuộc lòng ẩn khi không có callback', (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(
        _memoryHost(calls: calls, withLearnByHeart: false),
      );

      expect(find.byKey(rememberLearnByHeartKey), findsNothing);
      expect(find.byKey(rememberPrimaryCtaKey), findsOneWidget);
    });
  });

  group('RememberWorkspaceHeader — nhóm Xem tiến độ', () {
    testWidgets('đủ 4 công cụ xem dữ liệu + công cụ nhanh', (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(_memoryHost(calls: calls));

      expect(find.byKey(rememberProgressGroupKey), findsOneWidget);
      expect(find.byKey(rememberToolWordListKey), findsOneWidget);
      expect(find.byKey(rememberToolTimelineKey), findsOneWidget);
      expect(find.byKey(rememberToolStatsKey), findsOneWidget);
      expect(find.byKey(rememberToolWordMapKey), findsOneWidget);
      expect(find.byKey(rememberToolQuickActionsKey), findsOneWidget);
    });

    testWidgets('mỗi công cụ gọi đúng callback của nó — không bị hoán đổi',
        (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(_memoryHost(calls: calls));

      Future<void> tapTool(Key key) async {
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(key));
        await tester.pump();
      }

      await tapTool(rememberToolWordListKey);
      expect(calls.wordList, 1);

      await tapTool(rememberToolTimelineKey);
      expect(calls.timeline, 1);

      await tapTool(rememberToolStatsKey);
      expect(calls.stats, 1);

      await tapTool(rememberToolWordMapKey);
      expect(calls.map, 1);

      await tapTool(rememberToolQuickActionsKey);
      expect(calls.quickActions, 1);

      // Các callback khác không bị gọi nhầm.
      expect(calls.review, 0);
      expect(calls.learnByHeart, 0);
    });

    testWidgets('render ở màn hẹp 320dp không gây overflow ngang',
        (tester) async {
      final calls = _MemoryCalls();
      await tester.pumpWidget(
        _memoryHost(calls: calls, dueCount: 99, totalWords: 1234, width: 320),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(rememberPrimaryCtaKey), findsOneWidget);
    });
  });

  group('buildContinueLearningEntries — chỉ dữ liệu thật', () {
    void noop() {}

    test('không có dữ liệu → không có entry (không mock dữ liệu giả)', () {
      final entries = buildContinueLearningEntries(
        onResumeListening: noop,
        onResumeReading: noop,
        onReviewDue: noop,
      );
      expect(entries, isEmpty);
    });

    test('chuỗi rỗng/khoảng trắng không tạo entry', () {
      final entries = buildContinueLearningEntries(
        onResumeListening: noop,
        onResumeReading: noop,
        onReviewDue: noop,
        listeningTitle: '   ',
        readingTitle: '',
        dueWordCount: 0,
      );
      expect(entries, isEmpty);
    });

    test('đủ dữ liệu → 3 entry đúng thứ tự, entry đến hạn có badge', () {
      final entries = buildContinueLearningEntries(
        onResumeListening: noop,
        onResumeReading: noop,
        onReviewDue: noop,
        listeningTitle: 'BBC 6 Minute English',
        readingTitle: 'The Little Prince',
        dueWordCount: 9,
      );

      expect(entries, hasLength(3));
      expect(entries[0].key, continueListeningTileKey);
      expect(entries[0].subtitle, 'BBC 6 Minute English');
      expect(entries[1].key, continueReadingTileKey);
      expect(entries[1].subtitle, 'The Little Prince');
      expect(entries[2].key, continueDueWordsTileKey);
      expect(entries[2].badge, '9');
    });

    test('chỉ có từ đến hạn → duy nhất 1 entry', () {
      final entries = buildContinueLearningEntries(
        onResumeListening: noop,
        onResumeReading: noop,
        onReviewDue: noop,
        dueWordCount: 3,
      );
      expect(entries, hasLength(1));
      expect(entries.single.key, continueDueWordsTileKey);
    });
  });

  group('ContinueLearningSection — khu vực Tiếp tục học của Home', () {
    testWidgets('danh sách rỗng → hiện gợi ý trống, không có tile',
        (tester) async {
      await tester.pumpWidget(_homeHost(const []));

      expect(find.byKey(continueLearningSectionKey), findsOneWidget);
      expect(find.byKey(continueLearningEmptyKey), findsOneWidget);
      expect(find.byKey(continueListeningTileKey), findsNothing);
      expect(find.byKey(continueReadingTileKey), findsNothing);
      expect(find.byKey(continueDueWordsTileKey), findsNothing);
    });

    testWidgets('render 3 tile với badge đến hạn', (tester) async {
      final entries = buildContinueLearningEntries(
        onResumeListening: () {},
        onResumeReading: () {},
        onReviewDue: () {},
        listeningTitle: 'Podcast A',
        readingTitle: 'Sách B',
        dueWordCount: 5,
      );
      await tester.pumpWidget(_homeHost(entries));

      expect(find.byKey(continueLearningEmptyKey), findsNothing);
      expect(find.byKey(continueListeningTileKey), findsOneWidget);
      expect(find.byKey(continueReadingTileKey), findsOneWidget);
      expect(find.byKey(continueDueWordsTileKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(continueDueWordsTileKey),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap tile gọi đúng callback tương ứng', (tester) async {
      var listen = 0;
      var read = 0;
      var review = 0;
      final entries = buildContinueLearningEntries(
        onResumeListening: () => listen++,
        onResumeReading: () => read++,
        onReviewDue: () => review++,
        listeningTitle: 'Podcast A',
        readingTitle: 'Sách B',
        dueWordCount: 5,
      );
      await tester.pumpWidget(_homeHost(entries));

      await tester.tap(find.byKey(continueListeningTileKey));
      await tester.pump();
      expect(listen, 1);
      expect(read, 0);
      expect(review, 0);

      await tester.tap(find.byKey(continueReadingTileKey));
      await tester.pump();
      expect(read, 1);

      await tester.tap(find.byKey(continueDueWordsTileKey));
      await tester.pump();
      expect(review, 1);
      expect(listen, 1);
    });

    testWidgets('render 2 tile ở màn hẹp 320dp không overflow',
        (tester) async {
      final entries = buildContinueLearningEntries(
        onResumeListening: () {},
        onResumeReading: () {},
        onReviewDue: () {},
        listeningTitle:
            'Một tiêu đề bài nghe rất dài để kiểm tra ellipsis không tràn',
        dueWordCount: 123,
      );
      await tester.pumpWidget(_homeHost(entries, width: 320));

      expect(entries, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  });
}
