// lib/features/pdf_reader/services/pdf_file_identity.dart
//
// Định danh BỀN của một file PDF.
//
// Bài toán cũ: mọi ghi chú + trang đọc cuối bị khoá theo `pdfPath.hashCode`
// (32 bit) → hai file khác nhau có thể đụng khoá, và chỉ cần đổi tên / chuyển
// thư mục là mất sạch dữ liệu đọc. ReadEra giải quyết bằng cách không dính
// đường dẫn: họ giữ trạng thái theo chính file, nên "xoá file rồi tải lại vẫn
// tiếp tục đúng trang đã đọc".
//
// Cách của ta (không cần đọc nội dung file cho mỗi lần mở):
//   • primaryKey = md5(kích thước | mtime)  → bất biến khi file DI CHUYỂN /
//     ĐỔI TÊN (thông tin này đi theo file, không theo đường dẫn).
//   • pathKey    = md5(đường dẫn chuẩn hoá) → dùng làm khoá dự phòng khi file
//     không còn truy cập được (permission, sandbox, file trên thẻ nhớ rút ra).
//   • legacyKey  = khoá cũ theo hashCode    → chỉ để DỜI dữ liệu cũ sang
//     khoá mới một lần (xem PdfAnnotationStorage.migrateLegacy).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:in4up/utils/audio_source_identity.dart';

class PdfFileIdentity {
  const PdfFileIdentity({
    required this.path,
    required this.primaryKey,
    required this.pathKey,
    required this.legacyKey,
    required this.hasStat,
  });

  /// Đường dẫn gốc khi mở (không chuẩn hoá — vẫn cần để đọc file).
  final String path;

  /// Khoá chính dùng để lưu/ngâm mọi dữ liệu đọc của file này.
  final String primaryKey;

  /// Khoá chỉ theo đường dẫn — ổn định, không cần chạm ổ đĩa.
  final String pathKey;

  /// Phần đuôi của khoá di sản (`pdf_<legacyKey>_annotations`,
  /// `last_page_<legacyKey>`) — chỉ dùng để dời dữ liệu cũ.
  final String legacyKey;

  /// `true` khi lấy được stat (kích thước/ctime) → `primaryKey` bền vững.
  final bool hasStat;

  static final Map<String, PdfFileIdentity> _cache = <String, PdfFileIdentity>{};

  /// Đọc stat một lần rồi nhớ lại cho cả phiên.
  static Future<PdfFileIdentity> resolve(String pdfPath) async {
    final cached = _cache[pdfPath];
    if (cached != null) return cached;
    final identity = _compute(pdfPath);
    _cache[pdfPath] = identity;
    return identity;
  }

  /// Phiên bản đồng bộ (dùng trong test / khi đã biết không có IOblocking).
  static PdfFileIdentity resolveSync(String pdfPath) =>
      _cache[pdfPath] ?? _compute(pdfPath);

  static PdfFileIdentity _compute(String pdfPath) {
    final pathKey = hashPath(pdfPath);
    final legacyKey = legacyKeyFor(pdfPath);
    var primaryKey = pathKey;
    var hasStat = false;
    try {
      final file = File(pdfPath);
      if (file.existsSync()) {
        final stat = file.statSync();
        primaryKey = _hash(
          '${stat.size}|${stat.modified.millisecondsSinceEpoch}',
        );
        hasStat = true;
      }
    } catch (_) {
      // Sandbox/permission/rút thẻ nhớ — đường dẫn vẫn là khoá đủ dùng.
      hasStat = false;
    }
    return PdfFileIdentity(
      path: pdfPath,
      primaryKey: primaryKey,
      pathKey: pathKey,
      legacyKey: legacyKey,
      hasStat: hasStat,
    );
  }

  /// Bỏ cache (test, hoặc khi file vừa được copy sang vị trí mới).
  static void forget([String? pdfPath]) {
    if (pdfPath == null) {
      _cache.clear();
    } else {
      _cache.remove(pdfPath);
    }
  }

  static String hashPath(String pdfPath) => _hash(normalizePath(pdfPath));

