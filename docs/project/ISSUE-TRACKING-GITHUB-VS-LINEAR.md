# ISSUE-TRACKING — Dùng GitHub Issues thay Linear?

- **Ngày đo:** 2026-11-27 · repo `Pabhassaracitto/In4Up`
- **Bối cảnh:** Linear báo giới hạn thêm issue (plan/quota) ⇒ owner hỏi có chuyển
  sang quản lý issue bằng GitHub được không.

## 1. Đo thực tế (không suy đoán)

| Phép thử | Kết quả |
|---|---|
| `repos/…/issues` — cấu hình | Issues **bật**, Projects **bật**, repo public |
| Quyền của phiên agent | `viewerPermission = ADMIN` (thuộc chủ repo) |
| **Tạo issue** | ✅ **được** — đã tạo thử #209/#210/#211 |
| Gắn label khi tạo | tạo được nhưng **label bị bỏ qua** (server trả `labels=[]`) |
| Tạo label riêng | ✅ được (đã thử `probe-tmp`, đã xoá) |
| **Sửa issue (title/state)** | ❌ `403 Resource not accessible by integration` |
| **Comment** | ❌ 403 |
| **Gắn label vào issue đã có** | ❌ 403 |
| **Đóng/xoá issue** | ❌ 403 (cả REST `PATCH` lẫn GraphQL `deleteIssue`) |
| Sửa mô tả repo | ❌ 403 |
| Milestone hiện có | 0 |

**Kết luận về quyền:** token GitHub của Arena trong phiên này là token của một
GitHub App **chỉ được cấp quyền tạo issue**, không có `issues: write` cho các
thao tác cập nhật. Nói cách khác: agent **mở được** issue mới, nhưng **không
đóng/sửa/nhãn/comment** được — những việc đó phải do owner làm trên web, hoặc
phải cấp thêm quyền cho app.

## 2. Hiện trạng quản lý việc của repo

Repo **đã có** hệ thống issue trong Git, không phải ngoài:

- `docs/project/KANBAN.md` — **294 card** + bảng tổng quan **313 dòng**.
- `docs/GOVERNANCE.md` §3 — luật status-only / append-only: không xoá dòng,
  đổi trạng thái phải thêm dòng `Lịch sử` theo format cố định.
- `.github/pull_request_template.md` — PR đã buộc khai báo *Card Kanban*, phạm vi,
  agent/branch, base.

Thêm GitHub Issues là **hệ thống thứ ba**. Rủi ro chính không phải kỹ thuật mà là
**hai nguồn sự thật**: một việc tồn tại ở cả Linear/GitHub Issues lẫn KANBAN thì
sớm muộn lệch nhau.

## 3. Ba phương án

### A. Ở lại Linear, dùng KANBAN khi hết quota (khuyến nghị)
- Linear vẫn **đọc** được bình thường (đã kiểm: 2 team `PSRC`/`UIUX`, project
  `I4U`/`VDP`, đọc được issue + label + state).
- Hết quota ⇒ tạo card trong `KANBAN.md` (agent ghi được, không giới hạn, có
  governance sẵn). Việc vẫn chạy tiếp, không bị chặn.
- Không sinh nguồn thứ hai.

### B. Chuyển hẳn sang GitHub Issues
- Ưu: không quota; PR ↔ issue liên kết tự động (`Fixes #123`); search/label/board
  sẵn; owner đã có toàn quyền.
- Nhược: (1) agent **không cập nhật** được issue (mục 1) ⇒ mọi thay đổi trạng
  thái phải qua owner; (2) phải dựng quy ước nhãn mới, migrate 294 card; (3) dễ
  lệch với KANBAN.
- Cần làm trước: bật `issues: write` cho GitHub app của Arena (hoặc owner tự
  đóng/sửa), tạo nhãn, tạo issue template.

### C. Lai: GitHub Issues là cửa vào, KANBAN là sổ cái
- Issue = yêu cầu thô từ owner; khi nhận việc, agent tạo card KANBAN và ghi
  `GitHub #<n>` vào card; đóng issue khi card `done`.
- Chịu được giới hạn quyền: agent chỉ cần *tạo* card + đọc issue; đóng issue do
  owner hoặc do PR merge (`Fixes #n`).

## 4. Quy ước nếu chọn B/C

Nhãn (thay cho `P1/P2` + `agent-handoff` của Linear):

| Nhãn | Nghĩa |
|---|---|
| `prio:P0` / `prio:P1` / `prio:P2` / `prio:P3` | mức ưu tiên |
| `area:read` · `area:pdf` · `area:tts` · `area:dict` · `area:glib` · `area:i18n` · `area:ui` | vùng tính năng |
| `needs-device` | chưa nghiệm thu trên máy thật |
| `agent-handoff` | giao cho agent |
| `needs-review` | chờ owner duyệt |

Tiêu đề giữ đúng thói quen hiện tại: `[MÃ-CARD] (P?) mô tả ngắn`.
Thân issue: triệu chứng → kỳ vọng → nơi đọc code → nghiệm thu (giống card Linear).

## 5. Việc còn treo do lần đo này

3 issue thử **chưa đóng được** (403) — owner đóng hộ trên web:

- #209 `[probe] kiểm quyền tạo issue — sẽ đóng ngay`
- #210 `[probe-2] test khả năng`
- #211 `[probe-3] với label`
