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

### PSRC-211 — nguyên nhân thật (khác "Hướng điều tra" ở trên)

Dịch màn hình **không** dùng node accessibility. Luồng thật: MediaProjection chụp màn hình → ML Kit OCR (Dart) → dịch → `layoutTranslatedBlocks` (Dart) → `TranslationOverlayView` (Kotlin) vẽ. Mục 1–2 của "Hướng điều tra" vì vậy không áp dụng. Nguyên nhân tìm được:

1. **Cỡ chữ đo theo chiều cao CẢ KHỐI** — đoạn văn 4 dòng bị gán 28sp (trần) thay vì ~15sp, lại bỏ qua `fontScale`. Bản dịch cần gấp 3–4 lần chỗ ⇒ khối phình, đẩy mọi khối bên dưới lệch khỏi chữ gốc, khối cuối màn hình rơi khỏi màn hình ⇒ **bỏ vẽ**.
2. **Bộ ước lượng coi `\n` là dấu cách** trong khi `StaticLayout` của native xuống dòng thật ⇒ Dart cấp thiếu chiều cao ⇒ native bỏ vẽ khối (đúng luật "không vẽ chữ cụt").
3. **Xếp chỗ kiểu "đẩy trước"**: một khối cần thêm chỗ là đẩy cả cột bên dưới. Giờ: giữ đỉnh gốc → dùng khoảng trống tới khối kế → thu nhỏ RIÊNG khối đó (sàn 10sp) → cuối cùng mới đẩy.
4. Phụ: chữ toàn ôm (Hán/Kana/Hangul) ước 0,56em thay vì 1em; ML Kit tách một đoạn văn thành nhiều khối 1 dòng (giờ gộp lại trước khi dịch); native tô nền kín cả khung ước dư (giờ ôm sát chữ thật qua `coverBottom`); overlay vẽ theo toạ độ view, không trừ vị trí cửa sổ.

Bằng chứng tái hiện: bài test nghiệm thu `test/screen_translate/psrc_211_bubble_coverage_test.dart` chạy trên code CŨ ⇒ đỏ ở "đủ 10 bong bóng" (CI run `43492520476`).

### Chưa kiểm được / còn lại

- **Chưa chạy trên máy thật.** Sandbox không có Flutter/Android SDK — mọi thứ kiểm qua CI (analyze + test Dart + kotlinc + build APK). Cần owner thử trên máy và chụp **screenshot** cho mục nghiệm thu 1 (lane không tự chụp được).
- **Bù vị trí cửa sổ overlay** (`getLocationOnScreen` trong `TranslationOverlayView.onDraw`): trên máy cửa sổ nằm đúng (0,0) thì không đổi gì; chỉ máy có tai thỏ khi xoay ngang / ROM chèn lề mới thấy khác. Chưa có máy để xác nhận.
- **Cỡ chữ hệ thống 2.0× + màn hình dày chữ**: vẫn có khối bị lệch / bỏ vẽ (mô phỏng màn hình bài viết 10 khối: vẽ 8, hai nút cuối bị bỏ). Lý do: luật owner XLAT-SCR-006 cấm vẽ dưới 10sp và cấm cắt chữ, mà 10sp × 2.0 đã to hơn chữ gốc. Muốn hết phải đổi luật (cho phép < 10sp khi fontScale lớn) — cần owner quyết.
- **Trần 32 khối/lượt** (`kScreenTranslateMaxBlocks`, quyết định cũ vì mốc 3 giây + quota engine): màn hình ra > 32 khối sau khi gộp đoạn thì các khối nhỏ nhất vẫn không được dịch. Không đổi trong lane này; logcat giờ in phễu `screen translate blocks: ocr= paragraphs= selected= translatable= translated= drawn=` để đo trên máy thật trước khi quyết.
- **Tần suất ML Kit tách đoạn** chưa đo trên máy thật; điều kiện gộp đặt rất chặt (cùng cỡ chữ, cùng lề trái, sát nhau, câu đang dở) nên sai thì nghiêng về "không gộp" = hành vi cũ.
- **Tiêu đề viết hoa từng từ / tiếng Đức** bị ngắt dòng sẽ không được nối (dòng dưới viết hoa) — chấp nhận, xem `isSoftWrap`.
- `lib/features/ocr/**` (lane L3) không bị sửa.
- **PSRC-194** (đợt 2) chưa làm.
