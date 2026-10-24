# I4U — BONG BÓNG DỊCH: ĐIỀU TRA 6 ĐIỂM (2026-10-24)

> Vai: thám tử kỹ thuật. Mục tiêu: **giải thích được nguyên nhân** (không đoán),
> **chỉ ra cái gì đã sửa trong phiên này**, và **cái gì cần máy thật để nghiệm thu**.
>
> Nhánh: `arena/7550b302-in4up`. Card: `XLAT-SCR-005` (nâng cấp bong bóng),
> `XLAT-SCR-006` (đề xuất: nhà sưu tầm từ vựng).
>
> ⚠️ Sandbox này **không có Flutter SDK / Android SDK / thiết bị**. Mọi thay đổi
> là code + test thuần Dart đã viết nhưng **chưa chạy `flutter analyze`/`flutter
> test`** ở đây; CI của repo sẽ chạy. Phần Kotlin chưa được biên dịch ở sandbox
> (đúng như ghi chú sẵn có ở card XLAT-SCR-002).

---

## TL;DR — 6 câu hỏi, 6 câu trả lời

| # | Câu hỏi của chủ dự án | Kết luận điều tra | Trạng thái phiên này |
|---|---|---|---|
| 1 | Bấm xong phải chờ lâu mới dịch — do đâu? | **Dịch TUẦN TỰ từng khối**: tối đa 32 khối × 1 request mạng mỗi khối (250–700 ms), cộng cold start engine nền + kiểm tra mạng/`hasModel` lặp lại cho từng khối + OCR cả màn hình 1920px | ✅ Đã sửa: song song 3 luồng, gộp khối trùng, bỏ khối vô nghĩa, cache network/plan, warm-up engine nền, chọn vùng để OCR ít chữ |
| 2 | Có plan nào thêm cho bong bóng chưa? Có nên cho nó "sưu tầm từ vựng"? | Repo chỉ có XLAT-SCR-002/003/004 (chống crash/quyền) + XLAT-SCR-WIN-001 (Windows, có kéo vùng). **Không có** card nào cho: kéo chọn vùng trên Android, đổi ngôn ngữ nguồn, trạng thái engine, thu thập từ vựng | 📋 Đã tạo `XLAT-SCR-005` (làm trong phiên này) + `XLAT-SCR-006` (đề xuất, có thiết kế + lộ trình 3 giai đoạn) |
| 3 | Bấm bong bóng không có phản hồi | Bong bóng chỉ đổi màu theo quyền, **không có trạng thái "đang chạy"**; tiến trình có sẵn `reportProgress` nhưng **chưa nối** ở Dart | ✅ Bong bóng: nhấp nháy + "…" + màu tím khi chạy, ✓ xanh khi xong, ! đỏ khi lỗi + nhãn tiến trình dưới bong bóng ("Đang dịch 3/12 khối…") |
| 4 | Muốn kéo chọn vùng thay vì cả màn hình | Chưa từng có code vùng chọn (không có `crop/region` trong `lib/features/screen_translate/` lẫn package Kotlin) | ✅ Lớp phủ kéo chọn vùng + cắt ảnh **trước OCR** (thuần Dart, có test) + công tắc trong Cài đặt + giữ lâu bong bóng |
| 5 | Vì sao mặc định chỉ tiếng Anh và chỉ đổi được đích? | Pipeline luôn để nguồn = `AUTO` (tự nhận diện); UI chỉ có 1 picker + native chỉ nhận `targetLanguage` | ✅ Thêm ngôn ngữ nguồn (Tự nhận diện + 26 ngôn ngữ), nút hoán đổi hai chiều, mặc định đích = **ngôn ngữ ứng dụng**, áp dụng ngay khi đang chạy |
| 6 | Không biết engine đang là online/offline/Hy-MT/ML Kit | Sheet Cài đặt dịch chỉ có URL DeepLX + nút tải model + công tắc; `lastUsedEngine`/`activeEngine` có trong service nhưng **không hiện ở đâu** | ✅ Khối "Engine đang hiện hành": chip Online/Chỉ offline, **thứ tự ưu tiên thật**, engine đang chạy, lần trước dùng, model đã có, nút **"Kiểm tra engine ngay"** (dịch thử 1 câu → báo engine + ms) |

---

## 1. Vì sao bấm bong bóng phải chờ lâu?

