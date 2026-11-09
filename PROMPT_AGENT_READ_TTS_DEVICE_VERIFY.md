# Prompt giao việc — Nghiệm thu giọng Edge trên máy thật + kéo chọn nhiều từ ở tab Đọc (TTS-EDGE-VOICE-002 · READ-SELECT-002)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. Hai việc nhỏ
nhưng **bắt buộc có thiết bị thật** (nghe tai + chạm tay), nên tách khỏi đợt
sửa vừa rồi.

---

## 0. Luật phiên

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`).
- `AGENTS.md` + quy tắc vàng (không đụng `lib/ffi/`, không gộp 3 SM-2, giữ
  reopen anchor, ADR cho thay đổi kiến trúc, i18n rule #5 đủ
  `en/hi/zh/zh_TW/si`, **đừng** chạy `tool/generate_arbs.py`).
- Card KANBAN: `TTS-EDGE-VOICE-002` và `READ-SELECT-002` (append-only).

---

## Việc A — Nghiệm thu "chọn giọng nam mà giọng nữ đọc" (TTS-EDGE-VOICE-002)

### A.1 Đã sửa gì (đọc để biết chỗ mà kiểm)

Commit `TTS-EDGE-VOICE-002` đã xử lý ba nguyên nhân cộng dồn:

1. `TtsCache` khoá md5 **không có giọng/tốc độ/cao độ** ⇒ bản ghi giọng mặc
   định (nữ) có thể phát đè. Nay `TtsCache.makeKey` gồm
   `engine + ngôn ngữ + giọng + speed + pitch`.
2. `speak()` dò cache bằng `engineId: 'any'` trong khi `put` ghi bằng
   `engine.id` ⇒ bất đối xứng (cache coi như chết). Nay mỗi engine tự
   dò/ghi theo đúng danh tính.
3. `_prefetchOnline` tổng hợp **không truyền `voiceId`** ⇒ nạp sẵn giọng mặc
   định. Nay prefetch dùng đúng giọng sẽ phát.
4. Thêm `_resolveEdgeVoice(lang)`: giọng theo ngôn ngữ →
   `_selectedVoiceId` nếu đúng dạng id Edge → null.
5. Nhãn engine hiện kèm tên giọng (`🌐 Edge TTS · NamMinh`) để nghe sai là
   thấy ngay.

File liên quan: `lib/features/tts/tts_service.dart`,
`lib/features/tts/cache/tts_cache.dart`,
`lib/features/tts/engines/edge_tts_engine.dart`,
`lib/features/tts/edge_voice_prefs.dart`,
`lib/features/tts/widgets/tts_settings_section.dart`.

### A.2 Phải làm

1. **Nghe thật** trên máy có mạng:
   - Cài đặt → giọng Edge → tiếng Việt → chọn **Nam Minh (♂)** → đọc một
     đoạn tiếng Việt ⇒ phải là giọng nam, nhãn hiện `· NamMinh`.
   - Đọc lại chính đoạn đó (lần này vào cache) ⇒ vẫn giọng nam, nhãn
     `💾 Cache · Edge TTS`.
   - Đổi sang **Hoài My (♀)** rồi đọc lại đoạn cũ ⇒ **phải đổi giọng ngay**
     (không ăn cache cũ). Đây là bài kiểm tra quan trọng nhất.
2. **Đoạn lẫn Việt–Anh**: đọc một dòng tiếng Anh trong tài liệu tiếng Việt ⇒
   ghi lại nhãn giọng. Nếu rơi về giọng mặc định tiếng Anh (Aria, nữ) trong
   khi người dùng chỉ cấu hình giọng tiếng Việt: quyết định (và ghi vào
   KANBAN) một trong hai hướng, rồi làm:
   - thêm bộ chọn giọng cho ngôn ngữ đó ngay trong luồng đọc, hoặc
   - cho phép ghim "luôn dùng giọng này cho mọi ngôn ngữ".
3. **Dọn cache cũ**: bản cũ đã ghi file theo khoá không có giọng. Thêm một
   lần dọn (xoá thư mục `tts_cache` khi phiên bản khoá đổi) để người dùng cũ
   không nghe lại giọng sai. Ghi rõ trong KANBAN.
4. Test thuần cho `TtsCache.makeKey`: đổi giọng/tốc độ/cao độ ⇒ khoá đổi;
   cùng tham số ⇒ khoá ổn định. Nối vào bước TTS trong `app_analyze.yml`.

### A.3 Nghiệm thu

Nghe đúng giọng đã chọn ở cả 3 lần (lần đầu, lần cache, sau khi đổi giọng);
nhãn engine khớp tai nghe; `flutter analyze` 0 error; bước
`TTS engine tests` xanh.

---

## Việc B — Kéo chọn nhiều từ trong chế độ ô chữ của tab Đọc (READ-SELECT-002)

### B.1 Bối cảnh

Audit 0.10.3 mục 1.e: "chọn nhiều từ thường thất bại — chạm thì phát âm, giữ
thì ra việc khác".

Sự thật trong repo: ở chế độ tô màu/IPA, **mỗi từ là một `GestureDetector`
riêng** (`lib/screens/read_mode/widgets/colored_text_widget.dart`): chạm =
phát âm, chạm đúp = nghĩa nhanh, giữ = `WordActionsSheet`. Không có
`SelectableText` nên **không thể bôi chọn nhiều từ** — đây là giới hạn thiết
kế, không phải lỗi ngẫu nhiên.

Đã giảm đau trong commit `READ-ACT-001`: 4 nút Dịch/Ngữ pháp/Phát âm/Từ điển
nay tự chạy trên **cả dòng đang đọc** khi không có vùng chọn, và bảng hướng
dẫn (`READ-HINT-001`) nói đúng thao tác thật.

### B.2 Phải làm

1. Thêm **chế độ chọn nhiều từ** cho chế độ ô chữ:
   - giữ một từ ⇒ vào chế độ chọn, từ đó là mỏ neo (đổi nền rõ ràng);
   - kéo ngang (hoặc chạm từ thứ hai) ⇒ mở rộng vùng chọn liên tục;
   - thanh hành động dùng lại **đúng** `ReadTextActionRunner.run(...)` với
     `selectedText` là chuỗi đã ghép — **không** viết nhánh xử lý thứ hai.
2. Ghi vùng chọn vào `TextProvider.selectTextWithOffsets(...)` để phần còn
   lại của app (lưu từ, ngữ pháp, dịch) nhìn thấy như một selection thật.
3. Thoát chế độ chọn: chạm ra ngoài hoặc nút ✕; `clearSelection()`.
4. Giữ nguyên hành vi cũ khi **không** ở chế độ chọn (chạm = phát âm…) —
   đừng làm người dùng cũ mất phản xạ.
5. Cập nhật bảng hướng dẫn (`read_line_hint.dart`) + i18n đủ 5 ngôn ngữ.
6. Test thuần cho hàm gộp khoảng chọn (mỏ neo → mở rộng → chuỗi kết quả +
   offset đầu/cuối), nối vào bước `Read actions + mixed-language tests`
   trong `app_analyze.yml`.

### B.3 Nghiệm thu

Giữ → kéo 5 từ → bấm Dịch ⇒ dịch đúng 5 từ đó; bấm Ngữ pháp ⇒ phân tích
đúng cụm; thoát chọn ⇒ chạm lại phát âm như cũ; không vỡ chế độ dòng/
interlinear; `flutter analyze` 0 error + test xanh.
