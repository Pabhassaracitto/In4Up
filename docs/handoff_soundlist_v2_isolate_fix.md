# Bàn giao Âm mục (Soundlist) v2 — bản vá "Chỉ VAD không dùng được"

> Ngày: 2026-09-16 · Nhánh nguồn: `arena/01a0018e-in4up` · Commit cần bổ sung cho
> `arena/01a0251e-in4up`: **`3cca37a`** (4 file, +181/−131)
> Bản vá: `docs/soundlist_to_251e_isolate_fix.patch`

## 0. Kết quả đối chiếu ngược 0018e ↔ 0251e (2026-09-16)

`git diff --stat origin/arena/01a0251e-in4up HEAD` trên TOÀN CÂY cho ra **đúng 4 file**:

| File | 0251e đã có chưa | 0251e cần gì |
|---|---|---|
| `lib/services/sound_auto_toc_service.dart` | CÓ bản cũ (đã có `_evenSplitFallback`) | **Bản vá isolate (mục 2 dưới đây)** |
| `lib/services/audio_library_channel.dart` | CÓ `copyContentToCache`, `scanMediaStore` | thêm `readAudioDurationMs` |
| `android/…/com/in4up/MainActivity.kt` | CÓ `copyContentToCache` | thêm handler `readAudioDurationMs` + import `MediaMetadataRetriever` |
| `lib/providers/soundlist_provider.dart` | CÓ (chạy nền + bubble + autoToc state) | câu báo lỗi mới ( actionable ) |

Toàn bộ phần còn lại của Âm mục/P1 (models, dialog, panel, `resolvePlayablePath`,
tests, `docs/soundlist_ci_workflow.yml`, skills CI) **0251e đã có** — không cần bổ sung.
`packages/in4up_stt/pubspec.yaml` cũng đã hết lỗi trùng khai báo `sherpa_onnx` (chỉ còn `^1.13.6`).

**Áp dụng (chọn 1):**
```bash
# Cách 1 — patch có sẵn trong repo
git checkout arena/01a0251e-in4up && git am docs/soundlist_to_251e_isolate_fix.patch
# Cách 2 — cherry-pick thẳng từ nhánh kia
git cherry-pick 3cca37a
```

---

## 1. Bối cảnh: 3 lớp lỗi chồng lên nhau

User báo: *"chọn cả 2 chế độ đều báo không tạo được mục lục"* → sau đó
*"VAD + Whisper đã OK, **chỉ VAD vẫn lỗi**"*. Nguyên nhân là 3 lớp độc lập:

| Lớp | Triệu chứng | Trạng thái |
|---|---|---|
| **L1** — `return []` sớm trước fallback | Cả 2 chế độ fail với file waveform đọc lỗi | ✅ đã sửa (`d7c72ca`) |
| **L2** — `just_waveform` cần file cục bộ; `content://` mở không chạy | Mở bài từ tab Thư viện không phát | ✅ đã sửa (`70c4efc`: `resolvePlayablePath`) |
| **L3** — **MethodChannel gọi trong `Isolate.run`** | VAD-only LUÔN fail, VAD+Whisper vẫn chạy | ✅ **bản vá này (`3cca37a`)** |
| (phụ) — `sherpa_onnx` khai báo 2 lần trong `in4up_stt` | CI đỏ bước *Resolve dependencies* | ✅ đã sửa (`70c4efc`) |

## 2. L3 — gốc rễ "Chỉ VAD không dùng được" (quan trọng nhất)

**Cơ chế lỗi:** `just_waveform` là *federated plugin* → `JustWaveform.extract()`
gọi `MethodChannel`, mà **MethodChannel chỉ tồn tại ở root isolate**. Code cũ
bọc toàn bộ phần trích waveform **bên trong `Isolate.run`** để "cho nhẹ UI":