### 1.1 Chuỗi thực thi (đọc từ code, không suy diễn)

`onBubbleTapped()` → (nếu chưa có consent: hộp thoại hệ thống) → `captureOnce()`
→ `sendFrameToDart()` → `ScreenTranslateController.handleFrame()`:

1. `normalizeCaptureFrame` — copy ~10–20 MB + hoán kênh R↔B (một vòng lặp Dart).
2. OCR ML Kit cả màn hình (ảnh tối đa 1920px cạnh dài).
3. Chọn tối đa **32 khối** (`kScreenTranslateMaxBlocks`).
4. **`for (final block in selected) { await _translator(...) }`** — từng khối một,
   chờ xong khối trước mới sang khối sau ⇒ 32 request **nối đuôi**.

Mỗi request còn phải đi qua `TranslationService.translateText`:
`detectSourceLanguage` (nếu AUTO) → cache (SharedPreferences) → glossary →
`_checkNetwork()` (**platform channel, gọi lại cho từng khối**) → `_planSteps()`
(**đọc file `hymt.hasModel` + `mlkit.isAvailable` cho từng khối**) → chuỗi engine:
online (Google Free → MyMemory → Libre, mỗi engine timeout 12s + nghỉ 100ms) →
Hy-MT (GGUF chạy trên máy) → ML Kit (timeout 30s) → từ điển.

### 1.2 Con số ước tính (trước khi sửa)

| Thành phần | Thời gian |
|---|---|
| OCR cả màn hình | 0,6–2,0 s |
| 1 khối qua Google Free | 0,2–0,8 s |
| 32 khối TUẦN TỰ | **8–25 s** |
| Nếu rơi xuống Hy-MT (LLM offline) | mỗi khối 1–3 s ⇒ **30 s+** |
| Lần đầu trong phiên (engine nền vừa dựng, Hive/glossary/cache chưa mở) | +0,3–1,5 s |
| Chưa có consent MediaProjection | + hộp thoại hệ thống (người dùng còn phải bấm) |

⇒ Triệu chứng "bấm xong chờ rất lâu" **không phải do mạng chậm** mà do **số
request và cách xếp hàng**.

### 1.3 Đã sửa trong phiên này

| Sửa | Ở đâu | Tác dụng |
|---|---|---|
| Dịch **song song có giới hạn** (`kScreenTranslateConcurrency = 3`) | `screen_translate_controller.dart` | 32 khối ≈ 11 vòng thay vì 32 ⇒ nhanh ~3× |
| **Gộp khối trùng nội dung** (một màn hình hay lặp "Settings", "OK") | cùng file | giảm số request thật, tránh 429 |
| **Bỏ khối không có chữ cái** (giờ, số, ký hiệu) | `hasTranslatableLetters` | không đốt request cho "12:30" |
| **Cache kết quả kiểm tra mạng 5 s** | `translation_service.dart` | bỏ 31 lần gọi platform channel/lượt |
| **Cache kế hoạch bước dịch 10 s** (hasModel/isAvailable) | `translation_service.dart` | bỏ 31 lần đọc file/lượt |
| **`warmUp()`** ngay khi engine nền dựng xong | `screen_translate_entrypoint.dart` + `TranslationService.warmUp` | lần bấm ĐẦU TIÊN không gánh chi phí mở cache/glossary/Connectivity |
| **OCR chỉ trên vùng kéo chọn** | Q4 bên dưới | ít chữ ⇒ OCR nhanh hơn, ít khối hơn |

**Kỳ vọng sau sửa:** vùng chọn 5–10 khối: **1–2,5 s**; cả màn hình 30 khối:
**3–7 s** (tuỳ mạng). Đây vẫn là con số *kỳ vọng*, phải đo bằng log trên máy thật.

### 1.4 Chưa làm (đề xuất, xem mục 10)

- Dịch **nhiều khối trong MỘT request** (Google Free nhận nhiều `q`) — nhanh hơn nữa
  nhưng phải xử lý engine không hỗ trợ batch; cần ADR riêng.
- OCR ở chế độ "chỉ vùng nhìn thấy"/giảm `MAX_CAPTURE_EDGE` cho máy yếu.
- Nếu người dùng chọn engine offline (Hy-MT) thì **không song song 3** (GGUF dùng
  chung slot single-flight) — hiện chấp nhận vì Hy-MT tự xếp hàng.

---

