# I4U UX — Nguyên tắc thiết kế

> Trạng thái: bản nháp v0.1 — dùng để thảo luận, chưa phải đặc tả triển khai.
> Cập nhật: 2026-10-04

## Mục tiêu

Xây dựng một ứng dụng học ngôn ngữ mạnh nhưng không gây quá tải. Người mới có thể bắt đầu ngay; người dùng quen thuộc thao tác nhanh; người dùng chuyên gia có thể mở toàn bộ công cụ khi cần.

## Nguyên tắc đã thống nhất

1. **Workspace trước, công cụ sau**  
   Navigation cấp cao mô tả mục tiêu người dùng: Home, Nghe, Đọc, Hiểu, Nhớ. Công cụ không tự động trở thành tab chính.

2. **Progressive disclosure**  
   Mặc định chỉ hiển thị những điều cần cho nhiệm vụ hiện tại. Chức năng nâng cao phải dễ mở khi cần, nhưng không chiếm chỗ thường trực.

3. **Bốn tầng UX**  
   Mọi màn hình và tính năng được xếp vào: Global Shell → Workspace → Context Bar → Tools.

4. **Đúng ngữ cảnh**  
   Quick actions, tool panel và đề xuất phải thay đổi theo workspace, nội dung đang chọn và lịch sử sử dụng gần đây.

5. **Responsive theo hành vi, không chỉ theo kích thước**  
   Mobile, tablet và desktop có thể dùng các mô hình điều hướng khác nhau; desktop không chỉ là mobile phóng to.

6. **Thu gọn nhưng luôn có dấu hiệu mở lại**  
   Auto-hide, compact mode và panel đóng phải để lại affordance rõ ràng.

7. **Mỗi nhiệm vụ có đường dễ tìm và đường nhanh**  
   Ví dụ: tra từ bằng nút trực quan, đồng thời hỗ trợ command palette/shortcut cho người dùng chuyên gia.

8. **Không để người dùng mất trạng thái**  
   Mode, nguồn nội dung, panel và workspace gần nhất nên được giữ lại khi điều đó phù hợp và không gây bất ngờ.

9. **Accessibility là yêu cầu nền tảng**  
   Các hành động không chỉ phụ thuộc vào màu sắc, long-press hoặc hover; cần hỗ trợ touch, chuột, bàn phím, text scale và thao tác thay thế.

10. **Thiết kế trước, code sau**  
    Không bắt đầu refactor UI lớn khi bản đồ thông tin, wireframe và tiêu chí chấp nhận chưa được thống nhất.

## Quy tắc phạm vi agent sau này

- Một branch chỉ xử lý một capability.
- Tối đa 1–3 commit cho một capability.
- Không refactor ngoài phạm vi.
- Không đổi business logic nếu nhiệm vụ chỉ là shell/UI.
- Mọi quyết định mới phải được ghi vào `decision-log.vi.md`.
