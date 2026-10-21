# Nghiệm thu chung — YouTube (YT-LR-002/003/004 + YT-AUDIT-001 đợt 1–4)

**Branch:** `arena/9498c207-in4up` · **Gốc:** `arena/01a0251e-in4up`
**Ngày viết:** 2026-10-21 · **Trạng thái:** chờ nghiệm thu máy thật

Tài liệu này gom **toàn bộ** phần YouTube đã làm trên branch này thành **một
checklist nghiệm thu duy nhất**. Các tài liệu chi tiết theo đợt vẫn còn
(`bangiao_yt_lr_002.md`, `bangiao_yt_audit_001.md`) — dùng khi cần đào sâu
nguyên nhân. Còn khi cầm máy lên test, dùng file này.

---

## 0. Chuẩn bị

| # | Việc | Ghi chú |
|---|---|---|
| 0.1 | `git pull` + build lại | Version phải là **1.12.4+12** trở lên |
| 0.2 | Chuẩn bị **2 tình huống** model AI: <br>**(A) chưa cài model** và **(B) đã cài model** (hoặc đã cấu hình provider OpenRouter) | Nhiều mục bên dưới đổi hành vi theo (A)/(B) — phải test cả hai |
| 0.3 | Chuẩn bị **2 loại mạng**: **wifi** và **mạng di động** | Cần cho mục #6 (định tuyến AI) |
| 0.4 | Chọn sẵn 1 video **có phụ đề tiếng Anh**, dài ≥ 3 phút | Video có sẵn phụ đề (CC) thì test nhanh hơn video phải tự sinh |
| 0.5 | Vào **Cài đặt Home** → đổi *Ngôn ngữ đích* sang **English** → đổi lại **Tiếng Việt** | Cần cho mục #4 |

> **Mẹo:** mở sẵn Cài đặt phụ đề (nút ⚙ ở góc phụ đề) — phần lớn các mục test
> đều thao tác ở đó.

---

## A. 10 mục audit 2026-10-20

### A1. Tải audio chỉ được một xíu rồi dừng *(Đợt 1 · IN4-97)*

| Bước | Kỳ vọng |
|---|---|
| Vào tab **TẢI** → **Tải audio** một video dài | Thanh tiến trình chạy **đến 100%** và hiện *Hoàn tất* |
| Giữa chừng bật/tắt wifi (hoặc đổi sang mạng yếu) | **Tự nối tiếp** (không bắt đầu lại từ 0); tiến trình không kẹt quá ~30 giây |
| Sau khi xong, vào **Mở trong tab Nghe** | Nghe được **trọn vẹn** — không bị cụt |
| Trong lúc đang tải bấm **Dừng** | Dừng ngay, không để file rác `.part` |

*Gốc rễ đã sửa:* bản cũ không kiểm tra `downloaded == totalBytes`; YouTube hay
đóng kết nối giữa chừng **mà không ném lỗi** ⇒ file cụt nhưng vẫn báo xong.

### A2. Chọn “Làm mờ bản dịch” không thấy gì *(Đợt 1 · IN4-98)*

| Bước | Kỳ vọng |
|---|---|
| Cài đặt phụ đề → **Làm mờ bản dịch** | Bản dịch hiện **mờ** (đọc không rõ), phụ đề gốc vẫn rõ |
| **Bấm vào bản dịch** | Hiện rõ tạm thời, rồi **mờ lại** |
| Chuyển sang **Ẩn bản dịch** | Chỉ còn phụ đề gốc |
| Chuyển sang **Ẩn phụ đề** | Ô phụ đề trống nhưng **player không bị giật/nhảy** |

### A3. Dịch đôi khi ra tiếng Anh thay vì tiếng Việt *(Đợt 1 · IN4-99)*

| Bước | Kỳ vọng |
|---|---|
| Mở nhiều video khác nhau (có phụ đề tiếng Anh) | Bản dịch **luôn là tiếng Việt** (hoặc đúng ngôn ngữ đích đã chọn) |
| Xem nhiều dòng liên tục | Không có dòng nào sót lại tiếng Anh nguyên bản |

### A4. Ngôn ngữ đích theo Cài đặt Home + override từng video *(Đợt 2 · IN4-103)*

