# 📦 BÀN GIAO THỰC TẾ — TÍNH NĂNG SOUNDLIST (ÂM MỤC) — in4up

> **Phiên bản:** v1.1 — Bàn giao cho Hội đồng AI (đầu vào mục 【A】 giao thức handoff v2.8)
> **Ngày:** 2026-08-20
> **Tác giả:** Agent phát triển (arena/01a0018e-in4up)
> **Dự án:** in4up — Advanced Audio Player & Language Learning Ecosystem (Flutter)
> **Trạng thái code:** Đã viết xong toàn bộ; **CI chưa xanh** (chờ kích hoạt GitHub Actions — xem mục 8.4)
>
> **CẬP NHẬT v1.1:**
> - ⚠️ `docs/` nằm trong `.gitignore` → file này phải được thêm bằng `git add -f`; nếu bạn không thấy file trên GitHub, hãy báo người push dùng `-f`.
> - File CI workflow được đặt kèm ở `docs/soundlist_ci_workflow.yml` (vì GitHub App token thiếu quyền `workflows`, không push trực tiếp vào `.github/workflows/` được — copy file này sang `.github/workflows/soundlist_tests.yml` rồi push là CI chạy).

---

## 0. MỤC TIÊU & RÀNG BUỘC (điền cho giao thức)

- **Mục tiêu (1 câu):** Biến âm thanh — vốn vô hình, trôi qua trong thời gian — thành thứ **có thể nhìn thấy, đánh dấu, quản lý và tìm kiếm** như một cuốn sách (mục lục + điểm + đoạn + ghi chú + tìm trong nội dung), phục vụ nghe Pháp thoại, học tiếng Anh và sách nói; đồng thời tận dụng thói quen lặp A–B của người dùng để gợi ý thông minh.
- **Loại:** Spec kỹ thuật + Hồ sơ bàn giao tính năng (Feature Handoff).
- **Ràng buộc:**
  - Offline-first (Hive), không phụ thuộc mạng; Whisper chạy offline.
  - Tái sử dụng hạ tầng có sẵn (just_waveform, in4up_stt, Segment cũ, PlayerProvider), **không tạo dữ liệu song song**.
  - Ngôn ngữ UI tiếng Việt (phù hợp chủ dự án), mã nguồn có chú thích tiếng Việt.
  - Tương tác tối giản: 1 chạm để lưu, không bắt người dùng "nghĩ" trước khi lưu.
- **Ngưỡng đánh giá:** theo giao thức (≥85 Usable, ≥90×2 Stable, ≥95 Final).

---

## 1. TÓM TẮT ĐIỀU HÀNH

Soundlist ("Âm mục") đã được triển khai trọn vẹn 3 lớp dữ liệu — **Điểm (mark)**, **Chương/Mục (chapter TOC)**, **Đoạn (segment A–B)** — cộng 3 lớp thông minh — **Tự tạo mục lục (VAD + Whisper)**, **Tìm kiếm trong audio (transcript)**, **Gợi ý theo thói quen lặp** — với 2 điểm vào (panel trong Listen Mode + thư viện riêng). Toàn bộ lưu Hive offline-first, có test đơn vị cho logic thuần. Điểm yếu đã biết: chưa được build/analyze bằng CI (xem mục 8.4), và **lớp "thư viện âm thanh" (quét file) của app còn yếu** — đã phân tích và đưa vào Phụ lục A như workstream riêng có liên đới trực tiếp.

---

## 2. QUYẾT ĐỊNH ĐÃ CHỐT VỚI CHỦ DỰ ÁN (trích sổ quyết định)

