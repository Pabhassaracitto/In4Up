# I4U UX — Review tổng hợp Global Shell, Home và Đọc detail

> Trạng thái: coverage detail đầy đủ; còn một số blocker nhỏ cần chốt trước UX Freeze.
> Cập nhật: 2026-10-04

## Kết luận

Ba hệ thống đã có đủ state detail:

- Global Shell: 18 states.
- Home: 14 states.
- Đọc Minimal Reader: 16 states.

Có thể coi đây là **interaction baseline hoàn chỉnh**, nhưng chưa nên gọi là UX Freeze tuyệt đối trước khi chốt 8 điểm dưới đây.

## Blocker 1 — Shortcut registry

Không nên gọi các shortcut sau là “không xung đột” khi chưa kiểm thử platform:

- `Cmd/Ctrl+1..5` có thể chuyển browser tab.
- `Cmd/Ctrl+[` có thể Back.
- `Cmd/Ctrl+K` có behavior riêng trên một số browser.
- `Alt+B`, `Alt+C`, `Alt+S`, `Alt+N` phụ thuộc layout bàn phím/accessibility.
- `Cmd/Ctrl+O` có thể mở file dialog của browser/OS.

Chốt trước mắt:

- Click/tap luôn là đường chính.
- Shortcut chỉ hoạt động trong đúng focus scope.
- Có thể tắt/đổi shortcut trong Settings.
- Không hiển thị shortcut trong UI như một cam kết cho đến khi registry được kiểm thử.

## Blocker 2 — Layer policy mobile

Không dùng mặc định ba lớp nổi cùng lúc:

```text
Bottom Navigation + Quick Actions + Mini Player
```

Khuyến nghị:

- Quick Actions mở: Mini Player thu gọn hoặc tích hợp vào sheet.
- Sheet lớn/Chat: Mini Player ẩn foreground, audio vẫn phát.
- Expanded Player: full-screen modal exception.

Không dùng `translateY(-118px)` như contract UX cứng.

## Blocker 3 — Panel split desktop

Context Panel + Global Chat nên dùng Replace làm baseline. Split chỉ là advanced option khi đủ width và không làm Reader hẹp. Không nên gọi “không bao giờ dual panel” rồi đồng thời đặc tả pinned split như behavior ngang hàng.

## Blocker 4 — Back stack

Nấc cuối không luôn là Home. Cần tôn trọng router/deep-link/history:

- đóng overlay;
- đóng panel;
- về source return nếu có;
- về route trước;
- Home chỉ là fallback khi không còn history.

Nếu có draft/session chưa lưu, cần xác nhận hoặc autosave trước khi thoát.

## Blocker 5 — Offline conflict

Home và Nhớ không nên ghi “tự động hợp nhất” mọi dữ liệu. Cần phân biệt:

- event có thể merge;
- note có conflict;
- delete vs edit;
- review progress trên hai thiết bị.

Phải có conflict resolution khi không thể merge an toàn.

## Blocker 6 — Focus Rhythm

Đổi `18 ngày liên tiếp` thành một chỉ số không mang nghĩa streak:

```text
18 ngày có hoạt động trong 30 ngày qua
```

hoặc `Nhịp học gần đây`. Cho phép ẩn khỏi Home.

## Blocker 7 — Reader dynamic measurement

Không dùng cứng `76px`, `68px`, `110px`, `65%` làm implementation contract. Dùng token + safe-area + viewInsets + available height. Chiều rộng Reader dùng available width/max width, không khóa 340px.

## Blocker 8 — Reader preservation semantics

Không cam kết “từng pixel” trong mọi thay đổi font/viewport. Dùng semantic anchor:

```text
sourceId + blockId/paragraphId + characterOffset + visual offset
```

Sau layout/font change, khôi phục paragraph/character anchor gần vị trí cũ; pixel offset chỉ là mục tiêu trong cùng viewport.

## Acceptance criteria trước UX Freeze

- Có shortcut registry hoặc tạm ẩn shortcut hints.
- Có layer policy mobile thống nhất.
- Có baseline Replace cho panel/chat.
- Có router/back policy.
- Có offline conflict policy.
- Đổi Focus Rhythm khỏi streak wording.
- Có safe-area/viewInsets token policy.
- Có semantic reading anchor policy.
