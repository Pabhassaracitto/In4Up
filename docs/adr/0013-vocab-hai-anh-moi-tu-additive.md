# ADR-0013: Mỗi từ có 1 HOẶC 2 ảnh/animation — thêm `imageUrl2` additive, không migration

- **Ngày:** 2026-10-07
- **Trạng thái:** ĐÃ QUYẾT ĐỊNH (chờ triển khai + CI, xem card KANBAN `VOCAB-MEDIA-003`)
- **Phạm vi:** `WordEntry` (WordList), `MemoryItem` (Vườn nhớ), các màn hình tiêu thụ media,
  sheet chọn media, nguồn thư viện animation

## Bối cảnh

Audit 0.10.3 mục 2, yêu cầu của chủ dự án:

1. "Cho phép **xem trước** ảnh/animation rồi mới chọn cái nào tải về" — phần dán-URL đã
   xong ở `LOTTIE-IMPORT-002`; còn thiếu **duyệt một danh sách Lottie** và xem trước từng
   cái trước khi tải.
2. "Cho phép thêm **1 hoặc 2 ảnh** tuỳ người dùng."

Hiện trạng: `WordEntry.imageUrl` (và `MemoryItem.imageUrl`) là **MỘT** trường duy nhất, dùng
cho cả relative path local (`vocabulary_images/xx.webp`) lẫn URL http(s). Loại media (ảnh tĩnh
/ Lottie) suy ra từ đuôi file — không có cột schema riêng (LOTTIE-001).

Luật cứng của dự án: **thay đổi dữ liệu phải additive** — dữ liệu cũ mở lên vẫn chạy, không
migration phá huỷ.

## Quyết định

### 1. Schema: thêm trường mới `imageUrl2` (slot 2), KHÔNG đụng `imageUrl` (slot 1)

- `WordEntry.imageUrl2` và `MemoryItem.imageUrl2`: `String?`, cùng ngữ nghĩa với `imageUrl`
  (relative path local hoặc URL http(s)).
- `fromJson`: `imageUrl2: json['imageUrl2'] as String?` — dữ liệu cũ không có key ⇒ `null`,
  đọc bình thường. **Không migration.**
- `toJson`: **chỉ ghi khi khác null/rỗng** (giữ file nhỏ, tương thích ngược — app cũ đọc
  file mới vẫn chạy vì `fromJson` của app cũ bỏ qua key lạ... thực tế app cũ không có key
  trong từ điển nên key mới bị bỏ qua khi deserialize bằng `as String?` từng field — an
  toàn; ngược lại app mới đọc file cũ ⇒ null).
- **Không** nhồi hai path vào một chuỗi ngăn cách bằng ký tự lạ — mọi nơi đang đọc
  `imageUrl` (danh sách, flashcard mặt trước, thumbnail) sẽ hỏng nếu đổi ngữ nghĩa trường.
- Getter tiện dụng: `List<String> get mediaPaths` — lọc null/rỗng, slot 1 trước slot 2.

### 2. Quy tắc slot (nghiệm thu: không mất dữ liệu)

- Slot 1 = **ảnh chính** (mọi chỗ chỉ đủ 1 ảnh vẫn dùng slot 1: thumbnail danh sách,
  flashcard mặt trước — giữ nguyên hành vi cũ).
- Slot 2 = **ảnh phụ** (chỉ hiện ở màn chi tiết / mặt sau thẻ / ô sửa từ).
- **Xoá ảnh chính khi đang có 2 ảnh ⇒ ảnh phụ LÊN THAY (promote)**, không để slot 1 trống
  mà slot 2 vẫn còn. Xoá slot 2 chỉ xoá slot 2.
- "Đặt làm ảnh chính" = **hoán đổi** slot 1 ↔ slot 2 (đơn giản, không xoá file nào).
- Invariant: nếu slot 2 có giá trị thì slot 1 luôn có giá trị (UI enforce; `swapMediaSlots`
  no-op khi slot 2 trống để giữ invariant).

### 3. Đồng bộ / serializer (quy tắc: thêm field ⇒ rà toàn bộ serializer)

| Nơi | Cơ chế | Thay đổi |
|---|---|---|
| Hive `vocabulary_v2` (`VocabularyProvider._saveWord`) | `jsonEncode(w.toJson())` | theo `toJson` — tự động đủ |
| Firestore sync (`VocabSyncService`) | push/pushAll đọc nguyên map JSON trong Hive box; pull ghi map vào box rồi `WordEntry.fromJson` | **không đổi code** — map passthrough đủ cả `imageUrl2` |
| `MemoryItem` (Vườn nhớ) | `toJson`/`fromJson` | thêm `imageUrl2` additive như trên |
| CSV export (`word_list_controller.exportFolderAsCsv`) | cột `image_url` | thêm cột `image_url_2` ở CUỐI (additive — parser cũ đọc được, cột mới tự rơi vào ô tự do) |
| CSV import (`word_import_sheet.dart` + `WordTableParser`) | alias `image_url` → `imageUrl` | thêm alias `image_url_2` → `imageUrl2`; đuôi media mở rộng tối đa 2 cột |
| `word_list_models.WordEntry` (model CSV, plumb từ `MemoryItem`) | field `imageUrl` | thêm `imageUrl2` |
| Knowledge migration (`word_entry_migrator._collectUnmappedFields`) | liệt kê field cũ chưa có chỗ trong schema v1 | thêm `imageUrl2` (không rơi âm thầm) |

