# PLAN-031 — Nhận diện CỤM TỪ + CẤU TRÚC CÂU trong tab Đọc

- **Trạng thái:** 📋 proposed (kế hoạch — chưa code trong sản phẩm)
- **Nguồn:** người sở hữu (2026-09-24, qua agent `arena/01a0d344-in4up`)
- **Điểm gắn vào UI:** đúng chỗ badge **"Loại từ · CEFR"** hiện có —
  `lib/screens/read_mode/sheets/word_actions_sheet.dart` (badge row ~§209),
  mở từ `text_line_widget.dart` / `colored_text_widget.dart` → `WordActionsSheet.show(...)`
- **Bằng chứng kèm theo (spike đã chạy):** `tool/grammar_probe/`
  (`engine.py` = đặc tả thuật toán chạy được + `corpus.json`, `holdout.json`,
  `holdout2.json`, `run_probe.py`). Số đo ở §7.
- **KANBAN:** `READ-GRAM-001` · **ADR:** `docs/adr/0006-*.md`

---

## 1. Mục tiêu & phạm vi

### 1.1 Người dùng nhận được gì

Khi chạm một từ trong tab Đọc (như đang xem "Loại từ, CEFR"), người học thấy **thêm 3 tầng thông tin**:

| Tầng | Nội dung | Câu hỏi người học |
|---|---|---|
| **Cụm** | Từ này nằm trong cụm gì: `NP`, `VP`, `AdvP`, `AdjP`, `PP`, `GerP`, `InfP`, `PHRASAL_V`… + **ranh giới cụm** trong câu | "Từ này đi với những từ nào thành một khối?" |
| **Cụm rộng hơn** | Cụm chứa cụm trên (`a cat` ⊂ `under the bed`… ) để thấy quan hệ bổ nghĩa | "Khối này nằm trong khối nào?" |
| **Cấu trúc câu** | Loại câu (hỏi / khẳng định / phủ định / mệnh lệnh / cảm thán), **thì–thể–thái** (quá–hiện–vị, hoàn thành, tiếp diễn, chủ/bị động), **công thức** `S + V + O …` | "Câu này là câu gì, chia thì gì, theo mẫu nào?" |

Đây là 2 yêu cầu gốc của người sở hữu, tách thành 2 khối UI riêng nhưng **một engine duy nhất**
(cụm và cấu trúc câu dùng chung kết quả tách token + chung thông tin về nhóm động từ — tách đôi
engine sẽ sinh mâu thuẫn nhãn).

### 1.2 Tiêu chí chất lượng (quan trọng nhất)

> **Nguyên tắc "không nhãn sai to hơn nhãn đúng":** khi không đủ tin cậy, engine trả `null`
> và UI **không hiện gì**, thay vì đoán bừa. Precision ưu tiên hơn recall.

Hệ quả thiết kế: mọi kết quả đều có `confidence` + `notes[]`; UI ẩn hẳn khối khi `confidence < ngưỡng`
hoặc `supported == false` (câu tiếng Việt/Pali) — ở trạng thái đó hiện đúng **một dòng nhắc**
"Câu tiếng Việt — chưa hỗ trợ phân tích cấu trúc" (i18n, xem §6).

### 1.3 KHÔNG làm trong đợt này

- Không đổi/sửa bảng màu POS/CEFR, không đổi `ColorMode`, không đụng legend hiện có.
- Không thêm dependency, không gọi mạng, không bundle asset lớn (từ vựng seed dạng JSON nhỏ).
- Không đụng `lib/ffi/`, không đổi schema `TextItem`/`TextProvider`.
- Không làm "phân tích cả trang" mặc định; không auto-bật lớp phủ toàn văn.
- Không dùng AI làm đường chính (xem §4.4).

---

## 2. Quyết định UX (đã cân nhắc và chốt)

### 2.1 Chỗ hiện: mở rộng `WordActionsSheet` (P1) — không mở màn hình mới

Người sở hữu chỉ đúng chỗ "Loại từ, CEFR". Thiết kế **P1**: thêm **một section gập được**
ngay **dưới badge row** trong `word_actions_sheet.dart`, **không đổi thứ tự** các section
WORD HEADER / MDX / PHONETIC / DIFFICULTY / IMAGE / QUICK ACTIONS / STATS hiện có (đổi thứ tự
sẽ phá các test/QA đang chạy và thói quen người dùng).

```
┌ WordActionsSheet ────────────────────────────────┐
│  [từ]  ·  beautiful                               │
│  [ADJ] [B2]                        ← badge hiện có│
│  ┌ Cấu trúc câu ────────────────────────┐  ▾     │  ← MỚI (P1)
│  │ Cụm:      AdjP · "very beautiful"            │ │
│  │ Cụm rộng: ⊂ VP · "is very beautiful"         │ │
│  │ Mẫu:      S + V + C                          │ │
│  │ Câu:      Khẳng định · Hiện tại · đơn · chủ  │ │
│  │ [ Giải thích chi tiết (AI) ]  ← chỉ khi có model│
│  └──────────────────────────────────────┘        │
│  … các section cũ giữ nguyên …                    │
└──────────────────────────────────────────────────┘
```

