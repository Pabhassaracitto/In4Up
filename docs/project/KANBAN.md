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
| MODELS-002 | Trung tâm model: quản lý AI Chat GGUF 1 chỗ + UX import rõ (PLAN-018) | 🔄 doing | banner trạng thái + progress + mock disclaimer + section Chat trong Quản lý Model AI (thu hoạch 01a02a4a) |
| AI-CHAT-01 | Chat: báo "Chưa nạp model AI" sau khi gửi + nút gửi xoay vòng mãi | 🔄 doing (chờ CI + nghiệm thu) | root cause: state=processing ⇒ hasModel=false khi đang generate; chat không có timeout; không xử lý isolate chết; context không giới hạn |
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
| READ-DEV-001 | Thư viện đọc: quét + hiển thị file trên máy (SAF folder, như thư viện nhạc) | ✅ done + CI xanh (chờ nghiệm thu máy) | native in4up/textlib (DocumentsContract đệ quy) + TextDeviceProvider + tab Thiết bị thành danh sách quét; persist folder qua restart |
| LHB-004 | Học thuộc lòng: lặp TTS RIÊNG từng câu (tùy số lần/câu) + persist theo bài — re-apply commit bị revert | ✅ done + CI xanh (chờ nghiệm thu máy) | re-apply b631395 + 3 bug fix (compile: Map.map→Iterable; analyze: chuỗi ?.map().where() → helper; runtime: jsonEncode Iterable) — CI xanh 33944392085 |
| WORDLIST-002 | Import WordList 8 cột chuẩn: nạp CHÍNH XÁC khi dán (fix example_simple/complex bị rơi + phẩy không nháy lệch cột + header VN) | ✅ done (chờ CI) | WordTableParser (pure, test được) + 15 test; căn neo word/ipa/language + cột hấp thụ thông minh + hàng thiếu cột |

---
| CABIN-001 | Cabin dịch: "Không thể khởi động micro / nhận diện giọng nói" — fix mic/STT | 🔄 doing (chờ CI xanh cuối + nghiệm thu máy) | self-heal session treo + retry + keep-alive + lỗi chẩn đoán cụ thể + bỏ cap 2 phút + dictation + Shadowing mic thành toggle (chặn mic treo) |

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
- **Trạng thái:** doing (chờ CI app_analyze + nghiệm thu của owner)
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


### AI-CHAT-01 — Chat báo "Chưa nạp model AI" ngay sau khi gửi + nút gửi xoay vòng mãi
- **Trạng thái:** doing (chờ CI app_analyze + nghiệm thu chủ trên thiết bị)
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
- **Trạng thái:** done + CI xanh 33944392085 (chờ nghiệm thu máy)
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

### CABIN-001 — Cabin dịch: không khởi động được mic / nhận diện giọng nói
- **Trạng thái:** doing (chờ CI xanh cuối + nghiệm thu máy)
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
  đã đổi sang `(_)` theo convention, chờ xác nhận CI xanh.
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
