# SPEC VOCAB MASTER Y — v4.1 (FINAL, audit-fixed + owner quyết định)

> **Trạng thái:** FINAL v4.1.
> **D9 (LOCKED):** cả 2 view (Word + Collection) + toggle chuyển đổi.
> **D10 (LOCKED):** đồng ý — Dùng giữ q nguyên + 2 EMA con, bỏ 0.4/0.6.
> **ADR-0021 (SIMPLIFIED):** network tinh chỉnh ở **Settings**; **KHÔNG phân loại model rẻ/đắt**
> (model hiện tại chủ yếu free); `dataLeavesDevice`/AI-grading defer Phase 2.
> **P0 spike:** PASS (xem `docs/plans/P0_SPIKE_REPORT.md`).
> **Chưa Lock:** còn D11 (chỉ giữ gradedBy + local-first) + audit độc lập ≥95.
>
> **Nguồn bằng chứng:** mọi symbol đã **tái xác minh ở P0** (spike report). Không có gì DỪNG.

---

## 1. SPEC (schema-first)

### 1.1 Trục kỹ năng (append-only, 6 trục / 2 nhóm)

| Index | Trục (SkillKind) | Nhóm | Nhãn UI (i18n key) | Bằng chứng Phase 1 | Mirror |
|---|---|---|---|---|---|
| 0 | understand | Input | Hiểu | Meaning recognition (cheap, offline) | ↔ use |
| 1 | listen | Input | Nghe | Audio identification (expensive, cache) | ↔ speak |
| 2 | read | Input | Đọc | Context clue (cheap, offline) | ↔ write |
| 3 | use | Output | Dùng (có ràng buộc) | form + sentence (xem 1.3) | ↔ understand |
| 4 | speak | Output | Nói (phát âm) | Từ đơn qua `PronunciationService.analyze` | ↔ listen |
| 5 | write | Output | Viết (chính tả) | Từ đơn qua scorer Write Studio đã trích xuất | ↔ read |

- **Enum `SkillKind`:** append `use=3, speak=4, write=5`. **Chỉ thêm vào cuối, không chèn giữa.**
- **Mapping 2 enum (audit fix — MED-5):**
  - `WordEntry.Skill` = `understand, listen, read` (giữ nguyên).
  - `knowledge.SkillDimension` = `understanding, listening, reading` (giữ nguyên).
  - `SkillKind` mới = `understand, listen, read, use, speak, write` — **tiểu tương ánh** sang 2 enum cũ:
    `understand→understanding, listen→listening, read→reading`.
  - Migration phải map cả 3 enum consistently; không gộp tên.
- **Ranh giới chống đếm trùng:** Viết = từ đơn (chính tả). Nói = phát âm từ đơn. Dùng = trong câu + đúng dạng + đúng kết hợp từ.
- Mỗi task có **đúng 1 primarySkill**. Secondary impact ≤0.3 chỉ cập nhật Mastery Vector, không vào SM-2.

### 1.2 Bằng chứng Output (theo A.1.1 — đã xác minh)

- **Nói:** ghi âm → `OfflineSTTService.transcribe` → `PronunciationService.analyze(originalText: từ)`.
  Không dùng `ShadowingLine`. Tier expensive → cần cache hoặc offline.
- **Viết:** `WritingAssignment(sourceText: từ)`, scorer trích từ `_scoreDictation` thành hàm reusable.
  Tier cheap, offline.
- **Dùng, form:** chỉ bật rule có sẵn trong `grammar_lexicon_service` (plural/3sg, past/pp, comparative/superlative, gerund).
  Item không có rule → **không hiện sub-test**, không tính là 0.
- **Dùng, sentence:** cloze điền dạng (Phase 1). Collocation **không có dữ liệu repo** → Phase 2 hoặc khi có nguồn.

### 1.3 Trục Dùng

- Giữ `q` nguyên 0–5 cho từng event, kèm `subTestType` (`inflection` | `cloze_sentence` | `collocation` | `ai_sentence`).
- SM-2 của Dùng là **1 SM2Snapshot riêng**, tiêu thụ `q` nguyên của từng event (cùng cách Viết/Nói).
- Mastery Vector giữ **2 EMA con**: `useForm`, `useSentence`.
- Hiển thị Dùng = trung bình các sub-test **có bằng chứng**. Chỉ có 1 sub-test → gắn nhãn "một phần". **Không bù 0.**
- **Bỏ trọng số 0.4/0.6** (vi phạm integer SM-2).
- Không dùng LLM on-device cho Dùng ở Phase 1. AI sentence grading = Phase 2, premium, cần consent.

### 1.4 Thuật toán

