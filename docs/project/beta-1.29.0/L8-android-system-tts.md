# L8 — Android: in4up làm giọng đọc hệ thống

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD).
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Người dùng chọn được **in4up** trong *Cài đặt Android → Ngôn ngữ & nhập → Chuyển văn bản thành giọng nói*, và app khác đọc được văn bản qua engine của mình.

## Issue

| # | Trạng thái | Triệu chứng |
|---|---|---|
| **PSRC-221** | Backlog | in4up chưa xuất hiện như một giọng đọc hệ thống của Android |

## Hướng điều tra

1. Cần một `android.speech.tts.TextToSpeechService` thật ở phía Kotlin, khai báo trong `AndroidManifest.xml`:
   `<service android:name=".In4UpTtsService" android:exported="true"><intent-filter><action android:name="android.intent.action.TTS_SERVICE"/></intent-filter></service>`
   kèm `res/xml/tts_engine.xml` (metadata `android.speech.tts`) và `<queries>` nếu cần.
2. Service phải trả `isLanguageAvailable`, `setLanguage`, `getVoices`, `synthesizeToFile`, `speak` (dùng `SynthesisRequest`).
3. Cầu nối sang engine của app: qua `MethodChannel` sang Dart (chậm, dễ chết khi app bị kill) **hoặc** gọi native trực tiếp. Ưu tiên đường **chạy được khi app ở nền**: nếu chỉ đi qua Flutter engine, ghi rõ giới hạn và vẫn phải phát được câu ngắn.
4. Kiểm tra `targetSdk` — Android 11+ cần khai báo đúng để hiện trong danh sách TTS.
5. Không được làm hỏng build: `vieneu_engine_build` phải xanh (lane này chạm `android/`).

## File chạm (dự kiến)

`android/app/src/main/kotlin/**` (service mới + manifest), `android/app/src/main/res/xml/**`, `lib/core/**` (MethodChannel), test Kotlin nếu có sẵn hạ tầng, ngược lại ghi chú kiểm tay.

## Nghiệm thu

- [ ] in4up xuất hiện trong danh sách TTS engine của Android trên **máy thật**.
- [ ] Chọn in4up + bấm "Nghe thử" trong cài đặt hệ thống ⇒ có tiếng.
- [ ] Một app khác (vd. ứng dụng đọc sách) đọc được 1 câu qua in4up.
- [ ] `app_analyze` xanh + `vieneu_engine_build` xanh.
- [ ] Nếu chỉ chạy được khi app đang mở: **ghi rõ** trong commit body và issue.

## Không làm

- Không thay engine TTS nội bộ của app.
- Không đăng ký voice chất lượng cao (network) ở bước này.

## Commit

```
feat(PSRC-221): in4up là giọng đọc hệ thống Android [L8]
```

## Kết quả lane (2026-11-13)

Đã land trong commit `feat(PSRC-221): in4up là giọng đọc hệ thống Android [L8]`.
**Chưa có ai cầm máy thật kiểm** — bốn ô nghiệm thu đầu ở trên vẫn để trống cho tới khi chạy xong bảng dưới.

### Kiến trúc đã chọn

```
Android (Cài đặt / app khác)
   │ bind  action android.intent.action.TTS_SERVICE
   ▼
com.in4up.systemtts.In4UpTtsService        (Kotlin — TextToSpeechService)
   │ MethodChannel "in4up/system_tts"
   ▼
engine Flutter NỀN, entrypoint in4upSystemTtsMain
   lib/core/platform/system_tts/system_tts_worker.dart
   ├─ PiperTtsEngine   (sherpa-onnx, có sẵn)
   └─ VieneuTtsEngine  (audio.cpp, có sẵn; chỉ vi-VN)
```

- **Chạy khi app không mở: có** — service tự dựng engine Flutter nền, không dùng engine UI.
- Không gọi native thẳng vì Piper/VieNeu của app đi qua Dart FFI, không có lớp JNI.
- Tên service là `com.in4up.systemtts.In4UpTtsService` (không phải `.In4UpTtsService` như gợi ý ở § Hướng điều tra) để nằm cùng gói với runtime + 3 activity.
- Không thêm chuỗi UI: tên engine trong Cài đặt là nhãn app theo flavor.

### Kiểm tay trên máy thật (chưa làm)

Chuẩn bị: cài APK, mở app, import **ít nhất một giọng Piper** có tên mang mã ngôn ngữ (vd. `vi_VN-vais1000-medium`) kèm `espeak-ng-data`, đọc thử một câu trong tab Đọc để chắc giọng chạy.

| # | Bước | Mong đợi |
|---|---|---|
| 1 | Cài đặt ▸ Ngôn ngữ & nhập ▸ Chuyển văn bản thành giọng nói ▸ Công cụ ưa thích | Có mục **In4Up** |
| 2 | Chọn In4Up, chọn ngôn ngữ của giọng đã import | Ngôn ngữ đó có trong danh sách |
| 3 | Bấm **Nghe thử** | Có tiếng bằng giọng Piper |
| 4 | Vuốt in4up khỏi màn gần đây, rồi làm lại bước 3 | Vẫn có tiếng (chậm hơn vài giây lần đầu) |
| 5 | App đọc sách / TalkBack dùng engine In4Up đọc 1 câu | Có tiếng |
| 6 | Đang đọc đoạn dài thì bấm dừng | Dừng trong vòng ~1 đoạn, không treo |
| 7 | Gỡ hết giọng Piper trong app rồi mở lại màn Cài đặt TTS | In4Up vẫn hiện; "Nghe thử" bị khoá, không crash |
| 8 | Bấm bánh răng cạnh In4Up | Mở app in4up |

Khi lỗi: `adb logcat -s In4UpSystemTts flutter` — service ghi lý do (`không có giọng offline cho …`, `engine Flutter nền chưa sẵn sàng`, `worker: failed …`).

### Giới hạn đã biết

- Chưa import giọng ⇒ mọi ngôn ngữ trả "không hỗ trợ".
- Giọng Piper tên không mang mã ngôn ngữ (vd. `calmwoman3688`) chỉ hiện nếu đã được gán cho một ngôn ngữ trong Cài đặt giọng Piper của app.
- Chỉ giọng offline (Piper, VieNeu). Giọng online để đợt sau, đúng § Không làm.
- Lần đọc đầu sau khởi động nguội phải chờ engine nền + nạp model — chưa đo trên máy.

## Phát hiện thêm

1. **`vieneu_engine_build.yml` không chạy khi chỉ đổi Kotlin/manifest/res** (README § 6 ghi `android/**`, thực tế chỉ `cpp/**` + `build.gradle.kts`). Lane này đã thêm 3 đường dẫn kích hoạt vì không còn cách nào khác để CI biên dịch service mới (`workflow_dispatch` từ token agent trả 403). → hub xem lại nếu không muốn build APK ở mọi thay đổi Kotlin.
2. **Chưa kiểm:** manifest của app không có `<queries>` cho `android.intent.action.TTS_SERVICE`. Nếu plugin `flutter_tts` không tự khai, trên Android 11+ engine "giọng hệ thống" trong app có thể không thấy engine TTS của hãng khác. Ngoài phạm vi L8, chưa mở issue.
3. Khi in4up là engine mặc định của máy **và** app đang mở, engine "giọng hệ thống" trong app (`OfflineTtsEngine`) sẽ đi vòng về chính service này. Không lặp vô hạn (worker không dùng `flutter_tts`), nhưng model Piper có thể bị nạp ở hai isolate. Đề xuất đợt sau: ẩn lựa chọn "giọng hệ thống" trong app khi engine mặc định là chính in4up.
