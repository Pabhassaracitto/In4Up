# L4 — Hub trả lời các điểm chưa kiểm (2026-11-13)

> Phiếu chính: `L4-bong-bong-dich.md`. File này chỉ ghi **quyết định của hub** cho 6 điểm
> agent L4 báo chưa kiểm được. Đọc hết rồi làm, không cần hỏi lại.
> Nguyên tắc bao trùm: **không khối chữ nào bị bỏ im lặng**. Mỗi khối OCR vào phải có đúng
> một đầu ra — bong bóng đầy đủ, hoặc một dấu hiệu thu gọn mà người dùng mở ra được.

## Bảng quyết định

| # | Agent báo | Hub quyết | Agent phải làm |
|---|---|---|---|
| 1 | Chưa chụp ảnh máy thật, chưa mở PR | **Không mở PR.** Ảnh chụp là việc của owner ở cổng G3 | Không mở PR; trong commit body ghi "chờ ảnh G3" |
| 2 | `ScreenTranslateService.kt` chưa được biên dịch (dispatch 403) | **403 là đúng — token của agent *và* của hub đều không có `actions:write`; chỉ owner bấm được.** Nhưng không cần bấm: lane L8 đã thêm trigger `android/app/src/main/kotlin/**` vào `vieneu_engine_build.yml` | Kiểm trước khi push (xem § 2); push xong **phải** thấy run "VieNeu engine build" xanh trên nhánh mình |
| 3 | Bù vị trí cửa sổ (tai thỏ, xoay ngang) chưa thấy khác | **Không chặn.** Giữ cách tính từ `WindowMetrics` | Thêm test cho phép cộng inset với inset giả (0 / 24 / 48 dp, dọc + ngang) |
| 4 | Cỡ chữ hệ thống 2.0× vẫn rơi 2/10 khối | **Không hạ sàn 10sp, không ellipsize** (giữ luật owner 2026-11-11). Thay bằng **trạng thái thứ ba: thu gọn** | Xem § 3 — đây là việc chính của vòng này |
| 5 | Trần 32 khối: khối nhỏ nhất không được dịch | **Giữ trần 32 mỗi lượt, nhưng không bỏ vĩnh viễn** — phần dư thành "còn N khối", dịch tiếp được | Xem § 4 |
| 6 | PSRC-194 (đợt 2) chưa làm | **Đúng — không làm bây giờ** (ngoài cổng beta) | Giữ nguyên ghi chú trong phiếu, không sửa code |

## 1. Ảnh chụp & PR

Bằng chứng cuối của lane là **ảnh trên máy thật của owner** gắn vào issue `PSRC-211`, không phải
PR. Agent chỉ cần: CI xanh + commit body có triệu chứng/nguyên nhân/bằng chứng + dòng
"chưa kiểm máy thật: ảnh chụp G3".

## 2. Biên dịch Kotlin — làm trước khi push

Hiện `app_analyze` **chỉ chạy Dart**; mã Kotlin **chỉ** được biên dịch trong
`vieneu_engine_build.yml` (build APK arm64). Trên tip beta hôm nay, file đó **chưa** có trigger
Kotlin; lane L8 đã bổ sung 3 dòng:

```yaml
      - 'android/app/src/main/kotlin/**'
      - 'android/app/src/main/AndroidManifest.xml'
      - 'android/app/src/main/res/**'
```

**Kiểm trước khi push:**

```bash
grep -c "android/app/src/main/kotlin" .github/workflows/vieneu_engine_build.yml   # phải >= 1
```

- `>= 1` ⇒ push bình thường, CI tự build APK (≈18 phút) và biên dịch `ScreenTranslateService.kt`.
- `0` ⇒ **dừng, báo hub**: cần land L8 (hoặc cherry-pick 6 dòng đó) trước, nếu không phần sửa Kotlin
  sẽ không có oracle nào cả. Không tự thêm trigger vào nhánh mình (tránh xung đột với L8).

## 3. Font scale 2.0× — thêm trạng thái "thu gọn" (việc chính)

Nguyên nhân gốc đã xác định: `TranslationOverlayView.buildLayout` trả `null` khi vẫn tràn ở sàn
`MIN_READABLE_SP` (= 10sp) và caller **bỏ vẽ** khối đó (đổi từ ellipsize sang bỏ hẳn để không cắt
chữ). Với màn hình dày chữ + font scale 2.0×, 2/10 khối rơi vào nhánh này.

