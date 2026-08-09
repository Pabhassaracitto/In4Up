# DICTIONARY_SPEC — Hybrid Dictionary (Tham chiếu) + ML Kit + Gemma

> **Trạng thái:** Spec cho Branch B (agent khác) triển khai  
> **Branch A (arena/019fe7ba)** đã làm: Repository Pattern + Canon FTS PoC (`.md` + Hive FTS).  
> **Branch B** làm tiếp: Mở rộng `OfflineDictionary` 500 từ → 10-20k thuật ngữ Phật học + 2 engine offline (ML Kit & Gemma).  
> **Tiêu chí:** Ngon (chính xác Phật học) - Bổ (có AI fallback) - Rẻ (0đ server) - Offline (100%) - Có Tham Chiếu (kèm nguồn)

---

## 1) Mục tiêu

Thay thế `OfflineEngine` 1 dòng hiện tại (tra từng từ, không có ngữ cảnh) bằng hybrid 3 tầng:

```
Text cần dịch
  ↓
[1] Dictionary FTS exact → nếu hit 100% → trả ngay kèm chú thích + nguồn (canon id / glossary id) — 0-5ms
  ↓ miss
[2] ML Kit Offline Translation → dịch thường, offline, chất lượng cao — 50-100ms
  ↓ chưa tải model / không hỗ trợ cặp ngôn ngữ
[3] Gemma 2B (in2up_ai đã có) → prompt nhúng glossary → dịch có giữ thuật ngữ + giải thích — 2-5s (chỉ khi model đã load)
  ↓ all miss
[4] OfflineEngine cũ (fallback cuối, giữ nguyên) — từng từ
```

Tất cả kết quả đi qua `TranslationCache` (LRU 500) như cũ.

---

## 2) Tại sao không làm y như Gemini (Isar + MarianMT ONNX 30-50MB)?

| Gemini đề xuất | Vấn đề thực tế với VipSound | Sửa lại trong spec này |
|---|---|---|
| `Isar` | Isar archive 11/2023, không còn maintain. | Dùng `Drift (SQLite FTS5)` — cùng họ với Canon FTS vừa làm, đã có tokenizer bỏ dấu. Hoặc `Hive` tạm rồi migrate Drift sau (đừng dùng Isar). |
| `MarianMT ONNX 30-50MB bundle vào APK` | Thêm 40MB cố định + `sentencepiece` + phải build `onnxruntime` cho Windows, lại chạy cùng Gemma 2B → RAM >2GB, APK >200MB. Chất lượng `opus-mt-en-vi` quant kém hơn ML Kit, Pali không có model. | **ML Kit Offline** 11MB/cặp ngôn ngữ, tải động như `AiModelLoader` (đã có 3 tầng), chất lượng production. Nếu bắt buộc không GMS thì mới dùng MarianMT nhưng cũng phải tải động, không bundle. |
| Bundle model | APK phình | Tải động khi user bấm "Tải bộ dịch offline" — như Whisper/Gemma hiện tại. |

**Kết luận:** Giữ ý hybrid của Gemini, sửa stack thành `Drift FTS + ML Kit + Gemma` — rẻ hơn, nhẹ hơn, tận dụng code đã có.

---

## 3) Dữ liệu

### 3.1 Nguồn thuật ngữ (10-20k entries, ~12MB)

- `assets/canon/*.md` đã có (3 bài mẫu) — extract bảng `Pali - Việt` tự động.
- Thêm file glossary: `assets/dictionary/glossary_phathoc.csv` hoặc `.json`:
  ```csv
  term,translation,pali,han,context,priority,source
  dukkha,khổ,dukkha,苦,Khổ đế - Tứ Diệu Đế,10,mn10
  satipatthana,niệm xứ,satipaṭṭhāna,念处,Tứ Niệm Xứ,10,mn10
  anicca,vô thường,anicca,無常,Tam pháp ấn,10,dhammapada_001
  mindfulness,chánh niệm,sati,正念,Bát Chánh Đạo,9,mn10
  ```
- Tuệ: Ưu tiên `priority 10` (thuật ngữ cốt lõi) →  `exact match` ưu tiên hơn.

### 3.2 Schema Drift (gợi ý — Branch B điền)

