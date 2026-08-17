# BLUEPRINT AS-IS — TAB VIẾT / WRITING STUDIO CỦA IN4UP

> **Mục đích tài liệu:** mô tả trung thực tab Viết đang tồn tại để chuyển cho các chuyên gia AI, UX, EdTech, NLP và kiến trúc phần mềm đánh giá. Đây chủ yếu là bản **as-is blueprint**, không phải đặc tả của phiên bản lý tưởng.
>
> **Mốc mã nguồn:** trạng thái nhánh `arena/019ffcbe-in4up` ngày 17/08/2026, đã gồm luồng handoff Web/PDF → Viết.
>
> **Cách đọc:** phần 1–12 mô tả baseline trước addendum; phần 13–16 nêu constraint, câu hỏi cần chuyên gia phản biện, mẫu yêu cầu đầu ra và kết luận.
>
> **Cập nhật triển khai D14:** nhánh hiện tại đã bắt đầu áp dụng `WritingAssignment`, tách `AssignmentOrigin` khỏi `ScoringProfile`, giữ `contextText` đầy đủ cho excerpt fallback, dùng document signals không giả lập semantic score, và autosave draft Workspace theo `(sourceKey, task, assignmentId)`. Các mục “chưa có” bên dưới được giữ lại như lịch sử baseline để đối chiếu quyết định đa AI.

---

## 1. Tóm tắt một câu

Tab **Viết** hiện là một **Writing Studio dựa trên nguồn có sẵn**, phục vụ luyện ngoại ngữ bằng active recall: người học lấy câu/đoạn từ văn bản đang đọc, Web Reader hoặc PDF Reader, sau đó làm bài chép, cloze, viết lại hoặc tóm tắt; hệ thống chấm nhanh bằng heuristic offline và có thể bổ sung phản hồi từ mô hình AI local.

Tab này **chưa phải** trình soạn thảo văn bản tổng quát, công cụ viết luận hoàn chỉnh hay hệ thống quản lý bản nháp.

---

## 2. Bối cảnh sản phẩm

In4Up là ứng dụng học tập đa nền tảng với các nhánh chính:

- **Nghe**
- **Nói**
- **Đọc**
- **Viết**
- **Hiểu**
- **Nhớ**

Trong shell hiện tại, **Đọc | Viết** là hai sub-mode của cùng một tab chính. Hai màn hình được giữ trong `IndexedStack`, vì vậy tab Viết dùng chung nguồn văn bản và `TextProvider` với tab Đọc.

### Cách hiểu sản phẩm hiện tại

- **Đọc** thiên về input và phân tích nội dung.
- **Viết** thiên về output có hướng dẫn dựa trên chính nguồn input đó.
- Giá trị cốt lõi hiện tại không phải “mở trang trắng và viết bất cứ thứ gì”, mà là chuyển nội dung vừa đọc thành bài luyện output.
- Thiết kế ưu tiên **offline-first**: chấm cục bộ luôn hoạt động; AI local là tầng tăng cường và không bắt buộc.

### Người dùng mục tiêu đang được ngầm giả định

- Người học ngoại ngữ, đặc biệt là tiếng Anh.
- Người muốn luyện nhớ câu, chính tả, từ khóa, paraphrase và tóm tắt ngắn.
- Người dùng muốn học từ chính bài đọc, PDF, web hoặc lyric đang có trong ứng dụng.

Đây là giả định rút ra từ implementation; hiện chưa thấy persona, JTBD hoặc learning outcome chính thức được mã hóa thành tài liệu sản phẩm.

---

## 3. North Star hiện tại

Có thể diễn đạt logic sản phẩm đang có như sau:

> **Biến nguồn input đang đọc thành một vòng luyện output ngắn, có phản hồi ngay, chạy được offline.**

Chu trình hiện tại:

```text
Chọn nguồn → Chọn câu/dòng → Chọn dạng bài → Viết câu trả lời
→ Chấm nhanh offline → Nhận phản hồi cục bộ
→ Tùy chọn gọi AI local → Chuyển câu khác / làm lại
```

Điểm cần chuyên gia xác định lại: North Star này có nên tiếp tục là **micro-writing drills**, hay tab Viết nên mở rộng thành **một hệ thống viết hoàn chỉnh** gồm idea → outline → draft → revise → publish.

---

## 4. Luồng người dùng hiện có

### 4.1. Trường hợp đã có văn bản trong tab Đọc

