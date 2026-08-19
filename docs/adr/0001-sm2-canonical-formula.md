# ADR-0001: Chuẩn hóa SM-2 về MỘT hàm duy nhất — chọn bản "SkillReviewData"

- **Ngày:** 2026-08-19
- **Trạng thái:** ĐÃ TRIỂN KHAI (Task 2, 2026-08-20 — CI xanh, xem "Triển khai" cuối file)
- **Phạm vi:** Task 2 của bàn giao

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

## Triển khai (Task 2 — 2026-08-20)

Audit bằng chứng trước khi sửa:

| Nơi | Kết quả audit |
|---|---|
| `SM2Algorithm.calculate` (Bản 1) | CHỈ dùng vẽ nhãn preview nút "Hard/Good/Easy …d": `review_tab.dart:335`, `single_word_review_screen.dart:381`, `word_detail_sheet.dart:390` — không ghi dữ liệu |
| `SkillReviewData.review` (Bản 2) | Đường GHI thật: `vocabulary_provider.reviewWord/reviewWordSkill` → `_saveWord` |
| `memory_item.dart` (Bản 3) | Engine stage/giờ riêng — KHÔNG đụng theo mục Quyết định 3 |
| `word_list_models.dart` (WordEntry trùng tên) | Không chứa logic SM-2 — không việc gì |

Thay đổi:

1. `lib/models/sm2_algorithm.dart` — viết lại thành hàm duy nhất với ngữ nghĩa
   Bản 2 (bỏ ×1.3/×0.8, EF chuẩn cho mọi quality, thêm `now` tiêm được),
   phát hành `kSm2AlgorithmVersion = 'sm2-srd-v1'`.
2. `lib/models/word_entry.dart` — `SkillReviewData.review()` delegate sang hàm
   duy nhất; giữ nguyên bookkeeping mastery-score. Due date dữ liệu cũ không đổi.
3. `lib/knowledge/models/learning_state.dart` — `kSm2AlgorithmVersion` chuyển
   nguồn về sm2_algorithm.dart, re-export giữ tương thích.
4. 3 chỗ gọi Bản 1 giữ nguyên signature — giờ preview **khớp** dữ liệu được ghi.
5. Test khóa: `test/knowledge/sm2_canonical_test.dart` — bao lưới tương đương
   384 tổ hợp `SkillReviewData.review() ≡ SM2Algorithm.calculate()`.