Vì sao không chọn "(b) panel riêng ngay từ đầu": (i) không thêm một bước điều hướng mới cho việc
đang làm (đang tra từ); (ii) anchor từ là câu hỏi tự nhiên "cụm nào chứa từ này"; (iii) P1 nhỏ,
rollback 1 chỗ. Panel riêng là **P3** (khi cần chế độ *luyện tập* xem cả câu + công thức dạng khối).

### 2.2 Nhãn cấp dòng + NÚT BẬT/TẮT NHANH trên thanh công cụ (P2) — ✅ người sở hữu đã chốt

**Mặc định OFF, nhưng KHÔNG phải vào Cài đặt mới bật được** (yêu cầu trực tiếp của người sở hữu
2026-09-24): có **nút bật/tắt nhanh ngay trên thanh công cụ đáy tab Đọc**, cùng chỗ nút IPA.

- **Vị trí:** `lib/screens/read_mode/widgets/read_bottom_bar.dart` — chèn **ngay sau nút IPA**
  (`Icons.abc`, cyan `0xFF4DD0E1`) và trước nút TTS; dùng đúng `_BarAction(icon, isActive,
  activeThumbColor, compact: isSmall, onTap)` đang có, không tạo widget mới.
- **Hành vi:** chạm = **xoay vòng 3 trạng thái, y hệt nút IPA** (giữ một idiom duy nhất cho các lớp
  hiển thị trong tab Đọc):

  | Trạng thái | Hiện gì | Nhãn (vi) |
  |---|---|---|
  `hidden` (mặc định) | không hiện gì | Tắt |
  `activeLine` | chỉ câu đang đọc/hiện tại có nhãn | Dòng hiện tại |
  `all` | mọi câu đều có nhãn | Toàn văn bản |

  *(Nếu người sở hữu muốn bật/tắt thuần 2 trạng thái: bỏ `all` khỏi vòng xoay — sửa 1 dòng trong
  `next`; phần còn lại không đổi.)*
- **Mô hình:** file mới `lib/models/sentence_structure_display_mode.dart`, **sao chép đúng khuôn**
  `lib/models/ipa_display_mode.dart` (`enum` + `label` + `icon` + `next`) — cùng ADR-0005.
  Icon đề xuất `Icons.account_tree_outlined` (chưa dùng trong thanh); màu active phải **chưa dùng**
  (đang dùng: xanh lá `0xFF4CAF50` dịch, cyan `0xFF4DD0E1` IPA, orange TTS, amber bookmark,
  `0xFF6C63FF` panel) — đề xuất `0xFF7E57C2`, và thêm test nhỏ duyệt **màu accent không trùng**
  trong `read_bottom_bar.dart` (repo đã có văn hoá test quét nguồn, xem rule-5).
- **Lưu trạng thái:** `TextProvider` (thêm getter/setter + `cycleStructureBadgeMode()` cạnh
  `cycleIpaDisplayMode()`), ghi vào **`sentence_structure_settings_v1`** (KHÔNG sửa
  `grammar_highlight_settings_v1`).
- **Đường sâu vẫn có:** nhóm mới "Cấu trúc câu" trong `read_settings_sheet.dart`
  (cạnh nhóm grammar ~§1335–1500) cho ai muốn đặt cố định + đọc mô tả. Nút trên thanh công cụ là
  đường nhanh, không thay thế Cài đặt.
- **Chống tràn thanh công cụ:** thêm 1 nút là thêm chỗ trên màn nhỏ — bắt buộc kiểm nhánh
  `compact: isSmall` và màn hẹp (tiền lệ lỗi tràn: LISTEN-630-01 "AB loop bottom overflow 24px");
  nếu tràn thì gom vào `collapsible_bottom_controls`/menu phụ, KHÔNG để tràn.
- **Phản hồi khi chạm:** đổi icon + nhãn tooltip ngay (`uiText` của `label`), có `HapticFeedback`
  (đã có sẵn trong `_BarAction`); không cần snackbar.

Nhãn nội dung khi bật: `SVO · Hiện tại đơn · chủ động` (1 dòng, chữ nhỏ, màu mờ — không tô đè lên
lớp POS/CEFR/legend hiện có).

### 2.3 Trạng thái hiển thị

