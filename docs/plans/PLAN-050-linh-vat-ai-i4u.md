# PLAN-050 — Linh vật AI In4Up (I4U Mascot): quản gia · gia sư · hướng dẫn dùng app

> **Trạng thái:** 📋 proposed — đã khảo sát repo (2026-11-25) và lập kế hoạch;
> chờ owner chốt DQ1–DQ5 (§12) rồi thi công theo thứ tự P0→P4.
> **Nguồn:** người sở hữu (2026-11-25, qua agent `arena/4ad3035e-in4up`) —
> *"tạo Linh vật AI đóng vai trò quản gia, gia sư, hướng dẫn dùng app, có thể chat
> hay trò chuyện âm thanh, có thể mở nhanh các file, chức năng… Mục đích: giải phóng
> thời gian, công sức, nâng cao trải nghiệm, hiệu suất trong khi dùng app."*
> **ADR:** [ADR-0036 — linh vật AI: lớp trợ lý nổi trong shell + registry hành động](../adr/0036-linh-vat-ai-assistant-overlay-intent-registry.md) (proposed).
> **Card:** `MASCOT-001..008` trong `docs/project/KANBAN.md`.
> **Phiên bản nền:** `1.29.2+31` (tip `74242d42`, nhánh `arena/4ad3035e-in4up`).

## 1. Mục tiêu

Một linh vật AI **duy nhất** xuất hiện trong toàn app, kết hợp 3 vai trò:

1. **Quản gia** — chủ động lo việc hộ người học: "học tiếp bài dở", "ôn X từ đến hạn",
   tổng kết nhịp học, nhắc khi có việc đáng làm; tự thực hiện được hành động, không
   chỉ trả lời.
2. **Gia sư** — dạy theo ngữ cảnh đang mở: giải thích từ/câu đang đọc/nghe, hỏi đáp
   kiểm tra hiểu bài, luyện shadowing có chấm phản hồi, quiz từ vựng đến hạn.
3. **Hướng dẫn dùng app** — dẫn đường: tour tương tác từng khu vực chức năng, trả lời
   "cách làm X trong In4Up" theo dữ liệu tour nội bộ (không cần mạng).

2 hình thức tương tác:

- **Chat chữ** (streaming, có ngừng được, có lịch sử).
- **Hội thoại âm thanh** (nói → nghe hiểu → trả lời bằng giọng, có barge-in — nói đè
  để dừng/đổi ý).

1 năng lực nền: **mở nhanh file & chức năng** — một registry hành động + một bộ chỉ
mục tìm kiếm hợp nhất, gọi được bằng chữ lẫn giọng.

**Đo thành công theo mục đích owner:** giảm số bước để làm một việc (mở file, bật chế
độ học, ôn từ), tăng tần suất quay lại học (streak/gợi ý đúng lúc), trải nghiệm mới
người dùng không cần "mò" app. Mỗi card nghiệm thu phải chỉ ra **đường trước/sau**
(theo số bước).

## 2. Khảo sát nội bộ — hiện trạng & khe hở

