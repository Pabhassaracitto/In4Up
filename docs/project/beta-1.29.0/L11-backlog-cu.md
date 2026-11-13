# L11 — Backlog cũ + hàng đợi In Review (ngoài cổng beta)

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD).
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

> ⚠️ **Lane này KHÔNG thuộc cổng beta 1.29.0.** Nó tồn tại để backlog cũ có chủ, và để chủ dự án có thể nhắn một câu và kéo một nhúm vào cùng nhánh beta nếu rảnh. Hub chỉ land sau khi 10 lane trên xong.

## Mục tiêu

Dọn phần còn lại của project I4U: (a) **chốt 2 issue đang In Review** đã sửa xong, (b) phân loại các issue mở **ID ≤ PSRC-196** — mỗi cái phải được gán vào một lane khu vực (L1–L10) hoặc đóng với lý do.

## A. Hai issue đang In Review — chốt trước

| # | Trạng thái | Việc cần làm |
|---|---|---|
| **PSRC-14** | In Review | `READ-SELECT-002` (kéo chọn nhiều từ). Mô tả nói đã sửa, CI xanh (run `37529218138`). **Việc của agent:** kiểm lại trên nhánh beta, chạy lại test liên quan, nếu đúng ⇒ comment bằng chứng rồi chuyển **Done** |
| **PSRC-6** | In Review | `XLAT-MIX-001` (câu trộn ngôn ngữ). Như trên |

Không viết lại code nếu đã xanh — chỉ **xác minh + đóng**, hoặc mở lại nếu thấy hồi quy.

## B. Backlog cũ — bảng phân loại

Những issue dưới đây **đã biết** và được gán sẵn. Chúng **không** nằm trong đợt 1 của lane khu vực tương ứng; làm khi hub yêu cầu.

| # | Nội dung ngắn | Lane khu vực |
|---|---|---|
| PSRC-196 | Live cabin: đồng bộ chọn tab | L1 — **trùng PSRC-199** ⇒ đóng as duplicate khi 199 xong |
| PSRC-195 | Xuất file media kẹt "Estimating duration…" | L2 (đã đưa vào đợt 1 vì chặn 202/203) |
| PSRC-180 | Tạo lời lỗi FfmpegKit | L2 (đợt 1) |
| PSRC-179 | Đồng bộ khoảng lặng nút AB | L2 (đợt 1) |
| PSRC-194 | Icon dịch cabin hiện trên tab Nghe/Speaking | L4 |
| PSRC-193 | Tipitaka: chỉ mục con sai danh mục | L3 |
| PSRC-178 | Tên gọi "Lặp câu tiếp theo" | L3 |
| PSRC-174, PSRC-172 | Linux: quét thư viện không phản hồi | L5 |

## C. Phần chưa đọc hết — việc của agent L11

Page JSON của Linear bị giới hạn kích thước nên ~15 issue còn lại (ID thấp hơn PSRC-172, trạng thái Backlog) **chưa được liệt kê ở trên**. Agent L11 làm:

1. Mở Linear, project **I4U**, state **Backlog**, sắp theo `createdAt` tăng dần, **đọc từng trang ≤ 12 issue** (trang lớn hơn sẽ bị cắt giữa).
2. Với mỗi issue: gán **một** lane khu vực L1–L10 (theo thư mục `lib/features/...` mà nó chạm), hoặc đề xuất **đóng** (trùng/không còn tái hiện/ngoài sản phẩm) kèm lý do.
3. Ghi kết quả vào **§ D** của chính file này (một commit tài liệu), không sửa issue nào khác ngoài comment phân loại.
4. Chỉ sửa code khi chủ dự án chỉ định issue cụ thể.

## D. Bảng phân loại do agent điền

| # | Nội dung ngắn | Lane | Ghi chú |
|---|---|---|---|
| _(agent điền)_ | | | |

## Nghiệm thu

- [ ] PSRC-14 và PSRC-6: có comment bằng chứng + đóng, hoặc mở lại kèm lý do.
- [ ] Mọi issue Backlog của I4U xuất hiện **đúng một lần** trong § B hoặc § D.
- [ ] Không issue nào bị đóng mà không có lý do viết ra.
- [ ] `app_analyze` xanh (nếu có sửa code).

## Commit

```
docs(PSRC-14): xác minh và đóng READ-SELECT-002 [L11]
docs(PSRC-6): xác minh và đóng XLAT-MIX-001 [L11]
docs(backlog): phân loại issue cũ vào lane khu vực [L11]
```

## Phát hiện thêm

_(trống)_
