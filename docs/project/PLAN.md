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

### PLAN-001 — Bubble TTS cho audio karaoke + đọc
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound)
- Trạng thái: proposed
- Milestone đề xuất: M2+ / M3
- Chi tiết:
  - Tương tự bubble wordlist đã làm (persistent playback + floating round bubble mute + auto-hide 4s + hide khi quay lại wordlist)
  - Áp dụng cho tab Nghe (audio kèm chữ karaoke): bubble hiển thị chế độ karaoke nhiều chế độ (1 chữ hiện thời, 1 dòng hiện thời, full), có thể draggable, tap để mute, auto-hide sau vài giây
  - Tương tự cho tab Đọc TTS: bubble đọc văn bản, hiện dòng đang đọc, tap mute, auto-hide
  - Yêu cầu: playback không dừng khi đổi tab, bubble chỉ hiện khi không ở tab gốc
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | ý tưởng từ issue 4

### PLAN-002 — Đánh giá hàng loạt từ vựng trong tab Đọc (pen + tray màu)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound)
- Trạng thái: proposed
- Milestone đề xuất: M2
- Chi tiết:
  - Trong tab Đọc, đánh giá dễ/vừa/khó/rất khó thủ công từng từ rất lâu
  - Thêm chế độ đánh giá hàng loạt: tay như cây bút, có khay màu tương ứng dễ (xanh), vừa (vàng), khó (cam), rất khó (xám/đỏ)
  - Khi chạm vào khay màu loại nào thì sau đó chỉ cần vẽ chạm lên từ nào thì nó lây chuyển qua thuộc tính đó luôn rất nhanh
  - Cần: bulk update trong VocabularyProvider, HapticFeedback, undo, hiệu ứng lây màu
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 5

### PLAN-003 — Mô hình 4 mức độ thành thạo đề xuất (tư vấn)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound) + tư vấn agent
- Trạng thái: proposed
- Milestone đề xuất: M2
- Chi tiết:
  - Đề xuất gốc:
    - Dễ: hiểu + nhận diện khi nghe + có thể phát âm
    - Vừa: hiểu + nhận ra âm thanh mà không viết hay phát âm được
    - Khó: hiểu + viết mà không phát âm được
    - Rất khó: không được tất cả = vùng mù (blind spot)
  - Tư vấn thêm:
    - Nên tách 4 kỹ năng SM-2 hiện có (Hiểu-Nghe-Đọc-Viết) nhưng gộp vào UI 4 mức để dễ thao tác nhanh
    - Dễ = mastery cao + listen/understand/read/write đều >0.7
    - Vừa = hiểu + nghe được nhưng recall viết/yếu phát âm → gợi ý luyện viết + shadowing
    - Khó = hiểu + viết được nhưng nghe/phát âm yếu → gợi ý luyện nghe + shadowing
    - Rất khó = blind spot → đưa vào review ưu tiên, SM-2 due
    - Không nên gộp thành 1 điểm số duy nhất (vi phạm golden rule AGENTS.md Rule 2) — giữ 4 skill SM-2 tách biệt trong model, chỉ gộp ở lớp UI đánh giá nhanh
    - Thêm bulk evaluation (PLAN-002) sẽ map vào 4 mức này
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 6

### PLAN-004 — Thêm hàng loạt câu/cụm vào wordlist kèm chủ đề
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound)
- Trạng thái: proposed
- Milestone đề xuất: M2
- Chi tiết:
  - Bổ sung vào phần thêm hàng loạt vào wordlist: có thể chọn cả nhiều câu hay nhiều cụm thêm vô một lần luôn
  - Có thể thêm chủ đề cho cả cụm/đoạn đó (topic batch)
  - UI: WordImportSheet mở rộng — chọn nhiều dòng, detect type (phrase/sentence), nhập topic chung, saveDecomposeResults
  - Lưu context từ story nếu đang đọc
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 7

### PLAN-005 — Hoàn thiện merge 630 không mất cũ
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound)
- Trạng thái: proposed
- Milestone đề xuất: M0-M2 INTEGRATE-1
- Chi tiết:
  - Issue 1: đen màn hình khi AI doc + thêm Cloud → fix TextProvider._parsePlainText luôn tạo id mới, resetTranslationForNewDocument(), try-catch analyzedLines, CloudPickerSheet try-catch + snackbar
  - Issue 2: bản dịch cũ chưa lưu → TextLibraryEntry thêm translations field Map<lang, List>, TextProvider.applySavedTranslations() + saveCurrentTranslationsToCloud() auto sau translateAll, load từ Firestore + Hive fallback
  - Issue 3: phần Viết mất AI chấm điểm sau merge → đảm bảo WriteStudioScreen giữ _buildAiReviewCard, _buildRewriteAiReviewCard, _buildSummaryAiReviewCard (2 tầng local + AI local), không xóa
  - Quy trình merge trọn vẹn: theo GOVERNANCE.md rule 4b — không rewrite main, dùng path-checkout sync snapshot: `git checkout origin/arena/01a019bb-in4up -- docs/project docs/GOVERNANCE.md docs/skills AGENTS.md`, commit nhỏ, push ngay, dùng ci_check.sh để tự check CI đỏ, không clean build (giữ cache)
  - Checklist: sau merge chạy `docs/skills/ci-red-debugging/scripts/ci_check.sh` để xác nhận analyze xanh, test xanh, không mất file .bin verification >1MB
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue 8 + handover SECTION1+2

