# ADR-0021: Network policy — Settings + cheap/expensive (simplified, KHÔNG phân loại model)

- **Ngày:** 2026-11-03
- **Trạng thái:** ĐÃ XÁC NHẬN (owner) — SIMPLIFIED
- **Phạm vi:** Settings (shell), engine routing, task policy.

## Bối cảnh

Owner: app **không còn offline-first tuyệt đối** → linh hoạt + user choice.
Mẫu tốt: PDF reader — offline dictionary khi chưa kết nối, online load khi có mạng.

Owner **đánh dấu**:
1. Tinh chỉnh mạng ở **Settings** (vốn có sẵn).
2. **KHÔNG cần phân loại model rẻ/đắt** — model hiện tại chủ yếu free.
3. Đừng vì offline-first mà mất trải nghiệm đắt giá; nhưng đừng để mất data gói cước ở audio/hình ảnh.

## Quyết định

### 1. Phân loại op (chỉ 2 loại, KHÔNG phân loại model)

| Loại op | Ví dụ | Default |
|---|---|---|
| **cheap** | Tra từ, dịch, IPA, cloze, inflection, lookup | online |
| **expensive** | DSP, TTS neural, shadowing scoring, OCR, xử lý hình ảnh | user-gate (offline/cache) |

- **KHÔNG có tier "model rẻ/đắt"** — model hiện tại chủ yếu free, chưa cần layer classification.

### 2. Network toggle ở Settings

- **Always online / Always offline / Auto** (3 chế độ) ở Settings.
- **Auto:** cheap → online; expensive → user-gate (offline/cache); offline khi mất mạng.

### 3. Local-first cho task tất định

- inflection/cloze chấm cục bộ (1ms) → **local-first**. Online chỉ làm giàu dữ liệu.

### 4. gradedBy

- `gradedBy` (engine + version) lưu trong EvidenceMetadata → EMA online/offline không so sánh sai.

### 5. Defer tới Phase 2

- **`dataLeavesDevice`**: defer — Phase 1 chưa cần (chưa có AI grading).
  **D11 resolution:** không build consent layer mới. App **đã có** `ai_providers_screen.dart`
  (user chọn local llama.cpp vs remote server API) — đó là control "data leaves device" hiện có.
  Phase 2 AI grading **tái dùng pattern này**.
- **AI sentence grading**: Phase 2, premium, cần consent.

### 6. Không tải model nặng lúc bootstrap

- Giữ nguyên rule hiện tại.

## Hệ quả

- (+) Linh hoạt theo kết nối + user override (Settings).
- (+) Bảo vệ data gói cước ở expensive ops.
- (+) Đơn giản — không over-engineer network layer.
- (−) Cross-cutting — Settings UI cần thêm toggle.

## Kiểm thử

- Unit test policy: cheap online; expensive user-gate; offline fallback.
- Unit test local-first cho task tất định.
