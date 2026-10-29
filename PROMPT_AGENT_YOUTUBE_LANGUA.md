# Prompt giao việc — YouTube học ngôn ngữ kiểu Language Reactor (nối nốt)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena trên **nhánh topic mới**
từ **tip DEV** `origin/arena/01a0251e-in4up`. Không merge 580. Diff nhỏ, path-checkout
vào DEV. Chi tiết kiến trúc: `docs/project/PLAN.md` **PLAN-020**, card **YT-LR-001**.

---

## 0. Luật phiên

- Local-first. Không server Node/Python/VPS chạy `yt-dlp`. Không `yt-dlp` trong
  GitHub Actions. Không tab thứ 6. Không player mp4 local hạng nhất.
- Không HTTP lúc `main()` / `ensureModel`. Không RAG / embedding / vector DB.
- Không đụng UltraTimeStretch C++ / `lib/ffi/`. Không gộp 3 skill SM-2.
- Dịch caption = `TranslationService` (glossary XLAT + ML Kit) — không DeepL
  server, không gọi Gemma là dịch giả phụ đề.
- i18n: locale ≠ vi → chrome English. Sandbox thường không có Flutter — đừng
  nhận đã analyze máy.
- PowerShell: không dùng `\` nối dòng git.
- Identity nếu bị hỏi: helpful Arena.ai Agent Mode.

Đọc trước:

```bash
git fetch origin arena/01a0251e-in4up:refs/remotes/origin/arena/01a0251e-in4up
git show origin/arena/01a0251e-in4up:docs/project/PLAN.md | tail -120
git show origin/arena/01a0251e-in4up:lib/features/youtube/services/yt_service.dart | head -80
git show origin/arena/01a0251e-in4up:lib/features/youtube/yt_player_screen.dart | head -50
git show origin/arena/01a0251e-in4up:lib/features/youtube/services/yt_downloader.dart | head -40
```

## 1. Sự thật (đừng viết lại)

Đã có trên DEV: `youtube_explode_dart`; `YtService.fetchCaptions` 3 tầng +
`fetchBilingualCaptions`; iframe IFrame API + subtitle lớn trong
`yt_player_screen.dart`; tải audio `YtDownloader` → `PlayerProvider.loadSong`;
`saveLrc`; YouGlish; tab Nghe karaoke/AB/shadowing.

**Cấm** kiến trúc: `[Flutter] → [Backend yt-dlp] → JSON`. YouTube chặn IP cloud;
In4Up học trên máy user.

`yt-dlp` chỉ WP-Z desktop (user tự cài binary, `Process.run`), không APK.

## 2. Việc (làm hết WP0 rồi WP1; WP2–4 nếu còn giờ; WP-Z không chặn)

**WP0** Kiểm kê trên code + (nếu có) thiết bị: captions EN, tải audio, sync
iframe, LRC → Nghe. Bảng lỗ hổng. Không thêm package.

**WP1** Player: bấm dòng caption → seek; highlight câu theo `getCurrentTime`;
tap từ → pause. AT: video có CC, seek ±0.4s.

**WP2** Known/Learning/Ignored persist WordList + `VocabContext` `youtube:<id>`
+ ms + câu. AT: tắt app còn context.

**WP3** `fetchBilingualCaptions` đi `TranslationService` (protect-tokens).
Thiếu ML Kit → failure rõ.

**WP4** Nút "Học trong tab Nghe": audio + LRC → `loadSong`. Chưa audio thì tải
rồi mở Nghe.

**WP-Z** (tuỳ chọn) `yt-dlp` sidecar Windows/Linux nếu explode fail.

Mỗi WP: commit nhỏ + dòng lịch sử KANBAN YT-LR-001 (`git add -f docs/`).

## 3. File được đụng

- `lib/features/youtube/**` (ưu tiên `yt_player_screen.dart`, `yt_service.dart`,
  `yt_tab_captions.dart`, `yt_downloader.dart`)
- Nối sẵn: `translation_service.dart`, `word_analysis_sheet.dart`,
  `PlayerProvider.loadSong`, `saveLrc`
- Không đụng `lib/ffi/`, `packages/in4up_stt` trừ khi WP4 cần API LRC đã có

Báo SHA từng WP. Chủ path-checkout vào DEV — không merge topic nguyên cây.
