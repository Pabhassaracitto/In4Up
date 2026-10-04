# ADR-0002: Lộ trình phủ ngôn ngữ theo bậc — vi (nguồn) → en (chuẩn fallback) → hi/zh/zh_TW/si → còn lại

- **Ngày:** 2026-08-22
- **Trạng thái:** ĐÃ TRIỂN KHAI (LANG-630-01, CI xanh run 32573825623; thu hoạch vào
  `arena/01a0251e-in4up` 2026-08-23 — merge 81dc2c8)
- **Phạm vi:** Rule #5 (GOV-2) mở rộng xuống tầng ARB + ratchet độ phủ

## Bối cảnh

Rule #5 (GOV-2) đã bắt ở tầng shim legacy (`uiText` + `generated_legacy_ui_fallbacks`
+ test catalog): locale ≠ vi mà chrome hiện tiếng Việt là vi phạm. Nhưng tầng ARB
(26 locale × 376 message) khi đó chưa có chuẩn:

1. **Runtime fallback yếu:** `AppUITranslations._valueForLocale` cũ là
   `translations[locale] ?? translations['en']!` — crash (null-check) nếu entry
   thiếu key `en`; giá trị locale rỗng được trả nguyên (rò tiếng Việt vào chrome
   nếu entry dịch bằng chuỗi trống).
2. **Không có key parity:** ARB một locale thiếu/thừa key so với template
   `app_en.arb` → gen-l10n fallback lẫn lộn, khó audit.
3. **Bootstrap cũ nguy hiểm:** `generate_arbs.py` nhúng từ điển 19 locale × ~50 key
   rồi GHI ĐÈ `lib/l10n/app_*.arb` — chạy nó khi catalog đã 26 locale × 376 message
   sẽ phá cả template `app_en.arb` (gen-l10n gãy).
4. **Không có chuẩn độ phủ:** phủ ngôn ngữ nào đến đâu, có được phép lùi không —
   không có máy bắt.

Yêu cầu người sở hữu (2026-08-22, "I4U | Language EL HIN CH SH"):
(1) locale ≠ vi không còn tiếng Việt, thiếu dịch → English;
(2) triển khai đặc biệt Hindi + Chinese + Sinhala phủ dần thay English;
(3) lộ trình Việt → Anh → India + Chinese + Sinhala → …

## Quyết định

1. **Bất biến rule #5 mở xuống tầng ARB:** locale ≠ vi thiếu dịch thì HIỆN ENGLISH,
   không bao giờ tiếng Việt. Mọi ARB locale giữ **key parity với `app_en.arb`**
   (không thiếu, không thừa key) — máy bắt bằng test.
2. **Lộ trình theo bậc** (`lib/core/language/language_roadmap.dart`):
   - **T0 `vi`** — ngôn ngữ nguồn của chuỗi UI gốc (không đo coverage).
   - **T1 `en`** — chuẩn fallback toàn cục, cũng là ARB template.
   - **T2 `hi`, `zh`, `zh_TW`, `si`** — rollout ưu tiên, phủ dần thay English.
     Wave 1 (2026-08-22) đạt **100% message chrome**: hi/si 371/371,
     zh/zh_TW 372/372 (mẫu số = 376 key − key keep-English theo chính sách).
   - **T3** — 20 locale còn lại, sàn bằng độ phủ hiện tại (làm tròn xuống 2 số).
   Canonicalize locale: `zh-TW`/`zh-Hant`/`zh-HK`/`zh-MO` → `zh_TW`; phần còn lại
   lấy subtag ngôn ngữ (mirror `AppUITranslations.canonicalLocaleCode`).
3. **Ratchet sàn độ phủ:** `tool/lang_rollout_floors.json` ↔
   `LanguageRollout.coverageFloors` — test fail nếu hai nơi lệch; sàn **chỉ được
   RA LÊN** qua wave mới (không hạ), thay đổi bậc T3→T2 cần wave + ADR mới.
4. **Chính sách keep-English** (`tool/lang_keep_english.json`): brand/từ mượn
   giữ nguyên English (toàn cục: `demoWordHello`, `demoWordWorld`, `youtube`,
   `youglish`; theo locale: `webReaderUrl` cho hi/si) — loại khỏi mẫu số coverage.
5. **Hardening runtime:** `_valueForLocale` trả `en` khi giá trị locale thiếu
   **hoặc rỗng** (không còn null-check crash; test catalog bảo đảm mọi entry có `en`).
6. **Máy bắt** — group ADR-0002 trong `test/locale_chrome_no_vietnamese_test.dart`
   (7 test: key parity; không ký tự Việt trong giá trị ARB của mọi locale ≠ vi;
   sàn Dart == sàn JSON; tier T2 == 4 locale ưu tiên + canonicalize; mọi locale ≥
   sàn; T2 phủ 100% — key mới phải dịch đủ 4 locale trong cùng PR; key keep-English
   tồn tại đúng chính sách). Chạy trong workflow `app_analyze.yml` hiện có —
   không đổi workflow (token agent thiếu quyền `workflows`).
7. **Vô hiệu hóa `generate_arbs.py`** — biến thành guard (in hướng dẫn + exit 1).
   Nguồn sự thật: `lib/l10n/app_*.arb` sửa trực tiếp (giữ parity) +
   `tool/generate_ui_translation_map.py` (bridge shim legacy) +
   `flutter gen-l10n` (CI) + `tool/lang_rollout_report.py` (báo cáo).

## Hệ quả

- Chrome hi/zh/zh_TW/si 100% ngôn ngữ bản địa (wave 1); 20 locale còn lại fallback
  English ở độ phủ 14–41% — **không bao giờ tiếng Việt**.
- Key ARB mới phải dịch đủ 4 locale T2 trong cùng PR (test chặn).
- Nâng locale T3 lên T2 = wave mới + nâng sàn — ADR này không đổi.
  Ứng viên wave 2 (theo độ phủ tại 2026-08-22): ar/ru 41.7%, ja/ko/th 41.4% —
  chờ owner chọn.
- Báo cáo độ phủ: `python3 tool/lang_rollout_report.py`.

## Triển khai

- Commit `1393244` lang(LANG-630-01) trên `arena/01a0296a-in4up` (2026-08-22):
  tier + ratchet + wave 1 (dịch đủ 4 locale T2, vá ~50 message word-salad) +
  hardening runtime + máy bắt + vô hiệu bootstrap.
- Bằng chứng: CI App Analyze + Locale Test xanh run 32573825623
  (analyze + 7 test ADR-0002 + test rule #5 cũ).
- Thu hoạch: merge `81dc2c8` vào `arena/01a0251e-in4up` (2026-08-23) — không
  xung đột với SHERPA-001/002 (VAD/TTS) vì không chạm file chung, trừ AGENTS.md
  (hai block phụ chú khác nhau, auto-merge sạch).
- ADR file này được bổ sung khi thu hoạch (commit gốc chỉ tham chiếu ADR-0002
  trong KANBAN/PLAN/AGENTS — thiếu file theo quy ước `docs/adr/` của AGENTS.md).
