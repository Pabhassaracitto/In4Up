// test/understand_ai_test.dart
//
// I4U — Prompt Agent 2: AI Coach trong tab Hiểu.
//
// Phạm vi máy bắt (theo yêu cầu):
//   1. Context builder — UnderstandAiContext.fromLineTexts
//   2. Quick prompt   — buildUnderstandQuickPrompt (4 action)
//   3. Optional callback / AiChatScreen(context: ...) không phá caller cũ
//   4. Đóng sheet/chat KHÔNG reset UnderstandProvider (dòng, mode, audio line)
//   5. Không tự động ghi âm / upload audio / gửi cả tài liệu / tự gửi tin
//
// Lưu ý: widget test chạy locale mặc định (en) nên các nhãn chrome hiển thị
// bằng tiếng Anh theo catalog — tìm widget bằng icon/text English để không
// phụ thuộc locale.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/understand_ai/understand_ai_context.dart';
import 'package:in4up/features/understand_ai/understand_ai_coach_sheet.dart';
import 'package:in4up/features/understand_ai/understand_ai_prompts.dart';
import 'package:in4up/screens/ai_chat/ai_chat_screen.dart';
import 'package:in4up/screens/understand_mode/services/understand_ai_coach_launcher.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up/screens/understand_mode/widgets/understand_workspace_header.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

List<String> _doc(int count) => List.generate(count, (i) => 'line $i');

List<LrcLine> _lrcDoc(int count) => List.generate(
      count,
      (i) => LrcLine(
        timestamp: Duration(seconds: i * 5),
        text: 'line $i',
      ),
    );