| ID | Quyết định | Cấp | Lý do |
|----|-----------|-----|-------|
| D1 | Tên chức năng: **Soundlist** (nhãn VN: "Âm mục"), KHÔNG dùng Voicelist | 🏗️ Kiến trúc | Song song hoàn hảo với Wordlist; "voice list" đã bị chiếm nghĩa (danh sách giọng TTS); "sound" bao trùm pháp thoại/nhạc/podcast/sách nói |
| D2 | Phạm vi: ưu tiên **Pháp thoại + tiếng Anh + sách nói** trước | 🏗️ | Theo chủ dự án; thể hiện qua bộ lọc loại nội dung |
| D3 | Đặt ở **cả 2 nơi**: panel trong Listen Mode + tab công cụ "Âm mục" | 🏗️ | Đánh dấu lúc nghe phải tức thì; quản lý thư viện cần không gian riêng |
| D4 | Lộ trình tự động: **thủ công trước → VAD → Whisper** | 🧱 | VAD (tách theo khoảng lặng) chạy offline không cần model; Whisper tự đặt tên chương |
| D5 | **Tái sử dụng hệ Segment cũ** (A–B loop) làm "Đoạn" | 🏗️ | Không tạo dữ liệu song song; Segment đã có sẵn trong PlayerProvider + Hive box `audio_segments` |
| D6 | Ngưỡng gợi ý thông minh: lặp ≥ **3 lần** / **14 ngày** | 🧱 | Tránh nhiễu; dễ chỉnh |
| D7 | VAD mặc định: khoảng lặng ≥ 0.9s, đoạn ≥ 6s, ngưỡng 0.28×mean | 🧱 | Cân bằng cho giọng nói; **đã cho tinh chỉnh trong UI** (mục 8.1) |
| D8 | Ngôn ngữ mã nguồn & UI: tiếng Việt | 🎨 | Theo chủ dự án |

---

## 3. KIẾN TRÚC TỔNG THỂ

```
┌─────────────────────────────────────────────────────────────────┐
│                       GIAO DIỆN (UI)                            │
│  Listen Mode: nút "Dấu" 📌 · nút "Âm mục" · panel 4 tab         │
│  Tools: màn hình "Âm mục" (thư viện)                           │
└───────────────┬──────────────────────────────┬──────────────────┘
                │                              │
                ▼                              ▼
┌────────────────────────────┐   ┌────────────────────────────────┐
│   SoundlistProvider        │   │  PlayerProvider (có sẵn)        │
│   (ChangeNotifier, trung   │◄──┤  - currentSongPath / state      │
│    tâm dữ liệu Âm mục)     │   │  - loopStart/loopEnd/loopCount  │
│  • marks / chapters /      │   │  - segments (A–B đã lưu)        │
│    transcripts / loopStats │   │  - seek/play/loadSong           │
│  • autoGenerateToc()       │   └──────────┬─────────────────────┘
│  • attachPlayer() theo dõi │              │ (lắng nghe loop)
│    thói quen lặp A–B       │              │
└──────┬─────────────┬───────┘              │
       │             │                      │
       ▼             ▼                      ▼
┌──────────────────────────┐   ┌────────────────────────────────┐
│ SoundAutoTocService      │   │ StorageService (Hive, có sẵn)   │
│  • vadSplit() (Isolate)  │──►│  box: sound_marks              │
│  • transcribe() (Whisper)│   │       sound_chapters           │
│  • buildChapters()       │   │       sound_transcripts        │
└──────────────────────────┘   │       sound_loop_stats         │
                               │       settings (vad_settings)  │
                               └────────────────────────────────┘
```

**Phụ thuộc (đều có sẵn trong dự án, không thêm package mới):**
- `just_waveform` — trích xuất waveform (đã dùng cho waveform hiển thị; tái dùng cho VAD).
- `in4up_stt` (packages/in4up_stt) — SttServiceFacade, SttConfig, SttResult/SttSegment, LrcLine, SttModelManager (Whisper offline).
- `provider`, `hive_flutter`, `file_picker` (có sẵn).

---

## 4. MÔ HÌNH DỮ LIỆU (file mới: `lib/models/`)

