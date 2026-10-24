// WORD-INSIGHT-001 — Unit test: waterfall "mạng → từ điển → offline".
//
// Toàn bộ nguồn ngoài được thay bằng seam ⇒ test chạy offline, không chạm
// mạng/SQLite/SharedPreferences.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/word_lookup/services/online_dictionary_source.dart';
import 'package:in4up/features/word_lookup/services/word_insight_service.dart';

OnlineDictEntry onlineHello() => const OnlineDictEntry(
      word: 'hello',
      phonetic: 'həˈloʊ',
      meanings: <OnlineDictMeaning>[
        OnlineDictMeaning(
          partOfSpeech: 'noun',
          senses: <OnlineDictSense>[
            OnlineDictSense(
              definition: 'a greeting',
              example: 'she said hello',
            ),
          ],
        ),
      ],
    );

void main() {
  setUp(() {
    WordInsightService.resetForTest();
    OnlineDictionarySource.resetForTest();
    // Mặc định: không có MDX, không dịch, không offline ⇒ test tự bật cái cần.
    WordInsightService.dictionaryLookupOverride =
        (word) async => const <DictEntry>[];
    WordInsightService.translateOverride = (text) async => null;
    WordInsightService.offlineIpaOverride = (word) async => null;
    WordInsightService.offlineMeaningOverride = (word) => null;
    WordInsightService.dictionaryNamesOverride = () => const <String, String>{};
  });

  tearDown(() {
    WordInsightService.resetForTest();
    OnlineDictionarySource.resetForTest();
  });

  test('mạng thắng: IPA online + nghĩa đã dịch', () async {
    WordInsightService.onlineLookupOverride = (word) async => onlineHello();
    WordInsightService.translateOverride = (text) async => 'xin chào';

    final insight = await WordInsightService().resolve('Hello!');

    expect(insight.word, 'hello');
    expect(insight.ipa, '/həˈloʊ/');
    expect(insight.ipaSource, 'online');
    expect(insight.meaning, 'xin chào');
    expect(insight.partOfSpeech, 'noun');
    expect(insight.example, 'she said hello');
    expect(insight.origin, WordInsightOrigin.network);
  });

  test('mạng lỗi → rơi xuống từ điển MDX (đã làm sạch)', () async {
    WordInsightService.onlineLookupOverride = (word) async => null;
    WordInsightService.dictionaryLookupOverride = (word) async =>
        <DictEntry>[
          DictEntry(
            headword: word,
            definition: '<style>.x{color:red}</style>'
                '<div>/bʊk/</div><div>n.</div><div>1. quyển sách</div>',
            dictId: 'dict-a',
          ),
        ];
    WordInsightService.dictionaryNamesOverride =
        () => const <String, String>{'dict-a': 'Từ điển A'};

    final insight = await WordInsightService().resolve('book');

    expect(insight.ipa, '/bʊk/');
    expect(insight.ipaSource, 'mdx');
    expect(insight.partOfSpeech, 'noun');
    expect(insight.meaning, contains('quyển sách'));
    expect(insight.meaning, isNot(contains('color')));
    expect(insight.origin, WordInsightOrigin.dictionary);
    expect(insight.hasDictionary, isTrue);
    expect(insight.mergedDictionary.sourceLabels, <String>['Từ điển A']);
  });

  test('không mạng + không từ điển → offline (IPA + nghĩa)', () async {
    WordInsightService.onlineLookupOverride = (word) async => null;
    WordInsightService.offlineIpaOverride = (word) async => '/kæt/';
    WordInsightService.offlineMeaningOverride = (word) => 'con mèo';

    final insight = await WordInsightService().resolve('cat');

    expect(insight.ipa, '/kæt/');
    expect(insight.ipaSource, 'cmu');
    expect(insight.meaning, 'con mèo');
    expect(insight.origin, WordInsightOrigin.offline);
  });

  test('resolveLocal: chỉ cục bộ, không gọi mạng', () async {
    var networkCalls = 0;
    WordInsightService.onlineLookupOverride = (word) async {
      networkCalls++;
      return onlineHello();
    };
    WordInsightService.dictionaryLookupOverride = (word) async => <DictEntry>[
          DictEntry(
            headword: word,
            definition: '<div>/bʊk/</div><div>quyển sách</div>',
            dictId: 'dict-a',
          ),
        ];

    final local = await WordInsightService().resolveLocal('book');

    expect(networkCalls, 0);
    expect(local.ipa, '/bʊk/');
    expect(local.origin, WordInsightOrigin.dictionary);
  });

  test('resolve sau resolveLocal vẫn gọi mạng (cache cục bộ không chặn)',
      () async {
    var networkCalls = 0;
    WordInsightService.onlineLookupOverride = (word) async {
      networkCalls++;
      return onlineHello();
    };
    WordInsightService.translateOverride = (text) async => 'xin chào';
    WordInsightService.offlineMeaningOverride = (word) => 'con mèo';

    await WordInsightService().resolveLocal('hello');
    final upgraded = await WordInsightService().resolve('hello');

    expect(networkCalls, 1);
    expect(upgraded.origin, WordInsightOrigin.network);
    expect(upgraded.meaning, 'xin chào');
  });

  test('allowNetwork: false ⇒ không gọi mạng', () async {
    var networkCalls = 0;
    WordInsightService.onlineLookupOverride = (word) async {
      networkCalls++;
      return onlineHello();
    };
    WordInsightService.offlineMeaningOverride = (word) => 'con mèo';

    final insight = await WordInsightService().resolve(
      'hello',
      allowNetwork: false,
    );

    expect(networkCalls, 0);
    expect(insight.meaning, 'con mèo');
    expect(insight.origin, WordInsightOrigin.offline);
  });

  test('cache: lần tra thứ hai không gọi lại mạng', () async {
    var networkCalls = 0;
    WordInsightService.onlineLookupOverride = (word) async {
      networkCalls++;
      return onlineHello();
    };
    WordInsightService.translateOverride = (text) async => 'xin chào';

    await WordInsightService().resolve('hello');
    final second = await WordInsightService().resolve('hello');

    expect(networkCalls, 1);
    expect(second.fromCache, isTrue);
    expect(second.meaning, 'xin chào');
  });

  test('dịch lỗi vẫn giữ nghĩa tiếng Anh (không chặn người dùng)', () async {
    WordInsightService.onlineLookupOverride = (word) async => onlineHello();
    WordInsightService.translateOverride = (text) async => null;

    final insight = await WordInsightService().resolve('hello');

    expect(insight.meaning, 'a greeting');
    expect(insight.englishMeaning, 'a greeting');
    expect(insight.origin, WordInsightOrigin.network);
  });

  test('không nguồn nào → kết quả rỗng, không ném', () async {
    WordInsightService.onlineLookupOverride = (word) async => null;

    final insight = await WordInsightService().resolve('zzzz');

    expect(insight.hasAny, isFalse);
    expect(insight.origin, isNull);
  });

  test('normalizeWord: bỏ dấu câu bám ngoài, gộp khoảng trắng', () {
    expect(WordInsightService.normalizeWord('  "Hello,"  '), 'hello');
    expect(WordInsightService.normalizeWord('look   up!'), 'look up');
  });

  group('OnlineDictionarySource.parseJson', () {
    test('đọc được word/phonetic/meanings/examples', () {
      const body = '[{"word":"hello","phonetic":"həˈləʊ",'
          '"phonetics":[{"text":"həˈləʊ","audio":"https://x/a.mp3"}],'
          '"meanings":[{"partOfSpeech":"noun","definitions":['
          '{"definition":"a greeting","example":"she said hello"}]}]}]';

      final entry = OnlineDictionarySource.parseJson(body);

      expect(entry, isNotNull);
      expect(entry!.word, 'hello');
      expect(entry.phonetic, 'həˈləʊ');
      expect(entry.audioUrl, 'https://x/a.mp3');
      expect(entry.primaryPartOfSpeech, 'noun');
      expect(entry.senses.single.definition, 'a greeting');
      expect(entry.englishSummary(), 'a greeting');
      expect(entry.primaryExample, 'she said hello');
    });

    test('JSON hỏng / rỗng → null (không ném)', () {
      expect(OnlineDictionarySource.parseJson('not json'), isNull);
      expect(OnlineDictionarySource.parseJson('[]'), isNull);
      expect(OnlineDictionarySource.parseJson('{}'), isNull);
    });
  });
}
