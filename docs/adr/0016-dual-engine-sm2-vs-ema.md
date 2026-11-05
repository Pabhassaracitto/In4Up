# ADR-0016: Hai engine tách bạch — SM-2 (lịch ôn) vs EMA (Mastery Vector)

- **Ngày:** 2026-11-03
- **Trạng thái:** PROPOSED (chờ owner xác nhận)
- **Phạm vi:** `SM2Algorithm`, `SkillReviewData`, Mastery Vector (mới), `ReviewEvent`.

## Bối cảnh

Hiện tại SM-2 vừa quyết định **lịch ôn** vừa (trực tiếp hoặc gián tiếp) ảnh hưởng **điểm mastery**.
Owner muốn tách rõ hai vai trò:
- **SM-2** chỉ quyết định **khi nào ôn** (interval, easeFactor) — tiêu thụ `q` nguyên 0–5.
- **Mastery Vector** (hiện trị) mới quyết định **trình độ hiện tại** — cập nhật bởi EMA.

## Quyết định

### 1. Hai engine tách bạch

- **SM-2:** chỉ tính lịch ôn (`interval, repetitions, easeFactor, nextReview`) từ `q` nguyên.
- **EMA (Exponential Moving Average):** chỉ cập nhật Mastery Vector (score ∈ [0,1]) từ `scoreNor = q/5`.
- Một event review vừa ghi `ReviewEvent` (cho SM-2) vừa cập nhật Mastery Vector (cho EMA).

### 2. Patch A′ (bất đối xứng theo chiều)

```
wasCorrect = q >= 3
gate       = wasCorrect ? (1.0 - evidence.assistance) : 1.0
alphaE     = alpha * evidence.confidence * gate
mastery    = mastery + alphaE * (scoreNor - mastery)
```

- Nếu đúng → assistance (mức độ gợi ý) làm **giảm** mức cập nhật (người được gợi nhiều không tăng mastery nhiều).
- Nếu sai → gate = 1 (giữ nguyên cường độ, không bị assistance giảm).
- `confidence` (độ tin cậy bằng chứng) điều chỉnh alpha.

### 3. Unit test bắt buộc

1. clozeChoice đúng, assistance 0.75 → |Δ| ≈ 0.25·α.
2. Sai, assistance 0.75 → |Δ| đủ cường độ α (gate=1).
3. confidence 0.2 → cả hai chiều gần đứng yên.

## Hệ quả

- (+) SM-2 và mastery không bị chèn nhau; ADR-0001 (1 hàm SM-2 duy nhất) vẫn giữ.
- (+) Assistant/confidence được tính đúng, không làm sai mastery.
- (−) Cần evidence metadata (assistance, confidence) — xem ADR-0017.

## Kiểm thử

- 3 unit test chống hồi quy ở trên.
- Test SM-2 unchanged (ADR-0001 regression).
