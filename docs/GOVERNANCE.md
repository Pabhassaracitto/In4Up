# GOVERNANCE — Hiến pháp quản trị thông tin dự án (cho người & AI agent)

> Mọi agent làm việc trong repo này ĐỌC file này trước khi đổi bất kỳ tài liệu
> dự án nào. Mục tiêu: đồng bộ đa-agent, đa-nhánh; không mất dấu vết;
> kế thừa thông tin; người làm chủ thông tin cuối cùng.

## 1. Bản đồ tài liệu

| File | Vai trò | Ai ghi |
|---|---|---|
| `AGENTS.md` | Cửa vào — định hướng + quy tắc vàng kỹ thuật | Agent (đổi ít) |
| `docs/GOVERNANCE.md` | File này — luật quản trị thông tin | Agent/Người (đổi rất ít) |
| `docs/project/KANBAN.md` | Bảng việc — nguồn sự thật duy nhất về trạng thái việc | Agent (thường xuyên) |
| `docs/project/PLAN.md` | Milestone + kế hoạch + tiếp nhận kế hoạch mới | Agent/Người |
| `docs/adr/NNN-*.md` | Quyết định kiến trúc (append-only, không sửa file cũ) | Agent/Người |
| `docs/skills/*/SKILL.md` | Kỹ năng agent (debug/vận hành) | Agent |
| `docs/HANDOFF_MVA_v2.md` | Hợp đồng bàn giao gốc — IMMUTABLE (không sửa) | — |

## 2. Luật đọc (đầu mọi session)

```bash
git fetch -q origin
git show origin/main:docs/project/KANBAN.md   # bản mới nhất toàn cục
git show origin/main:docs/project/PLAN.md
# so với bản trên branch mình; khác nhau ⇒ đọc lịch sử cả hai, hợp nhất theo luật 3.3
```

Không bao giờ giả định bản trên branch mình là mới nhất.

## 3. Luật ghi (quy tắc status-only, append-only)

1. **KHÔNG XÓA** dòng việc, dòng lịch sử, ADR, entry kế hoạch.
2. Đổi trạng thái = sửa trường `Trạng thái` **+ thêm 1 dòng** vào mục
   `Lịch sử` của card theo đúng format:
   `- YYYY-MM-DD | <ngày-giờ UTC> | <từ>→<đến> | <ai: agent-session/người> | <bằng chứng: commit/run/PR>`
3. Hủy việc: chỉ người sở hữu dự án được chuyển `→ cancelled` (kèm lý do
   trong dòng lịch sử). Agent không tự hủy việc do người đề ra.
4. Việc mới: agent tạo card với `ID` tăng dần theo tiền tố trong KANBAN.md,
   `Trạng thái: proposed`, nguồn ghi rõ.
5. Conflict khi merge hai nhánh cùng cập nhật KANBAN: giữ NGUYÊN cả hai dòng
   lịch sử; trường `Trạng thái` lấy theo dòng lịch sử MỚI NHẤT theo thời gian.

## 4. Luật đồng bộ đa-nhánh

- Governance update đi cùng commit công việc (không commit riêng trừ khi
  chỉ đổi tài liệu).
- PR merge sớm — thông tin chỉ "kế thừa toàn cầu" khi vào `main`.
- Agent đọc nhánh khác: `git show origin/<branch>:<file>` (không cần checkout).
- Sau khi main đổi giữa chừng session: agent Fetch lại và append tiếp —
  không rebase -f lịch sử đã đẩy.

## 5. Luật tiếp nhận kế hoạch mới (từ người sở hữu)

Người nói tự nhiên ("thêm kế hoạch X vào P1") cho agent ĐANG hoạt động:
1. Agent thêm entry vào `docs/project/PLAN.md` mục "Kế hoạch mới" theo
   template có sẵn: `Tên | Nguồn: người (YYYY-MM-DD) | Trạng thái: proposed | Milestone đề xuất`.
2. Nếu thành việc thực thi → tạo card tương ứng trong KANBAN.md.
3. Người tự sửa trực tiếp PLAN.md cũng hợp lệ — agent đọc ở session kế tiếp.

## 6. Chu kỳ kiểm kê

- Mỗi khi hoàn thành 1 task trong bàn giao: agent cập nhật KANBAN + PLAN
  (1 commit) — đó là "checkpoint kế thừa".
- Người sở hữu xem `KANBAN.md` (bảng tóm tắt trên cùng) = bức tranh toàn
  cảnh trong 30 giây.
