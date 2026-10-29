# Prompt giao việc — Worklist: 1 HOẶC 2 ảnh cho mỗi từ + duyệt/xem trước thư viện Lottie (VOCAB-MEDIA-003)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena.

Phần "nhập Lottie được / dán link xem trước được" **đã xong** trong commit
`LOTTIE-IMPORT-002` (xem card KANBAN). Việc còn lại ở đây là phần đụng
**schema + nhiều màn hình**, cố tình tách ra để không làm nửa vời.

---

## 0. Luật phiên

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`).
- `AGENTS.md` + quy tắc vàng: không đụng `lib/ffi/`, không gộp 3 SM-2, giữ
  reopen anchor, ADR cho thay đổi kiến trúc, i18n rule #5 (chuỗi mới đủ
  `en/hi/zh/zh_TW/si` trong `priority_ui_overrides.dart`, **đừng** chạy
  `tool/generate_arbs.py`).
- Thay đổi dữ liệu phải **additive** (dữ liệu cũ mở lên vẫn chạy, không
  migration phá huỷ). Đây là luật cứng của dự án.
- Card KANBAN `VOCAB-MEDIA-003`: status-only + append lịch sử.

## 1. Yêu cầu của chủ dự án (audit 0.10.3 mục 2)

1. "Cho phép **xem trước** ảnh/animation rồi mới chọn cái nào tải về" —
   phần dán-URL đã làm xong; còn thiếu **duyệt một danh sách Lottie** và xem
   trước từng cái trước khi tải.
2. "Cho phép thêm **1 hoặc 2 ảnh** tuỳ người dùng."

## 2. Sự thật trong repo (đọc trước khi thiết kế)

- `lib/models/word_entry.dart` — `String? imageUrl` (MỘT trường), dùng cho cả
  relative path local (`vocabulary_images/xx.webp`) lẫn URL http.
- `lib/features/vocab_image/`:
  - `vocab_media_type.dart` — phân loại theo đuôi (`.json`/`.lottie` =
    Lottie), `isNetworkMediaUrl`.
  - `vocab_image_service.dart` — lưu/giải path, `pickMediaBytes()` (mới),
    `fetchPreviewBytes()` (mới), `saveFromUrl`.
  - `vocab_image_web_service.dart` — tìm ảnh (Openverse/Commons/Pexels) +
    `download()` + `looksLikeLottieContent()` (mới).
  - `vocab_image_picker_sheet.dart` — sheet 3 nguồn: Trên mạng / Trong máy /
    Dán URL (đã có xem trước cho Dán URL).
  - `vocabulary_media_widget.dart` — render hybrid ảnh/Lottie, local/http,
    materialize nền; `vocab_image_thumbnail.dart` — thumbnail danh sách.
- Nơi tiêu thụ ảnh (phải cập nhật khi có ảnh thứ hai):
  `lib/screens/tools/word_list/word_list_screen.dart` (3 chỗ),
  `single_word_review_screen.dart`, `flashcard_presenter.dart`,
  `lib/features/pdf_reader/.../pdf_word_tap_sheet.dart`.
- Test hiện có: `test/vocab_media_type_test.dart`,
  `test/vocab_image_search_test.dart` (có nhóm `looksLikeLottieContent`).

## 3. Thiết kế đề xuất (chốt trước khi code)

### 3.1 Hai ảnh — additive, không migration

Thêm **trường mới** `String? imageUrl2` vào `WordEntry` (và nơi nào đang
mirror ảnh: `MemoryItem` nếu cần), đọc/ghi trong `toJson`/`fromJson` theo
đúng lối additive đang dùng cho `phoneticSource`:

- `fromJson`: `imageUrl2: json['imageUrl2'] as String?` — dữ liệu cũ ⇒ null.
- `toJson`: chỉ ghi khi khác null (giữ file nhỏ, tương thích ngược).
- **Không** nhồi hai path vào một chuỗi ngăn cách bằng ký tự lạ — mọi nơi
  đang đọc `imageUrl` sẽ hỏng.
- Thêm getter tiện dụng: `List<String> get mediaPaths` (lọc null/rỗng).
- Đồng bộ đám mây/sync: kiểm tra `lib/services/` xem chỗ nào serialize
  `WordEntry` để không rơi trường mới (quy tắc: thêm field ⇒ rà toàn bộ
  serializer).

### 3.2 UI

- Sheet chọn ảnh trả về `VocabImagePickResult` như hiện nay; **người gọi**
  quyết định đặt vào slot 1 hay slot 2.
- Trong màn sửa từ / word list: ô minh hoạ hiển thị tối đa 2 khung; khung
  trống có nút "+" (chỉ hiện khi chưa đủ 2). Mỗi khung có menu: Đổi / Xoá /
  Đặt làm ảnh chính (hoán đổi slot).
- Chỗ chỉ đủ chỗ cho một ảnh (flashcard mặt trước, thumbnail danh sách):
  dùng `imageUrl` (ảnh chính). Ảnh thứ hai xuất hiện ở màn chi tiết / mặt
  sau thẻ. **Không** làm flashcard nặng thêm: Lottie trong danh sách luôn
  `animate: false`.

### 3.3 Duyệt + xem trước thư viện Lottie

- Thêm nguồn thứ tư vào sheet: **"Animation"** — danh sách kết quả dạng lưới,
  mỗi ô là một preview Lottie **chạy nhẹ** (chỉ ô đang hiện trên màn hình
  mới chạy; ngoài khung nhìn ⇒ đứng frame đầu).
- Nguồn dữ liệu: ưu tiên một **endpoint cấu hình được** (như
  `VocabImageApiConfig` đang làm cho ảnh) + ô dán URL có sẵn. **Không**
  hard-code khoá API của bên thứ ba vào repo; không tải gì khi mở app.
- Bấm một ô ⇒ xem trước lớn ⇒ "Lưu vào từ này" (dùng lại
  `fetchPreviewBytes` + `saveFromBytes`, không tải hai lần).

## 4. Việc phải làm

1. ADR ngắn nếu đổi schema `WordEntry` (ghi rõ additive + không migration).
2. Model + serializer + sync.
3. UI hai khung ảnh ở màn sửa từ + hiển thị ảnh phụ ở chi tiết/mặt sau thẻ.
4. Nguồn "Animation" trong sheet + xem trước có kiểm soát hiệu năng.
5. Test thuần: serializer (dữ liệu cũ không có `imageUrl2` vẫn đọc được; ghi
   rồi đọc lại giữ nguyên), `mediaPaths` lọc đúng, hoán đổi ảnh chính.
6. Nối test mới vào `app_analyze.yml` (mẫu bước có `[ -f ]` guard).
7. i18n đủ `en/hi/zh/zh_TW/si`.

## 5. Nghiệm thu

1. Thêm 1 ảnh — mọi màn hình cũ hiển thị y như trước.
2. Thêm ảnh thứ hai — hiện ở chi tiết/mặt sau; danh sách vẫn chỉ 1 thumbnail.
3. Xoá ảnh chính khi có 2 ảnh ⇒ ảnh phụ lên làm ảnh chính, không mất dữ liệu.
4. Mở file dữ liệu cũ (không có `imageUrl2`) ⇒ chạy bình thường.
5. Duyệt danh sách animation: cuộn 50 ô không giật, pin không nóng bất
   thường (chỉ ô đang hiện mới chạy).
6. `flutter analyze` 0 error + test xanh.
