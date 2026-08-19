# Shell Navigation Manual QA Checklist

## Mục tiêu

Checklist này dùng để test thủ công toàn bộ lớp điều hướng mới của VipSound sau khi refactor sang mô hình:

- Home
- Nghe
- Đọc
- Hiểu
- Nhớ
- Quick Actions thay cho Tools tab
- Nghe | Nói
- Đọc | Viết
- Shell advanced settings

---

## Lưu ý trước khi test

- Ưu tiên test trên **Android mobile thật** trước.
- Sau đó test lại trên:
  - Windows/Desktop
  - Web
  - màn hình nhỏ / lớn nếu có
- Nếu muốn test phần AI local beta:
  - cần có model `.gguf` đã import
- Nếu không có model:
  - các phần local scoring / local coaching vẫn phải chạy bình thường

---

## Thiết bị / tình huống nên test

### Thiết bị tối thiểu
- 1 máy Android
- 1 máy Windows hoặc Web

### Tình huống hiển thị
- màn hình dọc
- màn hình ngang
- font hệ thống lớn hơn mặc định
- có mini player
- không có mini player
- đang có audio
- chưa có audio
- đang có text
- chưa có text

---

# 1. Smoke Test nhanh

## 1.1 App mở lên bình thường
- [ ] App vào được `Home`
- [ ] Không có sọc vàng đen / overflow ngay khi khởi động
- [ ] Bottom nav hiển thị đủ 5 tab
- [ ] App bar không vỡ layout

## 1.2 Chuyển tab chính
- [ ] Home → Nghe
- [ ] Nghe → Đọc
- [ ] Đọc → Hiểu
- [ ] Hiểu → Nhớ
- [ ] Nhớ → Home
- [ ] Không bị lag bất thường / mất state ngoài ý muốn

## 1.3 Quick Actions
- [ ] Nút quick actions ở app bar mở được overlay
- [ ] Đóng overlay bình thường
- [ ] Chọn action điều hướng đúng màn hình

---

# 2. Bottom Navigation

## 2.1 Tap tab chính
### Home
- [ ] Tap `Home` vào đúng Home

### Nghe
- [ ] Tap `Nghe` vào mode `Nghe` hoặc submode gần nhất nếu bật remember mode

### Đọc
- [ ] Tap `Đọc` vào mode `Đọc` hoặc submode gần nhất nếu bật remember mode

### Hiểu
- [ ] Tap `Hiểu` vào workspace Hiểu

### Nhớ
- [ ] Tap `Nhớ` vào workspace Nhớ
- [ ] Badge due review hiển thị đúng khi có dữ liệu

## 2.2 Long-press tab chính
> Chỉ test khi bật setting long-press

- [ ] Long-press `Nghe` chuyển sang `Nói`
- [ ] Long-press `Đọc` chuyển sang `Viết`
- [ ] Long-press không làm app đứng / mở nhầm màn hình
- [ ] Nếu đang ở `Nói`, tap lại `Nghe` vẫn quay đúng logic mong muốn
- [ ] Nếu đang ở `Viết`, tap lại `Đọc` vẫn quay đúng logic mong muốn

## 2.3 Visual state
- [ ] Tab đang chọn có màu/indicator đúng
- [ ] Label không bị cắt chữ
- [ ] Badge của tab Nhớ không đè icon/label

---

# 3. Mode Switch: Nghe | Nói / Đọc | Viết

## 3.1 Mặc định khi chưa bật compact/auto-hide
- [ ] Vào `Nghe` thấy rõ `Nghe | Nói`
- [ ] Vào `Đọc` thấy rõ `Đọc | Viết`
- [ ] Tap qua lại giữa 2 mode hoạt động đúng
- [ ] Không overflow khi có mini player

## 3.2 Compact Mode
Bật trong `Tùy chỉnh giao diện shell`

- [ ] Khi bật compact mode, thanh mode switch không luôn hiển thị
- [ ] Chip mode dưới tiêu đề hiển thị đúng mode hiện tại
- [ ] Tap chip mode mở lại thanh switch
- [ ] Tap lại chip mode ẩn thanh switch
- [ ] Chuyển tab khác rồi quay lại vẫn đúng behavior

## 3.3 Auto-hide Mode Switch
Bật trong `Tùy chỉnh giao diện shell`

- [ ] Vào tab có submode, switch hiện lúc đầu
- [ ] Sau vài giây switch tự ẩn
- [ ] Tap chip mode mở lại switch
- [ ] Không bị nhấp nháy / rung layout quá khó chịu

## 3.4 Remember Last Submode
- [ ] Bật `Nhớ mode phụ gần nhất`
- [ ] Vào `Nghe`, chuyển sang `Nói`
- [ ] Đi sang tab khác rồi quay lại `Nghe`
- [ ] App nhớ `Nói`
- [ ] Làm tương tự với `Đọc → Viết`

- [ ] Tắt `Nhớ mode phụ gần nhất`
- [ ] Quay lại `Nghe` từ tab khác
- [ ] App trở về `Nghe`
- [ ] Quay lại `Đọc` từ tab khác
- [ ] App trở về `Đọc`

---

# 4. Shell UI Settings

Mở bằng:
- quick action `Giao diện shell`

## 4.1 Màn hình mở đúng
- [ ] Vào được screen `Tùy chỉnh giao diện shell`
- [ ] Các toggle hiển thị đầy đủ
- [ ] Không bị overflow khi cuộn

## 4.2 Persist setting
Thực hiện cho từng toggle:
- [ ] bật
- [ ] thoát màn hình
- [ ] quay lại kiểm tra còn giữ
- [ ] thoát app mở lại kiểm tra còn giữ

