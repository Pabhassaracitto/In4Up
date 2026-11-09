# ADR-0014: Tra nghĩa/IPA ưu tiên mạng + chuẩn hoá nội dung từ điển

- **Ngày:** 2026-10-24
- **Trạng thái:** ĐÃ TRIỂN KHAI (nhánh `arena/65ccbb37-in4up`; CI 🟢 run
  40123407509 — analyzer 0 error + test DICT-CLEAN-001/WORD-INSIGHT-001 xanh)
- **Phạm vi:** `lib/features/word_lookup/services/*` (mới),
  `lib/features/dictionary/services/dict_text_cleaner.dart` (mới),
  `lib/features/dictionary/widgets/dict_definition_view.dart`,
  `dict_entry_detail_sheet.dart`, `dict_result_sheet.dart` (viết lại),
  `PdfWordTapSheet` (PDF Reader), `WordAnalysisSheet`, `DictEntry`,
  `VocabularyBridge` (thêm `phoneticSource`).
  KHÔNG đụng `mdx_parser` (DICT-001), KHÔNG đổi `PdfGeometry`/`PdfFileIdentity`
  (quy tắc vàng #3), KHÔNG đổi smoke test rect.

## Bối cảnh

Người sở hữu phản hồi hai điểm:

1. Trong PDF Reader, khi chạm một từ, sheet hiện ra **chỉ** dùng nghĩa/IPA đã
   lưu hoặc lexicon nội bộ (`AnalyzedWord`). Từ nằm ngoài danh sách đó ⇒ hai ô
   trống, người dùng phải tự điền mới thấy cách đọc/nghĩa — trải nghiệm kém.
2. Nội dung trích từ từ điển MDX bị **dư thừa**: pipeline cũ chỉ
   `replaceAll(RegExp(r'<[^>]*>'))`, nên vẫn còn CSS/`<script>`/`&nbsp;`/URL/
   dòng lặp headword, và khi 2–3 bộ từ điển cùng trả một từ thì sheet in ra
   nhiều khối text gần giống nhau, không có IPA/loại từ/nghĩa đánh số.

## Quyết định

### 1. Waterfall một chiều cho nghĩa + IPA khi tra từ

`WordInsightService.resolve(word)`:

```
MẠNG (dictionaryapi.dev, không key) → dịch nghĩa bằng TranslationService
   → TỪ ĐIỂN đã import (MDX) → DictTextCleaner
      → OFFLINE (OfflineDictionary → SyntaxHighlighterService; IPA: CMU → G2P)
```

- Áp dụng cho `PdfWordTapSheet` (mở sheet là tra ngay, có skeleton trong lúc
  chờ; nghĩa/IPA đã tra được truyền thẳng vào `PdfWordSaveSection` và
  `saveWordToMemory`, KHÔNG lưu thẻ trống nghĩa).
- **Hai pha để không bắt người dùng chờ mạng:** `resolveLocal()` (MDX +
  offline, rất nhanh) hiện trước; sau đó `resolve()` (mạng) nâng cấp kết quả
  nếu mạng trả về. Hai cache riêng — kết quả cục bộ KHÔNG chặn lần tra mạng.
- Không bao giờ ném: nguồn nào lỗi/không có thì bỏ qua, trả kết quả một phần.
- Cache theo từ trong phiên (mở lại sheet không gọi mạng lần nữa).
- Seam override tĩnh cho mọi nguồn (`onlineLookupOverride`,
  `dictionaryLookupOverride`, `translateOverride`, `offlineIpaOverride`,
  `offlineMeaningOverride`) ⇒ test chạy offline, CI không cần egress.
- Timeout mạng 4s: người dùng đang chờ trong sheet, không treo UI.

### 2. Provenance IPA mở rộng (additive với ADR-0005)

`WordEntry.phoneticSource` nhận thêm giá trị `online` (chip "WEB" xanh lá trong
`IpaSourceChip`). Thứ tự vẫn một chiều; **không ghi đè** IPA đã có
(`addWithAutoClassify` smart-fill giữ nguyên hợp đồng cũ).

### 3. Hai chế độ hiển thị từ điển (hết dư thừa)

`DictTextCleaner` bóc HTML thành `DictDefinition{ipa, groups(pos→senses
+examples)}`, khử nghĩa trùng; `DictTextCleaner.merge` gộp nhiều bộ từ điển và
giữ nhãn nguồn.

- **Nhúng** (sheet PDF, Read Mode, YouTube, auto-fill): `DictDefinitionView`
  compact — IPA + 2–3 nghĩa + `+N nghĩa khác` + nút "Xem từ điển đầy đủ";
  auto-fill dùng `DictEntry.compactDefinition` (~200 ký tự) thay vì cả entry.
- **Tra riêng** (`DictResultSheet`, `DictEntryDetailSheet`): trang từ điển đầy
  đủ — headword lớn, IPA, chip loại từ, nghĩa đánh số, ví dụ in nghiêng, nguồn.

`DictEntry.plainDefinition` chuyển sang cleaner nhưng **vẫn giữ chuỗi IPA**
trong text: `IpaDefinitionExtractor` (ADR-0005) trích IPA từ chính text này.

## Hệ quả

- (+) Chạm từ trong PDF là thấy ngay nghĩa + IPA; lưu từ không còn thẻ trống.
- (+) Không còn CSS/script/entity/URL trong nội dung từ điển; nghĩa trùng giữa
  các bộ từ điển chỉ hiện một lần.
- (+) Trang từ điển đầy đủ đọc như từ điển thật.
- (−) Cần mạng cho kết quả tốt nhất; khi mạng yếu/không có → waterfall rơi
  xuống MDX/offline (hành vi cũ được giữ, chỉ bổ sung).
- (−) API miễn phí có thể rate-limit; cache + fallback đảm bảo không chặn.
- Nhãn UI mới đã đăng ký i18n rule #5 (`tool/legacy_ui_english_overrides.json`
  + `generated_legacy_ui_fallbacks.dart`).

## Kiểm thử

- `test/dictionary/dict_text_cleaner_test.dart` — làm sạch HTML, IPA validate,
  tách POS/nghĩa/ví dụ, khử trùng, merge.
- `test/word_lookup/word_insight_service_test.dart` — waterfall bằng seam,
  cache, `allowNetwork:false`, parser JSON.
- `test/dictionary/dict_result_sheet_test.dart` — cập nhật theo UI gộp/khử trùng.