1. Người dùng chuyển từ **Đọc** sang **Viết**.
2. Writing Studio đọc `TextProvider.lines` và nguồn tài liệu hiện tại.
3. Nếu tab Đọc đang focus một dòng, người dùng có thể đưa Writing Studio về đúng dòng đó.
4. Người dùng chọn một trong 5 dạng bài.
5. Khi đổi dòng hoặc đổi dạng bài, trạng thái câu trả lời hiện tại được reset.

### 4.2. Trường hợp chưa có văn bản

Writing Studio hiển thị empty state:

- “Cần nguồn văn bản để bắt đầu luyện viết”.
- Nút **Mở Web Reader**.
- Nút **Mở PDF Reader**.

### 4.3. Mở Web Reader từ tab Viết

Web Reader nhận `writingMode = true` và hiển thị rõ **“Nguồn cho Viết”**.

Có hai luồng:

#### A. Dùng toàn bộ bài web

1. Người dùng mở một URL.
2. Chọn **Dùng cả bài**.
3. Web Reader chạy JavaScript để trích xuất main article text.
4. Nội dung được chuyển vào `TextProvider.loadWritingSource(...)`.
5. Reader đóng và quay về Writing Studio.
6. Dạng bài được mở sẵn là **Tóm tắt ngắn**.

#### B. Dùng một đoạn được bôi chọn

1. Người dùng bôi chọn một đoạn trên trang web.
2. Chọn biểu tượng dùng đoạn đó cho Viết.
3. Chỉ đoạn đã chọn được chuyển về Writing Studio.
4. Dạng bài được mở sẵn là **Viết lại ý**.

### 4.4. Mở PDF Reader từ tab Viết

PDF Reader cũng nhận `writingMode = true` và hiển thị banner **Nguồn cho Viết**.

Có hai luồng:

#### A. Dùng toàn bộ PDF

1. Người dùng chọn **Dùng PDF**.
2. PDF Reader chuyển sang text mode và trích xuất toàn bộ text.
3. Nội dung được chuyển về Writing Studio.
4. Dạng bài được mở sẵn là **Tóm tắt ngắn**.
5. Nếu PDF chỉ là ảnh scan và không có lớp text, hệ thống báo không thể lấy chữ; hiện chưa có OCR fallback trong luồng này.

#### B. Dùng đoạn được chọn

1. Người dùng chọn một đoạn text trong PDF.
2. Chọn hành động dùng đoạn đó cho Viết.
3. Đoạn được chuyển về Writing Studio.
4. Dạng bài được mở sẵn là **Viết lại ý**.

### 4.5. Xác nhận handoff

Sau khi nhận nội dung từ reader, Writing Studio hiển thị card:

- Đã nhận toàn bộ nội dung hay chỉ một đoạn.
- Nguồn là Web/PDF/Text.
- Nhãn nguồn.
- Dạng bài đã được mở sẵn.
- Người dùng vẫn có thể đổi sang dạng bài khác.

---

## 5. Cấu trúc màn hình Writing Studio

Theo thứ tự từ trên xuống:

1. **Hero card**
   - Tên “Viết · Writing Studio”.
   - Trạng thái nguồn hiện tại.
   - Số dòng của tài liệu.

2. **Writing source handoff card** — chỉ xuất hiện khi vừa nhận nguồn từ reader.

3. **Quick actions**
   - Web Reader.
   - PDF Reader.
   - Công cụ nhanh.

4. **Context card**
   - Tên tài liệu.
   - Dòng hiện tại và tổng số dòng.
   - Nội dung dòng.
   - Hành động đồng bộ với dòng đang focus bên tab Đọc.

5. **Exercise selector**
   - Chép.
   - Điền từ.
   - Chọn đáp án.
   - Viết lại ý.
   - Tóm tắt ngắn.

6. **Bộ điều hướng bài tập**
   - Dòng trước.
   - Dòng ngẫu nhiên.
   - Dòng sau.

7. **Exercise card** tương ứng với dạng bài đang chọn.

8. **Phản hồi local và AI** nếu dạng bài có hỗ trợ.

9. **Tip card** giải thích vai trò tab Viết.

### Đặc điểm UI

- Giao diện dark theme.
- Màu accent chính: cyan/blue; mỗi loại bài có màu riêng.
- Nội dung nằm trong `ResponsiveContentFrame`.
- Exercise selector dùng layout wrap hai cột theo chiều rộng khả dụng.
- Màn hình chính là một `SingleChildScrollView` dài, chưa có composer/panel sticky.

---

## 6. Năm dạng bài hiện có

## 6.1. Chép chính tả / Recall câu

