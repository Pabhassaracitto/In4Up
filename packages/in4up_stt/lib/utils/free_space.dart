// Dung lượng trống thật của phân vùng chứa thư mục model.
//
// Vì sao cần: Parakeet nặng ~487MB (archive) và ~670MB sau giải nén, Whisper
// large ~1GB. Trước đây `SttModelManager` trả HẰNG SỐ 2048MB nên máy chỉ còn
// vài trăm MB vẫn được phép tải → chết giữa đường, file `.tmp` rác lại càng
// đầy bộ nhớ.
//
// Cách làm: gọi `statvfs(3)` của libc qua `dart:ffi` — POSIX, có sẵn trên
// Android/iOS/Linux/macOS, không cần thêm plugin native. Trên Windows không có
// `statvfs` ⇒ `lookupFunction` ném lỗi, hàm trả `null` ("không biết").
import 'dart:ffi' as ffi;

// package:ffi cung cấp CẢ HAI thứ cần ở đây: `toNativeUtf8()` (extension trên
// String) và kiểu `Utf8` (không nằm trong dart:ffi). Vì vậy import KHÔNG
// `show` — `show` chỉ lọc theo tên khai báo nên extension sẽ biến mất.
import 'package:ffi/ffi.dart';

/// Số byte mỗi MB (dùng chung để tránh lệch đơn vị).
const int kBytesPerMB = 1024 * 1024;

/// Trả về dung lượng còn trống (MB) của phân vùng chứa [dirPath].
///
/// `null` = KHÔNG đo được (nền tảng lạ, `statvfs` lỗi, đường dẫn chưa tồn
/// tại). Nơi gọi phải coi `null` là "không biết" và cho phép tiếp tục, thay vì
/// bịa ra một con số.
int? probeFreeSpaceMB(String dirPath) {
  if (dirPath.isEmpty) return null;
  ffi.Pointer<Utf8>? pathPtr;
  ffi.Pointer<ffi.Uint8>? buffer;
  try {
    final libc = ffi.DynamicLibrary.process();
    final statvfs = libc.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Uint8>),
        int Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Uint8>)>(
      'statvfs',
    );
    // `struct statvfs` mở đầu bằng 5 trường `unsigned long`:
    // f_bsize(0), f_frsize(1), f_blocks(2), f_bfree(3), f_bavail(4).
    // `UintPtr` = `unsigned long` trên cả LP64 (8B) và ILP32 (4B).
    final path = dirPath.toNativeUtf8();
    pathPtr = path;
    final wordSize = ffi.sizeOf<ffi.UintPtr>();
    final buf = calloc<ffi.Uint8>(wordSize * 8);
    buffer = buf;

    if (statvfs(path.cast<ffi.Uint8>(), buf) != 0) return null;

    final words = buf.cast<ffi.UintPtr>();
    final fragmentSize = words[1];
    final availableBlocks = words[4];
    if (fragmentSize <= 0 || availableBlocks <= 0) return null;
    return (fragmentSize * availableBlocks) ~/ kBytesPerMB;
  } catch (_) {
    return null;
  } finally {
    // Bản địa nullable: gán vào biến cục bộ không-null để không phụ thuộc
    // promotion (trước đây analyzer báo `Pointer<Uint8>?` không khớp).
    final pathToFree = pathPtr;
    if (pathToFree != null) malloc.free(pathToFree);
    final bufferToFree = buffer;
    if (bufferToFree != null) calloc.free(bufferToFree);
  }
}