Áp dụng cho:
- [ ] Compact mode
- [ ] Auto-hide switch mode
- [ ] Long-press tab chính để vào mode phụ
- [ ] Nhớ mode phụ gần nhất

---

# 5. Quick Actions Adaptive Ranking

## 5.1 Ranking theo ngữ cảnh tab
### Trong tab Nghe
- [ ] Các action liên quan `Nói`, `YouTube`, `YouGlish`, `Hiểu` ở nhóm ưu tiên cao

### Trong tab Đọc
- [ ] Các action liên quan `Viết`, `Web Reader`, `PDF Reader` ưu tiên cao

### Trong tab Nhớ
- [ ] `Review`, `Word List`, `Timeline`, `Stats` ưu tiên cao

## 5.2 Ranking theo usage
- [ ] Mở quick action và chọn một tool nhiều lần, ví dụ `YouGlish`
- [ ] Mở lại overlay
- [ ] `YouGlish` được đẩy lên cao hơn trước

## 5.3 Ranking theo recency
- [ ] Dùng một action mới gần đây
- [ ] Mở lại overlay
- [ ] Action vừa dùng có xu hướng ở gần top hơn

## 5.4 Regression
- [ ] Quick actions vẫn mở đúng màn hình
- [ ] Không bị trùng item
- [ ] Không crash khi usage stats chưa có dữ liệu

---

# 6. Home Command Center

- [ ] Home mở bình thường
- [ ] Các card điều phối hoạt động đúng
- [ ] Card Nghe đưa vào đúng khu vực Nghe
- [ ] Card Đọc đưa vào đúng khu vực Đọc
- [ ] Card Hiểu đưa vào đúng khu vực Hiểu
- [ ] Card Nhớ đưa vào đúng khu vực Nhớ
- [ ] Không bị chồng mini player / FAB / nội dung

---

# 7. Tab Nghe / Nói

## 7.1 Nghe
- [ ] Listen mode vẫn mở bình thường
- [ ] Không vỡ layout khi có waveform
- [ ] Mini player hoạt động đúng

## 7.2 Nói
- [ ] Speak mode mở được
- [ ] Preset hệ thống áp dụng đúng
- [ ] Preset cá nhân lưu được
- [ ] Preset cá nhân khôi phục được sau restart app
- [ ] History hiển thị đúng
- [ ] Mở chi tiết từng phiên được
- [ ] Copy phản hồi hoạt động

---

# 8. Tab Đọc / Viết

## 8.1 Đọc
- [ ] Read mode mở bình thường
- [ ] Không overflow với text dài

## 8.2 Viết
- [ ] Mở được `Viết`
- [ ] Chép chính tả chấm được
- [ ] Điền từ chấm được
- [ ] Chọn đáp án chấm được
- [ ] Viết lại ý chấm local được
- [ ] Tóm tắt ngắn chấm local được
- [ ] Nếu có model AI, các nút AI beta hoạt động đúng

---

# 9. Tab Hiểu / Nhớ

## 9.1 Hiểu
- [ ] Workspace Hiểu hiển thị đúng
- [ ] Chip shortcut sang `Nói` / `YouGlish` / `Ôn tập` hoạt động

## 9.2 Nhớ
- [ ] Workspace Nhớ hiển thị đúng
- [ ] Badge due review khớp dữ liệu
- [ ] Shortcut sang review / word list / timeline / stats hoạt động

---

# 10. Drawer / Mini Player / Overlay

## 10.1 Drawer
- [ ] Tab phù hợp mở text drawer đúng
- [ ] Audio drawer mở đúng
- [ ] Không bị gesture conflict bất thường

## 10.2 Mini Player
- [ ] Có audio thì mini player hiện đúng chỗ
- [ ] Không đè mode switch quá xấu
- [ ] Tap mini player quay đúng logic mong muốn

## 10.3 Overlay
- [ ] Quick actions overlay đóng/mở mượt
- [ ] Back button / tap backdrop đóng đúng

---

# 11. Overflow / Responsiveness

## 11.1 Mobile nhỏ
- [ ] Bottom nav không tràn
- [ ] App bar không tràn
- [ ] Chip mode không tràn
- [ ] Settings shell không tràn

## 11.2 Font lớn hệ thống
- [ ] Label tab không vỡ nặng
- [ ] App bar vẫn dùng được
- [ ] SwitchListTile trong settings không vỡ nghiêm trọng

## 11.3 Landscape / Desktop / Web
- [ ] Layout shell vẫn ổn
- [ ] Không có RenderFlex overflow rõ ràng
- [ ] Long-press/tap behavior vẫn nhất quán chấp nhận được

---

# 12. Persistence / Restart

Đóng app hoàn toàn rồi mở lại:
- [ ] Shell settings còn giữ
- [ ] Preset nói còn giữ
- [ ] History nói còn giữ
- [ ] Quick action ranking vẫn có dấu hiệu nhớ usage gần đây
- [ ] Nếu bật remember last submode, app khôi phục đúng submode

---

# 13. Bug Report Template

Khi gặp lỗi, ghi theo mẫu:

- Thiết bị / nền tảng:
- Màn hình / mode đang đứng:
- Setting shell đang bật:
- Bước tái hiện:
- Kết quả mong đợi:
- Kết quả thực tế:
- Có overflow / crash / lag không:
- Có ảnh chụp / screen recording không:

---

# 14. Ghi chú kỹ thuật hiện tại

- Shell mới đã hỗ trợ:
  - compact mode
  - auto-hide mode switch
  - long-press tab chính
  - remember last submode
  - adaptive quick actions
- Một số phần AI local vẫn mang tính beta và cần test riêng nếu có model.
- Trong môi trường agent hiện tại không chạy được `flutter analyze` / build thật, nên checklist này đặc biệt quan trọng để xác nhận runtime trên máy của bạn.