| Khu vực | Hiện trạng (bằng chứng trong repo) | Kết luận cho linh vật |
|---|---|---|
| Não hội thoại | `packages/in4up_ai/lib/src/facade/ai_service_facade.dart` (1.989 dòng): singleton ChangeNotifier, chat history persist, `sendMessage(message, {oneShotContext})`, SSE streaming, `stopGenerating()`, `clearChat()` epoch guard; local Gemma GGUF (llama.cpp) + remote OpenAI-compat; provider có sẵn OpenRouter seed lần đầu, model mặc định `openrouter/free`, routing `AiRouteCapability.chat = onlineFirst` (`builtin_ai_providers.dart`) | **Tái dùng, không dựng não thứ hai.** Linh vật là một "mặt.CLIENT" trên cùng facade; prompt hệ thống + ngữ cảnh do mascot inject qua `oneShotContext` |
| Ngữ cảnh theo tab | `lib/features/understand_ai/understand_ai_context.dart` + `understand_ai_prompts.dart`: bó ký tự selected 600 / surrounding 1200 / recent 1600; prompt là nội dung AI (không đưa vào catalog dịch) | Khuôn mẫu chép cho `MascotContextBuilder` — mỗi tab một snapshot có trần ký tự, cắt ở biên câu |
| Tai (STT) | `packages/in4up_stt/lib/stt_service_facade.dart` (1.387 dòng): Whisper, Sherpa Zipformer streaming, remote; `startListening` / `liveResultStream`; Sherpa VI streaming đã dùng ở Cabin (SHERPA-WP4-01) và QuickCapture (`lib/screens/home/quick_capture/`) | Đường mic linh vật đi qua facade này; thêm **không** engine mới. Lưu ý: STT tiếng Việt streaming là "simulated streaming" — kiểm máy thật ở P2 |
| Miệng (TTS) | `lib/features/tts/tts_service.dart` (2.412 dòng): multi-engine Edge/Piper/VieNeu/FPT/Zalo/Google/OpenAI-compat/offline, epoch/stop guard, queue per-session (ADR-0019) | Đường trả lời bằng giọng đi qua `TtsService`; barge-in dùng stop guard sẵn có, không đụng FFI UltraTimeStretch (quy tắc vàng 1) |
| Điều khiển phát | `PlayerProvider` (play/pause/seek/speed/currentSongTitle), `TextProvider` (currentDocument/currentTextPath), `VocabularyProvider` (dueCount/dueWords/reviewWord/saveToWordList), `AudioLibraryProvider`, `SoundlistProvider`, `DharmaProvider`, `TextDeviceProvider` | "Bàn tay" của quản gia/gia sư — gọi trực tiếp provider đã đăng ký ở `lib/main.dart` (MultiProvider) |
| Điều hướng shell | `lib/screens/main_shell.dart`: `_PrimaryTab{home,listen,read,understand,remember}`, `_setPrimaryTab/_setListenMode(0-2)/_setReadMode(0-1)`, `_handleTool(toolId)` là **dispatcher trung tâm** của ~28 tool id (`shell_ui_settings`, `live_cabin`, `youtube_downloader`, `web_reader`, `pdf_reader`, `tipitaka`, `video_library`, `media_tools`, `dict_manager`, `dictionary`, `dict_packs`, `speak_mode`, `write_mode`, `understand_tab`, `understand_ai_coach`, `youglish`, `learn_by_heart`, `review`, `word_list`, `sound_list`, `timeline`, `wordlist_stats`, `stats`, `word_map`, `triangle`, `venn`, `video_player`); quick actions xếp hạng theo usage (`StorageService.getQuickActionUsageCount`) | **Khe hở 1:** không có cách gọi `_handleTool`/chuyển tab từ bên ngoài widget tree. → registry hành động + cầu gọi (MASCOT-001) |
| Điều hướng từ route push | `lib/core/navigation/shell_navigation_request.dart`: chỉ 2 target `read`/`listen` qua `ValueNotifier` | **Khe hở 2:** mở rộng target + payload (toolId, file path, audio id) — vẫn giữ hợp đồng cũ |
| Mở nhanh file | `RecentFilesService` (tab Đọc), `TextLibraryService` (Firestore), `AudioLibraryService` (Hive merge), video library, Tipiṭaka library, dict packs | **Khe hở 3:** chưa có tìm kiếm hợp nhất đa nguồn → `MascotSearchIndex` (MASCOT-002) |
| Trợ lý đã có | AI chat là **màn hình push** + card "I4U AI Chat" ở Home; coach AI chỉ trong tab Hiểu (`understand_ai_coach`) | **Khe hở 4:** không có trợ lý nổi toàn app, không có vai trò chủ động (quản gia) hay dẫn dắt (hướng dẫn) |
| Lệnh giọng cũ | `lib/features/voice_command/`: parser thuần ngữ pháp vi/en + executor, 8 intent phát lại (play/pause/next/prev/faster/slower/lyrics/translate) | Tiền đề tốt — registry intent mới sẽ **nuốt** grammar này thành hành động đăng ký, giữ tương thích |
| Nhịp học (cho quản gia) | `LearningActivityService` (`in4up_learning_activity_v1`): record idempotent theo (ngày, kind, sourceKey), `snapshot(days)`, `streak`, `today`; `FocusProvider` là lớp xem; `ContinueLearningCard` đọc provider thật (bài dở nghe/đọc, từ đến hạn) | Dữ liệu "quản gia chủ động" đã có sẵn, không hardcode — chỉ cần bộ **quy tắc gợi ý** thuần (MASCOT-006) |
| Overlay nổi (tiền đề UX) | `word_mini_pop.dart` trên `OverlayEntry` không chặn (ADR-0016); bong bóng dịch toàn hệ thống (XLAT-SCR-002, lane native); QuickCaptureSheet mic→WordList; `showToolsOverlayV2` overlay công cụ | Linh vật = overlay trong `Stack` của MainShell (không phải màn push); kinh nghiệm autohide/inset đã có (`lib/utils/system_insets.dart`) |
| Thương hiệu & hoạt ảnh | `brand/identity/README.md`: Hidden Gift Quiet Reveal **04A**; Midnight `#06121E`, Bodhi gold `#F4C95D`, Jade `#53D6BD`, Ivory `#F8F4EA`; gradient Jade→Gold ("rise"); `assets/animations/` 100 khái niệm Lottie CC0 (`concept_animation_pack.json`) + `lottie: ^3.6.1` đã có (LOTTIE-001) | Dựng linh vật bằng khối hình học In4Up + Lottie nhẹ — **không thêm dependency**, không vật nuôi bản quyền |
| i18n | 26 ARB; Rule 5 AGENTS.md: chrome ≠ vi phải có dịch; key mới T2 (en/hi/zh/zh_TW/si) đủ ngay trong PR qua `lib/core/language/priority_ui_overrides.dart` + `tool/legacy_ui_english_overrides.json`; **KHÔNG chạy `tool/generate_arbs.py`**; prompt AI là nội dung (không catalog) | Mỗi card MASCOT phải kèm 5 locale trong cùng PR (bài học REL-1.29.2: thiếu nhãn ⇒ CI đỏ sau tag) |
| CI / môi trường | Oracle `.github/workflows/app_analyze.yml` (flutter 3.44.1, chỉ ERROR fatal; quét Rule 5 + các test thuần); sandbox **không có Flutter SDK** ⇒ chỉ test thuần Dart + CI | Toàn bộ logic mới viết **thuần Dart** (`lib/features/mascot/`) + `test/mascot/` thuần; UI chỉ nghiệm thu máy (G0–G5 kiểu PLAN-047) |
| Quản trị | KANBAN nguồn sự thật; ADR bắt buộc khi đổi kiến trúc; quy tắc vàng: không đụng FFI, không gộp 3 SM-2, không mất khả năng mở lại đúng vị trí nguồn | Ghi vào §4 + ADR-0036; mascot chỉ **gọi** API mở nguồn hiện có, không tự mở file theo đường dẫn |

