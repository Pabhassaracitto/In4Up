// lib/models/text_device_entry.dart
// Thư viện đọc (tab Thiết bị) — 1 file văn bản/PDF quét được trong thư mục
// SAF mà user đã chọn. URI là content:// document URI (scoped storage).

class TextDeviceEntry {
  /// Content URI document (content://com.android.externalstorage.documents/...).
  final String uri;

  /// Tên file đầy đủ (kèm extension).
  final String name;

  /// Đường dẫn tương đối trong thư mục đã chọn (nếu native cung cấp).
  final String relativePath;

  final int sizeBytes;
  final DateTime modified;

  /// Extension chữ thường: txt / lrc / srt / md / markdown / json / docx / pdf.
  final String ext;

  /// Tiêu đề hiển thị (không kèm extension) — tính sẵn một lần để tìm kiếm/render
  /// danh sách lớn hàng nghìn mục không cấp phát chuỗi lặp lại trên UI thread.
  final String title;

  /// Chuỗi tra cứu chữ thường đã gộp `title`, `name`, `relativePath`.
  final String searchKey;

  TextDeviceEntry({
    required this.uri,
    required this.name,
    required this.sizeBytes,
    required this.modified,
    required this.ext,
    this.relativePath = '',
  })  : title = _extractTitle(name),
        searchKey = _buildSearchKey(name, relativePath);

  static String _extractTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot >= fileName.length - 1) return fileName;
    return fileName.substring(0, dot);
  }

  static String _buildSearchKey(String fileName, String relPath) {
    final lowerName = fileName.toLowerCase();
    if (relPath.isEmpty) return lowerName;
    return '$lowerName\n${relPath.toLowerCase()}';
  }

  factory TextDeviceEntry.fromMap(Map<String, dynamic> map) {
    return TextDeviceEntry(
      uri: (map['uri'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      relativePath: (map['relativePath'] ?? '').toString(),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      modified: DateTime.fromMillisecondsSinceEpoch(
        (map['dateModifiedMs'] as num?)?.toInt() ?? 0,
      ),
      ext: (map['ext'] ?? '').toString().toLowerCase(),
    );
  }

  /// PSRC-206: parse + sắp xếp toàn bộ danh sách file quét được (chạy được
  /// trong `compute()` trên isolate nền khi thư mục có hàng trăm/nghìn file).
  static List<TextDeviceEntry> parseAndSortEntries(
    List<Map<String, dynamic>> raw,
  ) {
    final parsed = <TextDeviceEntry>[];
    for (final map in raw) {
      final uri = (map['uri'] ?? '').toString();
      if (uri.isEmpty) continue;
      parsed.add(TextDeviceEntry.fromMap(map));
    }
    parsed.sort((a, b) => b.modified.compareTo(a.modified));
    return parsed;
  }

  bool get isPdf => ext == 'pdf';

  /// Emoji thể hiện loại file.
  String get iconEmoji {
    switch (ext) {
      case 'pdf':
        return '📕';
      case 'docx':
        return '📘';
      case 'lrc':
      case 'srt':
        return '🎵';
      case 'json':
        return '🧾';
      case 'md':
      case 'markdown':
        return '📝';
      default:
        return '📄';
    }
  }

  /// "1.2 MB" / "340 KB" / "12 B".
  String get sizeLabel {
    final bytes = sizeBytes.toDouble();
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }

  /// "dd/MM/yyyy".
  String get modifiedLabel {
    final d = modified;
    if (d.millisecondsSinceEpoch == 0) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  /// Dấu dạng "1.2 MB · 05/09/2026 · pdf".
  String get metaLabel {
    final parts = <String>[
      sizeLabel,
      if (modifiedLabel.isNotEmpty) modifiedLabel,
      ext.toUpperCase(),
    ];
    return parts.join(' · ');
  }
}
