// test/home_streak/home_streak_suites.dart
//
// HOME-STREAK-001 — bộ test thật (không phụ thuộc plugin/native):
//   • kho hoạt động học theo ngày: duplicate event, date boundary, restart,
//     persist gọn, dọn dữ liệu cũ;
//   • thẻ "Nhịp điệu học tập": số liệu lấy từ provider thật, chrome theo locale
//     (rule #5 — locale ≠ vi thì không còn tiếng Việt).
//
// Cấu trúc "suite function" để cùng một bộ test có thể chạy từ nhiều entry
// point: `test/home_streak/*.dart` (đúng chỗ) và cầu nối oracle trong
// `test/knowledge/home_streak_ci_oracle_test.dart` (job knowledge là CI duy
// nhất chạy được bộ test mới, vì GitHub App token không có quyền `workflows`).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/models/learning_activity.dart';
import 'package:in4up/providers/focus_provider.dart';
import 'package:in4up/screens/home/widgets/focus_streak_card.dart';
import 'package:in4up/services/learning_activity_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. Kho hoạt động học (service + model)
// ─────────────────────────────────────────────────────────────────────────────

void defineLearningActivityServiceTests() {
  group('LearningActivityKind — tên lưu bền', () {
    test('wireName round-trip cho mọi kind', () {
      for (final kind in LearningActivityKind.values) {
        expect(LearningActivityKind.fromWireName(kind.wireName), kind);
      }
      expect(LearningActivityKind.fromWireName('unknown_kind'), isNull);
    });
  });

  group('learningDayKey — ngày địa phương', () {
    test('đệm 0 và khớp thành phần ngày giờ địa phương', () {
      final local = DateTime(2026, 9, 5, 7, 3);
      expect(learningDayKey(local), '2026-09-05');
      expect(learningDayStart(local), DateTime(2026, 9, 5));
    });

    test('instant UTC được quy về ngày theo giờ địa phương', () {
      final utcInstant = DateTime.utc(2026, 9, 15, 23, 30);
      final local = utcInstant.toLocal();
      final expected = '${local.year}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      expect(learningDayKey(utcInstant), expected);
    });

    test('dịch ngày qua ranh giới tháng/năm (không dùng Duration)', () {
      expect(learningDayShift(DateTime(2026, 9, 1), -1), DateTime(2026, 8, 31));
      expect(learningDayShift(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
      expect(learningDayShift(DateTime(2026, 2, 28), 1), DateTime(2026, 3, 1));
    });

    test('learningDayFromKey từ chối khoá hỏng', () {
      expect(learningDayFromKey('2026-09-15'), DateTime(2026, 9, 15));
      expect(learningDayFromKey('2026-13-01'), isNull);
      expect(learningDayFromKey('2026-02-31'), isNull);
      expect(learningDayFromKey('nonsense'), isNull);
      expect(learningDayFromKey(''), isNull);
    });
  });

  group('LearningActivityService — ghi hoạt động học thật', () {
    late InMemoryLearningActivityStorage storage;
    late DateTime now;
    late LearningActivityService service;

    setUp(() {
      storage = InMemoryLearningActivityStorage();
      now = DateTime(2026, 9, 15, 10, 0);
      service = LearningActivityService(storage: storage, clock: () => now);
    });

    tearDown(() => service.dispose());

    test('AT: đọc + lưu từ trong ngày → số hôm nay > 0', () async {
      await service.record(LearningActivityKind.readDocument,
          sourceKey: 'doc-1');
      await service.record(LearningActivityKind.readingMinutes,
          sourceKey: 'doc-1|10:00', amount: 12);
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'apple');

      expect(service.today.countOf(LearningActivityKind.readDocument), 1);
      expect(service.today.countOf(LearningActivityKind.readingMinutes), 12);
      expect(service.today.countOf(LearningActivityKind.vocabulary), 1);
      expect(service.today.totalEvents, greaterThan(0));
      expect(service.activeToday, isTrue);
      expect(service.today.isActive, isTrue);
    });

    test('duplicate event: cùng (kind, khoá, ngày) chỉ tính một lần', () async {
      final first = await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'apple');
      final second = await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'apple');
      final third = await service.record(LearningActivityKind.vocabulary,
          sourceKey: '  apple  ');

      expect(first, isTrue);
      expect(second, isFalse);
      expect(third, isFalse);
      expect(service.today.countOf(LearningActivityKind.vocabulary), 1);
    });

    test('khoá khác nhau cùng ngày được cộng dồn; khác kind không lẫn nhau',
        () async {
      await service.record(LearningActivityKind.vocabulary, sourceKey: 'apple');
      await service.record(LearningActivityKind.vocabulary, sourceKey: 'banana');
      await service.record(LearningActivityKind.learnByHeart, sourceKey: 'apple');

      expect(service.today.countOf(LearningActivityKind.vocabulary), 2);
      expect(service.today.countOf(LearningActivityKind.learnByHeart), 1);
    });

    test('sự kiện không có khoá nguồn vẫn được tính (không bị gộp)', () async {
      await service.record(LearningActivityKind.translation);
      await service.record(LearningActivityKind.translation);
      expect(service.today.countOf(LearningActivityKind.translation), 2);
    });

    test('amount <= 0 bị bỏ qua', () async {
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'apple', amount: 0);
      expect(service.today.isActive, isFalse);
    });

    test('date boundary: 23:59 và 00:01 rơi vào hai ngày khác nhau', () async {
      final beforeMidnight = DateTime(2026, 9, 15, 23, 59, 30);
      final afterMidnight = DateTime(2026, 9, 16, 0, 0, 30);

      await service.record(LearningActivityKind.readDocument,
          sourceKey: 'doc-1', at: beforeMidnight);
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'apple', at: afterMidnight);

      expect(
        service
            .activityOn(beforeMidnight)
            .countOf(LearningActivityKind.readDocument),
        1,
      );
      expect(
        service.activityOn(beforeMidnight)
            .countOf(LearningActivityKind.vocabulary),
        0,
      );
      expect(
        service.activityOn(afterMidnight)
            .countOf(LearningActivityKind.vocabulary),
        1,
      );
      expect(
        service.activityOn(afterMidnight)
            .countOf(LearningActivityKind.readDocument),
        0,
      );
    });
  });

  group('LearningActivityService — streak theo ngày thật', () {
    late InMemoryLearningActivityStorage storage;
    late DateTime now;
    late LearningActivityService service;

    setUp(() {
      storage = InMemoryLearningActivityStorage();
      now = DateTime(2026, 9, 15, 10, 0);
      service = LearningActivityService(storage: storage, clock: () => now);
    });

    tearDown(() => service.dispose());

    Future<void> recordOn(int day) => service.record(
          LearningActivityKind.vocabulary,
          sourceKey: 'word-$day',
          at: DateTime(2026, 9, day, 9, 0),
        );

    test('chưa học ngày nào → streak 0', () async {
      await service.ready;
      expect(service.streak(now: now), 0);
      expect(service.activeToday, isFalse);
    });

    test('học hôm nay → streak 1', () async {
      await recordOn(15);
      expect(service.streak(now: now), 1);
    });

    test('học hôm qua + hôm nay → streak 2', () async {
      await recordOn(14);
      await recordOn(15);
      expect(service.streak(now: now), 2);
    });

    test('AT: ngày không học không tăng — hôm nay chưa học thì giữ chuỗi hôm qua',
        () async {
      await recordOn(13);
      await recordOn(14);

      // Bây giờ là 15/09, hôm nay CHƯA học: chuỗi chưa tụt (1 ngày), nhưng
      // cũng không được cộng thêm.
      expect(service.streak(now: now), 2);
      expect(service.activeToday, isFalse);

      // Học tiếp ngày kế tiếp → +1.
      await recordOn(15);
      expect(service.streak(now: now), 3);
      expect(service.activeToday, isTrue);
    });

    test('AT: nghỉ trọn một ngày → chuỗi về 0 (không giữ chuỗi cũ)', () async {
      await recordOn(13);
      expect(service.streak(now: now), 0);
    });

    test('ngày trống nằm giữa làm đứt chuỗi', () async {
      await recordOn(13);
      await recordOn(15);
      expect(service.streak(now: now), 1);
    });

    test('streak đếm liên tiếp nhiều ngày liền', () async {
      for (var offset = 0; offset < 5; offset++) {
        await recordOn(15 - offset);
      }
      expect(service.streak(now: now), 5);
    });

    test('snapshot: 7 ngày, cũ → mới, phần tử cuối là hôm nay', () async {
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'a', amount: 4, at: DateTime(2026, 9, 15, 9));
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'b', at: DateTime(2026, 9, 13, 9));

      final snapshot = service.snapshot(now: now);

      expect(snapshot.recentDays.length, 7);
      expect(snapshot.recentDays.first.dayKey, '2026-09-09');
      expect(snapshot.recentDays.last.dayKey, '2026-09-15');
      expect(snapshot.today.dayOfMonth, 15);
      expect(snapshot.maxDayTotal, 4);
      expect(snapshot.activeDaysInWindow, 2);
      expect(snapshot.activeToday, isTrue);
      expect(snapshot.streak, 1);
      // recentDays: [0] = 09-09 … [4] = 09-13 (ngày đã ghi) … [6] = 09-15.
      expect(
        snapshot.recentDays[4].countOf(LearningActivityKind.vocabulary),
        1,
      );
      expect(
        snapshot.recentDays[3].countOf(LearningActivityKind.vocabulary),
        0,
      );
    });
  });

  group('LearningActivityService — persist gọn / restart', () {
    late InMemoryLearningActivityStorage storage;
    late DateTime now;
    late LearningActivityService service;

    setUp(() {
      storage = InMemoryLearningActivityStorage();
      now = DateTime(2026, 9, 15, 10, 0);
      service = LearningActivityService(storage: storage, clock: () => now);
    });

    tearDown(() => service.dispose());

    test('persist gọn: gộp theo ngày, không lưu từng event thô', () async {
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'a', amount: 3);
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'b', amount: 2);
      await service.record(LearningActivityKind.shadowing, sourceKey: 's-1');

      final payload =
          jsonDecode(storage.payload!) as Map<String, dynamic>;
      expect(payload['v'], LearningActivityService.schemaVersion);
      final days = payload['days'] as Map<String, dynamic>;
      expect(days.keys.length, 1);
      expect(days[service.today.dayKey], {'vocab': 5, 'shadowing': 1});
      expect(service.today.totalEvents, 6);
    });

    test('AT: mở lại app (service mới trên cùng storage) không nhân đôi',
        () async {
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'apple');
      await service.record(LearningActivityKind.readDocument,
          sourceKey: 'doc-1', at: DateTime(2026, 9, 14, 9));
      final writesBeforeRestart = storage.writeCount;

      final restarted =
          LearningActivityService(storage: storage, clock: () => now);
      addTearDown(restarted.dispose);
      await restarted.ready;

      expect(restarted.today.countOf(LearningActivityKind.vocabulary), 1);
      expect(restarted.streak(now: now), 2);
      // Nạp lại không ghi thêm (không "event hóa" mỗi lần mở app).
      expect(storage.writeCount, writesBeforeRestart);

      // Cùng một hành động được kích hoạt lại sau khi mở app → vẫn không tăng.
      expect(
        await restarted.record(LearningActivityKind.vocabulary,
            sourceKey: 'apple'),
        isFalse,
      );
      expect(restarted.today.countOf(LearningActivityKind.vocabulary), 1);
      expect(restarted.streak(now: now), 2);
    });

    test('restart giữ nguyên dữ liệu nhiều ngày và mốc 7 ngày', () async {
      for (var offset = 0; offset < 3; offset++) {
        await service.record(LearningActivityKind.learnByHeart,
            sourceKey: 'lhb-$offset', at: DateTime(2026, 9, 15 - offset, 9));
      }

      final restarted =
          LearningActivityService(storage: storage, clock: () => now);
      addTearDown(restarted.dispose);
      await restarted.ready;

      final snapshot = restarted.snapshot(now: now);
      expect(snapshot.streak, 3);
      expect(snapshot.activeDaysInWindow, 3);
      expect(snapshot.recentDays.last.countOf(LearningActivityKind.learnByHeart),
          1);
      expect(
        snapshot.recentDays[4].countOf(LearningActivityKind.learnByHeart),
        1,
      );
    });

    test('payload hỏng hoặc rỗng thì bắt đầu sạch, không crash', () async {
      storage.payload = '{{{ not json';
      final broken =
          LearningActivityService(storage: storage, clock: () => now);
      addTearDown(broken.dispose);
      await broken.ready;

      expect(broken.isLoaded, isTrue);
      expect(broken.today.isActive, isFalse);
      expect(broken.streak(now: now), 0);

      await broken.record(LearningActivityKind.vocabulary, sourceKey: 'apple');
      expect(broken.today.countOf(LearningActivityKind.vocabulary), 1);
    });

    test('bỏ kind lạ trong payload cũ thay vì crash', () async {
      storage.payload = jsonEncode({
        'v': 1,
        'days': {
          '2026-09-15': {'vocab': 2, 'kind_tuong_lai': 9},
        },
        'keys': {
          '2026-09-15': ['vocab|apple'],
        },
      });
      final upgraded =
          LearningActivityService(storage: storage, clock: () => now);
      addTearDown(upgraded.dispose);
      await upgraded.ready;

      expect(upgraded.today.countOf(LearningActivityKind.vocabulary), 2);
      expect(upgraded.today.totalEvents, 2);
      expect(upgraded.streak(now: now), 1);
    });

    test('dọn dữ liệu: khoá chống trùng ngày cũ bị bỏ, số liệu ngày cũ giữ lại',
        () async {
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'old', at: DateTime(2026, 9, 10, 9));
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'new', at: now);

      final payload =
          jsonDecode(storage.payload!) as Map<String, dynamic>;
      final keys = payload['keys'] as Map<String, dynamic>;
      final days = payload['days'] as Map<String, dynamic>;

      expect(keys.keys, contains('2026-09-15'));
      expect(keys.keys, isNot(contains('2026-09-10')));
      expect(days.keys, contains('2026-09-10'));
      expect(
        service.activityOn(DateTime(2026, 9, 10, 9))
            .countOf(LearningActivityKind.vocabulary),
        1,
      );
    });

    test('sự kiện cũ hơn retentionDays bị dọn ngay, không phình dữ liệu',
        () async {
      final tooOld = DateTime(2025, 1, 1, 9);
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'ancient', at: tooOld);

      final payload =
          jsonDecode(storage.payload!) as Map<String, dynamic>;
      final days = payload['days'] as Map<String, dynamic>;
      expect(days, isEmpty);
      expect(service.activityOn(tooOld).isActive, isFalse);
    });

    test('stableSourceKey ổn định giữa các lần gọi', () {
      final first = LearningActivityService.stableSourceKey('Hello world|vi');
      final second = LearningActivityService.stableSourceKey('Hello world|vi');
      final other = LearningActivityService.stableSourceKey('Hello world|en');

      expect(first, second);
      expect(first, isNot(other));
      expect(first.length, 8);
    });
  });

  group('AppUITranslations — chrome của thẻ có bản dịch (rule #5)', () {
    test('mọi nhãn chrome mới của thẻ Nhịp điệu học tập đều có trong catalog',
        () {
      const labels = [
        'NHỊP ĐIỆU HỌC TẬP',
        '7 ngày qua',
        'Hôm nay chưa có hoạt động học',
        'Đọc tài liệu hoặc lưu một từ để bắt đầu',
        '2 ngày liên tiếp',
        '12 phút đọc',
        '3 tài liệu',
        '5 từ',
        '2 lượt ôn',
        '1 lượt shadowing',
        '4 câu đã dịch',
        '2/7 ngày có học',
      ];

      final missing = labels
          .where((label) => !AppUITranslations.containsSource(label))
          .toList();
      expect(
        missing,
        isEmpty,
        reason: 'Nhãn chrome chưa được phân loại trong catalog i18n: $missing',
      );

      // Locale ≠ vi phải ra English, không được rơi về tiếng Việt.
      expect(AppUITranslations.translate('7 ngày qua', 'en'), 'Last 7 days');
      expect(AppUITranslations.translate('12 phút đọc', 'en'), '12 min read');
      expect(
        AppUITranslations.translate('2 ngày liên tiếp', 'en'),
        '2-day streak',
      );
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Thẻ "Nhịp điệu học tập"
// ─────────────────────────────────────────────────────────────────────────────

void defineFocusStreakCardTests() {
  group('FocusStreakCard — số liệu thật từ FocusProvider', () {
    late InMemoryLearningActivityStorage storage;
    late DateTime now;
    late LearningActivityService service;
    late FocusProvider provider;

    setUp(() async {
      storage = InMemoryLearningActivityStorage();
      now = DateTime(2026, 9, 15, 20, 0);
      service = LearningActivityService(storage: storage, clock: () => now);
      provider = FocusProvider(service: service);
      await service.ready;
    });

    tearDown(() {
      provider.dispose();
      service.dispose();
    });

    Future<void> pumpCard(WidgetTester tester, Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ChangeNotifierProvider<FocusProvider>.value(
            value: provider,
            child: const Scaffold(
              body: SingleChildScrollView(child: FocusStreakCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('không có hoạt động → empty state + streak 0 (không số giả)',
        (tester) async {
      await pumpCard(tester, const Locale('en'));

      expect(find.text('No learning activity today yet'), findsOneWidget);
      expect(
        find.text('Read a document or save a word to get started'),
        findsOneWidget,
      );
      expect(find.text('0-day streak'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
    });

    testWidgets('có hoạt động hôm nay → hiện số thật, streak + 7 ngày',
        (tester) async {
      await service.record(LearningActivityKind.readingMinutes,
          sourceKey: 'doc-1|20:00', amount: 12);
      await service.record(LearningActivityKind.readDocument,
          sourceKey: 'doc-1');
      await service.record(LearningActivityKind.vocabulary, sourceKey: 'apple');
      await service.record(LearningActivityKind.vocabulary, sourceKey: 'pear');
      await service.record(LearningActivityKind.vocabulary, sourceKey: 'plum');
      await service.record(LearningActivityKind.learnByHeart,
          sourceKey: 'lhb-1', at: DateTime(2026, 9, 14, 9));

      await pumpCard(tester, const Locale('en'));

      expect(find.text('2-day streak'), findsOneWidget);
      expect(find.text('12 min read'), findsOneWidget);
      expect(find.text('1 documents'), findsOneWidget);
      expect(find.text('3 words'), findsOneWidget);
      expect(find.text('2/7 days with activity'), findsOneWidget);
      expect(find.text('No learning activity today yet'), findsNothing);
    });

    testWidgets('locale vi → chrome tiếng Việt (nguồn)', (tester) async {
      await service.record(LearningActivityKind.readingMinutes,
          sourceKey: 'doc-1|20:00', amount: 7);
      await service.record(LearningActivityKind.vocabulary, sourceKey: 'apple');

      await pumpCard(tester, const Locale('vi'));

      expect(find.text('1 ngày liên tiếp'), findsOneWidget);
      expect(find.text('7 phút đọc'), findsOneWidget);
      expect(find.text('1 từ'), findsOneWidget);
      expect(find.text('7 ngày qua'), findsOneWidget);
    });

    testWidgets('sự kiện của ngày khác không bị tính vào hôm nay',
        (tester) async {
      await service.record(LearningActivityKind.vocabulary,
          sourceKey: 'yesterday', at: DateTime(2026, 9, 14, 9));

      await pumpCard(tester, const Locale('en'));

      // Hôm nay trống → empty state; chuỗi 1 ngày vẫn giữ.
      expect(find.text('No learning activity today yet'), findsOneWidget);
      expect(find.text('1-day streak'), findsOneWidget);
      expect(find.text('1 words'), findsNothing);
    });
  });
}
