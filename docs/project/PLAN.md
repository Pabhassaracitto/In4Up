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


### PLAN-006 — Check chéo đa chiều Hiểu ↔ Nghe ↔ Viết (cross-modal mastery)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound)
- Trạng thái: proposed
- Milestone đề xuất: M2 / M3 (sau INTEGRATE-1)
- Chi tiết:
  - Nguyên lý: Hiểu nối với âm thanh 2 chiều qua lại, âm thanh nối với chữ viết 2 chiều, mở rộng hiểu nối với chữ viết 2 chiều → ma trận 3x3 = 9 hướng kiểm tra nhanh cho 1 từ/cụm/câu
  - Các chế độ check nhanh đề xuất (tận dụng pipeline đã có):
    - **Hiểu → Nghe (mô tả nghĩa → nói từ):** hiện nghĩa/định nghĩa → user phải nói được từ/cụm đó càng sớm càng tốt, STT (whisper.cpp / sherpa streaming) check đúng đáp án → pass. Nếu sai, AI gợi ý như phần Viết (summary + action_items)
    - **Nghe → Hiểu (nghe từ → mô tả nghĩa):** phát âm từ → user phải mô tả nghĩa bằng lời nói (STT) hoặc gõ, AI chấm điểm như đã có ở WriteStudio (summary + topics + grammar)
    - **Nghe → Viết (nghe → gõ / viết tay):** nghe từ/câu → gõ lại hoặc dùng Android pen viết xuống, AI chấm chính tả + thứ tự + gợi ý tức thì
    - **Viết → Nghe (thấy từ → đọc đúng):** hiện từ → user đọc, STT check phát âm + shadowing score
    - **Hiểu ↔ Viết:** cho nghĩa → viết câu chứa từ đó, hoặc cho câu → tóm tắt ý → AI chấm như rewrite/summary hiện tại
  - Mục đích: hình thành đa chiều thông tin, thông suốt mọi khía cạnh của từ/cụm, làm chủ hoàn toàn (mastery)
  - Kiến trúc:
    - Tận dụng `VadWhisperPipeline` + `SttServiceFacade` đã có cho STT check
    - Tận dụng `AiServiceFacade` (local GGUF) cho chấm điểm mô tả nghĩa / viết
    - Mỗi lượt check là 1 `ReviewEvent` append-only → đưa vào SM-2 lifecycle (MVA-T5/T6) để tính Attention Score
    - UI: thêm tab `ReviewTab` mở rộng với 9 nút chế độ, mỗi chế độ có bubble riêng (kế thừa PLAN-001)
  - Tư vấn agent:
    - Ý tưởng rất đúng với khoa học ghi nhớ: **cross-modal retrieval** mạnh hơn single-modal. Nên làm!
    - Không nên làm 9 chế độ cùng lúc — bắt đầu với 4 cốt lõi: Hiểu→Nói, Nghe→Hiểu, Nghe→Viết, Nhìn→Nói (đã có 70% nền)
    - Thêm pen viết tay là điểm mạnh trên tablet — cần lưu ý `RECORD_AUDIO` + `WRITE_EXTERNAL_STORAGE` đã có, và cần thêm `android:largeHeap`
    - Tránh OOM: mỗi lần check chỉ load 1 từ/cụm, không load cả list, dùng singleton TTS/STT pointer
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue mới 1 + tư vấn agent

### PLAN-007 — Tab Viết mở rộng: nhật ký, sáng tác, bóng đổ (trace writing)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound)
- Trạng thái: proposed
- Milestone đề xuất: M3
- Chi tiết:
  - Thêm vào tab Viết:
    - **Nhật ký / sáng tác / viết văn:** user viết tự do, có gợi ý AI nếu không rành tiếng Anh thì cứ viết tiếng Việt rồi AI chuyển hoặc dạy cách chuyển sang tiếng Anh
    - **Gợi ý bằng từ khóa:** AI đưa 3-5 từ khóa, user viết đoạn văn chứa chúng
    - **Bóng đổ / trace writing:** hiện chữ xám mờ (ghost text) rồi user viết theo dấu chân chữ viết ấy — như luyện chữ
    - **Dịch Việt→Anh có hướng dẫn:** user viết tiếng Việt → AI local (gemma GGUF) chuyển sang tiếng Anh + giải thích từng bước chuyển (grammar pattern, subject/verb/object) như đã có ở `_buildAiReviewCard`
  - Kiến trúc:
    - Tận dụng `WritingAssignment` + `WritingDraftStore` đã có
    - Thêm `WritingTaskType.journal`, `WritingTaskType.composition`, `WritingTaskType.trace`
    - Ghost text dùng `TextStyle(color: Colors.white.withAlpha(60))` + `Stack` + `TextField` transparent overlay
    - AI Việt→Anh dùng `AiServiceFacade.analyzeSentence()` với prompt dạng `in4up_TRANSLATE_VI_EN` tương tự `in4up_WRITE_REVIEW`
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue mới 2

