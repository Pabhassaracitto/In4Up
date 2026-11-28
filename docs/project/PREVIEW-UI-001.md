# PREVIEW-UI-001 — Xem giao diện trên trình duyệt (sau 2 bản beta 1.30.0 / 1.30.1)

- **Trạng thái:** ✅ done — gallery dựng từ commit `1191da7a`…`a72a8800`, smoke-test
  Chromium **11/11 màn render · 0 lỗi console** (run `45849632526`)
- **Nguồn:** owner 2026-11-26 — *“Hãy giúp tôi lập preview live để xem những thay
  đổi về giao diện nhé. Đặc biệt sau 2 bản beta vừa rồi.”*
- **Nhánh công cụ:** `arena/395208ef-in4up` (không đổi `pubspec.yaml`; đây **không
  phải** một bản phát hành)

## 1. Vấn đề: bản web chính thức không cho thấy thay đổi của beta

`lib/main_web.dart` là **entrypoint web riêng** (IN4-109 / WEB-BUILD-001) vì
`lib/main.dart` kéo `dart:ffi` + `dart:io`. Nhưng nó không dựng các màn của app
native — chỉ có một màn **“In4Up · Web”** với 4 card: tài khoản/đồng bộ, nguồn
văn bản + Web Reader, phát audio, YouTube. Toàn bộ thay đổi giao diện của sprint
3/4 (sàn chữ ≥11sp, vùng chạm ≥40pt, SafeArea cho sheet, i18n 8 locale, GLIB)
nằm ở các màn **không có trên web**.

Ngoài ra sandbox của agent:

| Thứ cần | Kết quả đo |
|---|---|
| Flutter/Dart SDK | **không có**; `storage.googleapis.com` bị chặn (`curl` http 000) ⇒ không cài được |
| Tải artifact Actions | 302 → `productionresultssa0.blob.core.windows.net` → `SSL_ERROR_SYSCALL` ⇒ **không tải được** |
| Chromium headless | thiếu `libnspr4.so`/`libnss3.so`; `apt` bị chặn egress ⇒ **không chạy được** |
| `gh workflow run` | 403/404 với token sandbox |
| `github.com` (git) | **được** ⇒ mọi bản build phải đi qua **một nhánh git** |

## 2. Cách làm

Hai mảnh, cả hai đều nằm trong repo:

1. **`lib/main_ui_gallery.dart`** — entrypoint thứ ba, chỉ để xem: dựng **chính
   theme và widget thật** của sprint 3/4 vào 6 tab (không mock, không vẽ lại).
2. **`.github/workflows/web_preview_branch.yml`** — chạy trên runner GitHub:
   build **hai** bản web (gallery + `main_web.dart`), chạy smoke-test bằng
   Chromium, rồi force-push toàn bộ vào nhánh `preview/arena-395208ef-in4up`.

```
/            → UI Gallery   (lib/main_ui_gallery.dart)
/web-lite/   → app web chính thức (lib/main_web.dart, base-href /web-lite/)
/smoke/      → ảnh chụp từng màn + report.txt
/BUILD_INFO.txt
```

Nhánh `preview/*` **không** đụng `gh-pages` và **không** thay site thật; mỗi lần
chạy đều force-push nên nhánh chỉ chứa đúng một bản build.

### Kích hoạt

- Tự động: push commit có chuỗi `[preview-web]` trong tiêu đề (đường dùng được
  từ sandbox, vì `workflow_dispatch` bị chặn 403/404).
- Thủ công: **Actions → Web preview → Run workflow** (owner/UI).

### Xem

Dùng script trong repo (`tool/web/serve_preview.py`) — **một lệnh** lo cả hai
việc fetch và chạy server, và dựng lại được sau khi sandbox mất `/tmp`:

```bash
# dựng lại /tmp/preview từ nhánh preview rồi chạy server ở cổng 4173
python3 tool/web/serve_preview.py serve 4173 --sync

# hoặc tách hai bước
python3 tool/web/serve_preview.py sync                 # → /tmp/preview
python3 tool/web/serve_preview.py serve 4173           # bind 0.0.0.0
```

Mở `https://4173-<sandboxId>.e2b.app` (hoặc panel LIVE PREVIEW).

`http.server` trơn **không đủ**: preview có hai app con và Flutter dùng routing
client-side, nên route sâu phải trả `index.html` của **đúng** app con
(`/web-lite/...` → `/web-lite/index.html`, còn lại → `/index.html`), kèm COOP/COEP
cho CanvasKit. Script làm việc đó.

### Phục hồi khi preview tắt

| Triệu chứng | Xử lý |
|---|---|
| Panel LIVE PREVIEW trống, link không vào | `python3 tool/web/serve_preview.py serve 4173 --dest /tmp/preview` |
| Báo `LỖI: /tmp/preview không tồn tại` | thêm `--sync` (hoặc chạy `sync` trước) — `/tmp` **không** được lưu qua snapshot |
| Cổng 4173 bị chiếm bởi tiến trình cũ | `pkill -f "serve_preview.py serve 4173"` rồi khởi động lại |
| Muốn bản giao diện mới hơn | push commit có `[preview-web]`, chờ run xanh, rồi `sync` lại |