**Quyết định:** giữ nguyên hai luật "không nhỏ hơn 10sp" và "không ellipsize", nhưng thay vì bỏ
khối thì vẽ **chip thu gọn**:

1. `buildLayout` không trả `null` nữa; trả một layout có `collapsed = true` với nội dung là nhãn
   ngắn (1 ký tự hoặc "…" theo ngôn ngữ, **không** phải chữ bị cắt giữa từ) — kích thước tối thiểu
   khoảng 20×14 dp, vẽ ở góc trên-phải khối gốc.
2. Chạm chip ⇒ mở bản dịch **đầy đủ** (dialog/popup) ở cỡ chữ bình thường — chữ vẫn ≥ 10sp, chỉ là
   không nằm trong khung gốc nữa.
3. Ưu tiên trước khi thu gọn: các bước 1–4 hiện có (đẩy lên, mở rộng khung vào chỗ trống, thu nhỏ
   đều tới `kOverlayMinShrink` = 0.78) vẫn chạy đủ. Chỉ khi hết cách mới tới chip.

**Nghiệm thu (bắt buộc có test, không chỉ mô phỏng tay):**
- Fixture màn hình dày chữ (≥ 10 khối, khung thấp) ở `fontScale = 2.0` ⇒
  `slots.length == blocks.length` và **0** khối `dropped`.
- Có ≥ 1 slot `collapsed` trong fixture đó (chứng minh nhánh mới thật sự chạy).
- Ở `fontScale = 1.0` cùng fixture ⇒ 0 slot `collapsed` (không hồi quy: nhánh mới không kích hoạt
  khi không cần).
- Chip chạm được: test cho hàm trả "khối nào tại toạ độ (x, y)" hoặc cho callback chạm.

Việc này nằm gọn trong Dart (`screen_translate_overlay_layout.dart` + slot model) và một chỗ trong
`TranslationOverlayView.kt` (bỏ `null`, vẽ chip).

## 4. Trần 32 khối — không bỏ vĩnh viễn

`selectBlocksToTranslate` hiện `ranked.take(32)` rồi **mất phần dư**. Đổi thành:

1. Xếp hạng theo **ưu tiên nhìn thấy**: khối giao với viewport trước, rồi mới tới diện tích × độ dài
   như hiện tại. Giữ nguyên thứ tự đọc khi trả về.
2. Trả `(selected, pending)` thay vì chỉ `selected`; `pending` = phần dư (đếm được, không mất).
3. Sau lượt đầu, hiện chip trạng thái **"còn N khối · Dịch tiếp"**; bấm ⇒ lượt kế tiếp cho phần dư.
   Không tự động vòng lặp vô hạn (giữ mốc 3 giây và quota engine).
4. Giữ `kScreenTranslateMaxBlocks = 32` làm mặc định; **không** nâng lên 64 ở lane này.

**Nghiệm thu:**
- Test: 70 khối vào ⇒ 32 dịch + 38 pending, `selected` giữ đúng thứ tự đọc, không khối nào xuất hiện
  hai lần.
- Test: viewport cắt nửa trên màn hình ⇒ các khối trong viewport được chọn trước.
- UI: chip "còn N khối" chỉ hiện khi `pending > 0`.

## 5. Commit — gộp, không thêm đuôi

Toàn bộ việc trên **vẫn là PSRC-211**. Gộp vào commit đã có của lane (amend hoặc `git rebase -i`
squash) để cuối cùng lane L4 vẫn đúng **một commit code** (cộng tối đa một commit tài liệu).
Tiêu đề giữ nguyên: `fix(PSRC-211): bong bóng dịch không bỏ sót khối và đúng vị trí [L4]`.

Chuỗi UI mới (nhãn chip, "còn N khối · Dịch tiếp", tiêu đề popup) phải đủ **8 locale** qua
`tool/priority_native_pack.json` + regenerate như README § 3 mô tả.

## 6. Định nghĩa xong của vòng này

- [ ] Không còn đường nào bỏ khối im lặng: `buildLayout` không trả `null`, `selectBlocksToTranslate`
      không cắt mất phần dư.
