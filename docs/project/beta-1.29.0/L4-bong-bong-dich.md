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

### Vòng 2 (hub 2026-11-13, `L4-hub-tra-loi.md`) — không khối nào bị bỏ im lặng

- **§ 3 — trạng thái "thu gọn".** Khối không còn chỗ cho NGUYÊN bản dịch ở sàn 10sp ⇒ `layoutTranslatedBlocks` trả `collapsed: true` (bản dịch nguyên vẹn, `rect` = chỗ vẽ chip 28×20dp) thay vì `translation: ''`. Native: `buildLayout` trả `FittedText` (không còn `null`), vẽ chip "…", mỗi chip có một cửa sổ chạm riêng (`OverlayChipLayer`), chạm ⇒ popup đủ bản dịch 16sp + chữ gốc, cuộn được. Chip ưu tiên góc trên-phải chữ gốc; chỗ đó đã bị khung khác chiếm (màn hình bị đẩy kín tới đáy) thì chip xuống một hàng dành riêng sát đáy màn hình — **khác chữ "ở góc trên-phải" trong phiếu hub**, vì đặt ở góc lúc đó là đè lên khung khác.
- **§ 4 — trần 32 khối.** `selectBlocksToTranslate` trả `(selected, pending)`; ưu tiên khối giao vùng nhìn (màn hình trừ lề hệ thống, native gửi `insetLeft/Top/Right/Bottom` từ `WindowMetrics`), rồi diện tích × độ dài. Phần dư nằm trong phiên; kết quả mang `pendingCount` + `pendingLabel`; native hiện chip "Còn N khối · Dịch tiếp", bấm ⇒ `translatePending` dịch thêm tối đa 32 khối trên CÙNG ảnh (không tự lặp). Lượt hỏng ⇒ báo lỗi, giữ nguyên khối chờ.
- **Khung đè nhau khi hai HÀNG khác nhau giao ngang một dải hẹp** (lỗi có từ trước lane, ngưỡng "cùng cột" 25%): `_pack` giờ coi hai khối khác hàng có giao ngang (dù hẹp) là xếp chồng dọc. Hai khối CÙNG hàng giao vài pixel giữ hành vi cũ.
- 3 chuỗi UI mới đủ 8 locale trong `tool/priority_native_pack.json` (đã regenerate).
- Test: `test/screen_translate/psrc_211_no_silent_drop_test.dart` (4 test § 3, 3 test § 4 + nhiều lượt / lượt hỏng / frame mới, 8 locale, lề 0/24/48dp dọc + ngang, nối dây Kotlin); sửa `overlay_layout_audit_test.dart` và `screen_translate_controller_test.dart` theo hợp đồng mới.

### Chưa kiểm được / còn lại

- **Vòng 2 chưa có kết quả CI tại thời điểm commit.** Cổng § 2 của hub đã mở: L8 đã land, `grep -c "android/app/src/main/kotlin" .github/workflows/vieneu_engine_build.yml` trên tip beta `5ed5765` = 1. Sandbox không có Flutter/Dart SDK ⇒ trước khi push, **mã Dart và test Dart của vòng 2 chưa từng được biên dịch hay chạy** (chỉ kiểm cú pháp bằng tree-sitter); Kotlin mới biên dịch bằng kotlinc dựng tạm trong sandbox với stub Flutter/`R` viết tay — gần đúng, KHÔNG thay được build Gradle. Chỉ coi là xong khi `App Analyze`, `Listen queue` và `VieNeu engine build` xanh trên nhánh lane.
- **Vòng 1** đã được hub land vào beta (`5ed5765`, cùng nội dung với `c2f1a14`): xanh ở `App Analyze` 43493738612 (analyze + test Dart) và `Listen queue` 43493738401 (kotlinc cho `TranslationOverlayView.kt`). Vì vậy vòng 2 là **một commit riêng nằm trên** commit đó (không amend được commit đã ở beta) — hub squash khi land nếu muốn giữ đúng một commit. Trước vòng 2 **chưa có lần build APK nào** biên dịch `ScreenTranslateService.kt` (dòng "build APK" ở bản trước của phiếu này là sai).
- **Chưa chạy trên máy thật.** Cần owner thử và chụp ảnh ở cổng G3 (mục nghiệm thu 1). Riêng vòng 2 cần nhìn tận mắt: chip chạm có trúng không, popup, chip "Dịch tiếp", vị trí chip khi xoay ngang / máy có tai thỏ.
- **Bù vị trí cửa sổ overlay** (`getLocationOnScreen`): máy cửa sổ nằm đúng (0,0) thì không đổi gì; chỉ máy có tai thỏ khi xoay ngang / ROM chèn lề mới thấy khác. Phép cộng lề đã có test với lề giả; chưa có máy để xác nhận.
- **Lề hệ thống chỉ lấy được từ API 30** (`currentWindowMetrics`). Máy cũ hơn không gửi lề ⇒ mọi khối tính là "đang nhìn", chỉ còn xếp theo diện tích × độ dài (hành vi cũ) — phần dư vẫn không mất.
- **Khối dịch HỎNG lẻ** (engine lỗi ở một khối trong khi các khối khác dịch được) vẫn không có bong bóng lẫn chip, và không quay lại hàng chờ — hành vi cũ, chưa đổi ở vòng này. Chỉ lượt "Dịch tiếp" hỏng TOÀN BỘ mới được giữ lại để bấm lại.
- **Hai khối CÙNG hàng mà khung OCR gốc đã giao nhau** thì khung dịch vẫn giao đúng dải đó (không tách được nếu không cắt chữ).
- **Quá nhiều chip** (hơn 4 hàng chip sát đáy, cỡ > 50 chip trên màn dọc): chip thừa bị đặt ở góc chữ gốc dù có đè — chưa gặp trong mô phỏng, không có test.
- **Popup** dùng cửa sổ `FLAG_NOT_FOCUSABLE`: đóng bằng chạm ra ngoài thẻ, nút Back không đóng.
- **Tần suất ML Kit tách đoạn** chưa đo trên máy thật; điều kiện gộp đặt rất chặt (cùng cỡ chữ, cùng lề trái, sát nhau, câu đang dở) nên sai thì nghiêng về "không gộp" = hành vi cũ.
- **Tiêu đề viết hoa từng từ / tiếng Đức** bị ngắt dòng sẽ không được nối (dòng dưới viết hoa) — chấp nhận, xem `isSoftWrap`.
- `lib/features/ocr/**` (lane L3) không bị sửa. File chung đã đụng: `tool/priority_native_pack.json` + `lib/core/language/generated_priority_native_pack.dart` (thêm 3 khoá ở cuối).
- **PSRC-194** (đợt 2) chưa làm — hub hoãn, ngoài cổng beta.
