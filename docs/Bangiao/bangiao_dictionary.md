# Bàn giao — Từ điển MDX/MDD đa ngữ (DICT-001)

> Agent đọc file này trước khi code. Owner tham khảo khi review.

## 1. Mục tiêu

Tích hợp từ điển MDX/MDD đa ngôn ngữ vào In4Up — người dùng có thể:
- **Tra từ tức thì** khi đọc PDF, TXT, Web, YouTube (tap từ → hiện nghĩa từ từ điển)
- **Quản lý đa từ điển**: import file `.mdx` (+`.mdd` tùy chọn) từ thiết bị, xóa, bật/tắt
- **Đa ngôn ngữ**: hỗ trợ mọi cặp ngôn ngữ trong MDX (EN↔VI, EN↔ZH, JA↔EN, Pali↔VI…)
- **Lưu vào WordList**: nghĩa từ từ điển tự điền vào khi lưu từ (auto-fill meaning/IPA)
- **Offline-first**: tra từ không cần mạng, file MDX lưu trong app documents

## 2. Kiến trúc

### 2.1 Convert MDX → SQLite (chọn approach C)

MDX là binary format phức tạp (zlib compressed, nhiều encoding). Thay vì parser binary
trong app, dùng **Dart parser extract entries → SQLite**:

```
User import .mdx (+ .mdd)
  → MdxParser.parse(filePath) → Stream<MdxEntry>  [isolate, compute-bound]
  → Lưu vào SQLite: dict_entries(dictId, headword, definition_html, ...)
  → Lưu resource MDD vào app documents (audio, images)
  → DictionaryService.registerDb(dictId, dbPath)
```

Lý do chọn SQLite thay vì parse MDX runtime:
- sqflite đã có trong dự án (Tipitaka dùng)
- SQLite query O(1) + FTS cho prefix search
- Import 1 lần, tra từ nhanh mãi
- Tránh maintain binary parser phức tạp trong app

### 2.2 File structure

```
lib/features/dictionary/
├── models/
│   ├── dict_entry.dart          ← headword, definitions, phonetic, audio path
│   └── dict_info.dart           ← metadata: id, name, sourceLang, targetLang, entryCount
├── services/
│   ├── mdx_parser.dart          ← Dart parser: .mdx binary → Stream<MdxEntry>
│   ├── dict_db_service.dart     ← SQLite CRUD cho dictionary entries
│   ├── dictionary_service.dart  ← facade: lookup(word) → List<DictEntry>
│   └── dict_import_service.dart ← import file .mdx/.mdd từ device
├── widgets/
│   ├── dict_result_sheet.dart   ← bottom sheet hiển thị kết quả tra từ
│   ├── dict_entry_card.dart     ← card 1 entry (HTML rendering)
│   └── dict_manager_screen.dart ← quản lý từ điển đã import
└── dictionary.dart              ← barrel export
```

### 2.3 Tích hợp vào luồng tra từ hiện tại

```
User tap từ → WordActionsSheet._buildHeader()
  → 1. OfflineDictionary.lookup()        ← giữ nguyên (nhanh, basic, ~500 từ)
  → 2. DictionaryService.lookupMdx()     ← MỚI: tra từ MDX đã import
  → 3. AiServiceFacade.analyzeWord()     ← giữ nguyên (AI deep analysis)
```

Hiển thị ưu tiên:
- MDX result → hiện ngay (tầng 1, nhanh)
- AI analysis → hiện sau (tầng 3, sâu)

### 2.4 Nơi đặt file từ điển

```
getApplicationDocumentsDirectory()/
├── dictionaries/
│   ├── manifest.json                    ← danh sách từ điển đã import
│   ├── en_vi_bdict.dict.sqlite          ← converted DB
│   ├── en_vi_bdict.resources/           ← MDD resources (audio, images)
│   └── ...
```

### 2.5 Tích hợp vào WordActionsSheet

Khi user tap từ trong Read mode:
1. `DictionaryService.lookup(word)` trả `List<DictEntry>` (multi-dict)
2. Hiển thị trong sheet: nghĩa từ từ điển (HTML rendered) + IPA + audio
3. Nút "Lưu từ" → auto-fill meaning từ kết quả từ điển đầu tiên

