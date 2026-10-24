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

## Trạng thái (wave 2, 2026-10-24)

- Pack: **505 entry × 8 locale**.
- **Rò rỉ tiếng Việt ở cả 7 locale ưu tiên: 0** trên 2 577 chuỗi chrome được
  quét (193 file) — đầu wave 2 là 181/2 616 (zh).
  Home 0 · Settings 0 · Listen 0 · Library/YouTube 0 · Video 0 · Read 0 ·
  Understand 0 · Tipiṭaka 0 · Learn by heart 0 · Tools/WordList 0 · Cabin 0 ·
  Web Reader 0 · PDF Reader 0 · TTS 0.
- Việc còn lại của wave sau là **tiếng Anh** (chưa dịch) — xem
  `docs/language/PRIORITY_LOCALE_LEAK_REPORT.md`: zh 988 · zh_TW 988 · hi 989 ·
  si 989 · th 1 479 · ja 1 478 · my 1 529. Số này đã tính cả trường hợp *fallback
  sang English* (trước đây tool bỏ sót đúng nhóm đó nên chỉ báo ~150), nên phải
  chia thành nhiều wave nhỏ theo khu vực — xem hướng dẫn trong
  `docs/language/HOW_TO_ADD_TRANSLATIONS.md`.
- Tool điều tra đã được sửa trong wave này: chuỗi bị **cắt ngang** (cửa sổ 400
  ký tự) và chuỗi **nối nhiều literal** của Dart từng tạo ra “nguồn ma” không tồn
  tại ở runtime; comment (`//`, `/* */`) từng bị tính là chrome. Nay tool:
  ghép literal liền kề, bỏ comment, chỉ nhận literal đã đóng → số liệu khớp với
  chuỗi người dùng thực thấy.
- Lỗi cấu trúc đã sửa trong wave này: 8 file UI từng import
  `material.dart show Text` (bỏ qua shim, nên **không bao giờ** dịch) nay dùng
  `localized_material`; ~20 chuỗi nội suy được đưa qua `uiText` để template bắt
  được (pin/STT, video library, soundlist, read library, playlist, OCR sheet…).

## Lưu ý

- Không thêm key ARB chỉ cho một vài locale — ARB yêu cầu đủ 26 file, và T2
  (`hi`/`zh`/`zh_TW`/`si`) phải dịch đủ ngay trong cùng PR.
- Không bật dịch máy runtime. Chuỗi lạ (nội dung người dùng, PDF/web, từ vựng)
  phải giữ nguyên.
- `Text` shim vẫn là exact-match; nội suy phải đi qua `uiText` tại biên render.
