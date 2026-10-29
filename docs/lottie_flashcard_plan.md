# KẾ HOẠCH: LOTTIE ANIMATION CHO FLASHCARD / TỪ VỰNG (LOTTIE-001)

> Trạng thái: **ĐÃ TRIỂN KHAI** (commits trên nhánh `arena/01a107d1-in4up`).
> Blueprint gốc: soi từ prompt Gemini + rà soát codebase 2026-10-04.
>
> **QUYẾT ĐỊNH CHỦ DỰ ÁN (2026-10-04):**
> 1. Phạm vi flashcard: **CẢ HAI** (WordList SM-2 review + Memory Garden).
> 2. URL khi import: **tải về local ngay (mặc định)** + toggle
>    "Chỉ tải ảnh/animation khi xem" (lazyDownload) trong dialog Cài đặt ảnh —
>    lazy chỉ nới luồng import; materialize-on-view luôn chạy (không tốn
>    thêm byte nào, hai nhánh chỉ khác THỜI ĐIỂM tải).
> 3. Đổi minh họa: **có ô Dán URL** (ảnh/Lottie) trong picker + nút **Bỏ
>    ảnh hiện tại** (có sẵn) — đổi/bỏ/thay được ngay trên flashcard.
> 4. Lottie trên mặt sau thẻ: `repeat: true` (tự nhịp đọc >1s — mượt kiểu
>    WordUp; blueprint nháp ban đầu ghi "1 lần khi lật", chốt lại là lặp).
> 5. Triển khai 1 session, ~5 commit, rebase lên `arena/01a0251e-in4up`
>    trước khi PR.

---

## 1. HIỆN TRẠNG CODEBASE (đã rà soát)

### 1.1. Hai hệ thống từ vựng song song

| Hệ thống | Model | Lưu trữ | Có `imageUrl`? | Flashcard UI |
|---|---|---|---|---|
| **WordList** | `lib/models/word_entry.dart` (`WordEntry`) | Hive `Box<String>` (JSON) qua `VocabularyProvider` | ✅ CÓ sẵn, serialize đầy đủ | `single_word_review_screen.dart` (SM-2) — **chưa hiển thị ảnh** |
| **Memory Garden** | `lib/screens/memory_mode/models/memory_item.dart` (`MemoryItem`) | `memory_storage_service.dart` | ❌ CHƯA có | `flashcard_presenter.dart` (`_FrontFace`/`_BackFace`) — **chưa hiển thị ảnh** |

### 1.2. Hạ tầng ảnh ĐÃ CÓ (`lib/features/vocab_image/`)

