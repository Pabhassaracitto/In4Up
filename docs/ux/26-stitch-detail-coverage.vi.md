# I4U UX — Ma trận coverage prompt và state detail

> Mục đích: tránh tuyên bố đã có prompt chi tiết khi file chưa tồn tại.

| Nhóm | Architecture prompt | State/detail prompt | Trạng thái |
|---|---|---|---|
| Global Shell | Prompt 1–5 | Chưa có file riêng cho toàn bộ shell states | Cần bổ sung nếu chuẩn bị code shell |
| Home | Prompt 6 | Chưa có file riêng | Có thể bổ sung trước khi code Home |
| Đọc Minimal Reader | Prompt 7 | Có review, chưa có state prompt riêng | Đủ baseline; nên detail selection/aA/source states trước code |
| Contextual Tool Panel | Prompt 8 | Prompt bổ sung + 11 states | Đã có |
| Nghe/Audio Library | Prompt 9 | Prompt state 14 states | Đã có |
| Xem trong Nghe | Prompt 10 | Prompt state 14 states | Đã có |
| Hiểu/AI Coach | Prompt 11 | `24-stitch-understand-state-detail-prompt.vi.md` | Đã có |
| Nhớ/Học thuộc | Prompt 12 | `25-stitch-memory-state-detail-prompt.vi.md` | Đã có |

## Các nhóm còn thiếu detail prompt riêng

### Global Shell

Cần tạo nếu sắp code shell:

- mobile/desktop minimal, expanded, collapsed;
- Quick Actions open/close;
- Command Palette results/empty/loading;
- Chat contextual/free/reset;
- Mini Player state transitions;
- panel stacking and safe-area.

### Home

Cần tạo nếu sắp code Home:

- no history/first launch;
- continue card populated/stale;
- needs attention empty/populated;
- quick capture input/saved/cancelled;
- offline/loading;
- mobile scroll and desktop two-column responsive.

### Đọc Minimal Reader

Cần tạo nếu sắp code Đọc:

- source empty/loading/loaded/error;
- text settings aA open;
- selection action bar overflow;
- bookmark/save success;
- audio entry;
- mobile keyboard/context sheet interaction.

## Nguyên tắc

Không cần đặc tả mọi animation trước khi code. Nhưng bất kỳ state nào ảnh hưởng đến navigation, data preservation, keyboard, safe-area, loading/error hoặc destructive action phải có state contract trước khi giao agent.
