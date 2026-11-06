# 📝 PROMPT HỘI ĐỒNG AI — Nâng cấp đánh giá từ vựng I4U: Input + Output + Dùng nghĩa (lục giác / tam giác đôi)

> ⚡ **VÒNG TIỆT CỤC (FINAL SUMMARY)** — đây là lượt **CUỐI**. Hội đồng **KHÔNG** mở thêm
> câu hỏi mới, **KHÔNG** tự chấm điểm để đưa lên. Nhiệm vụ: tổng hợp V8/V9 + patch HIGH/MED
> + **kết quả kiểm chứng 3 giả định mở** (xem **A.1.1**) thành **bản spec FINAL + ADR +
> task list có DoD**. Output là **quyết định hành động**, không phải prose.

> Mục tiêu của file này: một prompt **tự chứa**, bạn copy nguyên file gửi cho hội đồng AI lớn
> (Claude / ChatGPT / Gemini / Grok / Kimi / Qwen). Hội đồng sẽ chắt lọc đề xuất thành
> một **bản spec + ADR + danh sách task** qua các vòng lặp tinh hoa.
>
> Protocol bên dưới là **v3.0** — đã cải tiến từ handoff v2.8 bạn cung cấp (xem phần
> “ĐỔI GÌ TRONG PROTOCOL” ở cuối). Nếu bạn thích giữ nguyên v2.8, bỏ phần đó đi vẫn dùng được.

---

## 0. MỤC TIÊU & RÀNG BUỘC (bắt đầu)

- **Mục tiêu (1 câu):**  thiết kế lại mô hình đánh giá từ vựng của I4U để nó đo được **cả đầu vào (hiểu–nghe–đọc) và đầu ra (viết–nói)**, đồng thời nâng cấp trực quan (Venn/tam giác → lục giác hoặc tam giác đôi) sao cho vừa thể hiện level người dùng vừa liên kết trực tiếp với từng từ và với luồng ôn tập.
- **Loại:** Spec / Kế hoạch kiến trúc (cần hội đồng AI góp ý thành vòng lặp).
- **Audience:**  owner I4U + agent triển khai (Arena/Claude Code/Cursor).
- **TC4:**  Khả năng đo lường được (mọi trục phải gắn bằng chứng có thật trong code).
- **TC5:**  Khả năng thực thi (additive migration, không phá vỡ 3 SM-2 input).

### Ràng buộc BẮT BUỘC (vi phạm = reject ngay)
1. **KHÔNG** đụng `UltraTimeStretch` C++ FFI / `lib/ffi/` — audio realtime là vùng bảo vệ.
2. **KHÔNG** gộp 3 kỹ năng SM-2 input (Hiểu–Nghe–Đọc) thành 1 điểm số duy nhất — tách là có chủ đích.
3. **KHÔNG** làm mất khả năng reopen đúng vị trí nguồn (PDF page/rect, Web url/scroll, Audio timestamp).
4. Quyết định kiến trúc → phải ra **ADR** trong `docs/adr/` (repo quy định: không qua “hội đồng AI” để duyệt code).
5. Chuỗi UI mới phải đủ i18n `en` + `hi/zh/zh_TW/si` (ADR-0002); chrome không tiếng Việt khi locale ≠ vi.
6. Mọi claims của hội đồng phải **có căn cứ file/symbol**; KHÔNG bịa.

---

## A. NỘI DUNG CẦN CHẤT LỌC (dán thực tế vào đây)

### A.1 Hiện trạng dự án (đã đọc code — tóm tắt có căn cứ)

**I4U** là xưởng học ngôn ngữ đa nền (Android/iOS/Win/Linux/Web), 7 chế độ:
Nghe · Nói · Xem · Đọc · Viết · Hiểu · Nhớ. Nền tảng là engine âm thanh UltraTimeStretch.
**Chế độ mạng:** không còn offline-first tuyệt đối — chuyển sang **linh hoạt (adaptive) +
quyền người dùng**: tự theo kết nối (WiFi/4G/offline) + user override. Chi tiết ở **A.6**.

**Mô hình từ vựng hiện tại (`lib/models/word_entry.dart`):**
- `WordEntry` có **3 kỹ năng**: `understand` (Hiểu), `listen` (Nghe), `read` (Đọc).
  Mỗi kỹ năng có `SkillReviewData` = **SM-2 riêng** (`lib/models/skill_review_data.dart`).
