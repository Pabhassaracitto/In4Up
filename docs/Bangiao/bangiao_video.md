# Bàn giao — Video Player local (VID-001)

> Agent đọc file này trước khi code. Owner tham khảo khi review.

## 1. Mục tiêu

Xem video local (MP4, MKV, WebM...) với phụ đề + học từ vựng:
- **Approach A:** Sub-tab "Xem" trong tab Nghe (Nghe | Nói | Xem)
- **Approach B:** Quick-action "Video" trong ⚡ menu
- Phụ đề SRT/ASS overlay đồng bộ
- Tap từ trong phụ đề → tra từ điển + lưu WordList
- Tốc độ phát thay đổi
- A-B loop theo câu phụ đề

## 2. Kiến trúc

### 2.1 File structure

```
lib/features/video/
├── models/
│   └── video_info.dart          ← model video file
├── services/
│   └── video_library_service.dart ← quét thiết bị tìm video
├── widgets/
│   ├── video_player_screen.dart ← phát video + phụ đề + controls
│   └── video_library_screen.dart ← thư viện video browse/search
└── video.dart                   ← barrel export
```

### 2.2 Package

```yaml
video_player: ^2.8.0  # Flutter official, cross-platform
```

### 2.3 Tích hợp navigation

**Approach A — Sub-tab trong Listen mode:**
- `main_shell.dart`: IndexedStack 3 children: [ListenModeScreen, SpeakModeScreen, VideoLibraryScreen]
- Mode switch: ['Nghe', 'Nói', 'Xem']
- Accent color: Nghe=#6C63FF, Nói=#B388FF, Xem=#FFB300

**Approach B — Quick-action:**
- ⚡ → "Video" → VideoLibraryScreen (full screen)
- Priority 98 trong listen mode (cao hơn YouTube)

### 2.4 Video Player Screen

- Portrait: title bar + video area + subtitle overlay + controls + subtitle timeline
- Landscape: video full screen + overlay controls
- Subtitle: SRT parser → overlay tap → dictionary lookup
- Speed: 0.5×, 0.75×, 1×, 1.25×, 1.5×, 2×
- A-B loop per subtitle line

## 3. Quy tắc ngôn ngữ (i18n)

- **Chrome UI** (nút, tiêu đề): rule #5 AGENTS.md — locale ≠ vi → English
  - "Video" → "Video" (universal)
  - "Xem" → "Watch" (EN) / "观看" (ZH) / "देखें" (HI) / "දකින්න" (SI)
  - Dùng `uiText()` + ARB keys
- **Nội dung phụ đề**: giữ nguyên ngôn ngữ gốc — KHÔNG dịch
- **Tên file**: giữ nguyên

## 4. Scope

### Trong scope (VID-001):
- [ ] Video player screen (video_player package)
- [ ] SRT subtitle parser + overlay
- [ ] Video library screen (browse/search files)
- [ ] Sub-tab "Xem" trong Listen mode
- [ ] Quick-action "Video" trong ⚡
- [ ] Speed control (0.5× - 2×)
- [ ] A-B loop per subtitle line
- [ ] i18n chrome UI

### Ngoài scope (tương lai):
- ASS/SSA subtitle support (complex styling)
- MKV embedded subtitle extraction
- Video → audio extraction (reuse UltraTimeStretch)
- Video chapter navigation
- Picture-in-picture mode

## 5. Bẫy

- `video_player` trên Windows cần `media_kit` hoặc Windows native plugin
- Large video files → memory management (dispose controller đúng)
- Subtitle encoding (UTF-8 vs UTF-16) → graceful fallback
- Không auto-download subtitle từ mạng
- Không đụng vùng bảo vệ UltraTimeStretch FFI

## 6. Acceptance Test

1. Tab Nghe → mode switch hiện "Xem" → mở VideoLibraryScreen
2. ⚡ → Video → mở VideoLibraryScreen
3. Chọn file MP4 → phát video + controls hoạt động
4. Có file .srt cạnh video → phụ đề hiện overlay
5. Tap phụ đề → hiện nghĩa từ từ điển (nếu đã import MDX)
6. Thay đổi tốc độ → video phát đúng tốc độ
7. Locale ≠ vi → chrome UI hiện English