### 4.1 `sound_mark.dart` — Điểm (đơn vị nhỏ nhất, như "đánh dấu trang")
| Trường | Kiểu | Ghi chú |
|--------|------|---------|
| id | String | `mark_<microseconds>` |
| audioPath | String | Địa chỉ file (điểm nối với thư viện âm thanh) |
| position | Duration | Mốc thời gian trong file |
| label | String | Mặc định = thời gian "12:34" nếu không đặt |
| note | String? | Ghi chú thêm |
| tags | List\<String> | Tag tự do |
| kind | SoundMarkKind | enum: important ⭐ / hard 💪 / question ❓ / favorite ❤️ / quote 💬 / other 📌 — mỗi loại có icon + màu |
| createdAt | DateTime | |

### 4.2 `sound_chapter.dart` — Chương / Mục (cây mục lục kiểu sách)
| Trường | Kiểu | Ghi chú |
|--------|------|---------|
| id / audioPath / title / note | | |
| position | Duration? | Neo thời gian (null = nhóm tổ chức) |
| parentId | String? | null = mục gốc cấp 1 → cây linh hoạt (chương → mục → đoạn) |
| order | int | Thứ tự trong cùng cha |
| createdAt | DateTime | |

### 4.3 `sound_transcript.dart` — Bản ghi nội dung (cho tìm kiếm)
`SoundTranscript{audioPath, lines: List<TranscriptLine>, updatedAt}`; `TranscriptLine{start, end, text}`.

### 4.4 `sound_loop_stat.dart` — Thói quen lặp (nguồn gợi ý thông minh)
`SoundLoopStat{id = "path|startMs|endMs", audioPath, start, end, count, lastUsed, dismissed}`.

### 4.5 `vad_settings.dart` — Cài đặt tách đoạn (tinh chỉnh trong app)
`VadSettings{minSilenceSec=0.9, minSegmentSec=6.0, thresholdFactor=0.28}` + 3 preset `many/normal/few`.

**Lưu trữ:** Hive 4 box mới trong `StorageService` (đều là `Box<String>` chứa JSON):
`sound_marks`, `sound_chapters`, `sound_transcripts` (key = audioPath), `sound_loop_stats`; cài đặt VAD nằm trong box `settings` key `soundlist_vad_settings`. Mở box trong `StorageService.initialize()`.

---

## 5. DANH MỤC FILE & TRÁCH NHIỆM

### 5.1 File MỚI
| Đường dẫn | Vai trò | API chính |
|-----------|---------|-----------|
| `lib/models/sound_mark.dart` | Model điểm + enum kind (label/icon/color) | toJson/fromJson, formatTime |
| `lib/models/sound_chapter.dart` | Model chương/mục (cây) | toJson/fromJson, isRoot |
| `lib/models/sound_transcript.dart` | Transcript + dòng | toJson/fromJson, fullText |
| `lib/models/sound_loop_stat.dart` | Thống kê lặp | toJson/fromJson, timeLabel |
| `lib/models/vad_settings.dart` | Cài đặt VAD + preset | copyWith, toJson/fromJson |
| `lib/services/sound_auto_toc_service.dart` | **Bộ máy tự tạo mục lục** | `vadSplit()`, `transcribe()`, `buildChapters()`, `isWhisperModelReady()` |
| `lib/providers/soundlist_provider.dart` | **Provider trung tâm** | xem 5.2 |
| `lib/widgets/sound_mark_edit_sheet.dart` | Sheet tạo/sửa điểm (loại, nhãn, ghi chú, tag) | `showCreateMarkSheet()`, `showEditMarkSheet()` |
| `lib/widgets/sound_auto_toc_dialog.dart` | Dialog tự tạo mục lục (chọn chế độ + tinh chỉnh VAD + tiến trình + hủy) | `runSoundAutoToc()` |
| `lib/screens/listen_mode/widgets/soundlist_panel.dart` | **Panel Âm mục trong Listen Mode** (4 tab + hành động nhanh + gợi ý) | `showSoundlistPanel()` |
| `lib/screens/tools/sound_list/sound_list_screen.dart` | **Thư viện Âm mục** (tìm, lọc, mở rộng từng file) | `SoundListScreen` |
| `test/sound_auto_toc_test.dart` | 6 test logic thuần | — |

