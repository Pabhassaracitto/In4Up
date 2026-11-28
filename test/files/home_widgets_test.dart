// test/files/home_widgets_test.dart — PLAN-050 · ADR-0040
//
// Bộ kiểm thử tự động cho hệ thống Home Screen Widgets, App Icon Shortcuts,
// Quick Settings Tiles và Bộ định tuyến hành động 1-chạm (`in4up://action|nav`).
//
// Đặt trong `test/files/` để cổng CI `app_analyze.yml` (`flutter test test/files`)
// luôn chạy tự động trên mọi lần đẩy nhánh `arena/**`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/dict_deep_link.dart';
import 'package:in4up/features/home_widgets/models/widget_action_link.dart';
import 'package:in4up/features/home_widgets/models/widget_quick_action.dart';
import 'package:in4up/features/home_widgets/models/widget_snapshot.dart';
import 'package:in4up/features/home_widgets/services/widget_action_router.dart';
import 'package:in4up/features/home_widgets/services/widget_snapshot_builder.dart';
import 'package:in4up/models/learning_activity.dart';
import 'package:in4up/models/word_entry.dart';

class _FakeWidgetActionHost implements WidgetActionHost {
  bool ready = true;
  final List<WidgetActionRequest> received = <WidgetActionRequest>[];

  @override
  bool get isReady => ready;

  @override
  Future<void> dispatchWidgetAction(WidgetActionRequest request) async {
    received.add(request);
  }
}

// Bộ ký tự CHỈ tồn tại trong tiếng Việt (khớp `locale_chrome_no_vietnamese_test.dart`
// và `tool/lang_ui_inventory.py`), không bắt nhầm dấu tiếng Pháp (`Compréhension`).
final RegExp _vietnameseDiacriticRegex = RegExp(
  r'[đĐơƠưƯảạằắẳẵặầấẩẫậẻẽẹềếểễệỉĩịỏọồốổỗộờớởỡợủũụừứửữựỳỷỹỵ]',
);

LearningStreakSnapshot _sampleStreak({
  int streak = 7,
  bool activeToday = true,
}) {
  final days = <LearningDayActivity>[
    LearningDayActivity(
      dayKey: '2026-11-19',
      counts: const <LearningActivityKind, int>{
        LearningActivityKind.vocabulary: 3,
      },
    ),
    LearningDayActivity(
      dayKey: '2026-11-20',
    ),
    LearningDayActivity(
      dayKey: '2026-11-21',
      counts: const <LearningActivityKind, int>{
        LearningActivityKind.readingMinutes: 10,
      },
    ),
    LearningDayActivity(
      dayKey: '2026-11-22',
      counts: const <LearningActivityKind, int>{
        LearningActivityKind.shadowing: 4,
      },
    ),
    LearningDayActivity(
      dayKey: '2026-11-23',
      counts: const <LearningActivityKind, int>{
        LearningActivityKind.learnByHeart: 5,
      },
    ),
    LearningDayActivity(
      dayKey: '2026-11-24',
      counts: const <LearningActivityKind, int>{
        LearningActivityKind.readingMinutes: 15,
      },
    ),
    LearningDayActivity(
      dayKey: '2026-11-25',
      counts: const <LearningActivityKind, int>{
        LearningActivityKind.readingMinutes: 18,
        LearningActivityKind.vocabulary: 6,
      },
    ),
  ];
  return LearningStreakSnapshot(
    streak: streak,
    activeToday: activeToday,
    today: activeToday ? days.last : LearningDayActivity.empty('2026-11-25'),
    recentDays: days,
  );
}

