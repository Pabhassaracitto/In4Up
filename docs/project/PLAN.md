# PLAN — Milestone & Kế hoạch dự án

> Milestone đổi trạng thái theo luật GOVERNANCE.md (status-only + append).
> "Kế hoạch mới" ở cuối file là nơi tiếp nhận ý tưởng từ người sở hữu.

## Milestone

### M0 — Hạ tầng kiến thức (schema + chuẩn hóa + migrate) · ✅ done 2026-08-20
- MVA-T1, MVA-T2, MVA-T3 — CI xanh, ADR-0001, skill ci-red-debugging.
- Lịch sử:
  - 2026-08-20 | doing→done | agent | CI runs 32287539067/32293474036/32302871487

### M1 — Pipeline & Vận hành ghi nhớ · ✅ done 2026-08-20
- MVA-T4 ✅ (TextPipeline + isolate worker — nền cho T5/T7).
- MVA-T5 ✅ (compaction + store append-only + worker op — 2026-08-20).
- MVA-T6 ✅ (lifecycle engine — 2026-08-20).
- Đầu ra kiểm chứng: AT4, AT5 (mục 9 bàn giao).
- Lịch sử:
  - 2026-08-20 | doing→done | agent | CI runs 32358239999/32371603413/32380422644

### M2 — Trí tuệ gợi ý · ✅ done 2026-08-20
- MVA-T7 ✅ + MVA-T8 ✅ (Chat grounding — 2026-08-20).
- Lịch sử:
  - 2026-08-20 | todo→done | agent | CI runs 32381534996/32382509679
- Đầu ra kiểm chứng: AT2, AT3, AT6 (mục 9).

### M3 — Phạm vi P2+ · 📌 out-of-scope (theo bàn giao)
- Embedding, vector DB, LLM summarizer tự động, fine-tune GGUF,
  knowledge graph UI. KHÔNG làm trong giai đoạn này — mở lại bằng ADR mới.

## Acceptance Test bàn giao (mục 9) — theo dõi

| AT | Nội dung | Trạng thái |
|---|---|---|
| AT1 | 1 từ gặp ở PDF + audio → 1 unit, 2 evidence, reopen đúng | 🔶 mô hình hỗ trợ ✓; kịch bản e2e chờ INTEGRATE-1 |
| AT2 | Giống chữ khác nghĩa không tự merge | ✅ phủ bởi unit test T1 |
| AT3 | Web đổi nội dung → phát hiện "nguồn đã đổi" | 🔶 phần cơ chế (verifyAgainst) ✅; phần UI còn thiếu |
| AT4 | Đổi tokenizer → unitId & lịch sử KHÔNG đổi | ✅ phủ bởi unit test T1/T3 |
| AT5 | 2 thiết bị conflict → không nhân đôi/mất | 🔶 resolver ✅; tích hợp sync còn thiếu |
| AT6 | Xóa nguồn PDF → xử lý evidence theo policy | 📋 (chờ INTEGRATE-1 + policy xóa ADR mới) |
| AT7 | Tắt AI/GGUF → 4 luồng vẫn chạy | 🔶 OfflineQuoteFirstModel ✓ (không phụ thuộc model); e2e chờ INTEGRATE-1 |
| AT8 | Audio 0.3x + isolate nặng → không giật | 🔶 kiến trúc isolate ✓; đo trên máy thật khi INTEGRATE-1 |

## Trạng thái lineage (LINEAGE-1 done)

- main = vipsound (417-commit lineage) + governance — mọi session mới tự kế thừa.
- Knowledge-work (8/8 task) nằm trên `arena/01a019bb-in4up` — vào main qua INTEGRATE-1.
- Đồng bộ governance-mới-nhất lên main (khi cần):
  `git checkout main && git pull && git checkout origin/arena/01a019bb-in4up -- docs/project docs/GOVERNANCE.md docs/skills AGENTS.md && git commit -m "docs(governance): sync snapshot" && git push origin main`

## Kế hoạch mới (tiếp nhận từ người sở hữu)

> TEMPLATE khi thêm:
> ```
> ### PLAN-<số> — <tên>
> - Nguồn: người sở hữu (YYYY-MM-DD, qua agent <session>/trực tiếp)
> - Trạng thái: proposed
> - Milestone đề xuất: M?
> - Chi tiết: <mô tả>
> - Lịch sử:
>   - YYYY-MM-DD | created | ...
> ```

*(chưa có entry nào)*
