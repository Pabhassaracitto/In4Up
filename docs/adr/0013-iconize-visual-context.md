# ADR-0013 — Iconize Visual Context: tầng render ephemeral cho học từ vựng qua ngữ cảnh thị giác

- **Status:** Accepted (owner duyệt 2026-10-08 — "Được hãy bắt đầu")
- **Date:** 2026-10-07
- **Nguồn:** Hội đồng đa AI ICONIZE-001 (5 vòng, 94.2/100) + audit đối chiếu
  repo của agent. Blueprint đầy đủ: `docs/iconize_visual_context_blueprint.md`.
  Prompt gốc: `PROMPT_HOIDONG_ICONIZE_VISUAL_CONTEXT.md`.

## Context

Cần hệ thống chèn icon vào văn bản/bản dịch để tăng hiệu quả ghi nhớ từ vựng
qua dual coding (câu ví dụ thị giác `The [🐱] catches the [🐭]`, nút "Icon hóa"
trong panel dịch, Smart Cloze thị giác trong vòng ôn), với ràng buộc: không
phá cache dịch/search/export/i18n, miễn phí giấy phép sạch, hoạt động offline,
dữ liệu additive.

## Decision

1. `IconizeEngine` (`lib/features/iconize/`) là **pure function tầng render,
   ephemeral** — chạy SAU cùng pipeline dịch
   (`protect → dịch → restore → plain text cache → iconize tại render`);
   không bao giờ ghi vào `TranslationCache`; plain text luôn là nguồn sự thật.
2. Tra cứu theo khóa `(lemma, POS)`; không khớp chính xác → giữ chữ (an toàn
   trước, đẹp sau). Đọc ké kết quả `sentence_structure_service` nếu đã chạy
   sẵn, không chạy phân tích mới.
3. Ngôn ngữ ≠ `en` dùng Bridge-to-English qua dictionary offline sẵn có;
   phạm vi v1: `en`/`vi` full, `hi/si/zh/zh_TW` light-beta (confidence ≥ 0.85,
   badge Beta).
4. Scaffolding fading điều khiển bởi kết quả ôn thật: hàm `nextScaffoldStage`
   nhận **`quality` int 0..5 của SM-2 canonical (ADR-0001)** — KHÔNG tạo enum
   grade mới, không tạo engine điểm thứ tư, không gộp 3 skill SM-2. Nudge chủ
   động sau 30 ngày density High nếu user không tự rút giàn giáo.
5. Density là 3 nấc 18/32/48% (Low/Medium/High), gợi ý mặc định theo setting
   mới additive "CEFR tự khai" (nullable, null → Medium).
6. Asset nhị phân có Magic Header versioning `ICNB0001`; lỗi đọc → disable
   Iconize cho session + badge cảnh báo, không crash, không retry loop.
7. Per-document override dùng **box Hive riêng**, khóa bắt buộc prefix
   `icon_override_<documentHash>`; tái dùng giá trị hash của cơ chế reopen
   anchor (PDF: `PdfFileIdentity`) nhưng **không** dùng chung box/key —
   luật chặn xung đột keyspace từ gốc.
8. Lazy resolution theo viewport, LRU 200 kết quả; implementation tách nhánh
   platform (mobile/desktop: visibility_detector — **dependency mới, chưa có
   trong pubspec** — hoặc tái dùng virtualization của pdf_reader; Web:
   IntersectionObserver qua `package:web`).
9. Nguồn dữ liệu: Twemoji (CC-BY) + Material Symbols (Apache-2.0) + Brysbaert
   (CC0) + Tatoeba vetted (CC-BY); **không dùng OpenMoji** (CC-BY-SA).
   Attribution vào AboutScreen. Core bundle ~2.1 MB kèm app; pack mở rộng
   ~8.5–9.5 MB qua Model Centre.
10. Schema `WordEntry` additive (`visualExample`, `visualExampleSource`,
    `visualScaffoldStage` default 2) theo tiền lệ `phoneticSource`/`imageUrl2`;
    rà mọi serializer trong `lib/services/`.
11. **Thứ tự rollout bề mặt (chốt với owner 2026-10-07):** v1 chỉ Tab Đọc
    (`pdf_page_translate_panel` + Web reader) — nơi pha ENCODE xảy ra và nguồn
    "ngữ cảnh user đã gặp từ" sinh ra; v1.1 (lane 001d2, SAU nghiệm thu v1)
    mới gắn `translation_toolbar` dùng chung + panel dịch Tab Hiểu. Không phải
    hoặc–hoặc: engine pure function + toggle per-surface nên bề mặt sau chỉ là
    gắn nút.

## Consequences

- (+) Không rủi ro vỡ search/cache/export/a11y/cross-platform; dữ liệu cũ mở
  lên vẫn chạy.
- (+) Tái dùng tối đa hạ tầng sẵn có (grammar services, dictionary,
  vocab_image, SM-2/FSRS, word tap sheet); dung lượng bổ sung nhỏ.
- (+) Giàn giáo rút theo dữ liệu thật, có cơ chế chống trì trệ.
- (−) Recompute lặp khi cuộn nhanh (chấp nhận: LRU + lazy + pre-warm 500 lemma).
- (−) Chất lượng Bridge-to-English phụ thuộc độ dày từ điển offline từng ngôn
  ngữ — `si` có thể yếu; fallback giữ chữ minh bạch, badge Beta.
- (−) Thêm 1 dependency tiềm năng (`visibility_detector`) — quyết định chốt ở
  PR ICONIZE-001d.

## Work breakdown

Card KANBAN `ICONIZE-001` — 9 lane (a–h + d2), mỗi PR ≤ 500 dòng, thứ tự:
asset build tool → engine core → guard/fallback/bridge → UI toggle Tab Đọc (v1)
→ câu ví dụ → Smart Cloze → override/blacklist → test hiệu năng; lane 001d2
(toolbar chung + Tab Hiểu, v1.1) chỉ mở sau nghiệm thu v1 của owner.
Chi tiết: blueprint mục 12.
