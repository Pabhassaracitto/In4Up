import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/screens/memory_mode/controllers/memory_controller.dart';
import 'package:in4up/screens/memory_mode/models/garden_rating.dart';
import 'package:in4up/screens/memory_mode/models/memory_item.dart';
import 'package:in4up/screens/memory_mode/models/memory_stage.dart';
import 'package:in4up/screens/memory_mode/widgets/memory_garden_view.dart';
import 'package:in4up/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('garden_rating');
    Hive.init(temp.path);
    await Hive.openBox('settings');
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('four buttons use the existing failed and correct schedules', () {
    final now = DateTime.now();
    final item = MemoryItem(
      id: 'one', word: 'one', createdAt: now,
      stage: MemoryStage.tree,
      nextReviewAt: now.add(const Duration(hours: 30)),
    );
    final again = GardenRating.again.apply(item);
    final forgot = GardenRating.forgot.apply(item);
    final good = GardenRating.good.apply(item);
    final easy = GardenRating.easy.apply(item);
    int minutes(MemoryItem value) =>
        value.nextReviewAt!.difference(value.lastReviewedAt!).inMinutes;
    expect(again.incorrectCount, item.incorrectCount + 1);
    expect(forgot.incorrectCount, item.incorrectCount + 1);
    expect(minutes(again), lessThan(30 * 60));
    expect(minutes(easy), greaterThan(30 * 60));
    // ADR-0001: no new scheduler. The two failure labels both call
    // markIncorrect; Good/Easy both call markCorrect, as in flashcards.
    expect(minutes(again), minutes(forgot));
    expect(minutes(good), minutes(easy));
    expect(minutes(good), greaterThan(minutes(forgot)));
    expect(good.stage, easy.stage);
  });

  test('new labels and feedback have priority translations', () {
    for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
      for (final text in [
        'Lại', 'Quên', 'Ổn', 'Giỏi', 'Nhấn giữ một từ để chấm điểm',
        'Ôn lại sau 6 ngày', 'Ôn lại sau 1 giờ',
      ]) {
        expect(AppUITranslations.translate(text, locale), isNot(text),
            reason: '$locale: $text');
      }
    }
  });

  testWidgets('first visit hint and long press show four ratings', (tester) async {
    await Hive.box('settings').delete('garden_onboarding_seen_v1');
    expect(StorageService().getGardenOnboardingSeen(), isFalse);
    final controller = MemoryController();
    while (!controller.isLoaded) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(controller.addWord(word: 'garden-test-word'), isTrue);
    Widget garden() => ChangeNotifierProvider<MemoryController>.value(
      value: controller,
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: MemoryGardenView()),
      ),
    );
    await tester.pumpWidget(garden());
    await tester.pump();
    expect(find.text('Nhấn giữ một từ để chấm điểm'), findsOneWidget);
    expect(StorageService().getGardenOnboardingSeen(), isTrue);
    await tester.longPress(find.text('garden-test-word'));
    await tester.pumpAndSettle();
    expect(find.byType(ElevatedButton), findsNWidgets(4));
    for (final label in ['Lại', 'Quên', 'Ổn', 'Giỏi']) {
      expect(find.text(label), findsOneWidget);
    }
    final original = controller.allItems.single;
    await tester.tap(find.text('Giỏi'));
    await tester.pumpAndSettle();
    expect(controller.allItems.single.totalReviews, original.totalReviews + 1);
    expect(controller.allItems.single.nextReviewAt, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(garden());
    await tester.pump();
    expect(find.text('Nhấn giữ một từ để chấm điểm'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