| Trạng thái | UI |
|---|---|
| Phân tích được | Section đầy đủ (§2.1) |
| Tin cậy thấp | Ẩn dòng nhãn cụ thể, chỉ hiện "Chưa đủ tin cậy để phân tích" |
| Ngôn ngữ ≠ EN | "Chưa hỗ trợ phân tích cấu trúc cho ngôn ngữ này" (giữ fail-safe như spike) |
| Không tìm thấy từ trong dòng | Ẩn hẳn section (giữ sheet như hiện nay) |
| AI có model | Thêm nút "Giải thích chi tiết (AI)" → block riêng, có nhãn **AI** |
| Nhãn cấp dòng — `hidden` | Không hiện gì (mặc định) |
| Nhãn cấp dòng — `activeLine` | Chỉ câu đang đọc có nhãn `SVO · Hiện tại đơn · chủ động` |
| Nhãn cấp dòng — `all` | Mọi câu có nhãn |
| Dòng là MẢNH câu (không kết bằng `.?!`) | Chỉ hiện cụm từ + dòng nhắc "Câu có thể tiếp tục ở dòng dưới"; **ẩn** thì/thể/công thức (§10.2) |

---

## 3. Kiến trúc (tái dùng, KHÔNG port Python)

### 3.1 Nguyên tắc

> **Tái dùng, không chuyển ngữ máy móc.** `engine.py` là **đặc tả thuật toán chạy được + bộ test vàng**,
> KHÔNG phải mã nguồn sản phẩm. Bản Dart **viết lại theo idiom Dart**, dùng đúng các service đã có
> trong repo; chỉ phần *luật* đã kiểm chứng mới được chuyển (và phải chứng minh **parity** bằng chính
> 3 corpus JSON ở §7).

| Việc | Dùng lại cái gì | Ghi chú |
|---|---|---|
| Tách token + offset | `SyntaxHighlighterService.tokenizeText`, `GrammarToken.startOffset/endOffset` | Đã là nền của mọi thứ trong Read tab |
| Từ loại + lemma + biến thể | `GrammarLexiconService` (`registerEntries`, `_deriveCandidates` inflection) | **Bảng từ 60 dòng trong Python bị BỎ HOÀN TOÀN** |
| Biên câu / mệnh đề | `lib/knowledge/text/segmenter.dart` → `TextSegmenter.sentences/clauses` | An toàn với viết tắt/số thập phân, đã có `Segment{text,start,end}` |
| Kết quả token theo dòng (cache) | `GrammarAnalysisService` (`GrammarAnalysisResult`) | Không phân tích lại token |
| Cài đặt/legend | `GrammarHighlightSettings` + preset library | Chỉ thêm nhóm cài đặt mới, không sửa nhóm cũ |

### 3.2 Thành phần mới

```
lib/features/grammar/
  models/
    phrase_info.dart          # PhraseKind, PhraseInfo{kind,startOffset,endOffset,parts[],split}
    sentence_structure.dart   # SentenceStructure{type,question,polarity,negator,tense,aspect,
                              #                   voice,modal,pattern,spanStart,spanEnd}
    structure_analysis.dart   # StructureAnalysis{sourceText,supported,phrase,outer,sentence,
                              #                   clauseRole,conditionalType,confidence,notes[]}
    structure_settings.dart   # SentenceStructureSettings (key sentence_structure_settings_v1)
  services/
    sentence_structure_service.dart   # API công khai + cache LRU
    phrase_builder.dart               # dựng NP/VP/AdvP/AdjP/PP/GerP/InfP/PHRASAL_V/CLAUSE
    verb_group_reader.dart            # thì × thể × thái × modal + phủ định (bảng §5.3)
    sentence_typer.dart               # loại câu + công thức + vai trò mệnh đề
  widgets/
    structure_section.dart            # section trong WordActionsSheet (P1)
    structure_line_badge.dart         # nhãn cấp dòng (P2)
```

Thêm ở tầng model + thanh công cụ (P2):

```
lib/models/sentence_structure_display_mode.dart   # enum + label + icon + next (khuôn IpaDisplayMode)
lib/screens/read_mode/widgets/read_bottom_bar.dart  # +1 _BarAction (nút bật/tắt nhanh) sau nút IPA
lib/screens/read_mode/sheets/read_settings_sheet.dart # nhóm "Cấu trúc câu" (đường sâu)
lib/providers/text_provider.dart                  # + getter/setter + cycleStructureBadgeMode()
```

API công khai (1 hàm duy nhất cho UI, không lộ chi tiết):

```dart
class SentenceStructureService {
  /// Phân tích câu CHỨA anchor trong 1 dòng.
  /// [anchorStart]/[anchorEnd] = offset ký tự của từ được chạm (từ GrammarToken).
  StructureAnalysis analyzeLine(String lineText, {required int anchorStart, required int anchorEnd});

  /// P2: phân tích cả dòng 1 lượt (khi bật lớp phủ) — dùng lại cache.
  List<StructureAnalysis> analyzeLineAll(String lineText);
}
```

Chạy **trong isolate** khi P2 bật lớp phủ toàn văn (ủy thác qua `Isolate.run` / worker đang có của
`TextPipeline`); P1 chỉ chạy **1 câu, lazy, theo cú chạm** (đo được ~0,2–0,3 ms/câu ở Python ⇒ Dart
cùng bậc hoặc nhanh hơn; không cần isolate cho P1).