### PLAN-008 — Sẵn sàng tích hợp sherpa (live stream, cabin dịch STS EL)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/019fe630-vipsound)
- Trạng thái: doing (VAD + TTS xong, còn Zipformer streaming + STS cabin)
- Milestone đề xuất: M3 — Sherpa Integration
- Chi tiết:
  - **Mục tiêu:** Live Streaming STT + Speech Translation (STS) cabin:
    - Sound EL (English Listening) → text ngôn ngữ đích (VI/EN) hiện ra màn hình theo thời gian thực
    - Có lựa chọn phát âm thanh dịch nếu muốn (TTS via sherpa-onnx VITS/Piper)
    - Nhắc thông minh: ví dụ đeo tai nghe để tránh làm ồn phòng họp/lớp giảng (detect headphone plugged + show banner)
  - **Sẵn sàng hiện tại:**
    - `SherpaVadService` đã tạo singleton, absolute path, verification, chỉ load VAD module nhẹ 2-5MB
    - `VadWhisperPipeline` đã chạy trong Isolate, cleanup chunk ngay, tránh OOM
    - `ChunkAudioExtractor` + `VadPipelineIntegration` đã sẵn sàng cho chunk streaming
    - AndroidManifest đã thêm `RECORD_AUDIO`
    - Đã có `lib/features/vad/README_VAD_TTS_STREAMING.md` định hướng format: Whisper .bin, Sherpa .onnx
  - **Khi bạn đưa thông tin dự án có sẵn liên quan:**
    - Agent sẽ lấy tinh túy thừa kế: copy VAD model `silero_vad.onnx`, Zipformer/RNN-T streaming model, VITS TTS model vào `getApplicationDocumentsDirectory()/sherpa_vad_models/` với verification >1MB
    - Thay `EnergyVad` fallback bằng `sherpa_onnx.Vad` thật trong `_ensureInitialized()`
    - Thêm `SherpaSttStreamingService` singleton giữ Pointer C-struct (tránh re-init liên tục, tránh xung đột FFI với whisper.cpp)
    - Thêm `SttsCabinService` (Speech Translation): audio EL → Whisper/Sherpa STT → TranslationService → TTS (sherpa-onnx) → UI stream
    - UI: thêm `LiveCaptionBubble` (kế thừa bubble wordlist) hiển thị 1 chữ hiện thời / 1 dòng hiện thời / full transcript, có nút phát âm + nhắc đeo tai nghe
  - **Đề xuất hay hơn nếu có:**
    - Thay vì STS 2 bước (STT → Translation → TTS), thử **direct speech-to-speech translation** với sherpa-onnx nếu model có (giảm latency)
    - Dùng `sherpa_onnx` offline TTS trước (VITS) thay vì Google TTS để giữ offline hoàn toàn, phù hợp cabin họp
    - Thêm `auto_hide_banner` (đã có widget) để nhắc tai nghe: khi phát TTS mà không có headphone → hiện banner 3s
    - Triết lý bạn nói rất hay: đãi cát tìm đồng, đãi đồng tìm vàng, luyện thành ngọc/kim cương — nên đi theo lộ trình: **VAD (xong) → Live STT (streaming) → TTS (VITS) → STS cabin** mỗi bước 1 milestone, mỗi milestone có AT riêng, không gộp
  - **Checklist sẵn sàng:**
    - [x] VAD singleton + absolute path + verification
    - [x] Pipeline Isolate + cleanup
    - [x] RECORD_AUDIO permission
    - [x] Branch sherpa mẫu — `origin/arena/019fe27a-vipsound` (6d26aaa
      PoC + c614276 Strategy) đã fetch tham khảo; kế thừa từ trước ở 8c6ec9e
    - [x] Model .onnx trên local device (user không đưa lên GitHub vì nặng)
      — cách đặt: `<app documents>/sherpa_vad_models/silero_vad.onnx`
    - [x] Agent tích hợp `sherpa_onnx.Vad` THẬT — `SherpaVadCore`
      (in4up_stt, API v1.13.4 verify từ source k2-fsa) + SherpaVadService
      gọi Silero VAD trước, EnergyVad chỉ còn là fallback
    - [ ] User chạy trên thiết bị: push model → log "Silero VAD: N segments"
    - [x] TTS VITS/Piper — `SherpaPiperTtsCore` + `PiperTtsEngine` (SHERPA-002)
    - [ ] Zipformer streaming (step kế tiếp lộ trình)
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound | issue mới 3 + handover Section3
  - 2026-08-22 | VAD done (SHERPA-001, 4a50a77+cd9cccf) + TTS Piper done code (SHERPA-002) | agent arena/01a0251e-in4up | còn chờ build nghiệm thu + Zipformer streaming

### PLAN-009 — Học tinh hoa Google dịch cabin mới (Gemini 3.5 Live + Gemma Translator offline) → bộ vượt trội
- Nguồn: người sở hữu (2026-08-21) + web search Google 2026 + branch sherpa 019fe27a
- Trạng thái: proposed
- Milestone đề xuất: M3 — Sherpa Integration + Google Cabin Essence
- Chi tiết:
  - **Thông tin Google mới 2026 đã học (từ web search):**
    - **Gemini 3.5 Live Translate (09/06/2026):** model audio mới nhất, speech-to-speech near real-time 70+ ngôn ngữ, tự động detect không cần config tay, giữ nguyên intonation/pacing/pitch của người nói, generate liên tục (continuous) cân bằng giữa chờ context để tăng quality và dịch ngay để đồng bộ, chỉ chậm vài giây sau người nói, noise robustness cho môi trường ồn, dùng cho multilingual calls/meetings/lessons/broadcasts. Đang rollout: Gemini Live API + AI Studio (public preview), Google Meet private preview cho Workspace business, Google Translate app Android/iOS. Đối tác Grab test với 10M voice calls/tháng driver-traveler.
    - **Live Translate upgrade cho travelers (31/03/2026):** trong Google Translate app, Live Translate + Listening mode qua tai nghe, giữ emotional tone (vui, bực, thì thầm), xử lý idioms/slang/local expressions thay vì dịch từng từ, hỗ trợ 70+ languages, markets: US, India, Mexico beta 12/2025 → mở rộng FR, DE, IT, JP, ES, TH, UK.
    - **Gemma Translator offline (10/08/2026):** Raspberry Pi 5 + mic/speaker portable, chạy Gemma 4 E2B lightweight LLM, màn hình cảm ứng nhỏ hiện text, núm xoay chọn ngôn ngữ, nút push-to-talk, chassis in 3D, open-source trên GitHub, cho phép real-time voice translation không cần WiFi/cellular. Khác Timekettle Fluentalk T1 ở chỗ open-source + hardware rẻ → mở cửa cho creators/startups.
    - **TranslateGemma (15/01/2026):** family open translation models trên Gemma 3, 4B/12B/27B, 55 ngôn ngữ, SFT trên parallel data human + synthetic từ Gemini + RL phase, 12B vượt Gemma 3 27B với <50% params, giữ multimodal (dịch text trong ảnh).
    - **Google Meet speech translation GA (27/01/2026):** general availability cho business, bidirectional EN <-> ES, FR, DE, PT, IT, dubbed audio đè lên giọng gốc mô phỏng tone/cadence, 1 language pair per meeting, không có trong recording, admin ON by default. Với Gemini 3.5 private preview: 70+ languages, 2000+ combos trong 1 meeting (trước chỉ EN<->X).
  - **Tinh hoa sẵn có của mình (đã có):**
    - Whisper.cpp offline .bin GGML q4_0 (37MB) đã chạy, VAD pipeline đã xong (SherpaVadService singleton absolute path, ChunkAudioExtractor lazy delete ngay, VadWhisperPipeline Isolate + offset corrector)
    - Sherpa-ONNX spike PoC từ branch 019fe27a (6d26aaa): SherpaSttEngine OfflineRecognizer + OnlineRecognizer, Strategy Pattern, registry SttEngineType.sherpa, model .onnx nhẹ 2-5MB VAD
    - Wordlist bubble persistent playback đã làm (draggable, auto-hide 4s, tap mute, hide khi về tab gốc) — kế thừa cho karaoke bubble
    - Cross-modal mastery PLAN-006 (Hiểu↔Nghe↔Viết 9 hướng) + bulk evaluation pen+tray màu PLAN-002
  - **Tích hợp thành bộ vượt trội (đề xuất):**
    - **Offline-first như Gemma Translator:** dùng sherpa_onnx VAD (2-5MB) + Whisper tiny q4_0 (37MB) cho file → LRC karaoke, sherpa streaming Zipformer cho live mic (<100ms), TranslateGemma 4B cho text translation 55 languages (thay Google Free/Libre/MyMemory), VITS/Piper TTS cho output → chạy hoàn toàn offline trên tablet ARM64, giống Gemma Translator open-source trên Pi5
    - **Online-enhanced như Gemini 3.5 Live:** khi có mạng, switch sang Gemini Live API để có tone/emotion preservation, 70+ languages, continuous generation (không turn-by-turn), noise robustness, auto detect
    - **Cabin mode như Google Meet + Cabin AI:** UI side-by-side (original | translation) + dubbed audio giữ tone, listening mode (đưa phone lên tai như call thường) + headphone mode, per-viewer language setting, 1 pair per meeting nhưng hỗ trợ 2000+ combos khi dùng Gemini 3.5, reminder đeo tai nghe (auto_hide_banner) khi phát TTS mà không có headphone để tránh ồn phòng họp/lớp
    - **Học thêm cho cộng đồng:** open-source model paths, dynamic download (giống SttModelManager) thay vì đóng gói APK tránh phình, giữ Pointer singleton tránh xung đột FFI whisper.cpp + sherpa_onnx, cung cấp STL 3D print chassis như Gemma Translator để makers tự build device dịch offline giá rẻ
  - **Lộ trình đãi cát tìm vàng:**
    - VAD (xong) → Live STT streaming (Zipformer) → TTS VITS → TranslateGemma 4B → STS cabin (STT→Translation→TTS) → S2S direct nếu có model → bundle thành In4Up Super Translator Device (tablet + bubble karaoke 1 chữ/1 dòng/full)
    - Mỗi bước có AT riêng, không gộp, CI check qua `ci_check.sh`
