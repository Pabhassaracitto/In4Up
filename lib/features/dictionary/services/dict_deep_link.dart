// ADR-0018 (P1) — BÓC LINK/TỆP TỪ NGOÀI APP (thuần Dart, không plugin).
//
// Nhiệm vụ: biến một chuỗi bất kỳ đến từ hệ điều hành (link `in4up://…`, một
// dòng `argv`, hay URL `https://`) thành **một yêu cầu rõ ràng** cho app, hoặc
// trả `null` nếu chuỗi đó không phải việc của từ điển.
//
// Vì sao thuần Dart: Android đưa `Intent`, iOS đưa `URL`, Windows/Linux đưa
// `argv` — ba kiểu dữ liệu khác nhau nhưng cùng phải qua **một** chỗ kiểm tra
// an toàn. Tách khỏi Flutter ⇒ test được cả ma trận link xấu trên CI mà không
// cần thiết bị (xem `test/dictionary/dict_deep_link_test.dart`).
//
// Quy tắc an toàn (theo ADR-0018):
//   - Từ cần tra ≤ 64 ký tự, bỏ ký tự điều khiển (link từ web có thể chứa
//     `\n`, NUL…).
//   - Mở TỆP chỉ với đuôi app thật sự đọc được: mdx · mdd · pdf · txt · md ·
//     markdown · epub. **Không** nhận `*/*`.
//   - Đường dẫn chứa `..` hoặc rỗng ⇒ từ chối (link không được phép chỉ tới
//     chỗ tuỳ ý ngoài ý người dùng).
//   - Không ném exception trong mọi trường hợp — đầu vào là dữ liệu lạ.

/// Loại việc mà một link/tệp yêu cầu.
enum DictDeepLinkKind {
  /// Tra một từ có sẵn: `in4up://dict?w=ubiquitous`.
  word,

  /// Mở một tệp trên máy: `in4up://open?path=/sdcard/x.mdx` (P3 — mới bóc link).
  file,
}

/// Kết quả bóc link. Bất biến, không phụ thuộc Flutter.
class DictDeepLinkRequest {
  final DictDeepLinkKind kind;

  /// Từ cần tra (`kind == word`) hoặc đường dẫn tệp (`kind == file`).
  final String value;

  /// Nhãn nguồn để đi vào lịch sử/nhật ký: `deep_link` · `file` · `argv`.
  final String source;

  const DictDeepLinkRequest({
    required this.kind,
    required this.value,
    required this.source,
  });

  bool get isWord => kind == DictDeepLinkKind.word;

  @override
  String toString() => 'DictDeepLinkRequest($kind, $value, $source)';

  @override
  bool operator ==(Object other) =>
      other is DictDeepLinkRequest &&
      other.kind == kind &&
      other.value == value &&
      other.source == source;

  @override
  int get hashCode => Object.hash(kind, value, source);
}

class DictDeepLink {
  DictDeepLink._();

  /// Giới hạn độ dài từ — link dài bất thường là dấu hiệu tấn công/lỗi.
  static const int maxWordLength = 64;

  /// Đuôi tệp app mở được. Cố ý KHÔNG có `*/*`.
  static const Set<String> allowedFileExtensions = <String>{
    'mdx',
    'mdd',
    'pdf',
    'txt',
    'md',
    'markdown',
    'epub',
  };

  /// Scheme riêng của app.
  static const Set<String> appSchemes = <String>{'in4up', 'i4u'};

  /// Host của web link (chấp nhận sẵn để sau này chỉ cần đặt file tĩnh
  /// `assetlinks.json`/`.well-known` trên domain).
  static const Set<String> httpsHosts = <String>{
    'in4up.app',
    'www.in4up.app',
  };

  /// Bóc một chuỗi (link hoặc đường dẫn tệp). Trả `null` nếu không liên quan.
  ///
  /// `source` cho phép nơi gọi ghi rõ nguồn (`deep_link`, `file`, `argv`).
  static DictDeepLinkRequest? parse(String raw, {String source = 'deep_link'}) {
    final cleaned = _stripControl(raw).trim();
    if (cleaned.isEmpty) return null;

    // Windows: `C:\x.mdx` bị `Uri.parse` hiểu thành scheme `c` ⇒ nhận diện
    // đường dẫn trước khi parse URI.
    if (_looksLikeWindowsPath(cleaned)) {
      return _fileRequest(cleaned, source);
    }

    Uri? uri;
    try {
      uri = Uri.parse(cleaned);
    } catch (_) {
      uri = null;
    }

    if (uri == null) return _fileRequest(cleaned, source);

    final scheme = uri.scheme.toLowerCase();

    if (appSchemes.contains(scheme)) {
      return _fromAppUri(uri, source);
    }

    if (scheme == 'file') {
      // `file:///sdcard/x.mdx` — bỏ qua host (thường rỗng hoặc `localhost`).
      final path = uri.path;
      return _fileRequest(path, source);
    }

    if ((scheme == 'https' || scheme == 'http') &&
        httpsHosts.contains(uri.host.toLowerCase())) {
      return _fromHttpsUri(uri, source);
    }

    // Không có scheme ⇒ có thể là đường dẫn tuyệt đối do argv đưa vào
    // (`in4up.exe "C:\x.mdx"`).
    if (scheme.isEmpty) {
      final path = uri.path;
      if (path.isEmpty) return null;
      return _fileRequest(path, source);
    }

    return null;
  }

