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
| LISTEN-630-01 | Tab Nghe: AB loop bottom overflow 24px + nút "lặp câu tiếp theo" | ✅ done | LRC budget + onPanelChanged (chờ nghiệm thu) |
| GOV-2 | Rule vàng #5: chrome UI không tiếng Việt khi locale ≠ vi + máy bắt | ✅ done | AGENTS.md + test locale (346 entries sạch) |
| WORDLIST-630-01 | Import hàng loạt clipboard/text hoạt động thật + meaning | ✅ done | CSV quotes + smart-fill + preview meaning (chờ nghiệm thu) |
| SRC-630-01 | Nguồn text mới: .md, .json, .docx (thuần Dart, 0 dep mới) | ✅ done | TextSourceLoader + picker + loadTextFile (chờ nghiệm thu) |
| SHERPA-001 | Silero VAD (sherpa_onnx) thay EnergyVad fallback (PLAN-008) | ✅ done | 4a50a77 + cd9cccf (chờ nghiệm thu trên thiết bị) |
| SHERPA-002 | TTS Piper offline (sherpa_onnx): core + engine trong TtsService | ✅ done | run 32524455212 (chờ nghiệm thu build) |
| LANG-630-01 | Sứ giả ngôn ngữ: fallback EN chuẩn + lộ trình bậc vi→en→hi/zh/si→… (ADR-0002, wave 1 phủ 100% T2) | ✅ done | CI run 32573825623 (analyze + rule5/ADR-0002 test xanh) |

---

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
- **Trạng thái:** proposed
- **Nội dung:** EL sound → text đích real-time, TTS nếu muốn, nhắc đeo tai nghe. Đã xong VAD singleton, pipeline isolate, RECORD_AUDIO. Chờ bạn đưa branch sherpa mẫu + .onnx model để thay EnergyVad fallback bằng sherpa_onnx thật.
- **Lịch sử:**
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue mới 3 + Section3 handover

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
- **Trạng thái:** done (chờ CI + nghiệm thu bản dịch của owner)
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