### Trải nghiệm

- Người dùng có thể nghe dòng hiện tại qua TTS.
- Có thể hiện/ẩn đáp án.
- Gõ lại câu từ âm thanh hoặc trí nhớ.
- Nhấn **Chấm nhanh**.
- Có nút **Làm lại**.

### Chấm cục bộ

Text được lowercase, bỏ ký tự ngoài tập `[a-z0-9']`, rồi token hóa theo khoảng trắng.

Các thành phần:

- `orderScore = LCS(expectedTokens, actualTokens) / expectedTokens.length`
- `spellingScore = 1 - LevenshteinDistance(expectedText, actualText) / maxLength`
- `finalScore = 0.70 × orderScore + 0.30 × spellingScore`

Hệ thống còn tính:

- Từ thiếu bằng phép trừ multiset.
- Từ dư bằng phép trừ multiset.

### Phản hồi cục bộ

Dựa trên các ngưỡng điểm và lỗi, hệ thống sinh:

- Kết luận.
- Thế mạnh.
- Điểm cần sửa.
- Gợi ý cho lượt tiếp theo.
- Tags như “Giữ câu tốt”, “Thiếu từ”, “Vỡ cấu trúc”, “Chính tả”, “Qua câu mới”.

### AI local

Sau khi đã chấm cục bộ, người dùng có thể gọi AI local để nhận thêm:

- Summary.
- Topics.
- Action items.
- Phân tích grammar: subject, verb, pattern…

---

## 6.2. Cloze — Điền từ

### Cách tạo ô trống

Hệ thống xếp hạng token trong dòng dựa trên:

- Độ dài từ.
- Không phải stop word: `+4`.
- POS là noun/verb/adjective/adverb: `+3`; POS khác: `+0.5`.
- CEFR:
  - B2/C1/C2: `+2.5`.
  - B1: `+1.5`.
  - A2: `+0.5`.

Quy tắc số ô trống:

- Dòng dưới 8 token: 1 ô.
- Từ 8 đến 13 token: 2 ô.
- Từ 14 token trở lên: 3 ô.

Hai ô được chọn không nằm quá gần nhau; khoảng cách token phải từ 2 trở lên.

### Cách trả lời và chấm

- Người dùng gõ từ còn thiếu.
- So khớp exact match sau normalization.
- Điểm = số ô đúng / tổng số ô.
- Có thể đổi bộ ô trống và làm lại.
- Hiện đáp án cùng chi tiết `câu trả lời → đáp án`.

Hiện chưa có phản hồi AI riêng cho Cloze.

---

## 6.3. Cloze — Chọn đáp án

Dùng cùng thuật toán chọn từ khóa như Cloze điền từ.

### Distractor hiện tại

- Lấy từ toàn bộ tài liệu hiện hành.
- Chuẩn hóa và loại từ ngắn hơn 3 ký tự.
- Loại đáp án đúng.
- Shuffle và lấy tối đa 3 distractor để tạo tối đa 4 lựa chọn.

### Chấm

- Exact match với đáp án chuẩn hóa.
- Hiển thị lựa chọn đúng/sai bằng màu.
- Điểm = số ô đúng / tổng số ô.

Distractor hiện chưa dựa trên POS tương đồng, hình thái học, semantic similarity hay common learner error.

---

## 6.4. Viết lại ý / Paraphrase

### Trải nghiệm

- Hiển thị câu gốc.
- Người dùng diễn đạt lại bằng câu khác.
- Nhấn **Phân tích bài viết**.
- Nhận điểm tổng và phản hồi chi tiết.
- Có thể gọi AI local để phân tích sâu hơn.

### Trích xuất từ khóa

Tối đa 6 từ khóa:

- Ưu tiên noun, verb, adjective, adverb.
- Loại stop word.
- Nếu POS không thuộc nhóm trên, từ dài từ 5 ký tự vẫn có thể được chọn.
- Nếu không có kết quả phân tích, fallback lấy tối đa 6 từ dài từ 4 ký tự trong câu.

### Điểm thành phần

1. **Completeness / Giữ ý**
   - Tỷ lệ từ khóa có mặt trong câu trả lời.
   - Exact lexical match, chưa dùng semantic equivalence.

2. **Similarity to original**
   - Levenshtein similarity trên chuỗi đã chuẩn hóa.
   - Đây là character-level similarity, không phải semantic similarity.

3. **Paraphrase score**