### 5.2 `SoundlistProvider` — API chính
```
load() / reload()                                  # nạp / đọc lại từ Hive
marksForSong(path) / chaptersForSong(path)         # truy vấn theo file (cây sắp thứ tự)
addMark(...) / updateMark(mark) / deleteMark(id)
addChapter(...) / renameChapter / setChapterNote / moveChapter / deleteChapter (cascade)
autoGenerateToc({audioPath, totalDuration, useWhisper, whisperLevel, onStatus})
    → VAD + Whisper → thay thế TOC file → lưu transcript → trả SoundAutoTocResult
transcriptFor(path) / saveTranscript(t) / transcriptFromLrcLines(path, lrcLines)
attachPlayer(PlayerProvider)                       # lắng nghe loopCount → ghi SoundLoopStat
suggestionsForSong(path, {minCount=3})             # lọc: ≥3 lần/14 ngày, bỏ dismissed, bỏ vùng đã có điểm Khó
dismissSuggestion(id) / setVadSettings(s) / vadSettings
buildFileIndex() → List<SoundFileIndex>            # cho thư viện (gắn transcriptText, hotRanges)
```

### 5.3 File SỬA (dấu vết tích hợp)
| Đường dẫn | Thay đổi |
|-----------|----------|
| `lib/services/storage_service.dart` | +4 box Hive, +CRUD marks/chapters/transcripts/loopStats, +get/saveVadSettings |
| `lib/screens/listen_mode/listen_mode_screen.dart` | Nút "Dấu": chạm = **lưu điểm thật** (trước chỉ snackbar ảo) + snackbar có action "Ghi chú"; **giữ lâu = mở panel**. Thêm nút "Âm mục" cạnh đó |
| `lib/screens/main_shell.dart` | Tool entry `sound_list` (title "Âm mục", icon menu_book, màu 0xFF26C6DA, ưu tiên 97 tab Remember) + route → SoundListScreen |
| `lib/main.dart` | Đăng ký `SoundlistProvider` (load + attachPlayer) trong MultiProvider |
| `README.md` | Tài liệu tính năng |

---

## 6. LUỒNG NGƯỜI DÙNG CHÍNH

1. **Đánh dấu nhanh:** đang nghe → chạm "Dấu" 📌 → tạo Điểm tức thì tại vị trí (snackbar kèm nút "Ghi chú" để mở sheet bổ sung loại/tag). Giữ lâu "Dấu" hoặc chạm "Âm mục" → panel.
2. **Tạo mục lục thủ công:** panel → "＋ Chương" → đặt tên → tự neo vào vị trí đang nghe. Giữ lâu một mục → Đổi tên / Thêm mục con / Ghi chú / Xóa (cascade).
3. **Tạo mục lục tự động:** panel → banner "⚡ Tự tạo mục lục · VAD + Whisper" → chọn chế độ (khuyên dùng / chỉ VAD) → tinh chỉnh VAD nếu cần → dialog tiến trình (có % + Hủy) → danh sách chương hiện ra, mỗi chương có tiêu đề = câu mở đầu, chạm để nhảy.
4. **Lưu đoạn A–B:** chọn A→B như cũ → panel "Đoạn A–B" (hoặc nút Lưu trong AB loop) → SaveSegmentDialog (tiêu đề, loại, độ khó, ghi chú) → xem trong tab "Đoạn", chạm phát lặp theo repeatCount.
5. **Tìm trong audio:** panel → tab "Tìm kiếm" → gõ "Tứ Niệm Xứ" → danh sách dòng khớp kèm thời gian → chạm nhảy tới & phát; giữ lâu để tạo điểm. (Transcript tự lưu sau Whisper, hoặc dựng từ LRC có sẵn.)
6. **Gợi ý thông minh:** lặp A–B nhiều lần → chip "💪 Lặp N× · mm:ss" hiện đầu panel → chạm → Đánh dấu Khó / Tạo điểm / Bỏ qua.
7. **Quản lý thư viện:** Tools → "Âm mục" → tìm kiếm (tên file, nhãn, tag, **cả nội dung transcript**), lọc (loại điểm, Pháp thoại/Tiếng Anh), mở rộng từng file = "cuốn sách" (Mục lục → Điểm → Đoạn → Nội dung preview 5 dòng), nút Phát/Đánh dấu/Thêm mục/Tự tạo, badge 🔥 cho file có vùng lặp nhiều.