## 3. Tham chiếu ngoại bộ

> Ghi chú trung thực: sandbox phiên này chỉ có egress GitHub/npm/PyPI nên **không
> fetch được trang sản phẩm ngoài**; mục dưới đây là kiến thức phổ quát đã kiểm định,
> dùng để định vị thiết kế, không làm bằng chứng nghiệm thu.

| Sản phẩm / pattern | Bài học rút cho linh vật |
|---|---|
| Command palette (VS Code, Linear, Notion) | Mở bằng ≤2 thao tác từ **mọi** nơi; xếp hạng theo tần suất + ngữ cảnh; gõ gần đúng vẫn ra (fuzzy/romanized). In4Up đã có điểm "Quick actions" xếp theo usage ở shell — palette là bản **tìm kiếm được** của cùng dữ liệu |
| Trợ lý thiết bị (Google Assistant / Siri) | Ngữ pháp lệnh ngắn cho việc máy làm được ("mở X", "phát Y", "ôn từ") đi đường **deterministic** (không cần LLM khi mạng kém); hội thoại mở đi LLM. Tách hai đường này tiết kiệm latency + token |
| Điểm nổi động (Anthropic Claude mobile, ChatGPT voice) | Barge-in là điều kiện bắt buộc để hội thoại "thật": dừng TTS ngay khi người dùng bắt đầu nói; trạng thái nhân vật phản ánh máy đang nghe/nghĩ/nói |
| Onboarding tour (Duolingo, Notion first-run) | Tour phải chạy trên **dữ liệu thật** (highlight widget thật, không screenshot); mỗi bước có thể bỏ qua; lưu tiến độ tour trong prefs |
| Gia sư AI (Khanmigo) | Gia sư tốt **hỏi ngược** và chia bước, không làm hộ bài: system prompt của vai gia sư cấm "làm hộ", ưu tiên gợi ý + kiểm tra hiểu bài |

