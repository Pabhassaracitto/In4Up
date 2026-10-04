# ADR-0007: Cấu trúc câu — lớp RIÊNG, tái dùng service sẵn có, line-first + side-table, luật-cục-bộ là đường chính

- **Ngày:** 2026-09-24 (đổi số `0006 → 0007` ngày 2026-09-27: nhánh tích hợp
  `arena/01a0251e-in4up` đã dùng ADR-0006 cho LHB-006 trước khi ADR này vào)
- **Trạng thái:** 📋 ĐỀ XUẤT (chưa code trong sản phẩm) — đặc tả đã kiểm chứng bằng spike
  `tool/grammar_probe/` (xem PLAN-031 §7)
- **Phạm vi:** tab Đọc (`lib/features/grammar/**`, `read_mode/sheets/word_actions_sheet.dart`,
  `read_mode/sheets/read_settings_sheet.dart`), lớp đọc dữ liệu (`TextProvider` — chỉ thêm
  side-table, **không** đổi schema `TextItem`).
  KHÔNG đổi `ColorMode`/legend POS-CEFR, KHÔNG thêm dependency, KHÔNG đụng `lib/ffi/`,
  KHÔNG đổi `TextSplitterService`.
- **Liên quan:** PLAN-031, KANBAN `READ-GRAM-001`, ADR-0005 (bài học "lớp riêng, không trộn ngữ nghĩa")

## Bối cảnh

Người sở hữu yêu cầu thêm 2 tầng phân tích vào đúng chỗ badge "Loại từ · CEFR" trong tab Đọc:
(1) nhận diện **cụm từ** (NP/VP/AdvP/…), (2) nhận diện **cấu trúc câu** (hỏi/khẳng định/phủ định,
thì quá–hiện–vị, hoàn thành, tiếp diễn, công thức `S + V + …`).

Ràng buộc thực tế của repo:

- `GrammarAnalysisService` hiện chỉ chạy **cấp token theo dòng** (`GrammarAnalysisResult{sourceText,
  tokens, sourceLabel}`) — không có mô hình cụm, không có câu.
- `TextProvider` **line-first**: nội dung là `List<TextItem>`, cắt bằng
  `TextSplitterService.split(..., mode: SplitMode.smart)`; nhịp TTS đang bám theo dòng.
- Đã có sẵn: `TextSegmenter.sentences/clauses/phrases` (an toàn viết tắt, trả `Segment{text,start,end}`),
  `GrammarLexiconService` (từ loại + biến thể + lemma), `SyntaxHighlighterService.tokenizeText`,
  và một đường AI sẵn có (`AiAnalysisType.sentenceParse` → `GrammarAnalysis{subject,verb,…,explanationVi}`,
  hiện chỉ `write_studio_screen.dart` gọi).
- Máy chạy CI **không có** Flutter/Dart trong môi trường phát triển của agent ⇒ cần một cách kiểm chứng
  thuật toán **trước khi** viết Dart (spike Python ở `tool/grammar_probe/`).

## Quyết định

1. **Một lớp mới `SentenceStructureService` (thuần Dart, không phụ thuộc Flutter), tái dùng hạ tầng có sẵn.**
   - Token/offset: `SyntaxHighlighterService.tokenizeText` + `GrammarToken.startOffset/endOffset`.
   - Từ loại/lemma/biến thể: `GrammarLexiconService` — **không** dựng bảng từ mới trong code.
   - Biên câu/mệnh đề: `TextSegmenter.sentences/clauses` — **không** viết lại bộ tách câu.
   - `engine.py` (spike) chỉ là **đặc tả chạy được**; bản Dart viết lại theo idiom Dart và phải
     chứng minh **parity** bằng 3 corpus JSON (PLAN-031 §7.2). Bảng từ 60 dòng của spike bị bỏ.

2. **Câu vắt dòng: giữ `line-first` + thêm side-table (không đổi schema).**
   - P1: phân tích theo dòng đang chứa từ; dòng không kết bằng `.?!` ⇒ nhãn thì/thể/công thức hạ
     `confidence` và UI ẩn (có dòng nhắc "câu có thể tiếp tục ở dòng dưới").
   - P2: `SentenceJoiner` dựng 1 lượt khi load document → `Map<lineIndex, SentenceRef{sentenceId,
     startLine, endLine, offsetInSentence}>`, cache theo doc id.
   - **Lý do:** đổi `TextItem` sang sentence-first sẽ lan ra tầng TTS/nhịp/`synced_line`/lưu đoạn
     (đã có READ-630-01..04 bám theo dòng) — rủi ro cao, lợi ích chỉ ở lớp phân tích vốn độc lập.
     Side-table đủ để hiển thị và rollback được.

