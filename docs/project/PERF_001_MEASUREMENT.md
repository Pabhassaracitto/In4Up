# PERF-001 — Đo RAM & khựng trên MÁY THẬT

> Task: `PERF-001` (giảm RAM, hết khựng) — **không chuyển Rust**, không đổi
> kiến trúc, không đổi UI/UX.
>
> File này là **quy trình đo** + **biên bản những gì đã xét & loại**. Các ô số
> liệu "trước / sau" **CỐ Ý ĐỂ TRỐNG**: agent làm việc trong sandbox **không có
> Flutter/Android SDK, không adb, không thiết bị** ⇒ mọi con số RAM dưới đây
> phải do owner đo trên máy thật. **Không có số nào trong file này là số đo
> thật của app.**

---

## 1. Chuẩn bị (một lần)

```bash
# Bản build cần đo: flavor stable, profile hoặc release (debug làm số RAM sai)
flutter build apk --profile --flavor stable
adb install -r build/app/outputs/flutter-apk/app-profile-stable.apk

# Xác nhận đúng package (flavor khác nhau ⇒ package khác nhau)
adb shell pm list packages | grep in4up
#  com.in4up          ← stable
#  com.in4up.dev      ← dev (KHÔNG dùng để so sánh với stable)
#  com.in4up.beta     ← beta
```

DevTools (để chụp heap Dart):

```bash
adb forward tcp:9222 localabstract:flutter-devtools   # hoặc dùng nút "DevTools" trong IDE
```

---

## 2. Đo tổng RAM tiến trình (TOTAL PSS) — lệnh copy-paste được

```bash
# (a) 1 lần, đọc dòng TOTAL PSS
adb shell dumpsys meminfo com.in4up | grep -E "TOTAL PSS|TOTAL RSS|Native Heap|Dalvik Heap|Graphics|GL mtrack"

# (b) Theo dõi liên tục mỗi 2 giây (Ctrl+C để dừng) — thấy "RAM leo dốc" hay không
while true; do
  adb shell dumpsys meminfo com.in4up | grep "TOTAL PSS";
  sleep 2;
done
```

Cách đọc nhanh 3 dòng quan trọng:

| Dòng | Nghĩa | Nếu tăng nhiều ⇒ thủ phạm |
|---|---|---|
| `Native Heap` | bộ nhớ C++ (llama.cpp GGUF, sherpa-onnx, audio.cpp) | **model đang nạp** ⇒ PERF-001-B (nhả model) |
| `Graphics` / `GL mtrack` | texture/ảnh đã decode | **ảnh** ⇒ PERF-001-A (`cacheWidth`, hạn mức cache) |
| `Dalvik Heap` (Dart) | object Dart | parse/dựng object quá nhiều ⇒ PERF-001-D |

> Trên Android 11+ nên dùng `adb shell dumpsys meminfo <pid>` (theo pid) nếu
> có nhiều process cùng package.

---

## 3. Chụp heap snapshot ở 4 mốc

Mỗi mốc: mở DevTools → **Memory** → `Take Heap Snapshot`, đặt tên
`moc1..moc4`. Giữa các mốc **không** force-stop app (để thấy RAM có được trả
lại hay không).

| Mốc | Thao tác trước khi chụp | Câu hỏi cần trả lời |
|---|---|---|
| **M1** | Mở app, đứng ở tab Đọc (chưa mở gì) | Nền của app là bao nhiêu? |
| **M2** | Mở 1 PDF 50 trang, cuộn hết, **quay lại** tab Đọc | Rời màn PDF xong RAM có tụt? (PERF-001-A) |
| **M3** | Mở sheet chọn ảnh của 1 từ, cuộn ~200 ảnh từ vựng, đóng sheet | Ảnh có bị giữ mãi? (`imageCache` ≤ 48 MB?) |
| **M4** | Dịch 1 đoạn bằng Hy-MT offline, **chờ 5–6 phút** không thao tác | Model có được nhả? (PERF-001-B) |
| **M5** *(tuỳ chọn)* | Sau M4, dịch lại 1 đoạn | Nạp lại được, không báo "chưa import model"? |