## 2. Plan hiện có + người dùng cần gì thêm + có nên "sưu tầm từ vựng"?

### 2.1 Cái đang có trong repo

| Card | Nội dung | Trạng thái |
|---|---|---|
| `XLAT-SCR-002` | Lane native: bong bóng + MediaProjection + overlay | chờ nghiệm thu thiết bị |
| `XLAT-SCR-003` | Chạm bong bóng không có gì xảy ra (quyền/background) | chờ logcat + máy |
| `XLAT-SCR-004` | Crash PendingIntent + engine nền không khởi tạo | chờ máy |
| `XLAT-SCR-WIN-001` | Windows: chụp màn hình + **kéo chọn vùng** | 📋 proposed (chưa code) |
| ADR-0011 | Chụp/vẽ ở native, OCR/dịch ở Dart | đã chốt |

⇒ **Không có** card nào cho: kéo chọn vùng trên Android, đổi ngôn ngữ nguồn,
"engine nào đang chạy", hay thu thập từ vựng từ màn hình. Vì vậy phiên này lập
`XLAT-SCR-005` (làm luôn) và `XLAT-SCR-006` (đề xuất).

### 2.2 Người dùng thật cần gì ở "bong bóng hoạt động bên ngoài"?

Đóng vai người dùng (đang đọc tài liệu/tin nhắn tiếng Anh trên một app không có
nút dịch), xếp theo mức đau:

1. **Biết nó đã nhận lệnh chưa** — đau nhất, vì hiện tại bấm mà không thấy gì
   ⇒ bấm lại ⇒ "Đang dịch màn hình trước…" ⇒ tưởng app treo. (Q3)
2. **Đừng dịch cả màn hình** — người dùng chỉ cần một đoạn; dịch cả màn hình vừa
   lâu vừa rối. (Q4)
3. **Đừng đoán sai ngôn ngữ** — tài liệu Nhật/Trung/Đức; hoặc cần dịch ngược
   VI→EN để viết lại. (Q5)
4. **Biết nó dùng engine nào** — vì chất lượng khác nhau rõ rệt (Google vs
   Hy-MT vs ML Kit) và vì "không có bản dịch" thường là **thiếu model offline**,
   không phải app hỏng. (Q6)
5. **Lấy được chữ ra khỏi màn hình** — dán sang ghi chú, tra từ điển, lưu từ
   vựng. Đây là "FBI đi thu thập tình hình" mà chủ dự án nói.
6. **Dịch lại nhanh khi nội dung đổi** (cuộn trang, thông báo mới) — hiện phải
   bấm lại; chưa làm "live mode" (tốn pin, cần ADR).
7. **Không bị lộ dữ liệu** — nhiều người dùng không biết ảnh màn hình được gửi
   lên engine online. Cần nói rõ trong Cài đặt (đề xuất P2).

### 2.3 Có nên cho nó kiêm "nhà sưu tầm từ vựng"?

**Có — nhưng không phải kiểu tự động lưu mọi thứ.** Lý do:

- **Nên:** người dùng đang đọc tài liệu trên app khác, gặp từ mới; hiện phải:
  dịch màn hình → đọc → mở In4Up → gõ lại từ → lưu. Ma sát quá cao ⇒ không ai
  lưu. Bong bóng đã có sẵn **chữ gốc + bbox** của từng khối trong
  `ScreenBlock.original` ⇒ nguyên liệu đã nằm trong tay.
- **Không nên (tự động):** OCR cả màn hình ra 30 khối, phần lớn là nhãn UI, tên
  nút, số. Tự lưu hết sẽ **đầu độc Wordlist** và làm hỏng SRS (thẻ rác, nghĩa
  máy dịch sai ngữ cảnh). Bài học từ chính repo: rule "KHÔNG gộp 3 skill SM-2" và
  nguyên tắc "không đoán" trong i18n.

**Thiết kế đề xuất (XLAT-SCR-006), 3 giai đoạn:**

