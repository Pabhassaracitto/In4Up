# Kế hoạch: PDF Reader hiển thị nghĩa/IPA ngay + Từ điển không dư thừa

- **Ngày lập:** 2026-10-24
- **Nhánh:** `arena/65ccbb37-in4up`
- **Yêu cầu gốc (người sở hữu):**
  1. PDF Reader: khi nhấn vào từ, sheet lưu từ **phải hiện ngay nghĩa + IPA** —
     người dùng không phải tự điền mới thấy cách đọc/nghĩa.
     Cơ chế lấy: **ưu tiên mạng → từ điển (MDX đã import) → AI/offline**.
  2. Từ điển: nội dung trích xuất đang **dư thừa** (HTML/CSS/script/entry trùng
     nhau giữa nhiều từ điển). Khi dùng **trong ngữ cảnh khác** (PDF/Read) phải
     cô đọng, đúng nghĩa; khi **tra riêng như một từ điển** phải đầy đủ, đẹp,
     hài hòa (IPA, loại từ, nghĩa đánh số, ví dụ, nguồn).

## 1. Hiện trạng (đọc code, không đoán)

| Điểm | Hiện tại | Vấn đề |
|---|---|---|
| `PdfWordTapSheet` (`lib/features/pdf_reader/widgets/pdf_word_tap_sheet.dart`) | Nghĩa/IPA lấy từ `WordEntry` đã lưu, không có thì `AnalyzedWord.meaning/phonetic` (từ điển nội bộ ~500 từ + lexicon) | Từ ngoài danh sách ⇒ **trống**, buộc người dùng tự điền |
| `PdfWordSaveSection._saveQuick` | `meaning: analysis?.meaning ?? ''` | Nghĩa trống được lưu vào Wordlist ⇒ thẻ sinh từ "chưa có nghĩa" |
| `DictEntry.plainDefinition` | `definition.replaceAll(RegExp(r'<[^>]*>'), '')` | Bỏ tag nhưng **giữ lại CSS/script/entity/URL/tiêu đề lặp** → chuỗi dài, rác |
| `DictResultSheet` (tra từ điển riêng) | Đổ `plainDefinition` thành 1 `Text` | Không có IPA, không loại từ, không đánh số nghĩa, không ví dụ; nhiều bộ từ điển ⇒ nội dung trùng lặp |
| `WordAnalysisSheet._buildMdxCard`, `word_actions_sheet`, `word_mini_pop`, `yt_word_panel` | Cũng đổ `plainDefinition` | Dư thừa y hệt ở các màn khác |

## 2. Kiến trúc triển khai

### 2.1 Lớp làm sạch + cấu trúc hoá từ điển (mới)

`lib/features/dictionary/services/dict_text_cleaner.dart`

- `DictTextCleaner.plain(raw)`: bỏ `<script>/<style>/<head>/<svg>/<iframe>/<audio>…`,
  comment, thẻ `<link>/<meta>/<img>`; đổi block (`br/p/div/li/tr/h1-6`) thành
  xuống dòng; giải mã entity (`&nbsp; &amp; &#39; …`); bỏ dòng CSS/URL/ký tự rác;
  bỏ dòng lặp lại đúng headword; gộp khoảng trắng.
- `DictTextCleaner.parse(raw, headword:)` → `DictDefinition`:
  - `ipa` (chuẩn hoá `/…/`, validate bằng bộ dấu IPA — **không** nhận respelling),
  - `groups`: `DictPosGroup(pos, senses)` → `DictSense(text, examples)` — tách
    theo tiêu đề loại từ (`n.`, `v.`, `adj.`, `danh từ`, `động từ`…) và số thứ
    tự nghĩa (`1.`, `2)`, `(3)`), khử trùng lặp nghĩa, giới hạn số nghĩa,
  - `compactMeaning()`: chuỗi ngắn 2–3 nghĩa để nhúng trong PDF/Read.
- `DictTextCleaner.merge([...])` → `DictMergedEntry`: gộp nhiều từ điển, **khử
  nghĩa trùng** (giữ nhãn nguồn) — hết cảnh 3 bộ từ điển in cùng một nghĩa 3 lần.

### 2.2 Nguồn mạng + điều phối "mạng → từ điển → offline" (mới)