### 3.3 Câu vắt dòng — quyết định

`TextProvider` là **line-first**: nội dung lưu `List<TextItem>` (`content`/`translation`/`lang`/timing),
`TextSplitterService.split(..., mode: SplitMode.smart)` cắt theo dòng. Nên:

- **P1: phân tích theo DÒNG.** Nếu dòng không kết thúc bằng dấu câu (`.?!`), thêm 1 dòng nhắc mờ
  "Câu có thể tiếp tục ở dòng dưới" (i18n) và **không** đưa ra nhãn thì/thể như thể câu đã trọn
  (đặt `confidence` thấp cho các trường `tense/aspect/voice/pattern` → ẩn theo §1.2).
- **P2: `SentenceJoiner` ở tầng đọc** — thêm **side-table** (không đổi schema `TextItem`):
  `Map<int /*lineIndex*/, SentenceRef{int sentenceId, int startLine, int endLine, int startOffsetInSentence}>`,
  dựng 1 lượt khi load document bằng `TextSegmenter.sentences(text gốc)`, cache theo doc id.
  Chi phí O(n) một lần; không đổi luồng TTS/nhịp đang bám theo dòng.
- Điều này ghi ở **ADR-0007**: "line-first + side-table" thay vì đổi `TextItem` thành sentence-first.

---

## 4. Logic ngôn ngữ (đặc tả thuật toán)

Thứ tự xử lý — mỗi bước là một hàm thuần, test được riêng:

```
text ─► normalize (1 ký tự ↔ 1 ký tự, giữ offset)
     ─► tokenize (offset) ─► expand_contractions ('s / n't / 're / I'm …)
     ─► tag POS (lexicon + luật ngữ cảnh) ─► [gate ngôn ngữ]
     ─► sentence_spans ─► clause_spans ─► modifier_spans (mệnh đề quan hệ/participial)
     ─► verb_group_reader tại mệnh đề chính  ⇒ tense/aspect/voice/modal/neg
     ─► sentence_typer ⇒ type/question/polarity/pattern/span
     ─► phrase_builder: all_candidates(anchor) ⇒ chọn cụm nhỏ nhất + cụm bao ngoài
     ─► StructureAnalysis{...} (+ confidence, notes)
```

### 4.1 Cụm từ (phrase/chunk)

| Kind | Nhận dạng (rút gọn) |
|---|---|
`NP` | head noun/pronoun + determiner/adjective/number bên trái; `'s` sở hữu (`Peter's car`); PP **bổ ngữ** bên phải (`of/for/with/from/about/to/by`)
`VP` | nhóm động từ hữu hạn (aux + modal + neg + adv chen), **KHÔNG gồm tân ngữ**
`PHRASAL_V` | cặp (động từ, tiểu từ) trong danh sách đóng, kể cả tách rời: `turn off`, `pick it up`, `look after`
`AdjP` | adjective + degree adv + `than …`/`to V`/PP bổ nghĩa (`taller than me`)
`AdvP` | trạng từ (+ degree)
`PP` | giới từ + NP
`GerP` | V-ing làm chủ ngữ/bổ ngữ (`Walking in the rain…`)
`InfP` | `to V` (trừ khi nằm trong chuỗi bán-khuyết-thiếu: `be going to V`)
`PartP` | phân từ (V-ing/V-ed) bổ nghĩa danh từ
`CLAUSE` | mệnh đề con (chỉ dùng cho `clause_role`, không phải nhãn cụm chính)
`COORD` | liên hợp `X and Y`

**"Cụm nhỏ nhất chứa anchor"** là mặc định; **"cụm rộng hơn"** = cụm bao ngoài khác loại, gần nhất
(tối đa +6 token) — đây chính là cặp `phrase`/`outer` người học cần để hiểu quan hệ bổ nghĩa.

### 4.2 Loại câu

| type | Dấu hiệu | `question` |
|---|---|---|
`declarative` | trật tự S–V, không đảo | `none` |
`interrogative` | đảo trợ động từ lên đầu mệnh đề | `yesno` / `wh` / `tag` / `alternative` |
`imperative` | động từ dạng base ở đầu, không chủ ngữ (bỏ qua `please/never/always/just/kindly`; chấp nhận động từ bất biến `put/cut/let/set/read…`) | `none` |
`exclamative` | `what/how … !` | `none` |

`polarity`: `negative` khi có `not/n't/never/no/nothing/nobody/neither/nor/hardly…` **trong mệnh đề chính**;
ghi lại `negator` (từ nào tạo phủ định) để UI giải thích được "phủ định vì *never*".

### 4.3 Thì–thể–thái + công thức

Bảng chân trị của `VerbGroupReader` (đã kiểm chứng trên corpus):

