// lib/features/dictionary/services/dict_bundle_scanner.dart
//
// DictBundleScanner — nhận diện "dictionary set" (.mdx + .mdd + .css/asset
// kèm theo) từ danh sách file (I4U18-DICT-001).
//
// Thuần Dart (không dart:io, không Flutter) để test được không cần thiết bị:
// input là path tương đối (posix) + size — caller tự walk thư mục hoặc dựng
// từ các file user chọn (multi-file pick).
//
// Quy ước ghép cặp (MDict / GoldenDict phổ biến):
// - `Dict.mdx`  ↔ `Dict.mdd`, `Dict.1.mdd`, `Dict.2.mdd`… (multi-part MDD)
// - `.css` cùng thư mục gắn vào set (stylesheet hiển thị entry)
// - Folder chỉ có 1 MDX: mọi `.mdd` chưa khớp stem trong folder đó được tính
//   là MDD của set (ngườI dùng hay đổi tên file).
// - File còn lại cùng thư mục (hình/font/audio) = asset đi kèm.
//
// Thiếu file phụ KHÔNG chặn import: báo thiếu rõ ràng (missingParts) và vẫn
// tra từ được ở chế độ giảm cấp (không hình/âm thanh khi thiếu .mdd, style
// mặc định khi thiếu .css).

/// Một file scanner nhìn thấy (path tương đối posix + kích thước).
class DictScannedFile {
  final String path;
  final int sizeBytes;

  const DictScannedFile(this.path, {this.sizeBytes = 0});

