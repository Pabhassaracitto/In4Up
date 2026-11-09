# ADR-0018: Trục Dùng — form + sentence, deterministic Phase 1 (collocation Phase 2)

- **Ngày:** 2026-11-03
- **Trạng thái:** PROPOSED (chờ owner xác nhận; phần collocation Phase 2)
- **Phạm vi:** Trục Dùng, `grammar_lexicon_service`, task inflection/cloze.

## Bối cảnh

Owner muốn đo **"dùng nghĩa"**: biết đặt câu, biết dạng số ít/nhiều, động từ v1/v2/v3.
Trục Dùng là trục **kết hợp** của 2 sub-test:
- (a) **Dạng từ (form/morphology)**.
- (b) **Đặt câu + kết hợp từ (sentence + collocation)**.

Kiểm chứng repo (A.1.1): `grammar_lexicon_service` có **rule-based inflection** (partial),
**collocation KHÔNG có dữ liệu**.

## Quyết định

### 1. Sub-test form (inflection) — Phase 1

- Chỉ bật rule có sẵn trong `grammar_lexicon_service`: plural/3sg, past/pp, comparative/superlative, gerund.
- Item không có rule → **không hiện sub-test**, không tính là 0.

### 2. Sub-test sentence (cloze) — Phase 1

- Cloze điền dạng (cho câu thiếu từ, điền đúng dạng).
- Deterministic, local-first.

### 3. Collocation — Phase 2

- **Không có dữ liệu repo** → Phase 2 hoặc khi có nguồn (wordfreq/collexeme).
- Phase 1 không giả vờ có collocation.

### 4. Trục Dùng — SM-2 riêng + 2 EMA con

- Mỗi event giữ `q` nguyên + `subTestType` (`inflection` | `cloze_sentence` | `collocation` | `ai_sentence`).
- SM-2 của Dùng là 1 SM2Snapshot riêng, tiêu thụ `q` nguyên của từng event.
- Mastery Vector giữ **2 EMA con**: `useForm`, `useSentence`.
- Hiển thị Dùng = trung bình các sub-test **có bằng chứng**. Chỉ có 1 sub-test → nhãn "một phần". **Không bù 0.**
- **Bỏ trọng số 0.4/0.6** (vi phạm integer SM-2).

### 5. AI sentence grading — Phase 2

- Không dùng LLM on-device cho Dùng ở Phase 1.
- AI sentence grading = Phase 2, premium, cần consent (`dataLeavesDevice`).

## Hệ quả

- (+) Dùng đo được bằng task objective, không "AI thấy ổn".
- (+) Tránh lạm phát mastery (không bù 0, nhãn "một phần").
- (−) Collocation phải chờ Phase 2.

## Kiểm thử

- Unit test: sub-test form chỉ bật khi có rule.
- Unit test: Dùng SM-2 với q nguyên từ từng sub-test.
- Unit test: 2 EMA con, không bù 0.
