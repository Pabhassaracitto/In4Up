# IN4UP — MATRIX KNOWLEDGE MVA
### Minimum Viable Architecture · v2.0 · Handoff cho AI Agent triển khai

> Tài liệu bàn giao gốc (đưa vào repo 2026-08-19 để truy vết). Người triển khai:
> đọc file này như hợp đồng — "làm gì, theo schema nào, khi nào coi là xong."
> Quyết định kiến trúc phát sinh sau này đi qua ADR (xem `docs/adr/`), không qua
> "hội đồng AI".

## 0. Đọc trước khi code (3 dòng)

1. Đây là bản vá kiến trúc lên **hệ thống local-first đang chạy thật**, không phải viết lại từ đầu.
2. **3 thứ tuyệt đối không được động vào / không được làm chậm đi:** Audio time-stretch realtime, SRS 3 chiều (Hiểu–Nghe–Đọc tách biệt), khả năng reopen đúng vị trí nguồn (PDF/Web/Audio).
3. Nếu một task nào bên dưới buộc bạn phải sửa code trong `UltraTimeStretch` C++ FFI hoặc gộp 3 skill SM-2 thành 1 điểm số duy nhất → **dừng lại, hỏi người, đừng tự quyết.**

## 1. Glossary bắt buộc — chống lệch thuật ngữ khi code

Agent triển khai **không được** dùng các từ sau sai nghĩa trong code/commit/comment:

| Từ | Nghĩa ĐÚNG trong dự án này | KHÔNG được gọi là |
|---|---|---|
| Vector Embedding | Chưa tồn tại ở P0–P2. Chỉ xuất hiện ở P3 (tương lai, ngoài phạm vi bàn giao này) | "Ma trận tag hiện có" không phải embedding |
| RAG | Chưa tồn tại | Việc inject Evidence theo tag/mastery vào prompt Chat gọi là **"context injection"**, không phải RAG |
| Self-Attention | Không có mô hình attention thật | Ranking deterministic theo công thức (mục 5) gọi là **"Attention Score"** (có ghi rõ là công thức, không phải neural attention) |
| RLHF / Fine-tuning | Không làm ở phạm vi này | Log hành vi người dùng để chỉnh ranking gọi là **"policy adjustment"** |
| Semantic Search | Không có | Tìm theo tag/full-text gọi là **"lexical retrieval"** |

## 2. Schema bắt buộc (contract, không phải file cụ thể)

> Agent có quyền chọn tên class/file, nhưng **field và semantics dưới đây là bắt buộc**. Đây là bản dịch logic từ D8, D13, D14, D20–D25 sang dạng implementable.

### 2.1 `KnowledgeUnit` — đơn vị tri thức bất biến

```
KnowledgeUnit {
  unitId: String            // immutable, KHÔNG sinh từ raw text, KHÔNG đổi khi tokenizer đổi
  kind: enum { word, phrase, sentence, paragraph, note }
  canonicalForm: String     // dùng để tìm candidate trùng, KHÔNG dùng làm primary key
  surfaceForms: List<String> // các biến thể chữ viết đã gặp
  language: String
  senseNote: String?        // nếu có nhiều nghĩa (vd "bank" ngân hàng vs bờ sông) → 2 unitId khác nhau, senseNote phân biệt
  createdAt, updatedAt
}
```

**Quy tắc cứng:**
- Trùng `canonicalForm` KHÔNG tự động merge. Chỉ gợi ý "có thể trùng" cho người dùng xác nhận.
- Merge/split là hành vi **có thể hoàn tác** (giữ lịch sử merge).

### 2.2 `Evidence` — nơi/lúc gặp một KnowledgeUnit

```
Evidence {
  evidenceId: String
  unitId: String              // FK → KnowledgeUnit
  sourceType: enum { pdf, web, audio, youtube, text, clipboard }
  sourceId: String
  locator: {                  // để reopen
    page?, rect?, offset?,    // PDF
    url?, scrollPercent?,     // Web
    timestampStart?, timestampEnd? // Audio
  }
  excerpt: String             // đoạn văn bản gốc quanh vị trí gặp
  snapshotHash: String        // hash của excerpt tại thời điểm ghi nhận — dùng phát hiện "nguồn đã đổi"
  createdAt: DateTime
  producerVersion: {          // bắt buộc — để biết dữ liệu này sinh bởi rule/version nào
    splitterVersion: String,
    extractorVersion: String
  }
}
```

**Quy tắc cứng:**
- Khi reopen: nếu `locator` resolve được nhưng nội dung tại đó không khớp `snapshotHash` → UI phải báo **"Nguồn đã thay đổi"**, không được âm thầm coi là evidence hợp lệ.

### 2.3 `LearningState` — trạng thái ghi nhớ (snapshot, không phải log)

```
LearningState {
  unitId: String
  skills: {
    understanding: SM2Snapshot,
    listening: SM2Snapshot,
    reading: SM2Snapshot
  }
  lastReviewEventId: String
}

SM2Snapshot {
  easeFactor, interval, repetitions, dueDate, lastReviewedAt
  algorithmVersion: String   // bắt buộc
}
```

