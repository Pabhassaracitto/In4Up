# ICONIZE-001 — BLUEPRINT CHÍNH THỨC v2.1-FINAL (đã hiệu đính repo-audit)

Hệ thống học từ vựng qua Ngữ cảnh Thị giác — "Direct Visual Anchoring Loop"

- **Trạng thái:** ✅ Hội đồng đa AI thông qua (94.2/100, 5 vòng) → **đã audit
  đối chiếu repo** bởi agent ngày 2026-10-07 → chờ owner duyệt ADR.
- **Hội đồng:** MAX (điều phối) · Claude (Kiến trúc) · ChatGPT (Học thuật) ·
  Gemini (Dữ liệu) · Grok (Phản biện đỏ).
- **ADR đi kèm:** `docs/adr/0013-iconize-visual-context.md` (Proposed).
- **Card KANBAN:** `ICONIZE-001` (📋 proposed, 8 lane a–h).
- **Prompt gốc của hội đồng:** `PROMPT_HOIDONG_ICONIZE_VISUAL_CONTEXT.md` (gốc repo).

---

## 0. HIỆU ĐÍNH REPO-AUDIT (đọc trước — 4 chỗ bản hội đồng lệch sự thật code)

Bản hội đồng viết rất khớp repo, nhưng audit cuối phát hiện 4 điểm phải sửa.
**Văn bản từ mục 1 trở xuống ĐÃ áp dụng các hiệu đính này.**

| # | Hội đồng viết | Sự thật trong repo | Hiệu đính |
|---|---|---|---|
| 1 | "ADR-027" | `docs/adr/` đang ở 0001–0011 | Số ADR là **0012** |
| 2 | `enum ReviewGrade { again, hard, good, easy }` | SM-2 canonical nhận `quality` **int 0..5** (`lib/models/sm2_algorithm.dart`, ADR-0001); FSRS có model riêng trong `lib/features/learn_by_heart/models/fsrs_models.dart` | Không tạo enum mới ở tầng chấm điểm; Smart Cloze map kết quả → `quality`: Again=1, Hard=3, Good=4, Easy=5 (xem 6.5). Với hàng đợi FSRS (Thuộc Lòng) dùng đúng Rating của `fsrs_models.dart` |
| 3 | "VisibilityDetector (đã có pattern tương tự trong pdf_reader)" | pdf_reader có virtualized rendering tự chế, nhưng package `visibility_detector` **chưa có** trong `pubspec.yaml` | Card ICONIZE-001d phải thêm dependency (hoặc tái dùng cơ chế virtualization sẵn có của pdf_reader — quyết định lúc code, ghi vào PR) |
| 4 | `suggestDefaultDensity(CefrLevel? userSelfRated)` | Repo chỉ có CEFR **mức từ** (tô màu Tab Đọc); chưa có "CEFR tự khai" của user | Thêm setting mới additive (SharedPreferences, nullable). Null → Medium, đúng như code hội đồng đã phòng sẵn |

Ghi chú thêm: "Model Centre" trong văn bản = cơ chế tải model/gói dữ liệu
on-demand sẵn có của app (như màn tải model STT/Piper — `stt_model_settings_screen.dart`,
`docs/project/MODELS.md`), không phải module mới.

---

## 1. Bối cảnh & nguyên tắc nền tảng

In4Up là studio học sâu offline-first, 7 chế độ học (Nghe·Nói·Xem·Đọc·Viết·Hiểu·Nhớ).
ICONIZE-001 bổ sung một lớp trải nghiệm xuyên suốt: **học từ vựng qua câu ví
dụ/bản dịch có chèn icon ngữ cảnh**, thay vì flashcard dịch nghĩa vòng qua tiếng Việt.

**7 nguyên tắc bất di bất dịch** (mọi PR code review đối chiếu về đây):

1. **Iconize là tầng trình bày (render-layer), ephemeral** — không bao giờ ghi
   vào `TranslationCache`; plain text luôn là nguồn sự thật cho
   search/copy/export/TTS.
2. **Pipeline bất biến:** `Glossary protect → Dịch → Glossary restore →
   [plain text = nguồn sự thật, được cache] → Iconize (on-the-fly tại render,
   cache riêng tầng UI) → Widget`.