```sql
-- Bảng chính
CREATE TABLE dict_entries (
  id TEXT PRIMARY KEY,
  term TEXT NOT NULL,          -- "mindfulness"
  term_norm TEXT NOT NULL,     -- "mindfulness" lower + strip dấu để exact
  translation TEXT NOT NULL,   -- "chánh niệm"
  pali TEXT,                   -- "sati"
  han TEXT,                    -- "正念"
  context TEXT,                -- "Bát Chánh Đạo"
  source TEXT,                 -- "mn10_satipatthana / glossary"
  priority INTEGER DEFAULT 5,  -- 10 = core, 5 = thường
  updated_at TEXT
);

-- FTS5 cho prefix/fuzzy
CREATE VIRTUAL TABLE dict_fts USING fts5(
  term, translation, pali, context,
  content='dict_entries', content_rowid='rowid',
  tokenize='porter unicode61 "remove_diacritics 1"'
);

-- Trigger giữ sync (Drift tự sinh)
```

Nếu chưa muốn thêm `drift` ngay, Branch B có thể tạm dùng **Hive box `dict_entries` + inverted index** y hệt `canon_fts_service.dart` (copy tokenizer `canon_tokenizer.dart` — đã bỏ dấu TV/Pali).

### 3.3 Import pipeline

```dart
// assets/dictionary/glossary_phathoc.csv → Drift/Hive
// + tự extract từ assets/canon/*.md (bảng | Pali | Việt |) → dict_entries
// Chạy 1 lần khi install / khi update assets
await DictionaryLoader.importFromAssets();
```

---

## 4) File structure

```
lib/features/translation/
  DICTIONARY_SPEC.md          // <- file này (copy vào docs/DICTIONARY_SPEC.md)
  data/
    offline_dictionary.dart   // cũ, giữ lại cho fallback
    dictionary_loader.dart    // NEW (Branch B): import csv/md → Drift
  engines/
    translation_engine.dart   // interface (đã có)
    dictionary_engine.dart    // NEW STUB (Branch B điền) — Tier 1
    mlkit_engine.dart         // NEW STUB (Branch B điền) — Tier 2
    gemma_translation_engine.dart // NEW STUB (Branch B điền) — Tier 3, wrapper AiServiceFacade
    offline_engine.dart       // cũ, fallback cuối
  translation_service.dart    // sửa _initEngines() để chèn 3 engine mới

assets/dictionary/
  glossary_phathoc.csv        // NEW (Branch B tạo, 10k dòng mẫu 100 dòng trước)
```

---

## 5) Engine contracts (Branch B implement)

### 5.1 `DictionaryEngine` — Tier 1 (bắt buộc)

```dart
class DictionaryEngine implements TranslationEngine {
  @override String get name => 'Phật Học Từ Điển'; // hiển thị UI
  @override String get id => 'dictionary';
  
  // Trả về TranslationResult với:
  // - translatedText: bản dịch
  // - engineName: 'dictionary'
  // - kèm metadata để UI hiện "Tham chiếu: MN 10 • pali: satipaṭṭhāna"
  // Nếu miss → return failure (để TranslationService fallback)
}
```

**Yêu cầu:**
- `translate("satipatthana")` → `Tứ Niệm Xứ` (exact, 0ms)
- `translate("mindfulness")` → `chánh niệm (sati)` (exact)
- `translate("dukkha is ...")` → nếu câu chứa thuật ngữ, highlight hoặc dịch từng thuật ngữ trong câu giữ nguyên cấu trúc (gợi ý: thay thế token trước khi gọi Tier 2)
- `lookupWithSource(term)` trả thêm `DictHit { translation, pali, source, snippet }` để UI hiện chú thích .

### 5.2 `MlKitEngine` — Tier 2 (khuyên dùng)

```dart
class MlKitEngine implements TranslationEngine {
  @override String get name => 'ML Kit Offline';
  @override Future<bool> isAvailable() // check model đã tải chưa
  Future<void> downloadModelIfNeeded(String source, String target) // tải động
}
```

- Thêm `google_mlkit_translation: ^0.13.0` vào `pubspec.yaml` (Branch B tự thêm)
- Model tải động, không bundle. UI hiện "Chưa tải • Bấm để tải 11MB".
- Hỗ trợ `en↔vi`, `en↔fr`, `en↔ja`... Pali không hỗ trợ → sẽ tự fallback Tier 3.

### 5.3 `GemmaTranslationEngine` — Tier 3 (wrapper)

```dart
class GemmaTranslationEngine implements TranslationEngine {
  GemmaTranslationEngine(this._facade);
  final AiServiceFacade _facade; // đã có trong in2up_ai
  // Chỉ chạy khi _facade.state == ready
  // Prompt mẫu: "Dịch sang tiếng Việt, giữ nguyên thuật ngữ Phật học: {glossary}. Text: {input}"
}
```

