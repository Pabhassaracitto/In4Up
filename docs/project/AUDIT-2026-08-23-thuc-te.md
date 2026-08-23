# AUDIT 2026-08-23 — Nghiệm thu thực tế các chức năng + kết quả điều tra VAD file 30p

> Đối tượng: chủ dự án chạy trên thiết bị thật (Android tablet + phone).
> Nguồn build: **branch `arena/01a0251e-in4up`** (commit `43c3545` trở đi) —
> ⚠️ KHÔNG build từ `origin/main`: main đã MẤT wave 1 ngôn ngữ do merge
> (xem mục C).

## 0. Bật log theo dõi (làm 1 lần)

Kết nối máy qua USB + `adb`, mở app, rồi theo dõi log:

```bash
adb logcat -c && adb logcat | grep -E "Silero VAD|EnergyVadFallback|VAD Pipeline|Chunk cut|Whisper|Piper|Sherpa" 
```

Mọi bước bên dưới đều có **chữ log bắt buộc** phải thấy — không thấy đúng
chữ đó là FAIL, ghi lại nguyên văn gửi lại.

---

## A. Chức năng cần check

### A1. VAD + tạo lời file DÀI (30 phút) — ★ vấn đề owner báo

**Làm:** Tab Nghe → chọn file audio 30 phút (mp3/m4a) → bấm tạo lời.

**Đúng (sau fix 43c3545) phải thấy tuần tự:**

| # | Bước | Log bắt buộc | Sai thì |
|---|---|---|---|
| 1 | File >5MB → pipeline VAD | `[SttMixin] File lớn (...) >5MB, chuyển sang VAD pipeline tối ưu` | File bị đi đường Whisper trực tiếp (chậm, không skip silence) |
| 2 | Có model Silero | `✅ VAD model found at absolute path: .../sherpa_vad_models/silero_vad.onnx` | Thấy `ℹ️ Sherpa VAD model not found` → đang dùng fallback (không skip silence thật) — cần push model (mục D) |
| 3 | **Quét VAD có tiến độ** (không đơ) | `Đang quét VAD… 10%` … `Đang quét VAD… 100%` (thanh tiến độ NHẢY dần trên UI) | UI đơ im ở "Đang quét mốc thời gian im lặng/tiếng nói" → fix chưa vào bản build |
| 4 | Kết quả VAD | `✅ Silero VAD: <tên file> → N speech segments (Xs speech)` — với file 30p có nhiều khoảng lặng, **X phải RÕ RỆT < 1800s** | X ≈ 1800s (toàn bộ) → VAD không loại được silence |
| 5 | **Cắt chunk trên Android** (fix chính) | `✅ Chunk cut OK: .../vad_chunks/chunk_... size=...` cho từng chunk | Thấy `❌ Chunk cut failed @...` + `⚠️ Segment ...: không cắt được chunk` → FFmpegKit lỗi trên máy đó (gửi log + model máy) |
| 6 | Whisper từng chunk | `🎙️ Chunk i/N: ...` + `[Whisper] Chunk i xong Xms - Y% - ETA` — **i/N với N = số đoạn speech (vài chục), KHÔNG phải ~120 chunk × lặp đi lặp lại** | Cùng `Chunk 1/...` lặp lại nhiều lần = bug cũ (re-transcribe toàn file) chưa hết |
| 7 | Hoàn tất | `🏁 VAD Pipeline hoàn tất: N segments, time=Xs, skippedSilence=M` | — |

**Thước đo:** file 30 phút có ~50% khoảng lặng phải xong trong
**~2-4 phút** trên tablet tầm trung (trước fix: hàng giờ + đơ + crash).
Nếu file 30p mà `time=Xs` trong log xong là >10 phút → gửi log.

**Crash:** nếu app vẫn chết trong lúc tạo lời → mở
`adb logcat -b crash` ngay sau khi chết, gửi nguyên văn.

---

### A2. VAD file ngắn (<60s, <5MB) — đường cũ không bị ảnh hưởng

**Làm:** tạo lời cho file 30-60s.
**Đúng:** không thấy `chuyển sang VAD pipeline` (đi đường Whisper trực tiếp),
lời hiện dần từng chunk (`Đang nhận diện chunk i/N`), LRC khớp tiếng.

