# Bàn giao tư vấn — Pic Anki (Image Occlusion) + Pic Express (Look & Describe)

> Nguồn: owner 2026-09-05 — “Anki thêm hình rồi che một phần để đố rất hay; Google nhìn hình miêu tả và chấm điểm rất hay — tư vấn để khi OK tích hợp.”
> Trạng thái: **tư vấn only**. Không code cho đến khi owner chọn WP.

## 1. Tinh hoa cần lấy (không copy sản phẩm)

### 1.1 Anki Image Occlusion (Pic Anki)

Anki thắng vì **một hình = nhiều thẻ độc lập**, ôn đúng chỗ yếu, không ôn cả bức.

Tinh hoa:

1. **Che hình học, không che file.** Ảnh gốc giữ nguyên. Lớp mặt nạ (rect / ellipse / polygon) là dữ liệu riêng — như Evidence PDF page+rect.
2. **Một vùng = một thẻ SM-2.** Che “động mạch chủ” khác lịch ôn với “tĩnh mạch chủ”. Không gộp 1 điểm số (Rule vàng #2).
3. **Hai chiều:** Hide → đoán nhãn; Show label → chỉ vùng. Hide All / Reveal One.
4. **Vẽ nhanh:** kéo hình chữ nhật trên tablet; nhóm vùng; nhân bản mask.
5. **Nguồn reopen:** mở lại đúng ảnh + đúng vùng (Rule vàng #3).

Không cần clone editor Anki. Cần: mask JSON + review overlay + SM-2 per-mask.

### 1.2 Google “nhìn hình → miêu tả → chấm điểm” (Pic Express)

Gần nhất: luyện nói/viết multimodal (Gemini / Translate practice / Look and Speak):

1. **Kích thích thị giác** (ảnh thật, không flashcard chữ).
2. **Sản xuất ngôn ngữ** (nói hoặc viết 1–5 câu).
3. **Chấm có tiêu chí** (từ vựng, ngữ pháp, độ phủ nội dung, phát âm nếu nói) — không “AI khen mơ hồ”.
4. **Gợi ý sửa được hành động** (thiếu giới từ, thiếu chủ thể, thiếu thì).

In4Up đã có nửa đường: WriteStudio 2 tầng (local + GGUF) + STT + SM-2 listening/reading/understanding.

## 2. Vị trí trong In4Up (không tab thứ 6)

| Sản phẩm | Vào đâu | Skill SM-2 |
|---|---|---|
| Pic Anki (che hình) | Tools ⚡ + Memory Garden review | **reading** (nhận diện thị giác) — không gộp listening |
| Pic Express (miêu tả) | Tab Viết (task type mới) + tùy chọn mic | **understanding** (nội dung) + listening nếu nói |

Ảnh = Evidence `kind=image`, locator `{path, w, h, masks[]}`. Reopen = mở editor/review đúng file.

Pic Express **không** dùng Gemma làm “dịch giả Phật học”. Chấm miêu tả = cùng facade WriteStudio.

## 3. Mô hình dữ liệu (đề xuất, ADR khi code)

```
PicDeck
  id, title, sourceImagePath (app documents, không bundle Git)
  width, height
  createdAt

PicMask          // một vùng che = một KnowledgeUnit
  id, deckId
  shape: rect|ellipse|polygon
  normRect: {x,y,w,h}  // 0–1 theo ảnh (xoay/scale an toàn)
  label, hint, extraNotes
  unitId                 // nối knowledge nếu đã promote

PicDescribeTask
  id, imagePath
  promptLang, answerLang
  rubric: vocab|grammar|coverage|pronunciation
  referenceNotes?        // đáp án mẫu do user (không bắt buộc)
```

Offline-first: Hive. Ảnh copy vào `getApplicationDocumentsDirectory()/pic_anki/`. Không HTTP lúc bootstrap. Không auto-download VLM.

## 4. Lộ trình khi owner OK (mỗi WP 1 nhánh)

**WP-A — Pic Anki tối thiểu (offline 100%)**

- Import ảnh (gallery / camera / crop).
- Vẽ rect mask, lưu Hive.
- Review: che hết → tap vùng → hiện label; Again/Hard/Good/Easy → SM-2 **reading** only.
- AT: 1 ảnh 3 mask, ôn mask 2 không lộ mask 1; tắt app mở lại đúng.

**WP-B — Pic Express viết (tái dùng WriteStudio)**

- Ảnh + ô viết L2.
- Rubric cố định (JSON schema như `in4up_WRITE_REVIEW`): coverage 0–5, vocab, grammar, missing_entities[].
- Tầng 1: từ khóa / entity list do user gắn lúc tạo thẻ (offline, deterministic).
- Tầng 2: GGUF nếu đã nạp (không giả “sẵn sàng”).
- AT: thiếu 2 vật trong ảnh → coverage thấp + liệt kê vật thiếu; không model → tầng 1 vẫn chạy.

**WP-C — Pic Express nói (sau WP-B + mic ổn)**

- STT (system hoặc Sherpa WP4) → cùng rubric.
- Pronunciation = shadowing score nếu có câu mẫu; không bịa điểm phát âm từ LLM.

**WP-D (tuỳ chọn, online)** — Gemini/ML Kit image label chỉ khi user bật, để **gợi ý mask/label**, không thay SM-2.

Không làm cùng lúc A+B+C.

## 5. Cấm

- Tab thứ 6.
- Gộp reading+listening thành 1 score.
- Mất reopen (chỉ lưu bitmap đã che — phải giữ ảnh gốc + mask).
- Auto-download model thị giác.
- LLM bịa nội dung ảnh khi không có ảnh trong prompt (GGUF text-only: **không** “nhìn” được — tầng 2 chỉ chấm **text user vs label/entity do user gắn**). Đây là điểm then chốt: Gemma 2B **không multimodal**. Chấm “đúng hình” = so với **danh sách entity user gắn lúc tạo**, hoặc online VLM sau này.
- Đóng gói ảnh mẫu nặng vào Git.

## 6. Vì sao GGUF không “nhìn hình”

Viết rõ để khỏi thất vọng lúc tích hợp:

- `llama.cpp` + Gemma text GGUF = không encode ảnh.
- Pic Anki không cần AI.
- Pic Express offline = rubric so khớp entity/keyword + grammar heuristic WriteStudio.
- “Nhìn hình thật” = (1) user gắn nhãn lúc tạo, hoặc (2) ML Kit Image Labeling on-device, hoặc (3) API multimodal khi có mạng.

Đề xuất hay hơn Google một bước: **user là giám khảo sơ cấp** (gắn 5–10 entity) → máy chấm coverage deterministic → AI chỉ nhận xét câu. Không phụ thuộc cloud, không ảo giác “con mèo” khi ảnh là bình bát.

## 7. UX tablet (In4Up mạnh pen)

- Pic Anki: pen vẽ rect, khay màu nhóm mask (giống PLAN-002).
- Pic Express: ảnh full-bleed, ô viết dưới / mic nổi; rubric 4 thanh như assessment LHB.

## 8. Quyết định chờ owner

1. Làm **WP-A trước** (che hình, 0 AI) hay WP-B (miêu tả)?
2. Ảnh chỉ local hay có sync Firebase (thường không — file nặng)?
3. Có dùng ML Kit Image Labeling (Android/iOS) làm gợi ý entity không?

Khi OK: nhánh mới từ tip DEV, 1 WP, AT trong card KANBAN PIC-001.