| Bước | Kỳ vọng |
|---|---|
| Cài đặt Home để ngôn ngữ đích = **Tiếng Việt** → mở video | Cài đặt phụ đề hiện *“Cài đặt Home đang để: Tiếng Việt”*; ô **Ngôn ngữ dịch** mặc định = **Theo Cài đặt Home** |
| Đổi Cài đặt Home sang **English** → mở lại video | Ngôn ngữ dịch theo **English** |
| Trong Cài đặt phụ đề, chọn riêng **Ngôn ngữ dịch** = một ngôn ngữ khác | **Chỉ video này** dùng ngôn ngữ đó; video khác vẫn theo Home |
| Chọn **Phụ đề gốc** = `en` | Lấy đúng track `en` (không bị lén đổi thành `vi`) |

*Đã bỏ:* đoạn `target == 'en' ? 'vi'` (lén đổi đích) và việc hard-code English
làm mặc định.

### A5. Tab GIẢI THÍCH có nội dung thật *(Đợt 4 · IN4-105)*

**Tình huống (B) — có model AI:**

| Bước | Kỳ vọng |
|---|---|
| Bấm 1 từ trong phụ đề → tab **GIẢI THÍCH** | Có ô **Ngữ pháp** gồm **Cấu trúc / Chủ ngữ / Động từ / Tân ngữ / Giải thích** (tiếng Việt) ← **phần chưa từng có trước đây** |
| Cùng lúc | Có **Tóm tắt** dài 2–3 câu (**không** còn chỉ 2–5 từ) |
| Cùng lúc | Có **Mẹo nhớ**, **Ví dụ trong ngữ cảnh**, **Hình ảnh gợi nhớ**, **Câu chuyện ghi nhớ** |
| Bấm 1 từ **không có** trong từ điển offline | Vẫn có kết quả AI (**không** còn *“No local dict entry and engine not ready”*) |

**Tình huống (A) — chưa cài model:**

| Bước | Kỳ vọng |
|---|---|
| Bấm 1 từ → tab GIẢI THÍCH | Có banner + nút **Cài AI**, **không crash** |
| Cùng lúc | **Vẫn có nội dung**: ô **Nghĩa** (từ điển nhanh hoặc MDX) + ô **Câu đang phát** = chính câu phụ đề vừa bấm |
| Cùng lúc | Có ô **“Cần AI cho phần còn lại”** liệt kê **đúng** những phần còn trống, kèm nút **Phân tích bằng AI** |

**Cả hai tình huống:** nếu AI gọi được nhưng lỗi ⇒ ô lỗi hiện **tiếng Việt**,
không còn câu tiếng Anh thô.

### A6. Chưa cài model → banner + nút Cài AI, ưu tiên theo loại mạng *(Đợt 2 · IN4-104)*

| Bước | Kỳ vọng |
|---|---|
| (A) chưa cài model → vào bất kỳ nơi nào gọi AI | Banner + nút **Cài AI**; **không crash**, **không tự gọi mạng** |
| **(B) + wifi** → bấm phân tích | **Ưu tiên mạng** (online trước) |
| **(B) + mạng di động** → bấm phân tích | **Ưu tiên cục bộ**; chỉ khi cục bộ không xong mới qua mạng |
| Tắt hẳn mạng + (B) | Không treo; có thông báo rõ ràng |

### A7. Lịch sử hoạt động ghi nhận truy cập *(Đợt 1 · IN4-101)*

| Bước | Kỳ vọng |
|---|---|
| Mở 2–3 video → ra vào lại màn YouTube | **Lịch sử xem** hiện đủ 2–3 video, **video mới nhất ở trên cùng** |
| Bấm 1 mục trong lịch sử | Mở đúng video đó |
| Lịch sử trống | Hiện *“Chưa có lịch sử xem.”* |

### A8. Bấm 1 từ → hiện từ loại / phiên âm / nghĩa *(Đợt 1 · IN4-102)*

| Bước | Kỳ vọng |
|---|---|
| Bấm từ **`very`** | Tab **NGHĨA** hiện từ loại = **trạng từ**, có phiên âm, có nghĩa tiếng Việt |
| Bấm các từ khác nhau (danh từ / động từ / tính từ…) | Từ loại hiện **đúng** từng từ: `danh từ`, `động từ`, `tính từ`, `trạng từ`, `giới từ`, `liên từ`, `đại từ`, `tên riêng`… |
| Bấm 1 từ lạ (không có trong từ điển) | Hiện *“Chưa có nghĩa offline cho từ này.”* — **không** để trống im lặng |
| Kéo thanh **Ngưỡng tần suất** | Từ quen/không quen đổi cách đánh dấu |

