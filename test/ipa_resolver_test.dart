// test/ipa_resolver_test.dart — READ-IPA-002
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/services/ipa_resolver.dart';

DictEntry _entry({
  String? phonetic,
  String definition = 'a test definition',
  String headword = 'world',
}) =>
    DictEntry(
      headword: headword,
      definition: definition,
      phonetic: phonetic,
      dictId: 'test_dict',
    );

void main() {
  setUp(() {
    IpaResolver.dictLookupOverride = null;
    IpaResolver.cmuWordIpaOverride = null;
    IpaResolver.g2pWordIpaOverride = null;
  });

  group('IpaValidator.looksLikeIpa', () {
    test('chấp nhận IPA thật', () {
      expect(IpaValidator.looksLikeIpa('/wɜːld/'), isTrue);
      expect(IpaValidator.looksLikeIpa('wɝld'), isTrue);
      expect(IpaValidator.looksLikeIpa('həˈloʊ'), isTrue);
      expect(IpaValidator.looksLikeIpa('[wɜːld]'), isTrue);
    });

    test('từ chối respelling, rác Anh/Việt, câu dài', () {
      expect(IpaValidator.looksLikeIpa('house'), isFalse);
      expect(IpaValidator.looksLikeIpa('he-lō'), isFalse);
      expect(IpaValidator.looksLikeIpa('phát âm'), isFalse);
      expect(IpaValidator.looksLikeIpa('a person, place or thing'), isFalse);
      expect(IpaValidator.looksLikeIpa(''), isFalse);
      // Dài > 80 nhưng có ký tự IPA → vẫn từ chối (giới hạn độ dài).
      expect(
        IpaValidator.looksLikeIpa('wɝ'.padRight(100, 'x')),
        isFalse,
      );
    });
  });

  group('IpaValidator.normalize', () {
    test('bọc /.../ và chuẩn hóa [] → //', () {
      expect(IpaValidator.normalize('wɝld'), '/wɝld/');
      expect(IpaValidator.normalize('[wɝld]'), '/wɝld/');
      expect(IpaValidator.normalize('/wɝld/'), '/wɝld/');
    });

    test('trả null nếu không hợp lệ', () {
      expect(IpaValidator.normalize('house'), isNull);
      expect(IpaValidator.normalize(''), isNull);
    });
  });

  group('IpaDefinitionExtractor.extract', () {
    test('rút /.../ rồi [...]', () {
      expect(
        IpaDefinitionExtractor.extract('world /wɜːld/ noun'),
        '/wɜːld/',
      );
      expect(IpaDefinitionExtractor.extract('world [wɝld]'), '/wɝld/');
    });

    test('bỏ qua slash rác / không có IPA', () {
      expect(IpaDefinitionExtractor.extract('visit /etc/path now'), isNull);
      expect(IpaDefinitionExtractor.extract('no phonetic here'), isNull);
      expect(IpaDefinitionExtractor.extract(null), isNull);
    });
  });

  group('IpaResolver.resolve', () {
    test('off → null', () async {
      IpaResolver.dictLookupOverride =
          (_) async => [_entry(phonetic: 'wɝld')];
      final r = await IpaResolver.resolve('world', mode: IpaSaveMode.off);
      expect(r, isNull);
    });

    test('dict mode: có entry hợp lệ → mdx, normalize /.../', () async {
      IpaResolver.dictLookupOverride =
          (_) async => [_entry(phonetic: 'wɝld')];
      final r = await IpaResolver.resolve('world', mode: IpaSaveMode.dict);
      expect(r, isNotNull);
      expect(r!.ipa, '/wɝld/');
      expect(r.source, 'mdx');
    });

    test('dict mode: phonetic rác → trích từ definition', () async {
      IpaResolver.dictLookupOverride = (_) async => [
            _entry(phonetic: 'house', definition: 'a building /haʊs/'),
          ];
      final r = await IpaResolver.resolve('house', mode: IpaSaveMode.dict);
      expect(r, isNotNull);
      expect(r!.ipa, '/haʊs/');
      expect(r.source, 'mdx');
    });

    test('dict mode: không có từ điển → null (KHÔNG fall G2P)', () async {
      IpaResolver.dictLookupOverride = (_) async => [];
      IpaResolver.cmuWordIpaOverride = (_) => 'ˈwɝld';
      IpaResolver.g2pWordIpaOverride = (_) => 'ˈwɝld';
      final r = await IpaResolver.resolve('world', mode: IpaSaveMode.dict);
      expect(r, isNull);
    });

    test('auto: hết MDX → CMU (provenance cmu)', () async {
      IpaResolver.dictLookupOverride = (_) async => [];
      IpaResolver.cmuWordIpaOverride = (w) => w == 'world' ? 'wɝld' : null;
      IpaResolver.g2pWordIpaOverride = (_) => 'ˈwɝldz';
      final r = await IpaResolver.resolve('world', mode: IpaSaveMode.auto);
      expect(r, isNotNull);
      expect(r!.ipa, '/wɝld/');
      expect(r.source, 'cmu');
    });

    test('auto: CMU miss → G2P (provenance g2p)', () async {
      IpaResolver.dictLookupOverride = (_) async => [];
      IpaResolver.cmuWordIpaOverride = (_) => null;
      IpaResolver.g2pWordIpaOverride = (_) => 'ˈfoʊni';
      final r = await IpaResolver.resolve('phoney', mode: IpaSaveMode.auto);
      expect(r, isNotNull);
      expect(r!.ipa, '/ˈfoʊni/');
      expect(r.source, 'g2p');
    });

    test('g2p mode: bỏ qua MDX dù MDX có (vẫn CMU nếu bật)', () async {
      IpaResolver.dictLookupOverride =
          (_) async => [_entry(phonetic: 'wɝld')];
      IpaResolver.cmuWordIpaOverride = (_) => 'wɝld';
      final r = await IpaResolver.resolve('world', mode: IpaSaveMode.g2p);
      expect(r, isNotNull);
      expect(r!.source, 'cmu');
    });

    test('chữ không ASCII → không G2P; auto không dict → null', () async {
      IpaResolver.dictLookupOverride = (_) async => [];
      IpaResolver.cmuWordIpaOverride = (_) => 'x';
      IpaResolver.g2pWordIpaOverride = (_) => 'x';
      final r = await IpaResolver.resolve('chào', mode: IpaSaveMode.auto);
      expect(r, isNull);
    });

    test('cụm ASCII: join từng từ, 1 từ thiếu IPA → bỏ cả cụm', () async {
      IpaResolver.dictLookupOverride = (_) async => [];
      IpaResolver.cmuWordIpaOverride = (w) => w == 'well' ? 'wɛl' : null;
      IpaResolver.g2pWordIpaOverride =
          (w) => w == 'known' ? 'noʊn' : null;
      final ok =
          await IpaResolver.resolve('well known', mode: IpaSaveMode.auto);
      expect(ok, isNotNull);
      expect(ok!.ipa, '/wɛl noʊn/');
      expect(ok.source, 'g2p'); // có 1 từ qua G2P → trung thực 'g2p'

      IpaResolver.g2pWordIpaOverride = (_) => null;
      final missing =
          await IpaResolver.resolve('well unknownword', mode: IpaSaveMode.auto);
      expect(missing, isNull);
    });

    test('IpaSaveMode.fromName: khớp storage, lạ → auto', () {
      expect(IpaSaveMode.fromName('auto'), IpaSaveMode.auto);
      expect(IpaSaveMode.fromName('dict'), IpaSaveMode.dict);
      expect(IpaSaveMode.fromName('g2p'), IpaSaveMode.g2p);
      expect(IpaSaveMode.fromName('off'), IpaSaveMode.off);
      expect(IpaSaveMode.fromName('whatever'), IpaSaveMode.auto);
    });
  });
}