- `mastery = (understand + listen + read) / 3`.
- `MasteryZone` = **8 vùng** do threshold 0.6 trên 3 kỹ năng:
  `blindSpot / understandOnly / listenOnly / readOnly / understandListen / understandRead /
  listenRead / mastered`.
- Hàm SM-2 **duy nhất** trong toàn repo: `SM2Algorithm.calculate` (`lib/models/sm2_algorithm.dart`,
  ADR-0001, version `sm2-srd-v1`).

**Bảng điều khiển hiện tại (Tools):**
- **Venn** (`lib/screens/tools/venn_tab.dart`): 3 vòng tròn Hiểu/Nghe/Đọc, kéo từ vào 8 vùng.
  → Đây là **phân loại thủ công** (`setWordZone`), **KHÔNG viết SM-2**, không đo được level.
- **Tam giác** (`lib/screens/tools/triangle_tab.dart`):
  1. Bản đồ tam giác — từ được đặt theo trọng số 3 kỹ năng, bán kính theo mastery.
  2. Đánh giá nhanh — tự test từng chiều.
  → Trực quan nhưng **chỉ 3 trục input**, thiếu chiều output và thiếu chiều level tổng hợp.
- **Ôn tập** (`lib/screens/tools/review_tab.dart`): SM-2 4 nút Again/Hard/Good/Easy,
  tab Tất cả/Hiểu/Nghe/Đọc.
- **Vườn nhớ / Memory mode** (`lib/screens/memory_mode/`): 6 stage `seed→bloom`,
  engine riêng (`markCorrect/markIncorrect/markHard/markRetired/markSnoozed`),
  **KHÔNG dùng hàm SM-2 chuẩn** (ADR-0001 loại trừ) — đo **retention**, khác với **mastery**.
- **Knowledge module MVA** (`lib/knowledge/`): `KnowledgeUnit` bất biến + `Evidence` +
  `LearningState` (3 kỹ năng `SM2Snapshot`) + `ReviewEvent` append-only + `LearningAction`
  + `Attention Score v1` (có reason giải thích) + Dual-Memory lifecycle.

**Đầu ra hiện tại — có thực hành nhưng KHÔNG vào điểm số:**
- **Write Studio** (`lib/screens/read_mode/write_studio_screen.dart`): dictation / clozeInput /
  clozeChoice / rewrite / summary.
- **Speak mode** (`lib/screens/listen_mode/speak_mode_screen.dart`) + shadowing
  (`lib/features/shadowing/`): ghi âm, canh dòng, chấm phát âm theo âm vị.
→ Cả hai đều **không feed vào `mastery` vector**. Mastery hiện tại là **input-only (receptive)**.

### A.1.1 KẾT QUẢ KIỂM CHỨNG (đã đóng 3 giả định mở của V9 — owner verify bằng repo)

| # | Giả định mở | Kết quả kiểm chứng |
|---|---|---|
| 1 | Scorer âm vị có chấm **chuỗi tùy ý**? | **CÓ** — `PronunciationService.analyze({originalText, recognizedText})` nhận **chuỗi tùy ý**, chia theo từ + Jaro-Winkler + phoneme. → **Nói 1 từ khả thi**: ghi âm → STT (`OfflineSTTService.transcribe`) → `analyze(originalText: từ)`. Không cần đụng `ShadowingLine`. |
| 2 | Scorer Write Studio nhận **target tùy ý**? | **CÓ** — `_scoreDictation` so sánh `assignment.sourceText` vs input, **generic**, không bắt whole line. → **Viết 1 từ khả thi**: `WritingAssignment(sourceText: từ)` + **trích xuất scorer** ra thành hàm reusable (hiện là private trong screen). |
| 3 | Repo có bảng **inflection/collocation**? | **Inflection: CÓ PHẦN** — `grammar_lexicon_service` có rule-based inflection (plural/3sg, gerund/participle, past/participle, comparative/superlative) nhưng **không có paradigm đầy đủ** (go/went/gone). **Collocation: KHÔNG CÓ** → Phase 1 chỉ bật sub-test có dữ liệu; collocation Phase 2 hoặc thêm nguồn. |

