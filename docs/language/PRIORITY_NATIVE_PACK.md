# Priority-locale native pack (ADR-0002 wave 2)

> Mục tiêu: ngôn ngữ ưu tiên — **Trung (zh, zh_TW), Myanmar (my), Sinhala (si),
> Hindi (hi), Thái (th), Nhật (ja)** — đọc chrome UI bằng *ngôn ngữ của họ*,
> không còn tiếng Việt, và hạn chế tối đa tiếng Anh. Chỉ giữ English cho
> thuật ngữ/thương hiệu (AI, PDF, Whisper, YouTube, LRC…).

## Vì sao có thêm một catalog ngoài ARB

ARB vẫn là nơi chuẩn để khai báo chuỗi UI mới. Nhưng mỗi key ARB phải có mặt ở
**cả 26 locale**, và ratchet `tool/lang_rollout_floors.json` tính “giá trị ==
English” là *chưa dịch*. Thêm vài trăm chuỗi legacy vào ARB sẽ làm hơn 20 locale
T3 tụt dưới sàn và buộc phải dịch lại toàn bộ 26 ngôn ngữ.

Vì vậy phần chrome legacy (đã hard-code tiếng Việt từ trước, phần lớn đã có
English trong `tool/legacy_ui_english_overrides.json`) được bản địa hoá bằng
pack riêng:

| tầng | file | vai trò |
| --- | --- | --- |
| nguồn | `tool/priority_native_pack.json` | bản dịch review tay, 8 locale/entry |
| sinh ra | `lib/core/language/generated_priority_native_pack.dart` | const map cho runtime |
| hoà vào | `lib/core/language/app_ui_translations.dart` | ưu tiên cao nhất cho 7 locale ưu tiên |
| máy bắt | `test/language/priority_native_pack_test.dart` | đủ locale, không tiếng Việt, giữ placeholder |
| điều tra | `tool/lang_ui_inventory.py` | báo cáo chuỗi nào còn rò rỉ |

Locale ngoài danh sách ưu tiên vẫn đi theo thứ tự cũ (ARB → English), nên
`de`/`fr`… không bị “hạ cấp” về English.

## Quy trình thêm/sửa một chuỗi

1. Chạy điều tra để biết còn gì rò rỉ:

   ```bash
   python3 tool/lang_ui_inventory.py              # tổng quan theo locale
   python3 tool/lang_ui_inventory.py --locale zh --list
   python3 tool/lang_ui_inventory.py --write-report
   ```

2. Thêm entry vào `tool/priority_native_pack.json`:

   ```json
   "Từ đến hạn ôn": {
     "en": "Words due for review",
     "hi": "…", "zh": "…", "zh_TW": "…",
     "si": "…", "my": "…", "th": "…", "ja": "…"
   }
   ```

   - Chuỗi có nội suy dùng placeholder `{value0}`, `{value1}`, … **và phải giữ
     đủ placeholder ở mọi locale** (generator fail nếu thiếu).
   - Chuỗi nội suy chỉ dịch được khi call site gọi `context.uiText(...)`
     (shim `Text` cố ý **không** bật template để không dịch nhầm nội dung
     người dùng).
   - Nếu chuỗi chưa có trong `tool/legacy_ui_english_overrides.json`, generator
     ở bước 4 sẽ tự thêm `en` vào đó (đăng ký phân loại UI).

3. Sinh lại Dart:

   ```bash
   python3 tool/generate_priority_native_pack.py          # ghi file
   python3 tool/generate_priority_native_pack.py --check  # CI-style verify
   ```

4. Kiểm tra lại: `python3 tool/lang_ui_inventory.py` (số rò rỉ phải giảm) và
   chạy test `test/language/priority_native_pack_test.dart` (+ group rule #5
   trong `test/locale_chrome_no_vietnamese_test.dart`).

## Trạng thái (wave 5, 2026-10-25 — rebase lên nhánh 251e)

- Pack: **1155 entry × 8 locale** (1037 gốc wave 2–4 + 62 chuỗi Settings/model
  config + engine dịch mới xuất hiện sau khi rebase 251e + 39 chuỗi YouTube mới
  + 18 chuỗi nhỏ ở TTS/OCR/Read/Listen/Settings/Dictionary/Video library/
  Web Reader/Learn by heart/Other).
- **Rò rỉ tiếng Việt ở cả 7 locale ưu tiên: 0** trên **2675** chuỗi
  chrome được quét (197 file).
- Các khu vực đã **hết tiếng Anh**: `Home` · `YouTube` · `Read` · `Listen` ·
  `Settings` · `Web Reader` · `Video library` · `Dictionary` · `TTS` · `OCR` ·
  `Learn by heart` · `Other`.
- Bảy tên thương hiệu/định dạng thuần kỹ thuật (`In4Up`, `In4Up logo`,
  `YouGlish`, `Oxford`, `TXT · LRC · SRT`, `web_batch`,
  `en_US-lessac-medium`) được khai báo trong `ENGLISH_STOPWORDS` của
  `tool/lang_ui_inventory.py` — chúng *không* bị tính là rò rỉ.
- Việc còn lại (zh, **442 chuỗi**): Tools / WordList 99 · Other screens 69 · Shared widgets 55 · Memory 44 · Tipiṭaka 37 · Other features 30 · PDF Reader 27 · Understand 27 · Grammar / Understand 22 · Translation 20 · AI Chat 12.
  Mỗi khu vực là một wave nhỏ — xem `docs/language/HOW_TO_ADD_TRANSLATIONS.md`.
- Tổng English còn lại theo locale: zh/zh_TW 442 · hi 446 · si 447 · th 935 ·
  ja 934 · my 987 (th/ja/my cao vì tầng ARB sinh tự động của các locale này mỏng).

## Lưu ý

- Không thêm key ARB chỉ cho một vài locale — ARB yêu cầu đủ 26 file, và T2
  (`hi`/`zh`/`zh_TW`/`si`) phải dịch đủ ngay trong cùng PR.
- Không bật dịch máy runtime. Chuỗi lạ (nội dung người dùng, PDF/web, từ vựng)
  phải giữ nguyên.
- `Text` shim vẫn là exact-match; nội suy phải đi qua `uiText` tại biên render.