  /// Bóc một danh sách tham số dòng lệnh (Windows/Linux `argv`).
  ///
  /// Bỏ qua cờ (`--foo`), trả yêu cầu ĐẦU TIÊN hợp lệ — đủ cho
  /// `in4up.exe "C:\a.mdx"` và cho `in4up in4up://dict?w=hello` khi thiết bị
  /// chưa có handler.
  static DictDeepLinkRequest? parseArguments(List<String> args) {
    for (final arg in args) {
      if (arg.isEmpty || arg.startsWith('-')) continue;
      final request = parse(arg, source: 'argv');
      if (request != null) return request;
    }
    return null;
  }

  /// Bóc link có scheme của app: `in4up://dict?w=…`, `in4up://open?path=…`.
  static DictDeepLinkRequest? _fromAppUri(Uri uri, String source) {
    final host = uri.host.toLowerCase();
    if (host == 'dict' || host == 'dictionary' || host == 'lookup') {
      return _wordRequest(
        _firstQueryValue(uri, const ['w', 'word', 'q', 'text']),
        source,
      );
    }
    if (host == 'open') {
      return _fileRequest(
        _firstQueryValue(uri, const ['path', 'file', 'url']),
        source,
      );
    }
    // `in4up://?w=…` (một số trình tạo link bỏ host) — vẫn nhận nếu có `w`.
    if (host.isEmpty) {
      return _wordRequest(
        _firstQueryValue(uri, const ['w', 'word', 'q', 'text']),
        source,
      );
    }
    return null;
  }

  /// `https://in4up.app/dict?w=…` — cùng hợp đồng với link riêng.
  static DictDeepLinkRequest? _fromHttpsUri(Uri uri, String source) {
    final segments = uri.pathSegments
        .map((segment) => segment.toLowerCase())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;
    final head = segments.first;
    if (head == 'dict' || head == 'dictionary' || head == 'lookup') {
      return _wordRequest(
        _firstQueryValue(uri, const ['w', 'word', 'q', 'text']),
        source,
      );
    }
    if (head == 'open') {
      return _fileRequest(
        _firstQueryValue(uri, const ['path', 'file', 'url']),
        source,
      );
    }
    return null;
  }

  static DictDeepLinkRequest? _wordRequest(String? raw, String source) {
    final word = normalizeWord(raw);
    if (word == null) return null;
    return DictDeepLinkRequest(
      kind: DictDeepLinkKind.word,
      value: word,
      source: source,
    );
  }

  static DictDeepLinkRequest? _fileRequest(String? raw, String source) {
    final path = normalizeFilePath(raw);
    if (path == null) return null;
    return DictDeepLinkRequest(
      kind: DictDeepLinkKind.file,
      value: path,
      source: source,
    );
  }

  /// Chuẩn hoá từ cần tra. `null` = không dùng được.
  ///
  /// - Bỏ ký tự điều khiển, gộp khoảng trắng;
  /// - ≤ [maxWordLength] ký tự (tính theo rune để không cắt giữa ký tự
  ///   Unicode — chữ Việt có dấu là 1 rune, emoji có thể nhiều);
  /// - Rỗng ⇒ `null`.
  static String? normalizeWord(String? raw) {
    if (raw == null) return null;
    final cleaned = _stripControl(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.runes.length > maxWordLength) return null;
    return cleaned;
  }

  /// Chuẩn hoá đường dẫn tệp. `null` = không dùng được.
  static String? normalizeFilePath(String? raw) {
    if (raw == null) return null;
    var path = _stripControl(raw).trim();
    if (path.isEmpty) return null;
    // Bỏ `file://` nếu nơi gọi chưa tách (tiện cho argv trên Linux).
    if (path.toLowerCase().startsWith('file://')) {
      path = path.substring('file://'.length);
    }
    if (path.isEmpty) return null;
    // Link không được phép trỏ lung tung.
    final segments = path.split(RegExp(r'[\\/]+'));
    if (segments.any((segment) => segment == '..')) return null;
    final ext = fileExtension(path);
    if (ext == null || !allowedFileExtensions.contains(ext)) return null;
    return path;
  }

  /// Đuôi tệp (chữ thường, không kèm dấu chấm) của [path]; `null` nếu không có.
  static String? fileExtension(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  static String? _firstQueryValue(Uri uri, List<String> keys) {
    for (final key in keys) {
      final value = uri.queryParameters[key];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static bool _looksLikeWindowsPath(String value) =>
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);

  /// Bỏ ký tự điều khiển (NUL, xuống dòng, ESC…) — dữ liệu từ ngoài app.
  static String _stripControl(String value) {
    if (!value.runes.any((rune) => rune < 0x20 || rune == 0x7F)) return value;
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune < 0x20 || rune == 0x7F) continue;
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }
}