- **Hai engine tách bạch:** SM-2 chỉ quyết định **lịch ôn** (q nguyên). EMA chỉ cập nhật **Mastery Vector** (scoreNor = q/5 ∈ [0,1]).
- **Patch A′**, bất đối xứng theo chiều:
```
wasCorrect = q >= 3
gate       = wasCorrect ? (1.0 - evidence.assistance) : 1.0
alphaE     = alpha * evidence.confidence * gate
mastery    = mastery + alphaE * (scoreNor - mastery)
```
- Unit test bắt buộc: (1) clozeChoice đúng, assistance 0.75 → |Δ| ≈ 0.25·α. (2) Sai, assistance 0.75 → |Δ| đủ cường độ α. (3) confidence 0.2 → cả hai chiều gần đứng yên.
- **Level tổng hợp KHÔNG gộp SM-2:** dùng **8 archetype** (blindSpot, passiveListener, textReader, receptiveHoarder, imitativeSpeaker, productiveAsymmetric, functionalBalanced, fullMastery) với ngưỡng **[P0 — cần calibrate bằng dữ liệu thật]**. **Không** lưu scalar tổng, **không** dùng diện tích làm level.
- **Gate chặn lên level nếu thiếu output bị loại.** Bất đối xứng input/output chỉ là thông tin hiển thị.

### 1.5 Retention (Nhớ)

- Là **lớp riêng**: glow/opacity quanh đỉnh, không phải trục, không cộng vào mastery (ADR-0001).
- Retention unknown **không** gán 0.5.

### 1.6 Visual

**Đã khóa:**
- **Null-vertex contract:** đỉnh chưa có bằng chứng = vòng rỗng nét đứt, không tô. Envelope không nội suy qua null. Legend: "○ Chưa đánh giá", không hiển thị là 0.
- **Không dùng barycentric 6 đỉnh cho từng từ** ( chiếu 6D→2D không đơn ánh, null không biểu diễn được).
- **Hình học hexagram (ứng viên):** 3 cặp mirror trên đường kính xuyên tâm (Hiểu↔Dùng dọc, Nghe↔Nói chéo trái, Đọc↔Viết chéo phải). Input tam giác trong, Output tam giác ngoài, khe gap = production gap.
- Tap đỉnh → Focus Lens → Evidence gốc (reopen đúng PDF page/rect, Web scroll, Audio timestamp).

**Chờ owner quyết (D9) — ĐÃ QUYẾT:** **CẢ 2 view + toggle chuyển đổi.**
- **Word view (hexagram):** xem **1 từ** — 6 đỉnh, khoảng cách từ tâm = mastery,
  production gap = khoảng cách giữa 2 đỉnh đối diện (Hiểu↔Dùng, Nghe↔Nói, Đọc↔Viết).
- **Collection view (scatter):** xem **toàn kho** — x = Input, y = Output, đường chéo = cân bằng,
  production gap = khoảng cách tới đường chéo.
- **Toggle** cho người dùng chuyển Word ↔ Collection. **Painter code ở P3.**

### 1.7 Mạng (ADR-0021) — SIMPLIFIED theo owner

**Owner quyết:** tinh chỉnh mạng ở **Settings** (vốn có sẵn shell settings).
**KHÔNG phân loại model rẻ/đắt** — model hiện tại chủ yếu free, chưa cần layer classification.

| Loại op | Ví dụ | Default |
|---|---|---|
| cheap | Tra từ, dịch, IPA, cloze, inflection, lookup | online |
| expensive | DSP, TTS neural, shadowing scoring, OCR, xử lý hình ảnh | user-gate (offline/cache) |

- **Network toggle** (Always online / Always offline / Auto) ở **Settings**.
- **Task tất định (inflection/cloze):** **local-first**. Online chỉ làm giàu dữ liệu.
- **`gradedBy`** (engine + version) lưu trong EvidenceMetadata — EMA online/offline không so sánh sai.
- **`dataLeavesDevice`:** **defer tới Phase 2** (AI grading) — Phase 1 chưa cần.
- **AI sentence grading:** Phase 2, premium, cần consent.
- Không tải model nặng lúc bootstrap.

### 1.8 Không được đụng

`lib/ffi/` và UltraTimeStretch; 3 SM-2 input; `WordEntry` fields 0–25; khả năng reopen nguồn; ADR cũ (0001, 0002).

---

## 2. MIGRATION (additive, không mất dữ liệu)

> **Audit fix (MED-2, MED-4):** ReviewEvent lưu theo **NAME (string)**, không phải ordinal.
> Hive dùng **string box** (`Hive.openBox<String>`), không có typed adapter / `@HiveType` / `registerAdapter`.
> → Migration dựa **JSON serialization + string box**, không phải typeId.