```text
similarity >= 0.94  → 0.18
similarity >= 0.82  → 0.38
similarity >= 0.58  → 0.82
similarity >= 0.34  → 0.72 nếu completeness >= 0.45, ngược lại 0.50
similarity <  0.34  → 0.64 nếu completeness >= 0.45, ngược lại 0.28
```

4. **Grammar proxy score**
   - Đủ ít nhất 4 token.
   - Có verb giống verb trong câu gốc hoặc thuộc một danh sách common verbs tiếng Anh.
   - Bắt đầu bằng chữ hoa.
   - Kết thúc bằng `.`, `!` hoặc `?`.

### Điểm tổng

```text
overall = 0.50 × completeness
        + 0.22 × grammarProxy
        + 0.28 × paraphrase
```

### Phản hồi

- Giữ ý.
- Hình dáng câu.
- Độ viết lại.
- Từ khóa đã giữ / còn thiếu.
- Nhận xét.
- Điểm mạnh.
- Điểm cần sửa.
- Bước tiếp theo.
- Tags.
- Tùy chọn AI local.

---

## 6.5. Tóm tắt ngắn

### Trải nghiệm

- Hiển thị câu gốc hiện tại.
- Người dùng viết một câu ngắn hơn.
- Nhấn **Chấm tóm tắt**.
- Nhận điểm, phản hồi và tùy chọn AI local.

### Điểm thành phần

1. **Content retention**
   - Tỷ lệ từ khóa được giữ lại.
   - Nếu không có keyword, fallback sang string similarity.

2. **Compression ratio**

```text
số token câu trả lời / số token câu gốc
```

3. **Brevity score**

```text
ratio <= 0.45 → 0.92 nếu contentRetention >= 0.45, ngược lại 0.50
ratio <= 0.70 → 0.82
ratio <= 1.00 → 0.64
ratio >  1.00 → 0.32
```

4. **Grammar proxy**
   - Dùng cùng heuristic với bài Viết lại ý.

### Điểm tổng

```text
overall = 0.50 × contentRetention
        + 0.25 × brevity
        + 0.25 × grammarProxy
```

### Giới hạn quan trọng

Mặc dù **Dùng cả bài Web/PDF** đưa toàn bộ nội dung vào `TextProvider`, bài **Tóm tắt ngắn hiện chỉ chấm dòng/câu đang chọn**, chưa chấm bản tóm tắt toàn bài hoặc toàn đoạn dài. Đây là chênh lệch đáng chú ý giữa affordance của reader và năng lực thật của exercise.

---

## 7. Hệ thống phản hồi hai tầng

## Tầng 1 — Local heuristic

- Luôn khả dụng.
- Không cần model AI.
- Phản hồi gần như tức thì.
- Dựa trên LCS, Levenshtein, exact keyword matching, token count và punctuation/capitalization proxy.
- Có feedback rule-based bằng tiếng Việt.

## Tầng 2 — AI local

- Dùng `AiServiceFacade` từ package `in2up_ai`.
- Engine mặc định: `AiEngineGemma`.
- Người dùng tự import file `.gguf`.
- Dialog hiện khuyến nghị `gemma-2b-it-q4_k_m.gguf` khoảng 1.5 GB.
- Không tự tải model khi khởi tạo.
- Khi không có model, nút AI trong Writing Studio bị vô hiệu hóa nhưng tầng local vẫn hoạt động.
- Facade có retry tối đa 3 lần và kiểm tra hallucination ở mức package AI.

### Prompt contract hiện tại

Writing Studio ghép vào prompt:

- Expected text.
- Actual text.
- Các điểm heuristic.
- Từ khóa thiếu/giữ.
- Yêu cầu AI trả JSON với:
  - `summary`
  - `topics`
  - `action_items`
  - `grammar`

Sau đó gọi chung API:

```text
AiServiceFacade.analyzeSentence(sentence: prompt)
```

Kết quả được ghép với UI qua `_lastAiPromptKey`; chỉ analysis có `inputText` khớp prompt hiện tại mới được hiển thị.

### Định hướng riêng tư hiện tại

Luồng Writing Studio được định hướng local/offline. Nội dung câu gốc và câu người dùng viết được gửi vào model local trên thiết bị, không thấy một cloud-writing API bắt buộc trong flow hiện tại.

---

## 8. State và data model hiện tại

### State dùng chung — `TextProvider`

Giữ:

- Current document.
- Full text.
- Danh sách `TextItem` theo dòng.
- Dòng đang focus.
- Source metadata.
- Syntax/POS/CEFR analysis.
- TTS state.
- Writing handoff request.

