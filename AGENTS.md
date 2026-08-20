# AGENTS.md — Chỉ mục cho AI agent làm việc trong repo này

> File này để agent (Arena/Claude Code/Cursor/...) định hướng nhanh.
> Người đọc mới: bắt đầu từ đây, đừng dò code mù.

## Skills (tải trước khi làm việc liên quan)

- **`docs/skills/ci-red-debugging/SKILL.md`** — bắt buộc đọc khi CI GitHub Actions đỏ
  mà không tải được log (`gh run view --log` EOF) hoặc không có Flutter SDK local.
  Kèm script 1-lệnh `scripts/ci_check.sh` trong cùng folder.

## Tài liệu kiến trúc (không code mù — đọc trước khi đổi kiến trúc)

- `docs/HANDOFF_MVA_v2.md` — hợp đồng bàn giao MATRIX KNOWLEDGE MVA (schema mục 2,
  isolate boundary mục 4, 8 task, 8 acceptance test).
- `docs/adr/` — mọi quyết định kiến trúc sau bàn giao đi qua ADR tại đây
  (xem 0001: chuẩn hóa SM-2 về một hàm duy nhất + postmortem).

## Quản trị thông tin dự án (BẮT BUỘC đọc `docs/GOVERNANCE.md`)

- `docs/project/KANBAN.md` — bảng việc, nguồn sự thật duy nhất về trạng thái.
  Luật: CHỈ đổi trạng thái + append lịch sử, KHÔNG xóa.
- `docs/project/PLAN.md` — milestone + nơi tiếp nhận kế hoạch mới từ người sở hữu.
- Đầu session: `git fetch` rồi đọc bản trên `origin/main` trước khi cập nhật.

## Quy tắc vàng (vi phạm = dừng lại hỏi người, không tự quyết)

1. KHÔNG đụng `UltraTimeStretch` C++ FFI / `lib/ffi/` — audio realtime là vùng bảo vệ.
2. KHÔNG gộp 3 skill SM-2 (Hiểu–Nghe–Đọc) thành 1 điểm số — đang tách biệt có chủ đích.
3. KHÔNG làm mất khả năng reopen đúng vị trí nguồn (PDF page/rect, Web url/scroll,
   Audio timestamp) — xem schema Evidence mục 2.2.
4. Mọi thay đổi kiến trúc: ADR + code review, không "hội đồng AI".

## Vận hành CI / môi trường (đúc kết từ thực chiến)

- CI test module Knowledge: `.github/workflows/knowledge_tests.yml` (flutter 3.44.1,
  chỉ chạy khi chạm `lib/knowledge/**` hoặc `test/knowledge/**`).
- `flutter analyze` trong CI coi info-lint là lỗi — nhưng flutter_lints 6.0 đã giảm
  mạnh rule set; kiểm rule thật trước khi "đoán lint" (mục 3 của skill ci-red-debugging).
- Bẫy đã biết + quy trình hồi phục sandbox: mục 5 của skill ci-red-debugging.
- Commit nhỏ, push ngay — push là backup (sandbox có thể tái bản giữa phiên).

## Module mới (đang trên branch `arena/01a019bb-in4up`, chờ merge)

`lib/knowledge/` — 5 model schema MVA + merge/split hoàn tác + migrator WordEntry cũ.
Test: `test/knowledge/` (58 test xanh). Lịch sử bisect trong commit message — đọc
postmortem trong `lib/knowledge/migration/word_entry_migrator.dart` trước khi đụng
import giữa `lib/models` và `lib/knowledge`.
