# I4U UX — Review Pre-Freeze Architecture Contract

> Trạng thái: 7 resolution đã đạt; còn 5 technical clarifications nên ghi vào contract trước UX Freeze.
> Cập nhật: 2026-10-04

## Kết luận

Bản chuẩn hóa đã đóng đúng các blocker lớn:

- Shortcut governance.
- Mobile layer stacking.
- Context Panel vs Global Chat.
- Hierarchical back.
- Offline conflict.
- Calm Focus Rhythm.
- Semantic reading anchor.

Có thể tiến tới UX Freeze sau khi bổ sung các điều kiện kỹ thuật dưới đây. Không cần thêm mockup lớn.

## Technical clarifications

### 1. Shortcut Registry cần schema và precedence

Cần lưu rõ:

```text
id, platform, keyChord, scope, enabled, userOverride, fallbackAction
```

Khi xung đột, thứ tự ưu tiên là:

```text
OS/browser/native input
→ focused input/contenteditable
→ active modal/panel
→ workspace shortcut
→ global shortcut
```

`Esc`, arrow keys và Enter trong Command Palette là ngoại lệ của active modal scope.

### 2. Mobile layer policy cần có state machine

Không chỉ mô tả ẩn/hiện. Cần quy định chuyển đổi:

```text
idle → miniPlaying
miniPlaying + peekOpen → miniCollapsed/integrated
miniPlaying + largeSheet → miniBackground
largeSheetClosed → restore previous mini state
expandedPlayer → fullScreenModal
```

Audio playback state không được bị thay đổi khi visual layer đổi.

### 3. Offline SRS merge không nên mặc định gọi là CRDT

Append-only event log và idempotent event IDs là nền tảng tốt. Nhưng việc tính lịch SRS vẫn cần deterministic merge rule. Contract nên ghi:

- event ID duy nhất;
- device ID và logical timestamp;
- deduplication;
- deterministic ordering;
- replayable scheduler;
- conflict audit.

Chỉ gọi là CRDT nếu implementation thực sự thỏa mô hình CRDT đã chọn.

### 4. Reading position không nên luôn ưu tiên “mốc xa nhất”

Thiết bị có thể có position xa hơn do người dùng lướt nhanh, không phải đã học đến đó. Nên ưu tiên:

1. last explicit resume position;
2. position có timestamp gần nhất và source revision phù hợp;
3. user chọn khi conflict;
4. fallback xa nhất chỉ khi có policy rõ.

### 5. Semantic anchor cần version/fallback

Nên bổ sung:

```json
{
  "source_id": "...",
  "source_revision": "...",
  "block_id": "para_014",
  "character_offset": 128,
  "selected_term": "tri giác",
  "locale": "vi",
  "viewport_relative_ratio": 0.35,
  "created_at": "..."
}
```

Fallback khi source revision đổi:

```text
block_id → text fingerprint → nearby text search → page/position → source unavailable
```

Không được highlight nếu match không đủ tin cậy.

### 6. Vertical Split cần accessibility contract

Split ≥1440px là hợp lý như advanced option, nhưng cần:

- divider/resize rõ;
- close riêng từng pane;
- keyboard navigation;
- screen reader labels;
- không mở mặc định;
- minimum content width;
- fallback Replace khi viewport giảm.

## Quyết định

Bản contract đạt mức UX Freeze candidate. Sau khi ghi 6 clarification trên, có thể chuyển sang Production Readiness và component/capability breakdown.
