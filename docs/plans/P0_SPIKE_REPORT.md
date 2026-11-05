# P0 Spike Report — Vocab Mastery (2026-11-03)

**Trạng thái:** Spike hoàn tất (agent-only, không test 3 người — theo owner).
**Mục đích:** đóng 3 giả định mở + xác định flag mechanism → để Lock spec.

## 1. Tái xác minh 3 symbol (A.1.1) — ĐÂY LÀ CĂN CỨ

| Symbol | Kết quả | Chứng cứ |
|---|---|---|
| `PronunciationService.analyze({originalText, recognizedText})` | **Arbitrary string** — chia theo từ + Jaro-Winkler + phoneme | `lib/features/shadowing/services/pronunciation_service.dart` |
| `_scoreDictation` | **Generic target** — so sánh `assignment.sourceText` vs input | `lib/screens/read_mode/write_studio_screen.dart:417` |
| `grammar_lexicon_service` inflection | Rule-based: plural/3sg, past/pp, comparative/superlative, gerund | `lib/features/grammar/services/grammar_lexicon_service.dart:106` |

→ **Nói/Viết/Dùng adapter khả thi** (word-scoped), không cần đụng `ShadowingLine`/Write Studio line.

## 2. Serialization + Hive

- **ReviewEvent:** lưu theo **name (string)** — `toJson` ghi `skill.name`, `fromJson` dùng `firstWhere(s.name == ...)`. Append `use/speak/write` an toàn. `lib/knowledge/models/review_event.dart:86,99`.
- **Hive:** `Hive.openBox<String>` (string box), **không có** `@HiveType`/`registerAdapter`/typeId. `lib/main.dart:123`.
- → **Migration dựa JSON + string box**, không dùng typeId.

## 3. Feature flag mechanism

- **KHÔNG có** `FeatureFlag` class trung tâm.
- Settings dùng `shared_preferences` rải rác (grammar, tts, translation, vocab_image...).
- → **Flag `hexagon_v1`**: thêm **1 key bool + helper nhỏ** (`FeatureFlags` hoặc dùng pattern `shared_preferences` hiện có). **Không cần hệ thống flag lớn.**

## 4. Home settings (vị trí network setting)

- Có `shell_ui_settings_screen.dart` + `ai_providers_screen.dart` + `stt_model_settings_screen.dart`.
- → Network toggle (Always online / Always offline / Auto) ghép vào **settings** (không cần Home-specific).

## 5. Inflection rules (list)

- `plural_or_3sg` (ies→y, es→, s→)
- `past_or_participle` (ed→)
- `gerund_or_participle` (ing→)
- `comparative` / `superlative` (er/est→)
- **KHÔNG có paradigm đầy đủ** (go/went/gone) — irregular cần nguồn Phase 2.

## 6. Prototype 2 màn (Word/Collection)

- **Chưa làm** — owner quyết không test 3 người. → D9 đã quyết (cả 2 view + toggle), painter code ở P3.

## 7. Kết luận

- **3 giả định mở đã đóng.** Không có gì **DỪNG**.
- **Spec có thể Lock** sau khi owner confirm D10/D11/ADR-0021 (đã nhận: D10 ✓, ADR-0021 simplified).
- **P0 spike pass.**
