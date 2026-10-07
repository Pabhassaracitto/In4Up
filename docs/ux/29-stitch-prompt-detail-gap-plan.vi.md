# I4U UX — Kế hoạch prompt detail còn thiếu

## Đã có prompt detail riêng

- `27-stitch-prompt-11-detail-understand.vi.md` — 16 states Hiểu/Chat/Coach
- `28-stitch-prompt-12-detail-memory.vi.md` — 20 states Nhớ/Ôn tập/Học thuộc
- `14-stitch-context-panel-detail-prompt.vi.md` — 11 states Contextual Tool Panel
- `17-stitch-listen-state-detail-prompt.vi.md` — 14 states Nghe/Audio Library
- `20-stitch-watch-state-detail-prompt.vi.md` — 14 states Xem trong Nghe

## Cần bổ sung nếu chuẩn bị code

### Prompt 1–5 Detail — Global Shell

Các state cần có:

- Mobile/desktop minimal;
- Sidebar collapsed/expanded;
- Quick Actions open/close;
- Command Palette results/empty/loading;
- Global Chat contextual/free/reset;
- Mini Player transition;
- panel stacking/safe-area;
- keyboard focus/escape/back.

### Prompt 6 Detail — Home

Các state cần có:

- First launch/no history;
- Continue card populated/stale;
- Needs Attention empty/populated;
- Quick Capture input/saved/cancelled;
- loading/offline;
- mobile one-column/desktop two-column.

### Prompt 7 Detail — Đọc Minimal Reader

Các state cần có:

- source empty/loading/loaded/error;
- aA typography sheet;
- selected-text action overflow;
- bookmark/save success;
- audio entry;
- mobile keyboard/context sheet;
- scroll/selection restoration.

## Quy tắc đặt tên mới

Từ bây giờ mọi prompt detail dùng format:

```text
Prompt <số> Detail — <số state>: <tên hệ thống>
```

Tên file cũng bắt buộc chứa số prompt để dễ tìm và copy.