---

## 7. CHI TIẾT KỸ THUẬT QUAN TRỌNG

### 7.1 VAD — tự tách đoạn theo khoảng lặng (`vadSplit`)
- Chạy trong **`Isolate.run`** (không block UI).
- Lấy waveform bằng `just_waveform` zoom **200 px/s** (mỗi mẫu = 5ms), file tạm `$path.vad_toc.waveform` tự xóa.
- Thuật toán: chuẩn hóa biên độ theo **p95** (chống phụ thuộc volume) → năng lượng cửa sổ 100ms → ngưỡng = `max(0.045, mean × thresholdFactor)` → gom cửa sổ im lặng liên tiếp ≥ `minSilenceSec` → ranh giới = điểm giữa khoảng lặng, loại ranh giới sát đầu/cuối file (< `minSegmentSec`) → ghép slice, bỏ slice < `minSegmentSec`.
- Trả `List<AudioSlice>{start, end}`; nếu < 2 slice → coi như không tách được.

### 7.2 Whisper — tự đặt tên chương (`transcribe`)
- `SttServiceFacade().transcribeFile(path, config: SttConfig.deepLearning.copyWith(whisperModel: base, generateLrc: false, grouping: sentence))`.
- Model `ggml-base.bin` (~57MB) tự tải lần đầu qua `SttModelManager` (HuggingFace/GitHub mirror); **có cache kết quả** trong facade (lần sau tức thì).
- Ghép: mỗi slice → tìm STT segment đầu tiên nằm trong slice → **tiêu đề = câu mở đầu** (làm sạch, cắt ≤64 ký tự), **note = toàn bộ câu**; không có slices → gom STT thành ≤80 chương; không có text → fallback "Đoạn N · mm:ss".
- Sau thành công: tự lưu `SoundTranscript` (mỗi STT segment → TranscriptLine, end = start dòng sau).

### 7.3 Theo dõi thói quen lặp (attachPlayer)
- Lắng nghe `PlayerProvider` (ChangeNotifier); khi `loopCount` tăng trong cùng vùng `(path, loopStart, loopEnd)` → cộng delta vào `SoundLoopStat` (Hive). Vùng mới → tạo mới.
- Gợi ý: `suggestionsForSong` lọc count ≥ 3, lastUsed trong 14 ngày, không dismissed, và **không có điểm loại Khó trong bán kính 1.5s quanh đầu đoạn** (tránh gợi ý trùng). Giới hạn 3 gợi ý, sắp theo count giảm dần.

### 7.4 Tìm kiếm trong audio
- Tìm kiếm tuyến tính `text.toLowerCase().contains(q)` trên các dòng transcript (đủ nhanh cho file 1–2h với vài trăm dòng; nâng cấp n-gram nếu cần trong tương lai).
- Nguồn transcript: (1) tự lưu sau Whisper; (2) dựng từ `UnderstandProvider.lrcLines` (đã có LRC) khi mở tab Tìm kiếm; (3) thư viện lưu sẵn.

### 7.5 Điểm nối quan trọng
- **Địa chỉ file là chìa khóa:** mọi entity đều key bằng `audioPath` (chuỗi đã `replaceAll("\\","/")`). Điều này tạo rủi ro khi file đổi chỗ/đổi tên (xem Phụ lục A).
- Mở rộng tab panel: `TabController(length: 4)`; các tab nhận `player`, `soundlist`, `path` từ parent (giữ sync khi đổi bài).
- Suggestion chip & banner tự tạo chỉ hiện khi `path != null` (đang phát file).