### A.2 Vấn đề cốt lõi (theo người dùng + phân tích code)

1. **Đánh giá thiếu đầu ra.** Hệ chỉ đo đầu vào (hiểu/nghe/đọc). Viết/nói có thực hành nhưng
   không có bằng chứng điểm số ⇒ đánh giá bị lệch về “nhớ hay quên”, đúng như người dùng
   nhận định: cần đo được “mắt–tai–não đầu vào tương ứng đọc–nghe–nhớ” **và** “viết–nói–dùng đầu ra”.
2. **Visual là bề mặt, chưa gắn dữ liệu đo.** Venn là phân loại thủ công (không gắn SM-2);
   tam giác chỉ 3 trục input; thiếu trục output và thiếu trục **level**.
3. **Hai khái niệm đang lẫn nhau:** `mastery` (kỹ năng kỹ thuật) vs `retention` (vườn nhớ).
   Cần tách và liên kết rõ ràng.

### A.3 Đề xuất nâng cấp (giả thuyết cần hội đồng chắt lọc)

**Giai đoạn 0 — lock SCHEMA trước khi lock hình (quan trọng nhất):**
- xác định chính xác **trục kỹ năng** — **6 trục / 2 nhóm** (theo bổ sung + quyết định của owner):
   - Nhóm **Input (receptive, đầu vào):** Hiểu (understand), Nghe (listen), Đọc (read) — **giữ nguyên, tách biệt**.
   - Nhóm **Output (productive, đầu ra):** Viết (write), Nói (speak), **Dùng (use/dùng nghĩa)**.
     → **Dùng xếp cùng nhóm Output** (owner affirm YES): vì bằng chứng của Dùng luôn là **sản xuất**
     (viết dạng đúng / đặt câu). Dùng là trục **kết hợp** gồm 2 nhỏ:
     (a) **Dạng từ (form/morphology):** số ít/nhiều, thì (v1/v2/v3), so sánh, danh từ hóa.
     (b) **Đặt câu + tùng phố (sentence + collocation):** dùng từ đúng ngữ pháp + đúng tùng phố.
   - Nhóm **Trữ (retention):** Nhớ — là **lớp/layer riêng**, tách khỏi mastery (không nằm trong 6 trục).
- **RANH GIỚI (cảnh báo — chống đếm trùng):** “đặt câu” đụng chạm Viết/Nói → phải định rõ:
   - **Viết** = viết từ (chính tả, từ đơn, tách biệt).
   - **Dùng** = dùng từ **trong câu + đúng dạng + đúng tùng phố**.
   → Nếu không sẽ bị **đếm trùng** giữa Viết/Nói và Dùng.
- xác định **bằng chứng đầu ra** thu thập từ đâu (ưu tiên task **objective** trước):
   - **Dạng từ (form):** task **inflection** — cho căn + yêu cầu dạng (plural / past / past participle…)
     → so khớp chuẩn dictionary. Rất đo được.
   - **Đặt câu + collocation:** **cloze điền dạng** + **collocation chọn đáp án** (objective);
     **tạo câu + AI chấm ngữ pháp** (làm sau, cần guardrail).
   - **Viết:** Write Studio dictation/spelling. **Nói:** shadowing chấm phát âm theo âm vị.
- xác định **cách output feed mastery**: mỗi kỹ năng SM-2 riêng? **Dùng** là **SM-2 riêng** hay
  **tổng hợp có trọng số của 2 sub-test (form + sentence)**?
- xác định **cách tính level tổng hợp** mà **không gộp 3 SM-2 input**.

**Giai đoạn 1 — chọn visual (xuống sau giai đoạn 0):**
- **★ LỤC GIÁC KÉP (concentric double hexagon) — ĐĂNG TIÊN NHẤT:**
  - Lục giác **trong** = **Input** (Hiểu, Nghe, Đọc), 3 đỉnh.
  - Lục giác **ngoài** = **Output** (Viết, Nói, Dùng), 3 đỉnh.
  - **Khe giữa 2 lục giác = “khoảng cách đầu ra” (production gap)** — thứ owner muốn thấy:
    từ “nhận được” → “dùng được”.
  - Mỗi từ = 1 điểm (barycentric 6 đỉnh); nằm gần lục giác nào ⇒ ưu tiên nhóm đó.
  → **2 nhóm × 3 trục = 3+3 ⇒ lục giác kép là hình tự nhiên + trực quan nhất.**