- **G1 — Thu hoạch có chủ đích (nhỏ, an toàn):** giữ lâu bong bóng khi overlay
  đang hiện ⇒ mở "chế độ thu hoạch": overlay chuyển sang **nhận chạm**, chạm một
  khối ⇒ sheet hiện `original` + bản dịch + nút **"Lưu vào Wordlist"** (dùng
  `WordListController` sẵn có, kèm ảnh/ngữ cảnh nếu muốn). Không tự lưu gì.
  - Kỹ thuật: overlay hiện `FLAG_NOT_TOUCHABLE`; cần thêm cờ "collect mode" để
    bật chạm **chỉ khi người dùng yêu cầu**, rồi trả lại trạng thái cũ. → **ADR
    bắt buộc** (đổi hợp đồng overlay, ảnh hưởng "người dùng vẫn dùng được app
    bên dưới").
- **G2 — Trích từ trong khối:** tách token từ khối đã chọn, so với Wordlist hiện
  có (đã biết/chưa biết), gợi ý 1–3 từ đáng lưu; hiện IPA nếu có nguồn.
- **G3 — "Tình báo" chủ động (FBI mode):** gom các từ **lặp lại qua nhiều phiên**
  (đếm tần suất trong SharedPreferences, không gửi đi đâu), gợi ý "bạn gặp từ này
  4 lần trong tuần — lưu để học?". Có công tắc tắt. Tuyệt đối không tự tạo thẻ.

**Điều kiện tiên quyết:** G1 cần chạy ổn định trên máy thật (Q4) trước, vì cùng
đụng vào lớp phủ.

---

## 3. Phản hồi khi bấm bong bóng (đã làm)

**Trước:** bong bóng chỉ có 2 dáng (xanh = sẵn sàng, cam ⚙ = thiếu consent).
Bấm xong không đổi gì; `reportProgress` có trong giao thức nhưng **Dart không gọi**
⇒ notification cũng đứng ở "Đang đọc chữ và dịch màn hình…".

**Nay:**

| Thời điểm | Bong bóng | Nhãn dưới bong bóng | Notification |
|---|---|---|---|
| Bấm trúng | tím + **nhấp nháy** + "…" | "Đang đọc chữ và dịch màn hình…" | cùng nội dung |
| OCR xong | tím nhấp nháy | "Đang nhận dạng chữ…" → "Đang dịch 3/12 khối chữ…" | theo từng chặng |
| Thành công | **✓ xanh** 1,4 s rồi về xanh dương | ẩn | "Đã dịch bằng <engine> — bấm bong bóng để tắt" |
| Lỗi | **! đỏ** 1,4 s | câu lỗi cụ thể | toast + notification (như cũ) |
| Kéo chọn vùng | tím nhấp nháy | "Kéo trên phần chữ bạn muốn dịch" | — |

Vì sao cần **cả ba kênh**: máy có thể tắt thông báo (Android 13+ chưa cấp
`POST_NOTIFICATIONS`), toast có thể bị che, và bong bóng luôn nằm trên cùng ⇒
bong bóng là kênh chắc chắn nhất.

**Thao tác mới:** **giữ lâu bong bóng 450 ms** = kéo chọn vùng (không cần bật
công tắc). Khi lớp phủ chọn vùng đang hiện: **chạm suông = huỷ** ("Đã huỷ chọn
vùng"), **kéo quá bé = huỷ kèm hướng dẫn** ("Vùng chọn quá nhỏ…"). Lớp phủ phủ
toàn màn hình nên bong bóng không bấm được trong lúc chọn — vì vậy hai đường huỷ
trên là đường duy nhất, và cả hai đều **có thông báo**, không im lặng.

---

## 4. Kéo chọn vùng (đã làm)

### 4.1 Cách dùng

- Bật công tắc **"Mỗi lần bấm bong bóng: kéo chọn vùng"** trong thẻ *Dịch màn
  hình toàn hệ thống* → mọi lần bấm bong bóng đều mở khung chọn.
- Hoặc **giữ lâu bong bóng** bất cứ lúc nào (kể cả khi công tắc đang tắt).
- Kéo một khung → nhấc tay → dịch **chỉ vùng đó**.
- Chạm suông (không kéo) ⇒ huỷ + "Đã huỷ chọn vùng".
- Vùng < 28dp (kéo non tay) ⇒ huỷ + "Vùng chọn quá nhỏ — hãy kéo khung lớn hơn".

### 4.2 Kỹ thuật

- `RegionSelectView.kt` (mới): lớp phủ vẽ 4 dải tối quanh khung + viền + hướng
  dẫn. **Không giữ Bitmap/Image**, không cấp phát trong `onDraw`, toạ độ clamp
  theo kích thước view.
- Service gỡ lớp phủ **trước** rồi chờ **180 ms** mới chụp (nếu không ảnh chụp
  dính luôn lớp phủ tối ⇒ OCR rác + bản dịch lệch chỗ).
- Vùng đi kèm frame dưới dạng `regionLeft/Top/Right/Bottom` (**pixel màn hình**);
  Dart tự đổi sang pixel ảnh (`screenRegionToCapture`) rồi **cắt ảnh trước OCR**
  (`cropPackedFrame`), sau đó **dời bbox** (`offsetOcrRect`) để overlay vẽ đúng.
- `pendingRegion` là **one-shot**: dùng cho đúng một lượt chụp; mọi nhánh lỗi
  đều xoá nó (không để áp nhầm sang lượt sau).
- Toàn bộ phần "toán" có test host VM: `test/screen_translate/screen_translate_selection_test.dart`.

### 4.3 Chống crash (bài học "kéo xong là sập")

| Nguy cơ | Cách chặn |
|---|---|
| Rect rỗng/âm ⇒ crop ném lỗi | `screenRegionToCapture` trả `null` nếu < 16 px hoặc ngoài ảnh; controller rơi về "cả màn hình" |
| Cắt ảnh sai kích thước ⇒ đọc tràn | `cropPackedFrame` kiểm tra độ dài mảng, ném `ArgumentError` — controller bắt và fallback |
| View bị gỡ giữa lúc chạm | cờ `finished` chặn callback thứ hai; service bọc try/catch |
| Chụp khi lớp phủ còn hiện | gỡ view → chờ 180 ms → chụp |
| Mất quyền overlay giữa chừng | mọi `addView` có try/catch → `onOverlayRevoked()` (dừng sạch + hướng dẫn) |

---

## 5. Ngôn ngữ nguồn (đã làm)

**Vì sao trước đây chỉ có đích:** `TranslationService.translateText(text,
targetLang: …)` để `sourceLang` mặc định `AUTO` (tự nhận diện bằng
`LanguageDetector`); Dart gọi engine chỉ với `target`; native chỉ gửi
`targetLanguage`. Tức là **kiến trúc coi nguồn là "không cần biết"**, không phải
giới hạn kỹ thuật.

**Nay:**

- Thẻ cài đặt có **2 đầu**: *Ngôn ngữ nguồn* (mặc định **Tự nhận diện**) và
  *Ngôn ngữ đích* (mặc định = **ngôn ngữ ứng dụng**, fallback VI), kèm nút
  **hoán đổi ⇄**.
- Hoán đổi: `EN→VI` thành `VI→EN`; `AUTO→VI` thành `VI→EN` (không có "đích tự
  nhận diện"); hai ngôn ngữ không phải tiếng Anh (JA→VI, ZH→HI…) đều chọn được.
- Lưu `screen_translate_source_lang` / `screen_translate_target_lang` trong
  SharedPreferences (engine nền đọc chung).
- Mỗi frame mang thêm `sourceLanguage`; đổi ngôn ngữ khi bong bóng đang chạy có
  hiệu lực **ngay lượt kế tiếp** (`setLanguages`).
- Mã lạ ⇒ **AUTO** (không đoán bừa sang EN).

---

## 6. Biết chính xác engine nào đang chạy (đã làm)

**Trước:** sheet "⚙️ Engine dịch thuật" chỉ có: URL DeepLX, nút tải gói ML Kit,
chip Hy-MT/ML Kit, công tắc "Chỉ dùng dịch offline", phần LLM API. Không có chỗ
nào nói **lượt dịch kế tiếp sẽ đi qua engine nào**, cũng không hiện
`lastUsedEngine`/`activeEngine` (service đã có sẵn nhưng không ai đọc).

**Nay — khối "Engine đang hiện hành" ở đầu sheet:**

- Chip **Online** / **Chỉ offline** (theo `offlineOnly`).
- **Thứ tự ưu tiên thật** (lấy từ `TranslationService.routingOrder`, sao chép
  đúng điều kiện của `_runEngineChain`): ví dụ
  `Google Translate → MyMemory → Libre → Hy-MT · offline (dự phòng) → ML Kit → Offline dictionary`.
- **Đang dịch bằng** (engine đang chạy — `activeEngineNotifier`).
- **Lần trước** (engine thực sự trả bản dịch: `💾 Cache`, `📚 Google Translate`…).
- Model đã có: `Hy-MT`, `ML Kit: EN, VI`.
- Nút **"Kiểm tra engine ngay"**: dịch thử 1 câu EN→đích, **bỏ cache**, **không
  ghi Nhịp điệu học tập**, rồi báo `Đã dịch bằng <engine> · 412 ms` hoặc
  `Không engine nào trả được bản dịch: <lý do>`.

**Vì sao phải "dịch thử" chứ không suy luận từ cấu hình:** chuỗi engine có
fallback (online lỗi → Hy-MT → ML Kit → từ điển), nên chỉ một lượt dịch thật mới
biết engine nào trả lời. Đây cũng là câu trả lời cho "Hy-MT hay ML Kit?".

---

## 7. Thay đổi kỹ thuật trong phiên này

**Dart**

| File | Nội dung |
|---|---|
| `lib/features/screen_translate/screen_translate_controller.dart` | song song có giới hạn, gộp khối trùng, bỏ khối vô nghĩa, cắt vùng + offset bbox, `sourceLanguage`, `onProgress`/`progressText`, `hasTranslatableLetters` |
| `.../screen_translate_geometry.dart` | `ScreenRegion`, `CaptureRegion`, `screenRegionToCapture`, `cropPackedFrame`, `offsetOcrRect` (+ hằng `kMinCaptureRegionEdge`) |
| `.../screen_translate_prefs.dart` | ngôn ngữ nguồn, chế độ kéo chọn vùng, `defaultScreenTranslateTargetForLocale`, `loadScreenTranslateTarget(fallback:)` |
| `.../screen_translate_channel.dart` | `start(source, target, selectRegion)`, `setLanguages`, `setCaptureMode` |
| `.../screen_translate_card.dart` | picker nguồn (AUTO + 26 ngôn ngữ), hoán đổi, công tắc kéo chọn vùng, mặc định theo locale app |
| `.../screen_translate_entrypoint.dart` | nối `onProgress` → `reportProgress`, `TranslationService().warmUp()` |
| `.../screen_translate_models.dart` | hằng giao thức mới (`setLanguages`, `setCaptureMode`, khoá vùng/nguồn) |
| `lib/features/translation/translation_service.dart` | `warmUp()`, `routingOrder`, cache network 5 s, cache plan bước 10 s, `translateText(recordActivity:)` |
| `lib/features/translation/translation_toolbar.dart` | khối "Engine đang hiện hành" + nút kiểm tra engine |
| `lib/core/language/priority_ui_overrides.dart` | 27 khoá mới, đủ `en/hi/zh/zh_TW/si` (quy tắc vàng #5) |

**Kotlin**

| File | Nội dung |
|---|---|
| `RegionSelectView.kt` (mới) | lớp phủ kéo chọn vùng |
| `ScreenTranslateService.kt` | trạng thái bong bóng (nhấp nháy/✓/!), nhãn tiến trình, giữ lâu = chọn vùng, `sourceLanguage`, `pendingRegion`, dọn dẹp an toàn |
| `ScreenTranslatePlugin.kt` | `start` nhận nguồn + chế độ chọn vùng, `setLanguages`, `setCaptureMode` |
| `res/values*/strings_screen_translate.xml` | 8 chuỗi mới (EN mặc định + VI) |

**Test**

- `test/screen_translate/screen_translate_selection_test.dart` (mới): vùng/kẹp/cắt/dời bbox,
  song song ≤ 3, gộp khối trùng, bỏ khối số/ký hiệu, ngôn ngữ nguồn, thứ tự tiến trình,
  `progressText` không còn tiếng Việt khi locale `en`.
- `test/screen_translate/screen_translate_prefs_test.dart`: chuẩn hoá nguồn, khoá lưu,
  mặc định đích theo locale.

### 7.1 Vá sau khi rà soát tĩnh (lượt 2, cùng ngày)

Không có Flutter/Android SDK trong sandbox nên phần dưới đây là **soát bằng
đọc code + script**, không phải kết quả biên dịch. Mỗi mục đều là lỗi thật nếu
để nguyên:

| Vá | Vì sao |
|---|---|
| `RegionSelectView`: `area.isEmpty` → `area.isEmpty()` | `Rect.isEmpty` là **hàm** của Android, viết như thuộc tính là lỗi biên dịch Kotlin ⇒ cả module không build được |
| `ScreenTranslateService`: `!region.isEmpty` → `!region.isEmpty()` | cùng lỗi, nằm ngay trên đường gửi frame (mọi lượt dịch đều đi qua) |
| `ScreenTranslateService`: bỏ smart-cast trên `intent` khi đọc `EXTRA_SELECT_REGION` | service có thể bị hệ thống khởi lại với `intent == null`; smart-cast làm hỏng build (và crash nếu lọt) |
| `RegionSelectView`: bỏ `import kotlin.math.min` trùng | trùng import là rác, dễ che lỗi thật khi đọc |
| `screen_translate_channel.start(locale:)` + card truyền `_appLocaleCode` | `EXTRA_LOCALE` có trong native nhưng **chưa ai gửi** ⇒ engine nền luôn dùng `vi`: UI tiếng Anh vẫn thấy nhãn tiếng Việt (vi phạm quy tắc vàng #5) |
| `_swapLanguages`: chặn cặp trùng + AUTO→EN | trước đó `AUTO→EN` hoán đổi ra `EN→EN` (engine coi là "cùng ngôn ngữ", trả nguyên văn) |

**Hai điểm từng để mở, nay đã chốt:**

- `screen_translate_region_cancelled` **được dùng** cho nhánh chạm suông trên
  lớp phủ chọn vùng (và nhánh huỷ từ bong bóng nếu lớp phủ chưa kịp phủ);
  `region_too_small` dùng đúng cho nhánh kéo quá bé — hai câu khác nhau vì
  một cái là "tôi đổi ý", một cái là "kéo chưa đủ". Không còn khoá
  nào định nghĩa mà không dùng (script đối chiếu `R.string.*` ↔ 2 file XML: 28
  khoá, khớp 100%, không thừa/thiếu ở cả `values` và `values-vi`).
- `routingOrder` **giữ nguyên** việc liệt kê ML Kit và **Offline Dictionary**
  (`_offlineEngine.name`): đó đúng là thứ tự chuỗi engine thật
  (`_runEngineChain`), kể cả khi chúng hiếm khi được dùng. Ẩn đi sẽ là "đoán",
  đúng thứ owner phàn nàn. (Cache `💾 Cache` nằm TRƯỚC chuỗi, chỉ hiện ở dòng
  "Lần trước" nếu lượt trước ăn cache.)

---

## 8. Trạng thái kiểm chứng (đừng đọc thành "đã xanh")

| Việc | Trạng thái |
|---|---|
| Soát cú pháp Dart (cân bằng ngoặc/chuỗi/comment 11 file) | ✅ chạy bằng script, sạch |
| Đối chiếu API test ↔ code (`OcrBlock`, `OcrBlocksResult`, `TranslationResult.success`, `ScreenRegion`, `cropPackedFrame`, prefs, `defaultScreenTranslateTargetForLocale`…) | ✅ đọc tay từng chữ ký |
| Đối chiếu `R.string.*` ↔ XML (en + vi) | ✅ 28/28 khoá, 0 thừa |
| i18n: 27 khoá mới đủ 5 locale, không lẫn tiếng Việt ở locale ≠ vi | ✅ script |
| Nguồn chuỗi tiếng Việt mới đều có trong catalog (kể cả `generated_legacy_ui_fallbacks`) | ✅ script (trừ chuỗi log `debugPrint`) |
| Rebase lên `arena/01a0251e-in4up` (251e) mới nhất | ✅ rebase sạch, tuyến tính 6 commit; 3 xung đột đã hợp nhất tay (xem 8.1) |
| `flutter analyze` / `flutter test` / Gradle build | ❌ **chưa chạy** — sandbox không có SDK |
| Máy thật (10 mục dưới) | ❌ **chưa chạy** |

### 8.1 Xung đột khi rebase lên 251e — cách hợp nhất

251e (từ 3f8197a) đã đổi **cùng 3 file** với XLAT-SCR-005. Không dùng
"ours/theirs" cho nhanh: cả ba chỗ đều phải GIỮ CẢ HAI bên.

| File | 251e đã làm gì | Hợp nhất thế nào |
|---|---|---|
| `screen_translate_card.dart` | SETTINGS-UI-COMPACT-001: mô tả dài → 1 dòng có icon, nhãn "Ngôn ngữ đích" dùng icon + `bodyMedium` | Giữ phong cách gọn của 251e nhưng vẫn đủ **hai cột** nguồn/đích: nhãn mỗi cột thành `_LanguageLabel` (icon 14 + `bodySmall`) thay vì 2 kiểu nhãn khác nhau; nút ⇄ nằm giữa. Nút nguồn đặt trong `SizedBox(width: double.infinity)` để label dài (`TextOverflow.ellipsis`) không tràn cột |
| `priority_ui_overrides.dart` | +61 khoá (từ điển/STT/settings) chèn ở CÙNG vị trí cuối map | Giữ nguyên 61 khoá của 251e rồi nối 27 khoá XLAT-SCR-005 sau; kiểm bằng script: 79 (251e) + 27 = **106 khoá, 0 trùng**, và 0 giá trị locale ≠ vi còn ký tự tiếng Việt |
| `docs/project/KANBAN.md` | +3 card STT/DICT ở cuối file | 3 card của 251e giữ nguyên, card `XLAT-SCR-005`/`XLAT-SCR-006` nối sau |

Sau rebase đã chạy lại toàn bộ kiểm tĩnh (mục 8 ở trên) trên cây đã hợp nhất —
không chỉ tin vào "rebase không báo lỗi".

---

## 9. Nghiệm thu trên máy thật (checklist)

1. Bật bong bóng → bấm: bong bóng **tím + nhấp nháy + "…"**, nhãn dưới bong bóng
   đổi "Đang nhận dạng chữ…" → "Đang dịch k/N khối…", kết thúc **✓ xanh**.
2. Bấm khi đang dịch: toast "Đang dịch màn hình trước…" (không im lặng).
3. Giữ lâu bong bóng (450 ms) → hiện khung chọn; kéo một đoạn văn → chỉ đoạn đó
   được dịch; **không sập**; vùng < 28dp → huỷ + thông báo.
4. Bật công tắc "kéo chọn vùng" → mọi lần bấm đều mở khung chọn (kể cả sau khi
   tắt/bật lại bong bóng trong cùng phiên).
5. So sánh thời gian: dịch cả màn hình vs chọn 1 đoạn (ghi lại số giây + số khối).
6. Đổi nguồn `Tự nhận diện → Tiếng Nhật`, đích `Tiếng Việt`, mở trang tiếng Nhật
   → bản dịch đúng; bấm **⇄** (VI→JA) → dịch ngược được.
7. Đổi ngôn ngữ khi bong bóng **đang chạy** → lượt bấm kế tiếp dùng cặp mới.
8. Mở **⚙️ Engine dịch thuật** → thấy chip Online/Chỉ offline, thứ tự ưu tiên,
   "Lần trước", model đã có; bấm **Kiểm tra engine ngay** → có engine + ms.
9. Bật "Chỉ dùng dịch offline" + xoá model ML Kit → kiểm tra engine phải báo
   thiếu model (không im lặng).
10. Tắt/bật lại bong bóng, xoay màn hình giữa lúc dịch — không crash, không kẹt
    khung chọn.

---

## 10. Việc còn lại / đề xuất (đã ghi vào KANBAN)

| Card | Nội dung | Ưu tiên |
|---|---|---|
| `XLAT-SCR-005` | Nâng cấp trong phiên này (Q1, Q3–Q6) | P1 — chờ CI + máy thật |
| `XLAT-SCR-006` | Nhà sưu tầm từ vựng (G1 chạm khối → lưu Wordlist; G2 trích từ; G3 gợi ý theo tần suất) — cần ADR vì overlay phải nhận chạm | P2 (sau khi Q4 ổn định trên máy) |
| `XLAT-SCR-007` (đề xuất) | Dịch **batch** nhiều khối/1 request + "live mode" khi nội dung đổi | P2 |
| `XLAT-SCR-008` (đề xuất) | Nói rõ quyền riêng tư: ảnh màn hình đi đâu khi dùng engine online | P2 |

**Câu hỏi mở cần chủ dự án chốt:**

1. Có muốn **mặc định bật** "kéo chọn vùng" (thay vì tắt) không? Hiện tắt để giữ
   hành vi cũ; người mới có thể không biết có tính năng.
2. Có muốn **dịch cả màn hình song song 4–5 luồng** cho nhanh hơn, đổi lại nguy
   cơ 429 của Google Free không? Hiện chọn 3.
3. Với "nhà sưu tầm từ vựng": lưu **cụm từ** hay **từng từ**? (đề xuất: cả hai,
   mặc định cụm, có nút tách từ)