- Lịch sử:
  - 2026-08-21 | created | owner via arena/019fe630-vipsound + agent web search | học Google cabin mới + sherpa branch 27
  - 2026-08-22 | lộ trình step "TTS VITS" done (code) | agent arena/01a0251e-in4up | SHERPA-002 — Piper offline hoàn toàn; step kế: Zipformer streaming live STT
### PLAN-010 — Tab Đọc: chủ đề + ngôn ngữ xuyên suốt lưu từ (READ-630-01/02)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/01a0251e-in4up — kế thừa 019fe630)
- Trạng thái: done (code 2026-08-21, chờ nghiệm thu build)
- Milestone đề xuất: M2
- Chi tiết:
  - Model: `WordEntry` thêm `topics: List<String>` + `languages: List<String>`
    (từ/cụm/câu thuộc N chủ đề, M ngôn ngữ). Migration lossless từ `topic`/`language`
    cũ; filter WordList dùng `.contains()`; xóa tag không xóa từ + ngữ cảnh.
  - `SelectionSaveSheet` chung PDF + Web cho đoạn chọn nhiều dòng (mode không màu):
    lưu nguyên cụm/câu HOẶC lưu thông minh (hàng loạt), đều có chọn/tạo topic +
    language (chip có sẵn + ô nhập mới).
  - Tap/long-press sheet (các mode wordType/CEFR/difficulty): hiện đủ IPA,
    từ/cụm/câu, topic, language của entry đã lưu; nút "Sửa thông tin" mở
    `VocabEntryEditSheet` (IPA, loại, thêm/bớt topic, thêm/bớt language) —
    chỉ sửa tag + meta, KHÔNG đụng word/context/SM-2.
- Lịch sử:
  - 2026-08-21 | created | owner via chat | issue tab đọc #1, #2 (+ rà soát #2)

### PLAN-011 — Tab Đọc: marker "từ đã lưu" theo nhu cầu + lưu hàng loạt (READ-630-03/04)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/01a0251e-in4up — kế thừa 019fe630)
- Trạng thái: done (code 2026-08-21, chờ nghiệm thu build)
- Milestone đề xuất: M2
- Chi tiết:
  - Marker bao quanh từ đã lưu (green = đã lưu, amber = có ghi chú, red = đến kỳ ôn):
    MẶC ĐỊNH TẮT (đọc sạch, "đơn giản mặc định"), nút toggle trong toolbar PDF + Web
    ("sẵn sàng phức tạp khi cần"), khi bật kèm legend giải thích. Persist
    SharedPreferences key `reader_show_recall_markers`.
  - Lưu hàng loạt thông minh: tách extractor/model/importer sang
    `lib/services/vocab_batch/` (dùng chung); Web batch sheet thêm field
    **language** (bulk apply + edit + import); PDF thêm nút "Lưu hàng loạt" từ
    đoạn chọn / cả trang (từ + cụm + câu → 1 topic + language cùng lúc).
- Lịch sử:
  - 2026-08-21 | created | owner via chat | issue tab đọc #3 + lưu hàng loạt

