# ADR-0001: Chuẩn hóa SM-2 về MỘT hàm duy nhất — chọn bản "SkillReviewData"

- **Ngày:** 2026-08-19
- **Trạng thái:** Đã duyệt (chủ sở hữu dự án, trong phiên bàn giao MATRIX KNOWLEDGE MVA v2.0)
- **Phạm vi:** Task 2 của bàn giao (chưa triển khai — ADR này chốt trước *đích đến*)

## Bối cảnh

Bàn giao MVA v2.0 mục 8 (Task 2) yêu cầu: chỉ giữ đúng **1 hàm tính SM-2** trong toàn bộ
codebase. Audit hiện trạng phát hiện **3 nơi** chứa toán SM-2 (nhiều hơn 2 nơi như brief
v1.0 mục 3.4 đã nêu):

| # | Vị trí | Vai trò thực tế | Ngữ nghĩa |
|---|---|---|---|
| 1 | `lib/models/sm2_algorithm.dart` → `SM2Algorithm.calculate()` | review_tab.dart dùng để **hiển thị** interval dự kiến (`_calcInterval`) | Anki kiểu chuẩn: thưởng ×1.3 cho Easy, phạt ×0.8 cho Hard; fail trừ EF phẳng −0.2 |
| 2 | `lib/models/word_entry.dart` → `SkillReviewData.review()` (~dòng 143) | `vocabulary_provider.reviewSkill()` gọi — **đây mới là đường GHI dữ liệu thật** của luồng 3 kỹ năng | Không thưởng/phạt interval; EF luôn theo công thức chuẩn kể cả khi fail; cập nhật thêm mastery score 0–1 |
| 3 | `lib/screens/memory_mode/models/memory_item.dart` (~dòng 130–200) | Memory Mode: engine riêng theo `MemoryStage`, interval tính bằng **giờ** | markHard −0.05 EF, markRetired +0.2 EF & +90 ngày — không phải SM-2 thuần |

Hệ quả hiện tại: màn hình review **nói một đằng** (bản 1) trong khi dữ liệu **được ghi một nẻo**
(bản 2) — cùng 1 lần bấm "Easy" hai bản chênh nhau đến ~30% interval.

## Quyết định

1. **Bản 2 (`SkillReviewData`) là chuẩn ngữ nghĩa** — vì đó là đường đang quyết định
   due date thật của dữ liệu người dùng; chuẩn hóa về nó giữ nguyên
   *"review due date không đổi bất ngờ"* (DoD Task 3, AT mục 9).
2. Task 2 sẽ gom mọi nơi gọi về MỘT hàm `SM2Algorithm.calculate()` duy nhất
   mang ngữ nghĩa bản 2; xóa toán trùng ở `SkillReviewData` và nơi khác.
3. **Memory Mode (bản 3) xử riêng:** giữ nguyên hệ stage (đó là đặc tính sản phẩm,
   không phải "công thức SM-2 trùng lặp"); chỉ phần toán EF dùng chung lõi.
   Đổi hành vi của Memory Mode phải được báo cáo và duyệt riêng — không tự quyết.
4. `SM2Snapshot.algorithmVersion` (schema mục 2.3) khởi điểm là **`sm2-srd-v1`**
   (srd = SkillReviewData) — hằng số `kSm2AlgorithmVersion` trong
   `lib/knowledge/models/learning_state.dart`.

## Hệ quả

- Due date các từ hiện tại KHÔNG đổi; preview trên review_tab sẽ khớp dữ liệu thật.
- Bản 1 (thưởng/phạt Anki) bị bỏ — nếu sau này muốn lại, phải nâng `algorithmVersion`
  và có ADR mới; dữ liệu cũ vẫn đọc được nhờ trường version trên snapshot.
- Được thực thi ở Task 2, sau Task 1 (schema models) — không sớm hơn.
