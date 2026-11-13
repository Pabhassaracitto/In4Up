// lib/core/files/export_destination.dart
//
// PSRC-204 · ADR-0029 — Mô hình thuần & chính sách chọn nơi lưu mặc định +
// "Đổi…" từng lần xuất.
//
// File này KHÔNG import `dart:io` hay plugin Flutter để unit test thuần chạy
// dưới 1 giây trên VM và chứng minh mọi nhánh quyết định của ADR-0029:
//   1. Mặc định theo nền tảng:
//        - Android 10+ (API ≥ 29): MediaStore.Downloads (`Download/In4Up`)
//        - Android ≤ 9 (API ≤ 28): thư mục Downloads công khai (`Download/In4Up`)
//        - iOS: `Documents/In4Up` (hiện trong Files → `On My iPhone/In4Up`)
//        - Windows / Linux / macOS: `<Downloads>/In4Up` (dự phòng `~/In4Up`)
//   2. Bấm "Đổi…" mà KHÔNG tick "Luôn lưu vào thư mục này":
//        - Chỉ áp dụng cho lần xuất hiện tại; phiên xuất kế tiếp quay về mặc định.
//   3. Bấm "Đổi…" VÀ tick "Luôn lưu vào thư mục này":
//        - Ghi nhớ làm mặc định của hồ sơ cho những lần xuất sau.
//   4. Thư mục đã ghi nhớ bị xoá hoặc mất quyền SAF:
//        - Tự quay về mặc định gốc của nền tảng, xoá cấu hình hỏng để chỉ báo
//          MỘT lần duy nhất (không văng lỗi, không im lặng nuốt file).
//   5. Trùng tên file ⇒ thêm hậu tố ` (2)`, ` (3)`… không bao giờ ghi đè.

/// Tên thư mục xuất công khai thống nhất trên cả 4 nền tảng (ADR-0029 § 6.1).
const String kIn4UpPublicFolderName = 'In4Up';

/// Phân loại đích lưu thực tế để tầng I/O chọn đúng cơ chế ghi.
enum ExportDestinationKind {
  /// Android 10+ (API ≥ 29): ghi qua `MediaStore.Downloads` (`IS_PENDING` → 0),
  /// không cần xin bất kỳ quyền lưu trữ nào.
  androidMediaStoreDownloads,

  /// Android 9 trở xuống (API ≤ 28): thư mục `DIRECTORY_DOWNLOADS/In4Up`.
  androidLegacyDownloads,

  /// Android SAF `ACTION_OPEN_DOCUMENT_TREE` (`content://.../tree/...`).
  androidSafTree,

  /// iOS `Documents/In4Up` — hiển thị tại `Files → On My iPhone/In4Up` nhờ
  /// `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`.
  iosDocumentsFolder,

  /// Đường dẫn thư mục thực trên hệ thống tệp (Windows, Linux, macOS, hoặc
  /// thư mục tuỳ chọn do `FilePicker.getDirectoryPath` trả về).
  directoryPath,
}

/// Đích xuất đã chuẩn hoá để cả UI ("Lưu vào: …") và tầng I/O dùng chung.
class ExportDestination {
  const ExportDestination({
    required this.kind,
    required this.location,
    required this.displayPath,
    this.isBuiltInDefault = false,
  });

  final ExportDestinationKind kind;

  /// Định danh kỹ thuật:
  /// - `androidMediaStoreDownloads`: `'Download/In4Up'`
  /// - `androidSafTree`: chuỗi `content://...` của tree URI
  /// - các loại còn lại: đường dẫn tuyệt đối của thư mục trên hệ thống tệp
  final String location;

  /// Chuỗi đường dẫn thân thiện cho người dùng đọc trong hộp thoại xuất &
  /// thông báo sau khi lưu (ví dụ `'Download/In4Up'`, `'On My iPhone/In4Up'`,
  /// `'~/Downloads/In4Up'`).
  final String displayPath;

  /// `true` nếu đây là nơi lưu mặc định gốc của nền tảng (chưa đổi bằng SAF /
  /// thư mục riêng).
  final bool isBuiltInDefault;

  bool get isSafTree => kind == ExportDestinationKind.androidSafTree;

