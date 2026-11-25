# ADR-0036 — Linh vật AI In4Up: lớp trợ lý nổi trong shell + một registry hành động, tái dùng facade AI/STT/TTS hiện có

- **Trạng thái:** 🔨 accepted (thi công theo pha) — owner chốt DQ1–DQ5 ngày
  2026-11-25; **P0 (MASCOT-001+002) đã code** trên nhánh `arena/4ad3035e-in4up`:
  registry + search index + shell action hub + palette «Mở nhanh»; P1–P4 làm
  tiếp theo PLAN-050 §9.
- **Nguồn:** người sở hữu (2026-11-25, qua agent `arena/4ad3035e-in4up`).
- **Bối cảnh kỹ thuật:** khảo sát đầy đủ tại `docs/plans/PLAN-050-linh-vat-ai-i4u.md` §2/§5.

## Bối cảnh

Yêu cầu: một linh vật AI đóng 3 vai (quản gia · gia sư · hướng dẫn dùng app), chat được
và hội thoại âm thanh được, mở nhanh file/chức năng; mục đích giải phóng thời gian,
nâng trải nghiệm và hiệu suất khi dùng app.

Hiện trạng liên quan (bằng chứng ở PLAN-050 §2):

- **Não hội thoại đã có:** `AiServiceFacade` (local Gemma GGUF + remote OpenAI-compat,
  routing chat `onlineFirst` với OpenRouter seed) — màn AI Chat là màn hình push, coach
  AI chỉ trong tab Hiểu ⇒ **không có trợ lý toàn app, không có vai chủ động/dẫn dắt**.
- **Tai/miệng đã có:** `SttServiceFacade` (Whisper/Sherpa streaming/remote) và
  `TtsService` (8 engine, epoch/stop guard).
- **Điều hướng đóng:** `_handleTool(toolId)` ở `main_shell.dart` là dispatcher trung tâm
  nhưng chỉ gọi được từ widget shell; `ShellNavigationRequest` chỉ có 2 target
  (`read`/`listen`).
- **Lệnh giọng cũ:** `lib/features/voice_command/` — 8 intent phát lại, parser thuần
  vi/en ⇒ chưa đủ cho "mở nhanh file/chức năng".
- **Quy tắc vàng:** không đụng FFI UltraTimeStretch; không mất khả năng mở lại đúng
  nguồn (PDF page/rect, url/scroll, audio timestamp).

Ba lực đẩy mâu thuẫn cần cân: (1) linh vật phải có mặt ở **mọi tab** và chủ động ⇒
cần lớp phủ ngoài màn hình push; (2) tái dùng tối đa hạ tầng có sẵn để không trùng
não/chi phí; (3) mọi hành động mới không được phá hợp đồng điều hướng và quy tắc vàng.

## Quyết định

### D1 — Linh vật là LỚP PHỦ trong MainShell, không phải màn hình push mới

- Bong bóng đặt trong `Stack` của `MainShell` (trên content, dưới/đứng cạnh bottom nav),
  kéo được, autohide thành chấm nhỏ, ẩn hẳn được trong Cài đặt.
- Hội thoại mở dạng **sheet** kéo lên; màn `AiChatScreen` hiện có GIỮ NGUYÊN — cùng
  một bộ não (`AiServiceFacade`), linh vật là lối vào nhanh + vai trò, không phải bản
  chat thứ hai.

### D2 — MỘT registry hành động là nguồn sự thật của mọi điều linh vật làm được

- `MascotIntentRegistry` (thuần Dart): mỗi `ActionDef` có `id`, nhãn i18n, matcher
  lệnh vi/en, nhóm và hàm thực thi qua hub. Palette mở nhanh, lệnh giọng deterministic
  và yêu cầu hành động từ LLM (JSON một dòng `{"say":…, "action":…}`) đều đi qua cổng
  này — một nơi đăng ký, mọi mặt nhìn thấy.
- JSON hỏng ⇒ chỉ hiển thị lời nói, không thực thi; hành động ghi/xoá luôn có xác nhận.
- 8 intent `voice_command` cũ được đăng ký lại thành hành động registry cùng ngữ nghĩa
  (parser cũ giữ nguyên cho luồng phát lại tab Nghe).

### D3 — Mở rộng `ShellNavigationRequest`, không tạo cơ chế điều hướng thứ hai

- Thêm target `home/understand/remember` + yêu cầu tool (`id` từ registry) + payload
  (định danh nguồn file/audio/book). Hợp đồng `openRead/openListen` cũ giữ nguyên.
- Shell thêm một "cầu" nhỏ (`ShellActionHub`) bọc `_setPrimaryTab/_setListenMode/
  _setReadMode/_handleTool` để tầng ngoài gọi được mà không đụng private state.

### D4 — Não dùng `AiServiceFacade` + ngữ cảnh theo tab có trần ký tự

- Persona (quản gia/gia sư/hướng dẫn) + ngữ cảnh tab (khuôn `UnderstandAiContext`,
  trần ~1.2k ký tự cho mascot) inject qua `oneShotContext`; streaming/stop/epoch
  hành xử như AI chat hiện có.
- Prompt hệ thống là **nội dung AI** (không đưa vào catalog i18n); chrome của mascot
  thì phải i18n đầy đủ (Rule 5) trong cùng PR.

### D5 — Giọng nói = `SttServiceFacade` → máy trạng thái thuần → `TtsService`

- `MascotVoiceLoop` (thuần, test được): `idle → listening → thinking → speaking`,
  barge-in khi phát hiện speech lúc đang speaking ⇒ stop TTS bằng epoch guard sẵn có.
- Không tự dựng engine STT/TTS mới, không đụng FFI UltraTimeStretch (quy tắc vàng 1).
- Chính sách âm thanh: không tự TTS khi audio học đang phát; duck → restore qua
  `PlayerProvider`, không hủy bài.

### D6 — Offline-first & riêng tư

- Palette + lệnh deterministic + tour + FAQ chạy khi không mạng; hội thoại AI rớt về
  Gemma local khi offline; cloud chỉ theo routing người dùng đã cấu hình.
- Không gửi nội dung user nếu không có yêu cầu rõ ràng từ người dùng.

### D7 — Hình mẫu theo thương hiệu có sẵn, không thêm dependency

- Đốm sáng "Hidden Gift Quiet Reveal 04A": Midnight `#06121E`, gradient Jade→Gold,
  viền Ivory; hoạt ảnh Lottie CC0 dựng trong `assets/animations/mascot/`
  (`lottie: ^3.6.1` đã có). 4 trạng thái idle/listening/thinking/speaking.

## Hệ quả

- (+) Trợ lý có mặt mọi nơi, một bộ não không nhân bản, offline dùng được phần lớn.
- (+) Mọi tính năng điều hướng mới của app chỉ cần **đăng ký một dòng** vào registry
  để palette + giọng + LLM đều gọi được — tăng chi phí nhỏ khi thêm tool, đổi lại
  không có đường tắt rải rác.
- (−) Overlay phải tự quản lý inset/autohide/fontScale để không che chrome thiết yếu
  (kiểm cả máy font chữ lớn — bài học XLAT-SCR-006).
- (−) Chưa có wake-word hands-free ngầm (cần spike sherpa KWS + quyền mic nền ⇒ ADR
  riêng sau P2); P2 dùng nhấn-bong-bóng-để-nói và barge-in khi vòng giọng mở.
- (−) Không có "nhớ sở thích" dài hạn riêng của mascot ở P0–P3 (chỉ prefs cài đặt);
  nếu cần ⇒ ADR mới theo luật.
