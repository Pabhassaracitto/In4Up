# PROMPT HỘI ĐỒNG ĐA AI — "ICONIZE / VISUAL CONTEXT" cho In4Up (ICONIZE-001)

> **Cách dùng file này:** Copy toàn bộ nội dung làm prompt khởi động cho từng
> thành viên hội đồng đa AI (Claude, ChatGPT, Gemini, Grok, Qwen, …). Mỗi vòng,
> từng AI đánh giá + nâng cấp blueprint theo đúng "Giao thức vòng lặp" ở mục 7.
> Kết quả cuối cùng là **một bản blueprint hoàn chỉnh, đủ chi tiết để code ngay**
> trong repo `Pabhassaracitto/In4Up`.
>
> ⚠️ Lưu ý quản trị: theo `AGENTS.md` quy tắc vàng #4 của dự án, hội đồng đa AI
> chỉ sản xuất **blueprint đề xuất**. Quyết định kiến trúc cuối cùng phải được
> ghi thành ADR trong `docs/adr/` + code review như thường lệ.

---

## 1. Bối cảnh dự án (sự thật trong repo — KHÔNG được bịa thêm)

**In4Up** là studio học sâu offline-first (Flutter, Android/iOS/Windows/Linux/Web),
~600 file Dart / ~255k dòng, 7 chế độ học: Nghe · Nói · Xem · Đọc · Viết · Hiểu · Nhớ.
Triết lý: cả vòng học nằm trong một app, chạy trên máy, cloud AI là opt-in BYOK.

Những mảnh đã có sẵn mà blueprint **bắt buộc tái dùng** (không xây lại từ đầu):

| Mảnh có sẵn | Vị trí | Dùng cho Iconize như thế nào |
|---|---|---|
| Pipeline dịch đa engine (Google Free, MLKit offline, DeepLX, Libre, MyMemory, LLM-MT, HyMT, Offline dict) | `lib/features/translation/` (`translation_service.dart`, `engines/`) | Nơi gắn nút **"Icon hóa"** vào kết quả dịch |
| Cơ chế bảo vệ token qua engine dịch (placeholder `__G{n}__`, longest-match, word-boundary) | `lib/features/translation/glossary/protect_tokens.dart` | Tái dùng nguyên khuôn để đánh dấu từ sẽ thay icon mà không bị engine phá |
| Chế độ hiển thị dịch (ẩn / xếp dưới / 2 cột) | `lib/features/translation/translation_display_mode.dart` | Thêm biến thể hiển thị iconized |
| Tô màu CEFR + từ loại, word tap sheet trong Tab Đọc (PDF/Web/Tipiṭaka) | `lib/features/pdf_reader/`, `lib/features/web_reader/`, `lib/features/word_lookup/word_analysis_sheet.dart` | Tầng POS tagging + điểm chạm UI đã có |
| Dịch vụ phân tích ngữ pháp/từ loại thuần Dart | `lib/features/grammar/services/` (`grammar_analysis_service.dart`, `sentence_structure_service.dart`, …) | Bước 1 của pipeline NLP (tokenize + POS) chạy offline |
| Kho media từ vựng: ảnh/Lottie, 1–2 media mỗi từ, tìm Openverse/Commons/Pexels, dán URL, xem trước | `lib/features/vocab_image/` (`vocab_image_service.dart`, `vocabulary_media_widget.dart`) + card KANBAN `VOCAB-MEDIA-003` | Hạ tầng tải/lưu/render icon-SVG/Lottie theo từ |
| Từ điển offline (MDX, bundle scanner) + Wiktionary-style lookup | `lib/features/dictionary/` | Nguồn nghĩa + câu ví dụ |
| SM-2 canonical + FSRS, Memory Garden, WordEntry | `lib/models/word_entry.dart`, tab Nhớ | Nơi cắm chế độ ôn **Smart Cloze thị giác** |
| AI on-device (llama.cpp, Whisper, Sherpa-ONNX, Piper) + Model Centre | `lib/` services, `docs/MODELS.md` | Sinh câu ví dụ thị giác bằng LLM nhỏ local, TTS phát âm khi chạm icon |

**Luật cứng của repo (vi phạm = blueprint bị loại ngay vòng đó):**

1. Offline-first: mọi tính năng phải có đường chạy không mạng; online chỉ là nâng cao.
2. Dữ liệu **additive** — file dữ liệu cũ mở lên vẫn chạy, không migration phá hủy
   (tiền lệ: `imageUrl2`, `phoneticSource` trong `WordEntry`).
