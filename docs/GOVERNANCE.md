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

### 2a. Cạm bẫy sandbox: nhánh `arena/*` bị "mất" do clone single-branch

> Ghi nhận 2026-08-22 (session Beta `arena/01a02a12-in4up`): agent được tạo từ
> tip 251e nhưng `git branch -r` chỉ thấy `main`, và
> `git show origin/arena/01a0251e-in4up:SO_TAY_CHU.md` báo `fatal: path ... does not exist`.
> **KHÔNG phải nhánh gốc bị mất.** Nguyên nhân: sandbox clone có
> `remote.origin.fetch = +refs/heads/main:refs/remotes/origin/main`
> (single-branch), nên `git fetch origin` chỉ kéo `main` mà không kéo các
> nhánh `arena/*` dù chúng vẫn tồn tại trên GitHub.

Check nhanh:

```bash
git config --get remote.origin.fetch   # nếu chỉ có main ⇒ đúng bẫy này
git branch -r                          # nếu chỉ origin/main ⇒ chưa fetch nhánh lineage
gh api "repos/Pabhassaracitto/In4Up/branches?per_page=100"  # xác nhận nhánh tồn tại trên GitHub
```

Chạy để fetch đủ nhánh lineage trước khi đọc sổ tay / đối chiếu:

```bash
git fetch origin arena/01a0251e-in4up:refs/remotes/origin/arena/01a0251e-in4up
git fetch origin arena/01a01580-in4up:refs/remotes/origin/arena/01a01580-in4up
git fetch origin arena/019fe630-vipsound:refs/remotes/origin/arena/019fe630-vipsound
git branch -a
git show origin/arena/01a0251e-in4up:SO_TAY_CHU.md
```

Lưu ý thêm:

- Sandbox này vẫn là **shallow clone**: lịch sử sâu phía sau tip có thể không
  đầy đủ cho bisect, nhưng refs + blobs của tip thường đủ cho path-checkout.
- Chỉ vì không thấy ref **không** được tự tạo/rebase/merge dựa trên giả định;
  nếu không fetch được, dừng lại báo chủ.

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

## 4b. Luật bảo vệ lịch sử main (KHÔNG dựng lại main nữa)

> Hậu kiểm tiền lệ: main đã bị rewrite **3 lần** (2026-08-20/21: squash-nhập
> khẩu → force-move sang lineage vipsound → squash-nhập lần 2). Cả 3 lần
> may mắn không mất dữ liệu (governance được cứu nhờ content-sync). Từ
> 2026-08-21, ký kết giữa người sở hữu và agent:

1. **KHÔNG force-push / squash-rewrite / filter-branch trên main.**
2. Mọi thay đổi lên main = commit thường, hoặc path-checkout chọn lọc
   (`git checkout origin/<branch> -- <files>` — content-sync, 0 conflict).
3. Cần "làm lại" gì ⇒ branch mới; main là bản kiểm toán (mục 3.3 mở rộng).
4. Đồng bộ nội dung giữa branch = path-checkout; KHÔNG merge chéo các
   lineage bị squash (base chung sai ⇒ conflict giả hàng chục file).

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
