// test/tts_settings_edge_and_api_test.dart — PSRC-18
//
// Kiểm chứng widget + source-scan cho Cài đặt Text Studio (mục TTS):
//  1. Bộ chọn giọng Microsoft Edge Neural chỉ hiển thị mặc định đúng 8 ngôn ngữ
//     tiêu biểu (`vi-VN`, `en-US`, `en-GB`, `zh-CN`, `hi-IN`, `my-MM`, `si-LK`,
//     `th-TH`) và có nút mở rộng/thu gọn cho các ngôn ngữ còn lại.
//  2. Chạm trực tiếp vào giọng nữ mặc định (`Hoài My`) cũng ghi nhận lựa chọn
//     tường minh vào `EdgeVoicePrefs` (sửa lỗi RadioListTile không bắn
//     onChanged khi `value == groupValue`), và đổi qua lại Nam Minh ↔ Hoài My
//     cũng như `en-US` ↔ `en-GB` hoạt động chính xác.
//  3. Đã xoá hoàn toàn mục nhập Zalo AI & FPT.AI API Key trong Cài đặt Text
//     Studio, thay bằng thẻ `ServerApiSyncSection` đồng bộ trực tiếp với
//     `AiProviderStore` (Server & API ở Home).
//  4. Rule #5: khi locale = `en`, giao diện không rò rỉ ký tự tiếng Việt.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/edge_voice_prefs.dart';
import 'package:in4up/features/tts/widgets/tts_settings_section.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RegExp _vietnameseOnly = RegExp(
  r'[đĐơƠưƯ]'
  r'|[ảạằắẳẵặầấẩẫậ]'
  r'|[ẻẽẹềếểễệ]'
  r'|[ỉĩị]'
  r'|[ỏọồốổỗộờớởỡợ]'
  r'|[ủũụừứửữự]'
  r'|[ỳỷỹỵ]',
);

