// YT-AUDIT-05 (IN4-105) — Hậu phương cho tab GIẢI THÍCH.
//
// Triệu chứng owner báo (2026-10-20):
//   "Tab GIẢI THÍCH hiện 'AI chưa phân tích được - No local dict entry and
//    engine not ready'", và KHÔNG có phần nào trong 7 phần cần có.
//
// Ba nguyên nhân gốc, pin lại để không tái phát:
//   1. Panel chỉ gửi `{'meaning': _localMeaning}` ⇒ từ điển nhanh không có từ
//      là gửi `null` ⇒ facade rớt vào "No local dict entry" dù vẫn còn nghĩa
//      MDX và câu phụ đề đang phát.
//   2. `errorReason` là câu tiếng Anh thô của engine ⇒ hiện nguyên lên màn
//      hình, không dịch được.
//   3. Kết quả chỉ là nghĩa từ điển (success:true) ⇒ không ai báo cho người
//      dùng biết 6 phần kia đang trống.
//
// Test thuần — không cần thiết bị / mạng / model AI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/services/yt_word_analysis_fallback.dart';
import 'package:in4up_ai/in4up_ai.dart';

void main() {
  group('đấu nối (pin nguồn) — bảng tra từ', () {
    final panel = File('lib/features/youtube/widgets/yt_word_panel.dart')
        .readAsStringSync();
    final facade =
        File('packages/in4up_ai/lib/src/facade/ai_service_facade.dart')
            .readAsStringSync();

    test('bảng gửi `localDictEntry` ĐẦY ĐỦ, không phải `null` khi thiếu offline',
        () {
      expect(panel.contains('localDictEntry: _localDictEntry(),'), isTrue,
          reason: 'Bản cũ: `_localMeaning == null ? null : {\'meaning\': …}` '
              '⇒ từ điển nhanh không có từ là rớt thẳng vào "No local dict '
              'entry" dù vẫn còn nghĩa MDX và câu phụ đề đang phát.');
    });

    test('nghĩa + phiên âm offline phải xong TRƯỚC khi hỏi AI', () {
      expect(
        panel.contains('await Future.wait<void>(['),
        isTrue,
        reason: 'Gọi AI ngay trong postframe ⇒ `_mdxEntries` và `_ipa` vẫn '
            'trống ⇒ `localDictEntry` nghèo đi.',
      );
      expect(panel.contains('_prepareAi();'), isTrue);
      expect(panel.indexOf('await Future.wait<void>'),
          lessThan(panel.indexOf('_prepareAi();')));
    });

    test('câu tiếng Anh thô của engine KHÔNG còn bị hiện lên màn hình', () {
      // Chữ ký CŨ (hiện thẳng chuỗi thô vào ô lỗi) phải biến mất. Lưu ý
      // `_aiErrorText()` bên trong vẫn đọc `_aiError ?? _aiResult?.errorReason`
      // — đó là nguồn, không phải chỗ hiển thị.
      expect(
        panel.contains("_aiError ?? a?.errorReason ?? context.uiText('Không rõ lý do.')"),
        isFalse,
        reason: 'Chuỗi thô của engine phải đi qua `_aiErrorText()` để được dịch.',
      );
      expect(panel.contains('body: _aiErrorText(),'), isTrue);
    });

    test('facade phát MÃ MÁY, không phát câu tiếng Anh', () {
      expect(
        facade.contains(
            "errorReason: 'No local dict entry and engine not ready'"),
        isFalse,
        reason: 'Câu tiếng Anh thô được nhắc lại trong comment lịch sử là được, '
            'nhưng không được còn làm giá trị `errorReason`.',
      );
      expect(facade.contains('errorReason: kAiErrLocalDictMissing,'), isTrue);
    });

    test('ví dụ không bị nhét vào "Mẹo nhớ" nữa', () {
      // Bản cũ `WordDetail(..., memoryHook: example)` ⇒ câu ví dụ hiện dưới
      // nhãn "Mẹo nhớ". Đưa về `contextExamples` mới đúng chỗ.
      expect(facade.contains('memoryHook: example'), isFalse);
      expect(
        facade.contains(
            'example == null || example.isEmpty ? const [] : <String>[example]'),
        isTrue,
      );
    });

    test('tab vẫn hiện nội dung khi AI hoàn toàn không có', () {
      expect(panel.contains('_buildOfflineAnalysis(),'), isTrue);
      expect(panel.contains('_buildMissingSectionsCard(),'), isTrue);
    });
  });

  group('buildLocalDictEntry — đừng tự tay ném đi dữ liệu mình có', () {
    test('gửi đủ nghĩa + phiên âm + ví dụ + từ loại', () {
      final e = YtWordAnalysisFallback.buildLocalDictEntry(
        meaning: 'rất',
        phonetic: '/ˈveri/',
        example: 'This is a very good idea.',
        wordType: 'adv',
      );
      expect(e, isNotNull);
      expect(e![YtWordAnalysisFallback.kMeaning], 'rất');
      expect(e[YtWordAnalysisFallback.kPhonetic], '/ˈveri/');
      expect(e[YtWordAnalysisFallback.kExample], 'This is a very good idea.');
      expect(e[YtWordAnalysisFallback.kWordType], 'adv');
    });

    test('thiếu nghĩa ⇒ null (báo lỗi thà hơn gửi bản đồ rỗng)', () {
      // Bản đồ rỗng làm facade trả success:true với nội dung trống ⇒ UI tưởng
      // AI đã xong ⇒ tệ hơn nhiều so với việc báo đúng là không có gì.
      expect(
        YtWordAnalysisFallback.buildLocalDictEntry(
            meaning: null, example: 'a sentence'),
        isNull,
      );
      expect(
        YtWordAnalysisFallback.buildLocalDictEntry(meaning: '   '),
        isNull,
      );
    });

    test('bỏ qua các giá trị rỗng (không gửi khoá thừa)', () {
      final e = YtWordAnalysisFallback.buildLocalDictEntry(
        meaning: 'rất',
        phonetic: '  ',
        example: '',
      );
      expect(e!.length, 1);
      expect(e.containsKey(YtWordAnalysisFallback.kPhonetic), isFalse);
      expect(e.containsKey(YtWordAnalysisFallback.kExample), isFalse);
    });

    test('câu phụ đề đang phát ĐƯỢC gửi làm ví dụ (có sẵn mà không cần AI)', () {
      // Đây là nội dung giá trị nhất: chính câu người dùng vừa bấm vào.
      final e = YtWordAnalysisFallback.buildLocalDictEntry(
        meaning: 'rất',
        example: 'Thank you very much.',
      );
      expect(e![YtWordAnalysisFallback.kExample], 'Thank you very much.');
    });
  });

  group('pickMeaning — chọn nghĩa tốt nhất trong những nguồn có thật', () {
    test('từ điển offline thắng (nhanh hơn, đúng nghĩa phổ biến)', () {
      expect(
        YtWordAnalysisFallback.pickMeaning(
          offline: 'rất',
          mdxDefinitions: const ['(phó từ) ở mức cao độ'],
        ),
        'rất',
      );
    });

    test('không có offline ⇒ rớt sang MDX', () {
      expect(
        YtWordAnalysisFallback.pickMeaning(
          offline: null,
          mdxDefinitions: const ['', '  ', '(phó từ) ở mức cao độ'],
        ),
        '(phó từ) ở mức cao độ',
      );
    });

    test('không có gì ⇒ null (không bịa)', () {
      expect(YtWordAnalysisFallback.pickMeaning(), isNull);
      expect(
        YtWordAnalysisFallback.pickMeaning(
            offline: '  ', mdxDefinitions: const []),
        isNull,
      );
    });

    test('định nghĩa MDX quá dài bị cắt (đi thẳng vào summary của AI)', () {
      final long = 'x' * 500;
      final picked =
          YtWordAnalysisFallback.pickMeaning(mdxDefinitions: [long]);
      expect(picked!.length, 161); // 160 + dấu …
      expect(picked.endsWith('…'), isTrue);
    });
  });

  group('missingSections — báo ĐÚNG phần còn trống', () {
    test('chưa có kết quả ⇒ thiếu cả 6', () {
      expect(YtWordAnalysisFallback.missingSections(null), hasLength(6));
      expect(
        YtWordAnalysisFallback.missingSections(null),
        contains(YtWordSection.grammar),
      );
    });

    test('chỉ có nghĩa từ điển ⇒ thiếu 5 (vẫn chưa có ngữ pháp)', () {
      final a = AiAnalysis(
        inputText: 'very',
        type: AiAnalysisType.wordLookup,
        summary: 'rất',
        topics: const ['Vocabulary'],
        terms: const [],
        success: true,
        generatedAt: DateTime.now(),
        wordDetail: const WordDetail(word: 'very', meaning: 'rất'),
      );
      final missing = YtWordAnalysisFallback.missingSections(a);
      expect(missing, hasLength(5));
      expect(missing, contains(YtWordSection.grammar));
      expect(missing, contains(YtWordSection.pao));
      expect(missing, isNot(contains(YtWordSection.summary)));
      expect(YtWordAnalysisFallback.hasAnyAiDepth(a), isTrue);
    });

    test('AI trả đủ 7 phần ⇒ không thiếu gì', () {
      final a = AiAnalysis(
        inputText: 'very',
        type: AiAnalysisType.wordLookup,
        summary: 'rất — dùng để nhấn mạnh',
        topics: const ['Vocabulary'],
        terms: const [],
        success: true,
        generatedAt: DateTime.now(),
        grammar: const GrammarAnalysis(
          subject: 'It',
          verb: 'is',
          object: 'a very good idea',
          pattern: 'S + V + C',
          explanationVi: 'Cấu trúc S + V + C.',
        ),
        contextExamples: const ['It is very cold.'],
        paoSuggestions: const ['PAO 1'],
        visualPrompt: 'một cảnh rất lạnh',
        wordDetail: const WordDetail(
          word: 'very',
          meaning: 'rất',
          memoryHook: 'Nghĩ đến VERY = "vẹt" nhấn mạnh',
        ),
      );
      expect(YtWordAnalysisFallback.missingSections(a), isEmpty);
      expect(YtWordAnalysisFallback.hasAnyAiDepth(a), isTrue);
    });

    test('kết quả lỗi (fallback) ⇒ thiếu cả 6, không có chiều sâu', () {
      final a = AiAnalysis.fallback('very',
          errorReason: kAiErrLocalDictMissing,
          analysisType: AiAnalysisType.wordLookup);
      expect(YtWordAnalysisFallback.missingSections(a), hasLength(6));
      expect(YtWordAnalysisFallback.hasAnyAiDepth(a), isFalse);
    });
  });

  group('errorCode — mã máy để UI dịch (không hiện câu tiếng Anh thô)', () {
    test('câu tiếng Anh CŨ của engine vẫn map được', () {
      expect(
        YtWordAnalysisFallback.errorCode(
            'No local dict entry and engine not ready'),
        kAiErrLocalDictMissing,
      );
      expect(YtWordAnalysisFallback.errorCode('Engine not ready'),
          kAiErrEngineNotReady);
      expect(YtWordAnalysisFallback.errorCode('Empty word'),
          kAiErrEmptyWord);
    });

    test('timeout (cả tiếng Anh lẫn tiếng Việt) ⇒ cùng một mã', () {
      expect(
        YtWordAnalysisFallback.errorCode(
            'TimeoutException after 0:00:30.000000: Future not completed'),
        kAiErrTimeout,
      );
      expect(YtWordAnalysisFallback.errorCode('hết giờ'), kAiErrTimeout);
    });

    test('lỗi mạng ⇒ mã mạng', () {
      expect(
        YtWordAnalysisFallback.errorCode(
            'SocketException: Failed host lookup'),
        kAiErrNetwork,
      );
      expect(YtWordAnalysisFallback.errorCode('Connection refused'),
          kAiErrNetwork);
    });

    test('đã là mã ⇒ giữ nguyên (idempotent)', () {
      for (final code in <String>[
        kAiErrLocalDictMissing,
        kAiErrEngineNotReady,
        kAiErrTimeout,
        kAiErrNetwork,
        kAiErrEmptyWord,
      ]) {
        expect(YtWordAnalysisFallback.errorCode(code), code);
      }
    });

    test('rỗng / không nhận ra ⇒ unknown (không bao giờ null)', () {
      expect(YtWordAnalysisFallback.errorCode(null), kAiErrUnknown);
      expect(YtWordAnalysisFallback.errorCode(''), kAiErrUnknown);
      expect(YtWordAnalysisFallback.errorCode('lỗi lạ gì đó'), kAiErrUnknown);
    });
  });
}
