# KANBAN — Bảng việc dự án (nguồn sự thật duy nhất về trạng thái)

> Luật cập nhật: xem `docs/GOVERNANCE.md` mục 3 — CHỈ đổi trạng thái +
> append lịch sử, không xóa. Bảng tóm tắt dưới đây luôn được làm mới
> tương đồng với các card phía dưới.

## Tổng quan

| ID | Việc | Trạng thái | Bằng chứng gần nhất |
|---|---|---|---|
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
| PDF-W0 | Wave 0 PDF Reader: nối selection + TTS câu + định danh file + hệ toạ độ + i18n + test sàn | 🔨 doing | code + CI 🟢 05-09-2026 (`370ff91`, run 33984585516: analyze 0 error + test rule #5 xanh) trên `arena/01a07250-in4up`; CÒN nghiệm thu thiết bị + `flutter test test/pdf_reader` ở máy dev |
| PDF-W1 | Wave 1+2 PDF Reader (đợt A+B+C): mục lục + tìm trong file + thumbnail + nhảy trang + phím tắt + chủ đề đọc + xuất/nhập chú thích (JSON/XFDF/bản chụp PDF) | 🔨 doing | code + CI 🟢 06-09-2026 (đợt A `032f321` run 34012087643; đợt B 1.5 run 34042635098; đợt C = wave 2 mục 2.6 B1+B2, run xanh cuối `34058736214` sau 3 run đỏ vì API Dart — chi tiết docs §4.3) trên `arena/01a07250-in4up`; ADR-0004; docs §4.1+§4.2+§4.3; CÒN nghiệm thu thiết bị + `flutter test test/pdf_reader` (14 file / 134 test, chưa chạy lần nào) + một lượt round-trip share sheet thật + 1.4/1.7/1.8 + phần 2.6 còn lại (Markdown/CSV, in, stamp thật vào tệp) |
| READ-630-05 | Nhận diện text ĐÃ LƯU khi lưu nhiều text + gợi ý hành động (thêm ngữ cảnh/cập nhật/bỏ qua) | 📋 proposed | nền: badge đã-có + smart-fill đã có (PLAN-015) |
| LISTEN-630-01 | Tab Nghe: AB loop bottom overflow 24px + nút "lặp câu tiếp theo" | ✅ done | LRC budget + onPanelChanged (chờ nghiệm thu) |
| LISTEN-823-01 | Tab Nghe: rèm LRC + AI sheet + dịch Hiểu + transcript đúng audio | ✅ done | 1d05ce9; CI run 32660616256 xanh (chờ QA đổi file nhanh) |
| GOV-2 | Rule vàng #5: chrome UI không tiếng Việt khi locale ≠ vi + máy bắt | ✅ done | AGENTS.md + test locale (346 entries sạch) |
| WORDLIST-630-01 | Import hàng loạt clipboard/text hoạt động thật + meaning | ✅ done | CSV quotes + smart-fill + preview meaning (chờ nghiệm thu) |
| SRC-630-01 | Nguồn text mới: .md, .json, .docx (thuần Dart, 0 dep mới) | ✅ done | TextSourceLoader + picker + loadTextFile (chờ nghiệm thu) |
| AICHAT-01 | AI Chat thật: llama.cpp native backend (hết mock) | ✅ done — **CI build XANH 3 NỀN TẢNG** | run 32592622383: Android ✅ + iOS ✅ + Windows ✅ (llama.cpp build thật trong pipeline) |
| CI-ANDROID-01 | Fix job Android build.yml: `--flavor stable` + rename đúng tên | 🔄 doing (in-repo fix CI-only — chờ oracle) | in4up_ci_fixes.gradle (CI=true): inject mock client + copy stable→tên không-flavor; oracle tag v1.4.0-ci-android-fix |
| CI-ANDROID-02 | Build llama.cpp cho Android trong CI | ✅ done | run 32592622383: Android ✅ (GGML_LLAMAFILE OFF c6cc97e + pin CMake 5995183) |
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
| LHB-002 | Vanishing cloze scaffolding 4 tầng + first-letter mnemonics + i18n vi/en/hi/zh/zh_TW/si | ✅ done | cherry-pick 0ed55c8 → fb483df (chờ CI + nghiệm thu UX) |
| LHB-003 | Voice Recall (ghi mic + fuzzy align + gợi ý FSRS) + Nối xích câu kệ + Anki Cloze {{c1::}} | ✅ done | cherry-pick 10fecd3 → 19efa2d + fix transcribeAuto (0177c35 → 4f123e6); chờ CI + nghiệm thu mic |
| SOUNDLIST-630-02 | transcriptFromLrcLines: end = dòng KHÔNG TRỐNG kế tiếp (dòng trống phá highlight) | ✅ done | c978432 (providers copy sống); CI Soundlist xanh 32663677483 |
| AUDLIB-001 | Audio Library P1 (MediaStore) — fix content:// playback + VAD-only fallback + sherpa pubspec | ✅ done | thâu hoạch 01a0018e 70c4efc; CI xanh 33037686097 + 33037686068 (chờ nghiệm thu thiết bị) |
| LANG-03033-01 | Chrome i18n Soundlist/LHB/shell + hi/zh/zh_TW/si (thâu hoạch 01a03033) + fix 2 regression | ✅ done | ff f149d5a + fix 10 file bị dd081fb revert (a5ee489) + fix rule5 ARB (881d8aa); CI xanh 33078187839 |
| I18N-001 | i18n backlog: 354 chrome literals chưa phân loại UI/content (generator legacy fallbacks không chạy được) + raw strings player tab Nghe | 📋 proposed | cần branch i18n riêng (rà soát theo skill i18n-localization); fix lẻ tab Gần đây/Thư viện đã làm (rule 5) |
| READ-630-06 | Bôi nhiều chữ mặc định; box-từng-từ tuỳ chọn (chip cam + settings); sheet lưu từ hiện từ cũ + Sửa | ✅ done | thâu hoạch 01a01580 db5c6ed (path-checkout 6 file) + fix 5 lỗi compile; CI xanh 33082501188 (chờ nghiệm thu thiết bị) |
| XLAT-001 | Dịch offline: glossary Phật học/Pali + protect-tokens trước mọi engine + ML Kit (EN↔VI, EN↔HI; HI↔VI pivot EN) + offline-only | ✅ done + CI xanh | thâu hoạch 02ffc + 7 lỗi compile (6 agent + 1 owner fix import extension bcpCode); CI xanh 33273465065 (chờ nghiệm thu máy EN→VI/EN→HI) |
| XLAT-002 | Dịch ONLINE-FIRST (smart default): online trước, offline fallback khi hết mạng/online fail; vẫn đổi được trong Cài đặt dịch | ✅ done + CI xanh | ce4945a; CI xanh 33697490397 (chờ nghiệm thu máy online/offline) |
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

---
| CABIN-001 | Cabin dịch: "Không thể khởi động micro / nhận diện giọng nói" — fix mic/STT | ✅ done + CI xanh (chờ nghiệm thu máy) | self-heal session treo + retry + keep-alive + lỗi chẩn đoán cụ thể + bỏ cap 2 phút + dictation + Shadowing mic thành toggle (chặn mic treo) |
| SHERPA-WP4-01 | Live STT offline qua sherpa Zipformer (cabin không phụ thuộc speech service) | ✅ done (chờ CI + nghiệm thu máy) | docs/Bangiao/bangiao_sherpa_wp4_live_stt.md + PLAN-023; hoàn thiện N1-N4 (VI simulated streaming + EN streaming, SherpaModelManager ASR, UI Quản lý Model AI, Cabin engine toggle, priority i18n, test unit) |

| LHB-005 | LHB: bấm icon lặp 1× của câu không mở menu — chọn cả dòng luôn | 🔄 doing (chờ CI + nghiệm thu máy) | chip per-line: HitTestBehavior.opaque + vùng chạm min 44×32 + menu neo context của CHIP (trước neo rect cả ListView → menu ra ngoài màn hình) |
| TTS-PIPER-001 | LHB phát tới câu tiếng Việt sập app (Piper TTS) dù đã import vi_VN-25hours_single | 🔄 doing (chờ CI + nghiệm thu máy) | pre-flight TRƯỚC init native: kiểm tra espeak-ng-data (phontab) + file model nguyên vẹn (onnx ≥1MB, tokens ≥1KB); thiếu/hỏng → fallback giọng máy (không crash) + isAvailable() chuẩn xác + log init native |
| READ-FOCUS-001 | Tab Đọc Focus: thanh đáy chỉ ẩn icon, vẫn chiếm không gian | 🔄 doing (chờ CI + nghiệm thu máy) | Focus mode: AnimatedSize gập chiều cao bottom bar về 0 (trả không gian cho vùng đọc); smart-hide khi cuộn giữ nguyên hành vi cũ |
| BATCH-0915 | 9 lỗi sau build 1d58b78 (owner 2026-09-15) — handoff agent Arena | 🔄 doing | 9 card chi tiết: PDF-JUMP-001, WLIST-LANG-001, PDF-PAGE-001, XLAT-MLKIT-001, READ-TOOLBAR-001, TTS-PIPER-002 (fix xong chờ nghiệm thu), SHELL-GEAR-001, LISTEN-LRC-001, LISTEN-VIEW-001 — xem section "BATCH OWNER 2026-09-15" |
| BATCH-0916 | 9 việc mới (owner 2026-09-16) — handoff agent Arena | 🔄 doing | HYMT-002 (timeout Hy-MT), CABIN-ASR-002 (Zipformer "cho EN" + cabin offline regression), HOME-QUICK-001 (nạp tri thức + mic stub), HOME-STUDIO-001 (Studio đủ 7 mode), HOME-KG-001 (Knowledge Graph vô đáp), HOME-STREAK-001 (thống kê thật), LISTEN-LRC-LAYOUT-001 (lời AI chạm sóng âm), XP-MODE-001 (tab Trải nghiệm + tool ẩn), SHADOW-FILE-001 (ENOENT cache + AB) — xem section "BATCH OWNER 2026-09-16" |
| SHERPA-STREAM-001 | Crash SIGABRT: model streaming nạp qua OfflineRecognizer ("Got 51 Expected 39") | ✅ fix code (chờ CI + nghiệm thu máy) | detection 2 lớp (tên + metadata) + 3 hard-guard chặn OfflineRecognizer với model streaming — live EN (streaming) chạy OnlineRecognizer, file/LRC với model streaming báo lỗi rõ không crash |
| VIENEU-001 | VieNeu-TTS optional engine (PLAN-027) | 📋 proposed | chỉ ghi plan — chưa code |
| TTS-PIPER-002 | Catalog tải Piper (HF rhasspy/piper-voices) ưu tiên VI/EN/ZH/HI + xem thêm | 🔄 doing | PLAN-028; sheet Tải giọng + k2-fsa rồi HF |
| CI-IOS-01 | Action iOS đỏ: `pod install` báo google_mlkit_commons cần deployment target cao hơn | ✅ done (chờ run CI xác nhận) | nâng iOS min target 13/14/15.0 → **15.5** (Podfile + project.pbxproj + AppFrameworkInfo.plist) + script `scripts/ci/ios_set_deployment_target.sh`; patch workflow ở `scripts/ci/ios_ci_workflow.patch` (owner áp — app thiếu quyền `workflows`) |


## Card chi tiết

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
- **Trạng thái:** doing (chờ CI + nghiệm thu máy)
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

### TTS-PIPER-001 — LHB phát tới câu tiếng Việt SẬPP app (Piper TTS)
- **Trạng thái:** doing (chờ CI + nghiệm thu máy)
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

### READ-FOCUS-001 — Tab Đọc Focus: thanh đáy vẫn chiếm không gian
- **Trạng thái:** doing (chờ CI + nghiệm thu máy)
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

### XP-MODE-001 — "Chế độ trải nghiệm": nâng lên tab riêng, đủ 7 mode + hiện các chức năng ẩn trong icon sấm sét
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
  1. Tab "Trải nghiệm" (hoặc mở rộng card Phòng Studio — chọn theo
      wireframe): 7 mục NGHE/NÓI/XEM/ĐỌC/VIẾT/HIỂU/NHỚ — mỗi mục =
      "hướng dẫn có dẫn đường" (guided tour): mục tiêu 1 dòng + 3-5 bước
      thao tác thật (bấm theo chỉ dẫn) + demo nhanh chức năng chính.
  2. Mục "Khám phá công cụ" trong tab: trình chiếu (carousel) các tool
      đang ẩn sau icon sấm sét (Tipiṭaka/Tam Tạng, Video, Word map,
      Triangle, Venn, Cabin…) — mỗi card: icon + tên + 1 dòng mô tả +
      nút "Mở ngay" → mở đúng tool.
  3. Giữ "Chế độ trải nghiệm" cũ trong read settings (không phá), tab
      mới là lớp UX bao trùm.
- **AT:** mở tab Trải nghiệm → chọn ĐỌC → làm theo 3 bước → tới đúng
  chỗ; carousel hiện ≥5 tool ẩn + bấm "Mở ngay" mở đúng tool (kiểm tra
  Tipiṭaka).

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
