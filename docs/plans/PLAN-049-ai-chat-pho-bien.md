# PLAN-049 — AI Chat: làm đầy hội thoại (P1) + lộ trình P2/P3

> **Trạng thái:** 🔨 doing — P1 đã code (copy trả lời, gợi ý prompt, xác nhận
> xoá hội thoại), chờ CI + nghiệm thu máy.
> **Ngày:** 2026-11-24. **Nguồn:** owner qua `ask_user` — *"lên kế hoạch làm
> cho AI Chat đầy hơn + implement các P1 dễ đầu tiên (chat history, prompt
> suggestions, copy-answer…)"* ⇒ **plan + P1 code trong cùng đợt** (không chỉ
> plan).
> **Liên quan:** `AI-CHAT-01`, `API-002`, `PSRC-19`, `PSRC-263`, `PSRC-264`,
> `I4U18-HOME-AI-001`; PR #… (branch `arena/7ba1e7b3-in4up`).

## 1. Mục tiêu

Chat hiện đã **hoạt động** (streaming local/remote, hàng đợi, timeout, nút
Dừng, markdown PSRC-263, ngữ cảnh 1-lần PSRC-264, đếm token) nhưng còn **thô**
khi dùng hằng ngày: không sao chép được câu trả lời, màn trống không có gợi ý
gì để bấm, và nút xoá hội thoại xoá ngay không hỏi lại. P1 sửa đúng 3 điểm
dễ đó; P2/P3 ghi rõ thứ tự để làm sau mà không phải khảo sát lại.

## 2. Khảo sát hiện trạng (bằng chứng trong repo)

| Khía cạnh | Hiện trạng | Bằng chứng |
|---|---|---|
| Lịch sử hội thoại | **ĐÃ CÓ** — persist/restore xuyên restart, khoá `in4up_ai_chat_history_v1`; `clearChat()` tăng epoch để tin đang chờ không trả lời vào phiên mới | `ai_service_facade.dart` `_restoreChatHistory`/`_persistChatHistory`/`clearChat` |
| Sao chép trả lời | **THIẾU** — bubble trợ lý không có nút copy; user phải tự chọn chữ (không chọn được với `RichText`) | `_MessageBubble` (`ai_chat_screen.dart` ~:857) |
| Gợi ý prompt | **THIẾU** — `_EmptyChat` chỉ có icon + 2 dòng chữ, không có chip nào để bấm | `_EmptyChat` (~:667) |
| Xác nhận xoá | **THIẾU** — AppBar xoá gọi `clearChat()` thẳng, một chạm là mất cả lịch sử | `ai_chat_screen.dart` :217 |
| Retry câu trả lời | **CÓ 1 phần** — retry nạp model (`_retryEngine`) + nút Dừng streaming; chưa có "gửi lại câu này" / regenerate | `_retryEngine` :642 |
| i18n copy | **SẴN** — `'Sao chép'` + `'Đã sao chép'` đã trong cả legacy JSON lẫn pack 8 locale | `tool/legacy_ui_english_overrides.json`, `tool/priority_native_pack.json` |
| Test chat | 5 file trong `test/ai_chat/` nhưng **chỉ 2 chạy trên CI** (`model_copy_cancel`, `thinking_indicator`); `brand_i4u`, `chat_oneshot_context`, `chat_runtime_stability` chưa nối step | `.github/workflows/app_analyze.yml` :477, :501 |

## 3. P1 — làm trong đợt này (code xong, chờ CI)

### P1-1 — Nút sao chép câu trả lời (copy-answer)

- Nút copy nhỏ (icon 16, `VisualDensity.compact`) ở góc phải **dưới cùng**
  bubble trợ lý (kể cả bubble lỗi — tiện báo lỗi). Bubble user giữ nguyên.
- `Clipboard.setData(ClipboardData(text: display))` — copy **đúng chuỗi đang
  hiển thị** (sau khi đã `uiText` nếu là chrome), snackbar `'Đã sao chép'`.
- i18n: **không chuỗi mới** — `'Sao chép'` (tooltip) + `'Đã sao chép'`
  (snackbar) đã đăng ký sẵn.
- Pattern đúng theo `dict_entry_detail_sheet.dart` :214 (copy → snackbar
  floating), import `package:flutter/services.dart` + `context.mounted` sau
  `await`.

### P1-2 — Gợi ý prompt ở màn trống (prompt suggestions)

- 4 chip trong `_EmptyChat`, bấm = **điền vào ô nhập** (KHÔNG tự gửi — cùng
  triết lý với `initialDraft`: người dùng duyệt lại trước khi bấm Gửi).
- `_EmptyChat` nhận callback `onPick(String)`; caller nối `_controller.text`.
- Chuỗi mới (vi nguồn) — đăng ký đủ cả **legacy JSON (en) + pack 8 locale**:

| vi | en |
|---|---|
| `Giải thích ngữ pháp cho mình` | `Explain grammar to me` |
| `Đặt 3 ví dụ với từ mới` | `Give 3 examples with a new word` |
| `Tóm tắt giúp mình một đoạn văn` | `Summarize a paragraph for me` |
| `Sửa lỗi câu tiếng Anh của mình` | `Fix mistakes in my English sentence` |