3. KHÔNG đụng `lib/ffi/` (audio C++), KHÔNG gộp 3 điểm SM-2, KHÔNG làm mất reopen
   anchor (PDF page/rect, Web url/scroll, Audio timestamp).
4. i18n rule #5: chuỗi chrome UI mới phải có đủ `en/hi/zh/zh_TW/si`, không fallback `vi`.
   **Icon trong nội dung là nội dung user, không phải chrome** — không bị rule này trói.
5. Chỉ dùng tài nguyên **miễn phí, giấy phép rõ** (Apache-2.0 / CC-BY / MIT / public domain),
   ghi rõ attribution vào màn About nếu giấy phép yêu cầu.

---

## 2. Ý tưởng gốc cần hiện thực hóa (đúc kết từ phiên trao đổi với Gemini)

### 2.1 Học từ vựng qua Ngữ cảnh Thị giác (Visual Context)

Thay vì flashcard `cat = con mèo` (đi vòng qua tiếng Việt), hệ thống hiển thị
**câu ví dụ Iconized** — câu bản xứ trong đó các từ "cụ thể" được thay/kèm icon:

```
[Chữ bản xứ]   The cat catches the mouse.
                    │              │
[Chuyển Icon]  The [🐱] catches the [🐭].
                    │              │
[Tư duy đích]  [Thực thể] + [Hành động] + [Đối tượng]
```

Nguyên tắc phân vai:
- **Danh từ cụ thể** (chủ ngữ/tân ngữ) → icon: `[🐱]`, `[🐭]`, `[🍎]`.
- **Động từ hành động** → Option A: icon động/Lottie action (ưu tiên);
  Option B: giữ chữ bản xứ (người học thấm luôn cách chia thì).
- **Tính từ cụ thể** (màu sắc, hình dáng) → icon: `The [🍎] is [🔴].`
- **Từ trừu tượng / chức năng** (freedom, the, is, policy) → giữ nguyên chữ.

Cơ sở thần kinh học (dual coding + contextual anchoring):
- Não ghi nhớ hình ảnh hành động vượt trội so với chữ tĩnh; icon gắn trong câu
  cho não thấy ngay **thuộc tính + hành vi** của từ.
- Việc "giải mã" câu chữ-lẫn-icon là một mini-puzzle → kích thích dopamine,
  đẩy từ vào bộ nhớ dài hạn (desirable difficulty).
- **Triệt tiêu lỗi dịch thầm**: người học thấy một "bức tranh thu nhỏ" thay vì
  chuỗi chữ phải dịch sang tiếng Việt mới hiểu — đường truyền thần kinh đi thẳng
  `khái niệm ↔ từ bản xứ`, hoàn toàn sạch bóng L1.

### 2.2 Pipeline tự động hóa 100% miễn phí (đã khảo sát)

```
[Văn bản] → [1. Tokenize + POS tagging offline]
          → [2. Lọc từ "cụ thể" (concreteness filter)]
          → [3. Map từ → icon/SVG/Lottie]
          → [Giao diện câu Iconized]
```

- **Bước 1 — POS offline:** tái dùng `grammar_analysis_service` sẵn có; nếu cần
  nâng độ chính xác thì model POS nhỏ dạng onnx/tflite chạy local.
- **Bước 2 — Lọc từ cụ thể:** bảng **Brysbaert Concreteness Ratings** (~40k từ
  tiếng Anh, miễn phí) + WordNet (Princeton). Ngưỡng đề xuất: concreteness
  ≥ 4.0/5.0 → đủ điều kiện icon hóa; thấp hơn → giữ chữ.
- **Bước 3 — Nguồn icon miễn phí, gọi theo tên từ:**
  - **Twemoji / OpenMoji SVG** (CC-BY/MIT): phủ gần hết danh từ cụ thể + hành
    động cơ bản qua Unicode emoji — **ưu tiên làm bộ local asset offline**
    (~2.000 SVG thông dụng đóng gói trong app).
  - **Google Material Symbols** (Apache-2.0): URL pattern theo tên từ, dùng làm
    nguồn CDN bổ sung khi online.
  - **Noun Project API** (free tier có hạn mức): nguồn tùy chọn BYOK.
  - Icon user tự gán trong `vocab_image/` **luôn thắng** icon tự động (ảnh cá
    nhân hóa ghi nhớ mạnh hơn ảnh generic).
- **Nguồn câu ví dụ:** Tatoeba (CC-BY, dump offline được), Wiktionary API,
  hoặc LLM nhỏ on-device với prompt "tạo 1 câu ngắn tả hành động thực tế của
  từ [X], chỉ dùng danh từ cụ thể dễ hình dung".

