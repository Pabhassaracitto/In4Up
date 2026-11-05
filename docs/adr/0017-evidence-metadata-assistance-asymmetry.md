# ADR-0017: EvidenceMetadata + assistance asymmetry (patch A′)

- **Ngày:** 2026-11-03
- **Trạng thái:** PROPOSED (chờ owner xác nhận)
- **Phạm vi:** `EvidenceMetadata` (mới), `ReviewEvent` (thêm metadata), Mastery Vector.

## Bối cảnh

Mastery Vector cần biết **bằng chứng** dùng để tính điểm:
- `assistance` (mức độ gợi ý người học) — để bất đối xứng đúng/sai.
- `confidence` (độ tin cậy bằng chứng) — để điều chỉnh alpha.
- `gradedBy` (engine + version) — để EMA online/offline không so sánh sai.

## Quyết định

### 1. EvidenceMetadata (additive)

- Thêm `EvidenceMetadata { assistance: double, confidence: double, gradedBy: String }`.
- Gắn vào mỗi event review. Không thay đổi `ReviewEvent` cũ (additive field).

### 2. Assistance asymmetry

- Đúng (q ≥ 3): `gate = 1 - assistance` → assistance cao = tăng mastery ít.
- Sai (q < 3): `gate = 1` → không bị assistance làm giảm.

### 3. gradedBy

- `gradedBy = "<engine>/<version>"` (vd: `"local-cloze/v1"`, `"ai-sentence/v2"`).
- Lưu để biết điểm có so sánh được giữa online/offline hay không.

## Hệ quả

- (+) Mastery Vector phản ánh đúng chất lượng bằng chứng.
- (+) EMA online/offline so sánh được.
- (−) Cần trải nghiệm ghi assistance/confidence ở mỗi task.

## Kiểm thử

- Unit test patch A′ (3 case ở ADR-0016).
- Unit test gradedBy tách biệt giữa engine online/offline.