- [ ] 4 test ở § 3 + 3 test ở § 4 xanh trong `app_analyze`.
- [ ] 8 locale đủ cho chuỗi mới; `flutter analyze` 0 error.
- [ ] Run "VieNeu engine build" xanh trên nhánh (chứng minh `ScreenTranslateService.kt` biên dịch được).
- [ ] Commit body ghi rõ: chưa kiểm máy thật (ảnh G3); chỗ nào chưa làm được thì nói thẳng.

---

# § 7 — Nghiệm thu hai nhánh L4 (hub, 2026-11-14)

Ngày 2026-11-13 có **hai** nhánh cùng làm PSRC-211. Hub chọn một để land, nhánh còn lại giữ làm
tài liệu tham chiếu.

| | `arena/33cb5b7a-in4up` (**nhận**) | `arena/defa5264-in4up` (giữ tham chiếu) |
|---|---|---|
| Commit | `c2f1a146` → rebase thành `5ed57656` | `490294ed` |
| Diff | 10 file, +1711/−257 | 7 file, +717/−164 |
| Test | suite cũ + **2 file mới** (984 dòng): `psrc_211_bubble_coverage_test.dart`, `screen_translate_text_flow_test.dart` | sửa 2 file cũ (264 dòng) |
| Chứng minh đỏ trước khi sửa | **Có** — coverage test đỏ trên code cũ (run `43492520476`), xanh sau khi sửa | Không có bước chứng minh đỏ |
| Nguyên nhân gốc bao phủ | cỡ chữ theo `fontScale` + `\n`, xếp chỗ "đẩy trước", gộp dòng cùng đoạn trước khi dịch (module mới `screen_translate_text_flow.dart`), bù `getLocationOnScreen` khi vẽ | như trên **+** cutout/insets/`maximumWindowMetrics`/resize `VirtualDisplay` khi xoay, `RegionSelectView` offset, lọc rác **trước** khi cắt hạn mức |
| Trần khối | giữ 32 | nâng 64 (hub **không** chấp nhận — xem § 4) |

**Quyết định:** nhận `33cb5b7a` vì (1) có máy bắt đầu-cuối *và* chứng minh đỏ-trước-xanh-sau — đúng
DoD "sửa nguyên nhân gốc + có test khoá lại"; (2) gộp đoạn/dòng mềm trước khi dịch là cải thiện
chất lượng bản dịch, không chỉ vá hiển thị; (3) mặt test rộng gấp ~3,7 lần.

**Nợ chuyển sang vòng 2** (lấy từ `defa5264`, đã CI xanh ở nhánh đó nên dùng làm bản tham chiếu,
đừng viết lại từ đầu):
1. `ScreenTranslateService.kt`: `layoutInDisplayCutoutMode`, `fitInsetsTypes = 0`,
   `maximumWindowMetrics`, `syncWarmDisplayIfSizeChanged()` + `onConfigurationChanged`.
2. `RegionSelectView.kt`: quy đổi `getLocationOnScreen` khi chọn vùng.
3. `ScreenTranslateController`: **lọc số/ký hiệu/link trước khi cắt** hạn mức (giữ trần 32).
4. Cộng với § 3 (chip thu gọn) và § 4 (pending + "Dịch tiếp") ở trên.

**Trạng thái land (tuyến tính trên beta):** `3e3ca64` → `d3819528`+`fe0832ac` (L8) → `5ed57656` (L4).
Push này chạm `android/app/src/main/kotlin/**` nên `vieneu_engine_build` **tự chạy** — đúng cái
oracle mà agent L4 trước đó bị chặn (§ 2), không cần ai bấm `workflow_dispatch`.

**CI trên tip đã land `5ed57656` (2026-11-14):** `app_analyze` **43575629305** 🟢 ·
`listen_queue_tests` **43575629308** 🟢 · `vieneu_engine_build` **43575629299** 🟢 (biên dịch Kotlin
+ đóng gói 3 `.so`). Tức là ngay sau khi land, `ScreenTranslateService.kt` **đã** được biên dịch —
điểm chặn số 2 ở đầu file này coi như đóng, không cần owner bấm dispatch.

**Chưa nghiệm thu được ở đây:** hiển thị thật trên máy (tai thỏ, xoay ngang, font scale 2.0×,
màn hình dày chữ) — thuộc cổng **G3**, cần ảnh của owner gắn vào `PSRC-211`.
