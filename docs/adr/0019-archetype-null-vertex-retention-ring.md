# ADR-0019: Archetype (level) + null-vertex + retention ring

- **Ngày:** 2026-11-03
- **Trạng thái:** PROPOSED (phần visual chờ owner quyết D9)
- **Phạm vi:** Visual hexagram, Mastery Vector, Retention lớp.

## Bối cảnh

- Level tổng hợp **không gộp SM-2** (ADR-0001). Không lưu scalar tổng, không dùng diện tích làm level.
- Visual: null-vertex contract + retention ring.

## Quyết định

### 1. Archetype (8 loại)

- blindSpot, passiveListener, textReader, receptiveHoarder, imitativeSpeaker,
  productiveAsymmetric, functionalBalanced, fullMastery.
- Ngưỡng **[P0 — cần calibrate bằng dữ liệu thật]** (không dùng ngưỡng tùy tiện).

### 2. Null-vertex contract

- Đỉnh chưa có bằng chứng = vòng rỗng nét đứt, không tô.
- Envelope không nội suy qua null.
- Legend: "○ Chưa đánh giá", không hiển thị là 0.

### 3. Retention ring

- Retention (Nhớ) là lớp glow/opacity quanh đỉnh, không phải trục, không cộng vào mastery.
- Retention unknown không gán 0.5.

### 4. Visual (D9 — ĐÃ QUYẾT)

**Owner quyết: CẢ 2 view + toggle chuyển đổi.**

- **Word view (hexagram):** 3 cặp mirror trên đường kính xuyên tâm (Hiểu↔Dùng, Nghe↔Nói, Đọc↔Viết).
  Input tam giác trong, Output tam giác ngoài, khe gap = production gap. Xem **1 từ**.
- **Collection view (scatter):** x = Input, y = Output, đường chéo = cân bằng.
  Xem **toàn kho**. Production gap = khoảng cách tới đường chéo.
- **Toggle** cho người dùng chuyển Word ↔ Collection. **Painter code ở P3.**

## Hệ quả

- (+) Level đọc được, không gộp SM-2.
- (+) Cả 2 view: vừa inspect 1 từ, vừa nhìn tổng thể.
- (−) Archetype ngưỡng cần calibrate thật.
- (−) P3 cần code 2 painter + toggle.

## Kiểm thử

- Unit test archetype classifier.
- Unit test null-vertex không nội suy.
- Golden test visual (sau D9).
