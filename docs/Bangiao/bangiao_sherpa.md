# Bàn giao — Sherpa (VAD · TTS Piper · Speaker waveform · Voice commands)

> Đây là file bàn giao DUY NHẤT cho chức năng sherpa. Khi mở nhánh mới để giao
> việc tiếp theo, đọc toàn bộ file này trước — nó ghi rõ **đã làm gì, phải làm
> gì, sẽ làm gì** và các bẫy không được lặp lại.

## Chỉ mục nhanh (đọc bắt buộc)

- `docs/GOVERNANCE.md` — luật quản trị (status-only + append, không xóa).
- `docs/project/PLAN.md` — **PLAN-008** (lộ trình sherpa), **PLAN-009** (tinh hoa
  Google cabin), **PLAN-022** (bàn giao WP2/WP3 — bản chuẩn đã làm/phải làm/sẽ làm).
- `docs/project/KANBAN.md` — **SHERPA-001/002/003**, **SHERPA-WP23-01** (trạng thái
  + commit + CI chính thức).
- `docs/project/MODELS.md` — trung tâm model (VAD/Piper/AI Chat GGUF).
- `lib/features/vad/README_VAD_TTS_STREAMING.md` — định hướng format model Whisper
  `.bin` / Sherpa `.onnx` + pipeline streaming.
- `docs/skills/i18n-localization/SKILL.md` + `docs/skills/ci-red-debugging/SKILL.md`
  — bắt buộc đọc khi thêm/sửa UI hoặc khi CI đỏ (kèm `scripts/ci_check.sh`).

## 1. Tóm tắt

- **Nguồn:** owner (2026-09-03), triển khai trên session `arena/01a039e9-in4up`;
  code đã thâu hoạch vào DEV (tip `arena/01a0251e-in4up`) qua cherry-pick `-x`.
- **Trạng thái:** code done + CI xanh — **chờ nghiệm thu thiết bị**. Các việc còn
  lại làm trên **nhánh mới từ tip DEV**, KHÔNG cherry-pick lại từ `01a039e9`.
- **KANBAN:** `SHERPA-WP23-01` = cherry-pick `-x` `4cdaffb` → `01f5235` + fix scope
  `8c2e868`; CI xanh run `33336160268`.

## 2. Đã làm (đang chạy trong DEV)

### 2.1 SHERPA-001 — Silero VAD (sherpa_onnx) thay EnergyVad fallback
- `4a50a77` + `cd9cccf` (chờ nghiệm thu thiết bị).
- `SherpaVadCore` (in4up_stt) verify API sherpa_onnx v1.13.4; singleton, absolute
  path, chỉ load module VAD nhẹ 2–5MB; EnergyVad chỉ còn là fallback khi thiếu
  `silero_vad.onnx` hoặc sherpa lỗi.

### 2.2 SHERPA-002 — TTS Piper offline (sherpa_onnx)
- CI run `32524455212` (chờ nghiệm thu build).
- `SherpaPiperTtsCore` bọc `OfflineTts` Piper + engine trong `TtsService`; model
  ở `<documents>/sherpa_piper_models/` (`<voice>.onnx` + `<voice>_tokens.txt`).
- FFI: `ensureSherpaBindings()` singleton dùng chung VAD/TTS/STT — KHÔNG re-init,
  tránh xung đột whisper.cpp + sherpa_onnx.

### 2.3 SHERPA-003 — VAD pipeline file dài 30p
- `43c3545`; CI run `32617775840` (chờ nghiệm thu thiết bị).
- Cắt chunk FFmpegKit (Android) + quét async (`SherpaVadCore.detectAsync()` yield
  mỗi 256 frame + onProgress) + guard (không chặn main isolate).

### 2.4 SHERPA-WP23-01 — WP2: waveform màu theo người nói
- Parse timestamp LRC khi load → `WaveformSegmentRef` (joinKey = ContentId.joinKey)
  + `SpeakerSidecar.loadSpeakerMap` (sidecar `.spk` cạnh LRC — offline overlay,
  **không** re-run STT).
- Truyền `speakerColorMap` vào `RollingWaveformView` + legend "Người N"; file cũ
  không có sidecar → fallback mono (không crash).

### 2.5 SHERPA-WP23-01 — WP3: voice commands qua STT facade
- `lib/features/voice_command/`: parser **thuần** 8 nhóm lệnh VI/EN (+ không dấu):
  phát / tạm dừng / tiếp theo / bài trước / nhanh hơn / chậm hơn / ẩn lời / dịch.
- `VoiceCommandService` dùng **duy nhất** `SttServiceFacade.startListening()` +
  `partialResultStream`; **một** mic session; first-match debounce; silence 1.5s /
  max 6s; dispose subscription/timer/mic sạch.
- UI: mic button + indicator + partial preview trên Stack waveform tab Nghe.
- i18n: English fallback hợp lệ + VI/HI/ZH-Hans/ZH-Hant/SI (không fallback về `vi`).

### 2.6 Fix scope (`8c2e868`)
- `4cdaffb` đặt voice button vào `GenerateLrcButton` (StatelessWidget độc lập)
  nhưng dùng state của `_ListenModeScreenState` → undefined name. Đã khôi phục nút
  Shadowing gốc + chuyển voice button vào Stack waveform (top-right, ẩn khi isLoading).

