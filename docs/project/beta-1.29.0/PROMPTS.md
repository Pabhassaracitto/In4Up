# Tin nhắn gửi agent — mỗi lane một câu

Dùng đúng như dưới. **Không** dán thêm nội dung lỗi/đoạn code: agent tự đọc Linear và tự đọc repo.
Chỉ cần thay `<session-id>` bằng id phiên của agent đó (Arena đặt tên nhánh `arena/<session-id>-in4up`).

## Câu chung cho mọi agent (gửi kèm câu của lane)

> Nhánh cha là `arena/60e35d65-in4up`. Tạo nhánh `arena/<session-id>-in4up` từ **tip nhánh cha**, rồi đọc `docs/project/beta-1.29.0/README.md` và phiếu lane của bạn trong cùng thư mục. Làm đúng các issue ghi trong phiếu. Commit theo đúng định dạng ở README § 2 (một issue = một commit, chỉ rebase, không merge). Xong thì rebase lên `origin/arena/60e35d65-in4up`, push nhánh của bạn, và báo lại: issue nào xong, run CI nào xanh, phần nào chưa kiểm được trên máy thật.

## Câu riêng từng lane

| Lane | Tin nhắn |
|---|---|
| **L1** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L1-cabin.md và sửa các issue PSRC-199, 200, 201, 223.` |
| **L2** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L2-audio-video.md và sửa các issue PSRC-202, 203, 205, 219, 220 — làm 202/203 trước vì cùng đường xuất file.` |
| **L3** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L3-tab-doc.md và sửa các issue PSRC-206, 207, 208, 209, 210, 230, 233.` |
| **L4** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L4-bong-bong-dich.md và sửa issue PSRC-211.` |
| **L5** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L5-linux.md và sửa các issue PSRC-212, 213 (Linux only; phần phát mp4 là của lane L2, đừng chạm).` |
| **L6** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L6-vieneu-engine.md và sửa các issue PSRC-214, 215, 216, 217, 218 theo đúng thứ tự đó.` |
| **L7** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L7-tep-va-noi-luu.md, làm theo ADR-0029, sửa các issue PSRC-204 và 222.` |
| **L8** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L8-android-system-tts.md và sửa issue PSRC-221.` |
| **L9** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L9-shadowing.md và sửa các issue PSRC-226, 228, 227, 225.` |
| **L10** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L10-pdf-web-reader.md và sửa các issue PSRC-231, 232, 229 theo đúng thứ tự đó.` |
| **L11** | `Nhánh của bạn là arena/<session-id>-in4up. Đọc docs/project/beta-1.29.0/L11-backlog-cu.md: chốt PSRC-14 và PSRC-6, rồi phân loại backlog cũ vào bảng § D. Chưa sửa code issue nào khác.` |

## Khi agent báo xong — hub làm gì

```bash
git switch arena/60e35d65-in4up
git fetch origin <nhánh-của-agent>
git rebase origin/<nhánh-của-agent>      # giữ tuyến tính: hub KHÔNG merge commit
```
Nếu rebase tuyến tính được (thường là vậy khi agent đã rebase trước khi push) thì tương đương `merge --ff-only`; nếu agent lỡ tạo merge commit, yêu cầu agent viết lại lịch sử (`git rebase -i`) chứ hub không sửa hộ.
Sau khi land: hub cập nhật `docs/project/KANBAN.md` + `BETA-1.29.0.md` § 8 trong **một** commit `docs(beta): cập nhật tiến độ sau lane Lx`.

## Thứ tự land (hub)

`L7 (đang làm)` → `L1` → `L8` → `L9` → `L2` → `L3` → `L10` → `L4` → `L5` → `L6` → `L11`

Lý do: L7/L1 chạm hạ tầng (lưu file, trạng thái cabin) mà lane khác dùng; L8 chạm `android/` (build lâu, land sớm để phát hiện lỗi build); L10 sau L3 vì dùng chung bộ chia câu; L6 sau cùng vì nặng native; L11 là dọn dẹp.