---

### A3. TTS Piper offline (SHERPA-002)

**Cần push model trước (mục D).** Sau khi push:

1. **Settings → Text-to-Speech**: thấy dòng `Piper (Offline Neural)` trong
   "Thứ tự nguồn phát" (có công tắc bật/tắt) + chip trạng thái
   `Piper (offline)` màu XANH (có model) / ĐỎ (thiếu model).
2. **Phát 1 câu tiếng Anh** (file EL hoặc từ vựng): log đúng chính xác là
   `🎙️ SherpaPiperTtsCore: giọng "<tên giọng>" sẵn sàng (22050Hz)`;
   UI `lastUsedEngine` = `🎙️ Piper` (không phải `📖 Offline`).
   Nghe: giọng neural (không phải giọng máy Android).
3. **Tắt mạng (airplane mode)** rồi phát lại → vẫn phát bằng Piper
   (offline hoàn toàn — yêu cầu cabin).
4. **Tắt công tắc Piper** trong settings → phát → dùng giọng máy
   (pipeline không gãy).
5. Tiếng Việt: nếu chỉ có giọng EN → Piper không nhận (báo
   `Không có giọng Piper khớp vi-VN`) → tự rơi giọng máy/online. Muốn TTS
   Piper tiếng Việt phải push thêm model Piper vi (vd `vi_VN-...`).

**Log khi thiếu model:** `⚠️ SherpaPiperTtsCore: thiếu thư mục
espeak-ng-data` hoặc `Chưa có model Piper — push <voice>.onnx ...`.

---

### A4. Ngôn ngữ HI/ZH/SI (LANG-630-01 wave 1)

**Làm:** Settings → đổi ngôn ngữ app sang **Hindi / Chinese / Sinhala**.

| Check | Đúng |
|---|---|
| Toàn bộ chrome (nút, tab, sheet, empty state) | Viết bằng Devanagari / Hán / Sinhala — KHÔNG còn tiếng Anh (trừ brand: YouGlish, Dharma, CEFR...) và KHÔNG BAO GIỜ tiếng Việt |
| VD `commonConfirm` (nút Xác nhận) | Hindi: `पुष्टि करें` · ZH: 确认 · SI: ඇනුම කරන්න |
| Chuyển về English | Chrome tiếng Anh sạch |
| locale chưa dịch hết (vd Bengali/Arabic ~40%) | Phần thiếu hiện **English**, không phải tiếng Việt |

⚠️ **Nếu build từ `origin/main`** → chrome HI/ZH/SI vẫn tiếng Anh =
KHÔNG LỖI APP — là do main mất wave 1 (mục C). Build lại từ
`arena/01a0251e-in4up`.

---

### A5. STT model + chữ viết tay (commit của owner trên nhánh)

1. **Tải model STT khi bấm** (`6388114`): Home → Quản lý Model AI →
   bấm tải → chỉ báo hướng dẫn, không tự download HuggingFace;
   model có trong máy → dùng được ngay.
2. **Chấm viết 2 tầng** (`dfe81f7`) + **sổ tay chữ** (`fc824f6`/`SO_TAY_CHU.md`):
   Tab Viết → bài viết tay → chấm điểm (2 tầng) + mở sổ tay chữ xem mẫu.
   (Chi tiết theo `SO_TAY_CHU.md` trong repo.)

---

## B. Kết quả điều tra VAD 30p (trả lời câu hỏi "đã áp dụng chưa?")

**Câu trả lời ngắn:**Routing + Silero VAD + offset corrector **đã áp dụng**;
nhưng **bước chuyển chunk trên Android bị hỏng** nên việc "skip khoảng lặng"
**chưa từng phát huy tác dụng trên máy Android** — tệ hơn: nó khiến mỗi
đoạn speech re-transcribe TOÀN BỘ file → đơ + duplicate + OOM. Đã sửa
(commit `43c3545`, CI xanh run 32617775840).

