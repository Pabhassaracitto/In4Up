# ADR-0020: Migration append-only + Session Bundler

- **Ngày:** 2026-11-03
- **Trạng thái:** PROPOSED (sau spike Hive P0)
- **Phạm vi:** `SkillKind`, `ReviewEvent`, `LearningState`, Hive box, Session Bundler.

## Bối cảnh

- Mở rộng 3 kỹ năng input → 6 trục (ADR-0015). Cần migration **additive, không mất dữ liệu**.
- Owner muốn gom các skill đến hạn của cùng 1 từ thành **1 thẻ** (Session Bundler).

## Quyết định

### 1. Migration append-only (audit-fixed)

- **ReviewEvent lưu theo NAME (string)**, không phải ordinal:
  `ReviewEvent.toJson` ghi `skill.name`; `fromJson` dùng `SkillDimension.values.firstWhere((s) => s.name == ...)`.
  → Append `use/speak/write` **an toàn** (dữ liệu cũ parse bình thường).
  Chứng cứ: `lib/knowledge/models/review_event.dart:86,99`.
- **LearningState hiện có 5 field** (unitId, understanding, listening, reading, lastReviewEventId).
  Thêm **3 field output snapshot mới** (use, speak, write) là **thêm field**, không dùng "fields 7–9".
  Chứng cứ: `lib/knowledge/models/learning_state.dart:102–110`.
- **Hive dùng string box** (`Hive.openBox<String>`, `lib/main.dart:123`), không có `@HiveType`/`registerAdapter`.
  → Migration dựa **JSON serialization + string box**, **không dùng typeId** (không có hệ typeId trong repo).

### 2. Session Bundler

- Gom các skill đến hạn của cùng 1 từ thành **1 thẻ**.
- DoD: độ dài phiên ≤ +20% baseline; vượt → rollback flag.

### 3. Feature flag `hexagon_v1`

- **[P0]** xác định mechanism (không có `FeatureFlag` class trong repo).
- Venn và Triangle cũ chạy song song.

## Hệ quả

- (+) Dữ liệu cũ không mất; append an toàn.
- (+) Session Bundler rút gọn phiên ôn.
- (−) Cần spike Hive P0 xác nhận mechanism.

## Kiểm thử

- Unit test migration old→new zero loss.
- Unit test Session Bundler ≤ +20%.
- Hive roundtrip test.
