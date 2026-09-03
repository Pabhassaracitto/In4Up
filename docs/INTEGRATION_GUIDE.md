# Hướng dẫn nhanh cho bạn (Windows 11 / VS Code / Flutter)

## 1. Dự án đã được xác nhận
Repo: `Pabhassaracitto/In4Up` → nhánh `arena/019ff2f6-in4up`. Stack: Flutter (`pubspec.yaml` tên `in2up`), có các package `in2up_core`, `in2up_ai`, `in2up_stt`. Tôi đã thêm module `lib/features/tipitaka/` và cập nhật `pubspec.yaml` (`sqflite`, `path`).

## 2. Tại sao tôi không tải DB được?
Server `dhamma.paauksociety.org` từ chối kết nối TLS từ curl / Python trong sandbox (lỗi SSL handshake). Nhưng `fetch_page` (trình duyệt) đọc được trang danh sách. Do đó bạn **phải tải bằng trình duyệt trên Windows 11**.

## 3. Bạn cần làm gì (chi tiết từng bước)

### A. Tải dữ liệu (bằng trình duyệt)
Mở các liên kết sau trên Chrome / Edge:
- Pali (Roman): `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-roman-pali.db.zip`
- Tiếng Việt: `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/vietnamese_tipitaka_translation_data-2026-04-29.db.zip`
- (Tùy chọn) Tiếng Anh: `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/english_tipitaka_translation_data-2026-04-28.db.zip`

Lưu vào `C:\Users\<Bạn>\Downloads\tipitaka_db\` (tạo thư mục).

### B. Giải nén
Dùng WinRAR / 7-Zip / Windows Explorer giải nén các `.zip` → bạn sẽ có các `.db` (có thể tên dài).

### C. Đặt file vào workspace (cách gửi cho tôi / cho script)
Cách 1 — Cho tôi xử lý: Copy file `.db` đã giải nén vào thư mục `/home/user/In4Up/assets/db/` (trong workspace này). Nếu bạn có thể tải file lên chat (attach file), tôi sẽ tự động đặt vào đó.
Cách 2 — Tự chạy trên Windows: Để file `.db` tại `C:\tipitaka_src\` và sửa `SOURCE_DIR` trong `scripts/import_tipitaka.py`.

### D. Chạy import
Nếu bạn để file trong workspace:
```bash
# Từ thư mục gốc repo (trong VS Code terminal hoặc Git Bash)
python scripts/import_tipitaka.py
```
Kết quả: `assets/db/tipitaka.sqlite` (DB chuẩn hóa cho Flutter).

Nếu bạn tự chạy trên Windows:
```cmd
python scripts\import_tipitaka.py
```

Nếu DB nguồn có tên bảng / cột khác, tôi cần bạn cho tôi xem 2-3 dòng đầu từ bảng bằng **DB Browser for SQLite** (miễn phí trên Windows). Tôi sẽ cập nhật `import_tipitaka.py` ngay.

### E. Tích hợp vào Flutter (mã tôi đã viết sẵn)
Tôi đã tạo các màn hình:
- `lib/features/tipitaka/screens/library_screen.dart` — cây Piṭaka (Vinaya / Sutta / Abhidhamma) → sách (DN MN SN AN...). Nhấn mở sách → hiển thị đoạn đọc.
- `lib/features/tipitaka/screens/reader_screen.dart` — đọc Pāli + bản dịch Việt + Anh, có nút bookmark / ghi chú, nút trước/sau đoạn.
- `lib/features/tipitaka/screens/search_screen.dart` — tìm kiếm toàn văn từ khóa.
- `lib/features/tipitaka/services/db_service.dart` — mở SQLite, tạo bảng chuẩn, tìm kiếm `LIKE`, index.

Bạn chỉ cần thêm vào route/menu chính (ví dụ trong `main_shell.dart` hoặc màn hình chủ):
```dart
import 'package:in2up/features/tipitaka/tipitaka.dart';
...
Navigator.push(context, MaterialPageRoute(builder: (_) => const TipitakaLibraryScreen()));
```

## 4. Ba điều tôi cần bạn xác nhận để hoàn thiện tiếp
1. **Ngôn ngữ DB**: Bạn muốn dùng Pali (Roman) + Tiếng Việt? Hay thêm Anh / Miến / Thái? (Tôi đã để chỗ cho nhiều ngôn ngữ trong schema).
2. **Mức tích hợp trước**: Chỉ đọc + tìm kiếm + bookmark? Hay thêm ngay **học thuộc / spaced repetition / câu hỏi tự động** (tôi có thể thêm bảng `tipitaka_learning_items` và UI flashcard)?
3. **DB nguồn**: Bạn có muốn tôi tự tải và xử lý nếu bạn upload file `.db` vào workspace, hay bạn tự chạy `python` trên Windows?

## 5. Cách theo dõi tiến độ
- Mọi file mới nằm trong `lib/features/tipitaka/` và `scripts/`.
- Tôi sẽ `git commit` lên nhánh `arena/019ff2f6-in4up` sau mỗi bước quan trọng.
- Nếu bạn muốn xem trực tiếp, bạn có thể mở file `lib/features/tipitaka/README.md` trong VS Code.

## 6. Lưu ý kỹ thuật (để bạn tránh lỗi)
- `sqflite` đã thêm vào `pubspec.yaml`; sau khi tôi commit, bạn chạy `flutter pub get` để tải package.
- DB lớn (`tipitaka.sqlite` có thể 200-500MB sau merge) **không nên bundle trong `assets/`** cho app production; tốt nhất là download về thư mục ứng dụng (`getApplicationDocumentsDirectory`) khi người dùng mở app lần đầu, hoặc bạn copy thủ công vào thiết bị qua ADB / file manager.
- Tôi chưa thêm `spaced repetition`; nếu muốn, hãy nói tôi, tôi sẽ thêm bảng `learning_items` và UI ôn tập ngay.

---
**Tóm lại**: Bạn tải 2 file zip bằng trình duyệt → giải nén → cho tôi biết vị trí file hoặc đặt vào `assets/db/` → chạy `python scripts/import_tipitaka.py` → tôi hoàn thiện UI học tập nếu bạn xác nhận. Tôi đã sẵn sàng viết tiếp ngay khi bạn trả lời 3 câu hỏi trên.