  String get name {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  String get dir {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  String get lowerName => name.toLowerCase();

  @override
  String toString() => 'DictScannedFile($path, $sizeBytes)';
}

/// Một dictionary set nhận diện được (1 MDX + các file phụ).
class DictSetCandidate {
  /// File .mdx chính (bắt buộc).
  final DictScannedFile mdx;

  /// Các file .mdd ghép được (có thể nhiều part).
  final List<DictScannedFile> mddFiles;

  /// Các file .css cùng thư mục.
  final List<DictScannedFile> cssFiles;

  /// Asset khác cùng thư mục (hình ảnh/font/audio tham chiếu từ entry).
  final List<DictScannedFile> assetFiles;

  const DictSetCandidate({
    required this.mdx,
    this.mddFiles = const [],
    this.cssFiles = const [],
    this.assetFiles = const [],
  });

  /// Tên gợi ý cho từ điển (stem của file .mdx).
  String get suggestedName {
    final name = mdx.name;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// Thư mục chứa set (tương đối so với listing root — '' = gốc).
  String get folder => mdx.dir;

  /// MDX có vẻ trống/không đọc được dung lượng (size == 0 vì file rỗng
  /// thật hoặc SAF chặn stat). Không chặn import — parser của
  /// `DictionaryService` sẽ báo "MDX trống/không đọc được" khi đọc thật.
  bool get mdxLooksEmpty => mdx.sizeBytes == 0;

  /// Phần phụ còn thiếu — nhãn kỹ thuật kèm hậu quả cho user (UI tự bản
  /// địa hoá câu dẫn, giữ nguyên đuôi file để đối chiếu).
  List<String> get missingParts => [
        if (mddFiles.isEmpty) '.mdd (hình ảnh & âm thanh trong bài viết)',
        if (cssFiles.isEmpty) '.css (định dạng hiển thị của entry)',
      ];

  /// Set đầy đủ phụ kiện (mdx + mdd + css).
  bool get isCompleteBundle => mddFiles.isNotEmpty && cssFiles.isNotEmpty;

  /// Mọi file thuộc set (để Import/copy hoặc link đều liệt kê đủ).
  List<DictScannedFile> get allFiles => [
        mdx,
        ...mddFiles,
        ...cssFiles,
        ...assetFiles,
      ];
}

/// Kết quả quét 1 nguồn (folder hoặc multi-file selection).
class DictBundleReport {
  /// Các set nhận diện được (1 folder có thể chứa nhiều từ điển).
  final List<DictSetCandidate> sets;

  /// File .css/.mdd lẻ không ghép được vào set nào (thông tin cho user).
  final List<DictScannedFile> strayCompanions;

  const DictBundleReport({
    this.sets = const [],
    this.strayCompanions = const [],
  });

  bool get hasSets => sets.isNotEmpty;

  /// Set "tốt nhất" (đầy đủ nhất — ưu tiên có cả mdd + css).
  DictSetCandidate? get bestSet {
    if (sets.isEmpty) return null;
    final sorted = [...sets]..sort((a, b) {
        final scoreA = (a.mddFiles.isNotEmpty ? 2 : 0) +
            (a.cssFiles.isNotEmpty ? 1 : 0);
        final scoreB = (b.mddFiles.isNotEmpty ? 2 : 0) +
            (b.cssFiles.isNotEmpty ? 1 : 0);
        return scoreB.compareTo(scoreA);
      });
    return sorted.first;
  }
}

class DictBundleScanner {
  DictBundleScanner._();

  /// Chuẩn hoá path Windows → posix.
  static String normSep(String path) => path.replaceAll('\\', '/');

  static bool isMdxName(String name) =>
      name.toLowerCase().endsWith('.mdx');

  static bool isMddName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mdd')) return true;
    // Multi-part: name.1.mdd, name.2.mdd… (và .mdd.* không nhận)
    final dot = lower.lastIndexOf('.mdd');
    if (dot < 0) return false;
    final before = lower.substring(0, dot);
    final part = before.substring(before.lastIndexOf('.') < 0 ? 0 : before.lastIndexOf('.') + 1);
    return int.tryParse(part) != null;
  }

  static bool isCssName(String name) =>
      name.toLowerCase().endsWith('.css');

  /// Stem ghép MDD: `Dict.2.mdd` → `dict`, `Dict.mdd` → `dict`.
  static String mddStem(String name) {
    var lower = name.toLowerCase();
    if (lower.endsWith('.mdd')) {
      lower = lower.substring(0, lower.length - '.mdd'.length);
    }
    final dot = lower.lastIndexOf('.');
    if (dot > 0 && int.tryParse(lower.substring(dot + 1)) != null) {
      lower = lower.substring(0, dot);
    }
    return lower;
  }

  /// Stem của file MDX: `Oxford.MDX` → `oxford`.
  static String mdxStem(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mdx')
        ? lower.substring(0, lower.length - '.mdx'.length)
        : lower;
  }

  /// Quét danh sách file → báo cáo set.
  static DictBundleReport scan(List<DictScannedFile> files) {
    final normalized = <DictScannedFile>[
      for (final f in files)
        DictScannedFile(normSep(f.path), sizeBytes: f.sizeBytes),
    ];

    // Gom theo thư mục — một set sống gọn trong 1 thư mục.
    final byDir = <String, List<DictScannedFile>>{};
    for (final f in normalized) {
      byDir.putIfAbsent(f.dir, () => []).add(f);
    }

    final sets = <DictSetCandidate>[];
    final stray = <DictScannedFile>[];
    final usedPaths = <String>{};

    for (final entry in byDir.entries) {
      final dirFiles = entry.value;
      final mdxFiles =
          dirFiles.where((f) => isMdxName(f.name)).toList(growable: false);
      if (mdxFiles.isEmpty) continue;

      final mddFiles = dirFiles.where((f) => isMddName(f.name)).toList();
      final cssFiles = dirFiles.where((f) => isCssName(f.name)).toList();
      final pairedMdd = <DictScannedFile>[];

      // 1. Ghép theo stem: Dict.mdx ↔ Dict.mdd / Dict.1.mdd…
      for (final mdx in mdxFiles) {
        final target = mdxStem(mdx.name);
        for (final mdd in mddFiles) {
          if (usedPaths.contains(mdd.path)) continue;
          if (mddStem(mdd.name) == target) {
            pairedMdd.add(mdd);
            usedPaths.add(mdd.path);
          }
        }
      }

      // 2. Folder 1-MDX: mdd lẻ (không khớp stem) cũng tính vào set —
      // ngườI dùng đổi tên file tải về (vd `data.mdd`).
      if (mdxFiles.length == 1) {
        for (final mdd in mddFiles) {
          if (usedPaths.contains(mdd.path)) continue;
          pairedMdd.add(mdd);
          usedPaths.add(mdd.path);
        }
      }

      final sharedAssets = <DictScannedFile>[
        for (final f in dirFiles)
          if (!isMdxName(f.name) &&
              !isMddName(f.name) &&
              !isCssName(f.name) &&
              !usedPaths.contains(f.path))
            f,
      ];

      // Mỗi MDX một set; chia sẻ mdd lẻ chỉ cho MDX đầu tiên (1-MDX folder
      // thì đã gom ở bước 2).
      var assignedPair = false;
      for (final mdx in mdxFiles) {
        final target = mdxStem(mdx.name);
        final own = <DictScannedFile>[
          for (final mdd in pairedMdd)
            if (mddStem(mdd.name) == target) mdd,
        ];
        final fallback = (!assignedPair && own.isEmpty && mdxFiles.length == 1)
            ? pairedMdd
            : const <DictScannedFile>[];
        if (fallback.isNotEmpty) assignedPair = true;
        sets.add(DictSetCandidate(
          mdx: mdx,
          mddFiles: own.isNotEmpty ? own : fallback,
          cssFiles: cssFiles,
          assetFiles: sharedAssets,
        ));
      }
    }

    // File .mdd/.css lẻ ngoài mọi set (thông tin — không chặn gì).
    for (final f in normalized) {
      if (usedPaths.contains(f.path)) continue;
      if (isMddName(f.name) || isCssName(f.name)) {
        // css trong folder CÓ set đã được gắn vào set → chỉ báo stray khi
        // folder không có MDX nào.
        final dirFiles = byDir[f.dir] ?? const <DictScannedFile>[];
        final dirHasSet = dirFiles.any((g) => isMdxName(g.name));
        if (!dirHasSet) stray.add(f);
      }
    }

    return DictBundleReport(sets: sets, strayCompanions: stray);
  }
}