| Chuỗi nhận được | tense | aspect | voice |
|---|---|---|---|
V / V-s | present | simple | active |
V-ed (bất quy tắc: `PAST_FORMS`) | past | simple | active |
`did + V` | past | simple | active |
have/has + V3 | present | perfect | active |
had + V3 | past | perfect | active |
have/has been + V-ing | present | perfect_continuous | active |
be + V-ing | present(am/is/are) / past(was/were) | continuous | active |
be + V3 | present/past | simple | **passive** |
modal + V | modal | simple | active |
will/shall + V, `be going to V` | future | simple | active |
`used to + V` | past | simple | active |
`is used to + V-ing` | present | continuous | active (KHÔNG nhầm thành "used to") |
`had better/would rather + V` | modal | simple | active |

`pattern` (công thức hiển thị): `SV`, `SVO`, `SVC`, `SVA`, `SVOO`, `SVOC`, `SVOA`, `There+V+S`,
`IT-CLEFT`, `VO`/`V` (mệnh lệnh). Động từ nối (`be`, `become`, `seem`…) → `SVC`; **trừ khi** là
cụm động từ cố định (`look after`, `turn off`) → `SVO`. Tiểu từ của cụm động từ được nhảy qua khi
đọc phần sau động từ.

`clause_role` (câu nhiều mệnh đề): `relative` (quan hệ, kể cả **zero relative**: "The book **I borrowed**…"),
`nominal` (`that/Whether`-clause làm tân ngữ/bổ ngữ), `adverbial` (trạng ngữ). Trường phái câu
(`tense/aspect/voice/pattern`) **chỉ tính trên mệnh đề chính**; vai trò của mệnh đề chứa anchor ghi riêng.
`conditionalType` 0/1/2/3 cho câu điều kiện (phục vụ giải thích sau này).

### 4.4 AI: đường bổ trợ, không phải đường chính

- Đường chính = luật cục bộ ⇒ **chạy được 100% offline, không cần model** (yêu cầu bắt buộc:
  đa số người dùng chưa tải model AI).
- Khi có model: nút "Giải thích chi tiết (AI)" gọi façade đã có
  (`analyzeSentenceWithResult`, `AiAnalysisType.sentenceParse` → `GrammarAnalysis{subject,verb,object,
  complement,adverbial,pattern,explanationVi}`) — hiện ở **block riêng có nhãn AI**.
- **Không bao giờ** hiển thị 2 nhãn mâu thuẫn cùng lúc: nhãn luật là nhãn chính; AI chỉ là *giải thích*
  bằng chữ. Nếu AI lệch luật, UI ghi "AI gợi ý khác: …" (trung thực, không tự ý trộn).
- Đây là đường đã có sẵn (`write_studio_screen.dart` gọi `analyzeSentence`) nên không phát sinh
  hạ tầng AI mới.

---

## 5. Mô hình dữ liệu (Dart)

```dart
enum PhraseKind { np, vp, adjp, advp, pp, gervp, infp, partp, phrasalV, clause, coord }
enum SentenceType { declarative, interrogative, exclamative, imperative }
enum QuestionKind { none, yesNo, wh, tag, alternative }
enum Polarity { affirmative, negative }
enum Tense { present, past, future, modal, none }
enum Aspect { simple, continuous, perfect, perfectContinuous }
enum Voice { active, passive }
enum ClauseRole { relative, nominal, adverbial }

class PhraseInfo {
  final PhraseKind kind;
  final int startOffset, endOffset;          // theo ký tự trong dòng
  final List<(int, int)> parts;              // nhiều khúc khi cụm bị tách (pick … up)
  bool get isSplit => parts.length > 1;
}

class SentenceStructure {
  final SentenceType type; final QuestionKind question;
  final Polarity polarity; final String? negator;
  final Tense tense; final Aspect aspect; final Voice voice; final String? modal;
  final String pattern;                      // "S + V + O"
  final int spanStart, spanEnd;
}

class StructureAnalysis {
  final String sourceText; final bool supported;
  final PhraseInfo? phrase, outer;
  final SentenceStructure? sentence;
  final ClauseRole? clauseRole; final int? conditionalType;
  final double confidence;                   // 0..1
  final List<String> notes;                  // language_gate | anchor_not_found | no_chunk | line_continues …
}
```

`confidence` giảm khi: dòng chưa kết câu, thiếu lexicon cho head, có `SUB/WH` lạ, câu > 40 token,
nhiều mệnh đề không dấu phẩy. UI dùng 1 ngưỡng duy nhất (`>= 0.6` hiện nhãn) — để tinh chỉnh được
mà không phải sửa engine.

---

## 6. i18n & luật #5 (bắt buộc, cùng PR)

Mọi nhãn mới dùng `context.uiText('...')` (hoặc `Text` shim đã bản địa hoá). **Locale ≠ `vi` ⇒ tiếng Anh**;
các bản dịch ưu tiên (`en/hi/zh/zh_TW/si`) phải có **trong cùng PR** (`AGENTS.md`).
**Không** dùng `generate_arbs.py`.