void main() {
  group('UnderstandAiContext.fromLineTexts (context builder)', () {
    test('follows the playing line when no focus is given', () {
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: _doc(10),
        currentLineIndex: 4,
      );

      expect(ctx.selectedText, 'line 4');
      expect(ctx.currentLineIndex, 4);
      expect(ctx.focusLineIndex, 4);
      // Surrounding = 2 dòng trước + 2 dòng sau (không gồm chính câu đó).
      expect(ctx.surroundingText, 'line 2\nline 3\nline 5\nline 6');
      // Recent = 5 dòng kết thúc ở dòng đang phát.
      expect(ctx.recentText, 'line 0\nline 1\nline 2\nline 3\nline 4');
      expect(ctx.learningMode, UnderstandLearningMode.sync);
      expect(ctx.hasText, isTrue);
    });

    test('focus line overrides selection but keeps the audio line', () {
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: _doc(10),
        currentLineIndex: 7,
        focusLineIndex: 2,
      );

      expect(ctx.selectedText, 'line 2');
      expect(ctx.focusLineIndex, 2);
      expect(ctx.currentLineIndex, 7);
      // "Đoạn vừa nghe" vẫn neo vào dòng đang phát.
      expect(ctx.recentText, 'line 3\nline 4\nline 5\nline 6\nline 7');
      expect(ctx.surroundingText, 'line 0\nline 1\nline 3\nline 4');
    });

    test('empty / out-of-range inputs stay null and safe', () {
      final empty = UnderstandAiContext.fromLineTexts(lines: []);
      expect(empty.selectedText, isNull);
      expect(empty.surroundingText, isNull);
      expect(empty.recentText, isNull);
      expect(empty.currentLineIndex, isNull);
      expect(empty.focusLineIndex, isNull);
      expect(empty.hasText, isFalse);

      final outOfRange = UnderstandAiContext.fromLineTexts(
        lines: _doc(3),
        currentLineIndex: 99,
        focusLineIndex: -5,
      );
      expect(outOfRange.currentLineIndex, isNull);
      expect(outOfRange.selectedText, isNull);
      expect(outOfRange.hasText, isFalse);
    });

    test('long documents are clipped — never sent whole', () {
      final lines = List.generate(200, (i) => 'word $i ' * 100);
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: lines,
        currentLineIndex: 100,
      );

      expect(
        ctx.selectedText!.length,
        lessThanOrEqualTo(UnderstandAiContext.selectedTextMaxLength + 1),
      );
      expect(
        ctx.surroundingText!.length,
        lessThanOrEqualTo(UnderstandAiContext.surroundingTextMaxLength + 1),
      );
      expect(
        ctx.recentText!.length,
        lessThanOrEqualTo(UnderstandAiContext.recentTextMaxLength + 1),
      );

      final prompt = buildUnderstandQuickPrompt(
        UnderstandAiQuickAction.explainSentence,
        ctx,
      );
      // Đầu và cuối tài liệu không lọt vào prompt.
      expect(prompt.contains('word 0 '), isFalse);
      expect(prompt.contains('word 199'), isFalse);
      expect(prompt.length, lessThan(2400));
    });

    test('passes through title, mode, target language and learner level',
        () {
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: _doc(2),
        currentLineIndex: 0,
        sourceTitle: '  Podcast 101  ',
        learningMode: UnderstandLearningMode.shadowing,
        targetLanguage: 'vi',
        learnerLevel: 'B1',
      );

      expect(ctx.sourceTitle, 'Podcast 101');
      expect(ctx.learningMode, UnderstandLearningMode.shadowing);
      expect(ctx.targetLanguage, 'vi');
      expect(ctx.learnerLevel, 'B1');
    });
  });

  group('buildUnderstandQuickPrompt (quick prompt)', () {
    test('requiresLyrics: chỉ "gợi ý" là không cần lyric', () {
      expect(UnderstandAiQuickAction.explainSentence.requiresLyrics, isTrue);
      expect(UnderstandAiQuickAction.summarizeRecent.requiresLyrics, isTrue);
      expect(
        UnderstandAiQuickAction.checkComprehension.requiresLyrics,
        isTrue,
      );
      expect(UnderstandAiQuickAction.giveHint.requiresLyrics, isFalse);
    });

    test('explain embeds sentence, surroundings and instruction', () {
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: _doc(10),
        currentLineIndex: 4,
        sourceTitle: 'Unit 1',
      );

      final prompt = buildUnderstandQuickPrompt(
        UnderstandAiQuickAction.explainSentence,
        ctx,
      );

      expect(prompt, contains('« line 4 »'));
      expect(prompt, contains('Ngữ cảnh quanh câu'));
      expect(prompt, contains('line 3'));
      expect(prompt, contains('Unit 1'));
      expect(prompt, contains('Đồng bộ'));
      expect(prompt, contains('Giải thích câu'));
    });

    test('summarize uses the recently-heard window only', () {
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: _doc(12),
        currentLineIndex: 9,
      );

      final prompt = buildUnderstandQuickPrompt(
        UnderstandAiQuickAction.summarizeRecent,
        ctx,
      );

      expect(prompt, contains('Đoạn vừa nghe'));
      expect(prompt, contains('line 5'));
      expect(prompt, contains('line 9'));
      expect(prompt, isNot(contains('line 4')));
      expect(prompt, isNot(contains('line 10')));
      expect(prompt, contains('Tóm tắt'));
    });

    test('check comprehension asks questions and waits for the learner', () {
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: _doc(6),
        currentLineIndex: 3,
      );

      final prompt = buildUnderstandQuickPrompt(
        UnderstandAiQuickAction.checkComprehension,
        ctx,
      );

      expect(prompt, contains('Đoạn vừa nghe'));
      expect(prompt, contains('3 câu hỏi'));
      expect(prompt, contains('Kiểm tra hiểu bài'));
    });

    test('hint works without lyrics and mentions the mode', () {
      const ctx = UnderstandAiContext(
        learningMode: UnderstandLearningMode.shadowing,
      );

      final prompt = buildUnderstandQuickPrompt(
        UnderstandAiQuickAction.giveHint,
        ctx,
      );

      expect(prompt, contains('Shadowing'));
      expect(prompt, contains('Chưa có câu nào đang phát'));
      expect(prompt.trim().isNotEmpty, isTrue);
    });

    test('no prompt is ever empty or contains "null"', () {
      const empty = UnderstandAiContext();
      for (final action in UnderstandAiQuickAction.values) {
        final prompt = buildUnderstandQuickPrompt(action, empty);
        expect(prompt.contains('null'), isFalse, reason: '$action');
        expect(prompt.trim().isNotEmpty, isTrue, reason: '$action');
      }
    });

    test('payload is text-only — no audio path or recording markers', () {
      final ctx = UnderstandAiContext.fromLineTexts(
        lines: const ['Hello from the other side'],
        currentLineIndex: 0,
      );

      for (final action in UnderstandAiQuickAction.values) {
        final prompt = buildUnderstandQuickPrompt(action, ctx);
        expect(prompt.contains('.mp3'), isFalse, reason: '$action');
        expect(prompt.contains('.wav'), isFalse, reason: '$action');
        expect(prompt.contains('record'), isFalse, reason: '$action');
        expect(prompt.contains('upload'), isFalse, reason: '$action');
      }
    });
  });

  group('AiChatScreen optional context (back-compat)', () {
    testWidgets('constructor cũ vẫn hoạt động: không context, không banner',
        (tester) async {
      await tester.pumpWidget(const _ChatHost());
      await tester.pump();

      expect(find.text('I4U AI Chat'), findsOneWidget);
      // Không có banner trợ lý hiểu bài khi context == null.
      expect(find.byIcon(Icons.psychology_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('context != null: hiện banner ngữ cảnh + nháp, không tự gửi',
        (tester) async {
      final aiContext = UnderstandAiContext.fromLineTexts(
        lines: _doc(3),
        currentLineIndex: 1,
        sourceTitle: 'Unit 9',
      );

      await tester.pumpWidget(
        _ChatHost(aiContext: aiContext, draft: 'Giải thích giúp mình câu này'),
      );
      await tester.pump();

      // Title đổi theo chế độ coach, banner hiện mode + dòng + câu.
      expect(find.text('Comprehension coach'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.textContaining('Sync'), findsOneWidget);
      expect(find.textContaining('line 1'), findsOneWidget);

      // Nháp có sẵn trong ô nhập — người dùng duyệt rồi mới gửi.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Giải thích giúp mình câu này');

      // KHÔNG tự gửi: chưa có message nào.
      expect(_hostFacade!.chatMessages, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Workspace header "Hỏi AI" (optional callback)', () {
    testWidgets('chip là action trong header và gọi callback', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UnderstandWorkspaceHeader(
                onOpenSpeakMode: () {},
                onOpenYouGlish: () {},
                onOpenReview: () {},
                onOpenQuickActions: () {},
                onOpenAiCoach: () => calls++,
              ),
            ),
          ),
        ),
      );

      // Chip hiển thị (locale test = en) và là action, không phải tab item.
      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);

      await tester.tap(find.text('Ask AI'));
      await tester.pump();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('Coach sheet: đóng sheet/chat không reset state, không ghi âm', () {
    testWidgets('đóng sheet bằng nút close giữ nguyên UnderstandProvider',
        (tester) async {
      final understand = UnderstandProvider();
      understand.loadLrcLines(_lrcDoc(10));
      understand.updatePosition(const Duration(seconds: 47));
      understand.setLearningMode(UnderstandLearningMode.shadowing);

      final before = <Object?>[
        understand.currentLineIndex,
        understand.learningMode,
        understand.lrcLines.length,
      ];
      expect(before, [9, UnderstandLearningMode.shadowing, 10]);

      await tester.pumpWidget(_CoachHost(understand: understand));
      await tester.tap(find.text('OPEN_COACH'));
      await tester.pumpAndSettle();

      // Sheet mở: hiện rõ context sẽ gửi.
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.textContaining('Context sent to the AI'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(<Object?>[
        understand.currentLineIndex,
        understand.learningMode,
        understand.lrcLines.length,
      ], before);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'quick action mở chat (nháp, chưa gửi); back về — state nguyên vẹn',
        (tester) async {
      final understand = UnderstandProvider();
      understand.loadLrcLines(_lrcDoc(10));
      understand.updatePosition(const Duration(seconds: 47));
      understand.setLearningMode(UnderstandLearningMode.shadowing);

      await tester.pumpWidget(_CoachHost(understand: understand));
      await tester.tap(find.text('OPEN_COACH'));
      await tester.pumpAndSettle();

      // Quick action "Cho tôi một gợi ý" (icon gợi ý) — luôn bật.
      await tester.tap(find.byIcon(Icons.tips_and_updates_outlined));
      await tester.pumpAndSettle();

      // Chat mở với banner coach; nháp có sẵn nhưng CHƯA gửi.
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(find.text('Comprehension coach'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isNotEmpty);
      expect(_hostFacade!.chatMessages, isEmpty);

      // Quay lại workspace.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AiChatScreen), findsNothing);

      // Audio position (currentLineIndex), mode, lrcLines không đổi.
      expect(understand.currentLineIndex, 9);
      expect(understand.learningMode, UnderstandLearningMode.shadowing);
      expect(understand.lrcLines.length, 10);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onAsk callback (optional) thay navigation mặc định',
        (tester) async {
      UnderstandAiQuickAction? seenAction;
      UnderstandAiContext? seenContext;

      await tester.pumpWidget(
        _CoachHost(
          understand: UnderstandProvider(),
          onAsk: (action, aiContext) {
            seenAction = action;
            seenContext = aiContext;
          },
        ),
      );
      await tester.tap(find.text('OPEN_COACH'));
      await tester.pumpAndSettle();

      // Không có lyric → hint vẫn dùng được.
      expect(find.text('No line is playing yet'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tips_and_updates_outlined));
      await tester.pumpAndSettle();

      expect(seenAction, UnderstandAiQuickAction.giveHint);
      expect(seenContext, isNotNull);
      expect(seenContext!.learningMode, UnderstandLearningMode.sync);
      // Sheet đã đóng và KHÔNG push chat mặc định khi có callback.
      expect(find.byType(AiChatScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'toàn bộ flow chạy mà không cần provider/plugin audio trong tree '
        '(không ghi âm, không upload tự động)', (tester) async {
      // Cây widget chỉ có UnderstandProvider (thuần ChangeNotifier). Không
      // PlayerProvider / ShadowingProvider / TtsService — nếu flow AI Coach
      // có chạm ghi âm hay audio thì test này fail ngay vì thiếu plugin.
      final understand = UnderstandProvider();
      understand.loadLrcLines(_lrcDoc(4));
      understand.updatePosition(const Duration(seconds: 12));

      await tester.pumpWidget(_CoachHost(understand: understand));
      await tester.tap(find.text('OPEN_COACH'));
      await tester.pumpAndSettle();

      // Quick action giải thích (icon bóng đèn) — cần text, đang bật.
      await tester.tap(find.byIcon(Icons.lightbulb_outline));
      await tester.pumpAndSettle();

      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(_hostFacade!.chatMessages, isEmpty); // chưa tự gửi gì
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, contains('line 2'));
      // Prompt chỉ chứa text của context, không chứa path audio.
      expect(field.controller!.text.contains('.mp3'), isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Host cho AiChatScreen — provider AiServiceFacade thật (không mock trả lời
/// giả): test chỉ đọc trạng thái, không gửi tin.
class _ChatHost extends StatelessWidget {
  final UnderstandAiContext? aiContext;
  final String? draft;

  const _ChatHost({this.aiContext, this.draft});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AiServiceFacade>(
      create: (_) {
        final facade = AiServiceFacade();
        _hostFacade = facade;
        return facade;
      },
      child: MaterialApp(
        home: AiChatScreen(context: aiContext, initialDraft: draft),
      ),
    );
  }
}

/// Giữ tham chiếu facade của host để assert "chưa tự gửi".
AiServiceFacade? _hostFacade;

/// Host cho sheet AI Coach: 1 nút mở sheet với context dựng từ provider thật
/// (qua buildUnderstandAiContextFromProviders — đúng đường launcher dùng).
class _CoachHost extends StatelessWidget {
  final UnderstandProvider understand;
  final UnderstandAiAskCallback? onAsk;

  const _CoachHost({required this.understand, this.onAsk});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AiServiceFacade>(
      create: (_) {
        final facade = AiServiceFacade();
        _hostFacade = facade;
        return facade;
      },
      child: ChangeNotifierProvider<UnderstandProvider>.value(
        value: understand,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (hostContext) => Center(
                child: ElevatedButton(
                  onPressed: () => showUnderstandAiCoachSheet(
                    context: hostContext,
                    aiContext: buildUnderstandAiContextFromProviders(
                      understand: understand,
                    ),
                    lines: understand.lrcLines
                        .map((line) => line.text)
                        .toList(growable: false),
                    onAsk: onAsk,
                  ),
                  child: const Text('OPEN_COACH'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
