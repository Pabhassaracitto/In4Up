// lib/core/files/incoming_file_classifier.dart
//
// PSRC-222 · BETA-1.29.0 (lane L7) — Phân loại thuần cho luồng "Mở bằng in4up"
// (ACTION_VIEW, ACTION_SEND, iOS CFBundleDocumentTypes, tham số dòng lệnh).
//
// Tách hoàn toàn khỏi `dart:io` và Flutter widget để unit test kiểm mọi nhánh:
//   - Nhận diện theo phần mở rộng (`.txt`, `.pdf`, `.docx`, `.md`, `.lrc`, `.srt`,
//     `.mp3`, `.m4a`, `.wav`, `.opus`, `.mp4`, `.mkv`, `.mdx`…).
//   - Rơi về MIME type + chữ ký đầu tệp (`%PDF-`, ZIP `word/document.xml`) khi
//     URI `content://` từ Gmail / Zalo / Drive không kèm đuôi tệp.
//   - Chặn dứt khoát tệp thực thi / gói cài đặt (`.apk`, `.exe`, `.sh`…) dù bên
//     gửi gắn nhầm `text/plain`; báo riêng `.doc` (Word 97–2003) để hướng dẫn
//     đổi sang `.docx` hoặc `.txt`.

enum IncomingFileCategory {
  pdf,
  textDocument,
  audio,
  video,
  dictionary,
  unsupported,
}

enum IncomingUnsupportedReason {
  legacyDoc,
  blockedExecutable,
  unknownFormat,
}

class IncomingFilePayload {
  const IncomingFilePayload({
    required this.localPath,
    required this.displayName,
    this.mimeType,
    this.originalUri,
    this.source = 'external',
  });

  /// Đường dẫn tệp thực trên đĩa (trên Android/iOS đã được chép sang bộ nhớ
  /// riêng của app trước khi quyền tạm của `content://` hết hạn).
  final String localPath;

  /// Tên tệp gốc hiển thị cho người dùng.
  final String displayName;

  /// MIME do hệ điều hành / ContentResolver báo (có thể null).
  final String? mimeType;

  /// URI gốc lúc nhận intent (`content://...` hoặc `file://...`).
  final String? originalUri;

  /// Nguồn mở (`android_view`, `android_send`, `ios_open`, `cli_arg`, `deep_link`).
  final String source;

  static IncomingFilePayload? fromChannelMap(Map<Object?, Object?>? raw) {
    if (raw == null) return null;
    final localPath = (raw['localPath'] as String?)?.trim() ?? '';
    if (localPath.isEmpty) return null;
    final rawName = (raw['displayName'] as String?)?.trim();
    final fallbackName = localPath.replaceAll(r'\', '/').split('/').last;
    return IncomingFilePayload(
      localPath: localPath,
      displayName:
          (rawName != null && rawName.isNotEmpty) ? rawName : fallbackName,
      mimeType: (raw['mimeType'] as String?)?.trim(),
      originalUri: (raw['originalUri'] as String?)?.trim(),
      source: (raw['source'] as String?)?.trim() ?? 'external',
    );
  }
}

class IncomingFileClassification {
  const IncomingFileClassification({
    required this.category,
    this.canonicalExtension,
    this.unsupportedReason,
  });

  final IncomingFileCategory category;

  /// Đuôi tệp chuẩn không dấu chấm (ví dụ `'pdf'`, `'docx'`, `'mp3'`, `'mp4'`).
  final String? canonicalExtension;

  final IncomingUnsupportedReason? unsupportedReason;

  bool get isSupported => category != IncomingFileCategory.unsupported;

  /// Thư mục con nội bộ bền vững theo từng loại tệp.
  String get appStorageSubfolder {
    switch (category) {
      case IncomingFileCategory.pdf:
        return 'in4up_pdfs';
      case IncomingFileCategory.textDocument:
        return 'in4up_texts';
      case IncomingFileCategory.audio:
        return 'audio_imports';
      case IncomingFileCategory.video:
        return 'in4up_videos';
      case IncomingFileCategory.dictionary:
        return 'in4up_dicts';
      case IncomingFileCategory.unsupported:
        return 'in4up_incoming';
    }
  }
}

class IncomingFileClassifier {
  const IncomingFileClassifier._();

  static const Set<String> pdfExtensions = <String>{'pdf'};

  static const Set<String> textDocumentExtensions = <String>{
    'txt',
    'md',
    'markdown',
    'docx',
    'lrc',
    'srt',
    'vtt',
    'json',
  };

  static const Set<String> audioExtensions = <String>{
    'mp3',
    'm4a',
    'm4b',
    'aac',
    'wav',
    'ogg',
    'oga',
    'opus',
    'flac',
    'wma',
  };

  static const Set<String> videoExtensions = <String>{
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
    'm4v',
    '3gp',
    'flv',
    'ts',
    'mpg',
    'mpeg',
    'wmv',
    'ogv',
  };

  static const Set<String> dictionaryExtensions = <String>{
    'mdx',
    'mdd',
  };