### A9. Chế độ “Có bản dịch”: bấm 1 dòng ⇒ nhiều dòng dịch bị ẩn *(đã fix ở YT-LR-003)*

| Bước | Kỳ vọng |
|---|---|
| Chế độ **Có bản dịch** → bấm 1 dòng phụ đề | **Chỉ dòng đó** thay đổi; các dòng khác giữ nguyên |

### A10. Phát phụ đề: tự do hay tự động theo dòng hiện tại *(Đợt 1 · IN4-100)*

| Bước | Kỳ vọng |
|---|---|
| Tab **VĂN BẢN** → mặc định | = **Tự động theo dòng hiện tại**: danh sách tự cuộn theo audio |
| Chuyển sang **Cuộn tự do** | Danh sách **không** tự cuộn nữa — kéo thoải mái, không bị giật về dòng đang phát |
| Đang ở **Cuộn tự do**, chờ vài giây | Không bị tự nhảy về dòng hiện tại |
| Chuyển lại **Tự động theo dòng hiện tại** | Cuộn theo lại bình thường |

---

## B. Đợt 3 — Chia câu + bù trễ âm thanh/chữ *(IN4-108)*

| Bước | Kỳ vọng |
|---|---|
| Mở một video có phụ đề dạng caption (ngắt dòng tuỳ ý) | Phụ đề được **ghép thành câu hoàn chỉnh**: đầu câu **viết hoa**, cuối câu có **dấu chấm/hỏi/thán** |
| Đọc vài câu liên tiếp | Không còn câu bị ngắt giữa chừng, không còn dòng bắt đầu bằng chữ thường |
| Tab **VĂN BẢN** | Cũng là câu hoàn chỉnh (cùng bộ phân câu) |
| Nghe mà thấy chữ đến **trễ hơn** tiếng | Cài đặt phụ đề → mục *“Đo được chữ đến trễ …”* → bấm **Áp dụng** ⇒ khớp hơn |
| Kéo tay thanh trượt **Âm thanh nhanh hơn chữ / Chữ nhanh hơn âm thanh** | Bù từ **−3,0 giây đến +3,0 giây**, bước **0,1 giây**; giá trị **được lưu lại** khi mở lại video |
| Bấm **Đặt về 0** | Về đúng 0 và lưu |

*Ghi chú:* đã **không** dùng VAD (iframe WebView không có PCM). Bù trễ = thanh
trượt thủ công **+** gợi ý tự động lấy từ độ lệch đo được.

---

## C. Ba nhóm lõi (đã nghiệm thu trước đó — kiểm tra không bị hỏng)

### C1. Cài đặt phụ đề (YT-LR-002)

| Bước | Kỳ vọng |
|---|---|
| Mở ⚙ Cài đặt phụ đề | Có đủ: **Bản dịch** (4 chế độ), **Bố cục danh sách** (3 kiểu: Đơn giản / Song song / Trên-dưới), **Ngưỡng tần suất**, **Phụ đề gốc**, **Ngôn ngữ dịch**, phần bù trễ |
| Đổi bố cục sang **Song song** | Tab VĂN BẢN hiện 2 cột: gốc + dịch |
| Đổi sang **Trên và dưới** | Gốc ở trên, dịch ở dưới |
| Đóng rồi mở lại | Mọi lựa chọn **được nhớ** |

### C2. Từ điển & phân tích từ (YT-LR-002/003)

| Bước | Kỳ vọng |
|---|---|
| Bấm 1 từ → bảng tra từ hiện | 2 tab **NGHĨA** / **GIẢI THÍCH** |
| Tab NGHĨA | Có từ loại, phiên âm, nghĩa, **Từ đồng nghĩa**, mục **Từ điển (n)** |
| Khi kết quả thực ra chỉ là nghĩa từ điển (AI không trả được gì thêm) | Có **cảnh báo** nói rõ điều đó — không giả vờ là do AI phân tích |

### C3. Lexa AI Chat (YT-LR-002)

| Bước | Kỳ vọng |
|---|---|
| Tab **LEXA** | Khung chat hiện, gửi được câu hỏi |
| Hỏi về từ/câu trong video | Trả lời có **ngữ cảnh video** |
| (A) chưa cài model | Thông báo rõ + nút **Cài AI**, không crash |