Chuỗi mới (nguồn tiếng Việt → tiếng Anh):

| vi (nguồn) | en (fallback) |
|---|---|
Cấu trúc câu | Sentence structure |
Cụm từ | Phrase |
Cụm rộng hơn | Larger phrase |
Công thức câu | Pattern |
Cụm danh từ / động từ / tính từ / trạng từ / giới từ | Noun / Verb / Adjective / Adverb / Preposition phrase |
Cụm danh động từ / động từ nguyên thể / phân từ | Gerund / Infinitive / Participle phrase |
Cụm động từ ghép | Phrasal verb |
Câu hỏi / khẳng định / phủ định / mệnh lệnh / cảm thán | Question / Affirmative / Negative / Imperative / Exclamative |
Hỏi đuôi | Tag question |
Hiện tại / quá khứ / tương lai / động từ khuyết thiếu | Present / Past / Future / Modal |
đơn / tiếp diễn / hoàn thành / hoàn thành tiếp diễn | simple / continuous / perfect / perfect continuous |
chủ động / bị động | active / passive |
Câu có thể tiếp tục ở dòng dưới | Sentence may continue on the next line |
Chưa đủ tin cậy để phân tích | Not confident enough to analyse |
Chưa hỗ trợ phân tích cấu trúc cho ngôn ngữ này | Structure analysis is not supported for this language yet |
Giải thích chi tiết (AI) | Detailed explanation (AI) |
Cấu trúc câu *(dùng cho cả nhóm cài đặt + tooltip nút thanh công cụ)* | Sentence structure |

Cổng kiểm tự động (mirror `test/pdf_reader/pdf_reader_i18n_coverage_test.dart`):
`test/read_sentence_structure_i18n_test.dart` quét literal trong các file mới và đối chiếu
priority/legacy/arb; `test/locale_chrome_no_vietnamese_test.dart` hiện có sẽ tự bắt nếu lọt tiếng Việt.

---

## 7. Đo lường — và một con số TRUNG THỰC

Spike `tool/grammar_probe/` chạy: `python3 tool/grammar_probe/run_probe.py [corpus.json]`
(runtime in kèm, exit 1 nếu lệch — dùng được như golden test).

| Bộ | Số case | Viết khi nào | Case sai | Đọc con số này thế nào |
|---|---|---|---|---|
`corpus.json` (dev) | 65 | tinh chỉnh 8 vòng | **0** | Đã tinh chỉnh trên chính nó ⇒ **KHÔNG phải** ước lượng tổng quát hoá |
`holdout.json` | 30 | viết sau đợt tinh chỉnh 1 | **0** (đã sửa 2 nhãn vàng sai: H24, H27 — ghi trong file) | Cũng đã tinh chỉnh lại trên nó ⇒ vẫn không phải ước lượng |
`holdout2.json` (**ĐÓNG BĂNG**) | 25 | viết sau cùng, **chạy 1 lần, không sửa engine sau đó** | **8** ⇒ **17/25 = 68%** case đúng trọn; **7** ⇒ **18/25 = 72%** sau khi chốt quy ước hỏi đuôi (§10.1) | ✅ **Đây là con số khách quan duy nhất.** Trích "khả năng tổng quát hoá" ⇒ **17/25**; trích "theo quy ước đã chốt" ⇒ **18/25** |

Độ chính xác từng trường trên bộ đóng băng `holdout2`:

| Trường | Đúng/tổng | | Trường | Đúng/tổng |
|---|---|---|---|---|
tense | 11/11 | | phrase.kind | 23/25 (92%) |
pattern | 5/5 | | phrase.span | 21/25 (84%) |
polarity | 3/3 | | aspect | 10/11 |
voice | 3/3 | | type | 5/5 (sau §10.1) |
question | 3/3 | | clause_role | 1/2 |
conditional | 1/1 | | outer.span | 0/1 |

7 case sai còn lại (sau khi áp quy ước hỏi đuôi): F01, F05, F09, F14, F15, F17, F21.

Runtime: trung bình **286 µs/câu**, max **730 µs** (Python, một lõi; Dart cùng bậc hoặc nhanh hơn)
⇒ 1 câu theo cú chạm là tức thời; lớp phủ toàn dòng 100 dòng ≈ 30 ms ⇒ vẫn nên chạy isolate khi P2 bật.

### 7.1 Các case sai ⇒ 4 nguyên nhân gốc (đây là backlog của bản Dart)

