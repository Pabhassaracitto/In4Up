# In4Up — Preview giao diện sau 2 bản beta 1.30.0 / 1.30.1

Bản build **a72a8800** · `pubspec 1.30.1+33` · smoke-test **11/11 màn · 0 lỗi console**

| Mở | Nội dung |
|---|---|
| **`/`** | **UI Gallery** — theme + widget thật của sprint 3/4 |
| `/web-lite/` | App web chính thức (`lib/main_web.dart`) |
| `/smoke/` | Ảnh chụp từng màn + `report.txt` |
| `/BUILD_INFO.txt` | Nhánh / commit / run đang xem |

## Tab trong gallery

| Tab | Link | Xem gì |
|---|---|---|
| Chữ (11sp) | `/#chu` | Thang chữ thật `AppTypography` — dòng caption là sàn **11.0sp** |
| Chạm (40pt) | `/#cham` | `FSRSRatingBar`, `AssessmentRatingBar`, `ShadowingSentencePicker` (3 hàng timestamp), `PhonemeDisplay` |
| Sheet | `/#sheet` | `ReadSettingsGroup/LinkRow`; mở thật `PdfReaderThemeSheet` (`/#sheet-pdf`) và `GrammarQuickSettingsSheet` (`/#sheet-grammar`) — đều `useSafeArea: true` |
| 8 locale | `/#locale` | Bảng dịch thật; mở thẳng một ngôn ngữ: `/?lang=zh#locale`, `/?lang=si#locale`, `/?lang=ja#locale` |
| Thư viện | `/#thuvien` | 5 màn GLIB (chỉ có trên app native) + lý do |
| Ghi chú | `/#ghichu` | Phạm vi preview |

## Đây là bản build thật, không phải mock

Gallery dựng **chính** các widget đã đổi ở sprint 3/4 — cùng theme, cùng
`AppTypography`, cùng các sheet — nên cái bạn thấy là code đang nằm trong
1.30.1-Beta. Widget được chọn bằng phân tích đồ thị import: chỉ những widget
không kéo `dart:io` / `dart:ffi` / `dart:isolate` mới lên được web (48 file).

## Không có trong preview

Ghi âm/âm thanh, tải gói GLIB, engine dịch FFI, OCR PDF, đồng bộ Firebase —
cần native. Các mục “chưa kiểm trên máy thật” trong card `REL-1.30.1-Beta`
vẫn nguyên: cài đè 1.30.0-Beta → 1.30.1-Beta, sàn chữ/vùng chạm trên thiết bị,
picker 3 hàng, `ReadSettingsSheet` SafeArea. Nghiệm thu chính thức vẫn là
APK/IPA của beta.

## Tái lập

```bash
git fetch --depth=1 origin preview/arena-395208ef-in4up:refs/remotes/origin/preview
mkdir -p /tmp/preview && git archive refs/remotes/origin/preview | tar -x -C /tmp/preview
python3 -m http.server 4173 --bind 0.0.0.0 --directory /tmp/preview
```

Build lại: push commit có tiêu đề chứa `[preview-web]`, hoặc
**Actions → Web preview → Run workflow**.
