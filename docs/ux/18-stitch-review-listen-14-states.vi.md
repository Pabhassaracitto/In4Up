# I4U UX — Review đặc tả 14 trạng thái Nghe

> Trạng thái: đạt interaction baseline; có thể chuyển sang Xem trong Nghe sau khi chốt vài điểm về mobile player, import và shortcut.
> Cập nhật: 2026-10-04

## Kết luận

Đặc tả 14 state đã đủ chi tiết để làm baseline cho Audio Library và Player. Nó đã bao phủ:

- empty/populated;
- select vs play;
- mini/expanded player;
- import/transcript processing;
- unavailable/error;
- pitch/IPA capability;
- A-B/shadowing;
- success/failure feedback;
- safe area và bottom navigation.

## Những điểm đạt rất tốt

1. Quy tắc Select vs Play rõ và nhất quán.
2. Continue Listening giữ vị trí primary.
3. Mini Player không xuất hiện khi idle/empty.
4. Transcript có state unavailable thay vì giả định luôn sẵn sàng.
5. Pitch/IPA có Available, Analyzing, Unsupported, Failed.
6. Import chạy nền và không làm gián đoạn phiên nghe hiện tại.
7. Expanded Player có transcript và context actions.
8. Library không biến thành dashboard analytics.
9. Empty state có ba lối vào rõ.

## Các điểm cần chốt/sửa

### 1. Chuẩn hóa khoảng cách Mini Player trên mobile

Các mô tả đang dùng cả:

- `bottom: 64px + safe-area-inset`;
- cách bottom tab `12px`;
- `bottom offset ~68px`.

Không nên chốt ba số khác nhau. Đặc tả nên dùng một công thức:

```text
bottom = bottomNavigationHeight + safeAreaInset + spacing
```

Trong đó spacing là token responsive, không hard-code theo một thiết bị.

### 2. Expanded Player 95% là modal exception

State 10 che navigation là chấp nhận được nếu đây là full-screen modal thật sự:

- có close/drag handle rõ;
- focus trap;
- back gesture/hardware back đóng modal;
- không giả vờ rằng bottom navigation vẫn đang tương tác phía dưới.

Ghi rõ đây là ngoại lệ có chủ đích, khác với Mini Player/Bottom Sheet thông thường.

### 3. Import raw audio và transcript

Nếu raw audio phát được trong lúc transcript đang xử lý, UI cần phân biệt:

```text
Audio: Ready
Transcript: Processing
```

Không dùng một trạng thái “Ready” chung khiến người dùng nghĩ cả hai đã sẵn sàng.

### 4. Import feedback không nên tự chuyển hướng

`Nghe ngay` và `Quay lại thư viện` là hai hành động tốt. Không auto-open hoặc auto-play sau khi import nếu người dùng chưa chọn.

### 5. Shortcuts chỉ hoạt động trong scope đúng

`J/K`, `A/B`, `Space`, `L`, `M` chỉ hoạt động khi player/expanded player đang focus hoặc người dùng bật keyboard mode. Không bắt shortcut khi focus ở input, transcript selection hoặc browser body.

Các shortcut `U/L` trong Empty State nên để ở backlog shortcut registry, chưa đưa vào core UX.

### 6. Expanded Player và Contextual Tool Panel

Khi chọn từ trong transcript, cần chốt dùng:

- contextual popover;
- right panel;
- hay chuyển sang Tool Panel của Đọc.

Không mở đồng thời quá nhiều surface. Context source cần được truyền rõ từ transcript sang Dictionary/Translate/Nhớ.

### 7. A-B Loop và Shadowing

Cần phân biệt:

- A-B loop: nghe lặp một đoạn;
- Shadowing: có thêm pause, repeat count và có thể record/feedback.

Không nên làm người dùng nghĩ A-B loop tự động là một bài shadowing hoàn chỉnh.

## Quyết định chuyển tiếp

Đặc tả 14 state đủ tốt để đóng vòng Nghe & Audio Library. Tiếp theo chuyển sang Prompt 10 — Xem within Nghe, giữ nguyên model: Xem là media mode, transcript là context source, và không tạo workspace cấp 1 mới.