3. **Không một chữ tiếng Việt nào xen vào chu trình ghi nhớ từ vựng** — icon
   hoặc chữ bản xứ trực tiếp, không qua L1.
4. **Icon là giàn giáo, phải rút dần** — điều khiển bởi dữ liệu ôn thật
   (SM-2/FSRS outcome), có nudge chủ động nếu user không tự rút (mục 6.4).
5. **An toàn trước, đẹp sau** — từ không chắc nghĩa (đa nghĩa, nhạy cảm văn
   hóa) → mặc định giữ chữ.
6. **A11y bắt buộc** — mọi icon có `Semantics(label: surfaceForm)`.
7. **Offline-first, miễn phí, giấy phép sạch** — Twemoji (CC-BY) + Material
   Symbols (Apache-2.0) + Brysbaert (CC0) + Tatoeba (CC-BY); **không dùng
   OpenMoji** (CC-BY-SA, rủi ro lây nhiễm ShareAlike).

---

## 2. Kiến trúc tổng thể

```
┌──────────────────────────────────────────────────────────────────────┐
│ TẦNG DỮ LIỆU TĨNH                                                     │
│ Core bundle (~2.1 MB, kèm app)       │ Model Centre pack (~8.5–9.5MB)│
│ - concreteness.bin (~85KB)           │ - tatoeba_vetted.db (~4-5MB)  │
│ - icon_index.bin (~120KB)            │   (35.000 câu, Filter 1-6)    │
│ - icons_bundle.bin (~1.8MB, 2.000)   │ - extended_icons_bundle.bin   │
│ - irregular_lemmas.json (~15KB)      │   (~4.5MB, 5.000 icon)        │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ mmap/Uint8List lúc khởi động; mọi file có
                            │ Magic Header 8-byte "ICNB0001" versioning
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│ IconizeEngine — pure function (lib/features/iconize/)                │
│ (text, lang, density, scope) → IconizeResult{plainText, spans[]}     │
│                                                                      │
│ 1. Tokenize+POS (tái dùng grammar_analysis_service)                  │
│ 2. Lemmatize (luật + irregular_lemmas.json)                          │
│ 3. Tra (lemma,POS) → concreteness + icon (binary search)             │
│ 4. Đọc ké kết quả sentence_structure_service nếu đã có sẵn           │
│    (tăng độ tin cậy subject/object, KHÔNG chạy phân tích mới)        │
│ 5. lang≠en → Bridge-to-English qua dictionary offline                │
│ 6. Cognitive-load guard: cắt theo density (18%/32%/48%)              │
│ 7. Fallback 4 tầng: user vocab_image > core bundle > CDN > giữ chữ   │
│ 8. Kiểm blacklist toàn cục + per-document override trước khi chốt    │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ lazy resolution theo viewport, LRU cache 200 kết quả
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│ UI LAYER                                                             │
│ - Toggle "Icon hóa" (translation_toolbar, pdf_page_translate_panel,  │
│   Tab Hiểu, Web reader) — long-press mở Density Slider popup         │
│ - RichText + WidgetSpan(Semantics-wrapped icon, SizedBox chiều cao)  │
│ - Word tap sheet: câu ví dụ thị giác + nút "Giữ chữ cho tài liệu này"│
│ - Tab Nhớ: Smart Cloze thị giác, hint ladder context-aware           │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Khối A — Iconize Engine

### 3.1 Data classes

```dart
// lib/features/iconize/models/iconize_span.dart

enum IconizeSource { userVocabImage, localTwemoji, cdnFallback, none }
enum IconizeDensity { low, medium, high }

const Map<IconizeDensity, int> maxIconPercentByDensity = {
  IconizeDensity.low: 18,
  IconizeDensity.medium: 32,
  IconizeDensity.high: 48,
};

class IconizeSpan {
  final int start;
  final int end;
  final String surfaceForm;    // "catches"
  final String lemma;          // "catch"
  final String pos;            // nhãn từ grammar_analysis_service
  final double concreteness;
  final String? iconAssetRef;
  final IconizeSource source;
  final bool isAmbiguous;
}

