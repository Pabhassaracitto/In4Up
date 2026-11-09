import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/widgets/voice_clone_section.dart';
import 'package:in4up/l10n/app_localizations.dart';

Widget _host(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: SingleChildScrollView(child: VoiceCloneSection()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voice messages interpolate data in every supported locale', () async {
    // A voice name is user content: it must remain unchanged, even when it
    // looks like another placeholder or contains Vietnamese characters.
    const voiceName = 'Giọng {mẹ}';
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.ttsCloneVoiceSamplesCount(12), contains('12'),
          reason: 'count missing for $locale');
      expect(l10n.ttsCloneVoiceSuccess(voiceName), contains(voiceName),
          reason: 'voice name changed for $locale');
      expect(l10n.ttsCloneVoiceRecordingError, isNotEmpty);
      expect(l10n.ttsCloneVoiceCreateError, isNotEmpty);
    }

    final bn = await AppLocalizations.delegate.load(const Locale('bn'));
    expect(bn.ttsCloneVoiceNeedSample,
        'No recordings found. Record at least one sample.');
    expect(bn.ttsCloneVoiceSuccess(voiceName),
        'Voice $voiceName created successfully!');
  });

  testWidgets('voice clone chrome and visible errors follow the app locale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    const permissionChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(recordChannel, (call) async => null);
    messenger.setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'requestPermissions') return <int, int>{7: 0};
      if (call.method == 'checkPermissionStatus') return 0;
      throw MissingPluginException(call.method);
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(recordChannel, null);
      messenger.setMockMethodCallHandler(permissionChannel, null);
    });

    await tester.pumpWidget(_host(const Locale('en')));
    await tester.pump();
    expect(find.text('Clone a VieNeu-TTS voice'), findsOneWidget);
    expect(find.text('Microphone access is required to record voice samples.'),
        findsOneWidget);

    await tester.tap(find.text('Record a sample'));
    await tester.pump();
    expect(find.text('Microphone access has not been granted.'), findsOneWidget);
    await tester.tap(find.text('Create voice from samples'));
    await tester.pump();
    expect(find.text('Enter a voice name.'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Giọng {mẹ}');
    await tester.pump();

    // State remains mounted. Error kinds are stored independently of the
    // translated text, so both messages change without another user action.
    await tester.pumpWidget(_host(const Locale('hi')));
    await tester.pump();
    expect(find.text('VieNeu-TTS आवाज़ क्लोन करें'), findsOneWidget);
    expect(find.text('माइक्रोफ़ोन की अनुमति नहीं दी गई है।'), findsOneWidget);
    expect(find.text('आवाज़ का नाम दर्ज करें।'), findsOneWidget);

    await tester.pumpWidget(_host(const Locale('zh', 'TW')));
    await tester.pump();
    expect(find.text('複製 VieNeu-TTS 聲音'), findsOneWidget);
    expect(find.text('尚未授予麥克風權限。'), findsOneWidget);
    expect(find.text('請輸入聲音名稱。'), findsOneWidget);
    expect(find.text('Giọng {mẹ}'), findsOneWidget); // User input is not translated.

    // Bengali is T3; the untranslated voice messages use English, never vi.
    await tester.pumpWidget(_host(const Locale('bn')));
    await tester.pump();
    expect(find.text('Clone a VieNeu-TTS voice'), findsOneWidget);
    expect(find.text('Enter a voice name.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