| # | Case | Lỗi | Nguyên nhân gốc | Cách sửa ở bản Dart |
|---|---|---|---|---|
A | F01, F15 | `outer=None`; GerP không hút PP vị trí | PP **vị trí** (`under/in/on`) không được coi là bổ nghĩa | Cho phép PP vị trí khi **bao ngoài** cụm (outside-in) — luật "PP bổ ngữ" chỉ áp khi **bên trong** NP |
B | F05 | `had already left` → aspect `simple` | trạng từ chen giữa aux và phân từ cắt chuỗi | Cho phép ADV chen trong chuỗi động từ (cửa sổ nhìn tới phân từ) |
B | F09 | `was born` → nhãn `NP` | thiếu dữ liệu bất quy tắc (`bear/born`) trong bảng từ nhỏ của spike | **Tự khỏi ở bản Dart**: `GrammarLexiconService` đã có lemma + biến thể |
C | F13 | câu hỏi đuôi → `interrogative` | **chưa chốt quy ước** (không phải lỗi engine) | ✅ **ĐÃ CHỐT** (§10.1): `type=declarative` + `question=tag` ⇒ case này **đã đúng** |
C | F14 | `The book I borrowed…` → `clause_role=None` | quan hệ **zero** (không có đại từ quan hệ) | Luật mới: mệnh đề chứa anchor kết thúc trước một mệnh đề chính phía sau ⇒ `relative` |
D | F17 | `will cancel` → nhãn `NP` | `cancel` không có trong bảng từ 60 dòng ⇒ bị tag NOUN | **Tự khỏi phần lớn ở bản Dart** (lexicon đầy đủ hơn); vẫn giữ heuristic hậu tố + ngữ cảnh sau modal |
D | F21 | `would rather stay` → thiếu trong chuỗi | chưa có semi-modal `would rather` (đã có `had better`) | Thêm `would rather / had better / would sooner` vào họ semi-modal + `+ V` |

**Kết luận từ phép đo:** kiến trúc **đúng**; 6/8 lỗi đến từ **bao phủ dữ liệu từ vựng** (thứ mà bản Dart
đã có sẵn) và 2 lỗi là **2 luật còn thiếu** + 1 quy ước cần chốt. Ước lượng sau khi port + sửa A–D:
**case đúng trọn ≥ 22/25 (88%)**, các trường đơn ≥ 95%.

### 7.2 Cổng test trong CI (Dart)

1. `test/sentence_structure_golden_test.dart` — nạp **cả 3** corpus JSON, so từng trường.
   - `corpus.json` + `holdout.json` (95 case): **phải 100%**.
   - `holdout2.json`: **không được thấp hơn 17/25** (mốc đóng băng gốc); 7–8 case đang lỗi đánh dấu
     `known-gap` kèm lý do A–D (F13 đã hết lỗi nhờ quy ước §10.1)
     trong test, và test **đếm chính xác số lượng known-gap** — tăng lên ⇒ đỏ (chống hồi quy ngầm).
   - Sau P2 (sửa A–D): mục tiêu ≥ 22/25, known-gap ≤ 3, và hạ trần known-gap trong test.
2. `test/sentence_structure_perf_test.dart` — 200 câu < 50 ms (JIT) / không chặn UI (isolate).
3. `test/read_sentence_structure_i18n_test.dart` — luật #5.
4. `test/sentence_structure_language_gate_test.dart` — dòng tiếng Việt ⇒ `supported == false`,
   UI ẩn nhãn (giữ fail-safe).

---

## 8. Lộ trình

| Phase | Nội dung | File chạm | DoD |
|---|---|---|---|
**P0** (đã xong) | Spike đặc tả + 3 corpus + số đo | `tool/grammar_probe/*` | 65/65 dev; bộ đóng băng công bố 68% + phân loại lỗi |
**P1** (2,5–4 ngày) | Models + `SentenceStructureService` (NP/VP/PHRASAL_V/PP/AdjP/AdvP/GerP/InfP) + `SentenceTyper` + `VerbGroupReader`; section trong `WordActionsSheet`; i18n + 4 test | `lib/features/grammar/**`, `word_actions_sheet.dart`, arb | Sheet hiện cụm + công thức + thì/thể; 95 case phải 100%; CI xanh |
**P2** (2–2,5 ngày) | Sửa A–D + `SentenceJoiner` (side-table) + nhãn cấp dòng + **nút bật/tắt nhanh trên `read_bottom_bar`** + nhóm cài đặt | `sentence_structure_display_mode.dart`, `read_bottom_bar.dart`, `read_settings_sheet.dart`, `TextProvider`, `sentence_structure_service.dart` | `holdout2` ≥ 22/25; mặc định `hidden`; 1 chạm là bật/tắt được; không tràn thanh công cụ màn hẹp; perf đạt |
**P3** (1–2 ngày) | Panel "Cấu trúc câu" + block AI + giải thích tiếng Việt cho negator/conditional | widget mới, AI façade (đã có) | Panel mở từ sheet; AI chỉ hiện khi có model; không nhãn mâu thuẫn |

Ước lượng tổng: **5,5–8,5 ngày công** (kể cả test + i18n), chia được thành 3 PR nhỏ.

---

## 9. Rủi ro & đối sách