  static const Set<String> blockedExtensions = <String>{
    'apk',
    'aab',
    'exe',
    'msi',
    'bat',
    'cmd',
    'com',
    'sh',
    'bash',
    'dmg',
    'pkg',
    'deb',
    'rpm',
    'so',
    'dll',
    'dylib',
    'jar',
    'class',
  };

  /// Phân loại tệp đến từ ngoài ứng dụng.
  static IncomingFileClassification classify({
    String? displayName,
    String? localPath,
    String? originalUri,
    String? mimeType,
    List<int>? headerBytes,
  }) {
    final ext = extractExtension(displayName) ??
        extractExtension(localPath) ??
        extractExtensionFromUri(originalUri);

    if (ext != null) {
      if (ext == 'doc') {
        return const IncomingFileClassification(
          category: IncomingFileCategory.unsupported,
          canonicalExtension: 'doc',
          unsupportedReason: IncomingUnsupportedReason.legacyDoc,
        );
      }
      if (blockedExtensions.contains(ext)) {
        return IncomingFileClassification(
          category: IncomingFileCategory.unsupported,
          canonicalExtension: ext,
          unsupportedReason: IncomingUnsupportedReason.blockedExecutable,
        );
      }
      final byExt = _fromExtension(ext);
      if (byExt != null) return byExt;
    }

    // Không có đuôi rõ ràng (hoặc đuôi tạm `.bin`/`.tmp` từ content provider):
    // kiểm tra chữ ký đầu tệp trước rồi mới tới MIME.
    if (headerBytes != null && headerBytes.isNotEmpty) {
      final sniffed = sniffHeaderBytes(headerBytes);
      if (sniffed != null) return sniffed;
    }

    if (mimeType != null && mimeType.trim().isNotEmpty) {
      final byMime = _fromMimeType(mimeType);
      if (byMime != null) return byMime;
    }

    return const IncomingFileClassification(
      category: IncomingFileCategory.unsupported,
      unsupportedReason: IncomingUnsupportedReason.unknownFormat,
    );
  }

  /// Đảm bảo tên tệp lưu trong bộ nhớ app có đuôi chuẩn khớp phân loại (ví dụ
  /// `attachment` + `'pdf'` → `'attachment.pdf'`).
  static String ensureFileNameHasExtension(
    String rawDisplayName,
    String? canonicalExtension,
  ) {
    final trimmed = rawDisplayName.trim();
    final base = trimmed.isEmpty ? 'in4up_file' : trimmed;
    if (canonicalExtension == null || canonicalExtension.isEmpty) {
      return base;
    }
    final currentExt = extractExtension(base);
    if (currentExt == canonicalExtension.toLowerCase()) {
      return base;
    }
    // Nếu tệp từ provider mang đuôi vô nghĩa kiểu `.bin` hoặc không có đuôi thì
    // gắn đuôi chuẩn để TextSourceLoader / PdfReaderScreen nhận ra ngay.
    if (currentExt == null || currentExt == 'bin' || currentExt == 'tmp') {
      final withoutTmp = currentExt == null
          ? base
          : base.substring(0, base.length - currentExt.length - 1);
      return '$withoutTmp.$canonicalExtension';
    }
    return base;
  }

  /// Đọc chữ ký byte đầu (PDF `%PDF-` hoặc gói OOXML `.docx` chứa `word/`).
  static IncomingFileClassification? sniffHeaderBytes(List<int> bytes) {
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D) {
      return const IncomingFileClassification(
        category: IncomingFileCategory.pdf,
        canonicalExtension: 'pdf',
      );
    }

    // ZIP local file header `PK\x03\x04` có mục `word/` ở đầu ⇒ tệp `.docx`.
    if (bytes.length >= 30 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      final asciiWindow = String.fromCharCodes(
        bytes.take(4096).map((b) => (b >= 32 && b < 127) ? b : 0x20),
      );
      if (asciiWindow.contains('word/')) {
        return const IncomingFileClassification(
          category: IncomingFileCategory.textDocument,
          canonicalExtension: 'docx',
        );
      }
    }
    return null;
  }

  /// Trích tham số tệp từ dòng lệnh Desktop (`in4up /path/to/bai.pdf` hoặc
  /// `file:///path/to/nhac.mp3`), bỏ qua cờ `--...` và link tra từ `in4up://dict`.
  static String? parseCliFilePath(String rawArg) {
    final trimmed = rawArg.trim();
    if (trimmed.isEmpty || trimmed.startsWith('-')) return null;
    if (trimmed.contains('\u0000')) return null;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('in4up://dict') ||
        lower.startsWith('i4u://dict') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return null;
    }

    if (lower.startsWith('in4up://open') || lower.startsWith('i4u://open')) {
      final uri = Uri.tryParse(trimmed);
      final p = uri?.queryParameters['path'] ?? uri?.queryParameters['file'];
      if (p == null || p.trim().isEmpty) return null;
      return p.trim();
    }

