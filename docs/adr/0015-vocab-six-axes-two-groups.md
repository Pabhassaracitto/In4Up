# ADR-0015: Từ vựng 6 trục / 2 nhóm (Input + Output) + ranh giới chống đếm trùng

- **Ngày:** 2026-11-03
- **Trạng thái:** PROPOSED (chờ owner xác nhận + P0 tái xác minh)
- **Phạm vi:** `WordEntry` (WordList), `SkillKind` (mới), `SkillDimension` (knowledge),
  `ReviewEvent`, `LearningState`, các task nguồn (Write Studio, Shadowing, grammar_lexicon).

## Bối cảnh

Owner muốn đánh giá từ vựng **cả đầu vào và đầu ra**, không chỉ "nhớ hay quên".
Hiện tại `WordEntry` chỉ có 3 kỹ năng input: `understand / listen / read`, mỗi kỹ năng SM-2 riêng.
Output (viết/nói/dùng) có thực hành nhưng **không feed vào mastery**.

Owner cũng xác định: **"Dùng nghĩa" xếp cùng nhóm Output** (vì bằng chứng của Dùng luôn là sản xuất).
Mô hình 2 nhóm (đầu vào / đầu ra) giữ trọn triết lý của owner.

## Quyết định

### 1. 6 trục / 2 nhóm

| Index | Trục | Nhóm | Bằng chứng Phase 1 |
|---|---|---|---|
| 0 | understand | Input | Meaning recognition |
| 1 | listen | Input | Audio identification |
| 2 | read | Input | Context clue |
| 3 | use | Output | form + sentence |
| 4 | speak | Output | Từ đơn qua `PronunciationService.analyze` |
| 5 | write | Output | Từ đơn qua scorer Write Studio |

- `SkillKind` enum append `use=3, speak=4, write=5`. **Chỉ append, không chèn giữa.**
- **Mapping 3 enum (audit fix):**
  - `WordEntry.Skill` = `understand, listen, read` (giữ nguyên).
  - `SkillDimension` = `understanding, listening, reading` (giữ nguyên).
  - `SkillKind` mới tiểu tương ánh: `understand→understanding, listen→listening, read→reading`.
  - Migration map cả 3 enum consistently; không gộp tên.

### 2. Ranh giới chống đếm trùng

- **Viết** = viết từ (chính tả, từ đơn, tách biệt).
- **Nói** = phát âm từ đơn.
- **Dùng** = dùng từ **trong câu + đúng dạng + đúng kết hợp từ**.
- Mỗi task có **đúng 1 primarySkill**. Secondary impact ≤0.3 chỉ cập nhật Mastery Vector, không vào SM-2.

### 3. Nhớ (retention) là lớp riêng

- `Nhớ` là lớp glow/opacity, **không** là trục, **không** cộng vào mastery (ADR-0001).
- Retention unknown **không** gán 0.5.

## Hệ quả

- (+) Đánh giá toàn diện input + output; visual lục giác kép 3+3.
- (+) Append-only → dữ liệu cũ không mất.
- (−) Cần adapter word-scoped cho Viết/Nói (P0 tái xác minh scorer).
- (−) 3 enum cần mapping rõ để không rối trong migration.

## Kiểm thử

- Unit test: append `use/speak/write` không làm hỏng parse dữ liệu cũ.
- Unit test: ranh giới chống đếm trùng (task chỉ tính vào 1 primarySkill).