- Tận dụng `AiServiceFacade` đã có (đừng tạo Isolate mới).
- Chỉ dùng khi user đã import model Gemma (check `hasModel`), không tự download.

---

## 6) Tích hợp `TranslationService`

Sửa `lib/features/translation/translation_service.dart`:

```dart
void _initEngines() {
  _engines.clear();
  // --- OFFLINE HYBRID (ưu tiên) ---
  _engines.add(DictionaryEngine()); // Tier 1 — luôn available
  if (await MlKitEngine().isAvailable()) _engines.add(MlKitEngine()); // Tier 2
  if (AiServiceFacade().hasModel) _engines.add(GemmaTranslationEngine(...)); // Tier 3

  // --- ONLINE (giữ nguyên) ---
  if (_deeplxUrl != null) _engines.add(DeepLXEngine(...));
  _engines.add(GoogleFreeEngine());
  _engines.add(MyMemoryEngine());
  _engines.add(LibreEngine());
  // OfflineEngine cũ để cuối cùng làm fallback từng từ
}
```

Hoặc tách rõ: khi `hasNetwork == false` chỉ chạy 3 tier offline, khi `hasNetwork == true` vẫn thử online trước rồi mới offline.

---

## 7) Checklist cho Branch B (copy paste làm)

- [ ] Tạo `assets/dictionary/glossary_phathoc.csv` (100 dòng mẫu trước, commit)
- [ ] Viết `lib/features/translation/data/dictionary_loader.dart` (import csv + extract từ canon .md)
- [ ] Implement `DictionaryEngine` từ stub (exact + FTS prefix, kèm `source`)
- [ ] Thêm `google_mlkit_translation` vào `pubspec.yaml` + implement `MlKitEngine` (download động)
- [ ] Implement `GemmaTranslationEngine` wrapper `AiServiceFacade`
- [ ] Sửa `TranslationService._initEngines()` + `translateText()` để log `lastUsedEngine = dictionary|mlkit|gemma`
- [ ] Thêm UI nhỏ ở `TranslationToolbar`: badge "📖 Từ điển • ML Kit • Gemma"
- [ ] Viết test: `dictionary_engine_test.dart` — `expect(await DictionaryEngine().translate(text:"satipatthana", targetLang:"vi")).translatedText == "niệm xứ"`

---

## 8) Test thủ công (không cần mạng)

- `satipatthana` → `niệm xứ (Tứ Niệm Xứ - MN 10)` — Tier 1 hit
- `mindfulness` → `chánh niệm` — Tier 1 hit
- `dukkha` (không dấu `dukkha`) → `khổ` — test `stripDiacritics`
- `The nature of dukkha` → `Bản chất của khổ` — Tier 1 thay token + Tier 2 dịch phần còn lại
- Không có mạng, chưa tải ML Kit → vẫn ra Tier 1 hoặc fallback OfflineEngine
- Có mạng → online engines vẫn chạy như cũ, không vỡ

---

## 9) Ngân sách

- APK gốc: không tăng (glossary tải động)
- Sau khi user tải: Dict ~12MB + ML Kit 11MB/cặp + Gemma 1.2GB (nếu đã có thì 0 thêm)
- RAM: Dict ~20MB, ML Kit ~50MB, Gemma 1.5GB (chỉ khi đang dịch tier 3)

---

## 10) Ghi chú Isar vs Drift

Đừng dùng `isar` (archive). Dùng `drift` + `sqlite3_flutter_libs` hoặc tạm `hive` như `canon_fts_service.dart`. Code tokenizer `canon_tokenizer.dart` đã bỏ dấu Pali/Việt sẵn, Branch B copy lại là xong.

---

## 11) Tham chiếu

- Branch A đã xong: FTS canon (`.md` + tokenizer + inverted index) — Branch B copy pattern.
- File stub: `lib/features/translation/engines/dictionary_engine.dart` đã tạo sẵn TODO, Branch B chỉ việc điền.
- Liên hệ: Branch A (arena/019fe7ba) giữ `Repository Pattern` + `Canon FTS`, Branch B làm Dictionary Hybrid, không đụng file nhau (tránh conflict).

> Sau khi Branch B xong, 2 branch merge vào `main` qua PR, QA: test offline 100% với 3 câu Pali mẫu trong `assets/canon/`.