### PLAN-012 — Tab Nghe: sửa AB loop bottom overflow + lặp câu tiếp theo (LISTEN-630-01)
- Nguồn: người sở hữu (2026-08-21, qua agent arena/01a0251e-in4up — kế thừa 019fe630)
- Trạng thái: proposed
- Milestone đề xuất: M2
- Chi tiết:
  - Bug: audio + chữ tiny + bật lặp AB → bottom overflow 24px che thanh điều hướng
    (Lặp bài, Lặp AB, tốc độ, AI...) và che 1/2 nút "Looping passage"
    (Next loop; Save; Delete). Sửa layout (Flexible/ConstrainedBox/safe area).
  - Tính năng: nút "Lặp câu tiếp theo" — sau khi xong chu kỳ AB ở câu hiện,
    tự chuyển sang câu kế tiếp rồi lặp (giúp người học "lười vận động thân
    mà nhận được tâm" — dưỡng chất tự thấm, không cần mò xa). Đặt cạnh
    Next loop / Save / Delete.
  - Owner chỉ đạo: làm SAU khi READ-630-* hoàn tất và đã push.
- Lịch sử:
  - 2026-08-21 | created | owner via chat | "Trước khi làm phần này... hoàn tất các task trước và push"
### PLAN-013 — Rule locale chrome + import WordList thật + nguồn text md/json/docx
- Nguồn: người sở hữu (2026-08-21, qua agent arena/01a0251e-in4up — item 3,4,5)
- Trạng thái: done (code 2026-08-21, chờ nghiệm thu build)
- Chi tiết:
  - **Rule #5 (GOV-2):** locale ≠ vi → chrome UI không tiếng Việt; thiếu dịch
    → English; không bao giờ fallback vi. Máy bắt: generator + test
    `locale_chrome_no_vietnamese_test.dart` + QA tay EN/JA/BN.
  - **Import WordList (WORDLIST-630-01):** bảng header word/meaning/ipa/
    topic/example/example_simple/example_complex/language — CSV quotes,
    không _minLength cho hàng cấu trúc, từ đã có được smart-fill (nền merge
    từ điển + trò chơi nhìn chữ–nghe âm–viết nghĩa AI chấm).
  - **Nguồn text (SRC-630-01):** TextSourceLoader thuần Dart: .md (strip),
    .json (gom string), .docx (ZIP + ZLibCodec raw-deflate + <w:t>);
    loadTextFile → Future<bool>; picker 4 điểm; .doc cũ báo rõ.
- Lịch sử:
  - 2026-08-21 | created | owner via chat
  - 2026-08-21 | doing→done | agent arena/01a0251e-in4up | 3 commit (rule, import, loader)

### PLAN-017 — AI Chat thật: tích hợp llama.cpp native backend (hết mock)
- Ghi chú ID: từng ghi PLAN-014 trên nhánh 01a02601; đổi PLAN-017 khi merge
  01a0251e vì PLAN-014 (Sứ giả ngôn ngữ) và PLAN-015 (READ-630-05) đã có sẵn —
  tránh trùng ID.
- Nguồn: người (2026-08-21) — yêu cầu "Hoàn thiện chat AI" kèm audit nhánh
  arena/01a0251e-in4up (chat UI/wiring chạy nhưng câu trả lời vẫn mock;
  native binding có sẵn nhưng chưa nối; llama.cpp chưa có submodule/CMake).
- Trạng thái: done (code 2026-08-21, chờ nghiệm thu build) — agent arena/01a02601-in4up, PR #8; card KANBAN AICHAT-01.
- CI: workflow full build đỏ sẵn trên baseline (bisect 5 vòng bằng tag oracle — xem card AICHAT-01).
- Milestone đề xuất: M3 (ngoài hợp đồng bàn giao MVA) — AI local offline.
- Chi tiết: submodule llama.cpp pin b10567; CMake Android (file riêng, không
  đụng vùng bảo vệ UltraTimeStretch) + Windows; nối AiNativeBindings vào
  isolate AiEngineGemma với mock fallback; hasModel trung thực; mock→real
  re-init; validate GGUF magic; CMake tự init submodule (token thiếu quyền
  workflows). Đã verify local (build + ABI smoke) và chờ CI full build.
### PLAN-014 — Sứ giả ngôn ngữ: lộ trình bậc vi → en → hi/zh/si → … (LANG-630-01)
- Nguồn: người sở hữu (2026-08-22, qua agent arena/01a0296a-in4up — "EL HIN CH SH")
- Trạng thái: done (code + ADR-0002 + máy bắt; chờ CI + nghiệm thu bản dịch)
- Chi tiết:
  - Bất biến rule #5 mở rộng xuống tầng ARB: locale ≠ vi thiếu dịch → English
    (không bao giờ vi); mọi ARB giữ key parity với template `app_en.arb`.
  - Tier lộ trình + sàn ratchet: `lib/core/language/language_roadmap.dart`,
    `tool/lang_rollout_floors.json`, chính sách giữ-English
    `tool/lang_keep_english.json`, báo cáo `tool/lang_rollout_report.py`,
    máy bắt group ADR-0002 trong `test/locale_chrome_no_vietnamese_test.dart`
    (CI app_analyze.yml đã chạy file này sẵn).
  - Wave 1 (2026-08-22): hi/zh/zh_TW/si phủ 100% message chrome; vá word-salad
    cũ; key ARB mới phải dịch đủ 4 locale T2 ngay trong cùng PR.
  - Bước sau (đề xuất, chờ owner chọn): nâng locale T3 tiếp theo lên T2
    (ứng viên theo độ phủ: ar/ru 41.7%, ja/ko/th 41.4%) — làm bằng wave mới,
    nâng sàn, không đổi ADR này.
- Lịch sử:
  - 2026-08-22 | created | owner via chat | "I4U | Language EL HIN CH SH"
  - 2026-08-22 | doing→done | agent arena/01a0296a-in4up | ADR-0002 + wave 1 + ratchet test

### PLAN-015 — Tab Đọc: nhận diện text ĐÃ LƯU khi lưu + gợi ý hành động tiếp (READ-630-05)
- Nguồn: người sở hữu (2026-08-23, qua agent arena/01a0251e-in4up)
- Trạng thái: proposed
- Milestone đề xuất: M2
- Chi tiết:
  - Khi lưu dạng NHIỀU text (lưu hàng loạt / lưu thông minh), nếu đoạn text
    ấy ĐÃ CÓ trong WordList:
    1. **Nhận diện + cho người dùng biết** (không im lặng skip, không im lặng
       ghi đè) — badge/khối báo "đã có" rõ ràng từng mục.
    2. **Gợi ý hành động tiếp theo hợp lý**:
       - **Thêm ngữ cảnh** nếu đó là ngữ cảnh MỚI (câu/chương/khoá học khác
         với các context đã lưu của entry) — action một chạm.
       - **Cập nhật** (bổ sung nghĩa/note/tag) nếu thông tin mới có giá trị.
       - **Bỏ qua** nếu không có gì mới.
  - Nền có sẵn (tận dụng, không làm lại):
    - `SelectionSaveSheet` chế độ "Lưu thông minh (hàng loạt)" đã có badge
      `đã có`/`mới` + nút "Chỉ chọn mục MỚI" (READ-630-04).
    - `addWithAutoClassify` đã smart-fill entry cũ: bổ sung context + tag,
      KHÔNG ghi đè nghĩa/IPA có sẵn.
    - `WordEntry.contexts` (List<VocabContext>) — so sánh context mới với
      context đã có để biết "ngữ cảnh mới hay trùng".
  - Lưu ý: KHÔNG thay đổi chính sách "không ghi đè dữ liệu cũ"
    (READ-630-02) — mọi cập nhật phải qua hành động người dùng chọn.
- Lịch sử:
  - 2026-08-23 | created | owner via chat | "khi lưu dạng nhiều text nếu đoạn đã có thì nhận diện + gợi ý hành động (cập nhật, thêm ngữ cảnh nếu mới)"

### PLAN-016 — Tab Nghe: curtain LRC + AI sheet theo thói quen + dịch xuyên tab
- Nguồn: người sở hữu (2026-08-23, qua agent arena/01a02fee-in4up)
- Trạng thái: done (fix source-binding + CI, chờ QA đổi file trên thiết bị)
- Milestone đề xuất: M2
- Chi tiết:
  - Khi STT/cached LRC hoàn tất, rèm lời thoại mở tối đa an toàn sát waveform.
  - AI là bottom sheet riêng có một chuỗi gesture tự nhiên: cuộn nội dung; khi
    nội dung về đầu thì kéo tiếp hạ cả sheet; kéo hết hoặc chạm ngoài để ẩn.
  - Layout lấy chiều cao viewport thật của Listen trong shell để loại bỏ bottom
    overflow khoảng 126px khi LRC + bộ chọn AI cùng xuất hiện.
  - Tab Hiểu và Nghe dùng chung resolver bản dịch từ `TextProvider`, bảo đảm
    bản dịch tạo/lưu ở tab Đọc xuất hiện theo cùng cài đặt karaoke.
- Lịch sử:
  - 2026-08-23 | created→doing | agent arena/01a02fee-in4up | triển khai LISTEN-823-01, chờ CI + nghiệm thu
  - 2026-08-23 | 18:52 UTC | doing→done | agent arena/01a02fee-in4up | bf83fdc; App Analyze + Locale run 32659292077 xanh
  - 2026-08-24 | 00:43 +0530 | done→reopened | owner + agent arena/01a02fee-in4up | lời audio cũ vẫn bám khi đổi file; bổ sung source identity + chặn callback/cache cũ
  - 2026-08-24 | 00:46 +0530 | reopened→done | agent arena/01a02fee-in4up | 1d05ce9; CI 32660616256 xanh

### PLAN-018 — Trung tâm model: quản lý AI Chat (Gemma GGUF) 1 chỗ + UX import rõ ràng
- Nguồn: người sở hữu (2026-08-23) — "sau khi import model không thấy biểu hiện gì,
  người dùng nghi ngờ không biết nạp chưa; nên quản lý models 1 chỗ nơi setting
  của home, import trực quan và tải online nếu muốn".
- Trạng thái: doing — thu hoạch từ arena/01a02a4a-in4up vào 251e (2026-08-25); card KANBAN MODELS-002.
- Chi tiết:
  - Chat screen: banner trạng thái model LUÔN HIỆN (chưa nạp / copy X% / tải X% /
    đang nạp native 1–2 phút / lỗi + Thử lại / sẵn sàng + tên file + dung lượng).
  - Engine báo model-load thật (isolate gửi tín hiệu sau khi llama_model_load xong)
    — facade chờ signal trước khi trả lời chat; mock response luôn kèm disclaimer
    "⚠️ Chưa nạp model AI — đây là trả lời MẪU".
  - Trung tâm "Quản lý Model AI" (stt_model_settings_screen — đã mở từ home settings):
    thêm section 4 "Chat — Gemma (LLM)" — status + Import .gguf + Tải về (URL,
    default HuggingFace Gemma-2-2B-it Q4_K_M, chỉ WiFi, progress) + Xóa.
  - Import copy file theo chunk kèm tiến độ (file ~1.5GB); download có verify
    header GGUF sau tải.
- Lịch sử:
  - 2026-08-25 | created→doing | agent arena/01a0251e-in4up | thu hoạch từ 01a02a4a (26571af/38e8865/b84e571/2868af2) + fix 3 lỗi compile, chờ CI + nghiệm thu

### PLAN-019 — Dịch offline: glossary Phật học/Pali + protect-tokens + ML Kit (XLAT-001)
- Nguồn: người sở hữu (2026-08-23, qua prompt giao việc cho agent
  arena/01a02ffc-in4up — "Dịch offline + glossary Phật học / Pali (+ Hindi)")
- Trạng thái: proposed
- Milestone đề xuất: ngoài M0–M3 (phạm vi Đọc/Dịch, không đụng knowledge MVA)
- Chi tiết:
  - **Vòng 1 (mọi nền tảng):** glossary Hive + lookup longest-match
    (normalize Pali/Việt qua CanonTokenizer) + protect-tokens `__G{n}__`
    cắm TRƯỚC mọi engine; hạt giống 226 mục Pali/EN → VI (locked);
    đồng bộ 1 chiều WordEntry(Pali/Phật học) → glossary domain=user;
    UI "Thuật ngữ dịch".
  - **Vòng 2 (Android/iOS):** ML Kit on-device (google_mlkit_translation)
    — engine dịch câu offline, EN↔VI, EN↔HI; HI↔VI pivot qua EN
    (2 bước + glossary hai đầu); model chỉ tải khi user bấm; thiếu model
    → failure rõ, không rơi về ráp từ.
  - **Vòng 3:** toggle "chỉ offline"; KANBAN XLAT-001.
  - Pipeline: cache MD5 → glossary → ML Kit → online (nếu mạng + không
    khóa offline) → từ điển offline (last resort) → restore.
  - KHÔNG phải RAG/embedding/vector DB. KHÔNG gọi chat GGUF là "dịch giả
    Phật học". Pali không phải ngôn ngữ MT — Pali = glossary + giữ nguyên + gloss.
  - **Chưa làm (đề xuất tiếp theo):** Windows `GgufTranslateEngine` stub
    (chỉ khi PR #8 đã nằm trên 251e); hạt giống HI (chờ bảng từ chủ gửi);
    seed tiếng HI hiện để trống theo lệnh chủ.
- Bằng chứng: card XLAT-001 (KANBAN) + test/translation_glossary_test.dart.
  Lưu ý: sandbox không có Flutter SDK — code + test chưa chạy máy,
  chờ `flutter pub get` + CI + nghiệm thu thiết bị của chủ.
- Lịch sử:
  - 2026-08-23 | created | owner via prompt | "I4U | READ Translate"

### PLAN-020 — YouTube học ngôn ngữ kiểu Language Reactor (nối nốt, local-first)
- Nguồn: người sở hữu (2026-08-30) — tham khảo yt-dlp + Language Reactor;
  agent arena/01a01580-in4up tư vấn kiến trúc (không copy server Node/Python).
- Trạng thái: proposed
- Milestone đề xuất: ngoài M0–M3 (phạm vi Tools/YouTube + tab Nghe; không đụng
  knowledge MVA, không tab thứ 6)
- Chi tiết: xem mục dưới. Card KANBAN: YT-LR-001.
- Lịch sử:
  - 2026-08-30 | created | owner via chat + agent arena/01a01580-in4up |
    "tùy biến youtube tải về / phụ đề / chạy luôn + công cụ sẵn có như langua reaction"

#### 0. Quyết định kiến trúc (đọc trước khi code)

**Không** dựng backend Node.js/Python trên cloud để chạy `yt-dlp`. In4Up là
local-first: máy chủ cloud bị YouTube chặn IP; cookie/proxy trên server = rủi ro
Tài khoản + ToS; CI GitHub Actions không phải máy học của user; dịch đã có
`TranslationService` + glossary (XLAT-001), không thêm DeepL/Libre server.

`yt-dlp` **không** phải trụ cột mặc định trên mobile. App **đã có**:

| Nhu cầu LR | Đã có trên DEV | Ghi chú |
|---|---|---|
| Phát video | iframe + IFrame API (`yt_player_screen.dart`, WebView) | Đúng ToS hơn tải video |
| Phụ đề + timestamp | `YtService.fetchCaptions` 3 tầng (explode / timedtext / HTML) | `youtube_explode_dart` |
| Song ngữ | `fetchBilingualCaptions` + merge overlap + `TranslationService.translateBatch` | Nối XLAT glossary, đừng engine mới |
| Tải audio | `YtDownloader` / `youtube_download_service` → `PlayerProvider.loadSong` | Tab Nghe karaoke/LRC sẵn |
| Lưu lời | `YtService.saveLrc` từ tab Captions | Reopen LRC (REOPEN-001) |
| Tra từ / POS | `word_analysis_sheet` + WordList / SM-2 | Player đã phác Known/Learning |
| YouGlish | `lib/screens/tools/youglish/` | Giữ, không làm lại |
| Shadowing | tab Nghe / Understand | Câu YouTube → clip audio đã tải |

`yt-dlp` chỉ **WP-Z (tuỳ chọn, desktop)**: binary user tự cài, Process spawn,
không đóng gói APK, không chạy trên GitHub Actions / VPS. Dùng khi explode
gãy (YouTube đổi client). Mobile = explode + iframe.

Pháp lý: học cá nhân, không redistributive video/audio, không cache YouTube
trên server. UI nói rõ "tải audio để học offline trên máy bạn".

Không tab thứ 6. Không player mp4 local first-class. Không HTTP lúc bootstrap.

#### 1. Sư phạm (vì sao LR hiệu quả — giữ đúng, đừng làm "máy dịch phụ đề")

Language Reactor thắng vì **i+1 trong dòng chảy**: nghe + chữ cùng lúc, bấm
dừng đúng câu, nhìn L1 khi kẹt, lưu từ **trong ngữ cảnh video**.

Bắt buộc:

1. **Phụ đề gốc (L2) là nguồn sự thật** — thường EN (hoặc ngôn ngữ video).
   Bản L1 (VI/HI/…) là lớp phủ, không thay lời gốc.
2. **Một câu = một vòng lặp học**: phát lại câu, chậm 0.75–0.9, shadow,
   rồi mới câu sau. Timestamp caption = AB loop, không cắt video.
3. **Từ phải về WordList có ngữ cảnh** (title video, dòng, offset thời gian)
   — Known/Learning/Ignored trong player = view lên vocabulary, không hộp
   đếm riêng chết.
4. **Không auto-play dịch TTS đè tiếng gốc** trừ khi user bật (cabin ≠ LR).
   LR = đọc chữ + nghe gốc. Cabin STS là PLAN-008, kênh khác.
5. **Pali/Phật học**: glossary XLAT protect-tokens nếu dịch caption — không
   để ML Kit dịch *sati/nibbāna*.

#### 2. Việc còn thiếu (không viết lại explorer)

`yt_player_screen.dart` (~1216 dòng) đã: iframe sync `getCurrentTime`,
subtitle lớn + translation, tab văn bản, Known/Learning/Ignored **phác**.
Khe cần đóng:

- A. Đồng bộ ổn: poll IFrame API + highlight câu; seek khi bấm dòng;
  pause-on-click từ (LR).
- B. Known/Learning **ghi WordList** (`VocabularyBridge` / `addWithAutoClassify`)
  + `VocabContext.sourceRef = youtube:<id>`, `textStartOffset` thời gian.
- C. Dịch caption đi `TranslationService` (glossary + ML Kit + cache MD5),
  không `translateBatch` tách pipeline.
- D. "Học offline": audio đã tải + LRC đã lưu → mở tab Nghe (karaoke,
  AB, shadowing) — một nút, không pipeline thứ hai.
- E. Loop câu / câu kế từ timestamp caption (LISTEN-630-01 đã có nút
  "lặp câu tiếp" cho LRC — tái dùng, đừng viết AB YouTube riêng nếu audio
  path có LRC).
- F. Gộp `youtube_download_service.dart` vs `YtDownloader` (hai stack).
- G. YouTube Data API key đang `''` — explorer kênh/list phụ thuộc key;
  dán link video phải **chạy không cần key** (oEmbed + explode đã có).

#### 3. Work package (mỗi WP 1 commit xanh + AT; harvest riêng)

**WP0 — Kiểm kê (không code):** bảng file × hành vi trên thiết bị
(explode captions EN/VI, tải audio, iframe sync, save LRC → Nghe).
Báo SHA + lỗ hổng thật. Không thêm package.

**WP1 — Player LR dùng được:** seek dòng, highlight câu theo
`getCurrentTime`, pause khi tap từ, hiện L2 + L1. AT: 1 video có CC EN,
bấm dòng nhảy đúng ±0.4s.

**WP2 — Từ → WordList:** tap từ mở sheet có sẵn; Known/Learning/Ignored
persist Hive; ngữ cảnh = câu + `youtube:<id>` + ms. AT: lưu từ, tắt app,
mở WordList còn context.

**WP3 — Dịch caption = XLAT:** `fetchBilingualCaptions` gọi
`TranslationService` (protect-tokens). Thiếu model ML Kit → failure rõ,
không rơi từ điển 670 từ im lặng. AT: câu có *sati* không bị dịch bậy.

**WP4 — Một nút "Học trong tab Nghe":** nếu đã có audio path + LRC,
`loadSong` + áp LRC. Chưa có audio → tải (YtDownloader) rồi mở Nghe.
AT: từ player YouTube sang Nghe, karaoke khớp timestamp.

**WP-Z — (tuỳ chọn, desktop) yt-dlp sidecar:** `Process` gọi `yt-dlp`
nếu user đã cài (`yt-dlp --version`); `--write-sub --write-auto-sub
--skip-download` hoặc `-x --audio-format m4a`. Không binary trong APK;
Android/iOS không hiện. Cập nhật yt-dlp = việc của user, không `pip`
trong CI.

Thứ tự: WP0 → WP1 → WP2 → WP3 → WP4. WP-Z sau cùng, có thể không làm.

#### 4. Cấm

- Server/VPS/`yt-dlp` trong GitHub Actions để lấy YouTube.
- Tab thứ 6; player mp4 local như nguồn hạng nhất.
- Tải full video 1080p mặc định (chỉ audio khi user bấm, chất lượng chọn được — đã có).
- LLM chat GGUF dịch phụ đề (không gọi Gemma là dịch giả).
- Embedding/vector DB / RAG.
- HTTP lúc `main()` / `ensureModel`.

#### 5. Prompt topic

Copy `PROMPT_AGENT_YOUTUBE_LANGUA.md` (gốc repo) cho agent topic **nhánh mới
từ tip DEV**. Không merge 580. Path-checkout file YouTube + test nhỏ vào DEV.

### PLAN-021 — Tipiṭaka (OpenTipitaka Pa-Auk): nối tiếp module kinh điển
- **Nguồn:** owner (2026-09-03), triển khai trên session
  `arena/019ff2f6-in4up` (workspace Linux + worktree Windows).
- **Trạng thái:** doing — DEMO đã nằm trong DEV (commit `18813d6`),
  các bước production làm trên **nhánh mới từ tip DEV**.
- **Tài liệu bàn giao (BẮT BUỘC đọc trước khi giao việc):**
  - `docs/Bangiao/bangiao_tipitaka.md` — gom đủ INTEGRATION_GUIDE + README
    module + AGENT_PROMPT_TIPITAKA + TIPITAKA_HANDOFF (ngữ cảnh, 4 bước
    F/C/B/D, ràng buộc, nguồn DB).
  - `lib/features/tipitaka/models/README.md` — schema DB chuẩn hóa.
  - KANBAN card `TIPITAKA-001`.

#### 1. Đã làm (đang chạy trong DEV)
- Module `lib/features/tipitaka/`: models (Collection/Book/Segment —
  Equatable), `services/db_service.dart` (sqflite, schema chuẩn, tìm
  kiếm LIKE + index), screens (Library 2 cột theo Piṭaka → sách;
  Reader song ngữ Pāli/Việt/Anh + bookmark/ghi chú; Search toàn văn;
  Download; Language Pack 26 ngôn ngữ), `tipitaka.dart` barrel.
- Tích hợp app: `main_shell.dart` — quick-action bolt "tipitaka"
  (Home → ⚡ → Tipiṭaka).
- `pubspec.yaml`: +`sqflite`, +`path`.
- Dữ liệu DEMO: `assets/db/tipitaka.sqlite` (~1.69MB, ~10k đoạn, import
  từ 3 file nguồn Pali-roman + Vi + En) + `scripts/import_tipitaka.py`
  (Windows/Linux, dynamic repo_root).
- i18n: `language_pack_screen.dart` fallback vi/en; 26 gói tải từ nguồn
  Pa-Auk (chỉ khi user bấm — quy tắc model, không auto lúc mở app).

#### 2. Phải làm (production — MỖI NHÁNH MỚI chọn 1 bước, đừng làm tất)
- **Bước F — Full DB import:** cập nhật `scripts/import_tipitaka.py`
  nhập TẤT CẢ bảng nguồn (`vin01t_tik`, `e0101n_mul`, …) thay vì chỉ
  `e0703n_nrf` + LIMIT 10000 (hoặc adapter đọc trực tiếp 2 file `.db`
  nguồn). Kết quả: `tipitaka.sqlite` ~500MB đầy đủ.
- **Bước D — Production/Offline/Citation:** DB KHÔNG bundle assets
  production — download về `getApplicationDocumentsDirectory` khi user
  mở lần đầu (hoặc ADB/file manager với bản test); hoàn thiện
  bookmark/note persistence qua restart (`tipitaka_user_notes`); nút
  "Copy Citation" (format `DN 1.1` / `Dīgha Nikāya 1.1`).
- **Bước B — Spaced repetition/học thuộc:** bảng `tipitaka_learning_items`
  (đã có trong schema, chưa dùng) ↔ `memory_mode`; nút "Thêm vào bộ
  nhớ" trên đoạn kinh; SM-2 hoặc `next_review_at` + `memory_strength`.
- **Bước C — AI-RAG với citation:** `TipitakaRAGService` (đặt trong
  `in4up_ai` hoặc module tipitaka): câu hỏi → tìm đoạn kinh qua
  `tipitaka_fts`/LIKE → trả lời DUY NHẤT từ đoạn đã lấy + citation chuẩn
  (`Dīgha Nikāya 1.1, paragraph N` + link `read/:segmentId`).
  **Không có citation từ DB → KHÔNG trả lời như kinh điển.**

#### 3. Sẽ làm (sau F/D/B/C)
- FTS5 thay LIKE (typo-tolerant, nhanh) — yêu cầu SQLite build có FTS5.
- Ngôn ngữ nguồn thêm: Miến, Thái (schema đã để chỗ đa ngôn ngữ).
- Nối Reader tipitaka với tab Đọc (mở đoạn kinh trong TextProvider).

#### 4. Cấm / ràng buộc
- Không trả lời giáo pháp tùy tiện — AI layer phải có trích dẫn.
- Tôn trọng giấy phép OpenTipiṭaka / Pa-Auk khi đóng gói data.
- Không commit DB 500MB vào `assets/` (production) — chỉ bản DEMO 1.69MB
  được phép bundle; file nguồn tải từ
  `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database`
  (server chỉ cho browser — sandbox TLS bị chặn, tải bằng trình duyệt).

#### 5. Mở nhánh mới để giao việc
- Branch mới **từ tip DEV** (`arena/01a0251e-in4up`). Code module đã có
  sẵn trong DEV (`18813d6`) — KHÔNG copy lại từ workspace 019ff2f6.
- Prompt topic: trỏ vào `docs/Bangiao/bangiao_tipitaka.md` + "chọn bước
  F/D/B/C duy nhất" + quy trình harvest/CI như PLAN-020 mục 5.
- Nghiệm thu: Home → ⚡ → Tipiṭaka → Library → Reader; DB thiếu →
  `python scripts\import_tipitaka.py`.

- **Lịch sử:**
  - 2026-09-03 | created | owner via session arena/019ff2f6-in4up | module
    tipitaka + DB DEMO + quick-action; bàn giao qua
    docs/Bangiao/bangiao_tipitaka.md (commit 5374214)
  - 2026-09-03 | doing | agent arena/01a0251e-in4up | module đã nằm trong
    DEV từ 18813d6; PLAN-021 ghi rõ đã làm/phải làm/sẽ làm cho các
    branch tiếp theo

### PLAN-022 — Sherpa WP2/WP3: nối tiếp speaker waveform + voice commands
- **Nguồn:** owner (2026-09-03), session `arena/01a039e9-in4up`; code đã
  thâu hoạch vào DEV (KANBAN `SHERPA-WP23-01`: cherry-pick `-x` 4cdaffb
  → 01f5235 + fix scope 8c2e868; CI xanh 33336160268).
- **Trạng thái:** code done + CI xanh — **chờ nghiệm thu thiết bị**; các
  việc còn lại làm trên **nhánh mới từ tip DEV**.
- **Tài liệu bàn giao (BẮT BUỘC đọc):** `docs/Bangiao/bangiao_sherpa.md`
  (prompt handoff WP3: nhiệm vụ, bẫy không được lặp lại, checklist báo
  cáo), PLAN-008/009 (lộ trình sherpa/cabin), `lib/features/vad/README_VAD_TTS_STREAMING.md`,
  KANBAN SHERPA-001/002/003 + SHERPA-WP23-01.

#### 1. Đã làm (đang chạy trong DEV)
- **SHERPA-001:** Silero VAD (sherpa_onnx) thay EnergyVad fallback
  (4a50a77 + cd9cccf).
- **SHERPA-002:** TTS Piper offline (sherpa_onnx): core + engine trong
  TtsService (CI 32524455212; model push vào thiết bị của owner).
- **SHERPA-003:** VAD pipeline 30p: cắt chunk FFmpegKit (Android) +
  quét async + guard (43c3545, CI 32617775840).
- **SHERPA-WP23-01 — WP2:** parse timestamp LRC khi load →
  `WaveformSegmentRef` + `SpeakerSidecar.loadSpeakerMap` (sidecar `.spk`
  cạnh LRC — offline overlay, không re-run STT) → waveform tô màu theo
  speaker + legend "Người N"; file cũ fallback mono.
- **SHERPA-WP23-01 — WP3:** `lib/features/voice_command/` — parser thuần
  8 nhóm lệnh VI/EN (+ không dấu): phát/tạm dừng/tiếp theo/bài trước/
  nhanh hơn/chậm hơn/ẩn lời/dịch; `VoiceCommandService` dùng DUY NHẤT
  `SttServiceFacade.startListening()` + `partialResultStream`, một mic
  session, first-match debounce, silence 1.5s/max 6s; UI mic button +
  indicator + partial preview trên Stack waveform tab Nghe; i18n
  en/vi/hi/zh/zh_TW/si.
- **Fix scope (8c2e868):** nút voice không đặt trong StatelessWidget
  độc lập dùng state màn hình; khôi phục nút Shadowing gốc.

#### 2. Phải làm (nghiệm thu thiết bị trước khi code tiếp)
- Lệnh giọng nói: "phát/tạm dừng/tiếp theo/nhanh hơn/chậm hơn/ẩn lời"
  trên audio có LRC; thiếu model STT phải hiện "No speech model
  available" (không crash, không im lặng).
- WP2: waveform nhiều speaker cần audio đã qua STT pipeline (sidecar
  `.spk` tạo tự động) — kiểm tra file cũ không sidecar không crash.
- SHERPA-002: build + push model Piper vào thiết bị, nghiệm thu TTS.

#### 3. Sẽ làm (nhánh mới, sau khi nghiệm thu xanh)
- **WP3 action `translate`:** nối lệnh "dịch" vào provider toggle
  translation — CHỈ nối sau khi owner xác nhận API; không giả lập
  hành vi (known limitation bàn giao).
- **WP-Z (có thể không làm):** sidecar desktop `yt-dlp` khi explode gãy
  — chỉ khi user đã cài, không binary trong APK, không chạy trong CI.
- Meetily Rust/Zipformer: KHÔNG chờ — pipeline hiện dùng
  `SttServiceFacade`; nếu có sẽ là engine bổ sung, không thay kiến trúc.
- Diarization heuristic nâng cấp (sidecar chất lượng hơn) khi có model
  thật (pyannote v.v.) — thay `HeuristicDiarizationService`.

#### 4. Cấm / bẫy (từ bàn giao — không được lặp lại)
- Không khai báo trùng `_voiceCommandService`, `_voiceListening`,
  `_lastVoiceText`, `_startVoiceCommands` — tất cả field/method nằm
  trong `_ListenModeScreenState`.
- Không chèn snippet vào file bằng mắt khi đã có conflict — kiểm tra
  `git diff`.
- Không sửa `.github/workflows/`; docs bị ignore thì `git add -f`.
- Không bịa URL/model Zipformer; không auto-download model.
- Một phiên voice chỉ fire command đầu tiên; dispose
  subscription/timer/mic sạch.
- CI là oracle (skill `docs/skills/ci-red-debugging/SKILL.md`); chạm
  path app để paths-filter trigger đúng workflow.

#### 5. Mở nhánh mới để giao việc
- Branch mới **từ tip DEV**; code WP2/WP3 đã có sẵn trong DEV —
  KHÔNG cherry-pick lại từ 01a039e9.
- Prompt topic: trỏ `docs/Bangiao/bangiao_sherpa.md` + mục 3 PLAN-022
  (chọn 1 việc duy nhất) + checklist báo cáo "WP DONE" trong file bàn giao.

- **Lịch sử:**
  - 2026-09-03 | created | owner via session arena/01a039e9-in4up |
    bàn giao WP2/WP3 (docs/Bangiao/bangiao_sherpa.md, commit 5374214)
  - 2026-09-03 | doing | agent arena/01a0251e-in4up | PLAN-022 ghi rõ
    đã làm/phải làm/sẽ làm + bẫy; chờ nghiệm thu thiết bị trước khi
    mở nhánh code tiếp