- `SkillKind` append `use=3, speak=4, write=5`. `ReviewEvent.toJson` ghi `skill.name`;
  `fromJson` dùng `SkillDimension.values.firstWhere((s) => s.name == ...)` → **append an toàn**
  (dữ liệu cũ parse bình thường). Chứng cứ: `lib/knowledge/models/review_event.dart:86,99`.
- `LearningState` hiện có **5 field** (unitId, understanding, listening, reading, lastReviewEventId)
  — **audit fix MED-3**: không có "fields 7–9". Thêm **3 field output snapshot mới**
  (use, speak, write) là **thêm field**, không dùng chỗ trống.
  Chứng cứ: `lib/knowledge/models/learning_state.dart:102–110`.
- **Dùng 2 EMA con** không có chỗ trong `LearningState` → typeId mới cho `MasteryVectorV2`,
  `EvidenceMetadataV2`. **Không dùng số typeId "20, 22, 50–57"** (audit fix MED-4 — không có hệ
  typeId trong repo). Thay vào đó: JSON field additive + string box, hoặc typed box mới có
  adapter được register ở P0.
- `WordEntry` không đổi. MVA là nguồn sự thật mới.
- **Feature flag `hexagon_v1`** — **[P0]** xác định mechanism (không có `FeatureFlag` class trong repo;
  cần kiểm tra shared_preferences/settings hoặc thêm mechanism).
- **Session Bundler:** gom các skill đến hạn của cùng 1 từ thành 1 thẻ. DoD: độ dài phiên ≤ +20% baseline; vượt → rollback flag.

---

## 3. ADR (docs/adr/)

> **Audit fix HIGH-1:** repo đã có ADR 0001–0014. Số đề xuất 0003–0009 **đánh trùng** → đổi thành **0015–0021**.

| ADR | Nội dung | Trạng thái |
|---|---|---|
| 0015 | 6 trục / 2 nhóm, ranh giới chống đếm trùng | Sẵn sàng (sau P0) |
| 0016 | Dual engine: SM-2 lịch ôn vs EMA Mastery | Sẵn sàng |
| 0017 | EvidenceMetadata + assistance asymmetry (patch A′) | Sẵn sàng |
| 0018 | Dùng: form + sentence, deterministic Phase 1 | Sẵn sàng; collocation Phase 2 |
| 0019 | Archetype + null-vertex + retention ring | **D9 đã quyết** (cả 2 view + toggle) |
| 0020 | Migration append-only + Session Bundler | Sẵn sàng (sau spike Hive) |
| 0021 | Network policy: Settings + cheap/expensive (simplified) | **Owner đã xác nhận** (simplified) |

---

## 4. TASK LIST (phase, DoD)

**P0 — Spike + prototype (≤1 ngày, song song owner):**
- Tái xác minh 3 symbol A.1.1 → ghi **path + symbol + line**:
  - `PronunciationService.analyze` (arbitrary string).
  - `_scoreDictation` (generic target).
  - `grammar_lexicon_service` inflection rules (liệt kê rule hiện có).
- Xuất mẫu serialization `ReviewEvent` (name-based, đã xác minh).
- Kiểm tra Hive box type (string box, `lib/main.dart:123`) → xác định migration mechanism.
- Xác định **feature flag mechanism** [P0].
- Prototype giấy 2 màn (Word, Collection), thử 3 người.
- **DoD:** báo cáo path + symbol + line. Nếu 1 điểm không xác minh được → **DỪNG**, không viết code.

**P1 — Schema + ADR (~3 ngày):**
- Viết ADR 0015–0021 (trừ phần visual chờ D9).
- Thêm `SkillKind` append-only; `EvidenceMetadata`; field additive cho LearningState.
- **DoD:** unit test migration old→new zero loss; CI xanh; ADR merge.

**P2 — Engine (~3 ngày):**
- EMA patch A′ + 3 unit test chống hồi quy.
- Mastery con cho Dùng; archetype classifier (threshold [P0 calibrate]); `NetworkPolicy.decide` thuần.
- Session Bundler.
- **DoD:** test thuần xanh; Session Bundler ≤ +20%.

**P3 — Adapter + UI (~3 ngày, sau D9):**
- Viết/Nói chế độ 1 từ (trích scorer, dùng lại `analyze`).
- Dùng sub-test form + cloze.
- HexagramPainter (**chỉ sau D9**); Focus Lens; i18n en/hi/zh/zh_TW/si; flag `hexagon_v1`.
- **DoD:** chrome không tiếng Việt khi locale ≠ vi; golden test; Venn/Triangle vẫn chạy.

**P4 — Verify + launch (~1–2 ngày):**
- Integration event → mastery → repaint.
- Hiệu năng 1000 từ ≤60ms.
- Bật flag, theo dõi calibration Dùng sau 2 tuần.
- **DoD:** tất cả DoD trước đạt; rollback flag sẵn sàng.