### 2.6 Tích hợp vào WordAnalysisSheet (YouTube)

Tương tự: `DictionaryService.lookup(word)` → hiển thị trong analysis sheet

## 3. MDX Format (tóm tắt cho parser)

MDX file structure:
- Header: encoding, version, key format, description
- Index: keyword blocks (key_type, encoding, compressed_size, decompressed_size)
- Record blocks: definitions (HTML/text, compressed with zlib/ripemd160)

Parser cần xử lý:
- Đọc header (UTF-8/UTF-16, version 1.x/2.x)
- Giải nén index blocks (zlib)
- Giải nén record blocks (zlib, key_type determines format)
- Extract headword + definition pairs

## 4. Quy tắc ngôn ngữ (i18n)

- **Chrome UI** (nút, tiêu đề, tooltip): theo rule #5 AGENTS.md — locale ≠ vi → English
  - "Từ điển" → "Dictionary" (EN) / "辞書" (JA) / "शब्दकोश" (HI) / "词典" (ZH)
  - Dùng ARB keys hoặc `uiText()` + English overrides
- **Nội dung từ điển** (nghĩa, định nghĩa): giữ nguyên ngôn ngữ gốc — KHÔNG dịch
  - Entry EN→VI: "hello = xin chào" → hiển thị nguyên "xin chào"
  - Entry JA→EN: "こんにちは = hello" → hiển thị nguyên "hello"
- **Import UI**: mô tả bằng ngôn ngữ user (i18n), tên file giữ nguyên
- **Lookup**: so sánh headword không phân biệt hoa/thường, hỗ trợ fuzzy match cơ bản

## 5. Scope & Boundaries

### Trong scope (DICT-001):
- [ ] MDX parser (Dart, pure, isolate)
- [ ] SQLite dict DB service
- [ ] Dictionary service facade
- [ ] Import flow (file_picker → parse → SQLite)
- [ ] Dict manager screen (list, delete, toggle)
- [ ] Tích hợp WordActionsSheet (Read mode)
- [ ] Tích hợp WordAnalysisSheet (YouTube)
- [ ] Auto-fill meaning khi lưu từ
- [ ] i18n chrome UI

### Ngoài scope (tương lai):
- Download từ điển từ server (cần backend/CDN)
- MDX full-text search (chỉ exact + prefix match)
- MDD audio playback trong dict result
- Strok (writing) lookup cho CJK
- StarDict format

## 6. Bẫy / Constraints

- MDX format có nhiều biến thể (version 1.x vs 2.x, encoding khác nhau) — parser
  phải graceful fallback, không crash khi gặp file lạ
- File MDX có thể rất lớn (>100MB) — parse trong isolate, progress callback
- SQLite WAL mode cho performance khi import entry lớn
- Không auto-download từ điển (quy tắc MODELS.md)
- Không đụng vùng bảo vệ UltraTimeStretch FFI
- i18n rule #5: chrome UI không tiếng Việt khi locale ≠ vi

## 7. Package dependencies

```yaml
# pubspec.yaml (không thêm package mới — dùng sqflite + archive đã có)
# Chỉ thêm nếu cần:
flutter_widget_from_html: ^0.14.0  # render HTML từ MDX entry (nếu cần)
```

Lưu ý: `sqflite`, `archive`, `file_picker`, `path_provider` ĐÃ có trong pubspec.

## 8. Test plan

- Unit test: MdxParser (mock binary data)
- Unit test: DictDbService (in-memory SQLite)
- Unit test: DictionaryService (lookup multi-dict)
- Widget test: DictResultSheet
- Integration: import .mdx → lookup → auto-fill meaning

## 9. AT (Acceptance Test)

1. Import file .mdx → hiện trong danh sách từ điển + entry count > 0
2. Tap từ trong Read mode → hiện nghĩa từ từ điển (nếu có)
3. Lưu từ → meaning tự điền từ kết quả từ điển
4. Xóa từ điển → lookup không trả kết quả từ dict đó
5. Import nhiều từ điển → lookup trả kết quả từ tất cả
6. File .mdx hỏng/lạ → báo lỗi rõ, không crash
7. Locale ≠ vi → chrome UI hiện English
