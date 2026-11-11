// test/srs/rate_before_flip_test.dart
//
// PSRC-197 — SRS Cram Hard: cho chấm điểm không cần lật thẻ.
//
// Ba thứ được khoá lại ở đây, đúng thứ mà audit v1.27.0 bắt được:
//   1. Quyết định "chấm được chưa?" là MỘT hàm thuần dùng chung cho nút bấm
//      và cho vuốt (`RatingGate`) — không còn hai chỗ chặn lệch nhau.
//   2. Controller mặc định CHO chấm trước khi lật, tắt được, và chốt cuối
//      trong `gradeCurrentCard` vẫn tôn trọng cài đặt.
//   3. Trên màn hình thật: thẻ chưa lật vẫn thấy đủ 4 nút, bấm "Nhớ" là ghi
//      nhận + sang thẻ kế, không hiện snackbar "phải lật thẻ".
//
// Test chạy trên host VM: SharedPreferences được mock, không mở Hive thật;
// `MemoryController` chỉ chạm storage qua SharedPreferences.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/screens/memory_mode/controllers/memory_controller.dart';
import 'package:in4up/screens/memory_mode/models/memory_stage.dart';
import 'package:in4up/screens/memory_mode/models/rating_gate.dart';
import 'package:in4up/screens/memory_mode/models/review_session.dart';
import 'package:in4up/screens/memory_mode/widgets/flashcard_presenter.dart'
    show FlashcardPresenter;
// Timer ngầm đã tách sang file riêng để test được logic ngưỡng thời gian.
import 'package:in4up/screens/memory_mode/widgets/swipe_grade_resolver.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _flipGateSnack = '👆 Nhấn lật thẻ trước khi đánh giá';
const _beforeFlipHint =
    'Chấm được ngay khi chưa lật — hoặc tap thẻ để xem nghĩa';

Future<MemoryController> _loadedController({WidgetTester? tester}) async {
  final controller = MemoryController();
  var waited = Duration.zero;
  while (!controller.isLoaded) {
    const delay = Duration(milliseconds: 5);
    waited += delay;
    if (waited > const Duration(seconds: 5)) {
      fail('MemoryController không load xong sau 5s (SharedPreferences treo?)');
    }
    if (tester != null) {
      // Trong testWidgets thời gian là FakeAsync ⇒ phải runAsync mới trôi.
      await tester.runAsync(() => Future<void>.delayed(delay));
    } else {
      await Future<void>.delayed(delay);
    }
  }
  return controller;
}