### 2.3 Yêu cầu bổ sung mới của chủ dự án

> **Trong panel dịch có nút "Icon hóa" (toggle): bật lên thì phần bản dịch
> được chèn icon.**

Tức là Iconize không chỉ sống trong câu ví dụ từ vựng, mà là **một chế độ render
của kết quả dịch** ở mọi nơi có dịch: Tab Đọc (PDF/Web/Tipiṭaka), Tab Hiểu,
panel dịch trang PDF (`pdf_page_translate_panel.dart`), dịch màn hình. Người
học đọc bản dịch mà vẫn bị "ép" neo thị giác thay vì trôi tuột qua chữ L1.

---

## 3. Phương thức học ngôn ngữ tối ưu được chốt làm kim chỉ nam

Blueprint phải phục vụ đúng phương pháp này — mọi quyết định UX/kỹ thuật đối
chiếu ngược về đây:

**"Direct Visual Anchoring Loop" — vòng neo thị giác trực tiếp, 4 pha:**

1. **ENCODE — Mã hóa kép (dual coding):** gặp từ mới trong Tab Đọc → lưu từ
   kèm ngữ cảnh (đã có) → hệ thống tự sinh/tìm **câu ví dụ Iconized** cho từ đó.
   Não nhận đồng thời kênh ngôn ngữ (chữ bản xứ) + kênh thị giác (icon hành động),
   không có kênh L1 chen giữa.
2. **DECODE — Giải mã chủ động (retrieval qua mini-puzzle):** khi đọc bản dịch
   hoặc câu ví dụ ở chế độ Iconize, người học phải tự "đọc ra" từ từ icon.
   Đây là active recall trá hình trò chơi — rẻ hơn flashcard về ý chí, đắt hơn
   về hiệu quả ghi nhớ.
3. **RETRIEVE — Smart Cloze thị giác trong vòng SM-2:** đến hạn ôn, thẻ hiển thị
   `The [🐱] catches a mouse.` — người học nói/gõ ra `cat` (chấm bằng STT sẵn có
   hoặc so chuỗi). Kết quả chấm đổ về đúng hàng đợi SM-2 hiện hữu, **không** tạo
   hệ điểm thứ tư.
4. **GROUND — Tiếp đất đa giác quan:** chạm icon → phát audio phát âm bản xứ
   (TTS Piper sẵn có) + hiệu ứng nhỏ (mèo kêu nhẹ nếu có asset). Từ đó mỗi icon
   là một "nút bấm phát âm" rải khắp văn bản.

Nguyên tắc tối thượng: **không một chữ tiếng Việt nào xuất hiện trong chu trình
ghi nhớ từ vựng** (tiếng Việt chỉ còn ở chrome UI cho user Việt, theo đúng i18n
của app). Mức độ icon hóa phải **thích nghi theo trình độ**: người mới → icon
hóa nhiều (nhìn tranh hiểu chuyện); trình độ lên (CEFR của từ đã thuộc) → icon
rút dần, chữ bản xứ trả lại chỗ — icon là giàn giáo, không phải nạng vĩnh viễn.

---

## 4. Phạm vi blueprint hội đồng phải sản xuất

Blueprint cuối cùng phải đặc tả đủ 6 khối, mức chi tiết "đưa cho agent code là
code được, không phải hỏi lại":

### Khối A — Iconize Engine (thuần Dart, offline)
- API đề xuất: `IconizeResult iconize(String text, {IconizeLevel level, String lang})`
  trả về danh sách span `{start, end, word, lemma, pos, concreteness, iconRef}`.
- Tokenize + POS: tái dùng `grammar_analysis_service`; đặc tả cách lemmatize
  (catches → catch, mice → mouse) bằng luật + bảng ngoại lệ, không cần model nặng.
- Concreteness filter: format bảng Brysbaert nén trong assets (đề xuất cấu trúc
  dữ liệu, dung lượng, cách tra O(1)).
- Bảng map `lemma → emoji codepoint → file SVG local`: đặc tả format
  (đề xuất JSON/CSV trong `assets/`), quy trình build bộ ~2.000 icon từ
  Twemoji/OpenMoji (script trong `tool/`), chiến lược fallback
  (user icon trong `vocab_image` > local asset > CDN online > giữ chữ).
- Đa ngôn ngữ: v1 chốt tiếng Anh; đặc tả điểm mở rộng cho ngôn ngữ khác
  (bảng concreteness thay thế, hoặc nước đi "dịch lemma sang en rồi tra").