Với mỗi mốc ghi lại: **TOTAL PSS**, **Native Heap**, **Graphics**, và (nếu
đang chạy bản debug) số ở **Settings → Quản lý Model AI → Hiệu năng & bộ nhớ →
Chẩn đoán bộ nhớ** (màn này **chỉ có ở build debug**, `kReleaseMode` guard).

---

## 4. Đọc kết quả ⇒ chọn việc

| Quan sát | Kết luận | Việc tương ứng |
|---|---|---|
| Native Heap cao & **không tụt** sau M4 | model GGUF còn nằm trong RAM | PERF-001-B (watchdog) — kiểm logcat `[in4up-perf] unload ...` |
| Graphics/GL cao & tăng dần khi cuộn ảnh | ảnh decode quá to / cache quá lớn | PERF-001-A (`cacheWidth`, `ImageCachePolicy`) |
| Dalvik Heap tăng vọt khi mở file text/LRC lớn | parse trên luồng UI | PERF-001-D (isolate) |
| TOTAL PSS tụt sau M4 nhưng M5 lỗi | watchdog nhả **quá tay** | tắt công tắc "Nhả model khi rảnh" + báo lại kèm logcat |

Xem log watchdog:

```bash
adb logcat -s flutter | grep "in4up-perf"
# [in4up-perf] image-cache: tối đa 48 MB / 160 ảnh
# [in4up-perf] image-cache trim #1 (…)
# [in4up-perf] unload hymt sau 300s rảnh
```

---

## 5. Bảng "TRƯỚC / SAU" — **owner điền** (để trống có chủ ý)

Thiết bị: `________` · Android: `________` · Build: `________`

| Mốc | TRƯỚC — TOTAL PSS | TRƯỚC — Native Heap | TRƯỚC — Graphics | SAU — TOTAL PSS | SAU — Native Heap | SAU — Graphics |
|---|---|---|---|---|---|---|
| M1 app mới mở | | | | | | |
| M2 sau PDF 50 trang (đã quay lại) | | | | | | |
| M3 sau cuộn 200 ảnh từ vựng | | | | | | |
| M4 sau dịch Hy-MT + 5 phút rảnh | | | | | | |
| M5 dịch lại sau khi nhả (nạp lại) | | | | | | |

Ghi chú của owner:

```
(khựng còn không? ở màn nào? mất bao lâu? …)
```

---

## 6. Kỳ vọng của code đã sửa (**kỳ vọng**, không phải số đo)

| Việc | Kỳ vọng | Căn cứ |
|---|---|---|
| PERF-001-A hạn mức ảnh | Trần ảnh giảm từ **100 MB → 48 MB**, số ảnh 1000 → 160 | `lib/services/image_cache_policy.dart` |
| PERF-001-A `cacheWidth` | Ảnh thumbnail decode **160 px** thay vì ảnh web 1280 px ⇒ mỗi ảnh nhỏ hơn ~64× số điểm ảnh | `ImageCachePolicy.thumbCacheWidth` |
| PERF-001-B nhả model khi rảnh | Native Heap tụt sau M4 (Hy-MT Q4_K_M **~1,13 GB** theo `hymt_engine.dart:448` `expectedBytes`; VieNeu Q8_0 ~170 MB; Gemma bf16 ~292 MB) | log `[in4up-perf] unload …` |
| PERF-001-D parse isolate | Mở LRC 2 giờ / text lớn: khung hình **không** rơi | `parseLrcContentOffThread`, `splitTextOffThreadIfLarge` |

---

## 7. Đã xét và **LOẠI** (không sửa code)

### 7.1 Catalog i18n (3,4 MB nguồn) — **LOẠI**, lợi ích < 2 MB

Đo lại bằng script (2026-11-08, nhánh `arena/e563943a-in4up`):

| File | Dung lượng nguồn | Entry |
|---|---|---|
| `lib/core/language/generated_priority_native_pack.dart` | 1,85 MB | 3.554 (399 có placeholder `{}`) |
| `lib/core/language/generated_ui_translations.dart` | 0,92 MB | 982 (52 có placeholder) |
| `lib/core/language/priority_ui_overrides.dart` | 0,44 MB | 1.212 (**66** có placeholder) |
| `lib/core/language/generated_legacy_ui_fallbacks.dart` | 0,16 MB | 2.252 (309 có placeholder) |
| **Tổng** | **3,38 MB chữ** | |