### 2.7 Trạng thái CI
- `SHERPA-WP23-01`: CI xanh run `33336160268` (App Analyze + Locale).
- Chờ nghiệm thu thiết bị của owner (mục 3).

## 3. Phải làm (nghiệm thu thiết bị TRƯỚC khi code tiếp)

- [ ] Lệnh giọng nói "phát / tạm dừng / tiếp theo / bài trước / nhanh hơn / chậm
      hơn / ẩn lời" trên audio **có LRC** hoạt động đúng.
- [ ] Thiếu model STT → hiện "No speech model available" (không crash, không im lặng).
- [ ] WP2: audio đã qua STT pipeline (sidecar `.spk` tạo tự động) hiện nhiều màu
      speaker; file cũ không sidecar không crash.
- [ ] SHERPA-002: build + push model Piper vào thiết bị, nghiệm thu TTS offline.

## 4. Sẽ làm (nhánh mới, sau khi nghiệm thu xanh — MỖI NHÁNH CHỌN 1)

- **WP3 action `translate`:** nối lệnh "dịch" vào provider toggle translation —
  **CHỈ** nối sau khi owner xác nhận API của provider; không giả lập hành vi
  (known limitation bàn giao).
- **WP-Z (có thể không làm):** sidecar desktop `yt-dlp` khi explode gãy — chỉ khi
  user đã cài, không binary trong APK, không chạy trong CI.
- **Meetily Rust/Zipformer:** KHÔNG chờ — pipeline hiện dùng `SttServiceFacade`;
  nếu có thì là engine bổ sung, không thay kiến trúc.
- **Nâng cấp diarization:** thay `HeuristicDiarizationService` bằng model thật
  (pyannote…) khi có model — sidecar chất lượng hơn.

## 5. Cấm / bẫy (từ bàn giao — KHÔNG được lặp lại)

- Không khai báo trùng `_voiceCommandService`, `_voiceListening`, `_lastVoiceText`,
  `_startVoiceCommands` — mọi field/method nằm trong `_ListenModeScreenState`.
- Không chèn snippet vào file bằng mắt khi đã có conflict — kiểm tra `git diff`.
- Không sửa `.github/workflows/`; docs bị ignore thì `git add -f`.
- Không bịa URL/model Zipformer; không auto-download model.
- Một phiên voice chỉ fire command đầu tiên; dispose subscription/timer/mic sạch.
- CI là oracle (skill `docs/skills/ci-red-debugging/SKILL.md`); chạm path app để
  paths-filter trigger đúng workflow.
- Sandbox có thể không có Flutter SDK — kiểm tra API `dart:io`/`dart:async` trước
  khi kết luận; dùng CI để xác nhận analyze/test.

## 6. Cách mở nhánh mới để giao việc

1. **Branch mới từ tip DEV** (`arena/01a0251e-in4up`). Code WP2/WP3 **đã có sẵn**
   trong DEV — KHÔNG cherry-pick lại từ `01a039e9`.
2. **Prompt topic** trỏ `docs/Bangiao/bangiao_sherpa.md` + mục 3/4 của **PLAN-022**
   (chọn đúng 1 việc duy nhất) + quy trình harvest/CI như PLAN-020 mục 5.
3. **Ràng buộc trong prompt:** đọc skills i18n-localization + ci-red-debugging;
   giữ parser pure + test hiện có; không đổi grammar nếu không có lý do; i18n
   VI/HI/ZH-Hans/ZH-Hant/SI ngay từ đầu.
4. **Báo cáo khi xong (checklist bắt buộc):**

   ```
   WP DONE
   - Branch/SHA:
   - Harvest source:
   - CI run:
   - AT đạt/chờ thiết bị:
   - Known limitation:
   - Files:
   ```

5. Gửi SHA cho owner/leader để review → cherry-pick/harvest → nghiệm thu thiết bị.
   **Không tuyên bố done nếu chỉ có code mà chưa báo trạng thái CI trung thực.**

## 7. Tài liệu tham khảo

- `docs/project/PLAN.md` — PLAN-008 (lộ trình VAD → Live STT → TTS → STS cabin),
  PLAN-009 (Gemini/Gemma cabin), PLAN-022 (chuẩn bàn giao WP2/WP3).
- `docs/project/KANBAN.md` — SHERPA-001/002/003, SHERPA-WP23-01, MODELS-001.
- `lib/features/vad/README_VAD_TTS_STREAMING.md` — format model + streaming.
- `lib/features/voice_command/` — code WP3 (parser + service + widget).
- `packages/in4up_stt/` — sherpa VAD/TTS core + diarization.

## Lịch sử bàn giao

- 2026-09-03 | created | owner via session `arena/01a039e9-in4up` | bàn giao WP2/WP3.
- 2026-09-03 | harvest | agent `arena/01a0251e-in4up` | cherry-pick `-x` `4cdaffb`
  → `01f5235` + fix scope `8c2e868`; CI xanh `33336160268`; PLAN-022 + KANBAN
  `SHERPA-WP23-01` ghi rõ đã làm/phải làm/sẽ làm.
- 2026-09-03 | restructure | agent `arena/01a06915-in4up` | gom các file dồn trước
  đây (prompt handoff + KANBAN + PLAN-019/020 + fallback dump) thành 1 bàn giao
  chuẩn mục đã/phải/sẽ để nhánh mới đọc là hiểu.
