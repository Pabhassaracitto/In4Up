# ADR-0032 — Tài nguyên MDD theo lô có giới hạn

- Bối cảnh: ADR-0029–0031, PR #192 đã merge vào 251e `4b022c1`; mỗi tài nguyên
  trước đây phải mở và lập lại index của từng part, không phù hợp nhiều ảnh.
- Quyết định: thêm tác vụ worker tra tối đa bốn key, giới hạn byte mỗi mục và
  tổng 8 MiB, giữ thứ tự/ưu tiên part và lỗi nguồn. Một MDD chỉ được mở/index
  một lần **trong tác vụ**, rồi đóng; các key trùng được khử trùng khi đọc.
  Không giữ index/handle giữa các tác vụ: tránh tái sử dụng index sau relink,
  đổi file hoặc mất quyền SAF; đây là tối ưu theo lô, không phải persistent cache.
  Cơ chế huỷ, giới hạn worker và nguồn ở isolate gốc giữ như ADR-0031.
- Giới hạn: nếu một tài nguyên vượt trần, toàn bộ lô báo lỗi; chưa đo bộ thật,
  chưa hỗ trợ mọi biến thể MDD, chưa cache liên tác vụ; cần đo cold/warm, RAM,
  jank và SAF thật trước khi chọn cache lâu dài.