## 4. Định vị & nguyên tắc thiết kế

1. **Một bộ não, nhiều mặt.** Linh vật, màn AI Chat hiện có và coach Hiểu dùng chung
   `AiServiceFacade`. Linh vật KHÔNG nhân bản engine chat; chỉ thêm persona + ngữ cảnh
   + khả năng thực thi hành động.
2. **Một registry hành động.** Mọi điều linh vật làm được (chuyển tab, mở tool, mở file,
   phát/dừng, lưu từ, trả lời) đăng ký trong `MascotIntentRegistry` thuần Dart — palette,
   lệnh giọng và LLM đều đi qua một cổng này (ADR-0036 D2).
3. **Offline-first, riêng tư.** Palette + lệnh deterministic + tour chạy khi không mạng;
   hội thoại AI rớt về Gemma local khi offline; routing cloud chỉ theo cấu hình người
   dùng hiện có. Không gửi nội dung user đi đâu nếu người dùng không yêu cầu.
4. **Không đụng vùng bảo vệ.** Không sửa `lib/ffi/` UltraTimeStretch; không gộp 3 SM-2;
   không tự đọc/ghi file bỏ qua `RecentFilesService`/library service (giữ khả năng mở
   lại đúng nguồn — quy tắc vàng 3).
5. **Chrome i18n trong cùng PR.** Nhãn chrome mới của mascot đi qua
   `priority_ui_overrides.dart` (en/hi/zh/zh_TW/si) hoặc `uiText('…')` + overrides EN;
   prompt/AI output giữ nguyên nguồn. File UI import `core/language/localized_material.dart`.
6. **Nhân vật nhẹ.** Overlay Lottie nhỏ, idle thở nhẹ; không nạp sẵn Gemma chỉ vì
   linh vật (tái dùng hành vi nạp/lẫy của facade); có Cài đặt: bật/tắt, ẩn hẳn, vị trí.

## 5. Kiến trúc đề xuất

```
lib/features/mascot/
  mascot_intent_registry.dart     // thuần: IntentDef/ActionDef, ghép lệnh vi/en,
                                  //  định danh hành động = nguồn sự thật (ADR-0036 D2)
  mascot_action_hub.dart          // cổng thực thi: nhận IntentResult → điều hướng/
                                  //  provider/tool; Thuần phần quyết định, IO qua callback
  mascot_search_index.dart        // thuần: chỉ mục hợp nhất + chấm điểm fuzzy/romanized
  mascot_context_builder.dart     // thuần: snapshot theo tab (trần ký tự kiểu coach)
  mascot_prompts.dart             // thuần: persona quản gia/gia sư/hướng dẫn + format
                                  //  yêu cầu hành động (không phải chrome)
  mascot_voice_loop.dart          // thuần: máy trạng thái idle→listening→thinking→
                                  //  speaking→barge-in (epoch guard)
  mascot_proactive_rules.dart     // thuần: quy tắc gợi ý quản gia từ dữ liệu thật
  mascot_tour_data.dart           // thuần: script tour từng khu vực app
  mascot_settings.dart            // prefs: bật/tắt, ẩn, vị trí, giọng, mức chủ động
  widgets/mascot_bubble.dart      // overlay trong MainShell (Lottie 4 trạng thái)
  widgets/mascot_chat_sheet.dart  // hội thoại (streaming, tái dùng facade)
  widgets/mascot_palette.dart     // palette mở nhanh
  widgets/mascot_tour_overlay.dart// highlight + bước tour
```

Liên kết hệ thống:

```
                    ┌──────────────────────── MainShell (Stack) ─────────────────────────┐
                    │  content tabs ── bottom nav ── [MascotBubble overlay]              │
                    └──────────────┬──────────────────────────────────┬─────────────────┘
                                   │ chat / palette / giọng            │
                            MascotController (ChangeNotifier, mới ở main.dart
                            sau AiServiceFacade — cần facade sẵn)
                                   │
        ┌──────────────┬───────────┴────────┬─────────────────┬──────────────────┐
   MascotIntent  MascotSearchIndex  MascotContext  MascotVoiceLoop   ProactiveRules
     Registry        (files/tools)      Builder        (STT/TTS)         (quản gia)
        │                                                        │
  MascotActionHub ──► ShellActionHub (mới: bọc _handleTool/       │
        │               _setPrimaryTab/_setListenMode/_setReadMode)  │
        │                                                        │
  AiServiceFacade (đã có: Gemma local ⇄ OpenRouter remote) ◄─────┘
  SttServiceFacade + TtsService (đã có)
  PlayerProvider · TextProvider · VocabularyProvider · LearningActivityService (đã có)
```

- **Cầu shell (ShellActionHub):** main_shell expose các hàm điều hướng qua một
  `GlobalKey<MascotShellBridgeState>` hoặc ValueNotifier mở rộng
  `ShellNavigationRequest` (target `home/understand/remember` + `tool(id)` + `payload`).
  Chọn ValueNotifier mở rộng vì đã là hợp đồng hiện có (`openRead/openListen`).
- **Protocol hành động từ LLM:** mascot yêu cầu model trả **một dòng JSON**
  `{"say": "...", "action": {"id": "...", "args": {...}}}` hoặc chỉ văn bản;
  `MascotIntentRegistry.parse()` chấp nhận cả JSON lẫn lệnh thường vi/en. JSON hỏng ⇒
  chỉ hiện `say`, không thực thi (an toàn).
- **Tương thích lùi:** 8 intent `voice_command` cũ được đăng ký lại thành hành động
  registry cùng ngữ nghĩa; parser cũ giữ nguyên cho luồng phát lại trong tab Nghe.

## 6. Ba vai trò chi tiết

### 6.1 Quản gia (chủ động, dựa dữ liệu thật)

- Nguồn gợi ý — chỉ đọc, không hardcode:
  - Bài dở: `PlayerProvider.currentSongTitle`, `TextProvider.currentDocument/currentTextPath`
    (nguồn `ContinueLearningCard` đã dùng).
  - Ôn tập: `VocabularyProvider.dueCount/dueWords`; LHB theo `LearnByHeartProvider`.
  - Nhịp học: `LearningActivityService.snapshot()/streak/today` (qua `FocusProvider`).
  - Gần đây: `RecentFilesService` + audio/video library.
- Kênh trình bày: (a) chip gợi ý trên bong bóng (1 dòng, tappable, tự biến mất);
  (b) "Tổng kết hôm nay" khi mở app lần đầu ngày; (c) trả lời câu hỏi quản gia qua chat.
- Mức chủ động theo Cài đặt (tắt được hoàn toàn — MASCOT-006); **không** gợi ý khi
  audio đang phát hay trong focus mode; tối đa 1 chip/nhịp, cooldown.

### 6.2 Gia sư (theo ngữ cảnh đang mở)

- Giải thích từ/câu đang đọc: tái dùng đường `WordInsight`/selection hiện có, mascot
  đóng gói thành hội thoại (nối tiếp coach Hiểu — cùng pattern `UnderstandAiContext`).
- Quiz từ đến hạn: bốc từ `dueWords`, hỏi–đáp bằng chữ hoặc giọng; chấm qua
  `VocabularyProvider.reviewWord` (không tự chế SRS, không gộp 3 SM-2).
- Shadowing coach: nối sang coach Nói hiện có (gợi ý + chấm phản hồi đã có ở tab Nói/Hiểu).
- System prompt vai gia sư: **hỏi ngược, chia bước, không làm hộ** (tham chiếu §3).

### 6.3 Hướng dẫn dùng app

- Tour registry thuần: danh sách bước (mục tiêu widget theo key, tiêu đề, mô tả) cho
  ≥3 lộ trình đầu: "Vòng học 5 tab", "Đọc & tạo lời", "Ôn từ & Vườn nhớ".
- Hỏi "cách làm X" → khớp tour/FAQ nội bộ **deterministic** trước (offline), không có
  mới rơi xuống LLM với ngữ cảnh tour.
- Onboarding lần đầu (prefs `mascot_onboarding_done_v1`): 3 bước, bỏ qua được.

## 7. Mở nhanh file & chức năng (MASCOT-001 + MASCOT-002)