---

## 8. TRẠNG THÁI XÁC MINH & RỦI RO

### 8.1 Đã xác minh
- Cân bằng cú pháp toàn bộ file mới (script kiểm tra `{} () []`).
- Khớp API với code có sẵn (PlayerProvider, StorageService, SttServiceFacade, LrcLine, just_waveform) — rà soát tĩnh thủ công.
- 6 test logic thuần đã viết (`test/sound_auto_toc_test.dart`): title từ câu đầu, fallback "Đoạn N · mm:ss", gom ≤80 chương, cắt chuỗi 64 ký tự, transcriptFromLrcLines (end = timestamp dòng sau / fallback +3s), rỗng → null.

### 8.2 CHƯA xác minh — BẮT BUỘC làm qua CI (xem 8.4)
1. `flutter pub get`
2. `flutter analyze` (scope module Soundlist)
3. `flutter test test/sound_auto_toc_test.dart`
4. Build & kiểm thử tay trên thiết bị (checklist Phụ lục B)

### 8.3 Rủi ro / điểm cần giám sát
| Rủi ro | Mức | Hướng xử lý |
|--------|-----|-------------|
| Chưa chạy analyze/test qua CI | High | Kích hoạt workflow (mục 8.4) — đang chờ |
| Whisper lần đầu tải ~57MB (file dài: base có thể chậm) | Med | Đã có cache; có thể cho chọn tiny/base/small |
| Ngưỡng VAD chưa tối ưu cho mọi bài | Med | Đã tinh chỉnh trong UI; thu thập phản hồi thật |
| File đổi đường dẫn → dữ liệu Âm mục "mất" (key = path) | Med | Workstream thư viện âm thanh (Phụ lục A) |
| `attachPlayer` đếm loopCount — cần xác minh trên thiết bị thật | Med | Kiểm thử tay flow lặp A–B |
| Provider `SoundlistProvider` tạo trong MultiProvider dùng `ctx.read<PlayerProvider>()` — cần xác minh thứ tự provider | Med | Nếu lỗi runtime: đổi sang lazy (attach sau post-frame) |

### 8.4 CÁCH KÍCH HOẠT CI (quan trọng)
- File workflow: `docs/soundlist_ci_workflow.yml` (bản gốc `.github/workflows/soundlist_tests.yml` — pattern theo `knowledge_tests.yml` có sẵn, đã chạy 78 lần thành công).
- GitHub App token của agent **thiếu quyền `workflows`** → không push được file vào `.github/workflows/`. Hai cách:
  1. **Cấp quyền `Workflows: Read and write`** cho GitHub App (Settings → Developer settings → GitHub Apps) → agent tự push và chạy CI.
  2. **Thủ công:** copy `docs/soundlist_ci_workflow.yml` → `.github/workflows/soundlist_tests.yml` → commit → push nhánh `arena/01a0018e-in4up` (lần push đó tự kích hoạt workflow vì paths filter khớp).
- Workflow: `flutter pub get` → `flutter analyze` (scope module) → `flutter test test/sound_auto_toc_test.dart`.

---

## 9. NHẬT KÝ QUYẾT ĐỊNH (bảng D — bổ sung)

| ID | Quyết định | Cấp | Trạng thái | Vòng |
|----|-----------|-----|-----------|------|
| D9 | Whisper mặc định model **base** (cân bằng tốc độ/chất lượng) | 🧱 | Đã làm | 1 |
| D10 | Tìm kiếm transcript tuyến tính chữ thường (chưa n-gram) | 🧱 | Đã làm | 1 |
| D11 | Gợi ý hiển thị ≤ 3, loại trừ vùng có điểm Khó ±1.5s | 🧱 | Đã làm | 1 |
| D12 | Panel 4 tab (thêm "Tìm kiếm") thay vì 3 | 🏗️ | Đã làm | 2 |
| D13 | Cài đặt VAD lưu trong box `settings` (không box riêng) | 🧱 | Đã làm | 2 |
| D14 | **Vấn đề "mở file âm thanh khó" → workstream riêng (Phụ lục A), không trộn vào core Soundlist** | 🏗️ | Đề xuất | 2 |
| D15 | `docs/` nằm trong `.gitignore` → bàn giao + workflow-docs dùng `git add -f` | 🧱 | Đã làm | 3 |

