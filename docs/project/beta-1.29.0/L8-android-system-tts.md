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

## Phát hiện thêm

_(trống)_