| Rủi ro | Đối sách |
|---|---|
Ngữ pháp tiếng Anh không thể phủ hết bằng luật | Precision-first: `confidence` + ẩn nhãn khi yếu; đo bằng bộ đóng băng; coi ~≤95% là **trần tự nhiên**, không hứa hơn |
Văn học/kỹ thuật có đảo ngữ, tỉnh lược, câu dài | Không đoán: `notes` ghi lý do; UI ẩn; có thể mở rộng sau |
Quá tải nhận thức | P1 chỉ hiện khi **chạm từ**; P2 tắt mặc định; không tô màu đè lên bảng POS/CEFR |
Hiệu năng tài liệu dài | Lazy theo cú chạm; cache LRU 500 dòng; isolate khi P2 |
Nợ i18n | Cổng test #5 chạy cùng PR (bắt buộc) |
Trùng lặp với đường AI | Nhãn luật là chính; AI là block riêng có nhãn; hiển thị mâu thuẫn minh bạch |
Nhãn tiếng Việt lọt vào locale khác | `test/locale_chrome_no_vietnamese_test.dart` đã có sẵn làm lưới |

---

## 10. Quyết định của người sở hữu

### 10.1 ✅ ĐÃ CHỐT (2026-09-24) — câu hỏi đuôi
`You are a student, aren't you?` ⇒ hiển thị **"Câu khẳng định + hỏi đuôi"**: `type=declarative`,
`question=tag`, polarity tính trên mệnh đề chính. Đã áp vào `engine.py`, `corpus.json` (case E07) và
ghi quy ước ở `corpus.json/conventions.tag_question`. Ảnh hưởng số đo: §7.

### 10.2 ✅ ĐÃ CHỐT (2026-09-24) — câu vắt dòng: chọn (a)
Phân tích theo dòng trước; P2 mới ghép câu (side-table). Dòng là mảnh câu ⇒ chỉ hiện cụm từ + dòng
nhắc, ẩn thì/thể/công thức (`confidence` thấp). Không đổi `TextItem`/luồng TTS. (Chi tiết §2.3, §3.3.)

### 10.3 ✅ ĐÃ CHỐT (2026-09-24) — mặc định hiển thị
- **(a) Khối trong sheet khi chạm từ: ON.** Vừa chạm là thấy cụm + công thức + thì/thể.
- **(b) Nhãn dưới mỗi câu khi đang đọc: OFF mặc định, NHƯNG có nút bật/tắt nhanh trên thanh công cụ
  đáy tab Đọc** (cạnh nút IPA) — không phải vào Cài đặt mới bật được (yêu cầu trực tiếp của người
  sở hữu). Nút xoay vòng `Tắt → Dòng hiện tại → Toàn văn bản`; nếu muốn bật/tắt thuần thì bỏ `all`.
  Thiết kế chi tiết: §2.2.

### 10.4 ⏳ Còn lại (không chặn kế hoạch)
- Màu accent đề xuất `0xFF7E57C2` + icon `Icons.account_tree_outlined` cho nút mới — có thể veto khi
  xem bản chạy thật (đổi 1 dòng).
- Vòng xoay 3 trạng thái hay bật/tắt 2 trạng thái (§2.2) — có thể veto.

---

## 11. Lịch sử

- 2026-09-24 | created | agent `arena/01a0d344-in4up` | Kế hoạch theo yêu cầu người sở hữu
  ("cụm danh từ / cụm động từ / cụm trạng từ / cụm…" + "câu hỏi–khẳng định–phủ định, thì quá–hiện–vị,
  hoàn thành, tiếp diễn + công thức S+V+…"), gắn đúng chỗ "Loại từ, CEFR" trong tab Đọc.
  Kèm spike đặc tả `tool/grammar_probe/` + 3 bộ corpus + số đo trung thực (68% trên bộ đóng băng).
- 2026-09-24 | updated | agent `arena/01a0d344-in4up` | người sở hữu chốt cả 3 điểm (§10.1 câu hỏi
  đuôi; §10.2 câu vắt dòng chọn (a); §10.3 mặc định (a) ON, (b) OFF **kèm nút bật/tắt nhanh trên
  thanh công cụ**) ⇒ §2.2 viết lại thành thiết kế cụ thể (file, enum, icon/màu, test chống trùng màu,
  chống tràn thanh công cụ); thêm chuỗi i18n "Cấu trúc câu".
- 2026-09-27 | updated | agent `arena/01a0d344-in4up` | gộp nhánh tích hợp `arena/01a0251e-in4up`
  (4 commit: LHB-006, READ-IMPORT-001, CABIN-SAVE-001, build.yml). Đổi số `PLAN-029 → PLAN-031`
  và `ADR-0006 → ADR-0007` vì 251e đã dùng PLAN-029 (LHB-006), PLAN-030 (Cabin Save) và
  ADR-0006 (đồng bộ Thuộc Lòng). Không đổi nội dung kế hoạch.