Widget _presenter(MemoryController controller) {
  // `_BackFace` (chỉ dựng khi thẻ ĐÃ lật) đọc VocabularyProvider; cấp một
  // instance rỗng để test lật thẻ không cần Hive.
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MemoryController>.value(value: controller),
      ChangeNotifierProvider<VocabularyProvider>(
        create: (_) => VocabularyProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: FlashcardPresenter()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Trước MỖI test: kho rỗng ⇒ `startReview(cram)` chỉ có thẻ vừa thêm, hàng
  // chờ xác định (không phụ thuộc từ của test trước + xáo trộn ngẫu nhiên).
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RatingGate — một quyết định cho nút bấm lẫn vuốt', () {
    test('mặc định: chấm được khi thẻ chưa lật', () {
      expect(
        RatingGate.allowsRating(isFlipped: false, allowRateBeforeFlip: true),
        isTrue,
      );
      for (final dir in [
        SwipeDirection.left,
        SwipeDirection.right,
        SwipeDirection.up,
      ]) {
        expect(
          RatingGate.allowsSwipe(
            isFlipped: false,
            direction: dir,
            allowRateBeforeFlip: true,
          ),
          isTrue,
          reason: 'hướng $dir phải chấm được khi chưa lật (PSRC-197)',
        );
      }
    });

    test('tắt cài đặt: giữ kỷ luật lật-trước-khi-chấm', () {
      expect(
        RatingGate.allowsRating(isFlipped: false, allowRateBeforeFlip: false),
        isFalse,
      );
      for (final dir in [
        SwipeDirection.left,
        SwipeDirection.right,
        SwipeDirection.up,
      ]) {
        expect(
          RatingGate.allowsSwipe(
            isFlipped: false,
            direction: dir,
            allowRateBeforeFlip: false,
          ),
          isFalse,
        );
      }
      // Đã lật thì mọi hướng đều hợp lệ trở lại.
      expect(
        RatingGate.allowsSwipe(
          isFlipped: true,
          direction: SwipeDirection.left,
          allowRateBeforeFlip: false,
        ),
        isTrue,
      );
    });

    test('vuốt xuống (hoãn học) luôn hợp lệ — không phải câu trả lời', () {
      for (final flipped in [false, true]) {
        for (final allow in [false, true]) {
          expect(
            RatingGate.allowsSwipe(
              isFlipped: flipped,
              direction: SwipeDirection.down,
              allowRateBeforeFlip: allow,
            ),
            isTrue,
            reason: 'flipped=$flipped allow=$allow',
          );
        }
      }
    });
  });

  group('SwipeGradeResolver — ngưỡng thời gian của timer ngầm', () {
    test('phải là >3s mới thành Good (phụ thuộc: chỉ khác 3000ms)', () {
      // Bản gốc dùng `<= 3` trên số GIÂY nguyên ⇒ 3s vẫn là Easy. Chỉ đổi
      // sang so sánh mili-giây; test này chỉ ra chỗ nhạy cảm nếu ai đó đổi
      // ngưỡng (đổi ngưỡng thì sửa test này CHỦ ĐỘNG, không phải vô tình).
      expect(
        SwipeGradeResolver.resolve(
          SwipeDirection.right,
          const Duration(milliseconds: 3000),
        ),
        ReviewGrade.easy,
      );
      expect(
        SwipeGradeResolver.resolve(
          SwipeDirection.right,
          const Duration(milliseconds: 3100),
        ),
        ReviewGrade.good,
      );
    });

    test('trái: ≤2s là Hard, lâu hơn là Forgot; lên/xuống cố định', () {
      expect(
        SwipeGradeResolver.resolve(
          SwipeDirection.left,
          const Duration(milliseconds: 2000),
        ),
        ReviewGrade.hard,
      );
      expect(
        SwipeGradeResolver.resolve(
          SwipeDirection.left,
          const Duration(seconds: 9),
        ),
        ReviewGrade.forgot,
      );
      expect(
        SwipeGradeResolver.resolve(SwipeDirection.up, Duration.zero),
        ReviewGrade.retired,
      );
      expect(
        SwipeGradeResolver.resolve(SwipeDirection.down, Duration.zero),
        ReviewGrade.snoozed,
      );
    });
  });

  group('MemoryController — cài đặt + chốt cuối', () {
    test('mặc định cho phép; setAllowRateBeforeFlip đổi trạng thái', () async {
      final controller = await _loadedController();
      addTearDown(controller.dispose);
      expect(controller.allowRateBeforeFlip, isTrue);
      expect(
        controller.canRateCurrentCard,
        isTrue,
        reason: 'chưa lật + mặc định cho phép ⇒ chấm được',
      );

      controller.setAllowRateBeforeFlip(false);
      expect(controller.allowRateBeforeFlip, isFalse);
      expect(controller.canRateCurrentCard, isFalse);
      controller.setAllowRateBeforeFlip(true);
      expect(controller.allowRateBeforeFlip, isTrue);
    });

    test('gradeCurrentCard chấm được thẻ chưa lật (chế độ nhồi)', () async {
      final controller = await _loadedController();
      addTearDown(controller.dispose);
      expect(controller.addWord(word: 'psrc197', meaning: 'ghi chú'), isTrue);

      controller.startReview(mode: ReviewMode.cram);
      expect(controller.currentCard, isNotNull);
      expect(controller.isCardFlipped, isFalse);
      expect(controller.canRateCurrentCard, isTrue);

      await controller.gradeCurrentCard(ReviewGrade.good);

      final item = controller.allItems.firstWhere((i) => i.word == 'psrc197');
      expect(item.totalReviews, greaterThan(0),
          reason: 'bấm Nhớ khi chưa lật phải ghi vào lịch ôn thật');
      // KHÔNG khẳng định correctCount == 1: `markCorrect` có thể thăng giai
      // đoạn và reset bộ đếm (MemoryStage.requiredCorrectReviews) — đó là
      // hành vi engine SM-2 sẵn có (ADR-0001), không phải điều PSRC-197 đổi.
      expect(item.lastReviewedAt, isNotNull);
      expect(item.nextReviewAt, isNotNull);
      expect(item.stage.index,
          greaterThanOrEqualTo(MemoryStage.seed.index));
    });

    test('tắt cài đặt ⇒ gradeCurrentCard không ghi gì khi thẻ chưa lật',
        () async {
      final controller = await _loadedController();
      addTearDown(controller.dispose);
      expect(controller.addWord(word: 'psrc197b', meaning: 'ghi chú'), isTrue);

      controller.setAllowRateBeforeFlip(false);
      controller.startReview(mode: ReviewMode.cram);
      expect(controller.isCardFlipped, isFalse);
      expect(controller.canRateCurrentCard, isFalse);

      await controller.gradeCurrentCard(ReviewGrade.good);
      final item = controller.allItems.firstWhere((i) => i.word == 'psrc197b');
      expect(item.totalReviews, 0);
      expect(controller.currentCardIndex, 0, reason: 'không được nhảy thẻ');
    });
  });

  group('FlashcardPresenter — UI trước khi lật', () {
    testWidgets('thẻ chưa lật: đủ 4 nút, bấm Nhớ là sang thẻ kế',
        (tester) async {
      final controller = await _loadedController(tester: tester);
      expect(controller.addWord(word: 'alphaword', meaning: 'một'), isTrue);
      expect(controller.addWord(word: 'betaword', meaning: 'hai'), isTrue);
      controller.startReview(mode: ReviewMode.cram);

      await tester.pumpWidget(_presenter(controller));
      await tester.pump();

      expect(controller.isCardFlipped, isFalse);
      for (final label in ['Quên', 'Khó', 'Nhớ', 'Dễ']) {
        // Khoanh theo ElevatedButton: mũi tên gợi ý hướng cũng vẽ chữ
        // "Quên"/"Nhớ" ở mép thẻ.
        expect(find.widgetWithText(ElevatedButton, label), findsOneWidget,
            reason: 'PSRC-197: nút "$label" phải có ngay khi chưa lật');
      }
      expect(find.text('🤔 Cố nhớ nghĩa rồi tap để lật'), findsNothing);
      expect(find.text(_beforeFlipHint), findsOneWidget);

      final firstCardId = controller.currentCard!.id;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Nhớ'));
      await tester.pumpAndSettle();

      expect(find.text(_flipGateSnack), findsNothing,
          reason: 'không được nhắc lật thẻ nữa');
      expect(controller.currentCard?.id, isNot(firstCardId),
          reason: 'chấm xong phải sang thẻ kế, không đứng yên');
      expect(controller.isCardFlipped, isFalse,
          reason: 'thẻ mới vẫn ở mặt trước — nghĩa vẫn ẩn');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('tắt cài đặt: quay lại đúng hành vi cũ (ẩn nút + nhắc lật)',
        (tester) async {
      final controller = await _loadedController(tester: tester);
      expect(controller.addWord(word: 'gammaword', meaning: 'ba'), isTrue);
      controller.setAllowRateBeforeFlip(false);
      controller.startReview(mode: ReviewMode.cram);

      await tester.pumpWidget(_presenter(controller));
      await tester.pump();

      expect(find.widgetWithText(ElevatedButton, 'Nhớ'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Quên'), findsNothing);
      expect(find.text('🤔 Cố nhớ nghĩa rồi tap để lật'), findsOneWidget);
      expect(find.text(_beforeFlipHint), findsNothing);

      // Lật thẻ → nút hiện lại như trước PSRC-197.
      controller.flipCard();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Nhớ'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      controller.dispose();
    });
  });

  group('i18n — chuỗi mới không rò tiếng Việt (rule #5)', () {
    const strings = [
      'Chấm điểm khi chưa lật thẻ',
      _beforeFlipHint,
      'Tap để lật · hoặc chấm luôn bên dưới',
    ];

    test('đủ bản dịch cho en + 4 locale T2 và 3 locale ưu tiên', () {
      for (final locale in [
        'en',
        'hi',
        'zh',
        'zh_TW',
        'si',
        'my',
        'th',
        'ja',
      ]) {
        for (final text in strings) {
          final translated = AppUITranslations.translate(text, locale);
          expect(translated, isNot(text),
              reason: '$locale chưa có bản dịch cho "$text"');
          expect(translated.trim(), isNotEmpty);
        }
      }
    });

    test('không locale nào rơi về tiếng Việt', () {
      final vietnamese = RegExp(r'[đĐơƠưƯ]|'
          r'[ảạằắẳẵặầấẩẫậ]|[ẻẽẹềếểễệ]|[ỉĩị]|'
          r'[ỏọồốổỗộờớởỡợ]|[ủũụừứửữự]|[ỳỷỹỵ]');
      for (final locale in [
        'en',
        'hi',
        'zh',
        'zh_TW',
        'si',
        'my',
        'th',
        'ja',
      ]) {
        for (final text in strings) {
          final translated = AppUITranslations.translate(text, locale);
          expect(vietnamese.hasMatch(translated), isFalse,
              reason: '$locale → "$translated"');
        }
      }
    });
  });
}