- **Lục giác đơn (6 trục):** Hiểu, Nghe, Đọc, Viết, Nói, Dùng — mỗi đỉnh 1 kỹ năng (bảng nhìn nhanh).
- **Tam giác đôi (double triangle):** nếu chỉ giữ input/output tách biệt (5 trục) thì dùng.
- **Quy định:** visual **PHẢI map 1:1 vào dữ liệu đã lock ở giai đoạn 0** — tránh “hình đẹp nhưng không đo được”.
- Từ trong visual: **click → ngữ cảnh gốc (Evidence) → ôn tập theo trục bị yếu**.

**Giai đoạn 2 — additive migration:**
- Dữ liệu cũ (WordEntry 3 kỹ năng) giữ nguyên; kỹ năng output là **additive** (khoá null, không migration).
- `ReviewEvent` append-only; output events được ghi như event mới theo skill mới.

### A.4 CÂU HỎI CHẤT VẤN HỘI ĐỒNG (phải trả lời rõ, không được trả lời chung chung)

1. **Dùng nghĩa có xếp cùng nhóm Output cùng Viết/Nói không?** (Owner affirm YES — hội đồng cần
   kiểm tra lại) → nếu YES: ranh giới chống **đếm trùng** giữa Dùng và Viết/Nói phải là gì?
   Trục **Dùng** nên là **SM-2 riêng** hay **tổng hợp 2 sub-test (form + sentence)**?
   “understand” có bị trùng với listen+read không (hiểu nghĩa = tổng của nghe+đọc)?
2. Output/Dùng SM-2: **mỗi kỹ năng riêng** hay chung 1 “production confidence”? Có cần **gate**
   (vd: lên level phải có output/dùng)?
3. “Nhớ” (retention) nên là **trục** hay **lớp** riêng? Liên kết thế nào với mastery?
4. Visual nào tối ưu nhất về **đo lường + trực quan**: **lục giác kép** hay **tam giác đôi**?
   Lý do cụ thể (không phải “cả hai đều đẹp”).
5. “Level” tổng hợp tính thế nào **mà không vi phạm** “không gộp 3 SM-2 input”?
6. Cách link từ trong visual → ngữ cảnh → ôn tập sao cho **không làm chậm** luồng học hiện tại?
7. Migration additive cụ thể: field nào thêm, box nào, migration cũ có mất dữ liệu không?
8. **Chế độ mạng (A.6):** phân tầng dung lượng thế nào cho đúng — **không vì offline-first mà mất
   trải nghiệm đắt giá**, đồng thời **không bị mất data gói cước** ở audio/hình ảnh?
   Auto-detect (WiFi/4G) + user override nên đặt ở **lớp nào** (engine routing vs UI policy)?

### A.5 Thành phẩm mong đợi (FINAL SUMMARY — không phải văn xuôi)
- **1 Spec FINAL** (schema + thuật toán + visual + flow) có version, **không còn câu hỏi mở**.
- **ADR** (`docs/adr/`) cho: (1) 6 trục/2 nhóm, (2) visual Word/Collection, (3) q nguyên + 2 EMA,
  (4) network policy (`dataLeavesDevice` + `gradedBy`).
- **Danh sách task** có DoD (i18n 5 locale + test thuần + CI xanh), phân phase P0..P4.
- **Rủi ro ≤3** + cách hồi phục.
- **Sổ quyết định** cuối: D8–D11 đã lock hay còn dự kiến.

### A.6 Chế độ mạng (Network Policy) — BỔ SUNG theo owner

**Lý tưởng:** không còn "offline-first tuyệt đối". App **linh hoạt**: người dùng có quyền chọn,
mặc định **tùy duyên** theo kết nối hiện tại (WiFi / 4G / offline).

**Nguyên tắc phân tầng dung lượng (data tiers):**
- **Cheap (cho online mặc định):** tra từ / từ điển, dịch văn bản, tra IPA, lookup — dung lượng
  không đáng kể ⇒ online là tốt; **Đừng vì offline-first mà bỏ mất trải nghiệm đắt giá**.