---

## 10. HẠN CHẾ ĐÃ BIẾT & CÂU HỎI MỞ

1. **Chưa có CI xanh:** chưa analyze/test thật (đang chờ kích hoạt workflow, mục 8.4).
2. **Không có máy ảo/thiết bị:** chưa đo hiệu năng thực tế của VAD trên file 2 giờ, chưa xác minh hành vi `attachPlayer` ngoài đời thật.
3. **Không đồng bộ đám mây** cho dữ liệu Âm mục (Wordlist đã có Firebase sync — nên nhân lên cho Soundlist).
4. **Chưa xuất mục lục** ra văn bản/PDF.
5. **Transcript chỉ tiếng Anh mặc định** (`transcribeAuto(language:'en')` path trong player); cần cấu hình ngôn ngữ (vi-VN...) cho pháp thoại tiếng Việt — hiện `SoundAutoTocService.transcribe` dùng config `deepLearning` (ngôn ngữ mặc định của facade).
6. Câu hỏi mở: có nên gộp "Điểm" và "Chương" khi chương có note = transcript không? Có nên tự động tạo transcript song song khi người dùng tạo LRC (AI panel) không?

---

## 11. LỘ TRÌNH GỢI Ý (ưu tiên từ cao → thấp)

1. **Vòng 0 (bắt buộc):** kích hoạt CI (8.4) → chạy analyze/test → sửa lỗi → tinh chỉnh ngưỡng VAD theo bài thật.
2. **Cấu hình ngôn ngữ Whisper** (vi/en/auto) cho transcript + tên chương.
3. **Tự lưu transcript khi tạo LRC** (bắt mạch luồng AI panel hiện có).
4. **Đồng bộ Soundlist qua Firebase** (nhân mô hình Wordlist).
5. **Xuất mục lục** (văn bản / PDF) — "bản tóm tắt cuốn sách âm thanh".
6. **Workstream thư viện âm thanh** (Phụ lục A) — nền tảng để Soundlist bền vững.

---

## 12. PHỤ LỤC A — VẤN ĐỀ "MỞ FILE ÂM THANH KHÓ" → WORKSTREAM "THƯ VIỆN ÂM THANH"

### 12.1 Quyết định của người triển khai
**CÓ liên đới trực tiếp — đưa vào bàn giao này như workstream riêng, KHÔNG trộn vào core Soundlist.**

### 12.2 Chẩn đoán hiện trạng (đã đọc code)
- `ListenLibraryScreen` (màn hình khi chưa có bài) chỉ hiển thị **RecentAudio** (các file đã mở gần đây, lưu trong `RecentAudioService`), không quét thư viện.
- Mở file mới = `FilePicker.pickFiles` → người dùng phải **điều hướng sâu trong cây thư mục** điện thoại từng lần; không có nơi cấu hình "thư mục gốc", không có quét tự động, không có lập chỉ mục.
- `QuickAudioSheet` chỉ show 5 file recent.
- `PlayerProvider` lưu `lastAudioPath` (1 file duy nhất).

### 12.3 Vì sao liên đới với Soundlist
- Mọi entity Âm mục (điểm/chương/đoạn/transcript/thống kê lặp) **key bằng chuỗi `audioPath`** — một địa chỉ file ổn định là xương sống của tính năng. Người dùng không mở được file = không dùng được Âm mục.
- "Cuộc cách mạng âm thanh" (âm thanh nhìn thấy/quản lý được) bắt đầu từ **việc âm thanh có mặt trong app một cách có tổ chức**.