### Writing handoff contract

```text
WritingSourceRequest
- task: dictation | cloze | rewrite | summary
- kind: web | pdf | text
- sourceLabel: String
- isExcerpt: bool
```

Ngoài ra có `writingSourceVersion` tăng dần để Writing Studio nhận biết một handoff mới và tự đổi dạng bài.

### State cục bộ trong `WriteStudioScreen`

- Dạng bài hiện tại.
- Chỉ số dòng.
- Text controllers của dictation/rewrite/summary/cloze.
- Kết quả chấm.
- Trạng thái hiện đáp án.
- Prompt AI gần nhất.

### Reset behavior

Các câu trả lời và kết quả bị reset khi:

- Đổi nguồn.
- Đổi dòng.
- Đổi dạng bài.
- Yêu cầu tạo lại cloze.

Hiện không có autosave/restore cho draft đang gõ trước khi reset.

### Source identity

`_sourceKey` được ghép từ:

- `currentTextPath`
- document title
- line count
- `fullText.hashCode`

Writing handoff hiện mang `sourceLabel` nhưng chưa có một provenance object đầy đủ gồm URL/path, range/anchor, page, timestamp, checksum và quyền truy cập.

---

## 9. Kiến trúc hiện tại

```mermaid
flowchart LR
    Shell[MainShell\nĐọc | Viết] --> WS[WriteStudioScreen]
    Shell --> WR[WebReaderScreen]
    Shell --> PR[PdfReaderScreen]

    WR -->|loadWritingSource| TP[TextProvider]
    PR -->|loadWritingSource| TP
    TP --> WS

    WS --> LS[Local scorers\nLCS / Levenshtein / keywords / proxy]
    WS --> TTS[TextProvider TTS]
    WS --> AI[AiServiceFacade]
    AI --> GGUF[Gemma local .gguf]
```

### Các file chính

- `lib/screens/read_mode/write_studio_screen.dart`
  - Khoảng 3.200 dòng.
  - Chứa state, UI, thuật toán tạo bài, scoring, prompt AI và feedback models.

- `lib/providers/text_provider.dart`
  - Nguồn text dùng chung.
  - Chứa writing handoff contract và method `loadWritingSource`.

- `lib/screens/main_shell.dart`
  - Điều phối Đọc | Viết.
  - Mở reader với `writingMode` khi người dùng đang ở tab Viết.

- `lib/features/web_reader/web_reader_screen.dart`
  - Trích xuất article/selection và chuyển sang Viết.

- `lib/features/pdf_reader/pdf_reader_screen.dart`
  - Trích xuất PDF text/selection và chuyển sang Viết.

- `packages/in2up_ai/.../ai_service_facade.dart`
  - Điều phối model local, trạng thái, retry và analysis.

### Pattern

- Flutter + Provider/ChangeNotifier.
- StatefulWidget cho Writing Studio.
- UI, domain logic và scoring đang gắn chặt trong cùng một file/màn hình.
- Chưa thấy repository riêng cho writing attempts, drafts hoặc learning analytics.

---

## 10. Năng lực đã có

### Product/UX

- Quan hệ Đọc → Viết rõ ràng.
- Web/PDF không còn là reader độc lập khi mở từ tab Viết, mà trở thành source picker.
- Có empty state và CTA rõ.
- Có 5 dạng bài dễ khám phá.
- Có line navigator và đồng bộ dòng với tab Đọc.
- Có phản hồi tức thì và hướng dẫn “lượt tiếp theo”.

### Pedagogy

- Active recall.
- Dictation.
- Retrieval qua cloze.
- Paraphrase.
- Compression qua summary.
- Tăng cường output từ input đang học.

### Engineering

- Offline scoring luôn khả dụng.
- AI local là progressive enhancement.
- Web/PDF handoff có typed intent.
- Reader mở từ nơi khác vẫn giữ hành vi cũ.
- Cross-platform theo kiến trúc chung của Flutter app.

### Privacy/cost

- Không phụ thuộc cloud AI cho chức năng cơ bản.
- Local model giảm rủi ro đưa dữ liệu viết ra ngoài và tránh chi phí inference cloud, đổi lại là yêu cầu tài nguyên thiết bị và model lớn.

---

## 11. Những gì tab Viết chưa có

### Không gian sáng tác

- Chưa có **Trang trắng / Free writing**.
- Chưa có prompt writing tự do.
- Chưa có outline, paragraph plan hoặc essay structure.
- Chưa có multi-paragraph editor thực thụ.
- Chưa có revision mode, tracked changes hoặc compare versions.
- Chưa có save draft, autosave, history, export hoặc share bài viết.