```
Isolate.run(() { JustWaveform.extract(...) })   // ❌ background isolate
      → không có binary messenger → throw
      → catch (e) { return const <AudioSlice>[]; }   // [] , bỏ qua cả fallback
      → VAD-only: chapters = [] → "không tách được đoạn theo khoảng lặng"
```

Vì sao **VAD + Whisper vẫn chạy**: luồng đó dựng chương từ `stt.segments`
(Whisper/Sherpa dùng FFI/native lib, không cần MethodChannel) → có mục lục dù
VAD trả rỗng. Đây chính là dấu hiệu nhận dạng của lớp lỗi này.

**Vì sao hot reload (R) không hết:** còn 2 phần *không phải Dart-hot*:
handler Kotlin `copyContentToCache` (cần full rebuild) và kiến trúc isolate ở
trên. → **Phải `flutter run` lại, không hot R.**

**Bản vá (thuần Dart + 1 handler native):**

1. `_extractPeaks()` chạy ở **root isolate**; chỉ **DSP thuần**
   (`computeBoundaryMs`, dữ liệu phẳng `List<double>` + int) mới đưa vào
   `Isolate.run`. Plugin không còn bị gọi sai isolate.
2. Preview trong dialog và VAD thật **dùng chung `computeBoundaryMs`** →
   vạch ranh giới người dùng THẤY = ranh giới chương được tạo (không còn
   "preview đẹp, kết quả khác").
3. **Mọi** nhánh lỗi (file lạ, copy fail, audio liền mạch, isolate lỗi) đều
   rơi vào `_evenSplitFallback(durationMs, minSegmentSec)` → file có
   duration ≥ 2×`minSegmentSec` **luôn** ra mục lục thô.
4. `AudioLibraryChannel.readAudioDurationMs()` + `MainActivity`
   (`MediaMetadataRetriever`, đọc được cả `content://`) → biết thời lượng kể
   cả khi player chưa mở bài. Không có native (iOS/Windows, build cũ) → trả
   `null` và Dart tự suy duration từ số mẫu waveform.
   *Tab Thư viện không cần bước này*: `AudioLibraryEntry.durationMs` đã lấy từ
   `MediaStore…DURATION` và được truyền vào dialog (`audio_library_view.dart:78`).

## 3. Nghiệm thu bắt buộc (build mới, không hot R)

- [ ] **Chỉ VAD**, file giọng nói 1–2 phút (tab *Thư viện*, `content://`) → tạo được
      mục lục. Logcat phải có `⚠️ Auto-TOC: VAD chỉ tìm được N đoạn` **hoặc** không có
      dòng lỗi nào; **không** được có `❌ VAD split error`.
- [ ] **VAD + Whisper** → tiêu đề = câu mở đầu (không được hồi quy).
- [ ] Preview trong dialog: vạch trắng nằm khớp với tai nghe (khoảng lặng thật).
- [ ] Mở bài từ tab Thư viện → **phát được** (log: copy `content://` → `cacheDir/in4up_*`).
- [ ] Chạm bong bóng ⚡ khi job chạy nền → mở panel Âm mục; xong việc có snackbar.
- [ ] Tắt mạng + file đã có transcript → vẫn tạo mục lục (không chờ model).

## 4. CI

`docs/soundlist_ci_workflow.yml` (bản **v5**) là nguồn sự thật; owner copy đè
`.github/workflows/soundlist_tests.yml`. v5: tee `pubget.log`/`analyze.log`/`test.log`
+ **commit-back log vào `ci_reports/` khi đỏ** (môi trường agent không đọc được
workflow log/artifact nên log phải đi qua git), paths đã gồm Audio Library,
`pubspec*`, `android/**/kotlin/**`, `.github/workflows/**`.

Run xanh gần nhất trên `arena/01a0018e-in4up`: `32946979440` (✓ pub get · analyze · test).

---

*Hết v2. Sau khi 0251e merge `3cca37a` và user xác nhận đạt mục 3 → chốt
nghiệm thu Việc 4, chuyển sang P2 (chọn thư mục âm thanh).*
