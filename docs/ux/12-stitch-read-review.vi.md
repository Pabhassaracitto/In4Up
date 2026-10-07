# I4U UX — Review Đọc Minimal Reader

> Trạng thái: đạt baseline để chuyển sang Contextual Tool Panel; cần kiểm tra kích thước chữ, selection và mobile safe area bằng prototype.
> Cập nhật: 2026-10-04

## Đánh giá tổng quan

Kết quả Prompt 7 phù hợp rất tốt với nguyên tắc Content as Sovereign:

- Context Bar giữ đủ Đọc/Viết và nguồn nội dung nhưng không lấn át văn bản.
- Tool panel đóng mặc định.
- Reader có typography, max-width và line-height rõ ràng.
- Progress nhẹ, không biến thành dashboard.
- Vocabulary anchors có thể khám phá nhưng không giống nút nặng.
- Selected-text actions kết nối trực tiếp với Translate, Explain, Dictionary, Pronunciation và Nhớ.
- Desktop và mobile có behavior khác nhau đúng hướng.
- Negative constraints đã được tuân thủ.

## Những điểm nên giữ

1. Nội dung chính là vùng có hierarchy cao nhất.
2. Contextual Tool Panel đóng mặc định.
3. Contextual action ưu tiên xuất hiện sau selection, không luôn chiếm chỗ.
4. Reader không có stats/badge/AI summary mặc định.
5. “Thêm vào Nhớ” được dùng thay cho nhãn phụ thuộc sản phẩm ngoài.
6. Mobile giữ bottom navigation không bị player hoặc sheet che.

## Điểm cần kiểm chứng/chỉnh sửa

### 1. Chiều rộng 340px trên mobile

340px có thể phù hợp với một số màn hình, nhưng không nên hard-code. Reader cần dùng chiều rộng khả dụng sau safe area và padding. Trên thiết bị hẹp, 340px có thể làm dòng quá ngắn; trên thiết bị rộng, có thể còn chỗ thừa.

Khuyến nghị: dùng max-width và padding responsive, không dùng width cố định.

### 2. Line-height 1.8

1.8 là điểm khởi đầu tốt cho văn bản học thuật, nhưng nên để người dùng điều chỉnh trong aA. Cần kiểm tra khi text scale lớn, ngôn ngữ có chữ dài, CJK và tiếng Việt.

### 3. Floating selection action bar

Năm action trên mobile có nguy cơ quá rộng hoặc bị che khi vùng chọn gần mép màn hình. Khuyến nghị:

- Desktop: có thể hiển thị 5 action.
- Mobile: hiển thị 3 action ưu tiên và nút “Thêm” cho phần còn lại, hoặc cho phép cuộn ngang.
- Luôn có fallback bottom sheet nếu không đặt được thanh nổi.

### 4. Xung đột giữa selection bar và Context Sheet

Cần chốt rằng selected-text action bar là lớp đầu tiên, còn Context Tool Panel/Bottom Sheet là lớp thứ hai. Không mở đồng thời hai surface nặng.

### 5. Audio shortcut

“Truy cập nhanh âm thanh” hợp lý, nhưng nên xác định nó mở mini player, phát câu đã chọn hay mở audio panel. Một nút không nên có ba behavior khác nhau.

### 6. Back và navigation

Trong Reader cần phân biệt:

- Back về nguồn/danh sách trước.
- Đổi workspace bằng shell.
- Đóng tool panel/sheet.
- Giữ vị trí đọc khi quay lại.

### 7. Text selection trên nền tảng

Cần kiểm chứng khác biệt giữa native text selection trên mobile/web/desktop. Action bar không nên phá copy/select mặc định và cần có behavior khi người dùng chọn nhiều dòng.

## Quyết định chuyển giai đoạn

Đọc Minimal Reader đã đủ tốt để chuyển sang Prompt 8 — Đọc Contextual Tool Panel. Khi thiết kế Prompt 8, phải giữ nguyên Reader minimal và chỉ mở panel khi người dùng chủ động yêu cầu.