### Mục tiêu học tập

- Chưa chọn CEFR target, language target, genre, tone, audience hoặc word limit.
- Chưa có rubric theo dạng bài: email, essay, IELTS/TOEFL, journal, academic writing…
- Chưa có adaptive difficulty theo lịch sử người học.
- Chưa có session goal và trạng thái hoàn thành.

### Feedback

- Chưa có inline annotation tại vị trí lỗi.
- Chưa phân loại lỗi rõ theo grammar, spelling, vocabulary, cohesion, coherence, style.
- Chưa có feedback ưu tiên theo mức độ ảnh hưởng.
- Chưa có “sửa từng vòng” và đo improvement giữa các draft.
- Chưa có user rating cho chất lượng feedback ngay trong Writing Studio.

### Dữ liệu và tiến bộ

- Chưa lưu writing attempt.
- Chưa có attempt history, streak, progress chart hoặc mastery model.
- Chưa kết nối lỗi viết thành card ôn tập ở tab Nhớ.
- Chưa khai thác từ sai/chính tả/grammar pattern để tạo bài luyện tiếp theo.

---

## 12. Rủi ro và technical/product debt đã thấy

## 12.1. Multilingual mismatch — mức nghiêm trọng cao

Normalization hiện dùng regex:

```text
[^a-z0-9']
```

Hệ quả:

- Tối ưu chủ yếu cho tiếng Anh không dấu.
- Có thể loại bỏ chữ cái của tiếng Việt, Pháp, Đức, Tây Ban Nha và hầu hết script ngoài Latin cơ bản.
- Grammar proxy dùng danh sách common verbs tiếng Anh.
- Capitalization và sentence punctuation được coi như đại diện grammar.

Nếu In4Up định vị là app đa ngôn ngữ, scoring hiện tại chưa phù hợp.

## 12.2. Lexical score bị dùng thay semantic score

- Paraphrase và summary dùng exact keyword retention.
- Similarity là Levenshtein theo ký tự.
- Synonym, morphology, pronoun substitution và cấu trúc tương đương có thể bị chấm thấp.
- Câu vô nghĩa nhưng giữ keyword vẫn có thể được điểm content cao.
- Summary có nguy cơ khuyến khích keyword copying hơn là hiểu và tái diễn đạt.

## 12.3. “Tóm tắt cả bài” chưa thực sự là tóm tắt cả bài

Reader cho phép **Dùng cả bài/Dùng PDF**, nhưng scoring và UI chỉ xử lý `currentLine`. Đây là một khoảng cách giữa lời hứa UX và năng lực thật.

## 12.4. Draft loss

Đổi dòng, đổi task hoặc đổi nguồn sẽ clear input. Chưa có:

- Autosave.
- Cảnh báo unsaved changes.
- Cache riêng cho mỗi dòng/task.
- Khả năng quay lại câu vừa làm.

## 12.5. Monolithic architecture

`write_studio_screen.dart` chứa khoảng 3.200 dòng với:

- UI.
- State.
- Scoring.
- Prompt building.
- Feedback rules.
- Result models.

Điều này làm tăng chi phí test, mở rộng task mới, thay scoring engine và tái sử dụng trên nền tảng khác.

## 12.6. Hiệu năng thuật toán

- LCS dùng ma trận `O(tokensA × tokensB)`.
- Levenshtein dùng ma trận `O(charsA × charsB)`.
- Với câu ngắn thì chấp nhận được.
- Nếu full article hoặc paragraph dài vô tình trở thành một line, có nguy cơ tốn CPU/memory và block UI isolate.

## 12.7. AI contract chưa chuyên biệt cho Writing

- Writing Studio đang dùng `analyzeSentence` chung.
- Prompt chứa một block text và yêu cầu JSON, nhưng domain API chưa thể hiện rõ rubric, draft, source, target language, genre và learner profile.
- `AiServiceFacade.currentAnalysis` là state dùng chung toàn app; `_lastAiPromptKey` giảm nhầm kết quả nhưng chưa phải task/session isolation đầy đủ.
- Chưa có benchmark để biết phản hồi model local 2B có đáng tin với writing evaluation hay không.

## 12.8. UX, accessibility và localization

- Nhiều chuỗi tiếng Việt được hardcode trong màn hình thay vì đi qua ARB localization.
- Màn hình dài, nhiều card và metric; cognitive load có thể cao trên mobile.
- Chưa thấy luồng keyboard-first, focus management, screen reader semantics và accessibility audit riêng.
- Chưa có chế độ feedback ngắn/gọn so với chuyên sâu.