Ước lượng 11 ngày **không đáng tin** vì HIGH-1 chưa đóng. Ước lượng lại sau P0.

---

## 5. RỦI RO (≤3) VÀ HỒI PHỤC

1. **Hive mất dữ liệu người dùng.** Hồi phục: chỉ append, spike P0, test zero loss, không chèn enum giữa.
2. **Lạm phát mastery ở Dùng** (sub-test dễ). Hồi phục: nhãn "một phần", không bù 0, calibration 2 tuần, không công bố level khi dữ liệu mỏng.
3. **Visual không được người dùng hiểu** (D9 là giả thuyết UX). Hồi phục: prototype 3 người trước code painter; flag hexagon_v1 có thể tắt, Venn/Triangle còn chạy.

---

## 6. SỔ QUYẾT ĐỊNH

| ID | Quyết định | Trạng thái |
|---|---|---|
| O1–O5 | Dùng ∈ Output; visual lục giác kép; network adaptive; retention là lớp; ràng buộc bảo vệ | **Locked** (owner) |
| D6 | AI sentence grading | **Accepted**: Phase 2 |
| D7 | ADR-0021 network | **Proposed**: chờ owner xác nhận |
| D8 | Word-scoped adapter Viết/Nói | **Accepted có điều kiện**: P0 tái xác minh |
| D9 | Word view vs Collection view | **LOCKED** (owner): cả 2 + toggle |
| D10 | Dùng giữ q nguyên, 2 EMA con, bỏ 0.4/0.6 | **LOCKED** (owner): đồng ý |
| D11 | `dataLeavesDevice` + `gradedBy`, local-first | **Resolved (owner cho quyền)**: giữ gradedBy + local-first; **dataLeavesDevice defer Phase 2** — tái dùng pattern AI-provider settings hiện có (`ai_providers_screen.dart`: local vs remote), không build consent mới |
| A.4-Q8 | Routing mạng ở lớp engine, UI chỉ override | **LOCKED** (owner): Settings + Auto/Always/offline toggle |

---

## 7. TRẢ LỜI 8 CÂU A.4 (ngắn)

1. **Dùng ∈ Output:** Có. Ranh giới: Viết = từ đơn, Nói = phát âm, Dùng = câu + dạng + kết hợp từ. SM-2 riêng; Dùng = tổng hợp 2 sub-test có bằng chứng, không bù 0. "Hiểu" không trùng vì Hiểu là nghĩa nhận được, khác dùng được.
2. **Output SM-2:** Mỗi trục riêng. Không production confidence chung. Không gate.
3. **Nhớ:** Lớp riêng, glow/opacity, unknown ≠ 0.5.
4. **Visual:** Lục giác kép vì khe gap map trực tiếp production gap + đúng 3+3. Tam giác đôi là dự phòng.
5. **Level không gộp SM-2:** 8 archetype, không scalar, không diện tích.
6. **Link từ visual → Evidence → ôn tập:** Focus Lens + micro-task 30s; không chuyển màn hình bắt buộc.
7. **Migration:** Thêm SkillKind 3–5, LearningState thêm 3 field output, typeId mới cho EMA con/EvidenceMetadata (dựa JSON + string box, không dùng số typeId cũ). Không mất dữ liệu nếu chỉ append (xác nhận P0).
8. **Mạng:** Phân tầng cheap/expensive/premium. Routing ở engine; UI chỉ hiển thị + lưu override.

---

## 8. AUDIT LOG + ĐỀ QUYẾT (v4.1)

| # | Lỗi audit / Quyết định | Fix / Kết quả |
|---|---|---|
| HIGH-1 | ADR 0003–0009 đánh trùng repo | → **0015–0021** |
| MED-2 | "ReviewEvent lưu ordinal byte" | → **lưu name (string)**, append an toàn |
| MED-3 | "LearningState fields 7–9" | → **5 field**, thêm field output mới |
| MED-4 | "typeId 20, 22, 50–57" | → **không có typeId**; migration JSON + string box |
| MED-5 | 2 enum Skill trùng tên | → thêm **mapping 3 enum** |
| LOW-6 | feature flag không rõ | → **P0**: 1 key bool + helper nhỏ (không cần hệ thống lớn) |
| LOW-7 | archetype threshold | → **P0**: calibrate bằng dữ liệu thật (Phase 4) |
| **D9** | Word vs Collection | **LOCKED**: cả 2 + toggle |
| **D10** | Dùng q nguyên + 2 EMA | **LOCKED**: đồng ý |
| **ADR-0021** | Network tiering | **SIMPLIFIED**: Settings + cheap/expensive; KHÔNG phân loại model; dataLeavesDevice defer Phase 2 |
| **P0 spike** | — | **PASS** (`docs/plans/P0_SPIKE_REPORT.md`) |