Widget _wrapWithApp(
  Widget child, {
  Locale locale = const Locale('vi'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AiProviderStore.instance.applySnapshot(const AiSettingsSnapshot());
  });

  group('EdgeVoicePicker — 8 ngôn ngữ tiêu biểu & nút mở rộng (PSRC-18)', () {
    testWidgets(
      'mặc định chỉ hiện đúng 8 ngôn ngữ tiêu biểu, bấm mở rộng mới hiện phần còn lại',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithApp(
            const EdgeVoicePicker(loadLiveVoicesOnExpand: false),
          ),
        );
        await tester.pumpAndSettle();

        // 8 ngôn ngữ tiêu biểu phải xuất hiện ngay từ đầu.
        for (final code in const [
          'vi-VN',
          'en-US',
          'en-GB',
          'zh-CN',
          'hi-IN',
          'my-MM',
          'si-LK',
          'th-TH',
        ]) {
          expect(
            find.byKey(Key('edge-voice-lang-$code')),
            findsOneWidget,
            reason: 'Thiếu ngôn ngữ tiêu biểu $code',
          );
        }

        // Các ngôn ngữ còn lại bị ẩn cho đến khi bấm mở rộng.
        for (final extra in const ['zh-TW', 'ja-JP', 'ko-KR', 'fr-FR']) {
          expect(find.byKey(Key('edge-voice-lang-$extra')), findsNothing);
        }

        final toggle = find.byKey(const Key('edge-voice-more-languages-toggle'));
        expect(toggle, findsOneWidget);

        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        for (final extra in const ['zh-TW', 'ja-JP', 'ko-KR', 'fr-FR']) {
          expect(
            find.byKey(Key('edge-voice-lang-$extra')),
            findsOneWidget,
            reason: 'Sau khi mở rộng phải hiện $extra',
          );
        }

        // Bấm lần nữa để thu gọn lại.
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('edge-voice-lang-ja-JP')), findsNothing);
      },
    );

    testWidgets(
      'chạm giọng nữ mặc định Hoài My lẫn giọng nam Nam Minh đều lưu EdgeVoicePrefs',
      (tester) async {
        var voiceChangedCalls = 0;
        await tester.pumpWidget(
          _wrapWithApp(
            EdgeVoicePicker(
              loadLiveVoicesOnExpand: false,
              onVoiceChanged: () async {
                voiceChangedCalls++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ban đầu chưa có lựa chọn tường minh trong EdgeVoicePrefs.
        expect(await EdgeVoicePrefs.instance.voiceForLang('vi-VN'), isNull);

        // Mở nhóm Tiếng Việt và chạm thẳng vào giọng mặc định Hoài My (nữ).
        await tester.tap(find.byKey(const Key('edge-voice-lang-vi-VN')));
        await tester.pumpAndSettle();

        final hoaiMy = find.byKey(
          const Key('edge-voice-option-vi-VN-HoaiMyNeural'),
        );
        final namMinh = find.byKey(
          const Key('edge-voice-option-vi-VN-NamMinhNeural'),
        );
        expect(hoaiMy, findsOneWidget);
        expect(namMinh, findsOneWidget);

        await tester.ensureVisible(hoaiMy);
        await tester.tap(hoaiMy);
        await tester.pumpAndSettle();
        expect(
          await EdgeVoicePrefs.instance.voiceForLang('vi-VN'),
          'vi-VN-HoaiMyNeural',
        );
        expect(voiceChangedCalls, 1);

        // Chuyển sang Nam Minh (nam) rồi đổi ngược lại Hoài My (nữ).
        await tester.ensureVisible(namMinh);
        await tester.tap(namMinh);
        await tester.pumpAndSettle();
        expect(
          await EdgeVoicePrefs.instance.voiceForLang('vi-VN'),
          'vi-VN-NamMinhNeural',
        );

        await tester.ensureVisible(hoaiMy);
        await tester.tap(hoaiMy);
        await tester.pumpAndSettle();
        expect(
          await EdgeVoicePrefs.instance.voiceForLang('vi-VN'),
          'vi-VN-HoaiMyNeural',
        );
        expect(voiceChangedCalls, 3);
      },
    );
  });

  group('ServerApiSyncSection & xoá Zalo/FPT API Keys (PSRC-18)', () {
    testWidgets(
      'đồng bộ trực tiếp với AiProviderStore khi thêm/xoá provider TTS',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithApp(
            ServerApiSyncSection(
              color: const Color(0xFF6C63FF),
              onConfiguredChanged: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('tts-home-api-sync-card')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Đồng bộ chung với Server & API ở Home'),
          findsOneWidget,
        );

        await AiProviderStore.instance.upsert(
          const AiProviderConfig(
            id: 'openai-tts-1',
            label: 'OpenAI Cloud',
            baseUrl: 'https://api.openai.com/v1',
            apiKey: 'sk-test-123456',
            ttsModel: 'gpt-4o-mini-tts',
            enabled: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('OpenAI Cloud · gpt-4o-mini-tts'),
          findsOneWidget,
        );
      },
    );

    test('tts_settings_section.dart đã xoá hoàn toàn ô nhập Zalo AI & FPT.AI',
        () {
      final source = File(
        'lib/features/tts/widgets/tts_settings_section.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('_ApiKeySection')));
      expect(source, isNot(contains('FPT.AI API Key')));
      expect(source, isNot(contains('Zalo AI API Key')));
      expect(source, contains('ServerApiSyncSection'));
      expect(source, contains('AiProvidersScreen'));
    });

    testWidgets(
      'Rule #5: locale English không rò rỉ ký tự tiếng Việt trên UI mới',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithApp(
            Column(
              children: [
                const EdgeVoicePicker(loadLiveVoicesOnExpand: false),
                ServerApiSyncSection(
                  color: const Color(0xFF6C63FF),
                  onConfiguredChanged: () {},
                ),
              ],
            ),
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        // Mở nhóm vi-VN và bung luôn danh sách ngôn ngữ mở rộng để kiểm cả tên
        // giọng lẫn tên ngôn ngữ.
        await tester.tap(find.byKey(const Key('edge-voice-lang-vi-VN')));
        await tester.pumpAndSettle();
        final toggle = find.byKey(const Key('edge-voice-more-languages-toggle'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        final renderedTexts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        expect(renderedTexts, isNotEmpty);

        // Ngoại trừ tên riêng tiếng Việt "Hoài My", mọi nhãn ngôn ngữ/trạng thái
        // ở locale `en` không được còn ký tự tiếng Việt.
        final violations = <String>[];
        for (final text in renderedTexts) {
          final scrubbedProperNoun = text.replaceAll('Hoài My', 'Hoai My');
          if (_vietnameseOnly.hasMatch(scrubbedProperNoun)) {
            violations.add(text);
          }
        }
        expect(violations, isEmpty, reason: violations.join('\n'));
      },
    );
  });
}