class IconizeResult {
  final String plainText;          // nguồn sự thật, không đổi
  final List<IconizeSpan> spans;   // rời rạc, sort theo start
  final IconizeDensity density;
  final int actualIconPercent;
}
```

### 3.2 API

```dart
abstract class IconizeEngine {
  /// Pure function — không state, không side-effect giữa 2 lần gọi.
  Future<IconizeResult> iconize(
    String plainText, {
    required String langCode,
    IconizeDensity density = IconizeDensity.medium,
    String? documentHash,       // để áp per-document override
  });
}
```

### 3.3 Gợi ý density mặc định theo CEFR tự khai

> [Hiệu đính #4] "CEFR tự khai" là **setting mới** (additive, SharedPreferences,
> nullable — ví dụ khóa `user_self_rated_cefr`), hỏi một lần không bắt buộc.
> Chưa khai → Medium.

```dart
IconizeDensity suggestDefaultDensity(CefrLevel? userSelfRated) {
  if (userSelfRated == null) return IconizeDensity.medium;
  if (userSelfRated.index <= CefrLevel.a2.index) return IconizeDensity.high;
  if (userSelfRated.index <= CefrLevel.b1.index) return IconizeDensity.medium;
  return IconizeDensity.low;
}
```

### 3.4 Lookup `(lemma, POS)` — giải quyết từ bất quy tắc/đa nghĩa

```dart
final key = '${lemma.toLowerCase()}|$posNormalized';
final entry = iconIndex.lookup(key); // O(log N) binary search
// Không khớp key chính xác → KHÔNG icon hóa, giữ chữ (an toàn hơn đoán)
// Nếu sentence_structure_service đã chạy sẵn cho câu này (Tab Đọc thường bật),
// đọc ké kết quả subject/object để tăng độ tin cậy phân giải nghĩa — không
// chạy phân tích cấu trúc câu riêng cho Iconize.
```

### 3.5 Bridge-to-English (ngôn ngữ không phải `en`)

```
Token tiếng đích → tra dictionary offline (lib/features/dictionary/)
  → nghĩa tiếng Anh → nếu TẤT CẢ nghĩa khả dĩ đồng thuận 1 icon → dùng
  → nếu dictionary mỏng / đa nghĩa không đồng thuận → giữ chữ
```

**Phạm vi hỗ trợ v1 (chốt trung thực, không khoe khả năng chưa có):**

| Ngôn ngữ | Mức hỗ trợ |
|---|---|
| `en`, `vi` | Full (mọi density, POS tagging đã mạnh) |
| `hi`, `si`, `zh`, `zh_TW` | Light-only, chỉ icon hóa khi confidence POS ≥ 0.85; badge "Beta" cạnh toggle |

Nâng cấp POS cho `hi`/`si` (model ONNX nhỏ qua Model Centre) → **roadmap v2,
ngoài phạm vi v1**.

### 3.6 Fallback 4 tầng chọn icon

```
User vocab_image đã gán? → dùng (cá nhân hóa, ưu tiên cao nhất)
  ↓ không có
Core bundle local (2.000 icon)? → dùng
  ↓ không có
CDN Material Symbols (chỉ khi online)? → dùng, cache lại local
  ↓ không có/offline
Giữ chữ (graceful degradation) — KHÔNG BAO GIỜ hiện ô vuông lỗi
```

### 3.7 Cognitive-load guard + Lazy resolution

```dart
// Cắt icon theo ngân sách density; nếu vượt, ưu tiên giữ icon cho từ MỚI
// (Stage 2-1), bỏ icon cho từ đã thuộc (Stage 0) trước.

