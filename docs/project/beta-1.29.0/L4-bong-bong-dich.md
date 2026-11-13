# L4 — Bong bóng dịch (overlay)

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD).
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Bong bóng dịch phải phủ **mọi** khối văn bản trên màn hình (không bỏ sót khối) và đặt **đúng vị trí** của khối gốc — không lệch, không chồng nhau vô lý.

## Issue

| # | Trạng thái | Triệu chứng |
|---|---|---|
| **PSRC-211** | Backlog | Bong bóng dịch **bỏ sót khối** và **sai vị trí** |

Đợt 2 (cùng khu vực): **PSRC-194** — icon dịch của cabin hiện trên tab Nghe/Speaking (sai chỗ).

## Hướng điều tra

Thư mục: `lib/features/screen_translate/**` (+ `lib/features/translation/**` cho phân đoạn).

1. **Bỏ sót khối**: bộ thu thập node accessibility thường bỏ node có `bounds` rỗng/`Rect.zero`, node lồng trong `ScrollView`, hoặc node có text bị cắt. Ghi log số node tìm thấy vs số bong bóng tạo ra để chứng minh.
2. **Sai vị trí**: toạ độ node là toạ độ **cửa sổ của app nguồn**; overlay của mình phải cộng offset cửa sổ + trừ vùng bị che (status/nav bar, bàn phím). Kiểm tra `getWindowMetrics`/`Rect` gốc và phép `localToGlobal`.
3. Chồng lấn: sắp xếp + gộp bong bóng cùng khối thay vì vẽ đè.
4. 194: chỉ là điều kiện hiển thị icon — kiểm tra gate theo tab hiện tại.

## File chạm (dự kiến)

`lib/features/screen_translate/**`, `android/app/src/main/kotlin/**` (nếu là phía Kotlin), test `test/screen_translate/*`.

## Nghiệm thu

- [ ] Trên 1 màn hình có ≥ 8 khối text: tạo đủ bong bóng (có test/đếm được), screenshot trong mô tả PR.
- [ ] Sai lệch vị trí ≤ ~4 dp so với khối gốc, kể cả khi cuộn.
- [ ] Không còn bong bóng đè lên nhau khi 2 khối sát nhau.
- [ ] `flutter analyze` 0 error; `app_analyze` xanh.

## Không làm

- Không đổi engine dịch.
- Không thêm tính năng mới cho bong bóng (kéo/thả, ghim…).

## Commit

```
fix(PSRC-211): bong bóng dịch không bỏ sót khối và đúng vị trí [L4]
```

## Phát hiện thêm

_(trống)_
