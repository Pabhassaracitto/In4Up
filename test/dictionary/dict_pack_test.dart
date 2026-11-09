// DICT-PACK-001 — danh mục bộ từ điển tải về (owner 2026-10-25).
//
// Kiểm phần THUẦN: parse JSON danh mục do owner tự host (HuggingFace/GitHub
// raw/CDN). Yêu cầu: dòng hỏng bị bỏ mà KHÔNG làm hỏng cả danh mục; trường
// bắt buộc là id + downloadUrl.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_pack.dart';

void main() {
  group('DictPack.fromJson', () {
    test('parse đủ trường + nhãn hiển thị', () {
      final pack = DictPack.fromJson(<String, dynamic>{
        'id': 'en-vi',
        'name': 'Anh → Việt',
        'description': 'Bộ thử',
        'sourceLang': 'en',
        'targetLang': 'vi',
        'sizeMb': 11.4,
        'entryCount': 386600,
        'version': '1.1',
        'downloadUrl': 'https://example.com/a.mdx',
        'sha256': 'ABC123',
        'license': 'CC0',
        'homepage': 'https://example.com',
      })!;

      expect(pack.id, 'en-vi');
      expect(pack.name, 'Anh → Việt');
      expect(pack.langPairLabel, 'EN → VI');
      expect(pack.sizeLabel, '11.4 MB');
      expect(pack.entryCount, 386600);
      expect(pack.isEnglishVietnamese, isTrue);
      expect(pack.sha256, 'ABC123');
    });

    test('thiếu id hoặc downloadUrl ⇒ null (bỏ dòng)', () {
      expect(DictPack.fromJson(<String, dynamic>{}), isNull);
      expect(
        DictPack.fromJson(<String, dynamic>{'id': 'x'}),
        isNull,
        reason: 'không có link tải thì không cài được',
      );
      expect(
        DictPack.fromJson(<String, dynamic>{'downloadUrl': 'https://a/b.mdx'}),
        isNull,
        reason: 'thiếu id thì không theo dõi được bộ đã cài',
      );
    });

    test('chấp nhận khoá "url" như bí danh của downloadUrl', () {
      final pack = DictPack.fromJson(<String, dynamic>{
        'id': 'x',
        'url': 'https://example.com/x.zip',
      })!;
      expect(pack.downloadUrl, 'https://example.com/x.zip');
    });

    test('sizeMb dạng chuỗi vẫn parse được', () {
      final pack = DictPack.fromJson(<String, dynamic>{
        'id': 'x',
        'downloadUrl': 'https://example.com/x.zip',
        'sizeMb': '42.5',
      })!;
      expect(pack.sizeMb, 42.5);
      expect(pack.sizeLabel, '42.5 MB');
    });
  });

  group('DictPackCatalog.fromJsonString', () {
    test('parse {"packs": [...]} + giữ updated', () {
      final catalog = DictPackCatalog.fromJsonString('''
      {
        "updated": "2026-10-25",
        "packs": [
          {"id": "a", "name": "A", "downloadUrl": "https://e/a.mdx"},
          {"id": "b", "name": "B", "downloadUrl": "https://e/b.mdx"}
        ]
      }
      ''', sourceUrl: 'https://e/packs.json');

      expect(catalog.packs, hasLength(2));
      expect(catalog.updated, '2026-10-25');
      expect(catalog.sourceUrl, 'https://e/packs.json');
      expect(catalog.byId('b')?.name, 'B');
      expect(catalog.byId('zzz'), isNull);
    });

    test('chấp nhận mảng JSON trần', () {
      final catalog = DictPackCatalog.fromJsonString(
        '[{"id": "a", "downloadUrl": "https://e/a.mdx"}]',
      );
      expect(catalog.packs.single.id, 'a');
      expect(catalog.packs.single.name, 'a',
          reason: 'thiếu name ⇒ dùng id để vẫn hiển thị được');
    });

    test('dòng hỏng / trùng id bị bỏ, danh mục còn lại vẫn dùng được', () {
      final catalog = DictPackCatalog.fromJsonString('''
      {"packs": [
        {"id": "a", "downloadUrl": "https://e/a.mdx"},
        {"name": "thiếu id", "downloadUrl": "https://e/x.mdx"},
        {"id": "b"},
        "không phải object",
        {"id": "a", "downloadUrl": "https://e/a2.mdx"}
      ]}
      ''');
      expect(catalog.packs.map((p) => p.id).toList(), <String>['a']);
      expect(catalog.packs.single.downloadUrl, 'https://e/a.mdx',
          reason: 'id trùng ⇒ giữ bản ĐẦU, không nhân đôi dòng');
    });

    test('JSON hỏng hoàn toàn ⇒ danh mục rỗng, không ném', () {
      expect(DictPackCatalog.fromJsonString('{không phải json').isEmpty, isTrue);
      expect(DictPackCatalog.fromJsonString('').isEmpty, isTrue);
      expect(DictPackCatalog.fromJsonString('{}').isEmpty, isTrue);
    });
  });
}