// Lazy resolution: chỉ iconize câu đang NẰM TRONG VIEWPORT, prefetch ±1 viewport.
// - Mobile/Desktop: VisibilityDetector HOẶC tái dùng cơ chế virtualized
//   rendering sẵn có của pdf_reader.
//   [Hiệu đính #3] package visibility_detector CHƯA có trong pubspec.yaml —
//   nếu chọn nó, card ICONIZE-001d phải thêm dependency và nêu trong PR.
// - Web: VisibilityDetector không ổn định trên Flutter Web → dùng
//   IntersectionObserver qua package:web, implementation có điều kiện theo
//   platform (kIsWeb check), ghi rõ trong code comment tại sao tách nhánh.
// Pre-warm: lúc app idle sau splash, resolve trước 500 lemma tần suất cao nhất
// vào LRU cache tầng UI (< 50ms, chạy trên idle callback, không chặn UI thread).
```

### 3.8 Error handling khi binary asset hỏng

```dart
// Đọc Magic Header "ICNB0001" khi load mỗi file .bin lúc khởi động.
// Nếu mismatch hoặc file corrupt:
//   1. Log lỗi (không throw ra UI)
//   2. Disable Iconize cho TOÀN BỘ session hiện tại (không retry loop)
//   3. Hiện badge cảnh báo màu vàng cạnh toggle: "Iconize tạm tắt do lỗi dữ liệu"
//   4. Nút trong badge: "Tải lại gói học liệu" → trỏ về Model Centre
// Không bao giờ crash app vì icon lỗi.
```

### 3.9 Accessibility

```dart
WidgetSpan(
  child: Semantics(
    label: span.surfaceForm,
    excludeSemantics: true,
    child: SizedBox(
      height: fontSize * 1.2, // tránh vỡ layout Devanagari/Sinhala
      child: IconWidget(ref: span.iconAssetRef),
    ),
  ),
)
```

---

## 4. Khối B — Nút "Icon hóa" trong panel dịch

- **Vị trí:** `translation_toolbar.dart`, `pdf_page_translate_panel.dart`,
  panel dịch Tab Hiểu, Web reader.
- **Tương tác:** chạm = bật/tắt toggle; **long-press = mở Density Slider popup**
  (3 nấc Low/Medium/High), mặc định gợi ý theo CEFR tự khai (mục 3.3).
- **Trạng thái lưu:** per-surface, khóa `iconize_enabled_<surface_id>`, không global.
- **Toggle phụ "Iconize cả bản dịch":** mặc định **tắt** — icon mặc định chỉ
  hiện trên câu nguồn; bật thêm mới áp dụng Bridge-to-English cho bản dịch.
- **Nguyên tắc cứng:** Iconize chỉ nhận plain text **đã dịch xong +
  glossary-restore xong**, không bao giờ chạy trước/trong
  `TranslationService`/`protect_tokens.dart`, không ghi ngược vào cache tầng dịch.
- **Chạm icon:** tooltip hiện `surfaceForm` + phát âm (Piper TTS) + nút
  "Lưu từ này" (đổ vào `word_analysis_sheet.dart` có sẵn).
- **i18n rule #5:** mọi chuỗi chrome mới (nhãn toggle, badge Beta, badge lỗi,
  popup density…) đủ `en/hi/zh/zh_TW/si` ngay trong cùng PR.

---

## 5. Khối C — Câu ví dụ thị giác

### 5.1 Pipeline Quality Gate (6 tầng)

```
Tatoeba raw dump
  → F1: độ dài 4–10 từ
  → F2: chứa đúng (lemma,POS) đích, concreteness ≥ 4.0
  → F3: cấu trúc ngữ pháp CEFR A1–B1
  → F4: regex loại nội dung bạo lực/nhạy cảm
  → F5: ưu tiên upvote/rating cao
  → F6: Cultural Neutrality Score — loại câu gắn danh từ riêng văn hóa cụ thể
        (baseball, Thanksgiving...) trừ khi đó chính là lemma đích; ưu tiên
        phạm trù universal (động vật, hành động cơ thể, đồ vật sinh hoạt)
  → Output: ~35.000 câu → tatoeba_vetted.db (Model Centre, không bundle mặc định)
```

Thứ tự ưu tiên hiển thị câu: **ngữ cảnh user đã gặp từ trong bài đọc thật** →
`tatoeba_vetted.db` → từ điển MDX → LLM on-device (chỉ khi 3 nguồn trên trống,
qua quality gate trước khi dùng).

### 5.2 Schema additive trên `WordEntry`

```dart
final String? visualExample;        // "The cat catches the mouse."
final String? visualExampleSource;  // "tatoeba:12894" | "llm_ondevice" | "user_context"
final int visualScaffoldStage;      // 2=Heavy, 1=Medium, 0=Faded

