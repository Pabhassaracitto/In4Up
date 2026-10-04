// I4U18-DICT-001 — test thuần cho scanner dictionary set (.mdx + .mdd +
// .css/asset). Scanner thuần Dart nên chạy được trong `flutter test`
// không thiết bị.
//
// Yêu cầu card: chọn folder MDX+MDD+CSS → nhận diện thành 1 dictionary set;
// thiếu file phụ → báo thiếu file nào, vẫn cho dùng phần còn hoạt động.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/dict_bundle_scanner.dart';

DictScannedFile f(String path, [int size = 1024]) =>
    DictScannedFile(path, sizeBytes: size);

void main() {
  group('DictBundleScanner — nhận diện tên file', () {
    test('mdx/mdd/css không phân biệt hoa thường', () {
      expect(DictBundleScanner.isMdxName('Oxford.MDX'), isTrue);
      expect(DictBundleScanner.isMdxName('a.mdx.txt'), isFalse);
      expect(DictBundleScanner.isMddName('Oxford.MDD'), isTrue);
      expect(DictBundleScanner.isCssName('style.CSS'), isTrue);
    });

    test('mdd multi-part (.1.mdd, .2.mdd) + stem', () {
      expect(DictBundleScanner.isMddName('Dict.1.mdd'), isTrue);
      expect(DictBundleScanner.isMddName('Dict.12.MDD'), isTrue);
      expect(DictBundleScanner.isMddName('Dict.mdd.txt'), isFalse);
      expect(DictBundleScanner.mddStem('Dict.2.mdd'), 'dict');
      expect(DictBundleScanner.mddStem('Dict.mdd'), 'dict');
    });

    test('Windows path chuẩn hoá posix', () {
      expect(
        DictBundleScanner.normSep(r'C:\Dicts\Oxford\oxford.mdx'),
        'C:/Dicts/Oxford/oxford.mdx',
      );
    });
  });

  group('DictBundleScanner.scan — ghép set', () {
    test('folder MDX+MDD+CSS chuẩn → 1 set đầy đủ, không báo thiếu', () {
      final report = DictBundleScanner.scan([
        f('Oxford En-En/oxford.mdx', 120 * 1024 * 1024),
        f('Oxford En-En/oxford.mdd', 400 * 1024 * 1024),
        f('Oxford En-En/oxford.css', 40 * 1024),
      ]);

      expect(report.sets, hasLength(1));
      final set = report.sets.single;
      expect(set.suggestedName, 'oxford');
      expect(set.folder, 'Oxford En-En');
      expect(set.mddFiles, hasLength(1));
      expect(set.cssFiles, hasLength(1));
      expect(set.missingParts, isEmpty);
      expect(set.isCompleteBundle, isTrue);
    });

    test('chỉ có MDX → vẫn thành set, báo thiếu .mdd + .css rõ ràng', () {
      final report = DictBundleScanner.scan([
        f('lacviet.mdx', 80 * 1024 * 1024),
      ]);

      expect(report.sets, hasLength(1));
      final missing = report.sets.single.missingParts.join(' | ');
      expect(missing, contains('.mdd'));
      expect(missing, contains('.css'));
      // Không chặn dùng — tra từ vẫn được (degraded).
      expect(report.bestSet, isNotNull);
    });

    test('MDD đổi tên (data.mdd) trong folder 1-MDX vẫn được ghép', () {
      final report = DictBundleScanner.scan([
        f('bvudict/bvudict.mdx', 60 * 1024 * 1024),
        f('bvudict/data.mdd', 90 * 1024 * 1024),
      ]);
      expect(report.sets.single.mddFiles.single.name, 'data.mdd');
    });

    test('multi-part MDD (.mdd/.1.mdd/.2.mdd) gom đủ vào 1 set', () {
      final report = DictBundleScanner.scan([
        f('oa/oa.mdx', 200 * 1024 * 1024),
        f('oa/oa.mdd', 300 * 1024 * 1024),
        f('oa/oa.1.mdd', 300 * 1024 * 1024),
        f('oa/oa.2.mdd', 123 * 1024 * 1024),
      ]);
      expect(report.sets.single.mddFiles, hasLength(3));
      expect(report.sets.single.missingParts, isNot(contains('.mdd')));
    });

    test('nhiều từ điển trong 1 folder — tách thành nhiều set', () {
      final report = DictBundleScanner.scan([
        f('dicts/oxford.mdx', 1),
        f('dicts/oxford.mdd', 1),
        f('dicts/lacviet.mdx', 1),
        f('dicts/lacviet.mdd', 1),
        f('dicts/shared.css', 1),
      ]);

      expect(report.sets, hasLength(2));
      final oxford =
          report.sets.firstWhere((s) => s.suggestedName == 'oxford');
      final lacviet =
          report.sets.firstWhere((s) => s.suggestedName == 'lacviet');
      expect(oxford.mddFiles.single.name, 'oxford.mdd');
      expect(lacviet.mddFiles.single.name, 'lacviet.mdd');
      // css cùng folder gắn vào cả hai set (style dùng chung).
      expect(oxford.cssFiles, hasLength(1));
      expect(lacviet.cssFiles, hasLength(1));
    });

    test('asset cùng folder (hình/font) được kèm theo set dùng link', () {
      final report = DictBundleScanner.scan([
        f('ja/ja.mdx', 1),
        f('ja/ja.mdd', 1),
        f('ja/NotoSansJP.ttf', 5 * 1024 * 1024),
        f('ja/ja.css', 4096),
      ]);

      expect(report.sets.single.assetFiles.single.name, 'NotoSansJP.ttf');
      expect(report.sets.single.allFiles, hasLength(4));
    });

    test('file rác / listing rỗng → không có set, không throw', () {
      expect(DictBundleScanner.scan(const []).sets, isEmpty);
      final junk = DictBundleScanner.scan([
        f('readme.txt', 10),
        f('photo.jpg', 99),
      ]);
      expect(junk.sets, isEmpty);
    });

    test('css/mdd lẻ ngoài mọi folder có MDX → stray báo cho user', () {
      final report = DictBundleScanner.scan([
        f('loose/orphan.css', 12),
        f('loose/orphan.mdd', 12),
      ]);
      expect(report.sets, isEmpty);
      expect(report.strayCompanions, hasLength(2));
    });

    test('path Windows nested vẫn ghép theo thư mục cha', () {
      final report = DictBundleScanner.scan([
        f(r'D:\Dicts\Oxford\oxford.mdx', 7),
        f(r'D:\Dicts\Oxford\oxford.mdd', 7),
        f(r'D:\Dicts\Oxford\oxford.css', 7),
      ]);
      expect(report.sets.single.isCompleteBundle, isTrue);
      expect(report.sets.single.folder, 'D:/Dicts/Oxford');
    });
  });
}
