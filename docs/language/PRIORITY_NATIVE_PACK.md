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

## Trạng thái (wave 9, 2026-10-27 — 7 locale ưu tiên sạch)

- Pack: **3459 entry × 8 locale**.
- Máy dò đã được làm **trung thực hơn nữa** trong wave 9:
  - lexer literal Dart thật (`dart_string_end` / `iter_string_literals`) — không
    còn cắt sai ở `'${lang == 'en' ? ...}'`;
  - đệ quy vào `${...}` để bắt cả literal lồng bên trong template;
  - bỏ qua “vỏ ghép chuỗi” (literal mà phần tĩnh rỗng, runtime chỉ toàn nội suy);
  - `skipValuesByPath` nay áp cho **mọi** đường quét (trước đây chỉ đường quét
    rộng, nên chuỗi kỹ thuật vẫn quay lại báo cáo);
  - chuỗi mà phần tĩnh chỉ còn `${ui('…')}` được coi là đã dịch tại chỗ.
- Kết quả đo lại cuối wave 9 — **4340 chuỗi chrome / 308 file**:

  | locale | còn tiếng Việt | còn English |
  | --- | ---: | ---: |
  | `zh`, `zh_TW` | **0** | **0** |
  | `hi` | **0** | **0** |
  | `si` | **0** | **0** |
  | `my` | **0** | **0** |
  | `th` | **0** | **0** |
  | `ja` | **0** | **0** |

  `python3 tool/lang_ui_inventory.py --locale zh --fail-on-leak` → exit 0;
  `tool/lang_rollout_report.py` → mọi locale đạt sàn, 7 locale ưu tiên 392/392
  ở T2.
- Vì sao lần này khác các lần trước: con số trên **không** đến từ việc nới bộ
  lọc. Bộ lọc chỉ loại chuỗi kỹ thuật có ghi lý do trong
  `tool/lang_ui_scan_exclusions.json` (SQL, header HTTP, tên model/thương hiệu,
  regex bảng dấu, prompt LLM, khoá JSON, phím tắt hệ thống); mọi chuỗi hiển thị
  còn lại đều có bản dịch thật trong pack.
- Phần lớn công việc của wave 9 là **chuỗi nội suy**: chúng chỉ dịch được khi
  call site gọi `context.uiText(...)` (shim `Text` cố ý không bật template để
  không dịch nhầm nội dung người dùng). Các điểm đã rà và bọc: thông báo tiến
  trình VAD/Whisper (qua `autoTocStatus`), tiến trình tải YouTube, lỗi TTS,
  `_MetricRow` của Viết (độ dài/cụm trùng/từ khoá), tiêu đề chương tự sinh
  (`Chương {value0}`), "Đáp án: …" của bài tập điền từ, "… → Đã lưu nhanh" của
  tab Đọc, "Âm cần chú ý: …" của tab Nói.
- Lịch sử: 1037 (wave 2–4) → 1155 → 1575 → 2116 (wave 7) → 3005 (wave 8) →
  **3459** (wave 9: 300+ mẫu nội suy, Ngữ pháp/PDF/OCR/dịch màn hình, Learn by
  heart, Piper, YouTube, Memory, engine dịch, từ điển, cabin).
- `learn_by_heart_l10n.dart` có đủ **vi/en/hi/zh/zh_TW/si/my/th/ja** cho cả 74
  nhóm; `locale_map_gaps()` sẽ cảnh báo nếu một bảng `_get({...})` thiếu locale
  ưu tiên.
- Thuật ngữ **giữ nguyên English** (đúng yêu cầu): AI, PDF, TTS, STT, VAD, OCR,
  LRC, YouTube, Whisper, Hy-MT, ML Kit, Piper, Silero, Parakeet, Zipformer,
  Sherpa, GGUF, FSRS, Google Play services, Google Drive, `User-Agent`,
  `Content-Type`, `Authorization`, khoá API, tên model/thương hiệu, định dạng
  file.

## Lưu ý

- Không thêm key ARB chỉ cho một vài locale — ARB yêu cầu đủ 26 file, và T2
  (`hi`/`zh`/`zh_TW`/`si`) phải dịch đủ ngay trong cùng PR.
- Không bật dịch máy runtime. Chuỗi lạ (nội dung người dùng, PDF/web, từ vựng)
  phải giữ nguyên.
- `Text` shim vẫn là exact-match; nội suy phải đi qua `uiText` tại biên render.
