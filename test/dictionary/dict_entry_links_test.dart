import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/services/dict_entry_links.dart';
import 'package:in4up/features/dictionary/services/dict_redirect_resolver.dart';

DictEntry entry(String word, String definition) =>
    DictEntry(headword: word, definition: definition, dictId: 'a');

void main() {
  test('accepts whole-record redirects, including old DB terminators', () {
    expect(DictEntryLinks.redirectTarget('@@@LINK=meditation\u0000'), 'meditation');
    expect(DictEntryLinks.redirectTarget('@@@LINK=an example'), 'an example');
    expect(DictEntryLinks.redirectTarget('<p>@@@LINK=word</p>'), isNull);
    expect(DictEntryLinks.redirectTarget('@@@LINK=../../secret'), isNull);
    expect(DictEntryLinks.redirectTarget('@@@LINK=word\nother'), isNull);
  });

  test('extracts only safe dictionary links, not files, scripts or websites', () {
    final links = DictEntryLinks.extract('''
      <a href="entry://meditation">meditation</a>
      <a href="bword://look%20up">look up</a>
      <a href="entry://meditation">duplicate</a>
      <a href="https://example.com/">web</a>
      <a href="file:///etc/passwd">file</a>
      <a href="javascript:alert(1)">script</a>
      <a href="entry://%2e%2e%2fsecret">path</a>
      <a href="entry://word%0aother">control</a>
      <form><a href="entry://hidden">hidden</a></form>
    ''');
    expect(links, ['meditation', 'look up']);
    expect(DictEntryLinks.internalHref('entry://bad%xx'), isNull);
    expect(DictEntryLinks.internalHref('entry://${'a' * 257}'), isNull);
  });

  test('caps the number of links exposed from an untrusted entry', () {
    final html = List.generate(100, (i) => '<a href="entry://word$i">x</a>').join();
    expect(DictEntryLinks.extract(html), hasLength(DictEntryLinks.maxLinks));
  });

  test('follows redirects, preserving source and original headword', () async {
    final data = {
      'cats': [entry('cats', '@@@LINK=cat')],
      'cat': [entry('cat', '@@@LINK=feline')],
      'feline': [entry('feline', '<b>animal</b>')],
    };
    final result = await DictRedirectResolver.resolve(
      data['cats']!, (word) async => data[word] ?? [],
    );
    expect(result.single.headword, 'cats');
    expect(result.single.dictId, 'a');
    expect(result.single.definition, '<b>animal</b>');
  });

  test('broken, cyclic and failed redirects retain original records', () async {
    final data = {
      'x': [entry('x', '@@@LINK=y')],
      'y': [entry('y', '@@@LINK=x')],
    };
    final cyclic = await DictRedirectResolver.resolve(
      data['x']!, (word) async => data[word] ?? [],
    );
    expect(cyclic.single.definition, startsWith('@@@LINK='));
    final missing = entry('a', '@@@LINK=unknown');
    expect((await DictRedirectResolver.resolve([missing], (_) async => [])).single,
        same(missing));
    expect((await DictRedirectResolver.resolve([missing], (_) async => throw StateError('db'))).single,
        same(missing));
  });

  test('bounds work with malicious branching and avoids repeated lookup', () async {
    var calls = 0;
    final first = entry('a', '@@@LINK=b');
    final result = await DictRedirectResolver.resolve([first], (word) async {
      calls++;
      return List.generate(10, (i) => entry(word, '@@@LINK=${word}x'));
    });
    expect(calls, lessThanOrEqualTo(DictRedirectResolver.maxLookups));
    expect(result.length, lessThanOrEqualTo(DictRedirectResolver.maxVisitedEntries * 10));
  });
}
