# L9 — Shadowing: tab Nói & tab Hiểu

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD). Bản đồ gốc: `../BETA-1.29.0.md` § 2.
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Shadowing phải: thu gọn nội dung và **ưu tiên Shadowing Mode** ở tab Nói, "nghe mẫu" phát **đúng và chỉ** câu đang chọn, chấm điểm phản ánh đúng mức khớp ở **cả** tab Nói và tab Hiểu, tab Hiểu có dòng gợi ý, và không còn mục Shadow "chết" trong phần tạo lời.

> Ranh giới với **L3**: L3 lo engine/giọng khi đọc tài liệu. L9 lo luồng Shadowing (chọn câu, phát mẫu, ghi âm, chấm điểm, bố cục tab).

## Issue

| # | Triệu chứng (theo Linear) |
|---|---|
| **PSRC-224** | Tab Nghe, phần tạo lời có mục **Shadow** — nếu mục này không có chức năng thì **lược bỏ** |
| **PSRC-225** | Tab Nói quá nhiều chữ, khó tập trung: cần bung/gộp nội dung, đưa Shadowing Mode lên đầu |
| **PSRC-226** | Shadowing tab Nói, "Gợi ý theo câu": chọn một dòng, bấm "Nghe mẫu" ⇒ audio **đọc quá** dòng đã chọn |
| **PSRC-227** | Chấm điểm sai: đọc sai / chỉ đọc vài từ vẫn được điểm cao, đánh giá "đúng hết"; tab Hiểu cũng sai |
| **PSRC-228** | Tab Hiểu **không hiện dòng gợi ý**; "nghe mẫu" đọc **hết** nội dung thay vì giới hạn theo câu |

## Thứ tự làm

**224 → 226 → 228 → 227 → 225.** 224 là việc nhỏ (dọn UI chết) làm trước để biết mục Shadow nào còn thật; 226/228 cùng một gốc (phát mẫu không giới hạn theo câu) nên làm liền nhau; 227 nặng nhất (thuật toán chấm) để sau; 225 là bố cục, làm cuối.

## Hướng điều tra

Vùng code: `lib/features/shadowing/{screens,widgets,services,providers,models}`; phần tạo lời ở tab Nghe: `lib/screens/listen_mode/**`.

1. **224**: tìm mục "Shadow" trong panel tạo lời. Nếu nó chỉ là nút điều hướng chết (`onTap: null`, hoặc mở màn hình không tồn tại) ⇒ xoá; nếu có chức năng ⇒ sửa cho chạy và ghi lại trong commit. Đừng để "Shadow" nửa vời.
2. **226 & 228 (cùng gốc)**: "nghe mẫu" đang gọi TTS với **toàn bộ text** thay vì câu hiện tại. Cần: một hàm `speakSentence(index)` duy nhất, `stop()` + token chống race khi đổi câu, và mọi nút "Nghe mẫu" đều đi qua đó.
3. **228 gợi ý**: tab Hiểu chưa hiện dòng gợi ý — kiểm tra dữ liệu gợi ý có được tạo nhưng widget bị điều kiện ẩn; dùng lại dữ liệu sẵn có, **không** gọi AI mới nếu chưa cần.
4. **227**: đọc vài từ vẫn điểm cao ⇒ công thức đang chia cho **số từ người dùng đọc** thay vì số từ của câu mẫu, hoặc khớp theo tập từ mà không phạt thiếu. Cần: chuẩn hoá text (NFC, bỏ dấu câu, chữ thường, số→chữ nếu cần), tính độ khớp trên **toàn bộ câu mẫu** (bắt buộc phủ), và một hàm chấm **thuần** để test bằng bảng ca.
5. **225**: chỉ là bố cục — Shadowing Mode lên đầu, nội dung bung/gộp được (`ExpansionTile`/`AnimatedSize`), giữ trạng thái khi rebuild.

## File chạm (dự kiến)

`lib/features/shadowing/**`, `lib/screens/listen_mode/**` (chỉ mục Shadow ở panel tạo lời), test `test/shadowing/*` (bắt buộc có bảng ca cho hàm chấm điểm).

## Nghiệm thu

- [ ] Không còn mục Shadow chết ở phần tạo lời (hoặc nếu giữ thì nó chạy thật — ghi rõ trong commit).
- [ ] Chọn câu #3 ⇒ "Nghe mẫu" chỉ phát câu #3 (test: hàm phát nhận đúng text); đổi câu 10 lần liên tiếp không phát chồng.
- [ ] Bảng ca chấm điểm: đọc đúng / đọc thiếu nửa câu / đọc sai hoàn toàn, có dấu và không dấu, có số ⇒ điểm phản ánh đúng thứ tự.
- [ ] Tab Hiểu: có dòng gợi ý cho câu đang chọn; nghe mẫu chỉ đọc câu đó.
- [ ] Tab Nói trên 360×640: Shadowing Mode nằm trong màn hình đầu, không cần cuộn.
- [ ] `flutter analyze` 0 error; `app_analyze` + `listen_queue_tests` xanh.

## Không làm

- Không đổi mô hình nhận dạng giọng nói.
- Không thêm bảng điểm mới / lưu lịch sử học.

## Commit

```
fix(PSRC-224): bỏ mục Shadow không có chức năng ở phần tạo lời [L9]
fix(PSRC-226): nghe mẫu phát đúng và chỉ câu đang chọn [L9]
fix(PSRC-228): tab Hiểu có gợi ý, nghe mẫu giới hạn theo câu [L9]
fix(PSRC-227): chấm điểm đúng ở tab Nói và tab Hiểu [L9]
fix(PSRC-225): thu gọn nội dung, ưu tiên Shadowing Mode [L9]
```

## Phát hiện thêm

_(trống)_
