# ADR-0033 — Ảnh MDD thử nghiệm trong nội dung theo bộ

- Bối cảnh: ADR-0028–0032, owner muốn hiển thị gần nguồn hơn nhưng MDD có thể
  1,22 GB và HTML/tài nguyên đều không đáng tin; giữ SQLite và renderer text.
- Quyết định: dưới mỗi bộ, chỉ khi người dùng bấm nút mới tra tối đa bốn ảnh
  `img src` tương đối .png/.jpg/.jpeg trong MDD của đúng bộ. Ảnh hiện sau văn
  bản, không inline; không tải network, không mở file theo HTML, không JS/SVG,
  GIF hay APNG. Tác vụ tra theo lô dùng worker ADR-0032, tối đa 2 MiB/ảnh và
  8 MiB/lô. Kiểm tra header PNG/JPEG, ảnh tĩnh, cạnh ≤2048 và ≤2.097.152 pixel
  trước khi gọi codec; giải mã thu nhỏ chiều ngang tối đa 720, không upscale.
  Codec có thể từ chối dữ liệu hỏng, và kiểm tra header không phải sandbox codec.
- Vòng đời: đóng widget/đổi mục hoặc nguồn → huỷ tác vụ, bỏ kết quả cũ, evict
  ảnh khỏi image cache; thông báo phiên bản nguồn khi reimport/relink/xoá hoặc
  refresh mất quyền. Không theo dõi thay đổi file ngoài app; bấm tải lại để đọc
  mới. MDD thiếu hoặc sai định dạng hiện thông báo, không ảnh hưởng SQLite.
- Chưa hỗ trợ CSS, âm thanh, asset rời, inline fidelity, MDD LZO/engine khác;
  chưa có cache index liên tác vụ. Web không bật UI ảnh vì worker runtime chưa
  được kiểm chứng. Test synthetic/mock + widget không thay thế QA LAAD3 1,22 GB,
  memory/jank, tính hợp lệ đa biến thể, SAF/revocation và giải mã ảnh máy thật.
  Không tự sửa, xóa nguồn hay mở network.