  bool get isMediaStore =>
      kind == ExportDestinationKind.androidMediaStoreDownloads;

  ExportDestination copyWith({
    ExportDestinationKind? kind,
    String? location,
    String? displayPath,
    bool? isBuiltInDefault,
  }) {
    return ExportDestination(
      kind: kind ?? this.kind,
      location: location ?? this.location,
      displayPath: displayPath ?? this.displayPath,
      isBuiltInDefault: isBuiltInDefault ?? this.isBuiltInDefault,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.name,
        'location': location,
        'displayPath': displayPath,
        'isBuiltInDefault': isBuiltInDefault,
      };

  static ExportDestination? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final rawKind = json['kind'];
    final location = json['location'];
    final displayPath = json['displayPath'];
    if (rawKind is! String || location is! String || displayPath is! String) {
      return null;
    }
    if (location.trim().isEmpty || displayPath.trim().isEmpty) {
      return null;
    }
    ExportDestinationKind? parsedKind;
    for (final candidate in ExportDestinationKind.values) {
      if (candidate.name == rawKind) {
        parsedKind = candidate;
        break;
      }
    }
    if (parsedKind == null) return null;
    return ExportDestination(
      kind: parsedKind,
      location: location,
      displayPath: displayPath,
      isBuiltInDefault: json['isBuiltInDefault'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExportDestination &&
          other.kind == kind &&
          other.location == location &&
          other.displayPath == displayPath &&
          other.isBuiltInDefault == isBuiltInDefault);

  @override
  int get hashCode =>
      Object.hash(kind, location, displayPath, isBuiltInDefault);

  @override
  String toString() =>
      'ExportDestination(${kind.name}, location: $location, display: $displayPath)';
}

/// Kết quả phân giải nơi lưu mặc định trước khi mở hộp thoại xuất.
class ExportDestinationResolution {
  const ExportDestinationResolution({
    required this.destination,
    this.fellBackToBuiltInDefault = false,
    this.deadDestinationDisplayPath,
  });

  /// Đích mặc định đang có hiệu lực cho phiên xuất này.
  final ExportDestination destination;

  /// `true` đúng MỘT lần khi thư mục tuỳ chọn đã lưu trước đó không còn truy
  /// cập được (bị xoá trong Files hoặc bị thu hồi quyền SAF) và hệ thống đã tự
  /// quay về mặc định gốc của nền tảng.
  final bool fellBackToBuiltInDefault;

  /// Nhãn của thư mục cũ vừa mất quyền để UI thông báo rõ cho người dùng.
  final String? deadDestinationDisplayPath;
}

/// Trạng thái chọn đích của riêng MỘT lần mở hộp thoại xuất.
///
/// Tách thành đối tượng riêng để đảm bảo việc bấm "Đổi…" không rò rỉ sang lần
/// xuất kế tiếp trừ khi người dùng chủ động bật [rememberAsDefault].
class ExportDestinationSession {
  ExportDestinationSession({
    required this.resolution,
    this.overrideDestination,
    this.rememberAsDefault = false,
  });

  final ExportDestinationResolution resolution;
  ExportDestination? overrideDestination;
  bool rememberAsDefault;

  /// Đích thực tế sẽ dùng khi bấm nút "Xuất".
  ExportDestination get effectiveDestination =>
      overrideDestination ?? resolution.destination;

  /// Người dùng đã bấm "Đổi…" trong hộp thoại hiện tại hay chưa.
  bool get hasOverride => overrideDestination != null;

  /// Gán thư mục mới cho riêng lần xuất này. Mặc định KHÔNG tích ghi nhớ để
  /// lần xuất sau quay lại mặc định (đúng tiêu chí nghiệm thu PSRC-204).
  void selectOverride(ExportDestination picked) {
    if (picked.kind == resolution.destination.kind &&
        picked.location == resolution.destination.location) {
      overrideDestination = null;
      rememberAsDefault = false;
      return;
    }
    overrideDestination = picked.copyWith(isBuiltInDefault: false);
    rememberAsDefault = false;
  }

  /// Bỏ lựa chọn tạm thời trong phiên hiện tại để quay lại mặc định đang lưu.
  void clearOverride() {
    overrideDestination = null;
    rememberAsDefault = false;
  }
}

/// Kho lưu trữ cấu hình đích xuất mặc định của người dùng (tách khỏi
/// `SharedPreferences` để test thuần không cần mock channel).
abstract class ExportDestinationStore {
  Future<ExportDestination?> readCustomDefault();
  Future<void> writeCustomDefault(ExportDestination destination);
  Future<void> clearCustomDefault();
}

/// Kho lưu trong bộ nhớ phục vụ unit test thuần.
class InMemoryExportDestinationStore implements ExportDestinationStore {
  ExportDestination? _saved;

  @override
  Future<ExportDestination?> readCustomDefault() async => _saved;

  @override
  Future<void> writeCustomDefault(ExportDestination destination) async {
    _saved = destination;
  }

  @override
  Future<void> clearCustomDefault() async {
    _saved = null;
  }
}

/// Kết quả sau khi ghi 1 tệp vào đích xuất.
class ExportSavedFile {
  const ExportSavedFile({
    required this.fileName,
    required this.displayPath,
    required this.destination,
    this.localPath,
    this.uri,
  });

  /// Tên tệp cuối cùng (đã xử lý trùng tên ` (2)`, ` (3)` nếu có).
  final String fileName;

  /// Đường dẫn hiển thị cho người dùng (ví dụ `Download/In4Up/clip (2).mp3`).
  final String displayPath;

  /// Đích xuất đã nhận tệp.
  final ExportDestination destination;

  /// Đường dẫn tệp cục bộ trên hệ thống tệp nếu đọc trực tiếp được bằng `File`.
  final String? localPath;

  /// URI gốc (`content://...` hoặc `file://...`) trả về từ tầng hệ điều hành.
  final String? uri;
}

/// Toàn bộ quy tắc thuần của ADR-0029 cho việc chọn đích, đặt tên không đè và
/// chuẩn hoá nhãn hiển thị.
class ExportDestinationPolicy {
  ExportDestinationPolicy({
    required this.store,
    required this.builtInDefaultProvider,
    required this.isDestinationAccessible,
  });

  final ExportDestinationStore store;
  final Future<ExportDestination> Function() builtInDefaultProvider;
  final Future<bool> Function(ExportDestination destination)
      isDestinationAccessible;

  /// Phân giải đích lưu mặc định hiện hành để khởi tạo hộp thoại xuất.
  ///
  /// Nếu người dùng từng lưu một thư mục riêng ("Luôn lưu vào thư mục này")
  /// nhưng thư mục đó đã bị xoá hoặc thu hồi quyền SAF:
  ///   - xoá cấu hình hỏng trong [store]
  ///   - trả về mặc định gốc của nền tảng kèm `fellBackToBuiltInDefault = true`
  ///   - lần mở hộp thoại tiếp theo sẽ KHÔNG còn báo lặp lại nữa.
  Future<ExportDestinationResolution> resolveDefault() async {
    final builtIn = await builtInDefaultProvider();
    final custom = await store.readCustomDefault();
    if (custom == null) {
      return ExportDestinationResolution(destination: builtIn);
    }

    bool accessible = false;
    try {
      accessible = await isDestinationAccessible(custom);
    } catch (_) {
      accessible = false;
    }

    if (!accessible) {
      await store.clearCustomDefault();
      return ExportDestinationResolution(
        destination: builtIn,
        fellBackToBuiltInDefault: true,
        deadDestinationDisplayPath: custom.displayPath,
      );
    }

    return ExportDestinationResolution(
      destination: custom.copyWith(isBuiltInDefault: false),
    );
  }

  /// Mở một phiên chọn đích mới cho 1 hộp thoại xuất.
  Future<ExportDestinationSession> openSession() async {
    final resolution = await resolveDefault();
    return ExportDestinationSession(resolution: resolution);
  }

  /// Chốt lựa chọn của người dùng khi họ bấm nút "Xuất":
  /// - Trả về đích thực tế cho lần xuất này.
  /// - Chỉ ghi đè mặc định trong [store] khi [session.rememberAsDefault] bật.
  Future<ExportDestination> commitSession(
    ExportDestinationSession session,
  ) async {
    final chosen = session.effectiveDestination;
    if (session.hasOverride && session.rememberAsDefault) {
      await store.writeCustomDefault(
        chosen.copyWith(isBuiltInDefault: false),
      );
    }
    return chosen;
  }

  /// Đặt lại nơi lưu mặc định của hồ sơ về thư mục gốc `In4Up` của nền tảng.
  Future<ExportDestination> resetToBuiltInDefault() async {
    await store.clearCustomDefault();
    return builtInDefaultProvider();
  }

  // ── Các hàm thuần dựng mặc định theo từng nền tảng ────────────────────────

  static ExportDestination buildAndroidDefault({
    required int sdkInt,
    String? legacyDownloadsRoot,
  }) {
    const display = 'Download/$kIn4UpPublicFolderName';
    if (sdkInt >= 29) {
      return const ExportDestination(
        kind: ExportDestinationKind.androidMediaStoreDownloads,
        location: display,
        displayPath: display,
        isBuiltInDefault: true,
      );
    }
    final root = (legacyDownloadsRoot != null &&
            legacyDownloadsRoot.trim().isNotEmpty)
        ? legacyDownloadsRoot.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '')
        : '/storage/emulated/0/Download';
    return ExportDestination(
      kind: ExportDestinationKind.androidLegacyDownloads,
      location: '$root/$kIn4UpPublicFolderName',
      displayPath: display,
      isBuiltInDefault: true,
    );
  }

  static ExportDestination buildIosDefault({
    required String appDocumentsPath,
  }) {
    final normalized =
        appDocumentsPath.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    return ExportDestination(
      kind: ExportDestinationKind.iosDocumentsFolder,
      location: '$normalized/$kIn4UpPublicFolderName',
      displayPath: 'On My iPhone/$kIn4UpPublicFolderName',
      isBuiltInDefault: true,
    );
  }

  static ExportDestination buildDesktopDefault({
    String? downloadsPath,
    String? homePath,
    required String fallbackAppDocumentsPath,
    bool isWindows = false,
  }) {
    final sep = isWindows ? r'\' : '/';
    if (downloadsPath != null && downloadsPath.trim().isNotEmpty) {
      final clean = _trimTrailingSeparators(downloadsPath);
      final target = '$clean$sep$kIn4UpPublicFolderName';
      return ExportDestination(
        kind: ExportDestinationKind.directoryPath,
        location: target,
        displayPath: shortenWithHome(target, homePath: homePath),
        isBuiltInDefault: true,
      );
    }
    if (homePath != null && homePath.trim().isNotEmpty) {
      final clean = _trimTrailingSeparators(homePath);
      final target = '$clean$sep$kIn4UpPublicFolderName';
      return ExportDestination(
        kind: ExportDestinationKind.directoryPath,
        location: target,
        displayPath: isWindows ? target : '~/$kIn4UpPublicFolderName',
        isBuiltInDefault: true,
      );
    }
    final cleanFallback = _trimTrailingSeparators(fallbackAppDocumentsPath);
    final target = '$cleanFallback$sep$kIn4UpPublicFolderName';
    return ExportDestination(
      kind: ExportDestinationKind.directoryPath,
      location: target,
      displayPath: target,
      isBuiltInDefault: true,
    );
  }

  /// Rút gọn `/home/user/Downloads/In4Up` thành `~/Downloads/In4Up` trên Unix.
  static String shortenWithHome(String fullPath, {String? homePath}) {
    if (homePath == null || homePath.trim().isEmpty) return fullPath;
    if (fullPath.contains(r'\')) return fullPath;
    final cleanHome = _trimTrailingSeparators(homePath);
    if (cleanHome.isEmpty || cleanHome == '/') return fullPath;
    if (fullPath == cleanHome) return '~';
    if (fullPath.startsWith('$cleanHome/')) {
      return '~/${fullPath.substring(cleanHome.length + 1)}';
    }
    return fullPath;
  }

  /// Biến SAF tree URI (`content://.../tree/primary%3ADownload%2FHocTap`) thành
  /// nhãn người thật đọc hiểu ngay (`Download/HocTap`).
  static String formatSafTreeLabel(
    String treeUri, {
    String? providerDisplayName,
  }) {
    final raw = treeUri.trim();
    const marker = '/tree/';
    final idx = raw.indexOf(marker);
    if (idx >= 0) {
      var tail = raw.substring(idx + marker.length);
      final subIdx = tail.indexOf('/document/');
      if (subIdx >= 0) {
        tail = tail.substring(0, subIdx);
      }
      String decoded;
      try {
        decoded = Uri.decodeComponent(tail);
      } catch (_) {
        decoded = tail;
      }
      if (decoded.startsWith('primary:')) {
        final rel = decoded.substring('primary:'.length).trim();
        return rel.isEmpty ? 'Bộ nhớ trong' : rel;
      }
      if (decoded.startsWith('home:')) {
        final rel = decoded.substring('home:'.length).trim();
        return rel.isEmpty ? 'Documents' : 'Documents/$rel';
      }
      final colon = decoded.indexOf(':');
      if (colon > 0) {
        final volume = decoded.substring(0, colon);
        final rel = decoded.substring(colon + 1).trim();
        return rel.isEmpty ? volume : '$volume/$rel';
      }
      if (decoded.isNotEmpty) return decoded;
    }
    if (providerDisplayName != null && providerDisplayName.trim().isNotEmpty) {
      return providerDisplayName.trim();
    }
    return raw;
  }

  /// Trả về tên tệp không đè lên tệp đã có: `bai.mp3` → `bai (2).mp3` →
  /// `bai (3).mp3`… (ADR-0029 § 5).
  static String uniqueDisplayName(
    String desiredFileName,
    bool Function(String candidate) exists,
  ) {
    final sanitized = sanitizeFileName(desiredFileName);
    if (!exists(sanitized)) return sanitized;

    final dot = sanitized.lastIndexOf('.');
    final hasExt = dot > 0 && dot < sanitized.length - 1;
    final stem = hasExt ? sanitized.substring(0, dot) : sanitized;
    final ext = hasExt ? sanitized.substring(dot) : '';

    for (var i = 2; i < 10000; i++) {
      final candidate = '$stem ($i)$ext';
      if (!exists(candidate)) return candidate;
    }
    return '${stem}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  /// Làm sạch tên tệp để hợp lệ trên cả FAT32 / exFAT / NTFS / ext4 / APFS.
  static String sanitizeFileName(
    String raw, {
    String fallbackStem = 'in4up_export',
  }) {
    var cleaned = raw
        .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    while (cleaned.endsWith('.') || cleaned.endsWith(' ')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isEmpty || cleaned == '.') return fallbackStem;

    final dot = cleaned.lastIndexOf('.');
    final hasExt = dot > 0 && dot < cleaned.length - 1;
    final stem = (hasExt ? cleaned.substring(0, dot) : cleaned).trim();
    final ext = hasExt ? cleaned.substring(dot).trim() : '';
    final safeStem = stem.isEmpty ? fallbackStem : stem;
    final cappedStem =
        safeStem.length > 96 ? safeStem.substring(0, 96).trimRight() : safeStem;
    return '$cappedStem$ext';
  }

  /// MIME chuẩn theo đuôi tệp để đăng ký vào `MediaStore.Downloads` / chia sẻ.
  static String mimeTypeForFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext =
        dot >= 0 ? fileName.substring(dot + 1).toLowerCase().trim() : '';
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'm4b':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'opus':
        return 'audio/opus';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      case 'pdf':
        return 'application/pdf';
      case 'json':
        return 'application/json';
      case 'md':
      case 'markdown':
        return 'text/markdown';
      case 'srt':
        return 'application/x-subrip';
      case 'vtt':
        return 'text/vtt';
      case 'lrc':
      case 'txt':
        return 'text/plain';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  static String _trimTrailingSeparators(String path) {
    var out = path.trim();
    while (out.length > 1 && (out.endsWith('/') || out.endsWith(r'\'))) {
      // Giữ nguyên `C:\` trên Windows nếu chỉ còn gốc ổ đĩa.
      if (out.length == 3 && out[1] == ':') break;
      out = out.substring(0, out.length - 1);
    }
    return out;
  }
}
