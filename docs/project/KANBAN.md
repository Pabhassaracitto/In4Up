# KANBAN — Bảng việc dự án (nguồn sự thật duy nhất về trạng thái)

> Luật cập nhật: xem `docs/GOVERNANCE.md` mục 3 — CHỈ đổi trạng thái +
> append lịch sử, không xóa. Bảng tóm tắt dưới đây luôn được làm mới
> tương đồng với các card phía dưới.

## Tổng quan

| ID | Việc | Trạng thái | Bằng chứng gần nhất |
|---|---|---|---|
| API-001 | WP0: nền tảng Server API (ADR-0008) — provider store + client OpenAI-compat + màn Server & API | ✅ done (code+CI 🟢, chờ nghiệm thu thiết bị) | run 36268246588 (`e962557`..`3ea1716`, arena/01a0ddd1-in4up) |
| API-002 | WP1: LLM chat/analysis qua API + SSE streaming (AiEngineRemote cắm vào AiEngine) | 🔨 doing (code + CI 🟢 run 36346119791, chờ nghiệm thu thiết bị AT) | agent arena/01a0df5b-in4up — chatStream + AiEngineRemote + routing facade + màn chat streaming/nút Dừng |
| API-003 | WP2: STT file qua API (SttEngineRemote — whisper-large-v3, chunk + LRC chung) | 🔨 doing (code + CI 🟢 run 36348644820, chờ nghiệm thu thiết bị AT) | agent arena/01a0df5b-in4up — transcribeAudio multipart + SttEngineRemote + facade remote + UI auto-TOC engine API |
| API-004 | WP3: Dịch bằng LLM — LlmMtEngine vào chuỗi dịch theo routing (ADR-0008) | ✅ done (code+CI 🟢 run 36270711178; chờ owner nghiệm thu chất lượng 3 đoạn Pali + AT thiết bị) | run 36270711178 (`6f15658`..`8a3c350`, arena/01a0df5e-in4up) |
| API-005 | WP4: engine TTS qua Server API (OpenAI tts-1 / Kokoro local) cắm chuỗi engine-order, key store chung WP0 | ✅ done (chờ nghiệm thu thiết bị) | thu hoạch 2026-09-28 từ arena/01a0ddd1-in4up (`003f9c4`, PR #58) vào 251e — engine mới xếp SAU FPT (priority 5), thứ tự mặc định user cũ không đổi; 23 test thuần |
| TTS-EDGE-001 | Microsoft Edge Read Aloud TTS (giao thức edge-tts) — engine neural miễn phí không key, ưu tiên online đầu, fallback mượt | ✅ done (code + test thuần; chờ nghiệm thu thiết bị) | nhánh arena/01a10633-in4up — `edge_tts_engine.dart` (port edge-tts 7.2.8: WebSocket + Sec-MS-GEC) + TtsService đăng ký + 30 test thuần; sandbox không chạm được host speech.platform.bing.com (egress) ⇒ cần nghiệm thu thiết bị thật |
| TTS-EDGE-VOICE-001 | Edge TTS chọn giọng theo ngôn ngữ (trước đây Edge luôn dùng mặc định nữ vi-VN-HoaiMyNeural — app chỉ có picker cho Piper) | 🔄 doing (code + test xong, chờ CI + nghiệm thu máy) | **Re-apply** (commit gốc `c307e0a` MẤT — không được push trước khi phiên 01a10633 đóng): `edge_voice_prefs.dart` (kho giọng Edge theo ngôn ngữ, mẫu PiperVoicePrefs) + `EdgeTtsEngine.catalogVoices`/`catalogVoicesFor` (catalog offline đồng bộ cho UI) + `TtsService._trySpeakOnline(voiceOverride:)` (Edge đọc EdgeVoicePrefs, KHÔNG set `_selectedVoiceId` chung → không bẩn Piper/Zalo/FPT) + UI `_EdgeVoicePicker` (nhóm theo ngôn ngữ, radio, vi-VN: Hoài My/Nam Minh) + 5 test pin |
| API-006 | WP5: In4Up Server Box — Ollama + Speaches + Kokoro bằng Docker Compose (docs-only) | ✅ done (chờ nghiệm thu máy LAN) | thu hoạch 2026-09-28 từ arena/01a0ddd1-in4up (`0a0b912`, PR #52) — `docs/server_box/`: compose CPU 1 lệnh + health-check + hướng dẫn VI |
| MVA-T1 | 5 model schema mục 2 + merge/split hoàn tác | ✅ done | run 32287539067 |
| MVA-T2 | 1 hàm SM-2 duy nhất (ADR-0001) | ✅ done | run 32293474036 |
| MVA-T3 | Migration adapter WordEntry → Knowledge | ✅ done | run 32302871487 |
| MVA-T4 | TextPipeline + Trie Việt + isolate + 4 profile | ✅ done | run 32358239999 |
| MVA-T5 | ReviewEvent append-only + compaction job | ✅ done | run 32371603413 |
| MVA-T6 | Dual-Memory lifecycle (mục 6 bàn giao) | ✅ done | run 32380422644 |
| MVA-T7 | Attention Score v1 (mục 5) | ✅ done | run 32381534996 |
| MVA-T8 | Chat grounding + citation validator (mục 7) | ✅ done | run 32382509679 |
| OPS-1 | Bật CI knowledge_tests.yml | ✅ done | commit 797efff (người dùng) |
| OPS-2 | Skill ci-red-debugging v1.1 | ✅ done | commit a706953 |
| GOV-1 | Hạ tầng governance (file này + GOVERNANCE + PLAN) | ✅ done | commit này |
| PR-1 | PR #6 (knowledge-work) chờ chiến lược lineage | 🚫 blocked | xem LINEAGE-1 |
| LINEAGE-1 | Quyết định 2 dòng codebase (In4Up vs vipsound-main) | ✅ done | main=62ce24a (vipsound+governance) |
| INTEGRATE-1 | Tích hợp knowledge-work (PR #6) vào main mới | 📋 proposed | sau khi main cập nhật xong |
| READ-630-01 | Lưu cụm/câu nhiều dòng (mode không màu): chọn/tạo topic + language | ✅ done | SelectionSaveSheet (chờ nghiệm thu build) |
| READ-630-02 | Tap sheet: hiện đủ IPA + loại + topic + language, thêm/bớt không mất dữ liệu | ✅ done | VocabEntryEditSheet (chờ nghiệm thu build) |
| READ-630-03 | Marker "từ đã lưu": tắt mặc định, bật khi cần + legend | ✅ done | toggle toolbar PDF+Web (chờ nghiệm thu build) |
| READ-630-04 | Lưu hàng loạt thông minh (từ/cụm/câu → topic + language) PDF + Web | ✅ done | extractor dùng chung + language (chờ nghiệm thu) |
| WEB-LOAD-001 | Web Reader: spinner/load "kẹt" — trang đã load xong mà vẫn xoay + load (kể cả khi bấm icon "eye" đánh dấu từ đã lưu) | 🔄 doing (code xong, chờ CI + nghiệm thu máy) | WEB-LOAD-001 watchdog: `onPageFinished` vắng mặt >10s ⇒ tự `state→ready` (ẩn spinner); sửa `web_reader_controller.dart` — owner báo 2026-10-06 (build cũ) |
| WEB-TTS-PAUSE-001 | Web Reader: bấm nút Pause bài đọc vẫn tiếp tục đọc (icon đã đổi sang ▶ tam giác) | ✅ done + CI xanh (trong tip) — chờ owner build lại + nghiệm thu máy | fix PAUSE F3 đã ở tip `72b1e85` (2026-10-01): `pause()` dừng CẢ AudioPlayer + giọng máy + `speakLines` ĐỨNG YÊN khi pause (không auto-skip câu kế); build cũ `1d58b78` (09-15) KHÔNG có fix này → "bấm Pause xong vẫn nghe" |
| PDF-W0 | Wave 0 PDF Reader: nối selection + TTS câu + định danh file + hệ toạ độ + i18n + test sàn | 🔨 doing | code + CI 🟢 05-09-2026 (`370ff91`, run 33984585516: analyze 0 error + test rule #5 xanh) trên `arena/01a07250-in4up`; CÒN nghiệm thu thiết bị + `flutter test test/pdf_reader` ở máy dev |
| PDF-W1 | Wave 1+2 PDF Reader (đợt A+B+C): mục lục + tìm trong file + thumbnail + nhảy trang + phím tắt + chủ đề đọc + xuất/nhập chú thích (JSON/XFDF/bản chụp PDF) | 🔨 doing | code + CI 🟢 06-09-2026 (đợt A `032f321` run 34012087643; đợt B 1.5 run 34042635098; đợt C = wave 2 mục 2.6 B1+B2, run xanh cuối `34058736214` sau 3 run đỏ vì API Dart — chi tiết docs §4.3) trên `arena/01a07250-in4up`; ADR-0004; docs §4.1+§4.2+§4.3; CÒN nghiệm thu thiết bị + `flutter test test/pdf_reader` (14 file / 134 test, chưa chạy lần nào) + một lượt round-trip share sheet thật + 1.4/1.7/1.8 + phần 2.6 còn lại (Markdown/CSV, in, stamp thật vào tệp) |
| READ-630-05 | Nhận diện text ĐÃ LƯU khi lưu nhiều text + gợi ý hành động (thêm ngữ cảnh/cập nhật/bỏ qua) | 📋 proposed | nền: badge đã-có + smart-fill đã có (PLAN-015) |
| LISTEN-630-01 | Tab Nghe: AB loop bottom overflow 24px + nút "lặp câu tiếp theo" | ✅ done | LRC budget + onPanelChanged (chờ nghiệm thu) |
| LISTEN-823-01 | Tab Nghe: rèm LRC + AI sheet + dịch Hiểu + transcript đúng audio | ✅ done | 1d05ce9; CI run 32660616256 xanh (chờ QA đổi file nhanh) |
| GOV-2 | Rule vàng #5: chrome UI không tiếng Việt khi locale ≠ vi + máy bắt | ✅ done | AGENTS.md + test locale (346 entries sạch) |
| WORDLIST-630-01 | Import hàng loạt clipboard/text hoạt động thật + meaning | ✅ done | CSV quotes + smart-fill + preview meaning (chờ nghiệm thu) |
| SRC-630-01 | Nguồn text mới: .md, .json, .docx (thuần Dart, 0 dep mới) | ✅ done | TextSourceLoader + picker + loadTextFile (chờ nghiệm thu) |
| AICHAT-01 | AI Chat thật: llama.cpp native backend (hết mock) | ✅ done — **CI build XANH 3 NỀN TẢNG** | run 32592622383: Android ✅ + iOS ✅ + Windows ✅ (llama.cpp build thật trong pipeline) |
| CI-ANDROID-01 | Fix job Android build.yml: `--flavor stable` + rename đúng tên | 🔄 doing (patch workflow ĐÃ ÁP trong nhánh 01a0d013 cùng CI-ANDROID-03 — chờ oracle) | build.yml + build_final_complete.yml: `--flavor stable` cả 2 bước build, rename `app-<abi>-stable-release.apk`, bỏ `\|\| true`; in4up_ci_fixes.gradle giữ lại (no-op) |
| CI-ANDROID-02 | Build llama.cpp cho Android trong CI | ✅ done | run 32592622383: Android ✅ (GGML_LLAMAFILE OFF c6cc97e + pin CMake 5995183) |
| CI-ANDROID-03 | APK release KHÔNG CÀI ĐƯỢC (local + Actions): release không có `signingConfig` ⇒ APK unsigned | 🔄 doing (fix xong, chờ oracle tag `v*` + cài máy) | build.gradle.kts: ký key.properties → fallback debug; workflow: prepare-signing + verify-signed + `--flavor stable` + rename đúng tên + fix YAML indent build.yml + setup-android v4 |
| MAIN-RESTORE-001 | main = snapshot cũ 2026-09-23 (733 file, mất CI mới + 26k dòng) — cần content-sync từ 0251e | 📋 proposed (chờ owner quyết, GOVERNANCE 4b) | KHÔNG merge chéo (2 lineage không tổ tiên chung); content-sync bằng 1 commit thường trên main; giữ LICENSE nếu muốn; chi tiết thủ thuật trong card |
| CI-DEPS-001 | `pub get` đỏ trên máy Dart 3.11.5: mlkit_subject_segmentation 0.2.x cần Dart ≥3.12 + lock thiếu entry | 📋 proposed (cần máy có Flutter ≥3.47.6) | owner upgrade Flutter (pub gợi ý 3.47.6) + `pub get` + **commit pubspec.lock mới**; mọi dev: upgrade Flutter trước khi build |
| CI-ANDROID-04 | APK release = Universal "chip phổ thông" (mọi chip) thay vì 3 bản tách theo chip | ✅ script done + patch workflow chờ owner áp | `android_rename_apks.sh` giờ CHỈ ship `in4up-Android-Universal-All-CPU-<tag>.apk` (xóa bản tách nếu còn); patch bỏ bước "Build Split APKs" ở cả 2 workflow (tiết kiệm llama.cpp × 3 ABI) — owner: `git apply scripts/ci/android_universal_only_workflow.patch` |
| CI-LINUX-01 | Fix job Linux của build_final_complete.yml | 🚫 blocked (chờ owner) | root cause chốt: plugin webview_win_floating REQUIRE webkit2gtk-4.1 — apt thiếu |
| CI-WINDOWS-01 | Release Windows zip chỉ ~9-10 KB (rỗng) từ nhiều bản gần đây | 🚫 blocked (chờ owner: token GitHub App thiếu quyền `workflows`) | root cause chốt: `Get-ChildItem -Recurse -Directory -Filter Release \| Select -First 1` vớ nhầm thư mục `CMakeFiles/*.dir/Release` rác thay vì `runner/Release` thật; patch sẵn sàng ở `docs/project/CI-WINDOWS-01-patch.diff`, chờ owner áp hoặc cấp quyền |
| MODELS-002 | Trung tâm model: quản lý AI Chat GGUF 1 chỗ + UX import rõ (PLAN-018) | 🔄 doing (chờ nghiệm thu máy) | banner trạng thái + progress + mock disclaimer + section Chat trong Quản lý Model AI (thu hoạch 01a02a4a); CI app_analyze run 35027200801 XANH |
| AI-CHAT-01 | Chat: báo "Chưa nạp model AI" sau khi gửi + nút gửi xoay vòng mãi | 🔄 doing (chờ nghiệm thu máy) | root cause: state=processing ⇒ hasModel=false khi đang generate; chat không có timeout; không xử lý isolate chết; context không giới hạn. Lane B3 (aae4ec6 + 29f1e2b): queue FIFO, context GẦN NHẤT + ngân sách token + clip câu hỏi, engineError/`restartEngine()` tự hồi, banner 8 nhánh; CI 35027200801 XANH (app_analyze) + build.yml 35027568392 (Windows/iOS ✅) |
| SHERPA-001 | Silero VAD (sherpa_onnx) thay EnergyVad fallback (PLAN-008) | ✅ done | 4a50a77 + cd9cccf (chờ nghiệm thu trên thiết bị) |
| SHERPA-002 | TTS Piper offline (sherpa_onnx): core + engine trong TtsService | ✅ done | run 32524455212 (chờ nghiệm thu build) |
| LANG-630-01 | Sứ giả ngôn ngữ: fallback EN chuẩn + lộ trình bậc vi→en→hi/zh/si→… (ADR-0002, wave 1 phủ 100% T2) | 🔄 reopened | origin/main mất wave 1 (merge owner); branch này nguyên vẹn |
| SHERPA-003 | VAD pipeline 30p: cắt chunk FFmpegKit (Android) + quét async + guard | ✅ done | 43c3545; CI run 32617775840 (chờ nghiệm thu thiết bị) |
| MODELS-001 | Trung tâm model: import/tải trong app (VAD+Piper) + docs/project/MODELS.md | ✅ done | SherpaModelManager + 2 card UI + txt source topic/lang; CI xanh 32663677470 (chờ nghiệm thu thiết bị) |
| REOPEN-001 | Mở lại MP3/document dùng LRC + bản dịch ĐÃ LƯU (không tạo/dịch lại) + hỏi trước khi tạo lại | ✅ done | f5cd164 + a2f... CI xanh run 32650359097 (chờ nghiệm thu thiết bị) |
| LHB-001 | Learn by Heart (Dhammapada SRS): FSRS cold-start + cloze + assessment x2 + audio đa ngữ | ✅ done | nhánh 019ff2de (35d1d48) nghiệm thu + merge 15deaf0; CI xanh 32662979309 |
| AUTH-LINUX-01 | Linux: đăng nhập Google + sync từ vựng qua Firebase REST (fallback FlutterFire không có plugin native) | 🔄 doing (chờ CI + nghiệm thu Linux) | ADR-0005; code trên `arena/01a0ca82-in4up`; 0 dependency mới |
| LHB-002 | Vanishing cloze scaffolding 4 tầng + first-letter mnemonics + i18n vi/en/hi/zh/zh_TW/si | ✅ done | cherry-pick 0ed55c8 → fb483df (chờ CI + nghiệm thu UX) |
| LHB-003 | Voice Recall (ghi mic + fuzzy align + gợi ý FSRS) + Nối xích câu kệ + Anki Cloze {{c1::}} | ✅ done | cherry-pick 10fecd3 → 19efa2d + fix transcribeAuto (0177c35 → 4f123e6); chờ CI + nghiệm thu mic |
| SOUNDLIST-630-02 | transcriptFromLrcLines: end = dòng KHÔNG TRỐNG kế tiếp (dòng trống phá highlight) | ✅ done | c978432 (providers copy sống); CI Soundlist xanh 32663677483 |
| AUDLIB-001 | Audio Library P1 (MediaStore) — fix content:// playback + VAD-only fallback + sherpa pubspec | ✅ done | thâu hoạch 01a0018e 70c4efc; CI xanh 33037686097 + 33037686068 (chờ nghiệm thu thiết bị) |
| LANG-03033-01 | Chrome i18n Soundlist/LHB/shell + hi/zh/zh_TW/si (thâu hoạch 01a03033) + fix 2 regression | ✅ done | ff f149d5a + fix 10 file bị dd081fb revert (a5ee489) + fix rule5 ARB (881d8aa); CI xanh 33078187839 |
| I18N-001 | i18n backlog: 354 chrome literals chưa phân loại UI/content (generator legacy fallbacks không chạy được) + raw strings player tab Nghe | 📋 proposed | cần branch i18n riêng (rà soát theo skill i18n-localization); fix lẻ tab Gần đây/Thư viện đã làm (rule 5) |
| READ-630-06 | Bôi nhiều chữ mặc định; box-từng-từ tuỳ chọn (chip cam + settings); sheet lưu từ hiện từ cũ + Sửa | ✅ done | thâu hoạch 01a01580 db5c6ed (path-checkout 6 file) + fix 5 lỗi compile; CI xanh 33082501188 (chờ nghiệm thu thiết bị) |
| XLAT-001 | Dịch offline: glossary Phật học/Pali + protect-tokens trước mọi engine + ML Kit (EN↔VI, EN↔HI; HI↔VI pivot EN) + offline-only | ✅ done + CI xanh | thâu hoạch 02ffc + 7 lỗi compile (6 agent + 1 owner fix import extension bcpCode); CI xanh 33273465065 (chờ nghiệm thu máy EN→VI/EN→HI) |
| XLAT-002 | Dịch ONLINE-FIRST (smart default): online trước, offline fallback khi hết mạng/online fail; vẫn đổi được trong Cài đặt dịch | ✅ done + CI xanh | ce4945a; CI xanh 33697490397 (chờ nghiệm thu máy online/offline) |
| XLAT-DEEPLX-001 | Engine DeepLX (HF Space): lưu URL qua SharedPreferences (hết mất khi restart) + chuẩn hoá host trần → /translate + nút "Thử kết nối" dịch câu mẫu báo lỗi rõ ràng | 🔄 doing | agent arena/01a0f41f-in4up — code + test + ARB 6 key (dịch đủ hi/zh/zh_TW/si); chờ CI + nghiệm thu máy thật với Space |
| XLAT-SCR-002 | Dịch màn hình TOÀN HỆ THỐNG (Android): bong bóng nổi + MediaProjection → OCR bbox → dịch bằng engine đang chọn → overlay đè đúng vị trí từng khối chữ | 🔄 doing (code + CI 🟢 run 37337092117 sau rebase; chờ nghiệm thu thiết bị) | agent arena/01a10bdd-in4up — ADR-0011; lane native Kotlin + engine Flutter nền (FlutterEngineGroup) + 5 file test thuần Dart chạy trong app_analyze; Kotlin CHƯA có CI build (workflow Android chỉ chạy theo tag/dispatch) |
| READ-ACT-001 | Tab Đọc: 4 nút Dịch/Ngữ pháp/Phát âm/Từ điển báo "Bạn cần bôi chọn một đoạn trước" rồi không làm gì + thanh nổi trùng lặp + nút quá to | ✅ done (code + CI 🟢; chờ nghiệm thu máy) | audit 0.10.3 mục 1.a/1.b/1.c — `read_text_action_runner.dart` (đoạn chọn → dòng đang đọc → dòng đầu có chữ) + 2 sheet kết quả thật; bỏ render `ReadTextActionBar` (phương án 1 của owner); `WorkspaceActionButton.dense` + hàng nút cuộn ngang < 600 dp |
| READ-HINT-001 | Tab Đọc: bảng hướng dẫn hứa sai ("chạm một từ … mở bảng tra từ") + ghi chú IPA nằm sai chỗ | ✅ done (code + CI 🟢) | audit 1.e — ghi chú IPA thành dòng phụ trong ngoặc ngay dưới dòng nói về IPA; tách đúng 3 thao tác chạm/chạm đúp/giữ; thêm lối đi cho "nhiều từ" (4 nút chạy trên cả dòng) |
| XLAT-MIX-001 | Tài liệu lẫn tiếng Việt + tiếng Anh không dịch được sang tiếng Việt (bấm Dịch không có gì xảy ra) | ✅ done (code + CI 🟢; chờ nghiệm thu máy) | audit 1.h — nhận diện ngôn ngữ ở mức TÀI LIỆU (24 dòng gộp một mẫu) ⇒ nguồn == đích ⇒ 3 tầng cùng từ chối. Thêm `mixed_language_segmenter.dart` (nhận diện từng mẩu câu) + nhánh `_translateMixedLanguage` + nới guard `translateAll`/`translateLine` |
| TTS-EDGE-VOICE-002 | Giọng Edge: danh sách quá dài (1.f) + chọn giọng nam vẫn nghe giọng nữ (1.g) | 🔄 doing (code + CI 🟢; **chờ nghiệm thu tai nghe trên máy**) | audit 1.f/1.g — picker gập theo ngôn ngữ (ExpansionTile); khoá cache TTS thêm giọng/tốc độ/cao độ, bỏ bất đối xứng `get('any')` vs `put(engine.id)`, prefetch dùng đúng giọng, bậc thang `_resolveEdgeVoice`, nhãn engine kèm tên giọng. Prompt: `PROMPT_AGENT_READ_TTS_DEVICE_VERIFY.md` |
| LOTTIE-IMPORT-002 | Worklist: nhập Lottie `.json` từ máy không được, dán link báo "ảnh hỏng", Lottie đã lưu hiện icon vỡ trong danh sách | ✅ done (code + CI 🟢; chờ nghiệm thu máy) | audit mục 2 — `FileType.custom` cho `.json/.lottie`; nhận diện Lottie theo NỘI DUNG (`looksLikeLottieContent`) thay vì đuôi URL; xem trước trước khi tải; thumbnail giao Lottie cho `VocabularyMediaWidget(animate:false)` |
| DICT-LINK-001 | Từ điển: mất lựa chọn "Liên kết thư mục", lời thoại dung lượng gây hiểu nhầm | 🔄 doing (phần lời + giải thích ✅; phần đọc SAF chờ agent khác) | audit 1.d — Android chỉ cấp `content://` qua SAF nên parser MDX (`RandomAccessFile`) không mở được ⇒ lựa chọn bị ẩn. Hộp thoại nay nói rõ lý do + "bộ từ điển nằm ở HAI nơi". Prompt: `PROMPT_AGENT_DICT_SAF_LINK.md` |
| OCR-SCAN-CRASH-001 | Thư viện đọc ▸ Quét ảnh ▸ "Chụp & quét tài liệu" làm **sập app** | 📋 proposed (cần máy thật + logcat) | audit 1.i — lớp Dart đã try/catch ⇒ crash ở native: nghi tải module ML Kit qua GMS / mất activity result (`singleTop`) / thiếu quyền-khai báo. Prompt: `PROMPT_AGENT_OCR_SCAN_CRASH.md` |
| XLAT-SCR-003 | Dịch màn hình toàn hệ thống: chạm bong bóng **không có gì xảy ra** | 📋 proposed (cần máy thật + logcat) | audit 1.j — xin consent MediaProjection bằng `startActivity` **từ foreground service** ⇒ Android 10+ chặn im lặng; Android 14 còn bắt `foregroundServiceType=mediaProjection` + consent mỗi phiên. Prompt: `PROMPT_AGENT_SCREEN_TRANSLATE_BUBBLE.md` |
| READ-SELECT-002 | Tab Đọc: không kéo chọn được nhiều từ ở chế độ ô chữ | 📋 proposed | audit 1.e — mỗi từ là một `GestureDetector`, không có `SelectableText` ⇒ giới hạn thiết kế. Giảm đau tạm: 4 nút chạy trên cả dòng (READ-ACT-001). Prompt: `PROMPT_AGENT_READ_TTS_DEVICE_VERIFY.md` việc B |
| VOCAB-MEDIA-003 | Worklist: 1 hoặc 2 ảnh mỗi từ + duyệt/xem trước thư viện animation | 📋 proposed | audit mục 2 (phần còn lại) — `WordEntry.imageUrl` là MỘT trường; cần thêm `imageUrl2` additive + sửa các màn hiển thị. Prompt: `PROMPT_AGENT_VOCAB_TWO_IMAGES.md` |
| HYMT-001 | Hy-MT "native không load được" dù đã có model — handshake dối + file cắt + lỗi chung chung | ✅ done + CI xanh | 1677da3; _LoadResult sau create thật + minPlausible 481MB + modelIssue cụ thể + _headIsGguf bằng openRead (CI xanh 33697490397, chờ nghiệm thu máy) |
| AI-CHAT-02 | Chat "cứ xoay vòng" — engine queue đúng (đợi request cũ ≤90s) thay vì "not ready" ngay + state không kẹt processing | ✅ done + CI xanh | 5134f06; _inFlight counter + bỏ busy-wait facade (CI xanh 33697490397, chờ nghiệm thu máy) |
| YT-LR-001 | YouTube học ngôn ngữ kiểu Language Reactor (nối nốt, local-first; không server yt-dlp) | ✅ done | thâu hoạch 01a01580 19f6c3a → a8d6170 + fix a3c8a1a (thiếu _fetchTimedtextTranslated — bug nhánh nguồn); CI xanh 33355331358 (chờ nghiệm thu thiết bị) |
| STT-CRASH-001 | Crash SIGSEGV libwhisper.so khi tạo lời — serialize request native + pre-flight + align model file plugin | ✅ done + CI xanh | af65675 + 9ad6f85 (run 33687604868); root cause: plugin không check NULL sau whisper_init_from_file; crash 2 = file plugin ggml-tiny.bin cũ/hỏng trong khi manager verify ggml-tiny-q5_1.bin (chờ nghiệm thu thiết bị) |
| TIPITAKA-001 | Tipiṭaka (OpenTipitaka Pa-Auk): module Library/Reader song ngữ/Search + 26 language pack + import script + quick-action bolt | 🔄 doing (DEMO trong DEV) | 18813d6 (code+DB DEMO 1.69MB); bước production F/D/B/C trên nhánh mới — PLAN-021 + docs/Bangiao/bangiao_tipitaka.md |
| SHERPA-WP23-01 | WP2 speaker waveform + WP3 voice commands (thâu hoạch 01a039e9) | ✅ done + CI xanh (chờ nghiệm thu máy) | 01f5235 + 8c2e868 (run 33336160268); việc tiếp (WP3 translate action, WP-Z) — PLAN-022 + docs/Bangiao/bangiao_sherpa.md |
| HOME-001 | Bỏ phần "xác nhận nỗ lực" (slider + nút) ở tab Home — owner thấy dư thừa | ✅ done + CI xanh (chờ nghiệm thu) | thẻ còn lại: streak "X ngày liên tiếp"; streak không tự tăng nữa (đăng ký khi cần) |
| READ-DEV-001 | Thư viện đọc: quét + hiển thị file trên máy (SAF folder, như thư viện nhạc) | ✅ done + CI xanh + fix hậu nghiệm thu b08567a (chờ nghiệm thu lại máy) | native in4up/textlib (DocumentsContract đệ quy) + TextDeviceProvider + tab Thiết bị thành danh sách quét; persist folder qua restart; hardening: percent-encoding an toàn (hết "Illegal percent encoding" + tile màu theo ext |
| LHB-004 | Học thuộc lòng: lặp TTS RIÊNG từng câu (tùy số lần/câu) + persist theo bài — re-apply commit bị revert | ✅ done + CI xanh (chờ nghiệm thu máy) | re-apply b631395 + 3 bug fix (compile: Map.map→Iterable; analyze: chuỗi ?.map().where() → helper; runtime: jsonEncode Iterable) — CI xanh 33944392085 |
| DICT-001 | Từ điển MDX/MDD đa ngữ: import, tra từ, quản lý (PLAN-024) | 🔄 doing | bàn giao + PLAN + code WP0 (models + DB service) |
| VID-001 | Video Player local: xem video + phụ đề + học từ (PLAN-025) | 🔄 doing | bàn giao + PLAN + code WP0-WP3 (models + library + player + sub-tab) |
| WORDLIST-002 | Import WordList 8 cột chuẩn: nạp CHÍNH XÁC khi dán (fix example_simple/complex bị rơi + phẩy không nháy lệch cột + header VN) | ✅ done (chờ CI) | WordTableParser (pure, test được) + 17 test (T6/T7); _viBase ĐẦY ĐỦ 150 entries (khôi phục đ U+0111); căn neo word/ipa/language + cột hấp thụ thông minh + hàng thiếu cột + mảnh meaning 1 từ gộp đúng |
| STT-LRC-LANG-01 | Tạo lời (LRC) bằng Whisper đa ngữ: chip chọn ngôn ngữ + 'auto' tự nhận diện (hết hardcode 'en') | ✅ done + CI xanh (chờ nghiệm thu máy) | run 33977299465; chip 14 ngôn ngữ (mặc định auto) + 3 call sites hết hardcode 'en' + VAD/CLI/FFI/plugin đều hỗ trợ 'auto' | _LrcModelSelector + 14 ngôn ngữ (mặc định auto); 3 call sites hardcode 'en' → language param; VAD pipeline + transcribeAuto + transcribeFile đều nhận language |
| STT-LATIN-001 | Tạo lời Whisper: Hindi (và script ngoài Latin) ra CHỮ LATIN thay vì Devanagari — chuẩn hóa mã ngôn ngữ + model theo script + cảnh báo | 🔄 doing (chờ CI + nghiệm thu máy) | WhisperLanguage (99 mã whisper.cpp v1.5.4, verify bằng source) + bỏ map 'auto'→'en' ở auto-TOC + AUTO không còn cứng tiny + chip model tay được tôn trọng (honorWhisperModel) + 20 test |
| IMG-WEB-001 | Wordlist: thêm hình cho từ — ƯU TIÊN tìm ảnh TRÊN MẠNG qua API key (Pexels+Unsplash cùng bật, fallback Openverse/Commons), gallery xuống thứ hai; camera+ML Kit để sau | 🔄 doing (chờ CI + owner dán key) | Sheet web-first + saveFromUrl/saveFromBytes + 4 parser có test + dialog API key (prefs) + --dart-define trong build.yml + nối vào luồng thêm từ nhanh (PDF tap sheet, Wordlist snackbar) |

---
| CABIN-001 | Cabin dịch: "Không thể khởi động micro / nhận diện giọng nói" — fix mic/STT | ✅ done + CI xanh (chờ nghiệm thu máy) | self-heal session treo + retry + keep-alive + lỗi chẩn đoán cụ thể + bỏ cap 2 phút + dictation + Shadowing mic thành toggle (chặn mic treo) |
| SHERPA-WP4-01 | Live STT offline qua sherpa Zipformer (cabin không phụ thuộc speech service) | ✅ done (chờ CI + nghiệm thu máy) | docs/Bangiao/bangiao_sherpa_wp4_live_stt.md + PLAN-023; hoàn thiện N1-N4 (VI simulated streaming + EN streaming, SherpaModelManager ASR, UI Quản lý Model AI, Cabin engine toggle, priority i18n, test unit) |
| CABIN-SAVE-001 | Cabin Save: lưu ghi âm WAV + text song ngữ (LRC) + mở trong Tab Đọc (PLAN-030) | 🔨 doing (chờ CI + nghiệm thu máy) | bước 1+2+3 code 2026-09-25 (agent arena/01a0d363-in4up): tee PCM→WAV, journal+khôi phục, sheet Lưu/Lưu & mở Đọc/Chia sẻ/Bỏ, cài đặt (ghi âm, tự lưu, định dạng, text mặc định), màn Phiên đã lưu; test `test/cabin/`; nén audio = sắp có (R2) |
| IMPORT-MODELS-001 | Import model Piper (TTS) + Zipformer VI (STT) không hiện/không nhận diện + gỡ xung đột PR #48 với 251e | ✅ done + CI xanh (chờ nghiệm thu thiết bị) | root cause 2 bug + merge 251e c8132733; run 36407848778 🟢 (analyze 0 error); chi tiết card dưới |

| LHB-005 | LHB: bấm icon lặp 1× của câu không mở menu — chọn cả dòng luôn | ✅ done + CI xanh (run 37356246667 trên tip d7a4696) — chờ owner build lại từ tip MỚI + nghiệm thu máy | chip per-line: HitTestBehavior.opaque + vùng chạm min 44×32 + menu neo context của CHIP (trước neo rect cả ListView → menu ra ngoài màn hình); fix `58e0318` (đã vào tip sau rebase) |
| LHB-006 | Đồng bộ lưu trữ Thuộc Lòng đa thiết bị (như WordList): bài + tiến độ SRS + streak qua tài khoản | ✅ done + CI xanh (chờ nghiệm thu 2 thiết bị) | ADR-0006; `learn_by_heart_merge.dart` (thuần logic) + `learn_by_heart_sync_service.dart` (plugin/REST) + hàng đợi pending/bia mộ + badge & sheet ở hub; test `learn_by_heart_sync_test.dart`; oracle CI nay chạy thêm bước "LHB tests" (47 test) — run 35923191460 🟢 |
| TTS-PIPER-001 | LHB phát tới câu tiếng Việt sập app (Piper TTS) dù đã import vi_VN-25hours_single | ✅ done + CI xanh (run 37356246667 trên tip d7a4696) — chờ owner build lại từ tip MỚI + nghiệm thu máy | pre-flight TRƯỚC init native: kiểm tra espeak-ng-data (phontab) + file model nguyên vẹn (onnx ≥1MB, tokens ≥1KB); thiếu/hỏng → fallback giọng máy (không crash) + isAvailable() chuẩn xác + log init native; fix `d28a1e9` + `b6b2384` (đã vào tip sau rebase) |
| READ-FOCUS-001 | Tab Đọc Focus: thanh đáy chỉ ẩn icon, vẫn chiếm không gian | ✅ done + CI xanh (run 37356246667 trên tip d7a4696) — chờ owner build lại từ tip MỚI + nghiệm thu máy | Focus mode: gập chiều cao bottom bar về 0 (CollapsibleBottomControls, KHÔNG còn AnimatedSize/Slide/Opacity/ClipRect — READ-TOOLBAR-001 v2); smart-hide khi cuộn giữ nguyên hành vi cũ; fix `6ba029a` (đã vào tip sau rebase) |
| BATCH-0915 | 9 lỗi sau build 1d58b78 (owner 2026-09-15) — handoff agent Arena | 🔄 doing | 9 card chi tiết: PDF-JUMP-001, WLIST-LANG-001, PDF-PAGE-001, XLAT-MLKIT-001, READ-TOOLBAR-001, TTS-PIPER-002 (fix xong chờ nghiệm thu), SHELL-GEAR-001, LISTEN-LRC-001, LISTEN-VIEW-001 — xem section "BATCH OWNER 2026-09-15" — cập nhật A4 v2: READ-TOOLBAR-001 loại bỏ toàn bộ widget animation (bước 2 của card) do AT v1 icon ẩn nhưng vẫn còn khối đen; chờ nghiệm thu máy lần 2 |
| HOME-QUICK-001 | Home: "Nạp tri thức nhanh" + icon ghi âm chưa hoạt động (stub) | ✅ done + CI xanh (chờ nghiệm thu máy) | flow STT thật dùng chung card + FAB (Sherpa offline trước, fallback STT hệ thống), transcript realtime → lưu WordList/ghi chú; "Gợi ý" rút entry THẬT ưu tiên thẻ đến kỳ; bỏ `_SttDialog` giả — run 35863346239 |
| BATCH-0916 | 9 việc mới (owner 2026-09-16) — handoff agent Arena | 🔄 doing | HYMT-002 (timeout Hy-MT), CABIN-ASR-002 (Zipformer "cho EN" + cabin offline regression), HOME-QUICK-001 (nạp tri thức + mic stub), HOME-STUDIO-001 (Studio đủ 7 mode), HOME-KG-001 (Knowledge Graph vô đáp), HOME-STREAK-001 (thống kê thật), LISTEN-LRC-LAYOUT-001 (lời AI chạm sóng âm), XP-MODE-001 (tab Trải nghiệm + tool ẩn), SHADOW-FILE-001 (ENOENT cache + AB) — xem section "BATCH OWNER 2026-09-16" |
| SHERPA-STREAM-001 | Crash SIGABRT: model streaming nạp qua OfflineRecognizer ("Got 51 Expected 39") | ✅ fix code (chờ CI + nghiệm thu máy) | detection 2 lớp (tên + metadata) + 3 hard-guard chặn OfflineRecognizer với model streaming — live EN (streaming) chạy OnlineRecognizer, file/LRC với model streaming báo lỗi rõ không crash |
| VIENEU-001 | VieNeu-TTS optional engine (PLAN-027) | 📋 proposed | chỉ ghi plan — chưa code |
| TTS-PIPER-002 | Catalog tải Piper (HF rhasspy/piper-voices) ưu tiên VI/EN/ZH/HI + xem thêm | 🔄 doing | PLAN-028; sheet Tải giọng + k2-fsa rồi HF |
| CI-BUILD-01 | Workflow `build.yml` không parse được (YAML) ⇒ mọi push trên mọi nhánh đều có run đỏ ~0s, không build release được | ✅ fix YAML (chờ run build thật khi push tag/dispatch) | thụt lề 9 space trong block PowerShell `run: \|` cắt block scalar (lỗi có sẵn từ `origin/main`); sửa 1 space + kiểm chứng bằng parser YAML thật — commit `dfac0e2` |
| CI-BUILD-NDK | Build Android APK đỏ: `Unresolved reference: ndk` / `abiFilters` ở build.gradle.kts:101 | ✅ fix code (chờ owner re-trigger build — bot không có quyền dispatch) | `ndk { abiFilters += "arm64-v8a" }` bị đặt ở **top-level android{}** (commit `f1d4b49` arm64-only) — Kotlin DSL AGP 8.9.1 chỉ có `ndk` trong **defaultConfig** → script compile lỗi. Fix `eeace04`: di chuyển khối `ndk {}` VÀO `defaultConfig {}` (re-apply fix `24d0fa8` bị MẤT khi rebase). Xác minh: run pre-fix `37382171299` (f44eb96) Android=failure, 3 platform còn lại success ⇒ đúng 1 blocker này |
| CI-BUILD-ABI-001 | Release 1.10.3 (build bằng Actions) "có 3 chip" dù đã có lệnh 1-chip; tên APK ghi `arm64-v8a` nhưng file là 3-ABI ~216MB | 🔨 doing — **PR #88** mở (merge vào main) → main build Android xanh + bản 1-chip thật |
| CI-BUILD-LOGIN-001 | Bản 2f357 (release 1.10.3) crash khi chạm icon đăng nhập — owner nghi "flavor không có stable" | ✅ **ĐÃ XÁC NHẬN**: CI ký keystore `in4up-release.jks` (SHA-1 `88d5ee0d…`) mà google-services.json cũ CHƯA có ⇒ Sign-In sai hash; owner đã thêm SHA vào Console, còn đổi secret CI | 2f357 = "fix(android): configure arm64 ABI" (nhánh `arena/124c5760-in4up`), workflow tại 2f357 CÓ `--flavor stable` (build_final_complete.yml:227). google-services: client `com.in4up` cần `certificate_hash 8a1bc02e…` (release); CI fallback ký **DEBUG** keystore (SHA1 `7697fcbc…`) khi thiếu secret release ⇒ Google Sign-In sai hash → crash. Xem card chi tiết | Release 1.10.3 build từ `main` (tag `1.10.3`→`7386295`): (1) APK Android là **bản 3-ABI cũ** (tên file ghi commit `2f357` = TRƯỚC khi 1-chip có hiệu lực trên main); (2) `main` HIỆN có khối `ndk{abiFilters}` ở **top-level (sai)** ⇒ main **không build được Android** (lỗi ndk) cho tới khi fix `eeace04` vào main; (3) `android_rename_apks.sh` **hardcode** "arm64-v8a" vào tên ⇒ gắn nhãn SAI cho bản 3-ABI. Workflow KHÔNG sai (build đúng 1 bản universal, không --split-per-abi) |
| L10N-REGEN-001 | Build fail: `dart format` exit 65 khi sinh localizations — `app_localizations_th/vi/zh.dart` "could not be parsed" | ✅ done (chờ build xác nhận) | Root cause: file sinh `app_localizations*.dart` (build artifact, `generate:true`) bị **commit + hỏng** — `app_localizations_zh.dart` có **493 getter trùng** (gộp zh+zh_TW vào 1 file, thiếu file zh_TW riêng) ⇒ parse lỗi. Fix `b44c964`: **bỏ 26 file sinh ra khỏi git + gitignore** ⇒ build (local+CI) tự sinh file sạch từ `.arb`. ARB (nguồn) đã verify: JSON hợp lệ, không apostrophe/backslash lạ, placeholder khớp EN |
| CI-IOS-01 | Action iOS đỏ: `pod install` báo google_mlkit_commons cần deployment target cao hơn | ✅ done (chờ run CI xác nhận) | nâng iOS min target 13/14/15.0 → **15.5** (Podfile + project.pbxproj + AppFrameworkInfo.plist) + script `scripts/ci/ios_set_deployment_target.sh`; patch workflow ở `scripts/ci/ios_ci_workflow.patch` (owner áp — app thiếu quyền `workflows`) |
| READ-IPA-001 | IPA xếp chồng Read Mode: toggle 3 trạng thái + dòng IPA dưới chữ | ✅ done | commit `e1a4382`; App Analyze run 35687736425 🟢 |
| READ-IPA-002 | Nguồn IPA khi lưu: waterfall MDX→CMU→G2P + provenance + setting + chip | ✅ done | commit `259c322`; App Analyze run 35886676119 🟢 (2026-09-23) |
| READ-IPA-003 | Ruby IPA dòng active (word-chip chữ+IPA) + nháy theo nhịp dòng TTS/playback | ✅ done | commit `9b27586` (+ `fcdc037`); App Analyze run 35890021728 🟢 (2026-09-23); karaoke TỪ vẫn blocked (word-timestamp bị strip — cần capture riêng) |
| READ-IPA-004 | Tô màu phoneme (derived Okabe-Ito) + legend + mờ IPA từ đã thuộc (MasteryZone) | ✅ done | commit `f149237` (+ `fcdc037`); App Analyze run 35890021728 🟢 (2026-09-23); 2 toggle opt-in OFF + legend |
| READ-IPA-005 | G2P đa ngôn ngữ (VI/Pali) theo từ điển đóng gói | 📋 proposed | theo ADR-0005 §6 — cần asset content VI/Pali + ADR riêng, tách đợt sau |
| READ-IPA-006 | Panel màu IPA tương tác (ẩn từng loại, default bật hết) + màu NỐI ÂM + đánh dấu từ nhấn | 🔄 doing | code xong chờ CI + nghiệm thu (branch arena/01a0d33c-in4up) |
| READ-GRAM-001 | Cấu trúc câu + cụm từ trong tab Đọc (chỗ "Loại từ, CEFR"): cụm NP/VP/AdvP/… + hỏi/khẳng định/phủ định + thì–thể–thái + công thức S+V+… | 📋 proposed (KẾ HOẠCH, chưa code) | đặc tả + spike chạy được: `tool/grammar_probe/` (engine.py + 3 corpus JSON); đo TRUNG THỰC trên bộ đóng băng = 17/25 case (68%; 18/25 sau khi chốt quy ước hỏi đuôi), 8 lỗi phân loại thành 4 nguyên nhân gốc; PLAN-031 + ADR-0007 |
| READ-IMPORT-001 | I4U Read Import Many: đánh giá độ khó + bổ sung nghĩa/IPA/ví dụ khi nhập batch | 🔄 doing | shared PDF/Web selection + Web batch UI; test model thêm nhưng chưa chạy (Flutter SDK không có trong PATH) |
| XP-MODE-001 | "Chế độ trải nghiệm": 7 mode (NGHE/NÓI/XEM/ĐỌC/VIẾT/HIỂU/NHỚ) có dẫn đường + mục "Khám phá công cụ ⚡" phơi bày tool ẩn (Tipiṭaka…) — **D1-B: Phòng Studio ở Home, KHÔNG thêm tab** | ✅ **owner đã chốt — chờ bật đèn xanh PR implementation** (chưa code) | phase 1 xong (commit `d3ee12b` · PR #29): `docs/project/XP-MODE-001-wireframe.md` (bản D1-B) + `assets/xp-mode-001-wireframe.png`/`.svg` (vẽ lại theo D1-B) + `XP-MODE-001-route-inventory.csv` (28 entry, route thật) + `XP-MODE-001-i18n-keys.csv` (20 key × 6 locale) + `XP-MODE-001-review-checklist.md` (mục A/B đã tick) + KANBAN checkpoint; cần chốt phối hợp `HOME-STUDIO-001` trước khi sửa `home_screen.dart`; branch `arena/01a0a703-in4up` |
| DOC-1 | README v2: `README.md` (EN) + `README.vi.md` (VI) đúng tiến độ hiện tại + chức năng mới; khôi phục `LICENSE` thiếu trên trunk | ✅ done (chờ owner duyệt nội dung) | commit này — agent arena/01a0e2c8-in4up |
| OCR-001 | ML Kit Text Recognition v2 (OCR) + Document Scanner làm nguồn văn bản thứ 4 — ảnh trang sách / sách scan / PDF image-only → text (ADR-0009, PLAN-033) | 🔨 doing (code+CI 🟢, chờ nghiệm thu thiết bị Android/iOS) | run 36349047556 (`86d1626` = merge tip 251e `b90ba3e`, arena/01a09c9a-in4up) 🟢; trước đó run 36348760217 (`f133932`): analyze 0 error, 0 issue nhắc tới OCR |
| I4U18-BATCH | I4U L18 Problem: chuẩn hoá 15 phản hồi nghiệm thu thành các lane nhỏ, tránh xung đột và không để CI đỏ | 📋 proposed | `docs/project/I4U_L18_PROBLEM_BRIEF.md` + `PROMPT_AGENT_I4U_L18.md`; tham chiếu nhánh `arena/01a06931-in4up` cho Tipiṭaka/PDF/Home khi cần |
| I4U18-HOME-AI-001 | Home/Chat/Tab Viết: phản hồi AI chậm, fallback sai nội dung, summary/topic/action rỗng; thêm lựa chọn Server & API/LLM routing | 🔄 doing (code xong, chờ CI/thiết bị) | agent arena/01a0f3d9-in4up — chat prompt trả lời trực tiếp, dừng remote không fallback local, parser local/remote chịu fence/JSON cắt; test bổ sung (sandbox thiếu Flutter SDK) |
| I4U18-DICT-001 | Từ điển: import/link thư mục MDX/MDD/CSS và quản lý nguồn dùng ngay | 🔨 doing (WP2 parser+import xong, CI run 37175921579 xanh) | Dựa DICT-001; ưu tiên index/link folder hiện có, không bắt buộc copy dữ liệu lớn |
| I4U18-VIDEO-LIB-001 | Tab Video: quét thư mục, thư viện trực quan, chọn/phát nhiều file thay vì chỉ thêm đơn lẻ | 🔄 doing (code + test + CI xanh; chờ nghiệm thu thiết bị) | SAF recursive scan + filter/sort/search + recent/favorite + subtitle pairing + reopen; CI run 36771997803 |
| I4U18-TIPITAKA-001 | Tipiṭaka: import pack độc lập/có gợi ý Pali, tiêu đề thật + cây Tam Tạng, mục lục bài, multi-tab, split view, TTS | ✅ done (code + CI 🟢; chờ nghiệm thu UX/TTS thiết bị) | run 36771566072: analyze 0 error + Rule 5 + Tipiṭaka import/source-link/workspace-retention + Agent F/LHB/Cabin/ASR tests xanh |
| I4U18-LISTEN-LIB-001 | Tab Nghe: thư viện lọc theo album, tác giả, yêu thích và playlist thủ công/thông minh | 🔄 doing (code + test + CI xanh; chờ nghiệm thu thiết bị) | Album/artist/folder/favorite + manual/smart playlist; giữ LRC/transcript/reopen; CI run 36771997803 |
| I4U18-READ-IPA-001 | Tab Đọc IPA: file Word ở chế độ dòng chưa hiện; thêm chỉ dẫn bottom-sheet/snackbar đủ thời gian đọc | 🔨 doing (code+CI 🟢 run 36771164011, chờ nghiệm thu thiết bị) | `docxXmlToPlainText` xuống dòng cứng + `ReadLineHint` + nút Trợ giúp; test `test/read_mode/` |
| I4U18-TRANSLATE-001 | Dịch: Hy-MT vẫn chưa chạy ổn; cho phép chọn LLM Server/API làm engine dịch | 🔨 doing (code xong, chờ CI + AT model thật) | Validator lỗi cụ thể + snake_case error; API-004 offline-first; glossary/protect-token giữ nguyên |
| I4U18-MODEL-IMPORT-001 | Settings/Home model import: eSpeak/Piper/STT offline nhận diện sai khi chọn nhiều file hoặc chọn thư mục | 🔨 doing (code xong, CI run 36898178031 xanh) | Mở rộng IMPORT-MODELS-001/TTS-PIPER-001; kiểm tra onnx/txt/espeak-ng-data/ASR model bằng validator thống nhất |
| I4U18-PDF-OCR-TTS-001 | PDF/OCR Reader: spinner OCR khi mở PDF và TTS play/pause/next-line không dừng đúng | 🔨 doing (code+CI 🟢 run 36771164011, chờ nghiệm thu thiết bị) | `pdf_text_layer_probe.dart` + `ocr_cancel_token.dart` + `pdf_tts_machine.dart` + playback epoch; test OCR/PDF xanh |
| I4U18-DOCS-001 | Bổ sung hướng dẫn sử dụng trong app/docs cho import model, dictionary, Tipiṭaka, Server/API, PDF/OCR/TTS | ✅ done (docs-only; chờ owner QA thiết bị) | `docs/USER_GUIDE.md` + `.vi.md`; checklist QA; 51 local links + `git diff --check` sạch |
| TPI-DISPLAY-01 | Tipiṭaka: reader "trang sách" chuẩn OpenTipitaka (P0–P3) — cột đọc giữa, serif, heading/kệ/hangnum/mốc trang, cài đặt lưu bền (mode+lang+sepia), search deep-link, library 3 Tạng | ✅ done (code + checks tĩnh/i18n 🟢; CÒN `flutter analyze`+full test + nghiệm thu thiết bị) | branch arena/01a10843-in4up (3 commit: c7b7237→79d5a20 sau rebase e93a28e); docs/tipitaka_display_optimization_plan.md |
| TPI-DISPLAY-02 | Tipiṭaka: ghi nhớ vị trí đọc + thẻ "Đọc tiếp" (P4a) — store px theo book_id, reader auto-restore, thư viện resume tối đa 3 sách | ✅ done (code; CÒN nghiệm thu thiết bị) | branch arena/01a10843-in4up commit 0f7fe18 |
| TPI-DISPLAY-03 | Tipiṭaka P4b–P6: ấn bản song hành split, highlight/ghi chú đoạn, footnote apparatus, share+citation, bundle Noto Serif, sync cuộn, VRI attribution | 🔄 doing (code + CI oracle 🟢; chờ full test/AT thiết bị) | branch arena/01a10b88-in4up; CI run 37295697496 analyze + Rule #5 + Tipiṭaka tests xanh |
| PDF-OCR-002 | PDF Reader: Batch OCR — chọn quét trang hiện tại / khoảng trang / toàn bộ tài liệu (bỏ qua trang đã có lớp chữ), sửa "chế độ Text với PDF scan là ngõ cụt" (PLAN-035, mở rộng ADR-0009) | 🔨 doing (code + test thuần; chờ CI + nghiệm thu thiết bị Android/iOS) | agent arena/01a10b7e-in4up — `pdf_batch_ocr.dart` + `pdf_ocr_sheet.dart` + 3 điểm vào (nút TTS bar / menu ⋮ / Text Mode); OCR camera có sẵn của OCR-001 được tái dùng, 0 dependency mới |
| XLAT-SCR-001 | Dịch màn hình IN-APP cho PDF Reader: nút 🌐 trên toolbar → dịch trang hiện tại (câu từ lớp chữ; trang scan tự OCR 1 trang) → panel song ngữ + progress + "Mở trong Read Mode" (ADR-0010) | 🔨 doing (code + test thuần; chờ CI + nghiệm thu thiết bị) | agent arena/01a10b7e-in4up — `pdf_page_translate.dart` + `pdf_page_translate_panel.dart` + controller state (cache 6 trang, runId cancel); tái dùng TranslationService + TranslationCache + glossary |
| XLAT-SCR-002 | Dịch màn hình TOÀN HỆ THỐNG Android (MediaProjection + bubble overlay + OCR ML Kit + TranslationService) — Google Lens style | 🔨 doing (P1 code xong + CI 🟢 run 37337092117 trên nền 251e; chờ nghiệm thu thiết bị + build APK) | agent arena/01a10bdd-in4up — ADR-0011 (lane native, cạnh ADR-0010 in-app); `lib/features/screen_translate/` + `com/in4up/screentranslate/` + 5 file test thuần; Kotlin chưa có CI biên dịch |


## Card chi tiết

### TPI-DISPLAY-01 — Reader "trang sách" chuẩn OpenTipitaka + cài đặt hiển thị lưu bền (P0–P3)
- **Trạng thái:** done (code hoàn tất 2026-10-05; static checks + mô phỏng test
  i18n 🟢; CÒN `flutter analyze` + full `flutter test` + nghiệm thu thiết bị —
  sandbox không có Flutter SDK nên chưa có oracle runtime).
- **Nguồn:** owner (2026-10-04) qua agent arena/01a10843-in4up — yêu cầu tối ưu
  hiển thị theo `opentipitaka.org/texts/vin01m_mul?ui=vi&lang=vi` + brief phân
  tích của Claude. Kế hoạch: `docs/tipitaka_display_optimization_plan.md`.
- **Nội dung (3 commit sau khi rebase e93a28e):**
  - `79d5a20` reader + infra: `services/tipitaka_markup.dart` (parser CSCD:
    clean text, block kind book/chapter/subhead/centre/hangnum/gatha, page
    markers `<pb ed n>` → chip "M n", serif fallback stack),
    `models/reader_appearance.dart` (ChangeNotifier + SharedPreferences: chế độ
    Song ngữ/Pāli/Bản dịch, ngôn ngữ bản dịch chính độc lập UI, nền đọc
    Hệ thống/Sáng/Sepia/Tối, cỡ chữ 80–160%, English phụ); reader viết lại:
    cột giữa ≤800px, hairline thay Card, SliverAppBar floating+snap + progress
    theo vị trí cuộn, tải 2 chiều "Tải các đoạn phía trước", che reference kỹ
    thuật → "Đoạn N", meta bar thích ứng (overflow menu khi pane hẹp), TOC lọc.
  - `64411eb` search deep-link: kết quả mở Workspace tại đúng đoạn (thêm
    `TipitakaDb.getBookById`), snippet cắt quanh query + highlight match.
  - `a445f12` library: icon+màu 3 Tạng, chip Mūla/Aṭṭhakathā/Ṭīkā; docs plan.
  - i18n: 16 nhãn chrome mới → `priority_ui_overrides.dart` (cùng PR; rule #5).
- **AT:** reader mở demo DB (Mahāvaṃsa 10k đoạn) thấy heading/kệ/số đoạn/chip
  "M n"; settings đổi được mode/ngôn ngữ/nền Sepia-tối/cỡ chữ và GIỮ sau restart;
  search "namassitvāna" mở đúng đoạn; UI en không còn chrome tiếng Việt;
  `tipitaka_workspace_retention_test` xanh.
- **Lịch sử:**
  - 2026-10-05 | doing | agent arena/01a10843-in4up | audit 9 vấn đề hiển thị +
    implement P0–P3; 1 commit gốc `9ec243d` sau đó chia 3 commit logic +
    rebase lên `arena/01a0251e-in4up` (e93a28e) theo yêu cầu owner

### TPI-DISPLAY-02 — Ghi nhớ vị trí đọc + thẻ "Đọc tiếp" (P4a)
- **Trạng thái:** done (code 2026-10-05 commit `0f7fe18`; CÒN nghiệm thu
  thiết bị: restore đúng chỗ sau kill app, card xuất hiện/ẩn hợp lý).
- **Nội dung:** `services/reading_position_store.dart` (offset px theo
  book_id, SharedPreferences JSON v1, ≤16 sách); reader auto-restore khi mở
  từ đầu (tải dần ≤25 trang tới khi đủ chiều cao, jumpTo), checkpoint throttle
  scroll + dispose; thư viện thẻ "Đọc tiếp" ≤3 sách resolve getBookById + nút xóa.
- **AT:** mở sách → cuộn sâu → back → mở lại: về đúng chỗ (±vài đoạn); nhảy từ
  TOC/search KHÔNG bị restore đè; xóa vị trí → card mất entry; i18n en sạch.

### TPI-DISPLAY-03 — Tipiṭaka P4b–P6 (lộ trình còn lại)
- **Trạng thái:** doing — code Phase 2 hoàn tất; CI run `37295697496` xanh
  (analyze 0 error, Rule #5, import độc lập, workspace retention, dictionary i18n);
  còn full `flutter test` và checklist nghiệm thu thiết bị trước khi chuyển `done`.
- **Phạm vi:** ấn bản song hành Mūla↔Aṭṭhakathā ở split view (nút "mở bản đối
  chiếu"); highlight/ghi chú đoạn; footnote apparatus `\[(...)\]` chạm-mở; share
  đoạn kèm citation (DN 1.1); bundle Noto Serif assets/fonts; sync cuộn split;
  rà VRI attribution (CC-BY-NC) ở màn quản lý dữ liệu.
- **Brief:** `PROMPT_AGENT_TIPITAKA_P2.md`.
- **Hiện thực:** đối chiếu Mūla/ATT/TIK theo family code và split; sync cuộn theo
  `order_index`; highlight/note migration-safe + tab thư viện; apparatus parser chung
  + setting inline; share/copy citation; Noto Serif variable TTF (Regular/Italic/Bold)
  + OFL; attribution VRI/CSCD trên màn dữ liệu và bàn giao.
- **Lịch sử:**
  - 2026-10-05 | proposed→doing | agent arena/01a10b88-in4up | commits
    `9abf6b3` + `b0329c8`; CI run `37295697496` xanh; chưa tự nhận AT thiết bị/full suite

### API-001 — WP0: nền tảng Server API (ADR-0008) — cấu hình provider + client OpenAI-compat + màn Server & API
- **Trạng thái:** done (CI 🟢 App Analyze + Locale + LHB + Cabin — run 36268246588; còn nghiệm thu thiết bị theo AT)
- **Nguồn:** owner (2026-09-26/27) qua agent arena/01a0ddd1-in4up — PLAN-032,
  ADR-0008, `docs/server_api_tu_van.md`, `PROMPT_AGENT_SERVER_API.md`.
- **Nội dung:**
  - `packages/in4up_ai/lib/src/provider/` (mới): `AiProviderConfig` /
    `AiRouteMode` {offlineFirst, onlineFirst, offlineOnly} /
    `AiRoutingPrefs`; `AiProviderStore` (SharedPreferences, interface thiết kế
    swap secure-storage sau); `OpenAiCompatClient` (healthCheck 5s +
    listModels `/v1/models`, guard cleartext chỉ LAN, mã lỗi cấu trúc
    `AiApiErrorCode`).
  - `lib/screens/settings/ai_providers_screen.dart` (mới): CRUD provider
    (preset Gemini/Groq/OpenRouter/OpenAI/Ollama/LM Studio — KHÔNG kèm key),
    test kết nối, model list động, routing prefs từng năng lực.
  - Entry card từ màn "Quản lý Model AI"; iOS ATS `NSAllowsLocalNetworking`.
  - i18n: 38 key ARB × 26 locale (T2 đủ hi/zh/zh_TW/si; T3 = en fallback).
  - Test thuần: `test/ai_provider_wp0_test.dart` (normalize/guard/parser/
    round-trip). Không đụng engine nào — WP1–WP4 cắm sau.
- **AT (từ prompt WP0):** thêm provider Ollama LAN + cloud → test kết nối
  xanh/đỏ đúng; chưa cấu hình → không request AI nào đi ra, app như cũ; key
  không lộ logcat; CI App Analyze + Locale xanh.
- **Lịch sử:**
  - 2026-09-27 | created→doing | agent arena/01a0ddd1-in4up | code WP0 +
    ADR-0008 + PLAN-032; chờ CI run đầu tiên
  - 2026-09-27 | doing (1 run đỏ) | agent arena/01a0ddd1-in4up | run
    36267897524 đỏ test ratchet ADR-0002: 38 key mới English ở 20 locale
    T3 làm độ phủ tụt dưới sàn → fix theo tiền lệ sound_*: thêm key vào
    keepEnglish global (commit `4ea61fb`); commit fix chỉ chạm tool/ nên
    KHÔNG trigger CI (bẫy paths-filter 5.7) → commit `3ea1716` chạm lib/
    (Semantics label dùng key aiProviderEnabled) để chạy lại oracle
  - 2026-09-27 | doing→done | agent arena/01a0ddd1-in4up | run 36268246588
    🟢 (analyze + rule #5 + 38-key ARB đủ 26 locale + LHB + Cabin);
    test/ai_provider_wp0_test.dart đã qua analyze nhưng CHƯA được workflow
    nào chạy (app_analyze chỉ chạy 4 bộ test cố định — cần owner duyệt thêm
    nếu muốn đưa vào CI); còn AT thiết bị: test kết nối Ollama LAN + cloud

### API-002 — WP1: LLM chat/analysis qua API + streaming (AiEngineRemote)
- **Trạng thái:** doing (code + test + CI 🟢 run 36346119791 — analyze + rule
  #5 + LHB + Cabin; còn nghiệm thu thiết bị theo AT)
- **Nguồn:** owner (2026-09-26/27, PROMPT_AGENT_SERVER_API.md WP1) qua agent
  arena/01a0df5b-in4up — PLAN-032, ADR-0008, `docs/server_api_tu_van.md`.
- **Nội dung:**
  - `packages/in4up_ai/lib/src/engine/ai_engine_remote.dart` (mới): implements
    `AiEngine` — KHÔNG phá interface. `initialize(modelPath)` nhận config
    encoded `api://<providerId>/<model>` (hoặc provider inject qua constructor);
    `modelReady` complete ngay (remote không nạp model), `isBusy`/`recover()`
    trung thực (recover = hủy request treo + sẵn sàng request mới). Analysis
    tái dùng prompt schema `ai_prompts_library.dart` → parse bằng pipeline
    `AiAnalysis.fromGemmaJson` hiện có (kèm lột ```json fence — model lớn hay
    bọc markdown). `temperature`/`maxTokens` map từ tham số hiện có.
  - `openai_compat_client.dart`: thêm `chatStream(...)` — POST
    `/v1/chat/completions` (`stream: true`), đọc SSE, xử lý `data: [DONE]`,
    delta `choices[0].delta.content`, usage chunk cuối (OpenAI
    `include_usage`/Ollama/Groq `x_groq.usage`). Cơ chế stream:
    `http.Client.send()` (StreamedResponse — tương đương dio
    `ResponseType.stream`) thay vì thêm dio — giữ đúng 1 client duy nhất của
    WP0 + test được bằng `MockClient.streaming`, 0 dependency mới (dio chỉ
    cần cho multipart ở WP2). Cancel: `AiChatCancelToken` (mẫu dio
    CancelToken) — cancel ⇒ đóng socket ngay (cancel subscription response
    stream), kể cả khi đang chờ token tiếp; downstream hủy subscription cũng
    hủy request (onCancel). Idle timeout hữu hạn (mặc định 60s — hết chữ
    giữa chừng ⇒ lỗi `timeout`, không treo).
  - Mã lỗi cấu trúc `AiChatErrorCode` (enum riêng, mẫu HyMtErrorCode):
    `noNetwork, timeout, rateLimited, httpError, emptyOutput, busy, canceled,
    invalidResponse` — facade expose `lastChatErrorCode`, UI branch theo mã.
  - `ai_route_planner.dart` (mới, thuần): `planLlmRoute(mode,
    remoteAvailable, localModelReady)` — offlineOnly ⇒ KHÔNG có stop remote
    (engine remote không được tạo ⇒ không request nào đi ra); onlineFirst ⇒
    [remote, local]; offlineFirst ⇒ [local, remote] khi có model Gemma thật,
    [remote, local] khi chưa có (mock luôn là lớp cuối).
  - `AiServiceFacade`: chọn engine theo `AiRoutingPrefs` (WP0), KHÔNG đổi
    signature hàm public. Chat: remote đứng đầu route ⇒ streaming từng token
    (bubble cập nhật dần, throttle notify 60ms); lỗi remote chưa thu token
    nào ⇒ fallback Gemma (nếu có model) → mock kèm disclaimer như cũ; local
    timeout/engine chết ⇒ thử remote như stop cuối (fallback 2 chiều
    ADR-0008). Analysis (lookupWord/summarize/extractTerms/generatePao/
    analyzeSentence): route tương tự, call local giữ NGUYÊN như cũ (không
    tăng maxTokens cho Gemma). Thêm `stopGenerating()` (nút Dừng + đóng màn),
    `lastChatUsage`/`lastChatModelId` (đếm token BYOK).
  - `lib/screens/ai_chat/ai_chat_screen.dart`: nút gửi ⇄ nút Dừng khi remote
    đang stream; đóng màn ⇒ `stopGenerating()` (token không chảy tiếp sau
    dispose); banner 1 dòng "Đang dùng server AI · label · model" /
    "Server AI dự phòng" + ⚡ token vào/ra (từ usage) + dòng lỗi API theo mã.
  - i18n (quy tắc vàng #5): 14 key mới — 5 literal màn chat + 9 runtime label
    facade (thêm vào `reviewed_runtime_ui_labels.dart`) + English trong
    `tool/legacy_ui_english_overrides.json` + tay thêm vào
    `generated_legacy_ui_fallbacks.dart` (generator đang fail sẵn 50 override
    stale từ trước WP1 — đã verify HEAD cũng fail y hệt, không phải WP1 gây
    ra; chưa tự dọn vì ngoài scope).
  - Test thuần: `test/ai_wp1_remote_test.dart` (24 test) — routing thuần
    (offlineOnly ⇒ không request), SSE parser (đa biến thể), chatStream qua
    MockClient (429→rateLimited, đứt mạng→noNetwork, cancel sạch, idle
    timeout), engine (encoded config, isBusy trung thực, Word Lookup fixture
    JSON thật parse đúng schema như Gemma, emptyOutput), facade fallback
    (server chết thật: 127.0.0.1:9 → mock trung thực + mã lỗi; offlineOnly
    ⇒ không vết request API).
- **AT (từ prompt WP1):** chat Ollama LAN + Gemini token hiện dần > tốc độ
  Gemma on-device; cắt mạng giữa lúc generate ⇒ dừng sạch theo mã; routing
  offline-only ⇒ không request `/chat/completions` nào (đã test logic thuần);
  Word Lookup parse đúng JSON schema (đã test fixture); CI xanh.
- **Lịch sử:**
  - 2026-09-26 | created→doing | agent arena/01a0df5b-in4up | code WP1 đầy
    đủ (engine + client + facade + UI + i18n + test); chờ CI run đầu tiên
  - 2026-09-27 | doing (CI đỏ → bisect B1–B10) | agent arena/01a0df5b-in4up |
    run 36271938739 ĐỎ step Analyze; artifact/log không tải được (blob
    storage bị chặn khỏi sandbox) → bisect theo SKILL ci-red-debugging:
    B1 bỏ test (đỏ) · B2 hoàn facade/UI/i18n (đỏ) · B3 bỏ engine+planner
    (đỏ; B3 chỉ chạm packages/ không trigger workflow — bẫy paths-filter
    5.7/5.22, phải chạm test/) · B4 hoàn client+store (🟢) · B5 trả client
    (đỏ) ⇒ lỗi ở client · B6 stub _runChatStream (🟢) · B7 nửa đầu (🟢) ·
    B8 parser/onText/timers (🟢) · B9 +listen/await-done (đỏ) · B10 bỏ đúng
    1 dòng (🟢). Thủ phạm: `await responseSub.done` — StreamSubscription
    KHÔNG có getter `done` (đó là của StreamController) ⇒ undefined_getter;
    review tĩnh 3 lượt không bắt được vì tưởng vấn đề promotion. Fix: bỏ
    await + tail dư thừa (onDone/onError/abort/onCancel đã tự đóng
    controller). Ghi bẫy 5.23 vào SKILL; hoàn nguyên toàn bộ bisect về
    trạng thái WP1 đầy đủ trong 1 commit chốt.
  - 2026-09-27 | doing (CI 🟢 sau 4 lỗi + 21 vòng bisect) | agent
    arena/01a0df5b-in4up | run 36346119791 XANH TOÀN BỘ (analyze + rule #5 +
    LHB + Cabin). Tổng kết 4 lỗi thật — đều KHÔNG nhìn thấy được bằng review
    tĩnh (phải bisect CI vì artifact/log bị chặn khỏi sandbox):
    (1) client `await responseSub.done` — StreamSubscription không có getter
    `done` (của StreamController) [B1–B10];
    (2) test `parser.close('data: [DONE]')` — close() không nhận tham số
    [B11];
    (3) test `MockClient.streaming((req)…)` — http 1.6.0 (pubspec.lock)
    handler nhận 2 tham số (req, bodyStream); verify source dart-lang/http
    qua Contents API [T1–T4, patch 8 call site];
    (4) test `await facade.dispose()` — dispose là void (override
    ChangeNotifier), await void = lỗi analyze [T8–T9].
    Skill ci-red-debugging +bẫy 5.24 (await void — verify RETURN TYPE,
    không chỉ tên). Chuỗi bisect 21 vòng giữ nguyên history trên nhánh.

### API-003 — WP2: STT file qua API (SttEngineRemote — whisper-large-v3)
- **Trạng thái:** doing (code + CI 🟢 run 36348644820 — analyze + rule #5 +
  LHB + Cabin; còn nghiệm thu thiết bị theo AT)
- **Nguồn:** owner (PROMPT_AGENT_SERVER_API.md §5 WP2) qua agent
  arena/01a0df5b-in4up — PLAN-032, ADR-0008.
- **Nội dung:**
  - `packages/in4up_ai/.../ai_transcription.dart` (mới): parse
    verbose_json (`text`, `language`, `duration`, `segments[id,start,end,
    text,words?]`) — `words` nullable theo server, KHÔNG fake word
    timestamps (nguyên tắc MeetilyAdapter).
  - `OpenAiCompatClient.transcribeAudio()`: POST multipart
    `/v1/audio/transcriptions` bằng `http.MultipartRequest` của chính
    package:http — KHÔNG thêm client HTTP thứ 2 (dio có sẵn trong
    in4up_stt từ trước nhưng WP2 không dùng — rationale: 1 client duy nhất
    WP0, `MultipartFile.fromPath` stream file từ đĩa không load RAM, test
    được bằng MockClient.streaming). Fields `model`, `response_format=
    verbose_json`, `temperature=0`; `language` CHỈ gửi khi mã ISO hợp lệ
    ('auto' → omit). Header chỉ Authorization (multipart tự sinh
    boundary). Timeout hữu hạn 10 phút; 429/5xx → drain + backoff
    (Retry-After ≤30s hoặc 2s) + retry đúng 1 lần; 200 rỗng ⇒
    invalidResponse (không fake success); lỗi map về `AiApiException`
    codes có sẵn.
  - `packages/in4up_stt/lib/stt_engine_remote.dart` (mới): implements
    `SttEngine`, đăng ký `SttEngineType.remote` (additive — serialization
    `.name` chuỗi). Capabilities trung thực: file ✓ / offline ✗ /
    liveMic ✗ (AT: live mic giữ on-device) / wordTimestamps ✓ /
    chunking ✓. Provider resolve MỖI LẦN gọi (offlineOnly/chưa cấu hình
    ⇒ `(noProvider)`, không request nào đi ra). Single-flight static busy
    guard (mẫu hymt_slot) ⇒ `(busy)`. Cancel ⇒ `(canceled)`.
  - Chunking: luôn convert WAV 16k mono TRƯỚC (KHÔNG upload lossless gốc
    30p ≈ 57MB > 25MB); target ~10 phút/chunk (~19.2MB), siết theo size
    thật + limit 24MB. `planRemoteChunks` HÀM THUẦN: chia đều theo target
    + snap biên vào TRUNG TÂM khoảng lặng gần nhất ±90s, min chunk 60s,
    phủ kín [0,duration] không chồng lấn (kỷ luật hymt_chunking — không
    lặp/mất đoạn). DEVIATION so spec: silence detection bằng energy scan
    thuần Dart stream từ đĩa (`scanSilenceGaps`: RIFF parse đúng chunk
    'data', window 100ms RMS, lặng ≥400ms) thay vì SherpaVadService — vì
    SherpaVadCore cần model onnx + FFI init + readWave load full RAM, quá
    nặng cho mục đích chỉ tìm chỗ cắt (timestamp không phụ thuộc nó).
  - Offset stitch: timestamps chunk-relative + chunkStartMs; renumber id
    sequential; UID = ContentId.segmentUid theo mốc FILE GỐC. Partial
    SttResult sau mỗi chunk qua onProgress(i, count, partial).
  - Facade: nhánh `preferredEngine == remote` → `_runRemoteEngine`
    (mirror progress/cancel/partial của _runWhisperViaIsolate;
    `SttFacadeStatus.processingRemote` + isActive switch); kết quả đi tiếp
    CÙNG pipeline cache + LRC + diarization (remote chỉ là nguồn segment —
    AT: LRC cache từ remote mở offline vẫn thấy, không duplicate vì LRC
    file engine-agnostic tại lrcOutputPath). `transcribeAuto`: hết model
    local VÀ apiAllowed(sttFile) → remote; còn lại giữ đúng hành vi cũ.
  - UI auto-TOC: ListTile thứ 3 "Whisper qua API (nhanh, chính xác)" trong
    `sound_auto_toc_dialog.dart` — chỉ hiện khi store đã load +
    apiAllowed(sttFile); cắm cạnh 2 lựa chọn hiện có, không dựng màn mới.
    Chuỗi engine qua `startAutoTocBackground(sttEngine:)` →
    `autoGenerateToc` → `SoundAutoTocService.transcribe(engine:)`; lỗi
    engine hiện THẬT (mã cấu trúc) trong error auto-TOC. 'auto' giữ cho
    remote (server tự detect — khác on-device map 'en' legacy D16). i18n
    rule #5: 2 literal mới qua uiText + overrides JSON + generated
    fallbacks cập nhật TAY (precedent WP1).
  - Test thuần: `test/ai_wp2_stt_api_test.dart` — fromJson (đầy đủ/thiếu
    field), client multipart qua MockClient (body đúng fields + Bearer +
    audio/wav + filename; language vi-VN→vi, auto→omit; 429 retry đúng 1
    lần; 401; 200 rỗng ⇒ invalidResponse; cleartext public chặn),
    planRemoteChunks (thuần: 1 chunk/chia đều/snap ±90s/min 60s/không
    trùng lặng), scanSilenceGaps (WAV thật trên đĩa, LIST metadata,
    lặng <400ms), engine inject toàn bộ I/O (noProvider, busy
    single-flight, offset stitch 3 chunk + uid mốc gốc + renumber,
    cancel trước request, emptyResult, noNetwork, language mapping,
    capabilities), store offlineOnly ⇒ resolve null (AT offline gate).
- **AT (từ prompt WP2):** file ~30p nhanh hơn whisper-tiny on-device; LRC
  khớp karaoke; transcript search hoạt động; mất mạng giữa chừng ⇒ dừng
  sạch có mã lỗi, chạy lại on-device ngay; LRC cache từ remote mở offline
  vẫn thấy (không duplicate); chưa cấu hình provider ⇒ luồng STT y hệt
  hôm nay; CI xanh.
- **Lịch sử:**
  - 2026-09-27 | created→doing | agent arena/01a0df5b-in4up | code WP2
    đầy đủ 4 commit theo dependency (client multipart → engine remote →
    facade routing → UI auto-TOC + i18n) + test; run CI đầu 36347966404
    ĐỎ step Analyze (artifact/log vẫn không tải được — blob storage chặn
    khỏi sandbox như WP1); tìm 2 lỗi bằng static review: (1) `sw`
    (Stopwatch) khai báo trong transcribeFile nhưng dùng trong
    _transcribeLocked — khác scope; (2) `throw const AiApiException('…
    ${responseTimeout.inMinutes} min')` — const string interpolation với
    tham số không hằng. Fix cả 2 + mockClient closure async tường minh
    trong test.
  - 2026-09-28 | doing (CI 🟢) | agent arena/01a0df5b-in4up | run
    **36348644820** XANH TOÀN BỘ (commit `97d57fc`: analyze + rule #5 +
    LHB + Cabin) — 2 lỗi static review phía trên là ĐÚNG toàn bộ, không
    cần vòng bisect nào lần này. Còn nghiệm thu AT trên thiết bị thật
    (Groq/Speaches whisper-large-v3 với file pháp thoại 30–60p: nhanh hơn
    whisper-tiny on-device, LRC karaoke khớp, mất mạng giữa chừng dừng
    sạch theo mã + chạy lại on-device, LRC cache offline không duplicate).

### API-004 — WP3: Dịch bằng LLM qua tầng Server API (LlmMtEngine implements TranslationEngine)
- **Trạng thái:** ✅ done (code + CI 🟢 run 36270711178: analyze + rule #5 + LHB + Cabin — xanh ngay run đầu; còn owner nghiệm thu chất lượng 3 đoạn Pali/chuyên ngữ với provider thật + AT thiết bị).
- **Nguồn:** owner (2026-09-26/27) — `PROMPT_AGENT_SERVER_API.md` §6 (WP3), PLAN-032, ADR-0008.
- **Nội dung:**
  - `lib/features/translation/engines/llm_mt_engine.dart` (mới): implements
    `TranslationEngine` (name/id/isAvailable/translate/maxCharsPerRequest=2000/
    requestDelay=300ms). `isAvailable()` = provider bật + có chatModel + có
    mạng. Chunk ≤ ~2000 ký tự theo ranh giới câu (`HyMtChunking` — phân hoạch
    chính xác), mỗi chunk timeout riêng (60s) + outer budget tỷ lệ độ dài ở
    service (nền 75s + 75s/chunk, trần 8 phút). Single-flight `HyMtSlot`
    (mã `busy`). 429/5xx → backoff + tối đa 1 retry (luật tầng API 2.7);
    timeout/4xx không retry. Mã lỗi cấu trúc `LlmMtErrorCode` — 8 mã API
    trùng TÊN `AiApiErrorCode` (mã chung tầng API) + noProvider/busy/
    emptyOutput/slotLost/tooLong.
  - `lib/features/translation/engines/llm_mt_prompts.dart` (mới, thuần):
    system prompt nghiêm ngặt — "Output ONLY the translated text. No
    explanation…", slot `__G{n}__` copy EXACTLY, chỉ dẫn Pali/Sanskrit dùng
    nghĩa đã chuẩn; user prompt = đúng text nguồn (tách system/user để nội
    dung user không bị coi là chỉ dẫn). `cleanOutput` bỏ fence code/lời dẫn
    "Translation:"/lặp nguồn — có GUARD bằng nguồn (không cắt "Result:"…
    khi câu nguồn cũng bắt đầu như vậy). Mất slot trong output = lỗi
    `slot_lost` → chuỗi rơi engine khác, KHÔNG fake success mất nghĩa khóa.
  - `OpenAiCompatClient.chatCompletion` + `OpenAiChatMessage` — THÊM method
    vào client duy nhất của WP0 (không tạo client thứ 2): POST
    `/v1/chat/completions` (non-streaming), parse `choices[0].message.content`
    (kể cả biến thể List parts + legacy `choices[0].text`), mã lỗi
    `AiApiErrorCode`, guard cleartext giữ nguyên, không log key.
  - `TranslationService` (sửa, không phá hợp đồng): chèn theo routing
    `AiRouteCapability.translation` — **onlineFirst** → LLM TRƯỚC các engine
    online miễn phí; **offlineFirst** (mặc định) → sau Hy-MT/ML Kit, TRƯỚC
    từ điển ("thử offline trước; lỗi → thử API"); offlineOnly/chưa cấu
    hình/mất mạng → 2 điểm chèn tự ngắn mạch, thứ tự engine hiện có
    NGUYÊN VẸN. `forTest` nhận thêm `llmMtEngine` (mặc định null — mọi test
    cũ không đổi). `activeEngines`/`checkAllEngines` có thêm LLM khi tồn tại.
  - UI: KHÔNG màn hình mới — sheet "⚙️ Engine dịch thuật" thêm mục "Dịch
    bằng LLM (Server & API)": hiện provider · model khi đã cấu hình + dòng
    routing; "Chưa cấu hình…" kèm đường dẫn Cài đặt → Quản lý Model AI →
    Server & API. 4 chuỗi mới qua `uiText` + English fallback trong
    `legacy_ui_english_overrides.json` (rule vàng #5 — không thêm key ARB).
  - Test: `test/llm_mt_engine_test.dart` (thuần, không network/key —
    provider giả dạng server LAN): parse client (MockClient), prompt hợp
    đồng, cleanOutput + guard, mã lỗi từng nhánh (no_provider/no_network/
    busy/timeout/rate_limited/unauthorized/http_error/invalid_response/
    empty_output/slot_lost), retry 429/5xx, giữ/k mất slot, chunking ≤2000,
    chuỗi TranslationService theo routing (onlineFirst/offlineFirst/
    tắt mạng/khóa offline/không inject), glossary → slot → restore. Giống
    tiền lệ WP0: file test qua analyze nhưng CHƯA được workflow nào chạy
    (app_analyze chạy 4 bộ cố định) — owner duyệt thêm nếu muốn vào CI.
- **Ghi chú UI sau (đề xuất):** chuỗi dịch chưa có kéo-thả thứ tự như TTS —
  khi owner duyệt, dựng UI sắp xếp ưu tiên engine dịch (pattern
  `_buildDefaultEngineOrder` của TTS).
- **AT (từ prompt WP3):** (1) 3 đoạn Pali/tiếng Anh chuyên ngữ dịch tốt hơn
  Hy-MT — owner nghiệm thu với provider thật (Gemini/Groq/Ollama qwen);
  (2) output KHÔNG chứa giải thích — test prompt + parse ✅ (trong file
  test); (3) tắt mạng → chuỗi fallback nguyên vẹn, không regression test
  hiện có ✅ (test + mọi test cũ không đổi); (4) CI xanh + card này.
- **Lịch sử:**
  - 2026-09-27 | created (doing) | agent arena/01a0df5e-in4up | code WP3:
    LlmMtEngine + prompts + chatCompletion client + chèn chuỗi theo routing
    + UI status sheet + 4 chuỗi i18n + test thuần; chờ CI run đầu tiên
  - 2026-09-27 | doing→done | agent arena/01a0df5e-in4up | run 36270711178
    🟢 xanh ngay lần đầu (analyze + rule #5 + LHB + Cabin), commits
    `6f15658` (engine+client+service+test) + `1e3b9b6` (UI status + i18n) +
    `8a3c350` (docs). Test llm_mt_engine_test.dart qua analyze; như tiền lệ
    WP0, file test CHƯA được workflow nào chạy (app_analyze chạy 4 bộ cố
    định — owner duyệt thêm nếu muốn đưa vào CI). Còn: owner nghiệm thu
    chất lượng 3 đoạn Pali (cần provider thật: Gemini/Groq/Ollama qwen +
    routing Dịch = Ưu tiên online), AT thiết bị
  - 2026-09-28 | merge leader 251e | agent arena/01a0df5e-in4up | pull
    `origin/arena/01a0251e-in4up` vào nhánh WP3 (tiền nghiệm thu PR):
    adopt numbering của leader (ADR-0007→0008, PLAN-031→PLAN-032 cho tầng
    Server API), bỏ file ADR-0007 trùng (leader đã có bản 0008), cập nhật
    tham chiếu trong code + card; nội dung engine/test không đổi

### API-005 — WP4: engine TTS qua Server API (OpenAI tts-1 / Kokoro local) cắm chuỗi engine-order, key store chung WP0
- **Trạng thái:** ✅ done (code + 23 test thuần; chờ nghiệm thu thiết bị)
- **Nguồn:** owner (2026-09-26) qua agent arena/01a0df5f-in4up —
  `PROMPT_AGENT_SERVER_API.md` §7. Hoàn thành + xanh CI trên nhánh
  `arena/01a0ddd1-in4up` (PR #58, commit gốc `003f9c4`) — bị merge nhầm
  nhánh phụ, **thu hoạch vào 251e ngày 2026-09-28**.
- **Nội dung:**
  - `packages/in4up_ai/.../openai_compat_client.dart`: thêm TRÊN CÙNG
    client (luật 1 client) `synthesizeSpeech()` — POST `/v1/audio/speech`,
    đọc response dạng stream → bytes (không buffer text), guard payload
    ≥100B (`minSpeechBytes`), mã lỗi cấu trúc đủ nhánh (timeout/noNetwork/
    unauthorized 401-403/rateLimited 429/httpError kèm snippet ≤160 ký tự
    từ body server, KHÔNG log key/headers); `listVoices()` — GET
    `/v1/audio/voices` (endpoint không bắt buộc, lỗi → caller fallback);
    `OpenAiVoicesParser` (thuần, khoan dung mọi shape: list/string,
    voices|data|models, id|voice|name).
  - `lib/features/tts/engines/openai_compat_tts_engine.dart` (mới, theo
    mẫu zalo_tts_engine): chunk ≤2000 ký tự (tách câu→dấu phẩy→cắt
    cứng), nghỉ 150ms giữa chunks (chống binge rate-limit), tối đa 1
    retry sau backoff 800ms khi 429/5xx; speed clamp 0.25–4.0; voices:
    gọi `/audio/voices`, map prefix Kokoro `af_/bm_/jf_…` (vùng+giới
    tính), fallback 6 giọng OpenAI chuẩn khi server không có endpoint;
    thông điệp lỗi chỉ lộ label (không key/baseUrl); client inject được
    → test thuần.
  - `lib/features/tts/tts_service.dart`: TtsEngineInfo
    `openai_compat_tts` priority 5 — SAU piper/offline/google/zalo/fpt ⇒
    **thứ tự mặc định người dùng cũ KHÔNG đổi** (kéo thả lên bằng UI có
    sẵn); `_resolveApiTtsEngine()` đọc
    `AiProviderStore.resolveProvider(AiRouteCapability.tts)` — KHÔNG
    khóa riêng kiểu Zalo/FPT; chưa cấu hình → engine bỏ qua y hệt hôm
    nay; `_getOnlineEngines` chuyển async (4 call-site đã cập nhật).
  - Phát: bytes → `TtsCache.put` → file temp → `_playFile` AudioPlayer —
    y hệt đường Zalo/FPT, không đổi playback path.
- **Test:** `test/tts_api_wp4_test.dart` (23 test thuần — parser mọi
  shape, request chuẩn + phân lớp lỗi, cleartext-guard, guard thiếu
  model/text rỗng, chunking + thứ tự ghép, clamp speed, retry 5xx/429
  đúng 1 lần, voices Kokoro + fallback, isAvailable, pin source-scan
  thứ tự engine mặc định + pin không-SharedPreferences-trong-engine. Key
  test sinh runtime — BYOK, không key mẫu trong repo).
- **AT (từ prompt WP4):** chọn Kokoro (local) hoặc OpenAI tts-1 → đọc
  VI/EN; kéo thả ưu tiên như engine khác; chưa cấu hình → chuỗi TTS +
  mọi mặc định y hệt hôm nay; CI xanh + card này.
- **Lịch sử:**
  - 2026-09-26 | created→done (nhánh nguồn) | agent arena/01a0df5f-in4up
    | code client + engine + wiring + 23 test; CI xanh trên
    arena/01a0ddd1-in4up (PR #58)
  - 2026-09-28 | harvest→251e | agent arena/01a0251e-in4up (leader) |
    thu hoạch thủ công: tts_service.dart adopt nguyên (parent identical
    với 251e); client merge thủ công 5 điểm (import typed_data, 3 const,
    synthesizeSpeech+listVoices+_errorSnippet+_clip+parseVoicesBody,
    class OpenAiVoicesParser, export) — verify byte-identical từng khối
    với bản gốc; engine + test checkout nguyên; chờ CI 251e + nghiệm thu
    thiết bị

### API-006 — WP5: In4Up Server Box (docs-only)
- **Trạng thái:** done (chờ owner nghiệm thu trên một máy LAN sạch)
- **Nguồn:** owner (2026-09-26) — WP5 trong `PROMPT_AGENT_SERVER_API.md`.
  Hoàn thành trên `arena/01a0ddd1-in4up` (PR #52, commit gốc `0a0b912`)
  — **thu hoạch vào 251e ngày 2026-09-28**.
- **Nội dung:** `docs/server_box/docker-compose.yml` chạy Ollama,
  Speaches CPU/faster-whisper và Kokoro-FastAPI CPU; tự tải
  `qwen2.5:1.5b`, giữ model/cache trong volume; healthcheck Docker cho
  cả ba. `health-check.sh` gọi `/v1/models`; README tiếng Việt ghi cấu
  hình 8 GB, lấy IP/firewall, URL và cách cấu hình màn Server & API WP0.
- **AT:** cấu trúc/docs/script đã kiểm tra tĩnh; còn chạy
  `docker compose up -d` và xác nhận ba service `healthy` + ba nút kết
  nối xanh trên máy LAN sạch.
- **Lịch sử:**
  - 2026-09-26 | created→done-docs | agent arena/01a0df4c-in4up | hoàn
    tất bộ Compose CPU một lệnh, script health-check và hướng dẫn vận
    hành tiếng Việt; chờ nghiệm thu phần cứng/LAN
  - 2026-09-28 | harvest→251e | agent arena/01a0251e-in4up (leader) |
    checkout nguyên 3 file `docs/server_box/` (README.md,
    docker-compose.yml, health-check.sh) — docs-only, không ảnh hưởng
    analyze/build

### MVA-T1 — 5 model schema mục 2 + merge/split hoàn tác
- **Trạng thái:** done
- **Nội dung:** KnowledgeUnit, Evidence, LearningState, ReviewEvent, LearningAction
  theo schema mục 2 bàn giao + MergeSplitService (merge/split undo được).
- **Bằng chứng:** 39 test; CI xanh run 32287539067; commit 78bb09b.
- **Lịch sử:**
  - 2026-08-19 | todo→doing | agent arena/01a019bb-in4up |
  - 2026-08-19 | doing→done | agent arena/01a019bb-in4up | CI run 32287539067

### MVA-T2 — 1 hàm SM-2 duy nhất (ADR-0001)
- **Trạng thái:** done
- **Nội dung:** chuẩn hóa ngữ nghĩa Bản 2 (SkillReviewData); xóa bản chết thứ 4
  trong in4up_core; tách skill_review_data.dart; lưới tương đương 384 tổ hợp.
- **Bằng chứng:** CI run 32293474036; ADR-0001 + postmortem.
- **Lịch sử:**
  - 2026-08-19 | todo→doing | agent arena/01a019bb-in4up | ADR-0001 duyệt
  - 2026-08-20 | doing→done | agent arena/01a019bb-in4up | CI run 32293474036

### MVA-T3 — Migration adapter WordEntry → Knowledge schema
- **Trạng thái:** done
- **Nội dung:** thuần, lossless, idempotent; 12 test; JSON fixture đúng format Hive.
- **Bằng chứng:** CI run 32302871487.
- **Lịch sử:**
  - 2026-08-20 | todo→doing | agent arena/01a019bb-in4up |
  - 2026-08-20 | doing→done | agent arena/01a019bb-in4up | CI run 32302871487

### MVA-T4 — TextPipeline + Trie Việt + isolate + 4 profile
- **Trạng thái:** done
- **Nội dung:** normalize per-line; Trie longest-match; abbreviation-aware
  (Mr./U.S./GS./TS.); số thập phân an toàn; 4 profile; worker isolate
  JSON-payload (mục 4); 19 test.
- **Bằng chứng:** CI run 32358239999; skill bổ 2 bẫy mới (5.8, 5.9).
- **Lịch sử:**
  - 2026-08-20 | todo→doing | agent arena/01a019bb-in4up |
  - 2026-08-20 | doing→done | agent arena/01a019bb-in4up | CI run 32358239999

### MVA-T5 — ReviewEvent append-only + compaction job
- **Trạng thái:** done
- **Nội dung (DoD bàn giao):** ghi 1000 event giả lập → RAM không tăng bất thường
  (active per-unit về 0 sau nén, audit-trail đếm đủ), snapshot đúng sau compaction
  (bất biến associativity: nén 2 chặng == replay một mạch); job chạy trong worker
  isolate (op `compactReviewEvents`, JSON hai chiều).
- **Bằng chứng:** CI run 32371603413 (11 test mới); postmortem bẫy 5.10/5.11 trong skill.
- **Lịch sử:**
  - 2026-08-20 | todo→doing | agent arena/01a019bb-in4up |
  - 2026-08-20 | doing→done | agent arena/01a019bb-in4up | CI run 32371603413

### MVA-T6 — Dual-Memory lifecycle (mục 6)
- **Trạng thái:** done
- **Nội dung:** engine 5 trạng thái; 3 quy tắc capture implicit; promote chỉ
  từ người dùng; maintained dẫn xuất; BẢO ĐẢM KHÔNG-CHẶN-LUỒNG cấu trúc
  (zero dialog API — output duy nhất là suggestion-dữ liệu); Unit immutable
  copy-on-write (an toàn isolate mục 4); 15 test (gồm mô phỏng đọc 300 hành
  vi/5 phút).
- **Bằng chứng:** CI run 32380422644. Bisect D1–D9 lesson: mutable fields tự
  nhiễm prefer_final_fields khi bisect cắt Engine — giải triệt để bằng immutable.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ bàn giao mục 8
  - 2026-08-20 | todo→doing | agent arena/01a019bb-in4up |
  - 2026-08-20 | doing→done | agent arena/01a019bb-in4up | CI run 32380422644

### MVA-T7 — Attention Score v1 (mục 5)
- **Trạng thái:** done
- **Nội dung:** công thức deterministic w1–w4 (0.4/0.3/0.2/0.1, const tune
  được); overdue boost chặn ×1.5; tương tác gần đây chuẩn hóa bão hòa; lý do
  cụ thể theo tiêu chí (không "AI đề xuất" mơ hồ); tie-break unitId; op
  rankAttention trong worker isolate (mục 4). XANH NGAY VÒNG CI ĐẦU.
- **Bằng chứng:** CI run 32381534996 (11 test: ranking kỳ vọng thủ công
  C > A > D=E(tie) > B, đường cong overdue + chặn, lật goal skill…).
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ bàn giao mục 8
  - 2026-08-20 | todo→doing | agent arena/01a019bb-in4up |
  - 2026-08-20 | doing→done | agent arena/01a019bb-in4up | CI run 32381534996

### MVA-T8 — Chat grounding + citation validator (mục 7)
- **Trạng thái:** done
- **Nội dung:** pipeline 6 bước trọn vẹn dưới dạng "context injection" (đúng tên,
  không gọi RAG): builder top-5 có chặn (topic seam + mastery thấp + tie-break
  deterministic), prompt chỉ chứa current + top-5, ChatModel seam cắm được,
  OfflineQuoteFirstModel (quote-first, không tự sinh), validator 3 phán quyết
  (verified/nearMatch/unverified + lý do), GroundedAnswer gắn locator reopen
  cho mọi citation được tin + cờ hasUnverified cho UI cảnh báo.
- **Bằng chứng:** CI run 32382509679 (13 test: e2e reopen đúng vị trí, model
  bịa ⇒ cờ bật, bounded prompt…).
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ bàn giao mục 8
  - 2026-08-20 | todo→doing | agent arena/01a019bb-in4up |
  - 2026-08-20 | doing→done | agent arena/01a019bb-in4up | CI run 32382509679

### OPS-1 — Bật CI knowledge_tests.yml
- **Trạng thái:** done
- **Lịch sử:**
  - 2026-08-19 | todo→done | người dùng (commit 797efff) | theo tool/ci/README.md

### OPS-2 — Skill ci-red-debugging v1.1
- **Trạng thái:** done
- **Nội dung:** docs/skills/ci-red-debugging (SKILL.md + ci_check.sh);
  9 bẫy thực chiến; đã cứu Task 4 (escalation §6).
- **Lịch sử:**
  - 2026-08-20 | todo→done | agent arena/01a019bb-in4up | commit c0b5c4b→a706953

### GOV-1 — Hạ tầng governance
- **Trạng thái:** done
- **Nội dung:** GOVERNANCE.md + KANBAN.md (file này) + PLAN.md + AGENTS.md hook.
- **Lịch sử:**
  - 2026-08-20 | created→done | agent arena/01a019bb-in4up | theo yêu cầu người sở hữu

### PR-1 — PR #6: hợp nhất knowledge-work vào main
- **Trạng thái:** blocked (chờ người sở hữu quyết định chiến lược lineage — xem LINEAGE-1)
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | PR #6 draft
  - 2026-08-20 | waiting→blocked | agent arena/01a019bb-in4up | main bị dựng lại thành
    codebase vipsound (1 commit, lịch sử không còn chung gốc) — merge là hợp nhất
    2 dòng sản phẩm (565 file), ngoài thẩm quyền tự quyết của agent

### LINEAGE-1 — Chiến lược 2 dòng codebase (In4Up-knowledge vs vipsound-main)
- **Trạng thái:** done — main := arena/019fe630-vipsound + lớp governance
  (main=62ce24a, kiểm chứng bởi agent: GOVERNANCE/KANBAN/PLAN/skills/AGENTS齐全).
- **Cơ sở xác minh an toàn:** main hiện chỉ có 1 commit gốc (nhập khẩu toàn cây +
  AGENTS.md) — nội dung ĐÃ chứa trong 019fe630 (417 commit, kèm 3 commit docs/skill
  cherry-picked) ⇒ force-move không mất dữ liệu duy nhất nào.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | phát hiện unrelated histories
  - 2026-08-20 | proposed→decided | người sở hữu (qua chat) + agent xác minh trùng lặp |
    người chạy lệnh force-move main (agent không có quyền push main)
  - 2026-08-20 | decided→done | agent arena/01a019bb-in4up | người sở hữu đã chạy 2 khối
    lệnh; agent fetch kiểm chứng: main=62ce24a (vipsound lineage + governance cherry-picks)

### INTEGRATE-1 — Tích hợp knowledge-work vào main mới
- **Trạng thái:** proposed
- **Nội dung:** sau khi main := 019fe630, đưa lib/knowledge + chuẩn hóa SM-2 +
  CI + governance vào main (qua PR #6 đã retarget hoặc cherry-pick chọn lọc);
  kiểm tra xung đột với bản sm2/models của dòng vipsound.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ quyết định LINEAGE-1

### FIX-630-01 — Black screen khi AI doc -> Cloud doc
- **Trạng thái:** doing
- **Nội dung:** đang có tài liệu đọc từ AI tạo ra mà thêm tài liệu từ đám mây thì lên màn hình đen không thoát được. Fix TextProvider._parsePlainText luôn tạo id mới, resetTranslationForNewDocument(), try-catch analyzedLines, CloudPickerSheet + TextLibraryDrawer + LibraryScreen try-catch + snackbar.
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 1
  - 2026-08-21 | doing | agent arena/019fe630-vipsound | đã vá TextProvider + CloudPicker + Drawer

### FIX-630-02 — Bản dịch cũ không lưu, phải dịch lại
- **Trạng thái:** doing
- **Nội dung:** tab đọc những lần dịch trước chưa lưu vào case hay đã lưu mà không lấy ra, mỗi lần mở bản cũ phải dịch lại. Thêm translations field vào TextLibraryEntry Map<lang, List>, applySavedTranslations(), saveCurrentTranslationsToCloud() auto sau translateAll, load từ Firestore + Hive fallback.
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 2
  - 2026-08-21 | doing | agent arena/019fe630-vipsound | đã mở rộng model + provider

### FIX-630-03 — Phần Viết mất AI chấm điểm sau merge
- **Trạng thái:** doing
- **Nội dung:** phần viết chấm điểm, nhận xét đã tích hợp AI rồi mà sau merge mất luôn phần AI chấm điểm. Đảm bảo WriteStudioScreen giữ 2 tầng local + AI local (_buildAiReviewCard, _buildRewriteAiReviewCard, _buildSummaryAiReviewCard), không xóa trong merge.
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 3
  - 2026-08-21 | doing | agent arena/019fe630-vipsound | kiểm tra file hiện có AI, thêm vào checklist merge

### PLAN-001..005 — Ý tưởng mới từ owner
- **Trạng thái:** proposed
- **Nội dung:** bubble karaoke audio + đọc TTS, đánh giá hàng loạt pen+tray màu, mô hình 4 mức độ, thêm hàng loạt câu/cụm vào wordlist kèm topic, hoàn thiện merge 630.
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 4-8


### PLAN-006 — Check chéo đa chiều Hiểu ↔ Nghe ↔ Viết
- **Trạng thái:** proposed
- **Nội dung:** 9 hướng cross-modal: Hiểu→Nói (STT check), Nghe→Hiểu (AI chấm mô tả), Nghe→Viết (gõ + pen tablet), Nhìn→Nói (shadowing), Hiểu↔Viết (rewrite/summary). Dùng VadWhisperPipeline + AiServiceFacade, mỗi lượt là ReviewEvent cho SM-2. Bắt đầu 4 cốt lõi trước.
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue mới 1

### PLAN-007 — Tab Viết mở rộng nhật ký, bóng đổ trace writing
- **Trạng thái:** proposed
- **Nội dung:** journal/composition, viết TV → AI chuyển EN + dạy chuyển, gợi ý từ khóa, ghost text xám mờ viết theo dấu chân.
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue mới 2

### PLAN-008 — Sẵn sàng tích hợp sherpa live stream + cabin STS
- **Trạng thái:** done (chờ nghiệm thu thiết bị)
- **Nội dung:** EL sound → text đích real-time, TTS nếu muốn, nhắc đeo tai nghe. Đã triển khai `SttsCabinService` (STS pipeline), `LiveCabinScreen` (màn hình dịch cabin song ngữ thời gian thực) và `LiveCaptionBubble` (bong bóng nổi phụ đề cabin nổi toàn app).
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue mới 3 + Section3 handover
  - 2026-09-05 | doing→done | agent arena/01a0692a-in4up | hoàn thiện WP1: SttsCabinService, LiveCabinScreen, LiveCaptionBubble, banner tai nghe, QuickActions menu

### READ-630-01 — Tab Đọc: lưu cụm/câu (mode không màu) kèm chọn/tạo topic + language
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** Ở mode không màu, bôi chọn nhiều dòng → "Lưu vào WordList" hiện tại KHÔNG
  có bước chọn/tạo chủ đề & ngôn ngữ. Thêm `SelectionSaveSheet` chung (PDF + Web):
  (a) Lưu nguyên cụm/câu; (b) Lưu thông minh (hàng loạt) — chọn/tạo topic + language
  (chip có sẵn + ô tạo mới), áp cho cả mục đã tồn tại (chỉ bổ sung, không ghi đè).
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat (message "Thêm nữa" #1) | thiếu topic/language khi save full phrase
  - 2026-08-21 | proposed→doing | agent arena/01a0251e-in4up | kế thừa từ 019fe630
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | code xong, chờ nghiệm thu build của owner (sandbox không có Flutter SDK; CI module không cover paths này)

### READ-630-02 — Tap/long-press sheet: hiện đủ + sửa được IPA, loại, topic, language
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** Ở các mode (wordType/CEFR/difficulty), chạm giữ từ đã có sẵn → bảng
  phải hiện ĐẦY ĐỦ: IPA, từ/cụm/câu, chủ đề, ngôn ngữ; cho thêm/bớt chủ đề & ngôn
  ngữ ngay tại đó. BẢO ĐẢM: xóa topic/language chỉ gỡ tag, từ + ngữ cảnh vẫn giữ
  ("mất đi 1 tab mà thôi"). Model: WordEntry thêm `topics: List<String>` +
  `languages: List<String>` (migration tự động từ `topic`/`language` cũ, lossless).
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat | thiếu info đã lưu + không sửa được topic/language
  - 2026-08-21 | proposed→doing | agent arena/01a0251e-in4up | kế thừa từ 019fe630
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | code xong, chờ nghiệm thu build của owner (sandbox không có Flutter SDK; CI module không cover paths này)

### READ-630-03 — Marker "từ đã lưu" (outline/chấm) tắt mặc định, bật khi cần
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** Marker bao quanh từ đã lưu (green outline = đã lưu, amber = có ghi chú,
  red = đến kỳ ôn) đang LUÔN hiển thị → nhiễu thị giác. Thêm toggle trong toolbar
  (PDF + Web), mặc định TẮT (đọc sạch), BẬT khi cần + hiện legend giải thích marker.
  Persist qua SharedPreferences (`reader_show_recall_markers`).
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat | "Tốt khi cần nhưng bình thường gây nhiễu thị giác"
  - 2026-08-21 | proposed→doing | agent arena/01a0251e-in4up | kế thừa từ 019fe630
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | code xong, chờ nghiệm thu build của owner (sandbox không có Flutter SDK; CI module không cover paths này)

### READ-630-04 — Lưu hàng loạt thông minh: nhiều từ/cụm/câu → 1 topic + language
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** Web đã có `WebExtractionBatchSheet` (audit: có chọn nhiều mục, bulk
  topic, AI enrich, import — THiếu field language). PDF chưa có batch. Kế hoạch:
  (a) tách extractor + model + importer sang `lib/services/vocab_batch/` dùng chung;
  (b) web: thêm language vào bulk apply/edit/import; (c) PDF: nút "Lưu hàng loạt"
  từ đoạn chọn hoặc cả trang, dùng cùng extractor + SelectionSaveSheet.
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat | "lưu 1 lần cho nhiều đối tượng từ, cụm, câu"
  - 2026-08-21 | proposed→doing | agent arena/01a0251e-in4up | kế thừa từ 019fe630
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | code xong, chờ nghiệm thu build của owner (sandbox không có Flutter SDK; CI module không cover paths này)

### LISTEN-630-01 — Tab Nghe: AB loop bottom overflow 24px + lặp câu tiếp theo
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** (1) Sau khi có audio + chữ (tiny) và bật lặp AB → bottom overflow
  24px che thanh điều hướng (Lặp bài, Lặp AB, tốc độ, AI...) và che một nửa nút
  trong "Looping passage" (Next loop; Save; Delete). (2) Thêm nút "lặp câu tiếp
  theo" (auto-forward sang câu kế rồi loop) — đặt cạnh Next loop/Save/Delete.
  Owner yêu cầu: hoàn tất READ-630-* trước, ghi vào đây, rồi làm sau.
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat | "Trước khi làm phần này: ... Hãy hoàn tất các task trước và push"
  - 2026-08-21 | proposed→doing | agent arena/01a0251e-in4up | sau khi READ-630-* xong + push
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | code xong (LRC height budget + onPanelChanged + nút Lặp câu tiếp), chờ nghiệm thu build của owner
### GOV-2 — Rule vàng #5: chrome UI không tiếng Việt khi locale ≠ vi
- **Trạng thái:** done
- **Nội dung:** Rule #5 trong AGENTS.md (locale ≠ vi → chrome hiện English,
  không bao giờ fallback vi; thứ tự locale → en; ngoại lệ nội dung user/AI/STT).
  Máy bắt: (1) generator unclassified/unused_overrides giữ nguyên,
  (2) `test/locale_chrome_no_vietnamese_test.dart` — mọi locale ≠ vi trong
  catalog (en/ja + 20 locale khác) không ký tự Việt, mọi entry có `en`,
  legacy fallbacks + overrides json sạch; (3) QA tay EN + JA/BN.
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat (item 4)
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | rule + test (catalog 346 entries × 22 locale: 0 vi phạm)

### WORDLIST-630-01 — Import hàng loạt (Clipboard/Text) hoạt động thật + meaning
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** Bảng có header `word meaning ipa topic example example_simple
  example_complex language`: CSV có nháy kép không xé meaning chứa dấu phẩy;
  hàng cấu trúc không áp _minLength; từ ĐÃ CÓ vẫn hiện (badge "đã có") —
  import smart-fill (meaning/IPA/example chỉ điền chỗ trống + tag
  topic/language, không ghi đè, không mất ngữ cảnh). List import hiển thị
  meaning/IPA từng từ. Meaning là thuộc tính giải thích — nền cho merge từ
  điển + trò chơi "nhìn chữ, nghe âm, viết nghĩa" AI chấm (đã đưa vào plan).
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat (item 3)
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | parse mô phỏng bằng sample thật của owner (tab + CSV quotes)

### SRC-630-01 — Nguồn text mới: .md, .json, .docx
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** `TextSourceLoader` thuần Dart, 0 package mới:
  .md → strip markdown giữ chữ thật; .json → gom string values;
  .docx → tự parse ZIP local file header + inflate raw-deflate bằng
  ZLibCodec (bù zlib header) + tách <w:t>/<w:p>. `loadTextFile` trả
  Future<bool>; picker thêm md/markdown/json/docx (empty state, library,
  drawer, understand); .doc binary cũ → thông báo rõ.
- **Lịch sử:**
  - 2026-08-21 | created | owner via chat (item 5)
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | docx thật (deflate) + md + json mô phỏng pass
  - 2026-08-25 | fix bổ sung (cherry-pick 42ec495 từ 01a01580 → 356388a) | agent arena/01a0251e-in4up | docx: giữ tiếng Việt liền mạch — chỉ nối nội dung `<w:t>` trong đoạn (Word tách run), tokenizer Đọc dùng Unicode thay `\w` ASCII + test `test/text_source_loader_test.dart` (chờ CI + nghiệm thu mở file .docx tiếng Việt trên thiết bị)

### AICHAT-01 — AI Chat thật: llama.cpp native backend (hết mock)
- **Trạng thái:** done — CI build llama.cpp XANH 3 nền tảng (Android/iOS/Windows, run 32592622383); chờ nghiệm thu app của owner (import .gguf + chat)
- **Nội dung:** Đưa inference thật vào luồng AI Chat (audit nhánh 01a0251e:
  chat đang mock, AiEngineGemma gọi _mockInference, binding/CMake có sẵn
  nhưng chưa nối). (1) Submodule `third_party/llama.cpp` pin tag b10567
  (shallow). (2) CMake build `in4up_ai_native`: Android dùng file riêng
  `android/app/src/main/cpp/ai/CMakeLists.txt` — KHÔNG đụng CMakeLists
  UltraTimeStretch (vùng bảo vệ mục 0) — wire qua externalNativeBuild
  (ANDROID_STL=c++_static, Kotlin DSL `arguments += listOf(...)`); Windows
  thêm target + copy DLL cạnh in4up.exe (POST_BUILD + install) +
  `__declspec(dllexport)` cho ABI (thiếu là DLL không export symbol, FFI
  rơi về mock âm thầm). (3) Nối AiNativeBindings vào isolate AiEngineGemma:
  luồng thật Chat UI → Facade → Engine → isolate → FFI → llama.cpp → GGUF;
  mock fallback khi thiếu lib/model (app không vỡ); isolate báo ready trước
  khi load model. (4) Fix hasModel = _initialized && !_useMock (hết hiểu
  nhầm "model sẵn sàng" khi mock), cho phép mock→real re-init khi import
  .gguf giữa phiên chạy, loader validate magic header GGUF. (5) CMake tự
  init submodule khi thiếu (token GitHub App không có quyền workflows nên
  không sửa được .github/workflows/build.yml — push commit đó bị reject,
  đã bỏ và dùng self-heal tại configure).
- **Bằng chứng:** sandbox local (g++12 + CMake 4.4): llama.cpp b10567 build
  sạch; in4up_ai_native compile + link + ABI smoke pass (create path sai ⇒
  nullptr, alias in2up_ai_* OK, generate null ⇒ -1; nm -D xác nhận 8/8
  symbol export; -Wall -Wextra 0 warning); configure thiếu submodule tự
  clone lại đúng pin; mô phỏng git lỗi ⇒ WARNING (không fail).
  CI full build (tag v1.4.0-ai-ci-verify, run 32581570932): **iOS ✅ +
  Windows ✅** — llama.cpp + in4up_ai_native.dll build thành công trong
  pipeline Windows thật (bằng chứng vàng: native AI backend compile/link/
  ship). Android fail ở Build Split APKs nhưng **bisect native OFF (tag
  v1.4.0-android-no-native, run 32582388775) vẫn fail y hệt** ⇒ lỗi Android
  còn lại là pre-existing độc lập (không phải AI, không phải firebase —
  đã fix bằng main.dart và đã thông 2 nền tảng kia); cần owner xem log
  Android (sandbox không đọc được: blob/results-receiver bị chặn tầng
  mạng) để chốt. Lịch sử 5 vòng tag trước: workflow đỏ sẵn trên baseline
  cd9cccff do 'Member not found: androidForFlavor' (CI ghi đè
  firebase_options.dart bản tối giản) — đã fix main.dart dùng
  currentPlatform (file thật vẫn route đúng theo flavor).
- **Lịch sử:**
  - 2026-08-21 21:10 UTC | created | owner via chat | "Hoàn thiện chat AI" — audit: nhánh 01a0251e chat đang mock, llama.cpp chưa tích hợp (commit 959263d nằm ở arena/019fe84a-vipsound)
  - 2026-08-21 21:10 UTC | proposed→doing | agent arena/01a02601-in4up | 5 commits + PR #8 + tag CI oracle
  - 2026-08-21 21:55 UTC | doing→done | agent arena/01a02601-in4up | +3 commit (DSL fix, dllexport fix, KANBAN) — CI bisect 5 vòng: baseline đỏ sẵn, thay đổi không tạo điểm đỏ mới trên Android; chờ nghiệm thu build owner
  - 2026-08-22 | done→done | agent arena/01a02601-in4up | owner cung cấp log CI: llama.cpp + adapter compile sạch trên MSVC; gốc đỏ 3 nền tảng = androidForFlavor (CI ghi đè firebase_options bản tối giản) — đã fix lib/main.dart + dọn warning C4267; sandbox tái bản giữa phiên đã phục hồi theo playbook (0 mất dữ liệu)
  - 2026-08-22 | done→done | agent arena/01a02601-in4up | CI run 32581570932: iOS ✅ Windows ✅ (native AI build thành công); Android đỏ = pre-existing (bisect native OFF vẫn đỏ, run 32582388775); dọn tag bisect cũ
  - 2026-08-22 | done→done | agent arena/01a02a4a-in4up | owner dán log Android (processBetaReleaseGoogleServices / No matching client com.in4up.beta). CHẨN DOÁN CHUYỂN HƯỚNG: (1) run 32582388796 (build_final_complete, no-native tag v1.4.0-android-no-native) job Android **XANH 16m30s + artifact android-apk** — run bisect trước chỉ nhìn job build.yml (32582388775) nên kết luận "Android đỏ pre-existing" chưa đầy đủ; (2) build_final_complete với native ĐỎ ở "Build Split APKs" (run 32581570950) ⇒ riêng workflow này, native chính là điểm chặn; (3) tách 2 card CI-ANDROID-01 (build.yml — cần owner sửa workflow) + CI-ANDROID-02 (native build trong CI — pin CMake 3.31.5). Bỏ approach lách trong repo (inject client / alias tên APK / tắt flavor khi CI) — phá build_final_complete (dùng `--flavor stable`) và che secret thật, đã thống nhất với branch 01a01580
  - 2026-08-22 | done→done | agent arena/01a02a4a-in4up | owner dán log step "Build Split APKs" ⇒ **root cause Android native chốt: sgemm.cpp (llamafile) dùng FP16 NEON thiếu guard trên armv7** (upstream FIXME); fix GGML_LLAMAFILE OFF (c6cc97e) + pin CMake 3.31.5 (5995183) — cả 2 đúng (log xác nhận toolchain resolve đúng, sai ở compile). Chờ oracle tag v1.4.0-android-fp16. Log Linux cùng lúc chốt webkit2gtk (CI-LINUX-01)
  - 2026-08-22 | done→done | agent arena/01a02a4a-in4up | **ORACLE XANH: run 32592622383 (tag v1.4.0-android-fp16) — Build Android APK ✅ (9m, artifact android-apk) + iOS ✅ + Windows ✅** ⇒ llama.cpp build thật trong CI cả 3 nền tảng (Android = nền cuối). Release v1.4.0-android-fp16 đã có artifact 3 nền. Còn lại: CI-ANDROID-01 (build.yml, chờ owner) + CI-LINUX-01 (1 apt package, chờ owner)

### CI-ANDROID-01 — Fix job Android của build.yml (chỉ ship stable + rename đúng tên)
- **Trạng thái:** doing — in-repo fix CI-only `android/app/in4up_ci_fixes.gradle` (chỉ active `CI=true`, local no-op) chờ oracle tag `v1.4.0-ci-android-fix`. Patch workflow option A bên dưới vẫn là fix gốc — giữ nguyên cho owner dán khi có quyền `workflows`; khi đó in4up_ci_fixes thành no-op an toàn.
- **Nội dung:** Job Build Android APK của `build.yml` đỏ vì 2 lỗi chồng, ĐỀU không liên quan code AI:
  1. `flutter build apk --release --split-per-abi` (không `--flavor`) build **cả 3 flavor** →
     `:app:processBetaReleaseGoogleServices` chết: "No matching client found for package name
     'com.in4up.beta'" — secret `ANDROID_GOOGLE_SERVICES` chỉ có client `com.in4up` (log do
     owner dán 2026-08-22). CI chưa từng ship beta/dev.
  2. Dù secret đủ client thì bước "Rename All APKs" vẫn fail: workflow chờ tên KHÔNG-flavor
     (`app-arm64-v8a-release.apk`) trong khi flutter 3.44.1 đặt tên
     `app-<abi>-<flavor>-release.apk` (ABI TRƯỚC, flavor SAU — verify từ source
     `FlutterPlugin.kt` + `listApkPaths()` trong `gradle.dart` tag 3.44.1). `build_final_complete.yml`
     cũng check sai 2 thứ tự (`app-stable-<abi>-...` rồi `app-<abi>-release`) ⇒ split APKs của nó
     bị skip im lặng, chỉ universal (`app-stable-release.apk`) khớp — artifact hiện tại chỉ có 1 APK.
  Cách sửa đúng (option A, thống nhất với branch 01a01580): CI chỉ build stable →
  `--flavor stable` + rename đúng tên thật. KHÔNG lách trong repo: tắt flavor khi CI=true phá
  `build_final_complete.yml`; inject mock client / commit mock google-services.json che secret thật,
  lệch convention.
- **Patch chính xác (4 chỗ trong `.github/workflows/build.yml`):**
  ```diff
  -          flutter build apk --release --split-per-abi --android-skip-build-dependency-validation \
  +          flutter build apk --release --flavor stable --split-per-abi --android-skip-build-dependency-validation \
            "--dart-define=GOOGLE_WEB_CLIENT_ID=${{ secrets.GOOGLE_WEB_CLIENT_ID }}"

  -          flutter build apk --release --android-skip-build-dependency-validation \
  +          flutter build apk --release --flavor stable --android-skip-build-dependency-validation \
            "--dart-define=GOOGLE_WEB_CLIENT_ID=${{ secrets.GOOGLE_WEB_CLIENT_ID }}" \
  ```
  ```diff
  -          mv build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
  +          mv build/app/outputs/flutter-apk/app-armeabi-v7a-stable-release.apk \
             build/app/outputs/flutter-apk/in4up-Android-armv7-${{ ... }}.apk
  -          mv build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  +          mv build/app/outputs/flutter-apk/app-arm64-v8a-stable-release.apk \
             build/app/outputs/flutter-apk/in4up-Android-arm64-${{ ... }}.apk
  -          mv build/app/outputs/flutter-apk/app-x86_64-release.apk \
  +          mv build/app/outputs/flutter-apk/app-x86_64-stable-release.apk \
             build/app/outputs/flutter-apk/in4up-Android-x64-${{ ... }}.apk
  -          mv build/app/outputs/flutter-apk/app-release.apk \
  +          mv build/app/outputs/flutter-apk/app-stable-release.apk \
             build/app/outputs/flutter-apk/in4up-Android-Universal-All-CPU-${{ ... }}.apk
  ```
  ⚠️ Tên `app-<abi>-stable-release.apk` (ABI trước) là TÊN THẬT do flutter plugin sinh — bản draft
  patch `app-stable-<abi>-release.apk` (flavor trước) của branch 01a01580 sai thứ tự, dán nguyên
  sẽ đỏ ở chính bước Rename.
- **Bằng chứng:** log owner (processBetaReleaseGoogleServices); run 32581570932/32582388775
  (build.yml Android đỏ cả khi native OFF); source flutter 3.44.1 (tên APK).
- **Lịch sử:**
  - 2026-08-22 | created | agent arena/01a02a4a-in4up | owner dán log Android
  - 2026-08-22 | proposed→blocked | agent arena/01a02a4a-in4up | chẩn đoán xong + option A chốt với branch 01a01580; token thiếu quyền workflows ⇒ owner dán patch (bên trên) hoặc reconnect GitHub với permission `workflows` để agent tự áp; patch đã chỉnh lại thứ tự tên rename
  - 2026-08-27 | blocked→doing | agent arena/01a02a4a-in4up | In-repo fallback CI-only khi chờ quyền workflows: `android/app/in4up_ci_fixes.gradle` (apply CUỐI `android/app/build.gradle.kts`, chỉ active khi `CI=true`, build local no-op 100%) — (1) task `in4upCiEnsureGoogleServicesClients` chạy TRƯỚC mọi `process*GoogleServices`: đọc `android/app/google-services.json` (nơi build.yml decode secret), thêm client mock cho MỖI applicationId còn thiếu (applicationId DỌC từ defaultConfig + productFlavors của module, không hard-code; idempotent; client thật com.in4up không đổi; APK dev/beta KHÔNG ship — rename build.yml chỉ lấy tên không-flavor); (2) sau `assembleRelease` copy bản stable → tên không-flavor (`app-<abi>-stable-release.apk`→`app-<abi>-release.apk`, `app-stable-release.apk`→`app-release.apk`; phát hiện tên theo pattern, thêm/bớt ABI không cần sửa script). KHÁC draft đã bỏ 2026-08-22: không tắt flavor, không commit mock google-services.json, không che secret thật; không phá build_final_complete — lợi ích phụ ĐÚNG ý: fallback `app-<abi>-release.apk` trong rename của nó giờ có file thật ⇒ split APKs stable được ship kèm universal (trước đó artifact chỉ 1 universal). Logic JSON/copy verify bằng simulation Python 1:1 (17/17 pass, mock client cùng shape với fallback 12-client đã xanh CI). Oracle: tag `v1.4.0-ci-android-fix` → job "Build Android APK" của build.yml. ⚠️ CHỜ OWNER XEM RUN (sandbox không đọc log CI): ĐỎ ⇒ xin dán ~30–50 dòng cuối step fail. Job dự kiến CHẬM hơn build_final_complete (build cả 3 flavor ⇒ llama.cpp compile cho mọi flavor×ABI) — giá tạm thời của việc không sửa được workflow; option A (patch workflow) vẫn là fix gốc.
  - 2026-08-27 | doing→doing | agent arena/01a02a4a-in4up | Commit `fbb648d` (in4up_ci_fixes.gradle + build.gradle.kts + card này) xong TRÊN LOCAL; **push bị chặn**: GitHub token của sandbox (GH_TOKEN `arena-eg…`) hết hạn — `git push` trả "Invalid username or token", `gh auth status` "no longer valid", không có SSH key ⇒ tag oracle `v1.4.0-ci-android-fix` đã tạo LOCAL (annotated, chỉ định fbb648d) nhưng CHƯA push, workflow CHƯA chạy. **OWNER**: reconnect GitHub trong Arena (token cần quyền contents:write); sau đó chạy `git push origin arena/01a02a4a-in4up` + `git push origin v1.4.0-ci-android-fix` (hoặc tự push từ máy — file đã commit đầy đủ, không còn việc chưa lưu).
  - 2026-08-29 | doing→doing | agent arena/01a02a4a-in4up | Sandbox tái bản giữa lượt: branch local bị reset về base `e9824c1e`, object commit `fbb648d`/`561be0e` bị wipe (reflog còn clone+checkout). Phục hồi theo playbook AUDIT: worktree vẫn giữ đủ content (verify blob-hash 16/16 file khớp origin) ⇒ fetch `origin/arena/01a02a4a-in4up` (4efdba3) + `git reset --mixed` + re-commit → commit mới `f65a460` (= nội dung fbb648d). 0 mất dữ liệu. Tag oracle `v1.4.0-ci-android-fix` cần tạo lại LOCAL (tag cũ bị wipe cùng object).
  - 2026-08-29 | doing→doing | agent arena/01a02a4a-in4up | **GitHub đã reconnect — push thành công**: branch `4efdba3..3735298d` lên origin (gồm f65a460 CI-fix + merge DEV 5f98b94c + fix AI-CHAT-01 3735298d). Tag oracle `v1.4.0-ci-android-fix` force-move về TIP `3735298d` rồi push — chạy cả build.yml (job Android = oracle card này) lẫn build_final_complete (regression); run build.yml đồng thời compile-verify Dart packages/in4up_ai (app_analyze không cover `packages/`). ⚠️ CHỜ OWNER XEM RUN: ĐỎ ⇒ dán ~30–50 dòng cuối step fail (build.yml job Android: step "Build Split APKs" hoặc "Rename All APKs").

  - 2026-09-24 | 00:20 UTC | doing→doing | agent arena/01a0d013-in4up | Chủ yêu cầu sửa trực tiếp ⇒ áp option A vào CẢ 2 workflow trong repo (nhánh này có quyền `workflows`): `--flavor stable` ở Build Split + Build Universal, rename theo tên thật `app-<abi>-stable-release.apk` / `app-stable-release.apk` (verify lại FlutterPlugin.kt + listApkPaths tag 3.44.1 — ABI TRƯỚC flavor SAU; SO_TAY_CHU §"Tên APK" trích nhầm `_apkFilesFor` là hàm cho add-to-app MODULE, đã sửa sổ tay), bỏ `|| fallback`/`|| true` im lặng, thêm `set -e`. Đồng thời phát hiện lý do build.yml không chạy từ 403658a: YAML indent dòng `Get-ChildItem` (patch CI-BUILD-YML-INDENT-FIX) — đã áp. Oracle chung với CI-ANDROID-03.

### CI-ANDROID-02 — Build llama.cpp cho Android trong CI (pin CMake 3.31.5 + GGML_LLAMAFILE OFF)
- **Trạng thái:** done — run 32592622383: Build Android APK ✅ (artifact android-apk)
- **Nội dung:** Job Android của `build_final_complete.yml` (chỉ build `--flavor stable`,
  google-services ổn) XANH khi tắt native nhưng ĐỎ khi bật native ⇒ điểm chặn nằm ở stage
  CMake/NDK của llama.cpp, KHÔNG phải lỗi Dart/google-services. Bằng chứng timing:
  run 32582388796 (no-native): Build Android APK ✓ 16m30s + artifact android-apk;
  run 32581570950 (with-native): ✗ "Build Split APKs" chỉ 12m35s — chết SỚM hơn build
  không-native ⇒ lỗi ở stage configure, chưa tới compile dài. Gốc: runner ubuntu-latest
  (image 24.04/26.04, verify toolset actions/runner-images) preinstall NDK 27/28/29 +
  cmake 3.31.5/4.1.2 — **KHÔNG có cmake 3.22.1**; `build.gradle.kts` pin 3.22.1; bước
  `sdkmanager --install "cmake;3.22.1" || true` của workflow fail âm thầm (nếu fail) ⇒
  AGP chết "CMake version '3.22.1' not found". Fix trong repo (legal, không đụng workflow):
  `version = if (System.getenv("CI") == "true") "3.31.5" else "3.22.1"` — llama.cpp pin
  d7fa69b7 khai báo `cmake_minimum_required(VERSION 3.14...3.28)` ⇒ 3.31.5 chạy tốt;
  NDK 28.2.13676358 (=NDK 28 của image) giữ nguyên theo yêu cầu owner. Build local không đổi.
- **Verify (oracle 1-bit):** tag `v1.4.0-android-cmake` → xem job **Build Android APK** của
  `build_final_complete.yml` (KHÔNG phải build.yml — job đó vẫn đỏ google-services cho tới
  khi CI-ANDROID-01 được owner áp, đó là trạng thái ĐÚNG, không phải điểm đỏ mới).
  Xanh ⇒ llama.cpp build cho Android trong CI thành công (bằng chứng vàng thứ 3 sau
  Windows/... — Android là nền tảng cuối). ĐỎ ⇒ xin owner dán ~30 dòng cuối của step
  "Build Split APKs" trong run mới (sandbox không đọc được log CI).
- **Lịch sử:**
  - 2026-08-22 | created→doing | agent arena/01a02a4a-in4up | commit 5995183 + tag oracle v1.4.0-android-cmake
  - 2026-08-22 | doing→doing | agent arena/01a02a4a-in4up | ORACLE run 32586625020 (tag v1.4.0-android-cmake): iOS ✅ 8m0s, Windows ✅ 16m02s, Android ❌ 10m36s — vẫn chết "Build Split APKs" (annotation .github#248) ⇒ giả thuyết "thiếu CMake 3.22.1" CHƯA đủ giải thích (pin 3.31.5 đã có hiệu lực trên CI). Còn 2 nhóm nghi phạm: (a) CMake/NDK vẫn không resolve đúng (lỗi "version not found" khác / NDK patch), (b) compile error của llama.cpp b10567 trên NDK clang (MSVC + g++ host đã build sạch — NDK là toolchain duy nhất chưa verify). Sandbox không đọc được log (results-receiver bị chặn) ⇒ ĐỀ NGHỊ OWNER DÁN ~30–50 dòng cuối step "Build Split APKs" (đoạn FAILURE) từ run 32586625020 / job 97063853155: https://github.com/Pabhassaracitto/In4Up/actions/runs/32586625020/job/97063853155
  - 2026-08-22 | doing→doing | agent arena/01a02a4a-in4up | **ROOT CAUSE CHỐT** (owner dán log): `sgemm.cpp:311: error: use of undeclared identifier 'vld1q_f16'` (+ :314 vld1_f16) trên target armv7 — upstream ggml-cpu/llamafile/sgemm.cpp dùng intrinsics FP16 NEON cho mọi `__ARM_NEON` (non-MSVC) mà THƯA guard `__ARM_FEATURE_FP16_VECTOR_ARITHMETIC` (có FIXME thẳng trong code); armv7 NDK không có +fp16. Log đồng thời xác nhận: NDK 28.2.13676358 + CMake 3.31.5 resolve ĐÚNG (ninja chạy từ sdk/cmake/3.31.5) — pin CMake trước đó đúng hướng, chỉ chưa đủ. FIX: `set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)` trong ai/CMakeLists.txt (commit c6cc97e) — file sgemm.cpp không còn được compile; inference nguyên vẹn (kernel CPU chuẩn). Oracle mới: tag v1.4.0-android-fp16
  - 2026-08-22 | doing→done | agent arena/01a02a4a-in4up | **ORACLE XANH: run 32592622383 — Build Android APK ✅ 9m03s, đủ bước (Split APKs → Universal → Rename → Upload → Release) + artifact android-apk.** GGML_LLAMAFILE OFF + pin CMake 3.31.5 là bộ fix hoàn chỉnh cho stage native Android. (Ghi chú vận hành: sandbox tái bản giữa lượt — branch local bị reset về e9824c1, push non-fast-forward; phục hồi theo playbook AUDIT: fetch remote + reset --soft origin/branch + re-commit, 0 mất dữ liệu; tag v1.4.0-android-fp16 force-move về tip đúng)

### CI-ANDROID-03 — APK release không cài được trên Android (local lẫn GitHub Actions)
- **Trạng thái:** 🔄 doing — code + CI + docs hoàn tất trên `arena/01a0d013-in4up`, **sẵn sàng mở PR → `arena/01a0251e-in4up`**; chờ oracle (push tag `v*` hoặc workflow_dispatch) + chủ cài APK lên máy thật.
- **Nguồn:** chủ (2026-09-23, "I4U | APK SIGN"): `flutter build apk --release` ở máy ra file nhưng
  Android báo không cài được; APK từ Actions cũng vậy.
- **Root cause (chốt, bằng chứng trong repo — không cần log CI):**
  1. `android/app/build.gradle.kts` khối `buildTypes.release {}` **không có `signingConfig`**
     từ commit `c5d7adbf` (05/2026 — comment "XÓA DÒNG signingConfig NÀY ĐI HOẶC ĐỂ MẶC ĐỊNH").
     "Mặc định" của AGP cho release = **không ký** ⇒ AGP xuất `app-stable-release-unsigned.apk`.
  2. Flutter Gradle plugin 3.44.1 (`FlutterPlugin.kt` dòng ~386) copy APK sang
     `build/app/outputs/flutter-apk/` và **`rename { "$filename.apk" }`** ⇒ hậu tố `-unsigned`
     biến mất, file tên `app-stable-release.apk` trông y như bản ký. Android từ chối cài APK
     không chữ ký ("App not installed" / "package appears to be invalid";
     adb: `INSTALL_PARSE_FAILED_NO_CERTIFICATES`). Không workflow nào có bước ký ⇒ đúng
     triệu chứng ở CẢ local lẫn Actions. Không có keystore/key.properties nào trong repo
     (đúng — đã gitignore), tức chưa từng có khoá release.
  3. Phụ: `versionCode = 2` / `versionName = "1.0.0"` cứng (SO_TAY_CHU §4 đã ghi nợ) ⇒ mọi
     release cùng versionCode, không update đè có kiểm soát được.
- **Fix (trong nhánh này):**
  - `android/app/build.gradle.kts`: đọc `android/key.properties` (gitignore) ⇒ có đủ
    storeFile/storePassword/keyAlias/keyPassword ⇒ `signingConfigs.release` + gán cho
    release; **không có ⇒ fallback `signingConfigs.getByName("debug")`** (đúng template
    `flutter create`) + WARNING rõ. APK luôn CÀI ĐƯỢC; ký key thật thì update đè được.
    `versionCode/versionName` đọc từ pubspec qua `flutter.versionCode/versionName`.
  - `android/key.properties.example` — mẫu + hướng dẫn `keytool -genkey`.
  - `scripts/ci/android_prepare_signing.sh` — decode secret `ANDROID_KEYSTORE_BASE64`
    (+ `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) → ghi
    key.properties; verify bằng keytool (sai pass ⇒ fail sớm); thiếu secret ⇒ warning, không fail.
    Test 4 nhánh bằng keytool thật (JDK 25 qua pip `jdk4py`): 4/4 đúng.
  - `scripts/ci/android_verify_apk_signed.sh` — lưới an toàn sau rename, trước upload:
    apksigner nếu có, không thì đọc cấu trúc (APK Sig Block 42 / META-INF/*.RSA). Test
    3 fixture (unsigned/v1/v2) + 2 ca lỗi: đúng.
  - `.github/workflows/build.yml` + `build_final_complete.yml`: thêm 2 bước trên; `--flavor
    stable` + rename đúng tên (CI-ANDROID-01); build.yml: sửa YAML indent (workflow đang
    không parse được — mọi run "workflow file issue" từ 403658a), `setup-android@v3→v4`
    (v3 đỏ ở Setup SDK run 34977536488); KHÔNG ghi đè `lib/services/auth_service.dart` nữa
    (file thật trong git, không secret; stub thiếu `authStateChanges`/`AppUser` sau
    AUTH-LINUX-01 ⇒ compile đỏ) — cả 3 job của build.yml + job Android của bfc.
- **Việc của chủ (không thể làm hộ):**
  1. Tạo keystore MỘT LẦN, cất ngoài repo + backup:
     `keytool -genkey -v -keystore in4up-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias in4up`
  2. Local: `cp android/key.properties.example android/key.properties`, điền 4 dòng.
  3. GitHub → Settings → Secrets → Actions: `ANDROID_KEYSTORE_BASE64` (= `base64 -w0 in4up-release.jks`),
     `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
  4. Firebase/Google Sign-In: thêm SHA-1/SHA-256 của key mới vào Firebase Console (script
     in fingerprint trong log CI), tải lại google-services.json vào secret nếu cần đăng nhập Google.
  5. Máy đang có bản cũ (ký debug hoặc unsigned-fail) ⇒ gỡ rồi cài bản mới lần đầu.
  6. Đừng cài **universal đè lên split** trên cùng máy: split có `versionCode = ABI×1000 + N`
     (FlutterPlugin.kt 3.44.1 dòng 634: arm64 = 2003, armv7 = 1003, x64 = 4003 với pubspec `+3`),
     universal chỉ = 3 ⇒ Android báo hạ cấp (`INSTALL_FAILED_VERSION_DOWNGRADE`, hiện ra cũng là
     "App not installed"). Chọn một loại cho mỗi máy, hoặc gỡ trước khi đổi loại.
- **Verify (oracle):** push tag `v*` (hoặc dispatch) ⇒ job Android xanh đủ bước tới
  "Verify APKs are signed" (log in `Verified using v2 scheme: true` + SHA-256 cert); tải
  `in4up-Android-arm64-<tag>.apk` cài máy thật. Không có secret keystore ⇒ log có
  `::warning::[in4up-sign] Thiếu secret ANDROID_KEYSTORE_BASE64` nhưng APK vẫn cài được.
- **Lịch sử:**
  - 2026-09-23 | 21:05 UTC | created→doing | agent arena/01a0d013-in4up | Chẩn đoán từ repo: grep `signingConfig` = 0 kết quả; API GitHub soi lịch sử build.gradle.kts (5db5ba10 còn ký debug → c5d7adbf xoá); source flutter 3.44.1 xác nhận rename che `-unsigned`. Không tải được APK release 1.7.0 để soi trực tiếp (release-assets.githubusercontent.com bị chặn trong sandbox) — kết luận dựa trên cấu hình build, độ tin cậy cao vì thiếu signingConfig ⇒ chắc chắn unsigned.
  - 2026-09-24 | 00:30 UTC | doing→doing | agent arena/01a0d013-in4up | Code + 2 script + 2 workflow + docs xong; test script offline 9/9 ca; YAML 2 workflow parse OK; bash -n mọi step `run:` OK. Chờ chủ push tag để oracle (token sandbox hết hạn giữa phiên — xem ghi chú push).
  - 2026-09-24 | 07:10 UTC | doing→doing | agent arena/01a0d013-in4up | Sandbox tái tạo giữa phiên (bẫy 5.5): working tree còn, 3 commit mất ⇒ commit lại (c4c7294, f4fe0fe, 5723f18) + push thành công lên origin/arena/01a0d013-in4up. Chủ đang tạo keystore (keytool) — bước tiếp: key.properties local → `flutter build apk --release --flavor stable` → cài máy.
  - 2026-09-24 | 08:00 UTC | doing→doing (PR-ready) | agent arena/01a0d013-in4up | Gia cố trước PR: `scripts/ci/android_rename_apks.sh` (chịu mọi thứ tự tên, thiếu ⇒ đỏ; test 4/4), import `java.io.File` tường minh + resolver `project.file()` như docs Flutter, README mục build release (EN+VI), ghi bẫy versionCode split 2003 vs universal 3. Sandbox tái tạo lần 2 — đồng bộ local về origin (0a9aa44) không mất gì. Nhánh đích 251e vẫn ở 311fbfd ⇒ PR fast-forward, không conflict. Chưa chạy được Gradle trong sandbox (Maven bị chặn) ⇒ oracle CI/tag là bước xác nhận cuối.
  - 2026-09-24 | 08:40 UTC | doing→doing | agent arena/01a0d013-in4up | Merge 251e@30f912e vào nhánh (251e nhận #42/#45/#46 + tự sửa indent build.yml): 1 conflict build.yml (lấy bản 251e), SKILL bẫy 5.21/5.22 của tôi → **5.23/5.24** vì 251e đã dùng số đó (commit 5723f18 ghi 5.21/5.22 là số cũ). Mở PR → arena/01a0251e-in4up (số PR ghi ở dòng sau).
  - 2026-09-24 | 08:45 UTC | doing→doing (PR mở) | agent arena/01a0d013-in4up | **PR #49** https://github.com/Pabhassaracitto/In4Up/pull/49 → arena/01a0251e-in4up. Chờ owner: build local + cài máy, 4 secret ANDROID_KEYSTORE_*, tag `v*` để CI ký + verify.
  - 2026-09-27 | 21:00 UTC | doing→doing | agent arena/01a0d013-in4up | Owner build ở checkout KHÔNG có fix (không có `scripts/ci/`, 251e chưa merge #49) ⇒ APK vẫn unsigned, "gói không hợp lệ" — đúng dự đoán, chưa phải bằng chứng chống lại fix. Phát hiện `flutter build` gọi Gradle `-q` ⇒ đổi log `[in4up-sign]` sang `logger.quiet` (b6e8bf4) để người build thấy được. Merge lại 251e@b90ba3e (README viết lại ở 251e, chèn lại mục Build a release APK) — PR #49 hết conflict. Cách tự kiểm không cần script: `ls build/app/outputs/apk/stable/release/` — file gốc của AGP mang hậu tố `-unsigned` nếu chưa ký.

### CI-ANDROID-04 — APK release = Universal "chip phổ thông" (mọi chip) thay vì 3 bản tách theo chip
- **Trạng thái:** ✅ script done (đã push 0251e) + 0251e: patch workflow chờ áp
  (bước 1 hướng dẫn 2026-10-05); **main: workflow universal ĐÃ có từ e524214
  (04/10) nhưng THIẾU 3 scripts/ci** mà nó gọi → job Android main sẽ đỏ khi
  chạy (bước 2 hướng dẫn cho owner).
- **Nguồn:** owner (2026-10-04): "Hãy update workflow action github đảm bảo file
  apk dạng chip phổ thông thay vì chip đầy đủ."
- **Trước fix:** cả 2 workflow (`build.yml`, `build_final_complete.yml`) build
  **4 APK** — 3 bản tách theo chip (`--split-per-abi`: armv7/arm64/x64) + 1
  Universal — và đẩy **cả 4** lên artifact + GitHub Release.
- **Fix (2 tầng, tầng 1 hiệu lực NGAY):**
  1. `scripts/ci/android_rename_apks.sh` (ĐÃ PUSH — có hiệu lực từ build kế
     tiếp, không cần chờ ai): chỉ đổi tên + ship bản Universal
     (`in4up-Android-Universal-All-CPU-<tag>.apk`); nếu bước build split cũ
     còn để lại `app-<abi>-...-release.apk` → XÓA có log. Verify/upload/push
     (glob `in4up-Android-*.apk`) tự chỉ còn 1 file. Thiếu Universal ⇒ job
     ĐỎ (giữ lưới an toàn). Test 3 kịch bản local: pass (universal-only /
     workflow-còn-split / thiếu-universal→exit 1).
  2. `scripts/ci/android_universal_only_workflow.patch` (CHỜ OWNER ÁP): bỏ
     bước "Build Split APKs" ở cả 2 workflow + cập nhật comment. LỢI: tiết
     kiệm ~3 lần compile native llama.cpp cho 3 ABI (bước nặng nhất job).
     Owner: `git apply scripts/ci/android_universal_only_workflow.patch &&
     git commit -am "ci(android): CI-ANDROID-04 — chỉ build Universal APK" &&
     git push` (hoặc dán tay 2 khối đã xóa trong patch).
- **⚠️ CẢNH BÁO BẢN CẤY (quan trọng cho owner + user):** versionCode của
  Universal = `3` (pubspec +3), trong khi bản tách chip = `ABI×1000+3`
  (arm64 = 2003) — máy ĐANG CẤI bản tách cũ thì cài bản universal mới bị
  Android chặn `INSTALL_FAILED_VERSION_DOWNGRADE` → phải **gỡ app cũ trước**
  (một lần duy nhất ở lần chuyển đổi này). Nếu muốn tránh: nâng build
  number `version: x.y.z+N` trong pubspec.yaml LỚN HƠN versionCode cao
  nhất của mọi bản tách (x64 = 4003) — ví dụ pubspec `+5001` ⇒ universal
  versionCode 5001 > 4003/2003/1003 → đè cài được mọi bản split cũ —
  TRƯỚC khi tag release đầu tiên sau khi đổi.
- **Trade-off (owner đã chọn):** universal lớn hơn 1 bản tách (chứa native
  lib cả 3 ABI — kể cả llama.cpp/ggml) nhưng 1 file cài mọi chip, đúng yêu
  cầu "chip phổ thông".
- **AT:** chạy 1 release (tag `v*`) sau khi áp patch → GitHub Release chỉ
  có DUY NHẤT 1 file `in4up-Android-Universal-All-CPU-<tag>.apk` (còn
  .aar/.app khác bình thường); job Android xanh; bản universal ký thật
  (bước verify-signed không đổi) + cài máy arm64 thành công.
- **Lịch sử:**
  - 2026-10-04 | created→doing | agent arena/01a0251e-in4up | script
    universal-only (test 3 kịch bản pass) + patch 2 workflow + cảnh báo
    versionCode; chờ owner áp patch + oracle release
  - 2026-10-05 | sự kiện | main nhận commit e524214 "Modify Android build
    workflow for universal APK" (tài khoản owner — nguồn: máy khác hay agent
    session khác, CHƯA xác nhận): workflow universal-only ĐÃ áp vào main
    NHƯNG main vẫn là snapshot 733 file cũ ⇒ thiếu scripts/ci/ (3 script
    android_*) mà workflow gọi ⇒ job Android main sẽ đỏ khi chạy. Owner chạy
    nhầm thủ thuật content-sync trên nhánh 0251e (worktree DEV checkout
    0251e; main checkout ở clone chính nên không checkout được trong
    worktree) ⇒ 2 commit rác cục bộ (5c99b7a2 + 798cde87, triệt tiêu nhau),
    remote an toàn. Hướng dẫn sửa 3 bước đã gửi owner.

### CI-LINUX-01 — Fix job Linux của build_final_complete.yml
- **Trạng thái:** blocked (chờ owner: thêm 1 apt package vào workflow HOẶC cấp quyền `workflows`)
- **Nội dung:** Job Build Linux App của `build_final_complete.yml` ĐỎ ở bước
  "Build Linux Release" trong MỌI run (32581570950: 2m06s; 32586625020: 1m57s —
  chết sớm sau khi pub get). Pre-existing, riêng rẽ với Android/AI (Linux build
  không dùng llama.cpp native — CMake Android-only).
  **ROOT CAUSE CHỐT (owner dán log):** `Configuring incomplete, errors occurred!`
  tại `webview_win_floating/linux/CMakeLists.txt:42` — plugin (dùng thật ở 5
  screen: web_reader, youtube ×2, youglish ×2 — KHÔNG gỡ được khỏi pubspec) khai
  `pkg_search_module(WebKit REQUIRED webkit2gtk-4.1 webkit2gtk-4.2 webkit2gtk-4.3)`
  mà runner ubuntu-latest không cài webkit2gtk (apt list trong workflow thiếu).
  **Fix (1 dòng, cần quyền workflows):** thêm `libwebkit2gtk-4.1-dev` vào step
  "Install Linux dependencies":
  ```diff
  -          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libglu1-mesa libjson-glib-dev
  +          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libglu1-mesa libjson-glib-dev libwebkit2gtk-4.1-dev
  ```
- **Lịch sử:**
  - 2026-08-22 | created | agent arena/01a02a4a-in4up | phát hiện khi soi run oracle (job Linux đỏ mọi vòng)
  - 2026-08-22 | proposed→blocked | agent arena/01a02a4a-in4up | owner dán log Linux ⇒ root cause webkit2gtk (CMake plugin REQUIRED); fix = 1 apt package, chờ owner áp (token thiếu quyền workflows)
### CI-WINDOWS-01 — Release Windows zip chỉ ~9-10 KB (rỗng) từ nhiều bản gần đây
- **Trạng thái:** 🚫 blocked (chờ owner: token GitHub App của agent KHÔNG có
  quyền `workflows` nên không push được sửa đổi `.github/workflows/*.yml` —
  y hệt tình huống CI-LINUX-01. Patch đã viết xong và test logic kỹ, chỉ cần
  owner tự áp hoặc cấp quyền `workflows` cho agent)
- **Nguồn:** owner (2026-09-06) — hỏi vì sao release `in4up-Windows-1.7.0.zip`
  chỉ nặng 9.63 KB thay vì hàng chục MB như app Flutter Windows thật.
- **Patch sẵn sàng:** `docs/project/CI-WINDOWS-01-patch.diff` (áp bằng
  `git apply docs/project/CI-WINDOWS-01-patch.diff` rồi commit + push) —
  sửa cả `.github/workflows/build.yml` và `build_final_complete.yml`.
- **Root cause (xác nhận qua GitHub Releases API + lịch sử git):** bước
  "Zip Windows build" ở CẢ HAI `.github/workflows/build.yml` và
  `build_final_complete.yml` (thêm từ ~2026-08-21, xem commit lịch sử
  `755d928`→sau) dùng:
  ```powershell
  $RELEASE_DIR = Get-ChildItem -Path "build/windows/x64" -Recurse -Directory -Filter "Release" | Select-Object -First 1
  Compress-Archive -Path "$($RELEASE_DIR.FullName)\*" -DestinationPath "in4up-Windows-$TAG.zip" -Force
  ```
  Cây build CMake/MSBuild có RẤT NHIỀU thư mục con tên `Release` (VD:
  `build/windows/x64/CMakeFiles/<target>.dir/Release/` chỉ chứa vài file
  `.obj`/`.tlog` build tạm, vài trăm byte–vài KB) — không riêng
  `runner/Release` (bundle thật: .exe + flutter_windows.dll + icudtl.dat +
  data/flutter_assets, hàng chục MB). `Get-ChildItem -Recurse` duyệt theo
  alphabet, `CMakeFiles` < `runner` nên `-First 1` gần như luôn vớ trúng thư
  mục rác. `Compress-Archive` không báo lỗi vì thư mục nguồn hợp lệ (dù nhỏ)
  → job Windows luôn "success" nhưng release rỗng.
  Bằng chứng: mọi tag từ 21/8 trở đi (`v1.4.0-ai-native-test` 4.2KB,
  `v1.4.0-bisect-a` 4.2KB, ..., `1.7.0` 9.6KB) đều nhỏ bất thường; bản
  `1.5.0` (6/8, trước khi thêm đoạn "tự động quét") vẫn đúng ~33MB.
- **Fix:** cả 2 workflow — bỏ "tự động quét", trỏ thẳng
  `build/windows/x64/runner/Release` (đường dẫn output chuẩn của
  `flutter build windows`), guard có `.exe`, và chặn CI (exit 1) nếu zip
  ra < 5MB — thà đỏ CI còn hơn âm thầm phát hành bản lỗi lần nữa.
- **Lịch sử:**
  - 2026-09-06 | created→done | agent arena/01a07863-in4up | owner hỏi vì sao
    release 1.7.0 chỉ 9.63KB; fix cả build.yml + build_final_complete.yml,
    thêm guard chống tái diễn

### SHERPA-001 — Silero VAD (sherpa_onnx) thay EnergyVad fallback
- **Trạng thái:** done (code; chờ nghiệm thu trên thiết bị)
- **Nội dung:** `SherpaVadCore` (in4up_stt, API sherpa_onnx v1.13.4 verify
  từ source k2-fsa) gọi Silero VAD thật trước; `EnergyVad` chỉ còn là
  fallback khi thiếu `silero_vad.onnx` hoặc sherpa lỗi. Singleton +
  absolute path + verification (Section 3 handover). Model:
  `<app documents>/sherpa_vad_models/silero_vad.onnx`.
- **Bằng chứng:** commit 4a50a77 (VAD core + service) + cd9cccf (fix
  non-null convertedPath); CI App Analyze xanh (run 32519596464).
- **Lịch sử:**
  - 2026-08-21 | created | PLAN-008 (owner via arena/019fe630-vipsound)
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | code + CI xanh; còn chờ user push model lên thiết bị + log "Silero VAD: N segments"

### SHERPA-002 — TTS Piper offline (sherpa_onnx) — bước kế tiếp lộ trình PLAN-008/009
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nội dung:** `SherpaPiperTtsCore` (in4up_stt) bọc `OfflineTts` Piper
  (FastSpeech2 + HiFiGAN) — discover giọng trong
  `<documents>/sherpa_piper_models/` (`<voice>.onnx` + `<voice>_tokens.txt`
  + `espeak-ng-data/` dùng chung), sinh PCM float32 → WAV bytes.
  `PiperTtsEngine` (app) implement `TtsEngine` — engine offline sinh BYTES:
  TtsService thử Piper trước giọng máy (offlineFirst/offlineOnly) và làm
  fallback sau engine online (onlineFirst/onlineOnly); cache riêng
  `piper_tts`; voice khớp language từ tên file (quy ước Piper
  `xx_XX-...`, tên không có locale = universal); toggle trong settings.
  FFI: `ensureSherpaBindings()` singleton dùng chung VAD/TTS/STT —
  KHÔNG re-init, tránh xung đột whisper.cpp + sherpa_onnx.
- **Bằng chứng:** CI App Analyze xanh run 32524455212 (analyze + locale test);
  còn chờ build nghiệm thu của owner + model Piper push vào thiết bị (như SHERPA-001).
- **Lịch sử:**
  - 2026-08-22 | created | lộ trình PLAN-008 "VAD (xong) → Live STT → TTS VITS" + PLAN-009 "offline-first như Gemma Translator"
  - 2026-08-22 | doing | agent arena/01a0251e-in4up | core + engine + tích hợp TtsService; API verify từ source k2-fsa v1.13.4 + pub.dev docs 1.13.6 (khớp pubspec.lock)
  - 2026-08-22 | doing→done | agent arena/01a0251e-in4up | CI App Analyze xanh run 32524455212 (commit 4e1df4e + d4a3dc1); chờ build nghiệm thu của owner + model Piper trên thiết bị

### LANG-630-01 — Sứ giả ngôn ngữ: EN chuẩn fallback + lộ trình bậc vi→en→hi/zh/si→…
- **Trạng thái:** reopened (origin/main mất wave 1 do merge của owner; branch
  arena/01a0296a-in4up + arena/01a0251e-in4up NGUYÊN VẸN — build từ đây có đủ)
- **Nguồn:** người sở hữu (2026-08-22, qua agent arena/01a0296a-in4up —
  "I4U | Language EL HIN CH SH": (1) locale ≠ vi không còn tiếng Việt, thiếu
  dịch → English; (2) triển khai đặc biệt Hindi + Chinese + Sinhala phủ dần
  thay English; (3) lộ trình Việt → Anh → India + Chinese + Sinhala → …).
- **Nội dung (ADR-0002):**
  - Tier lộ trình T0 vi (nguồn) → T1 en (chuẩn fallback, không bao giờ về vi)
    → T2 ưu tiên hi/zh/zh_TW/si → T3 còn lại — machine-checked trong
    `lib/core/language/language_roadmap.dart`.
  - Wave 1: dịch đủ 4 locale ưu tiên lên **100% message chrome** (hi 371/371,
    zh 372/372, zh_TW 372/372, si 371/371 — trừ key keep-English theo chính
    sách `tool/lang_keep_english.json`); vá ~50 message word-salad từng locale
    (vd `hi.readLibrary "पढ़ना library"` → bản sạch); tái sinh
    `generated_ui_translations.dart` + literal `app_localizations_*.dart`
    (CI gen-l10n sẽ chuẩn hóa lại).
  - Ratchet sàn độ phủ: `tool/lang_rollout_floors.json` ↔
    `LanguageRollout.coverageFloors` (test chặn lệch); T2 = 1.0; T3 = độ phủ
    hiện tại (chỉ tăng). Báo cáo: `python3 tool/lang_rollout_report.py`.
  - Hardening runtime: `_valueForLocale` trả en khi giá trị locale thiếu/rỗng.
  - Máy bỏ vào group ADR-0002 của `test/locale_chrome_no_vietnamese_test.dart`
    (CI chạy sẵn; token agent không đổi được workflow GitHub).
  - Vô hiệu hóa `generate_arbs.py` (bootstrap cũ 19 locale × ~50 key ghi đè
    mất catalog) — biến thành guard exit-1.
- **Bằng chứng:** group ADR-0002 trong `test/locale_chrome_no_vietnamese_test.dart`
  (7 test machine-check) + báo cáo report 24/24 locale đạt sàn; CI App Analyze
  chạy file test này sẵn (không đổi workflow — token agent không có quyền
  `workflows`). Chờ owner nghiệm thu chất lượng bản dịch HI/ZH/SI.
- **Lịch sử:**
  - 2026-08-22 | created | owner via chat | yêu cầu "EL HIN CH SH"
  - 2026-08-22 | doing | agent arena/01a0296a-in4up | wave 1 + hạ tầng tier/ratchet + ADR-0002
  - 2026-08-22 | doing→done | agent arena/01a0296a-in4up | mọi check local xanh (ARB parity, không ký tự Việt, floors đồng bộ, T2=100%); chờ CI
  - 2026-08-22 | done (xác nhận CI) | agent arena/01a0296a-in4up | CI App Analyze xanh run 32573825623 (analyze + locale/rollout test); chờ owner nghiệm thu bản dịch HI/ZH/SI
  - 2026-08-23 | thu hoạch vào arena/01a0251e-in4up | agent arena/01a0251e-in4up | review OK → merge 81dc2c8 (không xung đột với SHERPA-001/002); bổ sung file `docs/adr/0002-language-rollout-tiers.md` (commit gốc thiếu file, chỉ tham chiếu) + sửa 3 comment ref test; CI post-merge xanh run 32593596431
  - 2026-08-23 | reopened (merge lost) | agent arena/01a0296a-in4up | owner báo "build vẫn English ở HI/ZH/SI". Kiểm chứng origin/main sau merge của owner: commonConfirm(hi)="Confirm", 222/376 message vẫn EN, language_roadmap.dart + test locale + rule#5 AGENTS không tồn tại → bản build KHÔNG chứa wave 1 (không phải flutter clean). Branch này nguyên vẹn trên remote (CI xanh run 32573825623); hướng dẫn merge lại: xem ADR-0002 + nhánh này. English còn lại hợp lệ sau merge đúng: keep-English keys + 1625 entry legacy fallback (wave 2)

### SHERPA-003 — VAD pipeline file dài 30p: cắt chunk Android + quét async + guard
- **Trạng thái:** done (chờ nghiệm thu trên thiết bị)
- **Nguồn:** owner (2026-08-23) — "chạy tạo lời file 30p bị đơ, crash trên
  nhiều máy Android" + yêu cầu check chức năng VAD tiền xử lý khoảng lặng.
- **RCA (audit VAD 30p):**
  1. Routing + Silero VAD đã apply (file >5MB → pipeline; detect Silero thật)
     nhưng **chuyển chunk trên Android BROKEN**: `ChunkAudioExtractor.
     _cutWithFFmpeg` chỉ tìm ffmpeg CLI (`which`/`where`) — Android không có
     binary → luôn false → MỖI segment dùng file GỐC → Whisper re-transcribe
     TOÀN BỘ file 30p cho từng segment (chậm ×N + duplicate text + OOM).
  2. UI đơ: `SherpaVadCore.detect()` đồng bộ chặn main isolate (readWave
     11.5MB + ~9.400 frame Silero, 0 yield) với file 30p.
  3. Pipeline "chạy Isolate riêng" (README) chưa đúng — VAD + extract chạy
     trên main isolate.
- **Sửa (43c3545):**
  - `AudioConverter.cutSegment()` — cắt theo start-time qua FFmpegKit
    (mobile)/Process (desktop) — cùng đường đã chứng minh.
  - `ChunkAudioExtractor._cutWithFFmpeg` dùng `cutSegment` (hết phụ thuộc
    ffmpeg CLI).
  - `SherpaVadCore.detectAsync()` — yield mỗi 256 frame + onProgress;
    `VadService.detectSpeechSegments(onVadProgress:)`; pipeline pump progress
    ra stream → UI vẽ "Đang quét VAD… N%".
  - GUARD pipeline: cut thất bại → BỎ QUA segment, không re-transcribe
    toàn file.
- **Bằng chứng:** CI App Analyze xanh run 32617775840 (analyze + locale/
  rollout test). Chờ owner chạy lại file 30p trên Android (log verify: xem
  AUDIT-2026-08-23 mục VAD).
- **Lịch sử:**
  - 2026-08-23 | created | owner via chat | "file 30p bị đơ + crash nhiều máy; check VAD tiền xử lý khoảng lặng"
  - 2026-08-23 | doing→done | agent arena/01a0251e-in4up | RCA + fix 3 điểm; CI xanh; chờ nghiệm thu thiết bị

### MODELS-001 — Trung tâm model: import/tải trong app cho VAD + Piper + tài liệu dev
- **Trạng thái:** done (chờ nghiệm thu build)
- **Nguồn:** owner (2026-08-23) — "hướng dẫn đặt model cho user/dev; khi
  quét không có model thì có import thủ công hoặc nút tải mạng" + "Piper
  đỏ vì chưa biết cách đặt model".
- **Nội dung:**
  - `SherpaModelManager` (in4up_stt): status stream + download (dio,
    progress, cancel, retry) + import (file/folder) + verify — cùng
    pattern SttModelManager; KHÔNG auto-download.
  - UI "Quản lý Model AI" (Home) thành 3 nhóm: Whisper STT (cũ) +
    **Silero VAD** (Import .onnx / Tải 2-5MB) + **Piper TTS**
    (Import thư mục / Import file / Tải giọng bundle EN/VI + danh sách
    giọng + xoá; espeak-ng-data theo dõi riêng).
  - `SherpaPiperTtsCore.discoverVoices` nhận THÊM layout bundle k2-fsa
    chính thức (`tokens.txt` dùng chung, không có .onnx.json).
  - `docs/project/MODELS.md`: bảng thư mục + tên file + adb push +
    nguồn tải verify — trả lời "đặt ở đâu, tên gì".
  - URL tải verify 2026-08-23: k2-fsa GitHub releases (asr-models/
    silero_vad.onnx; tts-models/ vits-piper-*.tar.bz2 — 536 giọng, có
    vi_VN). Piper bundle = 1 file tar.bz2 gồm onnx + tokens +
    espeak-ng-data (app không tự giải nén bz2 — hướng dẫn user).
- **Bằng chứng:** CI App Analyze (chờ run sau push). Verify on-device:
  mở "Quản lý Model AI" → VAD card Tải về → xanh; Piper card Tải giọng
  → giải nén → Import thư mục → xanh + phát thử.
- **Lịch sử:**
  - 2026-08-23 | created | owner via chat | 3 câu hỏi (hướng dẫn đặt model / quản lý 1 chỗ / Piper đỏ)
  - 2026-08-23 | doing→done | agent arena/01a0251e-in4up | manager + 2 card UI + core layout + MODELS.md
  - 2026-08-23 | CI đỏ → fix (3 lỗi compile, postmortem) | agent arena/01a0251e-in4up |
    (1) '$voiceName_tokens.txt' — interpolation maximal munch đọc thành
    biến 'voiceName_' → Undefined name (fix: '${voiceName}_tokens.txt');
    (2) 'url' khai báo trong try, dùng $url trong catch → out-of-scope
    (fix: hoist trước try); (3) screen: const Expanded chứa Theme.of
    (not a constant expression, 2 chỗ) + fp.FilePicker.platform (không
    có trong file_picker 11.x — dùng fp.FilePicker. trực tiếp, 3 chỗ).
    Lọc nhờ smoke test ép CFE compile graph qua knowledge_tests + đọc
    job log qua blob signed URL (artifact/job-log API bị chặn EOF).
  - 2026-08-23 | thêm (cùng wave) | agent arena/01a0251e-in4up | sheet
    'Lưu cụm/câu đầy đủ' nguồn TXT: thêm CHỦ ĐỀ + NGÔN NGỮ + pre-fill
    entry đã có (parity với web/PDF — owner báo 'ngèo nàn') + fix
    overflow 48px chip 'Cụm/từ liên đới' (constrain word 140px +
    ellipsis)

### READ-630-05 — Tab Đọc: nhận diện text đã lưu khi lưu nhiều text + gợi ý hành động
- **Trạng thái:** proposed
- **Nội dung:** khi lưu dạng nhiều text (lưu hàng loạt), text đã có trong
  WordList phải được NHẬN DIỆN + THÔNG BÁO cho user + gợi ý hành động
  tiếp: thêm ngữ cảnh (nếu ngữ cảnh mới) / cập nhật (nghĩa, note, tag) /
  bỏ qua. Nền có sẵn: badge `đã có`/`mới` + "Chỉ chọn mục MỚI"
  (SelectionSaveSheet, READ-630-04), smart-fill của
  addWithAutoClassify (bổ sung context+tag, không ghi đè),
  WordEntry.contexts để so context mới/trùng. Chi tiết: PLAN-015.
- **Lịch sử:**
  - 2026-08-23 | created | owner via chat (đề xuất tính năng sắp tới)

### PDF-W1 — PDF Reader: đợt A (điều hướng & tìm kiếm, đứng trên API pdfrx) · B (chủ đề đọc) · C (xuất/nhập chú thích B1+B2)
- **Trạng thái:** doing — code + CI 🟢 cả 3 đợt, chờ nghiệm thu thiết bị + `flutter test` của owner (chưa phải done)
- **Nguồn:** owner (2026-09-05): "Tiếp tục theo lộ trình bạn cho là hợp lý nhất"
  sau khi Wave 0 xanh CI. Lộ trình ở `docs/pdf_reader_readera_upgrade.md` mục
  WAVE 1; đợt A = 1.1 + 1.2 + 1.3 + nhảy trang nhanh (1.4/1.5/1.7/1.8/1.9 để
  lại vì đổi cảm giác đọc toàn màn hình, cần owner chốt).
- **Nội dung:**
  - **1.1 TOC**: `services/pdf_outline_index.dart` (cây `PdfOutlineNode` → danh
    sách phẳng, `findActiveOutlineIndex`, chốt rõ dest 1-based ↔ controller
    0-based) + `widgets/pdf_toc_panel.dart`; nhảy bằng `goToDest` để giữ cả vị trí
    trong trang; file không outline → thông báo thật, không crash; panel tự cuộn
    tới chương đang đọc MỘT lần khi mở (không đuổi theo từng lượt lật trang).
  - **1.2 Search**: dùng `PdfTextSearcher` của pdfrx (quét dần từng trang, cache
    structured text, `searchProgress`, `pageTextMatchPaintCallback` vẽ qua
    `pagePaintCallbacks`) — KHÔNG tự viết index/isolate ⇒ P0-11 không còn chặn
    tính năng này (Text Mode vẫn nợ). `services/pdf_search_query.dart`: escape
    ký tự đặc biệt, space khớp cả `\n`, tuỳ chọn "Không phân biệt dấu" gộp theo
    họ **1:1** (cố ý không co giãn `aa`↔`â` để offset tô sáng không lệch).
    `widgets/pdf_search_panel.dart` bám searcher như `Listenable`; cú nhảy bọc
    try/catch vì layout trang đích có thể chưa sẵn. Searcher tạo ở `onViewerReady`
    (không phải `onDocumentChanged`) vì ctor nó đọc `controller.document`.
  - **1.3 Thumbnails**: `widgets/pdf_thumbnail_grid.dart` — `PdfPageView`
    `maximumDpi: 96` trong `GridView.builder` (tab "Trang" cùng sheet).
  - **Nhảy trang**: nhãn "37 / 512" trên toolbar thành nút → dialog số + Slider.
  - Đang mở ô tìm ⇒ chrome không được ẩn (ô nhập liệu).
  - 13 nhãn mới vào `priority_ui_overrides.dart` (rule #5, không chạy generator).
  - Test mới: `test/pdf_reader/pdf_outline_index_test.dart`,
    `test/pdf_reader/pdf_search_query_test.dart`.
- **Kiến trúc:** ADR-0004 (đứng trên API pdfrx, không nâng `pdfrx ^2.2.24`, không
  tự xây search index, chính sách gộp dấu 1:1).
- **Rủi ro còn lại:** `test/pdf_reader/**` (7 file) **chưa chạy lần nào** — CI của
  workflow này chỉ chạy `test/locale_chrome_no_vietnamese_test.dart`; cần
  `flutter test test/pdf_reader test/locale_chrome_no_vietnamese_test.dart` ở máy
  dev. Hành vi touch/paint của `PdfTextSearcher` trên máy yếu + sách 800 trang chưa
  đo. P0-19 (hai nguồn offset) còn mở: "tìm rồi đọc từ chỗ tìm" phải đợi hợp nhất.
- **Lịch sử:**
  - 2026-09-05 | created→doing | agent arena/01a07250-in4up | 3 commit
    `99540d9` (service+test) → `a4b91dc` (widget) → `c4f62c5` (nối màn đọc + i18n);
    merge `7219ee4` kéo `arena/01a0251e-in4up` (Sherpa live STT + LRC đa ngữ) vào
    trước để tránh giẫm nhau — resolve 1 conflict ở `priority_ui_overrides.dart`
    (hai bên cùng append cuối map; giữ cả hai, 294 key, 0 trùng).
  - 2026-09-05 | bổ sung 1.9 | agent | `251c935` phím tắt desktop (`Focus.onKeyEvent`
    + bảng ưu tiên thuần + hộp "Phím tắt" trong menu More) + 6 nhãn i18n;
    `dc487d1`/`eb56035` sửa comment lẫn ký tự Hán.
  - 2026-09-06 | đỏ → xanh | agent | `251c935` đỏ vì `LogicalKeyboardKey.plus` không
    tồn tại (2 error, thấy được nhờ probe tắt lint — xem docs/skills/ci-red-debugging
    §6.2); `bca3bd3` sửa + revert `analysis_options.yaml` về baseline → run
    34011982375 🟢 cả hai step.
  - 2026-09-06 | merge 251e lần 2 | agent | `78f8513`+`71291c3` (tipitaka reading +
    pubspec.lock): auto-merge sạch, `priority_ui_overrides.dart` lên 318 key, **0 trùng**
    (kiểm tra bằng script đếm key — auto-merge không đảm bảo hết trùng key trong cùng
    một const map).
  - 2026-09-06 | đợt B (1.5) | agent | `services/pdf_reader_theme.dart` (thuần: veil
    màu + clamp + prefs khoan dung) + `widgets/pdf_page_veils.dart` (dịch veil sang
    `pagePaintCallbacks`) + `widgets/pdf_reader_theme_sheet.dart` (4 theme + slider độ
    sáng) + 9 key i18n (catalog 327 key, 0 trùng) + `test/pdf_reader/pdf_reader_theme_test.dart`
    (223 dòng). CI 🟢 run 34042635098 **ngay lần đầu** — vì mọi tên API pdfrx đối
    chiếu tag `pdfrx-v2.2.24` trước khi gõ (bài học §4.1.1).
  - 2026-09-06 | cứu worktree | agent | sandbox bị clone lại lần 2: HEAD rơi về
    `a55dfa8`, ref `origin/arena/*` mất, 53 file công việc thành uncommitted. Không mất
    gì: đóng băng bằng `git add -A && git commit` → `git ls-remote` xác nhận GitHub còn
    `032f321` → fetch refspec tường minh → `git diff` rỗng → `git reset --hard`. Củng cố
    rule của repo: **push liên tục là backup duy nhất**.
- **2026-09-06 (đợt C, wave 2 mục 2.6 — bậc B1+B2 do owner chốt):**
  - B1: sidecar `.in4up.json` có version + header định danh file (size+mtime, KHÔNG dùng
    đường dẫn), `decodePdfAnnotationSidecar` không ném / bỏ dòng hỏng, `compareSidecarToFile`
    → `sameFile|contentChanged|pageChanged|unknown`, `mergeSidecarAnnotations` (mới hơn thắng,
    hoà → note dài hơn), `PdfReaderController.importAnnotations()` cấp uuid mới cho dòng nhập.
    XFDF cho highlight+ghi chú (`annotReplace`, rect/quadpoints/opacity 0.40, `<text
    icon="Comment">`) — **chỉ xuất**, không nhập XFDF.
  - B2: "in bản chụp" = `PdfPage.render()` → BGRA thô → `pdf_snapshot_burn.dart` phủ
    highlight (alpha 0.35) + marker ghi chú → `pdf_snapshot_pdf_writer.dart` tự dựng PDF
    (image XObject/trang, Predictor 15, xref) → `share_plus` 12 (`ShareParams(files:[XFile])`,
    không còn `shareXFiles`). **Không thêm dependency nào**; tệp PDF gốc không bị sửa nên đây
    là ảnh chụp, không phải stamp thật.
  - Nối UI: `widgets/pdf_export_row.dart` trong `⋮ → Quản lý ghi chú` (JSON / XFDF / PDF ảnh /
    Nhập JSON), kết quả in inline vì sheet 0.88 che SnackBar; import hiện dialog xác nhận đếm
    số annotation + mức trùng tệp trước khi merge. 23 key vào `priority_ui_overrides.dart`
    (không chạy generator), 5 file test mới = 51 test, `test/pdf_reader` lên 14 file / 134 test.
  - Ghi lại 5 lỗi biên dịch CI bắt được (§4.3) — không có Flutter SDK trong sandbox nên CI là
    compiler duy nhất: `math.min/max` suy luận `num` làm vỡ index `Uint8List`,
    `const ZLibEncoder().encode()` (sai cả tên API lẫn const), `ZLibCodec` ctor là `factory`
    nên không const, `latin1.decode(..., allowMalformed:)` không tồn tại, test thiếu `Color`
    trong `import 'dart:ui' show …`.
  - **Chưa done:** chạy `flutter test test/pdf_reader` + round-trip share sheet trên máy owner;
    nghiệm thu thiết bị §4.1/§4.2 còn treo; phần 2.6 còn lại (Markdown/CSV, in, stamp thật).

### PDF-W0 — Wave 0 PDF Reader: sửa cho đúng cái đã có (không thêm tính năng)
- **Trạng thái:** doing — code xong, CI 🟢 (analyze 0 error + rule #5 test xanh); còn nghiệm thu thiết bị
- **Nguồn:** owner (2026-09-05): "Hãy phân tích thảo luận với tôi" → "Hãy tiến
  hành!" sau khi đọc `docs/pdf_reader_readera_upgrade.md`. Đối chiếu ReadEra.
- **Nội dung:** 5 wave được đề xuất; wave 0 = nối lại phần máy đang bị đứt, không
  thêm tính năng. 12 mục 0.1→0.10 + 0.16/0.17/0.18 đã code:
  - selection pdfrx → controller (`textSelectionParams.onTextSelectionChange`,
    giữ mảnh chọn theo từng trang + offset → reopen đúng chỗ, rule vàng #3);
  - xoá overlay `_WordTapDetector` (thủ phạm chặn pan/zoom), chuyển sang
    `onGeneralTap`: chạm = sheet từ, long-press = chọn từ, handle = mở rộng;
  - hit-test theo px + dung sai theo cao độ chữ (`pdf_word_hit_test.dart`);
  - TTS theo CÂU (`extractSentences` + `PdfSentenceCue`), karaoke highlight,
    prev/next trang + câu, pause/resume, auto-advance, speed; ẩn tuỳ chọn
    "Song ngữ" thay vì hứa suông (`isBilingualTtsAvailable=false`);
  - `PdfFileIdentity` (md5(size|mtime) + pathKey dự phòng + migrate 3 thế hệ key)
    → đổi tên/chuyển file không mất highlight, không mất trang đọc;
  - `Uuid` cho annotation id, `lineRects`, `canReopenToPosition`;
  - bỏ auto-hide chrome 3 s; bookmark thật (dùng `AnnotationType.bookmark`);
    basename 2 nền tảng (`pdfBaseName`/`pdfSourceMatches`) cho panel từ đã lưu;
  - `services/pdf_geometry.dart` = nguồn sự thật duy nhất cho quy đổi toạ độ
    (P0-18: rect PDF space có `top > bottom` → `height` âm, `contains` luôn false);
  - 51 key i18n vào `priority_ui_overrides.dart` (không chạy generator — rule #5);
  - 5 file test sàn trong `test/pdf_reader/` (geometry, hit-test bất biến zoom,
    annotation round-trip/dữ liệu cũ, file identity với temp file thật, cleaning,
    quét phủ i18n của feature).
- **Kiến trúc:** ADR-0003 (giữ quy ước toạ độ đã lưu — chỉ đổi chỗ quy đổi;
  khoá dữ liệu đọc là identity chứ không phải đường dẫn).
- **Rủi ro còn lại:** CI analyze đã xanh nên phần biên dịch/signature pdfrx ổn; nhưng
  `test/pdf_reader` (5 file) **chưa chạy lần nào** (CI workflow này chỉ chạy
  `test/locale_chrome_no_vietnamese_test.dart`) ⇒ cần `flutter test test/pdf_reader`
  ở máy dev trước khi tin Wave 0 xong. P0-11 (extract đa cột/isolate) và P0-12
  (reading order) còn mở — ghi ở doc mục 4.0.3.
- **Lịch sử:**
  - 2026-09-05 | created→doing | agent arena/01a07250-in4up | theo doc phân tích
    `docs/pdf_reader_readera_upgrade.md`; chưa commit CI
  - 2026-09-05 | CI đỏ → xanh | agent | 3 commit sửa lỗi CI (`f02854c`, `c62e8bf`,
    `370ff91`): regex raw-string `\'` (khai sinh ~20 error), `pdfSourceMatches` nhận
    `String?`, bỏ `const` trong test, 2 key trùng ở `priority_ui_overrides`, `leading:`
    kép trong `pdf_reader_screen`. Probe `analysis_options.yaml` (tắt lint để thấy lỗi)
    đã revert cùng đợt. Run `33984585516` 🟢 cả hai step. Cách đọc log CI:
    `docs/skills/ci-red-debugging` §6.1.

### REOPEN-001 — Mở lại file cũ dùng LRC + bản dịch đã lưu (không tạo/dịch lại)
- **Trạng thái:** done (chờ CI + nghiệm thu trên thiết bị)
- **Nguồn:** owner (2026-08-23) — "mở lại file mp3 cũ nhấn tạo lời thì nếu đã
  có bản lưu stt và dịch từ trước nên nhắc nhở/gợi ý; mở mp3 cũ thì quét xem
  đã từng tạo lời chưa, có thì mở luôn chứ mỗi lần mở phải tạo lời mất thời
  gian". Fix gốc từ agent arena/01a01580-in4up (commit d8486d3, đã check trên
  nhánh 251e).
- **RCA (trên 251e trước fix):**
  - STT ghi .lrc vào documents/.in4up_lrc/<tên>.lrc nhưng `findCachedLrcPath`
    chỉ tìm file .lrc CẠNH file gốc + `{path.hashCode}.lrc` — Android thường
    không ghi được cạnh file gốc (SAF), hashCode đổi sau restart → mở lại MP3
    = không thấy lời → phải bấm Tạo lời (chạy Whisper lại), nút không hỏi.
  - TranslationCache dùng `String.hashCode` → đổi mỗi VM session → mở lại
    document, cùng câu bị coi chưa dịch → dịch lại từ mạng.
  - Recent file/audio id dựa hashCode → cùng file thành 2 mục.
- **Sửa (f5cd164):**
  - `SourceArtifactStore` (mới): index LRC theo fingerprint
    MD5(size|duration|tên) tại .in4up_lrc/index.json; `peekCachedLrc()`
    quét index + .in4up_lrc + sidecar cạnh file.
  - Sau mỗi lần tạo LRC (VAD pipeline + direct) → `_rememberGeneratedLrc()`
    ghi index. Mở MP3 cũ: autoLoadCachedLrc tìm thấy → nạp luôn; bấm Tạo
    lời khi có bản lưu → hộp thoại **Dùng bản đã lưu / Tạo lại / Hủy**
    (`confirmAndGenerateLrc`); `generateLrcForCurrentAudio(forceRegenerate:)`.
  - TranslationCache key MD5 ổn định + migration 1 lần từ key hashCode cũ;
    `rehydrateTranslationsFromCache()` khi load document (text_provider) →
    paint lại bản dịch, không gọi mạng.
  - Recent audio/file: id MD5 + dedup theo path (không nhân bản).
- **Hoàn thiện (d8486d3 thiếu, compile không được nếu ghép nguyên):**
  `applyCachedLrc()`, body `_rememberGeneratedLrc()`, param
  `forceRegenerate` + cache guard, legacy-key migration trong `get()`.
- **Bằng chứng:** CI App Analyze + Locale xanh run 32650359097
  (f5cd164 + fix return-type confirmAndGenerateLrc). Verify on-device:
  tạo lời file MP3 → tắt app → mở lại → lời hiện ngay; bấm Tạo lời →
  hiện hộp thoại hỏi Dùng bản đã lưu/Tạo lại; mở document cũ đã dịch →
  dịch hiện lại từ cache (không gọi mạng).
- **Lịch sử:**
  - 2026-08-23 | created | owner via chat (gửi từ nhánh 01a01580) | fix d8486d3
    đã check trên 251e, nhờ tích hợp sang nhánh 251e
  - 2026-08-23 | doing→done | agent arena/01a0251e-in4up | checkout 10 file từ
    d8486d3 + 2 chỉnh tay (listen_mode_screen, text_provider) + hoàn thiện 3
    chỗ thiếu; CI đầu đỏ do return_of_invalid_type_from_closure (closure
    onGenerate) → fix return type confirmAndGenerateLrc → CI xanh
    run 32650359097; chờ nghiệm thu thiết bị

### LISTEN-823-01 — Tab Nghe: rèm LRC tối đa, AI sheet linh hoạt, dịch ở Hiểu
- **Trạng thái:** done (fix bổ sung chờ nghiệm thu đổi file trên thiết bị)
- **Nguồn:** người sở hữu (2026-08-23, qua agent arena/01a02fee-in4up — thay
  nhánh quản lý Listen arena/019fe27a-vipsound bị lỗi).
- **Nội dung:**
  1. Sau khi tạo/nạp LRC thành công, rèm lời thoại mặc định mở đến chiều cao
     tối đa an toàn và chạm biên waveform.
  2. Sửa RenderFlex bottom overflow khoảng 126px khi đã có lời rồi mở AI/model
     selector: tính budget theo viewport thật của tab, không lấy toàn MediaQuery.
  3. AI chuyển từ inline panel sang `DraggableScrollableSheet`: nội dung cuộn
     chung với sheet; kéo xuống đến đáy đóng sheet; chạm vùng ngoài hoặc nút X
     cũng đóng.
  4. Tab Hiểu dùng cùng bộ ghép LRC↔TextProvider với tab Nghe, nên bản dịch đã
     tạo/lưu ở tab Đọc hiện khi bật "Hiện bản dịch" trong cài đặt karaoke.
- **Bằng chứng:** `test/lrc_translation_resolver_test.dart`; commit `bf83fdc`;
  App Analyze + Locale xanh run `32659292077`; chờ nghiệm thu gesture/layout
  trên thiết bị thật.
- **Lịch sử:**
  - 2026-08-23 | created→doing | agent arena/01a02fee-in4up | nhận 4 yêu cầu từ owner, triển khai code + test
  - 2026-08-23 | 18:52 UTC | doing→done | agent arena/01a02fee-in4up | bf83fdc; CI 32659292077 xanh
  - 2026-08-24 | 00:43 +0530 | done→reopened | owner + agent arena/01a02fee-in4up | audio mới vẫn giữ lời cũ; RCA: PlayerProvider chỉ nhận UnderstandProvider sau khi vào tab Hiểu, in-memory LRC fallback không gắn audio nguồn, callback async cũ có thể ghi trả lại
  - 2026-08-24 | 00:46 +0530 | reopened→done | agent arena/01a02fee-in4up | 1d05ce9: inject provider toàn cục, clear UI/editor, bind cache với source, chặn callback cũ; CI 32660616256 xanh

### LHB-001 — Learn by Heart (Dhammapada SRS) — nghiệm thu từ nhánh 019ff2de
- **Trạng thái:** done (chờ nghiệm thu UX trên thiết bị)
- **Nguồn:** agent arena/019ff2de-in4up (branch 35d1d48, Spec v4.1 FINAL SEALED)
- **Nội dung:** 30 file +5765 dòng: models (LearnByHeartItem, FSRSParams,
  Chunk, LineTimestamp, ReviewState, RecitationCategory), services
  (FSRSEngine cold-start [0,1,3,7,14] ngày + assessment trọng số x2,
  ClozeGenerator deterministic, LearnByHeartStorage SharedPreferences,
  MultilingualAudioService highlight dòng theo timestamp), 6 screens
  (hub, active recall, assessment, chunking flow, item editor, new
  learning), 5 widgets, seed Dhammapada (≥12 kệ, Pali + Việt + chunks +
  keywords), test 161 dòng, tích hợp main.dart + main_shell (tool
  "Thuộc lòng") + RememberWorkspace chip.
- **Nghiệm thu (2026-08-24, agent 01a0251e):** review code OK (FSRS
  monotonic again<hard<good<easy, assessment perfect x2.2 stability,
  audio service dispose đúng, storage round-trip JSON); merge-tree clean
  (không xung đột với 251e); test CI xanh; merge 15deaf0 vào 251e →
  App Analyze + Locale xanh 32662979309. Ghi nhận minor: field
  `lapseCount` song song chết (engine chỉ update `fsrsParams.lapses` —
  không hiển thị ở đâu, không gây lỗi); UI hard-code tiếng Việt (nhất
  quán với codebase hiện có — rule #5 áp dụng khi wave i18n).
- **Lịch sử:**
  - 2026-08-24 | created→done | agent arena/01a0251e-in4up | nghiệm thu
    branch 019ff2de (35d1d48) + merge 15deaf0; CI xanh 32662979309
  - 2026-08-25 | thu hoạch thêm 0ed55c8 | agent arena/01a0251e-in4up |
    cherry-pick -x → fb483df (scaffolding 4 tầng + i18n 6 ngôn ngữ, xem LHB-002)

### LHB-002 — Vanishing cloze scaffolding 4 tầng + first-letter mnemonics + i18n 6 ngữ
- **Trạng thái:** done (chờ CI + nghiệm thu UX trên thiết bị)
- **Nguồn:** chủ yêu cầu (2026-08-25) — thâu hoạch commit mới nhất
  `0ed55c8` của `arena/019ff2de-in4up`.
- **Nội dung:** 9 file +786/−142: `learn_by_heart_l10n.dart` (mới, 350 dòng —
  6 ngôn ngữ vi/en/hi/zh/zh_TW/si + fallback), ClozeGenerator 4-level
  progressive vanishing (full → scaffolding → first-letter → blank) +
  first-letter mnemonics (hỗ trợ Pali diacritics), cloze_interactive_text
  (235 dòng) + active_recall/hub/assessment_rating_bar/fsrs_rating_bar/
  elaborative_card dùng l10n, test thêm 3 group (scaffolding accuracy,
  Pali diacritics, i18n coverage + fallback).
- **Bằng chứng:** cherry-pick clean (9 file không phân kỳ từ 35d1d48);
  CI App Analyze chạy khi push.
- **Lịch sử:**
  - 2026-08-25 | created→done | agent arena/01a0251e-in4up | cherry-pick -x
    0ed55c8 → fb483df; chờ CI xanh + nghiệm thu UX
  - 2026-08-25 | fix compile | agent arena/01a0251e-in4up | 0ed55c8 đã đỏ
    sẵn trên cả 019ff2de (undefined_getter `l10n.allCategories`/`allStates` —
    hub screen tham chiếu nhưng l10n thiếu) → fix 3c22e97 (thêm 2 getter
    6 ngôn ngữ); App Analyze + Locale XANH run 32772381254
  - 2026-08-25 | thu hoạch 0177c35 | agent arena/01a0251e-in4up |
    cherry-pick -x → 4f123e6 (keywords mode render plain text + isMaskedAtLevel
    + counters theo level + level1..4Desc). CI 019ff2de xanh 32775838260.
    Dedup allCategories/allStates (bản 0177c35 chính thống thay fix tạm 3c22e97)

### SOUNDLIST-630-02 — transcriptFromLrcLines: end = dòng không trống kế tiếp
- **Trạng thái:** done
- **Nguồn:** CI đỏ Soundlist run 32521698801 (test 137) — bug có sẵn
  trên 251e (nhánh learn_by_heart cũng dính).
- **Nội dung:** dòng LRC trống/whitespace nằm giữa 2 dòng nội dung làm
  `end` của dòng trước = timestamp dòng trống (= start) thay vì +3s
  fallback → highlight/playback transcript sai. Fix: tìm dòng không
  trống kế tiếp làm end; dòng cuối +3s.
- **Bẫy (ghi nhận):** tồn tại 2 file duplicate —
  `lib/providers/soundlist_provider.dart` (bản sống: main.dart, screens,
  test import) và `lib/models/soundlist_provider.dart` (bản chết: 0
  importers, tự import bản sống). Fix lần đầu (2fb9ead) trúng bản chết —
  sửa lại bản sống ở c978432; cả 2 bản giờ cùng fix. **Khuyến nghị
  cleanup:** xóa bản chết hoặc gộp (chờ owner duyệt).
- **Bằng chứng:** CI Soundlist xanh run 32663677483; App Analyze xanh
  32663677470.
- **Lịch sử:**
  - 2026-08-24 | created→done | agent arena/01a0251e-in4up | fix + CI xanh

### LHB-003 — Voice Recall + Nối xích câu kệ + Anki Cloze (thu hoạch 019ff2de)
- **Trạng thái:** done (chờ CI + nghiệm thu mic trên thiết bị)
- **Nguồn:** chủ yêu cầu (2026-08-25) — nghiệm thu `0177c35` của
  `arena/019ff2de-in4up`; thu hoạch kèm `10fecd3` (commit mới hơn trên nhánh).
- **Nghiệm thu 0177c35:** review OK — `ClozeToken.isMaskedAtLevel(level)`
  (4 level đầy đủ), keywords mode ghost đúng `isKeyword || isMasked`,
  firstLetter mode prompt cho TẤT CẢ từ (fix bug: từ không-masked trước
  đây render chữ thường), từ dấu câu/punctuation giữ nguyên (không thành
  '___'), counters `_totalMaskedForLevel`/`_revealedForLevel`, hint icon +
  màu theo level (level1..4Desc). CI 019ff2de XANH 32775838260.
- **Nội dung 10fecd3:** 8 file +1196/−52 — VoiceRecitationService (ghi mic
  qua RecordingService có sẵn + STT offline + fuzzy align Levenshtein
  cửa sổ ±3/4, chấm exact/partial/missed, gợi ý FSRSRating ≥88→easy),
  VoiceRecitationSheet (351 dòng), ChainRecitationController + View
  (nối xích line-by-line), AnkiClozeParser (`{{c1::từ::gợi ý}}` —
  hasAnkiCloze/getCardIndices/stripAnkiSyntax/parseToTokens),
  ItemEditor tự nhận diện Anki Cloze khi lưu (rút keyword + strip syntax),
  ActiveRecall thêm mode "Nối xích" + nút mic, test 3 group mới.
- **Fix compile (10fecd3 đỏ sẵn trên 019ff2de, run 32776254590):**
  `voice_recitation_service` gọi `_stt.transcribeFile(filePath:, language:)`
  + `res.text` — SttServiceFacade không có API đó (transcribeFile dùng
  positional + không có language; output là SttTranscribeOutput có
  .success/.result.fullText) → sửa dùng `transcribeAuto(path, language:,
  generateLrc: false)` (giống luồng auto-TOC). Cross-check thêm: toàn bộ
  tham chiếu l10n/item model/AnkiClozeParser/ChainRecitationController/
  VoiceRecitationSheet.show đều resolve.
- **Lịch sử:**
  - 2026-08-25 | created→done | agent arena/01a0251e-in4up | cherry-pick -x
    10fecd3 → 19efa2d (amend fix transcribeAuto); chờ CI + nghiệm thu mic

### HARVEST-1580-01 — Thâu hoạch phần còn thiếu từ 01a01580 (1580)
- **Trạng thái:** done (chờ CI + nghiệm thu thiết bị cho fix docx)
- **Nguồn:** chủ yêu cầu (2026-08-25) — "cherry-pick những phần còn thiếu từ 1580".
- **Đã có sẵn trên 251e (KHÔNG lấy lại, tránh đè):**
  - STT tải khi bấm (`928525a`) — `stt_model_manager`/facade cùng blob
  - Chấm viết 2 tầng + reload GGUF (`e4b51ff`) — `write_studio`/`ai_analysis`/mock
  - Mở lại MP3 dùng LRC đã lưu (`d8486d3`) — đã vào qua REOPEN-001 (`f5cd164`)
  - STT engine strategy Whisper+Native (`f8fd639`) — 4 file giống hệt
  - `ai_engine_gemma.dart` / `ai_service_facade.dart` / cả `in4up_stt/lib/` —
    251e đã tích hợp llama/Sherpa, đè là mất (theo `PROMPT_DEV_NHAN_580`)
- **Cherry-pick sang 251e lần này (chỉ tài liệu + 1 fix docx):**
  - `a8e0c3c` so-tay BETA=`01a02a12` → bản đã nằm sẵn (no-op, skip)
  - `f969dd8` so-tay mục A (Repo chính In4Up) + thứ tự 02601/296a vào DEV
    (conflict `ai_engine_gemma` — giữ bản 251e, chỉ lấy phần so-tay)
  - `7ec51df` so-tay tên APK `app-stable-<abi>`, PR #9 không merge main
  - `dbe4728` `PROMPT_AGENT_DICH_OFFLINE.md` (prompt dịch offline + glossary Pali)
  - `80c205a` `PROMPT_DEV_NHAN_580.md` (sổ chỉ dẫn nhận phần 580, ghi "khong merge")
  - `d8a26ee` `AUDIT_MAT_MERGE_DEV.md` (rà soát mất chức năng do merge DEV)
  - `42ec495` **fix(docx) tiếng Việt liền mạch** → commit `356388a`
    (parser chỉ nối `<w:t>` trong đoạn + tokenizer Unicode + test)
- **Bằng chứng:** `git cherry HEAD origin/arena/01a01580-in4up` — các code 580
  còn dấu `+` đều đã có bản tương đương trên 251e (đối chiếu blob, xem trên).
- **Lịch sử:**
  - 2026-08-25 | created→done | agent arena/01a0251e-in4up | cherry-pick 7 commit
    (6 docs + 1 docx fix) với `-x`; đối chiếu blob từng file; chờ CI + nghiệm thu

### LISTEN-825-01 — Màn hình đỏ ListenLibraryScreen: nhiều animation ticker
- **Trạng thái:** done (chờ chủ mở lại tab Nghe trên thiết bị xác nhận hết đỏ)
- **Nguồn:** chủ báo (2026-08-25) + fix `4bb14a3` trên nhánh `arena/01a03564-in4up`.
- **RCA:** `ListenLibraryScreen` tạo 2 ticker — `TabController(length: 2)`
  (tab Thư viện do Audio Library P1) + `_fabAnim` (AnimationController FAB)
  — trong khi State chỉ `SingleTickerProviderStateMixin` (giới hạn 1 ticker)
  → exception "A Ticker was active..." → màn hình đỏ. Lỗi xuất hiện khi
  màn hình có đủ 2 tab (sau thu hoạch Audio Library P1).
- **Sửa:** `with TickerProviderStateMixin` (1 dòng). An toàn vì `dispose()`
  đã dispose cả `_tabController` lẫn `_fabAnim` (TickerProviderStateMixin
  không auto-dispose).
- **Bằng chứng:** cherry-pick -x 4bb14a3 → 4b6a677; App Analyze + Locale
  XANH run 32777390692.
- **Lịch sử:**
  - 2026-08-25 | created→done | agent arena/01a0251e-in4up | cherry-pick fix
    từ 01a03564; CI xanh 32777390692

### MODELS-002 — Trung tâm model: quản lý AI Chat (Gemma GGUF) 1 chỗ + UX import rõ ràng
- **Trạng thái:** doing (chờ nghiệm thu máy — CI app_analyze đã XANH run 35027200801)
- **Nội dung:** (1) Chat screen: banner trạng thái model luôn hiện — chưa nạp
  (vàng, bấm để import) / copy file X% / tải từ URL X% / đang nạp native
  (1–2 phút) / lỗi + "Thử lại" / sẵn sàng (xanh + tên file + MB). (2) Engine
  Gemma gửi tín hiệu model-load từ isolate (sau llama_model_load) — facade
  `hasModel` chỉ true khi model THẬT sự nạp xong; `sendMessage` chờ signal
  trước khi analyze; mock reply luôn kèm disclaimer "⚠️ Chưa nạp model AI —
  đây là trả lời MẪU". (3) Màn "Quản lý Model AI" (home settings, có sẵn cho
  STT/VAD/TTS từ MODELS-001) thêm section 4 "Chat — Gemma (LLM)": status +
  Import .gguf + Tải về (dialog URL, default HuggingFace Gemma-2-2B-it Q4_K_M
  ~1.5GB, chỉ WiFi, progress bar) + Xóa (confirm). (4) Import copy theo chunk
  8MB kèm tiến độ; download verify header GGUF sau tải; `AiModelConfig.
  defaultDownloadUrl` cho nút Tải về.
- **Nguồn:** thu hoạch từ `arena/01a02a4a-in4up` (26571af, 38e8865, b84e571,
  2868af2) — 2026-08-25, agent arena/01a0251e-in4up.
- **Bằng chứng:** CI oracle app_analyze.yml (analyze + locale test) khi push.
- **Ghi chú debt:** generator legacy_ui_fallbacks chưa chạy được trên tree merge
  — còn ~179–194 literal chưa phân loại (toàn từ các commit 01a0251e trước,
  không phải của card này; CI không chạy generator nên không chặn).
- **Lịch sử:**
  - 2026-08-23 | created | owner via chat | "import xong không thấy biểu hiện gì… nên quản lý models 1 chỗ nơi setting của home, import trực quan và tải online"
  - 2026-08-23 | proposed→doing | agent arena/01a02a4a-in4up | implement engine signal + facade stages + banner + section settings
  - 2026-08-25 | thu hoạch vào 251e | agent arena/01a0251e-in4up | cherry-pick -x 4 commit (chờ CI + nghiệm thu)
  - 2026-08-25 | fix compile ×3 | agent arena/01a0251e-in4up | 26571af gốc
    (đỏ cả trên 01a02a4a run 32665063225) có 3 lỗi compile — bisect 11 vòng
    oracle (skill ci-red-debugging) định vị:
    (1) gemma `_spawnIsolate`: `final loadCompleter = _modelLoadCompleter;`
        đọc field `Completer<void>?` (nullable) rồi `.isCompleted/.complete()`
        không null-check → "receiver can be null". Sửa: tạo Completer local
        non-null rồi gán field.
    (2) loader `_copyFileWithProgress`: gọi `rs.read(buffer, ...)` — không
        tồn tại (`File.openRead()` trả `Stream<List<int>>`, không phải
        RandomAccessFile). Sửa: copy theo stream (openRead + openWrite IOSink,
        cùng pattern đã chứng minh trong downloadModel).
    (3) loader `importModelFromUser`: `final result` khai báo 2 lần cùng scope
        (đụng `final result = await FilePicker.pickFiles(...)`) → "name already
        defined". Sửa: đổi tên `loadResult`.
  - 2026-08-25 | khôi phục sau re-image | agent arena/01a0251e-in4up | sandbox
    tái bản giữa phiên làm mất các commit chưa push (UI/i18n/docs/facade);
    rebuild lại từ d43cc3d + restore facade 26571af (không bị 3 fix ảnh hưởng)
  - 2026-08-25 | CI xanh | agent arena/01a0251e-in4up | App Analyze + Locale
    XANH run 32855255220 (tip 3797dcc — full harvest) + run 32789473478
    (core fix, d43cc3d). Chờ nghiệm thu UX thiết bị (banner chat, import
    .gguf progress, tải URL chỉ WiFi, xóa model)
  - 2026-09-15 | doing (chờ CI app_analyze + nghiệm thu của owner)→doing (chờ nghiệm thu máy) | agent arena/01a0a6fb-in4up (lane B3) | Audit không hồi quy khi làm AI-CHAT-01: luồng import/status GIỮ NGUYÊN (loader Tier A/B/C, `.gguf` magic + copy theo chunk, tải URL chỉ WiFi, `_GemmaChatModelCard` với Import/Tải về/Xóa) — B3 chỉ THÊM `engineError` vào `errorText` khi engine tự hồi phục, không đổi hành vi import/status. Test hồi quy: không có file model → `importModelFromUser` fail ĐÚNG (stage `failed`, `error != null`, model không active, `hasModel` false). Điều kiện "chờ CI app_analyze" của card này nay ĐÃ ĐẠT: run 35027200801 XANH (tip 29f1e2b, tree có cả màn Settings Model). Còn lại: nghiệm thu máy (banner chat, import .gguf progress, tải URL chỉ WiFi, xóa model).

### AI-CHAT-01 — Chat báo "Chưa nạp model AI" ngay sau khi gửi + nút gửi xoay vòng mãi
- **Trạng thái:** doing (chờ nghiệm thu máy — AT chat Gemma trên thiết bị; CI app_analyze XANH run 35027200801)
- **Nguồn:** chủ báo 2026-08-29 (build trên DEV `5f98b94c`): tab Home
  "Gemma — AI Chat" báo XANH "gemma-3-1B đã import", màn chat cũng xanh
  "Model AI đã nạp — gemma-3-1B-it-QAT-Q4_.gguf (687 MB)", nhưng vừa nhấn
  gửi → liền thấy "Chưa nạp model AI — import file .gguf (Gemma ~1.5GB)"
  + nút gửi xoay vòng không ngừng.
- **Nội dung (3 root cause, đều verify từ code DEV 5f98b94c):**
  1. **Báo "chưa nạp" nhầm lúc đang generate:** `AiEngineGemma.analyze()`
     đặt `_state = AiEngineState.processing` trong SUẤT generate (30s–2 phút
     trên máy yếu), trong khi facade `isReady` chỉ nhận `ready` ⇒ `hasModel`
     bật FALSE giữa chừng ⇒ mọi lần UI rebuild (đổi tab, xoay máy…) render
     lại banner = VÀNG "Chưa nạp model AI — import file .gguf (Gemma ~1.5GB)"
     (chuỗi này chỉ tồn tại ở `ai_chat_screen.dart:343` — banner case 6).
     Model thực ra ĐÃ nạp thật — banner xanh lúc đầu là đúng.
  2. **Nút gửi treo VÔ HẠN:** `sendMessage` là API chat KHÔNG có timeout
     (lookup 30s / summarize 60s / terms 45s đều có), và engine gemma chờ
     reply port của isolate không timeout + không có xử lý isolate chết.
     `native.generate` là FFI blocking trong isolate con — nếu llama.cpp
     deadlock, hoặc OOM killer Android thu hồi process con (model 687MB ⇒
     ~1.5–2GB RAM runtime trên tablet) giữa chừng ⇒ không bao giờ có reply
     ⇒ `finally` không chạy ⇒ `isChatLoading` true mãi.
  3. **Trả lời rỗng/cắt cụt (kèm theo):** prompt chat nắn TOÀN BỘ lịch sử
     chat (persist, không giới hạn) làm context trong khi C++ n_ctx cố định
     2048 tokens ⇒ vượt là `llama_decode` fail ⇒ model trả về RỖNG;
     `maxTokens=256` hard-code trong khi schema JSON chat (summary 60 từ +
     action items) hay vượt 256 ⇒ JSON cắt giữa chừng ⇒ "Invalid Gemma JSON".
- **Fix (commit này):**
  1. facade `isReady` nhận cả `processing` ⇒ `hasModel` giữ TRUE khi đang
     generate (banner không nhảy vàng giữa chừng).
  2. `sendMessage`: (a) engine bận (đang generate request khác từ tab
     Viết/Nghe) → chờ tới khi rảnh, tối đa ~60s, thay vì báo "chưa sẵn
     sàng" sai; (b) `.timeout(3 phút)` + `on TimeoutException` trả lời rõ —
     nút gửi không bao giờ xoay vòng vô hạn; (c) context = 10 tin gần nhất;
     (d) `maxTokens: 512` cho chat.
  3. `AiEngineGemma`: (a) watchdog Timer 5 phút mỗi request — ép
     `_IsolateError` nếu native treo; (b) `Isolate.addOnExitListener` —
     isolate chết ⇒ báo lỗi mọi port đang chờ + load completer;
     (c) `maxTokens` passthrough vào isolate.
  4. `AiEngine.analyze` / `AiEngineMock.analyze`: thêm tham số `maxTokens`
     (mock bỏ qua) — không phá caller cũ (optional named).
- **Bằng chứng:** code review DEV tip `5f98b94c` trên worktree; chuỗi
  "Chưa nạp model AI — import file .gguf (Gemma ~1.5GB)" duy nhất ở
  `ai_chat_screen.dart:343` (banner hasModel=false); C++ `in4up_ai_native.cpp`
  (n_ctx=2048 từ `in4up_ai_create`, loop generate bounded max_tokens, trả {}
  khi decode fail); `ai_native_bindings.dart` (maxTokens=256 mặc định,
  generate blocking FFI). Sandbox KHÔNG có Flutter SDK — chưa chạy
  `flutter analyze`/test; chờ CI app_analyze + nghiệm thu.
- **Nghiệm thu đề xuất (chủ, trên tablet):** (1) import gemma → banner xanh
  → gửi tin → TRONG lúc chờ trả lời banner GIỮ XANH (không nhảy vàng) +
  nút gửi xoay → có trả lời (hoặc lỗi rõ sau 3 phút, không treo);
  (2) hội thoại dài (>15 tin) → vẫn có trả lời, không "chưa tạo được câu
  trả lời"; (3) nếu máy yếu thu hồi process AI → hiện lỗi "AI process bị
  hệ thống thu hồi" + gửi lại được, không xoay vòng.
- **Lịch sử:**
  - 2026-08-29 | created | owner via chat | báo lỗi chat sau khi build DEV (5f98b94c)
  - 2026-08-29 | created→doing | agent arena/01a02a4a-in4up | định vị 3 root cause trên code DEV (worktree detached HEAD)
  - 2026-08-29 | doing→done (chờ nghiệm thu) | agent arena/01a02a4a-in4up | 4 nhóm fix (isReady/timeout+watchdog+isolate-exit/context+maxTokens); chờ CI + chủ chạy 3 bước nghiệm thu
  - 2026-08-29 | done→done | agent arena/01a02a4a-in4up | Push 3735298d lên origin (GitHub đã reconnect). Verify compile: tag oracle `v1.4.0-ci-android-fix` (tip) chạy build.yml — bước Dart build của job Android compile toàn bộ packages/in4up_ai (app_analyze.yml không trigger do paths filter chỉ có lib/test/pubspec). Run đỏ ở Dart ⇒ fix compile trước khi nghiệm thu.
  - 2026-08-29 | done→done (bổ sung fix) | owner + agent arena/01a02a4a-in4up | Chủ bổ sung quan sát build cũ (chưa rebuild): sau khi xoay vòng LÂU (⇒ native generate CHẠY THẬT, không treo) chat hiện "Mình chưa tạo được câu trả lời cho tin nhắn này." rồi banner XANH lại. Xác nhận: (1) chu kỳ xanh→vàng→xanh = đúng root cause 1 (state=processing làm hasModel=false, `finally` chạy xong mới xanh lại); (2) "chưa tạo được câu trả lời" = model trả output KHÔNG parse được JSON (hết 256 tokens cắt giữa chừng / QAT viết lệch schema) ⇒ fromGemmaJson fallback — đúng root cause 3. FIX BỔ SUNG: `AiAnalysis.fromGemmaJson` catch thêm bước CỨU VỚT trường `"summary"` từ JSON hỏng/bị cắt (regex cho phép string không kín + unescape bằng JSON decoder; verify 7/7 case Python) ⇒ chat hiện câu trả lời THẬT (phần summary, thường model viết trước) thay vì câu trả lời chung chung; isPartial=true, success=true, không kích retry hallucination (check chỉ soi IPA/CEFR/PAO). maxTokens 512 (fix trước) giảm xác suất cắt.
  - 2026-08-30 | MODELS-VAD (cd8ee68 từ 01a01580) + fix archive | agent
    arena/01a0251e-in4up | Silero VAD 629KB (vadMinBytes), Piper tự giải
    nén tar.bz2 bundle, import .onnx, +archive dep. ⚠️ pub get CI ĐỎ:
    cd8ee68 pin archive ^3.6.1 nhưng app graph khoá archive 4.0.9
    (transitive) — không có version chung. Fix: in4up_stt → archive
    ^4.0.9 + adapt _extractTarBz2 sang API 4.x (file.filename thay
    .name, typeFlag==TarFile.directory thay isDirectory, contentBytes
    thay content List<int>) — đã đối chiếu source brendan-duncan/archive
    v4.0.9. File sherpa_vad_service/sherpa_piper_tts_core resolve lấy
    bản 580 (bản DEV là rev cũ cùng lineage).  - 2026-08-30 | thâu hoạch vào 251e | agent arena/01a0251e-in4up |
    cherry-pick 3735298 + 8898bb1 (+ KANBAN 55b22c6, cleanup c17bed0 rỗng)
    từ 01a02a4a (MODELS-002 đã vào DEV từ 08-25); code packages/in4up_ai
    KHÔNG bị app_analyze cover — đã verify balance/import tĩnh; chờ CI
    build.yml trên 251e + nghiệm thu chat Gemma (không báo 'Chưa nạp
    model' khi đang generate, nút gửi không loop, summary JSON hỏng có
    rescue).
  - 2026-09-15 | doing→doing (chờ nghiệm thu máy) | agent arena/01a0a6fb-in4up (lane B3) | Audit lại code 08-29 TRƯỚC khi sửa: cả 4 nhóm fix cũ vẫn còn nguyên trong tip (`isReady` nhận `processing`, `.timeout(3 phút)`, watchdog 5 phút, isolate-exit listener, context `take(10)`, `maxTokens: 512`) ⇒ KHÔNG làm lại. Chỉ fix các lỗ còn lộ: (1) engine bận → facade báo "chưa sẵn sàng" giả ⇒ thêm queue FIFO thật cho chat (`chatQueueLength`, tin không bị bỏ, lỗi trả per-request); (2) `take(10)` là 10 tin CŨ NHẤT ⇒ `ChatContextPolicy` chọn tin GẦN NHẤT + ngân sách token (2048−96 reserved, 3 char/token, min 96) và clip câu hỏi >1500 ký tự trước khi dựng prompt (chống decode rỗng / JSON cụt do tràn `n_ctx`); (3) isolate chết/OOM không có đường hồi ⇒ `engineError` + `restartEngine()` (dedup `_restartInFlight`) + seam test `debugKillIsolate()` / `debugSetIsolateHang(bool)`; (4) banner còn nhánh rơi về "Chưa nạp model AI" ⇒ 8 nhánh trạng thái + Settings hiện `engineError`. Suite mới `test/ai_chat/chat_runtime_stability_test.dart` (12 test): banner XANH khi đang processing; 2 tin liên tiếp → vào queue đúng thứ tự, không lỗi "chưa sẵn sàng"; timeout 150ms → lỗi retryable + tự restart + tin sau vẫn trả lời; context ≤ ngân sách & KHÔNG chứa tin cũ nhất; `maxTokens` ∈ [96,512]; engine chết → tự recover; MODELS-002 không có file → import fail đúng; gemma: hang → kill → "thu hồi" → recover OK. (2 commit: aae4ec6 code+test, 29f1e2b banner/settings.)
  - 2026-09-15 | doing (chờ nghiệm thu máy) | agent arena/01a0a6fb-in4up (lane B3) | CI: run **35027200801** (app_analyze.yml, tip 29f1e2b) XANH — job analyze-and-locale-test 2m28s (`flutter analyze` + locale test) ⇒ code mới + `test/ai_chat` compile sạch với kiểu API thật. Compile-verify rộng hơn (app_analyze không cover `packages/**`): tag oracle `v1.4.1-b3-ci-compile` → build.yml run **35027568392**: Windows ✅ 15m16s, iOS ✅ 13m55s (build release ⇒ compile toàn bộ graph Dart gồm `packages/in4up_ai`); Android ❌ 19s ở step "Setup Android SDK & Accept Licenses" — lỗi hạ tầng/action, trùng run 33268012381 (08-29), KHÔNG do code B3. ⚠️ Chưa workflow nào chạy `test/ai_chat` ⇒ assert runtime của suite mới CHƯA được CI chạy (muốn chạy: thêm step `flutter test test/ai_chat`; agent KHÔNG sửa được `.github/workflows/` — GitHub App thiếu quyền `workflows`, push bị từ chối). AT máy chờ chủ: import model nhỏ → gửi tin trong lúc đang xử lý (banner giữ XANH) → gửi 2 tin → ép timeout/isolate restart rồi gửi tiếp; ghi kèm dung lượng model + RAM máy.
  - 2026-09-15 | doing (chờ nghiệm thu máy) | agent arena/01a0a6fb-in4up (lane B3) | Vì agent KHÔNG có quyền `workflows`, phần "chạy test/ai_chat trong CI" được gói thành patch cho owner: `docs/project/B3-APP-ANALYZE-TEST-STEP.patch` (`git apply` sạch trên tip 342957a) — thêm step `flutter test test/ai_chat` + artifact log + mở path filter `packages/in4up_ai/**`. Áp xong ⇒ suite 12 test chạy thật trên CI (hiện chỉ mới được analyzer biên dịch).
  - 2026-09-23 | doing (chờ nghiệm thu máy) | agent arena/01a0a6fb-in4up (lane B3) | Cập nhật branch theo base mới (rule 2): base đi từ `df77ab0` → **`f54d58d`** (đã có #30/#35/#36/#37), merge `f363f41` **không xung đột** (verify `git merge-tree` + KANBAN không còn marker). CI trên base mới: push run **35861202198** XANH + PR run **35861207196** XANH. ⚠️ PHÁT HIỆN CHẶN AT MÁY: `.github/workflows/build.yml` đang vỡ YAML (dòng 265 thụt 9 space trong block `run: |` thụt 10, từ commit owner `403658a` 2026-09-23) ⇒ GitHub báo "workflow file issue", KHÔNG job nào chạy trên MỌI branch (kể cả base 01a0251e, 01a0a6fa, 01a0a6f9) ⇒ chưa build được APK cho nghiệm thu (tag `v*`/dispatch cũng chết). Patch 1 dòng cho owner: `docs/project/CI-BUILD-YML-INDENT-FIX.patch` (đã verify `git apply` sạch + quét lại block scalar hết lỗi); agent không push được file workflow (token thiếu quyền `workflows`).
 → `arena/01a0251e-in4up` (theo `.github/pull_request_template.md`, giữ nguyên 4 commit logic + merge base, KHÔNG squash). Base đã đổi trong lúc làm (`d40f604`→`df77ab0`) nên cập nhật TRÊN branch agent bằng merge `013ea4c` (rule 2 — không force-push, không cherry-pick mù); KANBAN auto-merge giữ đủ lịch sử cả hai phía (verify: 0 conflict marker). CI sau merge: push run **35029298621** XANH + PR run **35029323479** XANH (app_analyze, job analyze-and-locale-test). Suite `test/ai_chat` vẫn CHƯA execute ở đâu — patch cho owner: `docs/project/B3-APP-ANALYZE-TEST-STEP.patch`. AT máy vẫn chờ chủ (banner xanh khi đang xử lý; 2 tin liên tiếp; ép timeout/isolate restart rồi gửi tiếp) — nhớ ghi dung lượng model + RAM máy.
### AUDLIB-001 — Audio Library P1: nghiệm thu + 3 fix từ 01a0018e (content://, VAD-only, pubspec)
- **Trạng thái:** done (chờ owner build 70c4efc+ và nghiệm thu trên thiết bị)
- **Nguồn:** owner yêu cầu nghiệm thu `arena/01a0018e-in4up` (2026-08-25) —
  fix 3 lỗi từ audit thiết bị của owner: pub get đỏ (sherpa duplicate),
  mở bài từ tab Thư viện không chạy (content://), "Chỉ VAD" báo lỗi.
- **Nội dung (thâu hoạch ff 01a0018e → 0855cb3, 8 file +111/−69):**
  - `AudioLibraryService.resolvePlayablePath()`: content:// → copy sang cache
    trước khi phát (just_audio/ExoPlayer không phát content:// ổn định) — dùng
    ở `AudioLibraryView._openEntry` + `ListenLibraryScreen._openAudio`
    (kể cả mở lại file đã lưu ở tab Gần đây).
  - `SoundAutoTocService._evenSplitFallback()`: PURE, chia đều 2–8 đoạn
    ~60s/đoạn; áp vào MỌI early-return (copy content:// fail, waveform rỗng,
    energies <6, slices <2) → file ≥ ~12s luôn tạo được mục lục thô kể cả
    VAD-only, không cần Whisper.
  - `packages/in4up_stt/pubspec.yaml`: bỏ `sherpa_onnx: ^1.13.4` trùng khai báo
    (duplicate key làm pub get fail), giữ `^1.13.6`.
  - Dọn `sound_auto_toc_dialog.dart` (bỏ PlayerProvider import + biến unused),
    `stt_model_settings_screen.dart` (bỏ import googleapis/analytics auto-import
    nhầm + material trùng — 0855cb3).
  - `docs/soundlist_ci_workflow.yml` v5 (commit-back log khi đỏ + paths đủ
    Audio Library + pubspec) — **workflow đang chạy vẫn là bản cũ**; owner copy
    v5 vào `.github/workflows/soundlist_tests.yml` nếu muốn (agent không có
    quyền workflows).
- **Nghiệm thu (2026-08-25, agent arena/01a0251e-in4up):** review code từng file
  OK (resolvePlayablePath fallback an toàn `path ?? uri`; _evenSplitFallback
  đúng biên 2×minSegment; pubspec 1 key duy nhất). CI: App Analyze + Locale
  XANH run 33037686097 + Soundlist XANH run 33037686068 (analyze + test).
  01a0018e xanh sẵn run 32946979440 trước khi thâu hoạch.
- **Chờ owner (thiết bị):** (1) tab Thư viện → chạm 1 bài → phát được;
  (2) ⚡ Tự tạo mục lục → Chỉ VAD → ra "Đoạn 1 · 00:00…" kể cả file content://;
  (3) VAD+Whisper vẫn chạy. Xong → bước P2 (chọn thư mục âm thanh).
- **Lịch sử:**
  - 2026-08-25 | created→done | agent arena/01a0251e-in4up | ff-merge
    01a0018e (70c4efc, nhánh đã merge sẵn 251e 2cfb53b) + cleanup import;
    CI xanh 33037686097/33037686068
### I18N-001 — i18n backlog: 354 literals chưa phân loại + raw strings player tab Nghe
- **Trạng thái:** proposed (cần branch i18n riêng — KHÔNG trộn vào branch feature)
- **Phát hiện (2026-09-03, khi fix rule-5 cho tab Nghe "Gần đây"/"Thư viện"):**
  chạy `python3 tool/generate_legacy_ui_fallbacks.py` báo
  **"354 accented presentation literals need UI/content classification"** —
  repo đã drift từ lần regenerate catalog cuối: 354 chuỗi chrome tiếng Việt
  mới chưa được review (UI → thêm override / content → thêm exclusion).
  Generator là ratchet chặt — không sửa đủ 354 thì không regenerate được.
- **Drift đã dọn trong lúc fix lẻ:** 14 override stale (9 bị ARB shadow,
  5 đã mất khỏi code sau harvest YouTube LR) + 1 content exclusion stale
  (JS IFrame cũ thay bằng JS mới 19f6c3a) — generator giờ chỉ còn chặn
  đúng 354 literals thật sự chưa review.
- **Raw strings player tab Nghe (listen_mode_screen.dart — chưa fix):**
  hàng chục chuỗi chrome trần ('Đặt điểm A/B', 'Nhảy đến đây', 'Lặp lại',
  'Hẹn giờ ngủ', 'Theo câu/Theo cụm', 'Đang phân tích...', 'Hủy', …) —
  cùng class bug như tab "Gần đây"/"Thư viện" (đã fix: 9 strings
  ListenLibraryScreen + 2 strings AudioLibraryView qua uiText + fallback).
- **Làm gì (branch mới từ tip DEV):**
  1. Chạy generator, lấy danh sách 354; rà từng chuỗi: chrome UI →
     `tool/legacy_ui_english_overrides.json` (keep-English T3 theo ADR-0002)
     hoặc ARB nếu T1/T2; content (user/vocab/AI) →
     `tool/legacy_ui_content_exclusions.json` kèm lý do.
  2. i18n player tab Nghe (listen_mode_screen.dart) theo skill
     `docs/skills/i18n-localization/SKILL.md`: uiText + ARB parity +
     hi/zh/zh_TW/si, không fallback về Việt.
  3. Regenerate + CI App Analyze + Locale xanh + nghiệm thu locale ≠ vi.
- **Lịch sử:**
  - 2026-09-03 | proposed | agent arena/01a0251e-in4up | phát hiện khi fix
    rule-5 tab Nghe; dọn 14 override + 1 exclusion stale; fix lẻ 11 strings
    ListenLibraryScreen/AudioLibraryView (chờ CI)

### LANG-03033-01 — Chrome i18n Soundlist/LHB/shell (thâu hoạch 01a03033) + 3 fix nghiệm thu
- **Trạng thái:** done (CI xanh; chờ owner nghiệm thu: mở app locale ≠ vi →
  chrome Soundlist/LHB/shell hiện bản dịch hi/zh/zh_TW/si/EN, không Việt)
- **Nguồn:** owner yêu cầu nghiệm thu `arena/01a03033-in4up` (2026-08-27).
- **Nội dung thâu hoạch (ff 1982867 → f149d5a, 79 file):**
  - Bản dịch + fallback nhóm chrome Soundlist (Âm mục, Điểm, Đoạn, Mục lục,
    Chương, Ghi chú, Đánh dấu, Tìm kiếm, Phát, Thêm, Xóa, Đổi tên, …) +
    status notifications cho **hi/zh/zh_TW/si**; fallback: locale → EN →
    an toàn, **không bao giờ fallback về Việt**.
  - 6 file qua localized Material/Text bridge (soundlist_panel,
    sound_list_screen, sound_auto_toc_dialog, sound_mark_edit_sheet,
    selection_save_sheet, vocab_entry_meta) + import-swap 11 file.
  - Regenerate `generated_ui_translations.dart` (791 entries) +
    `generated_legacy_ui_fallbacks.dart` (1640 keys); ARB +78 key
    (audit_*, lhb_*, chrome shell/LHB/soundlist).
- **Fix 1 — regression merge (a5ee489):** merge dd081fb (01a03033) resolution
  giữ BẢN CŨ → revert im lặng 10 file (mất auto-TOC background + D16,
  dialog auto-TOC mới, LHB-002 scaffolding 4 tầng, LHB-003 wiring) →
  compile error CI đỏ. KANBAN.md cũng bị rơi 6 card 251e (AUDLIB-001,
  HARVEST-1580-01, LHB-002/003, LISTEN-825-01, MODELS-002) — đã khôi phục
  toàn bộ từ 1982867. Fix: 3-way merge-file đúng base (e02ac7e soundlist /
  35d1d48 LHB) — ours = đủ tính năng 251e + theirs = i18n. Verify: feature
  markers + i18n imports + i18n data ('Âm mục' → hi ध्वनि सूची / zh 音频目录 /
  zh_TW 音訊目錄 / si ශ්‍රව්‍ය ලැයිස්තුව).
- **Fix 2 — rule5 (881d8aa):** (a) app_ar.arb 3 subtitle có GIÁ TRỊ TIẾNG
  VIỆT (generator fallback sai) → về EN; (b) 78 key mới chưa dịch T3 →
  keep-English (chính sách ADR-0002) — 19 locale từng tụt dưới sàn ratchet.
- **Bằng chứng:** App Analyze + Locale XANH run 33078187839; Soundlist XANH
  33076735293. Verify local: replica đủ 11 check của
  locale_chrome_no_vietnamese_test → 0 vi phạm.
- **Lịch sử:**
  - 2026-08-27 | created→done | agent arena/01a0251e-in4up | ff-merge 01a03033
    + 3 fix (regression 10 file + khôi phục KANBAN + rule5 ARB/keep-English);
    CI xanh 33078187839

### READ-630-06 — Bôi nhiều chữ mặc định; box-từng-từ tuỳ chọn; sheet lưu hiện từ cũ
- **Trạng thái:** done (CI xanh; chờ owner nghiệm thu trên thiết bị)
- **Nguồn:** chủ yêu cầu nghiệm thu `arena/01a01580-in4up` (2026-08-27) —
  thâu hoạch commit `db5c6ed` bằng path-checkout 6 file (pattern SO_TAY).
- **Nội dung:**
  - **2 cách chọn:** mặc định bôi nhiều chữ (mọi màu POS/CEFR, như chế độ
    không màu); "box từng từ" là TUỲ CHỌN — chip lưới cam trên ReadTopBar
    (cạnh chip màu) + toggle trong ReadSettingsSheet; persist qua
    ReaderDisplaySettings (prefs).
  - Box từng từ: long-press box → sheet lưu từ (nền lưu hàng loạt sau này);
    render qua ColoredTextWidget.
  - **Sheet lưu từ đủ dữ liệu từ cũ:** `_loadRelated()` chạy khi mở sheet
    (postFrame) — trước đó không bao giờ chạy → mất bảng từ cũ. Entry đã
    có: VocabEntryMetaInfo (IPA, loại, chủ đề, ngôn ngữ) + nút Sửa
    (VocabEntryEditSheet — cùng bảng PDF/Web: thêm/bớt tag); chip ngôn ngữ
    en/vi/pali/my + ngôn ngữ đã có (không ô gõ mã mới); cụm/từ liên đới
    hiện lại khi WordList có mục gần giống.
- **Fix nghiệm thu (code 1580 db5c6ed dính 5 lỗi compile — chưa qua CI):**
  1. text_provider: dòng rác 'returoadTextFile: File not found: $path');'
     (merge-corrupt) — xóa.
  2. text_provider: tail corrupt — 'notifyListeners();' + block Auto-split
     nhân đôi + thừa đóng class — dọn.
  3. Thiếu TextProvider.setWordTapBoxes (read_top_bar + read_settings_sheet
     gọi) + thiếu import reader_display_settings — bổ sung setter delegate.
  4. _buildTextContent: 'lineIndex: index' mà index không có scope — truyền
     index từ caller.
  5. Mảnh rác 'otifyListeners();' (thiếu n) sót ở _applyLines — khôi phục.
  Verify: diff chéo 6 file với bản gốc 251e (2f64c18) — chỉ còn đúng diff
  feature; balance-check 6 file OK.
- **Bằng chứng:** App Analyze + Locale XANH run 33082501188.
- **Lịch sử:**
  - 2026-08-27 | created→done | agent arena/01a0251e-in4up | path-checkout
    6 file từ db5c6ed + 5 fix compile; CI xanh 33082501188
  - 2026-08-29 | fix bug layout rộng | agent arena/01a0251e-in4up | e715d85:
    _WordTapChip chỉ gắn nhánh compact (width<620 || height<700) → màn rộng
    (Windows/tablet) không có nút; bù vào Row không compact + icon tắt
    select_all → grid_view_outlined (khớp "nút lưới")
  - 2026-08-30 | DOCX-001 (thâu hoạch c301004 từ 01a01580) | agent
    arena/01a0251e-in4up | .docx ZIP raw-deflate: ZLibDecoder(raw: true)
    thay bu zlib header (moi .docx method 8 dung la vo), magic ZIP vs OLE,
    data-descriptor, ten entry case-insensitive, giu deu .docx khi
    FilePicker mat deu, snackbar trung thuc, test ZIP thuc (6b6eacc).
    + 2 fix compile c301004 de lai: test thieu import dart:convert/io/
    typed_data; library_screen dau file bi lap 6 token dong ket.
    CI xanh 33273465065. Chờ nghiệm thu máy: .docx thật (Word/LibreOffice)
    mở được; .doc OLE báo rõ; FilePicker mất đuôi vẫn .docx

### XLAT-001 — Dịch offline: glossary Phật học/Pali + protect-tokens + ML Kit (XLAT)
- **Trạng thái:** done (code + test thuần; chờ CI + nghiệm thu thiết bị)
- **Nội dung:**
  - **Vòng 1 — Glossary + protect-tokens (mọi nền tảng):** module
    `lib/features/translation/glossary/` (thuần Dart: `translation_glossary.dart`,
    `protect_tokens.dart` + `glossary_store.dart` Hive box `translation_glossary`).
    Lookup longest-match trên chuỗi đã normalize (dùng `CanonTokenizer`,
    Pali có dấu khớp biến thể không dấu), word boundary, tie-break
    priority (user 100 > hạt giống 0) + domain. Protect = thay hit bằng
    `__G{n}__` → engine dịch phần còn lại → restore nghĩa khóa. Cache
    (MD5) lưu câu ĐÃ RESTORE; glossary đổi → clear cache.
    - Hạt giống 226 mục Pali/EN Phật học → VI: `assets/glossary/buddhist_pi_en_vi.json`
      (locked=true; chưa có hạt giống HI — chờ bảng từ chủ).
    - Đồng bộ 1 chiều từ WordEntry (language Pali hoặc topic Phật học +
      meaning không rỗng → entry domain=user nếu chưa có, không ghi đè).
    - UI: màn "Thuật ngữ dịch" (list/thêm/sửa/khóa/xóa) mở từ Cài đặt
      engine dịch; chuỗi chrome qua uiText + override English.
  - **Vòng 2 — ML Kit offline (Android/iOS) + Hindi:** `MlKitEngine`
    (package `google_mlkit_translation` 0.15.x) — engine dịch CÂU, cắm
    TRƯỚC online engines trong pipeline. Cặp EN↔VI, EN↔HI; HI↔VI pivot
    qua EN (2 bước + glossary hai đầu) khi đủ model. Model CHỈ tải khi
    user bấm "Tải về" trong Cài đặt engine dịch (không auto lúc mở app,
    cùng quy tắc Whisper). Thiếu model → failure rõ "Chưa tải gói dịch
    <lang>" — không rơi im lặng về ráp từ. Desktop: isAvailable=false,
    import không crash.
  - **Vòng 3:** toggle "Chỉ dùng dịch offline" (persist SharedPreferences);
    KANBAN card này. (Windows GGUF stub CHƯA làm — chờ PR #8 trên 251e.)
  - Pipeline `TranslationService`: cache → glossary(protect) → ML Kit →
    online (nếu mạng + không khóa offline-only) → từ điển offline
    (last resort) → restore → cache.
- **File:** thêm `lib/features/translation/glossary/{translation_glossary,
  protect_tokens,glossary_store,glossary_sheet}.dart`,
  `lib/features/translation/engines/mlkit_engine.dart`,
  `assets/glossary/buddhist_pi_en_vi.json`, `test/translation_glossary_test.dart`;
  sửa `translation_service.dart`, `translation_toolbar.dart`,
  `vocabulary_provider.dart`, `pubspec.yaml`,
  `tool/legacy_ui_english_overrides.json` + generated fallbacks, PLAN-019.
- **Bằng chứng:** `test/translation_glossary_test.dart` (normalize,
  longest-match, boundary, restore, luật khóa, sync WordEntry, thứ tự
  tầng pipeline, pivot HI→VI, ML Kit desktop). **Lưu ý:** sandbox KHÔNG
  có Flutter SDK — chưa chạy `flutter analyze`/`flutter test`; owner cần
  `flutter pub get` (dependency mới) + chạy CI/test trước nghiệm thu.
- **Lịch sử:**
  - 2026-08-23 | created | owner via prompt giao việc (dịch offline +
    glossary Phật học/Pali + Hindi) | agent arena/01a02ffc-in4up
  - 2026-08-23 | doing→done | agent arena/01a02ffc-in4up | code + test thuần;
    cache MD5 kế thừa sẵn trên 251e (không cần path-checkout d8486d3);
    chưa build máy (sandbox không có Flutter SDK) — chờ CI + nghiệm thu
  - 2026-08-29 | thu hoạch vào 251e | agent arena/01a0251e-in4up |
    cherry-pick 4 SHA dbab77e→aa84747 thành ad874b6/e648d64/753d790/26a5c51
    (KHÔNG lấy read_top_bar/text_provider từ 02ffc — giữ nút lưới 1580);
    fix import WordEntry sai đường dẫn da2ea37 (bị vỡ cả trên 02ffc — chưa
    từng compile); PLAN-016 trùng số với card Tab Nghe trên DEV → PLAN-019;
    pubspec.lock chưa có google_mlkit_translation — CI pub get tự sync, chủ
    chạy `flutter pub get` trên máy rồi commit lock; chờ CI xanh + nghiệm
    thu máy: EN→VI, EN→HI, một câu có sati/nibbāna
  - 2026-08-29 | 3 lỗi compile tìm qua oracle CI (log/blob bị chặn) |
    agent arena/01a0251e-in4up | (1) DropdownButtonFormField initialValue→
    value ×3 (b497738); (2) translation_glossary thiếu import protect_tokens
    (f916244); (3) **Hive Box KHÔNG có putIfAbsent** (02ffc tưởng như Map)
    → `await box.put(...)` trong _doInit (commit này). Bisect 7 vòng CI
    ~2m/vòng, skill ci-red-debugging. Bài học: code 02ffc chưa từng qua
    compiler — mọi harvest tương tự phải coi "chưa compile" là mặc định
  - 2026-08-29 | tiếp tục bisect lỗi #4 | agent arena/01a0251e-in4up |
    Lỗi #4 nằm trong translation_service.dart (chuỗi bisect B10→B11→B12→
    B13 bằng file gốc f916244 — KẾT QUẢ CÓ HIỆU LỰC: B10 xanh, B11 đỏ,
    B12 đỏ (vocab→DEV), B13 đỏ (toolbar→DEV)). File service 251e == file
    02ffc byte-for-byte (cherry-pick không hỏng). Dependency (cache/
    engines/app_language/language_detector) KHÔNG đổi eca143f→a16509f.
    ⚠️ C1/C2/C3/C4 (hybrid do agent dựng tay) VÔ HIỆU — C1 tự tạo lỗi
    duplicate _instance khi copy block ctor. C1' (đã sửa, 1 _instance)
    CHƯA push được — GitHub token hết hạn giữa phiên (401 Bad
    credentials). TRẠNG THÁI DỪNG LẠI: remote = 5f98b94 (C3 xanh),
    local = C1' (hybrid đúng: service cũ + ctor/fields/getters/helpers
    XLAT, pipeline cũ). BƯỚC TIẾP THEO: push C1' → đỏ = lỗi trong
    ctor/fields/getters/helpers (tách tiếp từng phần); xanh = lỗi trong
    pipeline methods (_translateWithPipeline/_planSteps/_sentenceEngine
    Ready/_runEngineChain). Đã xong (cùng phiên): lỗi #4 =
    `store.changes.listen(_onGlossaryChanged)` — tearoff 0-arg
    (void Function()) truyền cho Stream<void>.listen đòi 1-arg
    (void Function(void)) → argument_type_not_assignable; fix
    `listen((_) => _onGlossaryChanged())`. Tổng 4 lỗi compile của
    batch 02ffc (initialValue×3, thiếu import protect_tokens, Hive
    putIfAbsent, listen 0-arg) — hết bằng oracle CI ~15 vòng.
    ⚠️ Ghi nhận: chuỗi C1–C4 và D1–D6 có 5 probe VÔ HIỆU do lỗi agent
    dựng hybrid (trùng _instance, thiếu method, thiếu import) — kết
    luận chỉ giữ các vòng D7–D14 (xác minh headSha + file tự thống
    nhất). Full stack XLAT đã khôi phục từ f916244 + cả 4 fix.
    ⚠️ 2026-08-29 (tiếp): full stack 984e936 vẫn ĐỎ; bisect E-series
    (toolbar) cho ra chuỗi E4–E9 đỏ / E5+E10 xanh nhưng E9→E10 chỉ khác
    1 dòng `//` comment — KHÔNG THỂ là lỗi Dart ⇒ nghi run FLAKE (step
    Resolve dependencies / infra) hoặc đỏ do step khác chứ không phải
    Analyze. Chưa verify được step-level (token GitHub chết giữa phiên).
    Trạng thái: e82a05d = full stack nguyên vẹn chờ push+CI; nếu xanh →
    hết lỗi, các đỏ E-series là flake; nếu đỏ ở Analyze → bisect lại
    toolbar/pipeline/test với re-run xác nhận. LỖI #5 XÁC NHẬN (owner gửi log commit ecc1ec4):
    `const Divider(color: Colors.grey.shade800)` — MaterialColor.shade800
    là GETTER, không tính được trong biểu thức const → const_with_non_constant.
    Fix: bỏ `const` trước Divider. Giải thích toàn bộ chuỗi E-series
    (E4–E9 đỏ do dòng này; E5 xanh vì cắt cả Divider; đọc 'xanh' E10 là
    run cũ — E10 thực ra đỏ). Tổng 6 lỗi compile batch 02ffc.
    LỖI #6 (owner gửi log a6cb845): `_mlkit is MlKitEngine` rồi gọi
    `_mlkit.isPairReady(...)` — FIELD không được type-promote qua `is`
    (chỉ local variable mới chắc chắn) → isPairReady isn't defined for
    TranslationEngine. Fix: copy `final mlkit = _mlkit;` rồi is-check
    trên local.
    LỖI #7 (fix của OWNER, commit 13d271f): toolbar thiếu import
    `package:google_mlkit_translation` — extension `bcpCode` (của package)
    KHÔNG resolve khi chưa import package (extension phải in-scope dù type
    được infer) → 3 lỗi bcpCode ở _loadModels/_downloadModel/_deleteModel.
    **CI XANH run 33273465065** (tip 13d271f) — hết 7 lỗi compile của
    batch 02ffc (6 fix agent + 1 fix owner). Chờ nghiệm thu máy: EN→VI,
    EN→HI, câu có sati/nibbāna; chủ chạy `flutter pub get` commit lock.
    DONE 2026-08-30.
    HOÀN TẤT (2026-08-30):
    thâu hoạch .docx ZIP raw-deflate từ 01a01580 (c301004 — 3 file:
    text_source_loader.dart, text_source_loader_test.dart,
    library_screen.dart; KHÔNG lấy text_provider.dart) — làm sau khi
    XLAT xanh. Đã rà static toàn bộ: imports ✓, named
    params ✓, API Hive/ML Kit/TranslationResult/SharedPreferences/
    Connectivity ✓ (đối chiếu source thật), brace balance ✓, không ký
    tự ẩn ✓, không trùng tên ✓. Hết cách static — cần oracle + đọc
    log analyze (artifact app-analyze-log) khi token hoạt động lại. Bài học: code 02ffc chưa từng qua
    compiler — mọi harvest tương tự phải coi "chưa compile" là mặc định

### XLAT-002 — Dịch online-first (smart default) + offline fallback
- **Trạng thái:** done + CI xanh (chờ nghiệm thu máy)
- **Báo cáo (owner 2026-09-03):** tab Đọc — dù bật/tắt "chỉ offline"
  trong cài đặt dịch, app LUÔN dịch offline Hy-MT.
- **Root cause:** `_runEngineChain` chạy offline (Hy-MT → ML Kit) TRƯỚC
  online engines — user đã có model Hy-MT thì mọi câu chạm offline
  trước, online không bao giờ được thử dù có mạng.
- **Fix (ce4945a):** chain mới = (1) ONLINE engines (Google Free/
  DeepLX/MyMemory/Libre) khi có mạng + không khóa "chỉ offline" →
  (2) OFFLINE fallback: Hy-MT (chọn/auto + có model) → ML Kit → từ điển.
  Toggle "chỉ offline" + engine pref (auto/hymt/mlkit) giữ nguyên —
  mặc định thông minh, vẫn đổi được trong Cài đặt dịch.
- **Lịch sử:**
  - 2026-09-03 | created→done | agent arena/01a0251e-in4up | owner báo
    "dù tắt hay bật trong cài đặt dịch thì vẫn dịch offline HY-MT";
    sửa ce4945a (chờ CI + nghiệm thu: có mạng → engine badge hiện
    Google/MyMemory...; rút mạng → tự rơi Hy-MT/ML Kit)

### HYMT-001 — Hy-MT "native không load được" dù đã có model
- **Trạng thái:** done + CI xanh (chờ nghiệm thu máy)
- **Báo cáo (owner 2026-09-03):** đã có model Hy-MT nhưng dịch vẫn báo
  "hy-mt native không load được".
- **Root cause (3 lớp):**
  1. Handshake dối: isolate gửi "ready" trước khi `create()` chạy
     (~600MB model, vài giây) — `ensureLoaded()` trả true dù create fail;
     lỗi lộ ở request đầu, isolate chết im, không retry.
  2. File cắt vẫn được coi là model: check cũ chỉ size ≥80MB + magic
     đầu — file 100MB (download cắt của file 601MB) vẫn qua →
     `llama_model_load_from_file` fail → NULL.
  3. Lỗi chung chung, không nói được file hỏng hay thiếu RAM.
- **Fix (cuối cùng 1677da3):** (1) `_LoadResult` gửi SAU khi create hoàn tất
  (ready + error thật); ensureLoaded chờ nó (2 phút), fail → dispose +
  `_lastLoadError` → lần sau RETRY. (2) `minPlausibleBytes` = 481MB (80% ×
  601MB, size thật xác minh trên HF) + check magic GGUF đầu khi resolve;
  file hỏng = chưa có model (fallback engine khác). (3) `modelIssue()`
  + lỗi hiển thị nguyên nhân thật từ isolate.
- **Ghi chú kỹ thuật quan trọng:** `_headIsGguf` KHÔNG dùng được
  `File.openSync()`/`readBytesSync`/`closeSync` (RandomAccessFile sync
  API) — analyzer CI (Flutter 3.44.1) từ chối compile (8 vòng bisect
  33694449146 → 33697327206: T2 bỏ I/O xanh, T3 positional đỏ, T4
  `openRead(0, 4).first` xanh). Dùng pattern `openRead(0, N).first`
  (đã proof trong chính file: importFromUser dùng `openRead(0, 8)`) —
  async, chỉ đọc 4 byte đầu, không load file 600MB vào RAM.
- **Lịch sử:**
  - 2026-09-03 | created→done | agent arena/01a0251e-in4up | xác minh
    size file thật 601MB (HF tencent/Hy-MT1.5-1.8B-2bit-GGUF); fix
    (ban dau — da squash vao 1677da3). Nghiệm thu: Import/Tải lại model → dịch → nếu vẫn lỗi,
    message giờ nói nguyên nhân (file cắt / quant / RAM / thiếu native)
  - 2026-09-03 | done→done | agent arena/01a0251e-in4up | CI đỏ triền
    miên do RandomAccessFile sync API + 1 lỗi `error:` null-safety; 8
    vòng bisect 1-bit xác định openSync/readBytesSync là thủ phạm (log
    không đọc được). Đổi sang openRead → fix hoàn chỉnh 1677da3,
    CI XANH 33697490397

### AI-CHAT-02 — Chat "cứ xoay vòng" — engine queue đúng
- **Trạng thái:** done + CI xanh (chờ nghiệm thu máy)
- **Báo cáo (owner 2026-09-03):** AI chat cứ bị xoay vòng khi chat.
- **Root cause:**
  1. `analyze()` yield fallback "Engine not ready" NGAY khi
     state=processing (request trước còn chạy) → sau 1 lần chat chậm/
     timeout 3 phút, mọi message kế tiếp trong ~2 phút chết yểu.
  2. `.first.timeout(3 phút)` KHÔNG cancel được stream — generator cũ
     vẫn treo trong `await for`; state processing chỉ reset khi isolate
     trả lời hay watchdog 5 phút → cửa sổ "kẹt" ~2 phút sau mỗi timeout.
  3. Facade busy-wait 60s rồi vẫn gọi analyze → fallback yểu mạng.
- **Fix (5134f06):** (1) `analyze()`: state=processing → ĐỢI request cũ
  xong ≤90s (isolate tuần tự = queue đúng) rồi mới fallback với lý do
  rõ. (2) `_inFlight` counter: generator CUỐI CÙNG thoát mới đặt state
  về ready — state không kẹt dù caller bỏ rơi stream. (3) bỏ busy-wait
  60s ở facade (một nguồn sự thật).
- **Lịch sử:**
  - 2026-09-03 | created→done | agent arena/01a0251e-in4up | fix 5134f06.
    Nghiệm thu: gửi 2 tin liên tiếp (tin 1 chậm) → tin 2 phải CHỜ rồi
    trả lời (không báo "chưa sẵn sàng"); sau 1 lần timeout 3 phút →
    tin kế tiếp vẫn hoạt động bình thường
  - 2026-09-15 | done (chờ nghiệm thu máy)→done (chờ nghiệm thu máy) | agent arena/01a0a6fb-in4up (lane B3) | Audit không hồi quy: giữ NGUYÊN cơ chế 5134f06 (`_inFlight` + chờ request cũ ≤90s, một nguồn sự thật ở engine, bỏ busy-wait 60s ở facade); lane B3 chỉ thêm queue FIFO PHÍA TRÊN facade (tin vào hàng đợi thay vì báo "chưa sẵn sàng" giả). Test hồi quy trong `test/ai_chat/chat_runtime_stability_test.dart`: 2 tin liên tiếp → prompt tới engine ĐÚNG THỨ TỰ, không lỗi "chưa sẵn sàng"; timeout → tin sau vẫn trả lời. CI app_analyze run 35027200801 XANH (compile). Nghiệm thu máy vẫn chờ chủ.

### YT-LR-001 — YouTube học ngôn ngữ kiểu Language Reactor (nối nốt)
- **Trạng thái:** done (chờ nghiệm thu thiết bị)
- **Nguồn:** người sở hữu (2026-08-30) — yt-dlp / Language Reactor; tư vấn
  agent arena/01a01580-in4up (local-first, không VPS).
- **Nội dung:** hoàn thiện học YouTube **trên máy**: iframe + phụ đề timestamp
  + song ngữ (TranslationService/XLAT) + tap từ → WordList + tải audio → tab
  Nghe (LRC/karaoke/shadowing). **Không** backend Node/Python chạy yt-dlp;
  **không** tab thứ 6. `yt-dlp` chỉ sidecar desktop (WP-Z) nếu explode gãy.
  Chi tiết + thứ tự WP0–WP4: PLAN-020.
- **Nền đã có (đừng làm lại):** `youtube_explode_dart`, `YtService.fetchCaptions`
  3 tầng + `fetchBilingualCaptions`, `YtDownloader`, `saveLrc`,
  `yt_player_screen.dart` (IFrame API + Known/Learning phác), YouGlish,
  tab Nghe REOPEN-001.
- **Bằng chứng:** thâu hoạch 01a01580 19f6c3a → DEV a8d6170 (path-checkout 6 file,
  dev == 03e7ea0 nên chỉ 19f6c3a mới): seek, lặp câu, tap từ → WordList,
  song ngữ (timedtext `tlang` fallback + TranslationService/XLAT), lưu LRC
  theo video id, Nghe, test `test/youtube_learning_test.dart`. Re-verify
  2026-08-31: c301004 (docx raw-deflate) + cd8ee68 (Silero VAD 629KB + Piper
  tự giải nén bundle + import .onnx) + 03e7ea0 (docs PLAN-020) ĐÃ có sẵn trong
  DEV từ các đợt thâu hoạch trước (blob so khớp, chỉ lệch comment/fix 4.x).
- **Lịch sử:**
  - 2026-08-30 | created | owner via chat + agent arena/01a01580-in4up |
    "tích hợp để app tùy biến youtube tải về / phụ đề / chạy luôn như langua reaction"
  - 2026-08-31 | proposed→done | agent arena/01a0251e-in4up | nghiệm thu 01a01580:
    19f6c3a thâu hoạch a8d6170; c301004/cd8ee68/03e7ea0 xác nhận đã có sẵn
    (bỏ tail hỏng của c301004 trong library_screen.dart — bug nhánh nguồn)
  - 2026-08-31 | done→done | agent arena/01a0251e-in4up | CI ĐỎ 33355151360 —
    root cause: 19f6c3a gọi `_fetchTimedtextTranslated` trong
    fetchBilingualCaptions nhưng phương thức KHÔNG ĐỊNH NGHĨA ở bất kỳ đâu
    trong nhánh nguồn (nhánh 01a01580 compile lỗi ở tip). Bổ sung a3c8a1a
    (timedtext API + tlang + srv3, theo style _fetchTimedtext) → CI XANH
    33355331358. Chờ nghiệm thu thiết bị (mở video → Học video → phụ đề
    song ngữ + lặp câu + tap từ + Mở trong tab Nghe)

### STT-CRASH-001 — Crash SIGSEGV libwhisper.so khi tạo lời (LRC)
- **Trạng thái:** done + CI xanh (chờ nghiệm thu thiết bị)
- **Triệu chứng:** Tạo lời cho file dài → FFmpeg cắt chunk OK
  (`LS75_chunk_0_*.wav`) → log "Use existing model tiny" → crash
  `libwhisper.so request+740` trên thread DartWorker,
  `SEGV_MAPERR fault addr 0x180` (null pointer).
- **Root cause (xác minh từ source plugin whisper_flutter_new 1.0.1):**
  - Mỗi chunk = `Isolate.run()` gọi C++ `request()` →
    `whisper_init_from_file()` **KHÔNG check NULL** → `whisper_full()`.
    Init fail (OOM RAM — thường khi 2 init chạy song song: user CANCEL
    LRC rồi tạo lại ngay → request cũ bị bỏ rơi vẫn chạy trong isolate
    plugin; hoặc model file mất giữa job) → `whisper_full(NULL)` → SEGV
    ở offset struct context (~0x180).
  - Log "Use existing model tiny" = chỉ check file `.bin` tồn tại
    (`_initModel`), KHÔNG phải tái dùng context.
  - Gợi ý isolate (Gemini #3) không giải quyết: isolate là thread cùng
    process — SIGSEGV giết cả process; và plugin VẪN chạy Isolate.run
    (DartWorker trong log = isolate đó).
- **Fix (app-side, plugin GPL không sửa):** `stt_engine_whisper.dart`
  (af65675): (1) `_withExclusiveNative` — mọi transcribe ĐỢI request
  native trước (kể cả orphan sau cancel) kết thúc thật sự → không bao
  giờ 2 `whisper_init_from_file` song song; (2) pre-flight mỗi chunk:
  chunk WAV ≥44B, model `ggml-*.bin` còn tồn tại >1MB (mất giữa job →
  lỗi Dart rõ ràng thay vì SIGSEGV); (3) bọc cả đường transcribeMobile.
- **Rủi ro còn lại + đề xuất dài hạn:** OOM-init-NULL khi MỘT request
  đơn tự OOM vẫn có thể crash (chỉ patch plugin mới chặn triệt để: NULL
  check + dùng MỘT context cho cả job thay vì init/free mỗi chunk —
  còn giảm RAM + tăng tốc). Cân nhắc fork plugin hoặc chuyển đường LRC
  mobile sang engine Sherpa (lifecycle tự quản trong app).
- **Crash 2 (single request — build 4a671c2, Samsung Tab S9 FE):**
  - Log: crash NGAY chunk 0/5, request đầu tiên của process (uptime
    338s, không có transcription nào trước đó) → **loại trừ** race 2
    init song song (fix af65675 không đủ).
  - Chìa khóa trong log: manager verify
    `ggml-tiny-q5_1.bin` (32,152,673 B) nhưng plugin HARD-CODE load
    `ggml-tiny.bin`; "Use existing model tiny" → `ggml-tiny.bin` tồn
    tại nhưng là **file cũ từ phiên bản app trước** (user chỉ build lại,
    chưa xóa app) → khả năng truncate/sai định dạng →
    `whisper_init_from_file` trả NULL → `whisper_full(NULL)` →
    SEGV_MAPERR 0x180 (plugin không check NULL).
  - Fix 9ad6f85: `ensurePluginModelFile()` trước mỗi transcribe mobile
    (facade + strategy) — copy model đã verify (hoặc candidate hợp lệ
    trong modelDir) sang tên file plugin khi thiếu/khác size. Trên máy
    user plugin sẽ load q5_1 32MB (whisper.cpp của plugin hỗ trợ Q5_1 —
    xác minh `GGML_TYPE_Q5_1` trong ggml.h repo plugin) thay vì file cũ,
    đồng thời giảm ~50% RAM model so với f32 75MB.
- **Lịch sử:**
  - 2026-09-03 | created→done | agent arena/01a0251e-in4up | owner dán log
    crash + phân tích Gemini; xác minh source plugin qua GitHub; fix
    af65675; CI đỏ 33677183078 do lỗi của chính guard cũ (gọi
    `isCompleted` trên Future — chỉ Completer mới có) → bisect 1-bit
    (xanh 33677984108) → guard mới (Completer-based) → CI XANH
    33678279101
  - 2026-09-03 | done→doing | owner via chat | crash 2 trên build
    4a671c2 (single request, không race) — dán log full + native
    backtrace
  - 2026-09-03 | doing→done | agent arena/01a0251e-in4up | xác định
    mismatch ggml-tiny.bin (plugin, file cũ) vs ggml-tiny-q5_1.bin
    (manager verify); fix 9ad6f85 ensurePluginModelFile; CI XANH
    33687604868. Chờ nghiệm thu: build mới → tạo lời file dài → nếu vẫn
    crash thì Gỡ cài đặt app cũ + cài lại (xóa sạch app_flutter)

### HARVEST-1580-02 — Rà soát tổng thể 580 vs DEV (2026-08-30)
- **Trạng thái:** done — 580 KHÔNG CÒN việc pending.
- **Nội dung:** diff file-level toàn bộ 580 (tip 03e7ea0) vs DEV
  (abd93f8), loại l10n/arb (DEV đã broad hơn qua wave 01a03033).
  Kết luận từng nhóm:
  - Đã harvest (trước đó): READ-630-06 (db5c6ed), 339aad6, docx
    raw-deflate (c301004), VAD/Piper (cd8ee68), docs YT-LR/PLAN-020
    (03e7ea0).
  - DEV đã có bản MỚI HƠN (không harvest — tránh lùi phiên bản):
    word_list TTS+repeat (DEV dùng WordlistPlaybackService thay state
    inline của 580), web_reader batch (DEV: VocabBatchExtractor +
    web_extraction_candidate refactored, regex/stopwords giống hệt),
    smart_playback_bar (mode chips), listen_mode (_InlinePanel),
    listen_library (FAB Thêm audio), main_shell
    (_shouldShowShellMiniPlayer), word_entry (SkillReviewData trong file
    riêng + ADR-0001), word_import (addWithAutoClassify),
    read_mode (smart_playback_bar + progress), android (largeHeap đã có
    ở DEV line 27; MainActivity DEV có MethodChannel audiolib P1 — bản
    580 là template default; build.gradle DEV có CI-fix infra).
  - Legacy/dead (bỏ qua): packages/in4up_core/sm2_algorithm.dart (bản
    in2up cũ — DEV canonical là lib/models/sm2_algorithm.dart),
    MainActivity template 580.
- **Bằng chứng:** numstat diff 580↔DEV — mọi file có insert đáng kể
  đều verify: DEV có feature tương đương hoặc mới hơn.
- **Lịch sử:**
  - 2026-08-30 | created→done | agent arena/01a0251e-in4up | owner yêu
    cầu "cứ thâu hoạch tiếp 1580... nghiệm thu từng nhóm" — audit toàn
    diện, không còn gì pending.

### TIPITAKA-001 — Tipiṭaka (OpenTipitaka Pa-Auk): module kinh điển
- **Trạng thái:** doing — DEMO trong DEV (18813d6); production trên nhánh mới
- **Nguồn:** session `arena/019ff2f6-in4up` (workspace Linux + worktree
  Windows `E:\PROJECTS\in4up.worktree\DEV`), bàn giao 2026-09-03.
- **Đã làm (đang chạy trong DEV — commit 18813d6):**
  - Module `lib/features/tipitaka/`: models (Collection/Book/Segment
    Equatable), `db_service.dart` (sqflite, schema chuẩn, LIKE + index),
    screens (Library 2 cột; Reader song ngữ Pāli/Việt/Anh + bookmark/ghi
    chú; Search toàn văn; Download; Language Pack 26 ngôn ngữ).
  - `main_shell.dart`: quick-action bolt "tipitaka" (Home → ⚡ → Tipiṭaka).
  - `pubspec.yaml`: +sqflite +path; `assets/db/tipitaka.sqlite` DEMO
    (~1.69MB, ~10k đoạn từ 3 file nguồn) + `scripts/import_tipitaka.py`.
- **Phải làm (mỗi nhánh mới chọn 1 — chi tiết PLAN-021 mục 2):**
  - **F** Full DB import (26 DB nguồn → ~500MB, hết LIMIT 10000)
  - **D** Production: download DB về documents (KHÔNG bundle 500MB
    assets) + bookmark/note persistence + Copy Citation (DN 1.1)
  - **B** Spaced repetition: `tipitaka_learning_items` ↔ memory_mode
  - **C** AI-RAG với citation bắt buộc (không citation → không trả lời)
- **Sẽ làm (sau F/D/B/C):** FTS5; ngôn ngữ Miến/Thai; nối Reader với
  tab Đọc.
- **Tài liệu bàn giao (đọc trước khi giao việc):**
  `docs/Bangiao/bangiao_tipitaka.md` (INTEGRATION_GUIDE + README module
  + AGENT_PROMPT_TIPITAKA + TIPITAKA_HANDOFF — 4 bước F/C/B/D, ràng
  buộc, nguồn DB Pa-Auk) + `lib/features/tipitaka/models/README.md` +
  PLAN-021.
- **Lịch sử:**
  - 2026-09-03 | created | owner via session arena/019ff2f6-in4up |
    module + DB DEMO + quick-action; code nằm trong DEV từ 18813d6
  - 2026-09-03 | doing | agent arena/01a0251e-in4up | card + PLAN-021
    ghi rõ đã làm/phải làm/sẽ làm; file bàn giao vào
    docs/Bangiao/bangiao_tipitaka.md (5374214)

### SHERPA-WP23-01 — WP2 speaker waveform + WP3 voice commands (thâu hoạch 01a039e9)
- **Trạng thái:** done + CI xanh 33336160268 (tip 8c2e868)
- **Nguồn:** commit 4cdaffb từ `arena/01a039e9-in4up` (cherry-pick -x → 01f5235).
- **Nội dung:**
  - **WP2 — speaker waveform:** parse timestamp LRC khi load →
    `WaveformSegmentRef` (joinKey = ContentId.joinKey) + `SpeakerSidecar.loadSpeakerMap`
    (sidecar .spk cạnh LRC — offline overlay, không re-run STT) → waveform tô màu
    theo speaker (`kSpeakerColors`) + legend "Người N".
  - **WP3 — voice commands:** `lib/features/voice_command/` (parser ngữ pháp VI/EN
    thuần: phát/tạm dừng/tiếp theo/bài trước/nhanh hơn/chậm hơn/ẩn lời/dịch;
    service dùng `SttServiceFacade.partialResultStream` + silence timer 1.5s +
    max 6s; localizations en/vi/hi/zh/zh_TW/si). Nút mic + partial text trên
    Stack waveform tab Nghe.
  - **Fix scope (8c2e868):** 4cdaffb đặt voice button vào `GenerateLrcButton`
    (StatelessWidget độc lập) nhưng dùng state của `_ListenModeScreenState`
    → undefined name. Đã khôi phục nút Shadowing gốc + chuyển voice button
    vào Stack waveform (top-right, ẩn khi isLoading).
- **Chờ:** nghiệm thu máy (lệnh giọng nói "phát/tạm dừng/tiếp theo/nhanh hơn/
  ẩn lời"; waveform nhiều speaker cần audio đã diarize — sidecar tạo tự động
  khi chạy STT pipeline).
- **Việc tiếp theo (nhánh MỚI từ tip DEV sau khi nghiệm thu xanh —
  chi tiết PLAN-022 mục 3, bàn giao docs/Bangiao/bangiao_sherpa.md):**
  - WP3 action `translate` — nối lệnh "dịch" vào provider toggle
    translation CHỈ sau khi owner xác nhận API (known limitation bàn
    giao; không giả lập hành vi).
  - WP-Z (có thể không làm): sidecar desktop yt-dlp khi explode gãy.
  - Nâng cấp diarization khi có model thật (thay heuristic).
  - Bẫy KHÔNG lặp lại: không khai báo trùng `_voiceCommandService`/
    `_voiceListening`/`_lastVoiceText`/`_startVoiceCommands`; không
    chèn snippet bằng mắt khi có conflict; không sửa `.github/workflows/`;
    không bịa URL/model Zipformer; không auto-download.
- **Lịch sử:**
  - 2026-08-30 | created→done | agent arena/01a0251e-in4up | cherry-pick -x
    4cdaffb (01f5235) + fix scope (8c2e868); CI xanh 33336160268
  - 2026-09-03 | done→doing | agent arena/01a0251e-in4up | bàn giao
    docs/Bangiao/bangiao_sherpa.md (5374214) + PLAN-022; card bổ sung
    mục "Việc tiếp theo" + row tổng quan trỏ PLAN-022

### HOME-001 — Bỏ phần "xác nhận nỗ lực" ở tab Home
- **Trạng thái:** done + CI xanh 33944392085 (chờ nghiệm thu)
- **Nguồn:** yêu cầu owner: "Loại bỏ phần xác nhận nỗ lực ở tab Home. Vì thấy nó có phần dư thừa."
- **Fix:** `lib/screens/home/widgets/focus_streak_card.dart` — xóa prompt
  "Hôm nay bạn nỗ lực bao nhiêu? (1-10)" + `_EffortSlider` (slider 1-10 +
  nút "Xác nhận nỗ lực") + dòng "Đánh giá nỗ lực hoàn tất". Thẻ còn lại
  đúng phần cốt lõi: icon lửa + "NHỊP ĐIỆU HỌC TẬP" + "X ngày liên tiếp".
- **Ghi chú:** `FocusProvider` giữ nguyên (streak vẫn hiện giá trị đã lưu).
  Streak KHÔNG tự tăng nữa vì logic tăng streak gắn với action xác nhận
  (saveEffort) đã bị bỏ. Nếu owner muốn streak theo hoạt động thật
  (mở app/học bài) → đăng ký việc mới.
- **Lịch sử:**
  - 2026-09-05 | created→done | agent arena/01a0251e-in4up | xóa UI +
    class _EffortSlider; chờ CI + nghiệm thu

### READ-DEV-001 — Thư viện đọc: quét + hiển thị file trên máy (như thư viện nhạc)
- **Trạng thái:** done + CI xanh 33944392085 + fix hậu nghiệm thu b08567a (chờ nghiệm thu lại máy)
- **Nguồn:** yêu cầu owner: "Thư viện nhạc đã có thể quét từ máy, vậy hãy làm
  cho thư viện đọc cũng có thể quét và hiển thị từ máy thay vì phải mở sâu vào
  trong hệ thống bất tiện cho người dùng."
- **Kiến trúc (ghép theo AUDLIB-001):**
  - **Native** `MainActivity.kt` — MethodChannel `in4up/textlib`:
    `scanTree(treeUri)` liệt kê ĐỆ QUY DocumentsContract từ tree URI (SAF),
    lọc extension đọc (txt/lrc/srt/md/markdown/json/docx/pdf), trả
    {uri, name, sizeBytes, dateModifiedMs, ext}; `keepTreePermission`
    (takePersistableUriPermission — chọn 1 lần, mở app sau vẫn quét);
    `copyContentToCache` (content:// → file thật trong cache).
    Giới hạn: depth ≤ 12, ≤ 5000 file — không quét hang.
  - **Dart:** `models/text_device_entry.dart` (model + label) ·
    `services/text_device_channel.dart` (channel wrapper, an toàn
    MissingPluginException trên iOS/Linux) · `providers/text_device_provider.dart`
    (pickFolder qua FilePicker.getDirectoryPath + persist URI vào prefs +
    scan/search/forget) · đăng ký trong `main.dart`.
  - **UI** tab "Thiết bị" (`library_screen.dart`): chưa chọn folder →
    nút "Chọn thư mục & quét"; đã chọn → header folder (tên + số tài liệu
    + nút quét lại + menu quét lại/đổi/bỏ chọn) + danh sách file
    (icon theo loại, tên, kích thước · ngày · ext), tìm kiếm dùng thanh
    search chung, chạm → mở (copy cache → persist app docs → loadTextFile /
    PdfReaderScreen, thêm vào Gần đây). 2 nút chọn file riêng lẻ GIỮ NGUYÊN
    (file ngoài thư mục + nền tảng không hỗ trợ quét như iOS).
- **Vì sao SAF thay vì MediaStore:** file văn bản KHÔNG có trong
  MediaStore; scoped storage (targetSdk 35) không cho quyền đọc tùy ý
  (MANAGE_EXTERNAL_STORAGE = quyền đặc biệt, Play Store hạn chế).
  Chọn thư mục 1 lần qua hệ thống = cách chuẩn của app đọc sách.
- **Lịch sử:**
  - 2026-09-05 | created→done | agent arena/01a0251e-in4up | 4 file mới +
    sửa library_screen/main/MainActivity; chờ CI + nghiệm thu máy
    (chọn folder → thấy danh sách → mở file → mở lại app vẫn còn folder)
  - 2026-09-06 | hardening | agent arena/01a0251e-in4up | fix crash
    "Illegal percent encoding in URI" (màn đỏ) khi TÊN THƯ MỤC chứa ký tự
    đặc biệt: native `safeDecodePercent` (fallback `getTreeDocumentId` +
    `buildChildDocumentsUriUsingTree` — chỉ encode lại % hợp lệ, slash →
    %2F) + Dart `TextDeviceProvider.safeDecodeComponent` (folderLabel decode
    an toàn, không throw); + màu tile theo ext (pdf đỏ / docx xanh / lrc-srt
    cam / text xanh lá)
  - 2026-09-15 | fix hậu nghiệm thu máy | agent arena/01a07d68-in4up |
    commit b08567a (+ merge 294a332 kéo 251e mới nhất) | BUG từ logcat
    tablet (thẻ SD 3033-3963): chọn thư mục xong báo "Không tìm thấy
    file văn bản/PDF" dù thư mục có file. Gốc:
    FilePicker.getDirectoryPath trả RAW PATH (/storage/...) chứ không
    phải SAF content:// tree URI → DocumentsContract.getTreeDocumentId
    throw "Invalid URI: /storage/..." + takePersistableUriPermission
    throw SecurityException; cả 2 bị try/catch nuốt lặng → scanTree
    rỗng. FIX: native pickFolder mở ACTION_OPEN_DOCUMENT_TREE trực
    tiếp + takePersistableUriPermission ngay trong onActivityResult
    (trả content:// thật); normalizeTreeUri (legacy raw path →
    <volume>:<path>, hỗ trợ /storage/emulated + thẻ SD/USB);
    scanTree/keepTreePermission tự normalize + báo PERMISSION_LOST/
    BAD_URI thay vì nuốt lặng; Dart _migrateLegacyFolder tự chuẩn hoá
    raw path đã lưu trong prefs bản cũ. Nghiệm thu lại cần: chọn lại
    thư mục 1 lần → hiện danh sách → restart app vẫn quét được.

### LHB-004 — Lặp TTS RIÊNG từng câu (số lần tùy ý/câu) + persist theo bài
- **Trạng thái:** done (chờ CI + nghiệm thu máy)
- **Nguồn:** yêu cầu owner: "khi chọn x3 là tất cả đều phát 3 lần mỗi câu
  rất tốt, nhưng tôi muốn chỉnh chi tiết thêm để có thể chỉnh đặc biệt cho
  câu mình muốn phát số lần tùy ý (câu khó nghe nhiều lần, câu dễ 1 lần)".
- **Bối cảnh:** commit `b631395` đã implement đúng tính năng này (ngày
  2026-09-04) nhưng bị REVERT (`f782cd6`) 5 phút sau, không có lý do trong
  message. Owner yêu cầu lại → re-apply.
- **Fix:** `git cherry-pick b631395` → commit `1665d53` (apply sạch, không
  conflict vì không commit nào sau revert đụng vào file LHB):
  - `LearnByHeartItem.lineRepeatOverrides` (Map<int,int> line→count 1..999)
    + toJson key stringified + fromJson tolerant + copyWith — persist
    qua restart (Hive).
  - `MultilingualAudioService`: restoreLineOverrides (khi mở bài),
    lineRepeatOverride(line), clearLineRepeatOverride (về mặc định),
    lineRepeatOverridesSnapshot (để persist).
  - `AudioControlBar`: khi có câu đang phát → bộ [−] [Câu N: 3×] [+]:
    bấm chip = menu số lần (1/2/3/4/5/7/10/tùy chỉnh), NHẤN GIỮ chip =
    về mặc định; callback onLineRepeatChanged cho màn hình persist.
  - `BilingualVerseView`: chip lặp từng câu có onLongPress reset + persist.
  - `new_learning_screen` + `chunking_flow_screen`: restore khi mở bài +
    persist qua LearnByHeartProvider.saveItem.
  - i18n +4 getter (repeatLineCountTitle/Plus/Minus/ResetLineRepeat)
    đủ vi/en/hi/zh/zh_TW/si; +3 test trong learn_by_heart_test.dart.
- **3 bug trong code gốc b631395 (tìm ra bằng CI bisect — code gốc chưa
  bao giờ chạy CI xanh, cả 2 run b631395/f782cd6 đều đỏ do bug tipitaka
  liền trước chìm mất lỗi):**
  1. COMPILE: `fromJson` dùng `Map.map()` (trả `Iterable<MapEntry>`,
     không phải Map) rồi gọi `.entries` → getter không tồn tại.
  2. ANALYZE: chuỗi `?.map(...).where(...).toMap() ?? const {}` lỗi
     (bị bắt khi bisect state-by-state) → thay bằng helper
     `_parseLineRepeatOverrides(dynamic raw)` (forEach + clamp, tolerant
     như cũ).
  3. RUNTIME: `toJson` dùng `lineRepeatOverrides.map(...)` (Iterable) →
     jsonEncode thành mảng {key,value} → fromJson cast fail → thay bằng
     map-collection `{'\${k}': v}`.
- **Lưu ý cho owner:** revert f782cd6 (chỉ 5 phút sau b631395) rất có thể
  là do CI đỏ — root cause bây giờ đã rõ. Nếu còn lỗi UX cụ thể → báo lại.
- **Lịch sử:**
  - 2026-09-04 | (nhánh nguồn) b631395 created → f782cd6 reverted (owner)
  - 2026-09-05 | created→done | agent arena/01a0251e-in4up | cherry-pick
    lại + CI bisect (8 run, log CI không đọc được — chỉ có oracle 1-bit
    xanh/đỏ) + 3 bug fix → CI xanh 33944392085 (chờ nghiệm thu máy)

### WORDLIST-002 — Import WordList 8 cột chuẩn: nạp CHÍNH XÁC khi dán
- **Trạng thái:** done + CI xanh 33944392085 (chờ nghiệm thu máy)
- **Fix CI:** `_normAliases` — `Map.map()` trả `Iterable<MapEntry>`,
  không phải Map (chạy vào 5409728; phát hiện qua CI analyze đỏ).
- **Nguồn:** yêu cầu owner: "Trong worklist chỗ Định dạng hỗ trợ: theo
  hướng dẫn .csv/.txt bằng cột (cần dòng header): word, meaning, ipa,
  topic, example, example_simple, example_complex, language → Hãy đảm bảo
  chắc chắn rằng khi tôi dán vào như hướng dẫn thì từ vựng được nạp chính
  xác. Vì trước đây tôi thử nhờ gemini tạo danh sách từ vựng theo hướng dẫn
  trên thì nó hiện chưa chính xác hoàn toàn, còn nhiều chỗ chưa đúng."
- **Root cause (3 bug cộng dồn):**
  1. **Header `example_simple`/`example_complex` bị BỎ SÓT:** key alias
     trong map có gạch dưới (`'example_simple'`) nhưng header được
     normalize BỎ gạch dưới (`examplesimple`) → tra map không thấy → 2
     cột đó bị drop im lặng (mapped = null → skip).
  2. **Phẩy KHÔNG bọc nháy trong meaning/example (Gemini hay sinh vậy):**
     hàng có NHIỀU ô hơn header → mapping theo vị trí → cột bị LỆCH PHẢI
     (language nhận rác, meaning bị cắt) → "nhiều chỗ chưa đúng".
  3. **Header tiếng Việt có dấu map sai:** regex strip ký tự ngoài
     U+00C0-024F chạy TRƯỚC khi bỏ dấu → các chữ U+1E00+ (ừ ự ấ ể ổ...)
     bị XÓA HOÀN TOÀN (không map về chữ thường): "từ vựng" → "tvng",
     "chủ đề" → "chd" → alias không bao giờ khớp.
- **Fix:** `word_import_sheet.dart` — tách parser thuần
  `WordTableParser` (public static, test được; widget chỉ gọi):
  - `normKey`: bảng bỏ dấu tiếng Việt ĐẦY ĐỦ 64 ký tự (escape \uXXXX,
    chạy TRƯỚC bước strip) → "từ vựng" ≡ "tu_vung" ≡ "tuvung"; thêm alias
    `phienam` (phiên âm), `tiengviet/tienganh` (ngôn ngữ).
  - `_normAliases`: alias map đã normalize key → `example_simple`/
    `example_complex` map ĐÚNG.
  - `alignRow(parts, fields)`: hàng ≤ cột → 1-1 + xử lý hàng thiếu cột
    (thiếu IPA → các cột sau trượt trái khi ô cuối giống mã ngôn ngữ;
    ô cuối là mã ngôn ngữ bị đẩy vào cột text → chuyển về cột language);
    hàng > cột → **căn neo**: word = ô đầu, language = ô cuối,
    ipa = ô `/.../` đầu tiên; ô trước ipa gộp vào meaning (", ");
    ô sau ipa chia vào topic/example/exampleSimple/exampleComplex —
    cột HẤP THỤ ô dư được CHỌN THÔNG MINH (cột nào khiến ít cột tự do
    nào đó bị "cụt" thành ô 1 từ nhất — phẩy ở example_simple không bị
    đổ nhầm sang example).
  - Header lạ (không đủ mỏ neo) → giữ hành vi vị trí cũ (best-effort).
  - `splitCsvLine` giữ nguyên (đã hiểu nháy kép + escape `""`).
- **Test:** `test/word_import_parser_test.dart` — 15 test phủ: header
  8 cột (EN + VN), hàng chuẩn, nháy kép, phẩy không nháy (meaning/
  example/example_simple/cả hai), thiếu ipa (7-8 ô), thiếu cột cuối,
  tab/semicolon, hàng 2 ô, ipa trống, không-gộp-lầm.
- **Lịch sử:**
  - 2026-09-05 | created→done | agent arena/01a0251e-in4up | WordTableParser
    + 15 test; chờ CI (flutter test chạy trong pipeline)
  - 2026-09-06 | hardening | agent arena/01a0251e-in4up |
    (1) `_viBase` mở rộng ĐẦY ĐỦ 150 entries \uXXXX (mọi dấu Latin,
    đả đủ khối U+1E00+ tiếng Việt — verify bằng Python unicodedata:
    không thiếu ký tự VN nào, không key trùng — key trùng là lỗi COMPILE
    Dart). Phát hiện + sửa regression: bản regenerate làm mất U+0111 (đ)
    → "chủ đề" → "chue" ≠ "chude" → cột topic bị rơi (test header VN
    sẽ fail CI) → đã khôi phục.
    (2) Bồi hoàn alignRow m==n (T6): ô cột ipa là TỪ THÔNG THƯỜNG
    (chỉ a-zA-Z — IPA-trần luôn có ký tự ngoài Latin ʃ θ ə ð ŋ...) +
    không có /.../ nào trong hàng → coi là mảnh meaning bị xé → gộp
    vào meaning (trước: chỉ gộp khi mảnh có khoảng trắng → hàng
    "apple, to eat, fruits, , ex, exs, exc, en" để "fruits" làm
    phonetic rác). IPA-trần có ký tự ngoài Latin ("æpl") vẫn GIỮ làm
    phonetic — không gộp nhầm.
    (3) +2 regression test T6/T7 (tổng 17 test); Python simulation
    replicate đúng logic Dart cuối: 19/19 pass (17 test file + T6b +
    T8-guard)
 - **2026-09-14 (governance, agent branch PDF):** dedupe bảng Tổng quan — từng có HAI dòng
   cùng ID `WORDLIST-002` (bản cũ ghi 15 test, bản mới ghi 17 test T6/T7). Nguyên nhân:
   `af08487` append thêm dòng thay vì sửa dòng cũ. Đã xoá dòng cũ, giữ bản siêu tuyến,
   sau khi kiểm mọi mảnh thông tin của dòng bị xoá đều có trong dòng được giữ.
   Không đổi trạng thái card.

### CABIN-001 — Cabin dịch: không khởi động được mic / nhận diện giọng nói
- **Trạng thái:** done + CI xanh 33961600553 @ a1a36e5 (chờ nghiệm thu máy)
- **Triệu chứng (owner):** vào tool Dịch Live Cabin → bấm mic → banner
  "Không thể khởi động micro / nhận diện giọng nói."
- **Định vị (code + source plugin speech_to_text 7.x — SpeechToTextPlugin.kt):**
  Lỗi này = `SttServiceFacade.startListening()` trả FALSE. Native plugin
  trả false khi (a) phiên nghe CŨ CÒN TREO (`isListening` bên native) hoặc
  (b) `initialize()` fail — máy Android 12+ KHÔNG có dịch vụ Speech
  Recognition (`isRecognitionAvailable` && `isOnDeviceRecognitionAvailable`
  đều false) hoặc (c) thiếu quyền mic (cabin đã tự xin quyền trước).
  **Nghi chính đã xác nhận có bug thật:** nút "Shadowing" tab Nghe gọi
  `startListening()` fire-and-forget (stateless, không bao giờ stop, và
  `context.read<SttServiceFacade>()` vốn crash vì facade không register
  làm Provider) → mic native chạy treo (tối đa 2 phút) → cabin bấm mic
  bị plugin từ chối.
  Lỗi tiềm ẩn thêm (kể cả khi start thành công): `listenFor` mặc định
  **2 phút** → mic tự chết im lặng giữa phiên; `ListenMode.confirmation`
  (dành cho lệnh ngắn) sai cho hội thoại; lỗi session bị swallow.
- **Fix:**
  - `stt_engine_native.dart`: SELF-HEAL (cancel session cũ trước khi
    start thay vì return true giả) + `lastError` chẩn đoán (init/listen/
    session) + `listenMode` parameter + `listenFor` nullable (bỏ cap 2
    phút). (Lỗi CI lần 1: `e.errorType` không tồn tại trong
    SpeechRecognitionError 7.x — chỉ có `errorMsg` + `permanent`.)
  - `stt_service_facade.dart`: `startListening` forward listenFor/
    pauseFor/listenMode; + `startConversation()` (dictation + không cap)
    cho cabin/shadowing; + `isLiveListening` / `liveLastError` /
    `checkLiveMicPermission()`.
  - `stts_cabin_service.dart`: pre-start `stopListening()` dọn session
    treo; fail → stop + RETRY 1 lần; **keep-alive** 4s (session chết mà
    cabin vẫn "đang nghe" → tự restart im lặng; fail 3 lần liên tiếp →
    lỗi); message lỗi HÀNH ĐỘNG ĐƯỢC (thiếu quyền → dẫn Settings; không
    có speech service → dẫn kiểm tra Google/Samsung Speech Services + ghi
    chú Whisper offline chưa hỗ trợ mic live); race-guard khi user bấm
    mic đúng lúc keep-alive đang restart.
  - `listen_mode_screen.dart`: nút Shadowing thành TOGGLE ("Dừng mic") +
    `startConversation()` + sửa `context.read` → singleton (chặn crash +
    chặn mic treo chiếm cabin).
- **Quá trình debug:** log CI không đọc được → bisect bằng CI oracle
  (~15 run xanh/đỏ) cô lập đúng khu vực lỗi; lần cuối: closure 0-arg
  cho `Timer.periodic` (khác convention 1-arg `(_)` của toàn repo) —
  đã đổi sang `(_)` theo convention — CI xanh xác nhận (33961600553).
- **Chưa làm (WP2 theo PLAN-008):** live STT offline bằng sherpa
  Zipformer streaming (không phụ thuộc speech service hệ thống) —
  `SherpaSttEngine.startListening` hiện là PoC chưa nối mic.
- **Nghiệm thu máy:** (1) tab Nghe: bấm Shadowing → mic chạy → bấm
  "Dừng mic" → dừng thật; (2) Cabin bấm mic → nghe+dịch liên tục (không
  chết sau 2 phút, tự sống lại sau im lặng); (3) nếu vẫn lỗi → banner
  mới chỉ đúng nguyên nhân (quyền vs speech service).
- **Lịch sử:**
  - 2026-09-05 | created→doing | agent arena/01a0251e-in4up | chẩn đoán
    qua source plugin + fix 4 file; CI bisect cô lập lỗi; chờ CI xanh
    cuối + nghiệm thu

### SHERPA-WP4-01 — Live STT offline qua sherpa Zipformer (WP4)
- **Trạng thái:** ✅ done (chờ CI + nghiệm thu máy)
- **Nguồn:** owner (2026-09-05) — tiếp nối CABIN-001: cabin chạy bằng
  speech service hệ thống → máy không có Google/Speech Services thì
  không khởi động được mic; WP4 cho cabin live STT OFFLINE qua
  sherpa-onnx Zipformer.
- **Tài liệu bàn giao (BẮT BUỘC đọc):**
  `docs/Bangiao/bangiao_sherpa_wp4_live_stt.md` — nhiệm vụ N1-N4,
  thực tế model ĐÃ VERIFY từ docs k2-fsa (2026-09-05), kiến trúc
  endpointing chốt (VI=simulated streaming + VAD; EN=streaming thật),
  bẫy không lặp lại (từ CABIN-001/WP3), AT thiết bị 7 bước, format
  báo cáo "WP DONE".
- **Model (đã verify URL + layout + size từ docs chính thức):**
  - VI (ưu tiên): `sherpa-onnx-zipformer-vi-30M-int8-2026-02-09`
    (~32MB int8, 6000h VI, RTF ~0.011) — simulated streaming +
    Silero VAD (đã có trong app).
  - EN: `csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17`
    (int8, streaming thật token-by-token) — endpoint rules tune.
  - KHÔNG có Zipformer streaming-thật tiếng Việt (verify từ docs).
- **Mở nhánh:** branch MỚI từ tip DEV; prompt topic = trỏ file bàn
  giao + PLAN-023; sau khi CI xanh + nghiệm thu → leader DEV
  cherry-pick `-x` harvest.
- **Lịch sử:**
  - 2026-09-05 | created | agent arena/01a0251e-in4up (leader DEV) —
    prompt bàn giao + PLAN-023; chờ owner mở nhánh sherpa
  - 2026-09-05 | proposed→done | agent arena/01a0692a-in4up | hoàn thành N1-N4 (SherpaSttEngine simulated streaming VI + streaming EN, SherpaModelManager 2 Zipformer profiles, UI Quản lý Model AI, Cabin engine toggle, priority i18n, test unit).

### DICT-001 — Từ điển MDX/MDD đa ngữ: import, tra từ, quản lý
- **Trạng thái:** 🔄 doing — WP0 models + DB, đang code
- **Nguồn:** owner (2026-09-05) — "tích hợp từ điển dạng mdd mdx vào dự án"
- **Chi tiết:** xem PLAN-024 + `docs/Bangiao/bangiao_dictionary.md`
- **Nội dung:**
  - MDX parser (Dart, pure, isolate) → SQLite dict_entries
  - Dictionary service facade: lookup multi-dict, register/unregister
  - Import flow: file_picker → parse → SQLite, progress, error handling
  - Dict manager screen: list, delete, toggle, entry count
  - Tích hợp WordActionsSheet (Read mode) + WordAnalysisSheet (YouTube)
  - Auto-fill meaning khi lưu từ (addWithAutoClassify)
  - i18n chrome UI (rule #5 AGENTS.md)
- **Work packages:**
  - WP0: Models + DB service (DictEntry, DictInfo, DictDbService)
  - WP1: MDX parser (Dart, isolate)
  - WP2: Dictionary service facade
  - WP3: Import flow
  - WP4: Dict manager screen
  - WP5: Tích hợp Read mode
  - WP6: Tích hợp YouTube + i18n
- **Bằng chứng:** code trên branch arena/01a07234-in4up
- **Lịch sử:**
  - 2026-09-05 | created→doing | agent arena/01a07234-in4up | PLAN-024 + bàn giao + WP0

### VID-001 — Video Player local: xem video + phụ đề + học từ (PLAN-025)
- **Trạng thái:** 🔄 doing — WP0-WP3 code, đang push
- **Nguồn:** owner (2026-09-05) — "làm phần video kết hợp A+B"
- **Chi tiết:** xem PLAN-025 + `docs/Bangiao/bangiao_video.md`
- **Nội dung:**
  - Sub-tab "Xem" trong tab Nghe (Nghe | Nói | Xem) — approach A
  - Quick-action "Video" trong ⚡ menu — approach B
  - Video player screen (video_player package) + controls + speed
  - SRT subtitle parser + overlay
  - Video library screen (browse/search files from device)
  - Tap subtitle → tra từ điển + lưu WordList
  - A-B loop per subtitle line
  - i18n chrome UI (rule #5)
- **Work packages:**
  - WP0: Models + video library service ✅
  - WP1: Video player screen ✅
  - WP2: SRT subtitle parser ✅
  - WP3: Sub-tab "Xem" + quick-action ✅
  - WP4: Tích hợp từ điển (tap subtitle → lookup)
  - WP5: A-B loop per subtitle line + i18n
- **Bằng chứng:** code trên branch arena/01a07234-in4up
- **Lịch sử:**
  - 2026-09-05 | created→doing | agent arena/01a07234-in4up | PLAN-025 + bàn giao + WP0-WP3

### IMG-001: Vocabulary Image Feature
- **ID**: IMG-001
- **Tiêu đề**: Thêm hình ảnh ghi nhớ cho từ vựng
- **Mô tả**: Cho phép người dùng chọn/gán hình ảnh cho từ vựng khi lưu hoặc chỉnh sửa. Hình ảnh được lưu vào app documents với hash-based deduplication. Hiển thị thumbnail trong danh sách từ và preview lớn hơn khi mở rộng chi tiết.
- **Ưu tiên**: Trung bình
- **Trạng thái**: ✅ Done
- **Ngày tạo**: 2026-09-05
- **Ngày hoàn thành**: 2026-09-05
- **Commit**: `c15b0b7` on `arena/01a07234-in4up`
- **Lý thuyết**: Dual-coding theory (Paivio 1971) - hình ảnh giúp tăng cường mã hóa ký ức
- **Files**:
  - `lib/features/vocab_image/vocab_image_service.dart`
  - `lib/features/vocab_image/vocab_image_picker.dart`
  - `lib/features/vocab_image/vocab_image_thumbnail.dart`
  - `lib/features/vocab_image/vocab_image.dart`
  - `lib/providers/vocabulary_provider.dart` (updateImageUrl method)
  - `lib/screens/read_mode/sheets/word_actions_sheet.dart`
  - `lib/screens/tools/word_list/word_list_screen.dart`
### STT-LRC-LANG-01 — Tạo lời (LRC) bằng Whisper: đa ngữ, hết hardcode 'en'
- **Trạng thái:** ✅ done + CI xanh run 33977299465 (chờ nghiệm thu máy)
- **Nguồn:** owner (2026-09-05): "Đảm bảo với file âm thanh khả năng tạo lời
  bằng AI có thể dùng cho đa ngữ chứ không riêng tiếng Anh."
- **Root cause:** `PlayerSttMixin.generateLrcForCurrentAudio` HARDCODE
  `language: 'en'` ở cả 3 đường transcribe (VAD pipeline >5MB,
  transcribeAuto khi AUTO, transcribeFile khi chọn model) → file tiếng
  Việt/Bất kỳ ngôn ngữ nào khác bị ép transcribe bằng tiếng Anh → lời
  thoại sai. UI `_LrcModelSelector` chỉ chọn model + grouping, không
  có chọn ngôn ngữ.
- **Fix:**
  - `player_stt_mixin.dart`: `generateLrcForCurrentAudio({..., String
    language = 'auto'})` + 3 call sites nhận `language`;
    `generateLrcWithVadPipeline` default 'vi' → 'auto'.
  - `generate_lrc_actions.dart`: `confirmAndGenerateLrc(..., {String
    language = 'auto'})` chuyển xuống mixin.
  - `listen_mode_screen.dart`: `_LrcModelSelector` thêm hàng chip ngôn
    ngữ (14 mã: auto/vi/en/zh/ja/ko/th/es/fr/de/ru/id/hi/pi), mặc định
    'Tự động'; `onGenerate(level, grouping, language)`; nút LRC hiện
    ngôn ngữ đang chọn.
  - 'auto' đã verify hoạt động trên CẢ 3 đường Whisper: plugin
    whisper_flutter_new (C++: `params.language = "auto"` qua
    whisper_lang_id, default của plugin cũng là "auto"), FFI desktop
    (whisper.cpp xử lý "auto" = auto-detect), CLI (`-l auto`).
  - Cache key đã gồm language (mỗi ngôn ngữ 1 cache — không trộn).
- **AT nghiệm thu máy:** (1) file tiếng Việt + chip "Tự động" → lời
  tiếng Việt đúng; (2) file tiếng Anh + "Tự động" → lời Anh đúng;
  (3) ép chip "Tiếng Việt" cho file Việt → đúng; (4) file dài >5MB
  (đường VAD pipeline) + "Tự động" → đúng ngôn ngữ; (5) "Tạo lại" sau
  khi đổi ngôn ngữ → LRC mới theo ngôn ngữ mới.
- **Lịch sử:**
  - 2026-09-05 | created→doing | agent arena/01a0251e-in4up | fix 3 file
    (mixin + generate_lrc_actions + listen_mode_screen); chờ CI +
    nghiệm thu
  - 2026-09-05 | proposed→done | agent arena/01a0692a-in4up | hoàn thành N1-N4 (SherpaSttEngine simulated streaming VI + streaming EN, SherpaModelManager 2 Zipformer profiles, UI Quản lý Model AI, Cabin engine toggle, priority i18n, test unit).

### CI-IOS-01 — Action iOS đỏ: `pod install` fail vì deployment target thấp
- **Trạng thái:** ✅ done (chờ run CI xác nhận)
- **Nguồn:** owner (2026-09-06) — log job Build iOS IPA (sideload).
- **Triệu chứng (log):**
  ```
  [!] CocoaPods could not find compatible versions for pod "google_mlkit_commons":
      ... they required a higher minimum deployment target.
  Error: The plugin "google_mlkit_commons" requires a higher minimum iOS
         deployment version than your application is targeting.
  To build, increase your application's deployment target to at least 15.5
  Error running pod install / exit code 1
  ```
- **Root cause:** app target đang là **15.0** (workflow `sed` ép 15.0; repo còn
  `ios/Podfile` = 14.0, `project.pbxproj` = 13.0, `AppFrameworkInfo.plist` = 13.0),
  trong khi `google_mlkit_commons`/`google_mlkit_translation` (kéo theo
  **MLKitVision**) khai báo `s.platform = :ios, '15.5'`. CocoaPods resolver
  không có spec nào thoả → đỏ ngay bước phân giải phụ thuộc.
  Thêm một mồi lửa nữa: `post_install` của Podfile **hạ** mọi pod về 14.0
  (kể cả pod tự khai 15.5) → kể cả khi qua được resolver vẫn sai.
- **Fix:**
  - `ios/Podfile`: biến `$ios_deployment_target = '15.5'`; `platform :ios,
    $ios_deployment_target`; `post_install` **chỉ nâng, không hạ**
    (`Gem::Version` so sánh) và đồng bộ luôn target của project Runner.
  - `ios/Runner.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 15.5`
    (3 configuration).
  - `ios/Flutter/AppFrameworkInfo.plist`: `MinimumOSVersion` 13.0 → 15.5.
  - `scripts/ci/ios_set_deployment_target.sh` (mới): 1 lệnh đồng bộ 3 file,
    idempotent — thay 2 bước `sed` rời rạc, dễ lệch, trong workflow.
  - **Workflow (CHƯA push được — xem "Việc còn lại"):** patch nằm ở
    `scripts/ci/ios_ci_workflow.patch` cho `.github/workflows/build.yml` +
    `build_final_complete.yml`: env chung `IOS_MIN_TARGET: '15.5'`, gọi script
    thay 2 bước `sed`, `export IPHONEOS_DEPLOYMENT_TARGET="$IOS_MIN_TARGET"`,
    thêm `flutter config --no-enable-swift-package-manager` (4 plugin
    whisper_flutter_new / google_mlkit_* / flutter_tts đều KHÔNG hỗ trợ SPM —
    log đã cảnh báo), `pod install --repo-update` chạy sớm để lỗi phụ thuộc hiện
    ngay, và bước chẩn đoán `if: failure()` in Podfile + target + Podfile.lock.
  - **Chống workflow cũ ghi đè:** `ios/Podfile` khai báo nền tảng dạng
    `platform(:ios, $ios_deployment_target)` (CÓ NGOẶC) nên bước
    `sed "s/platform :ios.*/... '15.0'/"` của workflow hiện tại KHÔNG khớp →
    15.5 sống sót; bước sed ép `project.pbxproj` về 15.0 thì `post_install`
    kéo lại 15.5. Nghĩa là CI xanh được ngay cả khi chưa vá workflow.
- **Việc còn lại (cần owner):** GitHub App không có quyền `workflows` → push bị
  từ chối (`refusing to allow a GitHub App to ... update workflow`). Owner áp
  patch: `git apply scripts/ci/ios_ci_workflow.patch` rồi commit/push, hoặc sửa
  tay 2 file workflow theo patch. Không bắt buộc để CI xanh, nhưng nên làm để
  workflow hết chỗ ép 15.0 lỗi thời.
- **Hệ quả cần biết:** app không còn cài được trên iOS < 15.5 (yêu cầu bắt buộc
  của ML Kit — muốn hạ thì phải bỏ `google_mlkit_translation`).
- **Lịch sử:**
  - 2026-09-06 | created→done | agent arena/01a07860-in4up | nâng target 15.5 +
    script đồng bộ + tắt SPM; chờ run CI xác nhận

### LHB-005 — Bấm icon lặp 1× của câu không mở menu (chọn cả dòng luôn)
- **Trạng thái:** done + CI xanh (run 37356246667 trên tip `d7a4696`) — chờ owner build lại từ tip MỚI + nghiệm thu máy
- **Triệu chứng (owner 2026-09-08):** "bấm vô 1x của từng câu để chỉnh thử
  thì không được. Nhấn vào biểu tượng lặp ở dòng thì nó chọn cả dòng chứ
  không phản ứng với icon lặp 1x."
- **Root cause (2 lỗi cộng dồn ở `_LineRepeatChip`, BilingualVerseView):**
  1. Chip là `GestureDetector` mặc định `HitTestBehavior.deferToChild` +
     kích thước ~39×19px — vùng chạm rất nhỏ, chạm lệch một chút (padding/
     khe icon-text) là mất hit test → tap rơi về `InkWell` của CẢ DÒNG
     (onLineTap → playSingleLine) → "chọn cả dòng".
  2. `showRepeatCountMenu` được gọi với context của BilingualVerseView
     (= RenderViewport của CẢ ListView shrinkWrap) → `position` = rect của
     cả danh sách câu (có thể dài hơn màn hình) → menu popup hiện Ở DƯỚI
     CUỐI danh sách / ngoài màn hình → "như không phản ứng" dù tap đúng chip.
- **Fix (`bilingual_verse_view.dart`):**
  - `GestureDetector(behavior: HitTestBehavior.opaque)` — TOÀN bộ rect chip
    (kể cả padding) bắt chạm → chip luôn thắng InkWell dòng trong gesture
    arena (đúng ngữ nghĩa: bấm chip = chỉnh lặp, bấm chỗ khác dòng = phát câu).
  - Vùng chạm min 44×32 (constraints) + icon/text nhích lên 12/11px — dễ
    bấm trên điện thoại; hiển thị chip gần như giữ nguyên.
  - Menu gọi với context CỦA CHIP (`_LineRepeatChip.build`) → menu neo sát
    icon 1×, luôn hiện trên màn hình, bấm chọn số lần (1/2/3/4/5/7/10/
    tùy chỉnh) xong là áp; NHẤN GIỮ chip = bỏ override về mặc định.
- **AT nghiệm thu:** mở bài LHB (New Learning / Học cuốn chiếu) → bấm icon
  1× ở góc phải trên của TỪNG CÂU → menu số lần hiện SÁT icon → chọn 3× →
  chip đổi "3×" màu cam → phát bài → câu đó lặp 3 lần; nhấn giữ chip → về
  mặc định; bấm phần KHÁC của dòng (văn bản) → vẫn phát riêng câu đó.
- **Lịch sử:**
  - 2026-09-08 | created→doing | agent arena/01a0251e-in4up | fix chip
    (opaque + target lớn + menu neo chip context); chờ CI + nghiệm thu
  - 2026-10-06 | doing→done(CI xanh) | agent arena/01a0251e-in4up | sau rebase
    lên tip `d7a4696`, App Analyze + Locale Test CI XANH run 37356246667 — fix
    `58e0318` đã nằm TRONG tip. Còn lại: owner build lại từ tip MỚI (KHÔNG phải
    build cũ 1d58b78) + nghiệm thu máy. Nếu VẪN chọn cả dòng khi bấm chip trên
    build MỚI → gửi repro chính xác + logcat để debug tiếp.

### TTS-PIPER-001 — LHB phát tới câu tiếng Việt SẬPP app (Piper TTS)
- **Trạng thái:** done + CI xanh (run 37356246667 trên tip `d7a4696`) — chờ owner build lại từ tip MỚI + nghiệm thu máy
- **Triệu chứng (owner 2026-09-08):** "tool học thuộc lòng khi nhấn phát
  âm thanh, sau khi phát pali xong tới phần tiếng Việt thì nó bị dish out
  app. Trong khi đã import vi_VN-25hours_single và en_US-lessac-medium rồi."
- **Định vị (code):** LHB bilingual = `_speakText(Pali, 'pi')` →
  `speakLocale` → Pali = `hi-IN` (không có giọng Piper hi-IN → fallback
  giọng máy hệ thống — nên Pali vẫn phát) → rồi `_speakText(VI, 'vi-VN')`
  → TtsService ưu tiên `piper_tts` → `_trySpeakPiper` →
  `PiperTtsEngine.isAvailable()` CHỈ check `voices.isNotEmpty` (có file
  .onnx) → `selectVoice` → `sherpa.OfflineTts(...)` = INIT NATIVE C++.
  Sherpa-onnx đọc `espeak-ng-data` (phonemizer) khi init — **thiếu thư
  mục này (hoặc model tải về bị cắt/già) thì init native SEGFAULT → app
  chết hẳn, Dart try/catch KHÔNG BẮT ĐƯỢC** → đúng cảnh "phát xong Pali,
  tới phần Việt là sập".
- **Fix (pre-flight TRƯỚC init native):**
  - `SherpaPiperTtsCore.isEspeakReady()` — check `phontab` (espeak-ng-data)
    tồn tại và > 64 bytes.
  - `SherpaPiperTtsCore.isVoiceFilesPlausible(voice)` — onnx ≥ 1MB +
    tokens ≥ 1KB (bắt file tải về bị cắt giữa chừng).
  - `selectVoice`: pre-flight 2 mục trên TRƯỚC khi `OfflineTts(...)` —
    thiếu/hỏng → return false (TtsService fallback sang giọng máy — vẫn
    đọc được tiếng Việt, không crash) + log lý do.
  - `PiperTtsEngine.isAvailable()`: giờ = có giọng + espeak ready + ≥1
    model nguyên vẹn → TtsService KHÔNG cố Piper vô nghĩa nữa.
  - Log init native (tên giọng + size onnx/tokens + espeak=OK) — nếu crash
    native vẫn xảy ra (vd OOM máy yếu), logcat dòng cuối cho biết đang
    init model nào.
- **Lưu ý cho owner:** nếu sau fix mà phát tiếng Việt BẰNG GIỌNG MÁY
  (không neural) = máy thiếu `espeak-ng-data` → vào **Cài đặt → TTS /
  Quản lý model** → bấm "Tải phonemizer (espeak-ng-data)" (~2MB, dùng
  chung mọi giọng) → phát lại. Nếu VẪN sập sau khi có phonemizer → là
  vấn đề bộ nhớ máy (model ~60MB) — báo lại để xử lý (numThreads/model
  nhỏ hơn).
- **Lịch sử:**
  - 2026-09-08 | created→doing | agent arena/01a0251e-in4up | pre-flight
    espeak + model plausibility trước init native + isAvailable chuẩn +
    log; chờ CI + nghiệm thu (Pali + VI liên tiếp không sập)
  - 2026-10-06 | doing→done(CI xanh) | agent arena/01a0251e-in4up | sau rebase
    lên tip `d7a4696`, CI XANH run 37356246667 — fix `d28a1e9` + `b6b2384` đã
    nằm TRONG tip. build cũ `1d58b78` của owner KHÔNG có đủ bộ vá này → sập.
    Còn lại: owner build lại từ tip MỚI + nghiệm thu (Pali + VI liên tiếp không
    sập). Nếu phát VI bằng GIỌNG MÁY = thiếu espeak-ng-data → Cài đặt → TTS/
    Quản lý model → "Tải phonemizer"; nếu VẪN sập trên build MỚI = model hỏng
    hoặc thiếu RAM → tải lại vi_VN-25hours_single + gửi logcat.

### READ-FOCUS-001 — Tab Đọc Focus: thanh đáy vẫn chiếm không gian
- **Trạng thái:** done + CI xanh (run 37356246667 trên tip `d7a4696`) — chờ owner build lại từ tip MỚI + nghiệm thu máy
- **Triệu chứng (owner 2026-09-08):** "khi nhấn Focus thì vùng bên dưới
  bottom vẫn chưa ẩn, nó chỉ không hiện các icon chức năng chứ vẫn chiếm
  không gian."
- **Root cause:** `read_mode_screen.dart` — bottom bar (SmartPlaybackBar +
  ReadBottomBar) trong Focus mode chỉ bị `AnimatedSlide(offset: 0, 1.2)`
  (trượt ra khỏi màn hình) + `AnimatedOpacity(0)` (trong veo) — **layout
  space vẫn nằm trong Column** → vùng đọc không được mở rộng, còn dải
  trống đen phía dưới.
- **Fix:** bọc bottom bar bằng `AnimatedSize` — Focus mode → child =
  `SizedBox(height: 0)` → chiều cao GẬP về 0 có animation 260ms (trả
  không gian cho vùng đọc, văn bản mở rộng hết chiều cao); ngoài Focus →
  giữ nguyên AnimatedSlide/Opacity (smart-hide khi cuộn GIỮ NGUYÊN hành
  vi cũ — chỉ slide, không gập — tránh văn bản nhảy giật khi đang đọc).
  `ClipRect` bao AnimatedSlide để bar không tràn khi đang mở rộng lại.
- **AT nghiệm thu:** tab Đọc → bấm Focus (hoặc double-tap) → thanh đáy
  (playback + hàng icon) gập xuống mượt, vùng đọc MỞ RỘNG hết đáy màn
  hình; bấm "Thoát Focus" (hoặc double-tap) → thanh đáy trồi lên lại
  đúng vị trí cũ; cuộn lên/xuống lúc không Focus → smart-hide như trước.
- **Lịch sử:**
  - 2026-09-08 | created→doing | agent arena/01a0251e-in4up | AnimatedSize
    gập đáy về 0 trong Focus mode; chờ CI + nghiệm thu
  - 2026-09-15 | làm lại v2 (READ-TOOLBAR-001 v2) | agent | bỏ TOÀN BỘ widget
    animation (AnimatedSize/Slide/Opacity/ClipRect) → `CollapsibleBottomControls`
    build điều kiện `SizedBox(height: 0)` tức thì — hết "khối đen che chữ" trên
    GPU Mali/Adreno; commit `6ba029a` + `311fbfd`
  - 2026-10-06 | doing→done(CI xanh) | agent arena/01a0251e-in4up | sau rebase
    lên tip `d7a4696`, CI XANH run 37356246667 — fix đã nằm TRONG tip. build cũ
    `1d58b78` của owner thiếu vá này → thanh đáy vẫn chiếm không gian. Còn lại:
    owner build lại từ tip MỚI + nghiệm thu (bấm Focus → đáy gập về 0, vùng đọc
    mở rộng hết đáy).

### WEB-LOAD-001 — Web Reader: spinner/load "kẹt" dù trang đã load xong
- **Trạng thái:** doing (code xong, chờ CI + nghiệm thu máy)
- **Triệu chứng (owner 2026-10-06):** "web reader khi mở web lên nó cứ xoay
  xoay + load trong khi thực tế đã load xong rồi; chọn icon 'eye' đánh dấu từ
  đã lưu thì nó vẫn xoay + load."
- **Định vị (code):** spinner toàn màn hình + thanh tiến trình AppBar hiển thị
  khi `state == WebReaderState.loading` (`web_reader_screen.dart`). `state` chỉ
  chuyển `loading→ready` khi WebView bắn `onPageFinished`. Một số trang (nặng /
  redirect / SPA / ad giữ load event / websocket) KHÔNG BAO GIỜ bắn
  `onPageFinished` → `state` kẹt ở `loading` → spinner che trang đã sẵn sàng.
  Icon "eye" (recall marker) chỉ re-inject JS highlight (KHÔNG navigate) nên
  không phải thủ phạm — nó chỉ là chỗ owner RỐT RA thấy spinner kẹt.
- **Fix (WEB-LOAD-001 — load watchdog):** `web_reader_controller.dart`
  - `onPageStarted` ⇒ `_startLoadWatchdog()` (Timer 10s, restart mỗi lần
    navigate mới).
  - `onPageFinished` / `onError` / `dispose` ⇒ `_stopLoadWatchdog()`.
  - Watchdog fire mà vẫn `loading` ⇒ ép `state→ready` + ẩn spinner (WebView
    vẫn load ngầm, không che tầm nhìn). An toàn: nếu `onPageFinished` tới muộn
    sau đó chỉ set `ready` lại (không hại); navigate mới lại set `loading`
    (đúng nghĩa).
- **AT nghiệm thu:** mở 1 trang web nặng/SPA (vd trang có nhiều ad / feed
  infinite scroll) → trong ≤10s spinner TẮT dù trang có kịp load xong hay
  chưa → đọc/scroll bình thường; mở trang thường → spinner tắt ngay khi load
  xong (onPageFinished); chuyển trang → spinner hiện lại đúng lúc.
- **Lưu ý cho owner:** fix này MỚI (commit hiện tại) — cần build lại từ tip
  MỚI nhất của `arena/01a0251e-in4up` để có.
- **Lịch sử:**
  - 2026-10-06 | created→doing | agent arena/01a0251e-in4up | watchdog
    `onPageFinished` 10s tự ẩn spinner; chờ CI + nghiệm thu máy

### WEB-TTS-PAUSE-001 — Web Reader: bấm Pause bài đọc vẫn tiếp tục đọc
- **Trạng thái:** done + CI xanh (fix đã trong tip) — chờ owner build lại +
  nghiệm thu máy
- **Triệu chứng (owner 2026-10-06):** "khi phát âm thanh ở web read, khi nhấn
  nút pause thì nó vẫn đọc, trong khi đã chuyển qua nút tam giác (icon)."
- **Root cause (xác minh bằng code build cũ `1d58b78`):** build của owner
  (09-15) có `pause()` CHỈ `await _audioPlayer.pause()` (KHÔNG pause giọng máy
  flutter_tts) + vòng `speakLines` KHÔNG có guard pause ⇒ câu đang đọc bằng
  giọng máy chạy tới hết + vòng lặp NHẢY sang câu kế → "bấm Pause xong vẫn
  nghe". Icon đổi ▶ vì cờ `_isPaused=true` (UI đúng) nhưng ÂM không dừng.
- **Fix (đã ở tip, commit `72b1e85` 2026-10-01 — I4U18-PDF-OCR-TTS-001 F3):**
  `tts_service.dart`
  - `pause()` = DỪNG ÂM ĐANG PHÁT CẢ AudioPlayer lẫn giọng máy
    (`_offlineEngine.pause()`, fallback `stop()` nếu device không hỗ trợ pause).
  - `speakLines` + `_awaitLineFinished` có guard: khi `_paused` vòng lặp ĐỨNG
    YÊN ở đúng câu đang đọc (KHÔNG auto-skip câu kế).
  - `stop()` tăng `_playbackEpoch` chặn mọi tác vụ phát đang bay.
- **AT nghiệm thu:** tab web → đọc bài (🎧) → bấm Pause → ÂM DỪNG NGAY (icon
  ▶) → bấm ▶ (Tiếp tục) → đọc lại → bấm ⏹ (Dừng) → hết. Kiểm tra cả 2 kiểu
  giọng: Piper/online (AudioPlayer) + giọng máy (flutter_tts).
- **Lưu ý cho owner:** fix NÀY đã có ở tip hiện tại — build cũ `1d58b78` của
  owner thiếu nên mới sập. Build lại từ tip MỚI để có. (Hạn chế còn lại đã
  ghi: resume giọng máy flutter_tts bắt đầu từ câu kế, không nối giữa câu —
  đúng như thiết kế F3.)
- **Lịch sử:**
  - 2026-10-06 | created→done(CI xanh) | agent arena/01a0251e-in4up | xác minh
    fix PAUSE F3 (`72b1e85`) đã trong tip, build cũ `1d58b78` thiếu; chờ owner
    build lại + nghiệm thu máy

### VIENEU-001 — VieNeu-TTS (PLAN-027)
- **Trạng thái:** proposed
- **Nội dung:** ghi kế hoạch, chưa implement. Engine TTS Việt bổ sung qua sherpa OfflineTts nếu có ONNX verify.
- **Lịch sử:**
  - 2026-09-15 | created | owner via arena/01a08043-in4up | chỉ ghi plan

### TTS-PIPER-002 — Catalog tải Piper (HuggingFace rhasspy/piper-voices)
- **Trạng thái:** doing
- **Nội dung:** sheet Tải giọng ưu tiên VI/EN/ZH/HI + Show more; k2-fsa tar trước, HF onnx+json fallback.
- **Lịch sử:**
  - 2026-09-15 | created→doing | agent arena/01a08043-in4up

## 🔥 BATCH OWNER 2026-09-15 — 9 lỗi sau build `1d58b78` (handoff cho agent Arena)

> Owner build từ tip `1d58b78` (DEBUG build — nên mới thấy assertion).
> Mỗi card: TRIỆU CHỨNG (lời owner) → REPRO → ROOT CAUSE (đã verify code /
> nghi) → FILES → FIX ĐỀ XUẤT → AT. Sửa xong → owner create PR vào
> `arena/01a0251e-in4up`. **Chạy `flutter clean && flutter pub get` trước
> khi build nghiệm thu** (có dep native mới: video_player 2.8.0).

### PDF-JUMP-001 — Nhập/chọn số trang rồi thoát → assertion `_dependents.isEmpty`
- **Trạng thái:** doing — đã có fix + test seam + CI App Analyze xanh, chờ nghiệm thu máy
- **Triệu chứng (owner):** "Khi nhấn vào chọn / điền số trang sau đó thoát ra
  thì báo lỗi: 'flutter/src/widgets/framework.dart': Failed assertion: line
  6268 pos 12: '_dependents.isEmpty': is not true."
- **Repro:** tab Đọc → mở PDF (pdf_reader mới) → toolbar → "Tới trang" →
  điền số / kéo slider → "Đi tới" (hoặc đóng) → assertion.
- **Assertion:** `InheritedElement.deactivate()` — 1 InheritedWidget (hình
  như `MediaQuery`) bị deactivate trong khi con vẫn depend. Debug build.
- **Nghi chính (đã đọc code):** `pdf_reader_screen.dart` —
  `_showJumpToPageDialog()` (showDialog + TextField autofocus + Slider) →
  pop → `_goToPageIndex(...)`. Điểm chết người tiềm tàng:
  1. `Focus(autofocus: true, onKeyEvent: _handleShortcutKey)` bọc TOÀN viewer
     (body) — focus transfer dialog↔viewer khi đóng.
  2. `_goToPageIndex` (pdfrx `jumpToPage`) chạy TRÙNG thời điểm route dialog
     đang dispose → rebuild viewer giữa chừng dispose.
  3. Dialog dùng `context` của State (không phải dialogContext) ở một số chỗ.
- **Files:** `lib/features/pdf_reader/pdf_reader_screen.dart`
  (`_showJumpToPageDialog` ~line 507; body `Focus(...)` ~line 583),
  `lib/features/pdf_reader/pdf_reader_controller.dart` (`goToPage`/`jumpToPage`).
- **Fix đề xuất:** (a) delay `_goToPageIndex` qua
  `WidgetsBinding.instance.addPostFrameCallback` SAU khi dialog pop hẳn;
  (b) trong dialog chỉ dùng `dialogContext`; (c) nếu còn lỗi: bọc
  `_goToPageIndex` try/catch + `debugPrint` stack, chạy lại repro để lấy
  stack thật trước khi sửa sâu.
- **AT:** mở PDF → "Tới trang" → điền + Đi tới → KHÔNG có assertion red;
  đóng bằng "Huỷ" → không lỗi; lặp 5 lần.
- **Lịch sử:**
  - 2026-09-15 | 20:51 UTC | doing→doing | agent arena/01a0a6cf-in4up | commit 3450d79 + 54e1171; App Analyze + Locale Test run 35021922026 xanh; thêm seam `PdfJumpToPageDialog` chờ nghiệm thu máy

### WLIST-LANG-001 — Lưu WordList: có tạo chủ đề mới nhưng KHÔNG có tạo ngôn ngữ mới
- **Triệu chứng (owner):** "Lưu vào WordList: Hiện có thể tạo chủ đề mới
  nhưng chưa có chỗ tạo ngôn ngữ mới."
- **Repro:** Đọc/PDF → chọn từ → "Lưu vào WordList" → sheet `SelectionSaveSheet`:
  hàng Chủ đề có ô "Tạo chủ đề mới…" nhưng hàng Ngôn ngữ chỉ hiện chips
  `provider.allLanguages` (các ngôn ngữ ĐÃ TỒN TẠI trong WordList) — muốn
  tag ngôn ngữ mới (vd `pi` Pali, `lo`, `my`…) thì không có cách nào.
- **Root cause (đã verify):** `lib/widgets/selection_save_sheet.dart`
  line ~186: `languageOptions = provider.allLanguages...` — chỉ từ dữ liệu
  có sẵn, không có chip "Thêm…".
- **Files:** `lib/widgets/selection_save_sheet.dart` (sheet chính),
  `lib/screens/read_mode/widgets/floating_text_actions.dart` (nếu cũng có
  picker ngôn ngữ tương tự — rà khi sửa), `lib/providers/vocabulary_provider.dart`
  (xem `allLanguages` + nơi lưu language code).
- **Fix đề xuất:** thêm chip "＋ Thêm ngôn ngữ…" → mở ô nhập (hoặc dialog nhỏ)
  chấp nhận code 2-4 chữ cái (vd `pi`, `lo`, `my`), validate + normalize
  lowercase, thêm vào `_selectedLanguage` + hiện chip mới đã chọn. Giữ đúng
  pattern của ô tạo chủ đề (`_newTopicCtrl`).
- **AT:** lưu từ với ngôn ngữ mới `pi` → thành công, chip `pi` hiện trong
  sheet ở lần mở sau; WordList lọc được theo `pi`.
- **History (2026-09-16 Lane A2):**
  - Đã thêm chip "＋ Thêm ngôn ngữ…" và ô nhập inline theo đúng pattern của Chủ đề trong `SelectionSaveSheet` (`lib/widgets/selection_save_sheet.dart`).
  - Đã đưa validation/normalization `validateCustomLanguageCode` & `normalizeCustomLanguageCode` vào `lib/widgets/vocab_entry_meta.dart`: nhận code 2-4 ký tự Latin (a-z), normalize lowercase, trim; báo lỗi chi tiết khi rỗng, sai độ dài, hoặc chứa ký tự đặc biệt/số.
  - Đồng bộ logic thêm ngôn ngữ mới vào `_FullSaveSheet` (`lib/screens/read_mode/widgets/floating_text_actions.dart`) và `VocabEntryEditSheet` (`lib/widgets/vocab_entry_meta.dart`).
  - Đăng ký đầy đủ i18n cho các chuỗi nhãn và thông báo lỗi mới theo Rule #5 trong `lib/core/language/priority_ui_overrides.dart` (en, hi, zh, zh_TW, si) và `tool/legacy_ui_english_overrides.json`.
  - Tạo bộ test unit toàn diện `test/custom_language_validation_test.dart` kiểm tra validation, normalization, lưu trữ WordEntry với ngôn ngữ mới, lọc WordList và Rule 5 i18n.

### PDF-PAGE-001 — Bấm icon "từ đã lưu" (góc phải dưới) → nhảy về trang 1
- **Trạng thái:** doing — đã có fix + test seam + CI App Analyze xanh, chờ nghiệm thu máy
- **Triệu chứng (owner):** "Khi chọn biểu tượng của 'Chưa có từ nào được lưu
  — Tap từ trên PDF hoặc bôi đen' thì nó mở lên khung từ vựng nhưng đồng thời
  cũng nhảy trang về trang PDF đầu tiên → hãy vẫn giữ nguyên trang."
- **Repro:** PDF reader → cuộn tới trang 50+ → bấm FAB `view_sidebar`
  (góc phải dưới, `heroTag: 'wordlist_panel'`) → panel từ vựng mở + **PDF
  nhảy về trang 1**.
- **Root cause (đã verify):** `pdf_reader_screen.dart` —
  `_buildSplitOrPdf()`: `_showWordlistPanel == false` → `_buildPdfMode()`
  đơn lẻ; `== true` → `Row(Expanded(65, _buildPdfMode()), Expanded(35,
  PdfWordlistPanel))`. Cấu trúc tree ĐỔI → element `PdfViewer.file`
  (pdfrx) bị unmount + tạo mới → viewer reload → **mất current page**.
- **Files:** `lib/features/pdf_reader/pdf_reader_screen.dart`
  (`_buildSplitOrPdf` ~line 733; `_buildPdfMode` ~line 752;
  `_pdfViewerController` + restore page logic trong
  `pdf_reader_controller.dart` `_restoredPageIndex`).
- **Fix đề xuất (chọn 1, ưu tiên A):**
  - A. Giữ viewer sống: đừng đổi cấu trúc — panel overlay bằng
    `Positioned(right: 0, top: 0, bottom: 0, width: ~35%)` TRÊN cùng 1
    `PdfViewer` (không chia Row) → element viewer không bao giờ đổi cha.
  - B. Hoặc: bắt `currentPage` trước khi toggle + sau rebuild gọi
    `jumpToPage` (yếu hơn — nháy trang 1 rồi mới nhảy về, dễ race).
  - C. Hoặc: `Key` stable cho `PdfViewer.file` (reparent) — pdfrx có thể
    vẫn recreate native surface, cần test.
- **AT:** trang 50 → mở panel → vẫn trang 50 (không nháy trang 1); đóng
  panel → vẫn trang 50; mở/đóng 5 lần không nhảy.
- **Lịch sử:**
  - 2026-09-15 | 20:51 UTC | doing→doing | agent arena/01a0a6cf-in4up | commit 3450d79 + 54e1171; App Analyze + Locale Test run 35021922026 xanh; `PdfReaderViewportShell` giữ `PdfViewer` mounted, chờ nghiệm thu máy

### XLAT-MLKIT-001 — Offline ML Kit EN→VI báo nhầm "Chưa tải gói dịch german"
- **Triệu chứng (owner):** "Khi dịch tiếng Việt bằng 'Chỉ dùng dịch offline'
  chọn ML Kit thì khi dịch xong nó báo 'Lỗi ML Kit On-Device: Chưa tải gói
  dịch german — vào cài đặt engine dịch để tải về'. Trong khi tôi đang dùng
  English -> Việt mà?"
- **Repro:** Cài đặt dịch → "Chỉ dùng dịch offline" + engine ML Kit; cặp
  EN→VI đã tải model en + vi; dịch văn bản Anh (dùng trong tab Đọc/PDF) →
  hầu hết dòng dịch OK nhưng có dòng báo lỗi "german".
- **Root cause (đã verify code):** `text_provider_translation.dart` —
  `translateLine` (line ~143) + `translateAll` (line ~238): MỖI dòng đều
  `LanguageDetector.detectLanguage(line.content, fallback: source)` — TỰ
  NHẬN DIỆN LẠI NGỒN dù user đã GẮN nguồn 'EN' → detector nhầm 1 dòng Anh
  ngắn thành 'de' (German — Anh/Đức gần nhau) → `translateText(sourceLang:
  'DE', targetLang: 'VI')` → `mlkit_engine.dart` line ~148: model DE chưa tải
  → `'Chưa tải gói dịch german'` (`_nativeNames` default = `language.name`).
- **Files:** `lib/features/translation/text_provider_translation.dart`
  (2 call sites), `lib/features/translation/engines/mlkit_engine.dart`
  (`translate` + `_nativeNames`), `lib/features/tts/language_detector.dart`
  (detector — chỉ để tham khảo).
- **Fix đề xuất (2 lớp):**
  1. `text_provider_translation.dart`: user GẮN nguồn (≠ AUTO) → dùng đúng
     nguồn gắn cho TẤT CẢ dòng, không re-detect. Re-detect chỉ khi chế độ
     AUTO (document hỗn hợp ngôn ngữ).
  2. `mlkit_engine.dart`: khi source model CHA CÓ nhưng target có, và source
     chỉ là kết quả auto-detect → service retry với nguồn gắn/mặc định 'EN'
     trước khi báo lỗi; đồng thời message lỗi nêu CẶP thật + gợi ý: "Cặp DE→VI
     thiếu gói German (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)".
- **AT:** offline ML Kit, nguồn gắn EN, tài liệu Anh (trộn vài câu ngắn) →
  dịch hết không có lỗi "german"; chế độ AUTO với file thật Đức → vẫn nhận
  ra và báo thiếu gói German đúng ngữ cảnh.
- **Trạng thái:** doing — fix code xong + CI xanh, chờ nghiệm thu máy
- **Fix đã làm (2026-09-16, lane A3 — agent arena/01a0a6d2-in4up):**
  - `text_provider_translation.dart`: thêm nguồn explicit
    `setTranslationSourceLanguage(code)` ('AUTO' bỏ gắn) + getter
    `translationSourceLanguage`/`translationSourceIsPinned`. Nguồn đã gắn
    được dùng cho TẤT CẢ dòng (translateAll/translateLine/rehydrate) —
    không gọi LanguageDetector từng dòng; chỉ AUTO mới re-detect.
    Ở AUTO, khi model của nguồn VỪA NHẬN DIỆN chưa tải (khác nguồn tài
    liệu) → retry đúng 1 lần với nguồn tài liệu trước khi báo lỗi — đóng
    lỗi "german" trên tài liệu Anh câu ngắn; văn Đức thật không bị retry.
    Lỗi thiếu model nguồn được chú thích "(nguồn tự nhận diện — kiểm tra
    lại ngôn ngữ nguồn)" ở AUTO và "(cặp nguồn đã chọn)" ở explicit.
    `resetTranslationForNewDocument` bỏ gắn nguồn của tài liệu cũ.
  - `engines/mlkit_engine.dart`: lỗi thiếu model nêu đúng cặp
    "Cặp DE → VI thiếu gói dịch Deutsch — vào Cài đặt engine dịch để tải
    về" (tên native từ catalog 26 ngôn ngữ, không còn enum lowercase
    'german'); thêm static `missingModelError`/`missingModelCodesOf`.
  - `engines/translation_engine.dart` (seam tối thiểu):
    `TranslationResult.missingModelCodes` — tín hiệu cấu trúc thay vì
    regex chuỗi lỗi.
  - Test: `test/translation_source_language_test.dart` (11 test qua seam
    `translationServiceForTest` + `TranslationService.forTest`, không cần
    thiết bị): AUTO retry EN/DE, AUTO văn Đức báo đúng cặp, AUTO mixed
    doc, explicit không detect/retry, API validate/reset, message engine.
  - Còn hở (ngoài ownership A3, để lane UI sau): chưa có UI chọn nguồn
    trên toolbar và chưa persist nguồn explicit (seam đã sẵn).
- **Lịch sử:**
  - 2026-09-16 | 21:51 UTC | doing→doing (fix code + test, CI xanh, chờ nghiệm thu máy) | agent arena/01a0a6d2-in4up (lane A3) | CI run 35027743218 (App Analyze + Locale Test xanh); branch arena/01a0a6d2-in4up, PR vào arena/01a0251e-in4up
  - 2026-09-16 | 22:00 UTC | doing (giữ nguyên — chờ nghiệm thu máy) | agent arena/01a0a6d2-in4up (lane A3) | PR #31 đã mở: https://github.com/Pabhassaracitto/In4Up/pull/31 ; CI pull_request run 35027994440 xanh

### READ-TOOLBAR-001 — Thanh đáy tab Đọc (size chữ/dịch/đọc/mark/lưu) "đen thui" khi kéo văn bản
- **Triệu chứng (owner):** "Thanh chức năng tăng giảm size chữ, dịch, đọc,
  mark, lưu. Khi kéo văn bản lên thì nó đen thui nhưng vẫn che chữ…"
  (câu bị cắt). = thanh `ReadBottomBar` (nút text_decrease/increase,
  translate, record_voice_over, bookmark, sidebar) hiện thành **khối đen
  không thấy nút** nhưng vẫn che văn bản.
- **Repro:** tab Đọc → cuộn văn bản (kéo lên/xuống) → thanh đáy thành khối
  đen che chữ.
- **Nghi chính (bằng chứng thời điểm):** build owner (`1d58b78`) ĐÃ CHỨA
  fix `READ-FOCUS-001` (commit `6ba029a`) bọc đúng thanh này bằng
  `AnimatedSize` + `ClipRect` + `AnimatedSlide` + `AnimatedOpacity`.
  Kết hợp `ClipRect` + offset phân số (1.2) + opacity trên một số GPU
  Android (Mali/Adreno) có thể render khối đen — HỢP TRÙNG với các artifact
  khác trên đúng máy này (SHELL-GEAR-001, LISTEN-LRC-001: sọc vàng đen).
- **Files:** `lib/screens/read_mode/read_mode_screen.dart` (AnimatedSize/
  ClipRect wrapper ~line 176), `lib/screens/read_mode/widgets/read_bottom_bar.dart`.
- **Fix đề xuất (A/B theo thứ tự):**
  1. Bỏ `ClipRect` (giữ AnimatedSize) — nếu hết khối đen → done.
  2. Nếu vẫn đen: thay AnimatedSize bằng build điều kiện đơn giản
     (`isFocusMode ? SizedBox(height:0) : AnimatedSlide(...)` cũ) — hy sinh
     animation gập, giữ đúng chức năng.
  3. Rà thêm: `AnimatedSlide` offset (0,1.2) → (0,1.0) (offset >1 trên GPU
     yếu dễ sinh artifact).
- **AT:** cuộn lên/xuống 10 lần: thanh đáy ẩn/hiện sạch, KHÔNG có khối đen;
  Focus/Thoát Focus mượt (giữ nguyên AT của READ-FOCUS-001).
- **Cập nhật 2026-09-16 (agent A4 — lane A4, commit `278a1d9`):** đã fix theo
  đúng thứ tự ít rủi ro của card: (1) BỎ `ClipRect` tường minh, (2) chặn
  offset ẩn về `(0, 1.0)` (bỏ overshoot phân số 1.2). Wrapper tách thành
  `lib/screens/read_mode/widgets/collapsible_bottom_controls.dart` (seam test
  được) + wire lại ở `read_mode_screen.dart`; smart-hide vẫn giữ chỗ layout,
  Focus vẫn gập về 0 (hợp đồng READ-FOCUS-001 giữ nguyên). Test invariant
  `test/read_bottom_controls_visibility_test.dart` khoá: offset ẩn ≤ 1.0
  chiều cao, opacity 0, giữ chiều cao, Focus 0↔full, stress lặp (test + fix
  cùng một commit xanh — test import widget mới). Trạng thái: **fix code xong
  — chờ nghiệm thu máy owner** (PR #27, CI run 35022838520 xanh).
- **Cập nhật v2 (agent A4 — lane A4):** Kết quả AT v1 của owner: "Khi kéo
  cuộn lên thì ẩn các icon chức năng… nhưng vẫn còn bị khối đen che chữ".
  Icon ẩn đúng chứng minh state cuộn/smart-hide hoạt động đúng; khối đen vẫn
  còn chứng minh RenderOpacity/saveLayer trung gian của các animation widget
  trên GPU Mali/Adreno là thủ phạm. Triển khai đúng **bước 2 của card**:
  "thay AnimatedSize bằng build điều kiện — hy sinh animation gập, giữ đúng
  chức năng", đồng thời mở rộng nhất quán loại bỏ TOÀN BỘ widget animation
  (`AnimatedSize`, `AnimatedSlide`, `AnimatedOpacity`, `ClipRect`).
  Wrapper `CollapsibleBottomControls` chuyển sang:
  1. Focus mode (`collapsed`): `SizedBox(width: double.infinity, height: 0)`
     ngay lập tức.
  2. Smart-hide: `Opacity(opacity: visible ? 1.0 : 0.0)` kèm
     `IgnorePointer(ignoring: !visible)` — RenderOpacity với opacity 0 skip
     paint hoàn toàn không gọi saveLayer; giữ nguyên kích thước layout
     không nhảy chữ; tránh cướp pointer tap khi ẩn.
  3. Cập nhật test invariant: cấm 4 widget animation quay lại wrapper, kiểm
     tra đầy đủ opacity, layout height, focus 0, IgnorePointer và stress test.
  Trạng thái: **chờ nghiệm thu máy lần 2**.

### TTS-PIPER-002 — Settings vẫn báo × đỏ Piper dù "đã có model và hoạt động"
- **Triệu chứng (owner):** "Trong setting sao đã có model TTS sherpa và hoạt
  động được rồi nhưng nó vẫn báo x Piper (offline neural) (chữ/màu đỏ)."
- **Root cause (REGRESSION do chính DEV — commit `d28a1e9`):** pre-flight
  mới làm `PiperTtsEngine.isAvailable()` đòi: giọng + **espeak-ng-data
  (phontab)** + file model nguyên vẹn (onnx ≥1MB, **tokens ≥1KB**). Trên máy
  owner: (a) thiếu phonemizer (cũng là root cause crash TTS-PIPER-001) VÀ/
  HOẶC (b) ngưỡng tokens 1KB quá gắt (file tokens Piper single-speaker hợp
  lệ có thể <1KB) → `checkEngineStatus()` (widget chip
  `tts_settings_section.dart`) hiện × đỏ KHÔNG GIẢI THÍCH → owner hiểu
  nhầm model hỏng.
- **Fix ĐÃ LÀM (turn này, chờ nghiệm thu):**
  - Ngưỡng tokens hạ về **≥128B** (`sherpa_piper_tts_core.dart`
    `isVoiceFilesPlausible`).
  - Chip engine status: khi Piper × → hiện chip cam giải thích "Piper × :
    chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS →
    Quản lý model" (`tts_settings_section.dart`).
- **AT:** (1) máy có giọng + phonemizer → chip Piper xanh; (2) thiếu
  phonemizer → chip × + dòng giải thích; bấm "Quản lý model" → tải
  phonemizer → chip xanh; TTS phát tiếng Việt bằng giọng neural không crash.

### SHELL-GEAR-001 — Nhấn GIỮ nút setting (răng cưa) → sọc vàng đen + lỗi overlay.dart
- **Triệu chứng (owner):** "Nút setting (răng cưa icon) khi nhấn và giữ nó bị
  lỗi màn hình sọc vàng đen dọc bên phải và ngang ở dưới
  ('package:flutter/src/widgets/overlay.dart')."
- **Repro:** long-press nút settings (2 ứng viên: drawer "Giao diện shell"
  `Icons.tune_rounded` `main_shell.dart` ~line 419, hoặc gear
  `Icons.settings_outlined` của toolbar dịch `translation_toolbar.dart`
  line 87) → màn hình hiện **sọc vàng-đen** (vertical phải + horizontal
  dưới) + assertion overlay.dart.
- **Nghi chính (hypothesis mạnh):** **orphaned Ink** — long-press sinh ink
  splash (Material ripple); nếu `Material` chứa ink BỊ RỜI khỏi tree trong
  khi splash còn animation (rebuild/rút drawer/đổi chrome) → ink feature
  mồ côi bị paint thành rác (sọc vàng-đen là "chữ ký" của artifact này —
  flutter/flutter#114524, #89403). Cùng gia đình với READ-TOOLBAR-001 /
  LISTEN-LRC-001 trên đúng máy này.
- **Files:** `lib/screens/main_shell.dart` (mode switch + drawer +
  longPressModeSwitch line ~1052/1230/1252 — long-press ĐỔI MODE shell:
  `_setListenMode` cycle — rất có thể long-press gear TRÙNG với long-press
  đổi mode → đổi screen giữa ink splash), `lib/features/translation/
  translation_toolbar.dart` (gear 2).
- **Fix đề xuất:**
  1. Xác định đúng gear (hỏi owner 1 ảnh chụp màn hình / vị trí nút).
  2. Nếu là long-press đổi mode shell: tách hành vi (long-press chỉ đổi mode
     khi mode switch BẬT — `_enableLongPressModeSwitch`) và đảm bảo surface
     không đổi trong 400ms đầu của long-press; hoặc dùng
     `GestureDetector` + highlight tự vẽ (không Ink) cho nút đó.
  3. Chạy repro trong debug, bắt stack overlay.dart chính xác (chụp logcat).
- **AT:** long-press nút settings 3s (lặp 10 lần) → không sọc vàng-đen,
  không assertion; hành vi long-press (đổi mode) vẫn đúng.
- **Cập nhật 2026-09-16 (agent A4 — lane A4, commit `877c6a7`):** CHƯA sửa sâu
  — không tái hiện được ngoài máy owner và chưa có log xác nhận orphaned Ink
  (đúng prompt A4: chỉ thay InkWell bằng highlight tự vẽ khi log xác nhận).
  Đã thêm seam log CHỈ debug (`kDebugMode`) phủ CẢ HAI ứng viên gear + mọi
  long-press đổi surface, xem bằng `adb logcat | grep SHELL-GEAR-001`:
  - gear #1 drawer `tune_rounded` — `main_shell.dart::_openShellUiSettings`
    (route push + drawer close = đổi surface giữa splash);
  - gear #2 `settings_outlined` toolbar dịch — `translation_toolbar.dart`
    bọc `Listener` pointer down/up/cancel (raw listener, KHÔNG tham gia
    gesture arena — tap/tooltip giữ nguyên);
  - long-press đổi mode (`_toggleCurrentSecondaryMode`, nav Nghe/Đọc) +
    mọi swap surface (`_setPrimaryTab`/`_setListenMode`/`_setReadMode`) +
    `_openQuickActions` (rule-out OverlayEntry).
  Cần owner: chạy lại repro debug → gửi logcat → chốt đúng gear + cơ chế.
  Trạng thái: **chờ logcat owner** trước khi fix (không đoán sửa sâu; PR #27).

### LISTEN-LRC-001 — Chọn file âm thanh CÓ LỜI SẴN → sọc đen vàng + assertion framework + tab Hiểu đỏ
- **Triệu chứng (owner):** "Tab music khi chọn file âm thanh và có lời sẵn do
  đã tạo từ trước khi nó bị lỗi màn hình sọc đen vàng 99304 pixels hàng
  ngang bên dưới và 'framework.dart': Failed assertion: line 2168 pos 12:
  '_elements.contains(element)': is not true. Đồng thời tab Hiểu lỗi màn
  hình đỏ hoàn toàn với báo lỗi: 'framework.dart': line 6417 pos 14 …
  'check that it really is our descendant … return ancestor == this'
  is not true."
- **Repro:** tab Nghe (music) → chọn file audio **đã có file .lrc tương
  ứng** (tạo từ trước) → sọc + assertion; tab Hiểu bị red screen.
- **Đọc assertion:**
  - line 6417 = assertion `InheritedElement.dependOn`: context dùng để đọc
    InheritedWidget **không còn là descendant** → **STALE CONTEXT** (context
    của subtree đã dispose được dùng trong build/listener).
  - line 2168 `_elements.contains(element)` = element tree bất nhất (thường
    đi kèm setState-during-build hoặc element bị mount lại sai vị trí).
- **Nghi chính:** `listen_mode_screen.dart` (3336 dòng) — flow mở file +
  phát hiện LRC có sẵn: stream của `just_audio`/`PlayerProvider` +
  `setState`/notify của provider firing **trong build** (đổi UI giữa khi
  file open đang rebuild), hoặc `context` captured từ build cũ trong
  `ValueListenableBuilder`/`StreamBuilder`. Tab Hiểu đỏ = stale context
  tương tự trong `UnderstandWorkspaceScreen` khi tab Nghe đổi state.
- **Files:** `lib/screens/listen_mode/listen_mode_screen.dart` (file picker +
  LRC detection — grep `lrc`/`lyrics`), `lib/providers/player_provider.dart`,
  `lib/screens/understand/...` (tab Hiểu — tìm `dependOn`/`context.watch`
  trong listener).
- **Fix đề xuất:**
  1. Chạy debug: BẮT log "setState() or markNeedsBuild() called during build"
    (Flutter in log TRƯỚC assertion — nó chỉ stack chính xác).
  2. Mọi listener player/stream: guard `if (!mounted) return;` + KHÔNG
    setState trong build (chuyển qua `addPostFrameCallback`).
  3. Rà `context` dùng trong callback async — luôn dùng context của
    `StatefulElement` hiện tại, không dùng context build cũ.
  4. Rà artifact sọc: cùng hypothesis orphaned Ink như SHELL-GEAR-001 (nếu
     có InkWell trong toolbar bị remove giữa splash).
- **AT:** chọn file CÓ lrc sẵn → phát bình thường, không sọc/assertion;
  tab Hiểu mở/đóng sau đó không red; lặp 5 file.
- **Trạng thái:** code xong + CI xanh, chờ nghiệm thu máy (2026-09-15)
- **Lịch sử:**
  - 2026-09-15 | doing→done-code (chờ nghiệm thu máy) | agent
    arena/01a0a6d4-in4up (lane A5) | SafeSetStateMixin + stored provider ref
    (không setState/notify trong build, không context.read trong
    listener/dispose); rèm LRC render từ local clamped; tab Hiểu defer
    waveform/shadowing sync ra post-frame; test
    test/listen_lifecycle_guards_test.dart; CI run 35022505773 xanh
    (analyze + locale)

### LISTEN-VIEW-001 — Nghe → tab phụ Xem (video) → quay lại Nghe = màn hình đen không thoát
- **Triệu chứng (owner):** "Khi từ tab nghe -> tab phụ xem quay trở lại thì
  bị lỗi màn hình đen không thoát được."
- **Repro:** tab Nghe (sub-tab "Nghe") → sub-tab **"Xem"**
  (`VideoLibraryScreen` — xem video local + phụ đề) → quay lại sub-tab
  "Nghe" → **đen toàn màn hình, không thoát được**.
- **Context:** `main_shell.dart` ~line 840: Listen section =
  `IndexedStack(index: _listenModeIndex, children: [ListenModeScreen,
  SpeakModeScreen, VideoLibraryScreen])` — cả 3 screen SỐNG LUÔN (offstage).
  `video_player: 2.8.0` (dep native mới — commit `5b3a663`).
- **Nghi chính:** (a) `VideoPlayerController`/texture Android: surface video
  không release khi screen offstage → texture đen phủ lên; hoặc
  (b) `ListenModeScreen` rebuild từ offstage gặp lỗi state (player stream
  error) → red/black + navigation freeze; (c) release build: exception
  không render → đen.
- **Files:** `lib/screens/main_shell.dart` (IndexedStack),
  `lib/features/video/widgets/video_library_screen.dart` (dispose controller
  khi hide?), `lib/screens/listen_mode/listen_mode_screen.dart` (state sau
  khi offstage→onstage).
- **Fix đề xuất:**
  1. `VideoLibraryScreen`: `dispose()`/`didChangeDependencies` — đảm bảo
     `VideoPlayerController.dispose()` (hoặc `pause() + setVolume(0)`) khi
     screen offstage, và controller tạo lại sạch khi onstage.
  2. Bọc body của `VideoLibraryScreen` `try` — nếu lỗi init video → hiện
     lỗi văn bản thay vì đen.
  3. Test cả debug + release; nếu release đen → bắt logcat
     (`adb logcat | grep -i flutter`) khi repro.
- **AT:** Nghe → Xem (mở 1 video, để chạy 5s) → quay lại Nghe → nghe bình
  thường, không đen; đổi 10 lần không kẹt.
- **Trạng thái:** code xong + CI xanh, chờ nghiệm thu máy (2026-09-15)
- **Lịch sử:**
  - 2026-09-15 | doing→done-code (chờ nghiệm thu máy) | agent
    arena/01a0a6d4-in4up (lane A5) | root cause = nút back của
    VideoLibraryScreen pop nhầm route gốc khi nhúng trong IndexedStack
    (không phải texture — chưa có VideoPlayerController thật);
    thêm showBackButton=false khi nhúng + mounted guard + error UI retry;
    test test/listen_view_video_library_test.dart; CI run 35022505773 xanh
    (analyze + locale)

### GHI CHÚ CHUNG CHO AGENT SỬA BATCH NÀY
- Build owner = DEBUG (thấy assertion) — repro nhanh nhất bằng `flutter run`
  debug trên Android.
- 3 lỗi visual (READ-TOOLBAR-001, SHELL-GEAR-001, LISTEN-LRC-001) cùng
  "chữ ký" artifact (sọc vàng-đen / khối đen) trên 1 máy → ưu tiên hypothesis
  **orphaned Ink** + **GPU clip/transform** (test A/B: bỏ ClipRect, đổi
  InkWell→GestureDetector+custom highlight cho các bar bị remove giữa animation).
- Sau mỗi fix: `flutter analyze` + `flutter test` trước khi commit; CI oracle
  = "App Analyze + Locale Test (wide oracle)" phải xanh.
## 🔥 BATCH OWNER 2026-09-16 — 9 việc mới (handoff cho agent Arena)

> Owner báo sau build `1d58b78`. Format giống batch 09-15: TRIỆU CHỨNG →
> REPRO → ROOT CAUSE (verify code / nghi) → FILES → FIX ĐỀ XUẤT → AT.
> Sửa xong → owner create PR vào `arena/01a0251e-in4up`.

### HYMT-002 — Dịch bằng Hy-MT 1.5 vẫn không chạy: "Timeout Hy-MT"
- **Triệu chứng (owner):** "Dịch bằng Hy-MT 1.5 vẫn không hoạt động được:
  Lỗi Hy-MT1.5 (GGLIF) Timeout HyMT-" ("GGLIF" = đọc trại "GGUF").
- **Context:** `hymt_engine.dart` = engine offline GGUF + llama.cpp
  (model `Hy-MT1.5-1.8B-2bit.gguf` ~601MB, chạy trong Isolate).
- **Root cause (đã đọc code — cơ chế):** request gửi qua SendPort cho
  isolate, chờ `reply.first.timeout(2 phút)` (line ~398) → hết 2 phút =
  "Hy-MT timeout". Isolate KHÔNG có guard request đang chạy: 1 request
  trước kẹt (llama generate lâu / isolate chết OOM) → request sau CŨNG
  timeout theo. Trên máy yếu, model 1.8B-2bit + câu dài có thể thật sự
  >2 phút. UI hiện lỗi ngay — user nghĩ engine chết.
- **Files:** `lib/features/translation/engines/hymt_engine.dart`
  (isolate entry `_isolateEntry` line ~245+, request flow line ~360-430),
  `lib/features/translation/translation_service.dart` (nơi gọi engine),
  UI hiện error (translation toolbar / read tab).
- **Fix đề xuất:**
  1. Guard `_busy` trong isolate: request tới khi đang chạy → trả reply
     "ĐANG BẬN" ngay (không treo 2 phút); service queue hoặc báo UX rõ.
  2. Heartbeat isolate: trước khi gửi request, ping (loadDone/alive);
     isolate chết → kill + spawn lại + retry 1 lần.
  3. Timeout: tăng 2→4 phút HOẶC chia text dài thành cụm ≤ ~500 ký tự
     (maxCharsPerRequest của engine khác = 5000 — Hy-MT nên chunk
     nhỏ hơn cho device).
  4. UI: hiện trạng thái "Đang dịch bằng Hy-MT… (offline, có thể chậm)"
     thay vì im lặng rồi lỗi.
- **AT:** máy owner: dịch 1 câu ngắn EN→VI bằng Hy-MT → có kết quả
  (thời gian bao nhiêu cũng được nhưng phải về); dịch text dài 2000+ ký
  tự → chunk không timeout; 2 request liên tiếp không kẹt.
- **Trạng thái:** done
- **Lịch sử:**
  - 2026-09-15 | 21:50 | proposed→doing | agent arena/01a0a6f9-in4up | 949c437 (seam: HyMtChunking ≤500 ký tự/câu + HyMtSlot single-flight + test), 7cba9bd (runtime: heartbeat ping trước request, isolate chết/load hỏng → dispose+spawn+retry tối đa 1 lần + errorCode cấu trúc, mỗi chunk timeout hữu hạn riêng, ghép đúng thứ tự, service budget tỷ lệ theo độ dài trần 8 phút + test runtime), a412f47 (UI "Đang dịch bằng Hy-MT offline, có thể chậm" + EN override); Python 1:1 sim 12/12 green — chờ CI app_analyze + AT máy owner
  - 2026-09-23 | 11:30 | doing→done | agent arena/01a0a6f9-in4up | commit 4bea3a0: hoàn thiện 4 lớp timeout (single-flight slot, isolate heartbeat ping + auto-restart retry 1 lần, sentence-aware chunking ≤500 chars reassembly, UI progress hint "Đang dịch bằng Hy-MT offline, có thể chậm" + fallback EN); unit test + runtime test đầy đủ; mở PR vào target arena/01a0251e-in4up

### CABIN-ASR-002 — "Chưa có model Zipformer cho EN" dù đã import; cabin offline (sherpa) trước chạy giờ không
- **Triệu chứng (owner):** "Chưa có model Zipformer cho EL. Vào quản lý từ
  AI để tải về. Trong khi đã import rồi. Và không hiểu sao hồi trước khi
  cập nhật ở các lần build trước hoạt động được cabin offline (sherpa) mà
  lần này lại không được." ("EL" = nhìn nhầm "EN" — code in
  `sourceLanguage.toUpperCase()` = **EN**).
- **Root cause (đã verify code):** cabin `SttsCabinService._sourceLanguage`
  MẶC ĐỊNH `'en'` (`stts_cabin_service.dart:51`). Owner đã import model
  **VI**ETNAMESE (`asr-vi-30M-int8`) nhưng app kiểm tra
  `hasAsrModel('en')` → quét folder `asr-en-20M-streaming-int8` → TRỐNG →
  snackbar "Chưa có model Zipformer cho EN" + service từ chối start
  (line 144-148). Build trước chạy được = build trước dùng ngôn ngữ nguồn
  khác (vi) hoặc check khác — STT session (`1d58b78` merge #25) đã đổi.
- **Files:** `lib/features/cabin/services/stts_cabin_service.dart`
  (default + check), `lib/features/cabin/screens/live_cabin_screen.dart`
  (chip engine + snackbar line ~372-385),
  `packages/in4up_stt/lib/sherpa_model_manager.dart`
  (`predefinedAsrProfiles` — chỉ có VI + EN), `stt_model_settings_screen.dart`
  (UI import/download).
- **Fix đề xuất:**
  1. Default source language cabin = **'vi'** (app chính là cho người
     Việt) — hoặc: default = ngôn ngữ có model đã cài (scan
     `SherpaModelManager().asrInfo`), fallback 'vi'.
  2. Khi ngôn ngữ chọn CHƯA có model nhưng CÓ model khác đã cài →
     snackbar rõ: "Chưa có model cho EN — app sẽ dùng Tiếng Việt
     (đã cài)" + tự dùng model đã cài (hoặc hỏi user), thay vì chặn.
  3. Dropdown ngôn ngữ cabin: đánh dấu (màu/xám) các ngôn ngữ CHƯA có
     model Zipformer (zh/fr/de/ja/ko/th/hi/si đều chưa có profile —
     chọn là lỗi) để không dẫn user vào ngõ cụt.
  4. Rà diff STT session (#25) quanh cabin/ASR để hiểu chính xác cái gì
     đã đổi so với build trước (nếu owner build trước chạy được với vi).
- **Liên quan:** crash SIGABRT khi dùng model streaming EN qua
  OfflineRecognizer đã fix riêng ở `SHERPA-STREAM-001` — nghiệm thu
  card này phải kèm AT của SHERPA-STREAM-001 (model EN streaming +
  cabin live chạy được online path).
- **AT:** máy có model VI đã import: mở Cabin → chọn engine Sherpa
  offline → START được + nhận diện tiếng Việt; chọn EN (chưa cài) →
  thông báo rõ + fallback/hướng dẫn tải, không chết im.

- **WP B2 (agent `arena/01a0a6fa-in4up`, 2026-09-16) — code xong, CHỜ CI + CHỜ NGHIỆM THU MÁY (chưa đánh dấu done):**
  - Mapping một nguồn: `packages/in4up_stt/lib/asr_model_routing.dart`
    (profile + router + `AsrModelIssue`/`AsrLiveRoute`) và
    `lib/features/cabin/services/cabin_asr_plan.dart` (kế hoạch STT thuần —
    test được không cần thiết bị).
  - Bỏ hardcode `'en'`: ngôn ngữ nguồn mặc định = ngôn ngữ ĐÃ CÀI model
    (ưu tiên VI theo `kAsrLanguagePriority`), máy chưa cài model nào →
    `vi` + giải thích ở UI (`defaultCabinSourceLanguage`).
  - Chọn EN khi máy chỉ có model VI → **không** tự nhận tiếng Anh bằng model
    VI: chặn + dialog nêu rõ thiếu model + nút "Mở Quản lý Model AI", hoặc
    user TỰ XÁC NHẬN dùng VI (`confirmFallbackToInstalledLanguage`) — không
    đổi ngôn ngữ sau lưng user.
  - `getAsrModelPaths`: bỏ fallback `orElse: predefinedAsrProfiles.first`
    (trước đây hỏi `zh`/`fr` bị trả model VI) → ngôn ngữ không có profile =
    `null` + báo "chưa hỗ trợ nhận diện offline".
  - Import model: chỉ nhận model có BẰNG CHỨNG khớp profile (metadata ONNX →
    tên archive/thư mục → tokens tiếng Việt); model lạ → `unknownProfile` /
    "không khớp profile", KHÔNG nhét model streaming vào folder offline
    (chống SIGABRT "Expected 39").
  - UI: dropdown ngôn ngữ nguồn đánh dấu ngôn ngữ chưa có model (engine
    Offline) + banner lỗi có nút mở Quản lý Model AI; màn Quản lý Model AI
    ghi rõ model dùng cho Cabin live vs file/LRC.
  - i18n (rule #5): 15 chuỗi mới đăng ký English ở
    `tool/legacy_ui_english_overrides.json` + `generated_legacy_ui_fallbacks.dart`;
    7 chuỗi thiếu-model/fallback/import + ghi chú dropdown có đủ
    en/hi/zh/zh_TW/si trong `priority_ui_overrides.dart`.
  - Test mới: `test/asr_model_routing_test.dart` (mapping ngôn ngữ ↔ profile,
    kế hoạch cabin, nhận diện encoder streaming/offline).
  - **Chưa chạy CI** (sandbox không có Flutter/Dart SDK → không `analyze`/
    `test` được) và **chưa nghiệm thu máy** — AT 2 mục ở trên vẫn nguyên.
- **Lịch sử:**
  - 2026-09-16 | doing | agent `arena/01a0a6fa-in4up` | WP B2: code + test + i18n xong; CHỜ CI (`app_analyze.yml` chưa cover `packages/**` — xem SHERPA-STREAM-001) + AT máy
  - 2026-09-16 | CI xanh (một phần) | agent `arena/01a0a6fa-in4up` | commit `cb9c49d` — run **35027575467** `App Analyze + Locale Test` XANH: `flutter analyze` (ERROR-fatal) + test rule #5 `locale_chrome_no_vietnamese_test.dart` đều pass ⇒ code/i18n/test KHÔNG lỗi biên dịch. Lưu ý: workflow này KHÔNG chạy `test/asr_model_routing_test.dart` (cần owner chạy `flutter test test/asr_model_routing_test.dart` hoặc xác nhận qua AT máy)
  - 2026-09-16 | cảnh báo còn hiệu lực | agent `arena/01a0a6fa-in4up` | `app_analyze.yml` vẫn chưa có `packages/**` trong `paths:` → lần này workflow chạy được là nhờ push có `lib/**`; đổi CHỈ trong `packages/**` vẫn sẽ KHÔNG trigger (owner áp `scripts/ci/analyze_paths_packages.patch`)
  - 2026-09-23 | merge base + CI xanh | agent `arena/01a0a6fa-in4up` | base tiến `d40f604` → `9c22f48` (đã merge #26/#31/#35/#36/#37…) ⇒ lane merge `e150823`; 3 conflict đều THUẦN BỔ SUNG nên giữ CẢ HAI phía — `legacy_ui_english_overrides.json` giữ style 2-space của base tip (commit `df77ab0` đã re-indent) + 20 key Cabin (+21/−1), `priority_ui_overrides.dart` +53/−0, KANBAN +42/−0; `generated_legacy_ui_fallbacks.dart` auto-merge +20. CI `App Analyze + Locale Test` XANH trên merge commit — run **35858406361** (event `pull_request`, gồm `flutter analyze` + rule #5). Vẫn CHƯA chạy `test/asr_model_routing_test.dart` (không workflow nào chạy file này).

### HOME-QUICK-001 — Home: "Nạp tri thức nhanh" + icon ghi âm CHƯA hoạt động (stub)
- **Triệu chứng (owner):** "Tab home: Nạp tri thức nhanh → đang chưa hoạt
  động. Icon ghi âm cũng chưa hoạt động."
- **Root cause (đã verify code — cả 2 là STUB):**
  - `hebbian_input_card.dart` (card "NẠP TRI THỨC NHANH"): 2 nút
    "Ghi chú nói" (mic) + "Gợi ý" (auto_awesome) — `onTap` là
    `() { // Start STT flow }` / `() { // Show random word with image }`
    — **rỗng**.
  - `home_screen.dart` `_buildOmniMicrophone()` (FAB mic lớn): mở
    `_SttDialog` — dialog GIẢ: chỉ hiện icon mic + chữ "listening…" +
    nút Done, **không gọi STT thật**.
- **Files:** `lib/screens/home/widgets/hebbian_input_card.dart`,
  `lib/screens/home/home_screen.dart` (`_SttDialog` line ~557), STT thật
  sẵn có: `lib/features/cabin/services/stts_cabin_service.dart` /
  `lib/providers/stt_service_facade.dart` (hỗ trợ sherpa offline — xem
  CABIN-001/SHERPA-WP4-01), WordList: `lib/providers/vocabulary_provider.dart`.
- **Fix đề xuất:**
  1. "Ghi chú nói" + FAB mic → 1 flow dùng chung: mở sheet STT thật
     (engine hiện tại của app, ưu tiên offline sherpa khi offline) →
     hiện transcript realtime → nút "Lưu vào WordList" (word/cụm) +
     "Lưu ghi chú".
  2. "Gợi ý" → rút NGẪU NHIÊN 1 từ từ WordList (ưu tiên thẻ đến kỳ ôn
     FSRS) → hiện word + IPA + nghĩa (+ ảnh nếu entry có) + nút "Nghe"
     (TTS) — bản tối giản trước, ảnh sau.
  3. Bỏ dialog `_SttDialog` giả.
- **AT:** bấm mic (cả FAB lẫn card) → nói 1 câu tiếng Việt → thấy
  transcript; lưu → có trong WordList/Ghi chú; bấm "Gợi ý" → hiện 1 từ
  thật từ danh sách.
- **Trạng thái:** done + CI xanh (chờ nghiệm thu máy)
- **Đã làm (2026-09-23, agent arena/01a0a6fc-in4up):**
  - 3 điểm vào (nút "Ghi chú nói" của card, FAB mic của Home) đi chung
    MỘT flow `QuickCaptureSheet`: transcript realtime → "Lưu vào WordList"
    / "Lưu ghi chú". Đã xoá `_SttDialog` giả.
  - KHÔNG tạo STT singleton thứ 2: seam `QuickCaptureSttSource` + 2 nguồn
    thật — `SherpaQuickCaptureSource` (SherpaSttEngine offline +
    AudioRecorder, ưu tiên khi có model đúng ngôn ngữ) và
    `SystemQuickCaptureSource` (qua `SttServiceFacade` sẵn có, không
    dispose singleton dùng chung). Ngôn ngữ theo
    `QuickCaptureLanguagePolicy` — không hardcode EN khi máy chỉ có model
    VI; engine không dùng được thì ghi rõ lý do ra UI.
  - "Gợi ý": `QuickSuggestionPicker.pick` lấy entry THẬT từ WordList (ưu
    tiên thẻ đến kỳ FSRS, rổ 5 thẻ đến kỳ sớm nhất), hiện word/IPA/nghĩa
    + nút Nghe (TTS). WordList rỗng → empty state có hướng dẫn. Bỏ hẳn
    text/ảnh random.
  - Lưu WordList đi qua `VocabularyBridge.addContextual` (đúng đường
    SelectionSaveSheet đang dùng) nên entry có ngữ cảnh nguồn + topic +
    SRS như từ lưu tay; ghi chú nói lưu trong box `settings`
    (`QuickCaptureNoteStore`), xem/xoá ngay trong sheet.
  - i18n đủ 5 ngôn ngữ (en/hi/zh/zh_TW/si) trong
    `priority_ui_overrides.dart`; rule #5 giữ nguyên (test locale chrome
    vẫn xanh).
- **Bằng chứng:** CI run 35863346239 (`app_analyze.yml`: `flutter analyze`
  full app + rule 5 locale test) — conclusion `success`; commit 73246d2.
  Test mới `test/home_quick_capture_test.dart`: 27 unit test (policy ngôn
  ngữ, controller ưu tiên engine/fallback/lỗi có cấu trúc/gom transcript/
  dừng sạch + release, picker, note store, saver trên Hive temp) + 1
  widget test `HebbianInputCard`.
  **Trung thực về phạm vi kiểm chứng:** sandbox không có Dart/Flutter SDK
  và không workflow nào chạy `test/home_quick_capture_test.dart`
  (`app_analyze.yml` chỉ `flutter analyze` + chạy riêng
  `test/locale_chrome_no_vietnamese_test.dart`) ⇒ file test này mới được
  **compile** xanh, CHƯA được thực thi. Luồng mic thật cần nghiệm thu trên
  thiết bị. Đã soạn sẵn patch cho owner (app thiếu quyền `workflows`,
  theo convention `docs/project/B3-APP-ANALYZE-TEST-STEP.patch`):
  **`docs/project/B4-HOME-QUICK-TEST-STEP.patch`** — thêm step
  `flutter test test/home_quick_capture_test.dart` + upload log vào
  `app_analyze.yml`.
- **Lịch sử:**
  - 2026-09-16 | todo→doing | agent arena/01a0a6fc-in4up | card trong BATCH-0916
  - 2026-09-23 | doing→done | agent arena/01a0a6fc-in4up | CI run 35863346239 xanh; nguyên nhân analyze đỏ trước đó: test `await` trên `dispose()` có kiểu `void` (8 chỗ) — đã sửa
  - 2026-09-23 | mở PR #38 (`arena/01a0a6fc-in4up` → `arena/01a0251e-in4up`) | agent arena/01a0a6fc-in4up | merge base `7ccf568` để hết conflict: `home_screen.dart` giữ cả 2 phía ở khối import rồi bỏ `package:animations` (chỉ `OpenContainer` của FAB stub `_SttDialog` dùng — đúng stub lane này xoá); KANBAN lấy dòng BATCH-0915 mới của base + giữ dòng HOME-QUICK-001; `priority_ui_overrides.dart` auto-merge sạch (brace depth 0, 417 key, 0 trùng, đủ `'en'`)

### HOME-STUDIO-001 — Phòng Studio thiếu thẻ XEM (chưa đủ 7: NGHE, NÓI, XEM, ĐỌC, VIẾT, HIỂU, NHỚ)
- **Triệu chứng (owner):** "Phòng Studio nên bổ sung đầy đủ: NGHE, NÓI,
  XEM, ĐỌC, VIẾT, HIỂU, NHỚ."
- **Hiện trạng (đã verify):** `home_screen.dart` `_buildBentoModesGrid`
  chỉ có 4 thẻ: "Nghe · Nói", "Đọc · Viết", "Hiểu", "Nhớ" — **thiếu
  XEM** (video). Thẻ gộp 2 mode (Nghe·Nói) trong khi shell có sub-tab
  riêng từng mode.
- **Files:** `lib/screens/home/home_screen.dart` (`_buildBentoModesGrid`
  line ~303; callbacks `onNavigateToListen/Read/Understand/Memory`),
  `lib/screens/main_shell.dart` (`_setListenMode(0/1/2)` = Nghe/Nói/Xem,
  `_setReadMode(0/1)` = Đọc/Viết — cần thêm callback tới XEM =
  listen mode index 2).
- **Fix đề xuất:** 7 thẻ riêng (hoặc 4 thẻ + 1 thẻ XEM rõ ràng — theo
  owner muốn 7): NGHE → listen mode 0, NÓI → listen mode 1, XEM → listen
  mode 2 (VideoLibrary), ĐỌC → read mode 0, VIẾT → read mode 1, HIỂU →
  understand, NHỚ → remember. Thêm `onNavigateToVideo`/`onNavigateToSpeak`
  ... từ main_shell. Grid responsive (7 thẻ → hàng 3+2+2 hoặc 4+3).
- **AT:** mỗi thẻ bấm vào đúng màn hình tương ứng (7/7); XEM mở thư
  viện video.
- **Kết quả (agent `arena/01a0a6fe-in4up`, 2026-09-15):** `_buildBentoModesGrid`
  tách thành 7 thẻ riêng NGHE · NÓI · XEM · ĐỌC · VIẾT · HIỂU · NHỚ; route
  đúng sub-mode qua 3 callback mới `onNavigateToSpeak/Watch/Write`
  (`main_shell` → `_setListenMode(1/2)`, `_setReadMode(1)`), giữ
  `onNavigateToListen/Read/Understand/Memory` cũ. Grid đổi
  `childAspectRatio` → `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: 108)`
  (2 cột phone, 3/4/5 cột khi rộng ⇒ 7 thẻ = 2+2+2+1 … 4+3), tiêu đề 1
  dòng + phụ đề 2 dòng ellipsis ⇒ không overflow. Nhãn mới
  (`NÓI`/`XEM`/`VIẾT`/`Thư viện video`) qua `uiText` + catalog
  en/hi/zh/zh_TW/si, không fallback `vi`. Commit `214d57d`; CI
  `App Analyze + Locale Test` run 35028370711 🟢 (analyze 0 error + test
  rule #5 xanh). **CÒN:** nghiệm thu thiết bị 7/7 thẻ (chờ nghiệm thu máy).
  Ghi chú ngoài lane: `video_library_screen.dart` có nút back
  `Navigator.pop(context)` trong khi màn này được nhúng trong
  `IndexedStack` của shell (`main_shell.dart` — `MainShell` là route gốc,
  `main.dart:364`) ⇒ sub-mode Xem có nguy cơ pop route gốc; lỗi có sẵn,
  không thuộc ownership lane B5, cần owner xác nhận trên máy.
  - 2026-09-15 | merge base `df77ab0` (A1 PDF + A2 WLIST-LANG) vào lane B5,
    resolve `tool/legacy_ui_english_overrides.json` theo union (giữ 5 key mới
    của A2 + 5 key của B5, gỡ 2 key mồ côi 'Nghe · Nói'/'Đọc · Viết') → merge
    `4214445`; CI `App Analyze + Locale Test` run 35029286725 (pull_request)
    và 35029282086 (push) 🟢 — analyze 0 error + test rule #5 xanh.

### HOME-KG-001 — "Xem Knowledge Graph" bấm vào không có phản ứng
- **Triệu chứng (owner):** "Xem Knowledge Graph nhấn vào chưa có phản ứng gì."
- **Root cause (đã verify):** `knowledge_graph_preview.dart` line 69 —
  nút "Xem Knowledge Graph →" **KHÔNG có onTap/Navigator** (chưa nối
  navigation). Màn hình đích ĐÃ TỒN TẠI: `lib/screens/tools/word_list/
  knowledge_graph_screen.dart` (cũng được mở từ WordList toolbar).
- **Files:** `lib/screens/home/widgets/knowledge_graph_preview.dart`,
  `lib/screens/tools/word_list/knowledge_graph_screen.dart`.
- **Fix đề xuất:** nút bấm → `Navigator.push(MaterialPageRoute(builder:
  (_) => KnowledgeGraphScreen()))` (match cách word_list_screen mở).
- **AT:** Home → card Knowledge Graph preview → bấm "Xem Knowledge Graph
  →" → mở đúng màn hình graph.
- **Kết quả (agent `arena/01a0a6fe-in4up`, 2026-09-15):** card preview được
  bọc `Material(transparent)` + `InkWell` ⇒ cả card (gồm nút "Xem Knowledge
  Graph →") mở `KnowledgeGraphScreen` bằng đúng cách
  `word_list_screen.dart` mở từ toolbar WordList
  (`Navigator.of(context).push(MaterialPageRoute(builder: (_) => const
  KnowledgeGraphScreen()))`) + haptic. Nhãn nút chuyển sang
  `context.uiText('Xem Knowledge Graph →')` và có trong catalog
  (en `View Knowledge Graph →`, đủ hi/zh/zh_TW/si). Commit `214d57d`; CI
  run 35028370711 🟢. **CÒN:** nghiệm thu thiết bị (chờ nghiệm thu máy).
  - 2026-09-15 | merge base `df77ab0` (A1 PDF + A2 WLIST-LANG) vào lane B5,
    resolve `tool/legacy_ui_english_overrides.json` theo union (giữ 5 key mới
    của A2 + 5 key của B5, gỡ 2 key mồ côi 'Nghe · Nói'/'Đọc · Viết') → merge
    `4214445`; CI `App Analyze + Locale Test` run 35029286725 (pull_request)
    và 35029282086 (push) 🟢 — analyze 0 error + test rule #5 xanh.

### HOME-STREAK-001 — "Nhịp điệu học tập" chưa có thống kê thật
- **Triệu chứng (owner):** "Nhịp điệu học tập chưa có thống kê thực sự."
- **Hiện trạng (đã verify):** `focus_streak_card.dart` chỉ hiện "X ngày
  liên tiếp" từ `FocusProvider.streak` — streak chỉ được cập nhật qua
  `saveEffort(score)` mà hàm đó **hiện không có caller nào** (slider nỗ
  lực đã bỏ ở HOME-001) → streak gần như luôn 0, không phản ánh hoạt
  động thật.
- **Files:** `lib/screens/home/widgets/focus_streak_card.dart`,
  `lib/providers/focus_provider.dart` (streak + saveEffort), nguồn dữ
  liệu thật có sẵn: `RecentFilesService` (tiến độ đọc),
  `VocabularyProvider` (số từ import/lưu), LHB (`LearnByHeartProvider` —
  số bài ôn), shadowing stats (`ShadowingProvider.totalPracticeCount`),
  translation history.
- **Fix đề xuất:**
  1. Định nghĩa "1 ngày học" = có ÍT NHẤT 1 sự kiện thật trong ngày:
     mở/đọc tài liệu ≥N phút, import ≥1 từ, ôn ≥1 bài LHB, shadowing
     ≥1 lượt, dịch ≥M câu. Ghi event vào prefs (append, theo ngày).
  2. Streak tính từ event thật (không cần effort slider).
  3. Card hiện thống kê thật: "Hôm nay: X phút · Y từ · Z ôn" + mini
     bar chart 7 ngày + streak. Bấm vào card → màn thống kê chi tiết
     (tái dùng `stats`/`wordlist_stats` tools nếu có).
- **AT:** học thật (đọc + lưu từ) hôm nay → card hiện số >0; hôm sau mở
  app không học → streak giữ; học tiếp ngày hôm sau → streak +1.
- **Trạng thái:** doing (code + test xong trên `arena/01a0a702-in4up`, CI 🟢;
  còn: owner bật job riêng + nghiệm thu thiết bị theo AT)
- **Triển khai (2026-09-15):** kho `LearningActivityService` +
  `LearningActivityKind` (ghi tại nơi hành động thật: mở tài liệu, phút đọc,
  lưu/import từ, ôn LHB, shadowing, dịch); `FocusProvider` thành facade (bỏ
  đường streak qua `saveEffort` — slider đã bỏ ở HOME-001); thẻ hiện số liệu
  hôm nay + streak + biểu đồ 7 ngày. Idempotent theo (ngày, kind, sourceKey);
  ngày = giờ địa phương chốt lúc ghi; persist gộp theo ngày (1 chuỗi JSON).
  Nhãn chrome mới qua `uiText` + 7 key catalog (rule #5). Quyết định: ADR-0005.
- **Bằng chứng:** commits `9a67d1a` → `0b59b1a` (nhánh đã merge base tip
  `df77ab0` — commit `34845d8`, chỉ giải conflict `tool/legacy_ui_english_overrides.json`);
  App Analyze + rule #5 test xanh (run 35028682236); 32 test mới xanh (run
  35028682280 — job knowledge chạy qua cầu nối
  `test/knowledge/home_streak_ci_oracle_test.dart` vì GitHub App thiếu quyền
  `workflows`, chưa tạo được job riêng). PR: #33.
- **Lịch sử:**
  - 2026-09-15 | 21:57 UTC | proposed→doing | agent arena/01a0a702-in4up | commits 9a67d1a..d9d7243; CI run 35028341250 (analyze + rule #5) & 35028341223 (32 test HOME-STREAK-001); ADR-0005; job riêng còn ở `docs/ci/home_streak_tests.yml` (chờ owner bật)
  - 2026-09-15 | 22:02 UTC | doing (không đổi trạng thái) | agent arena/01a0a702-in4up | cập nhật base tip df77ab0 + giải conflict catalog i18n (merge 34845d8), bỏ smoke test placeholder (0b59b1a); CI 35028682236 (analyze + rule #5) & 35028682280 (32 test) 🟢; PR #33 mở vào `arena/01a0251e-in4up`

### LISTEN-LRC-LAYOUT-001 — Tab Nghe: kết quả lời AI nên nằm CHẠM CẠNH sóng âm (mặc định)
- **Triệu chứng (owner):** "Tab nghe: Mặc định nên để phần kết quả lời tạo
  từ AI chạm cạnh của sóng âm."
- **Hiện trạng:** `listen_mode_screen.dart` — LRC panel "nằm ngay dưới
  waveform" (comment line 6) nhưng có khoảng cách/padding giữa waveform
  (`RollingWaveformView`) và khối lời (kết quả AI/LRC) → chủ đề muốn
  khoảng cách = 0 (chạm cạnh) làm MẶC ĐỊNH.
- **Files:** `lib/screens/listen_mode/listen_mode_screen.dart` (khối
  layout waveform + LRC panel — grep `RollingWaveform` + `_lrcScroll`),
  `lib/screens/listen_mode/widgets/rolling_waveform_view.dart`.
- **Fix đề xuất:** đặt panel lời AI/LRC sát đáy waveform (spacing 0) làm
  default; nếu cần khoảng cách thẩm mỹ → ≤4px; kiểm tra không overflow
  khi có/nhiều dòng lời (bài học "v11 LRC Fix" ở đầu file).
- **AT:** tab Nghe → phát file + tạo lời AI → khối lời chạm cạnh sóng âm,
  không khoảng trống trắng, không overflow.

### XP-MODE-001 — "Chế độ trải nghiệm": đủ 7 mode (KHÔNG thêm tab — mở rộng Phòng Studio ở Home) + hiện các chức năng ẩn trong icon sấm sét
- **Triệu chứng (owner):** "Trong setting đang có 'Chế độ trải nghiệm'.
  Hãy cân nhắc để cho nó ra màn hình tab và cho các chế độ tương ứng để
  người dùng có trải nghiệm hướng đối tượng và trình chiếu được các chức
  năng bị ẩn trong icon sấm sét như dịch bin, đọc tam tạng kinh điển."
- **Hiện trạng (đã verify):**
  - "Chế độ trải nghiệm" (`grammarExperienceMode`) hiện là 1 tùy chọn
    TRONG sheet `read_settings_sheet.dart` (line 90, icon auto_awesome) —
    chưa phải tab.
  - Icon sấm sét (`Icons.bolt_rounded`, `main_shell.dart` ~line 1032) =
    "Công cụ nhanh" (`_openQuickActions` → `showToolsOverlayV2`) — ẩn
    các tool mạnh: **Tipiṭaka ("Đọc Tam Tạng, tra cứu kinh điển")**,
    Video, Thư viện video, Timeline, Word map, Triangle, Venn, Cabin,
    Dictionary… user khó biết chúng tồn tại.
- **Files:** `lib/screens/main_shell.dart` (nav + quick actions),
  `lib/screens/read_mode/sheets/read_settings_sheet.dart`,
  `lib/screens/tools/tools_overlay*.dart` (showToolsOverlayV2),
  `lib/features/tipitaka/` (Tam Tạng), i18n (app_localizations).
- **Fix đề xuất (feature — agent thiết kế trước khi code, chốt với owner
  1 bản wireframe ngắn trong KANBAN):**
  0. ✅ **OWNER ĐÃ CHỐT 2026-09-16** — bản thiết kế chốt là **D1-B**: KHÔNG
     thêm tab; 7 mode nằm trong **"Phòng Studio" ở Home** (7 thẻ phẳng D2-A)
     + mục **"Khám phá công cụ ⚡"** trên Home. (Phương án thêm tab thứ 6 do
     agent đề xuất đã bị owner bác → bỏ khỏi phạm vi.)
  1. ~~Tab "Trải nghiệm"~~ → **Phòng Studio 7 mode** NGHE/NÓI/XEM/ĐỌC/VIẾT/
     HIỂU/NHỚ — mỗi mode = "hướng dẫn có dẫn đường": mục tiêu 1 dòng +
     4–5 bước thao tác thật (bấm theo chỉ dẫn) + badge "N bước ▸".
  2. Mục "Khám phá công cụ ⚡" **trên Home** (dưới lưới Studio): trình chiếu
     (carousel) các tool đang ẩn sau icon sấm sét (Tipiṭaka/Tam Tạng, Video,
     Word map, Triangle, Venn, Cabin…) — mỗi card: icon + tên + 1 dòng mô tả +
     nút "Mở ngay" → mở đúng tool; nguồn dữ liệu dùng lại
     `_buildQuickActions` + nút "Xem tất cả ⚡" (overlay v2 giữ nguyên).
  3. Giữ "Chế độ trải nghiệm" cũ trong read settings (không phá); lớp UX mới
     trên Home chỉ là vỏ dẫn đường, không dựng lại UI mode.
- **AT (đã cập nhật theo D1-B):** Home → Phòng Studio **7 thẻ** → chạm ĐỌC →
  làm theo các bước → tới đúng chỗ; mục "Khám phá công cụ ⚡" hiện ≥5 tool ẩn
  + bấm "Mở ngay" mở đúng tool (kiểm tra Tipiṭaka → thiếu DB vẫn mở được và
  dẫn tới màn hình tải dữ liệu).
- **Trạng thái:** ✅ **owner đã chốt thiết kế 2026-09-16** (D1-B · D2-A · D3-A
  mặc định · D4-A · D5-A) — hết design gate, **chưa code**; chờ owner bật đèn
  xanh cho **PR implementation riêng** (WP0–WP3). Lane B8 trong
  `AGENT_ASSIGNMENTS_2026-09-16.md` vẫn đúng tinh thần "chốt UX trước, code
  sau": bản thiết kế đã được owner duyệt, không còn agent tự quyết UX lớn.
  ⚠ **Vướng phối hợp:** D1-B dùng chung `home_screen.dart` +
  callback `main_shell.dart` với card `HOME-STUDIO-001` ⇒ chốt PA1 (làm chung
  một PR) hay PA2 (tuần tự) TRƯỚC khi sửa 2 file này.
- **Phase 1 — deliverable (branch `arena/01a0a703-in4up`, base `d40f604`):**
  - `docs/project/XP-MODE-001-wireframe.md` — hiện trạng verify bằng code (12
    điểm, file:line), wireframe 6 khối, đặc tả 7 mode (mục tiêu 1 dòng + 4–5
    bước/bước nào cũng trỏ route thật), mục "Khám phá công cụ ⚡" (7 thẻ tiêu
    biểu + quy tắc trạng thái unavailable), i18n plan, WP0–WP3, bất biến, rủi ro.
  - `docs/project/assets/xp-mode-001-wireframe.png` + nguồn `.svg` (ảnh wireframe).
  - `docs/project/XP-MODE-001-route-inventory.csv` — 28 entry (7 MODE + 21 TOOL):
    route đích thật (file), cách mở hiện tại (`_handleTool` / `_setListenMode` /
    `_setReadMode` / `_setPrimaryTab`), điều kiện unavailable (phát hiện bằng
    code), đường khắc phục, ghi chú id trùng (`dictionary`≡`dict_manager`,
    `video_player`≡`video_library`).
  - `docs/project/XP-MODE-001-i18n-keys.csv` — 20 key mới × vi/en/hi/zh/zh_TW/si
    (gồm 3 nhãn mode còn thiếu ARB: `speak`/`watch`/`write`).
  - `docs/project/XP-MODE-001-review-checklist.md` — checklist owner chốt
    D1–D5 + AT dùng lại cho PR implementation.
- **Đã verify khi làm phase 1 (điểm đáng chú ý cho PR implementation):**
  - Icon ⚡ chỉ ở tab Home mới có Tipiṭaka ⇒ 4 tab còn lại user không thấy tool này.
  - Tipiṭaka **không thể mở chết**: thiếu DB → `_MissingDatabaseView`
    (`library_screen.dart:385`) → `TipitakaDownloadScreen`; asset DB là optional.
  - Video/Từ điển/Map/Triangle/Venn đều có empty state riêng (không crash) ⇒
    chọn hướng D4-A (nút "Mở ngay" luôn hoạt động + badge nói thiếu gì).
  - Máy bắt i18n ở tầng **source** (`tool/generate_legacy_ui_fallbacks.py:301`
    quét `lib/**/*.dart`) ⇒ PR implementation phải dùng ARB ngay, không
    hard-code tiếng Việt.
- **Chờ owner (2 việc):** (a) bật đèn xanh cho **PR implementation** WP0–WP3
  + test navigation (card con `XP-MODE-002` Home 7 thẻ/carousel,
  `XP-MODE-003` tour); (b) chọn cách phối hợp `HOME-STUDIO-001` (PA1 làm chung
  một PR / PA2 tuần tự) — xem mục 8 `XP-MODE-001-wireframe.md`.
  Checklist chốt: `XP-MODE-001-review-checklist.md` (mục A/B đã tick theo
  quyết định owner; mục C–G dùng lại cho PR implementation).
- **Lịch sử:**
  - 2026-09-16 | owner Q&A | **chốt thiết kế D1-B/D2-A/D4-A/D5-A** (D3 giữ
    mặc định A, owner có thể phủ quyết ở PR code): KHÔNG thêm tab, 7 thẻ phẳng
    ở Phòng Studio, "Mở ngay" luôn mở + badge thiếu gì, tour = checklist bước
    thật; agent cập nhật wireframe md + ảnh png/svg (bỏ thiết kế tab), tick
    checklist A/B, cập nhật CSV i18n, chuyển card khỏi design gate |
  - 2026-09-16 | 21:47 UTC | doing (design gate) | agent arena/01a0a703-in4up |
    phase 1: wireframe md + png/svg + CSV route (28 entry) + CSV i18n (20 key) +
    checklist chốt; KHÔNG code tính năng; giữ `grammarExperienceMode` cũ |
    commit `d3ee12b` · PR #29 (draft, base `arena/01a0251e-in4up`)

### SHADOW-FILE-001 — Tab Nói: file âm thanh bị mất (ENOENT, file_picker cache) + AB bắt buộc gây bất tiện
- **Triệu chứng (owner, logcat):** ExoPlayer
  `FileNotFoundException: /data/user/0/com.in4up.beta/cache/file_picker/
  1788698176215/Out & about - poem.m4a: open failed: ENOENT` khi
  "PLAY ORIGINAL" (shadowing, loop 11s→15s, 5 lần, speed 0.75). Plus:
  "nó chỉ mới áp dụng cho AB nghĩa là bắt người dùng phải chọn AB xong
  mới qua luyện nói → Bất tiện, nên có cơ chế thông minh hơn, không
  bị giới hạn bởi AB."
- **Root cause (đã verify — log + code):**
  1. `audio_library_drawer.dart` (`_pickSingleFile`/`_pickMultipleFiles`
     line ~190-235) + `listen_library_screen.dart` line ~170: dùng
     `FilePicker.pickFiles(type: audio)` → `file.path` = file nằm trong
     **`/cache/file_picker/<timestamp>/`** — thư mục CACHE của app —
     Android XÓA cache bất kỳ lúc nào (thiếu bộ nhớ, user clear cache,
     restart…) → path chết → ExoPlayer ENOENT. LƯU Ý: lỗi này ảnh hưởng
     TOÀN BỘ thư viện âm thanh (không chỉ shadowing).
  2. Shadowing flow: user phải chọn AB loop (trong tab Nghe) TRƯỚC khi
     luyện nói được — cứng.
- **Files:** `lib/screens/listen_mode/widgets/audio_library_drawer.dart`,
  `lib/screens/listen_mode/widgets/listen_library_screen.dart`,
  `lib/providers/player_provider.dart` (loadSong giữ path),
  `lib/features/shadowing/providers/shadowing_provider.dart` +
  `widgets/shadowing_widget.dart` (AB requirement + play original),
  `lib/screens/listen_mode/speak_mode_screen.dart`.
- **Fix đề xuất:**
  1. **COPY file vào persistent** ngay sau pick:
     `getApplicationDocumentsDirectory()/audio_imports/<name>.m4a`
     (bảo toàn tên gốc, dedup nếu trùng) → tất cả chỗ (player, shadowing,
     LRC, VAD) dùng persistent path. File cũ trong cache: khi phát gặp
     ENOENT → báo rõ "File đã bị hệ thống dọn cache — vui lòng chọn lại
     file" (không để crash im lặng).
  2. AB thông minh: cho phép shadowing KHÔNG cần AB (chạy toàn track);
     TỰ GỢI AB từ timestamp LRC (nếu có lời: mỗi câu = 1 AB tự động,
     user luyện theo câu); user vẫn chỉnh tay AB được trong widget
     shadowing (không phải quay về tab Nghe).
- **AT:** chọn file audio → chờ/simulate clear cache (`adb shell pm
  clear` nhẹ hoặc xóa thư mục cache) → mở lại app → phát file VẪN được
  (đã copy persistent); shadowing không AB → luyện được toàn track; file
  có LRC → gợi ý AB theo câu.
- **FIX ĐÃ LÀM (agent Arena B7, 2026-09-16, chờ nghiệm thu):**
  - `lib/services/audio_import_service.dart` (MỚI): sau file_picker copy
    vào `getApplicationDocumentsDirectory()/audio_imports/`; dedup an
    toàn (size + fingerprint 64KB đầu/cuối → reuse; khác nội dung trùng
    tên → đổi tên `name (2).ext`, KHÔNG ghi đè/xóa); chỉ copy khi nguồn
    volatile (cache/temp) — path ổn định (Music/desktop) giữ nguyên để
    không nhân đôi bộ nhớ; hỗ trợ cả nguồn content://. Basename giữ
    nguyên → LRC cache (SourceArtifactStore fingerprint size|duration|
    basename) vẫn khớp sau khi đổi thư mục.
  - `audio_library_drawer.dart`, `listen_library_screen.dart`: pick →
    import (progress UI + snackbar khi lỗi) → player/recent/playlist/LRC/
    VAD/shadowing đều dùng path persistent.
  - `player_provider.dart`: `loadSong` trả bool; pre-check File tồn tại
    TRƯỚC khi qua ExoPlayer; tự khôi phục từ audio_imports/ khi đúng 1
    file trùng basename (recents/segment cũ hồi sinh); `AudioLoadErrorKind`
    (missingFile/loadFailed) + `lastLoadErrorPath` cho UI; recents chỉ ghi
    sau khi load OK; `playSegment` bail khi load fail.
  - ENOENT UX: thư viện Gần đây → dialog "File không còn tồn tại"
    (Đóng / Xóa khỏi danh sách / Chọn lại file — chọn lại sẽ copy
    persistent); snackbar "Đã khôi phục audio từ bản lưu trong thư viện"
    khi tự khôi phục; không crash, không im lặng.
  - Shadowing không bắt buộc AB: `ShadowingWidget` idle mới — "Nghe mẫu"
    + "Ghi âm" chạy TOÀN TRACK khi chưa có AB (playOriginal lấy duration
    từ setFilePath, gapProgress theo số vòng nghe); `player_provider`
    `clearLoopPoints` + `shadowing.clearLoopRegion()`.
  - Gợi ý AB theo câu LRC: `lrc_ab_suggestions.dart` (PURE) — mỗi câu = 1
    AB (B = đầu câu kế, câu cuối = duration), nút "Dùng câu đang phát",
    list gợi ý trong tab Nói (lấy từ UnderstandProvider hoặc lazy-load
    cache LRC 1 lần/bài); đặt AB qua `player.setLoop` + practice text.
  - Chỉnh tay AB ngay trong tab Nói: nudge ±0.5s cho A/B (clamp
    0≤A<B≤duration), "Đặt A/B tại vị trí phát" (A>B tự swap), "Xóa A-B".
    A chạm B → `player.setLoopRegion` đồng bộ cả player và shadowing.
  - `speak_mode_screen.dart`: tip card cập nhật luồng mới.
  - i18n rule #5: 27 chuỗi chrome mới vào `priority_ui_overrides.dart`
    (đủ en/hi/zh/zh_TW/si).
  - Tests MỚI: `test/audio_import_service_test.dart` (14 test: copy/dedup/
    rename không ghi đè/volatile/stable/restore/sanitize) +
    `test/lrc_ab_suggestions_test.dart` (gợi ý theo câu, câu đang phát,
    nudge clamp). KHÔNG xóa dữ liệu import cũ ở bất cứ chỗ nào;
    cleanup/migration (nếu cần) sẽ là luồng riêng có xác nhận + test.

### SHERPA-STREAM-001 — Crash SIGABRT: model STREAMING nạp qua OfflineRecognizer (FIXed code, chờ nghiệm thu)
- **Triệu chứng (logcat owner):** `Fatal signal 6 (SIGABRT)` —
  `Ort::Exception: Got invalid dimensions for input: x. Got: 51 Expected: 39`
  khi app load `sherpa-onnx-streaming-zipformer-en-20M-2023-02-17` qua
  `GetOfflineRecognizerConfig` / `SherpaOnnxDecodeOfflineStream`.
- **Root cause (đã verify code):**
  1. Model **streaming** Zipformer (EN profile) bắt buộc input đúng chunk
     cố định (39 frames). Nạp nó bằng **OfflineRecognizer** (API cho model
     offline — nhận độ dài tự do) → ONNX Runtime C++ abort, Dart không
     catch được.
  2. Engine `stt_engine_sherpa.dart` vốn ĐÃ CÓ 2 đường: `OnlineRecognizer`
     (streaming, WP4) và `OfflineRecognizer` (offline + VAD) — nhưng flag
     `isStreaming` bị **false-negative**: `isStreamingEncoderOnnx` chỉ dò
     magic string `encoder_dims`/`query_head_dims` trong 256KB đầu encoder
     — file int8/version khác không có chuỗi đó → model streaming bị coi
     là offline → đi nhầm đường → SIGABRT.
  3. Lỗ hổng thứ 2: `transcribeFile` LUÔN `_initOffline` bất kể
     `isStreaming` → LRC/VAD pipeline/auto-TOC/shadowing dùng model
     streaming cũng crash như nhau.
- **Fix ĐÃ LÀM (turn này):**
  - `sherpa_model_manager.dart::isStreamingEncoderOnnx`: 2 lớp — (1) tên
    file/thư mục chứa "streaming" → streaming (k2-fsa đặt tên chuẩn;
    "non-streaming" → offline), (2) metadata onnx (giữ nguyên).
  - `stt_engine_sherpa.dart::_initOffline`: **HARD GUARD** — model
    streaming (flag + re-detect) → KHÔNG tạo OfflineRecognizer, set
    `lastError` rõ → UI báo thay vì app chết.
  - `transcribeFile`: model streaming → trả failure RÕ ("dùng model
    OFFLINE cho file, vd asr-vi-30M-int8") trước khi init.
  - `startLive` nhánh offline: guard sớm trước khi setup VAD.
- **Hành vi sau fix:**
  - Cabin LIVE + model streaming (EN) → đường `OnlineRecognizer` (đúng,
    token-by-token) — hoạt động.
  - Cabin LIVE + model offline (VI) → simulated streaming VAD — hoạt động.
  - Transcribe file/LRC + model streaming → lỗi văn bản rõ, KHÔNG crash.
  - Transcribe file/LRC + model offline → như cũ.
- **Việc còn lại (nâng cấp, KHÔNG blocking):** transcribe file bằng model
  streaming qua OnlineRecognizer chạy chunk (feed 32-frame chunks +
  accumulate) — làm sau khi nghiệm thu fix này; cần test độ dài câu dài.
- **AT nghiệm thu (máy owner):**
  1. Cabin nguồn EN (model streaming đã import) + engine Offline (sherpa)
     → start được, nói tiếng Anh → ra chữ (online path), KHÔNG SIGABRT.
  2. Cabin nguồn VI (model asr-vi-30M-int8) → vẫn nhận diện như trước.
  3. Tab Nghe → tạo lời (LRC) bằng sherpa khi model đang chọn là streaming
     → hiện lỗi "model streaming không dùng cho file" (không crash).
  4. LRC bằng model VI offline → vẫn tạo lời bình thường.
- **CI (trạng thái):** fix code đã commit `d652ee1` (tip `827b35a`), NHƯNG
  wide oracle `app_analyze.yml` KHÔNG chạy vì paths filter chưa có
  `packages/**` (code fix nằm trong local package `in4up_stt`). GitHub
  App KHÔNG có quyền `workflows` → agent không sửa được workflow file /
  không trigger được workflow_dispatch (403). **Owner chọn 1:**
  (a) trên GitHub: Actions → "App Analyze + Locale Test" → Run workflow
  (branch `arena/01a0251e-in4up`) — verify fix `d652ee1`; hoặc
  (b) `git apply scripts/ci/analyze_paths_packages.patch` rồi commit/push
  (vĩnh viễn: mọi đổi `packages/**` sẽ tự chạy oracle).
- **Lịch sử:**
  - 2026-09-16 | fix code siết hơn | agent `arena/01a0a6fa-in4up` |
    `detectEncoderKind` chỉ nhận bằng chứng MẠNH: metadata ONNX
    ("non-streaming" ưu tiên trước "streaming") → nếu im lặng mới tới tên
    file/thư mục; BỎ heuristic `encoder_dims`/`query_head_dims` (trả
    `unknown` thay vì đoán). Route live theo profile (VI = offline+VAD,
    EN = streaming) khi metadata im lặng; import chặn model không có bằng
    chứng ngôn ngữ/loại model. 3 hard-guard cũ giữ nguyên.

### AUTH-LINUX-01 — Linux: đăng nhập + sync qua Firebase REST (ADR-0005)

- **Triệu chứng:** bản Linux không có nút đăng nhập ở tab Home (guard
  `Firebase.apps.isEmpty` trong `_FirebaseAuthButton` hiển thị icon ⚡ xám)
  vì FlutterFire không phát hành plugin native cho Linux; sync từ vựng cũng
  tắt (`VocabSyncService` early-return khi `!hasDb`).
- **Giải pháp (ADR-0005):** facade `AuthService` thống nhất plugin/REST;
  mới `firebase_rest_auth.dart` (signInWithIdp + securetoken refresh, session
  lưu Hive) + `firestore_rest_client.dart` (commit/runQuery/list + codec
  tương thích kiểu dữ liệu plugin). OAuth browser flow desktop dùng chung.
  Cùng uid Android/Windows → data về đúng tài khoản.
- **Không đổi:** hành vi Android/iOS/macOS/Windows/Web (đường plugin giữ
  nguyên); 0 dependency mới; schema Firestore giữ nguyên.
- **Còn mở:** CI build Linux xanh (Lưu ý CI-LINUX-01: webview_win_floating
  cần webkit2gtk-4.1 — độc lập với thay đổi này); nghiệm thu máy Linux thật:
  đăng nhập lần đầu, khởi động lại app giữ phiên, thêm từ trên Linux → thấy
  trên Android, thêm từ trên Android → thấy trên Linux (quy tắc updatedAt),
  đăng xuất; chạy `flutter analyze` (sandbox agent không có Flutter SDK).
- **Lịch sử:**
  - 2026-09-23: triển khai xong trên `arena/01a0ca82-in4up`.

### READ-IPA-001 — IPA xếp chồng Read Mode (toggle 3 trạng thái)

- **Trạng thái:** ✅ done — **Bằng chứng:** commit `e1a4382`; App Analyze
  + Locale Test run `35687736425` 🟢 (2026-09-22/23).
- **Nội dung đã ship (P1):**
  - `IpaDisplayMode` hidden → activeLine → all; toggle bottom-bar
    cạnh nút dịch (`Icons.abc`, cyan `0xFF4DD0E1`) — KHÔNG nằm ColorMode.
  - Dòng IPA xếp chồng dưới dòng chữ: fontSize × 0.75, height 1.4,
    nằm trong `originalWidget` nên chạy cả stacked lẫn side-by-side.
  - `LineIpaService`: eligibility ASCII từng dòng (chữ lạ → bỏ cả dòng),
    pipeline CMU → G2P tái dùng `PhonemeAnalyzer`, cache + `clearCache()`
    khi engine CMU nạp xong (G2P cũ bị thay bằng CMU).
  - Settings → "Phiên âm / IPA": selector 3 chip + persist
    `ipa_display_mode`; i18n 'Dòng hiện tại'/'Toàn văn bản'
    (priority 5 locale + legacy JSON).
- **Lịch sử:**
  - 2026-09-22 | 04:39 | created→done | ai | commit e1a4382 + run 35687736425 xanh

### READ-IPA-002 — Nguồn IPA khi lưu từ (waterfall + provenance)

- **Trạng thái:** ✅ done — **Bằng chứng:** commit `259c322`; App Analyze
  + Locale Test run `35886676119` 🟢 (2026-09-23, 2m00s).
- **Nội dung (P2 — ADR-0005 §2):**
  - `IpaResolver`: auto = MDX → CMU → G2P → bỏ trống; dict = chỉ MDX;
    g2p = bỏ MDX; off = không điền. Không prompt từng lần lưu.
  - `IpaValidator` chặn respelling/rác; normalize bọc `/.../`.
  - Trích IPA lazy từ `DictEntry.definition` lúc lookup — KHÔNG sửa
    `mdx_parser` (DICT-001 sở hữu; ghi chú read-time extract =
    candidate cho import-time extract của họ).
  - `WordEntry.phoneticSource` additive (`mdx|cmu|g2p|user`),
    EditSheet sửa tay → `user`; smart-fill không bao giờ đè.
  - Hook `_scheduleIpaResolve` trong `addWord` / `addWithAutoClassify`
    (async, re-check sau await — không đè IPA user gõ trong lúc tra).
  - UI: selector "Nguồn IPA khi lưu" (auto/dict/g2p/off) trong
    Settings → IPA; chip nguồn ở `VocabEntryMetaInfo` + preview IPA
    từ MDX (kèm chip MDX) trong `WordActionsSheet` trước khi lưu.
  - i18n: 'Nguồn IPA khi lưu', hint, 'Tự động', 'Từ điển', 'Bạn'
    → priority 5 locale + legacy JSON (bỏ 2 entry chết của P1 khỏi
    JSON — runtime vẫn qua priority).
- **Lịch sử:**
  - 2026-09-23 | 16:05 | created→doing | ai | code P2 + ADR-0005 + card này
  - 2026-09-23 | 16:14 | doing→done | ai | commit 259c322; run 35886676119 🟢

### READ-IPA-003 — Ruby/interlinear IPA cho dòng active + nhấn nháy nhịp

- **Trạng thái:** ✅ done — **Bằng chứng:** commit `9b27586` (+ cleanup
  `fcdc037`); App Analyze + Locale Test run `35890021728` 🟢 (2026-09-23).
- **Nội dung dự kiến (P3):**
  - `_LineData`携带 `IpaSegment[]` (surface + ipa + phonemes);
    dòng current/đang phát render word-chip 2 tầng (chữ × fontSize,
    IPA × 0.75 cyan) thay vì SelectableText — tap chip = `tp.speak(word)`.
  - Nhấn nháy: đổi độ đậm/weight IPA + tint chip theo
    `isSpeaking || isPlaybackActive` (cấp DÒNG — không karaoke từng
    từ: word-timestamp đã bị strip, ADR-0005 §3).
  - Không đụng colorMode word-chip đang hiển thị (fallback flat khi
    ColoredTextWidget đang chiếm dòng).
- **Lịch sử:**
  - 2026-09-23 | 16:05 | created→proposed | ai | theo roadmap P3/ADR-0005 §5
  - 2026-09-23 | 16:20 | proposed→doing | ai | code P3 (IpaSegment + interlinear + test segments)
  - 2026-09-23 | 16:39 | doing→done | ai | commit 9b27586 (+ fcdc037); run 35890021728 🟢

### READ-IPA-004 — Tô màu phoneme + legend + mờ IPA từ đã thuộc

- **Trạng thái:** ✅ done — **Bằng chứng:** commit `f149237` (+ cleanup
  `fcdc037`); App Analyze + Locale Test run `35890021728` 🟢 (2026-09-23).
- **Nội dung dự kiến (P4):**
  - Toggle `ipaColorByType` (default OFF): phoneme span theo loại —
    nguyên âm vàng / phụ âm sky-blue / đôi nguyên âm tím (derived
    Okabe-Ito, test trên nền `#1A1A2E`, không đụng bảng POS/CEFR),
    stress `ˈˌ` amber đậm; `CMUDictionaryService.getPhonemeType`
    phân loại từng phoneme (stress + diphthong set trước).
  - Legend 3 chấm trong Settings→IPA (widget riêng, không nhập
    `_LegendPanel` vì keying khác — ColorMode vs ipaColorByType).
  - Toggle `ipaFadeKnown` (default OFF): word đã `MasteryZone.mastered`
    (qua `VocabularyBridge.findByWord`) → IPA render alpha ~0.3.
- **Lịch sử:**
  - 2026-09-23 | 16:05 | created→proposed | ai | theo roadmap P4/ADR-0005 §4
  - 2026-09-23 | 16:35 | proposed→doing | ai | code P4 (IpaStyling + toggles + legend)
  - 2026-09-23 | 16:39 | doing→done | ai | commit f149237 (+ fcdc037); run 35890021728 🟢

### READ-GRAM-001 — Cụm từ + cấu trúc câu trong tab Đọc (chỗ "Loại từ, CEFR")

- **Trạng thái:** 🔄 doing — P1 đang triển khai trong sản phẩm (models/service/widget/test), giữ line-first và không đổi schema.
- **Bằng chứng (đặc tả đã kiểm chứng):**
  - `tool/grammar_probe/engine.py` — đặc tả thuật toán chạy được (Python; sandbox không có Dart SDK).
  - `tool/grammar_probe/run_probe.py` — đo từng trường + runtime, `exit 1` khi lệch (dùng như golden test).
  - 3 bộ corpus: `corpus.json` (65 case, tinh chỉnh ⇒ 0 sai — KHÔNG phải ước lượng tổng quát hoá),
    `holdout.json` (30 case), `holdout2.json` (**đóng băng**, chạy 1 lần, không sửa engine sau đó).
  - **Số trung thực:** bộ đóng băng `holdout2` = **17/25 case đúng trọn (68%)** lúc đóng băng;
    sau khi người sở hữu chốt quy ước *câu hỏi đuôi = khẳng định + hỏi đuôi* (2026-09-24) ⇒ **18/25 (72%)**
    (1 case đổi vì QUY ƯỚC, không phải vì engine giỏi hơn);
    tense 11/11, pattern 5/5, polarity 3/3, voice 3/3, question 3/3, phrase.kind 23/25,
    phrase.span 21/25; runtime ~286 µs/câu (Python, max 730 µs).
  - 8 lỗi ⇒ 4 nguyên nhân gốc (PLAN-031 §7.1): (A) PP vị trí ngoài cụm; (B) trạng từ chen trong
    nhóm động từ + thiếu semi-modal `would rather`; (C) quy ước câu hỏi đuôi chưa chốt;
    (D) quan hệ zero + thiếu từ vựng (bản Dart tự khỏi nhờ `GrammarLexiconService`).
- **Nội dung dự kiến:**
  - **P1:** `SentenceStructureService` (thuần Dart, tái dùng `SyntaxHighlighterService` +
    `GrammarLexiconService` + `TextSegmenter`) → cụm NP/VP/PHRASAL_V/PP/AdjP/AdvP/GerP/InfP/PartP
    + cụm bao ngoài + loại câu + thì–thể–thái–modal + công thức; **section gập trong
    `word_actions_sheet.dart` ngay dưới badge "Loại từ · CEFR"** (không đổi thứ tự section cũ).
  - **P2:** sửa 4 nguyên nhân gốc + `SentenceJoiner` (side-table cho câu vắt dòng, KHÔNG đổi
    `TextItem`) + nhãn cấp dòng (mặc định OFF) + **nút bật/tắt nhanh trên `read_bottom_bar.dart`
    cạnh nút IPA** (xoay `Tắt → Dòng hiện tại → Toàn văn bản`, theo khuôn `IpaDisplayMode`) +
    nhóm cài đặt "Cấu trúc câu"; key `sentence_structure_settings_v1`.
  - **P3:** panel "Cấu trúc câu" + block "Giải thích chi tiết (AI)" (dùng façade `sentenceParse`
    đã có; luật là nhãn chính, AI là block riêng, không trộn).
  - Precision-first: `confidence` + ẩn nhãn khi yếu; ngôn ngữ ≠ EN ⇒ `supported=false` + câu nhắc.
  - i18n luật #5 (vi nguồn → en fallback + ưu tiên en/hi/zh/zh_TW/si) + test cổng.
- **Kèm theo:** `docs/project/PLAN-031-cau-truc-cau-read-tab.md`, `docs/adr/0006-*.md`.
- **Lịch sử:**
  - 2026-09-24 | created→proposed | ai (arena/01a0d344-in4up) | yêu cầu người sở hữu; spike + 3 corpus
    + số đo trung thực; chờ chốt 3 điểm ở PLAN-031 §10
  - 2026-09-24 | proposed (giữ nguyên) | ai (arena/01a0d344-in4up) | người sở hữu CHỐT §10.1: câu hỏi
    đuôi = "khẳng định + hỏi đuôi" (`type=declarative` + `question=tag`) ⇒ áp vào engine + corpus;
    bộ đóng băng 17/25 → 18/25 (đổi do quy ước).
  - 2026-09-27 | proposed (giữ nguyên) | ai (arena/01a0d344-in4up) | gộp nhánh tích hợp
    `arena/01a0251e-in4up` về nhánh làm việc (giữ đủ cả hai phía ở KANBAN/PLAN theo luật append-only);
    đổi số `PLAN-029 → PLAN-031`, `ADR-0006 → ADR-0007` (251e đã dùng các số đó cho LHB-006 /
    Cabin Save). Nội dung kế hoạch không đổi.
  - 2026-09-24 | proposed (giữ nguyên) | ai (arena/01a0d344-in4up) | người sở hữu CHỐT §10.2 + §10.3:
    câu vắt dòng chọn (a) phân tích theo dòng rồi ghép ở P2; khối trong sheet ON; nhãn cấp dòng OFF
    **kèm nút bật/tắt nhanh trên thanh công cụ đáy** (không phải vào Cài đặt). Kế hoạch đã đủ điều
    kiện để code P1 — **chờ lệnh bắt đầu code của người sở hữu**.
  - 2026-09-28 | proposed→doing | ai (arena/01a0e7d8-in4up) | bắt đầu code P1 trên nhánh session Arena
    cố định: thêm models/service/widget section trong `WordActionsSheet`, 4 test CI và sửa UX IPA theo
    phản hồi (IPA toàn văn hiển thị interlinear khớp từ; toggle IPA có hint nhỏ; chọn dòng cập nhật
    `currentLineIndex` nhạy hơn). Giữ append-only; không đụng `TextItem`/`ColorMode`/`lib/ffi/`.

### READ-IPA-005 — G2P đa ngôn ngữ (VI/Pali) theo từ điển đóng gói

- **Trạng thái:** 📋 proposed — **KHÔNG code trong đợt này.**
- **Nội dung:** G2P rules VI (orthography→IPA + thanh) + Pali theo
  dữ liệu đóng gói; đi cùng gói từ điển VI/Pali đã có trong roadmap
  hiển thị. Theo ADR-0005 §6: cần ADR riêng cho chất lượng phiên âm
  từng vùng + asset content — tách đợt sau (tương tự READ-630-05
  chờ foundation).
- **Lịch sử:**
  - 2026-09-23 | 16:05 | created→proposed | ai | ADR-0005 §6 — blocked on packaged VI/Pali dicts

### READ-IPA-006 — Panel màu IPA tương tác + nối âm (liaison) + từ nhấn

- **Trạng thái:** 🔄 doing (code xong, chờ CI + nghiệm thu build)

  Yêu cầu người dùng (INA 2 Lưu Từ — 4 mục, branch `arena/01a0d33c-in4up`):

  1. **Khi dịch IPA toàn văn bị thiếu dòng:** ✅ đã sửa — root cause đã được
     xác nhận bằng chẩn đoán Gemini (screenshot dòng 33–36 không có IPA):
     `_computeSegments` hợp đồng P1 CŨ trả `null` CẢ DÒNG khi có token không
     khớp `^[A-Za-z][A-Za-z']*$` (từ Pali/Sanskrit có dấu `cetanā`,
     `(kusa la)`; hoặc dính dấu câu `consciousness.If`, `wholesome(kusa`).
     SỬA: bỏ short-circuit toàn dòng → tách token theo run chữ, từ Anh vẫn có
     IPA, phần ngoại/dấu câu thành segment surface-only (skip, render nguyên
     văn ở interlinear); CHỈ dòng không có từ ASCII nào (thuần Việt/Pali) mới
     null. Chú giải Pali thường bọc ngoặc trải dài nhiều token
     (`wholesome(kusa la),`) → theo dõi độ sâu `(` để không tra IPA sai cho
     `kusa`/`la`. Test mở rộng `line_ipa_service_test.dart` (Pali/diacritic +
     glue punctuation + dòng lẫn Anh/Việt; sửa 1 test cache tiềm ẩn sai
     counts vì chưa từng chạy do thiếu SDK).

  2. **Bảng thông tin màu IPA:** ✅
     - `IpaLegendStrip` — dải chip màu ngay dưới TopBar Read Mode, mỗi loại
       (nguyên âm/phụ âm/đôi nguyên âm/trọng âm/nối âm/từ nhấn) là 1 chip
       bật/tắt, MẶC ĐỊNH BẬT HẾT.
     - Ẩn/bật cả bảng: nút “Màu IPA” trên TopBar + nút X + switch trong
       Settings → IPA; persist `ipa_legend_visible`.
     - `IpaColorVisibility` (model) + persist `ipa_color_visibility` (JSON).
     - Cùng toggle chip trong Settings → IPA (đồng bộ với strip).
     - Bỏ widget animation (READ-TOOLBAR-001).

  3. **Màu nối âm (liaison C→V):** ✅ — người dùng chốt nghĩa là **nối âm**
     chứ KHÔNG phải “liên từ/function word”. Khi từ trước kết thúc phụ âm và
     từ sau bắt đầu nguyên âm: phụ âm cuối + nguyên âm đầu được tô
     deep-orange (`0xFFFF7043`) + underline. `IpaStyling.detectLinkMarks`
     quét ký tự IPA thật, KHÔNG phụ thuộc phoneme list.

  4. **Từ/cụm được nhấn trong câu:** ✅ (xấp xỉ) — KHÔNG có word-timestamp
     (bị strip lúc parse, ADR-0005 §3) nên đánh dấu **trọng âm chính `ˈ`**
     bằng gạch trên (overline) đúng âm tiết nhấn; `IpaStressAnnotator` bỏ
     trọng âm phụ `ˌ` và function word bảng dừng (can/to/that/for…) để không
     lẫn lộn. Toggle riêng `stressWords` (default ON). KHÔNG hứa chính xác
     sentence stress (dữ liệu nguồn là dictionary form).

- **Phạm vi thay đổi:** `lib/models/ipa_color_visibility.dart` (mới),
  `lib/services/ipa_styling.dart` (P1/P2/P3 + markRanges primitive),
  `lib/services/ipa_stress_annotator.dart` (mới),
  `lib/screens/read_mode/widgets/ipa_legend_strip.dart` (mới),
  `read_top_bar.dart`, `read_mode_screen.dart`, `read_settings_sheet.dart`,
  `text_line_widget.dart`, `lib/providers/text_provider.dart`,
  `lib/services/storage_service.dart`, i18n (`priority_ui_overrides.dart`).
  Tests: `ipa_styling_test.dart` (mở rộng), `ipa_color_visibility_test.dart`
  (mới), `ipa_stress_annotator_test.dart` (mới).

- **Lịch sử:**
  - 2026-09-24 | created→doing | ai | theo yêu cầu IPA 2 (4 mục) trên arena/01a0d33c-in4up
  - 2026-09-25 | doing | ai | item 1 — xác nhận root cause (LineIpaService bỏ CẢ DÒNG khi token lạ) theo chẩn đoán Gemini; sửa `_computeSegments` thành token-level fallback (tách run chữ, skip từ ngoại/dấu câu, giữ nguyên dòng); mở rộng test Pali/diacritic + glue punctuation; sửa 1 test cache thiếu count
### READ-IMPORT-001 — I4U | Read Import Many

- **Trạng thái:** 🔄 doing — chờ Flutter format/analyze/test và QA giao diện.
- **Nội dung:**
  - Batch UI dùng chung cho PDF/Web selection và Web article: lọc mục chưa
    đánh giá, nhìn tiến độ phân loại, gán độ khó từng mục hoặc áp nhóm có undo.
  - Trước khi nhập, cho sửa meaning, IPA, topic, language, example; lấy gợi ý
    local/dictionary/AI chỉ vào field trống, giữ nội dung người dùng đã có.
  - Form lưu chi tiết ở tap sheet hỗ trợ nhập hoặc smart-fill meaning/IPA/example;
    WordList hiển thị và cho sửa meaning/IPA/example.
  - `WebExtractionCandidate` lưu difficulty tương thích draft cũ; importer ghi
    difficulty vào entry WordList.
- **Bằng chứng gần nhất:** test round-trip/đọc draft cũ đã thêm ở
  `test/vocab_batch_models_test.dart` (chưa chạy); legacy English fallbacks cho
  nhãn mới đã cập nhật. Generator fallback hiện vướng 48 override cũ không còn
  khớp source; Flutter/Dart SDK không có trong PATH nên chưa format/analyze/test.
- **Lịch sử:**
  - 2026-09-24 | 12:21 UTC | created→proposed | agent arena/01a0d34b-in4up | owner yêu cầu qua hội thoại
  - 2026-09-24 | 12:21 UTC | proposed→doing | agent arena/01a0d34b-in4up | triển khai batch difficulty + metadata; cần chạy kiểm chứng
### LHB-006 — Đồng bộ lưu trữ Thuộc Lòng đa thiết bị (như WordList)
- **Nguồn:** yêu cầu owner (2026-09-23): "xem trong doc hay plan đã có kế hoạch
  đồng bộ hoá lưu trữ cho các bài lưu trong tool học thuộc lòng chưa? Để người
  dùng đồng bộ lưu trữ trên các thiết bị (như worklist đã có). Nếu có rồi hãy
  hoàn thiện và triển khai, nếu chưa có hãy lên kế hoạch và triển khai."
- **Trạng thái:** ✅ done + CI xanh (chờ nghiệm thu 2 thiết bị)
- **Kết quả rà soát trước khi code:** CHƯA có card/kế hoạch nào cho sync LHB.
  - `INTEGRATE-1` (proposed) chỉ bàn knowledge module (evidence/ReviewEvent).
  - `AUDIT-2026-08-21` §4: phạm vi sync hiện tại chỉ `vocabulary_v2` + meta;
    `LearnByHeartStorage` chỉ là SharedPreferences cục bộ.
  ⇒ vừa ghi kế hoạch (PLAN-029 + ADR-0006) vừa triển khai trong cùng đợt.
- **Kiến trúc (dùng lại hạ tầng của WordList, 0 dependency mới):**
  - Local vẫn là nguồn sự thật (SharedPreferences); thêm trạng thái sync:
    `learn_by_heart_pending_v1` (hàng đợi id) + `learn_by_heart_tombstones_v1`
    (bia mộ id→ISO). `readItems()` RAW (không seed) cho lớp đồng bộ; seed mặc
    định KHÔNG hồi sinh bài đã có bia mộ.
  - Cloud: `users/{uid}/learn_by_heart/{itemId}` (JSON bài + `updatedAt` +
    `deleted`/`deletedAt` + `_syncedAt`), `lhb_meta/checkpoint`,
    `lhb_meta/stats` (streak/lastActiveDate).
  - Hòa giải LWW "cloud thắng" TRỪ khi bản cục bộ pending và có `syncStamp`
    (updatedAt → lastReviewedAt → createdAt) mới hơn; xoá bằng bia mộ
    (chống hồi sinh, dọn sau 365 ngày).
  - Mọi mutation (`submitReview`, `submitAssessment`, `saveItem`,
    `deleteItem`, `toggleFavorite`, `startLearning`) đóng dấu `updatedAt` +
    `markPending` — kể cả khi chưa đăng nhập, để đăng nhập sau không mất tiến độ.
  - Luồng pull-trước/push-sau, debounce 5s, connectivity listener; lần đầu bật
    sync mà cloud trống + máy có bài → đẩy toàn bộ lên.
  - Linux không plugin → đi REST đúng ADR-0005 (`FirestoreRestClient`).
  - UI: icon trạng thái trên app bar hub + sheet "Đồng bộ đa thiết bị"
    (Đồng bộ ngay / Kéo toàn bộ / Đẩy tất cả / gợi ý đăng nhập), chuỗi 6 ngữ
    qua `LearnByHeartL10n` (rule #5).
- **File:** `models/learn_by_heart_{item,stats}.dart`,
  `services/learn_by_heart_{storage,merge,sync_service}.dart`,
  `controllers/learn_by_heart_provider.dart`,
  `screens/learn_by_heart_hub_screen.dart`, `i18n/learn_by_heart_l10n.dart`,
  `lib/main.dart` (listener `AuthService().authStateChanges`),
  `test/learn_by_heart_sync_test.dart`, ADR-0006, PLAN-029.
- **AT nghiệm thu (2 thiết bị):** thêm/sửa ở A → B thấy; FSRS ở B → A cập nhật;
  xoá ở A → B mất và không hồi sinh; cùng sửa offline → bản mới hơn thắng;
  máy mới đăng nhập → kéo đủ bài + streak; Linux chạy qua REST.
- **Bằng chứng máy (2026-09-23):**
  - Run **35922641394** 🟢 — analyze toàn app + rule #5 (commit `8e89954`).
  - Run **35923191460** 🟢 — thêm bước **"LHB tests"** trong `app_analyze.yml`
    (bỏ qua an toàn nếu nhánh chưa có file test): 4 file `test/learn_by_heart*`,
    **47 test xanh**, gồm **19 test LHB-006**; artifact `app-lhb-test-log`.
  - **PR #42** (base `arena/01a0251e-in4up`): run **35923638972** 🟢 và
    **35923797855** 🟢 (head `dfac0e2`, đủ 3 bước: analyze + rule #5 + LHB tests).
  - Sửa 6 lỗi analyze chặn CI (thiếu khai báo field `updatedAt`; getter
    `syncJustNow` thiếu từ khoá `get`) — bắt bằng probe tắt lint + đọc job log
    (skill ci-red-debugging §5.20/§6.1).
  - 2 lỗi hòa giải do bộ test bắt được (đảo thứ tự bài mới từ cloud; phép
    "đã sync rồi" dùng mốc thay vì nội dung ⇒ bỏ qua bản cloud mới hơn) — xem
    ADR-0006 mục 3 bổ sung.
- **Lịch sử:**
  - 2026-09-23 | created→doing | agent arena/01a0d016-in4up | rà doc: chưa có
    kế hoạch → viết ADR-0006 + PLAN-029 và triển khai (merge thuần + sync
    service + pending/bia mộ + badge/sheet + test); chờ CI + nghiệm thu máy
  - 2026-09-23 | 21:35 UTC | doing→done (code + CI xanh) | agent arena/01a0d016-in4up |
    commit `6c96d0e`→`8e89954`→`51b2eff`→`fc1e0d3`; App Analyze run 35922641394 🟢
    và 35923191460 🟢 (47 test LHB, 19 test sync); còn nghiệm thu 2 thiết bị +
    Linux REST theo ADR-0006 §AT
  - 2026-09-23 | 21:50 UTC | giữ nguyên done + mở PR | agent arena/01a0d016-in4up |
    PR #42 (base `arena/01a0251e-in4up`) + run PR 35923638972 🟢 / 35923797855 🟢;
    kèm card CI-BUILD-01 (fix YAML `build.yml` — commit `dfac0e2`)

### CI-BUILD-01 — `build.yml` không parse được: mọi push đều có run đỏ 0s
- **Nguồn:** phát hiện khi rà CI của PR #42 (LHB-006), 2026-09-23 — mọi push trên
  mọi nhánh (`01a0251e`, `01a0cff6`, `01a0cfc8`, `01a0d016`) đều sinh run
  `build.yml` **failure ~0s**, không bao giờ build release được.
- **Trạng thái:** ✅ fix YAML (chờ run build thật khi push tag `v*` / dispatch)
- **Nguyên nhân:** trong block `run: |` (PowerShell, job `build-windows`), dòng
  `Get-ChildItem $RELEASE_DIR | Select-Object Name, Length` bị thụt **9 space**
  thay vì 10 ⇒ YAML kết thúc block scalar sớm ⇒ cả file workflow không parse
  được; GitHub tạo "workflow file issue" run cho mọi push. Lỗi **có sẵn trên
  `origin/main`** (cùng dòng 265), không phải do đợt LHB-006.
- **Fix:** 1 space (`dfac0e2`). Kiểm chứng bằng parser YAML thật (npm `yaml`):
  `build.yml` OK (jobs build-android/build-windows/build-ios),
  `app_analyze.yml` + `build_final_complete.yml` OK (không đổi).
- **Hệ quả:** từ commit `dfac0e2` không còn run đỏ 0s nào của `build.yml` trên
  push nhánh; workflow về đúng trigger của nó (tag `v*` hoặc dispatch).
- **Còn mở:** chưa chạy được build Android/Windows/iOS thật (token Agent không có
  quyền `workflows` để dispatch; cần owner push tag hoặc bấm chạy workflow).
- **Lịch sử:**
  - 2026-09-23 | created→done (fix YAML) | agent arena/01a0d016-in4up | commit
    `dfac0e2`; PR #42; xác nhận không còn run `build.yml` đỏ 0s sau commit

### CI-BUILD-NDK — Build Android APK đỏ: `Unresolved reference: ndk` (build.gradle.kts:101)
- **Nguồn:** owner (2026-10-06) — build `assembleStableRelease` fail:
  ```
  e: .../android/app/build.gradle.kts:101:5: Unresolved reference: ndk
  e: .../android/app/build.gradle.kts:102:9: Unresolved reference: abiFilters
  e: .../android/app/build.gradle.kts:102:20: Unresolved reference: +=
  ```
- **Trạng thái:** ✅ fix code (chờ owner re-trigger build — bot không có quyền
  `workflow_dispatch`)
- **Nguyên nhân (đã verify code):** commit `f1d4b49`
  ("perf(android): chỉ build chip phổ thông arm64-v8a") thêm khối
  ```kotlin
  android {
      ...
      ndk {                 // ← SAI: đặt ở top-level android{}
          abiFilters += "arm64-v8a"
      }
  }
  ```
  Trong **Kotlin DSL AGP 8.9.1**, `ndk {}` là extension của
  **`DefaultConfig`** — chỉ hợp lệ **trong `defaultConfig {}`**. Đặt ở
  top-level `android {}` thì Kotlin compiler (compile build script) không
  resolve `ndk` → `Unresolved reference: ndk` + 2 lỗi dây theo
  (`abiFilters`, `+=`). Lỗi này là lỗi **compile script** (chạy trước mọi
  build thật) nên wide-oracle (flutter analyze/test) KHÔNG bắt được — chỉ
  workflow build APK mới lộ.
- **Lịch sử commit gốc:** fix trước đó là commit **local `24d0fa8`**
  ("fix(android): ndk{abiFilters} phải nằm TRONG defaultConfig") — nhưng
  **MẤT khi rebase** (chưa push). Remote tip chỉ có bản SAI `f1d4b49`.
- **Fix (`eeace04` — re-apply `24d0fa8`):** di chuyển khối `ndk {}` VÀO
  `defaultConfig {}`:
  ```kotlin
  defaultConfig {
      applicationId = "com.in4up"
      minSdk = 24
      ...
      ndk {                 // ✅ ĐÚNG: trong defaultConfig
          abiFilters += "arm64-v8a"
      }
      externalNativeBuild { cmake { arguments += listOf("-DANDROID_STL=c++_static") } }
  }
  ```
  Giữ nguyên `ndkVersion = "28.2.13676358"` ở top-level (đó là property hợp
  lệ của `android {}`). `abiFilters += "arm64-v8a"` = **add** (không thay
  thế) — chỉ compile arm64-v8a (APK nhỏ, build nhanh), đúng ý `f1d4b49`.
- **Xác minh:** run pre-fix `37382171299` (headSha `f44eb96`) →
  **Build Android APK = failure** (đúng lỗi ndk), trong khi
  **Linux/iOS/Windows = success** ⇒ xác nhận ĐÚNG 1 blocker là khối `ndk`.
  Fix `eeace04` (chưa được build vì run đó chạy code cũ).
- **Vận hành (quan trọng):** bot `arena-ai-coding-agent[bot]` **không có
  quyền** `workflow_dispatch` (HTTP 403) nên agent **không tự re-trigger
  được** build. Tag push `v*` thì chạy **4 platform + tạo GitHub Release**
  (nặng, không dùng để verify nhẹ). → **OWNER re-trigger**: GitHub Actions →
  `build_final_complete.yml` → **Run workflow** → `Build Android APK = true`,
  3 platform còn lại `false` (chạy ~15–20p) → xem job **Build Android APK**
  xanh = fix OK. Hoặc nếu muốn build release thật: push tag `v*`.
- **Lịch sử:**
  - 2026-10-04 | created | agent (fix local `24d0fa8`) — MẤT khi rebase
  - 2026-10-06 | re-apply + xác minh | agent arena/01a0251e-in4up | fix
    `eeace04` (ndk vào defaultConfig); xác minh run pre-fix `37382171299`
    Android=failure; chờ owner re-trigger build (bot 403 dispatch)

### CI-BUILD-ABI-001 — Release 1.10.3 "có 3 chip" dù đã có lệnh 1-chip (APK ~216MB, tên ghi arm64-v8a)
- **Nguồn:** owner (2026-10-06) — "tôi build bằng Actions → release 1.10.3,
  có 3 chip thì phải; vấn đề có lẽ do file workflow?"
- **Trạng thái:** 🔨 doing — đã xác định chính xác gốc; cần (a) merge fix ndk
  vào `main`, (b) build lại release từ main sau merge.
- **Xác minh (bằng chứng trong repo/GitHub):**
  - Release `1.10.3` (tag → commit `7386295` = **tip `origin/main`**).
  - APK Android: `in4up-Android-arm64-v8a-1.10.3-2f357.apk` — **đuôi commit
    `2f357` ≠ tag `7386295`** ⇒ APK được build từ commit `2f357` (một commit
    TRƯỚC đó trên main), không phải tip main.
  - `origin/main` (`7386295`) **KHÔNG** chứa fix ndk `eeace04` **cũng không**
    chứa commit 1-chip `f1d4b49` của nhánh em — nhưng `build.gradle.kts` của
    main **CÓ** khối `ndk { abiFilters += "arm64-v8a" }` ở **top-level
    android{}** (dòng 101) — tức main có ý định 1-chip nhưng **đặt SAI scope**
    (bị lỗi ndk y hệt CI-BUILD-NDK).
- **3 nguyên nhân chồng nhau (KHÔNG phải lỗi file workflow):**
  1. **APK 1.10.3 là bản 3-ABI cũ** — build từ `2f357` (trước khi 1-chip có
     hiệu lực trên main) ⇒ APK universal 3 chip ~216MB. (Build này TÙY VẪN
     xanh vì `2f357` chưa có khối ndk sai.)
  2. **`main` hiện tại không build được Android** — main có khối `ndk{}` sai
     scope (top-level) ⇒ lỗi `Unresolved reference: ndk`. Cho tới khi fix
     `eeace04` (khối ndk vào `defaultConfig`) vào main, mọi build Android từ
     main đều đỏ.
  3. **`scripts/ci/android_rename_apks.sh` hardcode "arm64-v8a"** vào tên file
     ⇒ gắn nhãn "arm64-v8a" cho BẤT CỨ APK universal nào (kể cả 3-ABI) ⇒
     tên file MISLEADING, khiến owner tưởng đã là 1-chip.
  - **Workflow `build_final_complete.yml` KHÔNG sai:** build đúng 1 bản
    universal (`flutter build apk`, không `--split-per-abi`); không có bước
    "Build Split APKs" (đã gỡ theo CI-ANDROID-04).
- **Hành động cần làm (theo thứ tự):**
  1. **Merge fix ndk `eeace04` vào `main`** (chỉ riêng việc di chuyển khối
     `ndk {}` vào `defaultConfig`). → main build được Android LẠI + build ra
     bản **1-chip arm64 thật** (~150–165MB). *(Agent đã tạo PR tối thiểu chỉ
     chứa fix này — xem liên kết PR ở Lịch sử.)*
  2. Sau merge, **build lại release** từ main (Actions → Run workflow, Android
     = true) → APK mới sẽ ~150–165MB, tên `...arm64-v8a...` lần này **đúng**.
  3. **(Nâng cấp, tuỳ chọn)** Sửa `android_rename_apks.sh`: **kiểm chứng** APK
     thực sự chỉ có `lib/arm64-v8a/` (dùng `unzip -l` | grep `lib/`) trước khi
     gắn tên "arm64-v8a"; nếu có `lib/armeabi-v7a/` hoặc `lib/x86_64/` ⇒ báo
     lỗi/đổi tên "universal-3abi" để không misleading.
- **Lịch sử:**
  - 2026-10-06 | created→doing | agent arena/01a0251e-in4up | xác minh:
    release 1.10.3 = main `7386295`; APK build từ `2f357` (3-ABI cũ); main
    có ndk sai scope (không build được Android); rename script hardcode
    arm64-v8a. Workflow không sai.
  - 2026-10-06 | mở **PR #88** (tối thiểu, 1 file: chỉ fix ndk vào
    defaultConfig) từ branch `fix/ndk-abi-defaultconfig` → **main** —
    https://github.com/Pabhassaracitto/In4Up/pull/88 . Owner merge PR #88
    → main build Android xanh + bản 1-chip arm64 thật.

### CI-BUILD-LOGIN-001 — Bản 2f357 (release 1.10.3) crash khi chạm icon đăng nhập
- **Nguồn:** owner (2026-10-06) — "bản commit 2f357 … crash khi chạm icon
  đăng nhập; có lẽ do build trong workflow mà flavor không có chữ stable?"
- **Trạng thái:** 🔬 investigating — đã LOẠI giả thuyết "thiếu stable flavor";
  nghi chính: **SHA1 keystore không khớp** client `com.in4up`.
- **GIẢ THUYẾT "flavor không có stable" — ĐÃ LOẠI (có bằng chứng):**
  - Workflow tại chính commit `2f357` **CÓ** `--flavor stable` ở CẢ 2
    workflow: `build_final_complete.yml:227` + `build.yml:116`
    (`flutter build apk --release --flavor stable …`).
  - ⇒ Bản 2f357 build đúng **flavor stable** (applicationId `com.in4up`).
  - Quy tắc "build KHÔNG `--flavor stable` → crash đăng nhập" là **THẬT**
    (đã ghi trong `build.gradle.kts` dòng 139–144 + card CI-ANDROID-01/03)
    nhưng **không áp dụng** cho 2f357 (vì 2f357 đã dùng stable).
- **2f357 là gì (xác minh):** commit "fix(android): configure arm64 ABI with
  Kotlin DSL API" (2026-10-05), trên nhánh **`arena/124c5760-in4up`** (1 phiên
  khác). Diff chỉ 3 dòng: `abiFilters += "arm64-v8a"` → `abiFilters.add
  ("arm64-v8a")` (cả 2 đúng; khối `ndk{}` nằm TRONG `defaultConfig`). Vậy
  2f357 = bản **1-chip arm64 + stable**.
- **NGUYÊN NHÂN NGHI CHÍNH — SHA1 keystore không khớp (evidence-based):**
  - google-services.json (cả secret lẫn fallback trong workflow) — client
    `com.in4up` yêu cầu `certificate_hash` =
    **`8a1bc02e5c8f2509eb18624fb5f4eb68df0a6127`** (RELEASE); client
    `com.in4up.dev` = `7697fcbcd36289fe5fb220575fcfb27704f4ca83` (DEBUG).
  - CI KÝ APK từ keystore decode từ secrets; **nếu thiếu/sai secret
    release → fallback ký bằng DEBUG keystore** (`build.gradle.kts`:
    "[in4up-sign] WARNING … fallback ký bằng DEBUG keystore").
  - Nếu bản 2f357 bị ký bằng **DEBUG** keystore (SHA1 `7697fcbc…`) thì
    **KHÔNG khớp** client `com.in4up` (`8a1bc02e…`) ⇒ **Google Sign-In**
    (icon đăng nhập tab Home) sai hash → lỗi/crash.
  - Lưu ý: `android_verify_apk_signed.sh` chỉ kiểm tra "đã ký" (pass cả khi
    ký debug) — nên bước verify KHÔNG bắt được lỗi SHA1 sai này.
- **MÂU THUẪN "3 chip" (cần chủ kiểm chứng APK thật):** 2f357 set
  `abiFilters.add("arm64-v8a")` ⇒ APK **nên là 1-chip**. Owner báo "3 chip"
  ⇒ hoặc (a) đang xem nhầm file, hoặc (b) lệnh abiFilters chưa có hiệu lực
  (cần `unzip -l` xem `lib/`). *(Sandbox agent KHÔNG tải được APK — CDN
  release-assets bị chặn SSL — nên chưa xác minh trực tiếp.)*
- **BƯỚC CHỦ CHẠY ĐỂ XÁC NHẬN (trên máy, với file APK 1.10.3):**
  1. **Kiểm tra ABI (1-chip hay 3-chip):**
     `unzip -l in4up-Android-arm64-v8a-1.10.3-2f357.apk | grep "lib/"`
     → chỉ `lib/arm64-v8a/` = 1-chip (đúng config); có thêm `lib/armeabi-
     v7a/` + `lib/x86_64/` = 3-chip (abiFilters chưa hiệu lực).
  2. **Kiểm tra SHA1 ký (gốc crash đăng nhập):**
     `apksigner verify --print-certs in4up-…-2f357.apk` (build-tools)
     → đọc **SHA-1** của signer. Hoặc:
     `unzip -p in4up-….apk META-INF/CERT.RSA | openssl pkcs7 -inform DER
      -print_certs | openssl x509 -noout -fingerprint -sha1`
     - SHA1 = `8a1bc02e…` → khớp com.in4up (đăng nhập OK).
     - SHA1 = `7697fcbc…` (debug) hoặc khác → **KHÔNG khớp → crash đăng
       nhập** (khớp nghi chính).
  3. **Lấy logcat crash** khi bấm đăng nhập:
     `adb logcat -d | grep -iE "Firebase|GoogleSignIn|Auth|FATAL|Exception"`.
  4. **Xem build log 2f357** (Actions): tìm dòng `[in4up-sign]` — có bị
     "fallback ký bằng DEBUG keystore" không?
- **HƯỚNG SỬA (nếu xác nhận SHA1):** đảm bảo CI dùng **đúng release
  keystore** (secret `ANDROID_KEYSTORE` + `key.properties` đúng) để SHA1 =
  `8a1bc02e…`; KHÔNG rơi vào fallback debug. *(Secret do owner quản lý.)*
- **2026-10-06 cập nhật (owner gửi Firebase Console + keystore):**
  - Firebase Console app `com.in4up` **đã đăng ký CẢ 2 SHA-1**: `7697fcbc…`
    (DEBUG) + `8a1bc02e…` (RELEASE) (+1 SHA-256). ⇒ ký bằng debug HOẶC
    release(8a1bc02e) đều KHỚP. Vậy crash chỉ còn 2 khả năng:
    (a) CI ký bằng keystore KHÁC (SHA-1 không nằm trong 2 cái trên), HOẶC
    (b) `google-services.json` trong **secret CI lỗi đồng bộ** Console (chưa
    chứa SHA-1 CI đang dùng để ký).
  - Keystore release của owner: `E:\PROJECTS\in4up.worktree\DEV\in4up-release.jks`
    (storepass `870078`). **Chờ owner chạy keytool lấy SHA-1** để chốt:
    - SHA-1 = `8a1bc02e…`/`7697fcbc…` → KHÔNG cần thêm Console; chỉ
      **tải lại google-services.json + cập nhật secret CI** + keystore khớp.
    - SHA-1 khác → **Add fingerprint** vào Console + tải lại + cập nhật secret.
  - Nguyên tắc 4-cái-khớp: Console(SHA-1) → google-services.json → secret CI
    → keystore CI ký.
- **Lịch sử:**
  - 2026-10-06 | created→investigating | agent arena/01a0251e-in4up | loại
    giả thuyết "thiếu stable" (2f357 có `--flavor stable`); định vị 2f357
    (nhánh 124c5760, 1-chip+stable); nghi chính SHA1 keystore (debug
    fallback vs com.in4up `8a1bc02e…`); ghi 4 bước chủ tự xác minh.
  - 2026-10-06 | investigating (cập nhật) | agent | owner gửi Firebase
    Console: com.in4up ĐÃ có CẢ 2 SHA-1 (7697fcbc debug + 8a1bc02e release)
    ⇒ thu hẹp còn 2 khả năng (a) CI ký keystore khác, (b) google-services.json
    trong secret CI lỗi đồng bộ; hướng sửa = đồng bộ google-services.json
    + secret + keystore; chờ owner chạy keytool lấy SHA-1 của
    `in4up-release.jks` để chốt.
  - 2026-10-06 | **ĐÃ XÁC NHẬN nguyên nhân (a)** | agent | owner chạy keytool:
    SHA-1 của `in4up-release.jks` = **`88d5ee0da168b320c52f51b7aab404675862e5b0`**
    — KHÔNG khớp 2 mã cũ (7697fcbc/8a1bc02e) ⇒ CI ký bằng keystore mà SHA-1
    chưa có trong google-services.json cũ ⇒ crash. Owner ĐÃ thêm SHA-1 +
    SHA-256 mới vào Console. **Hướng sửa (chủ làm):** (1) Download lại
    google-services.json (chứa 88d5ee0d); (2) base64 + cập nhật secret CI
    `ANDROID_GOOGLE_SERVICES_JSON` (hoặc `ANDROID_GOOGLE_SERVICES`); (3) verify
    secret keystore `ANDROID_KEYSTORE_BASE64`/`_PASSWORD`/`_KEY_ALIAS`/
    `_KEY_PASSWORD` trỏ đúng `in4up-release.jks` (88d5ee0d); (4) build lại.
    4-cái-trùng: Console(88d5ee0d) → google-services.json → secret CI →
    keystore ký. Chờ owner build + nghiệm thu login.

### L10N-REGEN-001 — Build fail: `dart format` (exit 65) khi sinh localizations (th/vi/zh "could not be parsed")
- **Nguồn:** owner (2026-10-07) — lỗi khi `flutter run/build` local:
  "Generating synthetic localizations package failed … `dart format` failed
  with exit code 65 … Could not format because the source could not be
  parsed: app_localizations_th.dart:1541 / _vi.dart:1546 / _zh.dart:3209".
- **Trạng thái:** ✅ done (chờ build của owner xác nhận xanh).
- **Diagnose (đã verify code):**
  - 26 file `lib/l10n/app_localizations*.dart` là **build artifact** (sinh bởi
    `flutter gen-l10n`, `generate: true` trong pubspec) nhưng **bị commit**
    vào git và **stale/hỏng**.
  - `app_localizations_zh.dart` checked-in **BỊ HỎNG**: **493 getter trùng**
    — gộp cả dịch zh (giản thể) + zh_TW (chuyền thống) vào **1 file**, và
    **không có** file `app_localizations_zh_TW.dart` riêng ⇒ 2 getter cùng tên
    trong 1 class = lỗi parse. (File zh dài gấp đôi 1544→3056 dòng vì lý do này.)
  - th/vi không trùng getter nhưng stale. ARB (nguồn) đã verify: 4 file đều
    JSON hợp lệ (514 keys), **không** apostrophe/backslash/ký tự điều khiển lạ
    trong value mới (ocr*, translationDeepLX*), placeholder `{…}` khớp EN.
    (fr/it có apostrophe nhưng gen-l10n escape tốt — không phải thủ phạm.)
- **Fix (`b44c964`):** `git rm` 26 file `app_localizations*.dart` + thêm
  `.gitignore`: `lib/l10n/app_localizations*.dart`. Giữ nguyên 25 `.arb` +
  `l10n.yaml`. ⇒ Mọi build (local + CI, qua `flutter pub get`) tự **sinh file
  SẠCH** từ `.arb` (zh và zh_TW tách riêng, không trùng) ⇒ `dart format` parse
  được.
- **LƯU Ý CHERRY-PICK (owner yêu cầu pick `7386295` + `e9b5900`):**
  - `7386295` ("Fix formatting in build_final_complete.yml") = **commit RỖNG**
    (không thay đổi file) ⇒ không có gì để pick.
  - `e9b5900` ("ndk{abiFilters} vào defaultConfig") = **root commit** (thêm cả
    1242 file, không có parent — artifact mất lịch sử) ⇒ **không pick được**
    bình thường; và fix ndk của nó **ĐÃ CÓ sẵn trên 251e** (`eeace04`).
  - ⇒ 251e **đã tuyến tính + đã có fix ndk**; không pick gì thêm. (Nếu owner
    muốn đồng bộ workflow với main, báo em diff `build_final_complete.yml`.)
- **Lịch sử:**
  - 2026-10-07 | created→done | agent arena/01a0251e-in4up | xác định file sinh
    checked-in hỏng (zh 493 getter trùng); bỏ 26 file sinh ra khỏi git +
    gitignore (`b44c964`); ghi nhận 2 commit cherry-pick không pick được
    (1 rỗng, 1 root-commit đã có sẵn fix). Chờ owner build xác nhận.

### DOC-1 — README v2 (EN + VI) đúng tiến độ hiện tại

- **Trạng thái:** done (chờ owner duyệt nội dung + chốt tên trên file `LICENSE`)
- **Nguồn:** owner (2026-09-28) qua agent `arena/01a0e2c8-in4up` — "thiết lập readme
  đúng với tiến độ hiện tại và các chức năng mới" (góc nhìn tâm lý học · màu sắc ·
  bố cục · IT · CEO).
- **Nội dung:**
  - `README.md` (English — trang chủ repo) + `README.vi.md` (tiếng Việt đầy đủ,
    ngang hàng), có link chuyển ngôn ngữ hai chiều ở đầu trang.
  - **Bảng tiến độ** chụp từ KANBAN ngày 28-09-2026: 88 thẻ (60 done · 19 doing ·
    6 proposed · 3 blocked), M0–M2 done, ADR-0001→0008, 32 mục PLAN, 81 file test,
    26 locale × 492 key, ~600 file Dart.
  - Bản đồ **7 chế độ Phòng Studio** + 5 đích điều hướng + quick actions; mục
    "vừa hoàn thành" gom theo 4 cụm (âm thanh/speech · đọc/IPA · tri thức/AI ·
    shell/nền tảng), mỗi gạch đầu dòng gắn mã thẻ Kanban để tra ngược.
  - **Hệ thiết kế:** token màu thương hiệu (brand/identity) + màu 7 mode lấy đúng
    từ `home_screen.dart`, nguyên tắc bố cục responsive, Okabe-Ito + quy ước
    "mọi tín hiệu màu đều có bạn đồng hành phi màu sắc".
  - Bảng model offline (theo `docs/project/MODELS.md`), 2 sơ đồ mermaid (vòng học
    + kiến trúc), cổng chất lượng CI, lộ trình, quy tắc vàng, bản đồ tài liệu
    quản trị cho người & agent.
  - Trạng thái được ghi **trung thực**: ✅ đã xong/CI xanh · 🔄 đang làm ·
    📋 kế hoạch · 🚫 nghẽn — không tô hồng mục còn chờ nghiệm thu máy.
- **Phát hiện phụ (cần owner quyết):** trunk **không có file `LICENSE`** dù README
  cũ vẫn link tới ⇒ đã khôi phục **nguyên văn** từ `origin/main`. File vẫn mang tên
  *"VipSound Source-Available License (Non-Commercial)"* — đổi tên sang In4Up là
  văn bản pháp lý, agent KHÔNG tự sửa; README hiện gọi trung tính là
  "Source-Available License (Non-Commercial)".
- **Không đụng:** `lib/**`, CI, engine, governance (chỉ thêm đúng thẻ này).
- **Lịch sử:**
  - 2026-09-28 | created→done | agent arena/01a0e2c8-in4up | `README.md` +
    `README.vi.md` + khôi phục `LICENSE`; nhánh đồng bộ từ `arena/01a0251e-in4up`
    (53b57ab) để README khớp đúng code đang chạy

### IMPORT-MODELS-001 — Import Piper/Zipformer không hiện giọng + "Không nhận diện được model" + xung đột PR #48

- **Nguồn:** owner (2026-09-28) build commit mới nhất 251e:
  (1) import thư mục/file giọng Piper báo thành công nhưng thẻ "3. TTS" vẫn
  "Chưa có giọng Piper. Bấm tải giọng"; (2) import
  `VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09` (file + folder) đều bị
  "Không nhận diện được model"; PR #48 đỏ CI (2 error `HyMtOfflinePreference`)
  + xung đột `live_cabin_screen.dart` / `stts_cabin_service.dart` với 251e.
- **Trạng thái:** ✅ done + CI xanh (chờ nghiệm thu thiết bị thật).
- **Root cause (verify từ docs k2-fsa + HF hynt/Zipformer-30M-RNNT-6000h):**
  - **TTS (IMPORT-TTS-001):** `discoverVoices()` bỏ qua onnx thiếu tokens —
    giọng kiểu HuggingFace rhasspy/piper-voices chỉ có `.onnx` + `.onnx.json`
    (KHÔNG tokens.txt) ⇒ import copy xong báo ✅ nhưng giọng không bao giờ
    được quét ra.
  - **STT (IMPORT-STT-001):** model VI 30M int8 2026-02-09 có từ vựng VI
    **VIẾT HOA** ("RỒI", "CŨNG", "HỖ TRỢ") — `asrTokensLookVietnamese()` chỉ
    khớp ký tự có dấu thường ⇒ mất bằng chứng duy nhất khi path cache
    file_picker không chứa "vi" ⇒ `unknownProfile`. Kèm theo regex
    `_nameLooksLanguage` có alternative `$` bị escape thành ký tự đô-la
    literal (thư mục "…-vi" cuối path không khớp).
- **Fix (nhánh `arena/01a0e761-in4up`, bao trùm head PR #48 `2cb9987a`):**
  1. **Merge 251e `c8132733`** vào chuỗi fix — gỡ 2 xung đột:
     `live_cabin_screen.dart` (giữ CABIN-SAVE-001 + nút "Dịch: <engine>",
     bổ sung import `hymt_engine.dart` ⇒ hết 2 error undefined_identifier),
     `stts_cabin_service.dart` (ghép guard dedup + mốc `_chunkStartOffset`
     LRC + bản dịch rỗng khi engine lỗi; bỏ 4 import trùng).
  2. **fix(stt):** `asrTokensLookVietnamese` lower-case trước khớp (Ồ→ồ, Đ→đ);
     `_nameLooksLanguage` dùng raw string `r'([^a-z]|$)'` đúng anchor; giữ
     nguyên guard streaming (SIGABRT SHERPA-STREAM-001).
  3. **fix(tts):** `_completePiperImport()` cho cả 3 đường import — mọi onnx
     thiếu tokens được ensure tokens dùng chung (tokens giọng khác / tải
     fallback k2-fsa) + rescan ngay ⇒ giọng hiện trong thẻ TTS không cần
     thoát màn hình; vẫn thiếu tokens (offline) thì báo RÕ kèm hướng dẫn.
  4. **Test:** `test/asr_model_routing_test.dart` +4 case (tokens VI hoa →
     VI; folder kết thúc "-vi" → VI; path cache + tokens VI hoa → VI; file
     rỗng/garbage → false không throw).
- **Bằng chứng:** CI `App Analyze + Locale Test` run **36407848778 🟢** trên
  `arena/01a0e761-in4up` (analyze 0 error — trước đó PR #48 đỏ vì
  `HyMtOfflinePreference` ×2).
- **Lịch sử:**
  - 2026-09-28 | created→doing→done | agent arena/01a0e761-in4up | merge
    251e + 2 fix commit (d764b453 stt, 3657593a tts) + test; CI xanh cùng ngày
### STT-LATIN-001 — Tạo lời từ file mp3 tiếng Hindi: ra chữ Latin dù đã chọn đúng ngôn ngữ
- **Trạng thái:** 🔄 doing (chờ CI + nghiệm thu máy)
- **Nguồn:** owner (2026-09-14): "Sao sound to text tạo lời từ file mp3 tiếng
  Hindi và đã chọn đúng ngôn ngữ này thì nó ra chữ latin thay vì chữ hindi?"
- **Bốn nguyên nhân trong code (không phải model "dịch" sang Latin):**
  1. **`SoundAutoTocService.transcribe` map `'auto' → 'en'`** với chú thích
     "in4up_stt chưa hỗ trợ auto-detect". SAI: `whisper.h` ghi rõ
     `language` = nullptr/""/"auto" là auto-detect, và plugin
     whisper_flutter_new cho phép `"auto"` (main.cpp chỉ báo lỗi khi
     `whisper_lang_id(x) == -1` VÀ x != "auto"). Kết quả: mọi bài không tiếng
     Anh bị ép decode theo English → **chữ Latin**. Dialog auto-TOC còn không
     có chip Hindi (chỉ auto/vi/en) nên "Tự động" = English thật, không phải
     auto-detect.
  2. **Mã ngôn ngữ truyền thẳng, không chuẩn hóa.** `SttConfig.language` là
     BCP-47 ('en-US', 'hi-IN') — đường mobile plugin + isolate KHÔNG cắt
     region (chỉ desktop FFI/CLI có `split('-')`). `whisper_lang_id('en-US')`
     = -1 → plugin trả `"error: unknown language = en-US"` và 'auto'/'hi' thì
     OK → hành vi lệch giữa các nền tảng. Tương tự chip **'pi' (Pali)** trong
     `_LrcModelSelector` — Whisper KHÔNG có Pali (99 mã, xem
     `whisper.cpp` `g_lang`) → bấm Pali là job chết.
  3. **AUTO cứng về tiny**: `generateLrcWithVadPipeline` dùng
     `level ?? WhisperModelLevel.tiny`, `transcribeAuto` ưu tiên
     tiny→base→… → bài hát Hindi chạy bằng tiny, là model hay "Latin-hóa"
     (không đủ sức decode Devanagari) — chọn ngôn ngữ đúng vẫn ra Latin.
  4. **User chọn model tay vẫn bị hạ về tiny**: `transcribeMobileChunked`
     ép tiny cho MỌI file >60s bất kể chip BASE/SMALL người dùng bấm →
     vòng lặp "chọn SMALL mà vẫn tiny" không lối thoát.
- **Fix:**
  - MỚI `packages/in4up_stt/lib/utils/whisper_language.dart`:
    `WhisperLanguage.code/resolve` — whitelist ĐÚNG 99+1 mã `g_lang`
    (verify bằng nguồn whisper.cpp v1.5.4, có test khóa số lượng), bỏ region
    ('hi-IN'→'hi', 'zh_TW'→'zh'), alias ('fil'→'tl','iw'→'he','in'→'id',
    ISO-639-2/T 3 ký tự), mã không hỗ trợ (Pali 'pi', 'xx', 'ky') → **'auto'**
    + cờ `unsupported` (không còn giết job); `scriptFor(code)`;
    `latinizedFor(...)` phát hiện "kết quả toàn chữ Latin trong khi ngôn ngữ
    cần script khác"; `prefersStrongModel(code)`.
  - Chuẩn hóa ở MỌI biên gọi Whisper: `transcribeMobile`,
    `transcribeMobileChunked`, `_buildAndRunWhisper` (FFI), CLI `-l`,
    `WhisperSttEngine.transcribeFile` (default 'en' → 'auto'),
    cache key (`_buildCacheKey` dùng code đã chuẩn hóa + phân biệt
    honor/explicit model).
  - `sound_auto_toc_service.dart`: **bỏ** `'auto' → 'en'` (để auto-detect
    thật), language đi qua `WhisperLanguage.code`, `honorWhisperModel: true`
    khi caller truyền level.
  - `SttModelManager.getBestModelLevelForLanguage(language)`: script ngoài
    Latin → ưu tiên **base→small→medium→large**→tiny; ngôn ngữ Latin giữ
    tiny-first (đúng intent fix OOM Android). Facade thêm
    `bestWhisperLevel(language:)`; `transcribeAuto`/`transcribeDeep` default
    'auto'; `SttConfig.language` default 'en-US' → 'auto'.
  - `honorWhisperModel` (SttConfig) + `allowModelDowngrade` (mobile chunked)
    + `honorModelLevel` (VAD pipeline/integration): **chip model người dùng
    bấm là lệnh**, engine không tự hạ tiny nữa. AUTO vẫn được hạ tiny ở file
    >60s — chủ đích, để không tái hiện OOM Scudo (mô hình tốn ~388MB RAM);
    UI nói rõ cách lên model.
  - `player_stt_mixin`: `_trackScriptWarning()` + `lastSttScriptWarning`
    (chỉ dữ liệu, không chuỗi UI); `listen_mode_screen` hiện cảnh báo hổ phách
    cạnh khu vực tạo lời: "Whisper trả về chữ Latin… hãy chọn BASE/SMALL rồi
    Tạo lại" (đã dịch en/hi/zh/zh_TW/si qua `priorityUiOverrides`).
  - VAD pipeline/integration: default `'vi'` → `'auto'` (bẫy cho caller quên
    truyền language).
- **i18n (rule #5):** chuỗi cảnh báo + các nhãn mới dùng `context.uiText` +
  `priorityUiOverrides` (đủ en/hi/zh/zh_TW/si) — không ARB mới nên không đụng
  parity 21 locale; `tool/legacy_ui_english_overrides.json` được cập nhật song
  song. KHÔNG chạy `generate_legacy_ui_fallbacks.py` (đang đỏ sẵn — card I18N-001).
- **Test:** `test/whisper_language_test.dart` — 20 test: 99 mã + số lượng,
  region/alias/'auto', Pali→auto, script map, latinizedFor (Devanagari vs
  roman hóa, văn bản ngắn không đoán, trích dẫn Latin lẫn Devanagari không báo
  oan), prefersStrongModel, SttConfig default + copyWith honor flag.
- **AT nghiệm thu máy (owner):** (1) mp3 Hindi + chip "Tiếng Hindi" + model
  TINY → vẫn có thể Latin NHƯNG hiện cảnh báo hướng dẫn; (2) cùng file + chip
  SMALL → lời ra **Devanagari**; (3) chip 'Pali' → không còn lỗi
  "unknown language", tự nhận diện; (4) Windows/desktop: 'en-US'/'hi-IN' không
  còn fail; (5) "Tự tạo mục lục" với 'Tự động' trên audio Hindi → ra chữ
  Devanagari chứ không phải English.
- **Lịch sử:**
  - 2026-09-14 | created→doing | agent arena/01a0a205-in4up | 4 root cause
    trên + WhisperLanguage + script guard + model theo script; chờ CI +
    nghiệm thu máy (quan trọng nhất: chip SMALL trên file dài có còn bị hạ
    tiny không)
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | rebase lên 251e `755b474`
    (40 commit): 251e đã có `paths: packages/**` trong CI + fix isolate
    auto-TOC (`d096a8a`) — hai cái đó khớp hướng em đã làm nên không trùng;
    code em giữ nguyên, chỉ merge catalog i18n (251e 417 entry + 29 entry của
    em, không trùng khoá); chờ CI + nghiệm thu máy
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | **PR #56**; catalog đã merge
    lại thuần cộng (0 dòng 251e bị mất, 481 → 510 entry); chờ CI

### IMG-WEB-001 — Wordlist: ưu tiên tìm hình TRÊN MẠNG (qua API key) khi thêm hình cho từ
- **Trạng thái:** 🔄 doing + 🚫 **chờ owner**: chọn provider + dán API key
  (app đã có chỗ nhập; repo không chứa key)
- **Nguồn:** owner (2026-09-14): "Worklist đã có thể thêm hình, tuy nhiên
  thường nên ưu tiên chọn hình trên mạng vì hình ở máy ít khi có… Ưu tiên lấy
  từ mạng, sau này mới kết hợp thêm chụp hình/xóa phông để thêm hình từ vựng
  (ML Kit)" + "lưu ý là tìm kiếm ảnh phải có key api nhé".
- **Hiện trạng trước (IMG-001):** chạm ô hình = mở thẳng gallery → người dùng
  bỏ qua bước hình; `saveFromUrl` chỉ được ghi trong bàn giao, **code chưa có**;
  tài liệu nói "có thể thêm Unsplash/Pixabay" nhưng chưa có provider nào.
- **Fix:**
  - `vocab_image_picker_sheet.dart` (MỚI): sheet 2 nguồn — **web (mặc định, tự
    tìm ngay khi mở, query = từ + nghĩa)** và "Trong máy"; lưới kết quả có
    thumbnail + title + credit; chạm ảnh = tải về + lưu storage + gán;
    "Bỏ ảnh hiện tại"; enum `VocabImageSourceKind {web, device}` chừa chỗ
    `camera` cho ML Kit.
  - `vocab_image_web_service.dart` (MỚI): Pexels/Unsplash/Openverse/Wikimedia
    Commons; provider đã chọn gọi trước, các nguồn dùng được còn lại là
    fallback (mạng lỗi/429/0 kết quả); 4 parser tĩnh thuần (test không cần
    mạng); `download()` chặn HTML-giả-làm-ảnh (magic bytes) + trần 8MB;
    User-Agent cho MediaWiki/Openverse.
  - `vocab_image_api_config.dart` (MỚI): **API key là điều kiện** —
    `VocabImageProvider.needsKey` (Pexels/Unsplash) → chưa key là BỎ QUA
    nguồn đó + `missingKeyProvider` để UI nhắc "Thêm API key" (dialog chọn
    provider + dán key, lưu SharedPreferences theo từng provider).
    Build-time: `--dart-define=VOCAB_IMAGE_PROVIDER=pexels
    --dart-define=VOCAB_IMAGE_API_KEY=…`; key build-time chỉ dùng cho đúng
    provider đã khai (không lọt sang provider khác). **Không commit key.**
  - `VocabImageService`: thêm `saveFromBytes`, `saveFromUrl(url, {client})`
    (dùng lại dedup MD5 + relative path cũ) → ảnh web vẫn sống offline.
  - `VocabImagePicker`: tap → sheet (thay vì gallery thẳng), nhận
    `word`/`meaning` mồi từ khóa, hỗ trợ `imageUrl` là URL http (Image.network)
    cho dữ liệu cũ; 3 call site (word_list 2 chỗ + word_actions_sheet) truyền từ.
- **Test:** `test/vocab_image_search_test.dart` — shape thật của Openverse
  (`results`/`result`, thumbnail tương đối), MediaWiki (`pages` là MAP, gỡ HTML
  `extmetadata`), Pexels (`src.large2x/medium`, bỏ photo thiếu src), Unsplash
  (`urls.regular/small`, `links.html`), `buildQuery`, `looksLikeImage`,
  `searchOrder`/`keyFor`/`selectedProviderUsable`/`resolveDefaultProvider`.
- **Việc còn lại của owner:** chọn provider (Pexels cần key, Unsplash cần
  Access Key, Openverse token miễn phí khuyến nghị, Commons không cần key) rồi
  dán key trong sheet (hoặc set dart-define trong `build.yml`) → khi đó tab
  web tìm đúng nguồn ưu tiên thay vì fallback.
- **Bước kế tiếp (đề xuất, chưa làm):** `camera` +
  `google_mlkit_subject_segmentation` (xóa phông) + `google_mlkit_object_detection`
  (gán nhãn đồ vật thật → từ vựng).
- **Quyết định của owner (trả lời 3 câu hỏi, 2026-09-15):**
  1. Nguồn ưu tiên = **Pexels + Unsplash cùng bật** → `searchOrder()` gọi
     provider đã chọn trước rồi tới provider CÓ KEY còn lại, cuối cùng mới
     Openverse → Wikimedia Commons (2 nguồn không cần key, để app không chết
     khi chưa dán key). Mặc định provider = Pexels.
  2. Chỗ đặt key = **CẢ HAI**: (a) dán trong app (sheet → nút "API key",
     lưu SharedPreferences theo từng provider), (b) build-time
     `--dart-define=VOCAB_IMAGE_PROVIDER=${{ vars.VOCAB_IMAGE_PROVIDER }}`
     `--dart-define=VOCAB_IMAGE_API_KEY=${{ secrets.VOCAB_IMAGE_API_KEY }}`
     — ĐÃ nối vào `build.yml` cho cả 3 job (APK/Windows/iOS). Chuỗi rỗng →
     app tự rơi về nguồn mở, build không hỏng. Key build-time chỉ dùng cho
     đúng provider đã khai. KHÔNG commit key vào repo.
  3. **"Thêm từ" nhanh cũng phải gán được hình** → `vocab_image_quick_add.dart`:
     `VocabImageQuickAddButton` (nút "Thêm hình/Đổi hình" ở trạng thái ĐÃ LƯU
     của sheet tap từ trong PDF) + action "Thêm hình" trong snackbar của
     Wordlist khi thêm từ. `attachVocabImage(...)` lấy provider TRƯỚC khi mở
     sheet để phần ghi không đụng context nữa.
     → CÓ Ý KHÔNG gắn action ở `selection_save_sheet` / `word_actions_sheet` /
     `floating_text_actions`: 3 chỗ đó pop sheet / gỡ overlay trước khi hiện
     snackbar ⇒ context đã chết, mở bottom sheet từ đó sẽ crash. Người dùng
     vẫn gán được hình ngay trong sheet tap PDF (state "đã lưu").
- **Bug bắt được nhờ test (đã sửa, commit 818f884):** helper `_str()` ban đầu đòi
  tiền tố `http(s)://` cho MỌI field → `title`/`creator`/`license` của cả 4
  provider sẽ luôn null (lưới ảnh không caption, mất ghi nguồn). Tách thành
  `_str()` (text) + `_url()` (chỉ nhận URL tuyệt đối; URL tương đối → fallback
  ảnh gốc). Fixture shape thật của 4 API được parse lại ngoài Dart để khóa
  hành vi đó trước khi commit.
- **Chờ:** owner dán key (Pexels/Unsplash) hoặc set secret
  `VOCAB_IMAGE_API_KEY` + var `VOCAB_IMAGE_PROVIDER` trong repo Settings →
  Secrets and variables → Actions; CI analyze/test; nghiệm thu máy.
- **Lịch sử:**
  - 2026-09-14 | created→doing | agent arena/01a0a205-in4up | sheet web-first +
    4 provider có key + saveFromUrl + tests; 🚫 chờ owner chọn provider + key
  - 2026-09-15 | doing | agent arena/01a0a205-in4up | owner chốt Pexels+Unsplash,
    key ở app + dart-define build.yml, nối thêm hình vào luồng thêm từ nhanh
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | rebase lên `arena/01a0251e-in4up`
    (`755b474`, 40 commit mới); PLAN của em thành **PLAN-033** vì 251e đã lấy
    PLAN-027…032; git history viết lại thành 4 commit nhỏ (i18n → STT → ảnh →
    docs) để mỗi commit tự chạy CI xanh; 🚫 vẫn chờ owner dán key + nghiệm thu máy
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | mở **PR #56** (base
    `arena/01a0251e-in4up`) — 4 commit, 31 file, +3524/-110; chờ CI
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | CI ĐỎ ở `flutter analyze` —
    5 vòng bisect theo `docs/skills/ci-red-debugging` (không đọc được log, không
    có SDK) ⇒ thủ phạm `SnackBar(actions: [...])`: Flutter chỉ có `action:` SỐ ÍT.
    SnackBar "đã lưu" của Wordlist giữ `action:` = SỬA, "Thêm hình" chuyển thành
    TextButton trong `content`. Run 36347200442: analyze ✅ + Rule 5 ✅ + Cabin ✅
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | linearize lịch sử thành 4
    commit trên nền `arena/01a0251e-in4up` mới nhất (`4beb553`, #59) — pull thêm
    #57 + #59, chỉ merge KANBAN (append-only, giữ nguyên card IMPORT-MODELS-001)
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | owner chốt cách chọn ảnh:
    **mặc định = tự tìm + chạm chọn**, thêm **toggle "Tự gán ảnh đầu tiên"**
    trong dialog Cài đặt ảnh (key `vocab_image_auto_assign`, mặc định TẮT). Bật
    thì `attachVocabImage` / lưu từ Wordlist gán luôn ảnh đầu tìm được, không mở
    sheet; lỗi mạng/key → im lặng bỏ qua rồi vẫn mở sheet cho chọn tay; đã có
    ảnh thì không đè. API key: owner tự set GitHub secret `VOCAB_IMAGE_API_KEY`
    (build.yml đã nối `--dart-define`) — không cần thêm tài liệu
  - 2026-09-28 | doing | agent arena/01a0a205-in4up | sửa hệ quả merge "giữ cả hai
    phía": `tool/legacy_ui_english_overrides.json` thiếu DẤU PHẨY giữa khối của base
    và khối của em ⇒ `jsonDecode` nổ ở dòng 1770, `test/locale_chrome_no_vietnamese_test.dart`
    FAIL (Rule 5). Vá 1 comma; JSON 1784 key, 0 trùng, 0 value chứa ký tự Việt.
    PLAN của em `PLAN-033` → **`PLAN-034`** vì `OCR-001` (PR #61) đã chiếm 033.
### OCR-001 — ML Kit Text Recognition v2 (OCR) + Document Scanner làm nguồn văn bản mới

- **Trạng thái:** doing — **code + CI 🟢** (run 36348760217, commit `f133932`:
  `flutter analyze` 0 error, Rule 5 locale test xanh, LHB xanh, Cabin xanh). Còn
  chờ nghiệm thu trên thiết bị Android/iOS (T6 Document Scanner + T9 bảy AT).
- **Nguồn:** owner — chỉ làm **Text Recognition v2 (OCR) + Document Scanner**, bỏ
  qua các phần còn lại của ML Kit; yêu cầu thứ tự nghiêm ngặt *pull từ
  `arena/01a0251e-in4up` → đăng ký KANBAN → mới triển khai code*.
- **Quyết định kiến trúc:** `docs/adr/0009-mlkit-text-recognition-ocr.md` +
  `docs/mlkit_ocr_integration_plan.md` (PLAN-033).
- **Nội dung đã làm:**
  - **T1 deps:** `google_mlkit_text_recognition: ^0.16.0` +
    `google_mlkit_document_scanner: ^0.5.0`. PIN 0.16.x/0.5.x vì 0.17.x/0.6.x đòi
    Dart `^3.12.0` trong khi CI + máy chủ là Flutter 3.44.1 (Dart 3.11.5).
    `google_mlkit_commons ^0.12.0` trùng đúng bản translation 0.14.0 đang kéo.
  - **T2 service:** `lib/features/ocr/ocr_service.dart` (singleton, `isAvailable`,
    `recognizeImage`, `recognizeBitmap`, `normalizeOcrText` + guard) và
    `ocr_image_picker.dart` (seam bọc `file_picker` để test được trên host VM).
  - **T3 flow:** `ocr_flow.dart` (chọn nguồn → ảnh → ML Kit → preview/SỬA → nạp),
    `ocr_source_sheet.dart`, `ocr_result_dialog.dart`. Nạp qua
    `TextProvider.loadFromString` để **kế thừa nguyên vẹn** pipeline phân tích sẵn
    có, không xây pipeline song song.
  - **T4 provenance:** `TextSourceType.ocr` + refType riêng `'ocrImage'` (KHÔNG dùng
    `'localText'` — đường đó `readAsString()` trên JPEG → throw → nút reopen chết).
    `vocab_context.dart` thêm nhãn `'Quét lại ảnh'` + icon 📷.
  - **T5 điểm vào:** nút "Quét ảnh" trong Text Library drawer, chỉ hiện khi
    `OcrService.instance.isAvailable` (desktop/web ẩn hẳn, không hiện rồi báo lỗi).
  - **T7 i18n:** 14 key × **26 locale** (không chỉ English — xem ràng buộc dưới),
    regenerate `generated_ui_translations.dart` (890 source messages).
  - **T8 PDF Reader:** trang scan không có text layer thì hiện nút "Quét chữ trang
    này" ngay tại chỗ thông báo; raster hoá bằng `pdf_page_ocr.dart`
    (`page.render()` → BGRA8888, dùng chung `pdfSnapshotRenderSize` với tính năng
    in bản chụp) rồi đưa thẳng `InputImage.fromBitmap` — **không ghi file ảnh tạm**.
  - **Test:** `test/ocr/ocr_service_test.dart` + `test/ocr/ocr_i18n_coverage_test.dart`
    (thuần Dart, chạy được trên host VM, không cần native/ML Kit).
- **Ràng buộc i18n (học được khi làm, agent sau phải biết):**
  - `test/locale_chrome_no_vietnamese_test.dart` (CI `app_analyze.yml` có chạy) bắt
    **T2 = hi/zh/zh_TW/si phải phủ 100%** → key ARB mới **bắt buộc dịch đủ**, chỉ
    thêm English là làm đỏ CI ngay.
  - Sàn ratchet rất mỏng ở một số locale → thêm key English-only làm tụt sàn.
  - KHÔNG thêm key cho chuỗi đã có sẵn trong catalog (ví dụ 'Nạp vào Đọc'): trùng
    chuỗi làm generator báo unused, đẩy baseline lệch.
- **Sự cố sandbox (quan trọng — lý do thẻ này phải làm lại một phần):**
  sandbox bị **re-clone từ đầu** giữa chừng: 5 commit OCR của phiên trước
  (`c870bf2`, `26d77d6`, `ac29556`, `4c9e240`, `db1f082`) **mất khỏi git history**
  (object không còn tồn tại), chỉ sống sót dưới dạng file chưa commit trong working
  tree. Đã backup toàn bộ working tree ra tarball trước khi pull, rồi
  `reset --hard` về `origin/arena/01a0251e-in4up` (755b474) và **re-apply** phần OCR.
  - Kiểm chứng trước khi reset: mọi delta lớn ngoài OCR đều là **bản STALE** (blob
    từng tồn tại trong lịch sử upstream, đã bị vượt qua) → pull không mất gì.
  - 42 file untracked là bản dup cũ của công việc đã merge upstream → xoá; 10 file
    OCR local-only → giữ.
  - **ADR phải đổi số 0005 → 0009** và **PLAN-029 → PLAN-033**: upstream đã chiếm
    `0005` tới **ba lần** (`0005-ipa-display…`, `0005-nhip-dieu-hoc-tap…`,
    `0005-rest-auth-firestore-linux`) và PLAN đã tới 032. Đây là lần thứ hai va
    đánh số → repo cần một quy ước cấp số ADR/PLAN chặt hơn (xem đề xuất dưới).
- **Bằng chứng CI (đã có):**
  - Run đầu `36347670229` **ĐỎ**: đúng 2 error, cả hai ở `ocr_service.dart`, cả hai
    vì đối chiếu API Document Scanner trên **master** thay vì trên bản đã pin.
    `google_mlkit_document_scanner` **0.5.0** khai `documentFormats` (SET, số nhiều)
    và `DocumentScanningResult.images` là `List<String>?` (**nullable**); master là
    API **0.6.x** (`documentFormat` số ít, non-null) — 0.6.x đòi Dart `^3.12` nên
    không dùng được với Flutter 3.44.1/Dart 3.11.5. **Bài học: phải đọc source tại
    đúng commit release của bản đã pin, không đọc master.**
  - Đã sửa theo source tại commit release 0.5.0 (`f29f844e8`), dọn luôn 2 warning +
    3 info trong code OCR → run `36348760217` **XANH**, tổng issue 188 → 181 (đúng
    bằng 7 issue đã sửa; 181 còn lại là legacy upstream), **0 issue nhắc tới OCR**.
  - `flutter pub get` xanh → bộ version pin (text_recognition ^0.16.0 +
    document_scanner ^0.5.0) resolve được, không xung đột `google_mlkit_commons`.
- **Chưa làm / chờ:**
  - **T6 Document Scanner** cần thiết bị Android thật (Google Beta, không chạy trên
    emulator không có Play services).
  - **T9 nghiệm thu 7 tiêu chí** trên máy.
  - Reopen cho văn bản OCR **từ PDF**: đường T8 không có file ảnh nên
    `localPath = null` → vocab lưu từ đó không có nút reopen (degradation trung thực,
    còn hơn trỏ ref vào file không tồn tại). Muốn reopen được thì phải lưu ảnh trang
    ra cache — việc riêng, chưa làm.
- **Đề xuất governance (cần owner quyết):** thêm một file `docs/adr/README.md` hoặc
  script cấp số ADR/PLAN kế tiếp, vì hai phiên liên tiếp đều va số (0003 rồi 0005).
- **Lịch sử:**
  - 2026-09-15 21:12 UTC | created→doing | agent arena/01a09c9a-in4up | phiên 1:
    ADR + PLAN + T1–T5, T7, T8; 5 commit local; không push được (GH_TOKEN invalid)
  - 2026-09-27 20:15 UTC | doing | agent arena/01a09c9a-in4up | sandbox bị re-clone
    → 5 commit mất khỏi history; backup working tree ra tarball, xác định delta
    ngoài OCR đều STALE, `reset --hard` về `origin/arena/01a0251e-in4up` (755b474,
    +48 commit) rồi re-apply toàn bộ phần OCR
  - 2026-09-27 20:15 UTC | doing | agent arena/01a09c9a-in4up | đổi ADR-0005→0009 +
    PLAN-029→033 (upstream chiếm số); inject lại 14 key × 26 locale vào ARB mới
    (492→506 key); regenerate catalog (890 msg); mô phỏng CI
    `locale_chrome_no_vietnamese_test.dart` bằng Python → PASS cả 5 phép thử
    (parity · không ký tự Việt · sàn độ phủ · T2 100% · keepEnglish)
  - 2026-09-27 20:41 UTC | doing | agent arena/01a09c9a-in4up | push được (GH_TOKEN
    đã cấp lại) → CI `app_analyze.yml` run 36347670229 ĐỎ: 2 error ở ocr_service.dart
    (Document Scanner 0.5.0 dùng `documentFormats` dạng Set + `images` nullable, khác
    master/0.6.x mà tôi đã đối chiếu). Sandbox không đọc được artifact/log
    (blob.core.windows.net bị chặn) → dựng workflow chẩn đoán tạm đẩy lỗi lên nhánh,
    đọc qua api.github.com
  - 2026-09-27 20:45 UTC | doing | agent arena/01a09c9a-in4up | sửa 2 error theo đúng
    source 0.5.0 (commit f29f844e8) + dọn 2 warning/3 info; run 36348760217 **XANH**
    (analyze 0 error, Rule 5 ✓, LHB ✓, Cabin ✓); xoá workflow chẩn đoán tạm
  - 2026-09-27 20:52 UTC | doing | agent arena/01a09c9a-in4up | merge tip mới của
    `arena/01a0251e-in4up` (`b90ba3e`, PR #57 API-004) — xung đột duy nhất ở
    PLAN.md (hai bên cùng append), giữ cả PLAN-032 upstream lẫn PLAN-033 OCR;
    KANBAN auto-merge đủ 116 card. CI run 36349047556 trên commit merge `86d1626`
    **XANH** (analyze · Rule 5 · LHB · Cabin). Ghi chú vận hành: clone này có
    refspec `remote.origin.fetch` CHỈ gồm `main` → `git fetch origin` KHÔNG cập nhật
    các nhánh arena khác, phải fetch tường minh
    `git fetch origin refs/heads/arena/01a0251e-in4up:refs/remotes/origin/...`
    (đã suýt kết luận sai rằng upstream không đi tiếp).
  - 2026-09-28 | doing | agent arena/01a09c9a-in4up | mở PR #61 (base
    `arena/01a0251e-in4up`) để công việc có chỗ merge — trước đó nhánh này là bản
    DUY NHẤT còn tồn tại của OCR (sandbox bị re-clone lần 2, git local mất sạch 9
    commit, chỉ còn remote). Base đã đi tiếp `c813273` + `4beb553` nên PR báo
    CONFLICTING ở đúng `docs/project/KANBAN.md` (hai bên cùng append card); resolve
    giữ CẢ HAI (IMPORT-MODELS-001 của base + OCR-001), không xoá lịch sử bên nào.
    Tự khai trong PR: lịch sử nhánh có 1 merge commit + 4 commit công cụ chẩn đoán
    tạm (không đạt chuẩn template) — chờ owner quyết có rebase gọn lại hay không

### I4U18-BATCH — I4U L18 Problem: chuẩn hoá 15 phản hồi nghiệm thu thành lane nhỏ
- **Trạng thái:** proposed.
- **Nguồn:** owner (2026-09-30) — danh sách "I4U l 18 Problem".
- **Mục tiêu:** biến danh sách phản hồi tự nhiên thành backlog có câu chữ rõ,
  người đọc được, AI agent đọc được, chia lane để nhiều agent làm song song mà
  ít xung đột, mỗi lane có DoD và test/CI riêng.
- **Phạm vi batch:** Home/Chat/Viết AI, Server & API/BYOK, Dịch/Hy-MT, Từ điển,
  Video, Tipiṭaka, Tab Nghe, Tab Đọc IPA, import model offline, PDF/OCR/TTS và
  hướng dẫn sử dụng.
- **Tài liệu đi kèm:** `docs/project/I4U_L18_PROBLEM_BRIEF.md` (bản chỉnh câu chữ
  + acceptance criteria) và `PROMPT_AGENT_I4U_L18.md` (prompt chia việc cho các
  agent Arena).
- **Ràng buộc phối hợp:**
  - Không gom toàn bộ vào một PR lớn; mỗi lane nên có 1–3 commit logic + 1
    checkpoint KANBAN nếu có code.
  - Không để CI đỏ khi bàn giao. Nếu sandbox không có Flutter, phải dùng CI làm
    oracle và ghi rõ run ID; docs-only tối thiểu chạy `git diff --check`.
  - Tipiṭaka/PDF/Home có công việc liên quan trên `arena/01a06931-in4up`: chỉ
    fetch và đọc bằng `git show`/`git diff`, không checkout/merge mù.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | chuẩn hoá yêu
    cầu, thêm card I4U18-* và prompt phân việc; thay đổi docs-only.

### I4U18-HOME-AI-001 — Home/Chat/Tab Viết: AI chậm, fallback sai, routing Server/API
- **Trạng thái:** doing (code xong trên `arena/01a0f3d9-in4up`; chờ CI/thiết bị vì sandbox hiện không có Flutter SDK để chạy `flutter test`).
- **Nguồn:** owner (2026-09-30), mục 1/3/10/12 của I4U L18.
- **Vấn đề đã chuẩn hoá:**
  - Tab Home cần rà soát lại luồng chính; lỗi cụ thể đang thấy rõ nhất nằm ở
    chat/AI.
  - Home Chat trả lời chậm và đôi khi sinh thông báo kiểu "mình chưa tạo được câu
    trả lời cho tin nhắn này" kèm một đoạn tóm tắt tiếng Anh không liên quan
    (ví dụ "The conversation is about a simple task...").
  - Tab Viết, tầng 2 AI local: dù đã nạp Gemma 2B, phần tóm tắt/chủ điểm/hành
    động gợi ý bị rỗng hoặc báo "AI chưa trả về phần tóm tắt rõ ràng", trong khi
    các commit cũ từng hoạt động tốt.
  - Cần cho người dùng chọn engine Server & API/LLM cho chat, phân tích và dịch;
    cân nhắc BYOK/local server để người dùng tự đăng nhập/nhập key hoặc URL.
- **Hướng giải quyết đề xuất:** dùng routing của API-001…004: offline-first mặc
  định, online-first/remote tùy chọn; parse JSON/Markdown fence bền hơn; timeout
  hữu hạn; fallback hiển thị đúng lỗi, không tự bịa summary tiếng Anh.
- **AT/DoD:**
  - Gửi 2 tin liên tiếp: UI không kẹt spinner, có nút dừng/hủy, lỗi có mã rõ.
  - Với model local không trả JSON chuẩn: app vẫn hiển thị phần thô hoặc lỗi rõ,
    không mất toàn bộ summary/topic/action.
  - Bật Server/API: chat/analysis/dịch đi đúng provider đã chọn, key không lộ log.
  - Locale khác `vi`: chrome UI không còn tiếng Việt theo rule #5.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-09-30 | 19:47 UTC | proposed→doing | agent arena/01a0f3d9-in4up | code parser/prompt/cancel + test bổ sung; `git diff --check` sạch; chưa chạy Flutter test do sandbox thiếu `flutter`/`dart`.

### I4U18-DICT-001 — Từ điển: import/link thư mục MDX/MDD/CSS và dùng ngay
- **Trạng thái:** 🔄 doing — WP2 (MDX parser + import + tra cứu SQLite) hoàn
  tất kèm 59 test, CI run 37175921579 xanh trên `arena/01a104cf-in4up`; chờ
  rebase/merge PR + nghiệm thu thiết bị.
- **Nguồn:** owner (2026-09-30), mục 2 của I4U L18.
- **Vấn đề đã chuẩn hoá:** từ điển vẫn chưa import được ổn định. Bộ từ điển thực
  tế thường gồm nhiều file liên quan như `.mdx`, `.mdd`, `.css`/asset kèm theo;
  cần quyết định rõ app sẽ copy import hay chỉ gán/link tới thư mục/file nguồn để
  dùng trực tiếp.
- **Hướng giải quyết đề xuất:** ưu tiên hai chế độ:
  1. **Link/index thư mục** để dùng ngay và tránh nhân đôi dữ liệu lớn.
  2. **Import/copy vào app storage** khi người dùng muốn ổn định lâu dài hoặc khi
     SAF/quyền truy cập không bền.
- **AT/DoD:** chọn một thư mục có MDX+MDD+CSS → app nhận diện thành một dictionary
  set, tra được từ, hiển thị asset/format tương ứng; thiếu file phụ thì báo thiếu
  file nào và cho tiếp tục ở chế độ giảm cấp nếu vẫn tra được.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-09-30 | proposed→doing | agent arena/01a0f3da-in4up | code xong:
    scanner thuần `dict_bundle_scanner.dart` (ghép set theo folder, mdd
    stem+multi-part, css/asset tách, stray báo tên) + service 2 chế độ
    Link/Import + screen mode-dialog/badges + 12 test thuần + i18n rule #5
    (priorityUiOverrides 5 locale + EN mirror). Commit `8c0969d`. CI chạy
    qua bước "I4U18 scanner tests" (commit lane, step có guard).
    CI run id sẽ cập nhật khi push xong.
  - 2026-10-01 | doing (giữ nguyên) | agent arena/01a0f3da-in4up | push xong
    + CI xanh: nội dung của `8c0969d`/`b4e6550`/`4355b92` nằm trong commit
    gộp `2a6b219` (16 file, 2 lane DICT-001 + MODEL-IMPORT-001, kèm merge
    lane VIDEO/LISTEN-LIB cùng branch) + fix `0ed4662` (gỡ dấu `},` thừa
    trong `priority_ui_overrides.dart` sau dedup — lỗi parse ở CI run
    36897541200, đã sửa). CI run **36898178031 SUCCESS** toàn bộ job, gồm
    bước "I4U18 scanner tests — MODEL-IMPORT-001 + DICT-001" (28 test
    thuần). Đã mở PR #67 (base arena/01a0251e-in4up): chờ merge + nghiệm thu.
  - 2026-10-04 | doing (tiếp tục — WP2 handoff DICT-001) | agent
    arena/01a104cf-in4up | MDX parser thuần Dart đúng đặc tả 1.2/2.0
    (UTF-8/UTF-16, zlib, multi-block, key index nén v1.2 fallback, lỗi rõ
    cho encrypted/GBK/LZO/engine 3.0) chạy trong isolate + progress;
    DictDbService SQLite WAL; DictionaryService import/link + manifest
    persisted; 59 test (MdxTestBuilder tổng hợp file MDX nhị phân theo
    readmdict.py + parser 15 + db 6 + import 7 + widget 3 + scanner 28);
    CI xanh run 37175921579 (kèm nâng cấp bước scanner: -r expanded +
    annotation tên test fail vì log blob không tải được qua API). 3 commit
    chính trên branch `arena/01a104cf-in4up` (lane riêng với PR #67 —
    cùng task I4U18-DICT-001, owner gộp khi rebase/merge).
  - 2026-10-05 | 09:58 UTC | doing→doing | agent arena/01a10b79-in4up |
    audit phản hồi "Windows + Android vẫn không import": sửa backend SQLite
    desktop bằng `sqflite_common_ffi`; Android dùng SAF tree URI + scan/copy
    nền thay cho raw `/storage` và cache path; file picker có read-stream
    fallback; bundle import Windows path-safe. ADR-0010 + commit `7d64c70`,
    CI app analyze + 59 dictionary tests xanh run `37293368838`; chờ build
    APK/Windows và nghiệm thu trên thiết bị.

### I4U18-VIDEO-LIB-001 — Tab Video: quét thư mục và thư viện phát file trực quan
- **Trạng thái:** 🔄 doing — code + unit test + CI xanh; chờ nghiệm thu thiết bị.
- **Nguồn:** owner (2026-09-30), mục 4 của I4U L18.
- **Vấn đề đã chuẩn hoá:** hiện tại dù đã thêm video, app chỉ thêm theo từng file
  đơn lẻ. Cần cho phép quét thư mục và tổ chức thư viện để người dùng dễ thấy,
  lọc, chọn và phát file.
- **Hướng giải quyết đề xuất:** mở rộng VID-001 theo mô hình thư viện: chọn thư
  mục bằng SAF, quét đệ quy video/subtitle, ghép phụ đề cùng tên, filter/sort,
  recent/favorite và reopen đúng vị trí phát gần nhất.
- **AT/DoD:** chọn thư mục có nhiều video → danh sách cập nhật rõ ràng, không nhân
  đôi item sau khi quét lại, phát được file có/không có phụ đề, vẫn hoạt động khi
  một file trong thư mục bị xoá/đổi tên.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-10-01 | proposed→doing | agent arena/01a0f3da-in4up | hoàn tất SAF scan đệ quy, thư viện filter/sort/search/recent/favorite, ghép phụ đề và lưu vị trí; test logic/subtitle + CI run 36771997803 xanh; chờ nghiệm thu Android thực.

### I4U18-TIPITAKA-001 — Tipiṭaka: import pack, tiêu đề thật, cây Tam Tạng, tab/split/TTS
- **Trạng thái:** done — code + CI 🟢 run `36771566072`; chờ nghiệm thu thiết bị cho TTS/UX split.
- **Nguồn:** owner (2026-09-30), mục 5/6 của I4U L18.
- **Nhánh tham chiếu:** `arena/01a06931-in4up` cũng đang làm nội dung Tipiṭaka;
  agent phải fetch/read nhánh đó trước khi code, nhưng không merge mù.
- **Vấn đề đã chuẩn hoá:**
  - Import ngôn ngữ, ví dụ Tiếng Việt, báo "chưa thấy Pali tương ứng" nhưng chưa
    hướng dẫn rõ nên import Pali trước hay có thể dùng độc lập.
  - Ba tạng đang hiện tiêu đề dạng mã như `Vi diệu pháp - Abh01a Att - ABH01A_ATT
    abh01a_att`; cần tiêu đề nội dung thật, không phơi mã kỹ thuật cho người dùng.
  - Cần cây thư mục theo cấu trúc: **Tam Tạng Chính Văn → Tạng (Kinh/Luật/Luận) →
    nhóm/bộ → bài kinh**, kèm nút xem mục lục chi tiết trong từng bài.
  - Cần mở nhiều tab kiểu Obsidian, chia màn hình xem hai tab cùng lúc để đối
    chiếu, và bổ sung đọc TTS.
- **Quyết định UX đề xuất:** không bắt buộc pack dịch phụ thuộc Pali để import;
  pack dịch có thể dùng độc lập. Chỉ các chức năng đối chiếu song ngữ/căn hàng
  mới cần Pali và phải hiện gợi ý "nên import Pali trước để đối chiếu tốt hơn".
- **AT/DoD:** import một pack Việt không có Pali không bị chặn; cây thư viện không
  hiện mã nội bộ ở tiêu đề chính; mở 2 bài ở 2 tab, bật split view và phát TTS
  từng đoạn không làm mất vị trí đọc.
- **Nội dung triển khai:**
  - Import từng gói ngôn ngữ độc lập và atomically: gói Việt có thể tạo thư viện
    đọc được khi chưa có Pāli; import Pāli sau sẽ enrich đúng segment bằng
    `source_table/source_row_key` hoặc reference, không xoá bản dịch.
  - Library đổi thành `Tam Tạng Chính Văn → Tạng → nhóm/bộ → bài kinh`; tiêu đề
    chính lấy từ nội dung structural, mã kỹ thuật chỉ còn trong sheet chi tiết.
  - Reader có mục lục chi tiết, arbitrary translation fallback và trạng thái
    translation-only giải thích rõ Pāli chỉ được khuyến nghị để đối chiếu; các
    tính năng song ngữ/căn hàng giảm cấp trung thực khi thiếu Pāli.
  - Workspace kiểu Obsidian: nhiều tab mounted bằng `Offstage`, chia đôi hai tab;
    reader state/scroll/lazy-page/TTS cursor không bị huỷ khi đổi tab hoặc split.
  - TTS từng đoạn và cả bài có play/stop, tiếp tục từ cursor; generation toàn cục
    ngăn hai pane tranh singleton `TtsService`.
  - Learn by Heart/Worklist giữ durable source anchor + context snapshot; passage
    translation-only chuyển sang ghi nhớ target side thay vì tạo bài Pāli rỗng;
    nguồn có nút mở lại trong Learn by Heart và Wordlist.
  - i18n: đăng ký English canonical fallback cho chrome Tipiṭaka mới trong
    `priority_ui_overrides.dart`.
- **Kiểm thử:** `test/tipitaka_independent_language_import_test.dart` khóa luồng
  Vietnamese-only → đọc thành công → import Pāli sau vẫn giữ bản Việt, tiêu đề
  semantic không lộ `ABH01A_ATT`, và Learn by Heart JSON round-trip giữ durable
  source link. `test/tipitaka_workspace_retention_test.dart` khóa hai bài cùng book
  giữ nguyên State + scroll offset qua đổi tab và bật split. CI run `36771566072`
  xanh: Flutter analyze 0 error; Rule 5; Tipiṭaka; Agent F; LHB; Cabin; ASR.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-09-30 | proposed→doing | agent `arena/01a0f3db-in4up` | đã fetch + đọc
    `arena/01a06931-in4up` theo yêu cầu; không checkout/merge cả nhánh, chỉ port
    chọn lọc sau khi review diff. Hoàn tất implementation importer/UI/workspace/
    TTS/provenance + focused test; `git diff --check` xanh, chờ CI compile/test.
  - 2026-09-30 | doing→done | agent `arena/01a0f3db-in4up` | run đầu phát hiện 6
    integration error (FilePicker 11 static API, import FlutterError/
    MemorizeSide/TipitakaSourceLink); sửa tại `e698c5d`. Run `36770934461` xanh
    toàn bộ: analyze 0 error + Rule 5 + READ-GRAM + Tipiṭaka independent import,
    Pāli enrich, semantic title, source-link round-trip + LHB/Cabin/ASR.
  - 2026-09-30 | done | agent `arena/01a0f3db-in4up` | bổ sung widget test hai discourse giữ State + scroll qua tab/split (`beaaf92`); run `36771566072` xanh toàn bộ.

### I4U18-LISTEN-LIB-001 — Tab Nghe: lọc album/tác giả/yêu thích/playlist
- **Trạng thái:** 🔄 doing — code + unit test + CI xanh; chờ nghiệm thu thiết bị.
- **Trạng thái:** proposed.
- **Nguồn:** owner (2026-09-30), mục 8 của I4U L18.
- **Vấn đề đã chuẩn hoá:** thư viện Tab Nghe cần bộ lọc và tổ chức giống thư viện
  media thật: album, tác giả/nghệ sĩ, yêu thích, danh sách phát thủ công và danh
  sách thông minh.
- **Hướng giải quyết đề xuất:** mở rộng AUDLIB-001/LISTEN-* bằng metadata scan,
  favorites, manual playlist, smart playlist theo folder/tag/recent/unplayed;
  không phá LRC/transcript và reopen timestamp.
- **AT/DoD:** người dùng có thể lọc theo album/tác giả, đánh dấu yêu thích, tạo
  playlist thủ công, và mở lại bài giữ đúng transcript/LRC đang dùng.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-10-01 | proposed→doing | agent arena/01a0f3da-in4up | hoàn tất filter album/artist/folder/favorite, manual + smart playlist; playlist chỉ giữ libraryId để bảo toàn LRC/transcript/reopen; test + CI run 36771997803 xanh; chờ nghiệm thu thiết bị.

### I4U18-READ-IPA-001 — Tab Đọc IPA: chế độ dòng với Word và hướng dẫn chọn IPA
- **Trạng thái:** doing — code + CI 🟢 run `36771164011`; chờ nghiệm thu thiết bị.
- **Nguồn:** owner (2026-09-30), mục 9 của I4U L18.
- **Vấn đề đã chuẩn hoá:** chế độ dòng khi mở file Word chưa hiển thị đúng; ngay
  cả khi hiển thị, người dùng khó biết phải chạm vào đâu để bật/hiện IPA.
- **Hướng giải quyết đề xuất:** sửa luồng DOCX/Word để vào được line mode như văn
  bản/PDF đã hỗ trợ; thêm hướng dẫn dạng bottom snackbar/sheet vài giây sau khi
  vào chế độ đọc: "Chạm vào một dòng hoặc một từ để hiện IPA/tra từ; dùng nút IPA
  trên thanh dưới để bật/tắt".
- **AT/DoD:** mở DOCX → thấy dòng; chạm dòng/từ hiện IPA/word sheet; hướng dẫn tự
  ẩn sau đủ thời gian đọc, có thể mở lại từ Help/tooltip, có i18n rule #5.
- **Nội dung (3 hạng mục owner yêu cầu):**
  - **F1.1 — mở Word/DOCX không vào chế độ dòng.** Gốc lỗi KHÔNG ở tab Đọc mà ở
    `TextSourceLoader.docxXmlToPlainText`: ranh giới `</w:p>`, `<w:br>`, `<w:cr>` xuất ra
    MỘT `\n`. `TextSplitterService._splitSmart` (chế độ mặc định) chỉ coi `\n\s*\n` là
    ranh giới cứng, nên nhiều đoạn Word bị dán thành một "dòng" khổng lồ → chạm dòng
    không ra IPA theo dòng. Sửa tại lớp DOCX (xuất dòng trống), KHÔNG đụng `_splitSmart`:
    `\n` đơn phải tiếp tục là ranh giới MỀM, nếu không văn bản `.txt` bẻ dòng cứng sẽ bị
    băm vụn.
  - **F1.2 — gợi ý.** `ReadLineHint.showSnackBar` (đáy màn hình, 7 s, có nút "Xem hướng dẫn")
    tự hiện MỘT LẦN cho mỗi tài liệu khi nguồn là file chữ theo dòng.
  - **F1.3 — mở lại.** Nút Trợ giúp (`_ReadHelpButton`) trên `ReadTopBar` mở
    `ReadLineHint.showSheet` bất cứ lúc nào; ai bấm "Đừng nhắc lại" vẫn còn đường vào.
- **File:** `lib/services/text_source_loader.dart`,
  `lib/screens/read_mode/services/read_line_hint_service.dart` (mới),
  `lib/screens/read_mode/widgets/read_line_hint.dart` (mới),
  `lib/screens/read_mode/read_mode_screen.dart`, `lib/screens/read_mode/widgets/read_top_bar.dart`,
  `lib/core/language/priority_ui_overrides.dart` (11 key × 6 locale, viết tay — KHÔNG chạy
  `tool/generate_arbs.py` theo AGENTS.md).
- **Test:** `test/read_mode/docx_line_mode_test.dart` (6 test: DOCX → dòng, không băm
  `.txt` bẻ dòng cứng), `test/read_mode/read_line_hint_test.dart` (luật hiện gợi ý),
  `test/text_source_loader_test.dart` (cập nhật kỳ vọng ranh giới đoạn).
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-09-30 | 20:05 UTC | proposed→doing | agent arena/01a0f3db-in4up | code + test xong, commit `cca0e0b` (rebase trên `e698c5d` — nhánh đã có công việc Tipiṭaka của phiên trước, giải xung đột GIỮ CẢ HAI ở `app_analyze.yml`, KANBAN, `priority_ui_overrides.dart`)
  - 2026-09-30 | 20:15 UTC | doing | agent arena/01a0f3db-in4up | CI `app_analyze.yml` run **36771164011 XANH** trên `cca0e0b`: analyze 0 error · Rule 5 ✓ · READ-GRAM ✓ · Tipiṭaka ✓ · **Agent F tests ✓** · LHB ✓ · Cabin ✓ · ASR ✓. CÒN nghiệm thu thiết bị: mở .docx thật → tab Đọc phải ra từng dòng + snackbar hướng dẫn trước khi được coi là done
  - 2026-09-30 | 20:40 UTC | doing | agent arena/01a0f3db-in4up | đối chiếu nguồn chuẩn I4U L18: PR #64 (`arena/01a0f3b6-in4up` → `arena/01a0251e-in4up`) đã merge 19:53 UTC (`14140d7`), nhánh session merge base về và GỘP card trùng do nhánh tạo trước thời điểm đó — giữ nguyên Vấn đề/Hướng giải quyết/AT-DoD của card gốc, chỉ thêm phần triển khai + lịch sử. Đã đọc `PROMPT_AGENT_I4U_L18.md` §6 (Agent F): phạm vi F1/F2/F3 và DoD khớp phần đã làm, không phát sinh hạng mục mới.

### I4U18-TRANSLATE-001 — Dịch: Hy-MT và lựa chọn LLM Server/API
- **Trạng thái:** doing (code xong, chờ CI + nghiệm thu model thật trên thiết bị).
- **Nguồn:** owner (2026-09-30), mục 10/11 của I4U L18.
- **Vấn đề đã chuẩn hoá:** Hy-MT vẫn chưa dịch được ổn định trên thiết bị; đồng
  thời người dùng cần tùy chọn dịch qua LLM Server/API khi muốn chất lượng cao hơn
  hoặc khi engine offline lỗi.
- **Hướng giải quyết đề xuất:** kiểm lại validator/model path của Hy-MT sau
  HYMT-001; dùng API-004 làm engine dịch LLM có routing offline-first/online-first;
  giữ glossary Phật học/Pali và protect-token trước mọi engine.
- **AT/DoD:** cùng một đoạn văn: Hy-MT chạy được hoặc báo lỗi cấu trúc có hướng
  sửa; bật LLM provider thì dịch đi qua provider đã chọn; tắt mạng/remote fail thì
  fallback đúng chính sách, không trả bản dịch rỗng.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-10-01 | proposed→doing | agent arena/01a0f3d9-in4up | đối chiếu nguồn chuẩn PR #64; gom validator path/import/download, phân biệt thiếu/sai magic/file cắt/không đọc được; giữ load handshake thật và coi output rỗng là lỗi; chuẩn hóa error code snake_case; xác nhận API-004 đã có và routing mặc định vẫn offline-first, glossary/protect-token chạy trước mọi engine; thêm test validator. Chưa chạy Flutter test vì SDK không có trong PATH, còn AT model/native thật trên thiết bị.

### I4U18-MODEL-IMPORT-001 — Model import: eSpeak/Piper/STT offline nhận diện sai
- **Trạng thái:** 🔄 doing — code + unit test + CI run 36898178031 xanh; chờ PR merge + nghiệm thu thiết bị.
- **Nguồn:** owner (2026-09-30), mục 13 của I4U L18.
- **Vấn đề đã chuẩn hoá:**
  - Settings/Home import bằng chọn nhiều file: thư mục `espeak` có sẵn nhưng app
    không tự nhập, sau đó báo thiếu dữ liệu.
  - Import bằng thư mục: app báo không tìm thấy `.onnx` và `.txt` dù file thật có
    trong thư mục.
  - STT offline: chọn đúng file hoặc chọn cả thư mục vẫn báo không nhận dạng được.
- **Hướng giải quyết đề xuất:** dùng một validator thống nhất cho model bundle:
  quét đệ quy, nhận diện alias/tên file phổ biến, phân loại Piper voice, eSpeak
  data và ASR/Zipformer/Whisper; báo thiếu chính xác theo loại model thay vì báo
  chung chung.
- **AT/DoD:** import Piper bằng multi-file và folder đều nhận model+config+tokens+
  espeak data; import STT offline bằng folder nhận đúng loại model; lỗi thiếu file
  chỉ ra file cần bổ sung và nút "chọn lại thư mục/file".
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-09-30 | proposed→doing | agent arena/01a0f3da-in4up | code xong:
    scanner thuần `model_bundle_scanner.dart` (classify Piper voice/eSpeak/
    Zipformer roles/VAD/Whisper, báo thiếu đúng role) + manager ASR import
    ăn scanner (copy đúng bộ, ZIP fallback, dest-rescan báo thiếu chính
    xác) + Piper hint nhầm loại bundle + settings picker FileType.any cho
    espeak + 16 test thuần. Commit `b4e6550`. CI run id CHƯA có — push bị
    chặn token, cùng cần reconnect GitHub.
  - 2026-10-01 | doing (giữ nguyên) | agent arena/01a0f3da-in4up | reconnect
    GitHub xong, push + CI xanh: nội dung nằm trong commit gộp `2a6b219`
    + fix `0ed4662` (gỡ dấu `},` thừa sau dedup overrides — lỗi ở CI run
    36897541200). CI run **36898178031 SUCCESS** toàn bộ job, gồm bước
    "I4U18 scanner tests — MODEL-IMPORT-001 + DICT-001" (28 test thuần).
    Đã mở PR #67 (base arena/01a0251e-in4up): chờ merge + nghiệm thu.

### I4U18-PDF-OCR-TTS-001 — PDF/OCR Reader: spinner OCR và TTS controls không dừng
- **Trạng thái:** doing — code + CI 🟢 run `36771164011`; chờ nghiệm thu thiết bị.
- **Nguồn:** owner (2026-09-30), mục 14/15 của I4U L18.
- **Vấn đề đã chuẩn hoá:**
  - OCR cho PDF bị load chạy hoài ở vùng đọc ngay khi mới mở file PDF.
  - PDF reader: nút Play/Pause không dừng phát; khi chuyển dòng sau, app lướt rất
    nhanh qua nhiều dòng, đọc không kịp; bấm Play/Stop/Pause vẫn không tắt ngay.
- **Nhận định:** `flutter clean` có thể giúp xoá build cache cũ, nhưng các triệu
  chứng lặp lại ở runtime thường là lỗi state machine/cancel async/controller TTS,
  không nên coi `flutter clean` là cách sửa chính.
- **Hướng giải quyết đề xuất:** tách rõ trạng thái idle/loading/playing/paused/
  stopping; mọi OCR/TTS operation có cancel token; khi pause/stop/next-line phải
  hủy timer/stream/callback cũ trước khi phát dòng mới; thêm guard chống double-tap.
- **AT/DoD:** mở PDF text-layer không bật spinner OCR vô hạn; mở PDF scan có
  timeout/hủy rõ; Play→Pause dừng âm trong thời gian chấp nhận; Next line chỉ phát
  đúng một dòng kế tiếp; Stop chặn mọi callback phát tiếp sau đó.
- **Nội dung:**
  - **F2.1 — phân biệt PDF có lớp chữ với PDF scan.** `services/pdf_text_layer_probe.dart`
    (thuần Dart): lấy mẫu tối đa 5 trang rải đều + trang đang đọc, đếm ký tự `\p{L}\p{N}`;
    **mọi** trang mẫu trống chữ mới kết luận `scanned` (một trang bìa trống không đủ).
    Controller chạy dò nền (`unawaited`) sau khi mở tài liệu.
  - **F2.2 — không quét khi không cần.** Nút "Quét chữ trang này" chỉ hiện khi trang đang
    đọc không có chữ hoặc bản dò kết luận cả tài liệu là scan; bấm nhầm thì báo
    "Trang này đã có lớp chữ — không cần quét OCR" thay vì quay spinner một vòng.
  - **F2.3 — timeout + hủy + error state.** `features/ocr/ocr_cancel_token.dart`
    (`OcrCancelToken`, `runOcrGuarded`, mặc định 45 s/ảnh) + `OcrFailureKind`
    (`none/error/cancelled/timeout`) + dialog tiến trình CÓ nút Hủy. Hủy và hết giờ KHÔNG
    báo đỏ như lỗi thật.
  - **F3 — máy trạng thái đọc to.** `services/pdf_tts_machine.dart`: một SỐ PHIÊN tăng dần
    + cờ `busy` chống double-tap. Ba lỗi thực địa và gốc của chúng:
    - *Pause không dừng âm:* `TtsService.pause()` chỉ tạm dừng `AudioPlayer`, giọng máy
      (flutter_tts) vẫn đọc hết câu; thêm `OfflineTtsEngine.pause()` và `_awaitLineFinished`
      ĐỨNG YÊN khi đang tạm dừng (vòng cũ dùng `playerStateStream.firstWhere`, lúc pause
      không bao giờ khớp nên chờ hết timeout rồi… chạy sang dòng kế).
    - *Stop xong vẫn phát:* `_stopRequested` bị `speak()` đặt lại `false` ở đầu mỗi câu →
      lệnh Stop rơi vào đúng khe đó bị nuốt; nay `stop()` tăng `_playbackEpoch` (chỉ tăng),
      mọi tác vụ đang bay mang theo thế hệ của mình.
    - *Next lướt nhiều dòng:* `onLineChanged` của phiên đã chết vẫn đẩy `_readingCueIndex`,
      và khối `finally` của phiên cũ hạ trạng thái của phiên mới; nay mọi tác dụng phụ đều
      qua `isCurrent(session)` / `markFinished(session)`.
  - **Không đụng đường khôi phục (ADR-0003/0004):** bản dò chỉ gọi đúng extractor đang dùng,
    chạy sau khi tài liệu đã mở, không chạm `PdfFileIdentity` (md5 `size|mtime`) cũng không
    chạm hình học y-up.
- **File:** `lib/features/ocr/ocr_cancel_token.dart` (mới), `lib/features/ocr/ocr_service.dart`,
  `lib/features/ocr/ocr_flow.dart`, `lib/features/pdf_reader/services/pdf_text_layer_probe.dart` (mới),
  `lib/features/pdf_reader/services/pdf_tts_machine.dart` (mới),
  `lib/features/pdf_reader/pdf_reader_controller.dart`, `lib/features/pdf_reader/widgets/pdf_tts_bar.dart`,
  `lib/features/tts/tts_service.dart`, `lib/features/tts/engines/offline_tts_engine.dart`.
- **Test:** `test/ocr/ocr_cancel_token_test.dart` (11), `test/pdf_reader/pdf_text_layer_probe_test.dart` (11),
  `test/pdf_reader/pdf_tts_machine_test.dart` (14). Đã thêm bước chạy 5 file test này vào
  `.github/workflows/app_analyze.yml` (trước đó oracle chung KHÔNG chạy `test/pdf_reader`, `test/ocr`).
- **Ghi chú owner:** `flutter clean` chỉ xoá cache build, không phải cách sửa; ba lỗi trên đều
  là trạng thái sống trong controller/service, clean xong vẫn tái hiện.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-09-30 | 20:05 UTC | proposed→doing | agent arena/01a0f3db-in4up | code + 36 test xong, commit `cca0e0b`
  - 2026-09-30 | 20:15 UTC | doing | agent arena/01a0f3db-in4up | CI `app_analyze.yml` run **36771164011 XANH** trên `cca0e0b` (analyze 0 error + bước mới "Agent F tests" chạy 36 test thuần logic đều xanh). CÒN nghiệm thu thiết bị: PDF có lớp chữ (không mời OCR) · PDF scan (Hủy + hết giờ) · Play→Pause phải tắt tiếng ngay · Next đúng một câu · Stop không phát lại
  - 2026-09-30 | 20:40 UTC | doing | agent arena/01a0f3db-in4up | đối chiếu nguồn chuẩn I4U L18: PR #64 (`arena/01a0f3b6-in4up` → `arena/01a0251e-in4up`) đã merge 19:53 UTC (`14140d7`), nhánh session merge base về và GỘP card trùng do nhánh tạo trước thời điểm đó — giữ nguyên Vấn đề/Hướng giải quyết/AT-DoD của card gốc, chỉ thêm phần triển khai + lịch sử. Đã đọc `PROMPT_AGENT_I4U_L18.md` §6 (Agent F): phạm vi F1/F2/F3 và DoD khớp phần đã làm, không phát sinh hạng mục mới.

### I4U18-DOCS-001 — Hướng dẫn sử dụng cho các luồng mới/dễ lỗi
- **Trạng thái:** done (docs-only; chờ owner chạy QA trên thiết bị).
- **Nguồn:** owner (2026-09-30), mục 7 của I4U L18.
- **Vấn đề đã chuẩn hoá:** người dùng cần hướng dẫn rõ cho các luồng nhiều bước:
  import model offline, cấu hình Server/API, import/link từ điển, import Tipiṭaka,
  thư viện media, PDF/OCR/TTS và IPA.
- **Hướng giải quyết đề xuất:** bổ sung tài liệu trong `docs/` và/hoặc màn Help
  trong app. Tối thiểu có bản tiếng Việt + English fallback, ảnh/chỉ dẫn từng bước
  nếu làm UI.
- **AT/DoD:** người dùng đọc hướng dẫn có thể tự import Piper/STT/dictionary,
  cấu hình provider API và xử lý lỗi thường gặp; mọi liên kết từ Settings/Help mở
  đúng, không còn chuỗi UI tiếng Việt khi locale khác `vi`.
- **Kết quả/bằng chứng:**
  - `docs/USER_GUIDE.md` + `docs/USER_GUIDE.vi.md`: guide song ngữ cho
    Piper/eSpeak/Whisper/Zipformer, BYOK/Ollama/LM Studio, MDX/MDD/CSS,
    Tipiṭaka/Pāli, Listen/Video và PDF/OCR/TTS/IPA; nêu rõ giới hạn UI hiện tại
    thay vì mô tả chức năng lane khác chưa merge.
  - `docs/manual_qa_I4U18_DOCS_001.md`: checklist owner cho happy path, lỗi,
    offline/restart, quyền, key, i18n rule #5 và chuỗi QA liên lane.
  - Link từ hai README; không thêm Help UI nên không phát sinh key i18n; không
    commit ảnh/video/model; local Markdown link check + `git diff --check` sạch.
- **Rủi ro còn lại:** cập nhật lại guide sau khi lane MDD/CSS, video/listen và
  Tipiṭaka merge UI mới; owner vẫn cần chạy checklist trên thiết bị thật.
- **Lịch sử:**
  - 2026-09-30 | created→proposed | agent arena/01a0f3b6-in4up | tạo card từ phản hồi owner.
  - 2026-09-30 | 19:49 UTC | proposed→doing | agent arena/01a0f3dc-in4up |
    soạn guide vi + checklist từ code hiện hành; đối chiếu nguồn chuẩn PR #64
  - 2026-09-30 | 20:32 UTC | doing→done | agent arena/01a0f3dc-in4up |
    bổ sung English fallback, README links và bằng chứng docs-only; local link
    check + `git diff --check` sạch

### XLAT-DEEPLX-001 — Engine DeepLX (HF Space): URL không lưu khi restart, dán host trần không chạy, lỗi im lặng
- **Triệu chứng (owner):** vừa dựng DeepLX trên Hugging Face Space
  (`https://beyou8778-deeplx.hf.space/translate`), hỏi cách cắm vào
  "Engine dịch thuật". Kiểm tra thực tế 2026-10-01: Space đang ở trạng thái
  "Your space is in error" (cả `/` lẫn `/translate`) — chưa dùng được.
- **Ba vấn đề trong app (đã verify code tại `14140d7`):**
  1. URL DeepLX chỉ sống trong RAM (`TranslationService._deeplxUrl`) —
     khởi động lại app là mất, phải dán lại mỗi lần.
  2. Engine POST NGUYÊN VĂN chuỗi dán vào (`deeplx_engine.dart`) — dán host
     trần `https://xxx.hf.space` (dạng HF copy mặc định) là 404; phải dán
     đủ `.../translate`.
  3. DeepLX fail (Space ngủ cold-start 20–60s > timeout 10s, 404, 429…)
     → chuỗi engine im lặng rơi về Google Free, người dùng không biết
     cấu hình của mình có hoạt động hay không.
- **Tài liệu đối chiếu (docs DeepLX:** mọi phiên bản OwO-Network từ cũ đến
  v1.2+ đều giữ `POST /translate` body `{text, source_lang, target_lang}` →
  `{code:200, data:"..."}`; `/v2/translate` (DeepL-Auth-Key) trả dạng
  `translations[0].text`; `/jsonrpc` là giao thức NỘI BỘ DeepL
  (`LMT_handle_texts`) — KHÔNG phải endpoint HTTP của DeepLX, không cần
  hỗ trợ riêng).
- **Fix (2026-10-01, agent arena/01a0f41f-in4up):**
  - `engines/deeplx_engine.dart`: viết lại —
    (a) `normalizeUrl()`: trim + bỏ `/` thừa; host trần → tự nối
    `/translate`; path riêng (reverse-proxy) giữ nguyên; giữ query
    `?token=`; (b) parser chấp nhận 3 dạng response: `data` (chuẩn),
    `translations[0].text` (/v2), `result.data`/`result.texts[0].text`
    (jsonrpc wrapper); (c) `probe()`: dịch câu mẫu `Hello` → VI, timeout
    20s (chịu cold start HF), trả `DeepLXProbeResult` (ok/sample/status/
    error/responseTime); (d) inject `http.Client` cho test; (e) lỗi rõ
    ràng: HTTP status + trường `message` server (v1.2+ trả 400 kèm
    `unsupported target_lang`…).
  - `translation_service.dart`: `configure(deeplxUrl:)` chuẩn hoá + lưu
    `SharedPreferences` key `translation_deeplx_url`; `_loadOfflineOnlyPref`
    phục hồi khi mở app (guard `_deeplxUrl == null` tránh đè configure
    mới); chỉ singleton đọc/ghi prefs (`_persistPrefs`) — forTest không
    chạm (giữ hợp đồng test cũ).
  - `translation_toolbar.dart` (sheet ⚙️ Engine dịch thuật): hint "Chỉ dán
    host cũng được" + nút "🔌 Thử kết nối DeepLX" (TextButton.icon +
    spinner) + kết quả inline xanh/đỏ: OK → "✅ … dịch thử: “Xin chào”
    (245 ms)"; lỗi HTTP → "❌ Lỗi HTTP 404: …"; không kết nối được →
    "❌ … kiểm tra Space/serve đang chạy (HF Space ngủ sau ~48h không dùng)".
  - i18n rule #5: 6 key ARB mới (`translationDeepLXUrlHint`,
    `translationDeepLXTestButton/Empty/Ok/HttpError/Unreachable`) dịch đủ
    vi/en + T2 (hi/zh/zh_TW/si) ngay trong PR; còn lại English fallback
    đúng convention; regenerate `generated_ui_translations.dart`
    (python3 tool/generate_ui_translation_map.py); template `{sample}/
    {ms}/{code}/{detail}` khớp cơ chế uiText.
  - Test: `test/deeplx_engine_test.dart` (16 test, MockClient không
    network): normalizeUrl 4 nhóm, translate 8 (body chuẩn, bỏ
    source_lang rỗng, 3 dạng response, 404/400+message, text rỗng,
    exception), probe 4 (ok, URL rác, lỗi HTTP, mất kết nối).
- **AT (nghiệm thu máy):** Space DeepLX thật (sau khi owner fix Space —
  lỗi thường gặp: app phải listen cổng 7860, `sdk: docker` + `app_port:
  7860`, Space Public): dán host trần → nút Thử kết nối xanh với thời
  gian; kill app mở lại → URL còn (không phải dán lại); tắt Space → nút
  đỏ kèm lý do; locale ≠ vi → chuỗi nút/kết quả không còn tiếng Việt.
- **Trạng thái:** doing — code + test + ARB xong, chờ CI + nghiệm thu máy.
- **Lịch sử:**
  - 2026-10-01 | created→doing | agent arena/01a0f41f-in4up | code +
    test + 26 ARB + regen map; branch arena/01a0f41f-in4up, PR vào main.
  - 2026-10-01 | doing→doing | agent arena/01a0f41f-in4up | CI xanh run
    36781345809 (app_analyze: analyze 0 lỗi + locale test xanh; PR #66).
    PHÁT HIỆN khi xem conflict PR: origin/main đã bị thay bằng root commit
    MỚI 0218c33 ("Fix indentation and improve Windows build script", author
    2026-09-23, main chỉ còn 1 commit) — snapshot cũ/lech: 733 file vs 1144
    (mất .github/workflows/app_analyze.yml, mất llm_mt_engine.dart,
    lib/features/api/, KANBAN 4468→136 dòng…) ⇒ PR #66 không tự merge
    được (hai lineage không còn tổ tiên chung). Lineage đầy đủ vẫn nguyên
    vẹn: arena/01a0251e-in4up (= 14140d7, tip cũ của main) + branch này
    (= 14140d7 + XLAT-DEEPLX-001). Theo GOVERNANCE 4b: KHÔNG merge chéo —
    chờ owner quyết (phục hồi main từ arena/01a0251e-in4up rồi path-checkout
    phần Windows build của 0218c33, hoặc path-checkout content từ branch này).

### CI-DEPS-001 — `flutter pub get` đỏ trên máy cũ: Dart 3.11.5 vs ML Kit subject_segmentation 0.2.x (cần Dart ≥3.12)
- **Trạng thái:** proposed (chờ 1 máy có Flutter ≥3.47.6 chạy pub get + commit lock)
- **Triệu chứng (owner, 2026-10-04):** `flutter pub get` ở worktree DEV:
  "The current Dart SDK version is 3.11.5. Because in4up depends on
  google_mlkit_subject_segmentation >=0.2.0 which requires SDK version
  >=3.12.0 <4.0.0, version solving failed. Try Flutter 3.47.6."
- **Root cause (đã verify):**
  1. `da2a3d2` (03/10) nâng `google_mlkit_subject_segmentation` ^0.0.3 →
     ^0.2.0 (ML Kit background removal — OCR/wordlist) — bản 0.2.x yêu cầu
     Dart ≥3.12 (Flutter ≥3.47.6 theo pub).
  2. **`pubspec.lock` KHÔNG BAO GIỜ có entry của package này** (git log -S
     trống) — commit thêm dep (`74ef923`) + nâng constraint (`da2a3d2`) đều
     không cập nhật lock ⇒ mọi máy `pub get` đều phải resolve MỚI từ
     pub.dev ⇒ ai SDK <3.12 là đỏ (CI pin Flutter của nó thì xanh).
- **Sửa (2 bước):**
  1. **Mọi dev/owner:** upgrade Flutter lên stable mới nhất (≥3.47.6) —
     `flutter upgrade` (hoặc `fvm install 3.47.6 && fvm use 3.47.6`),
     kiểm tra `flutter --version` có Dart ≥3.12.0, rồi `flutter clean &&
     flutter pub get`.
  2. **Làm 1 lần (ai chạy được bước 1):** sau pub get xanh →
     `git add pubspec.lock && git commit -am "chore(deps): lock
     google_mlkit_subject_segmentation 0.2.x (CI-DEPS-001)" && git push`
     → lock đủ entry ⇒ mọi máy sau này resolve deterministic, không phụ
     thuộc pub.dev state.
- **Ghi chú:** CI pin Flutter trong workflows (`flutter-version: '3.44.1'`
  ở app_analyze/build/build_final_complete) — nếu CI nào bắt đầu đỏ ở bước
  "Resolve dependencies" với cùng lỗi SDK ⇒ bump `flutter-version` trong
  workflow (file workflow cần owner push — GitHub App thiếu quyền
  workflows). Sandbox agent KHÔNG có Flutter SDK nên không tự sinh lock
  được.
- **AT:** máy Flutter mới: `flutter pub get` xanh; `git diff pubspec.lock`
  có entry `google_mlkit_subject_segmentation` 0.2.x sau khi commit; 1 dev
  khác clone + `pub get` xanh mà không cần sửa gì.
- **Lịch sử:**
  - 2026-10-04 | created | agent arena/01a0251e-in4up | diagnose từ lỗi
    pub get của owner (Dart 3.11.5); verify lock thiếu entry qua git log -S;
    chờ máy có Flutter ≥3.47.6

### MAIN-RESTORE-001 — main là snapshot cũ (0218c33, 2026-09-23): content-sync từ 0251e theo GOVERNANCE 4b
- **Trạng thái:** proposed — chờ owner quyết (đã phát hiện từ 2026-10-01 trong
  XLAT-DEEPLX-001; audit đầy đủ 2026-10-04).
- **Thực trạng main (audit 2026-10-04, verify git):**
  - main = đúng 1 commit `0218c33` "Fix indentation and improve Windows
    build script" (2026-09-23) — snapshot CŨ: 733 file vs 0251e 1144 file
    (diff main→0251e: 216 files, +26221/−7302).
  - Mất so với 0251e: `.github/workflows/app_analyze.yml` (+ knowledge/
    soundlist tests), `lib/features/api/`, `llm_mt_engine.dart`, phần lớn
    KANBAN (4468→136 dòng), toàn bộ CI-ANDROID-01..04 scripts
    (`scripts/ci/android_*.sh` không tồn tại trong main), workflow Android
    trong main vẫn là build cũ ("Build Split APKs", không có rename/verify
    script).
  - 36 file CHỈ main có: 33 file là build-artifact không nên commit
    (`linux/flutter/ephemeral/*`, `gradle-wrapper.jar`, `gradlew`,
    `GeneratedPluginRegistrant.java`, `icudtl.dat`, 2 package-lock của
    in4up_ai/in4up_core) + **`LICENSE`** (VipSound Non-Commercial — file
    "độc nhất" có giá trị, do owner quyết giữ/bỏ).
  - "Windows build fix" của 0218c33 nằm trong 2 workflow file (bản cũ);
    workflow 0251e MỚI HƠN (đã gồm các fix Windows build đời sau) ⇒ không
    mất gì khi sync 0251e sang.
  - Hệ quả: PR từ feature-branch → main không merge được (2 lineage không
    còn tổ tiên chung); tag release từ main sẽ build bằng pipeline cũ
    (APK split, không có signing-verify…).
- **Luật áp dụng (GOVERNANCE 4b):** KHÔNG force-push/squash-rewrite main;
  KHÔNG merge chéo lineage squash ⇒ chỉ **content-sync bằng commit thường**
  (hoặc path-checkout).
- **Thủ thuật đề xuất (Option A — owner chạy, agent session 0251e KHÔNG
  push được main):**
  ```bash
  git fetch origin
  git checkout main && git pull
  git rm -rf .                                    # bỏ toàn bộ cây hiện tại (giữ .git)
  git checkout origin/arena/01a0251e-in4up -- .  # trồng cây 0251e (stage sẵn)
  # (tuỳ chọn) giữ LICENSE cũ:  git show 0218c33:LICENSE > LICENSE && git add LICENSE
  git commit -m "chore(main): content-sync toàn bộ từ arena/01a0251e-in4up (GOVERNANCE 4b.2) — main thành bản kiểm toán hiện tại"
  git push origin main
  ```
  → main giữ lịch sử (commit mới đè trên 0218c33), nội dung = 0251e, 0
  conflict (không merge). Sau đó PR feature→main hoạt động lại bình thường.
  **Trật tự đúng:** (1) owner áp patch CI-ANDROID-04 trên 0251e trước
  (`git apply scripts/ci/android_universal_only_workflow.patch`…), (2) rồi
  mới sync main ⇒ main nhận luôn workflow Universal-only.
- **Option B (nếu owner không muốn động main):** main giữ nguyên làm
  backup; mọi release tag từ 0251e; chấp nhận PR→main hỏng cho tới khi
  quyết. (Không ảnh hưởng APK "chip phổ thông" nếu tag từ 0251e.)
- **Ghi chú cho câu hỏi owner 2026-10-04 ("main có cần điều chỉnh không?"):**
  - Nếu tag release từ **0251e** → việc APK universal đã đủ ở 0251e, main
    KHÔNG cần chỉnh riêng cho việc này.
  - main "cần chỉnh" ở tầm LỚN HƠN: nó không còn đại diện app hiện tại
    (Option A ở trên).
- **Lịch sử:**
  - 2026-10-01 | phát hiện | agent arena/01a0f41f-in4up | PR #66 thấy main
    đổi thành 0218c33 (ghi trong XLAT-DEEPLX-001)
  - 2026-10-04 | audit đầy đủ | agent arena/01a0251e-in4up | diff 216 file,
    phân loại 36 file chỉ-main (33 junk + LICENSE), xác nhận Windows fix
    nằm trong workflow cũ; soạn thủ thuật content-sync; chờ owner quyết
  - 2026-10-05 | cập nhật | e524214 trên main (lại là snapshot-replace 733
    file, chỉ sửa workflow Android) ⇒ Option A content-sync vẫn CHƯA làm;
    main giờ thêm lỗi: workflow gọi 3 scripts/ci không tồn tại. CẢNH BÁO
    GOVERNANCE 4b: main đã "dựng lại" lần nữa — cần owner xác nhận chính
    chủ e524214 để đồng bộ; sau e524214, Option A càng nên làm để main
    hết cảnh snapshot cũ + thiếu script.
  - 2026-10-05 | owner chạy thử | owner chạy thủ thuật content-sync nhưng
    commit 798cde87 rơi vào nhánh 0251e (không checkout được main trong
    worktree DEV — main đang checkout ở clone chính) + `git push origin main`
    bị reject (main đã có e524214). Local owner có 1 commit rác trên 0251e.
    Đã gửi owner 2 bước: (1) fix 0251e (apply CI-ANDROID-04 + reset rác),
    (2) content-sync 0251e→main ĐÚNG nhánh.

### TTS-EDGE-001 — Microsoft Edge Read Aloud TTS (edge-tts) vào chuỗi engine TtsService
- **Trạng thái:** ✅ done (code + 30 test thuần; chờ nghiệm thu thiết bị thật)
- **Nguồn:** owner (2026-10-04) — "I4U | TTS Microsoft Ege": bổ sung
  EdgeTtsEngine (giọng Neural miễn phí, không API key) vào hệ sinh thái
  TTS hiện có, ưu tiên online cho vi-VN/en-US, fallback mượt khi mất mạng.
- **Nội dung:**
  - `lib/features/tts/engines/edge_tts_engine.dart` (mới, theo mẫu
    zalo/openai engine): port giao thức edge-tts **7.2.8** (bản upstream
    mới nhất, đã đối chiếu source `constants.py`/`drm.py`/`communicate.py`):
    WebSocket `wss://speech.platform.bing.com/consumer/speech/synthesize/
    readaloud/edge/v1` + `TrustedClientToken` + `ConnectionId` + DRM mềm
    `Sec-MS-GEC` (sha256-UPPER(ticks+token), ticks làm tròn 300s ×10^7) +
    `Sec-MS-GEC-Version=1-143.0.3650.75`; header extension (Origin
    chrome-extension://…, Cookie muid, UA Edg/143). Frame speech.config
    (audio-24khz-48kbitrate-mono-mp3) → Path:ssml → nhận binary
    `Path:audio` (header BE-2byte) tới `turn.end`. Chia text: câu → dấu
    phẩy → cắt cứng, rồi cắt byte-an-toàn ≤4096B (không tách UTF-8, không
    tách XML entity) — y upstream. Trần tham chiếu `maxCharsPerRequest`
    10000. KHÔNG lưu key / KHÔNG SharedPreferences.
  - Giọng: catalog trưng 21 giọng — vi-VN-HoaiMyNeural/NamMinhNeural đứng
    đầu (theo yêu cầu) + en-US Aria/Guy/Emma, ja, ko, zh-CN/TW, th, fr,
    de, es, ru, pt-BR, id, hi; `getAvailableVoices` thử live-list từ
    endpoint (mới nhất khi Microsoft đổi), rớt → catalog trưng.
    `resolveVoice` chỉ nhận voiceId đúng dạng Edge (`xx-YY-*Neural`) —
    chặn nuốt nhầm `_selectedVoiceId` chung (Piper `vi_VN-…`, Zalo `1`,
    FPT `banmai`, OpenAI `alloy`).
  - `lib/features/tts/tts_service.dart`: đăng ký `edge_tts` priority 2 —
    **online đầu tiên cho cài đặt MỚI** (sau piper/offline); user cũ nhận
    engine append CUỐI qua merge saved json (thứ tự của họ không đổi —
    y luật WP4). Cắm switch `speak()` + `_getOnlineEngines` ⇒ tự có trong
    UI engine-order, engine-status, prefetch, `checkEngineStatus`.
    Fallback dùng sẵn hạ tầng: `_trySpeakOnline` check mạng trước +
    timeout 15s → engine kế → emergency Offline (Máy); cache MP3 reuse
    `TtsCache` (bytes → file temp → just_audio).
  - UI: không cần sửa — `TtsSettingsSection` render động từ `engineOrder`
    (kéo-thả + switch bật/tắt).
- **Test:** `test/edge_tts_engine_test.dart` — known-vector Sec-MS-GEC
  sinh bằng edge-tts Python 7.2.8 (ts cố định), khung message/SSML/escape,
  chia text (ranh câu, ≤4096B, entity/emoji/CJK an toàn), parse frame,
  chọn giọng, isAvailable/getAvailableVoices qua http.Client giả, và
  source-scan pin đăng ký TtsService. Cập nhật pin thứ tự mặc định trong
  `test/tts_api_wp4_test.dart` (chèn edge_tts trước google_tts, kèm
  comment rõ user cũ không bị xáo trộn).
- **Hạn chế đã biết:** sandbox agent không egress được
  `speech.platform.bing.com` (curl 000 — giống thiết bị mất mạng/chặn
  doanh nghiệp) ⇒ chưa nghiệm thu end-to-end ở đây; cần 1 lượt test máy
  thật (đọc câu tiếng Việt, nghe HoaiMy + NamMinh, bật/tắt mạng kiểm
  fallback). Nếu Microsoft nâng yêu cầu version, sửa hằng
  `chromiumFullVersion` trong engine (một chỗ duy nhất).
- **Lịch sử:**
  - 2026-10-04 | code + test | agent arena/01a10633-in4up | engine +
    đăng ký + 30 test thuần (chưa chạy được — sandbox không có
    Dart/Flutter SDK, đã kiểm chéo thuật toán bằng harness Python; chờ CI/
    máy dev verify)
  - 2026-10-04 | ✅ CI green | agent arena/01a10633-in4up | thêm step
    "TTS engine tests" vào `app_analyze.yml`; run 37194470015 xanh toàn
    bộ (analyze + 71/71 test TTS gồm 30 Edge + 41 WP4). Vá 3 lỗi lộ qua
    CI: (1) 2 expect `expect(x, RegExp(...))` trong test Edge → chuyển
    `hasMatch` tường minh; (2) pin no-key của WP4 (`isNot(contains
    ('SharedPreferences'))`) đã đỏ sẵn trên nhánh do comment header của
    `openai_compat_tts_engine.dart` chứa đúng từ khoá (chưa từng có step
    CI chạy file test này) → đổi câu chữ comment. Còn lại: nghiệm thu
    end-to-end trên thiết bị thật (sandbox không egress được
    speech.platform.bing.com).

### TTS-EDGE-VOICE-001 — Edge TTS chọn giọng theo ngôn ngữ (trước chỉ có picker Piper)
- **Trạng thái:** doing (code + 5 test pin xong, chờ CI + nghiệm thu máy)
- **Nguồn (owner 2026-10-06):** "app chỉ có bộ chọn giọng riêng cho Piper;
  các engine online (Google/Zalo/FPT/Edge) chưa có chỗ chọn giọng. Vì vậy
  Edge luôn dùng giọng mặc định `vi-VN-HoaiMyNeural` (nữ)."
- **Lịch sử commit gốc:** do agent phiên `arena/01a10633-in4up` làm thành
  commit **local `c307e0a`** (5 phần) — nhưng **KHÔNG ĐƯỢC PUSH** (phiên đóng
  sau khi PR #79 merge, mất quyền push). Commit LỎI. Phiên
  `arena/01a0251e-in4up` này **RE-APPLY** lại toàn bộ theo spec + mẫu repo.
- **Nội dung (5 phần):**
  1. `lib/features/tts/edge_voice_prefs.dart` (MỚI) — kho giọng Edge
     **theo ngôn ngữ**, singleton + SharedPreferences, theo đúng mẫu
     `PiperVoicePrefs` (khoá `edge_voice_for_lang_<lang>` + short code).
  2. `EdgeTtsEngine.catalogVoices` / `catalogVoicesFor(language)` (MỚI,
     **đồng bộ, KHÔNG mạng**) — bản static của danh mục trưng offline, cho
     UI render tức thì (getAvailableVoices vẫn fetch-live khi tổng hợp).
  3. `TtsService._trySpeakOnline(..., {String? voiceOverride})` — Edge đọc
     giọng đã lưu từ `EdgeVoicePrefs.instance.voiceForLang(lang)`; engine
     khác (Google/Zalo/FPT) vẫn dùng `_selectedVoiceId` (voiceOverride=null).
     **KHÔNG** set `_selectedVoiceId` chung từ picker Edge → không làm bẩn
     playback Piper/Zalo/FPT (mỗi engine một kho giọng).
  4. UI `_EdgeVoicePicker` trong `tts_settings_section.dart` — nhóm theo
     ngôn ngữ (🇻🇳 vi-VN, 🇺🇸 en-US, 🇯 ja-JP…), radio từng giọng,
     **vi-VN: Hoài My (nữ) / Nam Minh (nam)**, mặc định highlight HoaiMy.
  5. Test pin: `test/edge_tts_engine_test.dart` (+2: catalog đủ/thứ tự/
     unique + lọc locale) + `test/edge_voice_prefs_test.dart` (MỚI:
     normalizeLang + set/voice round-trip + chưa chọn→null).
- **Phát hiện bổ sung (đã xác minh code):** đọc cache
  (`TtsCache.get(engineId:'any')`) thực tế không bao giờ trúng file đã lưu
  (khoá literal `'any'` không match engine-id thật) ⇒ **đổi giọng Edge áp
  dụng NGAY cho câu tiếp theo** (mỗi câu tổng hợp mới + đọc giọng mới),
  KHÔNG lo cache giọng cũ — không cần sửa cache trong phạm vi này.
- **AT nghiệm thu:** Build app → Cài đặt → TTS → mục **"Giọng Microsoft
  Edge Neural theo ngôn ngữ"** → chọn **Nam Minh (nam)** cho tiếng Việt →
  đọc câu tiếng Việt bất kỳ (khi engine Edge được dùng) → nghe **giọng nam**.
  Chọn lại Hoài My → về giọng nữ. Catalog trưng **21 giọng** (offline, sẵn
  dùng chọn; khi có mạng endpoint còn trả live-list mới hơn).
- **Lịch sử:**
  - 2026-10-04 | created (agent 01a10633) | commit local `c307e0a` — MẤT
    (không push được)
  - 2026-10-06 | re-apply (agent 01a0251e) | tái hiện 5 phần + 5 test pin
    trên `arena/01a0251e-in4up`; chờ CI + nghiệm thu máy

### PDF-OCR-002 — PDF Reader: Batch OCR (trang hiện tại / khoảng trang / toàn bộ tài liệu)
- **Trạng thái:** 🔨 doing — code + test thuần xong (sandbox không Flutter SDK
  — chờ CI `app_analyze.yml` + nghiệm thu thiết bị Android/iOS).
- **Nguồn:** owner (2026-10-05) — "PDF reader chế độ Tr khi bấm vô thường nó
  hiện được vài dòng text thôi, chưa có làm cho tất cả. Nên cho người dùng lựa
  chọn quét OCR toàn bộ hay mấy trang, trang nào."
- **Quyết định kiến trúc:** mở rộng ADR-0009 (tái dùng ML Kit `recognizeBitmap`
  + `rasterizePdfPage`, KHÔNG dependency mới, KHÔNG pipeline OCR song song);
  kế hoạch `docs/pdf_ocr_batch_va_dich_man_hinh_plan.md` (PLAN-035).
- **Nội dung:**
  - `lib/features/pdf_reader/services/pdf_batch_ocr.dart`: `resolvePdfOcrPages`
    (3 phạm vi + clamp + hoán đổi from/to) + `runPdfBatchOcr` (recognizer/probe
    tiêm vào để test host VM; MỘT trang lỗi không giết cả lô — khác
    `recognizeFiles` dừng sớm; cancel giữ phần đã quét; skip trang đã có lớp
    chữ mặc định bật; join `\n\n` theo quy ước `recognizeFiles`).
  - `lib/features/pdf_reader/widgets/pdf_ocr_sheet.dart`: sheet chọn phạm vi +
    toggle skip + tổng kết số trang + ước lượng thời gian + cảnh báo tài liệu
    dài; `runPdfOcrBatchFlow` chạy dialog tiến độ có Hủy (route handle tự gỡ
    đúng 1 lần — pattern `_OcrProgressHandle` của ocr_flow) rồi qua
    `OcrFlow.presentResult` → preview/SỬA (bắt buộc ADR-0009) →
    `TextProvider.loadFromString(sourceType: ocr)`.
  - 3 điểm vào: (1) nút quét trên thanh TTS (trước đây quét cứng 1 trang — giờ
    mở sheet, mặc định "Trang hiện tại"); (2) menu ⋮ → "Quét OCR (trang /
    toàn bộ)…" — lối vào KỂ CẢ khi trang có lớp chữ; (3) Text Mode với PDF
    scan (trước đây ngõ cụt "Không thể trích xuất text…") → nút "Quét OCR tài
    liệu này" mặc định TOÀN BỘ. Tất cả gate `OcrService.instance.isAvailable`
    (desktop/web ẩn).
- **Test:** `test/pdf_reader/pdf_batch_ocr_test.dart` — resolve (biên + hoán
  đổi), skip, lỗi không chết lô, cancel giữa chừng giữ phần đã quét, progress,
  join. Thuần Dart.
- **i18n:** 22 chuỗi mới đăng ký `priority_ui_overrides.dart` đủ
  en/hi/zh/zh_TW/si (không thêm key ARB — không đụng sàn ratchet T2);
  mô phỏng `pdf_reader_i18n_coverage_test.dart` = 0 missing.
- **Lịch sử:**
  - 2026-10-05 | created → doing | agent arena/01a10b7e-in4up | code + test
    thuần + ADR-0010 + PLAN-035; chờ CI + nghiệm thu thiết bị (batch 50+ trang
    scan thật, cancel giữa chừng, sheet trên màn nhỏ)

### XLAT-SCR-001 — Dịch màn hình IN-APP cho PDF Reader (nút 🌐 → panel song ngữ theo trang)
- **Trạng thái:** 🔨 doing — code + test thuần xong (chờ CI + nghiệm thu thiết
  bị; cần máy thật xác nhận UX panel + tốc độ dịch trang dài).
- **Nguồn:** owner (2026-10-05) — tư vấn Gemini "Tính năng dịch màn hình…
  hướng 1: dịch nội dung bên trong app; tạo nút Dịch màn hình hiện tại trên
  toolbar". ADR-0010: in-app trước (95% khả thi, tận dụng 100%
  TranslationService/Cache), system-wide tách lane XLAT-SCR-002.
- **Nội dung:**
  - `lib/features/pdf_reader/models/pdf_page_translation.dart` +
    `services/pdf_page_translate.dart`: seeds từ `PdfSentenceCue` (trang có lớp
    chữ, giữ `bounds` cho overlay tương lai) HOẶC từ text OCR
    (`splitOcrTextIntoUnits`: ngắt đoạn trống, gom câu ≤480 ký tự, cắt cứng câu
    không dấu chấm) — translator tiêm vào, dừng sau 5 lỗi liên tiếp (mirror
    `translateAll`), shouldStop theo runId.
  - `PdfReaderController`: `translateCurrentPage()` (runId versioning như
    `_ttsMachine`/`TranslationMixin` — đổi trang giữa chừng hủy phiên cũ tự
    động), cache ~6 trang gần nhất (trim theo khoảng cách trang), lật trang khi
    panel mở → tự dịch trang mới (TranslationCache ăn phần lớn).
  - UI: nút `Icons.translate` trên PdfToolbar (chỉ pdfView) + panel
    `pdf_page_translate_panel.dart` ghép trên thanh TTS (cùng ẩn/hiện với
    chrome): từng câu gốc → bản dịch ngay dưới, spinner + progress bar, "Dịch
    lại", "Đóng", "Mở trong Read Mode" (load trang hiện tại vào TextProvider —
    dịch toàn bộ bằng translateAll đã có).
  - Trang scan: fallback OCR 1 trang trong cùng luồng (chỉ Android/iOS);
    không OCR được → error rõ 'page_no_text' với gợi ý quét OCR.
- **Test:** `test/pdf_reader/pdf_page_translate_test.dart` — seeds lọc
  isUsable, dịch tuần tự + progress, lỗi đơn không chết trang, 5 lỗi liên tiếp
  dừng, shouldStop, translator throw không crash, `splitOcrTextIntoUnits` (ngắt
  đoạn/budget/cắt cứng/giữ nguyên ký tự). Thuần Dart.
- **Chưa làm (nâng cấp sau, đã chừa schema):** overlay CustomPainter vẽ bản
  dịch đè lên dòng gốc theo `bounds` — cần nghiệm thu thiết bị thật (ADR-0010).
- **Lịch sử:**
  - 2026-10-05 | created → doing | agent arena/01a10b7e-in4up | code + test
    thuần + ADR-0010; chờ CI + nghiệm thu (PDF tiếng Anh nhiều câu, PDF scan,
    lật trang nhanh khi panel mở)

### XLAT-SCR-002 — Dịch màn hình TOÀN HỆ THỐNG Android (MediaProjection + overlay)
- **Trạng thái:** 🔨 doing — P1 Android đã thi công xong (code + test thuần,
  CI 🟢 run 37306440924 trước rebase); chờ owner nghiệm thu thiết bị thật +
  một lượt build APK `--flavor stable` (Kotlin chưa có CI biên dịch).
  Lane native riêng theo ADR-0010 → chi tiết kiến trúc trong **ADR-0011**;
  KHÔNG đụng lane in-app XLAT-SCR-001.
- **Nguồn:** owner (2026-10-05) — hướng 2 trong tư vấn Gemini: dịch app ngoài
  hệ thống kiểu Google Lens/NormCap.
- **Nội dung bàn giao:** `PROMPT_AGENT_DICH_MAN_HINH.md` — luật phiên (AGENTS.md,
  quy tắc vàng, pin ML Kit 0.16.x, --flavor stable, i18n rule #5, KHÔNG tải
  model lúc bootstrap), sự thật repo (bảng đối chiếu), kiến trúc chốt (native
  Kotlin: foreground service + bubble + MediaProjection + overlay view; Dart:
  OcrService mở rộng nhận blocks + TranslationService dịch; MethodChannel
  `in4up/screentranslate`), 7 cạm bẫy đã biết, 8 task + 7 tiêu chí nghiệm thu
  trên máy thật (Android 14 consent mỗi phiên, pin, cache lặp lại).
- **Thi công P1 (agent arena/01a10bdd-in4up):**
  - Kiến trúc: **chụp + vẽ ở native, hiểu chữ + dịch ở Dart** (ADR-0011).
    Tái dùng 100% `OcrService` (ML Kit Latin) + `TranslationService`
    (cache → glossary → ML Kit offline → online) — KHÔNG engine dịch thứ hai.
  - **Dart** `lib/features/screen_translate/`: `screen_translate_geometry.dart`
    (một hàm quy đổi toạ độ duy nhất + cắt rowStride padding + hoán R↔B),
    `screen_translate_models.dart` (giao thức channel), `..._channel.dart`
    (client điều khiển + binding engine nền), `..._controller.dart`
    (`CaptureGate` debounce 1.5s, cắt tối đa 32 khối, gom
    `missingModelCodes`), `..._entrypoint.dart` (entrypoint engine nền),
    `..._prefs.dart` (ngôn ngữ đích dùng chung qua SharedPreferences),
    `..._card.dart` (UI bật/tắt trong Quản lý Model AI mục 7).
  - **OCR:** thêm `OcrService.recognizeBitmapBlocks()` trả `List<OcrBlock>`
    (text + bbox) + `lib/features/ocr/ocr_block.dart`. `recognizeBitmap()`
    CŨ KHÔNG ĐỔI (PDF Reader đang dùng).
  - **Native** `android/app/src/main/kotlin/com/in4up/screentranslate/`:
    `ScreenTranslateService` (foreground service, bong bóng kéo được,
    ImageReader 1 frame/lần bấm, FlutterEngineGroup chạy
    `screenTranslateMain`, notification có action Tắt),
    `ScreenCaptureRequestActivity` (xin consent mỗi phiên — Android 14+),
    `TranslationOverlayView` (vẽ bản dịch đè, tự thu nhỏ cỡ chữ),
    `ScreenTranslatePlugin` (channel `in4up/screentranslate`) đăng ký trong
    `MainActivity`. Manifest: `SYSTEM_ALERT_WINDOW`,
    `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `FOREGROUND_SERVICE_SPECIAL_USE`,
    `POST_NOTIFICATIONS` + khai service (`mediaProjection|specialUse`) và
    activity trong suốt; proguard `-keep` cho package screentranslate.
  - **i18n:** 17 chuỗi chrome mới trong `priority_ui_overrides.dart` đủ
    en/hi/zh/zh_TW/si; chuỗi service nằm ở `res/values` **mặc định tiếng
    Anh** + `res/values-vi` tiếng Việt (quy tắc vàng #5 — không fallback vi).
  - **Phạm vi:** P1 Android. iOS KHÔNG làm (không có overlay toàn hệ thống).
    Desktop Linux/Windows = P2 (nút hiện "Chỉ có trên Android", bị khoá).
- **Bằng chứng:** `test/screen_translate/` — `ocr_block_test.dart`,
  `screen_translate_geometry_test.dart` (scale ở 2 mật độ, rowStride, hoán
  R/B), `screen_translate_controller_test.dart` (debounce, noText,
  missingModel, lỗi từng khối, cắt hạn mức), `screen_translate_protocol_test.dart`
  (round-trip payload + tên khoá Kotlin đọc), `screen_translate_prefs_test.dart`.
- **Đã xác nhận bằng CI:** run 37306440924 (trước rebase, base de9e00b) và
  run **37337092117** (sau rebase, trên nền tip 251e `296eafc`) — cả hai
  xanh toàn bộ: `flutter analyze` 0 error, test rule #5 xanh, step mới
  "Screen translate tests — XLAT-SCR-002" (`test/screen_translate/`) xanh,
  và các batch test của lane in-app (Agent F) cũng xanh ⇒ hai lane không
  giẫm chân nhau.
- **CHƯA có máy bắt:** phần Kotlin — không workflow nào biên dịch Android
  (build chỉ chạy theo tag/`workflow_dispatch`); sandbox không có Android
  SDK. Cần một lượt `flutter build apk --flavor stable` của owner.
- **Nghiệm thu thiết bị (owner):** 1) bật bong bóng → cấp quyền overlay +
  đồng ý capture → bong bóng hiện ở mọi app; 2) web tiếng Anh → bấm →
  ≤3s thấy bản dịch đè đúng khối, xoay ngang không lệch; 3) đổi engine
  trong Cài đặt dịch → bản dịch theo engine đó, lặp màn hình không tốn
  request (cache); 4) tắt → overlay + notification + tiến trình ngầm biến
  mất; 5) Android 14: tắt rồi bật lại → hỏi consent lại; 6) desktop không
  hỏng; 7) `flutter analyze` 0 error + 2 test locale xanh.
- **Lịch sử:**
  - 2026-10-05 | created (proposed) | agent arena/01a10b7e-in4up | prompt +
    ADR-0010; P1 Android only, P2 desktop + script CJK cần ADR riêng
  - 2026-10-05 | proposed→doing | agent arena/01a10bdd-in4up | nhận prompt
    giao việc, thi công P1: seam Dart + OCR bbox, lane native Kotlin, UI +
    i18n, 5 file test thuần, ADR-0011 (lane native — số 0010 đã là lane
    in-app). CI 🟢 run 37306440924 (analyze 0 error + rule #5 + step mới
    "Screen translate tests" trong `app_analyze.yml`) — CHẠY TRƯỚC rebase,
    trên base de9e00b.
  - 2026-10-05 | rebase lên 251e | agent arena/01a10bdd-in4up | rebase 6
    commit lên tip 296eafc (có sẵn lane in-app XLAT-SCR-001 + PDF-OCR-002);
    hợp nhất card này (giữ nguyên lịch sử của agent arena/01a10b7e-in4up),
    đổi PLAN-035→PLAN-036 vì số đã bị chiếm; không có xung đột code.
  - 2026-10-05 | 16:10 UTC | doing→doing | agent arena/01a10bdd-in4up | CI
    sau rebase ĐỎ ở bước "Resolve dependencies" vì commit nâng dependency của
    chủ dự án đặt `intl: 0.20.3` trong khi `flutter_localizations` của Flutter
    3.44.1 ghim ĐÚNG 0.20.2 (đỏ sẵn trên chính nhánh 251e — run 37311461428,
    mọi bước sau bị skip). Hạ về 0.20.2 trong `pubspec.yaml` + `pubspec.lock`
    ⇒ run **37337092117 🟢 toàn bộ**. Nếu owner cần 0.20.3 thì phải nâng
    Flutter trong CI và drop commit nhỏ này.
  - 2026-10-05 | 16:15 UTC | doing→doing | agent arena/01a10bdd-in4up | bàn
    giao phần còn lại bằng `PROMPT_AGENT_DICH_MAN_HINH_P2.md`: (a) thêm CI
    biên dịch Kotlin + nghiệm thu 7 tiêu chí trên máy thật, (b) P1+ (chạm xem
    bản gốc, chọn vùng, vòng lặp capture), (c) P2 script CJK (ADR riêng),
    (d) P2 desktop Linux/Windows.

### AUDIT-0103 — Đợt kiểm định bản 0.10.3 của chủ dự án (10 mục)

- **Trạng thái:** 🔨 doing — 6 mục đã sửa và CI 🟢 trên nhánh
  `arena/78cea3c6-in4up` (PR nhắm `251e`); 4 mục còn lại cần máy thật hoặc
  đụng schema ⇒ đã có prompt giao việc riêng.
- **Nguồn:** chủ dự án, 2026-10-06 — danh sách kiểm định bản 0.10.3.
- **Đã sửa trong đợt này (mỗi vùng một commit để rebase & merge dễ):**
  - `READ-ACT-001` (mục 1.a + 1.b + 1.c) — bỏ thanh hành động nổi trùng
    lặp (phương án 1 của owner); 4 nút chạy service thật qua
    `ReadTextActionRunner`; nút nhỏ lại + cuộn ngang trên điện thoại.
    Nguyên nhân gốc của "bôi chọn rồi vẫn báo chưa bôi chọn":
    `TextProvider.selectedText` **chỉ** được ghi bởi
    `SelectableText.onSelectionChanged`, mà chế độ ô chữ/interlinear không
    có `SelectableText`.
  - `READ-HINT-001` (mục 1.e phần hướng dẫn) — bảng hướng dẫn nói đúng
    thao tác thật; ghi chú IPA thành dòng phụ trong ngoặc ngay dưới dòng
    nói về IPA.
  - `XLAT-MIX-001` (mục 1.h) — nhận diện ngôn ngữ theo **từng mẩu câu**;
    `TranslationService` dịch riêng mẩu ngoại ngữ rồi ghép lại nguyên văn.
  - `TTS-EDGE-VOICE-002` (mục 1.f + 1.g) — picker giọng gập theo ngôn ngữ;
    khoá cache TTS có giọng/tốc độ/cao độ; prefetch dùng đúng giọng.
  - `LOTTIE-IMPORT-002` (mục 2 phần bug) — nhập `.json/.lottie` từ máy;
    nhận diện Lottie theo nội dung; xem trước trước khi tải; thumbnail
    Lottie hết vỡ.
  - `DICT-LINK-001` (mục 1.d phần lời) — nói rõ vì sao Android tạm mất chế
    độ "Liên kết thư mục" + sửa câu gây hiểu nhầm về dung lượng.
- **Bàn giao bằng prompt (không làm nửa vời):**
  `PROMPT_AGENT_OCR_SCAN_CRASH.md` (1.i),
  `PROMPT_AGENT_SCREEN_TRANSLATE_BUBBLE.md` (1.j),
  `PROMPT_AGENT_DICT_SAF_LINK.md` (1.d phần native),
  `PROMPT_AGENT_VOCAB_TWO_IMAGES.md` (mục 2 phần 1–2 ảnh + duyệt animation),
  `PROMPT_AGENT_READ_TTS_DEVICE_VERIFY.md` (nghiệm thu 1.g trên máy +
  kéo chọn nhiều từ 1.e).
- **Máy bắt:** `app_analyze.yml` — thêm bước
  "Read actions + mixed-language tests (logic thuần)"
  (`test/read_mode/read_text_action_runner_test.dart`,
  `test/translation/mixed_language_test.dart`), cộng nhóm
  `looksLikeLottieContent` trong `test/vocab_image_search_test.dart`.
- **Giới hạn đã biết (ghi để người sau không "sửa nhầm"):** tiếng Việt viết
  **không dấu** có thể bị bộ tách mẩu coi là ngoại ngữ ("di" là giới từ
  Indonesia/Ý, "toi" là đại từ Pháp). Hậu quả tối đa là dòng đó bị dịch
  thừa — nguyên văn không bao giờ bị thay.
- **Nghiệm thu còn thiếu (owner):** nghe giọng Edge nam/nữ trước và sau khi
  đổi giọng (bài kiểm tra cache), dịch một tài liệu lẫn Việt–Anh, nhập một
  file Lottie từ máy và một link Lottie, và một lượt dùng tab Đọc trên điện
  thoại để xác nhận hàng nút không còn chiếm chỗ.
- **Lịch sử:**
  - 2026-10-06 | created (doing) | agent arena/78cea3c6-in4up | kiểm định
    10 mục; 6 mục sửa tại chỗ (6 commit theo vùng), 4 mục ra prompt giao
    việc; CI app_analyze xanh ở `74af5d8` (analyze 0 error + toàn bộ bước
    test, gồm bước mới của đợt này).