- **Expensive (giữ offline / cần user-gate):** xử lý âm thanh (DSP, time-stretch, TTS neural),
  hình ảnh (OCR, background removal, vocab media), tải model ML (whisper/llama/Piper) —
  mới đáng lo mất data gói cước ⇒ default offline / cache / user chọn.

**Mô hình đề xuất — 3 lớp:**
1. **Auto (mặc định):** WiFi → ưu tiên online (richness); 4G → ưu tiên nhẹ (cheap op online,
   expensive op offline/cache); offline → offline hoàn toàn + fallback graceful.
2. **User override:** 1 nút "Luôn online / Luôn offline" (global) + có thể override theo feature.
3. **Fallback:** offline khi mất mạng → cache + engine offline (ML Kit / Hy-MT / Piper).
   Giống mẫu **PDF reader** owner thích: offline dictionary khi chưa kết nối, online load khi có mạng.

**Áp dụng vào đánh giá từ vựng (6 trục):**
- **Tra từ / Dùng task** (inflection, cloze, collocation): cheap ⇒ online được, không cần offline.
- **Nghe/Nói (audio) + hình ảnh:** expensive ⇒ offline/cache/user-gate.
- **Sync đa thiết bị (Firestore):** online, nhưng **không làm chậm** luồng học offline.

**Ràng buộc:**
- Không làm mất trải nghiệm đắt giá chỉ để giữ "offline-first".
- Không tải model nặng lúc bootstrap (giữ nguyên rule hiện tại).
- Cost-aware default theo connection type; user luôn có quyền override.

---

## B. PROTOCOL HỘI ĐỒNG — v3.0 (cải tiến từ handoff v2.8)

### B.1 Đội hình (council, không phải 1 AI)
- **Kiến trúc sư (Architect):** lock schema + thuật toán.
- **Đánh giá viên (Evaluator):** chấm điểm theo rubric.
- **Kẻ đỏ (Red Team):** tìm lỗi High / mâu thuẫn / giả định sai.
- **Tổng hợp viên (Synthesizer):** viết bản cuối + ADR + task list.

### B.2 Vòng lặp (5 vòng tối đa)
- **V0 Pre-register:** lock rubric + ràng buộc + non-goals **trước** khi chắt lọc nội dung.
- **V1 Schema-first gate:** ƯU TIÊN lock trục kỹ năng + bằng chứng output + cách feed mastery.
  **CHƯA** bàn visual. (Áp dụng ADR-0001: schema quyết định downstream.)
- **V2 Adversarial:** Kẻ đỏ tấn công; Architect phản biện; ghi nhận mâu thuẫn.
- **V3 Visual + flow:** chỉ sau khi schema lock, mới chọn lục giác/tam giác đôi + flow link từ.
- **V4 Synthesis:** Tổng hợp viên ra bản cuối + ADR + task + DoD.

### B.3 Luật trò chơi (cách cải tiến so với v2.8)
1. **CHẨN ĐOÁN:** 0–3 lỗi High/Med/Low, **có căn cứ file/symbol**, không bịa.
2. **ƯU TIÊN:** 1 lỗi đòn bẩy cao nhất + giải thích.
3. **CHẮT LỌC:** 10–20% nếu hợp lý; nếu không, nói rõ KHÔNG cắt.
4. **BỔ SUNG:** ≤1 ý tưởng mới; chỉ khi thực sự cần.
5. **HỒI QUY:** FAIL → quay B3 tối đa 1 lần.
6. **MÂU THUẪN (mới):** nếu Vn trái ngược Vn−1 → **PHẢI** xuất DIFF/giải quyết, không chỉ đổi điểm.
7. **EVIDENCE (mới):** mọi claims/recommendation ghi file path + symbol/line.
8. **CẬP NHẬT:** Viết 【A】, cập nhật B/C/D, tăng version.

### B.4 Điểm chất lượng (1=Tệ → 5=Xuất sắc) — ghi rõ lý do mỗi ô
- TC1 (30): Đúng mục tiêu
- TC2 (25): Rõ ràng
- TC3 (20): Súc tích
- TC4 (15): Khả năng đo lường được
- TC5 (10): Khả năng thực thi (additive, không phá SM-2 input)
→ Tổng: __/100