### C4. Vào thẳng YouTube (YT-LR-004)

| Bước | Kỳ vọng |
|---|---|
| Từ màn chính bấm icon **YouTube** | Vào **thẳng** màn YouTube — **không** còn tầng 1 trung gian |

---

## D. Kiểm tra vùng khác không bị ảnh hưởng (hồi quy)

Branch này đụng vào các file dùng chung, nên cần lướt qua:

| Vùng | Cần thấy |
|---|---|
| Tab **Đọc** | Căn lề các hàng vẫn đều; icon loa **đổi màu + nhấp nháy** khi đang đọc; bấm lần 2 thì **dừng**; dòng đang đọc có **highlight + badge số dòng** |
| **Cài đặt → Nhà cung cấp AI** | Có provider **OpenRouter** (model `minimax/minimax-m3.1-flash:free`); không còn vạch vàng-đen khi tên model dài |
| **Cài đặt Home → Ngôn ngữ đích** | Đổi được; YouTube đi theo (mục A4) |
| Màn **Nhớ** | Thanh công cụ không tự ẩn |
| Đổi ngôn ngữ ứng dụng sang **English** | Mọi chuỗi chrome (kể cả 12 chuỗi mới của bảng tra từ) hiện **tiếng Anh**, không rớt về tiếng Việt |

---

## E. Những điều **CÓ CHỦ ĐÍCH** không làm — đừng báo nhầm là lỗi

| Hiện tượng | Vì sao là đúng |
|---|---|
| Chưa cài model ⇒ **không có** ô Ngữ pháp / Mẹo nhớ / Hình ảnh gợi nhớ / Câu chuyện ghi nhớ | Đoán S-V-O bằng regex sẽ **sai phần lớn** và **dạy sai còn tệ hơn không có**. Tab hiện nội dung thật + ô “Cần AI cho phần còn lại” |
| Bảng tra từ **không gửi từ loại** cho AI | Gửi vào sẽ làm kết quả rớt về từ điển trông *như* AI đã trả lời ⇒ **mất cảnh báo** “thực ra chỉ là nghĩa từ điển” |
| Không có nút “bù trễ bằng VAD” | iframe WebView không có PCM ⇒ làm không được |
| Bù trễ **không** tự động sửa | Có sẵn gợi ý tự động từ số đo được; **phải bấm Áp dụng** để tránh tự chỉnh khi số đo nhiễu |

---

## F. Cách ghi nhận kết quả

Đánh dấu từng mục: **Đạt** / **Không đạt** / **Không test được**. Với mục
không đạt, ghi theo mẫu:

```
Mục:      A5 (tab GIẢI THÍCH)
Tình huống: (A) chưa cài model  /  (B) đã cài model
Máy:      <dòng máy> · Android <version> · build 1.12.4+12
Làm:      bấm từ "very" trong câu "…"
Thấy:     <mô tả / ảnh chụp màn hình>
Lẽ ra:    có ô Ngữ pháp với Cấu trúc / Chủ ngữ / Động từ / Tân ngữ
```

---

## G. Đối chiếu nhanh

| Mục | Issue Linear | Đợt |
|---|---|---|
| A1 tải audio | IN4-97 | 1 |
| A2 làm mờ bản dịch | IN4-98 | 1 |
| A3 dịch ra tiếng Việt | IN4-99 | 1 |
| A4 ngôn ngữ đích | IN4-103 | 2 |
| A5 tab GIẢI THÍCH | IN4-105 | 4 |
| A6 định tuyến AI theo mạng | IN4-104 | 2 |
| A7 lịch sử hoạt động | IN4-101 | 1 |
| A8 từ loại / phiên âm / nghĩa | IN4-102 | 1 |
| A9 ẩn nhiều dòng dịch | *(đã fix YT-LR-003)* | — |
| A10 tự do / tự động | IN4-100 | 1 |
| B chia câu + bù trễ | IN4-108 | 3 |
| C1–C3 ba nhóm lõi | IN4-85…88 | YT-LR-002/003 |
| C4 bỏ tầng 1 | IN4-95 | YT-LR-004 |

**Tổng: 10/11 mục của bản audit 2026-10-20** (mục #9 đã fix từ YT-LR-003).
