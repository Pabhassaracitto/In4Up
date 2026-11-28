# Ảnh giao diện 1.30.0-Beta + 1.30.1-Beta

Bản build `a72a8800` · `pubspec 1.30.1+33` · chụp tự động bằng Chromium trên
runner GitHub (run `45849632526`), **11/11 màn render · 0 lỗi console**.

> Ảnh nằm trong workspace, **không** commit vào Git (xem `.gitignore`). Sinh lại
> bằng cách push commit có `[preview-web]` rồi fetch nhánh `preview/arena-395208ef-in4up`,
> ảnh ở thư mục `smoke/`.

## Danh sách

| # | Tệp | Nội dung |
|---|---|---|
| 01 | `01-typography.png` | **Sàn chữ ≥11sp** — thang chữ thật `AppTypography.darkTextTheme()`: 24 / 20 / 17 / 15 / 13.5 / 12 / 13.5 / 12sp, dòng caption 11sp là sàn |
| 02 | `02-touch-targets.png` | **Vùng chạm ≥40pt** — `FSRSRatingBar` (Quên/Khó/Được/Dễ), `AssessmentRatingBar`, `ShadowingSentencePicker` 3 hàng timestamp 11sp |
| 03 | `03-sheets.png` | **SafeArea trong sheet** — 2 sheet mở thật + `ReadSettingsGroup` / `ReadSettingsLinkRow` (mũi tên xuống = mở tại chỗ, mũi tên phải = mở trang) |
| 04 | `04-sheet-pdf.png` | `PdfReaderThemeSheet` **đang mở** — Tối/Sáng/Giấy/Đêm + thanh độ sáng, `useSafeArea: true` |
| 05 | `05-sheet-grammar.png` | `GrammarQuickSettingsSheet` **đang mở** — preset Content Words, chip nhóm bật/ẩn, Mini/Advanced |
| 06 | `06-locales.png` | **8 locale** — hàng chip chọn ngôn ngữ + bảng dịch |
| 07 | `07-library.png` | **GLIB** — 5 màn Thư Viện Chung (native-only) + lý do không lên web |
| 07b | `07b-locale-zh.png` | Toàn bộ UI ở **中文** — 9 dòng dịch thật (zh, zh-TW, hi, si, my, th, ja) |
| 07c | `07c-locale-si.png` | Toàn bộ UI ở **සිංහල** (Sinhala) |
| 08 | `08-web-lite.png` | App web chính thức (`main_web.dart`) — 4 card: tài khoản, đọc văn bản, audio, YouTube |
| 09 | `09-mobile-small.png` | Màn hẹp **360×740** — kiểm vùng chạm/typography ở kích thước điện thoại nhỏ |

`smoke-report.txt` — log đầy đủ: thời gian boot, kích thước canvas, lỗi console
từng màn (lần cuối: **0**). Tệp này **không** bị gitignore (theo dõi được).

## Đây là bản build thật

Gallery dựng **chính** widget/theme đang nằm trong 1.30.1-Beta, không mock.
Widget được chọn bằng phân tích đồ thị import: chỉ những widget không kéo
`dart:io` / `dart:ffi` / `dart:isolate` mới lên được web.

**Không có trong ảnh:** ghi âm/âm thanh, tải gói GLIB, engine dịch FFI, OCR PDF,
đồng bộ Firebase — cần native. Các mục “chưa kiểm trên máy thật” của card
`REL-1.30.1-Beta` **vẫn nguyên**; nghiệm thu chính thức vẫn là APK/IPA.

Xem thêm: [`../../project/PREVIEW-UI-001.md`](../../project/PREVIEW-UI-001.md)
