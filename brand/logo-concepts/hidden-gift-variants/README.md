# In4Up — Hidden Gift variants

Vòng phát triển này đi sâu vào phương án **04 · Hidden Gift**, dựa trên phát hiện:

```text
In4Up  →  I4U  →  I For You
```

Hai ký tự `n` và `p` vẫn hiện diện để tên **In4Up** đọc được đầy đủ, nhưng được giảm tương phản để `I + 4 + U` nổi lên như một lớp nghĩa ẩn.

## Các biến thể

| Mã | Tên | Cá tính | Nên dùng |
|---|---|---|---|
| `00` | **Orbit Reveal** | Chuyển động, kể chuyện | Splash screen, motion logo, video thương hiệu |
| `04A` | **Quiet Reveal** | Tĩnh, rõ, tối giản | **Logo chính, launcher icon, favicon** |
| `04B` | **Mirror Bloom** | Đối xứng, khai mở | Nội dung Pháp học, biểu tượng phụ, cộng đồng |
| `04C` | **Service Seal** | Ấm, cao cấp, tin cậy | Nền sáng, desktop, ấn phẩm, nội dung premium |
| `04D` | **Resonant Gift** | Âm thanh, năng động | Player, podcast, waveform, Pháp thoại |
| `04E` | **One Stroke** | Nhân văn, gần gũi | Học tập, cộng đồng, nội dung đồng hành |

## Khuyến nghị

### `04A · Quiet Reveal` là bản phù hợp nhất để tiếp tục tinh chỉnh

So với bản gốc, 04A:

- Bỏ hai đầu mũi tên vòng để giảm nhiễu thị giác.
- Tăng độ rõ của toàn bộ tên ở 32–48 px.
- Vẫn giữ được khoảnh khắc nhận ra `I4U`.
- Không nghiêng quá mạnh về riêng audio, Pháp học hay EdTech.

Tuy nhiên, không cần buộc hệ thương hiệu chỉ dùng một biểu tượng. Có thể xây một **logo family**:

- `04A`: master icon tĩnh.
- `00`: motion logo; `n` và `p` mờ dần để lộ `I4U`.
- `04B`: không gian Pháp học/chuyển hóa.
- `04D`: trải nghiệm nghe và audio player.
- `04C`: phiên bản nền sáng/cao cấp.

## Tệp

Mỗi biến thể có:

- SVG vector chỉnh sửa được.
- PNG 1024 × 1024.

Bảng tổng hợp:

- [`hidden-gift-variants-board.png`](./hidden-gift-variants-board.png)
- [`hidden-gift-variants-board.svg`](./hidden-gift-variants-board.svg)

Gallery responsive và kiểm tra kích thước nhỏ:

- [`index.html`](./index.html)

## Bước tiếp theo sau khi chọn

1. Chọn một master icon — khuyến nghị 04A.
2. Tinh chỉnh khoảng âm giữa `I / n / 4 / U / p` theo lưới pixel.
3. Dựng wordmark ngang riêng; icon không phải gánh toàn bộ tên ở mọi ngữ cảnh.
4. Tạo phiên bản một màu, đảo màu, nền trong suốt và maskable icon.
5. Thiết kế motion `In4Up → I4U → In4Up` cho splash screen.
6. Sau khi duyệt mới thay launcher icon hiện tại trên Android, iOS, Web và Windows.