  /// Đuôi khoá của code cũ — giữ nguyên công thức để còn đọc được dữ liệu cũ.
  /// Storage ghép thành `pdf_<đuôi>_annotations` và `last_page_<đuôi>`.
  static String legacyKeyFor(String pdfPath) => '${pdfPath.hashCode.abs()}';

  /// Chuẩn hoá bằng đúng phép chuẩn hoá nguồn của repo (`AudioSourceIdentity`):
  /// separator về `/`, trim, lowercase và percent-decode URI do file picker trả
  /// về (`file:///Docs/My%20Book.pdf`). Trước đây thiếu percent-decode nên cùng
  /// một file mở bằng hai cách cho hai khoá khác nhau → mất vị trí đọc/annotation.
  /// Đánh đổi: hai file chỉ khác hoa/thường trên Linux/macOS sẽ chung khoá — hy
  /// hữu, và đồng nhất với cách app nhận diện nguồn audio.
  ///
  /// TODO(pdf-reader): tách AudioSourceIdentity thành SourcePathIdentity chung
  /// khi có người dùng thứ ba; giữ một định nghĩa duy nhất đến lúc đó.
  static String normalizePath(String path) {
    final normalized = AudioSourceIdentity.normalize(path);
    return normalized.isEmpty ? 'pdf' : normalized;
  }

  static String _hash(String input) =>
      md5.convert(utf8.encode(input)).toString().substring(0, 16);
}

/// Tên file, chấp nhận cả `/` (Android/iOS/macOS/Linux) và `\` (Windows).
///
/// Legacy bug: controller cắt `split('/')` còn screen cắt
/// `split(Platform.pathSeparator)`. Trên Windows hai bên ra kết quả khác nhau
/// → `VocabContext.sourceName` (toàn bộ đường dẫn) không khớp `pdfFileName`
/// (basename) → panel "từ đã lưu của file này" liệt. Dùng helper này ở CẢ HAI
/// phía là đóng được lỗ đó.
String pdfBaseName(String path) {
  final normalized = path.replaceAll(r'\', '/');
  var end = normalized.length;
  while (end > 0 && normalized[end - 1] == '/') {
    end--;
  }
  if (end == 0) return '';
  final start = normalized.lastIndexOf('/', end - 1) + 1;
  return normalized.substring(start, end);
}

/// Tên ngắn để hiển thị trong toolbar/snackbar (lược bỏ phần mở rộng).
String pdfDisplayName(String path, {int maxLength = 42}) {
  var name = pdfBaseName(path);
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  if (name.length <= maxLength) return name;
  return '${name.substring(0, maxLength - 1)}…';
}

/// So khớp "nguồn đã lưu" (VocabContext.sourceName / fileName) với file đang mở.
///
/// Dữ liệu cũ lưu lẫn lộn hai dạng: toàn bộ đường dẫn (module knowledge) hoặc
/// chỉ basename (toolbar PDF). Vì vậy thứ tự so khớp là: thô -> chuẩn hoá ->
/// basename đã chuẩn hoá. Nhờ thế một từ đã lưu vẫn hiện đúng trong panel "từ
/// đã lưu của file này" cả khi file đổi tên/đổi thư mục hay tên có `%20`.
///
/// Cẩn thận: khớp theo basename nghĩa là hai file cùng tên ở hai thư mục được coi
/// là một. Đó là đổi lại có chủ đích (đọc tiếp mạch lạc), và panel chỉ hiển thị
/// danh sách từ nên mức hại là thấp.
bool pdfSourceMatches(String storedSourceName, String currentPath) {
  if (storedSourceName.isEmpty || currentPath.isEmpty) return false;
  if (storedSourceName == currentPath) return true;
  if (PdfFileIdentity.normalizePath(storedSourceName) ==
      PdfFileIdentity.normalizePath(currentPath)) {
    return true;
  }
  final storedName =
      PdfFileIdentity.normalizePath(pdfBaseName(storedSourceName));
  final currentName = PdfFileIdentity.normalizePath(pdfBaseName(currentPath));
  return storedName.isNotEmpty && storedName == currentName;
}
