# Canon — Kho Kinh Chuẩn (.md + FTS)

> "Ngon - Bổ - Rẻ" nhất cho app Phật pháp: Kinh chuẩn lưu local dạng .md, đọc 0ms, offline 100%.

## Cấu trúc

```
assets/canon/
  dhammapada_001-002.md
  kinh_tu_niem_xu_mn10.md
  kinh_chuyen_phap_luan_sn56.11.md

lib/features/canon/
  models/
    canon_entry.dart          // Model đã parse
    canon_search_result.dart  // hit + snippet + score
  services/
    canon_frontmatter_parser.dart // parse --- YAML ---
    canon_tokenizer.dart          // bỏ dấu TV, tokenize Pali/VI/EN
    canon_fts_service.dart        // inverted index Hive (FTS5-like)
    canon_loader.dart             // load assets + cache Hive
  canon_repository.dart           // facade duy nhất UI cần gọi
  widgets/
    canon_search_sheet.dart       // demo search + reader
```

## Format .md

```markdown
---
id: dhammapada_001
slug: dhammapada-yamakavagga-1-2
title: Kinh Pháp Cú - Phẩm Song Yếu (1-2)
title_pali: Yamakavagga
category: phat_phap_chuan
collection: Khuddaka Nikaya
tags: [phap_cu, dhammapada, yamakavagga]
pali_ref: Dhp 1-2
translator: HT. Thích Minh Châu
language: vi
---
# Phẩm Song Yếu - Kệ 1 & 2
> Pāli gốc ...
Việt dịch ...
```

Parser tự loại bỏ `---` header, parse key:value thủ công (không cần `yaml` package), strip markdown để tạo `plainText` cho FTS.

## FTS — Hive inverted index (hiện tại)

- `token (không dấu)` → `{ docId: tf }` trong box `canon_fts_index`
- `_docLengths` + `_docCount` để tính TF-IDF: `score = (tf / docLen) * log(1 + N/df) * 100`
- Query: tokenize `query` → AND (intersection) nếu có kết quả, fallback OR (union) nếu không → sort theo score → snippet quanh match đầu tiên.

Ưu: pure Dart, không tăng APK size, chạy Windows/Android/iOS/Web, 3-1000 docs <20ms.
Nhược: với 10k+ docs, ranking kém hơn BM25 chuẩn của SQLite FTS5.

## Nâng lên Drift FTS5 (khi cần)

Trong `canon_fts_service.dart` đã để sẵn code mẫu Drift (comment). Để bật:

1. Thêm vào pubspec.yaml:
   ```yaml
   drift: ^2.20.0
   drift_flutter: ^0.2.0
   sqlite3_flutter_libs: ^0.5.0
   ```
2. Bật `DriftCanonFtsService` trong `canon_repository.dart`:
   ```dart
   final repo = AssetCanonRepository(fts: DriftCanonFtsService());
   ```
3. Tạo virtual table:
   ```sql
   CREATE VIRTUAL TABLE canon_fts USING fts5(id, title, pali, content, tokenize='porter unicode61');
   SELECT * FROM canon_fts WHERE canon_fts MATCH ? ORDER BY rank LIMIT ?
   ```

## Personal notes (ghi chú cá nhân)

- Lưu riêng trong Hive `canon_cache` key `note:<canonId>` (không đụng file .md).
- Sẽ sync riêng lên Supabase/Firestore khi có backend (chỉ sync notes, không sync Kinh chuẩn).
- UI: `CanonReaderScreen` có nút edit → `savePersonalNote()`.

## Cách dùng trong UI

```dart
final canonRepo = AssetCanonRepository();
await canonRepo.init(); // 1 lần khi mở app hoặc lazy khi mở sheet

// Search
final result = await canonRepo.search('niệm xứ');
for (final hit in result.hits) {
  print('${hit.entry.title} — ${hit.score} — ${hit.snippet}');
}

// Suggest
final sugs = canonRepo.suggest('niem'); // -> [niem, niemxu]

// Mở reader
Navigator.push(context, MaterialPageRoute(
  builder: (_) => CanonReaderScreen(repository: canonRepo, canonId: 'mn10_satipatthana'),
));

// Mở sheet search demo
CanonSearchSheet.show(context, canonRepo);
```

Thêm Kinh mới: tạo `assets/canon/ten_file.md` + thêm path vào `CanonLoader.assetPaths` + `pubspec.yaml` (đã wildcard `assets/canon/` nên chỉ cần thêm vào list trong code).