| Hạng mục | Trạng thái TRƯỚC fix | Sau fix |
|---|---|---|
| File >5MB → pipeline VAD | ✅ đã áp dụng | giữ |
| Silero VAD thật (không phải Energy giả) | ✅ đã áp dụng (khi có model) | giữ + quét **async** (không đơ UI) + progress |
| **Cắt chunk theo segment** | ❌ **hỏng trên Android** (tìm ffmpeg CLI — Android không có) → fallback file gốc | ✅ `AudioConverter.cutSegment()` qua **FFmpegKit** (mobile)/Process (desktop) — cùng đường đã chứng minh |
| Re-transcribe toàn file khi cut lỗi | ❌ không có guard | ✅ **bỏ qua segment** (log cảnh báo), không chạy lại 30p |
| UI đơ khi quét VAD 30p | ❌ `detect()` đồng bộ chặn main isolate | ✅ `detectAsync()` yield mỗi ~8s audio + "Đang quét VAD… N%" |
| Offset corrector (chunk time + segment start) | ✅ đã áp dụng | giữ |
| Cleanup chunk temp + nhường event loop | ✅ đã áp dụng | giữ |

**Hạn chế còn lại (tương thích, không crash):**
- File `.wav` KHÔNG phải 16kHz mono → Silero từ chối (an toàn) → fallback
  chia 14s đều, **không skip silence thật** → lời vẫn ra nhưng chậm hơn.
  → Khuyến nghị: giữ audio dạng mp3/m4a hoặc wav 16k.
- Thiếu `silero_vad.onnx` → fallback chia đều 14s (không skip silence thật).
- Quét VAD 30p vẫn tốn CPU (Silero inference) nhưng UI không đơ nữa.

---

## C. ⚠️ Lưu ý merge `origin/main` (LANG wave 1 bị mất ở main)

Agent nhánh `arena/01a0296a-in4up` đã kiểm chứng `origin/main` sau merge
của owner: `commonConfirm(hi)="Confirm"`, 222/376 message vẫn EN,
`language_roadmap.dart` + test + rule #5 AGENTS **không tồn tại** → bản build
từ main KHÔNG chứa wave 1.

- Branch `arena/01a0251e-in4up` (branch này) **nguyên vẹn**: wave 1 +
  TTS Piper + VAD fix đủ bộ (đã verify code + CI xanh 32617775840).
- Muốn main có đủ: merge `arena/01a0251e-in4up` vào main (hoặc
  `arena/01a0296a-in4up`) — theo ADR-0002 + KANBAN LANG-630-01.
- English còn lại sau merge ĐÚNG (hợp lệ) = key keep-English
  (YouGlish, Dharma, demo...) + 1625 entry legacy fallback (wave 2).

---

## D. Model cần push vào thiết bị (trước khi nghiệm thu)

Android: `documents = /sdcard/Android/data/<app>/documents/`
(release: `com.in4up` · dev: `com.in4up.dev` · beta: `com.in4up.beta`)

| Model | Đường dẫn | Kích thước | Dùng cho |
|---|---|---|---|
| Whisper tiny q4_0 | `in4up_whisper_models/ggml-tiny-q4_0.bin` | ~37MB | STT (bắt buộc) |
| Silero VAD | `sherpa_vad_models/silero_vad.onnx` | 2-5MB | VAD skip silence (A1) |
| Piper (EN) | `sherpa_piper_models/`: `espeak-ng-data/` + `<voice>.onnx` + `<voice>_tokens.txt` [+ `<voice>.onnx.json`] | ~75MB/voice | TTS offline (A3) |

Kiểm tra nhanh qua adb:
```bash
adb shell ls /sdcard/Android/data/com.in4up/documents/
adb shell ls /sdcard/Android/data/com.in4up/documents/sherpa_vad_models/
adb shell ls /sdcard/Android/data/com.in4up/documents/sherpa_piper_models/
```

## E. Nếu FAIL — gửi lại gì

1. Nguyên văn log (adb logcat) từ lúc bấm đến khi FAIL (theo bảng log
   bắt buộc mục A).
2. `adb logcat -b crash` nếu app chết.
3. Model máy + RAM (Settings → About / `adb shell getprop ro.product.model
   ro.product.cpu.abi` + RAM), tên file audio + độ dài + bitrate,
   build flavor (release/dev/beta) + commit hash build.
