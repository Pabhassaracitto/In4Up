// test/line_ipa_service_test.dart
//
// Unit test P1 (READ-IPA-001): LineIpaService.buildLineIpa —
// eligibility, join phoneme `''`, cache theo content.
// Dùng wordIpaOverride seam → không cần asset CMU Dict trong test.
//
// Contract (README-IPA-006 mục 1 — KHÔNG còn bỏ cả dòng vì 1 token lạ):
//  - dòng không có từ ASCII nào (thuần Việt/Pali) → null;
//  - token dính dấu câu / từ ngoại có dấu → tách run chữ, skip phần lạ,
//    giữ từ Anh (thay cho `null` cả dòng của v1).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/line_ipa_service.dart';

void main() {
  setUp(() {
    LineIpaService.clearCache();
    LineIpaService.wordIpaOverride = null;
  });

  tearDown(() {
    LineIpaService.wordIpaOverride = null;
    LineIpaService.clearCache();
  });

  String? Function(String) fakeTable(Map<String, String> table) {
    return (word) => table[word.toLowerCase()];
  }

  group('buildLineIpa — eligibility', () {
    test('dòng Anh ASCII → IPA từng từ, join bằng space', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'she': 'ʃiː',
        'sells': 'sɛlz',
        'seashells': 'ˈsiːʃɛlz',
      });
      expect(
        LineIpaService.buildLineIpa('She sells seashells'),
        'ʃiː sɛlz ˈsiːʃɛlz',
      );
    });

    test('dấu câu bám quanh từ bị bỏ, không lọt vào dòng IPA', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'hello': 'həˈloʊ',
        'world': 'wɝld',
      });
      expect(LineIpaService.buildLineIpa('Hello, (world)!'), 'həˈloʊ wɝld');
    });

    test('token toàn dấu câu bị bỏ qua, không tính là từ', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'hello': 'həˈloʊ',
        'world': 'wɝld',
      });
      // Token "—" là punct-only → skip; dòng vẫn hợp lệ.
      expect(LineIpaService.buildLineIpa('Hello — world'), 'həˈloʊ wɝld');
    });

    test('dòng thuần Việt (không từ ASCII nào) → null, không resolve', () {
      var called = false;
      LineIpaService.wordIpaOverride = (_) {
        called = true;
        return 'x';
      };
      // 'chào' và cả dòng đều không có từ ASCII → null.
      expect(LineIpaService.buildLineIpa('chào'), isNull);
      expect(LineIpaService.buildLineIpa('đây là tiếng Việt'), isNull);
      // Không từ ASCII → fail TRƯỚC khi resolve → resolver không gọi.
      expect(called, isFalse);
    });

    test('dòng lẫn từ Anh + chữ Việt → giữ từ Anh, bỏ chữ Việt (v2)', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'hello': 'həˈloʊ',
        'world': 'wɝld',
      });
      expect(LineIpaService.buildLineIpa('Hello chào world'), 'həˈloʊ wɝld');
    });

    test('từ ngoại có dấu (Pali cetanā / Pāḷi) đứng riêng → skip, giữ từ Anh',
        () {
      LineIpaService.wordIpaOverride = fakeTable({
        'mind': 'maɪnd',
        'is': 'ɪz',
      });
      // (cetanā) là cụm ngoại bọc ngoặc → skip; 2 từ Anh vẫn có IPA.
      expect(
        LineIpaService.buildLineIpa('mind (cetanā) is'),
        'maɪnd ɪz',
      );
    });

    test('dính dấu câu consciousness.If → tách, lookup đúng từ (cause B)', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'consciousness': 'ˈkɑːnʃəsnəs',
        'if': 'ɪf',
      });
      expect(
        LineIpaService.buildLineIpa('consciousness.If'),
        'ˈkɑːnʃəsnəs ɪf',
      );
    });

    test('dính từ ngoại wholesome(kusa la), → tách, lookup đúng từ (cause B)',
        () {
      LineIpaService.wordIpaOverride = fakeTable({
        'wholesome': 'ˈhoʊlsəm',
      });
      // (kusa la) là cụm ngoại bọc ngoặc → skip; phần Anh vẫn có IPA.
      expect(
        LineIpaService.buildLineIpa('wholesome(kusa la),'),
        'ˈhoʊlsəm',
      );
    });

    test('digit bám ngoài từ bị strip → từ vẫn hợp lệ', () {
      // "covid19" → strip "19" (digit không phải letter) → core "covid".
      LineIpaService.wordIpaOverride = fakeTable({
        'covid': 'koʊvɪd',
        'rules': 'ruːlz',
      });
      expect(LineIpaService.buildLineIpa('covid19 rules'), 'koʊvɪd ruːlz');
      expect(LineIpaService.buildLineIpa('covid, rules'), 'koʊvɪd ruːlz');
    });

    test('hyphen nội tại → tách run, mỗi phần thành từ (v2 khoan dung)', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'a': 'ə',
        'well': 'wɛl',
        'known': 'noʊn',
        'fact': 'fækt',
      });
      expect(LineIpaService.buildLineIpa('a well-known fact'), 'ə wɛl noʊn fækt');
    });

    test('từ có apostrophe hợp lệ', () {
      LineIpaService.wordIpaOverride = fakeTable({'don\'t': 'doʊnt'});
      expect(LineIpaService.buildLineIpa("Don't panic"), 'doʊnt');
    });

    test('dòng không có từ nào (toàn punct/số/rỗng) → null', () {
      LineIpaService.wordIpaOverride = (_) => 'x';
      expect(LineIpaService.buildLineIpa('!!! ... —'), isNull);
      expect(LineIpaService.buildLineIpa(''), isNull);
      expect(LineIpaService.buildLineIpa('   '), isNull);
      expect(LineIpaService.buildLineIpa('123 456'), isNull);
    });

    test('resolver trả rỗng cho mọi từ → null', () {
      LineIpaService.wordIpaOverride = (_) => '';
      expect(LineIpaService.buildLineIpa('Hello world'), isNull);
    });
  });

  group('buildLineIpa — join semantics', () {
    test('join(\'\') không thêm dấu chấm (khác ipaString)', () {
      LineIpaService.wordIpaOverride = (w) => switch (w.toLowerCase()) {
        'world' => 'wˈɝld',
        _ => '',
      };
      expect(LineIpaService.buildLineIpa('world'), 'wˈɝld');
      expect(LineIpaService.buildLineIpa('world'), isNot(contains('.')));
    });
  });

  group('buildLineIpa — cache', () {
    test('cùng content → resolver chỉ chạy 1 lần', () {
      var calls = 0;
      LineIpaService.wordIpaOverride = (w) {
        calls++;
        return 'x';
      };
      final a = LineIpaService.buildLineIpa('Hello');
      final b = LineIpaService.buildLineIpa('Hello');
      expect(calls, 1);
      expect(a, b);
      expect(LineIpaService.cacheSize, 1);
    });

    test('cache cả kết quả null (dòng Việt không tốn повтор compute)', () {
      var calls = 0;
      LineIpaService.wordIpaOverride = (w) {
        calls++;
        return 'x';
      };
      expect(LineIpaService.buildLineIpa('chào'), isNull);
      expect(LineIpaService.buildLineIpa('chào'), isNull);
      // "chào" fail eligibility trước resolve → calls luôn 0;
      // dùng dòng punct để xác minh cache chứa null:
      expect(LineIpaService.buildLineIpa('!!!'), isNull);
      expect(LineIpaService.buildLineIpa('!!!'), isNull);
      expect(calls, 0);
      expect(LineIpaService.cacheSize, 2);
    });

    test('clearCache → compute lại', () {
      var calls = 0;
      LineIpaService.wordIpaOverride = (w) {
        calls++;
        return 'x';
      };
      LineIpaService.buildLineIpa('Hello');
      LineIpaService.clearCache();
      expect(LineIpaService.cacheSize, 0);
      LineIpaService.buildLineIpa('Hello');
      expect(calls, 2);
    });

    test('tràn cache → clear-all rồi tiếp tục', () {
      // Ghi vượt cap 600 để ép clear-all.
      for (var i = 0; i < 601; i++) {
        LineIpaService.buildLineIpa('line $i');
      }
      // Sau vòng trên: entry cuối cùng được ghi sau khi clear → size ≤ 1
      // (clear xảy ra trước khi insert cuối). Chạy tiếp 1 dòng nữa.
      LineIpaService.buildLineIpa('after overflow');
      expect(LineIpaService.cacheSize, lessThanOrEqualTo(2));
    });
  });

  group('buildLineIpaSegments — READ-IPA-003', () {
    test('giữ surface thô + wordCore; punct-only → render-only', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'hello': 'həˈloʊ',
        'world': 'wɝld',
      });
      final segs = LineIpaService.buildLineIpaSegments('Hello, — world');
      expect(segs, isNotNull);
      expect(segs!.length, 3);
      expect(segs[0].surface, 'Hello,');
      expect(segs[0].wordCore, 'Hello');
      expect(segs[0].ipa, 'həˈloʊ');
      expect(segs[0].isWord, isTrue);
      expect(segs[1].surface, '—');
      expect(segs[1].isWord, isFalse);
      expect(segs[1].ipa, isNull);
      expect(segs[2].surface, 'world');
      expect(segs[2].wordCore, 'world');
      expect(segs[2].ipa, 'wɝld');
      // View phẳng từ segments = hợp đồng P1.
      expect(LineIpaService.flatIpa(segs), 'həˈloʊ wɝld');
      expect(LineIpaService.buildLineIpa('Hello, — world'), 'həˈloʊ wɝld');
    });

    test('dòng không đủ điều kiện → segments null (kể cả toàn punct)', () {
      LineIpaService.wordIpaOverride = (_) => 'x';
      expect(LineIpaService.buildLineIpaSegments('chào'), isNull);
      expect(LineIpaService.buildLineIpaSegments('đây là tiếng Việt'), isNull);
      expect(LineIpaService.buildLineIpaSegments('!!! ... —'), isNull);
      expect(LineIpaService.buildLineIpaSegments(''), isNull);
    });

    test('resolver rỗng → segment vẫn có (interlinear) nhưng flat null', () {
      LineIpaService.wordIpaOverride = (_) => '';
      final segs = LineIpaService.buildLineIpaSegments('Hello world');
      expect(segs, isNotNull);
      expect(segs!, hasLength(2));
      expect(segs[0].hasIpa, isFalse);
      expect(LineIpaService.flatIpa(segs), isNull);
      expect(LineIpaService.buildLineIpa('Hello world'), isNull);
    });

    test('override → phonemes là 1 blob (P4 tô màu dùng segment.phonemes)',
        () {
      LineIpaService.wordIpaOverride = fakeTable({'world': 'wɝld'});
      final segs = LineIpaService.buildLineIpaSegments('world');
      expect(segs!.single.phonemes, ['wɝld']);
    });

    test('token dính dấu câu → tách từ, punct giữ làm segment skip', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'consciousness': 'ˈkɑːnʃəsnəs',
        'if': 'ɪf',
      });
      final segs = LineIpaService.buildLineIpaSegments('consciousness.If');
      expect(segs, isNotNull);
      expect(segs, hasLength(3));
      expect(segs![0].surface, 'consciousness');
      expect(segs[0].wordCore, 'consciousness');
      expect(segs[0].ipa, 'ˈkɑːnʃəsnəs');
      // Dấu chấm dính giữa 2 từ → segment surface-only (interlinear giữ dấu).
      expect(segs[1].surface, '.');
      expect(segs[1].isWord, isFalse);
      expect(segs[1].ipa, isNull);
      expect(segs[2].surface, 'If');
      expect(segs[2].wordCore, 'If');
      expect(segs[2].ipa, 'ɪf');
      // View phẳng chỉ join phần có IPA (punct không lọt vào).
      expect(LineIpaService.flatIpa(segs), 'ˈkɑːnʃəsnəs ɪf');
    });

    test('token từ ngoại không-ASCII → segment surface-only, không tra IPA',
        () {
      var calls = 0;
      LineIpaService.wordIpaOverride = (w) {
        calls++;
        return w.toLowerCase() == 'mind' ? 'maɪnd' : 'x';
      };
      final segs = LineIpaService.buildLineIpaSegments('mind (cetanā)');
      expect(segs, isNotNull);
      expect(segs, hasLength(2));
      expect(segs![0].wordCore, 'mind');
      expect(segs[0].ipa, 'maɪnd');
      // (cetanā) là cụm ngoại → render nguyên văn, KHÔNG gọi resolver.
      expect(segs[1].isWord, isFalse);
      expect(segs[1].ipa, isNull);
      expect(segs[1].surface, '(cetanā)');
      // Đúng 1 lần resolve cho 'mind'.
      expect(calls, 1);
    });

    test('IpaSegment == theo value — selector không rebuild vô hạn', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'hello': 'həˈloʊ',
        'world': 'wɝld',
      });
      final a = LineIpaService.buildLineIpaSegments('Hello world');
      LineIpaService.clearCache();
      final b = LineIpaService.buildLineIpaSegments('Hello world');
      expect(a, b);
      expect(a!.first.hashCode, b!.first.hashCode);
      expect(a.first, b.first);
    });
  });
}
