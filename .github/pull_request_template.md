## Card / mục tiêu

- Card Kanban: `<!-- ví dụ BATCH-0915 / PDF-JUMP-001 -->`
- Phạm vi PR (một nhóm chức năng khép kín):
- Agent / branch:
- Base đã cập nhật từ `arena/01a0251e-in4up` lúc:

## Commit map

> Giữ các commit logic riêng biệt. Không squash để biến nhiều phần thay đổi
> thành một commit khó kiểm toán; không đưa `WIP`, `fixup!`, merge branch hoặc
> thay đổi ngoài phạm vi vào PR.

- `commit`: test / reproduction:
- `commit`: implementation:
- `commit`: i18n / docs / Kanban checkpoint (nếu có):
- [ ] Mỗi commit đã được kiểm tra không có lỗi đã biết; nếu regression test
      chỉ có thể đỏ trước khi sửa, test và fix nằm trong cùng một commit xanh.
- [ ] Không có generated files, `.dart_tool/`, `build/`, log, IDE settings,
      format toàn repo hoặc file ngoài ownership matrix.
- [ ] PR này **không yêu cầu squash**. Nếu repository bắt buộc squash, dừng
      và báo owner thay vì tự squash.

## Audit nghiệm thu bắt buộc

### Code / phạm vi

- [ ] Đã đọc `AGENTS.md` và `docs/GOVERNANCE.md`.
- [ ] Đã đọc card trong `docs/project/KANBAN.md` và tài liệu handoff/PLAN liên quan.
- [ ] Repro trước fix được ghi lại (thiết bị, build, bước thao tác, log/assertion).
- [ ] Fix tối thiểu, không đổi kiến trúc ngoài card; vùng bảo vệ FFI không bị chạm.
- [ ] `git diff --check` sạch; `git diff --name-only` chỉ gồm file thuộc card.
- [ ] Quy tắc locale #5 được kiểm tra; key UI mới có English fallback và đủ
      `hi` / `zh` / `zh_TW` / `si` khi thuộc T2.

### Test / CI

- [ ] Test regression/unit/widget liên quan đã thêm hoặc đã nêu rõ lý do không thể thêm.
- [ ] `flutter analyze --no-fatal-infos --no-fatal-warnings` xanh (hoặc CI artifact tương đương).
- [ ] Test liên quan chạy xanh; ghi lệnh và kết quả:
- [ ] `App Analyze + Locale Test` xanh — run URL / run ID:
- [ ] Nếu sửa `packages/**`, workflow đã thực sự chạy theo path filter; không coi
      một PR không trigger workflow là bằng chứng xanh.

### Nghiệm thu chức năng

- [ ] AT happy path:
- [ ] AT lỗi / timeout / model thiếu / lifecycle:
- [ ] AT hồi quy sau thao tác lặp lại (số lần):
- [ ] Android debug/release hoặc nền tảng liên quan đã kiểm tra; thiết bị / build:
- [ ] Nếu còn chờ owner nghiệm thu thiết bị, PR ghi rõ `chờ nghiệm thu máy`,
      không chuyển card sang `done` giả.

### Kanban / bàn giao

- [ ] Đã append lịch sử card theo format governance, không xóa lịch sử.
- [ ] KANBAN chỉ ghi trạng thái tương ứng với bằng chứng thực tế (commit/run/PR).
- [ ] PR body có link log, screenshot/logcat hoặc video cho lỗi UI/runtime nếu có.
- [ ] Không cherry-pick lại commit đã có trên base; không sửa workflow chỉ để né lỗi.

## Tóm tắt cho owner

- Đã sửa:
- Chưa sửa / ngoài phạm vi:
- Rủi ro còn lại:
- Cách owner kiểm tra nhanh:
