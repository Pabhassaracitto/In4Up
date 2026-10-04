# In4Up Server Box (WP5 / API-006)

Bộ Docker Compose này biến một máy tính trong mạng LAN thành ba API tương thích
OpenAI cho In4Up:

| Năng lực | Dịch vụ | Base URL mặc định |
|---|---|---|
| Chat và dịch | Ollama | `http://IP_MAY_CHU:11434/v1` |
| Nhận dạng giọng nói từ file | Speaches (faster-whisper) | `http://IP_MAY_CHU:8000/v1` |
| Đọc văn bản | Kokoro-FastAPI | `http://IP_MAY_CHU:8880/v1` |

> Đây là cấu hình **CPU mặc định**, không cần GPU. API không có mật khẩu và được
> mở trên LAN. Chỉ dùng trong mạng gia đình/cơ quan đáng tin cậy; không NAT/port
> forward ba cổng này ra Internet.

## 1. Yêu cầu máy chủ

- Linux, Windows 10/11 + Docker Desktop (WSL2), hoặc macOS + Docker Desktop.
- Docker Engine 24+ và Docker Compose v2 (`docker compose version`).
- CPU 64-bit, tối thiểu 4 luồng; khuyến nghị 6–8 luồng.
- Trống ít nhất 10 GB (image + model + cache; file model được giữ trong volume).
- Máy khách chạy In4Up và máy chủ ở cùng LAN/Wi-Fi, không bật AP/client isolation.

### Cấu hình model theo RAM

Các số dưới đây là mức thực dụng cho **toàn bộ ba container**, không phải cam
kết tuyệt đối; hệ điều hành và độ dài ngữ cảnh cũng dùng RAM.

| RAM / GPU | Ollama | Speaches | Kokoro | Ghi chú |
|---|---|---|---|---|
| **8 GB, không GPU (tối thiểu)** | `qwen2.5:1.5b` (mặc định) | `Systran/faster-whisper-small`, CPU `int8` | CPU | Chạy đủ ba dịch vụ; nên gọi lần lượt, không xử lý đồng thời file dài. |
| 16 GB, không GPU | `qwen2.5:3b` hoặc model 3B–4B quantized | `Systran/faster-whisper-medium` hoặc `small` | CPU | Chất lượng tốt hơn nhưng STT/LLM vẫn phụ thuộc tốc độ CPU. |
| 16–32 GB + NVIDIA 8 GB VRAM | model 7B quantized; Whisper `small`/`medium` | Nên dùng image CUDA theo tài liệu upstream | GPU hoặc CPU | Compose mặc định vẫn chạy CPU để tương thích mọi máy. |

Không chọn Whisper `large-v3` hoặc LLM 7B trên máy chỉ có 8 GB RAM. Model STT
được Speaches tải ở lần dùng đầu tiên nên lần đầu sẽ lâu hơn. Nếu máy 8 GB bị
swap/OOM, đóng ứng dụng nặng và giữ model mặc định; kiểm tra bằng
`docker stats`.

## 2. Khởi động bằng một lệnh

Mở terminal tại thư mục này (`docs/server_box`) rồi chạy:

```bash
docker compose up -d
```

Lần đầu Docker tải vài GB và job `ollama-model-loader` tải model
`qwen2.5:1.5b`; tùy mạng có thể mất nhiều phút. Chờ đến khi ba dịch vụ chính
đều `healthy`:

```bash
docker compose ps
```

`ollama-model-loader` hiện `Exited (0)` là **đúng**: đó là job chạy một lần.
Theo dõi khi cần:

```bash
docker compose logs -f
```

### Chọn model Ollama khác

Đặt biến trước lần chạy đầu (ví dụ máy 16 GB):

```bash
OLLAMA_MODEL=qwen2.5:3b docker compose up -d
```

Hoặc tải thêm sau đó:

```bash
docker compose exec ollama ollama pull qwen2.5:3b
```

Docker volume giữ model qua các lần `down`/`up`. Lệnh
`docker compose down -v` sẽ **xóa toàn bộ model/cache đã tải**.

## 3. Lấy địa chỉ IP LAN

Dùng **IP của máy chạy Docker**, không dùng `localhost`/`127.0.0.1` trong điện
thoại.

- Linux: `hostname -I` hoặc `ip -4 addr`
- Windows PowerShell: `ipconfig` → dòng `IPv4 Address` của Wi-Fi/Ethernet
- macOS: `ipconfig getifaddr en0` (Wi-Fi thường là `en0`)

Ví dụ IP là `192.168.1.50`, ba base URL là:

```text
http://192.168.1.50:11434/v1
http://192.168.1.50:8000/v1
http://192.168.1.50:8880/v1
```

Nên đặt DHCP reservation/static lease trên router để IP không đổi. Cho phép TCP
inbound các cổng **11434, 8000, 8880** trong firewall của máy chủ, chỉ với
subnet LAN. Docker Desktop/Windows có thể hỏi quyền mạng ở lần chạy đầu.

## 4. Health-check

Trên máy chủ (cần `curl`), chạy:

```bash
chmod +x health-check.sh
./health-check.sh
```

Từ một máy khác trong LAN, thay IP máy chủ:

```bash
./health-check.sh 192.168.1.50
```

Script gọi đúng `GET /v1/models` của từng dịch vụ và chỉ thành công khi cả ba
trả HTTP 200 cùng danh sách model. Có thể kiểm tra riêng:

```bash
curl http://192.168.1.50:11434/v1/models
curl http://192.168.1.50:8000/v1/models
curl http://192.168.1.50:8880/v1/models
```

Nếu chưa xanh, chạy `docker compose ps` và
`docker compose logs --tail=100 <ollama|speaches|kokoro>`. Hãy chờ Kokoro warm-up
và các image/model tải xong trước khi kết luận lỗi.

## 5. Nhập vào app In4Up

Trên điện thoại, mở **Cài đặt → Server & API** (màn WP0), tạo ba provider:

1. **Ollama LAN**: Base URL `http://IP:11434/v1`, để trống API key, bấm
   **Kiểm tra kết nối**, chọn `qwen2.5:1.5b`; dùng cho **Chat** và **Dịch**.
2. **Speaches LAN**: Base URL `http://IP:8000/v1`, để trống API key, kiểm tra
   kết nối; chọn `Systran/faster-whisper-small` cho **STT file**. Model sẽ được
   tải/cached ở request đầu.
3. **Kokoro LAN**: Base URL `http://IP:8880/v1`, để trống API key, kiểm tra
   kết nối; chọn model Kokoro được danh sách trả về cho **TTS**.

Sau đó bật từng provider và chọn routing `onlineFirst` cho năng lực muốn chạy
trên Server Box (hoặc giữ `offlineFirst` để ưu tiên engine trên điện thoại).
Cả ba nút kiểm tra phải hiện xanh. Tên mục có thể khác đôi chút theo ngôn ngữ
và phiên bản app.

### Lỗi thường gặp

- **Điện thoại không kết nối nhưng curl trên server được:** sai IP, firewall,
  guest Wi-Fi/AP isolation, VPN hoặc Private DNS; thử curl từ một máy LAN khác.
- **Test xanh nhưng dropdown không có model Ollama:** xem log job loader rồi
  chạy `docker compose exec ollama ollama list`; tải model bằng lệnh ở mục 2.
- **Chậm/OOM trên máy 8 GB:** dùng đúng LLM 1.5B và Whisper `small`, tránh chạy
  chat và bóc băng cùng lúc.
- **Đổi cổng:** đặt `OLLAMA_PORT`, `SPEACHES_PORT`, `KOKORO_PORT` khi chạy
  Compose và nhập đúng cổng mới trong app; container vẫn dùng cổng nội bộ cũ.

## 6. Dừng hoặc cập nhật

```bash
# Dừng, vẫn giữ model
docker compose down

# Cập nhật image rồi chạy lại
docker compose pull
docker compose up -d
```

Image dùng tag `latest`/`latest-cpu` để bộ docs-only tiếp tục cài được theo API
upstream. Với máy vận hành ổn định, quản trị viên nên ghi lại digest từ
`docker image inspect` và pin digest theo chính sách cập nhật của mình.
