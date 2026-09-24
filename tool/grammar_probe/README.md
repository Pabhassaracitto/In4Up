# `tool/grammar_probe/` — spike đặc tả: CỤM TỪ + CẤU TRÚC CÂU

> ⚠️ **Đây KHÔNG phải mã sản phẩm.** Đây là **đặc tả thuật toán chạy được** (Python), viết để
> kiểm chứng logic trước khi viết Dart — môi trường phát triển của agent không có Flutter/Dart SDK.
> Kế hoạch sản phẩm: `docs/project/PLAN-029-cau-truc-cau-read-tab.md`,
> quyết định kiến trúc: `docs/adr/0006-cau-truc-cau-lop-rieng-line-first.md`,
> card: `docs/project/KANBAN.md` → `READ-GRAM-001`.
>
> Bản Dart **viết lại theo idiom Dart** (tái dùng `SyntaxHighlighterService`,
> `GrammarLexiconService`, `TextSegmenter`) — **KHÔNG port nguyên file này**, và bảng từ ngắn
> trong `engine.py` **bị bỏ** vì repo đã có lexicon thật.

## Chạy

```bash
python3 tool/grammar_probe/run_probe.py                        # corpus dev (65 case)
python3 tool/grammar_probe/run_probe.py tool/grammar_probe/holdout.json
python3 tool/grammar_probe/run_probe.py tool/grammar_probe/holdout2.json   # bộ ĐÓNG BĂNG
```

Runner in độ chính xác từng trường + runtime, `exit 1` nếu có case lệch ⇒ dùng được như golden test.
`--verbose` in cả case đúng.

## Ba bộ corpus (đọc kỹ trước khi trích dẫn số)

| File | Case | Viết khi nào | Đọc số thế nào |
|---|---|---|---|
| `corpus.json` | 65 | tinh chỉnh 8 vòng trên chính nó | **0 sai** nhưng **KHÔNG** phải ước lượng tổng quát hoá |
| `holdout.json` | 30 | viết sau đợt tinh chỉnh 1 | 0 sai (đã sửa 2 **nhãn vàng sai**: H24, H27 — ghi trong file) ⇒ vẫn không phải ước lượng |
| `holdout2.json` | 25 | **ĐÓNG BĂNG** — viết sau cùng, chạy **một lần**, không sửa engine sau đó | ✅ **Con số khách quan duy nhất: 17/25 case (68%)** |

`holdout2` có 8 case sai ⇒ 4 nguyên nhân gốc, đã phân loại trong PLAN-029 §7.1:
**A** PP vị trí ngoài cụm · **B** trạng từ chen trong nhóm động từ + thiếu `would rather` ·
**C** quy ước câu hỏi đuôi chưa chốt · **D** quan hệ zero + thiếu từ vựng (bản Dart tự khỏi).

## Nội dung `engine.py`

`analyze(text, anchor, anchor_occurrence)` →
`{supported, phrase{kind,span,split,part_offsets}, outer, sentence{type,question,polarity,negator,
tense,aspect,voice,modal,pattern,span}, clause_role, conditional, sentence_span, notes}`

Chuỗi xử lý: `normalize` (1 ký tự ↔ 1 ký tự, giữ offset) → tokenize (offset) → `expand_contractions`
→ `tag_tokens` (POS + ngữ cảnh) → `sentence_spans`/`clause_spans`/`modifier_spans` →
`verb_chain_at` + `read_verb_group` (thì × thể × thái) → `sentence_type`/`polarity`/`pattern_of` →
`all_candidates`/`pick_chunk` (cụm nhỏ nhất + cụm bao ngoài) → `is_likely_english` (cổng ngôn ngữ).

**Bất biến cần giữ khi chuyển sang Dart:**
- Không bao giờ trả nhãn khi không đủ tin cậy — `supported=false` / `notes[]` / UI ẩn.
- Offset ký tự phải ổn định qua chuẩn hoá (kể cả khi tách `'s`, `n't`).
- Mệnh đề chính quyết định `tense/aspect/voice/pattern`; mệnh đề chứa anchor ghi ở `clause_role`.
- Nhóm động từ **không** gồm tân ngữ; tiểu từ cụm động từ (`turn off`) **thuộc** nhóm động từ.

## Sửa spike thì sửa cho đúng

- `bash` thay chuỗi là **no-op im lặng** nếu mẫu không khớp — luôn chạy lại `run_probe.py` và tin
  **bảng số đo**, không tin dòng "patch ok".
- Đã có 2 lần crash vì trộn **span ký tự** với **chỉ số token**; giữ hai loại tách bạch.
- Guard mọi truy cập `toks[i-1]` khi `i == 0`.