## 12.9. Testing

- Chưa có test chuyên biệt cho Writing Studio trong thư mục test hiện tại.
- Các công thức scoring, threshold, handoff Web/PDF và reset behavior chưa có regression test độc lập.
- Chưa có gold dataset do giáo viên/người học gán nhãn để kiểm chứng tương quan giữa điểm máy và chất lượng thật.

---

## 13. Các constraint nên giả định khi tư vấn

Hãy coi đây là constraint hiện tại, nhưng chuyên gia có thể phản biện nếu thấy cần thay đổi:

1. Flutter, Provider/ChangeNotifier và app đa nền tảng.
2. Ưu tiên Windows, Android, iOS; kiến trúc app cũng có web target.
3. Offline-first là lợi thế chiến lược.
4. Tính năng cơ bản không nên phụ thuộc mạng hoặc phí inference cloud.
5. AI local là tùy chọn; không phải thiết bị nào cũng chạy tốt model khoảng 1.5 GB.
6. Phải giữ liên kết với Đọc, Web Reader, PDF Reader, TTS, WordList và Memory ecosystem.
7. Không nên để một AI score thiếu ổn định trở thành “sự thật tuyệt đối” về năng lực người học.
8. Cần phân biệt rõ:
   - Mechanical correctness.
   - Meaning preservation.
   - Language quality.
   - Pedagogical next action.
9. Cần có graceful degradation khi không có model AI.
10. Dữ liệu người học và nội dung tài liệu có thể nhạy cảm; privacy cần được thiết kế ngay từ đầu.

---

## 14. Các câu hỏi mong chuyên gia đánh giá

### A. Product strategy

1. Tab này nên tiếp tục là **source-driven writing drills**, hay phát triển thành **full writing workspace**?
2. Nếu làm cả hai, information architecture nào tránh biến tab thành một “siêu màn hình” quá tải?
3. North Star Metric phù hợp là gì: số bài hoàn thành, số vòng revision, improvement, retained errors hay writing proficiency?
4. Khoảnh khắc “Aha!” nên là gì?

### B. Learning science / pedagogy

5. Năm dạng bài hiện tại có tạo thành progression hợp lý từ copy → recall → controlled output → free output không?
6. Nên thêm task nào trước: sentence combining, translation, guided writing, free writing, paragraph summary, error correction hay essay?
7. Làm sao dùng spacing, retrieval practice và interleaving cho Writing?
8. Làm sao biến lỗi viết thành kế hoạch ôn tập ở tab Nhớ mà không gây quá tải?
9. Rubric nào phù hợp cho beginner, intermediate và advanced?

### C. NLP và scoring

10. Cần thay LCS/Levenshtein/keyword exact match bằng gì để vẫn chạy offline?
11. Có nên dùng multilingual sentence embedding, NLI, grammar checker, edit distance theo token, morphology hay hybrid rubric?
12. Làm sao hiệu chỉnh điểm để không thưởng keyword stuffing hoặc phạt synonym đúng?
13. Grammar proxy nên được thiết kế lại thế nào theo từng ngôn ngữ?
14. Dataset và protocol nào cần có để validate scoring?
15. Khi nào nên trả score số, khi nào chỉ nên đưa feedback định tính và uncertainty?

### D. AI architecture

16. Model local nhỏ nên đảm nhận phần nào; phần nào nên để deterministic engine?
17. Có nên có tùy chọn cloud AI cho thiết bị yếu không? Nếu có, consent/privacy/cost control nên thiết kế thế nào?
18. Writing AI contract nên gồm những field nào: task, rubric, learner level, target language, source, draft, prior draft, constraints, error spans, confidence…?
19. Làm sao chống hallucination và tránh AI “sửa” làm thay người học?
20. Nên dùng một model chung hay pipeline gồm language ID + grammar + embedding + LLM feedback?

### E. UX/UI

21. Luồng tối ưu nên là Source → Brief → Compose → Feedback → Revise → Save/Review như thế nào?
22. Có cần split view nguồn và editor trên desktop/tablet?
23. Mobile composer nên tối giản ra sao để không bị ngập trong card/metric?
24. Feedback nên inline, side panel hay bottom sheet?
25. Khi nào reveal đáp án? Làm sao tránh người dùng “bấm xem” quá sớm?
26. Cần autosave, draft recovery và session completion như thế nào?