    if (lower.startsWith('file://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;
      try {
        final path = uri.toFilePath();
        return path.trim().isEmpty ? null : path;
      } catch (_) {
        return null;
      }
    }

    final looksLikePath = trimmed.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(trimmed) ||
        extractExtension(trimmed) != null;
    if (!looksLikePath) return null;
    return trimmed;
  }

  static String? extractExtension(String? nameOrPath) {
    if (nameOrPath == null || nameOrPath.trim().isEmpty) return null;
    final clean = nameOrPath.trim().replaceAll(r'\', '/');
    final lastSegment = clean.split('/').last;
    final dot = lastSegment.lastIndexOf('.');
    if (dot <= 0 || dot >= lastSegment.length - 1) return null;
    final ext = lastSegment.substring(dot + 1).toLowerCase().trim();
    if (ext.isEmpty || ext.length > 12 || !RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
      return null;
    }
    return ext;
  }

  static String? extractExtensionFromUri(String? rawUri) {
    if (rawUri == null || rawUri.trim().isEmpty) return null;
    final uri = Uri.tryParse(rawUri.trim());
    if (uri == null) return null;
    if (uri.pathSegments.isEmpty) return null;
    final last = Uri.decodeComponent(uri.pathSegments.last);
    return extractExtension(last);
  }

  static IncomingFileClassification? _fromExtension(String ext) {
    if (pdfExtensions.contains(ext)) {
      return IncomingFileClassification(
        category: IncomingFileCategory.pdf,
        canonicalExtension: ext,
      );
    }
    if (textDocumentExtensions.contains(ext)) {
      return IncomingFileClassification(
        category: IncomingFileCategory.textDocument,
        canonicalExtension: ext,
      );
    }
    if (audioExtensions.contains(ext)) {
      return IncomingFileClassification(
        category: IncomingFileCategory.audio,
        canonicalExtension: ext,
      );
    }
    if (videoExtensions.contains(ext)) {
      return IncomingFileClassification(
        category: IncomingFileCategory.video,
        canonicalExtension: ext,
      );
    }
    if (dictionaryExtensions.contains(ext)) {
      return IncomingFileClassification(
        category: IncomingFileCategory.dictionary,
        canonicalExtension: ext,
      );
    }
    return null;
  }

  static IncomingFileClassification? _fromMimeType(String rawMime) {
    final mime = rawMime.split(';').first.trim().toLowerCase();
    if (mime.isEmpty || mime == '*/*' || mime == 'application/octet-stream') {
      return null;
    }
    if (mime == 'application/msword') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.unsupported,
        canonicalExtension: 'doc',
        unsupportedReason: IncomingUnsupportedReason.legacyDoc,
      );
    }
    if (mime == 'application/pdf') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.pdf,
        canonicalExtension: 'pdf',
      );
    }
    if (mime ==
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.textDocument,
        canonicalExtension: 'docx',
      );
    }
    if (mime == 'text/markdown' || mime == 'text/x-markdown') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.textDocument,
        canonicalExtension: 'md',
      );
    }
    if (mime == 'application/x-subrip' || mime == 'text/srt') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.textDocument,
        canonicalExtension: 'srt',
      );
    }
    if (mime == 'text/vtt') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.textDocument,
        canonicalExtension: 'vtt',
      );
    }
    if (mime == 'application/json') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.textDocument,
        canonicalExtension: 'json',
      );
    }
    if (mime.startsWith('text/')) {
      return const IncomingFileClassification(
        category: IncomingFileCategory.textDocument,
        canonicalExtension: 'txt',
      );
    }
    if (mime == 'application/ogg' || mime == 'audio/ogg') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.audio,
        canonicalExtension: 'ogg',
      );
    }
    if (mime == 'audio/opus') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.audio,
        canonicalExtension: 'opus',
      );
    }
    if (mime == 'audio/mp4' || mime == 'audio/x-m4a' || mime == 'audio/m4a') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.audio,
        canonicalExtension: 'm4a',
      );
    }
    if (mime == 'audio/wav' || mime == 'audio/x-wav' || mime == 'audio/wave') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.audio,
        canonicalExtension: 'wav',
      );
    }
    if (mime == 'audio/flac' || mime == 'audio/x-flac') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.audio,
        canonicalExtension: 'flac',
      );
    }
    if (mime.startsWith('audio/')) {
      return const IncomingFileClassification(
        category: IncomingFileCategory.audio,
        canonicalExtension: 'mp3',
      );
    }
    if (mime == 'video/x-matroska') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.video,
        canonicalExtension: 'mkv',
      );
    }
    if (mime == 'video/webm') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.video,
        canonicalExtension: 'webm',
      );
    }
    if (mime == 'video/quicktime') {
      return const IncomingFileClassification(
        category: IncomingFileCategory.video,
        canonicalExtension: 'mov',
      );
    }
    if (mime.startsWith('video/')) {
      return const IncomingFileClassification(
        category: IncomingFileCategory.video,
        canonicalExtension: 'mp4',
      );
    }
    return null;
  }
}