### Khối B — Nút "Icon hóa" trong panel dịch
- Vị trí nút ở từng bề mặt: `translation_toolbar.dart`,
  `pdf_page_translate_panel.dart`, panel dịch Tab Hiểu, web reader.
- Trạng thái toggle lưu ở đâu (per-tab hay global setting), default off.
- Pipeline: bản dịch → Iconize Engine → rich text (chữ + `WidgetSpan` icon).
  Lưu ý: icon hóa chạy **sau** khi engine dịch trả kết quả và **sau** khi
  glossary restore — tuyệt đối không đưa icon đi qua engine dịch.
- Nếu cần đánh dấu từ trước khi dịch (giữ nguyên danh từ gốc): tái dùng cơ chế
  placeholder của `protect_tokens.dart`, nêu rõ giới hạn đã biết (engine có thể
  nuốt placeholder).
- Tương tác: chạm icon → tooltip chữ gốc + nút phát âm + nút "Lưu từ này"
  (đổ vào flow lưu từ vựng sẵn có của word tap sheet).

### Khối C — Câu ví dụ thị giác cho từ vựng
- Nguồn câu: thứ tự ưu tiên (Tatoeba dump offline → câu ngữ cảnh user đã lưu
  kèm từ → từ điển MDX → LLM on-device sinh), tiêu chí chọn câu (độ dài ≤ 8 từ,
  ≥ 2 từ concreteness cao, chứa đúng lemma đích).
- Schema additive trên `WordEntry`: trường mới (ví dụ `visualExample`,
  `visualExampleSource`) — nêu rõ `fromJson`/`toJson` theo tiền lệ `imageUrl2`,
  rà mọi serializer trong `lib/services/`.
- UI hiển thị trong word tap sheet, màn chi tiết từ, flashcard mặt sau.

### Khối D — Smart Cloze thị giác trong tab Nhớ
- Một **chế độ trình bày mới** của hàng đợi SM-2 hiện hữu (không engine mới):
  thẻ hiện câu iconized che từ đích, người học trả lời bằng gõ/nói.
- Cách chấm: so chuỗi sau chuẩn hóa; nếu trả lời bằng giọng → pipeline STT cabin
  sẵn có. Mapping kết quả → grade SM-2 (đề xuất bảng cụ thể).
- Luật rút giàn giáo: từ đã đạt bậc nhớ X (định nghĩa cụ thể theo Memory Garden
  Seed→Bloom) thì câu ví dụ hiển thị lại bằng chữ, icon chỉ hiện khi chạm.

### Khối E — Dữ liệu, giấy phép, dung lượng
- Danh mục asset: bộ SVG (ước lượng MB), bảng concreteness, bảng map lemma→icon,
  dump câu Tatoeba rút gọn — cái gì bundle trong app, cái gì tải qua Model
  Centre như một "gói học liệu".
- Ma trận giấy phép + dòng attribution bắt buộc.

### Khối F — Kiểm thử & nghiệm thu
- Unit test: POS/lemma vàng (≥ 50 câu), concreteness threshold, idempotency
  (iconize 2 lần = 1 lần), không icon hóa trong code block/URL/số.
- Golden test widget render câu iconized (LTR + độ dài icon khác nhau).
- Tiêu chí nghiệm thu trên máy (owner acceptance) theo format card KANBAN.
- Danh sách rủi ro có chủ: từ đa nghĩa (bank = 🏦 hay bờ sông?), emoji sai văn
  hóa, câu dài icon dày đặc gây rối — kèm đối sách cho từng rủi ro.

**Ngoài phạm vi (chốt luôn để hội đồng khỏi phình):** sinh ảnh AI theo từ,
icon động theo ngữ cảnh câu (chỉ dùng bộ tĩnh/Lottie có sẵn), icon hóa cho
chữ viết không phải Latin trong v1, server riêng.

---

## 5. Tiêu chí chấm điểm mỗi vòng (rubric 100 điểm)