- `VocabImageService`: download URL → lưu file local `vocabulary_images/<md5>.<ext>`,
  `imageUrl` lưu **relative path** (triết lý **offline-first**: "không lưu thẳng
  URL, ảnh ngoài mạng chết link là mất hình"). `resolvePath()` → absolute path.
- `VocabImageThumbnail`: render `Image.file` từ local path.
- `VocabImagePickerSheet` + `vocab_image_quick_add.dart`: luồng "đổi minh họa"
  (gallery / camera / web search) + `provider.updateImageUrl(wordId, path)` đã có.
- ⚠️ `_detectExtension()` chỉ nhận jpg/png/gif/webp từ magic bytes; file `.json`
  (bắt đầu bằng `{` = 0x7B) sẽ bị lưu thành `.jpg` — **cần sửa**.

### 1.3. CSV Import/Export

- Parser: `WordTableParser` trong `word_import_sheet.dart` — kiến trúc **header
  alias** (normalize bỏ dấu/gạch dưới), robust với hàng lệch cột. Header hiện tại:
  `word, meaning, ipa, topic, example, example_simple, example_complex, language`.
- Luồng: `alignRow()` → `_ImportCandidate(word, meaning, phonetic, topic,
  example, language…)` → tạo entry mới / **smart-fill chỗ trống** cho entry đã có.
- Export: `word_list_controller.dart::exportFolderAsCsv` chỉ xuất
  `word,meaning,phonetic,example` — chưa có `image_url`.

### 1.4. Dependencies

- ❌ Chưa có `lottie`, chưa có `cached_network_image`.
- ✅ Đã có `http`, `flutter_cache_manager` (transitive trong pubspec.lock).
- App đa nền tảng: Android/iOS/Windows/Linux/Web. Package `lottie` 3.x render
  thuần Dart/Skia — **chạy được tất cả nền tảng**, không cần native code.

---

## 2. ĐIỀU CHỈNH SO VỚI PROMPT GEMINI (quan trọng)

| # | Gemini đề xuất | Thực tế dự án | Quyết định blueprint |
|---|---|---|---|
| 1 | `Lottie.network(...)` + "cache sau lần tải đầu" | Dự án đã có pattern **download → file local** cho ảnh tĩnh | File `.json` Lottie (20–100KB) **download về local giống ảnh tĩnh** → offline-first thật, tái dùng `VocabImageService`, khỏi thêm cache package |
| 2 | Thêm `cached_network_image` cho ảnh tĩnh | Ảnh tĩnh đã render từ file local (`Image.file`) | **KHÔNG thêm**. Giữ footprint siêu nhẹ |
| 3 | Thêm trường phân loại media `LOTTIE`/`IMAGE` | `WordEntry.imageUrl` đã tồn tại | **Không thêm field, không migration** — detect bằng extension `.json`/`.lottie` tại render time (đúng convention additive của dự án) |
| 4 | Repaint màu Lottie theo dark/light theme | Chỉ khả thi nếu file Lottie đơn sắc + đặt tên layer chuẩn; minh họa từ vựng đa phần đa màu | **Hoãn sang Phase 2**. Phase 1: nền thẻ trong suốt → Lottie tự hoà cả dark/light |
| 5 | Flashcard = 1 màn duy nhất | App có **2 flashcard surface**: SM-2 review (WordList) và Memory Garden swipe card | Cần chủ dự án chốt phạm vi (xem mục 5) |

---

## 3. KIẾN TRÚC MỤC TIÊU

### 3.1. Quy ước giá trị `imageUrl` (không đổi schema)

| Dạng giá trị | Ý nghĩa | Render |
|---|---|---|
| `vocabulary_images/abc.webp` | Ảnh tĩnh local (hiện tại) | `Image.file` |
| `vocabulary_images/abc.json` | Lottie đã về máy | `Lottie.file` |
| `https://…​/anim.json` | URL Lottie (mới import, chưa/lỗi download) | `Lottie.network` + kick-off materialize về local |
| `https://…​/pic.png` | URL ảnh tĩnh chưa download | `Image.network` (fallback hiếm) + materialize |

### 3.2. Luồng materialize (offline-first)

```
CSV/picker nhập URL .json
   └─► VocabImageService.saveFromUrl(url, forceExt: 'json')
         └─► vocabulary_images/<md5>.json  →  cập nhật WordEntry.imageUrl = relative path
Nếu offline lúc import: giữ URL tạm; lần đầu render có mạng → tự tải & thay path
(background materializer, không chặn UI).
```

Bảo vệ: từ chối file `.json` > **2 MB** ở import (chặn animation nặng giết RAM).

---

## 4. CÁC BƯỚC TRIỂN KHAI (Step-by-step)

### Phase A — Core media (nền)

- [ ] **A1. `pubspec.yaml`**: thêm `lottie: ^3.3.1` (không dependency mới nào khác).
- [ ] **A2. `vocab_media_type.dart` (mới)**, đặt trong `lib/features/vocab_image/`:
  `enum VocabMediaType { staticImage, lottie }` + hàm pure
  `detectVocabMediaType(String? urlOrPath)` — nhận diện đuôi `.json`/`.lottie`
  (kể cả URL có query string). Test được, không phụ thuộc widget.
- [ ] **A3. `vocab_image_service.dart`**: mở rộng `_detectExtension` nhận JSON
  (byte đầu `{` = 0x7B → `'json'`); `saveFromUrl` cho phép override extension
  theo đuôi URL → lưu `.json` đúng nghĩa. Guard 2 MB.
- [ ] **A4. `vocabulary_media_widget.dart` (mới)** — widget hybrid duy nhất
  (mọi nơi đều dùng nó):

```dart
/// SKETCH (không phải code cuối)
class VocabularyMediaWidget extends StatelessWidget {
  final String? imageUrl;
  final bool animate;      // false trong list-view → frame tĩnh, 0 chi phí
  final bool repeat;       // flashcard: 1 lần khi lật; detail: lặp
  final BoxFit fit;
  final double? width, height;

  // build():
  //  1. null/empty → SizedBox.shrink()
  //  2. detectVocabMediaType():
  //     - lottie + local path  → Lottie.file(File(resolved), animate/repeat)
  //     - lottie + http        → Lottie.network(url, …) + materialize bg
  //     - static + local path  → Image.file (giữ nguyên hành vi cũ)
  //     - static + http        → Image.network + materialize bg
}
```

### Phase B — CSV pipeline

- [ ] **B1. `WordTableParser.fieldAliases`**: thêm
  `'image_url'→'imageUrl'`, `'imageurl'→'imageUrl'`(normalize tự lo),
  `'image'`, `'hinh'`, `'hinhanh'`, `'anh'`, `'illustration'`, `'lottie'`.
- [ ] **B2. `_ImportCandidate`**: thêm `String? imageUrl` (kênh y hệt
  `phonetic`/`topic` đang chạy → diff nhỏ).
- [ ] **B3. Luồng tạo/cập nhật**: entry MỚI → set `imageUrl`; entry ĐÃ CÓ →
  chỉ smart-fill khi `entry.imageUrl` đang trống (đúng convention hiện tại).
- [ ] **B4. Sau import**: với mỗi imageUrl là http → `saveFromUrl` (có throttle,
  tuần tự) rồi `provider.updateImageUrl(wordId, localPath)`.
- [ ] **B5. `exportFolderAsCsv`**: thêm cột `image_url` (round-trip đầy đủ).

### Phase C — Flashcard UI

- [ ] **C1. WordList SM-2 review** (`single_word_review_screen.dart`, nếu cần
  cả `review_tab.dart`): chèn `VocabularyMediaWidget` vào mặt sau thẻ (sau khi
  lật — tránh lộ đáp án), `repeat: false` chạy 1 lần khi lật.
- [ ] **C2. Memory Garden** (nếu chọn): thêm `String? imageUrl` vào
  `MemoryItem` (additive JSON — key mới, item cũ không có vẫn parse được);
  plumb qua `MemoryController.addWord()`/`importWords()`; `MemoryProvider.addWord`
  nhận thêm tham số; hiển thị ở `_BackFace` (nền #1A1A2E — Lottie sáng màu nổi đẹp).
  Nguồn ảnh: copy từ `WordEntry.imageUrl` nếu từ đã có trong WordList.
- [ ] **C3. Flashcard viewport rule**: chỉ thẻ ACTIVE animate; PageView/swipe
  deck dispose cùng widget (Lottie composition được `LottieCache` giữ trong RAM,
  không tốn parse lại).

### Phase D — Manual override ("Đổi minh họa")

- [ ] **D1. `VocabImagePickerSheet`**: thêm mục **"Dán URL (ảnh .png/.webp hoặc
  Lottie .json)"** → validate đuôi file → `saveFromUrl` → `updateImageUrl`.
- [ ] **D2. Nút "Đổi minh họa" trên flashcard/back-side**: mở picker hiện có
  (kèm lựa chọn D1), ghi đè `imageUrl` cho từ đó (Hive lưu y như ảnh tĩnh).

### Phase E — Khác

- [ ] **E1. l10n**: label mới ("Đổi minh họa", "Dán URL…") qua hệ thống
  `core/language` hiện có.
- [ ] **E2. Docs cập nhật** USER_GUIDE: header CSV chấp nhận thêm `image_url`.

---

## 5. QUY TẮC HIỆU NĂNG (bắt buộc tuân thủ)

1. **ListView word-list: Lottie = frame tĩnh** (`animate: false`). Chỉ flashcard
   / màn chi tiết mới animate.
2. **Chỉ 1 Lottie animate tại 1 thởi điểm** (thẻ đang xem).
3. Chặn file `.json` > 2 MB (import + paste URL).
4. Materialize chạy nền, tuần tự, không bắn đồng loạt sau import lớn.
5. Không thêm `cached_network_image` — tránh trùng lặp cache với file-local.

## 6. TEST PLAN

- Unit: `detectVocabMediaType` (đuôi file, query string, case hoa).
- Unit: `WordTableParser` với header chứa `image_url` + hàng lệch cột
  (tái dùng hạ tầng test parser hiện có trong `test/`).
- Unit: `WordEntry` round-trip toJson/fromJson với path `.json`.
- Widget: `VocabularyMediaWidget` chọn đúng nhánh render theo input.
- Thủ công: import CSV mẫu 5 từ có link LottieFiles → flashcard hiển thị,
  tắt mạng → vẫn hiển thị (offline-first).

## 7. NGOÀI PHẠM VI (Phase 2, chỉ làm khi có yêu cầu)

- Repaint màu Lottie theo theme (`ValueDelegate` cho layer đặt tên chuẩn).
- Hỗ trợ `.lottie` (dotLottie archive — lottie 3.x decode được nhưng cần test kỹ).
- Gợi ý Lottie tự động theo nghĩa của từ (cần nguồn API LottieFiles + key).
- Thư viện Lottie gợi ý sẵn theo chủ đề (bundle assets).

## 8. ƯỚC LƯỢNG

| Phase | File đụng | Khối lượng |
|---|---|---|
| A | 4 (2 mới, 2 sửa) | ~350 dòng + test |
| B | 2 sửa | ~80 dòng |
| C | 3–6 sửa (tùy phạm vi flashcard) | ~150 dòng |
| D | 1–2 sửa | ~120 dòng |
| E | 2 sửa | nhỏ |

**Tổng: 1 session Arena làm trọn vẹn** — KHÔNG cần tách nhiều prompt agent.
Không migration, không native code, không rủi ro CI (Dart 3.11 pin sẵn —
lottie 3.x tương thích).
