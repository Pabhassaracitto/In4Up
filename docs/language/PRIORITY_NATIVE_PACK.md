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

## Trạng thái (wave 8, 2026-10-27 — đang dở, số liệu đo lại)

- Pack: **3005 entry × 8 locale**.
- **Máy dò đã được viết lại cho trung thực hơn** (`collect_broad_sources()` trong
  `tool/lang_ui_inventory.py`): quét **mọi literal hiển thị** (không chỉ đối số
  đầu tiên của `Text`/`uiText`), nên con số “0 rò rỉ” của wave 7 là **thiếu
  thực tế** — wave 7 chỉ nhìn 2648 chuỗi ở 196 file, còn thực tế có ~4600 chuỗi
  ở 332 file, gồm cả chuỗi trong service/provider và widget tự viết.
- Sau wave 8 (`zh`, đo trên 4391 chuỗi chrome / 325 file):

  | locale | còn tiếng Việt | còn English |
  | --- | ---: | ---: |
  | `zh`, `zh_TW` | 339 | 87 |
  | `hi` | 341 | 95 |
  | `si` | 339 | 96 |
  | `my` | 339 | 218 |
  | `th` | 339 | 210 |
  | `ja` | 339 | 207 |

- Việc còn lại chủ yếu là **chuỗi nội suy** (`"$count phút"`, `"${x} dòng"`):
  `Text` shim chỉ dịch *exact match* nên các chuỗi này vẫn hiện tiếng Việt ở
  runtime dù pack có mẫu `{value0} …`. Cần quyết định: bật template trong shim
  (kèm chốt chặn nội dung người dùng) hay bọc `context.uiText(...)` tại chỗ render.
- Lịch sử: 1037 (wave 2–4) → 1155 → 1575 → 2116 (wave 7) → 2375/2448/2559/2677/
  2750/2830/2880/3005 (wave 8: TTS, Thuộc Lòng, Ngữ pháp, WordList, YouGlish,
  YouTube, dịch, Web Reader, Tipiṭaka, shadowing, widget dùng chung, Nghe,
  Vườn nhớ, từ điển, Cabin, OCR, cài đặt).
- `learn_by_heart_l10n.dart` nay có đủ **vi/en/hi/zh/zh_TW/si/my/th/ja** cho cả
  74 nhóm; `locale_map_gaps()` trong tool sẽ cảnh báo nếu một bảng `_get({...})`
  thiếu locale ưu tiên.
- Chuỗi được **loại khỏi phép quét** (khai báo trong
  `tool/lang_ui_scan_exclusions.json`, có ghi lý do): nội dung dữ liệu
  (stopword tiếng Việt cho thuật toán cloze/tóm tắt, regex dấu tiếng Việt, tên
  font, câu SQL), prompt gửi cho LLM, khoá JSON/HTTP, tên thương hiệu
  (`OpenAI`, `Gemini`, `Pexels`, `LibreTranslate`…), tên file model, tên phím.

## Lưu ý

- Không thêm key ARB chỉ cho một vài locale — ARB yêu cầu đủ 26 file, và T2
  (`hi`/`zh`/`zh_TW`/`si`) phải dịch đủ ngay trong cùng PR.
- Không bật dịch máy runtime. Chuỗi lạ (nội dung người dùng, PDF/web, từ vựng)
  phải giữ nguyên.
- `Text` shim vẫn là exact-match; nội suy phải đi qua `uiText` tại biên render.