3. **Luật cục bộ là đường chính; AI là bổ trợ có nhãn.**
   - Yêu cầu sản phẩm: đa số người dùng **chưa nạp model AI** ⇒ nhãn cụm/cấu trúc phải hoạt động
     offline 100%, không gọi mạng.
   - Khi có model: nút "Giải thích chi tiết (AI)" dùng façade `analyzeSentenceWithResult` sẵn có,
     hiển thị ở **block riêng có nhãn AI**; nếu AI lệch luật thì ghi rõ "AI gợi ý khác", **không**
     trộn hai nguồn vào một nhãn.

4. **Precision-first: trả `null`/ẩn nhãn thay vì đoán.**
   - Mọi kết quả có `confidence` + `notes[]`; UI có một ngưỡng duy nhất (mặc định 0.6).
   - Ngôn ngữ ≠ EN (có dấu tiếng Việt/Pali, tỉ lệ ASCII thấp, mật độ hư từ thấp) ⇒ `supported=false`
     và UI hiện "chưa hỗ trợ" — giữ nguyên hành vi fail-safe đã kiểm chứng ở spike (case E47).

5. **Cấu hình tách riêng:** key `sentence_structure_settings_v1` (mặc định: section trong sheet ON,
   chip cấp dòng OFF), không sửa `grammar_highlight_settings_v1` hay bảng màu POS/CEFR/legend.

6. **Nhãn mới phải qua luật #5** (locale ≠ vi ⇒ tiếng Anh; bản dịch ưu tiên `en/hi/zh/zh_TW/si`
   trong cùng PR; **không** dùng `generate_arbs.py`), kèm test cổng kiểu
   `test/pdf_reader/pdf_reader_i18n_coverage_test.dart`.

## Hệ quả

- (+) Không nhân bản logic tách câu/từ vựng; POS nhất quán ở mọi nơi trong Read tab; P1 nhỏ, rollback 1 chỗ.
- (+) Kiểm chứng được **trước khi** viết Dart (spike + 3 corpus, đo được 17/25 case trên bộ đóng băng
  và phân loại 4 nguyên nhân gốc — PLAN-031 §7.1).
- (+) AI vẫn dùng được nhưng không phải điều kiện sống còn của tính năng.
- (−) P1 chấp nhận sai số với câu vắt dòng (đã có nhãn nhắc + hạ `confidence`).
- (−) Phải giữ parity giữa đặc tả Python và bản Dart ⇒ cần golden test Dart nạp chính corpus JSON
  (chi phí nhỏ, lợi ích: chống hồi quy + tài liệu sống).
- (−) Trần độ chính xác là tự nhiên (ngữ pháp Anh không phủ hết bằng luật): tài liệu ghi rõ ngưỡng
  kỳ vọng ≥ 88% case-đúng-trọn sau P2, không hứa 100%.

## Phương án đã cân nhắc và loại

| Phương án | Vì sao loại |
|---|---|
Đổi `TextItem` sang sentence-first, TTS bám câu | Lan ra nhiều tầng đang ổn định (nhịp, lưu đoạn, synced_line); lợi ích không tương xứng |
Đưa hết vào `GrammarAnalysisService` (thêm cụm/câu vào `GrammarAnalysisResult`) | Service này cấp token theo dòng và đang được highlight dùng; nhồi thêm sẽ tăng rủi ro hồi quy cho lớp tô màu |
Chỉ dùng AI (`sentenceParse`) | Không chạy khi chưa nạp model; tốn tài nguyên; không ổn định cho nhãn hiển thị tức thời |
Port nguyên `engine.py` sang Dart | Bảng từ yếu + trùng lặp với `GrammarLexiconService`; vi phạm "tái dùng, không chuyển ngữ máy móc" |
Màn hình/panel riêng ngay từ đầu | Thêm bước điều hướng cho việc đang làm; P1 trong sheet nhỏ hơn và đúng yêu cầu ("chỗ Loại từ, CEFR") |
