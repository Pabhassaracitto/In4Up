# I4U UX — Quy tắc merge và rebase

> Trạng thái: chính sách dự kiến cho giai đoạn bắt đầu code.

## Branch

Session hiện tại tiếp tục làm việc trên branch cố định:

```text
arena/01a10675-in4up
```

Các agent phụ sẽ được giao branch capability riêng theo quy ước đã thống nhất, không thay đổi branch session chính.

## Quy tắc thay đổi

1. Một branch = một capability.
2. Không trộn nhiều workspace không liên quan trong cùng branch.
3. Tối đa 1–3 commit cho một capability.
4. Commit nhỏ, mô tả rõ, dễ cherry-pick.
5. Không squash hoặc rebase branch khác nếu chưa được yêu cầu.
6. Trước khi bàn giao phải báo cáo file đã sửa, test đã chạy và known issues.
7. Nếu phát sinh phạm vi mới, dừng và cập nhật nhiệm vụ thay vì tự mở rộng.

## Commit format đề xuất

```text
feat(shell): add adaptive desktop navigation
fix(reader): preserve contextual panel state
 test(shell): cover compact navigation behavior
```

## Definition of Done

- Đúng phạm vi nhiệm vụ.
- Không làm hỏng behavior hiện có ngoài phạm vi.
- Có test phù hợp hoặc ghi rõ lý do chưa có test.
- Có kiểm tra responsive nếu thay đổi UI.
- Có ảnh/video hoặc mô tả manual QA khi cần.
- Branch sạch, commit history ngắn và dễ review.