- **Registry hành động** (nguồn sự thật): mỗi `ActionDef` gồm `id`, nhãn i18n, nhóm
  (`tab/tool/data/playback/tutor`), matcher lệnh vi/en, hàm thực thi (qua hub).
  Đăng ký đầy đủ ~28 tool id hiện có + 5 tab + 4 sub-mode (Nghe/Nói/Xem, Đọc/Viết).
- **Chỉ mục hợp nhất** (bộ nhớ, rebuild khi provider notify — rẻ, không persist):
  tools + tab/mode + tài liệu gần đây (`RecentFilesService`, `TextLibraryService`) +
  audio (`AudioLibraryService`) + video + bài Tipiṭaka + bộ từ điển + từ trong WordList.
  Chấm điểm thuần: khớp tiền tố/chứa/fuzzy không dấu (người Việt gõ không dấu vẫn ra) +
  boost theo usage (`getQuickActionUsageCount`) + boost ngữ cảnh tab hiện tại
  (khuôn `_quickActionScore` đã có ở main_shell).
- **Palette UI:** mở từ bong bóng (tap) hoặc giọng ("mở nhanh…"); Enter = thực thi,
  mũi tên = chọn; mỗi dòng hiện nguồn (Tab Đọc · PDF / Nghe · Audio…).
- **Mở file an toàn:** palette trả về `payload` đúng định danh nguồn mà service hiện có
  yêu cầu (path PDF/audio id/book id) — **không** mở lại file bằng đường dẫn chế tạo
  (quy tắc vàng 3).

## 8. Trò chuyện chữ & hội thoại âm thanh

- **Chat:** sheet kéo lên từ bong bóng; lịch sử/tin nhắn đi qua `AiServiceFacade`
  (giữ epoch/stop). Chuỗi hệ thống persona + ngữ cảnh tab inject qua `oneShotContext`;
  streaming + nút dừng như AI chat hiện có. Không phá màn AI Chat cũ — sheet linh vật
  là **lối vào nhanh**, hội thoại dài vẫn khuyến nghị mở AI Chat (nút trong sheet).
- **Vòng giọng (máy trạng thái thuần `MascotVoiceLoop`):**
  `idle → listening (SttServiceFacade.startListening, liveResultStream hiện chữ) →
  thinking (stop STT → gửi facade) → speaking (TtsService.speak) → (barge-in:
  phát speech khi đang speaking ⇒ stop TTS bằng epoch guard → về listening)`.
- **Barge-in:** bật mặc định khi vòng giọng mở; không chạy khi audio học đang phát
  (tránh nuốt giọng bài học) — muốn hỏi thì nhấn bong bóng (tạm dừng phát, quay lại
  tiếp tục).
- **Chính sách âm thanh:** mascot **không** tự TTS khi `PlayerProvider` đang phát,
  trừ khi người dùng chủ động mở vòng giọng; khi trả lời xong khôi phục playback
  (duck → restore, không hủy bài).
- **Đường không cần LLM:** lệnh deterministic ("mở PDF", "ôn từ", "dừng") khớp registry
  **trước** khi gọi model — offline vẫn dùng được mở nhanh bằng giọng.
- Whisper/Sherpa/Edge/Piper/VieNeu đều là engine đã cấu hình trong app — mascot chỉ
  dùng facade; chọn giọng mặc định theo Cài đặt TTS hiện có.

## 9. Lộ trình P0–P4, card và tiêu chí nghiệm thu

