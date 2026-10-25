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

## Trạng thái (wave 7, 2026-10-25 — hoàn tất: 0 tiếng Việt, 0 tiếng Anh)

- Pack: **2116 entry × 8 locale**.
- **Rò rỉ tiếng Việt: 0** và **English còn lại: 0** ở **cả 7 locale ưu tiên**
  (`zh`, `zh_TW`, `hi`, `si`, `my`, `th`, `ja`) trên **2648 chuỗi chrome**
  (196 file presentation).
- Lịch sử wave: 1037 (wave 2–4) → 1155 (sau rebase 251e) → 1575 (wave 6:
  425 chuỗi còn lại, đưa `zh`/`zh_TW`/`hi`/`si` về 0) → 2116 (wave 7:
  491 chuỗi mà tầng ARB chỉ có bản dịch cho `zh`/`zh_TW`/`hi`/`si`, bổ sung
  `th`/`ja`/`my`, rồi vá 50 chuỗi chỉ thiếu `my`).
- Chuỗi giữ English theo chính sách (không tính là rò rỉ, khai báo trong
  `ENGLISH_STOPWORDS` của `tool/lang_ui_inventory.py`): `AI`, `PDF`, `URL`,
  `TTS`, `OCR`, `IPA`, `YouTube`, `Whisper`, `In4Up`, `YouGlish`, `Oxford`,
  `web_batch`, `en_US-lessac-medium`, `TXT · LRC · SRT`, `MP3, M4A, WAV, FLAC...`
  (danh sách định dạng file).
- Máy dò nay loại thêm **id công cụ / widget key / JSON field / storage name**
  (`word_list`, `pdf_jump_page_field`, `showLegend`, `vi`, `content`, `save`…)
  để số liệu chỉ còn chuỗi người dùng thực thấy.
- Cách hoàn tất phần `th`/`ja`/`my`: mỗi chuỗi còn thiếu được thêm vào pack với
  4 cột `hi`/`zh`/`zh_TW`/`si` **lấy nguyên từ tầng ARB đang chạy** (đã đúng,
  không dịch lại) và chỉ viết tay 3 cột `th`/`ja`/`my` — tránh dịch trùng và
  tránh lệch thuật ngữ giữa hai tầng.

## Lưu ý

- Không thêm key ARB chỉ cho một vài locale — ARB yêu cầu đủ 26 file, và T2
  (`hi`/`zh`/`zh_TW`/`si`) phải dịch đủ ngay trong cùng PR.
- Không bật dịch máy runtime. Chuỗi lạ (nội dung người dùng, PDF/web, từ vựng)
  phải giữ nguyên.
- `Text` shim vẫn là exact-match; nội suy phải đi qua `uiText` tại biên render.
