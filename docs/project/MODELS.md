# MODELS — Hướng dẫn đặt/tải model offline (STT · VAD · TTS)

> Áp dụng mọi build flavor. **Ưu tiên dùng trong app**: Home →
> **Quản lý Model AI** — mỗi model có nút **Import** (chọn file có sẵn)
> và **Tải về** (từ mạng, chỉ chạy khi bạn bấm — app không tự tải lúc mở).
> File này dành cho developer/adb — cách làm thủ công khi không có UI.

## Bảng tổng hợp (đặt ĐÚNG thư mục + ĐÚNG tên)

Android: `documents = /sdcard/Android/data/<package>/documents/`

| Flavor | package |
|---|---|
| release | `com.in4up` |
| dev | `com.in4up.dev` |
| beta | `com.in4up.beta` |

Windows: `documents = %LOCALAPPDATA%\<org>\<app>_documents/`

| Model | Thư mục (trong `documents/`) | Tên file | Kích thước | Dùng cho | Bắt buộc? |
|---|---|---|---|---|---|
| **Whisper STT** | `in4up_whisper_models/` | `ggml-tiny-q4_0.bin` (hoặc `ggml-tiny.bin`, `ggml-base.bin`…) | 37-75MB | Bóc băng audio → chữ (Tab Nghe, shadowing) | ✅ dùng STT |
| **Silero VAD** | `sherpa_vad_models/` | `silero_vad.onnx` | 2-5MB | Loại khoảng lặng — tạo lời file 30p nhanh, không đơ | ✅ khuyến nghị (thiếu → fallback chậm, không skip silence thật) |
| **Piper TTS** | `sherpa_piper_models/` | xem bảng giọng bên dưới | ~75MB/giọng | Đọc chữ offline (TTS cabin) | ✅ muốn TTS neural offline |

## Piper TTS — 2 layout hợp lệ (app tự nhận cả hai)

```
<documents>/sherpa_piper_models/
  espeak-ng-data/                    ← BẮT BUỘC, dùng chung mọi giọng
  # Layout 1 — bundle k2-fsa chính thức (tải về, giải nén là đủ):
  en_US-libritts_r-medium.onnx
  tokens.txt                         ← tokens DÙNG CHUNG
  # Layout 2 — file riêng từng giọng (rhasspy/user):
  <voice>.onnx
  <voice>_tokens.txt
  <voice>.onnx.json                  ← tuỳ chọn (chứa audio.sample_rate)
```

**Tải giọng (nguồn chính thức, đã verify):**
- Trang release: `https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models`
  (536 giọng, bundle `.tar.bz2` gồm onnx + tokens + espeak-ng-data)
- Gợi ý: `vits-piper-en_US-libritts_r-medium.tar.bz2` (Anh) ·
  `vits-piper-vi_VN-vais1000-medium.tar.bz2` (Việt)
- VAD: `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx`

**Luồng trong app (khuyến nghị cho user):**
1. **Import thư mục** — chọn thư mục giọng đã giải nén (app tự copy onnx +
   tokens + json + espeak-ng-data vào chỗ đúng).
2. **Import file** — chọn 1-3 file (`*.onnx` + `*_tokens.txt`/`tokens.txt`
   + `*.onnx.json`).
3. **Tải giọng** — app tải bundle tar.bz2 về `documents/downloads/`,
   hiện hướng dẫn giải nén rồi quay lại Import thư mục.

## adb push (developer)

```bash
PKG=com.in4up   # hoặc com.in4up.dev / com.in4up.beta
DOC=/sdcard/Android/data/$PKG/documents

adb push ggml-tiny-q4_0.bin   $DOC/in4up_whisper_models/
adb push silero_vad.onnx      $DOC/sherpa_vad_models/
# Piper: push CẢ thư mục đã giải nén
adb push vits-piper-en_US-libritts_r-medium/ $DOC/sherpa_piper_models/
# (hoặc adb shell + cp từng file)

# Verify:
adb shell ls $DOC/in4up_whisper_models/ $DOC/sherpa_vad_models/ $DOC/sherpa_piper_models/
```

Lưu ý: `adb push` thư mục vào thư mục CHƯA TỒN TẠI trên Android sẽ tạo
thư mục con mang tên đó — tạo thư mục trước (`adb shell mkdir -p ...`)
hoặc push từng file.

## Quy tắc đã cố định (đừng đổi bừa)

1. **Absolute path qua path_provider** (`getApplicationDocumentsDirectory`)
   — không hardcode `/data/...` (bài học HttpException tablet, handover
   SECTION 1 Rule 1).
2. **Verification**: file tồn tại + size > 1MB trước khi dùng
   (VAD >1MB, Whisper theo minimum mỗi level).
3. **Không auto-download** lúc khởi động — chỉ tải khi user bấm
   (bài học "Connection closed" Battery Saver).
4. **Pointer FFI singleton**: `ensureSherpaBindings()` init 1 lần,
   model giữ trong singleton — không re-init liên tục (xung đột FFI
   whisper.cpp + sherpa_onnx).
5. Model KHÔNG đưa lên GitHub (nặng) — user push vào thiết bị hoặc tải
   trong app.

## Tinh chỉnh chức năng (KHÔNG phải ở đây)

Quản lý Model = nơi DÚNG ĐÚNG để có model. Tinh chỉnh dùng model thì ở
tab chức năng:
- **TTS**: Settings → Text-to-Speech — thứ tự nguồn (Piper/Offline/…),
  tốc độ, chọn giọng (giọng Piper hiện trong danh sách).
- **STT**: Tab Nghe — model Whisper tiny/base khi tạo lời.
- **VAD**: không có UI (threshold mặc định hợp lý 0.5).