| Pha | Card | Nội dung | Nghiệm thu (tối thiểu) |
|---|---|---|---|
| **P0** nền móng | MASCOT-001 | Registry hành động + `ShellNavigationRequest` mở rộng + `ShellActionHub` | Thuần Dart + test: mọi action có định danh, matcher vi/en, hợp đồng nav cũ không gãy; CI xanh |
| **P0** | MASCOT-002 | `MascotSearchIndex` + palette UI | Palette mở ≤2 thao tác từ mọi tab; tìm "piper", "kinh", "phat am" không dấu đều ra đúng; ≤150 ms cho ~1000 mục (đo trong test) |
| **P1** linh vật chat | MASCOT-003 | `MascotController` + persona prompts + context builder + protocol hành động JSON | Prompt có đúng snippet tài liệu/nghe đang mở (test snapshot builder); JSON hỏng không thực thi; offline rớt Gemma vẫn trả lời |
| **P1** | MASCOT-004 | Bong bóng nổi trong MainShell + chat sheet | Kéo được, autohide thành chấm nhỏ, không che bottom nav/controls thiết yếu; chrome i18n đủ 5 locale T2; QA Android + Windows |
| **P2** giọng nói | MASCOT-005 | Vòng giọng STT→LLM→TTS + barge-in + chính sách duck | Hội thoại ≥5 lượt không treo; nói đè dừng TTS <300 ms (máy thật); không tự TTS khi audio đang phát |
| **P3** quản gia/gia sư | MASCOT-006 | Proactive rules + chip gợi ý + tổng kết ngày | Gợi ý sinh từ dữ liệu thật (test rules với snapshot giả); tắt được trong Cài đặt; không làm phiền khi phát |
| **P3** | MASCOT-007 | Gia sư: giải thích ngữ cảnh, quiz dueWords, nối coach | Quiz chấm đúng qua `reviewWord` (test thuần); giải thích có trích nguồn đang mở |
| **P4** hướng dẫn | MASCOT-008 | Tour registry + overlay highlight + FAQ "cách làm X" | ≥3 tour chạy trọn được; onboarding chỉ 1 lần; FAQ khớp offline |
| **P4** | MASCOT-POLISH (phụ thuộc) | Đo RAM/latency, tối ưu, thêm giọng/ngôn ngữ theo DQ2, dựng hoạt ảnh riêng nếu owner chọn hình mẫu mới | Không tăng RAM idle; đo trước/sau ghi vào card |

Thứ tự land giữ chuẩn dự án: nhánh con → CI (`app_analyze.yml` + test thuần) →
nghiệm thu máy → cập nhật KANBAN (append). Mỗi card = một PR, chrome i18n trong cùng PR.

## 10. i18n, thương hiệu & hoạt ảnh

- **Chrome:** nhãn bong bóng, palette, tour, cài đặt mascot —
  `priority_ui_overrides.dart` T2 (en/hi/zh/zh_TW/si) + `legacy_ui_english_overrides.json`;
  test máy bắt Rule 5 phải xanh ngay ở PR đầu tiên có UI.
- **Không dịch:** prompt hệ thống, output AI, transcript STT, nội dung user.
- **Hình mẫu mặc định (đề xuất — chờ DQ1):** "đốm sáng Hidden Gift" — khối tròn phát
  sáng nhẹ theo motif Quiet Reveal 04A, gradient Jade→Gold như đường "rise" của logo,
  nền Midnight, viền Ivory mờ; 4 trạng thái:
  - `idle`: thở + lấp lánh nhẹ (Lottie ~60 frame, ≤80 KB),
  - `listening`: vòng sóng mở dần quanh đốm,
  - `thinking`: các hạt Jade xoáy chậm,
  - `speaking`: nhịp sáng theo biên độ (thuộc tính playback của TTS là đủ, không cần PCM).
- Lottie dựng trong `assets/animations/mascot/` theo schema khái niệm có sẵn;
  đầu P1 dùng **biến thể CSS/Transform đơn giản** nếu chưa kịp dựng Lottie — không chặn card.

## 11. Rủi ro & biện pháp

| Rủi ro | Mức | Biện pháp |
|---|---|---|
| RAM: Gemma local + overlay mascot cùng lúc | cao | Không giữ model nạp sẵn vì mascot; theo profile RAM đã có (1.29.1 `a3bf6b84`); đo ở MASCOT-POLISH |
| Barge-in bắt nhầm (tiếng nền bài học) | cao | Vòng giọng tự khóa khi audio đang phát; ngưỡng speech từ Sherpa VAD; test máy thật bắt buộc |
| TTS đè playback / mất vị trí | cao | Duck → restore qua `PlayerProvider` (không hủy bài); epoch guard TTS sẵn có |
| Palette chậm khi index lớn (Tipiṭaka nghìn bài) | trung | Index dựng lười theo nguồn, trần số mục/nguồn, đo trong test thuần |
| Rule 5 đỏ (thiếu dịch chrome) | trung | Danh sách chuỗi chrome chốt ngay lúc viết card; i18n trong cùng PR (bài học REL-1.29.2) |
| LLM trả JSON sai định dạng | trung | Parser khoan dung + fallback "chỉ nói"; hành động nhạy cảm (xoá/ghi) luôn có xác nhận |
| STT tiếng Việt streaming trên máy thật | trung | Sherpa VI là simulated streaming — nghiệm thu P2 trên máy thật trước khi quảng bá hands-free |
| Overlay che nội dung/chrome | trung | Autohide + vùng chạm nhỏ + cài đặt ẩn hẳn; kiểm cả nhỏ máy + fontScale lớn (bài học XLAT-SCR-006) |
| Chi phí cloud nếu mascot onlineFirst | thấp | Trần ngữ cảnh mascot (~1.2k ký tự) thấp hơn coach; lệnh deterministic đi trước; quyết định cuối theo DQ3 |

