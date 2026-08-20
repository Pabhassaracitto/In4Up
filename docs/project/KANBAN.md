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
| MVA-T8 | Chat grounding + citation validator (mục 7) | 📋 todo | — |
| OPS-1 | Bật CI knowledge_tests.yml | ✅ done | commit 797efff (người dùng) |
| OPS-2 | Skill ci-red-debugging v1.1 | ✅ done | commit a706953 |
| GOV-1 | Hạ tầng governance (file này + GOVERNANCE + PLAN) | ✅ done | commit này |
| PR-1 | PR #6 (knowledge-work) chờ chiến lược lineage | 🚫 blocked | xem LINEAGE-1 |
| LINEAGE-1 | Quyết định 2 dòng codebase (In4Up vs vipsound-main) | 🟢 decided | main := arena/019fe630-vipsound |
| INTEGRATE-1 | Tích hợp knowledge-work (PR #6) vào main mới | 📋 proposed | sau khi main cập nhật xong |

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
- **Trạng thái:** todo
- **Nội dung:** pipeline 6 bước; validator quoteExcerpt; offline quote-first.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ bàn giao mục 8

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
- **Trạng thái:** decided — người sở hữu chọn: main := trạng thái arena/019fe630-vipsound
  (nâng cấp main "bắt kịp thời đại"; không đổi tên branch để không đứt session đang chạy).
- **Cơ sở xác minh an toàn:** main hiện chỉ có 1 commit gốc (nhập khẩu toàn cây +
  AGENTS.md) — nội dung ĐÃ chứa trong 019fe630 (417 commit, kèm 3 commit docs/skill
  cherry-picked) ⇒ force-move không mất dữ liệu duy nhất nào.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | phát hiện unrelated histories
  - 2026-08-20 | proposed→decided | người sở hữu (qua chat) + agent xác minh trùng lặp |
    người chạy lệnh force-move main (agent không có quyền push main)

### INTEGRATE-1 — Tích hợp knowledge-work vào main mới
- **Trạng thái:** proposed
- **Nội dung:** sau khi main := 019fe630, đưa lib/knowledge + chuẩn hóa SM-2 +
  CI + governance vào main (qua PR #6 đã retarget hoặc cherry-pick chọn lọc);
  kiểm tra xung đột với bản sm2/models của dòng vipsound.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ quyết định LINEAGE-1