### 12.4 Đề xuất thiết kế sơ bộ (cho Hội đồng AI phản biện)
- **Android:** quét `MediaStore.Audio` (API 29+ không cần quyền đọc cho chính file; API 33+ dùng `READ_MEDIA_AUDIO`; legacy dùng `READ_EXTERNAL_STORAGE`); hỗ trợ **SAF folder picker** (`ACTION_OPEN_DOCUMENT_TREE`, giữ quyền bằng `takePersistableUriPermission`) để người dùng chọn "thư viện âm thanh" của mình (VD thư mục Pháp thoại).
- **iOS:** `UIDocumentPicker` / Files app.
- **Bảng chỉ mục** (Hive): `library_id`, `path/uri`, `title`, `artist`, `duration`, `size`, `addedAt`, `lastPlayed`, `fingerprint` (hash đầu file) — quét tăng dần lúc khởi động/nền.
- **Tính bền vững địa chỉ:** thêm `audioId`/fingerprint vào `SoundMark`, `SoundChapter`, `Transcript`, `Segment` (khả năng tương thích: giữ `audioPath` cũ, bổ sung trường mới với mặc định). Tính năng "sửa liên kết đứt" (re-link khi file đổi chỗ bằng fingerprint + offset thời gian).
- **UI:** màn hình Thư viện (thư mục, tìm, sắp xếp) thay thế/bao quanh `ListenLibraryScreen` hiện tại; giữ RecentAudio làm lớp nhanh.
- **Quan hệ ngược:** Soundlist có thể trả ơn bằng cách hiển thị "file nào có mục lục đầy đủ nhất" trong thư viện.

### 12.5 Ranh giới đề xuất
Workstream này độc lập về mặt triển khai (có thể làm song song), nhưng **nên hoàn tất trước** khi làm đồng bộ Firebase cho Soundlist (để có khóa ổn định đồng bộ).

---

## 13. PHỤ LỤC B — CHECKLIST KIỂM THỬ TAY (sau khi build)

- [ ] Chạm "Dấu" khi đang phát → snackbar có nút "Ghi chú" → mở sheet → lưu loại/label/tag → thấy trong tab "Điểm".
- [ ] Giữ lâu "Dấu" → panel Âm mục mở.
- [ ] Tạo chương thủ công → chạm chương → nhảy đúng vị trí & phát; giữ lâu → thêm mục con → thấy cây lùi vào.
- [ ] Chọn A–B → "Đoạn A–B" → lưu → tab "Đoạn" → chạm phát lặp đúng repeatCount.
- [ ] "⚡ Tự tạo mục lục" chế độ Chỉ VAD trên file giọng nói → tạo N chương "Đoạn N · mm:ss".
- [ ] Chế độ VAD + Whisper (sau khi tải model) → tiêu đề = câu mở đầu, note = câu đầy đủ.
- [ ] Tinh chỉnh preset VAD → chạy lại → số chương thay đổi đúng hướng.
- [ ] Tab "Tìm kiếm": gõ từ khóa có trong transcript → chạm kết quả → nhảy tới; giữ lâu → tạo điểm.
- [ ] Lặp A–B cùng vùng ≥ 3 lần → mở panel → chip "💪 Lặp N×" xuất hiện → "Đánh dấu Khó" → chip biến mất, điểm Khó xuất hiện.
- [ ] Tools → "Âm mục": tìm kiếm theo từ trong transcript tìm được file; mở file → thấy Mục lục/Điểm/Đoạn/Nội dung; nút "Tự tạo" hoạt động.
- [ ] Đổi bài đang phát → panel cập nhật theo bài mới (không lẫn dữ liệu cũ).
- [ ] Thoát app → mở lại → mọi dữ liệu còn nguyên (Hive).

---

*Kết thúc bàn giao v1.1. Sẵn sàng nhận bản "tinh hoa" từ Hội đồng AI để đối chiếu, góp ý và triển khai.*
