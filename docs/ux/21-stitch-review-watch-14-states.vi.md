# I4U UX — Review đặc tả 14 state Chế độ Xem

> Trạng thái: đạt interaction baseline; cần chỉnh một số implementation-neutral constraints trước khi code.
> Cập nhật: 2026-10-04

## Kết luận

Đặc tả đã giải quyết đúng các câu hỏi của Prompt detail:

- Không có 3 cột đồng cấp mặc định.
- Subtitle có 4 mode.
- Transcript manual scroll có resume.
- Selected subtitle có 3 action + More trên mobile.
- Shadowing có 6 sub-state.
- Handoff sang Hiểu có context fingerprint và return path.
- Mobile có reduced video.

Có thể đóng vòng UX của Xem sau khi sửa các điểm bên dưới.

## Những điểm cần giữ

1. Video + Transcript là trục 2 vùng mặc định trên desktop.
2. Lexicon Inspector là overlay/hoán đổi, không tạo cột thứ ba.
3. Original Only là default hợp lý cho immersion, nhưng mode phải nhớ được theo user preference.
4. Manual scroll dừng auto-scroll và có `Theo lại câu đang phát`.
5. Handoff sang Hiểu là explicit, có cancel và return path.
6. Shadowing phải hỏi quyền micro và có failed/noisy state.
7. Mobile actions dùng 3 priority + More.

## Các điểm cần chỉnh

### 1. PiP native và In-app Mini Video

Không phải mọi web/mobile platform đều hỗ trợ native Picture-in-Picture theo cùng cách. Đặc tả nên phân biệt:

- In-app reduced video: luôn có thể thiết kế trong app.
- Native PiP: capability tùy platform/quyền người dùng.

Nếu native PiP không hỗ trợ, fallback về in-app floating mini video.

### 2. Safe-area formula phải thống nhất

Các phần dùng `64px`, `72px` và `bottom: 72px + safe-area`. Chốt một token/công thức dùng chung, không hard-code theo thiết bị:

```text
bottom = bottomNavigationHeight + safeAreaInset + spacingToken
```

### 3. Video selection và auto-pause

Khi bôi đen subtitle, video tạm dừng là hợp lý. Nhưng sau khi đóng action menu không nên tự phát lại ngoài ý muốn. Cần hiển thị rõ trạng thái paused và để người dùng bấm Play/Space tiếp tục.

### 4. Shortcut registry

`C`, `J/K`, `A/B`, `Space`, `↑/↓` chỉ hoạt động trong scope player/transcript khi focus phù hợp. Không bắt chúng trong input, search, text selection hoặc browser body.

### 5. Không nên dùng điểm số 92% như sự thật tuyệt đối

Shadowing score nên có:

- confidence/quality indicator;
- yếu tố góp phần: timing, pronunciation, pitch;
- feedback hành động được;
- fallback khi audio noisy.

Không nên tạo cảm giác một con số đơn lẻ đánh giá chính xác năng lực phát âm.

### 6. Ngôn ngữ handoff

`Khảo đàm` hơi hàn lâm và có thể không rõ với người dùng phổ thông. Nên dùng:

- `Mở trong Hiểu`
- `Phân tích trong Hiểu`
- `Hỏi AI về đoạn này`

### 7. Long-press và text selection

Cần có fallback cho người dùng không dùng được long-press: chọn text native, nút contextual khi tap câu, hoặc menu `Thêm`. Không để long-press là con đường duy nhất.

### 8. Subtitle mode và lưu preference

Khi user chọn subtitle mode, nên ghi nhớ theo user/source/language nhưng vẫn có reset rõ ràng. Không tự bật translation on-demand khi user đã chọn Original Only.

## Quyết định chuyển tiếp

Đặc tả 14 state đủ để đóng vòng Xem. Bước tiếp theo là Prompt 11 — Hiểu với Chat và Coach. Khi triển khai sau này, giữ context fingerprint:

```text
sourceId + videoId + timestamp + selectedText + subtitleLanguage + returnPath
```