| Tiêu chí | Điểm | Câu hỏi chấm |
|---|---|---|
| Trung thành phương pháp học (mục 3) | 20 | Mọi quyết định có phục vụ Direct Visual Anchoring Loop? Có chỗ nào lén đưa L1 vào chu trình nhớ? |
| Khớp repo thật | 20 | Có tái dùng đúng module sẵn có? Có bịa file/API không tồn tại? Có vi phạm luật cứng mục 1? |
| Khả thi offline + miễn phí | 15 | Đường chạy không mạng đầy đủ? Giấy phép sạch? Dung lượng chấp nhận được trên mobile? |
| Độ chi tiết code-ready | 15 | Agent code đọc xong có phải hỏi lại không? Schema/API/format asset đã chốt chưa? |
| UX học tập | 15 | Mini-puzzle có vui không? Giàn giáo có rút đúng lúc không? Icon có gây nhiễu người khá? |
| Kiểm thử & rủi ro | 10 | Test có bắt được hồi quy? Rủi ro đa nghĩa/văn hóa có đối sách? |
| Tính additive & an toàn dữ liệu | 5 | Dữ liệu cũ mở lên còn chạy? |

---

## 6. Vai trò từng thành viên hội đồng

- **AI-Kiến trúc (Claude đề xuất):** giữ Khối A/B, soát va chạm với
  `translation_service` và `protect_tokens`, viết draft ADR.
- **AI-Học thuật (ChatGPT đề xuất):** giữ mục 3 + Khối D, phản biện bằng tài
  liệu khoa học ghi nhớ (dual coding, retrieval practice, desirable difficulty),
  chặn các claim phóng đại (ví dụ con số "400%" phải được kiểm chứng hoặc gỡ).
- **AI-Dữ liệu (Gemini đề xuất):** giữ Khối C/E — nguồn câu, bảng concreteness,
  build script icon, ma trận giấy phép.
- **AI-Phản biện đỏ (Grok/Qwen đề xuất):** mỗi vòng bắt buộc nộp ≥ 5 đòn tấn
  công blueprint (edge case, trải nghiệm tệ, phình dung lượng, i18n vỡ) kèm
  mức độ nghiêm trọng.

## 7. Giao thức vòng lặp nâng cấp tinh hoa

1. **Vòng 0 — Khởi tạo:** AI-Kiến trúc viết blueprint draft v0 theo khung mục 4.
2. **Mỗi vòng (tối đa 4 vòng):**
   a. Từng AI chấm rubric mục 5, liệt kê cụ thể *điểm trừ ở dòng nào của blueprint*.
   b. AI-Phản biện đỏ nộp danh sách tấn công.
   c. AI-Kiến trúc tổng hợp, ra bản v(n+1) kèm **changelog** (gì đổi, vì sao,
      ai đề xuất) — không được âm thầm bỏ phản biện; bác thì phải ghi lý do.
3. **Điều kiện dừng:** tổng điểm trung bình ≥ 90/100 **và** AI-Phản biện đỏ xác
   nhận không còn đòn tấn công mức "nghiêm trọng" chưa có đối sách; hoặc hết 4 vòng.
4. **Đầu ra cuối:** `docs/iconize_visual_context_blueprint.md` (bản blueprint) +
   draft ADR (1 trang) + danh sách card KANBAN đề xuất (ICONIZE-001 chia nhỏ
   thành các PR ≤ 500 dòng, thứ tự: Engine → nút panel dịch → câu ví dụ →
   Smart Cloze). Chủ dự án duyệt → ADR vào `docs/adr/` → giao agent code.

## 8. Câu hỏi mở hội đồng PHẢI chốt (không được né)

1. Động từ: Option A (icon/Lottie action) hay Option B (giữ chữ) làm default?
   Hay default B, A là cấp độ "Iconize đậm" user tự bật?
2. Ngưỡng concreteness 4.0 lấy từ đâu ra — có cần A/B hai ngưỡng (4.0 vs 4.5)?
3. Từ đa nghĩa: tra nghĩa theo POS + ngữ cảnh câu, hay chỉ icon hóa khi lemma
   đơn nghĩa trong bảng map (an toàn hơn, phủ ít hơn)?
4. Icon trong bản dịch tiếng Việt (chiều en→vi): icon neo theo từ **gốc tiếng
   Anh** hay từ tiếng Việt? (Gợi ý: neo theo khái niệm — nhưng phải chốt cách
   tìm vị trí chèn trong câu đích khi trật tự từ đã đổi.)
5. Bộ icon local 2.000 từ: chọn theo tần suất corpus nào (COCA? Tatoeba?
   SUBTLEX?) và giao với danh sách CEFR A1–B1 ra sao?

---

*Soạn ngày 2026-10-07 từ: (a) phiên trao đổi chủ dự án ↔ Gemini về Visual
Context + pipeline icon miễn phí, (b) khảo sát repo In4Up thực tế, (c) yêu cầu
bổ sung "nút Icon hóa trong panel dịch". File này là prompt đầu vào cho hội
đồng — không phải quyết định kiến trúc.*