void main() {
  group('PLAN-050 · WidgetActionDeepLink URI parser & security', () {
    test('parses all 1-tap actions and query flags across schemes', () {
      final dictBlank = WidgetActionDeepLink.parse('in4up://dict');
      expect(dictBlank?.kind, WidgetActionKind.dictSearch);
      expect(dictBlank?.autoFocus, isTrue);

      final voice = WidgetActionDeepLink.parse(
        'in4up://action/voice_capture?autostart=1&src=widget',
      );
      expect(voice?.kind, WidgetActionKind.voiceCapture);
      expect(voice?.autoStart, isTrue);
      expect(voice?.source, 'widget');

      final ocr = WidgetActionDeepLink.parse('i4u://action/ocr_scan?src=qs');
      expect(ocr?.kind, WidgetActionKind.ocrScan);
      expect(ocr?.source, 'qs');

      final screenTranslate = WidgetActionDeepLink.parse(
        'in4up://action/screen_translate?src=qs_tile',
      );
      expect(screenTranslate?.kind, WidgetActionKind.screenTranslate);

      final reviewLhb = WidgetActionDeepLink.parse(
        'in4up://action/review_due?mode=lhb&src=widget',
      );
      expect(reviewLhb?.kind, WidgetActionKind.reviewDue);
      expect(reviewLhb?.reviewMode, WidgetReviewMode.learnByHeart);

      final resumeListen = WidgetActionDeepLink.parse(
        'https://in4up.app/action/resume_listen?autoplay=1&src=widget',
      );
      expect(resumeListen?.kind, WidgetActionKind.resumeListen);
      expect(resumeListen?.autoPlay, isTrue);

      final resumeRead = WidgetActionDeepLink.parse(
        'in4up://action/resume_read?src=widget',
      );
      expect(resumeRead?.kind, WidgetActionKind.resumeRead);

      final settings = WidgetActionDeepLink.parse(
        'in4up://action/widget_settings',
      );
      expect(settings?.kind, WidgetActionKind.widgetSettings);
    });

    test('parses studio navigation targets and rejects unknown targets', () {
      for (final target in WidgetStudioTarget.values) {
        final req = WidgetActionDeepLink.parse(
          'in4up://nav/studio?target=${target.wireName}&src=widget',
        );
        expect(req?.kind, WidgetActionKind.openStudio);
        expect(req?.studioTarget, target);
      }

      expect(
        WidgetActionDeepLink.parse('in4up://nav/studio?target=root_shell_exec'),
        isNull,
      );
      expect(
        WidgetActionDeepLink.parse('in4up://action/delete_all_files'),
        isNull,
      );
      expect(
        WidgetActionDeepLink.parse('in4up://action/${'a' * 600}'),
        isNull,
      );
    });

    test('preserves 100% compatibility with DictDeepLink word & file URIs', () {
      // Explicit word query must NOT be intercepted by WidgetActionDeepLink.
      expect(
        WidgetActionDeepLink.parse('in4up://dict?w=mindfulness'),
        isNull,
      );
      expect(
        DictDeepLink.parse('in4up://dict?w=mindfulness')?.value,
        'mindfulness',
      );

      // Explicit file open URI must NOT be intercepted by WidgetActionDeepLink.
      expect(
        WidgetActionDeepLink.parse('in4up://open?path=/storage/book.pdf'),
        isNull,
      );
      expect(
        DictDeepLink.parse('in4up://open?path=/storage/book.pdf')?.kind,
        DictDeepLinkKind.file,
      );
    });
  });

  group('PLAN-050 · WidgetActionRouter cold-start queue & dedup', () {
    test('queues cold-start actions before host attaches and suppresses duplicates', () async {
      var now = DateTime.utc(2026, 11, 25, 10, 0, 0);
      final router = WidgetActionRouter(clock: () => now);
      final host = _FakeWidgetActionHost()..ready = false;

      expect(
        router.tryHandleRawUri('in4up://action/voice_capture?autostart=1'),
        isTrue,
      );
      // Duplicate intent within 300ms (e.g. launcher + onNewIntent double fire)
      now = now.add(const Duration(milliseconds: 300));
      expect(
        router.tryHandleRawUri('in4up://action/voice_capture?autostart=1'),
        isTrue,
      );
      expect(router.pendingCount, 1);

      // Distinct action queued right behind it
      expect(router.tryHandleRawUri('in4up://action/ocr_scan'), isTrue);
      expect(router.pendingCount, 2);

      // Attach ready host → drains in exact FIFO order
      host.ready = true;
      router.attachHost(host);
      await Future<void>.delayed(Duration.zero);

      expect(host.received.length, 2);
      expect(host.received[0].kind, WidgetActionKind.voiceCapture);
      expect(host.received[1].kind, WidgetActionKind.ocrScan);

      // Tapping same button 2 seconds later is allowed again
      now = now.add(const Duration(seconds: 2));
      router.tryHandleRawUri('in4up://action/voice_capture?autostart=1');
      await Future<void>.delayed(Duration.zero);
      expect(host.received.length, 3);
    });
  });

  group('PLAN-050 · Quick Bar customization & platform fallback', () {
    test('normalizes 3 quick bar slots and filters Android-only Screen Translate on iOS/Desktop', () {
      final androidDefaults = WidgetQuickActionId.defaultQuickBarSlots(
        isAndroid: true,
      );
      expect(androidDefaults, <WidgetQuickActionId>[
        WidgetQuickActionId.voiceCapture,
        WidgetQuickActionId.ocrScan,
        WidgetQuickActionId.screenTranslate,
      ]);

      final nonAndroidNormalized = WidgetQuickActionId.normalizeSlots(
        const <String>['voice_capture', 'screen_translate'],
        isAndroid: false,
      );
      expect(nonAndroidNormalized.length, 3);
      expect(
        nonAndroidNormalized.contains(WidgetQuickActionId.screenTranslate),
        isFalse,
      );
      expect(
        nonAndroidNormalized.contains(WidgetQuickActionId.aiChat),
        isTrue,
      );
    });
  });

  group('PLAN-050 · WidgetSnapshotBuilder (SM-2 3-skill rule, <8KB cap, Rule #5 i18n)', () {
    test('keeps 3 SM-2 skills strictly separate and enforces < 8 KB JSON budget', () {
      final heavyWords = List<WordEntry>.generate(
        25,
        (index) => WordEntry(
          id: 'word_$index',
          word: 'sati_$index',
          phonetic: 'ˈsʌti',
          meaning: 'Chánh niệm tỉnh giác sâu sắc ' * 12,
          example: 'Satiปัฏฐาน 4 — câu ví dụ rất dài để thử giới hạn bộ nhớ ' * 10,
          understand: 0.2,
          listen: 0.65,
          read: 0.95,
        ),
      );

      final snapshot = WidgetSnapshotBuilder.build(
        localeCode: 'vi',
        streakSnapshot: _sampleStreak(),
        dueWords: heavyWords,
        fallbackWords: heavyWords,
        dueLhbCount: 3,
        listenSource: const WidgetListenSourceInput(
          title: 'Pháp thoại Buổi Sáng',
          position: Duration(minutes: 12, seconds: 34),
          duration: Duration(minutes: 45),
          isPlaying: true,
        ),
        readSource: const WidgetReadSourceInput(
          title: 'Nikaya_Tap_1.pdf',
          currentUnit: 42,
          totalUnits: 320,
          isPdf: true,
        ),
        isAndroid: true,
        nowEpochMs: 1764064800000,
      );

      final encoded = snapshot.toEncodedJson();
      final utf8Bytes = utf8.encode(encoded);
      expect(utf8Bytes.length, lessThanOrEqualTo(WidgetSnapshot.maxEncodedBytes));

      final decoded = WidgetSnapshot.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.srs.dueVocabCount, 25);
      expect(decoded.srs.dueLhbCount, 3);
      expect(decoded.srs.deck, isNotEmpty);

      // Golden Rule #2: 3 skills remain distinct (0.2 vs 0.65 vs 0.95)!
      final firstCard = decoded.srs.deck.first;
      expect(firstCard.understandScore, closeTo(0.2, 0.001));
      expect(firstCard.listenScore, closeTo(0.65, 0.001));
      expect(firstCard.readScore, closeTo(0.95, 0.001));
      expect(firstCard.understandDots, 1);
      expect(firstCard.listenDots, 2);
      expect(firstCard.readDots, 3);
    });

    test('Rule #5: zero Vietnamese chrome leak across all priority & fallback non-vi locales', () {
      const localesToVerify = <String>[
        'en',
        'hi',
        'zh',
        'zh_TW',
        'si',
        'my',
        'th',
        'ja',
        'fr',
        'de',
      ];

      final userCard = WordEntry(
        id: 'u1',
        word: 'impermanence',
        meaning: 'vô thường (ghi chú riêng của người dùng)',
        understand: 0.8,
        listen: 0.4,
        read: 0.1,
      );

      for (final locale in localesToVerify) {
        final snap = WidgetSnapshotBuilder.build(
          localeCode: locale,
          streakSnapshot: _sampleStreak(),
          dueWords: <WordEntry>[userCard],
          fallbackWords: <WordEntry>[userCard],
          dueLhbCount: 2,
          listenSource: const WidgetListenSourceInput(
            title: 'Morning Audio',
            isPlaying: false,
          ),
          readSource: const WidgetReadSourceInput(
            title: 'Book.pdf',
            currentUnit: 12,
            totalUnits: 100,
            isPdf: true,
          ),
          isAndroid: true,
          nowEpochMs: 1764064800000,
        );

        final chromeValues = <String>[
          snap.labels.searchHint,
          snap.labels.continueHeader,
          snap.labels.continueEmptyHint,
          snap.labels.openReadLabel,
          snap.labels.openListenLabel,
          snap.labels.gardenHeader,
          snap.labels.srsEmptyHint,
          snap.labels.flipShowLabel,
          snap.labels.flipHideLabel,
          snap.labels.nextCardLabel,
          snap.labels.reviewNowLabel,
          snap.labels.streakHeader,
          snap.labels.skillUnderstand,
          snap.labels.skillListen,
          snap.labels.skillRead,
          snap.labels.dueCountBadge,
          snap.streak.headline,
          snap.streak.todaySummary,
          snap.streak.weekWindowSummary,
          snap.streak.ctaLabel,
          snap.resume.listen!.subtitle,
          snap.resume.read!.subtitle,
          for (final slot in snap.quickSlots) slot.label,
        ];

        for (final value in chromeValues) {
          expect(
            _vietnameseDiacriticRegex.hasMatch(value),
            isFalse,
            reason: 'Locale "$locale" leaked Vietnamese chrome: "$value"',
          );
        }

        // User-owned vocabulary meaning MUST stay untouched!
        expect(
          snap.srs.deck.first.meaning,
          'vô thường (ghi chú riêng của người dùng)',
        );
      }
    });
  });

  group('PLAN-050 · Native Android/iOS manifest, RemoteViews & i18n resource gates', () {
    test('AndroidManifest, RemoteViews XMLs, strings_widgets.xml and iOS shortcuts satisfy all safety contracts', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('com.in4up.widgets.QuickBarWidgetProvider'));
      expect(
        manifest,
        contains('com.in4up.widgets.ContinueLearningWidgetProvider'),
      );
      expect(manifest, contains('com.in4up.widgets.FlashcardSrsWidgetProvider'));
      expect(manifest, contains('com.in4up.widgets.StreakPulseWidgetProvider'));
      expect(manifest, contains('com.in4up.widgets.ScreenTranslateTileService'));
      expect(manifest, contains('com.in4up.widgets.VoiceCaptureTileService'));
      expect(manifest, contains('android:resource="@xml/shortcuts"'));
      expect(manifest, contains('android:host="action"'));
      expect(manifest, contains('android:host="nav"'));

      // Default Android values/strings_widgets.xml MUST be English (zero Vietnamese)
      final defaultStrings = File(
        'android/app/src/main/res/values/strings_widgets.xml',
      ).readAsStringSync();
      expect(_vietnameseDiacriticRegex.hasMatch(defaultStrings), isFalse);

      // RemoteViews layouts MUST NOT use bare <View> (API 31+ only) or app:* namespace
      final layoutFiles = <String>[
        'android/app/src/main/res/layout/widget_quick_bar.xml',
        'android/app/src/main/res/layout/widget_continue_learning.xml',
        'android/app/src/main/res/layout/widget_flashcard_srs.xml',
        'android/app/src/main/res/layout/widget_streak_pulse.xml',
      ];
      for (final path in layoutFiles) {
        final xml = File(path).readAsStringSync();
        expect(
          RegExp(r'<\s*View\b').hasMatch(xml),
          isFalse,
          reason: '$path must not use bare <View> in RemoteViews (minSdk 24)',
        );
        expect(
          xml.contains('xmlns:app=') || xml.contains('app:'),
          isFalse,
          reason: '$path must not use AppCompat app:* attributes in RemoteViews',
        );
      }

      // iOS Info.plist & AppDelegate.swift declare Home Screen Quick Actions
      final iosPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(iosPlist, contains('UIApplicationShortcutItems'));
      expect(iosPlist, contains('com.in4up.shortcut.dict_search'));

      final iosDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(iosDelegate, contains('performActionFor shortcutItem'));
    });
  });
}
