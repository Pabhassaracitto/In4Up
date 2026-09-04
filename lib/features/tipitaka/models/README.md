aka_module.zip (đã present cho bạn xem).

Chỉ cần copy 5 thứ vào E:\PROJECTS\in4up.worktree\DEV\:

    lib/features/tipitaka/ → cả thư mục
    lib/screens/main_shell.dart → đè lên
    pubspec.yaml → thêm sqflite, path (hoặc đè nếu bạn đúng repo gốc)
    scripts/import_tipitaka.py → đè lên
    assets/db/ → giữ nguyên tipitaka.sqlite bạn đã tạo (đừng đè từ zip vì zip không có DB lớn)

Sau đó:

PowerShell

flutter pub get
python scripts\import_tipitaka.py   # chỉ nếu bạn muốn import lại

Rồi chạy app → chạm ⚡ bolt → chọn Tipiṭaka để test.

Nếu pubspec.yaml bạn sợ đè nhầm, chỉ cần thêm 2 dòng vào file hiện có:

YAML

  sqflite: ^2.3.3
  path: ^1.9.0

Muốn tôi viết thêm hướng dẫn cài đặt bước cuối (test trên thiết bị) không?


In4Up
arena/019ff2f6-in4up
Diff

# Tipiṭaka Module — In4Up / in2up

Tích hợp OpenTipitaka (Pa-Auk) vào dự án Flutter.

## Cấu trúc

- `models/`: Collection, Book, Segment (Equatable)
- `services/db_service.dart`: sqflite helper, tạo bảng chuẩn, tìm kiếm LIKE, index
- `screens/`: Library (2 cột), Reader (đọc song ngữ), Search (toàn văn)
- `scripts/import_tipitaka.py`: Import từ SQLite nguồn sang `assets/db/tipitaka.sqlite`

## Chuẩn bị dữ liệu (Windows 11 / VS Code)

1. Tải từ trình duyệt:
   - `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-roman-pali.db.zip`
   - `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/vietnamese_tipitaka_translation_data-2026-04-29.db.zip`
2. Giải nén vào một thư mục, ví dụ `C:\Users\You\Downloads\db_src\`
3. Chỉnh `SOURCE_DIR` trong `scripts/import_tipitaka.py` nếu cần.
4. Chạy:
   ```bash
   python scripts/import_tipitaka.py
   ```
5. Kết quả: `assets/db/tipitaka.sqlite`

## Tích hợp vào ứng dụng

Thêm import và push screen:

```dart
import 'package:in2up/features/tipitaka/tipitaka.dart';
...
Navigator.push(context, MaterialPageRoute(builder: (_) => const TipitakaLibraryScreen()));
```

Hoặc thêm vào `pubspec.yaml` assets nếu muốn bundle DB (chỉ nếu file nhỏ, không khuyên với DB lớn).

## Ghi chú

- DB service hiện dùng `LIKE` cho tìm kiếm; nếu muốn FTS5 (nhanh hơn, typo-tolerant), cần đảm bảo SQLite biên dịch có FTS5 và update schema.
- Module này chưa có `spaced repetition` / `learning`; có thể mở rộng thêm bảng `tipitaka_learning_items` và các UI học tập sau.