`lib/features/word_lookup/services/online_dictionary_source.dart`
- `https://api.dictionaryapi.dev/api/v2/entries/en/<word>` (miễn phí, không key)
  → IPA + loại từ + định nghĩa tiếng Anh + ví dụ. Timeout ngắn, lỗi ⇒ `null`
  (không ném). Có seam `lookupOverride` cho test (không gọi mạng thật).

`lib/features/word_lookup/services/word_insight_service.dart`
- `WordInsightService()` có 2 bước: `resolveLocal()` (MDX → offline, hiện
  ngay) rồi `resolve()` (mạng → cục bộ, nâng cấp kết quả). Waterfall **một
  chiều** cho từng bước:
  1. **Mạng**: online dictionary → dịch nghĩa sang ngôn ngữ đích bằng
     `TranslationService` (đã có pipeline online-first + offline fallback).
  2. **Từ điển MDX**: `DictionaryService.lookup` → `DictTextCleaner` → nghĩa
     cô đọng + IPA (entry.phonetic hoặc trích `/…/`).
  3. **Offline/AI**: `OfflineDictionary` (EN→VI) → `IpaResolver` (CMU → G2P) →
     `SyntaxHighlighterService.analyzeWord().meaning`.
- Kết quả `WordInsight{word, ipa, ipaSource, meaning, englishMeaning, pos,
  entries, definitions, origin}` + cache trong phiên; seam override cho test.
- `ipaSource` mở rộng provenance của ADR-0005 thêm `online` (chip "WEB").

### 2.3 Hiển thị

- `lib/features/dictionary/widgets/dict_definition_view.dart`: render
  `DictDefinition`/`DictMergedEntry` 2 chế độ:
  - **compact**: IPA + chip loại từ + tối đa N nghĩa + "+x nghĩa khác" +
    nút "Xem từ điển đầy đủ".
  - **full**: bố cục từ điển thật — headword lớn, IPA, nhóm loại từ, nghĩa đánh
    số, ví dụ in nghiêng, nhãn nguồn.
- `lib/features/dictionary/widgets/dict_entry_detail_sheet.dart`: "trang từ
  điển" đầy đủ (mở từ PDF/Lookup). `DictResultSheet` (tra riêng) dùng lại chế
  độ full + gộp/khử trùng.
- `PdfWordTapSheet`: stateful, gọi `WordInsightService` khi mở; hiện skeleton
  trong lúc tra; nghĩa + IPA hiện ngay khi có; chip nguồn (Mạng/Từ điển/Offline);
  nút mở trang từ điển đầy đủ; **nghĩa/IPA đã tra được truyền vào phần lưu**
  (`PdfWordSaveSection`, `saveWordToMemory`, `phoneticSource='online'|'mdx'|…`).
- `WordAnalysisSheet` (MDX card) dùng bản compact + nút mở full.

### 2.4 i18n (quy tắc #5)

Mọi nhãn mới: `uiText('…')` + mục trong `tool/legacy_ui_english_overrides.json`
và cập nhật `lib/core/language/generated_legacy_ui_fallbacks.dart` (bản `en`
canonical). Không có tiếng Việt trong chrome khi locale ≠ `vi`.

## 3. Kiểm thử

- `test/dictionary/dict_text_cleaner_test.dart`: HTML rác (script/style/link/
  entity/URL/headword lặp) → text sạch; tách POS + số nghĩa; IPA validate;
  merge khử trùng; `plainDefinition` giữ IPA (hợp đồng `IpaDefinitionExtractor`).
- `test/word_lookup/word_insight_service_test.dart`: waterfall bằng seam —
  mạng thắng; mạng lỗi → từ điển; cả hai lỗi → offline; cache; `allowNetwork:false`.
- QA tay: PDF tap từ hiếm (có mạng / mạng yếu / không mạng), locale EN.

## 4. Rủi ro & chặn

- Mạng chậm: timeout 4s + cache; mở sheet vẫn hiện dữ liệu offline trước.
- Mạng trả nghĩa tiếng Anh khi dịch lỗi ⇒ vẫn hiển thị (không chặn).
- Không đụng `mdx_parser` (DICT-001) — chỉ làm sạch ở đầu ra.
- Không đổi rect/identity PDF (quy tắc vàng #3).