### 4. Sheet chọn media: thêm nguồn thứ 4 "Animation" + ô sửa từ 2 khung

- `VocabImagePickerSheet` thêm segment **Animation**: lưới kết quả, mỗi ô là preview
  Lottie **chạy nhẹ** — chỉ ô đang nằm trong khung nhìn mới `animate: true`; ô chưa từng
  hiện trên màn hình chỉ hiện placeholder (không tải gì), ô đã từng hiện mà ngoài khung
  nhìn thì `animate: false` (đứng frame đầu, 0 ticker). Không có package mới.
- Nguồn dữ liệu: **endpoint cấu hình được** (prefs `vocab_animation_endpoint` +
  `vocab_animation_api_key` Bearer tùy chọn) **ưu tiên**; mặc định fallback
  **Wikimedia Commons** (MediaWiki `filemime:application/json`, không cần key). Không
  hard-code khoá API bên thứ ba vào repo; không tải gì khi mở app (chỉ tìm khi user mở
  tab Animation và bấm Tìm).
- Bấm một ô ⇒ **xem trước lớn** (dialog, `Lottie.memory`) ⇒ "Lưu vào từ này" — dùng lại
  `fetchPreviewBytes` + `saveFromBytes` trên **cùng một lần tải** (không tải hai lần).
- Sheet vẫn trả `VocabImagePickResult` như hiện nay; **người gọi quyết định slot**: ô sửa
  từ / chi tiết dùng `VocabMediaSlotsEditor` (tối đa 2 khung, khung trống có nút "+", menu
  mỗi khung: Đổi / Xoá / Đặt làm ảnh chính). Các luồng cũ (thêm từ nhanh, word actions,
  quick-add) giữ 1 ảnh như cũ.

### 5. Hiệu năng (theo blueprint `docs/lottie_flashcard_plan.md`)

- Danh sách / thumbnail / ô sửa từ: Lottie luôn `animate: false` (0 ticker).
- Chỉ màn chi tiết / mặt sau thẻ / dialog xem trước `animate: true`.
- Lottie trong lưới thư viện: chỉ ô đang trong khung nhìn chạy; ô chưa từng hiện không
  tải file (placeholder icon).

## Hệ quả

- Dữ liệu cũ (không có `imageUrl2`) đọc/ghi bình thường; app cũ đọc file mới vẫn chạy.
- `flutter analyze` 0 error + test thuần xanh (serializer, `mediaPaths`, promote/swap,
  parser CSV, parser thư viện animation).
- i18n rule #5: chuỗi mới đủ `en/hi/zh/zh_TW/si` trong `priority_ui_overrides.dart`.

## Triển khai (VOCAB-MEDIA-003 — 2026-10-07)

- `lib/models/word_entry.dart` — `imageUrl2`, `mediaPaths`, `setMediaSlot`, `swapMediaSlots`,
  `toJson`/`fromJson`, `copyWith`.
- `lib/screens/memory_mode/models/memory_item.dart` — `imageUrl2`, `withImageUrl2`,
  `removePrimaryMedia`; `memory_controller.updateImageUrl` promote + `updateImageUrl2`;
  `memory_provider.addWord` nhận `imageUrl2`.
- `lib/providers/vocabulary_provider.dart` — `updateImageUrl` (set slot 1, null ⇒ promote),
  `updateImageUrl2`, `updateMediaSlots` (ghi cả 2 slot, slot 2 trước), `swapImageSlots`.
- `lib/features/vocab_image/vocab_animation_library.dart` (MỚI) — config prefs + service +
  parser thuần (`parseAnimationLibraryJson`, `parseCommonsAnimations`).
- `lib/features/vocab_image/vocab_media_slots_editor.dart` (MỚI) — ô 2 khung.
- `lib/features/vocab_image/vocab_image_picker_sheet.dart` — tab Animation + dialog xem
  trước + dialog cấu hình nguồn.
- `lib/screens/tools/word_list/word_import_sheet.dart` + `word_list_controller.dart` +
  `word_list_models.dart` — CSV `image_url_2`.
- `lib/knowledge/migration/word_entry_migrator.dart` — liệt kê `imageUrl2`.
- Tiêu thụ: `word_list_screen.dart` (sửa từ + chi tiết), `single_word_review_screen.dart`,
  `flashcard_presenter.dart` (mặt sau cả 2 ảnh).
- Test: `test/vocab_two_images_test.dart`, `test/vocab_animation_library_test.dart`,
  `test/word_import_parser_image_url2_test.dart` + nối vào `app_analyze.yml`.