**Quy tắc cứng:**
- **Chỉ một** hàm tính SM-2 trong toàn bộ codebase. Nếu hiện có 2 công thức → audit xem cái nào đang thực sự chạy, xóa cái còn lại, không giữ cả hai "cho chắc". (→ ADR-0001)

### 2.4 `ReviewEvent` — log append-only (nguồn sự thật cho SM-2)

```
ReviewEvent {
  eventId: String
  unitId: String
  skill: enum { understanding, listening, reading }
  rating: enum { again, hard, good, easy }
  timestamp: DateTime
  deviceId: String
  algorithmVersion: String
}
```

**Quy tắc cứng:**
- Append-only, không sửa/xóa record cũ.
- Compaction: sau mỗi 500 event của 1 unit → nén thành baseline `SM2Snapshot` mới + xóa event đã nén.
- Conflict 2 thiết bị: nếu 2 review cùng `unitId + skill` cách nhau < 5 phút wall-clock → chỉ tính event có timestamp sớm hơn vào mastery, event còn lại giữ trong log nhưng đánh dấu `ignoredForMastery: true`.

### 2.5 `LearningAction` — tín hiệu hành vi (KHÔNG phải mastery)

```
LearningAction {
  actionType: enum { opened, replayed, highlighted, translated, savedToWordlist, sentToWriting, chatAsked, skipped }
  unitId: String?
  evidenceId: String?
  timestamp: DateTime
  sessionId: String
}
```

**Quy tắc cứng:** Bảng này **không bao giờ** được dùng để tự động thay đổi `LearningState`. Nó chỉ dùng cho Attention Score (mục 5) và để phát hiện candidate "nên promote".

## 3. Storage physical layout (bắt buộc theo)

| Data | Nơi lưu | Lý do |
|---|---|---|
| `KnowledgeUnit`, `LearningState` (snapshot hiện hành) | Hive box thường | Cần đọc nhanh cho UI render |
| `Evidence` | Hive `LazyBox` hoặc SQLite | Có thể lớn, không cần load hết cùng lúc |
| `ReviewEvent`, `LearningAction` | SQLite (khuyến nghị) hoặc Hive `LazyBox` chia theo tháng | Append-only, cần query theo thời gian, cần compaction |

**Cấm:** Load toàn bộ `ReviewEvent`/`LearningAction` box vào RAM cùng lúc lúc app khởi động.

## 4. Isolate boundary (bắt buộc theo — bảo vệ audio)

```
Main/UI Isolate:
  - Render UI
  - Audio C++ FFI control (UltraTimeStretch, A-B, waveform)
  - Đọc Hive hot box (KnowledgeUnit, LearningState)

Background Worker Isolate (bắt buộc tách riêng):
  - Tokenize / normalize / segment text
  - Tính Attention Score
  - Ghi/đọc Evidence, ReviewEvent, LearningAction
  - Full-text/lexical search
  - Compaction job

Giao tiếp: chỉ qua SendPort/ReceivePort, payload là primitive/JSON,
KHÔNG share mutable object giữa 2 isolate.
```

**Kiểm tra bắt buộc trước khi merge:** phát audio ở tốc độ 0.3x liên tục 2 phút trong khi đồng thời chạy full-text search trên 1000 evidence → không được có tiếng lag/giật.

## 5. Attention Score v1 (công thức cụ thể, không mơ hồ)

```
score(unit, context) =
    w1 * isWeakInCurrentGoalSkill(unit)     // 0 hoặc 1
  + w2 * isDueOrOverdue(unit)               // 0 hoặc 1, overdue tính thêm hệ số ngày trễ
  + w3 * appearsInCurrentSource(unit)       // 0 hoặc 1
  + w4 * recentInteractionCount(unit, last7days)

w1=0.4, w2=0.3, w3=0.2, w4=0.1   // giá trị khởi điểm, cho phép tune sau
```

UI hiển thị lý do kèm gợi ý, ví dụ: *"Gợi ý vì bạn hiểu từ này nhưng nghe chưa tốt, và nó vừa xuất hiện trong bài đang nghe."* — không được nói "AI đề xuất" mơ hồ, phải nói rõ tiêu chí.

## 6. Dual-Memory Lifecycle — hành vi UI cụ thể

```
Observed   ← tự động, chỉ ghi Evidence, KHÔNG hiện UI gì
Captured   ← tự động khi: bôi đen + tra nghĩa, HOẶC nghe lại 1 câu >3 lần, HOẶC mở lại cùng context ≥2 lần
Promoted   ← CHỈ khi người dùng chủ động: bấm "Lưu", kéo sang Writing, hoặc hoàn thành 1 lần shadowing
Practicing ← tự động sau Promoted, bắt đầu SM-2
Maintained ← SM-2 interval > ngưỡng (vd 21 ngày) trên cả 3 skill
```