### F. Data và analytics

27. Data model tối thiểu cho draft, attempt, revision, rubric score, feedback và source provenance là gì?
28. Nên lưu local bằng Hive/SQLite hay đồng bộ Firestore ở mức nào?
29. Event taxonomy nào giúp đo funnel và learning gain mà vẫn tôn trọng privacy?
30. Làm sao A/B test scoring/feedback mà không gây hại việc học?

### G. Engineering

31. Nên chia `write_studio_screen.dart` thành những domain/service/controller/widget nào?
32. Kiến trúc plugin cho exercise/scorer có đáng làm không?
33. Làm sao chạy scoring nặng ngoài UI isolate và cancel stale jobs?
34. Chiến lược unit, widget, integration và golden test nên ra sao?
35. Roadmap refactor nào cho phép ship giá trị sớm mà không “rewrite everything”?

---

## 15. Mẫu prompt có thể copy nguyên khối gửi cho chuyên gia AI

```text
Bạn đang đóng vai chuyên gia liên ngành về AI/NLP, UX sản phẩm, EdTech/learning science và kiến trúc Flutter.

Tôi gửi kèm “Blueprint AS-IS — Tab Viết của In4Up”. Hãy đánh giá dựa đúng vào hiện trạng được mô tả; đừng giả định các tính năng chưa có.

Mục tiêu của tôi là biến tab Viết thành một sản phẩm có giá trị học tập rõ, liên kết chặt với Đọc/Web/PDF, chạy tốt offline nhưng có thể tận dụng AI khi phù hợp.

Hãy trả lời theo cấu trúc:

1. Executive verdict: Tab Viết hiện đang là sản phẩm gì, mạnh ở đâu, đang mắc kẹt ở đâu?
2. 5 điểm mạnh nên giữ.
3. 10 vấn đề lớn nhất, mỗi vấn đề ghi:
   - mức nghiêm trọng,
   - bằng chứng từ blueprint,
   - tác động đến người học,
   - hướng xử lý.
4. Đề xuất product positioning và North Star rõ ràng.
5. Đề xuất information architecture và user journey mục tiêu.
6. Đề xuất taxonomy bài tập theo progression từ controlled writing đến free writing.
7. Thiết kế lại scoring:
   - deterministic layer,
   - NLP local layer,
   - LLM feedback layer,
   - confidence/uncertainty,
   - cách validate bằng dataset.
8. Đề xuất AI architecture phù hợp với offline-first và thiết bị tài nguyên hạn chế.
9. Đề xuất data model cho source, writing session, draft, attempt, revision, score, feedback và progress.
10. Đề xuất refactor architecture Flutter mà không rewrite toàn bộ app.
11. Roadmap ưu tiên:
    - P0: 0–6 tuần,
    - P1: 2–4 tháng,
    - P2: 4–12 tháng.
   Với mỗi hạng mục hãy ghi Impact, Effort, Risk và Dependency.
12. Bộ KPI và experiment cần chạy để xác minh sản phẩm thực sự giúp người học viết tốt hơn.
13. Những điều KHÔNG nên làm hoặc nên hoãn.

Yêu cầu:
- Phân biệt rõ quick win, foundational work và speculative bet.
- Ưu tiên giải pháp có thể ship dần.
- Không coi điểm AI là ground truth.
- Chỉ ra các trade-off giữa offline, chất lượng, tốc độ, kích thước model, privacy và chi phí.
- Nếu thiếu dữ kiện, hãy nêu câu hỏi cần xác minh thay vì tự bịa giả định.
```

---

## 16. Kết luận ngắn cho người đánh giá

Tab Viết hiện đã có một lõi đáng giá: **biến nguồn đọc thành bài luyện output, chấm được offline và có AI local tùy chọn**. Tuy vậy, nó vẫn đang ở giai đoạn **sentence-level drill studio**. Khoảng trống lớn nhất không chỉ là thêm nhiều nút hoặc nhiều dạng bài, mà là xác định rõ:

- Tab Viết muốn tối ưu cho micro-practice hay quá trình sáng tác đầy đủ.
- Cách đo “viết tốt hơn” một cách có căn cứ.
- Cách thay heuristic thiên tiếng Anh bằng scoring đa ngôn ngữ đáng tin.
- Cách đưa người học qua vòng draft → feedback → revision → retention.
- Cách refactor kiến trúc để task, scorer và AI có thể tiến hóa độc lập.

Đây là những quyết định nên được phản biện trước khi tiếp tục mở rộng implementation.