### B.5 Ngưỡng đánh giá
- ≥85 = Usable
- ≥90 (2 vòng liên tiếp) = Stable
- ≥95 + không còn đề xuất hợp lệ = Final Lock

### B.6 Sổ quyết định (🏗️Kiến trúc | 🧱Cấu trúc | 🎨Bề mặt)
ID | Quyết định | Cấp | Trạng thái | Vòng

### B.7 Điều kiện dừng (1 trong 4)
1. Điểm ≥85 + không lỗi High
2. 2 vòng liên tiếp không tăng điểm
3. Không còn đề xuất hợp lệ
4. Chỉ còn chỉnh câu chữ
→ Khi dừng, xuất **Evidence**: Vn−1: __/100 → Vn: __/100, Lỗi High: __.
→ Sau đó xuất: **Bản cuối + 3 điểm mạnh + ≤3 rủi ro**.

### B.8 Theo dõi
Vòng: __ | Điểm: __/100 | Độ dài: V1:___ → Vn:___ | Mode: DEV/PROD

---

## C. HƯỚNG DẪN CHO HỘI ĐỒNG (ghi rõ trước khi trả lời)

- Đọc file thật, KHÔNG bịa: `lib/models/word_entry.dart`, `lib/models/sm2_algorithm.dart`,
  `lib/models/skill_review_data.dart`, `lib/screens/tools/{venn,triangle,review,stats}_tab.dart`,
  `lib/screens/memory_mode/`, `lib/knowledge/`, `lib/screens/read_mode/write_studio_screen.dart`,
  `lib/screens/listen_mode/`, `AGENTS.md`, `docs/adr/0001-sm2-canonical-formula.md`,
  `docs/HANDOFF_MVA_v2.md`, `docs/project/KANBAN.md`.
- **BẮT BUỘC trả lời theo thứ tự:** (1) Current-state audit với căn cứ → (2) Chẩn đoán 0–3 lỗi →
  (3) Ưu tiên 1 đòn bẩy → (4) Trả lời rõ 8 câu chất vấn A.4 → (5) Chắt lọc thành Spec + ADR + task.
- Nếu bạn thấy đề xuất **sai về nguyên tắc** (ví dụ: cần gộp 3 SM-2, hoặc cần đụng FFI),
  **nói KHÔNG ngay** và giải thích.

---

## D. ĐỔI GÌ TRONG PROTOCOL (tại sao v3.0 > v2.8)

| Điểm | v2.8 | v3.0 | Lý do |
|---|---|---|---|
| Đội hình | 1 AI chấm điểm | 4 vai trò (Architect/Evaluator/RedTeam/Synthesizer) | Đa AI phải có đa vai trò, tránh chỉ một góc nhìn |
| Trật tự | Chắt lọc nội dung trước | **Lock schema trước, visual sau** | Visual là downstream của schema; lỡ chọn hình trước sẽ得返工 |
| Bằng chứng | Không bắt buộc | **Claims phải có file/symbol** | Tránh “đề xuất AI mơ hồ” |
| Mâu thuẫn | Không xử lý | **Phải xuất DIFF nếu Vn trái Vn−1** | Ngăn hội đồng “đổi ý mềm” mà không chịu trách nhiệm |
| Thành phẩm | Bản cuối + điểm mạnh/rủi ro | + **Spec + ADR + task list + DoD** | Hội đồng phải ra quyết định hành động, không phải văn xuôi |
| Cấp pháp | Không có | **Pre-register rubric + non-goals trước nội dung** | Ngăn chấm điểm thiên lệch (self-serving) |

---

### Phiên bản
- Document: v3.5 (FINAL SUMMARY ROUND; làm sạch typo + kèm kết quả kiểm chứng 3 giả định mở; **Dùng nghĩa xếp cùng nhóm Output**, visual = lục giác kép 3+3,
  **chế độ mạng linh hoạt + user choice** theo A.6)
- Nội dung 【A】: đề xuất nâng cấp đánh giá từ vựng I4U (2 nhóm × 6 trục, lục giác kép, network adaptive)
- Ghi nhận: 1 vòng lặp tinh hoa với hội đồng AI, target ≥95 + Final Lock.