**Cấm tuyệt đối:** hiện popup/dialog hỏi "có muốn lưu không" trong lúc đang nghe hoặc đang đọc liền mạch. Nếu cần gợi ý, dùng badge nhỏ không chặn luồng, hoặc gộp vào cuối phiên học.

## 7. Chat Grounding (không phải RAG, phải nói đúng tên)

Pipeline bắt buộc khi user hỏi Chat từ một Evidence đang mở:

```
1. Lấy excerpt hiện tại (đang đọc/nghe/từ đang xem)
2. Query top-5 Evidence khác có cùng tag/topic + unit có mastery thấp
3. Đưa cả 2 nhóm trên vào prompt (không đưa toàn bộ lịch sử/tài liệu)
4. Model trả lời KÈM citations: [{evidenceId, quoteExcerpt}]
5. Validator: kiểm tra quoteExcerpt có thực sự là substring/near-match của Evidence.excerpt
   → nếu không khớp: gắn cờ "unverified", hiển thị cảnh báo cho user
6. UI luôn hiện được nút "xem nguồn" trỏ về đúng evidenceId → reopen locator
```

Nếu không có model (mock/offline) → trả lời chỉ dựa evidence trực tiếp (quote-first), không tự sinh giải thích tự do.

## 8. Task breakdown — làm theo đúng thứ tự này

| # | Task | Definition of Done |
|---|---|---|
| 1 | Viết `KnowledgeUnit`, `Evidence`, `LearningState`, `ReviewEvent`, `LearningAction` theo schema mục 2 | Compile được, có unit test cho merge/split reversible |
| 2 | Audit code SM-2 hiện có → chọn 1, xóa cái kia | Có 1 function `SM2Algorithm.calculate()` duy nhất được gọi ở mọi nơi |
| 3 | Migration adapter: đọc `WordEntry` cũ → sinh `KnowledgeUnit` + `Evidence` + `LearningState`, KHÔNG xóa data cũ | Chạy trên 100% dữ liệu test hiện có, không mất từ nào, due date không đổi bất ngờ |
| 4 | TextPipeline trong Background Isolate: normalize + tokenize (Trie cho Việt) + 4 segment profile | Test với câu có "Mr.", "U.S.", số thập phân, câu tiếng Việt ghép → tách đúng |
| 5 | ReviewEvent append-only + compaction job | Ghi 1000 event giả lập → RAM không tăng bất thường, snapshot đúng sau compaction |
| 6 | Implicit/Explicit lifecycle theo mục 6 | Test thủ công: đọc 1 bài liên tục 5 phút không bị gián đoạn bởi bất kỳ dialog nào |
| 7 | Attention Score v1 theo công thức mục 5 | Cho 1 bộ dữ liệu test, ranking output đúng thứ tự kỳ vọng thủ công |
| 8 | Chat grounding theo pipeline mục 7 | Mọi câu trả lời có nguồn đều trỏ về evidenceId reopen được đúng vị trí |

**Không làm ở giai đoạn này:** embedding, vector DB, LLM summarizer tự động, fine-tune GGUF, knowledge graph UI thật.

## 9. Test bắt buộc trước khi coi P0 xong (rút gọn từ AT1–AT8)

- [ ] Một từ gặp ở PDF **và** audio → 1 `KnowledgeUnit`, 2 `Evidence`, mở lại được cả hai đúng vị trí.
- [ ] Hai từ giống chữ khác nghĩa → không tự merge.
- [ ] Sửa nội dung trang Web đã lưu → app phát hiện "nguồn đã đổi", không im lặng dùng evidence cũ.
- [ ] Đổi tokenizer version → `unitId` và lịch sử review KHÔNG đổi.
- [ ] Hai thiết bị review offline cùng lúc, sau đó sync → không nhân đôi tiến độ, không mất event.
- [ ] Xóa 1 nguồn PDF → excerpt/evidence liên quan bị xử lý theo policy xóa đã định.
- [ ] Tắt hoàn toàn AI/GGUF → toàn bộ luồng Nghe/Đọc/Viết/Nhớ vẫn chạy bình thường.
- [ ] Nghe audio 0.3x liên tục trong khi background isolate xử lý text nặng → không giật/lag âm thanh.

## 10. Nếu Agent gặp mâu thuẫn giữa tài liệu này và code thật

**Ưu tiên theo thứ tự:**
1. Không phá 3 thế mạnh ở mục 0.
2. Không mất dữ liệu người dùng hiện có.
3. Theo đúng schema mục 2 nếu không xung đột (1) và (2).
4. Nếu bắt buộc phải đổi 1 trong 3 điều trên → dừng, báo cáo, không tự quyết định.

## 11. Ghi credit quá trình

Tổng hợp 8 vòng review: Arena Agent → Claude 5 → MAX → ChatGPT 5.5 ×2 → Gemini 3.7 → Grok 4.20 → Claude 5 (spec implementable). Từ đây mọi thay đổi kiến trúc đi qua ADR + code review.

**— HẾT TÀI LIỆU BÀN GIAO —**