## 3. Nội dung gallery (toàn bộ là widget thật)

| Tab | Widget / bằng chứng | Thay đổi của beta |
|---|---|---|
| Chữ (11sp) | `AppTypography.darkTextTheme()` + `OpenTipitakaCredit` + `ElaborativeCard` | sàn chữ **≥11sp** (trước có chữ 9–10sp) |
| Chạm (40pt) | `FSRSRatingBar`, `AssessmentRatingBar`, `ShadowingSentencePicker`, `PhonemeDisplay` | vùng chạm **≥40pt**, picker 3 hàng timestamp 11sp |
| Sheet | `GrammarQuickSettingsSheet`, `PdfReaderThemeSheet`, `ReadSettingsGroup`/`ReadSettingsLinkRow` | `showModalBottomSheet(useSafeArea: true, isScrollControlled: true)` |
| 8 locale | `AppUITranslations` + đổi `Locale` thật (`?lang=zh`, `?lang=si`…) | i18n 8 locale ưu tiên |
| Thư viện | mô tả 5 màn GLIB (native-only) | nêu rõ vì sao không lên web |
| Ghi chú | phạm vi preview | — |

Widget được chọn bằng cách **phân tích đồ thị import**: chỉ nhận widget không
kéo `dart:io` / `dart:ffi` / `dart:isolate`. Kết quả: 48 file, sạch. Các màn
native-only bị loại và ghi rõ lý do (`ReadSettingsSheet`, `PdfToolbar`,
`DictEntryDetailSheet`, `LiveCaptionBubble`, toàn bộ `lib/features/great_library/ui/**`).

## 4. Smoke-test tự động (`tool/preview_smoke.mjs`)

Mở 11 màn bằng `puppeteer-core` + `@sparticuz/chromium`, chờ `flutter-view` /
`flt-glass-pane` và chờ `#in4up-loader` biến mất, chụp PNG, gom lỗi
console/network vào `smoke/report.txt`.

Kết quả lần cuối — run **45849632526**:

```
số màn render được: 11/11
tổng lỗi console/network: 0
01-typography        02-touch-targets   03-sheets          04-sheet-pdf
05-sheet-grammar     06-locales         07-library         07b-locale-zh
07c-locale-si        08-web-lite        09-mobile-small
```

Ba lỗi thật do smoke-test bắt được (đã sửa):

1. `#sheet-pdf` / `#sheet-grammar` rơi về tab 0 — thiếu `case` trong
   `_sectionFromFragment` ⇒ ảnh chụp nhầm màn.
2. web-lite build với `--base-href /` ⇒ `index.html` trong thư mục con nạp
   `/main.dart.js` **của gallery** ⇒ hiển thị sai app. Nay `--base-href /web-lite/`.
3. Flutter đặt `<canvas>` trong **shadow DOM** của `flt-glass-pane` nên
   `document.querySelector('canvas')` luôn rỗng ⇒ báo sai “0/9 màn render được”.
   Nay đi xuyên shadow root và đếm thêm `flt-scene-host`.

## 5. Giới hạn của preview

- Không có: ghi âm/âm thanh, tải gói GLIB, engine dịch FFI, OCR PDF, đồng bộ
  Firebase — đều cần native/quyền.
- Gallery chỉ chứng minh **giao diện**; các mục “chưa kiểm (máy thật)” trong
  card `REL-1.30.1-Beta` **vẫn nguyên**: cài đè 1.30.0-Beta → 1.30.1-Beta, sàn
  chữ/vùng chạm trên thiết bị, picker 3 hàng, `ReadSettingsSheet` SafeArea.
- Nghiệm thu giao diện chính thức vẫn là APK/IPA của beta.

## 6. Lịch sử

- 2026-11-26 | created→doing | agent `arena/395208ef-in4up` | thêm workflow build
  web → nhánh `preview/*` (sandbox không có Flutter, không tải được artifact)
- 2026-11-26 | doing→doing | agent | `main_web.dart` không chứa UI sprint 3/4 ⇒
  thêm `lib/main_ui_gallery.dart` dựng widget thật
- 2026-11-26 | doing→doing | agent | smoke-test Chromium trên runner; sửa 3 lỗi
  (deep-link, base-href web-lite, dò canvas trong shadow DOM)
- 2026-11-26 | doing→done | agent | **11/11 màn render · 0 lỗi console**; ảnh +
  report trong `preview/.../smoke/`
- 2026-11-26 | done→done | agent | đưa server vào repo (`tool/web/serve_preview.py`,
  có `sync` + `serve`); khởi động lại preview cổng 4173 sau khi tiến trình cũ
  dừng; kiểm 12 route = 200, SPA fallback đúng từng app con
