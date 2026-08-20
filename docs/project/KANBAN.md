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
| MVA-T5 | ReviewEvent append-only + compaction job | 📋 todo | — |
| MVA-T6 | Dual-Memory lifecycle (mục 6 bàn giao) | 📋 todo | — |
| MVA-T7 | Attention Score v1 (mục 5) | 📋 todo | — |
| MVA-T8 | Chat grounding + citation validator (mục 7) | 📋 todo | — |
| OPS-1 | Bật CI knowledge_tests.yml | ✅ done | commit 797efff (người dùng) |
| OPS-2 | Skill ci-red-debugging v1.1 | ✅ done | commit a706953 |
| GOV-1 | Hạ tầng governance (file này + GOVERNANCE + PLAN) | ✅ done | commit này |
| PR-1 | PR #6 (knowledge-work) chờ chiến lược lineage | 🚫 blocked | xem LINEAGE-1 |
| LINEAGE-1 | Quyết định 2 dòng codebase (In4Up vs vipsound-main) | 🟡 proposed | cần người chọn (a)/(b)/(c) |

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
- **Trạng thái:** todo
- **Nội dung (DoD bàn giao):** ghi 1000 event giả lập → RAM không tăng bất
  thường, snapshot đúng sau compaction (500 event/unit → baseline snapshot).
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ bàn giao mục 8

### MVA-T6 — Dual-Memory lifecycle (mục 6)
- **Trạng thái:** todo
- **Nội dung:** Observed→Captured→Promoted→Practicing→Maintained; cấm popup
  chặn luồng; DoD: đọc 5 phút không bị gián đoạn dialog.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ bàn giao mục 8

### MVA-T7 — Attention Score v1 (mục 5)
- **Trạng thái:** todo
- **Nội dung:** công thức w1-w4 (0.4/0.3/0.2/0.1); UI lý do cụ thể; chạy
  trong worker isolate đã có.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | từ bàn giao mục 8

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
- **Trạng thái:** proposed (cần người sở hữu chọn hướng)
- **Nội dung:** main mới = vipsound squashed; branch knowledge = In4Up-MVA.
  Lựa chọn: (a) merge PR #6 để tích hợp knowledge vào vipsound-main;
  (b) giữ song song, governance/docs đồng bộ qua cherry-pick nhỏ;
  (c) dựng lại main từ dòng In4Up. Agent sẵn sàng thực thi theo lựa chọn.
- **Lịch sử:**
  - 2026-08-20 | created | agent arena/01a019bb-in4up | phát hiện khi chuẩn bị
    hòa main: unrelated histories, 565 file khác biệt