## 12. Quyết định cần owner chốt (DQ1–DQ5)

| # | Câu hỏi | Đề xuất mặc định (nếu owner không chọn) |
|---|---|---|
| DQ1 | **Tên & hình linh vật?** Phương án: (a) **"Upi"** — đốm sáng Hidden Gift, dễ gọi giọng "Upi ơi"; (b) **"Bồ Đề"** — gắn Bodhi gold, tông tĩnh lặng; (c) để sau, dùng tên mã MASCOT | (a) Upi + đốm sáng §10 |
| DQ2 | **Ngôn ngữ hội thoại giọng nói ưu tiên?** vi+en trước (STT Sherpa vi/en + Whisper đa ngữ) / chỉ vi / đủ vi·en·hi·zh·si (kiểm STT từng ngôn ngữ) | vi + en trước |
| DQ3 | **Não mặc định?** (a) theo routing hiện có (ưu tiên online OpenRouter, rớt Gemma offline); (b) mascot riêng offline-first (Gemma trước, cloud chỉ khi bật) | (a) theo routing hiện có + trần ngữ cảnh §11 |
| DQ4 | **Vị trí & hành vi bong bóng?** góc phải-dưới trên bottom nav / góc trái-dưới / ẩn mặc định chỉ mở từ Home | góc phải-dưới, autohide 10 s, ẩn hẳn được |
| DQ5 | **Bắt đầu P0 ngay?** P0 (MASCOT-001+002) độc lập persona, có giá trị dùng riêng (palette) | Duyệt P0 làm ngay, P1 chờ DQ1–DQ3 |

## 13. Chiến lược kiểm thử & CI

- **Thuần Dart trước** (`test/mascot/`): registry matcher, index scoring + fuzzy không
  dấu, context builder trần ký tự, voice loop state machine (kể cả barge-in epoch),
  proactive rules với snapshot giả, tour data hợp lệ (mỗi bước có key tiêu đề).
- Bài học dự án: **không viết widget test phụ thuộc plugin** (DICT-SCREEN-001 treo
  runner) — UI nghiệm thu bằng máy thật; thêm seam bơm dữ liệu nếu cần widget test.
- CI: thêm bước `flutter test test/mascot/` vào `app_analyze.yml` ở PR P0 đầu tiên
  (khuôn bước "PLAN-039" hiện có); analyze chỉ ERROR là fatal.
- Máy thật: ma trận Android (máy chính owner) + Windows; iOS/Linux ở P4 polish.

## 14. Không làm trong kế hoạch này (non-goals)

- Không dựng engine AI/STT/TTS mới hay phụ thuộc mới (lottie, provider đã đủ).
- Không đổi `UltraTimeStretch` FFI, không gộp 3 SM-2, không đụng schema Evidence.
- Không thay thế màn AI Chat hiện có hay coach Hiểu — chỉ thêm lớp nổi dùng chung não.
- Không wake-word hands-free ngầm (cần spike sherpa KWS + quyền mic nền — làm ADR riêng
  nếu owner muốn sau P2).
- Không gửi nội dung user lên cloud ngoài routing cấu hình sẵn của người dùng.
- Không tự ghi nhớ dài hạn dữ liệu riêng của mascot ở P0–P3 (dùng prefs cài đặt +
  dữ liệu provider hiện có); nếu cần "nhớ sở thích" lâu dài → ADR mới.