Lý do **KHÔNG** tái cấu trúc:

1. Cả 4 catalog là **`const` map** ⇒ ở build AOT nằm trong vùng dữ liệu
   **chỉ-đọc** của binary, **không** nằm trong Dart heap; OS có thể đẩy ra khi
   thiếu RAM ⇒ **không phải** 3,4 MB heap.
2. Phần **thật sự dựng object lúc chạy** (`_templateCatalogs` trong
   `lib/core/language/app_ui_translations.dart:22` — chỉ entry **có `{}`**):
   **399 + 52 + 66 = 517 template**. (Ước lượng trước đó ghi 399+52+65 = 516 —
   chênh 1 entry do cách đếm; đã đếm lại bằng script, con số đúng là 517.)
3. Kết luận: lợi ích **< 2 MB** ⇒ **không đáng** đổi rủi ro 26 file ARB +
   rule #5 (sàn T2 = 1,0 cho `hi/zh/zh_TW/si`).
4. **Không tìm thấy** chỗ nào tạo object lúc chạy nhiều hơn 517 template ⇒
   không có gì để báo owner.

⇒ **Diff i18n của PERF-001 chỉ có 8 chuỗi MỚI** cho mục "Hiệu năng & bộ nhớ"
(`priority_ui_overrides.dart` + `generated_legacy_ui_fallbacks.dart` +
`tool/legacy_ui_english_overrides.json`), **không** sửa cấu trúc catalog, không
đụng `lib/l10n/*.arb`.

### 7.2 STT/Sherpa — **CỐ Ý** không nối watchdog (quy tắc dừng #3)

Đã đọc code trước khi nối:

* `packages/in4up_stt/lib/sherpa_model_manager.dart:3016` — `dispose()` đóng
  `asrState` / `piperState` / `vadState` rồi đặt `_instance = null`. Đây là
  **teardown singleton**, KHÔNG phải "nhả model". Gọi nó từ watchdog lúc app
  đang chạy sẽ làm **hỏng mọi listener** của màn Quản lý Model AI.
* `packages/in4up_stt/lib/stt_service_facade.dart:1365` — `dispose()` cũng là
  teardown facade (đóng `_progressSubject`, `_partialSubject`).
* Model sherpa **đã được free sau MỖI lần transcribe**:
  `SherpaSttEngine.dispose()` (`packages/in4up_stt/lib/stt_engine_sherpa.dart:759`,
  gọi `_offline?.free()`) và facade gọi nó trong `finally`
  (`stt_service_facade.dart:1124`). ⇒ Không có model sherpa "nằm không" để nhả.

⇒ Cần một `unloadModel()` **riêng** trên engine STT trước khi nối watchdog.
Việc này **vượt phạm vi** PERF-001 (đổi API nội bộ của package STT) ⇒ **chờ
owner quyết định**, không tự làm.

### 7.3 `web_reader` — không có widget ảnh Flutter để thêm `cacheWidth`

`lib/features/web_reader/**` render ảnh **trong WebView** (HTML), không dùng
`Image.network`/`Image.file` ⇒ bước "thêm cacheWidth cho web_reader" của
PERF-001-A **không áp dụng được** cho ảnh trong bài đọc. Test
`test/perf/image_cache_policy_test.dart` pin lại sự thật này để không ai tưởng
bị bỏ sót.

---

## 8. Việc **CHƯA** kiểm được trong sandbox (đúng sự thật)

1. **Không có Flutter/Android SDK, không adb, không thiết bị** ⇒ chưa build
   APK, chưa chạy app, **chưa có một số RAM nào**.
2. Mọi kiểm chứng ở trên là **test Dart thuần / source-scan chạy trên CI**
   (`.github/workflows/app_analyze.yml` step `PERF-001`), không phải đo máy thật.
3. Hành vi native khi `dispose()` model giữa 2 lượt dùng (Hy-MT isolate kill,
   VieNeu `audio.cpp` free, Gemma isolate kill) **chưa** chạy trên máy thật —
   chỉ suy ra từ code đã có (facade tự `restartEngine` khi state = `disposed`).
4. Cảm giác "hết khựng" chỉ owner xác nhận được (mở PDF 50 trang, cuộn 200
   ảnh, mở LRC 2 giờ).