// fromJson an toàn cho dữ liệu cũ (tiền lệ phoneticSource/imageUrl2):
visualScaffoldStage: json['visualScaffoldStage'] as int? ?? 2,
// toJson: chỉ ghi khi khác default — giữ file nhỏ, tương thích ngược.
```

Rà soát bắt buộc mọi serializer `WordEntry` trong `lib/services/` để field mới
không văng khi round-trip (test trong Khối F).

---

## 6. Khối D — Smart Cloze thị giác & Scaffolding

### 6.1 Rút giàn giáo dựa trên kết quả ôn thật

> [Hiệu đính #2] Không có `ReviewGrade` trong repo. Hàm nhận thẳng
> `quality` int 0..5 của SM-2 canonical (ADR-0001).

```dart
/// quality: 0..5 theo SM2Algorithm (lib/models/sm2_algorithm.dart)
int nextScaffoldStage(WordEntry w, int quality, int intervalDays) {
  if (quality <= 3) {                       // Again(≤2) hoặc Hard(3)
    return min(w.visualScaffoldStage + 1, 2);
  }
  // quality 4..5 (Good/Easy)
  if (w.last2ReviewsGoodOrBetter && intervalDays >= 7) {
    return max(w.visualScaffoldStage - 1, 0);
  }
  return w.visualScaffoldStage;
}
// User bật "Always iconize" → bỏ qua thuật toán, tôn trọng lựa chọn thủ công.
// Hàng đợi FSRS (Thuộc Lòng) dùng Rating của fsrs_models.dart, map tương đương.
```

### 6.2 Hint ladder context-aware

```dart
int hintTapsRequired(WordEntry w) {
  if (w.visualScaffoldStage == 0) return 1; // đã quen → mở sheet ngay
  if (w.visualScaffoldStage == 1) return 2;
  return 3; // từ mới/yếu → ladder đầy đủ
}
// Gesture vuốt lên trên icon = phát âm ngay, bất kể stage, không tính vào đếm chạm
```

Ladder 3 cấp (khi áp dụng đủ): chạm 1 = chữ mờ 30% → chạm 2 = chữ rõ + TTS →
chạm 3 = mở sheet đầy đủ + nút **"Icon này gây hiểu lầm"** (ghi vào blacklist
toàn cục, mục 6.3).

### 6.3 Blacklist toàn cục — đồng bộ qua kênh sẵn có

```
Lưu trong cùng Hive box với WordEntry metadata.
Key: "iconize_blacklist_<lang>_<lemma>_<pos>" → bool
Đồng bộ qua đúng cơ chế cloud opt-in (BYOK) hiện có của Memory Garden —
KHÔNG xây kênh sync riêng.
```

### 6.4 Nudge chủ động rút giàn giáo (chặn "density High vĩnh viễn")

```dart
// Sau 30 ngày liên tục ở Density = High mà tỉ lệ từ Stage 0 (đã thuộc)
// vượt ngưỡng (vd >40% từ gặp đều ở Stage 0):
// Hiện thông báo MỘT LẦN qua notification system sẵn có của app:
// "Bạn đã thuộc nhiều từ. Gợi ý giảm density xuống Medium để tăng thử thách?"
// User bỏ qua → không nhắc lại trong 30 ngày tiếp theo (tránh làm phiền).
```

### 6.5 Chuẩn hóa đáp án & mapping quality

| Stage | Chấm theo |
|---|---|
| Stage 2–1 | lemma (chấp nhận biến thể thì/số) |
| Stage 0 | surface form chính xác (học ngữ pháp) |

Mapping kết quả trả lời → `quality` SM-2 (0..5):

| Kết quả | quality |
|---|---|
| Đúng ngay, không hint (Easy) | 5 |
| Đúng sau 1 lần hint (Good) | 4 |
| Sai rồi tự sửa đúng (Hard) | 3 |
| Sai hoàn toàn (Again) | 1 |

Đổ thẳng vào hàng đợi SM-2/FSRS hiện hữu — **không tạo engine điểm thứ tư**,
không gộp 3 skill SM-2 (quy tắc vàng #2).

---

## 7. Khối E — Dữ liệu, đóng gói, giấy phép

### 7.1 Đóng gói

| Asset | Dung lượng | Vị trí |
|---|---|---|
| `concreteness.bin` | ~85 KB | Core bundle |
| `icon_index.bin` | ~120 KB | Core bundle |
| `icons_bundle.bin` (2.000 icon) | ~1.8 MB | Core bundle |
| `irregular_lemmas.json` | ~15 KB | Core bundle |
| `tatoeba_vetted.db` (35.000 câu) | ~4–5 MB | Model Centre |
| `extended_icons_bundle.bin` (5.000 icon) | ~4.5 MB | Model Centre |
| **Tổng Core** | **~2.1 MB** | kèm app |
| **Tổng Model Centre pack** | **~8.5–9.5 MB** | tải on-demand |

Mọi file `.bin` có Magic Header 8-byte `ICNB0001`.

### 7.2 Ma trận giấy phép

| Nguồn | Giấy phép | Quyết định |
|---|---|---|
| Twemoji | CC-BY 4.0 | ✅ Core icon |
| Material Symbols | Apache 2.0 | ✅ CDN fallback |
| Brysbaert Concreteness | CC0 | ✅ Core data |
| Tatoeba | CC-BY 2.0 FR | ✅ Model Centre |
| OpenMoji | CC-BY-SA 4.0 | ❌ Loại bỏ — rủi ro lây nhiễm ShareAlike |

Attribution bắt buộc vào `AboutScreen` cho cả 4 nguồn được chọn.

### 7.3 Per-document icon override (power user)

```dart
// Box Hive RIÊNG, KHÔNG chung với box reopen-anchor (PDF/Web).
// Key bắt buộc có prefix: "icon_override_<documentHash>"
// (documentHash tái dùng giá trị hash đã có của cơ chế reopen anchor —
//  PDF: PdfFileIdentity md5(size|mtime) — nhưng KHÔNG tái dùng chung box/key,
//  tránh xung đột keyspace. Luật prefix ghi trong ADR-0013.)
class DocumentIconOverride {
  final String documentHash;
  final Map<String, bool> lemmaPosOverrides; // "bank|NOUN" → false
}
// UI: word tap sheet có nút "Giữ chữ cho từ này trong tài liệu hiện tại"
// Dùng cho: thuật ngữ Phật học trong Tipiṭaka, thuật ngữ chuyên ngành...
```

---

## 8. Khối F — Kiểm thử & nghiệm thu

**Unit test:**
- Bộ vàng ≥ 50 câu lemmatize + POS (gồm case bất quy tắc "saw/ran/mice").
- Idempotency: iconize(plain text output) không đổi gì thêm.
- Không icon hóa trong code block/URL/số/placeholder `__G{n}__` sót lại.
- Round-trip `WordEntry.toJson()/fromJson()` với field mới trên file cũ.

**Golden test:** câu iconized với Devanagari (`hi`) + Sinhala (`si`) — không vỡ layout.

**Performance (2 tier, nhờ lazy resolution):**
- Thiết bị cao (Snapdragon 665+): < 200ms/trang.
- Thiết bị thấp (Android Go, RAM 2GB): < 500ms/trang.
- Scroll nhanh 10 trang liên tiếp: không giật quá 1 frame (16ms).

**Test case bổ sung từ phản biện đỏ:**
- Fatigue phiên dài 30 phút: memory không leak, UI thread không suy giảm.
- Cross-device: blacklist tạo trên mobile → xuất hiện trên Windows sau sync.
- Per-document isolation: override trong Tipiṭaka không rò rỉ sang PDF khác.
- Binary corrupt: Magic Header sai → disable session + badge, không crash/loop.
- Nudge sau 30 ngày: trigger đúng điều kiện, không nhắc lại trong 30 ngày sau
  khi bỏ qua.

**Tiêu chí nghiệm thu chủ dự án:**
1. Toggle "Icon hóa" ở panel dịch PDF → icon đúng chỗ, không vỡ layout.
2. Tắt mạng hoàn toàn → chạy đầy đủ với core bundle.
3. Ôn 1 từ qua 3 lần quality ≥ 4 liên tiếp → `visualScaffoldStage` giảm dần.
4. Chạm icon đúng số lần theo stage, nút "icon gây hiểu lầm" hoạt động, persist.
5. Từ đa nghĩa ("bank", "saw") → không bao giờ icon sai, giữ chữ nếu không chắc.
6. Long-press toggle → mở Density Slider, đổi mượt, áp dụng ngay không cần reload.
7. Tạo override trong một tài liệu Tipiṭaka → mở tài liệu khác chứa cùng từ →
   icon vẫn hiện bình thường (không rò rỉ).

---

## 9. Phạm vi & Ngoài phạm vi (v1)

**Trong phạm vi:** mọi mục A–F ở trên, ngôn ngữ `en`/`vi` full,
`hi/si/zh/zh_TW` light-beta.

**Ngoài phạm vi v1 (roadmap v2, ghi rõ để hội đồng tương lai không lặp tranh luận):**
- Action Icon Pack (Lottie động từ dạng hành động).
- Dynamic concreteness threshold theo độ dài câu.
- Model POS on-device riêng cho `hi`/`si` để nâng lên Full.
- Sinh ảnh AI theo từ, icon động theo ngữ cảnh câu phức tạp.
- Icon hóa cho chữ viết không phải Latin/Devanagari/Sinhala/Hán trong v1.

---

## 10. Câu hỏi mở — Chốt cuối cùng

| # | Chốt |
|---|---|
| 1 | Động từ: default giữ chữ. Action Icon Pack → roadmap v2. |
| 2 | Ngưỡng concreteness tĩnh 4.0 (danh từ) / 4.5 (tính từ). Dynamic theo độ dài câu → roadmap v2. |
| 3 | Tra theo `(lemma, POS)`; đọc ké `sentence_structure_service` nếu đã chạy sẵn để tăng độ tin cậy; không khớp → giữ chữ. |
| 4 | Icon mặc định chỉ câu nguồn; "Iconize cả bản dịch" là toggle phụ riêng, mặc định tắt, dùng Bridge-to-English. |
| 5 | Bộ 2.000 từ: COCA top 3.000 ∩ CEFR A1-B1 ∩ concreteness ≥ 4.0, xếp hạng bổ sung bằng SUBTLEX-US (không bundle thêm file, chỉ dùng lúc build). |

---

## 11. ADR đi kèm

Xem `docs/adr/0013-iconize-visual-context.md` (Status: Proposed — chờ owner
duyệt). Số 027 trong bản hội đồng là sai; đã sửa theo chuỗi ADR thật của repo.

## 12. Breakdown KANBAN (8 lane trong card ICONIZE-001, mỗi PR ≤ 500 dòng)

| # | Lane | Nội dung | Phụ thuộc |
|---|---|---|---|
| ICONIZE-001a | Build tool + asset | `tool/build_icon_map.dart`, sinh `concreteness.bin`, `icons_bundle.bin`, `icon_index.bin` với Magic Header | — |
| ICONIZE-001b | Iconize Engine core | `IconizeEngine`, data classes, lemmatize+POS, lookup `(lemma,POS)`, unit test bộ vàng | 001a |
| ICONIZE-001c | Guard + fallback + Bridge-to-English | Cognitive-load guard theo density, fallback 4 tầng, Bridge-to-English | 001b |
| ICONIZE-001d | UI toggle + Density Slider | Toggle trong 4 bề mặt, popup density, render `WidgetSpan`+`Semantics`, error badge binary corrupt; **quyết định visibility_detector vs virtualization sẵn có** | 001b, 001c |
| ICONIZE-001e | Câu ví dụ thị giác | Pipeline Tatoeba 6 tầng, schema additive `WordEntry`, hiển thị word tap sheet | 001b |
| ICONIZE-001f | Smart Cloze + scaffolding | Thuật toán rút giàn giáo (quality 0..5), hint ladder context-aware, chấm → SM-2/FSRS, nudge 30 ngày | 001e |
| ICONIZE-001g | Power-user: override & blacklist | Per-document override (box riêng, prefix chuẩn), blacklist toàn cục đồng bộ qua kênh sẵn có | 001b, 001d |
| ICONIZE-001h | Test & hiệu năng toàn diện | Golden test đa ngôn ngữ, performance 2-tier, lazy resolution conditional Web/mobile, fatigue/cross-device/corrupt test | Tất cả trên |

---

*Nguồn: hội đồng đa AI 5 vòng (94.2/100) theo prompt
`PROMPT_HOIDONG_ICONIZE_VISUAL_CONTEXT.md`; hiệu đính repo-audit 2026-10-07.
Theo AGENTS.md quy tắc vàng #4: văn bản này là blueprint đề xuất; hiệu lực
kiến trúc chỉ phát sinh khi owner duyệt ADR-0013.*