### P1-3 — Xác nhận trước khi xoá hội thoại (bảo vệ chat history)

- AppBar xoá → `AlertDialog` (`'Xóa cuộc trò chuyện'` / `'Hủy'` / `'Xóa'` —
  **cả 3 đã đăng ký**, không chuỗi mới) → chỉ `clearChat()` khi người dùng
  xác nhận.
- Lịch sử persist vốn đã có (bảng §2) — P1 không đổi hành vi lưu, chỉ chặn
  mất oan.

### P1-4 — Test + CI

- File mới `test/ai_chat/chat_p1_copy_suggest_test.dart` — **thuần
  source-scan + JSON** (không widget, không plugin ⇒ không treo như run
  40575300780):
  1. `ai_chat_screen.dart` có copy handler (`Clipboard.setData` +
     `'Đã sao chép'`), chip gợi ý (4 chuỗi) và confirm `'Xóa cuộc trò
     chuyện'` trước `clearChat()`;
  2. 4 chuỗi có trong `legacy_ui_english_overrides.json` (en) và
     `priority_native_pack.json` (đủ 8 locale, không có ký tự Việt ở locale
     ≠ vi — máy bắt rule #5);
- Nối step mới vào `app_analyze.yml` (cạnh các step `test/ai_chat/` hiện có).

## 4. P2 — kế tiếp (chưa code, ưu tiên theo thứ tự này)

| # | Việc | Ghi chú |
|---|---|---|
| P2-1 | **Gửi lại / regenerate câu trả lời** — nút trên bubble lỗi + bubble cuối: xoá bubble assistant lỗi, `sendMessage()` lại đúng câu user cuối | facade đã có `sublist(0, index)` làm context; cần method `retryLastExchange()` + epoch giữ chỗ |
| P2-2 | **Thao tác theo từng tin** — long-press bubble: Sao chép / Xoá tin này / Sửa rồi gửi lại | sửa tin = `copyWith(text:)` + tái gửi, phải giữ `oneShotContext` |
| P2-3 | **Giới hạn dung lượng lịch sử** — cap ~200 tin lúc persist (context policy đã clip khi GỬI, nhưng SharedPreferences thì chưa clip khi LƯU) | tránh JSON phình; **cần owner đồng ý** vì là mất dữ liệu cũ |
| P2-4 | **Nối 3 test chưa chạy** (`brand_i4u`, `chat_oneshot_context`, `chat_runtime_stability`) vào CI | `chat_runtime_stability` dùng engine giả + `SharedPreferences` mock — xem lại risk treo trước khi nối |
| P2-5 | Xuất/chia sẻ hội thoại (txt/LRC-style song ngữ) | tái util `cabin_transcript_exporter` style |

## 5. P3 — chưa làm (đừng hứa trước)

- Đính kèm hình ảnh/ảnh chụp vào chat ( multimodal cần model hỗ trợ ).
- Nói với chat bằng mic (tách khỏi STT cabin).
- Trích dẫn nguồn / cite đoạn văn đang đọc vào câu trả lời.
- Nhiều phiên hội thoại riêng biệt (history browser) — khác "1 phiên persist".

## 6. i18n (quy trình bắt buộc, cùng PR)

1. 4 chuỗi P1-2 → `tool/legacy_ui_english_overrides.json` (vi→en) +
   `lib/core/language/generated_legacy_ui_fallbacks.dart` (fallback en —
   **sửa tay**, đúng cách `71d53978` vì `generate_legacy_ui_fallbacks.py`
   đang fail sẵn `898 unused overrides` trên base, không phải do P1);
2. 4 chuỗi → `tool/priority_native_pack.json` (đủ `en,hi,zh,zh_TW,si,my,th,ja`)
   rồi `python3 tool/generate_priority_native_pack.py` (generator này **chạy
   được**, đã xác minh);
3. Không đụng `generate_arbs.py` (đã vô hiệu) và không thêm key ARB.

## 7. Rủi ro / lưu ý

- **Không** thêm test widget cho bubble/chip (sqflite/SharedPreferences treo
  runner — bài học run 40575300780); test P1 là source-scan thuần.
- Sandbox không có Flutter SDK ⇒ không chạy được `flutter analyze`/`test`
  locally; CI là oracle (analyze ERROR-fatal).
- Chip gợi ý chỉ **điền chữ**, không gửi — tránh surprise gửi khi chưa nạp
  model (banner `'Chưa nạp model AI'` vẫn là cơ chế báo lỗi chính).
- Confirm dialog dùng `Navigator.pop(context, false/true)` + `context.mounted`
  trước khi `clearChat()` (lint `use_build_context_synchronously`).

## 8. Nhận định

P1 đủ nhỏ để ship trong một lane: 3 điểm chạm UI đều dùng chuỗi/i18n đã có
hoặc đăng ký đúng quy trình, không đụng facade ngoài confirm path, không đổi
hành vi lưu trữ. P2-1 (regenerate) là mục "đầy hơn" giá trị nhất kế tiếp vì
người dùng lỗi engine hiện chỉ có banner chung, không có nút thử lại đúng
câu.